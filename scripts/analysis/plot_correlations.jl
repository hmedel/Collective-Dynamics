#!/usr/bin/env julia
# Generar plots de correlaciones κ-ρ, r-ρ, g-ρ

using HDF5
using Statistics
using Printf
using Plots

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
    r = radial_ellipse(φ, a, b)
    return r^2  # Aproximación en extremos
end

function analyze_and_plot(h5_file::String, output_dir::String)
    mkpath(output_dir)

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

        println("Generando plots para e=$(round(e, digits=3)), N=$N")

        # Crear bins angulares
        n_bins = 36
        bin_edges = range(0, 2π, length=n_bins+1)
        bin_centers = [(bin_edges[i] + bin_edges[i+1])/2 for i in 1:n_bins]

        # Calcular densidad
        density = zeros(n_bins)
        for φ in phi_final
            bin_idx = searchsortedfirst(bin_edges, φ) - 1
            bin_idx = clamp(bin_idx, 1, n_bins)
            density[bin_idx] += 1
        end
        density ./= N

        # Calcular variables geométricas
        kappa = [geometric_curvature(φ, a, b) for φ in bin_centers]
        g_metric = [metric_ellipse_polar(φ, a, b) for φ in bin_centers]
        r_values = [radial_ellipse(φ, a, b) for φ in bin_centers]

        # Correlaciones
        corr_kappa = cor(kappa, density)
        corr_metric = cor(g_metric, density)
        corr_r = cor(r_values, density)

        # Plot 1: Densidad vs Ángulo
        p1 = plot(rad2deg.(bin_centers), density * 100,
            xlabel = "Ángulo φ (grados)",
            ylabel = "Densidad (%)",
            title = "Distribución Angular (e=$(round(e, digits=2)))",
            label = "Datos",
            lw = 2,
            marker = :circle,
            markersize = 4,
            legend = :topright,
            size = (800, 500),
            dpi = 300
        )

        # Marcar ejes
        vline!([0, 180], label="Eje MAYOR", ls=:dash, lw=2, color=:red, alpha=0.5)
        vline!([90, 270], label="Eje menor", ls=:dot, lw=2, color=:blue, alpha=0.5)

        savefig(p1, joinpath(output_dir, "density_vs_angle.png"))
        println("  Guardado: density_vs_angle.png")

        # Plot 2: Densidad vs Curvatura
        p2 = scatter(kappa, density * 100,
            xlabel = "Curvatura κ(φ)",
            ylabel = "Densidad (%)",
            title = "Correlación Densidad-Curvatura\n(r=$(round(corr_kappa, digits=3)))",
            label = "Datos (bins de 10°)",
            marker = :circle,
            markersize = 6,
            alpha = 0.7,
            size = (800, 600),
            dpi = 300,
            legend = :topleft
        )

        # Línea de regresión
        A = [ones(length(kappa)) kappa]
        coeffs = A \ (density * 100)
        kappa_range = range(minimum(kappa), maximum(kappa), length=100)
        plot!(p2, kappa_range, coeffs[1] .+ coeffs[2] .* kappa_range,
            label = "Regresión lineal",
            lw = 2,
            ls = :dash,
            color = :red
        )

        savefig(p2, joinpath(output_dir, "density_vs_curvature.png"))
        println("  Guardado: density_vs_curvature.png")

        # Plot 3: Densidad vs Radio
        p3 = scatter(r_values, density * 100,
            xlabel = "Radio r(φ)",
            ylabel = "Densidad (%)",
            title = "Correlación Densidad-Radio\n(r=$(round(corr_r, digits=3)))",
            label = "Datos",
            marker = :circle,
            markersize = 6,
            alpha = 0.7,
            size = (800, 600),
            dpi = 300,
            legend = :topleft
        )

        # Línea de regresión
        A = [ones(length(r_values)) r_values]
        coeffs = A \ (density * 100)
        r_range = range(minimum(r_values), maximum(r_values), length=100)
        plot!(p3, r_range, coeffs[1] .+ coeffs[2] .* r_range,
            label = "Regresión lineal",
            lw = 2,
            ls = :dash,
            color = :red
        )

        savefig(p3, joinpath(output_dir, "density_vs_radius.png"))
        println("  Guardado: density_vs_radius.png")

        # Plot 4: Panel combinado
        p_combined = plot(
            plot(rad2deg.(bin_centers), density * 100,
                xlabel = "Ángulo (°)", ylabel = "Densidad (%)",
                title = "(a) Distribución Angular",
                label = "", lw = 2, marker = :circle, markersize = 3,
                titlefontsize = 10
            ),

            scatter(kappa, density * 100,
                xlabel = "Curvatura κ", ylabel = "Densidad (%)",
                title = "(b) ρ vs κ (r=$(round(corr_kappa, digits=2)))",
                label = "", marker = :circle, markersize = 4, alpha = 0.7,
                titlefontsize = 10
            ),

            scatter(r_values, density * 100,
                xlabel = "Radio r", ylabel = "Densidad (%)",
                title = "(c) ρ vs r (r=$(round(corr_r, digits=2)))",
                label = "", marker = :circle, markersize = 4, alpha = 0.7,
                titlefontsize = 10
            ),

            scatter(g_metric, density * 100,
                xlabel = "Métrica g_φφ", ylabel = "Densidad (%)",
                title = "(d) ρ vs g_φφ (r=$(round(corr_metric, digits=2)))",
                label = "", marker = :circle, markersize = 4, alpha = 0.7,
                titlefontsize = 10
            ),

            layout = (2, 2),
            size = (1200, 1000),
            dpi = 300,
            plot_title = "Clustering Geométrico (e=$(round(e, digits=2)), N=$N)",
            plot_titlefontsize = 14
        )

        savefig(p_combined, joinpath(output_dir, "combined_correlations.png"))
        println("  Guardado: combined_correlations.png")

        # Plot 5: Curvatura y Densidad vs Ángulo (dos ejes Y)
        p5 = plot(rad2deg.(bin_centers), kappa,
            xlabel = "Ángulo φ (grados)",
            ylabel = "Curvatura κ(φ)",
            title = "Curvatura y Densidad vs Ángulo",
            label = "κ(φ)",
            lw = 2,
            color = :blue,
            legend = :topright,
            size = (1000, 600),
            dpi = 300
        )

        # Segundo eje Y para densidad
        plot!(twinx(p5), rad2deg.(bin_centers), density * 100,
            ylabel = "Densidad ρ(φ) (%)",
            label = "ρ(φ)",
            lw = 2,
            color = :red,
            marker = :circle,
            markersize = 3,
            legend = :topright,
            ylims = (0, maximum(density)*100*1.1)
        )

        vline!(p5, [0, 180], label="Eje MAYOR", ls=:dash, lw=1, color=:gray, alpha=0.5)

        savefig(p5, joinpath(output_dir, "curvature_and_density_vs_angle.png"))
        println("  Guardado: curvature_and_density_vs_angle.png")

        println("\n✅ Todos los plots generados en: $output_dir")
        println()
        println("Correlaciones:")
        println("  ρ vs κ:    r = $(round(corr_kappa, digits=3))")
        println("  ρ vs r:    r = $(round(corr_r, digits=3))")
        println("  ρ vs g_φφ: r = $(round(corr_metric, digits=3))")
    end
end

# Generar plots
file = "results/campaign_20251114_151101/e0.980_N80_phi0.09_E0.32/seed_2/trajectories.h5"
output_dir = "results/correlation_plots"

if isfile(file)
    analyze_and_plot(file, output_dir)
else
    println("File not found: $file")
end
