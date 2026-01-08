#!/usr/bin/env julia
"""
Ensemble Analysis: Aggregate Results Across Seeds

Analyzes all runs for a specific parameter combination (e, N, φ, E/N)
and computes ensemble statistics with error bars.

Usage:
    julia --project=. analyze_ensemble.jl results/campaign_main/e0.866_N040_phi0.06_E0.32
"""

using Statistics, StatsBase
using CSV, DataFrames
using JSON
using HDF5
using Plots
using Interpolations

include("src/io_hdf5.jl")
include("src/coarsening_analysis.jl")

"""
    find_seed_directories(combo_dir::String)

Find all seed_XXXX subdirectories in a parameter combination directory.
"""
function find_seed_directories(combo_dir::String)
    if !isdir(combo_dir)
        error("Directory not found: $combo_dir")
    end

    seed_dirs = String[]
    for item in readdir(combo_dir, join=true)
        if isdir(item) && occursin(r"seed_\d+", basename(item))
            push!(seed_dirs, item)
        end
    end

    sort!(seed_dirs)
    return seed_dirs
end

"""
    load_run_summary(seed_dir::String)

Load summary.json from a seed directory.
"""
function load_run_summary(seed_dir::String)
    json_file = joinpath(seed_dir, "summary.json")
    if !isfile(json_file)
        @warn "Summary not found: $json_file"
        return nothing
    end

    return JSON.parsefile(json_file)
end

"""
    aggregate_timescales(summaries::Vector)

Compute ensemble statistics for timescales.
"""
function aggregate_timescales(summaries::Vector)
    # Extract timescales from all runs
    t_nucleation = [s["timescales"]["t_nucleation"] for s in summaries if !isnan(s["timescales"]["t_nucleation"])]
    t_half = [s["timescales"]["t_half"] for s in summaries if !isnan(s["timescales"]["t_half"])]
    t_cluster = [s["timescales"]["t_cluster"] for s in summaries if !isnan(s["timescales"]["t_cluster"])]

    function stats(data)
        if isempty(data)
            return (mean=NaN, std=NaN, sem=NaN, min=NaN, max=NaN, n=0)
        end
        n = length(data)
        m = mean(data)
        s = std(data)
        return (mean=m, std=s, sem=s/sqrt(n), min=minimum(data), max=maximum(data), n=n)
    end

    return (
        t_nucleation = stats(t_nucleation),
        t_half = stats(t_half),
        t_cluster = stats(t_cluster)
    )
end

"""
    aggregate_growth_exponents(summaries::Vector)

Compute ensemble statistics for growth exponents.
"""
function aggregate_growth_exponents(summaries::Vector)
    alphas = Float64[]
    R_squareds = Float64[]

    for s in summaries
        alpha = s["growth_exponent"]["alpha"]
        R2 = s["growth_exponent"]["R_squared"]

        if !isnan(alpha) && !isnan(R2) && R2 > 0.8  # Only good fits
            push!(alphas, alpha)
            push!(R_squareds, R2)
        end
    end

    if isempty(alphas)
        return (mean=NaN, std=NaN, sem=NaN, n=0, R2_mean=NaN)
    end

    n = length(alphas)
    alpha_mean = mean(alphas)
    alpha_std = std(alphas)
    alpha_sem = alpha_std / sqrt(n)
    R2_mean = mean(R_squareds)

    return (mean=alpha_mean, std=alpha_std, sem=alpha_sem, n=n, R2_mean=R2_mean)
end

"""
    aggregate_final_states(summaries::Vector)

Compute ensemble statistics for final states.
"""
function aggregate_final_states(summaries::Vector)
    N_clusters = [s["final_state"]["N_clusters"] for s in summaries]
    sigma_phi = [s["final_state"]["sigma_phi"] for s in summaries]

    # Fraction that fully clustered (N_clusters == 1)
    frac_clustered = count(n -> n == 1, N_clusters) / length(N_clusters)

    return (
        N_clusters_mean = mean(N_clusters),
        N_clusters_std = std(N_clusters),
        sigma_phi_mean = mean(sigma_phi),
        sigma_phi_std = std(sigma_phi),
        fraction_fully_clustered = frac_clustered
    )
end

