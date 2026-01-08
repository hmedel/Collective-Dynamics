#!/usr/bin/env julia
#
# analyze_critical_phenomena.jl
#
# Comprehensive analysis of non-equilibrium phase transition:
# 1. Nucleation time distributions (Poisson vs exponential)
# 2. Data collapse and scaling functions
# 3. Critical exponents near (N=40, e=0.5)
# 4. Spatial correlations and cluster growth
# 5. Avalanche analysis (secondary nucleation events)
#

using HDF5
using CSV
using DataFrames
using Statistics
using Plots
using Printf
using LsqFit
using Distributions
using StatsBase

gr()

"""
    calculate_local_curvature(phi, a, b)
"""
function calculate_local_curvature(phi::T, a::T, b::T) where T <: AbstractFloat
    denom = (a^2 * sin(phi)^2 + b^2 * cos(phi)^2)^(3/2)
    kappa = (a * b) / denom
    return kappa
end

"""
    compute_clustering_metrics(phi_snapshot)
"""
function compute_clustering_metrics(phi_snapshot)
    x = cos.(phi_snapshot)
    y = sin.(phi_snapshot)
    x_cm = mean(x)
    y_cm = mean(y)
    R = sqrt(mean((x .- x_cm).^2 + (y .- y_cm).^2))

    z = mean(exp.(im .* phi_snapshot))
    Psi = abs(z)
    sigma = sqrt(-2 * log(max(Psi, 1e-10)))

    return R, Psi, sigma
end

"""
    load_timeseries(h5_file; max_snapshots=200)
"""
function load_timeseries(h5_file::String; max_snapshots=200)
    h5open(h5_file, "r") do file
        phi = read(file["trajectories/phi"])
        phidot = read(file["trajectories/phidot"])
        times = read(file["trajectories/time"])

        meta_attrs = attributes(file["metadata"])
        a = read(meta_attrs["a"])
        b = read(meta_attrs["b"])
        e = read(meta_attrs["eccentricity"])
        N = read(meta_attrs["N"])

        n_times = length(times)
        if n_times > max_snapshots
            indices = round.(Int, range(1, n_times, length=max_snapshots))
        else
            indices = 1:n_times
        end

        return (
            phi = phi[indices, :],
            phidot = phidot[indices, :],
            times = times[indices],
            a = a, b = b, e = e, N = N
        )
    end
end

"""
    compute_timeseries_metrics(data)
"""
function compute_timeseries_metrics(data)
    n_snapshots = length(data.times)
    R_t = zeros(n_snapshots)
    Psi_t = zeros(n_snapshots)
    sigma_t = zeros(n_snapshots)

    for i in 1:n_snapshots
        phi_snap = data.phi[i, :]
        R_t[i], Psi_t[i], sigma_t[i] = compute_clustering_metrics(phi_snap)
    end

    return (times = data.times, R_t = R_t, Psi_t = Psi_t, sigma_t = sigma_t)
end

"""
    find_nucleation_time(times, Psi_t; threshold=0.5)
"""
function find_nucleation_time(times, Psi_t; threshold=0.5)
    idx = findfirst(Psi_t .>= threshold)
    return isnothing(idx) ? times[end] : times[idx]
end

# ============================================================================
# ANALYSIS 1: Nucleation Time Distributions
# ============================================================================

