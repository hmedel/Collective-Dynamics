#!/usr/bin/env julia
"""
Phase Diagram Classification Analysis

Classifies each simulation into gas/liquid/crystal phases based on:
- Order parameter: Ψ = |⟨e^{iφ}⟩| (orientational order)
- Spatial compactness: σ_φ (angular spread)
- Clustering metrics: n_clusters, max_cluster_fraction

Phase Criteria:
- **Gas**: σ_φ > 1.5, Ψ < 0.3 (particles spread uniformly)
- **Liquid**: 0.5 ≤ σ_φ ≤ 1.5, 0.3 ≤ Ψ ≤ 0.7 (intermediate)
- **Crystal**: σ_φ < 0.5, Ψ > 0.7 OR max_cluster_frac > 0.5 (clustered)

Scientific Goal: Build phase diagram in (e, N) or (E/N, e) parameter space

Usage:
    julia --project=. scripts/analysis/analyze_phase_classification.jl <campaign_dir>

Examples:
    julia --project=. scripts/analysis/analyze_phase_classification.jl results/intrinsic_v3_campaign_20251126_110434/
    julia --project=. scripts/analysis/analyze_phase_classification.jl results/campaign_EN_scan_*/
"""

using HDF5
using JSON
using Statistics
using DataFrames
using CSV
using Printf
using Dates

# Include HDF5 loader (relative to project root)
const PROJECT_ROOT = dirname(dirname(@__DIR__))
include(joinpath(PROJECT_ROOT, "src", "io_hdf5.jl"))

# ============================================================================
# Phase Classification Criteria
# ============================================================================

"""
    classify_phase(σ_φ, n_clusters, N, max_cluster_frac, Ψ)

Classify simulation into gas/liquid/crystal phase based on order parameters.

Criteria:
- Gas: σ_φ > 1.5 AND Ψ < 0.3 (particles spread uniformly)
- Crystal: σ_φ < 0.5 AND (n_clusters ≤ 2 OR max_cluster_frac > 0.5)
- Liquid: Everything else (intermediate)
- Transition: Mixed characteristics near phase boundaries

Returns: "gas", "liquid", "crystal", or "transition"
"""
function classify_phase(σ_φ::Float64, n_clusters::Int, N::Int,
                        max_cluster_frac::Float64, Ψ::Float64)
    # Crystal/Cluster phase: strongly clustered
    if σ_φ < 0.5 && (n_clusters <= 2 || max_cluster_frac > 0.5)
        return "crystal"
    end

    # Gas phase: spread out
    if σ_φ > 1.5 && n_clusters > N/2 && Ψ < 0.3
        return "gas"
    end

    # Liquid phase: intermediate
    if 0.5 <= σ_φ <= 1.5 && 0.3 <= Ψ <= 0.7
        return "liquid"
    end

    # Additional crystal detection
    if σ_φ < 1.0 && max_cluster_frac > 0.3
        return "crystal"
    end

    # Additional gas detection
    if σ_φ > 1.0 && Ψ < 0.5
        return "gas"
    end

    # Transition region
    if 0.4 <= σ_φ <= 0.6 || 0.6 <= Ψ <= 0.8
        return "transition"
    end

    return "liquid"  # Default fallback
end

# ============================================================================
# Clustering Analysis Functions
# ============================================================================

"""
    calculate_clusters(phi_values, threshold=0.3)

Identify clusters based on angular proximity.
Returns (n_clusters, max_cluster_size, cluster_sizes).
"""
function calculate_clusters(phi_values::Vector{Float64}, threshold::Float64=0.3)
    N = length(phi_values)
    if N == 0
        return 0, 0, Int[]
    end

    # Sort particles by position
    sorted_idx = sortperm(phi_values)
    sorted_phi = phi_values[sorted_idx]

    # Find clusters using gap detection
    clusters = Vector{Int}[]
    current_cluster = [sorted_idx[1]]

    for i in 2:N
        gap = sorted_phi[i] - sorted_phi[i-1]

        if gap < threshold
            push!(current_cluster, sorted_idx[i])
        else
            push!(clusters, current_cluster)
            current_cluster = [sorted_idx[i]]
        end
    end

    # Check wraparound gap
    wraparound_gap = 2π - sorted_phi[end] + sorted_phi[1]
    if wraparound_gap < threshold && length(clusters) > 0
        append!(clusters[1], current_cluster)
    else
        push!(clusters, current_cluster)
    end

    cluster_sizes = [length(c) for c in clusters]
    n_clusters = length(clusters)
    max_size = maximum(cluster_sizes)

    return n_clusters, max_size, cluster_sizes
