#!/usr/bin/env julia
#
# analyze_phase_transition_statistics.jl
#
# Statistical analysis of cluster formation as non-equilibrium phase transition:
# - Ensemble-averaged R(t), Ψ(t) evolution
# - Characteristic timescales (nucleation, saturation)
# - Scaling with N and e
# - Critical behavior search
# - Order parameter dynamics
#

using HDF5
using CSV
using DataFrames
using Statistics
using Plots
using Printf
using LsqFit

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

    # Angular dispersion
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

        # Subsample if too many snapshots
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
            a = a,
            b = b,
            e = e,
            N = N
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
    kappa_avg_t = zeros(n_snapshots)

    for i in 1:n_snapshots
        phi_snap = data.phi[i, :]
        R_t[i], Psi_t[i], sigma_t[i] = compute_clustering_metrics(phi_snap)

        # Average curvature
        kappas = [calculate_local_curvature(p, data.a, data.b) for p in phi_snap]
        kappa_avg_t[i] = mean(kappas)
    end

    return (
        times = data.times,
        R_t = R_t,
        Psi_t = Psi_t,
        sigma_t = sigma_t,
        kappa_avg_t = kappa_avg_t
    )
end

"""
    find_characteristic_times(times, R_t, Psi_t)

Identifica tiempos característicos:
- τ_nucleation: cuando Ψ > 0.5 (cluster formado)
- τ_saturation: cuando R se estabiliza (|dR/dt| pequeño)
"""
function find_characteristic_times(times, R_t, Psi_t)
    # Nucleation: Ψ cruza 0.5
    idx_nuc = findfirst(Psi_t .>= 0.5)
    if isnothing(idx_nuc)
        tau_nucleation = times[end]
    else
        tau_nucleation = times[idx_nuc]
    end

    # Saturation: R alcanza valor final (últimos 20%)
    idx_late = floor(Int, 0.8 * length(R_t)):length(R_t)
    R_final = mean(R_t[idx_late])

    # Buscar cuando |R - R_final| < 0.05
    idx_sat = findfirst(abs.(R_t .- R_final) .< 0.05)
    if isnothing(idx_sat)
        tau_saturation = times[end]
    else
        tau_saturation = times[idx_sat]
    end

    return tau_nucleation, tau_saturation, R_final
end

"""
    ensemble_average_timeseries(all_timeseries)

Promedia múltiples series temporales interpolándolas a una grilla común.
"""
function ensemble_average_timeseries(all_timeseries)
    # Find common time grid
    t_min = minimum([ts.times[1] for ts in all_timeseries])
    t_max = minimum([ts.times[end] for ts in all_timeseries])

    n_points = 200
    t_common = range(t_min, t_max, length=n_points)

    n_realizations = length(all_timeseries)
    R_interp = zeros(n_points, n_realizations)
    Psi_interp = zeros(n_points, n_realizations)
    sigma_interp = zeros(n_points, n_realizations)
    kappa_interp = zeros(n_points, n_realizations)

    for (i, ts) in enumerate(all_timeseries)
        for (j, t_target) in enumerate(t_common)
            # Linear interpolation
            idx = searchsortedfirst(ts.times, t_target)
            if idx > length(ts.times)
                R_interp[j, i] = ts.R_t[end]
                Psi_interp[j, i] = ts.Psi_t[end]
                sigma_interp[j, i] = ts.sigma_t[end]
                kappa_interp[j, i] = ts.kappa_avg_t[end]
            elseif idx == 1
                R_interp[j, i] = ts.R_t[1]
                Psi_interp[j, i] = ts.Psi_t[1]
                sigma_interp[j, i] = ts.sigma_t[1]
                kappa_interp[j, i] = ts.kappa_avg_t[1]
            else
                t1, t2 = ts.times[idx-1], ts.times[idx]
                w = (t_target - t1) / (t2 - t1)

                R_interp[j, i] = ts.R_t[idx-1] + w * (ts.R_t[idx] - ts.R_t[idx-1])
                Psi_interp[j, i] = ts.Psi_t[idx-1] + w * (ts.Psi_t[idx] - ts.Psi_t[idx-1])
                sigma_interp[j, i] = ts.sigma_t[idx-1] + w * (ts.sigma_t[idx] - ts.sigma_t[idx-1])
                kappa_interp[j, i] = ts.kappa_avg_t[idx-1] + w * (ts.kappa_avg_t[idx] - ts.kappa_avg_t[idx-1])
            end
        end
    end

    return (
        times = collect(t_common),
        R_mean = vec(mean(R_interp, dims=2)),
        R_std = vec(std(R_interp, dims=2)),
        Psi_mean = vec(mean(Psi_interp, dims=2)),
        Psi_std = vec(std(Psi_interp, dims=2)),
        sigma_mean = vec(mean(sigma_interp, dims=2)),
        sigma_std = vec(std(sigma_interp, dims=2)),
        kappa_mean = vec(mean(kappa_interp, dims=2)),
        kappa_std = vec(std(kappa_interp, dims=2))
    )
