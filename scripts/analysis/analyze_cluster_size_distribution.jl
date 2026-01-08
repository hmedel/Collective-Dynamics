#!/usr/bin/env julia
"""
Cluster Size Distribution Analysis

Analyzes the distribution of cluster sizes over time to characterize:
- Cluster formation dynamics
- Size distribution evolution
- Scaling behavior
- Comparison with theoretical predictions (e.g., power laws)

Scientific Questions:
1. What is the cluster size distribution P(s,t) at time t?
2. Does it follow a power law P(s) ~ s^(-τ) near critical point?
3. How does the largest cluster size s_max evolve?
4. What is the typical cluster size <s> vs time?

Usage:
    julia analyze_cluster_size_distribution.jl results/campaign_EN_scan_*/e0.866_N40_phi0.06_E0.32/
"""

using HDF5
using JSON
using Statistics
using DataFrames
using CSV
using Plots
using Printf

include("src/coarsening_analysis.jl")

"""
    load_cluster_data(hdf5_file::String)

Load cluster size time series from HDF5 file.

Returns:
- t: time points
- N_clusters: number of clusters at each time
- cluster_sizes: array of cluster size distributions at each time
"""
function load_cluster_data(hdf5_file::String)
    h5open(hdf5_file, "r") do file
        if !haskey(file, "analysis/clustering")
            error("No clustering analysis found in $hdf5_file")
        end

        t = read(file, "analysis/time")
        N_clusters = read(file, "analysis/clustering/N_clusters")

        # Cluster sizes stored as ragged array - load as vector of vectors
        cluster_sizes = []
        if haskey(file, "analysis/clustering/cluster_sizes")
            # Try to reconstruct from stored format
            # (This may need adjustment based on actual HDF5 structure)
            n_times = length(t)
            for i in 1:n_times
                # Placeholder - actual implementation depends on storage format
                push!(cluster_sizes, Int[])
            end
        end

        return t, N_clusters, cluster_sizes
    end
end

"""
    compute_size_distribution_snapshots(hdf5_file::String, snapshot_times::Vector{Float64})

Compute cluster size distributions at specific snapshot times.

Returns DataFrame with columns:
- time: snapshot time
- cluster_size: size of each cluster
- count: number of clusters of this size
"""
function compute_size_distribution_snapshots(hdf5_file::String, snapshot_times::Vector{Float64})
    # Load full trajectory
    h5open(hdf5_file, "r") do file
        t = read(file, "trajectories/time")
        phi = read(file, "trajectories/phi")  # [N, n_snapshots]

        N, n_snapshots = size(phi)

        distributions = DataFrame()

        for t_snap in snapshot_times
            # Find closest time index
            idx = argmin(abs.(t .- t_snap))
            actual_time = t[idx]

            # Get positions at this time
            phi_snap = phi[:, idx]

            # Detect clusters using spatial proximity
            clusters = detect_clusters_simple(phi_snap, threshold=0.1)

            # Count cluster sizes
            size_counts = countmap(length.(clusters))

            for (size, count) in size_counts
                push!(distributions, (
                    time = actual_time,
                    cluster_size = size,
                    count = count
                ))
            end
        end

        return distributions
    end
end

"""
    detect_clusters_simple(phi::Vector{Float64}, threshold::Float64)

Simple cluster detection based on angular distance threshold.

Returns vector of clusters, where each cluster is a vector of particle indices.
"""
function detect_clusters_simple(phi::Vector{Float64}, threshold::Float64)
    N = length(phi)
    visited = falses(N)
    clusters = Vector{Int}[]

    for i in 1:N
        if visited[i]
            continue
        end

        # Start new cluster
        cluster = [i]
        visited[i] = true
        queue = [i]

        while !isempty(queue)
            current = popfirst!(queue)

            for j in 1:N
                if visited[j]
                    continue
                end

                # Calculate angular distance (periodic boundary)
                dist = min(abs(phi[current] - phi[j]),
                          2π - abs(phi[current] - phi[j]))

                if dist < threshold
                    push!(cluster, j)
                    push!(queue, j)
                    visited[j] = true
                end
            end
        end

        push!(clusters, cluster)
    end

    return clusters
end