end

"""
    calculate_order_parameter(phi_values)

Calculate orientational order parameter Ψ = |⟨e^{iφ}⟩|.
Ψ = 1 means all particles at same position, Ψ = 0 means uniform distribution.
"""
function calculate_order_parameter(phi_values::Vector{Float64})
    N = length(phi_values)
    if N == 0
        return 0.0
    end

    z = sum(exp(im * φ) for φ in phi_values) / N
    return abs(z)
end

"""
    calculate_radius_of_gyration(phi_values)

Calculate normalized radius of gyration in angular space.
"""
function calculate_radius_of_gyration(phi_values::Vector{Float64})
    N = length(phi_values)
    if N <= 1
        return 0.0
    end

    sin_mean = mean(sin.(phi_values))
    cos_mean = mean(cos.(phi_values))
    φ_mean = atan(sin_mean, cos_mean)

    R² = sum((mod(φ - φ_mean + π, 2π) - π)^2 for φ in phi_values) / N
    return sqrt(R²) / π
end

# ============================================================================
# HDF5-based Analysis Functions
# ============================================================================

"""
    analyze_simulation_from_hdf5(h5_file::String)

Analyze a single simulation from HDF5 file and extract phase classification metrics.

HDF5 format:
- times: vector of snapshot times
- phi: matrix (n_snapshots × N) of angular positions
- phidot: matrix (n_snapshots × N) of angular velocities
- conservation: (times, total_energy, dE_E0)
"""
function analyze_simulation_from_hdf5(h5_file::String)
    if !isfile(h5_file)
        return nothing
    end

    result = load_trajectories_hdf5(h5_file)
    if result === nothing
        return nothing
    end

    # phi is a matrix: n_snapshots × N
    n_snapshots = size(result.phi, 1)
    N = size(result.phi, 2)

    if n_snapshots == 0 || N == 0
        return nothing
    end

    metrics = Dict{String, Any}()

    # Final state analysis (last row of phi matrix)
    phi_final = Vector{Float64}(result.phi[end, :])

    σ_φ_final = std(phi_final)
    Ψ_final = calculate_order_parameter(phi_final)
    R_final = calculate_radius_of_gyration(phi_final)
    n_clusters, max_size, _ = calculate_clusters(phi_final)
    max_cluster_frac = max_size / N

    # Phase classification
    phase = classify_phase(σ_φ_final, n_clusters, N, max_cluster_frac, Ψ_final)

    # Time evolution analysis (for stability check)
    if n_snapshots >= 5
        start_idx = max(1, Int(round(0.8 * n_snapshots)))
        σ_φ_values = Float64[]
        Ψ_values = Float64[]

        for i in start_idx:n_snapshots
            phi = Vector{Float64}(result.phi[i, :])
            push!(σ_φ_values, std(phi))
            push!(Ψ_values, calculate_order_parameter(phi))
        end

        metrics["sigma_phi_mean_late"] = mean(σ_φ_values)
        metrics["sigma_phi_std_late"] = std(σ_φ_values)
        metrics["Psi_mean_late"] = mean(Ψ_values)
        metrics["Psi_std_late"] = std(Ψ_values)
        metrics["phase_stable"] = metrics["sigma_phi_std_late"] < 0.1
    else
        metrics["sigma_phi_mean_late"] = σ_φ_final
        metrics["sigma_phi_std_late"] = 0.0
        metrics["Psi_mean_late"] = Ψ_final
        metrics["Psi_std_late"] = 0.0
        metrics["phase_stable"] = true
    end

    # Store all metrics
    metrics["N"] = N
    metrics["sigma_phi_final"] = σ_φ_final
    metrics["Psi_final"] = Ψ_final
    metrics["R_final"] = R_final
    metrics["n_clusters"] = n_clusters
    metrics["max_cluster_size"] = max_size
    metrics["max_cluster_frac"] = max_cluster_frac
    metrics["phase"] = phase

    # Energy conservation check
    if result.conservation !== nothing && length(result.conservation.total_energy) > 0
        E0 = result.conservation.total_energy[1]
        Ef = result.conservation.total_energy[end]
        metrics["dE_E0"] = abs(Ef - E0) / abs(E0)
    else
        metrics["dE_E0"] = NaN
    end

    return metrics
