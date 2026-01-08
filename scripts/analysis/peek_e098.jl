#!/usr/bin/env julia
# Preliminary peek at e=0.98 data (partial - only 4 runs available)

using HDF5
using Statistics
using Printf

println("="^70)
println("VISTAZO PRELIMINAR: e=0.98 (PARCIAL - solo primeros runs)")
println("="^70)
println()
println("⚠️  ADVERTENCIA: Muestra pequeña, resultados tentativos")
println()

campaign_dir = "results/campaign_eccentricity_scan_20251116_014451"

# Functions for metrics
function clustering_ratio(phi_positions, bin_width=π/4)
    n_mayor = count(φ -> (φ < bin_width || φ > 2π - bin_width ||
                          abs(φ - π) < bin_width), phi_positions)
    n_menor = count(φ -> abs(φ - π/2) < bin_width ||
                          abs(φ - 3π/2) < bin_width, phi_positions)
    return n_mayor / max(n_menor, 1)
end

function order_parameter(phi_positions)
    mean_cos = mean(cos.(phi_positions))
    mean_sin = mean(sin.(phi_positions))
    return sqrt(mean_cos^2 + mean_sin^2)
end

# Analyze e=0.98 runs
R_values = Float64[]
Psi_values = Float64[]

for file in sort(readdir(campaign_dir, join=true))
    !endswith(file, ".h5") && continue
    !occursin("e0.980", file) && continue

    h5open(file, "r") do f
        phi_final = read(f["trajectories"]["phi"])[:, end]

        R = clustering_ratio(phi_final)
        Psi = order_parameter(phi_final)

        push!(R_values, R)
        push!(Psi_values, Psi)
    end
end

n_runs = length(R_values)
println("Runs disponibles: $n_runs / 20 (parcial)")
println()

if n_runs > 0
    R_mean = mean(R_values)
    R_std = n_runs > 1 ? std(R_values) : 0.0
    Psi_mean = mean(Psi_values)
    Psi_std = n_runs > 1 ? std(Psi_values) : 0.0

    println("RESULTADOS PRELIMINARES e=0.98:")
    println("-"^70)
    @printf("  R (clustering):     %.2f ± %.2f  (n=%d)\n", R_mean, R_std, n_runs)
    @printf("  Ψ (order param):    %.4f ± %.4f\n", Psi_mean, Psi_std)
    println()

    # Individual values
    println("Valores individuales:")
    for (i, (R, Psi)) in enumerate(zip(R_values, Psi_values))
        @printf("  Run %d: R = %.2f, Ψ = %.4f\n", i, R, Psi)
    end
    println()

    # Comparison
    println("COMPARACIÓN CON e=0.95:")
    println("-"^70)
    println("  e=0.95:  R = 2.51 ± 0.62,  Ψ = 0.10 ± 0.05")
    @printf("  e=0.98:  R = %.2f ± %.2f,  Ψ = %.4f ± %.4f  ← PRELIMINAR (n=%d)\n",
            R_mean, R_std, Psi_mean, Psi_std, n_runs)
    println()

    # Tentative assessment
    if R_mean > 3.0
        println("  🚀 TENDENCIA: R > 3.0 → clustering EXTREMO detectado!")
        if Psi_mean > 0.2
            println("  ✨ Ψ > 0.2 → orden orientacional emergente!")
        end
    else
        println("  ⏸️  TENDENCIA: R < 3.0 → aceleración moderada")
    end

    println()
    println("="^70)
    println()
    println("⚠️  Esperar n=20 para estadística robusta")
    println("   ETA: ~20-25 minutos")
    println("="^70)
else
    println("⚠️  No se encontraron archivos para e=0.98 aún")
end
