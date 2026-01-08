#!/usr/bin/env julia
#
# analyze_campaign_statistics.jl
#
# Análisis estadístico completo de la campaña final
# Extrae metadata, conservación de energía, y estadísticas básicas
#

using HDF5
using JSON
using Statistics
using DataFrames
using CSV
using Printf
using Dates

"""
    extract_run_metadata(run_dir)

Extrae metadata y estadísticas básicas de un run individual
"""
function extract_run_metadata(run_dir)
    # Leer summary.json si existe
    summary_file = joinpath(run_dir, "summary.json")
    if !isfile(summary_file)
        return nothing
    end

    summary = JSON.parsefile(summary_file)

    # Leer HDF5 para estadísticas adicionales
    h5_file = joinpath(run_dir, "trajectories.h5")
    if !isfile(h5_file)
        return nothing
    end

    stats = Dict{String, Any}()

    h5open(h5_file, "r") do file
        # Metadata básica (almacenada como atributos)
        meta_attrs = attributes(file["metadata"])
        params_attrs = attributes(file["params"])

        stats["run_id"] = get(summary, "run_id", missing)
        stats["N"] = read(meta_attrs["N"])
        stats["e"] = read(meta_attrs["eccentricity"])
        stats["a"] = read(meta_attrs["a"])
        stats["b"] = read(meta_attrs["b"])

        # Intentar leer parámetros adicionales
        if haskey(params_attrs, "seed")
            stats["seed"] = read(params_attrs["seed"])
        else
            stats["seed"] = missing
        end

        if haskey(params_attrs, "radius")
            stats["radius"] = read(params_attrs["radius"])
        else
            stats["radius"] = missing
        end

        if haskey(params_attrs, "phi_intrinsic")
            stats["phi_intrinsic"] = read(params_attrs["phi_intrinsic"])
        else
            stats["phi_intrinsic"] = missing
        end

        # Conservación de energía
        if haskey(file, "conservation")
            E = read(file["conservation/total_energy"])
            stats["E_initial"] = E[1]
            stats["E_final"] = E[end]
            stats["E_mean"] = mean(E)
            stats["E_std"] = std(E)
            stats["dE_rel_max"] = maximum(abs.(E .- E[1])) / abs(E[1])
            stats["dE_rel_std"] = std(E) / abs(E[1])
        else
            stats["dE_rel_max"] = missing
        end

        # Estadísticas temporales
        if haskey(file, "trajectories/time")
            t = read(file["trajectories/time"])
            stats["t_final"] = t[end]
            stats["n_snapshots"] = length(t)
            stats["dt_avg"] = (t[end] - t[1]) / (length(t) - 1)
        end

        # Estadísticas de ángulos (para detectar clustering)
        if haskey(file, "trajectories/phi")
            phi = read(file["trajectories/phi"])
            N_particles = size(phi, 1)

            # Estadísticas del estado final
            phi_final = phi[:, end]
            stats["phi_final_mean"] = mean(phi_final)
            stats["phi_final_std"] = std(phi_final)
            stats["phi_final_range"] = maximum(phi_final) - minimum(phi_final)

            # Indicador simple de clustering (basado en dispersión espacial)
            # Si std es pequeño → clustering fuerte
            # Si std es grande (~π) → dispersión uniforme
            stats["clustering_indicator"] = stats["phi_final_std"] < 1.0
        end

        # File size
        stats["file_size_MB"] = filesize(h5_file) / 1e6
    end

    return stats
end

