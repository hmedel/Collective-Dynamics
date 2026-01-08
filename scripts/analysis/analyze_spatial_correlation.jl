#!/usr/bin/env julia
"""
Spatial Correlation Function g(r) Analysis

Computes the pair correlation function g(r) to characterize spatial structure:
- g(r) = 1: Random (gas-like)
- g(r) > 1 at small r: Clustering (liquid/crystal)
- g(r) with peaks: Ordered structure (crystal)

For particles on a circle/ellipse, we use angular distance:
- r = |φ_i - φ_j| (minimum distance on periodic domain)
- Normalize by random expectation

Scientific Questions:
1. How does g(r) evolve during cluster formation?
2. Are there characteristic length scales (peaks in g(r))?
3. Does the system show short-range or long-range order?
4. How does g(r) depend on E/N and eccentricity?

Usage:
    julia analyze_spatial_correlation.jl results/campaign_EN_scan_*/e0.866_N40_phi0.06_E0.32/
"""

using HDF5
using JSON
using Statistics
using DataFrames
using CSV
using Plots
using Printf

"""
    compute_angular_correlation(phi::Vector{Float64}, n_bins::Int=50)

Compute pair correlation function g(r) for angular positions.

For N particles on a circle at angles φ_i, compute:
- Pairwise angular distances: r_ij = min(|φ_i - φ_j|, 2π - |φ_i - φ_j|)
- Histogram of distances
- Normalize by random expectation: g(r) = ρ(r) / ρ_random(r)

Returns:
- r_bins: bin centers
- g_r: correlation function values
"""
function compute_angular_correlation(phi::Vector{Float64}, n_bins::Int=50)
    N = length(phi)

    # Calculate all pairwise angular distances
    distances = Float64[]
    for i in 1:N
        for j in (i+1):N
            # Angular distance (periodic)
            d = abs(phi[i] - phi[j])
            d_min = min(d, 2π - d)
            push!(distances, d_min)
        end
    end

    # Create histogram
    r_max = π  # Maximum distance on circle is π
    bin_edges = range(0, r_max, length=n_bins+1)
    r_bins = (bin_edges[1:end-1] .+ bin_edges[2:end]) ./ 2

    # Count pairs in each bin
    counts = zeros(Int, n_bins)
    for d in distances
        bin = searchsortedfirst(bin_edges, d) - 1
        if bin >= 1 && bin <= n_bins
            counts[bin] += 1
        end
    end

    # Normalize by expected count for uniform random distribution
    # For angular distance r, the "volume" element is ∝ r (arc length)
    # But on a circle, the expected number of pairs at distance r is constant
    # Expected pairs in bin [r, r+dr]: (N choose 2) × (2·dr / 2π)

    total_pairs = N * (N - 1) / 2
    dr = bin_edges[2] - bin_edges[1]

    # Expected count per bin (uniform distribution)
    expected_counts = total_pairs * (2 * dr / (2π))

    # Correlation function
    g_r = counts ./ expected_counts

    # Handle edge effects: very small bins may have zero expected count
    g_r[expected_counts .< 0.1] .= NaN

    return r_bins, g_r
end

"""
    analyze_correlation_evolution(hdf5_file::String, snapshot_times::Vector{Float64})

Compute g(r) at multiple time snapshots.

Returns DataFrame with columns:
- time: snapshot time
- r: angular distance
- g_r: correlation function value
"""
function analyze_correlation_evolution(hdf5_file::String, snapshot_times::Vector{Float64};
                                       n_bins::Int=30)
    h5open(hdf5_file, "r") do file
        t = read(file, "trajectories/time")
        phi = read(file, "trajectories/phi")  # [N, n_snapshots]

        results = DataFrame()

        for t_snap in snapshot_times
            # Find closest time index
            idx = argmin(abs.(t .- t_snap))
            actual_time = t[idx]

            # Get positions at this time
            phi_snap = phi[:, idx]

            # Compute g(r)
            r_bins, g_r = compute_angular_correlation(phi_snap, n_bins)

            # Store results
            for (r, g) in zip(r_bins, g_r)
                push!(results, (
                    time = actual_time,
                    r = r,
                    g_r = g
                ))
            end
        end

        return results
    end
