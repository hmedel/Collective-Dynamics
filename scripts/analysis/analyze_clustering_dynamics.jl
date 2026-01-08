#!/usr/bin/env julia
using HDF5
using Statistics
using Printf

"""
Analizar dinámica de clustering:
1. ¿Alcanza estado estacionario en t=200s?
2. ¿Clusters múltiples o uno solo?
3. ¿Hay coexistencia de fases (bimodalidad)?
"""

campaign_dir = "results/campaign_eccentricity_scan_20251116_014451"

println("="^70)
println("ANÁLISIS DE DINÁMICA DE CLUSTERING")
println("="^70)
println()

function clustering_ratio(phi_positions, bin_width=π/4)
    n_mayor = count(φ -> (φ < bin_width || φ > 2π - bin_width ||
                          abs(φ - π) < bin_width), phi_positions)
    n_menor = count(φ -> abs(φ - π/2) < bin_width ||
                          abs(φ - 3π/2) < bin_width, phi_positions)
    return n_mayor / max(n_menor, 1)
end

function analyze_temporal_evolution(file, e_val)
    """Analiza evolución temporal de R(t) para detectar equilibración"""
    h5open(file, "r") do f
        phi = read(f["trajectories"]["phi"])
        time = read(f["trajectories"]["time"])

        N_particles, N_frames = size(phi)

        # Calcular R(t) cada 10 frames
        step = max(1, div(N_frames, 50))  # ~50 puntos en el tiempo
        R_t = Float64[]
        t_samples = Float64[]

        for i in 1:step:N_frames
            R = clustering_ratio(phi[:, i])
            push!(R_t, R)
            push!(t_samples, time[i])
        end

        # Verificar si alcanzó estado estacionario
        # Comparar primera mitad vs segunda mitad
        mid = div(length(R_t), 2)
        R_first_half = mean(R_t[1:mid])
        R_second_half = mean(R_t[mid+1:end])
        R_final = R_t[end]

        # Calcular tendencia (drift)
        last_quarter = R_t[div(3*length(R_t), 4):end]
        drift = std(last_quarter) / mean(last_quarter)  # Coef. variación

        return (
            R_final = R_final,
            R_mean = mean(R_t),
            R_std = std(R_t),
            R_first_half = R_first_half,
            R_second_half = R_second_half,
            drift = drift,
            equilibrated = abs(R_second_half - R_first_half) < 0.5,
            t_max = time[end],
            R_trajectory = R_t,
            time_samples = t_samples
        )
    end
end

function count_clusters(phi_positions, cluster_threshold=π/6)
    """
    Cuenta número de clusters usando densidad angular.
    Un cluster es una región de alta densidad (>threshold).
    """
    # Discretizar en bins angulares
    n_bins = 24  # 15° por bin
    bins = range(0, 2π, length=n_bins+1)

    # Histograma de posiciones
    hist_counts = zeros(Int, n_bins)
    for φ in phi_positions
        bin_idx = min(searchsortedfirst(bins, φ), n_bins)
        hist_counts[bin_idx] += 1
    end

    # Threshold: bin con más de N/n_bins * factor partículas
    N = length(phi_positions)
    threshold_count = (N / n_bins) * 1.5  # 50% más que uniforme

    # Contar regiones contiguas sobre threshold
    in_cluster = hist_counts .> threshold_count

    # Contar transiciones (clusters separados)
    n_clusters = 0
    prev_state = false
    for state in in_cluster
        if state && !prev_state
            n_clusters += 1
        end
        prev_state = state
    end

    # Wrap-around: verificar si primero y último bin están en cluster
    if in_cluster[1] && in_cluster[end]
        n_clusters = max(1, n_clusters - 1)  # Son el mismo cluster
    end

    return n_clusters, hist_counts
end

# ==================== ANÁLISIS POR ECCENTRICIDAD ====================

eccentricities = [0.0, 0.3, 0.5, 0.7, 0.8, 0.9]

