#!/usr/bin/env julia
"""
Velocity Distribution Analysis
Analyzes evolution of P(φ̇, t) to test quasi-thermalization hypothesis

Tests:
1. Is P(φ̇) → Gaussian (Maxwell-Boltzmann-like)?
2. What is relaxation time τ_thermal?
3. Does system approach thermal equilibrium?

Usage:
    julia --project=. analyze_velocity_distributions.jl <hdf5_file_or_directory>
"""

using HDF5
using Statistics, StatsBase
using Distributions
using Plots
using DataFrames, CSV
using Printf

# Include HDF5 loader (relative to project root)
const PROJECT_ROOT = dirname(dirname(@__DIR__))
include(joinpath(PROJECT_ROOT, "src", "io_hdf5.jl"))

"""
    compute_distribution_metrics(velocities)

Compute statistical metrics for a velocity distribution
"""
function compute_distribution_metrics(velocities)
    μ = mean(velocities)
    σ = std(velocities)

    # Moments
    m3 = mean((velocities .- μ).^3)
    m4 = mean((velocities .- μ).^4)

    # Skewness and kurtosis
    skewness = m3 / σ^3
    kurtosis = m4 / σ^4

    # Entropy (binned estimate)
    bins = 50
    hist = fit(Histogram, velocities, nbins=bins)
    p = hist.weights ./ sum(hist.weights)
    p_nonzero = p[p .> 0]
    entropy = -sum(p_nonzero .* log.(p_nonzero))

    return (
        mean = μ,
        std = σ,
        skewness = skewness,
        kurtosis = kurtosis,
        excess_kurtosis = kurtosis - 3,  # Gaussian has κ=3
        entropy = entropy
    )
end

"""
    kolmogorov_smirnov_test(velocities, reference_dist)

KS test against reference distribution (typically Gaussian)
"""
function kolmogorov_smirnov_test(velocities, reference_dist)
    # Sort data
    v_sorted = sort(velocities)
    n = length(v_sorted)

    # Empirical CDF
    empirical_cdf = (1:n) ./ n

    # Theoretical CDF
    theoretical_cdf = cdf.(reference_dist, v_sorted)

    # KS statistic
    D = maximum(abs.(empirical_cdf .- theoretical_cdf))

    # Critical value at α=0.05
    D_crit = 1.36 / sqrt(n)  # Kolmogorov critical value

    # p-value (approximate)
    p_value = exp(-2 * n * D^2)

    return (
        D_statistic = D,
        D_critical = D_crit,
        p_value = p_value,
        is_gaussian = D < D_crit
    )
end

"""
    analyze_single_snapshot(velocities, time)

Complete analysis of velocity distribution at one time
"""
function analyze_single_snapshot(velocities, time)
    # Basic metrics
    metrics = compute_distribution_metrics(velocities)

    # Fit Gaussian
    gaussian_dist = Normal(metrics.mean, metrics.std)

    # KS test
    ks_test = kolmogorov_smirnov_test(velocities, gaussian_dist)

    println("t = $(round(time, digits=2))s:")
    println("  μ = $(round(metrics.mean, digits=4)), σ = $(round(metrics.std, digits=4))")
    println("  Skewness: $(round(metrics.skewness, digits=3))")
    println("  Excess kurtosis: $(round(metrics.excess_kurtosis, digits=3))")
    println("  KS D-stat: $(round(ks_test.D_statistic, digits=4)) (crit: $(round(ks_test.D_critical, digits=4)))")
    println("  Gaussian? $(ks_test.is_gaussian ? "✓" : "✗")")
    println()

    return merge(
        (time = time,),
        metrics,
        ks_test
    )
end

"""
    analyze_velocity_evolution(hdf5_file, times_to_check)

Analyze velocity distribution evolution over time
"""
function analyze_velocity_evolution(hdf5_file, times_to_check=nothing)
    println("="^70)
    println("Velocity Distribution Evolution Analysis")
    println("="^70)
    println("File: $hdf5_file")
    println()

    # Load data
    println("Loading HDF5...")
    data = load_trajectories_hdf5(hdf5_file)

    times = data.times
    phidot_matrix = data.phidot  # (n_snapshots, N)
    N = size(phidot_matrix, 2)

    println("Loaded: $(length(times)) snapshots, N=$N particles")
    println()

    # Determine times to analyze
    if times_to_check === nothing
        # Auto-select: beginning, middle, end, and logarithmic spacing
        t_max = times[end]
        times_to_check = unique([
            0.0,
            t_max * 0.1,
            t_max * 0.25,
            t_max * 0.5,
            t_max * 0.75,
            t_max * 0.9,
            t_max
        ])
    end

    # Find closest indices
    indices = [argmin(abs.(times .- t)) for t in times_to_check]
    actual_times = times[indices]

    println("Analyzing $(length(actual_times)) time snapshots...")
    println()

    # Analyze each time
    results = []
    for (idx, t) in zip(indices, actual_times)
        velocities = phidot_matrix[idx, :]
        result = analyze_single_snapshot(velocities, t)
        push!(results, result)
    end

    # Convert to DataFrame
    df = DataFrame(results)

    return df, data