end

"""
    analyze_ensemble(campaign_dir, N, e; max_seeds=10)
"""
function analyze_ensemble(campaign_dir::String, N::Int, e::Float64; max_seeds=10)
    println(@sprintf("Analyzing ensemble: N=%d, e=%.1f", N, e))

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

    if length(matching_h5_files) == 0
        @warn "No runs found for N=$N, e=$e"
        return nothing
    end

    println("  Found $(length(matching_h5_files)) realizations")

    # Load all timeseries
    all_timeseries = []
    all_tau_nuc = []
    all_tau_sat = []
    all_R_final = []

    for h5_file in matching_h5_files
        data = load_timeseries(h5_file)
        ts = compute_timeseries_metrics(data)

        tau_nuc, tau_sat, R_final = find_characteristic_times(
            ts.times, ts.R_t, ts.Psi_t
        )

        push!(all_timeseries, ts)
        push!(all_tau_nuc, tau_nuc)
        push!(all_tau_sat, tau_sat)
        push!(all_R_final, R_final)
    end

    # Ensemble average
    ensemble = ensemble_average_timeseries(all_timeseries)

    # Statistics
    stats = (
        N = N,
        e = e,
        n_realizations = length(matching_h5_files),
        tau_nucleation_mean = mean(all_tau_nuc),
        tau_nucleation_std = std(all_tau_nuc),
        tau_saturation_mean = mean(all_tau_sat),
        tau_saturation_std = std(all_tau_sat),
        R_final_mean = mean(all_R_final),
        R_final_std = std(all_R_final)
    )

    println(@sprintf("  τ_nucleation: %.2f ± %.2f", stats.tau_nucleation_mean, stats.tau_nucleation_std))
    println(@sprintf("  τ_saturation: %.2f ± %.2f", stats.tau_saturation_mean, stats.tau_saturation_std))
    println(@sprintf("  R_final: %.4f ± %.4f", stats.R_final_mean, stats.R_final_std))

    return (ensemble = ensemble, stats = stats)
end

"""
    plot_ensemble_evolution(results, label; output_file)
"""
function plot_ensemble_evolution(results, label; output_file=nothing)
    ens = results.ensemble

    p = plot(layout = (2, 2), size = (1400, 1000), dpi = 150)

    # R(t)
    plot!(p[1], ens.times, ens.R_mean,
          ribbon = ens.R_std,
          xlabel = "",
          ylabel = "R(t)",
          title = label,
          linewidth = 3,
          color = :blue,
          fillalpha = 0.3,
          legend = false,
          grid = true)

    # Add τ_nucleation
    vline!(p[1], [results.stats.tau_nucleation_mean],
           linestyle = :dash, color = :red, linewidth = 2,
           label = "τ_nuc")

    # Ψ(t)
    plot!(p[2], ens.times, ens.Psi_mean,
          ribbon = ens.Psi_std,
          xlabel = "",
          ylabel = "Ψ(t)",
          title = "Order Parameter",
          linewidth = 3,
          color = :red,
          fillalpha = 0.3,
          legend = false,
          grid = true)

    hline!(p[2], [0.5], linestyle = :dot, color = :black, linewidth = 1)

    # σ(t)
    plot!(p[3], ens.times, ens.sigma_mean,
          ribbon = ens.sigma_std,
          xlabel = "Time",
          ylabel = "σ(t)",
          title = "Angular Dispersion",
          linewidth = 3,
          color = :green,
          fillalpha = 0.3,
          legend = false,
          grid = true)

    # ⟨κ⟩(t)
    plot!(p[4], ens.times, ens.kappa_mean,
          ribbon = ens.kappa_std,
          xlabel = "Time",
          ylabel = "⟨κ⟩(t)",
          title = "Average Curvature",
          linewidth = 3,
          color = :purple,
          fillalpha = 0.3,
          legend = false,
          grid = true)

    if !isnothing(output_file)
        savefig(p, output_file)
    end

    return p
end

