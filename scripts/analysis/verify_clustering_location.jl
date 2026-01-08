#!/usr/bin/env julia
# Verificación: ¿Dónde ocurre el clustering? ¿Eje mayor o eje menor?

using HDF5
using Statistics
using Printf

"""
Carga datos de un archivo HDF5 y analiza distribución angular final
"""
function analyze_clustering_location(h5_file::String)
    # Leer datos
    h5open(h5_file, "r") do file
        traj = file["trajectories"]
        phi = read(traj["phi"])  # (N_particles, N_snapshots)
        t = read(traj["time"])

        # Leer parámetros de geometría
        config = file["config"]
        a = read(attributes(config)["a"])
        b = read(attributes(config)["b"])
        N = size(phi, 1)

        # Analizar snapshot final (después de clustering)
        phi_final = phi[:, end]

        # Normalizar ángulos a [0, 2π)
        phi_final = mod.(phi_final, 2π)

        # Geometría de referencia
        phi_minor_axis = [π/2, 3π/2]  # Eje menor
        phi_major_axis = [0.0, π]     # Eje mayor

        # Calcular densidad en bins angulares
        n_bins = 36  # bins de 10 grados
        bin_edges = range(0, 2π, length=n_bins+1)
        bin_centers = [(bin_edges[i] + bin_edges[i+1])/2 for i in 1:n_bins]

        counts = zeros(Int, n_bins)
        for φ in phi_final
            bin_idx = searchsortedfirst(bin_edges, φ) - 1
            bin_idx = clamp(bin_idx, 1, n_bins)
            counts[bin_idx] += 1
        end

        # Encontrar máximo de densidad
        max_count = maximum(counts)
        max_bin_idx = argmax(counts)
        phi_max_density = bin_centers[max_bin_idx]

        # Distancia angular al eje más cercano
        function angular_distance(φ1, φ2)
            d = abs(φ1 - φ2)
            return min(d, 2π - d)
        end

        # ¿Más cerca del eje menor o mayor?
        dist_to_minor = minimum([angular_distance(phi_max_density, pm) for pm in phi_minor_axis])
        dist_to_major = minimum([angular_distance(phi_max_density, pm) for pm in phi_major_axis])

        cluster_location = dist_to_minor < dist_to_major ? "MINOR_AXIS" : "MAJOR_AXIS"

        # Calcular r, g_φφ, κ en el pico de densidad
        r_at_peak = radial_ellipse(phi_max_density, a, b)
        g_at_peak = metric_ellipse_polar(phi_max_density, a, b)
        kappa_at_peak = geometric_curvature(phi_max_density, a, b)

        return (
            a = a,
            b = b,
            N = N,
            t_final = t[end],
            phi_max_density = phi_max_density,
            max_density_fraction = max_count / N,
            cluster_location = cluster_location,
            dist_to_minor = dist_to_minor,
            dist_to_major = dist_to_major,
            r_at_peak = r_at_peak,
            g_at_peak = g_at_peak,
            kappa_at_peak = kappa_at_peak,
            bin_centers = bin_centers,
            counts = counts
        )
    end
end

# Funciones geométricas
function radial_ellipse(φ, a, b)
    s, c = sincos(φ)
    return a * b / sqrt(a^2 * s^2 + b^2 * c^2)
end

function radial_derivative_ellipse(φ, a, b)
    s, c = sincos(φ)
    S = a^2 * s^2 + b^2 * c^2
    sin2φ = sin(2φ)
    return -a * b * (a^2 - b^2) * sin2φ / (2 * S^(3/2))
end

function metric_ellipse_polar(φ, a, b)
    r = radial_ellipse(φ, a, b)
    dr_dφ = radial_derivative_ellipse(φ, a, b)
    return dr_dφ^2 + r^2
end

function geometric_curvature(φ, a, b)
    s, c = sincos(φ)
    S = a^2 * s^2 + b^2 * c^2
    return a * b / S^(3/2)
end

# ANÁLISIS PRINCIPAL
println("="^70)
println("VERIFICACIÓN: ¿Dónde Ocurre el Clustering?")
println("="^70)
println()

# Analizar varios archivos de diferentes excentricidades
test_files = [
    ("Circle (e=0.0)", "results/debug_N80/e0.000_N80_phi0.04_E0.32/seed_999/trajectories.h5"),
    ("Moderate (e≈0.98)", "results/campaign_20251114_151101/e0.980_N80_phi0.09_E0.32/seed_2/trajectories.h5"),
]

for (label, file) in test_files
    if !isfile(file)
        println("⚠️  File not found: $file")
        continue
    end

    println("Analyzing: $label")
    println("File: $file")

    result = analyze_clustering_location(file)

    @printf("  Geometry: a=%.3f, b=%.3f (e=%.3f)\n", result.a, result.b, sqrt(1 - (result.b/result.a)^2))
    @printf("  N=%d particles, t_final=%.1fs\n", result.N, result.t_final)
    println()

    @printf("  Peak density at φ = %.3f rad (%.1f°)\n", result.phi_max_density, rad2deg(result.phi_max_density))
    @printf("  Fraction of particles: %.1f%%\n", result.max_density_fraction * 100)
    println()

    @printf("  Distance to MINOR axis: %.3f rad (%.1f°)\n", result.dist_to_minor, rad2deg(result.dist_to_minor))
    @printf("  Distance to MAJOR axis: %.3f rad (%.1f°)\n", result.dist_to_major, rad2deg(result.dist_to_major))
    println()

    @printf("  ✅ Cluster location: %s\n", result.cluster_location)
    println()

    @printf("  At peak density:\n")
    @printf("    r(φ) = %.4f\n", result.r_at_peak)
    @printf("    g_φφ = %.4f\n", result.g_at_peak)
    @printf("    κ = %.4f\n", result.kappa_at_peak)
    println()

    # Distribución completa
    println("  Angular distribution (bins of 10°):")
    for (i, (φ, count)) in enumerate(zip(result.bin_centers, result.counts))
        if count > 0
            bar = repeat("█", Int(round(20 * count / result.N)))
            @printf("    φ=%.2f (%.0f°): %3d particles %s\n", φ, rad2deg(φ), count, bar)
        end
    end

    println()
    println("-"^70)
    println()
end

println("="^70)
println("CONCLUSIÓN:")
println("="^70)
println()
println("Si el clustering ocurre en MINOR_AXIS:")
println("  ✅ Teoría CORRECTA: r pequeño → g_φφ pequeño → v lenta → clustering")
println()
println("Si el clustering ocurre en MAJOR_AXIS:")
println("  ❌ Teoría INCORRECTA: necesitamos revisar el mecanismo")
println()
println("="^70)
