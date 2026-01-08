#!/usr/bin/env julia
# Análisis de múltiples runs para confirmar generalidad

using HDF5
using Statistics
using Printf

include("verify_clustering_location.jl")

println("="^70)
println("ANÁLISIS DE MÚLTIPLES RUNS - GENERALIDAD DEL MECANISMO")
println("="^70)
println()

# Encontrar múltiples archivos
files = [
    "results/campaign_20251114_151101/e0.980_N80_phi0.09_E0.32/seed_2/trajectories.h5",
    "results/campaign_20251114_151101/e0.980_N80_phi0.09_E0.32/seed_7/trajectories.h5",
    "results/campaign_20251114_151101/e0.980_N80_phi0.09_E0.32/seed_9/trajectories.h5",
    "results/campaign_20251114_151101/e0.980_N80_phi0.09_E0.32/seed_4/trajectories.h5",
    "results/campaign_20251114_151101/e0.980_N80_phi0.09_E0.32/seed_10/trajectories.h5",
]

# Filtrar archivos existentes
files_exist = filter(isfile, files)
n_files = length(files_exist)

println("Archivos encontrados: $n_files")
println()

# Acumuladores
count_major = 0
count_minor = 0
densities_major = Float64[]
densities_minor = Float64[]
ratios = Float64[]

for (i, file) in enumerate(files_exist)
    println("[$i/$n_files] Analizando: $(basename(dirname(dirname(file))))...")

    result = analyze_clustering_location(file)

    # Calcular densidades en ejes
    phi_centers = result.bin_centers
    counts = result.counts
    N = result.N

    # Eje mayor (±20° de 0° y 180°)
    idx_major_1 = findall(x -> abs(x) < 0.35 || abs(x - 2π) < 0.35, phi_centers)
    idx_major_2 = findall(x -> abs(x - π) < 0.35, phi_centers)
    idx_major = vcat(idx_major_1, idx_major_2)

    # Eje menor (±20° de 90° y 270°)
    idx_minor_1 = findall(x -> abs(x - π/2) < 0.35, phi_centers)
    idx_minor_2 = findall(x -> abs(x - 3π/2) < 0.35, phi_centers)
    idx_minor = vcat(idx_minor_1, idx_minor_2)

    dens_major = sum(counts[idx_major]) / N * 100
    dens_minor = sum(counts[idx_minor]) / N * 100
    ratio = dens_major / dens_minor

    push!(densities_major, dens_major)
    push!(densities_minor, dens_minor)
    push!(ratios, ratio)

    if result.cluster_location == "MAJOR_AXIS"
        global count_major += 1
    else
        global count_minor += 1
    end

    @printf("  Densidad eje MAYOR: %.1f%%\n", dens_major)
    @printf("  Densidad eje MENOR: %.1f%%\n", dens_minor)
    @printf("  Ratio: %.1fx\n", ratio)
    @printf("  Clasificación: %s\n\n", result.cluster_location)
end

println("="^70)
println("RESULTADOS AGREGADOS")
println("="^70)
println()

@printf("Total runs analizados: %d\n", n_files)
println()

@printf("Clustering en EJE MAYOR: %d runs (%.1f%%)\n", count_major, 100*count_major/n_files)
@printf("Clustering en EJE MENOR: %d runs (%.1f%%)\n", count_minor, 100*count_minor/n_files)
println()

println("Densidades promedio:")
@printf("  Eje MAYOR: %.1f%% ± %.1f%%\n", mean(densities_major), std(densities_major))
@printf("  Eje MENOR: %.1f%% ± %.1f%%\n", mean(densities_minor), std(densities_minor))
println()

@printf("Ratio promedio (mayor/menor): %.1fx ± %.1fx\n", mean(ratios), std(ratios))
println()

println("="^70)
println("CONCLUSIÓN")
println("="^70)
println()

if count_major == n_files
    println("✅ 100%% de los runs muestran clustering en EJE MAYOR")
    println("   → Mecanismo ROBUSTO y REPRODUCIBLE")
    println("   → Alta curvatura κ → frenado → clustering")
    println()
    @printf("   Consistencia: %d/%d runs (%.1f%%)\n", count_major, n_files, 100.0)
elseif count_major > count_minor
    println("✅ Mayoría de runs muestran clustering en EJE MAYOR")
    @printf("   Consistencia: %d/%d runs (%.1f%%)\n", count_major, n_files, 100*count_major/n_files)
else
    println("⚠️  Resultados mixtos - revisar análisis")
end

println("="^70)
