"""
Análisis de dinámica de clustering - Campaña v3

Preguntas clave:
1. ¿Se forman clusters? ¿Cuántos? ¿De qué tamaño?
2. ¿El sistema llega a estado estacionario?
3. ¿Hay transición de fase con e o N?
"""

using Statistics
using Printf
using HDF5

campaign_dir = "results/intrinsic_v3_campaign_20251126_110434"

println("="^70)
println("ANÁLISIS DE DINÁMICA DE CLUSTERING")
println("="^70)
println()

# Función para detectar clusters basado en separación angular
function detect_clusters(φ; threshold_factor=2.0)
    N = length(φ)
    φ_sorted = sort(mod.(φ, 2π))
    
    # Separaciones entre partículas vecinas
    seps = diff(φ_sorted)
    push!(seps, 2π - φ_sorted[end] + φ_sorted[1])  # wrap
    
    mean_sep = 2π / N  # separación esperada si uniforme
    threshold = threshold_factor * mean_sep
    
    # Identificar gaps (separaciones grandes = fronteras de clusters)
    gaps = findall(s -> s > threshold, seps)
    n_clusters = length(gaps)
    
    if n_clusters == 0
        # Todo es un cluster o distribución uniforme
        return (n_clusters=1, sizes=[N], max_size=N, mean_size=Float64(N))
    end
    
    # Calcular tamaños de clusters
    sizes = Int[]
    if length(gaps) == 1
        push!(sizes, N)
    else
        for i in 1:length(gaps)
            if i == 1
                # Desde el último gap hasta el primero (wrapping)
                size = gaps[1] + (N - gaps[end])
            else
                size = gaps[i] - gaps[i-1]
            end
            push!(sizes, size)
        end
    end
    
    return (n_clusters=n_clusters, sizes=sizes, 
            max_size=maximum(sizes), mean_size=mean(sizes))
end

# Función alternativa: usar varianza de densidad local
function clustering_metric(φ; n_bins=20)
    N = length(φ)
    counts = zeros(Int, n_bins)
    
    for angle in φ
        bin = min(n_bins, floor(Int, mod(angle, 2π) / (2π) * n_bins) + 1)
        counts[bin] += 1
    end
    
    # Varianza normalizada (0 = uniforme, alto = clustered)
    expected = N / n_bins
    variance = var(counts)
    
    # Métrica: coeficiente de variación de la densidad
    CV = sqrt(variance) / expected
    
    return CV
end

println("="^70)
println("EVOLUCIÓN TEMPORAL DEL CLUSTERING")
println("="^70)
println()

# Para cada condición, mostrar evolución temporal
for e in [0.5, 0.7, 0.8, 0.9]
    for N in [30, 50]
        e_str = @sprintf("%.2f", e)
        N_str = @sprintf("%03d", N)
        
        dir = joinpath(campaign_dir, "e$(e_str)_N$(N_str)_seed01")
        h5_file = joinpath(dir, "trajectories.h5")
        
        isfile(h5_file) || continue
        
        println("--- e = $e, N = $N ---")
        
        h5open(h5_file, "r") do f
            times = read(f["trajectories/time"])
            φ_all = read(f["trajectories/phi"])
            
            @printf("%-8s %-10s %-10s %-10s %-10s\n",
                    "t", "n_clust", "max_size", "CV_dens", "max/N")
            println("-"^50)
            
            # Mostrar cada 40 snapshots + inicio y final
            indices = unique([1, 40, 80, 120, 160, 200])
            filter!(i -> i <= size(φ_all, 1), indices)
            
            for i in indices
                φ = φ_all[i, :]
                
                cl = detect_clusters(φ)
                cv = clustering_metric(φ)
                
                @printf("%-8.1f %-10d %-10d %-10.3f %-10.2f\n",
                        times[i], cl.n_clusters, cl.max_size, cv, cl.max_size/N)
            end
        end
        println()
    end
end

println("="^70)
println("ESTADO FINAL: MÉTRICAS DE CLUSTERING vs (e, N)")
println("="^70)
println()

# Promediar sobre seeds para cada (e, N)
println("Promedio sobre 10 seeds (snapshot final, t≈100):")
println()
@printf("%-6s %-4s %-8s %-12s %-12s %-12s %-12s\n",
        "e", "N", "seeds", "⟨n_clust⟩", "⟨max_size⟩", "⟨CV_dens⟩", "⟨max/N⟩")