"""
    analyze_nucleation_time_distribution(campaign_dir, N, e; max_seeds=20)
"""
function analyze_nucleation_time_distribution(campaign_dir::String, N::Int, e::Float64;
                                              max_seeds=20)
    println(@sprintf("\n=== Nucleation Time Distribution: N=%d, e=%.1f ===", N, e))

    # Find runs
    run_dirs = filter(readdir(campaign_dir, join=true)) do path
        isdir(path) && occursin(r"^e\d", basename(path))
    end

    matching_h5_files = []
    for run_dir in run_dirs
        run_name = basename(run_dir)
        m = match(r"e(\d+\.\d+)_N(\d+)_seed(\d+)", run_name)
        if !isnothing(m)
            e_run = parse(Float64, m.captures[1])
            N_run = parse(Int, m.captures[2])
            if N_run == N && abs(e_run - e) < 0.01
                h5_file = joinpath(run_dir, "trajectories.h5")
                if isfile(h5_file)
                    push!(matching_h5_files, h5_file)
                end
            end
        end
        if length(matching_h5_files) >= max_seeds
            break
        end
    end

    if length(matching_h5_files) < 3
        @warn "Insufficient data"
        return nothing
    end

    # Collect nucleation times
    tau_nuc_values = []
    for h5_file in matching_h5_files
        data = load_timeseries(h5_file)
        ts = compute_timeseries_metrics(data)
        tau = find_nucleation_time(ts.times, ts.Psi_t)
        push!(tau_nuc_values, tau)
    end

    # Fit exponential distribution: P(τ) = λ exp(-λτ)
    # MLE: λ = 1/mean(τ)
    lambda_mle = 1.0 / mean(tau_nuc_values)

    # Fit gamma distribution (more general)
    # k, θ such that mean = kθ, var = kθ²
    mean_tau = mean(tau_nuc_values)
    var_tau = var(tau_nuc_values)

    if var_tau > 0 && mean_tau > 0
        k = mean_tau^2 / var_tau
        theta = var_tau / mean_tau
    else
        k = 1.0
        theta = mean_tau
    end

    println(@sprintf("  n = %d realizations", length(tau_nuc_values)))
    println(@sprintf("  τ_mean = %.2f, τ_std = %.2f", mean_tau, sqrt(var_tau)))
    println(@sprintf("  Exponential: λ = %.4f", lambda_mle))
    println(@sprintf("  Gamma: k = %.4f, θ = %.4f", k, theta))

    return (
        tau_values = tau_nuc_values,
        lambda = lambda_mle,
        k = k,
        theta = theta,
        N = N,
        e = e
    )
end

"""
    plot_nucleation_distribution(dist_data; output_file)
"""
function plot_nucleation_distribution(dist_data; output_file=nothing)
    tau = dist_data.tau_values
    lambda = dist_data.lambda
    k = dist_data.k
    theta = dist_data.theta

    p = plot(layout = (1, 2), size = (1400, 600), dpi = 150)

    # Panel 1: Histogram + fits
    histogram!(p[1], tau,
               bins = 10,
               normalize = :pdf,
               xlabel = "τ_nucleation",
               ylabel = "Probability density",
               title = @sprintf("N=%d, e=%.1f", dist_data.N, dist_data.e),
               label = "Data",
               alpha = 0.7,
               color = :blue)

    tau_range = range(0, maximum(tau)*1.2, length=100)

    # Exponential fit
    exp_fit = lambda .* exp.(-lambda .* tau_range)
    plot!(p[1], tau_range, exp_fit,
          linewidth = 3,
          color = :red,
          linestyle = :dash,
          label = @sprintf("Exponential (λ=%.3f)", lambda))

    # Gamma fit
    gamma_dist = Gamma(k, theta)
    gamma_fit = pdf.(gamma_dist, tau_range)
    plot!(p[1], tau_range, gamma_fit,
          linewidth = 3,
          color = :green,
          linestyle = :dot,
          label = @sprintf("Gamma (k=%.2f, θ=%.2f)", k, theta))

    # Panel 2: Q-Q plot vs exponential
    sorted_tau = sort(tau)
    theoretical_quantiles = -log.(1 .- (1:length(tau)) ./ (length(tau) + 1)) ./ lambda

    scatter!(p[2], theoretical_quantiles, sorted_tau,
             xlabel = "Theoretical quantiles (Exponential)",
             ylabel = "Sample quantiles",
             title = "Q-Q Plot",
             markersize = 6,
             color = :purple,
             alpha = 0.6,
             legend = false)

    # Add diagonal
    plot!(p[2], [0, maximum(theoretical_quantiles)],
          [0, maximum(theoretical_quantiles)],
          linewidth = 2,
          color = :black,
          linestyle = :dash)

    if !isnothing(output_file)
        savefig(p, output_file)
    end

    return p