"""
    analyze_campaign(campaign_dir)

Analiza toda la campaña y genera estadísticas agregadas
"""
function analyze_campaign(campaign_dir::String)
    println("="^80)
    println("ANÁLISIS ESTADÍSTICO DE CAMPAÑA")
    println("="^80)
    println("Directorio: ", campaign_dir)
    println()

    # Buscar todos los directorios de runs
    run_dirs = filter(readdir(campaign_dir, join=true)) do path
        isdir(path) && occursin(r"^e\d", basename(path))
    end

    println("Runs encontrados: ", length(run_dirs))
    println()

    # Extraer metadata de todos los runs
    println("Extrayendo metadata...")
    all_stats = []
    failed_runs = []

    for (i, run_dir) in enumerate(run_dirs)
        stats = extract_run_metadata(run_dir)
        if stats !== nothing
            push!(all_stats, stats)
        else
            push!(failed_runs, basename(run_dir))
        end

        if i % 50 == 0
            print("\rProcesados: $i/$(length(run_dirs))")
        end
    end
    println("\rProcesados: $(length(run_dirs))/$(length(run_dirs))")
    println()

    # Convertir a DataFrame
    df = DataFrame(all_stats)

    # Ordenar por run_id
    sort!(df, :run_id)

    println("="^80)
    println("RESUMEN GENERAL")
    println("="^80)
    println("Simulaciones exitosas: ", nrow(df), "/240")
    println("Simulaciones fallidas:  ", length(failed_runs))
    println()

    # Cobertura del espacio de parámetros
    println("="^80)
    println("COBERTURA DEL ESPACIO DE PARÁMETROS")
    println("="^80)

    N_values = sort(unique(df.N))
    e_values = sort(unique(df.e))

    println("\nTabla de cobertura (N × e):")
    println("-"^80)
    @printf("%-8s", "N \\ e")
    for e in e_values
        @printf("%8.1f", e)
    end
    println("  Total")
    println("-"^80)

    total_per_N = zeros(Int, length(N_values))
    total_per_e = zeros(Int, length(e_values))

    for (i, N) in enumerate(N_values)
        @printf("%-8d", N)
        for (j, e) in enumerate(e_values)
            count = nrow(filter(row -> row.N == N && row.e == e, df))
            total_per_N[i] += count
            total_per_e[j] += count
            @printf("%8d", count)
        end
        @printf("%8d\n", total_per_N[i])
    end

    println("-"^80)
    @printf("%-8s", "Total")
    for count in total_per_e
        @printf("%8d", count)
    end
    @printf("%8d\n", sum(total_per_e))
    println()

    # Estadísticas de conservación de energía
    println("="^80)
    println("CONSERVACIÓN DE ENERGÍA")
    println("="^80)
    println()

    # Por eccentricity
    println("Estadísticas por excentricidad:")
    println("-"^80)
    @printf("%-10s %15s %15s %15s\n", "e", "ΔE/E₀ mean", "ΔE/E₀ max", "N runs")
    println("-"^80)

    for e in e_values
        subset = filter(row -> row.e == e, df)
        if nrow(subset) > 0
            @printf("%-10.1f %15.3e %15.3e %15d\n",
                    e,
                    mean(subset.dE_rel_max),
                    maximum(subset.dE_rel_max),
                    nrow(subset))
        end
    end
    println()

    # Por N
    println("Estadísticas por número de partículas:")
    println("-"^80)
    @printf("%-10s %15s %15s %15s\n", "N", "ΔE/E₀ mean", "ΔE/E₀ max", "N runs")
    println("-"^80)

    for N in N_values
        subset = filter(row -> row.N == N, df)
        if nrow(subset) > 0
            @printf("%-10d %15.3e %15.3e %15d\n",
                    N,
                    mean(subset.dE_rel_max),
                    maximum(subset.dE_rel_max),
                    nrow(subset))
        end
    end
    println()

    # Global
    println("Estadísticas globales:")
    @printf("  ΔE/E₀ mean:   %.3e\n", mean(df.dE_rel_max))
    @printf("  ΔE/E₀ median: %.3e\n", median(df.dE_rel_max))
    @printf("  ΔE/E₀ max:    %.3e\n", maximum(df.dE_rel_max))
    @printf("  ΔE/E₀ min:    %.3e\n", minimum(df.dE_rel_max))
    println()

    # Clasificación de conservación
    excellent = nrow(filter(row -> row.dE_rel_max < 1e-6, df))
    good = nrow(filter(row -> 1e-6 <= row.dE_rel_max < 1e-4, df))
    acceptable = nrow(filter(row -> 1e-4 <= row.dE_rel_max < 1e-2, df))
    poor = nrow(filter(row -> row.dE_rel_max >= 1e-2, df))

    println("Clasificación de conservación:")
    @printf("  ✅ Excelente (ΔE/E₀ < 1e-6):  %3d (%5.1f%%)\n", excellent, 100*excellent/nrow(df))
    @printf("  ✅ Bueno (1e-6 ≤ ΔE/E₀ < 1e-4): %3d (%5.1f%%)\n", good, 100*good/nrow(df))
    @printf("  ⚠️  Aceptable (1e-4 ≤ ΔE/E₀ < 1e-2): %3d (%5.1f%%)\n", acceptable, 100*acceptable/nrow(df))
    @printf("  ❌ Pobre (ΔE/E₀ ≥ 1e-2):       %3d (%5.1f%%)\n", poor, 100*poor/nrow(df))
    println()

    # Indicadores de clustering
    println("="^80)
    println("INDICADORES DE CLUSTERING")
    println("="^80)
    println()

    println("Runs con clustering detectado (φ_std < 1.0):")
    println("-"^80)
    @printf("%-10s %10s %15s\n", "e", "N", "Clustered/Total")
    println("-"^80)

    for e in e_values
        for N in N_values
            subset = filter(row -> row.N == N && row.e == e, df)
            if nrow(subset) > 0
                clustered = nrow(filter(row -> row.clustering_indicator, subset))
                @printf("%-10.1f %10d %15s\n", e, N, "$clustered/$(nrow(subset))")
            end
        end
    end
    println()

    # Estadísticas de archivos
    println("="^80)
    println("ALMACENAMIENTO")
    println("="^80)
    println()

    @printf("Tamaño total:           %.1f MB\n", sum(df.file_size_MB))
    @printf("Tamaño promedio/run:    %.2f MB\n", mean(df.file_size_MB))
    @printf("Tamaño min/run:         %.2f MB\n", minimum(df.file_size_MB))
    @printf("Tamaño max/run:         %.2f MB\n", maximum(df.file_size_MB))
    println()

    # Guardar resultados
    output_dir = joinpath(campaign_dir, "analysis")
    mkpath(output_dir)

    csv_file = joinpath(output_dir, "campaign_statistics.csv")
    CSV.write(csv_file, df)
    println("✅ Estadísticas guardadas en: $csv_file")

    # Guardar resumen
    summary_file = joinpath(output_dir, "statistical_summary.txt")
    open(summary_file, "w") do io
        println(io, "Campaign Statistical Summary")
        println(io, "="^80)
        println(io, "Campaign directory: ", campaign_dir)
        println(io, "Analysis date: ", now())
        println(io)
        println(io, "Successful runs: ", nrow(df), "/240 (", round(100*nrow(df)/240, digits=1), "%)")
        println(io, "Failed runs: ", length(failed_runs))
        println(io)
        println(io, "Energy Conservation:")
        println(io, "  Mean ΔE/E₀: ", mean(df.dE_rel_max))
        println(io, "  Max ΔE/E₀:  ", maximum(df.dE_rel_max))
        println(io)
        println(io, "Storage:")
        println(io, "  Total: ", round(sum(df.file_size_MB), digits=1), " MB")
        println(io, "  Average per run: ", round(mean(df.file_size_MB), digits=2), " MB")
    end
    println("✅ Resumen guardado en: $summary_file")
    println()

    return df
end

# Main execution
if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) < 1
        println("Usage: julia analyze_campaign_statistics.jl <campaign_dir>")
        exit(1)
    end

    campaign_dir = ARGS[1]

    if !isdir(campaign_dir)
        println("❌ Error: Campaign directory not found: $campaign_dir")
        exit(1)
    end

    df = analyze_campaign(campaign_dir)

    println("="^80)
    println("✅ ANÁLISIS COMPLETADO")
    println("="^80)
end
