#!/usr/bin/env julia
# Análisis de transición de fase: Gas → Cristal (clustering)
# Analiza dinámica de formación de orden, espacio fase, y nucleación

using Pkg
Pkg.activate(".")

using HDF5
using Statistics
using Printf
using Plots
using LaTeXStrings

"""
Calcula parámetro de orden para cuantificar clustering.

Usamos la varianza de la distribución angular como parámetro de orden:
- σ²(φ) = 0 → todas las partículas en mismo lugar (cristal perfecto)
- σ²(φ) → max → distribución uniforme (gas)

Normalizamos para que:
- Ψ = 0 → gas (uniforme)
- Ψ = 1 → cristal (todas en un punto)
"""
function order_parameter(phi_positions)
    # Calcular momentos circulares (correcto para ángulos)
    mean_cos = mean(cos.(phi_positions))
    mean_sin = mean(sin.(phi_positions))

    # R parameter (mean resultant length)
    R = sqrt(mean_cos^2 + mean_sin^2)

    # R = 0 → uniforme (gas)
    # R = 1 → todas en mismo ángulo (cristal)
    return R
end

"""
Calcula clustering ratio (más intuitivo para visualizar)
"""
function clustering_ratio(phi_positions, bin_width=π/4)
    # Bins para eje mayor (0°±45°, 180°±45°) y menor (90°±45°, 270°±45°)
    n_mayor = count(φ -> (φ < bin_width || φ > 2π - bin_width ||
                          abs(φ - π) < bin_width), phi_positions)
    n_menor = count(φ -> abs(φ - π/2) < bin_width ||
                          abs(φ - 3π/2) < bin_width, phi_positions)

    # Evitar división por cero
    return n_mayor / max(n_menor, 1)
end

"""
Analiza distribución en espacio fase (φ, φ̇)
"""
function phase_space_entropy(phi, phidot; n_bins=20)
    # Crear grid 2D en espacio fase
    phi_edges = range(0, 2π, length=n_bins+1)
    phidot_min, phidot_max = extrema(phidot)
    phidot_edges = range(phidot_min, phidot_max, length=n_bins+1)

    # Histograma 2D
    H = zeros(n_bins, n_bins)
    for (p, pd) in zip(phi, phidot)
        i = searchsortedfirst(phi_edges, p) - 1
        j = searchsortedfirst(phidot_edges, pd) - 1
        i = clamp(i, 1, n_bins)
        j = clamp(j, 1, n_bins)
        H[i, j] += 1
    end

    # Normalizar
    H ./= sum(H)

    # Entropía de Shannon
    S = 0.0
    for p in H
        if p > 0
            S -= p * log(p)
        end
    end

    # Normalizar por entropía máxima
    S_max = log(n_bins^2)

    return S / S_max  # 0 = orden perfecto, 1 = máximo desorden
end

"""
Detecta clusters (nucleación)
"""
function detect_clusters(phi_positions; threshold=0.3)
    # Ordenar ángulos
    phi_sorted = sort(phi_positions)
    N = length(phi_sorted)

    # Detectar gaps grandes
    clusters = []
    current_cluster = [phi_sorted[1]]

    for i in 2:N
        gap = phi_sorted[i] - phi_sorted[i-1]

        # Considerar wrap-around
        if i == N
            gap = min(gap, 2π - phi_sorted[N] + phi_sorted[1])
        end

        if gap < threshold
            push!(current_cluster, phi_sorted[i])
        else
            push!(clusters, current_cluster)
            current_cluster = [phi_sorted[i]]
        end
    end

    # Agregar último cluster
    push!(clusters, current_cluster)

    return clusters
end

