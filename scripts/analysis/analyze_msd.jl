#!/usr/bin/env julia
"""
Mean Squared Displacement (MSD) Analysis

Computes MSD(τ) = ⟨[φ(t+τ) - φ(t)]²⟩ to determine:
- Diffusive behavior: MSD ~ τ (normal diffusion)
- Subdiffusive: MSD ~ τ^α with α < 1 (caging, trapping)
- Superdiffusive: MSD ~ τ^α with α > 1 (ballistic, Lévy flights)

Usage:
    julia --project=. scripts/analysis/analyze_msd.jl <campaign_dir>
"""

using Pkg
Pkg.activate(".")

using Statistics
using Printf
using DataFrames
using CSV
using HDF5
using LinearAlgebra

const PROJECT_ROOT = dirname(dirname(@__DIR__))
include(joinpath(PROJECT_ROOT, "src", "io_hdf5.jl"))

# ============================================================================
# MSD Functions
# ============================================================================

"""
Compute MSD for a single particle trajectory using efficient algorithm
MSD(τ) = ⟨[φ(t+τ) - φ(t)]²⟩
"""
function compute_msd_single(trajectory::Vector{Float64}, max_lag::Int)
    n = length(trajectory)
    max_lag = min(max_lag, n - 1)

    msd = zeros(max_lag + 1)
    counts = zeros(Int, max_lag + 1)

    for τ in 0:max_lag
        for t in 1:(n - τ)
            # Handle angle wrapping for φ
            Δφ = trajectory[t + τ] - trajectory[t]
            # Unwrap: if jump > π, it's likely a wrap
            while Δφ > π
                Δφ -= 2π
            end
            while Δφ < -π
                Δφ += 2π
            end
            msd[τ + 1] += Δφ^2
            counts[τ + 1] += 1
        end
    end

    # Normalize
    msd ./= max.(counts, 1)

    return msd
end

"""
Compute ensemble-averaged MSD
"""
function compute_msd_ensemble(phi_matrix::Matrix{Float64}, times::Vector{Float64}; max_lag_frac::Float64=0.5)
    n_snapshots, N = size(phi_matrix)
    max_lag = Int(floor(max_lag_frac * n_snapshots))

    # Compute MSD for each particle
    msd_all = zeros(max_lag + 1)

    for j in 1:N
        trajectory = Vector{Float64}(phi_matrix[:, j])
        msd_particle = compute_msd_single(trajectory, max_lag)
        msd_all .+= msd_particle
    end

    msd_all ./= N

    # Convert lag indices to actual times
    dt_avg = (times[end] - times[1]) / (n_snapshots - 1)
    tau = collect(0:max_lag) .* dt_avg

    return tau, msd_all
end

"""
Fit MSD to power law: MSD = D * τ^α
Returns diffusion coefficient D and exponent α
"""
function fit_msd_powerlaw(tau, msd; fit_range=(0.1, 0.5))
    # Use only intermediate time range to avoid short-time ballistic
    # and long-time saturation effects
    valid = (tau .> fit_range[1] * tau[end]) .& (tau .< fit_range[2] * tau[end]) .& (msd .> 0) .& (tau .> 0)

    if sum(valid) < 3
        return NaN, NaN
    end

    log_tau = log.(tau[valid])
    log_msd = log.(msd[valid])

    # Linear fit in log-log space
    mean_x = mean(log_tau)
    mean_y = mean(log_msd)

    cov_xy = sum((log_tau .- mean_x) .* (log_msd .- mean_y))
    var_x = sum((log_tau .- mean_x).^2)

    α = cov_xy / var_x  # Exponent
    log_D = mean_y - α * mean_x
    D = exp(log_D)  # Diffusion coefficient

    return D, α
end

"""
Classify diffusion type based on exponent
"""
function classify_diffusion(α::Float64)
    if isnan(α)
        return "unknown"
    elseif α < 0.5
        return "subdiffusive (caging)"
    elseif α < 0.9
        return "subdiffusive"
    elseif α < 1.1
        return "normal diffusion"
    elseif α < 1.5
        return "superdiffusive"
    else
        return "ballistic"
    end
end

# ============================================================================
# Analysis Functions
# ============================================================================

