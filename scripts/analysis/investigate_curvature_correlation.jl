#!/usr/bin/env julia
#
# investigate_curvature_correlation.jl
#
# Análisis detallado del cambio de signo en la correlación ρ(φ) - κ(φ)
# para entender el mecanismo físico
#

using HDF5
using CSV
using DataFrames
using Statistics
using Plots
using Printf

gr()

"""
    calculate_local_curvature(phi, a, b)

Curvatura local κ(φ) en la elipse.
"""
function calculate_local_curvature(phi::T, a::T, b::T) where T <: AbstractFloat
    denom = (a^2 * sin(phi)^2 + b^2 * cos(phi)^2)^(3/2)
    kappa = (a * b) / denom
    return kappa
end

"""
    load_final_state(h5_file)

Carga el estado final de una simulación.
"""
function load_final_state(h5_file::String)
    h5open(h5_file, "r") do file
        phi = read(file["trajectories/phi"])
        phidot = read(file["trajectories/phidot"])
        times = read(file["trajectories/time"])

        meta_attrs = attributes(file["metadata"])
        a = read(meta_attrs["a"])
        b = read(meta_attrs["b"])
        e = read(meta_attrs["eccentricity"])
        N = read(meta_attrs["N"])

        # Estado final
        phi_final = phi[end, :]
        phidot_final = phidot[end, :]

        return (
            phi = phi_final,
            phidot = phidot_final,
            a = a,
            b = b,
            e = e,
            N = N
        )
    end
end

"""
    compute_density_and_curvature(phi, a, b; n_bins=50)

Computa ρ(φ) y κ(φ) en bins angulares.
"""
function compute_density_and_curvature(phi, a, b; n_bins=50)
    phi_edges = range(0, 2π, length=n_bins+1)
    phi_centers = (phi_edges[1:end-1] .+ phi_edges[2:end]) ./ 2

    # Densidad de partículas
    density = zeros(n_bins)
    for p in phi
        idx = searchsortedfirst(phi_edges, p) - 1
        idx = clamp(idx, 1, n_bins)
        density[idx] += 1
    end

    # Normalizar a densidad (partículas por bin)
    # NO normalizar a suma=1 aún, para ver magnitudes reales

    # Curvatura en cada bin
    curvature = [calculate_local_curvature(pc, a, b) for pc in phi_centers]

    return phi_centers, density, curvature
end

"""
    analyze_correlation_detailed(data; n_bins=50)

Análisis detallado de la correlación.
"""
function analyze_correlation_detailed(data; n_bins=50)
    phi_c, density, curvature = compute_density_and_curvature(
        data.phi, data.a, data.b; n_bins=n_bins
    )

    # Correlación de Pearson
    corr = cor(density, curvature)

    # Estadísticas
    stats = Dict(
        "N" => data.N,
        "e" => data.e,
        "correlation" => corr,
        "density_mean" => mean(density),
        "density_std" => std(density),
        "curvature_mean" => mean(curvature),
        "curvature_std" => std(curvature),
        "curvature_min" => minimum(curvature),
        "curvature_max" => maximum(curvature),
        "density_max_location" => phi_c[argmax(density)],
        "curvature_max_location" => phi_c[argmax(curvature)],
        "curvature_min_location" => phi_c[argmin(curvature)]
    )

    return phi_c, density, curvature, corr, stats
end

