"""
Análisis de estacionariedad - ¿El sistema llega a equilibrio?

Métricas:
1. Autocorrelación temporal de las métricas de clustering
2. Varianza en ventanas temporales
3. Drift en el tiempo
"""

using Statistics
using Printf
using HDF5

campaign_dir = "results/intrinsic_v3_campaign_20251126_110434"

println("="^70)
println("ANÁLISIS DE ESTACIONARIEDAD")
println("="^70)
println()

function clustering_metric(φ; n_bins=20)
    N = length(φ)
    counts = zeros(Int, n_bins)
    for angle in φ
        bin = min(n_bins, floor(Int, mod(angle, 2π) / (2π) * n_bins) + 1)
        counts[bin] += 1
    end
    expected = N / n_bins
    return sqrt(var(counts)) / expected
end

function analyze_stationarity(times, metric_series)
    n = length(times)
    
    # Dividir en 4 cuartos
    q1 = metric_series[1:n÷4]
    q2 = metric_series[n÷4+1:n÷2]
    q3 = metric_series[n÷2+1:3n÷4]
    q4 = metric_series[3n÷4+1:end]
    
    means = [mean(q1), mean(q2), mean(q3), mean(q4)]
    stds = [std(q1), std(q2), std(q3), std(q4)]
    
    # Test de drift: comparar primera y última mitad
    first_half = metric_series[1:n÷2]
    second_half = metric_series[n÷2+1:end]
    
    drift = mean(second_half) - mean(first_half)
    relative_drift = drift / mean(metric_series)
    
    # Varianza total vs varianza intra-cuartos
    total_var = var(metric_series)
    intra_var = mean([var(q1), var(q2), var(q3), var(q4)])
    
    # Si intra_var ≈ total_var, el sistema fluctúa alrededor de un valor estable
    variance_ratio = intra_var / total_var
    
    return (means=means, stds=stds, drift=drift, 
            rel_drift=relative_drift, var_ratio=variance_ratio)
end

println("EVOLUCIÓN POR CUARTOS DE TIEMPO")
println("(Si hay estado estacionario, los promedios deben ser similares)")
println()

for e in [0.5, 0.9]
    for N in [30, 50]
        e_str = @sprintf("%.2f", e)
        N_str = @sprintf("%03d", N)
        
        # Promediar sobre seeds
        all_metrics = []
        
        for seed in 1:10
            seed_str = @sprintf("%02d", seed)
            dir = joinpath(campaign_dir, "e$(e_str)_N$(N_str)_seed$(seed_str)")
            h5_file = joinpath(dir, "trajectories.h5")
            
            isfile(h5_file) || continue
            
            h5open(h5_file, "r") do f
                times = read(f["trajectories/time"])
                φ_all = read(f["trajectories/phi"])
                
                metrics = [clustering_metric(φ_all[i, :]) for i in 1:size(φ_all, 1)]
                push!(all_metrics, metrics)
            end
        end
        
        if length(all_metrics) > 0
            # Promediar métricas sobre seeds
            n_times = minimum(length.(all_metrics))
            avg_metric = zeros(n_times)
            for m in all_metrics
                avg_metric .+= m[1:n_times]
            end
            avg_metric ./= length(all_metrics)
            
            times = range(0, 100, length=n_times)
            stat = analyze_stationarity(collect(times), avg_metric)
            
            println("--- e = $e, N = $N ($(length(all_metrics)) seeds) ---")
            @printf("  Cuartos: Q1=%.3f, Q2=%.3f, Q3=%.3f, Q4=%.3f\n", 
                    stat.means...)
            @printf("  Drift relativo: %.1f%%\n", stat.rel_drift * 100)
            @printf("  Ratio varianza (intra/total): %.2f\n", stat.var_ratio)
            
            if abs(stat.rel_drift) < 0.1 && stat.var_ratio > 0.7
                println("  → ESTADO ESTACIONARIO (fluctuaciones alrededor de media)")
            elseif stat.rel_drift > 0.2
                println("  → TENDENCIA CRECIENTE")
            elseif stat.rel_drift < -0.2
                println("  → TENDENCIA DECRECIENTE")
            else
                println("  → POSIBLEMENTE TRANSITORIO")
            end
            println()
        end
    end
