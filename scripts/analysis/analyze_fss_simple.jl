#!/usr/bin/env julia
"""
Simple Finite-Size Scaling Analysis

Analyzes how order parameters scale with system size N directly from HDF5 files.

Usage:
    julia --project=. scripts/analysis/analyze_fss_simple.jl <campaign_dir>
"""

using Pkg
Pkg.activate(".")

using Statistics
using Printf
using DataFrames
using CSV
using HDF5

const PROJECT_ROOT = dirname(dirname(@__DIR__))
include(joinpath(PROJECT_ROOT, "src", "io_hdf5.jl"))

# ============================================================================
# Order Parameters
# ============================================================================

order_param(phi) = abs(sum(exp(im * φ) for φ in phi) / length(phi))

# ============================================================================
# Analysis
# ============================================================================

function analyze_sim(h5_file)
    !isfile(h5_file) && return nothing

    result = load_trajectories_hdf5(h5_file)
    result === nothing && return nothing

    n_snap = size(result.phi, 1)
    N = size(result.phi, 2)
    n_snap == 0 && return nothing

    # Late-time (last 20%)
    start_idx = max(1, Int(round(0.8 * n_snap)))

    psi_late = Float64[]
    sigma_late = Float64[]

    for i in start_idx:n_snap
        phi = Vector{Float64}(result.phi[i, :])
        push!(psi_late, order_param(phi))
        push!(sigma_late, std(phi))
    end

    return (
        N = N,
        psi_mean = mean(psi_late),
        psi_std = std(psi_late),
        sigma_mean = mean(sigma_late),
        sigma_std = std(sigma_late),
        chi = N * mean(psi_late.^2)  # Susceptibility
    )
end

function extract_params(dirname)
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
# Main
# ============================================================================

function main()
    length(ARGS) < 1 && (println("Usage: julia analyze_fss_simple.jl <dir>"); return)

    campaign_dir = ARGS[1]
    !isdir(campaign_dir) && (println("Not found: $campaign_dir"); return)

    println("="^60)
    println("FINITE-SIZE SCALING ANALYSIS")
    println("="^60)
    println("Campaign: $campaign_dir\n")

    # Find simulations
    subdirs = filter(d -> isdir(joinpath(campaign_dir, d)), readdir(campaign_dir))
    sim_dirs = filter(d -> isfile(joinpath(campaign_dir, d, "trajectories.h5")), subdirs)

    println("Found $(length(sim_dirs)) simulations\n")

    # Analyze
    results = DataFrame()

    for sim_dir in sim_dirs
        h5_file = joinpath(campaign_dir, sim_dir, "trajectories.h5")
        params = extract_params(sim_dir)
        metrics = analyze_sim(h5_file)

        if metrics !== nothing
            row = Dict{String, Any}("sim_dir" => sim_dir)
            merge!(row, params)
            merge!(row, Dict(string(k) => v for (k,v) in pairs(metrics)))
            push!(results, row; cols=:union)
        end
    end

    println("Analyzed $(nrow(results)) simulations\n")

    # Group by (e, N) and average
    println("="^60)
    println("SCALING BY ECCENTRICITY")
    println("="^60)

    for e in sort(unique(results.e))
        subset = filter(row -> row.e == e, results)
        N_values = sort(unique(subset.N))

        println("\ne = $e")
        println("-"^40)
        println("  N    | ⟨Ψ⟩    | σ(Ψ)  | ⟨σ_φ⟩  | χ")
        println("  -----|--------|-------|--------|--------")

        psi_by_N = Float64[]
        chi_by_N = Float64[]

        for N in N_values
            N_subset = filter(row -> row.e == e && row.N == N, subset)
            psi_m = mean(N_subset.psi_mean)
            psi_s = mean(N_subset.psi_std)
            sigma_m = mean(N_subset.sigma_mean)
            chi_m = mean(N_subset.chi)

            push!(psi_by_N, psi_m)
            push!(chi_by_N, chi_m)

            println(@sprintf("  %4d | %.4f | %.4f | %.4f | %7.2f",
                N, psi_m, psi_s, sigma_m, chi_m))
        end

        # Simple scaling estimate
        if length(N_values) >= 2
            # Log-log fit for Ψ ~ N^β
            log_N = log.(N_values)
            log_psi = log.(psi_by_N .+ 1e-10)

            mean_x = mean(log_N)
            mean_y = mean(log_psi)
            beta = sum((log_N .- mean_x) .* (log_psi .- mean_y)) /
                   sum((log_N .- mean_x).^2)

            # Log-log fit for χ ~ N^γ
            log_chi = log.(chi_by_N .+ 1e-10)
            mean_y_chi = mean(log_chi)
            gamma = sum((log_N .- mean_x) .* (log_chi .- mean_y_chi)) /
                    sum((log_N .- mean_x).^2)

            println()
            println(@sprintf("  Ψ scaling: Ψ ~ N^%.3f", beta))
            println(@sprintf("  χ scaling: χ ~ N^%.3f", gamma))

            # Physical interpretation
            if beta < -0.1
                println("  → Disordered (Ψ decreases with N)")
            elseif beta > 0.1
                println("  → Ordered tendency (Ψ increases with N)")
            else
                println("  → Near critical (Ψ ~ constant)")
            end
        end
    end

    # Save
    output_dir = joinpath(campaign_dir, "fss_analysis")
    mkpath(output_dir)
    CSV.write(joinpath(output_dir, "fss_data.csv"), results)

    println("\n" * "="^60)
    println("Saved to: $(joinpath(output_dir, "fss_data.csv"))")
    println("="^60)
end

main()
