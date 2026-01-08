#!/usr/bin/env julia
# Análisis agregado de campaña completa: Scaling laws y figuras para paper

using Pkg
Pkg.activate(".")

using HDF5
using Statistics
using Printf
using Plots
using LaTeXStrings
using DataFrames
using CSV
using Glob

"""
Analiza todos los archivos HDF5 en un directorio de campaña
"""
function analyze_campaign(campaign_dir::String; output_dir="campaign_analysis")
    println("="^70)
    println("ANÁLISIS DE CAMPAÑA COMPLETA")
    println("="^70)
    println()
    println("Directorio: $campaign_dir")
    println()

    # Buscar todos los archivos HDF5
    h5_files = glob("*.h5", campaign_dir)
    n_files = length(h5_files)

    if n_files == 0
        println("ERROR: No se encontraron archivos HDF5 en $campaign_dir")
        exit(1)
    end

    println("Archivos encontrados: $n_files")
    println()

    # DataFrame para almacenar resultados
    results = DataFrame(
        run_id = Int[],
        e = Float64[],
        N = Int[],
        seed = Int[],
        Ψ_initial = Float64[],
        Ψ_final = Float64[],
        R_initial = Float64[],
        R_final = Float64[],
        S_initial = Float64[],
        S_final = Float64[],
        τ_relax = Float64[],
        n_clusters_final = Int[],
        largest_cluster_frac = Float64[]
    )

    println("Procesando archivos...")
    for (i, filepath) in enumerate(h5_files)
        print("\r  Progreso: $i/$n_files")
        flush(stdout)

        h5open(filepath, "r") do file
            # Leer configuración
            run_id = read(attributes(file["config"]), "run_id")
            e = read(attributes(file["config"]), "eccentricity")
            N = read(attributes(file["config"]), "N")
            seed = read(attributes(file["config"]), "seed")

            # Leer trayectorias
            times = read(file["trajectories/time"])
            phi = read(file["trajectories/phi"])
            phidot = read(file["trajectories/phidot"])

            n_times = length(times)

            # Calcular métricas
            Ψ_initial = order_parameter(phi[:, 1])
            Ψ_final = order_parameter(phi[:, end])
            R_initial = clustering_ratio(phi[:, 1])
            R_final = clustering_ratio(phi[:, end])
            S_initial = phase_space_entropy(phi[:, 1], phidot[:, 1])
            S_final = phase_space_entropy(phi[:, end], phidot[:, end])

            # Calcular parámetro de orden temporal para τ_relax
            order_param_t = [order_parameter(phi[:, t]) for t in 1:n_times]
            Ψ_90 = 0.1 + 0.9 * Ψ_final
            idx_relax = findfirst(order_param_t .> Ψ_90)
            τ_relax = idx_relax !== nothing ? times[idx_relax] : NaN

            # Clusters finales
            clusters = detect_clusters(phi[:, end])
            n_clusters_final = length(clusters)
            largest_cluster_frac = maximum(length.(clusters)) / N

            # Agregar a resultados
            push!(results, (
                run_id, e, N, seed,
                Ψ_initial, Ψ_final,
                R_initial, R_final,
                S_initial, S_final,
                τ_relax,
                n_clusters_final,
                largest_cluster_frac
            ))
        end
    end
    println()
    println("✅ Procesamiento completado")
    println()

    # Crear directorio de salida
    mkpath(output_dir)

    # Guardar resultados
    CSV.write(joinpath(output_dir, "campaign_results.csv"), results)
    println("Resultados guardados: $(output_dir)/campaign_results.csv")
    println()

    # Análisis por eccentricity
    println("="^70)
    println("ANÁLISIS POR ECCENTRICITY")
    println("="^70)
    println()

    eccentricities = sort(unique(results.e))
    n_e = length(eccentricities)

    @printf("%-6s | %-5s | %-10s | %-10s | %-10s | %-10s\n",
            "e", "N", "Ψ_final", "R_final", "S_final", "τ_relax")
    println("-"^70)

    summary_e = DataFrame(
        e = Float64[],
        n_realizations = Int[],
        Ψ_final_mean = Float64[],
        Ψ_final_std = Float64[],
        R_final_mean = Float64[],
        R_final_std = Float64[],
        S_final_mean = Float64[],
        S_final_std = Float64[],
        τ_relax_mean = Float64[],
        τ_relax_std = Float64[]
    )

    for e in eccentricities
        subset = filter(row -> row.e == e, results)
        n_realizations = nrow(subset)

        Ψ_mean = mean(subset.Ψ_final)
        Ψ_std = std(subset.Ψ_final)
        R_mean = mean(subset.R_final)
        R_std = std(subset.R_final)
        S_mean = mean(subset.S_final)
        S_std = std(subset.S_final)

        # τ_relax puede tener NaNs
        τ_valid = filter(!isnan, subset.τ_relax)
        τ_mean = length(τ_valid) > 0 ? mean(τ_valid) : NaN
        τ_std = length(τ_valid) > 0 ? std(τ_valid) : NaN

        @printf("%.2f | %3d | %.3f±%.3f | %.2f±%.2f | %.3f±%.3f | %.1f±%.1f\n",
                e, n_realizations, Ψ_mean, Ψ_std, R_mean, R_std,
                S_mean, S_std, τ_mean, τ_std)

        push!(summary_e, (e, n_realizations,
                          Ψ_mean, Ψ_std,
                          R_mean, R_std,
                          S_mean, S_std,
                          τ_mean, τ_std))
    end
    println("="^70)
    println()

    # Guardar resumen
    CSV.write(joinpath(output_dir, "summary_by_eccentricity.csv"), summary_e)

    # Generar figuras para el paper
    println("Generando figuras para el paper...")

    # FIGURA 1: Scaling laws
    p1 = scatter(summary_e.e, summary_e.Ψ_final_mean,
                yerr=summary_e.Ψ_final_std,
                xlabel="Eccentricity e", ylabel=L"Order parameter $\Psi$",
                title="Transition Strength vs Eccentricity",
                label="Final state", markersize=6, legend=:topleft,
                xlims=(-0.05, 1.05), ylims=(0, 1.05))
    # Línea guía
    e_fit = range(0, 1, length=100)
    plot!(p1, e_fit, e_fit.^2, linestyle=:dash, color=:gray,
          label=L"$\Psi \sim e^2$", linewidth=2)

    p2 = scatter(summary_e.e, summary_e.R_final_mean,
                yerr=summary_e.R_final_std,
                xlabel="Eccentricity e", ylabel="Clustering ratio R",
                title="Clustering Strength vs Eccentricity",
                label="Final state", markersize=6, legend=:topleft,
                xlims=(-0.05, 1.05), yscale=:log10)

    p3 = scatter(summary_e.e, summary_e.S_final_mean,
                yerr=summary_e.S_final_std,
                xlabel="Eccentricity e", ylabel="Phase space entropy S",
                title="Entropy vs Eccentricity",
                label="Final state", markersize=6, legend=:topright,
                xlims=(-0.05, 1.05), ylims=(0, 1.05))

    p4 = scatter(summary_e.e[.!isnan.(summary_e.τ_relax_mean)],
                summary_e.τ_relax_mean[.!isnan.(summary_e.τ_relax_mean)],
                yerr=summary_e.τ_relax_std[.!isnan.(summary_e.τ_relax_mean)],
                xlabel="Eccentricity e", ylabel=L"Relaxation time $\tau$ (s)",
                title="Relaxation Time vs Eccentricity",
                label="Data", markersize=6, legend=:topleft,
                xlims=(-0.05, 1.05))

    fig1 = plot(p1, p2, p3, p4, layout=(2,2), size=(1200, 1000))
    savefig(fig1, joinpath(output_dir, "scaling_laws.png"))

    # FIGURA 2: Comparación gas vs cristal (e=0.0 vs e=0.98)
    if 0.0 in eccentricities && 0.98 in eccentricities
        # Encontrar un run de cada
        run_gas = filter(row -> abs(row.e) < 0.01, results)[1, :]
        run_crystal = filter(row -> abs(row.e - 0.98) < 0.01, results)[1, :]

        println("  Comparando: e=$(run_gas.e) (gas) vs e=$(run_crystal.e) (cristal)")

        @printf("    Gas:     Ψ=%.3f, R=%.2f, S=%.3f\n",
                run_gas.Ψ_final, run_gas.R_final, run_gas.S_final)
        @printf("    Cristal: Ψ=%.3f, R=%.2f, S=%.3f\n",
                run_crystal.Ψ_final, run_crystal.R_final, run_crystal.S_final)
    end

    println("✅ Figuras guardadas en $output_dir/")
    println()

    return results, summary_e
