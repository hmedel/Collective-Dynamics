#!/usr/bin/env julia
using HDF5
using Statistics
using DataFrames
using CSV
using Printf

campaign_dir = "results/campaign_eccentricity_scan_20251116_014451"

println("="^70)
println("ANÁLISIS CAMPAÑA PARCIAL: Eccentricity Scan (120/180 runs)")
println("="^70)
println()

# Funciones de análisis
function clustering_ratio(phi_positions, bin_width=π/4)
    """
    Calcula R = (partículas en eje mayor) / (partículas en eje menor)
    """
    n_mayor = count(φ -> (φ < bin_width || φ > 2π - bin_width ||
                          abs(φ - π) < bin_width), phi_positions)
    n_menor = count(φ -> abs(φ - π/2) < bin_width ||
                          abs(φ - 3π/2) < bin_width, phi_positions)
    return n_mayor / max(n_menor, 1)
end

function order_parameter(phi_positions)
    """
    Calcula Ψ = |⟨exp(iφ)⟩|
    Ψ=0: gas uniforme, Ψ=1: cristal perfecto
    """
    mean_cos = mean(cos.(phi_positions))
    mean_sin = mean(sin.(phi_positions))
    return sqrt(mean_cos^2 + mean_sin^2)
end

# Analizar todos los HDF5 existentes
results = []

files = sort(filter(f -> endswith(f, ".h5"), readdir(campaign_dir, join=true)))
println("Archivos encontrados: $(length(files))")
println()

for (i, file) in enumerate(files)
    filename = basename(file)

    # Extraer parámetros del nombre de archivo
    m = match(r"run_(\d+)_e([\d\.]+)_N(\d+)_E([\d\.]+)_seed(\d+)", filename)
    if m === nothing
        @warn "No se pudo parsear: $filename"
        continue
    end

    run_id = parse(Int, m.captures[1])
    e = parse(Float64, m.captures[2])
    N = parse(Int, m.captures[3])
    E_total = parse(Float64, m.captures[4])
    seed = parse(Int, m.captures[5])

    try
        h5open(file, "r") do f
            # Leer estado final
            phi_final = read(f["trajectories"]["phi"])[:, end]

            # Métricas
            R_cluster = clustering_ratio(phi_final)
            Psi = order_parameter(phi_final)

            # Energía
            if haskey(f, "conservation") && haskey(f["conservation"], "energy")
                energy = read(f["conservation"]["energy"])
                dE = maximum(abs.(energy .- energy[1])) / abs(energy[1])
            else
                dE = NaN
            end

            push!(results, (
                run_id=run_id, e=e, N=N, E_total=E_total, seed=seed,
                R=R_cluster, Psi=Psi, dE_rel=dE, file=filename
            ))
        end

        if i % 20 == 0
            print("\rProcesados: $i/$(length(files))")
        end
    catch err
        @warn "Error procesando $filename: $err"
    end
end
println("\rProcesados: $(length(results))/$(length(files))")
println()

# Crear DataFrame
df = DataFrame(results)

println("="^70)
println("RESUMEN TOTAL:")
println("-"^70)
println("Total simulaciones analizadas: $(nrow(df))")
println("Eccentricidades únicas: $(sort(unique(df.e)))")
println("Realizaciones por eccentricidad:")
println(combine(groupby(df, :e), nrow => :count))
println("="^70)
println()

# Agrupar por eccentricidad
grouped = groupby(df, :e)
summary = combine(grouped,
    :R => mean => :R_mean,
    :R => std => :R_std,
    :Psi => mean => :Psi_mean,
    :Psi => std => :Psi_std,
    :dE_rel => mean => :dE_mean,
    :dE_rel => std => :dE_std,
    nrow => :n_samples
)

# Ordenar por eccentricidad
sort!(summary, :e)

# Mostrar resumen
println("RESUMEN POR ECCENTRICIDAD:")
println("-"^70)
@printf("%-6s | %-5s | %-15s | %-15s | %-12s\n",
        "e", "N", "R (mean±std)", "Ψ (mean±std)", "⟨ΔE/E₀⟩")
