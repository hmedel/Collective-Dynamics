#!/usr/bin/env julia
#
# plot_clustering_preliminary.jl
#
# Genera plots preliminares de las métricas de clustering
# para visualización rápida de los resultados de la campaña
#

using CSV
using DataFrames
using Plots
using Statistics
using Printf
using HDF5

# Set plotting backend
gr()

"""
    plot_R_vs_e_all_N(grouped_df, output_dir)

Plot R_∞ vs e para todos los valores de N (finite-size scaling).
"""
function plot_R_vs_e_all_N(grouped_df, output_dir)
    println("Generando plot: R_∞ vs e (finite-size scaling)...")

    N_values = sort(unique(grouped_df.N))
    e_values = sort(unique(grouped_df.e))

    p = plot(
        xlabel = "Eccentricity e",
        ylabel = "Cluster Radius R_∞",
        title = "Finite-Size Scaling: R_∞(e, N)",
        legend = :best,
        size = (800, 600),
        dpi = 150,
        grid = true,
        minorgrid = true,
        framestyle = :box
    )

    colors = [:blue, :red, :green, :purple]
    markers = [:circle, :square, :diamond, :utriangle]

    for (i, N) in enumerate(N_values)
        subset = filter(row -> row.N == N, grouped_df)
        sort!(subset, :e)

        # Usar SEM (error entre seeds) como barra de error
        plot!(p, subset.e, subset.R_inf_mean,
              yerror = subset.R_inf_sem,
              label = "N = $N",
              marker = markers[i],
              markersize = 6,
              color = colors[i],
              linewidth = 2,
              markerstrokewidth = 1
        )
    end

    savefig(p, joinpath(output_dir, "R_inf_vs_e_all_N.png"))
    println("  ✅ Saved: R_inf_vs_e_all_N.png")

    return p
end

"""
    plot_Psi_vs_e_all_N(grouped_df, output_dir)

Plot Ψ_∞ vs e para todos los valores de N.
"""
function plot_Psi_vs_e_all_N(grouped_df, output_dir)
    println("Generando plot: Ψ_∞ vs e...")

    N_values = sort(unique(grouped_df.N))

    p = plot(
        xlabel = "Eccentricity e",
        ylabel = "Order Parameter Ψ_∞",
        title = "Kuramoto Order Parameter: Ψ_∞(e, N)",
        legend = :best,
        size = (800, 600),
        dpi = 150,
        grid = true,
        minorgrid = true,
        framestyle = :box
    )

    colors = [:blue, :red, :green, :purple]
    markers = [:circle, :square, :diamond, :utriangle]

    for (i, N) in enumerate(N_values)
        subset = filter(row -> row.N == N, grouped_df)
        sort!(subset, :e)

        plot!(p, subset.e, subset.Psi_inf_mean,
              yerror = subset.Psi_inf_sem,
              label = "N = $N",
              marker = markers[i],
              markersize = 6,
              color = colors[i],
              linewidth = 2,
              markerstrokewidth = 1
        )
    end

    savefig(p, joinpath(output_dir, "Psi_inf_vs_e_all_N.png"))
    println("  ✅ Saved: Psi_inf_vs_e_all_N.png")

    return p
end

"""
    plot_heatmap_R(grouped_df, output_dir)

Heatmap de R_∞ en el espacio (N, e).
"""
function plot_heatmap_R(grouped_df, output_dir)
    println("Generando heatmap: R_∞(N, e)...")

    N_values = sort(unique(grouped_df.N))
    e_values = sort(unique(grouped_df.e))

    # Crear matriz para heatmap
    R_matrix = zeros(length(N_values), length(e_values))

    for (i, N) in enumerate(N_values)
        for (j, e) in enumerate(e_values)
            subset = filter(row -> row.N == N && row.e == e, grouped_df)
            if nrow(subset) > 0
                R_matrix[i, j] = subset[1, :R_inf_mean]
            else
                R_matrix[i, j] = NaN
            end
        end
    end

    p = heatmap(
        e_values,
        N_values,
        R_matrix,
        xlabel = "Eccentricity e",
        ylabel = "Number of Particles N",
        title = "Cluster Radius R_∞(N, e)",
        colorbar_title = "R_∞",
        size = (700, 600),
        dpi = 150,
        c = :viridis,
        aspect_ratio = :auto
    )

    # Añadir valores numéricos
    for (i, N) in enumerate(N_values)
        for (j, e) in enumerate(e_values)
            if !isnan(R_matrix[i, j])
                annotate!(p, e, N, text(@sprintf("%.2f", R_matrix[i, j]), 8, :white))
            end
        end
    end

    savefig(p, joinpath(output_dir, "heatmap_R_inf.png"))
    println("  ✅ Saved: heatmap_R_inf.png")

    return p
end

"""
    plot_heatmap_Psi(grouped_df, output_dir)

Heatmap de Ψ_∞ en el espacio (N, e).
"""
function plot_heatmap_Psi(grouped_df, output_dir)
    println("Generando heatmap: Ψ_∞(N, e)...")

    N_values = sort(unique(grouped_df.N))
    e_values = sort(unique(grouped_df.e))

    # Crear matriz para heatmap
    Psi_matrix = zeros(length(N_values), length(e_values))

    for (i, N) in enumerate(N_values)
        for (j, e) in enumerate(e_values)
            subset = filter(row -> row.N == N && row.e == e, grouped_df)
            if nrow(subset) > 0
                Psi_matrix[i, j] = subset[1, :Psi_inf_mean]
            else
                Psi_matrix[i, j] = NaN
            end
        end
    end

    p = heatmap(
        e_values,
        N_values,
        Psi_matrix,
        xlabel = "Eccentricity e",
        ylabel = "Number of Particles N",
        title = "Order Parameter Ψ_∞(N, e)",
        colorbar_title = "Ψ_∞",
        size = (700, 600),
        dpi = 150,
        c = :plasma,
        aspect_ratio = :auto
    )

    # Añadir valores numéricos
    for (i, N) in enumerate(N_values)
        for (j, e) in enumerate(e_values)
            if !isnan(Psi_matrix[i, j])
                annotate!(p, e, N, text(@sprintf("%.2f", Psi_matrix[i, j]), 8, :white))
            end
        end
    end

    savefig(p, joinpath(output_dir, "heatmap_Psi_inf.png"))
    println("  ✅ Saved: heatmap_Psi_inf.png")

    return p
