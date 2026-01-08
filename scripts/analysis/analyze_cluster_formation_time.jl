#!/usr/bin/env julia
"""
Analyze cluster formation dynamics:
- Time to first significant clustering (τ_cluster)
- Cluster stability analysis
- Coalescence/splitting events

Usage:
    julia --project=. scripts/analysis/analyze_cluster_formation_time.jl <campaign_dir>
"""

using Pkg
Pkg.activate(".")

using HDF5
using Statistics
using Printf
using CSV
using DataFrames

# Thresholds for clustering detection
const PSI_THRESHOLD = 0.3      # Polar order threshold
const S_THRESHOLD = 0.4        # Nematic order threshold
const G_THRESHOLD = 1.3        # Pair correlation threshold

function polar_order(φ::Vector{Float64})
    abs(mean(exp.(im .* φ)))
end

function nematic_order(φ::Vector{Float64})
    abs(mean(exp.(2im .* φ)))
end

function analyze_run(h5_file::String)
    result = Dict{String, Any}()

    h5open(h5_file, "r") do fid
        times = read(fid, "trajectories/time")
        phi = read(fid, "trajectories/phi")

        # Handle orientation
        if size(phi, 1) == length(times)
            n_times, N = size(phi)
        else
            phi = phi'
            n_times, N = size(phi)
        end

        # Compute time series
        ψ_t = [polar_order(phi[t, :]) for t in 1:n_times]
        S_t = [nematic_order(phi[t, :]) for t in 1:n_times]

        result["t_max"] = times[end]
        result["n_frames"] = n_times
        result["N"] = N

        # Find first time above threshold
        τ_psi = findfirst(x -> x > PSI_THRESHOLD, ψ_t)
        τ_S = findfirst(x -> x > S_THRESHOLD, S_t)

        result["tau_psi"] = isnothing(τ_psi) ? NaN : times[τ_psi]
        result["tau_S"] = isnothing(τ_S) ? NaN : times[τ_S]

        # Time spent above threshold
        result["frac_psi_above"] = sum(ψ_t .> PSI_THRESHOLD) / n_times
        result["frac_S_above"] = sum(S_t .> S_THRESHOLD) / n_times

        # Max values
        result["psi_max"] = maximum(ψ_t)
        result["S_max"] = maximum(S_t)
        result["psi_final"] = ψ_t[end]
        result["S_final"] = S_t[end]

        # Stability: coefficient of variation in second half
        mid = n_times ÷ 2
        result["psi_cv_late"] = std(ψ_t[mid:end]) / mean(ψ_t[mid:end])
        result["S_cv_late"] = std(S_t[mid:end]) / mean(S_t[mid:end])

        # Cluster type classification
        if result["psi_max"] > 0.5
            result["cluster_type"] = "STRONG_SINGLE"
        elseif result["S_max"] > 0.5 && result["S_max"] > result["psi_max"]
            result["cluster_type"] = "TWO_CLUSTER"
        elseif result["psi_max"] > PSI_THRESHOLD
            result["cluster_type"] = "MODERATE"
        else
            result["cluster_type"] = "NONE"
        end

        # Count transitions (cluster formation/dissolution events)
        psi_above = ψ_t .> PSI_THRESHOLD
        transitions = sum(abs.(diff(Int.(psi_above))))
        result["n_transitions"] = transitions

    end

    return result
end

function parse_dirname(dirname::String)
    # Parse: e0.50_N040_E0.10_t500_seed01
    parts = split(dirname, "_")
    e = parse(Float64, replace(parts[1], "e" => ""))
    N = parse(Int, replace(parts[2], "N" => ""))
    E_per_N = parse(Float64, replace(parts[3], "E" => ""))
    t_max = parse(Float64, replace(parts[4], "t" => ""))
    seed = parse(Int, replace(parts[5], "seed" => ""))
    return (e=e, N=N, E_per_N=E_per_N, t_max=t_max, seed=seed)
end

function main(campaign_dir::String)
    println("="^70)
    println("CLUSTER FORMATION TIME ANALYSIS")
    println("="^70)
    println("Campaign: $campaign_dir")
    println()

    # Find all HDF5 files
    results = DataFrame()

    for dir in readdir(campaign_dir, join=true)
        h5_file = joinpath(dir, "trajectories.h5")
        if isfile(h5_file)
            dirname = basename(dir)
            try
                params = parse_dirname(dirname)
                analysis = analyze_run(h5_file)

                row = merge(
                    Dict(pairs(params)),
                    analysis,
                    Dict("dirname" => dirname)
                )
                push!(results, row, cols=:union)

            catch ex
                @warn "Error analyzing $dirname: $ex"
            end
        end
    end

    println("Analyzed $(nrow(results)) runs")
    println()

    # Summary by eccentricity
    println("="^70)
    println("SUMMARY BY ECCENTRICITY")
    println("="^70)

    for e_val in sort(unique(results.e))
        subset = filter(r -> r.e == e_val, results)
        println("\ne = $e_val ($(nrow(subset)) runs):")

        # Cluster types
        types = countmap(subset.cluster_type)
        for (t, c) in types
            @printf("  %-15s: %d (%.0f%%)\n", t, c, 100c/nrow(subset))
        end

        # Formation times (excluding NaN)
        τ_psi = filter(!isnan, subset.tau_psi)
        τ_S = filter(!isnan, subset.tau_S)

        if !isempty(τ_psi)
            @printf("  τ_ψ (polar):    %.1f ± %.1f s (n=%d)\n",
                    mean(τ_psi), std(τ_psi), length(τ_psi))
        end
        if !isempty(τ_S)
            @printf("  τ_S (nematic):  %.1f ± %.1f s (n=%d)\n",
                    mean(τ_S), std(τ_S), length(τ_S))
        end

        @printf("  ψ_max mean:     %.3f ± %.3f\n",
                mean(subset.psi_max), std(subset.psi_max))
        @printf("  S_max mean:     %.3f ± %.3f\n",
                mean(subset.S_max), std(subset.S_max))
    end

    # Summary by E/N
    println("\n" * "="^70)
    println("SUMMARY BY E/N (Temperature)")
    println("="^70)

    for E_val in sort(unique(results.E_per_N))
        subset = filter(r -> r.E_per_N == E_val, results)
        println("\nE/N = $E_val ($(nrow(subset)) runs):")

        types = countmap(subset.cluster_type)
        for (t, c) in types
            @printf("  %-15s: %d (%.0f%%)\n", t, c, 100c/nrow(subset))
        end

        @printf("  ψ_max mean:     %.3f ± %.3f\n",
                mean(subset.psi_max), std(subset.psi_max))
    end

    # Save results
    output_file = joinpath(campaign_dir, "cluster_formation_analysis.csv")
    CSV.write(output_file, results)
    println("\n\nSaved detailed results to: $output_file")

    return results
end

# Helper function
function countmap(x)
    d = Dict{eltype(x), Int}()
    for v in x
        d[v] = get(d, v, 0) + 1
    end
    return d
end

# Main execution
if length(ARGS) < 1
    println("Usage: julia analyze_cluster_formation_time.jl <campaign_dir>")
    exit(1)
end

main(ARGS[1])