end

# ============================================================================
# ANALYSIS 2: Data Collapse / Scaling Functions
# ============================================================================

"""
    analyze_data_collapse(campaign_dir, N_values, e_values; max_seeds=10)
"""
function analyze_data_collapse(campaign_dir::String, N_values, e_values; max_seeds=10)
    println("\n" * "="^80)
    println("DATA COLLAPSE ANALYSIS")
    println("="^80)

    # Collect all timeseries
    all_data = []

    for N in N_values
        for e in e_values
            run_dirs = filter(readdir(campaign_dir, join=true)) do path
                isdir(path) && occursin(r"^e\d", basename(path))
            end

            count = 0
            for run_dir in run_dirs
                run_name = basename(run_dir)
                m = match(r"e(\d+\.\d+)_N(\d+)_seed(\d+)", run_name)
                if !isnothing(m)
                    e_run = parse(Float64, m.captures[1])
                    N_run = parse(Int, m.captures[2])
                    if N_run == N && abs(e_run - e) < 0.01
                        h5_file = joinpath(run_dir, "trajectories.h5")
                        if isfile(h5_file)
                            data = load_timeseries(h5_file; max_snapshots=100)
                            ts = compute_timeseries_metrics(data)
                            tau_nuc = find_nucleation_time(ts.times, ts.Psi_t)

                            push!(all_data, (
                                N = N,
                                e = e,
                                times = ts.times,
                                R_t = ts.R_t,
                                Psi_t = ts.Psi_t,
                                tau_nuc = tau_nuc
                            ))

                            count += 1
                            if count >= max_seeds
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    println(@sprintf("Collected %d realizations", length(all_data)))

    return all_data
end

"""
    plot_data_collapse(all_data; output_file)

Try to collapse data: R(t/τ_nuc) for different (N, e)
"""
function plot_data_collapse(all_data; output_file=nothing)
    p = plot(layout = (1, 2), size = (1400, 600), dpi = 150)

    # Panel 1: Raw R(t)
    for (i, data) in enumerate(all_data)
        if i > 50  # Limit for visibility
            break
        end
        plot!(p[1], data.times, data.R_t,
              linewidth = 1,
              alpha = 0.3,
              color = :blue,
              legend = false,
              xlabel = "Time t",
              ylabel = "R(t)",
              title = "Raw Data")
    end

    # Panel 2: Collapsed R(t/τ_nuc)
    for (i, data) in enumerate(all_data)
        if i > 50
            break
        end
        t_scaled = data.times ./ data.tau_nuc
        plot!(p[2], t_scaled, data.R_t,
              linewidth = 1,
              alpha = 0.3,
              color = :red,
              legend = false,
              xlabel = "t/τ_nucleation",
              ylabel = "R(t/τ)",
              title = "Data Collapse Attempt",
              xlims = (0, 10))
    end

    if !isnothing(output_file)
        savefig(p, output_file)
    end

    return p
end

# ============================================================================
# ANALYSIS 3: Critical Exponents
# ============================================================================

