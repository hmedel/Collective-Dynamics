#!/usr/bin/env julia
"""
Partial Analysis of E/N Scan Campaign

Analyzes completed simulations from an ongoing campaign.
Can be run periodically to see emerging trends.

Usage:
    julia --project=. scripts/analysis/analyze_EN_scan_partial.jl <campaign_dir>
"""

using Pkg
Pkg.activate(".")

using Statistics
using Printf
using DataFrames
using CSV
using JSON

# ============================================================================
# Analysis Functions
# ============================================================================

"""
Load summary.json from a simulation directory
"""
function load_summary(dir::String)
    json_file = joinpath(dir, "summary.json")
    !isfile(json_file) && return nothing

    try
        return JSON.parsefile(json_file)
    catch
        return nothing
    end
end

"""
Extract parameters from directory name (e.g., e0.87_N040_E0.05_seed01)
"""
function extract_params(dirname::String)
    params = Dict{String, Any}()

    m = match(r"e(\d+\.?\d*)", dirname)
    m !== nothing && (params["e"] = parse(Float64, m.captures[1]))

    m = match(r"N(\d+)", dirname)
    m !== nothing && (params["N"] = parse(Int, m.captures[1]))

    m = match(r"E(\d+\.?\d*)", dirname)
    m !== nothing && (params["E_per_N"] = parse(Float64, m.captures[1]))

    m = match(r"seed(\d+)", dirname)
    m !== nothing && (params["seed"] = parse(Int, m.captures[1]))

    return params
end

# ============================================================================
# Main Analysis
# ============================================================================

function main()
    if length(ARGS) < 1
        println("Usage: julia --project=. scripts/analysis/analyze_EN_scan_partial.jl <campaign_dir>")
        return
    end

    campaign_dir = ARGS[1]

    if !isdir(campaign_dir)
        println("ERROR: Directory not found: $campaign_dir")
        return
    end

    println("="^70)
    println("PARTIAL E/N SCAN ANALYSIS")
    println("="^70)
    println("Campaign: $campaign_dir")
    println()

    # Find all simulation directories
    subdirs = filter(d -> isdir(joinpath(campaign_dir, d)), readdir(campaign_dir))
    sim_dirs = filter(d -> startswith(d, "e"), subdirs)

    println("Total simulation directories: $(length(sim_dirs))")

    # Find completed simulations (have summary.json)
    completed = filter(d -> isfile(joinpath(campaign_dir, d, "summary.json")), sim_dirs)

    println("Completed simulations: $(length(completed))")
    println()

    if isempty(completed)
        println("No simulations completed yet. Check back later.")
        return
    end

    # Collect results
    results = DataFrame()

    for sim_dir in completed
        summary = load_summary(joinpath(campaign_dir, sim_dir))
        summary === nothing && continue

        params = extract_params(sim_dir)

        row = Dict{String, Any}("sim_dir" => sim_dir)
        merge!(row, params)

        # Extract key metrics from summary
        row["sigma_phi_final"] = get(summary, "phi_std_final", NaN)
        row["is_clustered"] = get(summary, "is_clustered", false)
        row["total_collisions"] = get(summary, "total_collisions", 0)
        row["dE_E0"] = get(summary, "dE_E0", NaN)
        row["wall_time"] = get(summary, "wall_time_seconds", NaN)

        push!(results, row; cols=:union)
    end

    println("Analyzed $(nrow(results)) completed simulations")
    println()

    # ========================================================================
    # Summary by E/N
    # ========================================================================

    if "E_per_N" in names(results) && nrow(results) > 0
        println("="^70)
        println("RESULTS BY E/N (Effective Temperature)")
        println("="^70)
        println()

        for E_N in sort(unique(results.E_per_N))
            subset = filter(row -> row.E_per_N == E_N, results)
            n = nrow(subset)

            if n > 0
                # Check for sigma_phi_final column
                if "sigma_phi_final" in names(subset) && !all(ismissing, subset.sigma_phi_final)
                    valid_sigma = filter(x -> !ismissing(x) && !isnan(x), subset.sigma_phi_final)
                    if !isempty(valid_sigma)
                        sigma_mean = mean(valid_sigma)
                        sigma_std = length(valid_sigma) > 1 ? std(valid_sigma) : 0.0
                    else
                        sigma_mean = NaN
                        sigma_std = NaN
                    end
                else
                    sigma_mean = NaN
                    sigma_std = NaN
                end

                # Count clustered
                if "is_clustered" in names(subset)
                    n_clustered = count(x -> x === true, subset.is_clustered)
                else
                    n_clustered = 0
                end

                # Average wall time
                if "wall_time" in names(subset)
                    valid_times = filter(x -> !ismissing(x) && !isnan(x), subset.wall_time)
                    wall_time_avg = !isempty(valid_times) ? mean(valid_times) : NaN
                else
                    wall_time_avg = NaN
                end

                println(@sprintf("E/N = %.2f (n=%d completed)", E_N, n))
                println(@sprintf("  σ_φ (final): %.3f ± %.3f", sigma_mean, sigma_std))
                println(@sprintf("  Clustered: %d/%d (%.0f%%)", n_clustered, n, 100*n_clustered/n))
                if !isnan(wall_time_avg)
                    println(@sprintf("  Avg wall time: %.1f s", wall_time_avg))
                end
                println()
            end
        end
    end

    # ========================================================================
    # Summary by Eccentricity
    # ========================================================================

    if "e" in names(results) && nrow(results) > 0
        println("="^70)
        println("RESULTS BY ECCENTRICITY")
        println("="^70)
        println()

        for e in sort(unique(results.e))
            subset = filter(row -> row.e == e, results)
            n = nrow(subset)

            if n > 0
                if "is_clustered" in names(subset)
                    n_clustered = count(x -> x === true, subset.is_clustered)
                else
                    n_clustered = 0
                end

                println(@sprintf("e = %.2f: %d completed, %d clustered (%.0f%%)",
                    e, n, n_clustered, 100*n_clustered/n))
            end
        end
    end

    # ========================================================================
    # Progress Summary
    # ========================================================================

    println()
    println("="^70)
    println("CAMPAIGN PROGRESS")
    println("="^70)
    println(@sprintf("Completed: %d / %d (%.1f%%)",
        length(completed), length(sim_dirs), 100*length(completed)/length(sim_dirs)))

    # Estimate time remaining
    if "wall_time" in names(results) && nrow(results) > 0
        valid_times = filter(x -> !ismissing(x) && !isnan(x), results.wall_time)
        if !isempty(valid_times)
            avg_time = mean(valid_times)
            remaining = length(sim_dirs) - length(completed)
            # Assuming 24 parallel jobs
            estimated_remaining_s = (remaining / 24) * avg_time
            estimated_remaining_h = estimated_remaining_s / 3600

            println(@sprintf("Average wall time: %.1f s per simulation", avg_time))
            println(@sprintf("Estimated time remaining: %.1f hours (with 24 jobs)", estimated_remaining_h))
        end
    end

    # Save partial results
    output_file = joinpath(campaign_dir, "partial_analysis.csv")
    CSV.write(output_file, results)
    println()
    println("Saved partial results to: $output_file")
end

main()