end

"""
    plot_velocity_distributions(data, times_to_plot, output_dir)

Create comprehensive visualization of velocity distributions
"""
function plot_velocity_distributions(data, times_to_plot, output_dir)
    mkpath(output_dir)

    times = data.times
    phidot_matrix = data.phidot

    # Find indices
    indices = [argmin(abs.(times .- t)) for t in times_to_plot]
    actual_times = times[indices]

    # Create figure with distributions at different times
    p = plot(layout=(2,2), size=(1200, 900), dpi=150)

    colors = [:blue, :red, :green, :purple]

    for (i, (idx, t)) in enumerate(zip(indices, actual_times))
        if i > 4
            break
        end

        velocities = phidot_matrix[idx, :]

        # Histogram
        histogram!(p[i], velocities, bins=30, alpha=0.6, normalize=:pdf,
                  label="Data", color=colors[i],
                  xlabel="φ̇ (rad/s)", ylabel="Probability density",
                  title="t = $(round(t, digits=1))s")

        # Fit Gaussian
        μ, σ = mean(velocities), std(velocities)
        gaussian = Normal(μ, σ)
        x_range = range(minimum(velocities), maximum(velocities), length=100)
        plot!(p[i], x_range, pdf.(gaussian, x_range),
              linewidth=2, color=:black, linestyle=:dash,
              label="Gaussian fit")
    end

    savefig(p, joinpath(output_dir, "velocity_distributions_snapshots.png"))
    println("Saved: velocity_distributions_snapshots.png")

    # Time evolution of metrics
    n_snapshots = min(200, length(times))  # Subsample for performance
    indices_full = round.(Int, range(1, length(times), length=n_snapshots))

    times_full = times[indices_full]
    skewness_full = Float64[]
    kurtosis_full = Float64[]
    ks_stat_full = Float64[]

    println("\nComputing full time evolution...")
    for idx in indices_full
        velocities = phidot_matrix[idx, :]
        metrics = compute_distribution_metrics(velocities)

        μ, σ = metrics.mean, metrics.std
        gaussian = Normal(μ, σ)
        ks = kolmogorov_smirnov_test(velocities, gaussian)

        push!(skewness_full, metrics.skewness)
        push!(kurtosis_full, metrics.excess_kurtosis)
        push!(ks_stat_full, ks.D_statistic)
    end

    # Plot evolution metrics
    p2 = plot(layout=(3,1), size=(1000, 900), dpi=150)

    # Skewness
    plot!(p2[1], times_full, skewness_full, linewidth=2, label="",
          xlabel="", ylabel="Skewness γ",
          title="Deviation from Gaussian")
    hline!(p2[1], [0], linestyle=:dash, color=:black, label="Gaussian")

    # Excess kurtosis
    plot!(p2[2], times_full, kurtosis_full, linewidth=2, label="",
          xlabel="", ylabel="Excess Kurtosis (κ-3)")
    hline!(p2[2], [0], linestyle=:dash, color=:black, label="Gaussian")

    # KS statistic
    plot!(p2[3], times_full, ks_stat_full, linewidth=2, label="D statistic",
          xlabel="Time (s)", ylabel="KS Statistic")
    hline!(p2[3], [1.36/sqrt(size(phidot_matrix,2))],
           linestyle=:dash, color=:red, label="Critical (α=0.05)")

    savefig(p2, joinpath(output_dir, "velocity_metrics_evolution.png"))
    println("Saved: velocity_metrics_evolution.png")

    # Q-Q plot for final time
    velocities_final = phidot_matrix[end, :]
    μ_final, σ_final = mean(velocities_final), std(velocities_final)

    # Theoretical quantiles
    n = length(velocities_final)
    p_vals = (1:n) ./ (n+1)
    theoretical_quantiles = quantile.(Normal(μ_final, σ_final), p_vals)
    empirical_quantiles = sort(velocities_final)

    p3 = scatter(theoretical_quantiles, empirical_quantiles,
                 label="Data", alpha=0.6, markersize=4,
                 xlabel="Theoretical quantiles (Gaussian)",
                 ylabel="Empirical quantiles",
                 title="Q-Q Plot (Final time t=$(round(times[end],digits=1))s)",
                 size=(600, 600), dpi=150)
    plot!(p3, theoretical_quantiles, theoretical_quantiles,
          linestyle=:dash, color=:red, linewidth=2, label="y=x")

    savefig(p3, joinpath(output_dir, "qq_plot_final.png"))
    println("Saved: qq_plot_final.png")

    return (skewness=skewness_full, kurtosis=kurtosis_full, ks_stat=ks_stat_full, times=times_full)