"""
    analyze_critical_exponents(campaign_dir; output_dir)

Near (N=40, e=0.5), analyze:
- R_final ~ |e - e_c|^β
- τ_nuc ~ |e - e_c|^(-ν)
"""
function analyze_critical_exponents(campaign_dir::String; output_dir=nothing)
    println("\n" * "="^80)
    println("CRITICAL EXPONENTS ANALYSIS")
    println("="^80)

    # Fix N=40, vary e around 0.5
    N_fixed = 40
    e_values = [0.3, 0.5, 0.7, 0.8]

    results = []

    for e in e_values
        # Collect R_final and τ_nuc
        run_dirs = filter(readdir(campaign_dir, join=true)) do path
            isdir(path) && occursin(r"^e\d", basename(path))
        end

        R_finals = []
        tau_nucs = []

        for run_dir in run_dirs
            run_name = basename(run_dir)
            m = match(r"e(\d+\.\d+)_N(\d+)_seed(\d+)", run_name)
            if !isnothing(m)
                e_run = parse(Float64, m.captures[1])
                N_run = parse(Int, m.captures[2])
                if N_run == N_fixed && abs(e_run - e) < 0.01
                    h5_file = joinpath(run_dir, "trajectories.h5")
                    if isfile(h5_file)
                        data = load_timeseries(h5_file)
                        ts = compute_timeseries_metrics(data)

                        R_final = mean(ts.R_t[end-5:end])
                        tau_nuc = find_nucleation_time(ts.times, ts.Psi_t)

                        push!(R_finals, R_final)
                        push!(tau_nucs, tau_nuc)
                    end
                end
            end
        end

        if length(R_finals) > 0
            push!(results, (
                e = e,
                R_final_mean = mean(R_finals),
                R_final_std = std(R_finals),
                tau_nuc_mean = mean(tau_nucs),
                tau_nuc_std = std(tau_nucs)
            ))
        end
    end

    df = DataFrame(results)
    println(df)

    # Power-law fits near e_c = 0.5
    e_c = 0.5
    subset = filter(row -> row.e != e_c, df)

    if nrow(subset) >= 2
        delta_e = abs.(subset.e .- e_c)

        # R_final ~ |e - e_c|^β
        log_delta_e = log.(delta_e)
        log_R = log.(subset.R_final_mean)

        # Linear fit: log(R) = log(A) + β*log(|e-e_c|)
        X = hcat(ones(length(log_delta_e)), log_delta_e)
        coeffs_R = X \ log_R
        beta = coeffs_R[2]

        println(@sprintf("\nCritical exponents (e_c = %.1f):", e_c))
        println(@sprintf("  β (R_final ~ |e-e_c|^β): %.3f", beta))

        # τ ~ |e - e_c|^(-ν)
        log_tau = log.(subset.tau_nuc_mean)
        coeffs_tau = X \ log_tau
        nu = -coeffs_tau[2]

        println(@sprintf("  ν (τ_nuc ~ |e-e_c|^(-ν)): %.3f", nu))
    end

    if !isnothing(output_dir)
        csv_file = joinpath(output_dir, "critical_exponents.csv")
        CSV.write(csv_file, df)
    end

    return df
end

# ============================================================================
# ANALYSIS 4: Spatial Correlations
# ============================================================================

"""
    compute_spatial_correlation(phi_snapshot)

Correlation function: g(Δφ) = ⟨δρ(φ) δρ(φ+Δφ)⟩
"""
function compute_spatial_correlation(phi_snapshot; n_bins=30)
    N = length(phi_snapshot)

    # Density bins
    phi_edges = range(0, 2π, length=n_bins+1)
    density = zeros(n_bins)

    for p in phi_snapshot
        idx = searchsortedfirst(phi_edges, p) - 1
        idx = clamp(idx, 1, n_bins)
        density[idx] += 1
    end

    # Normalize
    density = density .- mean(density)

    # Autocorrelation
    correlation = zeros(n_bins)
    for lag in 0:(n_bins-1)
        for i in 1:n_bins
            j = mod1(i + lag, n_bins)
            correlation[lag+1] += density[i] * density[j]
        end
    end
    correlation ./= n_bins

    lags = (0:(n_bins-1)) .* (2π / n_bins)

    return lags, correlation
end