end

println("="^70)
println("SERIES TEMPORALES DETALLADAS")
println("="^70)
println()

# Mostrar series completas para casos extremos
for (e, N) in [(0.5, 50), (0.9, 50)]
    e_str = @sprintf("%.2f", e)
    N_str = @sprintf("%03d", N)
    
    dir = joinpath(campaign_dir, "e$(e_str)_N$(N_str)_seed01")
    h5_file = joinpath(dir, "trajectories.h5")
    
    isfile(h5_file) || continue
    
    println("Serie temporal: e=$e, N=$N, seed=1")
    println()
    
    h5open(h5_file, "r") do f
        times = read(f["trajectories/time"])
        φ_all = read(f["trajectories/phi"])
        
        metrics = [clustering_metric(φ_all[i, :]) for i in 1:size(φ_all, 1)]
        
        # Mostrar gráfico ASCII
        n_points = 50
        step = max(1, length(times) ÷ n_points)
        
        min_m, max_m = extrema(metrics)
        range_m = max_m - min_m
        
        println("CV_densidad vs tiempo:")
        println("  t=0" * " "^20 * "t=50" * " "^20 * "t=100")
        println("  |" * "-"^48 * "|")
        
        # Crear línea del gráfico
        n_cols = 50
        height = 10
        grid = fill(' ', height, n_cols)
        
        for (i, m) in enumerate(metrics[1:step:end])
            col = min(n_cols, ceil(Int, i / length(metrics[1:step:end]) * n_cols))
            row = height - floor(Int, (m - min_m) / range_m * (height-1))
            row = clamp(row, 1, height)
            grid[row, col] = '█'
        end
        
        for row in 1:height
            if row == 1
                @printf("%.2f |", max_m)
            elseif row == height
                @printf("%.2f |", min_m)
            else
                print("     |")
            end
            println(String(grid[row, :]))
        end
        
        println()
        @printf("  Media: %.3f, Std: %.3f\n", mean(metrics), std(metrics))
        println()
    end
end

println("="^70)
println("TIEMPO DE RELAJACIÓN ESTIMADO")
println("="^70)
println()

# Calcular autocorrelación para estimar tiempo de relajación
println("Autocorrelación temporal del clustering:")
println()

for (e, N) in [(0.5, 50), (0.9, 50)]
    e_str = @sprintf("%.2f", e)
    N_str = @sprintf("%03d", N)
    
    dir = joinpath(campaign_dir, "e$(e_str)_N$(N_str)_seed01")
    h5_file = joinpath(dir, "trajectories.h5")
    
    isfile(h5_file) || continue
    
    h5open(h5_file, "r") do f
        times = read(f["trajectories/time"])
        φ_all = read(f["trajectories/phi"])
        dt = times[2] - times[1]
        
        metrics = [clustering_metric(φ_all[i, :]) for i in 1:size(φ_all, 1)]
        m_centered = metrics .- mean(metrics)
        
        # Autocorrelación para diferentes lags
        max_lag = min(50, length(metrics)÷4)
        autocorr = zeros(max_lag)
        
        for lag in 1:max_lag
            c = sum(m_centered[1:end-lag] .* m_centered[lag+1:end])
            c /= sum(m_centered.^2)
            autocorr[lag] = c
        end
        
        # Encontrar tiempo donde autocorr < 1/e
        τ_idx = findfirst(x -> x < 1/ℯ, autocorr)
        τ = τ_idx !== nothing ? τ_idx * dt : NaN
        
        println("e=$e, N=$N:")
        @printf("  Autocorr(Δt=%.1f) = %.3f\n", dt, autocorr[1])
        @printf("  Autocorr(Δt=%.1f) = %.3f\n", 5*dt, autocorr[min(5, max_lag)])
        @printf("  Autocorr(Δt=%.1f) = %.3f\n", 10*dt, autocorr[min(10, max_lag)])
        if !isnan(τ)
            @printf("  Tiempo de correlación τ ≈ %.1f\n", τ)
        else
            println("  Tiempo de correlación τ > $(max_lag * dt)")
        end
        println()
    end
end

println("="^70)
