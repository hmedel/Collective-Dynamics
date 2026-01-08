#!/usr/bin/env julia
#
# analyze_temporal_dynamics.jl
#
# Análisis detallado de la dinámica temporal:
# - Evolución de R(t), Ψ(t), σ(t)
# - Identificación de timescales característicos
# - Análisis de relajación
# - Clustering transient vs steady state
#

using HDF5
using CSV
using DataFrames
using Statistics
using Plots
using Printf

gr()

"""
    load_timeseries(h5_file)

Carga series temporales completas de un run.
"""
function load_timeseries(h5_file::String)
    h5open(h5_file, "r") do file
        times = read(file["trajectories/time"])
        phi = read(file["trajectories/phi"])
        phidot = read(file["trajectories/phidot"])
        energy = read(file["conservation/total_energy"])

        return (
            times = times,
            phi = phi,
            phidot = phidot,
            energy = energy
        )
    end
end

"""
    compute_clustering_timeseries(phi_matrix)

Computa R(t), Ψ(t), σ(t) para cada snapshot.
"""
function compute_clustering_timeseries(phi_matrix)
    n_snapshots, N = size(phi_matrix)

    R_t = zeros(n_snapshots)
    Psi_t = zeros(n_snapshots)
    sigma_t = zeros(n_snapshots)

    for i in 1:n_snapshots
        phi = phi_matrix[i, :]

        # Cluster radius
        x = cos.(phi)
        y = sin.(phi)
        x_cm = mean(x)
        y_cm = mean(y)
        R_t[i] = sqrt(mean((x .- x_cm).^2 + (y .- y_cm).^2))

        # Order parameter
        z = mean(exp.(im .* phi))
        Psi_t[i] = abs(z)

        # Angular dispersion
        R_bar = abs(z)
        sigma_t[i] = sqrt(-2 * log(max(R_bar, 1e-10)))
    end

    return R_t, Psi_t, sigma_t
end

"""
    find_relaxation_time(times, R_t; threshold=0.05)

Encuentra el tiempo de relajación τ donde |R(t) - R_∞| < threshold.
"""
function find_relaxation_time(times, R_t; threshold=0.05)
    # Estimar R_∞ como promedio de últimos 20%
    idx_late = floor(Int, 0.8 * length(R_t)):length(R_t)
    R_inf = mean(R_t[idx_late])

    # Encontrar primer tiempo donde |R - R_inf| < threshold
    for (i, R) in enumerate(R_t)
        if abs(R - R_inf) < threshold
            return times[i], R_inf
        end
    end

    return times[end], R_inf  # No alcanzó equilibrio
end

"""
    exponential_relaxation(t, p)

Modelo: R(t) = R_inf + (R_0 - R_inf) * exp(-t/τ)
p = [R_inf, R_0, τ]
"""
function exponential_relaxation(t, p)
    R_inf, R_0, tau = p
    return R_inf .+ (R_0 .- R_inf) .* exp.(-t ./ tau)
end

"""
    analyze_single_run_dynamics(h5_file, run_name; output_dir=nothing)

Analiza la dinámica completa de un solo run.
"""
function analyze_single_run_dynamics(h5_file::String, run_name::String;
                                      output_dir=nothing, save_plots=true)

    # Cargar datos
    data = load_timeseries(h5_file)
    times = data.times
    phi = data.phi
    phidot = data.phidot
    energy = data.energy

    n_snapshots, N = size(phi)

    # Compute clustering metrics
    R_t, Psi_t, sigma_t = compute_clustering_timeseries(phi)

    # Find relaxation time
    tau_relax, R_inf = find_relaxation_time(times, R_t)

    # Statistics
    results = Dict{String, Any}(
        "run_name" => run_name,
        "N" => N,
        "t_final" => times[end],
        "n_snapshots" => n_snapshots,

        # Asymptotic values
        "R_inf" => R_inf,
        "Psi_inf" => mean(Psi_t[end-10:end]),
        "sigma_inf" => mean(sigma_t[end-10:end]),

        # Relaxation
        "tau_relax" => tau_relax,

        # Initial values
        "R_0" => R_t[1],
        "Psi_0" => Psi_t[1],

        # Variability
        "R_std" => std(R_t),
        "Psi_std" => std(Psi_t),

        # Energy conservation
        "dE_rel_max" => maximum(abs.(energy .- energy[1])) / abs(energy[1])
    )

    # Generate plots if requested
    if save_plots && !isnothing(output_dir)
        mkpath(output_dir)

        # Plot 1: R(t), Ψ(t), σ(t)
        p1 = plot(
            layout = (3, 1),
            size = (1000, 900),
            dpi = 150
        )

        plot!(p1[1], times, R_t,
              xlabel = "", ylabel = "R(t)",
              title = "$run_name - Clustering Dynamics",
              linewidth = 2, color = :blue,
              legend = false, grid = true)
        hline!(p1[1], [R_inf], linestyle = :dash, color = :black,
               linewidth = 1, label = "R_∞")
        vline!(p1[1], [tau_relax], linestyle = :dot, color = :red,
               linewidth = 1, label = "τ_relax")

        plot!(p1[2], times, Psi_t,
              xlabel = "", ylabel = "Ψ(t)",
              linewidth = 2, color = :red,
              legend = false, grid = true)

        plot!(p1[3], times, sigma_t,
              xlabel = "Time t", ylabel = "σ(t)",
              linewidth = 2, color = :green,
              legend = false, grid = true)

        savefig(p1, joinpath(output_dir, "$(run_name)_clustering_evolution.png"))

        # Plot 2: Energy conservation
        p2 = plot(times, (energy .- energy[1]) ./ energy[1],
                  xlabel = "Time t",
                  ylabel = "ΔE/E₀",
                  title = "$run_name - Energy Conservation",
                  linewidth = 2,
                  color = :purple,
                  legend = false,
                  grid = true,
                  size = (800, 400),
                  dpi = 150)

        savefig(p2, joinpath(output_dir, "$(run_name)_energy_conservation.png"))
    end

    return results, (R_t=R_t, Psi_t=Psi_t, sigma_t=sigma_t, times=times)