"""
    analyze_ensemble_cluster_distributions(ensemble_dir::String, snapshot_times::Vector{Float64})

Analyze cluster size distributions across an ensemble of simulations.

Returns:
- DataFrame with ensemble statistics
- Plots of size distributions
"""
function analyze_ensemble_cluster_distributions(ensemble_dir::String,
                                                snapshot_times::Vector{Float64})
    println("="^70)
    println("Cluster Size Distribution Analysis")
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

    # Collect distributions from all seeds
    all_distributions = DataFrame()

    for (i, seed_dir) in enumerate(seed_dirs)
        hdf5_file = joinpath(seed_dir, "trajectory.h5")

        if !isfile(hdf5_file)
            @warn "Skipping $seed_dir - no trajectory.h5"
            continue
        end

        println("[$i/$n_seeds] Processing: $(basename(seed_dir))")

        try
            df = compute_size_distribution_snapshots(hdf5_file, snapshot_times)
            df[!, :seed] .= parse(Int, match(r"seed_(\d+)", basename(seed_dir))[1])
            append!(all_distributions, df)
        catch e
            @warn "Error processing $seed_dir: $e"
        end
    end

    if isempty(all_distributions)
        error("No data collected!")
    end

    println()
    println("Collected $(nrow(all_distributions)) data points")
    println()

    # Compute ensemble statistics
    stats = combine(groupby(all_distributions, [:time, :cluster_size]),
                   :count => mean => :mean_count,
                   :count => std => :std_count,
                   :count => length => :n_samples)

    # Save results
    output_dir = joinpath(ensemble_dir, "cluster_size_analysis")
    mkpath(output_dir)

    CSV.write(joinpath(output_dir, "size_distributions_raw.csv"), all_distributions)
    CSV.write(joinpath(output_dir, "size_distributions_stats.csv"), stats)

    println("Saved raw data and statistics to: $output_dir")

    # Generate plots
    plot_cluster_size_distributions(stats, snapshot_times, output_dir)

    return stats
end

"""
    plot_cluster_size_distributions(stats::DataFrame, snapshot_times::Vector{Float64},
                                    output_dir::String)

Create visualization of cluster size distributions.
"""
function plot_cluster_size_distributions(stats::DataFrame, snapshot_times::Vector{Float64},
                                        output_dir::String)
    println()
    println("Generating plots...")

    # Plot 1: Size distribution at each snapshot time
    p1 = plot(title="Cluster Size Distribution Evolution",
              xlabel="Cluster Size s",
              ylabel="Count (ensemble average)",
              xscale=:log10,
              yscale=:log10,
              legend=:topright)

    colors = [:blue, :green, :orange, :red, :purple]

    for (i, t_snap) in enumerate(snapshot_times)
        subset = filter(row -> row.time ≈ t_snap, stats)

        if !isempty(subset)
            sort!(subset, :cluster_size)

            plot!(p1, subset.cluster_size, subset.mean_count,
                  label="t = $(round(t_snap, digits=1))s",
                  marker=:circle,
                  color=colors[mod(i-1, length(colors))+1],
                  linewidth=2)
        end
    end

    # Add power law reference
    s_ref = 1:20
    plot!(p1, s_ref, 10 .* s_ref.^(-2),
          label="s^(-2) reference",
          linestyle=:dash,
          color=:black,
          linewidth=1.5)

    savefig(p1, joinpath(output_dir, "size_distribution_evolution.png"))
    println("  ✓ Saved: size_distribution_evolution.png")

    # Plot 2: Largest cluster fraction vs time
    # (Requires loading additional data)

    # Plot 3: Mean cluster size vs time
    # (Requires loading additional data)

    println()
    println("Plots saved to: $output_dir")
end

"""
    test_power_law_fit(sizes::Vector{Int}, counts::Vector{Float64})

Test if cluster size distribution follows power law P(s) ~ s^(-τ).

Returns:
- exponent τ
- goodness of fit R²
"""
function test_power_law_fit(sizes::Vector{Int}, counts::Vector{Float64})
    # Filter out zeros and sizes < 2
    valid = (counts .> 0) .& (sizes .>= 2)
    s = sizes[valid]
    c = counts[valid]

    if length(s) < 3
        return NaN, NaN
    end

    # Log-log linear fit
    log_s = log10.(s)
    log_c = log10.(c)

    # Linear regression
    n = length(log_s)
    Σx = sum(log_s)
    Σy = sum(log_c)
    Σxy = sum(log_s .* log_c)
    Σx² = sum(log_s.^2)

    τ = -(n * Σxy - Σx * Σy) / (n * Σx² - Σx^2)  # Negative for P(s) ~ s^(-τ)
    intercept = (Σy - (-τ) * Σx) / n

    # R² goodness of fit
    y_pred = @. intercept - τ * log_s
    ss_res = sum((log_c .- y_pred).^2)
    ss_tot = sum((log_c .- mean(log_c)).^2)
    R² = 1 - ss_res / ss_tot

    return τ, R²
end

# ========================================
# Main Execution
# ========================================

if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) < 1
        println("Usage: julia analyze_cluster_size_distribution.jl <ensemble_dir>")
        println()
        println("Example:")
        println("  julia analyze_cluster_size_distribution.jl results/campaign_EN_scan_*/e0.866_N40_phi0.06_E0.32/")
        exit(1)
    end

    ensemble_dir = ARGS[1]

    # Snapshot times to analyze
    snapshot_times = [1.0, 10.0, 25.0, 50.0, 100.0]  # s

    # Run analysis
    stats = analyze_ensemble_cluster_distributions(ensemble_dir, snapshot_times)

    println()
    println("="^70)
    println("Analysis Complete!")
    println("="^70)
    println()
    println("Results saved to: $(ensemble_dir)/cluster_size_analysis/")
end
