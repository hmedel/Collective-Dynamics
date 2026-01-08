#!/usr/bin/env julia
"""
Verify Theoretical Prediction: ρ(φ) ∝ √g_φφ(φ)

For an ellipse with semi-axes (a, b), the metric tensor component is:
    g_φφ(φ) = a²sin²(φ) + b²cos²(φ)

The theoretical prediction (from equilibrium statistical mechanics on curved manifolds)
is that the steady-state angular density should be:
    ρ(φ) ∝ √g_φφ(φ)

This script:
1. Extracts time-averaged angular density from simulation data
2. Computes theoretical prediction √g_φφ(φ)
3. Compares measured vs predicted
4. Quantifies agreement via correlation and fit quality

Usage:
    julia --project=. scripts/analysis/verify_metric_density_prediction.jl <campaign_dir> [output_dir]
"""

using Pkg
Pkg.activate(".")

using HDF5
using Statistics
using LinearAlgebra
using Printf
using CSV
using DataFrames

# ============================================================================
# THEORETICAL PREDICTION
# ============================================================================

"""
Metric tensor component g_φφ for an ellipse.
    g_φφ(φ) = a²sin²(φ) + b²cos²(φ)
"""
function g_phiphi(φ::Real, a::Real, b::Real)
    return a^2 * sin(φ)^2 + b^2 * cos(φ)^2
end

"""
Predicted density: ρ(φ) ∝ √g_φφ(φ)
Returns normalized density (integrates to 1 over [0, 2π]).
"""
function predicted_density(φ_centers::Vector{<:Real}, a::Real, b::Real)
    ρ = [sqrt(g_phiphi(φ, a, b)) for φ in φ_centers]
    # Normalize: ∫ρ dφ = 1
    dφ = φ_centers[2] - φ_centers[1]
    ρ ./= sum(ρ) * dφ
    return ρ
end

"""
Compute eccentricity from semi-axes.
"""
function eccentricity(a::Real, b::Real)
    if a >= b
        return sqrt(1 - (b/a)^2)
    else
        return sqrt(1 - (a/b)^2)
    end
end

# ============================================================================
# DATA EXTRACTION
# ============================================================================

"""
Extract time-averaged angular density from HDF5 file.
Uses second half of simulation to focus on steady-state.
"""
function extract_angular_density(h5_file::String; n_bins=36, use_second_half=true)
    h5open(h5_file, "r") do fid
        times = read(fid, "trajectories/time")
        phi = read(fid, "trajectories/phi")

        # Handle data orientation
        if size(phi, 1) == length(times)
            n_times, N = size(phi)
        else
            phi = phi'
            n_times, N = size(phi)
        end

        # Use second half for steady-state average
        start_idx = use_second_half ? (n_times ÷ 2) : 1

        # Bin edges and centers
        bin_edges = range(0, 2π, length=n_bins+1)
        bin_width = 2π / n_bins
        bin_centers = [(i - 0.5) * bin_width for i in 1:n_bins]

        # Accumulate histogram over time
        total_counts = zeros(n_bins)
        n_samples = 0

        for t_idx in start_idx:n_times
            for p in 1:N
                φ = mod(phi[t_idx, p], 2π)
                bin_idx = min(n_bins, max(1, ceil(Int, φ / bin_width)))
                total_counts[bin_idx] += 1
            end
            n_samples += N
        end

        # Normalize to density (probability per unit angle)
        ρ_measured = total_counts ./ (n_samples * bin_width)

        return bin_centers, ρ_measured, N, times[end] - times[start_idx]
    end
end

"""
Parse simulation parameters from directory name or config.
Format: e0.50_N040_E0.10_t500_seed01
"""
function parse_params(dirname::String)
    parts = split(dirname, "_")
    e = parse(Float64, replace(parts[1], "e" => ""))
    N = parse(Int, replace(parts[2], "N" => ""))
    E_per_N = parse(Float64, replace(parts[3], "E" => ""))

    # Reconstruct semi-axes from eccentricity (assuming a=2.0 convention)
    a = 2.0
    b = a * sqrt(1 - e^2)

    return (e=e, N=N, E_per_N=E_per_N, a=a, b=b)
end

# ============================================================================
# COMPARISON METRICS
# ============================================================================

"""
Compute Pearson correlation coefficient.
"""
function correlation(x::Vector{<:Real}, y::Vector{<:Real})
    μx, μy = mean(x), mean(y)
    σx, σy = std(x), std(y)
    return sum((x .- μx) .* (y .- μy)) / ((length(x) - 1) * σx * σy)