"""
    plot_detailed_correlation(data, phi_c, density, curvature, corr, stats; output_file)

Plot detallado mostrando:
1. Distribución de partículas en la elipse
2. ρ(φ) vs φ
3. κ(φ) vs φ
4. ρ vs κ scatter con regresión lineal
"""
function plot_detailed_correlation(data, phi_c, density, curvature, corr, stats;
                                   output_file=nothing)

    p = plot(layout = (2, 2), size = (1400, 1200), dpi = 150)

    # Panel 1: Posición de partículas en la elipse
    a, b = data.a, data.b
    theta_ellipse = range(0, 2π, length=200)
    x_ellipse = a .* cos.(theta_ellipse)
    y_ellipse = b .* sin.(theta_ellipse)

    x_particles = a .* cos.(data.phi)
    y_particles = b .* sin.(data.phi)

    plot!(p[1], x_ellipse, y_ellipse,
          label = "Ellipse",
          linewidth = 2,
          color = :black,
          aspect_ratio = :equal,
          xlabel = "x",
          ylabel = "y",
          title = @sprintf("Particle Distribution (N=%d, e=%.1f)", data.N, data.e),
          legend = :topright)

    scatter!(p[1], x_particles, y_particles,
             label = "Particles",
             markersize = 4,
             color = :blue,
             alpha = 0.6)

    # Panel 2: Densidad ρ(φ) y Curvatura κ(φ) vs φ
    # Normalizar para comparación visual
    density_norm = density ./ maximum(density)
    curv_norm = curvature ./ maximum(curvature)

    plot!(p[2], phi_c, density_norm,
          label = "ρ(φ) [norm]",
          linewidth = 2,
          color = :blue,
          xlabel = "φ [radians]",
          ylabel = "Normalized value",
          title = @sprintf("Density & Curvature | Corr = %.3f", corr),
          legend = :best,
          grid = true,
          xlims = (0, 2π))

    plot!(p[2], phi_c, curv_norm,
          label = "κ(φ) [norm]",
          linewidth = 2,
          color = :red,
          linestyle = :dash)

    # Marcar máximos
    vline!(p[2], [stats["density_max_location"]],
           label = "ρ max",
           color = :blue,
           linestyle = :dot,
           linewidth = 1)

    vline!(p[2], [stats["curvature_max_location"]],
           label = "κ max",
           color = :red,
           linestyle = :dot,
           linewidth = 1)

    # Panel 3: Curvatura κ(φ) sola para ver el perfil
    plot!(p[3], phi_c, curvature,
          xlabel = "φ [radians]",
          ylabel = "κ(φ) [1/length]",
          title = "Curvature Profile",
          linewidth = 2,
          color = :red,
          legend = false,
          grid = true,
          xlims = (0, 2π))

    # Panel 4: Scatter ρ vs κ con regresión lineal
    scatter!(p[4], curvature, density,
             xlabel = "κ(φ) [curvature]",
             ylabel = "ρ(φ) [particle count]",
             title = @sprintf("ρ vs κ | Pearson r = %.3f", corr),
             markersize = 6,
             color = :purple,
             alpha = 0.6,
             legend = false,
             grid = true)

    # Regresión lineal
    X = hcat(ones(length(curvature)), curvature)
    β = X \ density
    κ_range = range(minimum(curvature), maximum(curvature), length=100)
    ρ_fit = β[1] .+ β[2] .* κ_range

    plot!(p[4], κ_range, ρ_fit,
          linewidth = 2,
          color = :black,
          linestyle = :dash,
          label = @sprintf("Fit: ρ = %.2f + %.2f·κ", β[1], β[2]))

    if !isnothing(output_file)
        savefig(p, output_file)
    end

    return p
end