end

# Funciones auxiliares (copiadas de analyze_phase_transition.jl)
function order_parameter(phi_positions)
    mean_cos = mean(cos.(phi_positions))
    mean_sin = mean(sin.(phi_positions))
    R = sqrt(mean_cos^2 + mean_sin^2)
    return R
end

function clustering_ratio(phi_positions, bin_width=π/4)
    n_mayor = count(φ -> (φ < bin_width || φ > 2π - bin_width ||
                          abs(φ - π) < bin_width), phi_positions)
    n_menor = count(φ -> abs(φ - π/2) < bin_width ||
                          abs(φ - 3π/2) < bin_width, phi_positions)
    return n_mayor / max(n_menor, 1)
end

function phase_space_entropy(phi, phidot; n_bins=20)
    phi_edges = range(0, 2π, length=n_bins+1)
    phidot_min, phidot_max = extrema(phidot)
    phidot_edges = range(phidot_min, phidot_max, length=n_bins+1)

    H = zeros(n_bins, n_bins)
    for (p, pd) in zip(phi, phidot)
        i = searchsortedfirst(phi_edges, p) - 1
        j = searchsortedfirst(phidot_edges, pd) - 1
        i = clamp(i, 1, n_bins)
        j = clamp(j, 1, n_bins)
        H[i, j] += 1
    end

    H ./= sum(H)

    S = 0.0
    for p in H
        if p > 0
            S -= p * log(p)
        end
    end

    S_max = log(n_bins^2)
    return S / S_max
