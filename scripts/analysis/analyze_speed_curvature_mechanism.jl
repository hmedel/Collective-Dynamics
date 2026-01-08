#!/usr/bin/env julia
#
# analyze_speed_curvature_mechanism.jl
#
# Test hypothesis: Clustering occurs because particles slow down in high-curvature
# regions, leading to increased dwell time and density accumulation
#

using HDF5
using CSV
using DataFrames
using Statistics
using Plots
using Printf
using LinearAlgebra

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
    calculate_metric(phi, a, b)

Métrica g_θθ = a²sin²φ + b²cos²φ
Partículas deben moverse más lento en φ donde g_θθ es grande para conservar energía.
"""
function calculate_metric(phi::T, a::T, b::T) where T <: AbstractFloat
    return a^2 * sin(phi)^2 + b^2 * cos(phi)^2
end

"""
    load_trajectory_data(h5_file)

Carga trayectorias completas.
"""
function load_trajectory_data(h5_file::String)
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
    analyze_speed_vs_curvature(data; n_bins=30)

Analiza si la velocidad (tanto φ̇ como |v| cartesiana) correlaciona con κ(φ).
Usa partículas individuales para evitar problemas con bins vacíos.
"""
function analyze_speed_vs_curvature(data; n_bins=30, snapshot_idx=nothing)
    if isnothing(snapshot_idx)
        snapshot_idx = size(data.phi, 1)  # último snapshot
    end

    phi = data.phi[snapshot_idx, :]
    phidot = data.phidot[snapshot_idx, :]
    a, b = data.a, data.b

    # MÉTODO 1: Correlación directa usando partículas individuales
    # Calcular κ y g_θθ en la posición de cada partícula
    N = length(phi)
    kappa_particles = zeros(N)
    metric_particles = zeros(N)
    v_cart_particles = zeros(N)

    for i in 1:N
        kappa_particles[i] = calculate_local_curvature(phi[i], a, b)
        metric_particles[i] = calculate_metric(phi[i], a, b)
        v_cart_particles[i] = abs(phidot[i]) * sqrt(metric_particles[i])
    end

    # Correlaciones usando todas las partículas
    corr_phidot_kappa_particles = cor(abs.(phidot), kappa_particles)
    corr_vcart_kappa_particles = cor(v_cart_particles, kappa_particles)
    corr_phidot_metric_particles = cor(abs.(phidot), metric_particles)
    corr_vcart_metric_particles = cor(v_cart_particles, metric_particles)

    # MÉTODO 2: Análisis por bins (para visualización)
    phi_edges = range(0, 2π, length=n_bins+1)
    phi_centers = (phi_edges[1:end-1] .+ phi_edges[2:end]) ./ 2

    # Promedios por bin
    phidot_mean = zeros(n_bins)
    v_cart_mean = zeros(n_bins)
    density = zeros(n_bins)
    counts = zeros(Int, n_bins)

    for (p, pd) in zip(phi, phidot)
        idx = searchsortedfirst(phi_edges, p) - 1
        idx = clamp(idx, 1, n_bins)

        g_theta = calculate_metric(p, a, b)
        v_cart = abs(pd) * sqrt(g_theta)

        phidot_mean[idx] += abs(pd)
        v_cart_mean[idx] += v_cart
        density[idx] += 1
        counts[idx] += 1
    end

    # Promedios
    for i in 1:n_bins
        if counts[i] > 0
            phidot_mean[i] /= counts[i]
            v_cart_mean[i] /= counts[i]
        end
    end

    # Curvatura y métrica en cada bin
    curvature = [calculate_local_curvature(pc, a, b) for pc in phi_centers]
    metric = [calculate_metric(pc, a, b) for pc in phi_centers]

    return (
        phi_centers = phi_centers,
        curvature = curvature,
        metric = metric,
        phidot_mean = phidot_mean,
        v_cart_mean = v_cart_mean,
        density = density,
        # Correlaciones de partículas individuales (más robusto)
        corr_phidot_kappa = corr_phidot_kappa_particles,
        corr_vcart_kappa = corr_vcart_kappa_particles,
        corr_phidot_metric = corr_phidot_metric_particles,
        corr_vcart_metric = corr_vcart_metric_particles
    )
end

