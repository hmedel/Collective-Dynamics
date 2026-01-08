"""
Dinámica temporal de clusters - ¿Cómo evolucionan en el tiempo?

Preguntas:
1. ¿Los clusters se forman gradualmente o rápidamente?
2. ¿Son estables o se forman/disuelven constantemente?
3. ¿La asimetría alta-κ/baja-κ crece con el tiempo?
"""

using Statistics
using Printf
using HDF5

campaign_dir = "results/intrinsic_v3_campaign_20251126_110434"

function curvature(φ, a, b)
    return a * b / (a^2 * sin(φ)^2 + b^2 * cos(φ)^2)^(3/2)
end

function detect_clusters_with_location(φ, a, b; threshold_factor=2.0)
    N = length(φ)
    φ_sorted_idx = sortperm(mod.(φ, 2π))
    φ_sorted = mod.(φ[φ_sorted_idx], 2π)
    
    mean_sep = 2π / N
    threshold = threshold_factor * mean_sep
    
    seps = diff(φ_sorted)
    push!(seps, 2π - φ_sorted[end] + φ_sorted[1])
    
    gaps = findall(s -> s > threshold, seps)
    
    κ_mid = (curvature(0, a, b) + curvature(π/2, a, b)) / 2
    
    if length(gaps) == 0
        center = mean(φ_sorted)
        κ_center = curvature(center, a, b)
        is_high_κ = κ_center > κ_mid
        return (n_clusters=1, 
                n_high_κ=is_high_κ ? 1 : 0, 
                n_low_κ=is_high_κ ? 0 : 1,
                max_size_high=is_high_κ ? N : 0,
                max_size_low=is_high_κ ? 0 : N,
                total_high=is_high_κ ? N : 0,
                total_low=is_high_κ ? 0 : N,
                sizes_high=[is_high_κ ? N : 0],
                sizes_low=[is_high_κ ? 0 : N])
    end
    
    sizes_high = Int[]
    sizes_low = Int[]
    
    for i in 1:length(gaps)
        if i == 1
            start_idx = gaps[end] + 1
            end_idx = gaps[1]
            if start_idx > N
                start_idx = 1
            end
        else
            start_idx = gaps[i-1] + 1
            end_idx = gaps[i]
        end
        
        if start_idx <= end_idx
            cluster_φ = φ_sorted[start_idx:end_idx]
        else
            cluster_φ = vcat(φ_sorted[start_idx:end], φ_sorted[1:end_idx])
        end
        
        if length(cluster_φ) > 0
            center = atan(mean(sin.(cluster_φ)), mean(cos.(cluster_φ)))
            if center < 0
                center += 2π
            end
            
            κ_center = curvature(center, a, b)
            
            if κ_center > κ_mid
                push!(sizes_high, length(cluster_φ))
            else
                push!(sizes_low, length(cluster_φ))
            end
        end
    end
    
    return (n_clusters=length(gaps),
            n_high_κ=length(sizes_high),
            n_low_κ=length(sizes_low),
            max_size_high=length(sizes_high) > 0 ? maximum(sizes_high) : 0,
            max_size_low=length(sizes_low) > 0 ? maximum(sizes_low) : 0,
            total_high=sum(sizes_high),
            total_low=sum(sizes_low),
            sizes_high=sizes_high,
            sizes_low=sizes_low)
end

println("="^70)
println("DINÁMICA TEMPORAL DE CLUSTERS")
println("="^70)
println()

