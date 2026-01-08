#!/usr/bin/env julia
#
# analyze_phase_space_dynamics.jl
#
# Análisis detallado del espacio fase (φ, φ̇):
# - Distribuciones en el espacio fase como función del tiempo
# - Correlación entre densidad de partículas y curvatura local
# - Estructura de clusters en el espacio fase
# - Evolución temporal de la ocupación del espacio fase
#

using HDF5
using CSV
using DataFrames
using Statistics
using Plots
using Printf
using LinearAlgebra

gr()

"""
    calculate_local_curvature(phi, a, b)

Calcula la curvatura local κ(φ) en un punto de la elipse.
"""
function calculate_local_curvature(phi::T, a::T, b::T) where T <: AbstractFloat
    # Curvatura de elipse: κ(φ) = (a*b) / (a²sin²φ + b²cos²φ)^(3/2)
    denom = (a^2 * sin(phi)^2 + b^2 * cos(phi)^2)^(3/2)
    kappa = (a * b) / denom
    return kappa
end

"""
    load_phase_space_snapshot(h5_file, snapshot_idx=nothing)

Carga un snapshot del espacio fase. Si snapshot_idx=nothing, carga el último.
"""
function load_phase_space_snapshot(h5_file::String; snapshot_idx=nothing)
    h5open(h5_file, "r") do file
        phi = read(file["trajectories/phi"])
        phidot = read(file["trajectories/phidot"])
        times = read(file["trajectories/time"])

        # Parámetros geométricos
        meta_attrs = attributes(file["metadata"])
        a = read(meta_attrs["a"])
        b = read(meta_attrs["b"])
        e = read(meta_attrs["eccentricity"])
        N = read(meta_attrs["N"])

        if isnothing(snapshot_idx)
            snapshot_idx = size(phi, 1)
        end

        phi_snap = phi[snapshot_idx, :]
        phidot_snap = phidot[snapshot_idx, :]
        t = times[snapshot_idx]

        return (
            phi = phi_snap,
            phidot = phidot_snap,
            time = t,
            a = a,
            b = b,
            e = e,
            N = N,
            all_phi = phi,
            all_phidot = phidot,
            all_times = times
        )
    end
end

"""
    compute_phase_space_density(phi, phidot; n_bins_phi=20, n_bins_phidot=20)

Computa la densidad en el espacio fase discretizado.
"""
function compute_phase_space_density(phi, phidot; n_bins_phi=20, n_bins_phidot=20)
    # Bins para φ ∈ [0, 2π] y φ̇
    phi_edges = range(0, 2π, length=n_bins_phi+1)
    phidot_min, phidot_max = extrema(phidot)
    phidot_range = phidot_max - phidot_min
    phidot_edges = range(phidot_min - 0.1*phidot_range,
                         phidot_max + 0.1*phidot_range,
                         length=n_bins_phidot+1)

    # Histograma 2D
    density = zeros(n_bins_phi, n_bins_phidot)

    for (p, pd) in zip(phi, phidot)
        i = searchsortedfirst(phi_edges, p) - 1
        j = searchsortedfirst(phidot_edges, pd) - 1

        i = clamp(i, 1, n_bins_phi)
        j = clamp(j, 1, n_bins_phidot)

        density[i, j] += 1
    end

    # Normalizar
    density ./= sum(density)

    phi_centers = (phi_edges[1:end-1] .+ phi_edges[2:end]) ./ 2
    phidot_centers = (phidot_edges[1:end-1] .+ phidot_edges[2:end]) ./ 2

    return density, phi_centers, phidot_centers
end