for e_val in eccentricities
    println("\n" * "="^70)
    println("ECCENTRICIDAD: e = $e_val")
    println("="^70)

    # Buscar archivos para esta eccentricidad (formato: e0.000, e0.300, etc.)
    e_str = @sprintf("e%.3f", e_val)
    files = filter(readdir(campaign_dir, join=true)) do f
        endswith(f, ".h5") && occursin("_$(e_str)_", f)
    end

    if isempty(files)
        println("  ⚠️  No hay archivos para e=$e_val")
        continue
    end

    println("\nRuns encontrados: $(length(files))")

    # Analizar cada run
    results = []
    for (i, file) in enumerate(files)
        try
            result = analyze_temporal_evolution(file, e_val)
            push!(results, result)
        catch err
            @warn "Error en $(basename(file)): $err"
        end
    end

    if isempty(results)
        println("  ⚠️  No se pudo analizar ningún run")
        continue
    end

    # Estadísticas de equilibración
    n_equilibrated = count(r -> r.equilibrated, results)
    println("\n📊 EQUILIBRACIÓN:")
    @printf("  Runs equilibrados: %d/%d (%.1f%%)\n",
            n_equilibrated, length(results), 100*n_equilibrated/length(results))

    # Comparar primera vs segunda mitad
    first_halves = [r.R_first_half for r in results]
    second_halves = [r.R_second_half for r in results]

    @printf("  R (primera mitad):  %.2f ± %.2f\n", mean(first_halves), std(first_halves))
    @printf("  R (segunda mitad):  %.2f ± %.2f\n", mean(second_halves), std(second_halves))
    @printf("  Drift promedio:     %.2f%% (coef. variación)\n", 100*mean(r.drift for r in results))

    # Detectar bimodalidad en R_final
    R_finals = [r.R_final for r in results]
    @printf("\n📈 DISTRIBUCIÓN DE R_final:\n")
    @printf("  Media:    %.2f ± %.2f\n", mean(R_finals), std(R_finals))
    @printf("  Min/Max:  %.2f / %.2f\n", minimum(R_finals), maximum(R_finals))
    @printf("  Rango:    %.2f\n", maximum(R_finals) - minimum(R_finals))

    # Simple test de bimodalidad: ¿hay gap en la distribución?
    sorted_R = sort(R_finals)
    max_gap = 0.0
    gap_position = 0
    for i in 1:length(sorted_R)-1
        gap = sorted_R[i+1] - sorted_R[i]
        if gap > max_gap
            max_gap = gap
            gap_position = i
        end
    end

    if max_gap > 0.5  # Gap significativo
        println("  ⚠️  POSIBLE BIMODALIDAD detectada:")
        @printf("    Gap máximo: %.2f entre R=%.2f y R=%.2f\n",
                max_gap, sorted_R[gap_position], sorted_R[gap_position+1])

        # Contar en cada modo
        threshold = (sorted_R[gap_position] + sorted_R[gap_position+1]) / 2
        n_low = count(R_finals .< threshold)
        n_high = count(R_finals .>= threshold)
        @printf("    Modo bajo (R<%.2f):  %d runs (%.1f%%)\n",
                threshold, n_low, 100*n_low/length(R_finals))
        @printf("    Modo alto (R≥%.2f):  %d runs (%.1f%%)\n",
                threshold, n_high, 100*n_high/length(R_finals))
    else
        println("  ✓ Distribución unimodal (no bimodal)")
    end

    # Analizar número de clusters en estado final
    println("\n🔍 NÚMERO DE CLUSTERS (estado final):")

    n_clusters_all = []
    for file in files[1:min(5, length(files))]  # Analizar primeros 5
        try
            h5open(file, "r") do f
                phi_final = read(f["trajectories"]["phi"])[:, end]
                n_clust, _ = count_clusters(phi_final)
                push!(n_clusters_all, n_clust)
            end
        catch
        end
    end

    if !isempty(n_clusters_all)
        @printf("  Número de clusters (muestra de %d runs):\n", length(n_clusters_all))
        for (i, nc) in enumerate(n_clusters_all)
            @printf("    Run %d: %d cluster(s)\n", i, nc)
        end
        @printf("  Promedio: %.1f clusters\n", mean(n_clusters_all))
    end
end

# ==================== RECOMENDACIONES ====================

println("\n" * "="^70)
println("RECOMENDACIONES")
println("="^70)
println()

println("📋 Basado en el análisis:")
println()
println("1. TIEMPO DE SIMULACIÓN:")
println("   Si drift > 10% en segunda mitad → necesita más tiempo")
println("   Recomendación: Probar t_max = 500s o 1000s para e ≥ 0.7")
println()
println("2. ESTADÍSTICA:")
println("   Si hay bimodalidad → coexistencia de fases")
println("   Recomendación: 50-100 realizaciones para caracterizar distribución")
println()
println("3. CLUSTERS:")
println("   Si múltiples clusters pequeños → no hay coalescencia completa")
println("   Recomendación: Analizar evolución de tamaño de clusters vs tiempo")
println()
println("4. PRÓXIMO EXPERIMENTO:")
println("   - e = 0.9, N = 80, t_max = 1000s, 50 realizaciones")
println("   - Guardar snapshots cada 10s para análisis temporal")
println("   - Analizar tiempo de coalescencia de clusters")
println()
println("="^70)
