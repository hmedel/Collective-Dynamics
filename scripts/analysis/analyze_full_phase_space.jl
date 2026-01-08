#!/usr/bin/env julia
"""
Full Phase Space Analysis - All Particles Evolution

Analyzes the complete phase space (φ, φ̇) for ALL particles to visualize:
1. How curvature affects velocity distribution
2. Cluster formation in phase space
3. Correlation between position (φ) and local curvature
4. Time evolution of phase space density

KEY INSIGHT (POLAR ANGLE PARAMETRIZATION):
We use TRUE polar coordinates φ (not eccentric angle θ).
The metric g_φφ(φ) = (dr/dφ)² + r² varies with position where:
- r(φ) = ab/√(a²sin²φ + b²cos²φ) is the radial distance to ellipse
- r is SMALL at φ=0,π (high curvature ends) and LARGE at φ=π/2,3π/2 (low curvature sides)

Regions where r(φ) is small → g_φφ can be small → slower tangential velocities
→ This creates "dynamical traps" where particles accumulate → clustering!

Usage:
    julia analyze_full_phase_space.jl results/campaign_EN_scan_*/e0.866_N40_phi0.06_E0.32/seed_1/
"""

using HDF5
using JSON
using Statistics
using DataFrames
using CSV
using Plots
using Printf
using LinearAlgebra

include("src/geometry/metrics_polar.jl")

"""
    load_full_trajectories(hdf5_file::String)

Load complete phase space trajectories for all particles.

Returns:
- t: time points [n_snapshots]
- phi: angular positions [N, n_snapshots]
- phidot: angular velocities [N, n_snapshots]
- params: simulation parameters (a, b, e, N)
"""
function load_full_trajectories(hdf5_file::String)
    h5open(hdf5_file, "r") do file
        t = read(file, "trajectories/time")
        phi = read(file, "trajectories/phi")
        phidot = read(file, "trajectories/phidot")

        # Load geometry parameters
        params = read(file, "parameters")

        return t, phi, phidot, params
    end
end

"""
    compute_local_curvature_metric(phi::Vector{Float64}, a::Float64, b::Float64)

Compute local metric g_φφ(φ) for each particle position.

The metric determines the "speed" at which angular velocity translates to tangential velocity:
v_tangent = √g_φφ(φ) · φ̇

For ellipse: g_φφ(φ) = a²sin²(φ) + b²cos²(φ)

Returns:
- g_phi: metric values at each particle position
- kappa: local curvature κ(φ) ∝ 1/√g_φφ (high curvature → slow region)
"""
function compute_local_curvature_metric(phi::Vector{Float64}, a::Float64, b::Float64)
    N = length(phi)
    g_phi = zeros(N)
    kappa = zeros(N)

    for i in 1:N
        g_phi[i] = metric_polar(phi[i], a, b)

        # Curvature is inversely related to metric
        # κ ∝ 1/√g_φφ (simplified - exact formula is more complex)
        kappa[i] = 1.0 / sqrt(g_phi[i])
    end

    return g_phi, kappa
end