end

"""
    plot_sample_timeseries(campaign_dir, output_dir)

Plot series temporales de ejemplo para casos representativos.
"""
function plot_sample_timeseries(campaign_dir, output_dir)
    println("Generando plots de series temporales de ejemplo...")

    # Casos de ejemplo: bajo, medio, alto clustering
    examples = [
        (N=40, e=0.5, seed=1, label="High clustering (N=40, e=0.5)"),
        (N=80, e=0.0, seed=1, label="Medium clustering (N=80, e=0.0)"),
        (N=60, e=0.9, seed=1, label="Low clustering (N=60, e=0.9)")
    ]

    for ex in examples
        run_name = @sprintf("e%.1f_N%03d_seed%02d", ex.e, ex.N, ex.seed)
        h5_file = joinpath(campaign_dir, run_name, "trajectories.h5")

        if !isfile(h5_file)
            @warn "File not found: $h5_file"
            continue
        end

        # Leer datos
        h5open(h5_file, "r") do file
            times = read(file["trajectories/time"])
            phi = read(file["trajectories/phi"])

            n_snapshots, N = size(phi)

            # Calcular R(t) y Psi(t)
            R_t = zeros(n_snapshots)
            Psi_t = zeros(n_snapshots)

            for i in 1:n_snapshots
                phi_snapshot = phi[i, :]

                # R(t)
                x = cos.(phi_snapshot)
                y = sin.(phi_snapshot)
                x_cm = mean(x)
                y_cm = mean(y)
                R_t[i] = sqrt(mean((x .- x_cm).^2 + (y .- y_cm).^2))

                # Psi(t)
                z = mean(exp.(im .* phi_snapshot))
                Psi_t[i] = abs(z)
            end

            # Plot R(t)
            p1 = plot(
                times, R_t,
                xlabel = "Time t",
                ylabel = "Cluster Radius R(t)",
                title = ex.label,
                legend = false,
                size = (800, 400),
                dpi = 150,
                linewidth = 2,
                color = :blue,
                grid = true,
                framestyle = :box
            )

            filename = @sprintf("timeseries_R_N%d_e%.1f.png", ex.N, ex.e)
            savefig(p1, joinpath(output_dir, filename))
            println("  ✅ Saved: $filename")

            # Plot Psi(t)
            p2 = plot(
                times, Psi_t,
                xlabel = "Time t",
                ylabel = "Order Parameter Ψ(t)",
                title = ex.label,
                legend = false,
                size = (800, 400),
                dpi = 150,
                linewidth = 2,
                color = :red,
                grid = true,
                framestyle = :box
            )

            filename = @sprintf("timeseries_Psi_N%d_e%.1f.png", ex.N, ex.e)
            savefig(p2, joinpath(output_dir, filename))
            println("  ✅ Saved: $filename")
        end
    end
end

"""
    generate_all_plots(campaign_dir)

Genera todos los plots preliminares.
"""
function generate_all_plots(campaign_dir::String)
    println("="^80)
    println("GENERACIÓN DE PLOTS PRELIMINARES")
    println("="^80)
    println("Campaign: ", campaign_dir)
    println()

    # Leer datos agrupados
    grouped_file = joinpath(campaign_dir, "clustering_analysis", "campaign_clustering_grouped.csv")

    if !isfile(grouped_file)
        println("❌ Error: Grouped data not found. Run extract_clustering_metrics.jl first.")
        return
    end

    grouped_df = CSV.read(grouped_file, DataFrame)

    # Crear directorio de plots
    plots_dir = joinpath(campaign_dir, "clustering_analysis", "plots")
    mkpath(plots_dir)

    # Generar plots
    plot_R_vs_e_all_N(grouped_df, plots_dir)
    plot_Psi_vs_e_all_N(grouped_df, plots_dir)
    plot_heatmap_R(grouped_df, plots_dir)
    plot_heatmap_Psi(grouped_df, plots_dir)
    plot_sample_timeseries(campaign_dir, plots_dir)

    println()
    println("="^80)
    println("✅ PLOTS GENERADOS")
    println("="^80)
    println("Directorio: $plots_dir")
    println()
    println("Plots generados:")
    println("  1. R_inf_vs_e_all_N.png      - Finite-size scaling")
    println("  2. Psi_inf_vs_e_all_N.png    - Order parameter scaling")
    println("  3. heatmap_R_inf.png         - R_∞ heatmap (N, e)")
    println("  4. heatmap_Psi_inf.png       - Ψ_∞ heatmap (N, e)")
    println("  5. timeseries_*.png          - Example time series")
    println()
end

# Main execution
if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) < 1
        println("Usage: julia plot_clustering_preliminary.jl <campaign_dir>")
        exit(1)
    end

    campaign_dir = ARGS[1]

    if !isdir(campaign_dir)
        println("❌ Error: Campaign directory not found: $campaign_dir")
        exit(1)
    end

    generate_all_plots(campaign_dir)
end