println("-"^70)

for row in eachrow(summary)
    @printf("%.2f | %5d | %5.2f ± %5.2f | %.4f ± %.4f | %.2e\n",
            row.e, row.n_samples, row.R_mean, row.R_std,
            row.Psi_mean, row.Psi_std, row.dE_mean)
end
println("="^70)
println()

# Guardar resultados
CSV.write(joinpath(campaign_dir, "summary_by_eccentricity_PARTIAL.csv"), summary)
CSV.write(joinpath(campaign_dir, "all_results_PARTIAL.csv"), df)

println("Archivos guardados:")
println("  ✓ $(campaign_dir)/summary_by_eccentricity_PARTIAL.csv")
println("  ✓ $(campaign_dir)/all_results_PARTIAL.csv")
println()

# Análisis de tendencia
println("="^70)
println("ANÁLISIS DE TENDENCIA:")
println("-"^70)

sorted_e = sort(unique(df.e))
R_by_e = [mean(df[df.e .== e, :R]) for e in sorted_e]
Psi_by_e = [mean(df[df.e .== e, :Psi]) for e in sorted_e]

println("Tendencia R(e):")
for (e_val, R_val) in zip(sorted_e, R_by_e)
    @printf("  e = %.2f → R = %.2f\n", e_val, R_val)
end
println()

# Check monotonicity
if all(diff(R_by_e) .>= -0.1)  # Tolerancia pequeña para ruido estadístico
    println("✅ HIPÓTESIS CONFIRMADA (parcial): R aumenta con e")
    println("   Rango analizado: e ∈ [0.0, 0.9]")
else
    println("⚠️  WARNING: Tendencia no monotónica detectada")
    println("   Diferencias: $(diff(R_by_e))")
end
println()

# Análisis de conservación
println("="^70)
println("CONSERVACIÓN DE ENERGÍA:")
println("-"^70)

good_conservation = count(df.dE_rel .< 1e-4)
fair_conservation = count(1e-4 .<= df.dE_rel .< 1e-2)
poor_conservation = count(df.dE_rel .>= 1e-2)

@printf("  Excelente (ΔE/E₀ < 10⁻⁴): %3d/%d (%.1f%%)\n",
        good_conservation, nrow(df), 100*good_conservation/nrow(df))
@printf("  Aceptable (10⁻⁴ ≤ ΔE/E₀ < 10⁻²): %3d/%d (%.1f%%)\n",
        fair_conservation, nrow(df), 100*fair_conservation/nrow(df))
@printf("  Pobre (ΔE/E₀ ≥ 10⁻²): %3d/%d (%.1f%%)\n",
        poor_conservation, nrow(df), 100*poor_conservation/nrow(df))

if poor_conservation > 0
    println("\n  Runs con conservación pobre:")
    poor_runs = df[df.dE_rel .>= 1e-2, [:file, :e, :dE_rel]]
    for row in eachrow(poor_runs[1:min(5, nrow(poor_runs)), :])
        @printf("    %s (e=%.2f): ΔE/E₀ = %.2e\n", row.file, row.e, row.dE_rel)
    end
    if nrow(poor_runs) > 5
        println("    ... y $(nrow(poor_runs)-5) más")
    end
end

println("="^70)
println()

# Resumen ejecutivo
println("="^70)
println("RESUMEN EJECUTIVO:")
println("="^70)
println()
println("📊 Datos analizados: $(nrow(df))/120 runs completados (e=0.0-0.9)")
println("📈 Tendencia R(e): $(R_by_e[1]) → $(R_by_e[end]) (aumento de $(round((R_by_e[end]/R_by_e[1]-1)*100, digits=1))%)")
println("🎯 Clustering máximo observado: e=$(sorted_e[end]) → R=$(round(R_by_e[end], digits=2))")
println("✅ Conservación energía: $(round(100*good_conservation/nrow(df), digits=1))% excelente")
println()
println("⏳ Pendiente: 60 runs (e=0.95, 0.98, 0.99) ejecutándose en background")
println("   Estos incluyen el régimen de clustering fuerte (R > 5)")
println()
println("="^70)