# Analizar evolución temporal para diferentes condiciones
for e in [0.5, 0.9]
    a = 2.0
    b = a * sqrt(1 - e^2)
    N = 50
    
    println("="^70)
    @printf("e = %.1f, N = %d\n", e, N)
    println("="^70)
    println()
    
    e_str = @sprintf("%.2f", e)
    N_str = @sprintf("%03d", N)
    
    # Recolectar datos de todos los seeds
    all_time_series = []
    
    for seed in 1:10
        seed_str = @sprintf("%02d", seed)
        dir = joinpath(campaign_dir, "e$(e_str)_N$(N_str)_seed$(seed_str)")
        h5_file = joinpath(dir, "trajectories.h5")
        
        isfile(h5_file) || continue
        
        h5open(h5_file, "r") do f
            times = read(f["trajectories/time"])
            φ_all = read(f["trajectories/phi"])
            
            time_series = []
            for i in 1:size(φ_all, 1)
                φ = φ_all[i, :]
                stats = detect_clusters_with_location(φ, a, b)
                push!(time_series, (t=times[i], stats...))
            end
            push!(all_time_series, time_series)
        end
    end
    
    if length(all_time_series) == 0
        continue
    end
    
    # Mostrar evolución temporal promediada
    n_times = minimum(length.(all_time_series))
    
    println("Evolución temporal (promedio sobre $(length(all_time_series)) seeds):")
    println()
    @printf("%-8s %-10s %-10s %-10s %-12s %-12s %-10s\n",
            "t", "n_clust", "n_high_κ", "n_low_κ", "max_high", "max_low", "ratio_N")
    println("-"^75)
    
    # Mostrar cada ~20 unidades de tiempo
    indices = [1]
    for t_target in [5, 10, 20, 40, 60, 80, 100]
        idx = findfirst(i -> all_time_series[1][i].t >= t_target, 1:n_times)
        if idx !== nothing
            push!(indices, idx)
        end
    end
    push!(indices, n_times)
    indices = unique(indices)
    
    for idx in indices
        # Promediar sobre seeds
        n_clust = mean([ts[idx].n_clusters for ts in all_time_series])
        n_high = mean([ts[idx].n_high_κ for ts in all_time_series])
        n_low = mean([ts[idx].n_low_κ for ts in all_time_series])
        max_high = mean([ts[idx].max_size_high for ts in all_time_series])
        max_low = mean([ts[idx].max_size_low for ts in all_time_series])
        total_high = mean([ts[idx].total_high for ts in all_time_series])
        total_low = mean([ts[idx].total_low for ts in all_time_series])
        
        t = all_time_series[1][idx].t
        ratio = total_high / max(total_low, 1)
        
        @printf("%-8.1f %-10.1f %-10.1f %-10.1f %-12.1f %-12.1f %-10.2f\n",
                t, n_clust, n_high, n_low, max_high, max_low, ratio)
    end
    
    println()
    
    # Gráfico ASCII de evolución
    println("Evolución del tamaño máximo de cluster:")
    println()
    
    max_high_series = [mean([ts[i].max_size_high for ts in all_time_series]) for i in 1:n_times]
    max_low_series = [mean([ts[i].max_size_low for ts in all_time_series]) for i in 1:n_times]
    
    # Subsamplear para gráfico
    n_points = 50
    step = max(1, n_times ÷ n_points)
    
    max_val = max(maximum(max_high_series), maximum(max_low_series))
    
    println("  ALTA κ (█) vs BAJA κ (░)")
    println("  " * "-"^52)
    
    for i in 1:step:n_times
        t = all_time_series[1][i].t
        h = max_high_series[i]
        l = max_low_series[i]
        
        bar_h = round(Int, h / max_val * 25)
        bar_l = round(Int, l / max_val * 25)
        
        if i == 1 || mod(i-1, step*10) == 0 || i >= n_times - step
            @printf("t=%5.1f |%s%s\n", t, repeat("█", bar_h), repeat("░", bar_l))
        end
    end
    
    println()
    println("Leyenda: █ = max cluster en ALTA κ, ░ = max cluster en BAJA κ")
    println()
end

println("="^70)
println("ESTABILIDAD DE CLUSTERS: ¿Se mantienen o fluctúan?")
println("="^70)
println()

