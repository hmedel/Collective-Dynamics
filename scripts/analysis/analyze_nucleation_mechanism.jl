#!/usr/bin/env julia
#
# analyze_nucleation_mechanism.jl
#
# Test nucleation hypothesis:
# - Particles slow in high-κ regions → momentary accumulation
# - Collisions trigger synchronization → cluster nucleation
# - Clusters grow over time
# - Final location is stochastic (out-of-equilibrium)
#

using HDF5
using CSV
using DataFrames
using Statistics
using Plots
using Printf

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
    load_full_trajectory(h5_file)
"""
function load_full_trajectory(h5_file::String)
    h5open(h5_file, "r") do file
        phi = read(file["trajectories/phi"])
        phidot = read(file["trajectories/phidot"])
        times = read(file["trajectories/time"])

        meta_attrs = attributes(file["metadata"])
        a = read(meta_attrs["a"])
        b = read(meta_attrs["b"])
        e = read(meta_attrs["eccentricity"])
        N = read(meta_attrs["N"])

        return (
            phi = phi,
            phidot = phidot,
            times = times,
            a = a,
            b = b,
            e = e,
            N = N
        )
    end
end

"""
    compute_clustering_metrics(phi_snapshot)

R_∞, Ψ_∞ para un snapshot.
"""
function compute_clustering_metrics(phi_snapshot)
    x = cos.(phi_snapshot)
    y = sin.(phi_snapshot)
    x_cm = mean(x)
    y_cm = mean(y)
    R = sqrt(mean((x .- x_cm).^2 + (y .- y_cm).^2))

    z = mean(exp.(im .* phi_snapshot))
    Psi = abs(z)

    return R, Psi
end

"""
    analyze_cluster_growth(data; n_snapshots=50)

Analiza el crecimiento del cluster en el tiempo.
"""
function analyze_cluster_growth(data; n_snapshots=50)
    n_times = length(data.times)
    snapshot_indices = round.(Int, range(1, n_times, length=min(n_snapshots, n_times)))

    times = data.times[snapshot_indices]
    R_t = zeros(length(snapshot_indices))
    Psi_t = zeros(length(snapshot_indices))

    # Curvatura promedio que experimentan las partículas
    kappa_avg_t = zeros(length(snapshot_indices))

    for (i, idx) in enumerate(snapshot_indices)
        phi_snap = data.phi[idx, :]
        R_t[i], Psi_t[i] = compute_clustering_metrics(phi_snap)

        # Curvatura promedio
        kappas = [calculate_local_curvature(p, data.a, data.b) for p in phi_snap]
        kappa_avg_t[i] = mean(kappas)
    end

    return (
        times = times,
        R_t = R_t,
        Psi_t = Psi_t,
        kappa_avg_t = kappa_avg_t
    )
end

"""
    find_cluster_center_evolution(data; n_snapshots=20)

Rastrea la ubicación del centro del cluster en el tiempo.
"""
function find_cluster_center_evolution(data; n_snapshots=20)
    n_times = length(data.times)
    snapshot_indices = round.(Int, range(1, n_times, length=min(n_snapshots, n_times)))

    times = data.times[snapshot_indices]
    cluster_centers = zeros(length(snapshot_indices))

    for (i, idx) in enumerate(snapshot_indices)
        phi_snap = data.phi[idx, :]
        z = mean(exp.(im .* phi_snap))
        cluster_centers[i] = angle(z)
        if cluster_centers[i] < 0
            cluster_centers[i] += 2π
        end
    end

    # Curvatura en cada centro
    kappa_at_center = [calculate_local_curvature(c, data.a, data.b)
                       for c in cluster_centers]

    # Curvatura máxima en la elipse
    phi_test = range(0, 2π, length=1000)
    kappa_test = [calculate_local_curvature(p, data.a, data.b) for p in phi_test]
    kappa_max = maximum(kappa_test)
    phi_kappa_max = phi_test[argmax(kappa_test)]

    return (
        times = times,
        cluster_centers = cluster_centers,
        kappa_at_center = kappa_at_center,
        kappa_max = kappa_max,
        phi_kappa_max = phi_kappa_max
    )
end

"""
    analyze_collision_distribution(data; n_bins=30)

Analiza si hay más colisiones en regiones de alta curvatura.
Aproximación: si dos partículas están muy cerca, asumimos colisión reciente.
"""
function analyze_collision_distribution(data; n_bins=30, snapshot_idx=nothing)
    if isnothing(snapshot_idx)
        snapshot_idx = size(data.phi, 1)
    end

    phi = data.phi[snapshot_idx, :]
    N = length(phi)

    # Bins
    phi_edges = range(0, 2π, length=n_bins+1)
    phi_centers = (phi_edges[1:end-1] .+ phi_edges[2:end]) ./ 2

    # Contar "posibles colisiones" = pares de partículas cercanas
    collision_density = zeros(n_bins)

    for i in 1:N
        for j in (i+1):N
            # Distancia angular
            dphi = min(abs(phi[i] - phi[j]), 2π - abs(phi[i] - phi[j]))

            # Si están muy cerca (< 0.2 rad), potencial colisión
            if dphi < 0.2
                # Asignar a bin del punto medio
                phi_mid = (phi[i] + phi[j]) / 2
                idx = searchsortedfirst(phi_edges, phi_mid) - 1
                idx = clamp(idx, 1, n_bins)
                collision_density[idx] += 1
            end
        end
    end

    # Curvatura en cada bin
    curvature = [calculate_local_curvature(pc, data.a, data.b) for pc in phi_centers]

    # Correlación
    if std(collision_density) > 1e-10 && std(curvature) > 1e-10
        corr = cor(collision_density, curvature)
    else
        corr = NaN
    end

    return (
        phi_centers = phi_centers,
        collision_density = collision_density,
        curvature = curvature,
        correlation = corr
    )
end

"""
    plot_nucleation_analysis(data, growth, evolution, collision; output_file)