"""
    analyze_phase_space_evolution(hdf5_file::String, snapshot_times::Vector{Float64})

Analyze how the full phase space (φ, φ̇) evolves at different times.

Creates visualizations showing:
1. Phase space scatter plot (φ vs φ̇) with color = local curvature
2. Density heatmap in phase space
3. Correlation between φ and φ̇ (alignment/anti-alignment)
4. Curvature-weighted velocity distribution
"""
function analyze_phase_space_evolution(hdf5_file::String, snapshot_times::Vector{Float64})
    println("="^70)
    println("Full Phase Space Analysis")
    println("="^70)
    println("File: $hdf5_file")
    println("Snapshots: $snapshot_times")
    println()

    # Load data
    t, phi, phidot, params = load_full_trajectories(hdf5_file)

    a = params["a"]
    b = params["b"]
    e = params["eccentricity"]
    N = params["N"]

    println("Geometry: a=$a, b=$b, e=$(round(e, digits=3))")
    println("Particles: N=$N")
    println()

    # Create output directory
    output_dir = joinpath(dirname(hdf5_file), "phase_space_analysis")
    mkpath(output_dir)

    # Analyze each snapshot
    for t_snap in snapshot_times
        # Find closest time index
        idx = argmin(abs.(t .- t_snap))
        actual_time = t[idx]

        println("Analyzing t = $(round(actual_time, digits=2))s...")

        # Get state at this time
        phi_snap = phi[:, idx]
        phidot_snap = phidot[:, idx]

        # Compute local metrics and curvature
        g_phi, kappa = compute_local_curvature_metric(phi_snap, a, b)

        # Compute tangential velocities
        v_tangent = sqrt.(g_phi) .* abs.(phidot_snap)

        # Create phase space plot
        plot_phase_space_snapshot(phi_snap, phidot_snap, kappa, v_tangent,
                                 actual_time, e, output_dir)

        # Analyze correlations
        analyze_curvature_velocity_correlation(phi_snap, phidot_snap, g_phi, kappa,
                                              actual_time, a, b, output_dir)
    end

    println()
    println("Analysis complete! Results saved to: $output_dir")

    # Create time evolution animation data
    create_phase_space_evolution_data(t, phi, phidot, a, b, output_dir)

    return output_dir
end

"""
    plot_phase_space_snapshot(phi, phidot, kappa, v_tangent, time, e, output_dir)

Create comprehensive phase space visualization for one time snapshot.
"""
function plot_phase_space_snapshot(phi::Vector{Float64}, phidot::Vector{Float64},
                                   kappa::Vector{Float64}, v_tangent::Vector{Float64},
                                   time::Float64, e::Float64, output_dir::String)

    # Plot 1: Phase space colored by local curvature
    p1 = scatter(phi, phidot,
                 marker_z=kappa,
                 color=:viridis,
                 xlabel="Angular Position φ (rad)",
                 ylabel="Angular Velocity φ̇ (rad/s)",
                 title="Phase Space at t=$(round(time, digits=1))s (color=curvature)",
                 colorbar_title="κ(φ)",
                 markersize=6,
                 alpha=0.7,
                 legend=false,
                 size=(800, 600))

    # Add reference lines
    hline!(p1, [0], color=:white, linestyle=:dash, linewidth=2, alpha=0.5)
    vline!(p1, [0, π, 2π], color=:white, linestyle=:dash, linewidth=1, alpha=0.3)

    savefig(p1, joinpath(output_dir, "phase_space_curvature_t$(round(Int, time)).png"))

    # Plot 2: Phase space colored by tangential velocity
    p2 = scatter(phi, phidot,
                 marker_z=v_tangent,
                 color=:thermal,
                 xlabel="Angular Position φ (rad)",
                 ylabel="Angular Velocity φ̇ (rad/s)",
                 title="Phase Space (color=tangential velocity)",
                 colorbar_title="v_tangent",
                 markersize=6,
                 alpha=0.7,
                 legend=false,
                 size=(800, 600))

    savefig(p2, joinpath(output_dir, "phase_space_velocity_t$(round(Int, time)).png"))

    # Plot 3: 2D histogram (phase space density)
    p3 = histogram2d(phi, phidot,
                     bins=30,
                     xlabel="Angular Position φ (rad)",
                     ylabel="Angular Velocity φ̇ (rad/s)",
                     title="Phase Space Density at t=$(round(time, digits=1))s",
                     color=:plasma,
                     size=(800, 600))

    savefig(p3, joinpath(output_dir, "phase_space_density_t$(round(Int, time)).png"))
end