function analyze_simulation_msd(h5_file::String)
    !isfile(h5_file) && return nothing

    result = load_trajectories_hdf5(h5_file)
    result === nothing && return nothing

    n_snapshots = size(result.phi, 1)
    N = size(result.phi, 2)

    n_snapshots < 20 && return nothing

    times = result.times

    # Compute ensemble-averaged MSD
    tau, msd = compute_msd_ensemble(result.phi, times)

    # Fit power law
    D, α = fit_msd_powerlaw(tau, msd)

    # Short-time and long-time behavior
    D_short, α_short = fit_msd_powerlaw(tau, msd; fit_range=(0.01, 0.1))
    D_long, α_long = fit_msd_powerlaw(tau, msd; fit_range=(0.5, 0.9))

    metrics = Dict{String, Any}()
    metrics["N"] = N
    metrics["n_snapshots"] = n_snapshots
    metrics["total_time"] = times[end] - times[1]

    # Main fit results
    metrics["diffusion_coeff"] = D
    metrics["msd_exponent"] = α
    metrics["diffusion_type"] = classify_diffusion(α)

    # Short-time (ballistic regime)
    metrics["alpha_short"] = α_short
    metrics["D_short"] = D_short

    # Long-time (may show saturation or caging)
    metrics["alpha_long"] = α_long
    metrics["D_long"] = D_long

    # MSD at specific times
    if length(tau) > 10
        t_10pct = Int(ceil(0.1 * length(tau)))
        t_50pct = Int(ceil(0.5 * length(tau)))
        metrics["msd_10pct"] = msd[t_10pct]
        metrics["msd_50pct"] = msd[t_50pct]
        metrics["msd_final"] = msd[end]
    else
        metrics["msd_10pct"] = NaN
        metrics["msd_50pct"] = NaN
        metrics["msd_final"] = msd[end]
    end

    # Saturation check: does MSD plateau?
    if length(msd) > 20
        late_msd = msd[Int(ceil(0.8*length(msd))):end]
        early_msd = msd[Int(ceil(0.1*length(msd))):Int(ceil(0.3*length(msd)))]

        # If late-time MSD growth is < 10% of early growth, likely saturating
        late_growth = std(late_msd) / mean(late_msd)
        early_growth = std(early_msd) / mean(early_msd)

        metrics["shows_saturation"] = late_growth < 0.1 * early_growth && α_long < 0.3
    else
        metrics["shows_saturation"] = false
    end

    return metrics
end

function extract_params(dirname::String)
    params = Dict{String, Any}()
    m = match(r"e([\d.]+)", dirname)
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
    length(ARGS) < 1 && (println("Usage: julia analyze_msd.jl <dir>"); return)

    campaign_dir = ARGS[1]
    !isdir(campaign_dir) && (println("Not found: $campaign_dir"); return)

    println("="^60)
    println("MEAN SQUARED DISPLACEMENT ANALYSIS")
    println("="^60)
    println("Campaign: $campaign_dir\n")

    subdirs = filter(d -> isdir(joinpath(campaign_dir, d)), readdir(campaign_dir))
    sim_dirs = filter(d -> isfile(joinpath(campaign_dir, d, "trajectories.h5")), subdirs)

    println("Found $(length(sim_dirs)) simulations\n")

    results = DataFrame()

    for (i, sim_dir) in enumerate(sim_dirs)
        h5_file = joinpath(campaign_dir, sim_dir, "trajectories.h5")
        params = extract_params(sim_dir)
        metrics = analyze_simulation_msd(h5_file)

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
    println("DIFFUSION PROPERTIES BY ECCENTRICITY")
    println("="^60)

    for e in sort(unique(results.e))
        subset = filter(row -> row.e == e, results)
        n = nrow(subset)

        α_mean = mean(filter(!isnan, subset.msd_exponent))
        α_std = std(filter(!isnan, subset.msd_exponent))
        D_mean = mean(filter(!isnan, subset.diffusion_coeff))

        # Count diffusion types
        type_counts = Dict{String, Int}()
        for t in subset.diffusion_type
            type_counts[t] = get(type_counts, t, 0) + 1
        end
        dominant_type = first(sort(collect(type_counts), by=x->-x[2]))[1]

        println(@sprintf("\ne = %.2f (n = %d)", e, n))
        println("-"^40)
        println(@sprintf("  α (MSD exponent):   %.3f ± %.3f", α_mean, α_std))
        println(@sprintf("  D (diffusion):      %.4f", D_mean))
        println("  Dominant type:      $dominant_type")

        # Short vs long time comparison
        α_short = mean(filter(!isnan, subset.alpha_short))
        α_long = mean(filter(!isnan, subset.alpha_long))
        println(@sprintf("  α(short):           %.3f", α_short))
        println(@sprintf("  α(long):            %.3f", α_long))

        if α_short > 1.5 && α_long < 1.0
            println("  → Ballistic → diffusive crossover")
        elseif α_long < 0.5
            println("  → Evidence of caging/trapping at long times")
        end

        # Saturation check
        n_saturating = count(subset.shows_saturation)
        if n_saturating > 0
            println(@sprintf("  Saturating: %d/%d (%.1f%%)", n_saturating, n, 100*n_saturating/n))
        end
    end

    # Physical interpretation
    println("\n" * "="^60)
    println("PHYSICAL INTERPRETATION")
    println("="^60)
    println()

    overall_α = mean(filter(!isnan, results.msd_exponent))
    if overall_α > 1.5
        println("System shows BALLISTIC behavior (α > 1.5)")
        println("Particles move in nearly straight lines (low collision rate)")
    elseif overall_α > 1.1
        println("System shows SUPERDIFFUSIVE behavior (1.1 < α < 1.5)")
        println("Possible Lévy-flight like dynamics or persistent motion")
    elseif overall_α > 0.9
        println("System shows NORMAL DIFFUSION (α ≈ 1)")
        println("Classical random walk behavior, thermalized system")
    elseif overall_α > 0.5
        println("System shows SUBDIFFUSIVE behavior (0.5 < α < 0.9)")
        println("Possible memory effects or partial trapping")
    else
        println("System shows STRONG SUBDIFFUSION/CAGING (α < 0.5)")
        println("Particles are likely trapped in local regions")
    end

    # Save
    output_dir = joinpath(campaign_dir, "msd_analysis")
    mkpath(output_dir)
    CSV.write(joinpath(output_dir, "msd_results.csv"), results)

    println("\n" * "="^60)
    println("Saved to: $(joinpath(output_dir, "msd_results.csv"))")
    println("="^60)
end

main()
