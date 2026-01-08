#!/usr/bin/env julia
"""
Time Evolution Analysis of Order Parameters

Analyzes how σ_φ (spatial spread) and Ψ (orientational order) evolve over time
to understand clustering dynamics and identify transient phenomena.

Usage:
    julia --project=. scripts/analysis/analyze_order_parameter_evolution.jl <campaign_dir>
"""

using Pkg
Pkg.activate(".")

using Statistics
using Printf
using DataFrames
using CSV
using HDF5

# Include HDF5 loader
const PROJECT_ROOT = dirname(dirname(@__DIR__))
include(joinpath(PROJECT_ROOT, "src", "io_hdf5.jl"))

# ============================================================================
# Order Parameter Calculations
# ============================================================================

"""
Calculate orientational order parameter Ψ = |⟨e^{iφ}⟩|
"""
function order_parameter(phi::Vector{Float64})
    N = length(phi)
    N == 0 && return 0.0
    return abs(sum(exp(im * φ) for φ in phi) / N)
end

"""
Calculate circular standard deviation
"""
function circular_std(phi::Vector{Float64})
    N = length(phi)
    N <= 1 && return 0.0

    # Circular mean
    sin_mean = mean(sin.(phi))
    cos_mean = mean(cos.(phi))
    R = sqrt(sin_mean^2 + cos_mean^2)

    # Circular std: sqrt(-2 * log(R))
    R ≈ 0 && return π  # Uniform distribution
    R ≥ 1 && return 0.0  # Perfect alignment
    return sqrt(-2 * log(R))
end

"""
Calculate number of clusters using gap detection
"""
function count_clusters(phi::Vector{Float64}; threshold=0.3)
    N = length(phi)
    N == 0 && return 0

    sorted_phi = sort(phi)
    n_clusters = 1

    for i in 2:N
        if sorted_phi[i] - sorted_phi[i-1] > threshold
            n_clusters += 1
        end
    end

    # Check wraparound
    if 2π - sorted_phi[end] + sorted_phi[1] > threshold
        # Already counted as separate
    else
        n_clusters = max(1, n_clusters - 1)  # Merge first and last
    end

    return n_clusters
end

# ============================================================================
# Time Series Analysis
# ============================================================================

"""
Analyze time evolution of order parameters for a single simulation
"""
function analyze_time_evolution(h5_file::String)
    if !isfile(h5_file)
        return nothing
    end

    result = load_trajectories_hdf5(h5_file)
    result === nothing && return nothing

    n_snapshots = size(result.phi, 1)
    N = size(result.phi, 2)

    n_snapshots == 0 && return nothing

    # Calculate order parameters at each time
    times = result.times
    sigma_phi = zeros(n_snapshots)
    psi = zeros(n_snapshots)
    n_clusters = zeros(Int, n_snapshots)

    for i in 1:n_snapshots
        phi = Vector{Float64}(result.phi[i, :])
        sigma_phi[i] = std(phi)
        psi[i] = order_parameter(phi)
        n_clusters[i] = count_clusters(phi)
    end

    # Calculate derivatives (rate of change)
    d_sigma = zeros(n_snapshots)
    d_psi = zeros(n_snapshots)

    for i in 2:n_snapshots
        dt = times[i] - times[i-1]
        if dt > 0
            d_sigma[i] = (sigma_phi[i] - sigma_phi[i-1]) / dt
            d_psi[i] = (psi[i] - psi[i-1]) / dt
        end
    end

    return (
        times = times,
        sigma_phi = sigma_phi,
        psi = psi,
        n_clusters = n_clusters,
        d_sigma = d_sigma,
        d_psi = d_psi,
        N = N
    )
end

