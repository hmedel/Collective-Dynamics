#!/usr/bin/env julia
"""
Collision Rate Analysis

Analyzes how collision rates depend on N, eccentricity, and energy.
Important for understanding thermalization and energy exchange.

Usage:
    julia --project=. scripts/analysis/analyze_collision_rates.jl <campaign_dir>
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

function load_summary(dir::String)
    json_file = joinpath(dir, "summary.json")
    !isfile(json_file) && return nothing
    try
        return JSON.parsefile(json_file)
    catch
        return nothing
    end
end

function extract_params(dirname::String)
    params = Dict{String, Any}()
    m = match(r"e(\d+\.?\d*)", dirname)
    m !== nothing && (params["e"] = parse(Float64, m.captures[1]))
    m = match(r"N(\d+)", dirname)
    m !== nothing && (params["N"] = parse(Int, m.captures[1]))
    m = match(r"seed(\d+)", dirname)
    m !== nothing && (params["seed"] = parse(Int, m.captures[1]))
    return params
end

# ============================================================================
# Main Analysis
# ============================================================================

function main()
    length(ARGS) < 1 && (println("Usage: julia analyze_collision_rates.jl <dir>"); return)

    campaign_dir = ARGS[1]
    !isdir(campaign_dir) && (println("Not found: $campaign_dir"); return)

    println("="^60)
    println("COLLISION RATE ANALYSIS")
    println("="^60)
    println("Campaign: $campaign_dir\n")

    # Find simulations with summary.json
    subdirs = filter(d -> isdir(joinpath(campaign_dir, d)), readdir(campaign_dir))
    sim_dirs = filter(d -> isfile(joinpath(campaign_dir, d, "summary.json")), subdirs)

    println("Found $(length(sim_dirs)) completed simulations\n")

    if isempty(sim_dirs)
        println("No completed simulations with summary.json")
        return
    end

    # Collect data
    results = DataFrame()

    for sim_dir in sim_dirs
        params = extract_params(sim_dir)
        summary = load_summary(joinpath(campaign_dir, sim_dir))

        if summary !== nothing
            row = Dict{String, Any}("sim_dir" => sim_dir)
            merge!(row, params)

            # Extract collision data
            row["total_collisions"] = get(summary, "total_collisions", 0)
            row["n_snapshots"] = get(summary, "n_snapshots", 0)
            row["E0"] = get(summary, "E0", NaN)
            row["wall_time"] = get(summary, "elapsed_time_s", NaN)

            # Calculate rates
            max_time = get(summary, "max_time", 100.0)
            N_particles = get(params, "N", 40)

            if row["total_collisions"] > 0
                # Collisions per unit time
                row["collision_rate"] = row["total_collisions"] / max_time
                # Collisions per particle per unit time
                row["collision_rate_per_particle"] = row["collision_rate"] / N_particles
                # Mean free time
                row["mean_free_time"] = max_time * N_particles / (2 * row["total_collisions"])
            else
                row["collision_rate"] = 0.0
                row["collision_rate_per_particle"] = 0.0
                row["mean_free_time"] = NaN
            end

            push!(results, row; cols=:union)
        end
    end

    if isempty(results) || nrow(results) == 0
        println("No data collected")
        return
    end

    println("Analyzed $(nrow(results)) simulations\n")

    # ========================================================================
    # Analysis by Eccentricity
    # ========================================================================

    println("="^60)
    println("COLLISION RATES BY ECCENTRICITY")
    println("="^60)

    for e in sort(unique(results.e))
        subset = filter(row -> row.e == e, results)
        n = nrow(subset)

        rate_mean = mean(subset.collision_rate)
        rate_std = std(subset.collision_rate)
        rate_pp = mean(subset.collision_rate_per_particle)
        mft = mean(filter(!isnan, subset.mean_free_time))

        println(@sprintf("\ne = %.2f (n = %d)", e, n))
        println("-"^40)
        println(@sprintf("  Total collision rate:    %.1f ± %.1f /time", rate_mean, rate_std))
        println(@sprintf("  Rate per particle:       %.2f /time", rate_pp))
        println(@sprintf("  Mean free time:          %.4f", mft))
    end

    # ========================================================================
    # Analysis by N
    # ========================================================================

    if "N" in names(results)
        println("\n" * "="^60)
        println("COLLISION RATES BY SYSTEM SIZE")
        println("="^60)

        for N in sort(unique(results.N))
            subset = filter(row -> row.N == N, results)
            n = nrow(subset)

            rate_mean = mean(subset.collision_rate)
            rate_pp = mean(subset.collision_rate_per_particle)

            println(@sprintf("\nN = %d (n = %d)", N, n))
            println(@sprintf("  Total collision rate: %.1f /time", rate_mean))
            println(@sprintf("  Rate per particle:    %.2f /time", rate_pp))

            # Theoretical scaling: collision rate ~ N² for dense system, N for dilute
            # Rate per particle ~ N for dense, ~1 for dilute
        end

        # Check N-scaling
        N_values = sort(unique(results.N))
        if length(N_values) >= 2
            rates_by_N = [mean(filter(row -> row.N == N, results).collision_rate) for N in N_values]

            # Log-log fit
            log_N = log.(N_values)
            log_rate = log.(rates_by_N)
            mean_x = mean(log_N)
            mean_y = mean(log_rate)
            scaling = sum((log_N .- mean_x) .* (log_rate .- mean_y)) /
                      sum((log_N .- mean_x).^2)

            println("\n" * "-"^40)
            println(@sprintf("Collision rate scaling: rate ~ N^%.2f", scaling))
            if scaling > 1.5
                println("  → Dense regime (many-body collisions)")
            elseif scaling < 0.5
                println("  → Dilute regime")
            else
                println("  → Intermediate regime")
            end
        end
    end

    # ========================================================================
    # Energy dependence
    # ========================================================================

    if "E0" in names(results) && any(!isnan, results.E0)
        println("\n" * "="^60)
        println("ENERGY DEPENDENCE")
        println("="^60)

        # Group by energy ranges
        E_values = filter(!isnan, results.E0)
        if !isempty(E_values)
            E_min, E_max = extrema(E_values)
            println(@sprintf("\nEnergy range: %.2f - %.2f", E_min, E_max))

            # Correlation between E and collision rate
            valid = filter(row -> !isnan(row.E0), results)
            if nrow(valid) > 2
                E_vals = valid.E0
                rate_vals = valid.collision_rate

                # Simple correlation
                mean_E = mean(E_vals)
                mean_r = mean(rate_vals)
                cov_Er = mean((E_vals .- mean_E) .* (rate_vals .- mean_r))
                std_E = std(E_vals)
                std_r = std(rate_vals)
                corr = cov_Er / (std_E * std_r + 1e-10)

                println(@sprintf("Correlation(E, collision_rate): %.3f", corr))

                if corr > 0.5
                    println("  → Higher energy increases collision rate")
                elseif corr < -0.5
                    println("  → Lower energy increases collision rate")
                else
                    println("  → Weak energy dependence")
                end
            end
        end
    end

    # Save results
    output_dir = joinpath(campaign_dir, "collision_analysis")
    mkpath(output_dir)
    CSV.write(joinpath(output_dir, "collision_rates.csv"), results)

    println("\n" * "="^60)
    println("Saved to: $(joinpath(output_dir, "collision_rates.csv"))")
    println("="^60)
end

main()