end

"""
    extract_params_from_dirname(dirname::String)

Extract simulation parameters from directory name.
Supports formats:
- e0.90_N040_seed01 (intrinsic_v3 format)
- e0.866_N40_phi0.06_E0.32 (E/N scan format)
"""
function extract_params_from_dirname(dirname::String)
    params = Dict{String, Any}()

    # Try to extract eccentricity
    m = match(r"e(\d+\.?\d*)", dirname)
    if m !== nothing
        params["e"] = parse(Float64, m.captures[1])
    end

    # Try to extract N
    m = match(r"N(\d+)", dirname)
    if m !== nothing
        params["N"] = parse(Int, m.captures[1])
    end

    # Try to extract seed
    m = match(r"seed(\d+)", dirname)
    if m !== nothing
        params["seed"] = parse(Int, m.captures[1])
    end

    # Try to extract E_per_N (for E/N scan campaigns)
    m = match(r"E(\d+\.?\d*)", dirname)
    if m !== nothing
        params["E_per_N"] = parse(Float64, m.captures[1])
    end

    # Try to extract phi (packing fraction)
    m = match(r"phi(\d+\.?\d*)", dirname)
    if m !== nothing
        params["phi"] = parse(Float64, m.captures[1])
    end

    return params
end

"""
    extract_phase_metrics(summary_json::String)

Extract key metrics from summary.json for phase classification (legacy format).
"""
function extract_phase_metrics(summary_json::String)
    data = JSON.parsefile(summary_json)

    # Extract metrics directly or compute from stored data
    σ_φ_final = get(data, "sigma_phi_final", get(data, "phi_std_final", NaN))
    N = get(data, "N", 40)

    return (
        σ_φ_final = σ_φ_final,
        N = N,
        E_per_N = get(data, "E_per_N", NaN),
        eccentricity = get(data, "eccentricity", NaN),
        seed = get(data, "seed", 0),
        is_clustered = get(data, "is_clustered", false)
    )
end

# ============================================================================
# Main Campaign Analysis
# ============================================================================

"""
    classify_campaign_phases(campaign_dir::String)

Classify all simulations in a campaign into phases.
Works with both intrinsic_v3 format (e0.90_N040_seed01/) and E/N scan format.

Returns DataFrame with classification results.
"""
function classify_campaign_phases(campaign_dir::String)
    println("="^70)
    println("Phase Classification Analysis")
    println("="^70)
    println("Campaign: $campaign_dir")
    println()

    # Find all simulation directories
    subdirs = filter(d -> isdir(joinpath(campaign_dir, d)), readdir(campaign_dir))

    # Filter to directories that contain trajectories.h5 (intrinsic_v3 format)
    sim_dirs = filter(subdirs) do d
        isfile(joinpath(campaign_dir, d, "trajectories.h5"))
    end

    n_sims = length(sim_dirs)
    println("Found $n_sims simulation directories with HDF5 data")
    println()

    if n_sims == 0
        println("ERROR: No simulation directories found!")
        println("Expected format: e0.XX_NXXX_seedXX/ with trajectories.h5")
        return DataFrame()
    end

    # Collect results
    results = DataFrame()

    for (i, sim_dir) in enumerate(sim_dirs)
        h5_file = joinpath(campaign_dir, sim_dir, "trajectories.h5")

        # Extract parameters from directory name
        params = extract_params_from_dirname(sim_dir)

        # Analyze simulation
        metrics = analyze_simulation_from_hdf5(h5_file)

        if metrics !== nothing
            row = Dict{String, Any}()
            row["sim_dir"] = sim_dir

            # Add parameters
            for (k, v) in params
                row[k] = v
            end

            # Add metrics
            for (k, v) in metrics
                row[k] = v
            end

            push!(results, row; cols=:union)
        end

        if i % 10 == 0 || i == n_sims
            println("  Processed $i / $n_sims")
        end
    end

    if isempty(results) || nrow(results) == 0
        println("ERROR: No data collected!")
        return results
    end

    println()
    println("Successfully analyzed $(nrow(results)) simulations")
    println()

    # Compute phase statistics
    phase_counts = Dict{String, Int}()
    for phase in results.phase
        phase_counts[phase] = get(phase_counts, phase, 0) + 1
    end

    println("Phase distribution:")
    for (phase, count) in sort(collect(phase_counts), by=x->-x[2])
        frac = count / nrow(results) * 100
        println("  $phase: $count ($(round(frac, digits=1))%)")
    end
    println()

    # Create output directory
    output_dir = joinpath(campaign_dir, "phase_analysis")
    mkpath(output_dir)

    # Save results
    output_file = joinpath(output_dir, "phase_classification_results.csv")
    CSV.write(output_file, results)
    println("Saved classification results to: $output_file")

    # Generate summary by eccentricity
    if "e" in names(results)
        generate_phase_summary_by_eccentricity(results, output_dir)
    end

    return results
