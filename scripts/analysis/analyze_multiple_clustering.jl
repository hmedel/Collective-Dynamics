#!/usr/bin/env julia
# Análisis de múltiples simulaciones para verificar ubicación de clustering

using HDF5
using Statistics
using Printf

include("verify_clustering_location.jl")

# Analizar múltiples archivos
files = [
    "results/campaign_20251114_151101/e0.980_N80_phi0.09_E0.32/seed_2/trajectories.h5",
    "results/campaign_20251114_151101/e0.980_N80_phi0.09_E0.32/seed_7/trajectories.h5",
    "results/campaign_20251114_151101/e0.980_N80_phi0.09_E0.32/seed_9/trajectories.h5",
    "results/campaign_20251114_151101/e0.980_N80_phi0.09_E0.32/seed_4/trajectories.h5",
    "results/campaign_20251114_151101/e0.980_N80_phi0.09_E0.32/seed_10/trajectories.h5",
]

println("="^70)
println("ANÁLISIS DE MÚLTIPLES SIMULACIONES (e≈0.98)")
println("="^70)
println()

results_minor = 0
results_major = 0

for (i, file) in enumerate(files)
    if !isfile(file)
        continue
    end

    result = analyze_clustering_location(file)

    @printf("Run %d: φ_peak = %.3f rad (%.0f°)\n", i, result.phi_max_density, rad2deg(result.phi_max_density))
    @printf("  Location: %s\n", result.cluster_location)
    @printf("  r = %.3f, g_φφ = %.3f, κ = %.3f\n\n", result.r_at_peak, result.g_at_peak, result.kappa_at_peak)

    if result.cluster_location == "MINOR_AXIS"
        results_minor += 1
    else
        results_major += 1
    end
end

println("="^70)
println("RESUMEN:")
println("="^70)
@printf("Clustering en EJE MAYOR: %d runs\n", results_major)
@printf("Clustering en EJE MENOR: %d runs\n", results_minor)
println()

if results_major > results_minor
    println("✅ CLUSTERING OCURRE EN EJE MAYOR")
    println("   → r grande, g_φφ grande, κ ALTA")
    println("   → Nuestra 'corrección' era INCORRECTA")
else
    println("✅ CLUSTERING OCURRE EN EJE MENOR")
    println("   → r pequeño, g_φφ pequeño, κ baja")
    println("   → Nuestra 'corrección' era CORRECTA")
end
println("="^70)