"""
    analyze_curvature_velocity_correlation(phi, phidot, g_phi, kappa, time, a, b, output_dir)

Analyze correlation between position (curvature) and velocity.

Tests hypothesis: High curvature regions → slower particles → clustering
"""
function analyze_curvature_velocity_correlation(phi::Vector{Float64}, phidot::Vector{Float64},
                                               g_phi::Vector{Float64}, kappa::Vector{Float64},
                                               time::Float64, a::Float64, b::Float64,
                                               output_dir::String)

    N = length(phi)

    # Compute tangential velocity
    v_tangent = sqrt.(g_phi) .* abs.(phidot)

    # Bin by curvature
    n_bins = 20
    kappa_min, kappa_max = extrema(kappa)
    kappa_edges = range(kappa_min, kappa_max, length=n_bins+1)
    kappa_centers = (kappa_edges[1:end-1] .+ kappa_edges[2:end]) ./ 2

    # Statistics in each curvature bin
    mean_v = zeros(n_bins)
    std_v = zeros(n_bins)
    n_particles = zeros(Int, n_bins)

    for i in 1:N
        bin = searchsortedfirst(kappa_edges, kappa[i]) - 1
        bin = clamp(bin, 1, n_bins)

        n_particles[bin] += 1
        mean_v[bin] += v_tangent[i]
    end

    # Average
    for bin in 1:n_bins
        if n_particles[bin] > 0
            mean_v[bin] /= n_particles[bin]
        end
    end

    # Compute std dev
    for i in 1:N
        bin = searchsortedfirst(kappa_edges, kappa[i]) - 1
        bin = clamp(bin, 1, n_bins)

        if n_particles[bin] > 0
            std_v[bin] += (v_tangent[i] - mean_v[bin])^2
        end
    end

    for bin in 1:n_bins
        if n_particles[bin] > 1
            std_v[bin] = sqrt(std_v[bin] / n_particles[bin])
        end
    end

    # Plot correlation
    p = plot(kappa_centers, mean_v,
             ribbon=std_v,
             xlabel="Local Curvature κ(φ)",
             ylabel="Mean Tangential Velocity ⟨v⟩",
             title="Curvature → Velocity Correlation at t=$(round(time, digits=1))s",
             label="Mean ± Std",
             linewidth=2,
             fillalpha=0.3,
             size=(800, 600))

    # Add particle count as secondary axis (bar plot)
    p_count = bar!(twinx(), kappa_centers, n_particles,
                   ylabel="Number of Particles",
                   label="Particle Count",
                   alpha=0.3,
                   color=:gray)

    savefig(p, joinpath(output_dir, "curvature_velocity_correlation_t$(round(Int, time)).png"))

    # Compute correlation coefficient
    valid = n_particles .> 0
    if sum(valid) > 2
        corr = cor(kappa_centers[valid], mean_v[valid])
        println("  Curvature-velocity correlation: r = $(round(corr, digits=3))")

        # Save correlation data
        df = DataFrame(
            time = time,
            kappa = kappa_centers[valid],
            mean_velocity = mean_v[valid],
            std_velocity = std_v[valid],
            n_particles = n_particles[valid],
            correlation_coef = corr
        )

        CSV.write(joinpath(output_dir, "curvature_correlation_t$(round(Int, time)).csv"), df)
    end
end