"""
    analyze_scaling(all_results; output_dir)

Analiza scaling de τ y R_final con N y e.
"""
function analyze_scaling(all_results; output_dir=nothing)
    println("\n" * "="^80)
    println("SCALING ANALYSIS")
    println("="^80)

    # Extract data
    df = DataFrame(all_results)

    # Scaling con N (fijo e)
    for e_val in unique(df.e)
        subset = filter(row -> row.e == e_val, df)
        if nrow(subset) < 2
            continue
        end

        println(@sprintf("\ne = %.1f:", e_val))
        println("  N     τ_nuc     τ_sat     R_final")
        for row in eachrow(subset)
            println(@sprintf("  %d    %.2f      %.2f      %.4f",
                           row.N, row.tau_nucleation_mean,
                           row.tau_saturation_mean, row.R_final_mean))
        end
    end

    # Scaling con e (fijo N)
    for N_val in unique(df.N)
        subset = filter(row -> row.N == N_val, df)
        if nrow(subset) < 2
            continue
        end

        println(@sprintf("\nN = %d:", N_val))
        println("  e     τ_nuc     τ_sat     R_final")
        for row in eachrow(subset)
            println(@sprintf("  %.1f   %.2f      %.2f      %.4f",
                           row.e, row.tau_nucleation_mean,
                           row.tau_saturation_mean, row.R_final_mean))
        end
    end

    # Plots de scaling
    if !isnothing(output_dir)
        mkpath(output_dir)

        # τ_nuc vs e para diferentes N
        p1 = plot(xlabel = "Eccentricity e",
                 ylabel = "τ_nucleation",
                 title = "Nucleation Time Scaling",
                 legend = :best,
                 size = (800, 600),
                 dpi = 150,
                 grid = true)

        for N_val in sort(unique(df.N))
            subset = filter(row -> row.N == N_val, df)
            if nrow(subset) > 0
                plot!(p1, subset.e, subset.tau_nucleation_mean,
                      yerror = subset.tau_nucleation_std,
                      label = "N=$N_val",
                      marker = :circle,
                      markersize = 6,
                      linewidth = 2)
            end
        end

        savefig(p1, joinpath(output_dir, "tau_nucleation_vs_e.png"))

        # R_final vs e
        p2 = plot(xlabel = "Eccentricity e",
                 ylabel = "R_final",
                 title = "Final Cluster Size Scaling",
                 legend = :best,
                 size = (800, 600),
                 dpi = 150,
                 grid = true)

        for N_val in sort(unique(df.N))
            subset = filter(row -> row.N == N_val, df)
            if nrow(subset) > 0
                plot!(p2, subset.e, subset.R_final_mean,
                      yerror = subset.R_final_std,
                      label = "N=$N_val",
                      marker = :circle,
                      markersize = 6,
                      linewidth = 2)
            end
        end

        savefig(p2, joinpath(output_dir, "R_final_vs_e.png"))

        println("\n✅ Scaling plots saved")
    end

    return df
end

"""
    main_analysis(campaign_dir)
"""
function main_analysis(campaign_dir::String)
    println("="^80)
    println("PHASE TRANSITION STATISTICS ANALYSIS")
    println("="^80)
    println()

    output_dir = joinpath(campaign_dir, "phase_transition_statistics")
    mkpath(output_dir)

    # Systematic parameter scan
    N_values = [20, 40, 60, 80]
    e_values = [0.0, 0.3, 0.5, 0.7, 0.8, 0.9]

    all_results = []

    for N in N_values
        for e in e_values
            println("\n" * "="^80)
            result = analyze_ensemble(campaign_dir, N, e; max_seeds=10)

            if !isnothing(result)
                # Plot individual ensemble
                label = @sprintf("N=%d, e=%.1f", N, e)
                output_file = joinpath(output_dir,
                    @sprintf("ensemble_N%d_e%.1f.png", N, e))
                plot_ensemble_evolution(result, label; output_file=output_file)
                println("  ✅ Plot saved")

                push!(all_results, result.stats)
            end
        end
    end

    # Scaling analysis
    df = analyze_scaling(all_results; output_dir=output_dir)

    # Save summary
    csv_file = joinpath(output_dir, "phase_transition_summary.csv")
    CSV.write(csv_file, df)

    println("\n" * "="^80)
    println("ANALYSIS COMPLETE")
    println("="^80)
    println("Output: $output_dir")
    println("Total conditions analyzed: $(nrow(df))")
end

# Main
if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) < 1
        println("Usage: julia analyze_phase_transition_statistics.jl <campaign_dir>")
        exit(1)
    end

    main_analysis(ARGS[1])
end