"""
    analyze_spatial_correlations(h5_file; output_file)
"""
function analyze_spatial_correlations(h5_file::String; output_file=nothing)
    data = load_timeseries(h5_file; max_snapshots=50)

    n_snapshots = length(data.times)
    snapshot_indices = [1, n_snapshots÷4, n_snapshots÷2, 3*n_snapshots÷4, n_snapshots]

    p = plot(size = (1000, 600), dpi = 150)

    for idx in snapshot_indices
        phi_snap = data.phi[idx, :]
        lags, corr = compute_spatial_correlation(phi_snap)

        plot!(p, lags, corr,
              label = @sprintf("t = %.1f", data.times[idx]),
              linewidth = 2,
              xlabel = "Δφ [rad]",
              ylabel = "g(Δφ)",
              title = @sprintf("Spatial Correlation (N=%d, e=%.1f)", data.N, data.e),
              legend = :best,
              grid = true)
    end

    if !isnothing(output_file)
        savefig(p, output_file)
    end

    return p
end

# ============================================================================
# ANALYSIS 5: Avalanche Analysis
# ============================================================================

"""
    detect_avalanches(times, Psi_t; threshold_rate=0.1)

Detect rapid growth events (dΨ/dt > threshold)
"""
function detect_avalanches(times, Psi_t; threshold_rate=0.1)
    n = length(times)
    avalanches = []

    for i in 2:n
        dt = times[i] - times[i-1]
        dPsi = Psi_t[i] - Psi_t[i-1]

        if dt > 0
            rate = dPsi / dt
            if rate > threshold_rate
                push!(avalanches, (
                    time = times[i],
                    rate = rate,
                    Psi_before = Psi_t[i-1],
                    Psi_after = Psi_t[i]
                ))
            end
        end
    end

    return avalanches
end

"""
    analyze_avalanches(campaign_dir, N, e; max_seeds=10, output_file)
"""
function analyze_avalanches(campaign_dir::String, N::Int, e::Float64;
                            max_seeds=10, output_file=nothing)
    println(@sprintf("\n=== Avalanche Analysis: N=%d, e=%.1f ===", N, e))

    run_dirs = filter(readdir(campaign_dir, join=true)) do path
        isdir(path) && occursin(r"^e\d", basename(path))
    end

    all_avalanches = []
    count = 0

    for run_dir in run_dirs
        run_name = basename(run_dir)
        m = match(r"e(\d+\.\d+)_N(\d+)_seed(\d+)", run_name)
        if !isnothing(m)
            e_run = parse(Float64, m.captures[1])
            N_run = parse(Int, m.captures[2])
            if N_run == N && abs(e_run - e) < 0.01
                h5_file = joinpath(run_dir, "trajectories.h5")
                if isfile(h5_file)
                    data = load_timeseries(h5_file)
                    ts = compute_timeseries_metrics(data)
                    avalanches = detect_avalanches(ts.times, ts.Psi_t)

                    append!(all_avalanches, avalanches)
                    count += 1

                    if count >= max_seeds
                        break
                    end
                end
            end
        end
    end

    println(@sprintf("  Found %d avalanche events", length(all_avalanches)))

    if length(all_avalanches) > 0
        rates = [av.rate for av in all_avalanches]
        times_av = [av.time for av in all_avalanches]

        println(@sprintf("  Mean avalanche rate: %.4f", mean(rates)))
        println(@sprintf("  Mean avalanche time: %.2f", mean(times_av)))

        # Plot distribution
        if !isnothing(output_file)
            p = plot(layout = (1, 2), size = (1400, 600), dpi = 150)

            histogram!(p[1], rates,
                      bins = 20,
                      xlabel = "Avalanche rate dΨ/dt",
                      ylabel = "Count",
                      title = @sprintf("N=%d, e=%.1f", N, e),
                      legend = false,
                      color = :blue,
                      alpha = 0.7)

            histogram!(p[2], times_av,
                      bins = 20,
                      xlabel = "Avalanche time",
                      ylabel = "Count",
                      title = "Temporal Distribution",
                      legend = false,
                      color = :red,
                      alpha = 0.7)

            savefig(p, output_file)
        end
    end

    return all_avalanches
