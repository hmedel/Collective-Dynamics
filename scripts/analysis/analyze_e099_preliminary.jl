#!/usr/bin/env julia
# Preliminary analysis of e=0.99 (partial data)

using HDF5
using Statistics
using Printf

println("="^70)
println("ANÁLISIS PRELIMINAR: e=0.99 (PARCIAL)")
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
    !occursin("e0.990", file) && continue

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
println("⚠️  ADVERTENCIA: Muestra parcial ($n_runs/20)")
println("   Resultados tentativos - no usar para conclusiones finales")
println()

if n_runs == 0
    println("❌ No hay datos disponibles aún para e=0.99")
    exit(0)
end

R_mean = mean(R_values)
R_std = n_runs > 1 ? std(R_values) : 0.0
Psi_mean = mean(Psi_values)
Psi_std = n_runs > 1 ? std(Psi_values) : 0.0

println("RESULTADOS PRELIMINARES e=0.99:")
println("-"^70)
@printf("  R (clustering):     %.2f ± %.2f  (n=%d)\n", R_mean, R_std, n_runs)
@printf("  Ψ (order param):    %.4f ± %.4f\n", Psi_mean, Psi_std)

if !isempty(dE_values)
    @printf("  ΔE/E₀:              %.2e (mean), %.2e (max)\n",
            mean(dE_values), maximum(dE_values))
end
println()

# Individual values
println("Valores individuales:")
for (i, (R, Psi)) in enumerate(zip(R_values, Psi_values))
    marker = Psi > 0.3 ? "  ← CRISTAL!" : ""
    @printf("  Run %d: R = %.2f, Ψ = %.4f%s\n", i, R, Psi, marker)
end
println()

# Comparison
println("COMPARACIÓN CON DATOS PREVIOS:")
println("-"^70)
println("  e=0.90:  R = 2.00 ± 0.57,  Ψ = 0.11 ± 0.06")
println("  e=0.95:  R = 2.51 ± 0.62,  Ψ = 0.10 ± 0.05")
println("  e=0.98:  R = 4.32 ± 1.18,  Ψ = 0.09 ± 0.07")
@printf("  e=0.99:  R = %.2f ± %.2f,  Ψ = %.4f ± %.4f  ← PRELIMINAR (n=%d)\n",
        R_mean, R_std, Psi_mean, Psi_std, n_runs)
println()

# Assessment
if n_runs >= 5
    delta_R = R_mean - 4.32
    @printf("Incremento vs e=0.98: ΔR = %+.2f (%+.0f%%)\n",
            delta_R, 100*delta_R/4.32)

    de = 0.99 - 0.98
    dR_de = delta_R / de
    @printf("Gradiente: dR/de ≈ %.1f\n", dR_de)
    println()
end

println("CLASIFICACIÓN TENTATIVA:")
println("-"^70)

n_extreme = count(R_values .> 5.0)
n_crystallized = count(Psi_values .> 0.3)

@printf("  Clustering extremo (R > 5):   %d/%d\n", n_extreme, n_runs)
@printf("  Cristalización (Ψ > 0.3):     %d/%d\n", n_crystallized, n_runs)
println()

if R_mean > 5.0
    println("  🚀 TENDENCIA: Clustering EXTREMO (R > 5)")
end

if n_crystallized > 0
    println("  ✨ CRISTALIZACIÓN DETECTADA!")
    println("     Orden orientacional emergente en algunos runs")
elseif Psi_mean > 0.15
    println("  📈 Ψ aumentando - posible pre-cristalización")
else
    println("  ⏸️  Aún en fase 'gas denso' (sin orden orientacional)")
end

println()
println("="^70)
println()
println("⏳ Esperar n=20 para estadística robusta")
println("="^70)