end

"""
Compute R² (coefficient of determination) for ρ_measured vs ρ_predicted.
"""
function r_squared(y_measured::Vector{<:Real}, y_predicted::Vector{<:Real})
    ss_res = sum((y_measured .- y_predicted).^2)
    ss_tot = sum((y_measured .- mean(y_measured)).^2)
    return 1 - ss_res / ss_tot
end

"""
Compute χ² per degree of freedom.
Assumes Poisson statistics for bin counts.
"""
function chi_squared(y_measured::Vector{<:Real}, y_predicted::Vector{<:Real}, n_counts::Vector{<:Real})
    # Avoid division by zero
    mask = n_counts .> 0
    χ² = sum((y_measured[mask] .- y_predicted[mask]).^2 ./ max.(y_predicted[mask], 1e-10))
    dof = sum(mask) - 1  # Subtract 1 for normalization constraint
    return χ² / dof
end

"""
Kolmogorov-Smirnov statistic between cumulative distributions.
"""
function ks_statistic(ρ1::Vector{<:Real}, ρ2::Vector{<:Real})
    # Normalize to sum to 1
    p1 = ρ1 ./ sum(ρ1)
    p2 = ρ2 ./ sum(ρ2)

    # Cumulative distributions
    cdf1 = cumsum(p1)
    cdf2 = cumsum(p2)

    return maximum(abs.(cdf1 .- cdf2))
end

# ============================================================================
# MAIN ANALYSIS
# ============================================================================

