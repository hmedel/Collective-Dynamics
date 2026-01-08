#!/usr/bin/env julia
# Visualización rápida de la distribución angular

using HDF5
using Statistics
using Printf

function quick_check(h5_file::String)
    h5open(h5_file, "r") do file
        traj = file["trajectories"]
        phi = read(traj["phi"])

        config = file["config"]
        a = read(attributes(config)["a"])
        b = read(attributes(config)["b"])
        e = sqrt(1 - (b/a)^2)
        N = size(phi, 1)

        # Snapshot final
        phi_final = mod.(phi[:, end], 2π)

        println("="^70)
        @printf("a=%.3f, b=%.3f, e=%.3f, N=%d\n", a, b, e, N)
        println("="^70)
        println()

        # Histograma con 18 bins (20° cada uno)
        n_bins = 18
        bin_edges = range(0, 2π, length=n_bins+1)
        bin_centers = [(bin_edges[i] + bin_edges[i+1])/2 for i in 1:n_bins]

        counts = zeros(Int, n_bins)
        for φ in phi_final
            bin_idx = searchsortedfirst(bin_edges, φ) - 1
            bin_idx = clamp(bin_idx, 1, n_bins)
            counts[bin_idx] += 1
        end

        # Mostrar histograma
        println("Distribución Angular (cada 20°):")
        println()
        for (i, (φ, count)) in enumerate(zip(bin_centers, counts))
            deg = rad2deg(φ)
            pct = 100 * count / N
            bar = repeat("█", max(1, Int(round(40 * count / maximum(counts)))))

            # Etiquetar eje mayor vs menor
            label = ""
            if abs(φ) < 0.2 || abs(φ - π) < 0.2 || abs(φ - 2π) < 0.2
                label = " ← EJE MAYOR (+x o -x)"
            elseif abs(φ - π/2) < 0.2 || abs(φ - 3π/2) < 0.2
                label = " ← EJE MENOR (+y o -y)"
            end

            @printf("%3.0f°: %4d (%4.1f%%) %s%s\n", deg, count, pct, bar, label)
        end

        println()
        println("Eje mayor: φ ≈ 0° (360°), 180° → donde r = a = $(round(a, digits=2))")
        println("Eje menor: φ ≈ 90°, 270° → donde r = b = $(round(b, digits=2))")
        println("="^70)
    end
end

# Archivo de alta excentricidad
file = "results/campaign_20251114_151101/e0.980_N80_phi0.09_E0.32/seed_2/trajectories.h5"

if isfile(file)
    quick_check(file)
else
    println("File not found: $file")
end