"""
function plot_nucleation_analysis(data, growth, evolution, collision; output_file=nothing)
    p = plot(layout = (3, 2), size = (1400, 1400), dpi = 150)

    # Panel 1: R(t) growth
    plot!(p[1], growth.times, growth.R_t,
          xlabel = "",
          ylabel = "R(t)",
          title = @sprintf("Cluster Growth (N=%d, e=%.1f)", data.N, data.e),
          linewidth = 2,
          color = :blue,
          legend = false,
          grid = true)

    # Panel 2: Ψ(t) synchronization
    plot!(p[2], growth.times, growth.Psi_t,
          xlabel = "",
          ylabel = "Ψ(t)",
          title = "Order Parameter Growth",
          linewidth = 2,
          color = :red,
          legend = false,
          grid = true)

    # Panel 3: Cluster center evolution
    plot!(p[3], evolution.times, evolution.cluster_centers,
          xlabel = "",
          ylabel = "Cluster center φ [rad]",
          title = "Cluster Center Trajectory",
          linewidth = 2,
          color = :green,
          legend = false,
          grid = true,
          ylims = (0, 2π))

    hline!(p[3], [evolution.phi_kappa_max],
           linestyle = :dash,
           color = :black,
           linewidth = 1,
           label = "κ_max location")

    # Panel 4: Curvatura en el centro del cluster vs tiempo
    plot!(p[4], evolution.times, evolution.kappa_at_center,
          xlabel = "Time",
          ylabel = "κ at cluster center",
          title = "Curvature at Cluster Location",
          linewidth = 2,
          color = :purple,
          legend = false,
          grid = true)

    hline!(p[4], [evolution.kappa_max],
           linestyle = :dash,
           color = :black,
           linewidth = 1,
           label = "κ_max")

    # Panel 5: Curvatura promedio vs tiempo
    plot!(p[5], growth.times, growth.kappa_avg_t,
          xlabel = "Time",
          ylabel = "⟨κ⟩ [avg over particles]",
          title = "Average Curvature Experienced",
          linewidth = 2,
          color = :orange,
          legend = false,
          grid = true)

    # Panel 6: Collision density vs curvature
    collision_norm = collision.collision_density ./ (maximum(collision.collision_density) + 1e-10)
    curv_norm = collision.curvature ./ maximum(collision.curvature)

    plot!(p[6], collision.phi_centers, collision_norm,
          label = "Collision density [norm]",
          linewidth = 2,
          color = :blue,
          xlabel = "φ [rad]",
          ylabel = "Normalized",
          title = @sprintf("Collisions vs κ | r = %.3f", collision.correlation),
          legend = :best,
          grid = true,
          xlims = (0, 2π))

    plot!(p[6], collision.phi_centers, curv_norm,
          label = "κ(φ) [norm]",
          linewidth = 2,
          color = :red,
          linestyle = :dash)

    if !isnothing(output_file)
        savefig(p, output_file)
    end

    return p
end

"""
    analyze_early_vs_late_clustering(data; t_threshold=0.2)

Compara clustering temprano vs tardío.
"""
function analyze_early_vs_late_clustering(data; t_threshold=0.2)
    t_max = data.times[end]
    idx_early = findfirst(data.times .>= t_threshold * t_max)
    idx_late = length(data.times)

    if isnothing(idx_early)
        idx_early = max(1, length(data.times) ÷ 5)
    end

    # Estados
    phi_early = data.phi[idx_early, :]
    phi_late = data.phi[idx_late, :]

    # Métricas
    R_early, Psi_early = compute_clustering_metrics(phi_early)
    R_late, Psi_late = compute_clustering_metrics(phi_late)

    # Centros
    z_early = mean(exp.(im .* phi_early))
    center_early = angle(z_early)
    if center_early < 0
        center_early += 2π
    end

    z_late = mean(exp.(im .* phi_late))
    center_late = angle(z_late)
    if center_late < 0
        center_late += 2π
    end

    # Curvatura en centros
    kappa_early = calculate_local_curvature(center_early, data.a, data.b)
    kappa_late = calculate_local_curvature(center_late, data.a, data.b)

    # Desplazamiento del centro
    center_drift = min(abs(center_late - center_early),
                      2π - abs(center_late - center_early))

    return (
        t_early = data.times[idx_early],
        t_late = data.times[idx_late],
        R_early = R_early,
        R_late = R_late,
        Psi_early = Psi_early,
        Psi_late = Psi_late,
        center_early = center_early,
        center_late = center_late,
        kappa_early = kappa_early,
        kappa_late = kappa_late,
        center_drift = center_drift
    )
end

"""
    main_analysis(campaign_dir)