"""
Análisis completo de un archivo HDF5
"""
function analyze_single_run(filepath::String; output_dir="analysis")
    println("="^70)
    println("ANÁLISIS DE TRANSICIÓN DE FASE")
    println("="^70)
    println()
    println("Archivo: $filepath")
    println()

    # Leer datos
    h5open(filepath, "r") do file
        # Configuración
        e = read(attributes(file["config"]), "eccentricity")
        N = read(attributes(file["config"]), "N")
        seed = read(attributes(file["config"]), "seed")

        @printf("Configuración: e=%.3f, N=%d, seed=%d\n", e, N, seed)
        println()

        # Trayectorias
        times = read(file["trajectories/time"])
        phi = read(file["trajectories/phi"])  # [N × n_times]
        phidot = read(file["trajectories/phidot"])

        n_times = length(times)

        println("Datos:")
        @printf("  Tiempo total: %.1f s\n", times[end])
        @printf("  Timesteps guardados: %d\n", n_times)
        println()

        # Calcular métricas temporales
        println("Calculando métricas temporales...")

        order_param = zeros(n_times)
        cluster_ratio = zeros(n_times)
        entropy = zeros(n_times)
        n_clusters = zeros(Int, n_times)
        largest_cluster_frac = zeros(n_times)

        for t in 1:n_times
            phi_t = phi[:, t]
            phidot_t = phidot[:, t]

            # Parámetro de orden
            order_param[t] = order_parameter(phi_t)

            # Clustering ratio
            cluster_ratio[t] = clustering_ratio(phi_t)

            # Entropía de espacio fase
            entropy[t] = phase_space_entropy(phi_t, phidot_t)

            # Detección de clusters
            clusters = detect_clusters(phi_t)
            n_clusters[t] = length(clusters)
            largest_cluster_frac[t] = maximum(length.(clusters)) / N
        end

        println("✅ Métricas calculadas")
        println()

        # Análisis de transición
        println("="^70)
        println("ANÁLISIS DE TRANSICIÓN DE FASE")
        println("="^70)
        println()

        # Estado inicial
        @printf("Estado inicial (t=%.1f s):\n", times[1])
        @printf("  Parámetro de orden Ψ: %.3f\n", order_param[1])
        @printf("  Clustering ratio R: %.2f\n", cluster_ratio[1])
        @printf("  Entropía espacio fase: %.3f\n", entropy[1])
        @printf("  # Clusters: %d\n", n_clusters[1])
        println()

        # Estado final
        @printf("Estado final (t=%.1f s):\n", times[end])
        @printf("  Parámetro de orden Ψ: %.3f\n", order_param[end])
        @printf("  Clustering ratio R: %.2f\n", cluster_ratio[end])
        @printf("  Entropía espacio fase: %.3f\n", entropy[end])
        @printf("  # Clusters: %d\n", n_clusters[end])
        @printf("  Fracción en cluster más grande: %.1f%%\n", largest_cluster_frac[end]*100)
        println()

        # Tiempo de relajación (cuando Ψ alcanza 90% de su valor final)
        Ψ_90 = 0.1 + 0.9 * order_param[end]
        idx_relax = findfirst(order_param .> Ψ_90)
        if idx_relax !== nothing
            τ_relax = times[idx_relax]
            @printf("Tiempo de relajación τ (90%% de Ψ_final): %.1f s\n", τ_relax)
        else
            println("Tiempo de relajación: No alcanzado")
        end
        println()

        # Crear directorio de salida
        mkpath(output_dir)

        # Generar figuras
        println("Generando figuras...")

        # Figura 1: Evolución temporal de métricas
        p1 = plot(times, order_param,
                 label=L"Order parameter $\Psi$",
                 xlabel="Time (s)", ylabel=L"$\Psi$",
                 title="Phase Transition Dynamics (e=$(@sprintf("%.2f", e)))",
                 linewidth=2, legend=:bottomright)

        p2 = plot(times, cluster_ratio,
                 label="Clustering ratio R",
                 xlabel="Time (s)", ylabel="R",
                 linewidth=2, color=:red, legend=:bottomright)

        p3 = plot(times, entropy,
                 label="Phase space entropy",
                 xlabel="Time (s)", ylabel="S/S_max",
                 linewidth=2, color=:green, legend=:topright)

        p4 = plot(times, n_clusters,
                 label="Number of clusters",
                 xlabel="Time (s)", ylabel="N_clusters",
                 linewidth=2, color=:purple, legend=:topright)

        fig1 = plot(p1, p2, p3, p4, layout=(2,2), size=(1000, 800))
        savefig(fig1, joinpath(output_dir, "phase_transition_e$(@sprintf("%.2f", e))_seed$(seed).png"))

        # Figura 2: Espacio fase en diferentes tiempos
        # Seleccionar 4 tiempos: inicial, 25%, 50%, final
        time_indices = [1, n_times÷4, n_times÷2, n_times]

        plots_ps = []
        for idx in time_indices
            t = times[idx]
            p = scatter(phi[:, idx], phidot[:, idx],
                       xlabel=L"$\phi$", ylabel=L"$\dot{\phi}$",
                       title="t = $(@sprintf("%.1f", t)) s",
                       markersize=3, alpha=0.6, legend=false,
                       xlims=(0, 2π), xticks=([0, π, 2π], ["0", "π", "2π"]))
            push!(plots_ps, p)
        end

        fig2 = plot(plots_ps..., layout=(2,2), size=(1000, 800),
                   plot_title="Phase Space Evolution (e=$(@sprintf("%.2f", e)))")
        savefig(fig2, joinpath(output_dir, "phase_space_e$(@sprintf("%.2f", e))_seed$(seed).png"))

        # Figura 3: Distribución angular en diferentes tiempos
        plots_dist = []
        for idx in time_indices
            t = times[idx]
            histogram_data = phi[:, idx]
            p = histogram(histogram_data, bins=36,
                         xlabel=L"$\phi$", ylabel="Count",
                         title="t = $(@sprintf("%.1f", t)) s",
                         legend=false, normalize=true,
                         xlims=(0, 2π), xticks=([0, π/2, π, 3π/2, 2π],
                                                ["0", "π/2", "π", "3π/2", "2π"]))
            # Marcar ejes mayor y menor
            vline!([0, π], linewidth=2, color=:red, alpha=0.3, label="Major axis")
            vline!([π/2, 3π/2], linewidth=2, color=:blue, alpha=0.3, label="Minor axis")
            push!(plots_dist, p)
        end

        fig3 = plot(plots_dist..., layout=(2,2), size=(1000, 800),
                   plot_title="Angular Distribution Evolution (e=$(@sprintf("%.2f", e)))")
        savefig(fig3, joinpath(output_dir, "angular_distribution_e$(@sprintf("%.2f", e))_seed$(seed).png"))

        println("✅ Figuras guardadas en $output_dir/")
        println()

        # Retornar resumen
        return (
            e = e,
            N = N,
            seed = seed,
            Ψ_initial = order_param[1],
            Ψ_final = order_param[end],
            R_initial = cluster_ratio[1],
            R_final = cluster_ratio[end],
            S_initial = entropy[1],
            S_final = entropy[end],
            τ_relax = idx_relax !== nothing ? times[idx_relax] : NaN,
            n_clusters_final = n_clusters[end],
            largest_cluster_frac = largest_cluster_frac[end]
        )
    end
end

# Main
if length(ARGS) < 1
    println("Usage: julia analyze_phase_transition.jl <hdf5_file> [output_dir]")
    println()
    println("Example:")
    println("  julia analyze_phase_transition.jl results/eccentricity_scan/run_0001_e0.980_N80_E0.32_seed1.h5")
    exit(1)
end

filepath = ARGS[1]
output_dir = length(ARGS) >= 2 ? ARGS[2] : "analysis"

if !isfile(filepath)
    println("ERROR: File not found: $filepath")
    exit(1)
end

results = analyze_single_run(filepath; output_dir=output_dir)

println("="^70)
println("ANÁLISIS COMPLETADO")
println("="^70)
println()
println("Resumen:")
@printf("  e = %.3f\n", results.e)
@printf("  Ψ: %.3f → %.3f\n", results.Ψ_initial, results.Ψ_final)
@printf("  R: %.2f → %.2f\n", results.R_initial, results.R_final)
@printf("  τ_relax: %.1f s\n", results.τ_relax)
println()