"""
    analyze_cluster_location_consistency(campaign_dir, N, e; max_seeds=10)

Verifica si los clusters se forman en las mismas posiciones φ entre diferentes seeds.
Si clustering es determinado por geometría → misma ubicación.
Si es aleatorio → ubicaciones diferentes.
"""
function analyze_cluster_location_consistency(campaign_dir::String, N::Int, e::Float64;
                                               max_seeds=10)
    println(@sprintf("\n=== Cluster Location Analysis: N=%d, e=%.1f ===", N, e))

    # Buscar runs
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
                    push!(matching_runs, h5_file)
                end
            end
        end

        if length(matching_runs) >= max_seeds
            break
        end
    end

    if length(matching_runs) == 0
        @warn "No runs found"
        return nothing
    end

    println("  Found $(length(matching_runs)) runs")

    # Para cada run, encontrar el centro del cluster principal
    cluster_centers = []
    a_val, b_val = 0.0, 0.0

    for h5_file in matching_runs
        data = load_trajectory_data(h5_file)
        a_val, b_val = data.a, data.b

        # Estado final
        phi_final = data.phi[end, :]

        # Centro de masa angular
        z = mean(exp.(im .* phi_final))
        cluster_center = angle(z)
        if cluster_center < 0
            cluster_center += 2π
        end

        push!(cluster_centers, cluster_center)
    end

    # Estadísticas de ubicaciones
    mean_center = angle(mean(exp.(im .* cluster_centers)))
    if mean_center < 0
        mean_center += 2π
    end

    # Dispersión angular
    R = abs(mean(exp.(im .* cluster_centers)))
    angular_std = sqrt(-2 * log(max(R, 1e-10)))

    println(@sprintf("  Cluster center locations: %.3f ± %.3f rad", mean_center, angular_std))

    # Curvatura en el centro promedio
    kappa_at_center = calculate_local_curvature(mean_center, a_val, b_val)
    metric_at_center = calculate_metric(mean_center, a_val, b_val)

    # Máximos de curvatura y métrica
    phi_test = range(0, 2π, length=1000)
    kappa_test = [calculate_local_curvature(p, a_val, b_val) for p in phi_test]
    metric_test = [calculate_metric(p, a_val, b_val) for p in phi_test]

    phi_kappa_max = phi_test[argmax(kappa_test)]
    phi_metric_max = phi_test[argmax(metric_test)]

    println(@sprintf("  κ at cluster center: %.4f", kappa_at_center))
    println(@sprintf("  κ_max location: %.3f rad | κ_max = %.4f", phi_kappa_max, maximum(kappa_test)))
    println(@sprintf("  g_θθ at cluster center: %.4f", metric_at_center))
    println(@sprintf("  g_θθ_max location: %.3f rad | g_θθ_max = %.4f", phi_metric_max, maximum(metric_test)))

    # ¿Cluster cerca de κ_max?
    dist_to_kappa_max = min(abs(mean_center - phi_kappa_max),
                            2π - abs(mean_center - phi_kappa_max))
    println(@sprintf("  Distance to κ_max: %.3f rad", dist_to_kappa_max))

    return (
        cluster_centers = cluster_centers,
        mean_center = mean_center,
        angular_std = angular_std,
        kappa_at_center = kappa_at_center,
        metric_at_center = metric_at_center,
        phi_kappa_max = phi_kappa_max,
        phi_metric_max = phi_metric_max,
        dist_to_kappa_max = dist_to_kappa_max
    )
end

"""
    plot_speed_curvature_analysis(data, analysis; output_file=nothing)
"""
function plot_speed_curvature_analysis(data, analysis; output_file=nothing)
    p = plot(layout = (3, 2), size = (1400, 1400), dpi = 150)

    phi_c = analysis.phi_centers

    # Normalizar para comparación
    kappa_norm = analysis.curvature ./ maximum(analysis.curvature)
    metric_norm = analysis.metric ./ maximum(analysis.metric)
    density_norm = analysis.density ./ maximum(analysis.density .+ 1e-10)

    # Panel 1: Densidad vs Curvatura
    plot!(p[1], phi_c, density_norm,
          label = "ρ(φ) [norm]",
          linewidth = 2,
          color = :blue,
          xlabel = "",
          ylabel = "Normalized",
          title = "Density vs Curvature (binned)",
          legend = :best,
          grid = true,
          xlims = (0, 2π))

    plot!(p[1], phi_c, kappa_norm,
          label = "κ(φ) [norm]",
          linewidth = 2,
          color = :red,
          linestyle = :dash)

    # Panel 2: φ̇ promedio vs Curvatura
    phidot_norm = analysis.phidot_mean ./ (maximum(analysis.phidot_mean) + 1e-10)

    plot!(p[2], phi_c, phidot_norm,
          label = "⟨|φ̇|⟩ [norm]",
          linewidth = 2,
          color = :green,
          xlabel = "",
          ylabel = "Normalized",
          title = @sprintf("Angular Speed vs Curvature | r = %.3f", analysis.corr_phidot_kappa),
          legend = :best,
          grid = true,
          xlims = (0, 2π))

    plot!(p[2], phi_c, kappa_norm,
          label = "κ(φ) [norm]",
          linewidth = 2,
          color = :red,
          linestyle = :dash)

    # Panel 3: |v| cartesiana vs Curvatura
    vcart_norm = analysis.v_cart_mean ./ (maximum(analysis.v_cart_mean) + 1e-10)

    plot!(p[3], phi_c, vcart_norm,
          label = "⟨|v|⟩ [norm]",
          linewidth = 2,
          color = :purple,
          xlabel = "",
          ylabel = "Normalized",
          title = @sprintf("Cartesian Speed vs Curvature | r = %.3f", analysis.corr_vcart_kappa),
          legend = :best,
          grid = true,
          xlims = (0, 2π))

    plot!(p[3], phi_c, kappa_norm,
          label = "κ(φ) [norm]",
          linewidth = 2,
          color = :red,
          linestyle = :dash)

    # Panel 4: Densidad vs Métrica g_θθ
    plot!(p[4], phi_c, density_norm,
          label = "ρ(φ) [norm]",
          linewidth = 2,
          color = :blue,
          xlabel = "φ [rad]",
          ylabel = "Normalized",
          title = "Density vs Metric (binned)",
          legend = :best,
          grid = true,
          xlims = (0, 2π))

    plot!(p[4], phi_c, metric_norm,
          label = "g_θθ [norm]",
          linewidth = 2,
          color = :orange,
          linestyle = :dash)

    # Panel 5: φ̇ vs Métrica
    plot!(p[5], phi_c, phidot_norm,
          label = "⟨|φ̇|⟩ [norm]",
          linewidth = 2,
          color = :green,
          xlabel = "φ [rad]",
          ylabel = "Normalized",
          title = @sprintf("Angular Speed vs Metric | r = %.3f", analysis.corr_phidot_metric),
          legend = :best,
          grid = true,
          xlims = (0, 2π))

    plot!(p[5], phi_c, metric_norm,
          label = "g_θθ [norm]",
          linewidth = 2,
          color = :orange,
          linestyle = :dash)

    # Panel 6: Scatter ρ vs κ
    scatter!(p[6], analysis.curvature, analysis.density,
             xlabel = "κ(φ)",
             ylabel = "ρ(φ) [count]",
             title = "Density vs Curvature Scatter",
             markersize = 6,
             color = :blue,
             alpha = 0.6,
             legend = false,
             grid = true)

    plot!(p, plot_title = @sprintf("N=%d, e=%.1f - Speed-Curvature Mechanism Analysis",
                                   data.N, data.e))

    if !isnothing(output_file)
        savefig(p, output_file)
    end

    return p