"""
Extract key dynamics metrics from time series
"""
function extract_dynamics_metrics(ts)
    n = length(ts.times)

    # Initial and final values
    sigma_initial = ts.sigma_phi[1]
    sigma_final = ts.sigma_phi[end]
    psi_initial = ts.psi[1]
    psi_final = ts.psi[end]

    # Maximum clustering (minimum sigma_phi)
    sigma_min = minimum(ts.sigma_phi)
    sigma_min_time = ts.times[argmin(ts.sigma_phi)]

    # Maximum order (maximum psi)
    psi_max = maximum(ts.psi)
    psi_max_time = ts.times[argmax(ts.psi)]

    # Compactification ratio
    compact_ratio = sigma_final / sigma_initial

    # Check for transient clustering
    # If sigma ever drops below 0.5 but final is > 1.0, there was transient clustering
    had_transient_clustering = sigma_min < 0.5 && sigma_final > 1.0

    # Check for sustained clustering
    # Last 20% of simulation
    late_start = max(1, Int(round(0.8 * n)))
    sigma_late_mean = mean(ts.sigma_phi[late_start:end])
    sigma_late_std = std(ts.sigma_phi[late_start:end])
    psi_late_mean = mean(ts.psi[late_start:end])

    # Relaxation time estimate (time to reach 1/e of initial-final difference)
    if abs(sigma_final - sigma_initial) > 0.1
        target = sigma_initial + (sigma_final - sigma_initial) * (1 - 1/exp(1))
        relax_idx = findfirst(i ->
            (sigma_initial > sigma_final && ts.sigma_phi[i] <= target) ||
            (sigma_initial < sigma_final && ts.sigma_phi[i] >= target),
            1:n)
        tau_relax = relax_idx !== nothing ? ts.times[relax_idx] : NaN
    else
        tau_relax = NaN
    end

    return Dict(
        "sigma_initial" => sigma_initial,
        "sigma_final" => sigma_final,
        "sigma_min" => sigma_min,
        "sigma_min_time" => sigma_min_time,
        "psi_initial" => psi_initial,
        "psi_final" => psi_final,
        "psi_max" => psi_max,
        "psi_max_time" => psi_max_time,
        "compact_ratio" => compact_ratio,
        "had_transient_clustering" => had_transient_clustering,
        "sigma_late_mean" => sigma_late_mean,
        "sigma_late_std" => sigma_late_std,
        "psi_late_mean" => psi_late_mean,
        "tau_relax" => tau_relax,
        "N" => ts.N
    )
end