end

# ============================================================================
# MAIN
# ============================================================================

"""
    main_analysis(campaign_dir)
"""
function main_analysis(campaign_dir::String)
    println("="^80)
    println("COMPREHENSIVE CRITICAL PHENOMENA ANALYSIS")
    println("="^80)

    output_dir = joinpath(campaign_dir, "critical_phenomena")
    mkpath(output_dir)

    # 1. Nucleation time distributions
    println("\n" * "="^80)
    println("PART 1: NUCLEATION TIME DISTRIBUTIONS")
    println("="^80)

    conditions = [
        (N=40, e=0.5, label="Optimal"),
        (N=40, e=0.9, label="High e"),
        (N=80, e=0.5, label="Large N")
    ]

    for cond in conditions
        dist_data = analyze_nucleation_time_distribution(
            campaign_dir, cond.N, cond.e; max_seeds=20
        )

        if !isnothing(dist_data)
            output_file = joinpath(output_dir,
                @sprintf("nucleation_dist_N%d_e%.1f.png", cond.N, cond.e))
            plot_nucleation_distribution(dist_data; output_file=output_file)
            println("  ✅ Plot saved")
        end
    end

    # 2. Data collapse
    println("\n" * "="^80)
    println("PART 2: DATA COLLAPSE")
    println("="^80)

    all_data = analyze_data_collapse(
        campaign_dir, [40, 60], [0.5, 0.7, 0.9]; max_seeds=5
    )

    output_file = joinpath(output_dir, "data_collapse.png")
    plot_data_collapse(all_data; output_file=output_file)
    println("✅ Data collapse plot saved")

    # 3. Critical exponents
    println("\n" * "="^80)
    println("PART 3: CRITICAL EXPONENTS")
    println("="^80)

    analyze_critical_exponents(campaign_dir; output_dir=output_dir)

    # 4. Spatial correlations
    println("\n" * "="^80)
    println("PART 4: SPATIAL CORRELATIONS")
    println("="^80)

    for cond in conditions
        run_dirs = filter(readdir(campaign_dir, join=true)) do path
            isdir(path) && occursin(r"^e\d", basename(path))
        end

        for run_dir in run_dirs
            run_name = basename(run_dir)
            m = match(r"e(\d+\.\d+)_N(\d+)_seed(\d+)", run_name)
            if !isnothing(m)
                e_run = parse(Float64, m.captures[1])
                N_run = parse(Int, m.captures[2])
                if N_run == cond.N && abs(e_run - cond.e) < 0.01
                    h5_file = joinpath(run_dir, "trajectories.h5")
                    if isfile(h5_file)
                        output_file = joinpath(output_dir,
                            @sprintf("spatial_corr_N%d_e%.1f.png", cond.N, cond.e))
                        analyze_spatial_correlations(h5_file; output_file=output_file)
                        println(@sprintf("  ✅ N=%d, e=%.1f saved", cond.N, cond.e))
                        break
                    end
                end
            end
        end
    end

    # 5. Avalanche analysis
    println("\n" * "="^80)
    println("PART 5: AVALANCHE ANALYSIS")
    println("="^80)

    for cond in conditions
        output_file = joinpath(output_dir,
            @sprintf("avalanches_N%d_e%.1f.png", cond.N, cond.e))
        analyze_avalanches(campaign_dir, cond.N, cond.e;
                          max_seeds=10, output_file=output_file)
        println("  ✅ Plot saved")
    end

    println("\n" * "="^80)
    println("COMPLETE ANALYSIS FINISHED")
    println("="^80)
    println("Output: $output_dir")
end

# Main
if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) < 1
        println("Usage: julia analyze_critical_phenomena.jl <campaign_dir>")
        exit(1)
    end

    main_analysis(ARGS[1])
end
