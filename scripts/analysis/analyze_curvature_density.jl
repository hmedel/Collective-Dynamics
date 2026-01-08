#!/usr/bin/env julia
"""
Curvature-Density Correlation Analysis

Analyzes whether particles accumulate in regions of high/low curvature.
For an ellipse: κ(φ) = ab / (a²sin²φ + b²cos²φ)^(3/2)

Key questions:
- Do particles prefer high-curvature regions (ends of ellipse)?
- Does this preference change with eccentricity?
- Is clustering driven by curvature?

Usage:
    julia --project=. scripts/analysis/analyze_curvature_density.jl <campaign_dir>
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
# Curvature Functions
# ============================================================================

"""
Curvature of ellipse at angle φ (polar angle parameterization)
κ(φ) = ab / (a²sin²φ + b²cos²φ)^(3/2)
"""
function curvature_ellipse(φ::Float64, a::Float64, b::Float64)
    sin_φ = sin(φ)
    cos_φ = cos(φ)
    denom = (a^2 * sin_φ^2 + b^2 * cos_φ^2)^1.5
    return a * b / denom
end

"""
Get curvature at each particle position
"""
function particle_curvatures(phi_values::Vector{Float64}, a::Float64, b::Float64)
    return [curvature_ellipse(φ, a, b) for φ in phi_values]
end

"""
Compute local density in angular bins
"""
function angular_density(phi_values::Vector{Float64}, n_bins::Int=36)
    N = length(phi_values)
    bin_edges = range(0, 2π, length=n_bins+1)
    bin_centers = [(bin_edges[i] + bin_edges[i+1])/2 for i in 1:n_bins]

    counts = zeros(Int, n_bins)
    for φ in phi_values
        φ_wrapped = mod(φ, 2π)
        bin_idx = min(n_bins, Int(floor(φ_wrapped / (2π/n_bins))) + 1)
        counts[bin_idx] += 1
    end

    # Normalize to density
    density = counts ./ (N * 2π/n_bins)

    return bin_centers, density
end

"""
Compute correlation between curvature and density
"""
function curvature_density_correlation(phi_values::Vector{Float64}, a::Float64, b::Float64; n_bins::Int=36)
    bin_centers, density = angular_density(phi_values, n_bins)

    # Curvature at bin centers
    κ_bins = [curvature_ellipse(φ, a, b) for φ in bin_centers]

    # Pearson correlation
    mean_κ = mean(κ_bins)
    mean_ρ = mean(density)

    cov_κρ = mean((κ_bins .- mean_κ) .* (density .- mean_ρ))
    std_κ = std(κ_bins)
    std_ρ = std(density)

    correlation = std_κ * std_ρ > 0 ? cov_κρ / (std_κ * std_ρ) : 0.0

    return correlation, κ_bins, density
end

# ============================================================================
# Analysis Functions
# ============================================================================

function analyze_simulation_curvature(h5_file::String, e::Float64)
    !isfile(h5_file) && return nothing

    result = load_trajectories_hdf5(h5_file)
    result === nothing && return nothing

    n_snapshots = size(result.phi, 1)
    N = size(result.phi, 2)
    n_snapshots == 0 && return nothing

    # Geometry from eccentricity
    b = 1.0
    a = e ≈ 0.0 ? 1.0 : b / sqrt(1 - e^2)

    # Compute curvature statistics
    κ_max = a * b / b^3  # At φ = 0, π (ends)
    κ_min = a * b / a^3  # At φ = π/2, 3π/2 (sides)
    κ_ratio = κ_max / κ_min

    metrics = Dict{String, Any}()
    metrics["N"] = N
    metrics["a"] = a
    metrics["b"] = b
    metrics["kappa_max"] = κ_max
    metrics["kappa_min"] = κ_min
    metrics["kappa_ratio"] = κ_ratio

    # Time-averaged correlation
    correlations = Float64[]
    density_at_high_κ = Float64[]  # Density at high curvature (ends)
    density_at_low_κ = Float64[]   # Density at low curvature (sides)

    for i in 1:n_snapshots
        phi = Vector{Float64}(result.phi[i, :])

        corr, κ_bins, density = curvature_density_correlation(phi, a, b)
        push!(correlations, corr)

        # Density at high vs low curvature regions
        # High κ: near φ = 0, π (ends)
        # Low κ: near φ = π/2, 3π/2 (sides)
        n_bins = length(density)
        high_κ_bins = vcat(1:3, n_bins-2:n_bins, Int(n_bins/2)-1:Int(n_bins/2)+1)
        low_κ_bins = vcat(Int(n_bins/4)-1:Int(n_bins/4)+1, Int(3*n_bins/4)-1:Int(3*n_bins/4)+1)

        high_κ_bins = filter(x -> 1 <= x <= n_bins, high_κ_bins)
        low_κ_bins = filter(x -> 1 <= x <= n_bins, low_κ_bins)

        push!(density_at_high_κ, mean(density[high_κ_bins]))
        push!(density_at_low_κ, mean(density[low_κ_bins]))
    end

    # Statistics
    metrics["correlation_mean"] = mean(correlations)
    metrics["correlation_std"] = std(correlations)
    metrics["correlation_final"] = correlations[end]

    # Density ratio: high_κ / low_κ regions
    density_ratio = density_at_high_κ ./ (density_at_low_κ .+ 1e-10)
    metrics["density_ratio_mean"] = mean(density_ratio)
    metrics["density_ratio_final"] = density_ratio[end]

    # Late-time (last 20%)
    late_start = max(1, Int(round(0.8 * n_snapshots)))
    metrics["correlation_late"] = mean(correlations[late_start:end])
    metrics["density_ratio_late"] = mean(density_ratio[late_start:end])

    # Interpretation
    metrics["prefers_high_curvature"] = metrics["correlation_mean"] > 0.1
    metrics["prefers_low_curvature"] = metrics["correlation_mean"] < -0.1

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
    length(ARGS) < 1 && (println("Usage: julia analyze_curvature_density.jl <dir>"); return)

    campaign_dir = ARGS[1]
    !isdir(campaign_dir) && (println("Not found: $campaign_dir"); return)

    println("="^60)
    println("CURVATURE-DENSITY CORRELATION ANALYSIS")
    println("="^60)
    println("Campaign: $campaign_dir\n")

    subdirs = filter(d -> isdir(joinpath(campaign_dir, d)), readdir(campaign_dir))
    sim_dirs = filter(d -> isfile(joinpath(campaign_dir, d, "trajectories.h5")), subdirs)

    println("Found $(length(sim_dirs)) simulations\n")

    results = DataFrame()

    for (i, sim_dir) in enumerate(sim_dirs)
        h5_file = joinpath(campaign_dir, sim_dir, "trajectories.h5")
        params = extract_params(sim_dir)

        e = get(params, "e", 0.0)
        metrics = analyze_simulation_curvature(h5_file, e)

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
    println("CURVATURE-DENSITY CORRELATION BY ECCENTRICITY")
    println("="^60)

    for e in sort(unique(results.e))
        subset = filter(row -> row.e == e, results)
        n = nrow(subset)

        corr_mean = mean(subset.correlation_mean)
        corr_std = std(subset.correlation_mean)
        κ_ratio = mean(subset.kappa_ratio)
        dens_ratio = mean(subset.density_ratio_late)

        println(@sprintf("\ne = %.2f (n = %d)", e, n))
        println("-"^40)
        println(@sprintf("  κ_max/κ_min:          %.2f", κ_ratio))
        println(@sprintf("  ρ(high κ)/ρ(low κ):   %.3f", dens_ratio))
        println(@sprintf("  Correlation ⟨ρ,κ⟩:    %.3f ± %.3f", corr_mean, corr_std))

        if corr_mean > 0.2
            println("  → Particles PREFER high curvature (ends)")
        elseif corr_mean < -0.2
            println("  → Particles PREFER low curvature (sides)")
        else
            println("  → No strong curvature preference")
        end
    end

    # Physical interpretation
    println("\n" * "="^60)
    println("PHYSICAL INTERPRETATION")
    println("="^60)
    println()

    overall_corr = mean(results.correlation_mean)
    if abs(overall_corr) < 0.1
        println("Weak correlation: Curvature is NOT the primary driver of clustering")
        println("The system distributes fairly uniformly regardless of local curvature")
    elseif overall_corr > 0
        println("Positive correlation: Particles accumulate at HIGH curvature regions")
        println("This could indicate a geometric trapping mechanism at ellipse ends")
    else
        println("Negative correlation: Particles accumulate at LOW curvature regions")
        println("Particles may be avoiding the sharp curvature at ellipse ends")
    end

    # Save
    output_dir = joinpath(campaign_dir, "curvature_analysis")
    mkpath(output_dir)
    CSV.write(joinpath(output_dir, "curvature_density_correlation.csv"), results)

    println("\n" * "="^60)
    println("Saved to: $(joinpath(output_dir, "curvature_density_correlation.csv"))")
    println("="^60)
end

main()