end

"""
    analyze_ensemble_correlations(ensemble_dir::String, snapshot_times::Vector{Float64})

Compute ensemble-averaged g(r) at multiple times.

Returns DataFrame with ensemble statistics.
"""
function analyze_ensemble_correlations(ensemble_dir::String,
                                      snapshot_times::Vector{Float64};
                                      n_bins::Int=30)
    println("="^70)
    println("Spatial Correlation Function g(r) Analysis")
    println("="^70)
    println("Directory: $ensemble_dir")
    println("Snapshot times: $snapshot_times")
    println()

    # Find all seed directories
    seed_dirs = filter(isdir, readdir(ensemble_dir, join=true))
    seed_dirs = filter(d -> occursin("seed_", basename(d)), seed_dirs)
    n_seeds = length(seed_dirs)

    if n_seeds == 0
        error("No seed directories found in $ensemble_dir")
    end

    println("Found $n_seeds ensemble members")
    println()

    # Collect correlations from all seeds
    all_correlations = DataFrame()

    for (i, seed_dir) in enumerate(seed_dirs)
        hdf5_file = joinpath(seed_dir, "trajectory.h5")

        if !isfile(hdf5_file)
            @warn "Skipping $seed_dir - no trajectory.h5"
            continue
        end

        println("[$i/$n_seeds] Processing: $(basename(seed_dir))")

        try
            df = analyze_correlation_evolution(hdf5_file, snapshot_times, n_bins=n_bins)
            df[!, :seed] .= parse(Int, match(r"seed_(\d+)", basename(seed_dir))[1])
            append!(all_correlations, df)
        catch e
            @warn "Error processing $seed_dir: $e"
        end
    end

    if isempty(all_correlations)
        error("No data collected!")
    end

    println()
    println("Collected $(nrow(all_correlations)) data points")
    println()

    # Compute ensemble statistics
    stats = combine(groupby(all_correlations, [:time, :r]),
                   :g_r => mean => :mean_g_r,
                   :g_r => std => :std_g_r,
                   :g_r => (x -> std(x)/sqrt(length(x))) => :sem_g_r,
                   :g_r => length => :n_samples)

    # Save results
    output_dir = joinpath(ensemble_dir, "spatial_correlation_analysis")
    mkpath(output_dir)

    CSV.write(joinpath(output_dir, "correlations_raw.csv"), all_correlations)
    CSV.write(joinpath(output_dir, "correlations_stats.csv"), stats)

    println("Saved raw data and statistics to: $output_dir")

    # Generate plots
    plot_correlation_functions(stats, snapshot_times, output_dir)

    return stats
end

