"""
Análisis de ubicación de clusters - ¿Se forman en alta curvatura?

Preguntas:
1. ¿Los clusters se forman preferentemente en regiones de alta κ?
2. ¿Los clusters son más compactos (partículas más "pegadas") en alta κ?
3. ¿Hay más clusters pequeños en baja κ vs clusters grandes en alta κ?
"""

using Statistics
using Printf
using HDF5

campaign_dir = "results/intrinsic_v3_campaign_20251126_110434"

println("="^70)
println("UBICACIÓN Y ESTRUCTURA DE CLUSTERS")
println("="^70)
println()

function curvature(φ, a, b)
    return a * b / (a^2 * sin(φ)^2 + b^2 * cos(φ)^2)^(3/2)
end

# Detectar clusters y su ubicación
function detect_clusters_with_location(φ, a, b; threshold_factor=2.0)
    N = length(φ)
    φ_sorted_idx = sortperm(mod.(φ, 2π))
    φ_sorted = mod.(φ[φ_sorted_idx], 2π)
    
    mean_sep = 2π / N
    threshold = threshold_factor * mean_sep
    
    # Separaciones
    seps = diff(φ_sorted)
    push!(seps, 2π - φ_sorted[end] + φ_sorted[1])
    
    # Encontrar gaps (fronteras de clusters)
    gaps = findall(s -> s > threshold, seps)
    
    if length(gaps) == 0
        # Un solo cluster
        center = mean(φ_sorted)
        κ_center = curvature(center, a, b)
        compactness = std(φ_sorted)
        return [(size=N, center=center, κ=κ_center, compactness=compactness)]
    end
    
    clusters = []
    
    for i in 1:length(gaps)
        # Índices del cluster
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
        
        # Manejar wrap-around
        if start_idx <= end_idx
            cluster_φ = φ_sorted[start_idx:end_idx]
        else
            cluster_φ = vcat(φ_sorted[start_idx:end], φ_sorted[1:end_idx])
        end
        
        if length(cluster_φ) > 0
            # Centro del cluster (promedio circular)
            center = atan(mean(sin.(cluster_φ)), mean(cos.(cluster_φ)))
            if center < 0
                center += 2π
            end
            
            κ_center = curvature(center, a, b)
            
            # Compactness: separación media dentro del cluster
            if length(cluster_φ) > 1
                internal_seps = diff(sort(cluster_φ))
                compactness = mean(internal_seps)
            else
                compactness = 0.0
            end
            
            push!(clusters, (size=length(cluster_φ), center=center, 
                           κ=κ_center, compactness=compactness))
        end
    end
    
    return clusters
end

println("CLUSTERS POR REGIÓN DE CURVATURA")
println()

