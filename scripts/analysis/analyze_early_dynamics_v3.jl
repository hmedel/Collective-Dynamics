"""
Dinámica temprana - ¿Qué pasa en los primeros instantes?
"""

using Statistics
using Printf
using HDF5

campaign_dir = "results/intrinsic_v3_campaign_20251126_110434"

function curvature(φ, a, b)
    return a * b / (a^2 * sin(φ)^2 + b^2 * cos(φ)^2)^(3/2)
end

function analyze_snapshot(φ, a, b)
    N = length(φ)
    κ_mid = (curvature(0, a, b) + curvature(π/2, a, b)) / 2
    
    n_high = 0
    n_low = 0
    
    for angle in φ
        ang = mod(angle, 2π)
        κ = curvature(ang, a, b)
        if κ > κ_mid
            n_high += 1
        else
            n_low += 1
        end
    end
    
    return (n_high=n_high, n_low=n_low, ratio=n_high/max(n_low,1))
end

println("="^70)
println("DINÁMICA EN LOS PRIMEROS INSTANTES")
println("="^70)
println()

for e in [0.5, 0.9]
    a = 2.0
    b = a * sqrt(1 - e^2)
    N = 50
    
    println("--- e = $e, N = $N ---")
    println()
    
    e_str = @sprintf("%.2f", e)
    N_str = @sprintf("%03d", N)
    
    @printf("%-8s %-12s %-12s %-10s\n", "t", "N(alta κ)", "N(baja κ)", "ratio")
    println("-"^45)
    
    # Promediar sobre seeds
    all_ratios = []
    all_n_high = []
    all_n_low = []
    
    for seed in 1:10
        seed_str = @sprintf("%02d", seed)
        dir = joinpath(campaign_dir, "e$(e_str)_N$(N_str)_seed$(seed_str)")
        h5_file = joinpath(dir, "trajectories.h5")
        
        isfile(h5_file) || continue
        
        h5open(h5_file, "r") do f
            times = read(f["trajectories/time"])
            φ_all = read(f["trajectories/phi"])
            
            ratios = Float64[]
            n_highs = Float64[]
            n_lows = Float64[]
            
            for i in 1:size(φ_all, 1)
                stats = analyze_snapshot(φ_all[i, :], a, b)
                push!(ratios, stats.ratio)
                push!(n_highs, stats.n_high)
                push!(n_lows, stats.n_low)
            end
            
            push!(all_ratios, ratios)
            push!(all_n_high, n_highs)
            push!(all_n_low, n_lows)
        end
    end
    
    if length(all_ratios) > 0
        n_times = minimum(length.(all_ratios))
        
        # Mostrar primeros 20 snapshots y luego algunos más
        indices = collect(1:20)
        append!(indices, [40, 60, 80, 100, 150, n_times])
        filter!(i -> i <= n_times, indices)
        indices = unique(indices)
        
        for idx in indices
            avg_ratio = mean([r[idx] for r in all_ratios])
            avg_high = mean([h[idx] for h in all_n_high])
            avg_low = mean([l[idx] for l in all_n_low])
            t = (idx - 1) * 0.5  # dt = 0.5
            
            @printf("%-8.1f %-12.1f %-12.1f %-10.2f\n", t, avg_high, avg_low, avg_ratio)
        end
    end
    println()
end

println("="^70)
println("CONDICIONES INICIALES: ¿De dónde parten?")
println("="^70)
println()

