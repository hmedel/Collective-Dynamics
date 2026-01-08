#!/usr/bin/env julia
# Análisis de evolución temporal de la distribución angular

using HDF5
using Statistics
using Printf

function analyze_evolution(h5_file::String)
    h5open(h5_file, "r") do file
        traj = file["trajectories"]
        phi = read(traj["phi"])
        t = read(traj["time"])

        config = file["config"]
        a = read(attributes(config)["a"])
        b = read(attributes(config)["b"])
        N = size(phi, 1)

        # Analizar varios snapshots
        n_snapshots = size(phi, 2)  # Segunda dimensión = snapshots
        indices = [1, max(2, n_snapshots ÷ 4), max(3, n_snapshots ÷ 2), max(4, 3n_snapshots ÷ 4), n_snapshots]

        println("="^70)
        @printf("Evolución Temporal (a=%.2f, b=%.2f)\n", a, b)
        println("="^70)
        println()

        for idx in indices
            phi_snap = mod.(phi[:, idx], 2π)
            t_snap = t[idx]

            # Calcular densidad en eje mayor vs menor
            ϵ = 0.3  # tolerancia angular (±17°)

            # Eje mayor: φ ≈ 0, π
            near_major = sum((abs.(phi_snap) .< ϵ) .|
                            (abs.(phi_snap .- π) .< ϵ) .|
                            (abs.(phi_snap .- 2π) .< ϵ))

            # Eje menor: φ ≈ π/2, 3π/2
            near_minor = sum((abs.(phi_snap .- π/2) .< ϵ) .|
                            (abs.(phi_snap .- 3π/2) .< ϵ))

            pct_major = 100 * near_major / N
            pct_minor = 100 * near_minor / N

            @printf("t = %6.2fs: ", t_snap)
            @printf("Eje MAYOR: %5.1f%%  ", pct_major)
            @printf("Eje MENOR: %5.1f%%  ", pct_minor)

            if pct_major > pct_minor
                ratio = pct_major / pct_minor
                @printf("→ Mayor gana (%.1fx)", ratio)
            else
                ratio = pct_minor / pct_major
                @printf("→ Menor gana (%.1fx)", ratio)
            end
            println()
        end

        println()
        println("="^70)
    end
end

file = "results/campaign_20251114_151101/e0.980_N80_phi0.09_E0.32/seed_2/trajectories.h5"

if isfile(file)
    analyze_evolution(file)
else
    println("File not found: $file")
end
