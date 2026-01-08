#!/usr/bin/env julia
# Quick analysis of e=0.95 data to check phase transition

using HDF5
using Statistics
using Printf

println("="^70)
println("ANÁLISIS RÁPIDO: e=0.95 (Región de Transición)")
println("="^70)
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

# Analyze e=0.95 runs
R_values = Float64[]
Psi_values = Float64[]
dE_values = Float64[]

for file in sort(readdir(campaign_dir, join=true))
    !endswith(file, ".h5") && continue
    !occursin("e0.950", file) && continue

    h5open(file, "r") do f
        # Final state
        phi_final = read(f["trajectories"]["phi"])[:, end]

        # Metrics
        R = clustering_ratio(phi_final)
        Psi = order_parameter(phi_final)

        push!(R_values, R)
        push!(Psi_values, Psi)

        # Energy conservation
        if haskey(f, "conservation") && haskey(f["conservation"], "energy")
            energy = read(f["conservation"]["energy"])
            dE = maximum(abs.(energy .- energy[1])) / energy[1]
            push!(dE_values, dE)
        end
    end
end

n_runs = length(R_values)
println("Runs analizados: $n_runs / 20")
println()

if n_runs > 0
    R_mean = mean(R_values)
    R_std = std(R_values)
    Psi_mean = mean(Psi_values)
    Psi_std = std(Psi_values)

    println("RESULTADOS e=0.95:")
    println("-"^70)
    @printf("  R (clustering):     %.2f ± %.2f\n", R_mean, R_std)
    @printf("  Ψ (order param):    %.4f ± %.4f\n", Psi_mean, Psi_std)

    if !isempty(dE_values)
        @printf("  ΔE/E₀ (mean):       %.2e\n", mean(dE_values))
        @printf("  ΔE/E₀ (max):        %.2e\n", maximum(dE_values))
    end
    println()

    # Comparison with previous data
    println("COMPARACIÓN CON DATOS PREVIOS:")
    println("-"^70)
    println("  e=0.00:  R = 1.01 ± 0.23,  Ψ = 0.10 ± 0.05  (círculo)")
    println("  e=0.50:  R = 1.18 ± 0.28,  Ψ = 0.11 ± 0.05  (moderado)")
    println("  e=0.70:  R = 1.36 ± 0.38,  Ψ = 0.12 ± 0.04")
    println("  e=0.90:  R = 2.00 ± 0.57,  Ψ = 0.11 ± 0.06")
    @printf("  e=0.95:  R = %.2f ± %.2f,  Ψ = %.4f ± %.4f  ← NUEVO\n", R_mean, R_std, Psi_mean, Psi_std)
    println()

    # Phase transition check
    println("ANÁLISIS DE TRANSICIÓN:")
    println("-"^70)

    # Expected: R ~ 3-4, Psi ~ 0.2-0.3
    if R_mean > 2.5
        println("  ✅ R > 2.5: Clustering FUERTE detectado")
    else
        println("  ⚠️  R < 2.5: Clustering moderado (menor a lo esperado)")
    end

    if Psi_mean > 0.15
        println("  ✅ Ψ > 0.15: Order parameter aumentando")
    else
        println("  ⏸️  Ψ < 0.15: Aún en régimen gas")
    end

    # Compare jump from e=0.9
    R_jump = R_mean - 2.00  # from e=0.90
    @printf("  Incremento R desde e=0.9: %+.2f (%.0f%%)\n", R_jump, (R_jump/2.00)*100)

    println()

    # Statistical spread
    println("DISTRIBUCIÓN ESTADÍSTICA:")
    println("-"^70)
    @printf("  R:   min=%.2f, median=%.2f, max=%.2f\n",
            minimum(R_values), median(R_values), maximum(R_values))
    @printf("  Ψ:   min=%.4f, median=%.4f, max=%.4f\n",
            minimum(Psi_values), median(Psi_values), maximum(Psi_values))

    # Check for bimodality
    if R_std / R_mean > 0.3
        println()
        println("  ⚠️  Alta variabilidad (CV > 0.3): posible régimen intermitente")
    end

    println()
    println("="^70)

    # Predictions for e=0.98, e=0.99
    println()
    println("PREDICCIÓN PARA e > 0.95:")
    println("-"^70)
    if R_mean > 2.5
        println("  e=0.98: R ~ 4-5 esperado (clustering muy fuerte)")
        println("  e=0.99: R ~ 6-8 esperado (cristalización)")
    else
        println("  Tendencia menos pronunciada de lo esperado")
        println("  Revisar si t_max=200s es suficiente para equilibración")
    end
    println("="^70)
else
    println("⚠️  No se encontraron archivos para e=0.95")
end
