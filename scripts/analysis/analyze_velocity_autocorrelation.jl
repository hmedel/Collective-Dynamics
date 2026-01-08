#!/usr/bin/env julia
"""
Velocity Autocorrelation Function Analysis

Computes C(τ) = ⟨v(t)·v(t+τ)⟩ / ⟨v²⟩ to measure:
- Memory loss timescale
- Relaxation dynamics
- Approach to equilibrium

Usage:
    julia --project=. scripts/analysis/analyze_velocity_autocorrelation.jl <campaign_dir>
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
# Autocorrelation Functions
# ============================================================================

"""
Compute normalized velocity autocorrelation (direct method)
C(τ) = ⟨v(t)·v(t+τ)⟩ / ⟨v²⟩
"""
function velocity_autocorr_direct(v::Vector{Float64}; max_lag_frac::Float64=0.5)
    n = length(v)
    n < 2 && return Float64[], Float64[]

    # Remove mean
    v_centered = v .- mean(v)
    var_v = var(v_centered)
    var_v < 1e-15 && return Float64[], Float64[]

    max_lag = Int(floor(max_lag_frac * n))

    acf = zeros(max_lag + 1)

    for τ in 0:max_lag
        s = 0.0
        count = 0
        for t in 1:(n - τ)
            s += v_centered[t] * v_centered[t + τ]
            count += 1
        end
        acf[τ + 1] = s / count
    end

    # Normalize by variance
    acf ./= acf[1]

    lags = collect(0:max_lag)

    return lags, acf
end

"""
Compute autocorrelation for a single particle trajectory
"""
function particle_autocorr(phidot_trajectory::Vector{Float64}, times::Vector{Float64})
    lags, acf = velocity_autocorr_direct(phidot_trajectory)

    if isempty(lags)
        return nothing
    end

    # Convert lags to actual time
    dt_avg = length(times) > 1 ? (times[end] - times[1]) / (length(times) - 1) : 1.0
    tau = lags .* dt_avg

    return (tau=tau, acf=acf)
end

"""
Find relaxation time τ_r where C(τ_r) = 1/e
"""
function find_relaxation_time(tau, acf)
    target = 1/exp(1)  # ≈ 0.368

    # Find first crossing below target
    for i in 2:length(acf)
        if acf[i] <= target && acf[i-1] > target
            # Linear interpolation
            t1, t2 = tau[i-1], tau[i]
            c1, c2 = acf[i-1], acf[i]
            τ_r = t1 + (target - c1) / (c2 - c1) * (t2 - t1)
            return τ_r
        end
    end

    return NaN  # Never decays to 1/e
end

"""
Check for oscillatory behavior (negative ACF)
"""
function has_oscillations(acf)
    return any(acf .< -0.1)
end

# ============================================================================
# Analysis Functions
# ============================================================================

function analyze_simulation_vacf(h5_file::String)
    !isfile(h5_file) && return nothing

    result = load_trajectories_hdf5(h5_file)
    result === nothing && return nothing

    n_snapshots = size(result.phi, 1)
    N = size(result.phi, 2)

    n_snapshots < 10 && return nothing

    times = result.times
    dt_avg = (times[end] - times[1]) / (n_snapshots - 1)

    # Compute autocorrelation for each particle
    tau_relaxation = Float64[]
    has_osc = Bool[]

    # Sample particles (all if N small, subset if large)
    particle_indices = N <= 20 ? (1:N) : rand(1:N, 20)

    for j in particle_indices
        phidot_traj = Vector{Float64}(result.phi[2:end, j] - result.phi[1:end-1, j]) ./ dt_avg

        if length(phidot_traj) > 10
            res = particle_autocorr(phidot_traj, times[2:end])
            if res !== nothing
                τ_r = find_relaxation_time(res.tau, res.acf)
                push!(tau_relaxation, τ_r)
                push!(has_osc, has_oscillations(res.acf))
            end
        end
    end

    # Also compute ensemble-averaged VACF
    # Average velocity at each time
    v_ensemble = Float64[]
    for i in 2:n_snapshots
        v_avg = mean((result.phi[i, :] .- result.phi[i-1, :]) ./ dt_avg)
        push!(v_ensemble, v_avg)
    end

    ensemble_res = particle_autocorr(v_ensemble, times[2:end])

    metrics = Dict{String, Any}()
    metrics["N"] = N
    metrics["n_snapshots"] = n_snapshots
    metrics["dt_avg"] = dt_avg
    metrics["total_time"] = times[end] - times[1]

    # Relaxation time statistics
    valid_tau = filter(!isnan, tau_relaxation)
    if !isempty(valid_tau)
        metrics["tau_relax_mean"] = mean(valid_tau)
        metrics["tau_relax_std"] = std(valid_tau)
        metrics["tau_relax_min"] = minimum(valid_tau)
        metrics["tau_relax_max"] = maximum(valid_tau)
    else
        metrics["tau_relax_mean"] = NaN
        metrics["tau_relax_std"] = NaN
        metrics["tau_relax_min"] = NaN
        metrics["tau_relax_max"] = NaN
    end

    # Oscillation check
    metrics["frac_oscillatory"] = isempty(has_osc) ? 0.0 : mean(has_osc)

    # Ensemble relaxation
    if ensemble_res !== nothing
        metrics["tau_ensemble"] = find_relaxation_time(ensemble_res.tau, ensemble_res.acf)
    else
        metrics["tau_ensemble"] = NaN
    end

    return metrics
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
# Main
# ============================================================================

function main()
    length(ARGS) < 1 && (println("Usage: julia analyze_velocity_autocorrelation.jl <dir>"); return)

    campaign_dir = ARGS[1]
    !isdir(campaign_dir) && (println("Not found: $campaign_dir"); return)

    println("="^60)
    println("VELOCITY AUTOCORRELATION ANALYSIS")
    println("="^60)
    println("Campaign: $campaign_dir\n")

    subdirs = filter(d -> isdir(joinpath(campaign_dir, d)), readdir(campaign_dir))
    sim_dirs = filter(d -> isfile(joinpath(campaign_dir, d, "trajectories.h5")), subdirs)

    println("Found $(length(sim_dirs)) simulations\n")

    results = DataFrame()

    for (i, sim_dir) in enumerate(sim_dirs)
        h5_file = joinpath(campaign_dir, sim_dir, "trajectories.h5")
        params = extract_params(sim_dir)
        metrics = analyze_simulation_vacf(h5_file)

        if metrics !== nothing
            row = Dict{String, Any}("sim_dir" => sim_dir)
            merge!(row, params)
            merge!(row, metrics)
            push!(results, row; cols=:union)
        end

        i % 20 == 0 && println("  Processed $i / $(length(sim_dirs))")
    end

    println("\nAnalyzed $(nrow(results)) simulations\n")

    # Summary by eccentricity
    println("="^60)
    println("RELAXATION TIMES BY ECCENTRICITY")
    println("="^60)

    for e in sort(unique(results.e))
        subset = filter(row -> row.e == e, results)
        n = nrow(subset)

        τ_mean = mean(filter(!isnan, subset.tau_relax_mean))
        τ_std = std(filter(!isnan, subset.tau_relax_mean))
        frac_osc = mean(subset.frac_oscillatory)

        println(@sprintf("\ne = %.2f (n = %d)", e, n))
        println("-"^40)
        println(@sprintf("  τ_relax:     %.3f ± %.3f", τ_mean, τ_std))
        println(@sprintf("  Oscillatory: %.1f%%", 100*frac_osc))

        if τ_mean < 1.0
            println("  → Fast relaxation (collisional)")
        elseif τ_mean > 10.0
            println("  → Slow relaxation (quasi-ballistic)")
        else
            println("  → Intermediate relaxation")
        end
    end

    # Save
    output_dir = joinpath(campaign_dir, "vacf_analysis")
    mkpath(output_dir)
    CSV.write(joinpath(output_dir, "velocity_autocorrelation.csv"), results)

    println("\n" * "="^60)
    println("Saved to: $(joinpath(output_dir, "velocity_autocorrelation.csv"))")
    println("="^60)
end

main()