"""
    compute_curvature_density_correlation(phi, a, b; n_bins=30)

Correlaciona la densidad de partículas ρ(φ) con la curvatura local κ(φ).
"""
function compute_curvature_density_correlation(phi, a, b; n_bins=30)
    # Bins para φ
    phi_edges = range(0, 2π, length=n_bins+1)
    phi_centers = (phi_edges[1:end-1] .+ phi_edges[2:end]) ./ 2

    # Histograma de densidad
    density = zeros(n_bins)
    for p in phi
        i = searchsortedfirst(phi_edges, p) - 1
        i = clamp(i, 1, n_bins)
        density[i] += 1
    end
    density ./= sum(density)

    # Curvatura en cada bin
    curvature = [calculate_local_curvature(pc, a, b) for pc in phi_centers]

    # Correlación de Pearson
    if std(density) > 1e-10 && std(curvature) > 1e-10
        correlation = cor(density, curvature)
    else
        correlation = 0.0
    end

    return phi_centers, density, curvature, correlation
end

"""
    plot_phase_space_snapshot(data; output_file=nothing)

Genera scatter plot del espacio fase en un instante dado.
"""
function plot_phase_space_snapshot(data; output_file=nothing)
    p = scatter(
        data.phi, data.phidot,
        xlabel = "φ",
        ylabel = "φ̇",
        title = @sprintf("Phase Space (N=%d, e=%.1f, t=%.2f)",
                        data.N, data.e, data.time),
        marker = :circle,
        markersize = 3,
        alpha = 0.6,
        color = :blue,
        legend = false,
        size = (800, 600),
        dpi = 150,
        xlims = (0, 2π),
        grid = true
    )

    if !isnothing(output_file)
        savefig(p, output_file)
    end

    return p
end

"""
    plot_phase_space_density(data; output_file=nothing)

Genera heatmap de densidad en el espacio fase.
"""
function plot_phase_space_density(data; output_file=nothing, n_bins_phi=30, n_bins_phidot=30)
    density, phi_c, phidot_c = compute_phase_space_density(
        data.phi, data.phidot;
        n_bins_phi=n_bins_phi,
        n_bins_phidot=n_bins_phidot
    )

    p = heatmap(
        phi_c, phidot_c, density',
        xlabel = "φ",
        ylabel = "φ̇",
        title = @sprintf("Phase Space Density (N=%d, e=%.1f, t=%.2f)",
                        data.N, data.e, data.time),
        color = :viridis,
        size = (800, 600),
        dpi = 150,
        xlims = (0, 2π),
        colorbar_title = "ρ(φ, φ̇)"
    )

    if !isnothing(output_file)
        savefig(p, output_file)
    end

    return p
end

"""
    plot_curvature_density_correlation(data; output_file=nothing)

Grafica correlación entre densidad ρ(φ) y curvatura κ(φ).
"""
function plot_curvature_density_correlation(data; output_file=nothing)
    phi_c, density, curvature, corr = compute_curvature_density_correlation(
        data.phi, data.a, data.b
    )

    # Normalizar para comparación visual
    density_norm = density ./ maximum(density)
    curv_norm = curvature ./ maximum(curvature)

    p = plot(
        layout = (2, 1),
        size = (1000, 800),
        dpi = 150
    )

    # Panel 1: Densidad y curvatura vs φ
    plot!(p[1], phi_c, density_norm,
          label = "ρ(φ) [normalized]",
          linewidth = 2,
          color = :blue,
          xlabel = "",
          ylabel = "Normalized value",
          title = @sprintf("N=%d, e=%.1f, t=%.2f | Correlation: %.3f",
                          data.N, data.e, data.time, corr),
          legend = :best,
          grid = true,
          xlims = (0, 2π))

    plot!(p[1], phi_c, curv_norm,
          label = "κ(φ) [normalized]",
          linewidth = 2,
          color = :red,
          linestyle = :dash)

    # Panel 2: Scatter ρ vs κ
    scatter!(p[2], curvature, density,
             xlabel = "κ(φ) [curvature]",
             ylabel = "ρ(φ) [density]",
             title = "Density vs Curvature",
             markersize = 4,
             color = :purple,
             alpha = 0.6,
             legend = false,
             grid = true)

    if !isnothing(output_file)
        savefig(p, output_file)
    end

    return p, corr
end

