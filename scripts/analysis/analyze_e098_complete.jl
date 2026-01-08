#!/usr/bin/env julia
# Complete analysis of e=0.98 (all 20 runs)

using HDF5
using Statistics
using Printf

println("="^70)
println("ANÁLISIS COMPLETO: e=0.98 (20/20 runs)")
println("="^70)
println()

campaign_dir = "results/campaign_eccentricity_scan_20251116_014451"

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

R_values = Float64[]
Psi_values = Float64[]
dE_values = Float64[]

for file in sort(readdir(campaign_dir, join=true))
    !endswith(file, ".h5") && continue
    !occursin("e0.980", file) && continue

    h5open(file, "r") do f
        phi_final = read(f["trajectories"]["phi"])[:, end]

        R = clustering_ratio(phi_final)
        Psi = order_parameter(phi_final)

        push!(R_values, R)
        push!(Psi_values, Psi)

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

if n_runs == 20
    println("✅ DATASET COMPLETO")
else
    println("⚠️  Dataset incompleto ($n_runs/20)")
end
println()

# Statistics
R_mean = mean(R_values)
R_std = std(R_values)
R_min = minimum(R_values)
R_median = median(R_values)
R_max = maximum(R_values)

Psi_mean = mean(Psi_values)
Psi_std = std(Psi_values)

println("RESULTADOS e=0.98:")
println("-"^70)
@printf("  R (clustering):\n")
@printf("    Mean:   %5.2f\n", R_mean)
@printf("    Std:    %5.2f\n", R_std)
@printf("    Median: %5.2f\n", R_median)
@printf("    Range:  [%.2f, %.2f]\n", R_min, R_max)
@printf("    CV:     %5.1f%%\n", 100*R_std/R_mean)
println()

@printf("  Ψ (order parameter):\n")
@printf("    Mean:   %6.4f\n", Psi_mean)
@printf("    Std:    %6.4f\n", Psi_std)
@printf("    Range:  [%.4f, %.4f]\n", minimum(Psi_values), maximum(Psi_values))
println()

if !isempty(dE_values)
    @printf("  ΔE/E₀ (conservación):\n")
    @printf("    Mean:   %.2e\n", mean(dE_values))
    @printf("    Max:    %.2e\n", maximum(dE_values))

    n_excellent = count(dE_values .< 1e-4)
    @printf("    Excellent (< 10⁻⁴): %d/%d (%.0f%%)\n",
            n_excellent, length(dE_values), 100*n_excellent/length(dE_values))
end
println()

# Comparison with previous
println("COMPARACIÓN CON DATOS PREVIOS:")
println("-"^70)
println("  e=0.90:  R = 2.00 ± 0.57,  Ψ = 0.11 ± 0.06")
println("  e=0.95:  R = 2.51 ± 0.62,  Ψ = 0.10 ± 0.05")
@printf("  e=0.98:  R = %.2f ± %.2f,  Ψ = %.4f ± %.4f  ← NUEVO\n", R_mean, R_std, Psi_mean, Psi_std)
println()

# Increments
delta_R_from_095 = R_mean - 2.51
pct_from_095 = (delta_R_from_095 / 2.51) * 100

@printf("Incremento vs e=0.95: ΔR = %+.2f (%+.0f%%)\n", delta_R_from_095, pct_from_095)
println()

# Gradient
de = 0.98 - 0.95
dR_de = delta_R_from_095 / de
@printf("Gradiente: dR/de = %.2f\n", dR_de)
println()

# Phase classification
println("CLASIFICACIÓN DE FASE:")
println("-"^70)

n_strong_clustering = count(R_values .> 3.0)
n_crystallized = count(Psi_values .> 0.3)

@printf("  Clustering fuerte (R > 3):    %2d/%2d (%.0f%%)\n",
        n_strong_clustering, n_runs, 100*n_strong_clustering/n_runs)

@printf("  Cristalización (Ψ > 0.3):     %2d/%2d (%.0f%%)\n",
        n_crystallized, n_runs, 100*n_crystallized/n_runs)

if n_strong_clustering > n_runs/2
    println("\n  🚀 MAYORÍA muestra clustering EXTREMO (R > 3)")
else
    println("\n  ⏸️  Clustering fuerte pero no extremo")
end

if n_crystallized > 0
    println("  ✨ Cristalización parcial detectada!")
else
    println("  ⏸️  Aún en fase 'gas denso' (sin orden orientacional)")
end

println()
println("="^70)
println()

# Distribution details
println("DISTRIBUCIÓN DE R:")
println("-"^70)

# Simple histogram
bins = [0.0, 2.0, 3.0, 4.0, 5.0, 10.0]
for i in 1:length(bins)-1
    n_in_bin = count(bins[i] .<= R_values .< bins[i+1])
    @printf("  %.1f ≤ R < %.1f:  %2d runs\n", bins[i], bins[i+1], n_in_bin)
end

println()
println("="^70)
println()

# Comparison with pilot
println("COMPARACIÓN CON PILOTO ORIGINAL:")
println("-"^70)
println("  Piloto (2025-11-16, n=1, t_max=50s):   R = 5.05 ± 2.00")
@printf("  Campaña (actual, n=20, t_max=200s):    R = %.2f ± %.2f\n", R_mean, R_std)
println()

if abs(R_mean - 5.05) < 2.0
    println("  ✅ Resultados consistentes (dentro de incertidumbre)")
else
    delta = R_mean - 5.05
    println("  ⚠️  Diferencia notable: ΔR = $(@sprintf("%.2f", delta))")
    if R_mean < 5.05
        println("     Posible causa: mayor equilibración en t_max=200s")
    end
end

println()
println("="^70)