"""
    create_phase_space_evolution_data(t, phi, phidot, a, b, output_dir)

Create comprehensive data file for phase space evolution over time.
"""
function create_phase_space_evolution_data(t::Vector{Float64},
                                          phi::Array{Float64,2},
                                          phidot::Array{Float64,2},
                                          a::Float64, b::Float64,
                                          output_dir::String)

    println()
    println("Creating phase space evolution dataset...")

    N, n_snapshots = size(phi)

    # Sample every ~10th snapshot for manageable file size
    sample_rate = max(1, n_snapshots ÷ 100)
    indices = 1:sample_rate:n_snapshots

    # Create DataFrame with all data
    data = DataFrame()

    for (idx_count, idx) in enumerate(indices)
        for i in 1:N
            # Compute local metric and curvature
            g = metric_polar(phi[i, idx], a, b)
            kappa = 1.0 / sqrt(g)
            v_tangent = sqrt(g) * abs(phidot[i, idx])

            push!(data, (
                time = t[idx],
                particle_id = i,
                phi = phi[i, idx],
                phidot = phidot[i, idx],
                g_phi = g,
                curvature = kappa,
                v_tangent = v_tangent
            ))
        end

        if idx_count % 10 == 0
            println("  Processed snapshot $idx_count / $(length(indices))")
        end
    end

    # Save
    csv_file = joinpath(output_dir, "phase_space_evolution_full.csv")
    CSV.write(csv_file, data)
    println("  Saved: $csv_file ($(nrow(data)) data points)")

    # Create summary statistics over time
    summary = combine(groupby(data, :time)) do df
        (
            mean_phi = mean(df.phi),
            std_phi = std(df.phi),
            mean_phidot = mean(df.phidot),
            std_phidot = std(df.phidot),
            mean_curvature = mean(df.curvature),
            mean_v_tangent = mean(df.v_tangent),
            curvature_velocity_corr = cor(df.curvature, df.v_tangent)
        )
    end

    CSV.write(joinpath(output_dir, "phase_space_summary.csv"), summary)

    # Plot evolution of correlation
    p = plot(summary.time, summary.curvature_velocity_corr,
             xlabel="Time (s)",
             ylabel="Curvature-Velocity Correlation",
             title="Evolution of κ-v Correlation",
             linewidth=2,
             marker=:circle,
             legend=false,
             size=(800, 600))

    hline!(p, [0], color=:black, linestyle=:dash, alpha=0.5)

    savefig(p, joinpath(output_dir, "correlation_evolution.png"))

    println("  Analysis complete!")
end

"""
    analyze_clustering_mechanism_geometry(hdf5_file::String)

Detailed analysis of the geometric clustering mechanism.

Shows how curvature variation creates "velocity traps" → clustering
"""
function analyze_clustering_mechanism_geometry(hdf5_file::String)
    println("="^70)
    println("Geometric Clustering Mechanism Analysis")
    println("="^70)
    println()

    t, phi, phidot, params = load_full_trajectories(hdf5_file)

    a = params["a"]
    b = params["b"]
    e = params["eccentricity"]

    output_dir = joinpath(dirname(hdf5_file), "clustering_mechanism")
    mkpath(output_dir)

    # Plot metric variation around ellipse
    phi_samples = range(0, 2π, length=200)
    g_samples = [metric_polar(p, a, b) for p in phi_samples]
    kappa_samples = 1.0 ./ sqrt.(g_samples)

    # Normalize curvature for visualization
    kappa_norm = (kappa_samples .- minimum(kappa_samples)) ./ (maximum(kappa_samples) - minimum(kappa_samples))

    p1 = plot(phi_samples, g_samples,
              xlabel="Angular Position φ (rad)",
              ylabel="Metric g_φφ(φ)",
              title="Metric Variation (e=$(round(e, digits=3)))",
              linewidth=3,
              label="g_φφ",
              size=(800, 600))

    plot!(twinx(), phi_samples, kappa_norm,
          ylabel="Normalized Curvature κ(φ)",
          label="κ (normalized)",
          color=:red,
          linewidth=3,
          linestyle=:dash)

    # Mark high curvature regions
    high_curv_threshold = quantile(kappa_samples, 0.75)
    high_curv_regions = findall(kappa_samples .> high_curv_threshold)

    for region in high_curv_regions[1:5:end]  # Sample every 5th point
        vline!(p1, [phi_samples[region]], color=:red, alpha=0.1, linewidth=2, label="")
    end

    savefig(p1, joinpath(output_dir, "metric_curvature_variation.png"))

    println("Metric analysis:")
    println("  g_φφ range: $(round(minimum(g_samples), digits=3)) - $(round(maximum(g_samples), digits=3))")
    println("  κ range: $(round(minimum(kappa_samples), digits=3)) - $(round(maximum(kappa_samples), digits=3))")
    println("  Variation: $(round(100*(maximum(g_samples) - minimum(g_samples))/mean(g_samples), digits=1))%")
    println()

    # Show particle evolution in high vs low curvature regions
    analyze_trajectory_by_curvature(t, phi, phidot, a, b, output_dir)

    return output_dir