println("-"^75)

results_table = []

for e in [0.5, 0.7, 0.8, 0.9]
    for N in [30, 40, 50, 60]
        n_clusters_list = Float64[]
        max_sizes = Float64[]
        cvs = Float64[]
        
        for seed in 1:10
            e_str = @sprintf("%.2f", e)
            N_str = @sprintf("%03d", N)
            seed_str = @sprintf("%02d", seed)
            
            dir = joinpath(campaign_dir, "e$(e_str)_N$(N_str)_seed$(seed_str)")
            h5_file = joinpath(dir, "trajectories.h5")
            
            isfile(h5_file) || continue
            
            h5open(h5_file, "r") do f
                φ = read(f["trajectories/phi"])[end, :]
                
                cl = detect_clusters(φ)
                cv = clustering_metric(φ)
                
                push!(n_clusters_list, cl.n_clusters)
                push!(max_sizes, cl.max_size)
                push!(cvs, cv)
            end
        end
        
        if length(n_clusters_list) > 0
            n_seeds = length(n_clusters_list)
            mean_nc = mean(n_clusters_list)
            mean_ms = mean(max_sizes)
            mean_cv = mean(cvs)
            mean_ratio = mean_ms / N
            
            push!(results_table, (e=e, N=N, n_seeds=n_seeds, 
                                  n_clust=mean_nc, max_size=mean_ms, 
                                  cv=mean_cv, ratio=mean_ratio))
            
            @printf("%-6.2f %-4d %-8d %-12.2f %-12.1f %-12.3f %-12.3f\n",
                    e, N, n_seeds, mean_nc, mean_ms, mean_cv, mean_ratio)
        end
    end
end

println()
println("="^70)
println("ANÁLISIS DE TRANSICIÓN DE FASE")
println("="^70)
println()

# Ver si hay un salto en las métricas
println("Parámetro de orden: fracción en cluster más grande (max_size/N)")
println()
println("Si hay transición de fase, esperamos:")
println("  - Fase desordenada: max/N ≈ 1/n_clusters (pequeño)")
println("  - Fase ordenada: max/N → 1 (un cluster dominante)")
println()

println("Tendencia con excentricidad (N=50 fijo):")
println()
for r in results_table
    if r.N == 50
        bar = repeat("█", round(Int, r.ratio * 30))
        @printf("e = %.1f: max/N = %.3f  %s\n", r.e, r.ratio, bar)
    end
end

println()
println("Tendencia con N (e=0.9 fijo):")
println()
for r in results_table
    if r.e == 0.9
        bar = repeat("█", round(Int, r.ratio * 30))
        @printf("N = %2d: max/N = %.3f  %s\n", r.N, r.ratio, bar)
    end
end

println()
println("="^70)
println("DISTRIBUCIÓN DE TAMAÑOS DE CLUSTER")
println("="^70)
println()

# Para e=0.9 mostrar distribución de tamaños
println("e = 0.9, distribución de tamaños de cluster (todos los seeds):")
println()

for N in [30, 50]
    all_sizes = Int[]
    
    for seed in 1:10
        e_str = "0.90"
        N_str = @sprintf("%03d", N)
        seed_str = @sprintf("%02d", seed)
        
        dir = joinpath(campaign_dir, "e$(e_str)_N$(N_str)_seed$(seed_str)")
        h5_file = joinpath(dir, "trajectories.h5")
        
        isfile(h5_file) || continue
        
        h5open(h5_file, "r") do f
            φ = read(f["trajectories/phi"])[end, :]
            cl = detect_clusters(φ)
            append!(all_sizes, cl.sizes)
        end
    end
    
    if length(all_sizes) > 0
        println("N = $N:")
        println("  Total clusters detectados: $(length(all_sizes))")
        println("  Tamaño medio: $(round(mean(all_sizes), digits=1))")
        println("  Tamaño máximo: $(maximum(all_sizes))")
        println("  Tamaño mínimo: $(minimum(all_sizes))")
        
        # Histograma simple
        println("  Distribución:")
        bins = [1, 5, 10, 15, 20, 25, 30, 50, 100]
        for i in 1:length(bins)-1
            count = sum(bins[i] .<= all_sizes .< bins[i+1])
            if count > 0
                bar = repeat("█", count)
                println("    [$(bins[i])-$(bins[i+1])): $count  $bar")
            end
        end
        println()
    end
end

println("="^70)