end

"""
    main_analysis(campaign_dir)
"""
function main_analysis(campaign_dir::String)
    println("="^80)
    println("SPEED-CURVATURE CLUSTERING MECHANISM ANALYSIS")
    println("="^80)
    println()
    println("Testing hypothesis: Particles slow in high-curvature regions")
    println("→ Increased dwell time → Density accumulation → Clustering")
    println()

    output_dir = joinpath(campaign_dir, "speed_curvature_mechanism")
    mkpath(output_dir)

    # Casos clave
    cases = [
        (N=40, e=0.5, label="Strong clustering"),
        (N=80, e=0.5, label="Same e, larger N"),
        (N=60, e=0.9, label="High eccentricity"),
        (N=40, e=0.0, label="Circle (control)")
    ]

    results = []

    for case in cases
        println("\n" * "="^80)
        println("CASE: $(case.label) - N=$(case.N), e=$(case.e)")
        println("="^80)

        # Análisis de ubicación de clusters
        loc_analysis = analyze_cluster_location_consistency(
            campaign_dir, case.N, case.e; max_seeds=10
        )

        if !isnothing(loc_analysis)
            # Cargar un run representativo para análisis de velocidad
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
                            # Cargar y analizar
                            data = load_trajectory_data(h5_file)
                            analysis = analyze_speed_vs_curvature(data)

                            println("\nSpeed-Curvature Correlations (per-particle):")
                            println(@sprintf("  |φ̇| - κ:      %.4f", analysis.corr_phidot_kappa))
                            println(@sprintf("  |v| - κ:      %.4f", analysis.corr_vcart_kappa))
                            println(@sprintf("  |φ̇| - g_θθ:   %.4f", analysis.corr_phidot_metric))
                            println(@sprintf("  |v| - g_θθ:   %.4f", analysis.corr_vcart_metric))

                            # Plot
                            output_file = joinpath(output_dir,
                                @sprintf("mechanism_N%d_e%.1f.png", case.N, case.e))
                            plot_speed_curvature_analysis(data, analysis; output_file=output_file)
                            println("  ✅ Plot saved")

                            push!(results, merge(
                                (N=case.N, e=case.e, label=case.label),
                                (corr_phidot_kappa = analysis.corr_phidot_kappa,
                                 corr_vcart_kappa = analysis.corr_vcart_kappa,
                                 corr_phidot_metric = analysis.corr_phidot_metric,
                                 corr_vcart_metric = analysis.corr_vcart_metric,
                                 angular_std = loc_analysis.angular_std,
                                 dist_to_kappa_max = loc_analysis.dist_to_kappa_max)
                            ))

                            break
                        end
                    end
                end
            end
        end
    end

    # Resumen
    println("\n" * "="^80)
    println("SUMMARY OF RESULTS")
    println("="^80)

    df = DataFrame(results)
    println(df)

    csv_file = joinpath(output_dir, "speed_curvature_correlations.csv")
    CSV.write(csv_file, df)

    println("\nOutput: $output_dir")
    println("="^80)
end

# Main
if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) < 1
        println("Usage: julia analyze_speed_curvature_mechanism.jl <campaign_dir>")
        exit(1)
    end

    main_analysis(ARGS[1])
end