end

"""
    analyze_trajectory_by_curvature(t, phi, phidot, a, b, output_dir)

Track particles in high vs low curvature regions over time.
"""
function analyze_trajectory_by_curvature(t, phi, phidot, a, b, output_dir)
    N, n_snapshots = size(phi)

    # Define curvature threshold
    phi_samples = range(0, 2π, length=200)
    kappa_samples = [1.0/sqrt(metric_polar(p, a, b)) for p in phi_samples]
    kappa_threshold = median(kappa_samples)

    # Count particles in high curvature regions over time
    n_high_curv = zeros(Int, n_snapshots)
    mean_v_high = zeros(n_snapshots)
    mean_v_low = zeros(n_snapshots)

    for idx in 1:n_snapshots
        n_h = 0
        sum_v_h = 0.0
        sum_v_l = 0.0
        n_l = 0

        for i in 1:N
            g = metric_polar(phi[i, idx], a, b)
            kappa = 1.0 / sqrt(g)
            v = sqrt(g) * abs(phidot[i, idx])

            if kappa > kappa_threshold
                n_h += 1
                sum_v_h += v
            else
                n_l += 1
                sum_v_l += v
            end
        end

        n_high_curv[idx] = n_h
        mean_v_high[idx] = n_h > 0 ? sum_v_h / n_h : 0.0
        mean_v_low[idx] = n_l > 0 ? sum_v_l / n_l : 0.0
    end

    # Plot
    p = plot(t, n_high_curv ./ N * 100,
             xlabel="Time (s)",
             ylabel="% Particles in High Curvature Regions",
             title="Clustering in High Curvature Regions",
             linewidth=2,
             label="% in high κ",
             size=(800, 600))

    hline!(p, [50], color=:black, linestyle=:dash, label="Random (50%)")

    savefig(p, joinpath(output_dir, "high_curvature_occupation.png"))

    # Velocity comparison
    p2 = plot(t, [mean_v_high mean_v_low],
              xlabel="Time (s)",
              ylabel="Mean Tangential Velocity",
              title="Velocity: High vs Low Curvature Regions",
              label=["High κ" "Low κ"],
              linewidth=2,
              size=(800, 600))

    savefig(p2, joinpath(output_dir, "velocity_by_curvature_region.png"))

    println("Curvature region analysis:")
    println("  Final % in high κ: $(round(n_high_curv[end]/N*100, digits=1))%")
    println("  Mean v (high κ): $(round(mean_v_high[end], digits=3))")
    println("  Mean v (low κ): $(round(mean_v_low[end], digits=3))")
end

# ========================================
# Main Execution
# ========================================

if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) < 1
        println("Usage: julia analyze_full_phase_space.jl <seed_directory>")
        println()
        println("Example:")
        println("  julia analyze_full_phase_space.jl results/campaign_EN_scan_*/e0.866_N40_phi0.06_E0.32/seed_1/")
        exit(1)
    end

    seed_dir = ARGS[1]
    hdf5_file = joinpath(seed_dir, "trajectories.h5")

    if !isfile(hdf5_file)
        error("HDF5 file not found: $hdf5_file")
    end

    # Snapshot times to analyze
    snapshot_times = [1.0, 10.0, 25.0, 50.0, 100.0]

    # Run phase space analysis
    println("PART 1: Phase Space Evolution")
    println("="^70)
    output_dir1 = analyze_phase_space_evolution(hdf5_file, snapshot_times)

    println()
    println("PART 2: Geometric Clustering Mechanism")
    println("="^70)
    output_dir2 = analyze_clustering_mechanism_geometry(hdf5_file)

    println()
    println("="^70)
    println("Analysis Complete!")
    println("="^70)
    println()
    println("Results:")
    println("  Phase space: $output_dir1")
    println("  Mechanism: $output_dir2")
end