"""
    plot_ensemble_time_series(seed_dirs, output_dir)

Plot ensemble-averaged time series with error bands.
"""
function plot_ensemble_time_series(seed_dirs, output_dir)
    println("Loading time series from $(length(seed_dirs)) runs...")

    # Load all evolution data
    all_times = Vector{Float64}[]
    all_N_clusters = Vector{Int}[]
    all_s_max = Vector{Int}[]

    for seed_dir in seed_dirs
        csv_file = joinpath(seed_dir, "cluster_evolution.csv")
        if !isfile(csv_file)
            continue
        end

        df = CSV.read(csv_file, DataFrame)
        push!(all_times, df.time)
        push!(all_N_clusters, df.N_clusters)
        push!(all_s_max, df.s_max)
    end

    if isempty(all_times)
        @warn "No evolution data found"
        return
    end

    # Find common time grid (interpolate to uniform grid)
    t_min = maximum(first.(all_times))
    t_max = minimum(last.(all_times))
    t_grid = range(t_min, t_max, length=200)

    # Interpolate all runs to common grid
    N_clusters_interpolated = []
    s_max_interpolated = []

    for (times, N_c, s_m) in zip(all_times, all_N_clusters, all_s_max)
        # Linear interpolation
        itp_N = LinearInterpolation(times, N_c, extrapolation_bc=Line())
        itp_s = LinearInterpolation(times, s_m, extrapolation_bc=Line())

        push!(N_clusters_interpolated, itp_N.(t_grid))
        push!(s_max_interpolated, itp_s.(t_grid))
    end

    # Compute mean and std at each time point
    N_c_mean = [mean([run[i] for run in N_clusters_interpolated]) for i in 1:length(t_grid)]
    N_c_std = [std([run[i] for run in N_clusters_interpolated]) for i in 1:length(t_grid)]

    s_max_mean = [mean([run[i] for run in s_max_interpolated]) for i in 1:length(t_grid)]
    s_max_std = [std([run[i] for run in s_max_interpolated]) for i in 1:length(t_grid)]

    # Plot with error bands
    p1 = plot(t_grid, N_c_mean, ribbon=N_c_std, fillalpha=0.3,
              label="Mean ± σ", xlabel="Time (s)", ylabel="Number of Clusters",
              title="Cluster Count Evolution ($(length(seed_dirs)) runs)",
              linewidth=2, legend=:topright)

    # Overlay individual runs (transparent)
    for N_c_run in N_clusters_interpolated[1:min(10, end)]
        plot!(p1, t_grid, N_c_run, alpha=0.2, label="", color=:gray)
    end

    p2 = plot(t_grid, s_max_mean, ribbon=s_max_std, fillalpha=0.3,
              label="Mean ± σ", xlabel="Time (s)", ylabel="Maximum Cluster Size",
              title="Cluster Growth ($(length(seed_dirs)) runs)",
              linewidth=2, legend=:bottomright)

    # Overlay individual runs
    for s_max_run in s_max_interpolated[1:min(10, end)]
        plot!(p2, t_grid, s_max_run, alpha=0.2, label="", color=:gray)
    end

    # Save
    mkpath(output_dir)
    savefig(p1, joinpath(output_dir, "ensemble_N_clusters.png"))
    savefig(p2, joinpath(output_dir, "ensemble_s_max.png"))

    println("Saved ensemble plots to $output_dir")

    return (p1, p2)
end

"""
    analyze_ensemble(combo_dir::String)

Complete ensemble analysis for one parameter combination.
"""
function analyze_ensemble(combo_dir::String)
    println("="^70)
    println("Ensemble Analysis")
    println("="^70)
    println("Directory: $combo_dir")
    println()

    # Find all seed directories
    seed_dirs = find_seed_directories(combo_dir)
    n_seeds = length(seed_dirs)

    if n_seeds == 0
        error("No seed directories found in $combo_dir")
    end

    println("Found $n_seeds seed runs")

    # Load all summaries
    println("\nLoading summaries...")
    summaries = []
    for seed_dir in seed_dirs
        summary = load_run_summary(seed_dir)
        if summary !== nothing
            push!(summaries, summary)
        end
    end

    println("Loaded $(length(summaries)) summaries")

    if isempty(summaries)
        error("No valid summaries found")
    end

    # Aggregate statistics
    println("\nComputing ensemble statistics...")

    timescales = aggregate_timescales(summaries)
    growth = aggregate_growth_exponents(summaries)
    final_state = aggregate_final_states(summaries)

    # Display results
    println("\n" * "="^70)
    println("ENSEMBLE RESULTS (n=$(length(summaries)))")
    println("="^70)

    println("\nTimescales:")
    println("  t_nucleation: $(round(timescales.t_nucleation.mean, digits=2)) ± $(round(timescales.t_nucleation.sem, digits=2))s (n=$(timescales.t_nucleation.n))")
    println("  t_1/2:        $(round(timescales.t_half.mean, digits=2)) ± $(round(timescales.t_half.sem, digits=2))s (n=$(timescales.t_half.n))")
    println("  t_cluster:    $(round(timescales.t_cluster.mean, digits=2)) ± $(round(timescales.t_cluster.sem, digits=2))s (n=$(timescales.t_cluster.n))")

    println("\nGrowth Exponent:")
    println("  α:            $(round(growth.mean, digits=3)) ± $(round(growth.sem, digits=3)) (n=$(growth.n))")
    println("  R² (mean):    $(round(growth.R2_mean, digits=3))")

    println("\nFinal State:")
    println("  N_clusters:   $(round(final_state.N_clusters_mean, digits=1)) ± $(round(final_state.N_clusters_std, digits=1))")
    println("  σ_φ:          $(round(final_state.sigma_phi_mean, digits=3)) ± $(round(final_state.sigma_phi_std, digits=3))")
    println("  Fully clustered: $(round(final_state.fraction_fully_clustered * 100, digits=1))%")

    println("="^70)

    # Save ensemble summary
    ensemble_output_dir = joinpath(combo_dir, "ensemble_analysis")
    mkpath(ensemble_output_dir)

    ensemble_summary = Dict(
        "n_seeds" => length(summaries),
        "parameters" => summaries[1]["parameters"],
        "timescales" => Dict(
            "t_nucleation" => timescales.t_nucleation,
            "t_half" => timescales.t_half,
            "t_cluster" => timescales.t_cluster
        ),
        "growth_exponent" => growth,
        "final_state" => final_state
    )

    json_file = joinpath(ensemble_output_dir, "ensemble_summary.json")
    open(json_file, "w") do io
        JSON.print(io, ensemble_summary, 2)
    end
    println("\nSaved ensemble summary: $json_file")

    # Plot ensemble time series
    println("\nGenerating ensemble plots...")
    plot_ensemble_time_series(seed_dirs, ensemble_output_dir)

    return ensemble_summary
end

# ========================================
# Main Execution
# ========================================

if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) < 1
        println("Usage: julia analyze_ensemble.jl <combo_directory>")
        println("Example: julia analyze_ensemble.jl results/campaign/e0.866_N040_phi0.06_E0.32")
        exit(1)
    end

    combo_dir = ARGS[1]
    analyze_ensemble(combo_dir)
end