"""
    compare_multiple_seeds(campaign_dir, N, e; max_seeds=10)

Analiza múltiples seeds para ver si la correlación es robusta.
"""
function compare_multiple_seeds(campaign_dir::String, N::Int, e::Float64;
                                max_seeds=10, output_dir=nothing)

    println(@sprintf("\n=== Analyzing N=%d, e=%.1f (multiple seeds) ===", N, e))

    # Buscar runs
    run_dirs = filter(readdir(campaign_dir, join=true)) do path
        isdir(path) && occursin(r"^e\d", basename(path))
    end

    matching_runs = []
    for run_dir in run_dirs
        run_name = basename(run_dir)
        m = match(r"e(\d+\.\d+)_N(\d+)_seed(\d+)", run_name)
        if !isnothing(m)
            e_run = parse(Float64, m.captures[1])
            N_run = parse(Int, m.captures[2])

            if N_run == N && abs(e_run - e) < 0.01
                h5_file = joinpath(run_dir, "trajectories.h5")
                if isfile(h5_file)
                    push!(matching_runs, (run_name, h5_file))
                end
            end
        end

        if length(matching_runs) >= max_seeds
            break
        end
    end

    if length(matching_runs) == 0
        @warn "No runs found for N=$N, e=$e"
        return nothing
    end

    println("  Found $(length(matching_runs)) runs")

    # Analizar cada run
    all_correlations = []
    all_stats = []

    for (i, (run_name, h5_file)) in enumerate(matching_runs)
        data = load_final_state(h5_file)
        phi_c, density, curvature, corr, stats = analyze_correlation_detailed(data)

        push!(all_correlations, corr)
        push!(all_stats, stats)

        println(@sprintf("    Seed %d: corr = %.4f", i, corr))

        # Guardar plot detallado del primer seed
        if i == 1 && !isnothing(output_dir)
            mkpath(output_dir)
            output_file = joinpath(output_dir,
                @sprintf("detailed_N%d_e%.1f_seed%d.png", N, e, i))
            plot_detailed_correlation(data, phi_c, density, curvature, corr, stats;
                                     output_file=output_file)
            println("    ✅ Detailed plot saved")
        end
    end

    # Estadísticas sobre las correlaciones
    mean_corr = mean(all_correlations)
    std_corr = std(all_correlations)

    println(@sprintf("  Mean correlation: %.4f ± %.4f", mean_corr, std_corr))

    # Locations de máximos
    density_max_locs = [s["density_max_location"] for s in all_stats]
    curv_max_locs = [s["curvature_max_location"] for s in all_stats]

    println(@sprintf("  Mean ρ_max location: %.3f ± %.3f rad",
                    mean(density_max_locs), std(density_max_locs)))
    println(@sprintf("  Mean κ_max location: %.3f ± %.3f rad",
                    mean(curv_max_locs), std(curv_max_locs)))

    return DataFrame(all_stats), mean_corr, std_corr
end

"""
    main_investigation(campaign_dir)
"""
function main_investigation(campaign_dir::String)
    println("="^80)
    println("DETAILED CURVATURE-DENSITY CORRELATION INVESTIGATION")
    println("="^80)

    output_dir = joinpath(campaign_dir, "curvature_investigation")
    mkpath(output_dir)

    # Casos críticos que muestran el cambio de signo
    cases = [
        (N=40, e=0.5, label="Small N, e=0.5 (positive corr?)"),
        (N=80, e=0.5, label="Large N, e=0.5 (negative corr?)"),
        (N=40, e=0.0, label="Circle (zero corr)"),
        (N=60, e=0.9, label="High e (frustrated)")
    ]

    summary_results = []

    for case in cases
        df, mean_corr, std_corr = compare_multiple_seeds(
            campaign_dir, case.N, case.e;
            max_seeds=10, output_dir=output_dir
        )

        if !isnothing(df)
            push!(summary_results, (
                N = case.N,
                e = case.e,
                mean_corr = mean_corr,
                std_corr = std_corr,
                label = case.label
            ))
        end
    end

    # Guardar resumen
    summary_df = DataFrame(summary_results)
    csv_file = joinpath(output_dir, "correlation_summary.csv")
    CSV.write(csv_file, summary_df)

    println()
    println("="^80)
    println("SUMMARY OF CORRELATIONS")
    println("="^80)
    println(summary_df)
    println()
    println("Output: $output_dir")
    println("="^80)
end

# Main
if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) < 1
        println("Usage: julia investigate_curvature_correlation.jl <campaign_dir>")
        exit(1)
    end

    main_investigation(ARGS[1])
end