"""
Extract parameters from directory name
"""
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
    if length(ARGS) < 1
        println("""
        Usage: julia --project=. scripts/analysis/analyze_order_parameter_evolution.jl <campaign_dir>

        Example:
            julia --project=. scripts/analysis/analyze_order_parameter_evolution.jl results/intrinsic_v3_campaign_20251126_110434/
        """)
        return
    end

    campaign_dir = ARGS[1]

    if !isdir(campaign_dir)
        println("ERROR: Directory not found: $campaign_dir")
        return
    end

    println("="^70)
    println("ORDER PARAMETER TIME EVOLUTION ANALYSIS")
    println("="^70)
    println("Campaign: $campaign_dir")
    println()

    # Find simulation directories
    subdirs = filter(d -> isdir(joinpath(campaign_dir, d)), readdir(campaign_dir))
    sim_dirs = filter(d -> isfile(joinpath(campaign_dir, d, "trajectories.h5")), subdirs)

    println("Found $(length(sim_dirs)) simulations")
    println()

    # Analyze each simulation
    results = DataFrame()

    for (i, sim_dir) in enumerate(sim_dirs)
        h5_file = joinpath(campaign_dir, sim_dir, "trajectories.h5")
        params = extract_params(sim_dir)

        ts = analyze_time_evolution(h5_file)

        if ts !== nothing
            metrics = extract_dynamics_metrics(ts)

            row = Dict{String, Any}("sim_dir" => sim_dir)
            merge!(row, params)
            merge!(row, metrics)

            push!(results, row; cols=:union)
        end

        if i % 20 == 0
            println("  Processed $i / $(length(sim_dirs))")
        end
    end

    println()
    println("Analyzed $(nrow(results)) simulations")

    # Save results
    output_dir = joinpath(campaign_dir, "dynamics_analysis")
    mkpath(output_dir)

    csv_file = joinpath(output_dir, "order_parameter_dynamics.csv")
    CSV.write(csv_file, results)
    println("Saved to: $csv_file")

    # ========================================================================
    # Summary Statistics
    # ========================================================================

    println()
    println("="^70)
    println("DYNAMICS SUMMARY BY ECCENTRICITY")
    println("="^70)

    if "e" in names(results)
        for e in sort(unique(results.e))
            subset = filter(row -> row.e == e, results)
            n = nrow(subset)

            println()
            println(@sprintf("e = %.2f (n = %d)", e, n))
            println("-"^40)

            # Compactification
            cr_mean = mean(subset.compact_ratio)
            cr_std = std(subset.compact_ratio)
            println(@sprintf("  Compactification ratio: %.3f ± %.3f", cr_mean, cr_std))

            # Transient clustering
            n_transient = count(row -> row.had_transient_clustering, eachrow(subset))
            println(@sprintf("  Transient clustering: %d/%d (%.0f%%)", n_transient, n, 100*n_transient/n))

            # Minimum sigma achieved
            sigma_min_mean = mean(subset.sigma_min)
            println(@sprintf("  Min σ_φ achieved: %.3f", sigma_min_mean))

            # Late-time behavior
            sigma_late = mean(subset.sigma_late_mean)
            psi_late = mean(subset.psi_late_mean)
            println(@sprintf("  Late-time ⟨σ_φ⟩: %.3f, ⟨Ψ⟩: %.3f", sigma_late, psi_late))

            # Relaxation time
            tau_valid = filter(x -> !isnan(x), subset.tau_relax)
            if !isempty(tau_valid)
                println(@sprintf("  Relaxation time τ: %.1f ± %.1f", mean(tau_valid), std(tau_valid)))
            end
        end
    end

    # ========================================================================
    # Key Findings
    # ========================================================================

    println()
    println("="^70)
    println("KEY FINDINGS")
    println("="^70)

    # Check for any transient clustering
    n_transient = count(row -> row.had_transient_clustering, eachrow(results))
    println()
    println("Transient Clustering Events: $n_transient / $(nrow(results))")

    if n_transient > 0
        transient = filter(row -> row.had_transient_clustering, results)
        println("  Eccentricities with transient clustering:")
        for e in sort(unique(transient.e))
            n_e = count(row -> row.e == e, eachrow(transient))
            println(@sprintf("    e = %.2f: %d cases", e, n_e))
        end
    end

    # Check for sustained clustering
    n_clustered = count(row -> row.sigma_final < 0.5, eachrow(results))
    println()
    println("Sustained Clustering (σ_φ_final < 0.5): $n_clustered / $(nrow(results))")

    # Strong compactification
    n_compact = count(row -> row.compact_ratio < 0.5, eachrow(results))
    println("Strong Compactification (ratio < 0.5): $n_compact / $(nrow(results))")

    # Generate report
    report_file = joinpath(output_dir, "dynamics_report.md")
    open(report_file, "w") do io
        println(io, "# Order Parameter Dynamics Report")
        println(io)
        println(io, "Campaign: `$campaign_dir`")
        println(io)
        println(io, "## Summary")
        println(io)
        println(io, "- Simulations analyzed: $(nrow(results))")
        println(io, "- Transient clustering events: $n_transient")
        println(io, "- Sustained clustering: $n_clustered")
        println(io, "- Strong compactification: $n_compact")
        println(io)

        if "e" in names(results)
            println(io, "## By Eccentricity")
            println(io)
            println(io, "| e | n | Compact Ratio | σ_min | Late σ_φ | Late Ψ | Transient |")
            println(io, "|---|---|---------------|-------|----------|--------|-----------|")

            for e in sort(unique(results.e))
                subset = filter(row -> row.e == e, results)
                n = nrow(subset)
                cr = mean(subset.compact_ratio)
                sm = mean(subset.sigma_min)
                sl = mean(subset.sigma_late_mean)
                pl = mean(subset.psi_late_mean)
                nt = count(row -> row.had_transient_clustering, eachrow(subset))

                println(io, @sprintf("| %.2f | %d | %.3f | %.3f | %.3f | %.3f | %d |", e, n, cr, sm, sl, pl, nt))
            end
        end
    end

    println()
    println("Report saved to: $report_file")
    println()
    println("="^70)
    println("ANALYSIS COMPLETE")
    println("="^70)
end

main()