end

"""
    generate_phase_summary_by_eccentricity(results::DataFrame, output_dir::String)

Generate phase summary statistics grouped by eccentricity.
"""
function generate_phase_summary_by_eccentricity(results::DataFrame, output_dir::String)
    println()
    println("="^70)
    println("Phase Distribution by Eccentricity")
    println("="^70)

    e_values = sort(unique(results.e))

    summary_rows = []

    for e in e_values
        subset = filter(row -> row.e == e, results)
        n_total = nrow(subset)

        gas_count = count(row -> row.phase == "gas", eachrow(subset))
        liquid_count = count(row -> row.phase == "liquid", eachrow(subset))
        crystal_count = count(row -> row.phase == "crystal", eachrow(subset))
        trans_count = count(row -> row.phase == "transition", eachrow(subset))

        println(@sprintf("e = %.2f (n=%d):", e, n_total))
        println(@sprintf("  GAS: %d (%.0f%%), LIQUID: %d (%.0f%%), CRYSTAL: %d (%.0f%%), TRANS: %d (%.0f%%)",
            gas_count, 100*gas_count/n_total,
            liquid_count, 100*liquid_count/n_total,
            crystal_count, 100*crystal_count/n_total,
            trans_count, 100*trans_count/n_total))

        # Average metrics
        σ_mean = mean(subset.sigma_phi_final)
        Ψ_mean = mean(subset.Psi_final)
        println(@sprintf("  ⟨σ_φ⟩ = %.3f, ⟨Ψ⟩ = %.3f", σ_mean, Ψ_mean))
        println()

        # Add to summary
        push!(summary_rows, (
            eccentricity = e,
            n_total = n_total,
            n_gas = gas_count,
            n_liquid = liquid_count,
            n_crystal = crystal_count,
            n_transition = trans_count,
            frac_gas = gas_count/n_total,
            frac_liquid = liquid_count/n_total,
            frac_crystal = crystal_count/n_total,
            frac_transition = trans_count/n_total,
            mean_sigma_phi = σ_mean,
            mean_Psi = Ψ_mean
        ))
    end

    # Save summary
    summary_df = DataFrame(summary_rows)
    summary_file = joinpath(output_dir, "phase_summary_by_eccentricity.csv")
    CSV.write(summary_file, summary_df)
    println("Saved summary to: $summary_file")

    # Identify phase boundaries
    println()
    println("="^70)
    println("Phase Boundary Identification")
    println("="^70)

    for i in 1:(length(e_values)-1)
        e1, e2 = e_values[i], e_values[i+1]

        subset1 = filter(row -> row.e == e1, results)
        subset2 = filter(row -> row.e == e2, results)

        crystal_frac1 = count(row -> row.phase == "crystal", eachrow(subset1)) / nrow(subset1)
        crystal_frac2 = count(row -> row.phase == "crystal", eachrow(subset2)) / nrow(subset2)

        # Check for phase transition
        if abs(crystal_frac2 - crystal_frac1) > 0.3
            e_crit = (e1 + e2) / 2
            println(@sprintf("Transition detected between e=%.2f and e=%.2f", e1, e2))
            println(@sprintf("  Crystal fraction: %.1f%% → %.1f%%", 100*crystal_frac1, 100*crystal_frac2))
            println(@sprintf("  Estimated e_c ≈ %.3f", e_crit))
        end
    end

    # Generate markdown report
    generate_phase_report(results, output_dir)

    return summary_df