for e in [0.5, 0.7, 0.8, 0.9]
    a = 2.0
    b = a * sqrt(1 - e^2)
    κ_max = curvature(0, a, b)
    κ_min = curvature(π/2, a, b)
    κ_mid = (κ_max + κ_min) / 2
    
    println("="^60)
    @printf("e = %.1f (κ_max=%.2f, κ_min=%.2f)\n", e, κ_max, κ_min)
    println("="^60)
    
    for N in [30, 50]
        clusters_high_κ = []  # κ > κ_mid
        clusters_low_κ = []   # κ < κ_mid
        
        all_clusters = []
        
        for seed in 1:10
            e_str = @sprintf("%.2f", e)
            N_str = @sprintf("%03d", N)
            seed_str = @sprintf("%02d", seed)
            
            dir = joinpath(campaign_dir, "e$(e_str)_N$(N_str)_seed$(seed_str)")
            h5_file = joinpath(dir, "trajectories.h5")
            
            isfile(h5_file) || continue
            
            h5open(h5_file, "r") do f
                φ = read(f["trajectories/phi"])[end, :]
                
                clusters = detect_clusters_with_location(φ, a, b)
                append!(all_clusters, clusters)
                
                for cl in clusters
                    if cl.κ > κ_mid
                        push!(clusters_high_κ, cl)
                    else
                        push!(clusters_low_κ, cl)
                    end
                end
            end
        end
        
        println()
        println("N = $N:")
        println("-"^50)
        
        if length(clusters_high_κ) > 0 && length(clusters_low_κ) > 0
            # Estadísticas
            n_high = length(clusters_high_κ)
            n_low = length(clusters_low_κ)
            
            size_high = mean([c.size for c in clusters_high_κ])
            size_low = mean([c.size for c in clusters_low_κ])
            
            compact_high = mean([c.compactness for c in clusters_high_κ if c.compactness > 0])
            compact_low = mean([c.compactness for c in clusters_low_κ if c.compactness > 0])
            
            @printf("  Clusters en ALTA κ: %d (%.0f%%)\n", n_high, 100*n_high/(n_high+n_low))
            @printf("  Clusters en BAJA κ: %d (%.0f%%)\n", n_low, 100*n_low/(n_high+n_low))
            println()
            @printf("  Tamaño medio (ALTA κ): %.1f partículas\n", size_high)
            @printf("  Tamaño medio (BAJA κ): %.1f partículas\n", size_low)
            @printf("  → Ratio tamaño: %.2f\n", size_high/size_low)
            println()
            if !isnan(compact_high) && !isnan(compact_low) && compact_low > 0
                @printf("  Separación interna (ALTA κ): %.4f rad\n", compact_high)
                @printf("  Separación interna (BAJA κ): %.4f rad\n", compact_low)
                @printf("  → Clusters más compactos en: %s\n", 
                        compact_high < compact_low ? "ALTA κ" : "BAJA κ")
            end
        end
    end
    println()
end

println("="^70)
println("DISTRIBUCIÓN DE TAMAÑOS POR REGIÓN")
println("="^70)
println()

# Para e=0.9, mostrar histograma de tamaños por región
e = 0.9
a = 2.0
b = a * sqrt(1 - e^2)
κ_max = curvature(0, a, b)
κ_min = curvature(π/2, a, b)
κ_mid = (κ_max + κ_min) / 2

println("e = $e, N = 50:")
println()

sizes_high = Int[]
sizes_low = Int[]

for seed in 1:10
    e_str = "0.90"
    N_str = "050"
    seed_str = @sprintf("%02d", seed)
    
    dir = joinpath(campaign_dir, "e$(e_str)_N$(N_str)_seed$(seed_str)")
    h5_file = joinpath(dir, "trajectories.h5")
    
    isfile(h5_file) || continue
    
    h5open(h5_file, "r") do f
        φ = read(f["trajectories/phi"])[end, :]
        clusters = detect_clusters_with_location(φ, a, b)
        
        for cl in clusters
            if cl.κ > κ_mid
                push!(sizes_high, cl.size)
            else
                push!(sizes_low, cl.size)
            end
        end
    end
end

println("Distribución de tamaños de cluster:")
println()
println("ALTA curvatura (φ ≈ 0, π):")
if length(sizes_high) > 0
    for s in sort(unique(sizes_high))
        count = sum(sizes_high .== s)
        bar = repeat("█", count)
        @printf("  size=%2d: %d  %s\n", s, count, bar)
    end
end

println()
println("BAJA curvatura (φ ≈ π/2, 3π/2):")
if length(sizes_low) > 0
    for s in sort(unique(sizes_low))
        count = sum(sizes_low .== s)
        bar = repeat("█", count)
        @printf("  size=%2d: %d  %s\n", s, count, bar)
    end
end

println()
println("="^70)
println("RESUMEN: CARACTERÍSTICAS DE CLUSTERS POR REGIÓN")
println("="^70)
println()

println("                    ALTA κ          BAJA κ")
println("                    (φ≈0,π)         (φ≈π/2,3π/2)")
println("-"^55)
if length(sizes_high) > 0 && length(sizes_low) > 0
    @printf("Número de clusters: %-15d %d\n", length(sizes_high), length(sizes_low))
    @printf("Tamaño medio:       %-15.1f %.1f\n", mean(sizes_high), mean(sizes_low))
    @printf("Tamaño máximo:      %-15d %d\n", maximum(sizes_high), maximum(sizes_low))
    @printf("Partículas totales: %-15d %d\n", sum(sizes_high), sum(sizes_low))
end

println()
println("="^70)