function analyze_campaign(campaign_dir::String, output_dir::String)
    mkpath(output_dir)

    println("="^70)
    println("VERIFICATION: ρ(φ) ∝ √g_φφ(φ)")
    println("="^70)
    println("Campaign: $campaign_dir")
    println("Output: $output_dir")
    println()

    results = DataFrame()
    n_bins = 36

    # Find all simulation directories
    for dir in readdir(campaign_dir, join=true)
        h5_file = joinpath(dir, "trajectories.h5")
        if !isfile(h5_file)
            continue
        end

        dirname = basename(dir)
        try
            params = parse_params(dirname)

            # Extract measured density
            φ_centers, ρ_measured, N, t_avg = extract_angular_density(h5_file; n_bins=n_bins)

            # Compute predicted density
            ρ_predicted = predicted_density(φ_centers, params.a, params.b)

            # Normalize measured to same scale
            dφ = 2π / n_bins
            ρ_measured_norm = ρ_measured ./ (sum(ρ_measured) * dφ)

            # Compute comparison metrics
            corr = correlation(ρ_measured_norm, ρ_predicted)
            R² = r_squared(ρ_measured_norm, ρ_predicted)
            ks = ks_statistic(ρ_measured_norm, ρ_predicted)

            # Store results
            row = Dict(
                "dirname" => dirname,
                "e" => params.e,
                "N" => params.N,
                "E_per_N" => params.E_per_N,
                "a" => params.a,
                "b" => params.b,
                "t_avg" => t_avg,
                "correlation" => corr,
                "R_squared" => R²,
                "KS_statistic" => ks,
                "rho_max" => maximum(ρ_measured_norm),
                "rho_min" => minimum(ρ_measured_norm),
                "rho_ratio" => maximum(ρ_measured_norm) / minimum(ρ_measured_norm),
                "pred_ratio" => maximum(ρ_predicted) / minimum(ρ_predicted)
            )
            push!(results, row, cols=:union)

            @printf("  %s: R²=%.4f, corr=%.4f, KS=%.4f\n",
                    dirname, R², corr, ks)

        catch ex
            @warn "Error analyzing $dirname: $ex"
        end
    end

    println("\n" * "="^70)
    println("SUMMARY BY ECCENTRICITY")
    println("="^70)

    # Summary by eccentricity
    for e_val in sort(unique(results.e))
        subset = filter(r -> r.e == e_val, results)

        println("\n--- e = $e_val ($(nrow(subset)) runs) ---")
        @printf("  Predicted ρ_max/ρ_min ratio: %.4f\n", mean(subset.pred_ratio))
        @printf("  Measured  ρ_max/ρ_min ratio: %.4f ± %.4f\n",
                mean(subset.rho_ratio), std(subset.rho_ratio))
        @printf("  Correlation:  %.4f ± %.4f\n", mean(subset.correlation), std(subset.correlation))
        @printf("  R²:           %.4f ± %.4f\n", mean(subset.R_squared), std(subset.R_squared))
        @printf("  KS statistic: %.4f ± %.4f\n", mean(subset.KS_statistic), std(subset.KS_statistic))

        if mean(subset.R_squared) > 0.8
            println("  ✓ GOOD AGREEMENT with prediction")
        elseif mean(subset.R_squared) > 0.5
            println("  ~ MODERATE agreement with prediction")
        else
            println("  ✗ POOR agreement - deviations from equilibrium prediction")
        end
    end

    println("\n" * "="^70)
    println("SUMMARY BY E/N (Temperature)")
    println("="^70)

    for E_val in sort(unique(results.E_per_N))
        subset = filter(r -> r.E_per_N == E_val, results)

        println("\n--- E/N = $E_val ($(nrow(subset)) runs) ---")
        @printf("  Correlation:  %.4f ± %.4f\n", mean(subset.correlation), std(subset.correlation))
        @printf("  R²:           %.4f ± %.4f\n", mean(subset.R_squared), std(subset.R_squared))
    end

    # Generate example density comparison plot data
    println("\n" * "="^70)
    println("GENERATING PLOT DATA")
    println("="^70)

    # Pick representative runs for each eccentricity
    for e_val in sort(unique(results.e))
        subset = filter(r -> r.e == e_val, results)
        if nrow(subset) == 0
            continue
        end

        # Take first run as example
        example_dir = joinpath(campaign_dir, subset.dirname[1])
        h5_file = joinpath(example_dir, "trajectories.h5")

        params = parse_params(subset.dirname[1])
        φ_centers, ρ_measured, N, t_avg = extract_angular_density(h5_file; n_bins=n_bins)
        ρ_predicted = predicted_density(φ_centers, params.a, params.b)

        # Normalize measured
        dφ = 2π / n_bins
        ρ_measured_norm = ρ_measured ./ (sum(ρ_measured) * dφ)

        # Save comparison data
        e_str = @sprintf("%.2f", e_val)
        plot_file = joinpath(output_dir, "density_comparison_e$(e_str).csv")

        df = DataFrame(
            phi = φ_centers,
            phi_deg = rad2deg.(φ_centers),
            rho_measured = ρ_measured_norm,
            rho_predicted = ρ_predicted,
            g_phiphi = [g_phiphi(φ, params.a, params.b) for φ in φ_centers],
            sqrt_g = [sqrt(g_phiphi(φ, params.a, params.b)) for φ in φ_centers]
        )
        CSV.write(plot_file, df)
        println("Saved: $plot_file")
    end

    # Save all results
    results_file = joinpath(output_dir, "metric_density_verification.csv")
    CSV.write(results_file, results)
    println("\nSaved: $results_file")

    # Final interpretation
    println("\n" * "="^70)
    println("INTERPRETATION")
    println("="^70)

    mean_R² = mean(results.R_squared)
    mean_corr = mean(results.correlation)

    println()
    if mean_R² > 0.8 && mean_corr > 0.9
        println("✓ STRONG SUPPORT for ρ(φ) ∝ √g_φφ(φ) prediction")
        println("  The system reaches quasi-equilibrium consistent with")
        println("  the invariant measure √g on the curved manifold.")
    elseif mean_R² > 0.5
        println("~ PARTIAL SUPPORT for the prediction")
        println("  Deviations may indicate:")
        println("  - Non-equilibrium dynamics (metastable clusters)")
        println("  - Insufficient averaging time")
        println("  - Collision-induced correlations not captured by simple model")
    else
        println("✗ DEVIATION from equilibrium prediction")
        println("  The system is NOT in simple thermal equilibrium.")
        println("  This could indicate:")
        println("  - Strong clustering (two-cluster states)")
        println("  - Metastable dynamics")
        println("  - Need for longer simulations")
    end

    println("\n" * "="^70)

    return results
end

# ============================================================================
# MAIN
# ============================================================================

if length(ARGS) < 1
    println("Usage: julia verify_metric_density_prediction.jl <campaign_dir> [output_dir]")
    println()
    println("Verifies the theoretical prediction ρ(φ) ∝ √g_φφ(φ)")
    println("where g_φφ = a²sin²(φ) + b²cos²(φ) is the metric tensor.")
    exit(1)
end

campaign_dir = ARGS[1]
output_dir = length(ARGS) >= 2 ? ARGS[2] : joinpath(campaign_dir, "metric_verification")

analyze_campaign(campaign_dir, output_dir)