end

"""
    generate_phase_report(results::DataFrame, output_dir::String)

Generate markdown report of phase classification results.
"""
function generate_phase_report(results::DataFrame, output_dir::String)
    report_file = joinpath(output_dir, "phase_classification_report.md")

    open(report_file, "w") do io
        println(io, "# Phase Classification Report")
        println(io)
        println(io, "Generated: $(now())")
        println(io)
        println(io, "## Summary")
        println(io)
        println(io, "- Total simulations analyzed: $(nrow(results))")
        println(io)

        # Phase counts
        phase_counts = Dict{String, Int}()
        for phase in results.phase
            phase_counts[phase] = get(phase_counts, phase, 0) + 1
        end

        println(io, "## Phase Distribution")
        println(io)
        println(io, "| Phase | Count | Percentage |")
        println(io, "|-------|-------|------------|")
        for (phase, count) in sort(collect(phase_counts), by=x->-x[2])
            pct = 100 * count / nrow(results)
            println(io, "| $phase | $count | $(@sprintf("%.1f", pct))% |")
        end
        println(io)

        # By eccentricity
        if "e" in names(results)
            println(io, "## Phase Distribution by Eccentricity")
            println(io)
            println(io, "| e | n | Gas | Liquid | Crystal | Trans | ⟨σ_φ⟩ | ⟨Ψ⟩ |")
            println(io, "|---|---|-----|--------|---------|-------|-------|-----|")

            for e in sort(unique(results.e))
                subset = filter(row -> row.e == e, results)
                n = nrow(subset)

                gas = count(row -> row.phase == "gas", eachrow(subset))
                liq = count(row -> row.phase == "liquid", eachrow(subset))
                crys = count(row -> row.phase == "crystal", eachrow(subset))
                trans = count(row -> row.phase == "transition", eachrow(subset))

                σ = mean(subset.sigma_phi_final)
                Ψ = mean(subset.Psi_final)

                println(io, @sprintf("| %.2f | %d | %d | %d | %d | %d | %.3f | %.3f |",
                    e, n, gas, liq, crys, trans, σ, Ψ))
            end
            println(io)
        end

        println(io, "## Classification Criteria")
        println(io)
        println(io, "- **Crystal**: σ_φ < 0.5 AND (n_clusters ≤ 2 OR max_cluster_frac > 0.5)")
        println(io, "- **Gas**: σ_φ > 1.5 AND n_clusters > N/2 AND Ψ < 0.3")
        println(io, "- **Liquid**: 0.5 ≤ σ_φ ≤ 1.5 AND 0.3 ≤ Ψ ≤ 0.7")
        println(io, "- **Transition**: Mixed characteristics near phase boundaries")
    end

    println()
    println("Saved report to: $report_file")
end

# ========================================
# Main Execution
# ========================================

if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) < 1
        println("Usage: julia --project=. scripts/analysis/analyze_phase_classification.jl <campaign_dir>")
        println()
        println("Examples:")
        println("  julia --project=. scripts/analysis/analyze_phase_classification.jl results/intrinsic_v3_campaign_20251126_110434/")
        println("  julia --project=. scripts/analysis/analyze_phase_classification.jl results/campaign_EN_scan_*/")
        exit(1)
    end

    campaign_dir = ARGS[1]

    if !isdir(campaign_dir)
        println("ERROR: Directory not found: $campaign_dir")
        exit(1)
    end

    # Run classification
    results = classify_campaign_phases(campaign_dir)

    if isempty(results) || nrow(results) == 0
        println("ERROR: No results generated!")
        exit(1)
    end

    println()
    println("="^70)
    println("Analysis Complete!")
    println("="^70)
    println()
    println("Results saved to: $(joinpath(campaign_dir, "phase_analysis"))/")
    println("  - phase_classification_results.csv")
    println("  - phase_summary_by_eccentricity.csv")
    println("  - phase_classification_report.md")
end