end

function detect_clusters(phi_positions; threshold=0.3)
    phi_sorted = sort(phi_positions)
    N = length(phi_sorted)

    clusters = []
    current_cluster = [phi_sorted[1]]

    for i in 2:N
        gap = phi_sorted[i] - phi_sorted[i-1]

        if i == N
            gap = min(gap, 2π - phi_sorted[N] + phi_sorted[1])
        end

        if gap < threshold
            push!(current_cluster, phi_sorted[i])
        else
            push!(clusters, current_cluster)
            current_cluster = [phi_sorted[i]]
        end
    end

    push!(clusters, current_cluster)
    return clusters
end

# Main
if length(ARGS) < 1
    println("Usage: julia analyze_campaign_phase_transition.jl <campaign_dir> [output_dir]")
    println()
    println("Example:")
    println("  julia analyze_campaign_phase_transition.jl results/campaign_eccentricity_scan_20251116_123456")
    exit(1)
end

campaign_dir = ARGS[1]
output_dir = length(ARGS) >= 2 ? ARGS[2] : "campaign_analysis"

if !isdir(campaign_dir)
    println("ERROR: Directory not found: $campaign_dir")
    exit(1)
end

results, summary = analyze_campaign(campaign_dir; output_dir=output_dir)

println("="^70)
println("ANÁLISIS DE CAMPAÑA COMPLETADO")
println("="^70)
println()
println("Resultados guardados en: $output_dir/")
println("  - campaign_results.csv")
println("  - summary_by_eccentricity.csv")
println("  - scaling_laws.png")
println()