end

"""
    analyze_multiple_runs(campaign_dir, conditions; max_runs=10)

Analiza múltiples runs para condiciones específicas (N, e).
"""
function analyze_multiple_runs(campaign_dir::String,
                                N::Int, e::Float64;
                                max_runs=10, output_dir=nothing)

    println("Analyzing dynamics for N=$N, e=$e...")

    # Buscar runs que coincidan
    run_dirs = filter(readdir(campaign_dir, join=true)) do path
        isdir(path) && occursin(r"^e\d", basename(path))
    end

    matching_runs = []
    for run_dir in run_dirs
        run_name = basename(run_dir)
        m = match(r"e(\d+\.\d+)_N(\d+)_seed(\d+)", run_name)
        if !isnothing(m)
            e_run = parse(Float64, m.captures[1])
            N_run = parse(Int, m.captures[2])

            if N_run == N && abs(e_run - e) < 0.01
                h5_file = joinpath(run_dir, "trajectories.h5")
                if isfile(h5_file)
                    push!(matching_runs, (run_name, h5_file))
                end
            end
        end

        if length(matching_runs) >= max_runs
            break
        end
    end

    if length(matching_runs) == 0
        @warn "No matching runs found for N=$N, e=$e"
        return nothing
    end

    println("  Found $(length(matching_runs)) runs")

    # Analizar cada run
    all_R_t = []
    all_Psi_t = []
    all_times = []
    results_list = []

    for (run_name, h5_file) in matching_runs
        results, timeseries = analyze_single_run_dynamics(h5_file, run_name;
                                                          output_dir=nothing,
                                                          save_plots=false)
        push!(results_list, results)
        push!(all_R_t, timeseries.R_t)
        push!(all_Psi_t, timeseries.Psi_t)
        push!(all_times, timeseries.times)
    end

    # Ensemble average
    # Interpolar a una grilla temporal común
    t_common = range(0, stop=minimum([t[end] for t in all_times]), length=200)

    R_interp = zeros(length(t_common), length(matching_runs))
    Psi_interp = zeros(length(t_common), length(matching_runs))

    for (i, (R, t)) in enumerate(zip(all_R_t, all_times))
        # Simple linear interpolation
        for (j, t_target) in enumerate(t_common)
            idx = searchsortedfirst(t, t_target)
            if idx > length(t)
                R_interp[j, i] = R[end]
                Psi_interp[j, i] = all_Psi_t[i][end]
            elseif idx == 1
                R_interp[j, i] = R[1]
                Psi_interp[j, i] = all_Psi_t[i][1]
            else
                # Linear interpolation
                t1, t2 = t[idx-1], t[idx]
                R1, R2 = R[idx-1], R[idx]
                Psi1, Psi2 = all_Psi_t[i][idx-1], all_Psi_t[i][idx]

                w = (t_target - t1) / (t2 - t1)
                R_interp[j, i] = R1 + w * (R2 - R1)
                Psi_interp[j, i] = Psi1 + w * (Psi2 - Psi1)
            end
        end
    end

    # Mean and std
    R_mean = vec(mean(R_interp, dims=2))
    R_std = vec(std(R_interp, dims=2))
    Psi_mean = vec(mean(Psi_interp, dims=2))
    Psi_std = vec(std(Psi_interp, dims=2))

    # Plot ensemble
    if !isnothing(output_dir)
        mkpath(output_dir)

        p = plot(
            layout = (2, 1),
            size = (1000, 800),
            dpi = 150
        )

        # R(t)
        plot!(p[1], t_common, R_mean,
              ribbon = R_std,
              xlabel = "",
              ylabel = "⟨R(t)⟩",
              title = @sprintf("Ensemble Average: N=%d, e=%.1f (%d realizations)",
                              N, e, length(matching_runs)),
              linewidth = 3,
              color = :blue,
              fillalpha = 0.3,
              legend = false,
              grid = true)

        # Ψ(t)
        plot!(p[2], t_common, Psi_mean,
              ribbon = Psi_std,
              xlabel = "Time t",
              ylabel = "⟨Ψ(t)⟩",
              linewidth = 3,
              color = :red,
              fillalpha = 0.3,
              legend = false,
              grid = true)

        filename = @sprintf("ensemble_N%d_e%.1f.png", N, e)
        savefig(p, joinpath(output_dir, filename))
        println("  ✅ Saved: $filename")
    end

    return (
        results = DataFrame(results_list),
        ensemble = (t=t_common, R_mean=R_mean, R_std=R_std,
                   Psi_mean=Psi_mean, Psi_std=Psi_std)
    )