# Calcular variabilidad temporal
for e in [0.5, 0.9]
    a = 2.0
    b = a * sqrt(1 - e^2)
    N = 50
    
    e_str = @sprintf("%.2f", e)
    N_str = @sprintf("%03d", N)
    
    println("e = $e, N = $N:")
    
    # Para un seed, ver fluctuaciones
    dir = joinpath(campaign_dir, "e$(e_str)_N$(N_str)_seed01")
    h5_file = joinpath(dir, "trajectories.h5")
    
    if isfile(h5_file)
        h5open(h5_file, "r") do f
            times = read(f["trajectories/time"])
            φ_all = read(f["trajectories/phi"])
            
            n_clusters_series = Int[]
            max_size_series = Int[]
            
            for i in 1:size(φ_all, 1)
                φ = φ_all[i, :]
                stats = detect_clusters_with_location(φ, a, b)
                push!(n_clusters_series, stats.n_clusters)
                push!(max_size_series, max(stats.max_size_high, stats.max_size_low))
            end
            
            # Segunda mitad (estado estacionario)
            n_half = length(n_clusters_series) ÷ 2
            
            @printf("  Número de clusters: media=%.1f, std=%.1f (fluctuación=%.0f%%)\n",
                    mean(n_clusters_series[n_half:end]),
                    std(n_clusters_series[n_half:end]),
                    100*std(n_clusters_series[n_half:end])/mean(n_clusters_series[n_half:end]))
            
            @printf("  Tamaño máximo cluster: media=%.1f, std=%.1f (fluctuación=%.0f%%)\n",
                    mean(max_size_series[n_half:end]),
                    std(max_size_series[n_half:end]),
                    100*std(max_size_series[n_half:end])/mean(max_size_series[n_half:end]))
            
            # Cambios entre snapshots consecutivos
            changes = abs.(diff(n_clusters_series[n_half:end]))
            @printf("  Cambios por snapshot: media=%.2f clusters\n", mean(changes))
        end
    end
    println()
end

println("="^70)
println("TIEMPO DE FORMACIÓN DE LA ASIMETRÍA")
println("="^70)
println()

# ¿Cuánto tarda en establecerse la diferencia alta-κ vs baja-κ?
for e in [0.5, 0.9]
    a = 2.0
    b = a * sqrt(1 - e^2)
    N = 50
    
    e_str = @sprintf("%.2f", e)
    N_str = @sprintf("%03d", N)
    
    ratios_over_time = []
    
    for seed in 1:10
        seed_str = @sprintf("%02d", seed)
        dir = joinpath(campaign_dir, "e$(e_str)_N$(N_str)_seed$(seed_str)")
        h5_file = joinpath(dir, "trajectories.h5")
        
        isfile(h5_file) || continue
        
        h5open(h5_file, "r") do f
            times = read(f["trajectories/time"])
            φ_all = read(f["trajectories/phi"])
            
            ratios = Float64[]
            for i in 1:size(φ_all, 1)
                φ = φ_all[i, :]
                stats = detect_clusters_with_location(φ, a, b)
                ratio = stats.total_high / max(stats.total_low, 1)
                push!(ratios, ratio)
            end
            push!(ratios_over_time, ratios)
        end
    end
    
    if length(ratios_over_time) > 0
        n_times = minimum(length.(ratios_over_time))
        avg_ratio = [mean([r[i] for r in ratios_over_time]) for i in 1:n_times]
        
        # Encontrar tiempo de equilibración (cuando ratio se estabiliza)
        final_ratio = mean(avg_ratio[end-10:end])
        threshold = 0.9 * final_ratio
        
        equil_idx = findfirst(r -> r >= threshold, avg_ratio)
        
        println("e = $e:")
        @printf("  Ratio inicial (t=0): %.2f\n", avg_ratio[1])
        @printf("  Ratio final (t≈100): %.2f\n", final_ratio)
        if equil_idx !== nothing
            t_equil = (equil_idx - 1) * 0.5  # dt = 0.5
            @printf("  Tiempo de equilibración: t ≈ %.1f\n", t_equil)
        end
        println()
    end
end

println("="^70)