"""
    plot_correlation_functions(stats::DataFrame, snapshot_times::Vector{Float64},
                               output_dir::String)

Create visualization of g(r) evolution.
"""
function plot_correlation_functions(stats::DataFrame, snapshot_times::Vector{Float64},
                                   output_dir::String)
    println()
    println("Generating plots...")

    # Plot 1: g(r) at each snapshot time
    p1 = plot(title="Pair Correlation Function g(r) Evolution",
              xlabel="Angular Distance r (radians)",
              ylabel="g(r)",
              legend=:topright,
              ylims=(0, 5))

    # Add reference line for random distribution
    hline!(p1, [1.0], label="Random (g=1)", color=:black,
           linestyle=:dash, linewidth=2)

    colors = [:blue, :green, :orange, :red, :purple]

    for (i, t_snap) in enumerate(snapshot_times)
        subset = filter(row -> row.time ≈ t_snap, stats)

        if !isempty(subset)
            sort!(subset, :r)

            # Plot with error bands
            plot!(p1, subset.r, subset.mean_g_r,
                  ribbon=subset.std_g_r,
                  label="t = $(round(t_snap, digits=1))s",
                  color=colors[mod(i-1, length(colors))+1],
                  linewidth=2,
                  fillalpha=0.2)
        end
    end

    savefig(p1, joinpath(output_dir, "correlation_function_evolution.png"))
    println("  ✓ Saved: correlation_function_evolution.png")

    # Plot 2: Peak height vs time (measure of clustering strength)
    peak_heights = DataFrame()

    for t_snap in snapshot_times
        subset = filter(row -> row.time ≈ t_snap, stats)

        if !isempty(subset)
            # Find peak in small r region (r < π/2)
            small_r = filter(row -> row.r < π/2, subset)

            if !isempty(small_r)
                peak_g = maximum(small_r.mean_g_r)
                peak_r = small_r.r[argmax(small_r.mean_g_r)]

                push!(peak_heights, (
                    time = subset.time[1],
                    peak_g = peak_g,
                    peak_r = peak_r
                ))
            end
        end
    end

    if !isempty(peak_heights)
        p2 = plot(peak_heights.time, peak_heights.peak_g,
                  xlabel="Time (s)",
                  ylabel="Peak g(r) Height",
                  title="Clustering Strength vs Time",
                  marker=:circle,
                  linewidth=2,
                  legend=false)

        hline!(p2, [1.0], color=:black, linestyle=:dash, label="Random")

        savefig(p2, joinpath(output_dir, "clustering_strength_vs_time.png"))
        println("  ✓ Saved: clustering_strength_vs_time.png")
    end

    # Plot 3: Heatmap of g(r) vs time
    # Extract unique r and time values
    r_values = sort(unique(stats.r))
    t_values = sort(unique(stats.time))

    n_r = length(r_values)
    n_t = length(t_values)

    g_matrix = fill(NaN, n_r, n_t)

    for row in eachrow(stats)
        i_r = findfirst(==(row.r), r_values)
        i_t = findfirst(==(row.time), t_values)

        if !isnothing(i_r) && !isnothing(i_t)
            g_matrix[i_r, i_t] = row.mean_g_r
        end
    end

    p3 = heatmap(t_values, r_values, g_matrix,
                 xlabel="Time (s)",
                 ylabel="Angular Distance r (radians)",
                 title="g(r,t) Evolution",
                 color=:thermal,
                 clims=(0, 3))

    savefig(p3, joinpath(output_dir, "correlation_heatmap.png"))
    println("  ✓ Saved: correlation_heatmap.png")

    println()
    println("Plots saved to: $output_dir")
end

"""
    extract_correlation_length(r::Vector{Float64}, g_r::Vector{Float64})

Estimate correlation length ξ from g(r).

Correlation length defined as:
- First zero crossing of (g(r) - 1)
- Or exponential decay length if g(r) ~ exp(-r/ξ)

Returns correlation length ξ (NaN if cannot be determined).
"""
function extract_correlation_length(r::Vector{Float64}, g_r::Vector{Float64})
    # Find first crossing of g(r) = 1 after initial peak
    for i in 2:length(r)
        if g_r[i] < 1.0 && g_r[i-1] > 1.0
            # Linear interpolation
            ξ = r[i-1] + (1.0 - g_r[i-1]) / (g_r[i] - g_r[i-1]) * (r[i] - r[i-1])
            return ξ
        end
    end

    return NaN
end

# ========================================
# Main Execution
# ========================================

if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) < 1
        println("Usage: julia analyze_spatial_correlation.jl <ensemble_dir>")
        println()
        println("Example:")
        println("  julia analyze_spatial_correlation.jl results/campaign_EN_scan_*/e0.866_N40_phi0.06_E0.32/")
        exit(1)
    end

    ensemble_dir = ARGS[1]

    # Snapshot times to analyze
    snapshot_times = [1.0, 10.0, 25.0, 50.0, 100.0]  # s

    # Run analysis
    stats = analyze_ensemble_correlations(ensemble_dir, snapshot_times, n_bins=30)

    println()
    println("="^70)
    println("Analysis Complete!")
    println("="^70)
    println()
    println("Results saved to: $(ensemble_dir)/spatial_correlation_analysis/")
end