"""
    plot_phase_space_evolution(data; output_file=nothing, n_snapshots=6)

Muestra evolución del espacio fase en múltiples instantes de tiempo.
"""
function plot_phase_space_evolution(data; output_file=nothing, n_snapshots=6)
    n_times = length(data.all_times)
    snapshot_indices = round.(Int, range(1, n_times, length=n_snapshots))

    p = plot(
        layout = (2, 3),
        size = (1500, 1000),
        dpi = 150
    )

    for (i, idx) in enumerate(snapshot_indices)
        phi_snap = data.all_phi[idx, :]
        phidot_snap = data.all_phidot[idx, :]
        t = data.all_times[idx]

        scatter!(p[i], phi_snap, phidot_snap,
                xlabel = (i > 3 ? "φ" : ""),
                ylabel = (i % 3 == 1 ? "φ̇" : ""),
                title = @sprintf("t = %.2f", t),
                marker = :circle,
                markersize = 2,
                alpha = 0.5,
                color = :blue,
                legend = false,
                xlims = (0, 2π),
                grid = true)
    end

    plot!(p, plot_title = @sprintf("Phase Space Evolution (N=%d, e=%.1f)",
                                   data.N, data.e))

    if !isnothing(output_file)
        savefig(p, output_file)
    end

    return p
end

"""
    analyze_single_run_phase_space(h5_file, run_name; output_dir)

Análisis completo del espacio fase para un solo run.
"""
function analyze_single_run_phase_space(h5_file::String, run_name::String;
                                        output_dir=nothing)
    println("  Analyzing $run_name...")

    # Cargar datos
    data = load_phase_space_snapshot(h5_file)

    if isnothing(output_dir)
        return
    end

    mkpath(output_dir)

    # Plot 1: Scatter phase space (last snapshot)
    plot_phase_space_snapshot(data;
        output_file=joinpath(output_dir, "$(run_name)_phase_space_scatter.png"))

    # Plot 2: Density heatmap
    plot_phase_space_density(data;
        output_file=joinpath(output_dir, "$(run_name)_phase_space_density.png"))

    # Plot 3: Curvature-density correlation
    _, corr = plot_curvature_density_correlation(data;
        output_file=joinpath(output_dir, "$(run_name)_curvature_correlation.png"))

    # Plot 4: Time evolution
    plot_phase_space_evolution(data;
        output_file=joinpath(output_dir, "$(run_name)_phase_space_evolution.png"))

    println("    ✅ 4 plots generated")

    return Dict(
        "run_name" => run_name,
        "N" => data.N,
        "e" => data.e,
        "curvature_density_correlation" => corr
    )
end