"""
function main_analysis(campaign_dir::String)
    println("="^80)
    println("NUCLEATION MECHANISM ANALYSIS")
    println("="^80)
    println()
    println("Hypothesis: Momentary slowdown in high-κ regions")
    println("→ Transient accumulation → Collisions → Cluster nucleation")
    println("→ Clusters grow over time")
    println("→ Final location is stochastic (out-of-equilibrium)")
    println()

    output_dir = joinpath(campaign_dir, "nucleation_analysis")
    mkpath(output_dir)

    # Casos clave
    cases = [
        (N=40, e=0.5, label="Strong clustering"),
        (N=80, e=0.5, label="Larger N"),
        (N=60, e=0.9, label="High eccentricity"),
        (N=40, e=0.0, label="Circle (control)")
    ]

    results = []

    for case in cases
        println("\n" * "="^80)
        println("CASE: $(case.label) - N=$(case.N), e=$(case.e)")
        println("="^80)

        # Buscar un run
        run_dirs = filter(readdir(campaign_dir, join=true)) do path
            isdir(path) && occursin(r"^e\d", basename(path))
        end

        for run_dir in run_dirs
            run_name = basename(run_dir)
            m = match(r"e(\d+\.\d+)_N(\d+)_seed(\d+)", run_name)
            if !isnothing(m)
                e_run = parse(Float64, m.captures[1])
                N_run = parse(Int, m.captures[2])

                if N_run == case.N && abs(e_run - case.e) < 0.01
                    h5_file = joinpath(run_dir, "trajectories.h5")
                    if isfile(h5_file)
                        # Cargar datos
                        data = load_full_trajectory(h5_file)

                        # Análisis 1: Crecimiento temporal
                        growth = analyze_cluster_growth(data)

                        # Análisis 2: Evolución del centro
                        evolution = find_cluster_center_evolution(data)

                        # Análisis 3: Distribución de colisiones
                        collision = analyze_collision_distribution(data)

                        # Análisis 4: Temprano vs tardío
                        early_late = analyze_early_vs_late_clustering(data)

                        # Resultados
                        println("  Growth Analysis:")
                        println(@sprintf("    R: %.4f → %.4f (growth: %.1f%%)",
                                        growth.R_t[1], growth.R_t[end],
                                        100 * (growth.R_t[end] - growth.R_t[1]) / growth.R_t[1]))
                        println(@sprintf("    Ψ: %.4f → %.4f (growth: %.1f%%)",
                                        growth.Psi_t[1], growth.Psi_t[end],
                                        100 * (growth.Psi_t[end] - growth.Psi_t[1]) / (growth.Psi_t[1] + 1e-10)))

                        println("\n  Cluster Center Evolution:")
                        println(@sprintf("    Early (t=%.2f): φ = %.3f rad, κ = %.4f",
                                        early_late.t_early, early_late.center_early,
                                        early_late.kappa_early))
                        println(@sprintf("    Late  (t=%.2f): φ = %.3f rad, κ = %.4f",
                                        early_late.t_late, early_late.center_late,
                                        early_late.kappa_late))
                        println(@sprintf("    Center drift: %.3f rad", early_late.center_drift))

                        println("\n  Collision-Curvature Correlation:")
                        println(@sprintf("    r = %.4f", collision.correlation))

                        # Plot
                        output_file = joinpath(output_dir,
                            @sprintf("nucleation_N%d_e%.1f.png", case.N, case.e))
                        plot_nucleation_analysis(data, growth, evolution, collision;
                                                output_file=output_file)
                        println("  ✅ Plot saved")

                        push!(results, (
                            N = case.N,
                            e = case.e,
                            label = case.label,
                            R_growth = (growth.R_t[end] - growth.R_t[1]) / growth.R_t[1],
                            Psi_growth = (growth.Psi_t[end] - growth.Psi_t[1]) / (growth.Psi_t[1] + 1e-10),
                            center_drift = early_late.center_drift,
                            collision_kappa_corr = collision.correlation,
                            kappa_early = early_late.kappa_early,
                            kappa_late = early_late.kappa_late
                        ))

                        break
                    end
                end
            end
        end
    end

    # Resumen
    println("\n" * "="^80)
    println("SUMMARY OF NUCLEATION ANALYSIS")
    println("="^80)

    df = DataFrame(results)
    println(df)

    csv_file = joinpath(output_dir, "nucleation_summary.csv")
    CSV.write(csv_file, df)

    println("\nOutput: $output_dir")
    println("="^80)
end

# Main
if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) < 1
        println("Usage: julia analyze_nucleation_mechanism.jl <campaign_dir>")
        exit(1)
    end

    main_analysis(ARGS[1])
end