end

"""
    estimate_relaxation_time(times, metric)

Estimate relaxation time τ from exponential fit
"""
function estimate_relaxation_time(times, metric)
    # Assume relaxation: metric(t) = metric(∞) + [metric(0) - metric(∞)] exp(-t/τ)

    # Simple estimate: time when metric reaches 1/e of initial deviation
    metric_0 = metric[1]
    metric_inf = mean(metric[end-10:end])  # Average of last 10 points

    threshold = metric_inf + (metric_0 - metric_inf) / ℯ

    idx = findfirst(m -> abs(m - threshold) < abs(metric_0 - threshold)/10, metric)

    if idx === nothing
        return NaN
    else
        return times[idx]
    end
end

"""
    main()
"""
function main()
    if length(ARGS) < 1
        println("Usage: julia analyze_velocity_distributions.jl <hdf5_file_or_directory>")
        println("Example: julia analyze_velocity_distributions.jl results/campaign/e0.866_N40_phi0.06_E0.32/seed_1/trajectories.h5")
        exit(1)
    end

    input_path = ARGS[1]

    # Check if file or directory
    if isfile(input_path)
        # Single file
        hdf5_files = [input_path]
        output_base = dirname(input_path)
    elseif isdir(input_path)
        # Directory - find all HDF5 files
        hdf5_files = []
        for (root, dirs, files) in walkdir(input_path)
            for file in files
                if endswith(file, ".h5") || endswith(file, ".hdf5")
                    push!(hdf5_files, joinpath(root, file))
                end
            end
        end
        output_base = input_path
    else
        error("Path not found: $input_path")
    end

    println("Found $(length(hdf5_files)) HDF5 file(s)")
    println()

    # Analyze each file
    for (i, hdf5_file) in enumerate(hdf5_files)
        println("\n[$(i)/$(length(hdf5_files))] Processing: $(basename(dirname(hdf5_file)))/$(basename(hdf5_file))")

        try
            # Create output directory
            file_dir = dirname(hdf5_file)
            output_dir = joinpath(file_dir, "velocity_analysis")

            # Analyze
            df, data = analyze_velocity_evolution(hdf5_file)

            # Create output directory
            mkpath(output_dir)

            # Save results
            CSV.write(joinpath(output_dir, "velocity_metrics_vs_time.csv"), df)
            println("\nSaved metrics to: velocity_metrics_vs_time.csv")

            # Plot
            evolution = plot_velocity_distributions(
                data,
                [0.0, data.times[end]*0.25, data.times[end]*0.5, data.times[end]],
                output_dir
            )

            # Estimate relaxation times
            τ_skew = estimate_relaxation_time(evolution.times, evolution.skewness)
            τ_kurt = estimate_relaxation_time(evolution.times, evolution.kurtosis)
            τ_ks = estimate_relaxation_time(evolution.times, evolution.ks_stat)

            println("\nRelaxation time estimates:")
            println("  From skewness: $(round(τ_skew, digits=2))s")
            println("  From kurtosis: $(round(τ_kurt, digits=2))s")
            println("  From KS stat:  $(round(τ_ks, digits=2))s")

            # Final assessment
            final_ks = df[end, :D_statistic]
            final_crit = df[end, :D_critical]

            println("\n" * "="^70)
            if final_ks < final_crit
                println("✓ CONCLUSION: Distribution IS consistent with Gaussian at final time")
                println("  → Evidence of quasi-thermalization")
            else
                println("✗ CONCLUSION: Distribution is NOT Gaussian at final time")
                println("  → System remains out of thermal equilibrium")
            end
            println("="^70)

        catch e
            println("ERROR processing $hdf5_file: $e")
            continue
        end
    end

    println("\n" * "="^70)
    println("Analysis complete!")
    println("="^70)
end

# Run main
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