# Ver la distribución inicial
for e in [0.9]
    a = 2.0
    b = a * sqrt(1 - e^2)
    N = 50
    
    println("e = $e, N = $N - Distribución inicial (t=0):")
    println()
    
    e_str = @sprintf("%.2f", e)
    N_str = @sprintf("%03d", N)
    seed_str = "01"
    
    dir = joinpath(campaign_dir, "e$(e_str)_N$(N_str)_seed$(seed_str)")
    h5_file = joinpath(dir, "trajectories.h5")
    
    if isfile(h5_file)
        h5open(h5_file, "r") do f
            φ_all = read(f["trajectories/phi"])
            
            # t=0
            φ_init = φ_all[1, :]
            
            println("Posiciones iniciales (φ):")
            φ_sorted = sort(mod.(φ_init, 2π))
            
            n_bins = 8
            counts = zeros(Int, n_bins)
            for angle in φ_init
                bin = min(n_bins, floor(Int, mod(angle, 2π) / (2π) * n_bins) + 1)
                counts[bin] += 1
            end
            
            κ_mid = (curvature(0, a, b) + curvature(π/2, a, b)) / 2
            
            for i in 1:n_bins
                φ_center = (i - 0.5) * 2π / n_bins
                κ = curvature(φ_center, a, b)
                region = κ > κ_mid ? "ALTA κ" : "BAJA κ"
                bar = repeat("█", counts[i])
                @printf("  φ=%.2f (%s): %2d  %s\n", φ_center, region, counts[i], bar)
            end
            
            println()
            
            # Comparar con t=10
            φ_t10 = φ_all[21, :]  # t ≈ 10
            
            println("Posiciones en t≈10:")
            counts_t10 = zeros(Int, n_bins)
            for angle in φ_t10
                bin = min(n_bins, floor(Int, mod(angle, 2π) / (2π) * n_bins) + 1)
                counts_t10[bin] += 1
            end
            
            for i in 1:n_bins
                φ_center = (i - 0.5) * 2π / n_bins
                κ = curvature(φ_center, a, b)
                region = κ > κ_mid ? "ALTA κ" : "BAJA κ"
                bar = repeat("█", counts_t10[i])
                @printf("  φ=%.2f (%s): %2d  %s\n", φ_center, region, counts_t10[i], bar)
            end
        end
    end
end

println()
println("="^70)
println("EVOLUCIÓN DEL RATIO N(alta)/N(baja) - DETALLE FINO")
println("="^70)
println()

# Gráfico ASCII de evolución del ratio
for e in [0.9]
    a = 2.0
    b = a * sqrt(1 - e^2)
    N = 50
    
    e_str = @sprintf("%.2f", e)
    N_str = @sprintf("%03d", N)
    
    all_ratios = []
    
    for seed in 1:10
        seed_str = @sprintf("%02d", seed)
        dir = joinpath(campaign_dir, "e$(e_str)_N$(N_str)_seed$(seed_str)")
        h5_file = joinpath(dir, "trajectories.h5")
        
        isfile(h5_file) || continue
        
        h5open(h5_file, "r") do f
            φ_all = read(f["trajectories/phi"])
            
            ratios = Float64[]
            for i in 1:size(φ_all, 1)
                stats = analyze_snapshot(φ_all[i, :], a, b)
                push!(ratios, stats.ratio)
            end
            push!(all_ratios, ratios)
        end
    end
    
    if length(all_ratios) > 0
        n_times = minimum(length.(all_ratios))
        avg_ratio = [mean([r[i] for r in all_ratios]) for i in 1:n_times]
        std_ratio = [std([r[i] for r in all_ratios]) for i in 1:n_times]
        
        println("e = $e: Ratio N(alta κ)/N(baja κ) vs tiempo")
        println()
        println("ratio  |  tiempo")
        println("-"^40)
        
        max_ratio = maximum(avg_ratio[1:min(50, n_times)])
        
        for i in 1:min(100, n_times)
            t = (i-1) * 0.5
            r = avg_ratio[i]
            
            if i <= 20 || mod(i, 20) == 0
                bar_len = round(Int, r / max_ratio * 30)
                bar = repeat("█", bar_len)
                @printf("%5.2f  |  t=%5.1f  %s\n", r, t, bar)
            end
        end
        
        println()
        @printf("Ratio inicial: %.2f\n", avg_ratio[1])
        @printf("Ratio en t=10: %.2f\n", avg_ratio[min(21, n_times)])
        @printf("Ratio final:   %.2f\n", avg_ratio[end])
        @printf("Ratio equilibrio (t>50): %.2f ± %.2f\n", 
                mean(avg_ratio[100:end]), std(avg_ratio[100:end]))
    end
end

println()
println("="^70)
