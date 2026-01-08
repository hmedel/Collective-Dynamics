#!/usr/bin/env julia
# Cálculo cuantitativo de la correlación entre κ(φ) y ρ(φ)

using HDF5
using Statistics
using Printf
using LinearAlgebra

# Funciones geométricas
function radial_ellipse(φ, a, b)
    s, c = sincos(φ)
    return a * b / sqrt(a^2 * s^2 + b^2 * c^2)
end

function geometric_curvature(φ, a, b)
    s, c = sincos(φ)
    S = a^2 * s^2 + b^2 * c^2
    return a * b / S^(3/2)
end

function metric_ellipse_polar(φ, a, b)
    # Para simplificar, usar aproximación en extremos
    r = radial_ellipse(φ, a, b)
    # En extremos: g_φφ ≈ r²
    return r^2
end

function analyze_correlation(h5_file::String)
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
        @printf("CORRELACIÓN CURVATURA-DENSIDAD (e=%.3f)\n", e)
        println("="^70)
        @printf("Geometría: a=%.3f, b=%.3f, N=%d\n", a, b, N)
        println()

        # Crear bins angulares
        n_bins = 36  # 10° cada uno
        bin_edges = range(0, 2π, length=n_bins+1)
        bin_centers = [(bin_edges[i] + bin_edges[i+1])/2 for i in 1:n_bins]

        # Calcular densidad ρ(φ) en cada bin
        density = zeros(n_bins)
        for φ in phi_final
            bin_idx = searchsortedfirst(bin_edges, φ) - 1
            bin_idx = clamp(bin_idx, 1, n_bins)
            density[bin_idx] += 1
        end
        density ./= N  # Normalizar a fracción

        # Calcular κ(φ) y g_φφ(φ) en cada bin
        kappa = [geometric_curvature(φ, a, b) for φ in bin_centers]
        g_metric = [metric_ellipse_polar(φ, a, b) for φ in bin_centers]
        r_values = [radial_ellipse(φ, a, b) for φ in bin_centers]

        # Calcular coeficientes de correlación de Pearson
        function pearson_corr(x, y)
            if std(x) == 0 || std(y) == 0
                return 0.0
            end
            return cor(x, y)
        end

        corr_kappa = pearson_corr(kappa, density)
        corr_metric = pearson_corr(g_metric, density)
        corr_r = pearson_corr(r_values, density)

        # Correlaciones con 1/κ, 1/g, 1/r
        corr_inv_kappa = pearson_corr(1 ./ kappa, density)
        corr_inv_metric = pearson_corr(1 ./ g_metric, density)
        corr_inv_r = pearson_corr(1 ./ r_values, density)

        println("COEFICIENTES DE CORRELACIÓN (Pearson r):")
        println("-"^70)
        @printf("ρ(φ) vs κ(φ):       %+.4f  ", corr_kappa)
        if abs(corr_kappa) > 0.7
            println("← FUERTE correlación positiva ✅")
        elseif abs(corr_kappa) > 0.4
            println("← Moderada correlación")
        else
            println("← Débil correlación")
        end

        @printf("ρ(φ) vs 1/κ(φ):     %+.4f  ", corr_inv_kappa)
        if abs(corr_inv_kappa) > 0.7
            println("← FUERTE anti-correlación")
        elseif abs(corr_inv_kappa) > 0.4
            println("← Moderada anti-correlación")
        else
            println("← Débil anti-correlación")
        end
        println()

        @printf("ρ(φ) vs g_φφ(φ):    %+.4f  ", corr_metric)
        if abs(corr_metric) > 0.7
            println("← FUERTE correlación")
        elseif abs(corr_metric) > 0.4
            println("← Moderada correlación")
        else
            println("← Débil correlación")
        end

        @printf("ρ(φ) vs 1/g_φφ(φ):  %+.4f  ", corr_inv_metric)
        if abs(corr_inv_metric) > 0.7
            println("← FUERTE anti-correlación")
        elseif abs(corr_inv_metric) > 0.4
            println("← Moderada anti-correlación")
        else
            println("← Débil anti-correlación")
        end
        println()

        @printf("ρ(φ) vs r(φ):       %+.4f  ", corr_r)
        if abs(corr_r) > 0.7
            println("← FUERTE correlación")
        elseif abs(corr_r) > 0.4
            println("← Moderada correlación")
        else
            println("← Débil correlación")
        end

        @printf("ρ(φ) vs 1/r(φ):     %+.4f  ", corr_inv_r)
        if abs(corr_inv_r) > 0.7
            println("← FUERTE anti-correlación")
        elseif abs(corr_inv_r) > 0.4
            println("← Moderada anti-correlación")
        else
            println("← Débil anti-correlación")
        end
        println()

        # Mostrar algunos valores para verificar
        println("-"^70)
        println("VALORES EN EXTREMOS:")
        println("-"^70)

        # Eje mayor (~0°)
        idx_major_1 = argmin(abs.(bin_centers .- 0.0))
        φ_maj_1 = bin_centers[idx_major_1]
        @printf("\nEje MAYOR (φ ≈ 0°):\n")
        @printf("  φ = %.2f rad (%.0f°)\n", φ_maj_1, rad2deg(φ_maj_1))
        @printf("  ρ = %.4f (%.1f%%)\n", density[idx_major_1], 100*density[idx_major_1])
        @printf("  κ = %.4f (ALTA)\n", kappa[idx_major_1])
        @printf("  r = %.4f (grande)\n", r_values[idx_major_1])
        @printf("  g_φφ = %.4f (grande)\n", g_metric[idx_major_1])

        # Eje mayor (~180°)
        idx_major_2 = argmin(abs.(bin_centers .- π))
        φ_maj_2 = bin_centers[idx_major_2]
        @printf("\nEje MAYOR (φ ≈ 180°):\n")
        @printf("  φ = %.2f rad (%.0f°)\n", φ_maj_2, rad2deg(φ_maj_2))
        @printf("  ρ = %.4f (%.1f%%)\n", density[idx_major_2], 100*density[idx_major_2])
        @printf("  κ = %.4f (ALTA)\n", kappa[idx_major_2])
        @printf("  r = %.4f (grande)\n", r_values[idx_major_2])
        @printf("  g_φφ = %.4f (grande)\n", g_metric[idx_major_2])

        # Eje menor (~90°)
        idx_minor_1 = argmin(abs.(bin_centers .- π/2))
        φ_min_1 = bin_centers[idx_minor_1]
        @printf("\nEje MENOR (φ ≈ 90°):\n")
        @printf("  φ = %.2f rad (%.0f°)\n", φ_min_1, rad2deg(φ_min_1))
        @printf("  ρ = %.4f (%.1f%%)\n", density[idx_minor_1], 100*density[idx_minor_1])
        @printf("  κ = %.4f (baja)\n", kappa[idx_minor_1])
        @printf("  r = %.4f (pequeño)\n", r_values[idx_minor_1])
        @printf("  g_φφ = %.4f (pequeño)\n", g_metric[idx_minor_1])

        # Eje menor (~270°)
        idx_minor_2 = argmin(abs.(bin_centers .- 3π/2))
        φ_min_2 = bin_centers[idx_minor_2]
        @printf("\nEje MENOR (φ ≈ 270°):\n")
        @printf("  φ = %.2f rad (%.0f°)\n", φ_min_2, rad2deg(φ_min_2))
        @printf("  ρ = %.4f (%.1f%%)\n", density[idx_minor_2], 100*density[idx_minor_2])
        @printf("  κ = %.4f (baja)\n", kappa[idx_minor_2])
        @printf("  r = %.4f (pequeño)\n", r_values[idx_minor_2])
        @printf("  g_φφ = %.4f (pequeño)\n", g_metric[idx_minor_2])

        println()
        println("="^70)
        println("CONCLUSIÓN:")
        println("="^70)

        if corr_kappa > 0.7
            println("✅ FUERTE correlación positiva ρ ∝ κ")
            println("   → Alta densidad donde curvatura es ALTA")
            println("   → Confirma mecanismo: alta κ → frenado → clustering")
        elseif corr_inv_kappa > 0.7
            println("✅ FUERTE correlación ρ ∝ 1/κ")
            println("   → Alta densidad donde curvatura es BAJA")
            println("   → Mecanismo alternativo")
        else
            println("⚠️  Correlación compleja - múltiples efectos")
        end

        println()
        println("="^70)

        return (
            corr_kappa = corr_kappa,
            corr_metric = corr_metric,
            corr_r = corr_r,
            density = density,
            kappa = kappa,
            bin_centers = bin_centers
        )
    end
end

# Analizar archivo
file = "results/campaign_20251114_151101/e0.980_N80_phi0.09_E0.32/seed_2/trajectories.h5"

if isfile(file)
    result = analyze_correlation(file)
else
    println("File not found: $file")
end