end

"""
    compare_dynamics_across_e(campaign_dir, N; output_dir)

Compara la dinámica para diferentes eccentricities con N fijo.
"""
function compare_dynamics_across_e(campaign_dir::String, N::Int; output_dir)

    println("\nComparing dynamics across eccentricities for N=$N...")

    e_values = [0.0, 0.3, 0.5, 0.7, 0.8, 0.9]

    mkpath(output_dir)

    p_R = plot(
        xlabel = "Time t",
        ylabel = "⟨R(t)⟩",
        title = @sprintf("Clustering Dynamics vs Eccentricity (N=%d)", N),
        legend = :best,
        size = (1000, 600),
        dpi = 150,
        grid = true
    )

    p_Psi = plot(
        xlabel = "Time t",
        ylabel = "⟨Ψ(t)⟩",
        title = @sprintf("Order Parameter vs Eccentricity (N=%d)", N),
        legend = :best,
        size = (1000, 600),
        dpi = 150,
        grid = true
    )

    colors = [:blue, :red, :green, :purple, :orange, :brown]

    for (i, e) in enumerate(e_values)
        result = analyze_multiple_runs(campaign_dir, N, e;
                                       max_runs=5, output_dir=nothing)

        if isnothing(result)
            continue
        end

        ens = result.ensemble

        plot!(p_R, ens.t, ens.R_mean,
              ribbon = ens.R_std,
              label = @sprintf("e = %.1f", e),
              linewidth = 2,
              color = colors[i],
              fillalpha = 0.2)

        plot!(p_Psi, ens.t, ens.Psi_mean,
              ribbon = ens.Psi_std,
              label = @sprintf("e = %.1f", e),
              linewidth = 2,
              color = colors[i],
              fillalpha = 0.2)
    end

    savefig(p_R, joinpath(output_dir, @sprintf("dynamics_vs_e_N%d_R.png", N)))
    savefig(p_Psi, joinpath(output_dir, @sprintf("dynamics_vs_e_N%d_Psi.png", N)))

    println("  ✅ Comparison plots saved")
end

"""
    main_analysis(campaign_dir)
"""
function main_analysis(campaign_dir::String)
    println("="^80)
    println("TEMPORAL DYNAMICS ANALYSIS")
    println("="^80)
    println()

    output_dir = joinpath(campaign_dir, "temporal_analysis")
    mkpath(output_dir)

    # Analyze representative cases
    println("Analyzing representative single runs...")

    cases = [
        (N=40, e=0.5, label="Strong clustering"),
        (N=80, e=0.0, label="Circle (reference)"),
        (N=60, e=0.9, label="High eccentricity")
    ]

    for case in cases
        result = analyze_multiple_runs(campaign_dir, case.N, case.e;
                                       max_runs=1, output_dir=output_dir)
    end

    # Compare dynamics across e for fixed N
    println("\nComparing dynamics across eccentricities...")
    for N in [40, 80]
        compare_dynamics_across_e(campaign_dir, N; output_dir=output_dir)
    end

    println()
    println("="^80)
    println("✅ TEMPORAL DYNAMICS ANALYSIS COMPLETE")
    println("="^80)
    println("Output: $output_dir")
end

# Main
if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) < 1
        println("Usage: julia analyze_temporal_dynamics.jl <campaign_dir>")
        exit(1)
    end

    main_analysis(ARGS[1])
end