"""
    compare_phase_space_across_e(campaign_dir, N; output_dir)

Compara el espacio fase para diferentes eccentricities con N fijo.
"""
function compare_phase_space_across_e(campaign_dir::String, N::Int; output_dir)
    println("\nComparing phase space across eccentricities for N=$N...")

    e_values = [0.0, 0.3, 0.5, 0.7, 0.8, 0.9]

    mkpath(output_dir)

    # Buscar un run representativo para cada e
    results = []

    for e in e_values
        run_dirs = filter(readdir(campaign_dir, join=true)) do path
            isdir(path) && occursin(r"^e\d", basename(path))
        end

        for run_dir in run_dirs
            run_name = basename(run_dir)
            m = match(r"e(\d+\.\d+)_N(\d+)_seed(\d+)", run_name)
            if !isnothing(m)
                e_run = parse(Float64, m.captures[1])
                N_run = parse(Int, m.captures[2])

                if N_run == N && abs(e_run - e) < 0.01
                    h5_file = joinpath(run_dir, "trajectories.h5")
                    if isfile(h5_file)
                        # Cargar datos
                        data = load_phase_space_snapshot(h5_file)
                        push!(results, (e=e, data=data))
                        break
                    end
                end
            end
        end
    end

    if length(results) == 0
        @warn "No runs found for N=$N"
        return nothing
    end

    # Plot comparativo: Phase space para cada e
    n_found = length(results)
    n_rows = 2
    n_cols = 3

    p = plot(
        layout = (n_rows, n_cols),
        size = (1500, 1000),
        dpi = 150
    )

    for (i, res) in enumerate(results)
        if i > 6
            break
        end

        scatter!(p[i], res.data.phi, res.data.phidot,
                xlabel = (i > 3 ? "φ" : ""),
                ylabel = (i % 3 == 1 ? "φ̇" : ""),
                title = @sprintf("e = %.1f", res.e),
                marker = :circle,
                markersize = 2,
                alpha = 0.5,
                color = :blue,
                legend = false,
                xlims = (0, 2π),
                grid = true)
    end

    plot!(p, plot_title = @sprintf("Phase Space Comparison (N=%d)", N))

    filename = @sprintf("phase_space_comparison_N%d.png", N)
    savefig(p, joinpath(output_dir, filename))
    println("  ✅ Saved: $filename")

    # Curvature correlation comparison
    correlations = [compute_curvature_density_correlation(
        res.data.phi, res.data.a, res.data.b
    )[4] for res in results]

    e_vals = [res.e for res in results]

    p2 = scatter(e_vals, correlations,
                xlabel = "Eccentricity e",
                ylabel = "Correlation ρ(φ) - κ(φ)",
                title = @sprintf("Curvature-Density Correlation vs e (N=%d)", N),
                markersize = 8,
                color = :purple,
                legend = false,
                grid = true,
                size = (800, 600),
                dpi = 150)

    plot!(p2, e_vals, correlations, linewidth=2, color=:purple, alpha=0.3)

    filename2 = @sprintf("curvature_correlation_vs_e_N%d.png", N)
    savefig(p2, joinpath(output_dir, filename2))
    println("  ✅ Saved: $filename2")

    return DataFrame(e=e_vals, correlation=correlations)
end

"""
    main_analysis(campaign_dir)
"""
function main_analysis(campaign_dir::String)
    println("="^80)
    println("PHASE SPACE DYNAMICS ANALYSIS")
    println("="^80)
    println()

    output_dir = joinpath(campaign_dir, "phase_space_analysis")
    mkpath(output_dir)

    # Analyze representative cases
    println("Analyzing representative single runs...")

    cases = [
        (N=40, e=0.5, label="Strong clustering"),
        (N=80, e=0.0, label="Circle (reference)"),
        (N=60, e=0.9, label="High eccentricity")
    ]

    for case in cases
        # Find one matching run
        run_dirs = filter(readdir(campaign_dir, join=true)) do path
            isdir(path) && occursin(r"^e\d", basename(path))
        end

        for run_dir in run_dirs
            run_name = basename(run_dir)
            m = match(r"e(\d+\.\d+)_N(\d+)_seed(\d+)", run_name)
            if !isnothing(m)
                e_run = parse(Float64, m.captures[1])
                N_run = parse(Int, m.captures[2])

                if N_run == case.N && abs(e_run - case.e) < 0.01
                    h5_file = joinpath(run_dir, "trajectories.h5")
                    if isfile(h5_file)
                        analyze_single_run_phase_space(h5_file, run_name;
                                                      output_dir=output_dir)
                        break
                    end
                end
            end
        end
    end

    # Compare phase space across e for fixed N
    println("\nComparing phase space across eccentricities...")
    for N in [40, 80]
        df = compare_phase_space_across_e(campaign_dir, N; output_dir=output_dir)
        if !isnothing(df)
            csv_file = joinpath(output_dir, @sprintf("curvature_correlation_N%d.csv", N))
            CSV.write(csv_file, df)
        end
    end

    println()
    println("="^80)
    println("✅ PHASE SPACE DYNAMICS ANALYSIS COMPLETE")
    println("="^80)
    println("Output: $output_dir")
end

# Main
if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) < 1
        println("Usage: julia analyze_phase_space_dynamics.jl <campaign_dir>")
        exit(1)
    end

    main_analysis(ARGS[1])
end
