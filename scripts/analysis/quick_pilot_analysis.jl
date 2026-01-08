#!/usr/bin/env julia
# Quick analysis of pilot results

using HDF5
using Statistics
using Printf

campaign_dir = "results/campaign_eccentricity_scan_20251116_002247"

println("="^70)
println("ANÁLISIS RÁPIDO DEL PILOTO")
println("="^70)
println()

# Function to compute clustering ratio
function clustering_ratio(phi_positions, bin_width=π/4)
    # Major axis: φ ≈ 0, 2π (and π for other side)
    # Minor axis: φ ≈ π/2, 3π/2
    n_mayor = count(φ -> (φ < bin_width || φ > 2π - bin_width ||
                          abs(φ - π) < bin_width), phi_positions)
    n_menor = count(φ -> abs(φ - π/2) < bin_width ||
                          abs(φ - 3π/2) < bin_width, phi_positions)
    return n_mayor / max(n_menor, 1)
end

# Function to compute order parameter
function order_parameter(phi_positions)
    mean_cos = mean(cos.(phi_positions))
    mean_sin = mean(sin.(phi_positions))
    return sqrt(mean_cos^2 + mean_sin^2)
end

# Analyze all files
results = []

for file in sort(readdir(campaign_dir, join=true))
    !endswith(file, ".h5") && continue

    filename = basename(file)

    h5open(file, "r") do f
        # Extract metadata
        e = read(attributes(f["metadata"]), "eccentricity")
        seed = read(attributes(f["metadata"]), "seed")

        # Read final state
        traj = read(f["trajectories"])
        phi_final = traj[:, end, 1]  # Final angular positions

        # Compute metrics
        R_cluster = clustering_ratio(phi_final)
        Psi = order_parameter(phi_final)

        push!(results, (e=e, seed=seed, R=R_cluster, Psi=Psi, file=filename))
    end
end

# Print results by eccentricity
println("Resultados por Eccentricity:")
println("-"^70)
@printf("%-6s | %-6s | %-12s | %-12s | %-20s\n", "e", "seed", "R (cluster)", "Ψ (order)", "Archivo")
println("-"^70)

for r in results
    @printf("%.2f | %6d | %12.2f | %12.4f | %s\n",
            r.e, r.seed, r.R, r.Psi, r.file)
end

println("="^70)
println()

# Summary by eccentricity
println("RESUMEN POR ECCENTRICITY:")
println("-"^70)

for e_val in unique([r.e for r in results])
    subset = filter(r -> r.e == e_val, results)
    R_mean = mean([r.R for r in subset])
    R_std = std([r.R for r in subset])
    Psi_mean = mean([r.Psi for r in subset])
    Psi_std = std([r.Psi for r in subset])

    @printf("e = %.2f:  R = %.2f ± %.2f,  Ψ = %.4f ± %.4f\n",
            e_val, R_mean, R_std, Psi_mean, Psi_std)
end

println("="^70)
println()

# Interpretation
println("INTERPRETACIÓN:")
println()
println("Hipótesis esperadas:")
println("  - e=0.0  (círculo) → R ≈ 1 (sin clustering)")
println("  - e=0.5  (moderado) → R ~ 2-5 (clustering moderado)")
println("  - e=0.98 (extremo) → R > 5 (clustering fuerte)")
println()

# Check control negative
e0_results = filter(r -> r.e == 0.0, results)
R_circle = mean([r.R for r in e0_results])
if R_circle < 1.5
    println("✅ Control negativo PASSED: Círculo no muestra clustering (R = $(round(R_circle, digits=2)))")
else
    println("⚠️  Control negativo WARNING: Círculo muestra clustering inesperado (R = $(round(R_circle, digits=2)))")
end

# Check clustering trend
e_vals = sort(unique([r.e for r in results]))
R_means = [mean([r.R for r in filter(rr -> rr.e == e, results)]) for e in e_vals]

if all(diff(R_means) .> 0)
    println("✅ Tendencia CONFIRMED: R aumenta con e")
    println("   R(e=0.0) = $(round(R_means[1], digits=2))")
    println("   R(e=0.5) = $(round(R_means[2], digits=2))")
    println("   R(e=0.98) = $(round(R_means[3], digits=2))")
else
    println("⚠️  Tendencia NO monotónica - revisar")
end

println()
println("="^70)
