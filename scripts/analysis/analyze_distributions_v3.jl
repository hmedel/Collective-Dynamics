"""
Análisis de distribuciones espaciales y de velocidad - Campaña v3
"""

using Statistics
using Printf
using HDF5

campaign_dir = "results/intrinsic_v3_campaign_20251126_110434"

println("="^70)
println("ANÁLISIS DE DISTRIBUCIONES - CAMPAÑA v3")
println("="^70)
println()

# Función para calcular estadísticas de un snapshot
function analyze_snapshot(φ, φ_dot)
    N = length(φ)
    
    # Estadísticas de posición (uniformidad)
    n_bins = 10
    counts = zeros(Int, n_bins)
    for angle in φ
        bin = min(n_bins, floor(Int, mod(angle, 2π) / (2π) * n_bins) + 1)
        counts[bin] += 1
    end
    expected = N / n_bins
    χ² = sum((counts .- expected).^2 ./ expected)
    
    # Estadísticas de velocidad
    mean_v = mean(φ_dot)
    std_v = std(φ_dot)
    
    # Energía cinética media (proporcional)
    KE = 0.5 * mean(φ_dot.^2)
    
    return (χ²=χ², mean_v=mean_v, std_v=std_v, KE=KE)
end

# Analizar snapshots finales
println("Análisis de snapshots finales (t=100):")
println()
@printf("%-6s %-4s %-8s %-10s %-10s %-10s\n",
        "e", "N", "χ²_pos", "⟨v⟩", "σ_v", "⟨v²⟩/2")
println("-"^55)

for e in [0.5, 0.7, 0.8, 0.9]
    for N in [30, 50]
        e_str = @sprintf("%.2f", e)
        N_str = @sprintf("%03d", N)
        
        dir = joinpath(campaign_dir, "e$(e_str)_N$(N_str)_seed01")
        h5_file = joinpath(dir, "trajectories.h5")
        
        isfile(h5_file) || continue
        
        h5open(h5_file, "r") do f
            φ_all = read(f["trajectories/phi"])      # (n_snapshots, N)
            φ_dot_all = read(f["trajectories/phidot"])
            
            # Último snapshot
            φ = φ_all[end, :]
            φ_dot = φ_dot_all[end, :]
            
            stats = analyze_snapshot(φ, φ_dot)
            
            @printf("%-6.2f %-4d %-8.2f %-10.4f %-10.4f %-10.4f\n",
                    e, N, stats.χ², stats.mean_v, stats.std_v, stats.KE)
        end
    end
end

println()
println("="^70)
println("EVOLUCIÓN TEMPORAL (e=0.9, N=50)")  
println("="^70)
println()

e, N = 0.9, 50
e_str = @sprintf("%.2f", e)
N_str = @sprintf("%03d", N)
dir = joinpath(campaign_dir, "e$(e_str)_N$(N_str)_seed01")
h5_file = joinpath(dir, "trajectories.h5")

if isfile(h5_file)
    h5open(h5_file, "r") do f
        times = read(f["trajectories/time"])
        φ_all = read(f["trajectories/phi"])
        φ_dot_all = read(f["trajectories/phidot"])
        
        n_snap = length(times)
        println("Total snapshots: $n_snap, t_max = $(times[end])")
        println()
        
        @printf("%-8s %-10s %-10s %-10s\n", "t", "χ²_pos", "σ_v", "⟨v²⟩/2")
        println("-"^40)
        
        indices = [1, n_snap÷4, n_snap÷2, 3*n_snap÷4, n_snap]
        for i in indices
            φ = φ_all[i, :]
            φ_dot = φ_dot_all[i, :]
            stats = analyze_snapshot(φ, φ_dot)
            
            @printf("%-8.1f %-10.2f %-10.4f %-10.4f\n",
                    times[i], stats.χ², stats.std_v, stats.KE)
        end
    end
end

println()
println("="^70)
println("SEPARACIONES ANGULARES (indicador de clustering)")
println("="^70)
println()

function analyze_separations(φ)
    φ_sorted = sort(mod.(φ, 2π))
    N = length(φ_sorted)
    
    seps = diff(φ_sorted)
    push!(seps, 2π - φ_sorted[end] + φ_sorted[1])
    
    CV = std(seps) / mean(seps)  # Coef. variación
    
    return (mean=mean(seps), std=std(seps), min=minimum(seps), 
            max=maximum(seps), CV=CV)
end

@printf("%-6s %-4s %-10s %-10s %-10s %-8s\n",
        "e", "N", "⟨Δφ⟩", "σ_Δφ", "max/min", "CV")
println("-"^55)

for e in [0.5, 0.7, 0.8, 0.9]
    for N in [30, 50]
        e_str = @sprintf("%.2f", e)
        N_str = @sprintf("%03d", N)
        dir = joinpath(campaign_dir, "e$(e_str)_N$(N_str)_seed01")
        h5_file = joinpath(dir, "trajectories.h5")
        
        isfile(h5_file) || continue
        
        h5open(h5_file, "r") do f
            φ_all = read(f["trajectories/phi"])
            φ = φ_all[end, :]
            
            seps = analyze_separations(φ)
            ratio = seps.max / seps.min
            
            @printf("%-6.2f %-4d %-10.4f %-10.4f %-10.1f %-8.2f\n",
                    e, N, seps.mean, seps.std, ratio, seps.CV)
        end
    end
end

println()
println("Nota: CV > 1 sugiere clustering, ratio max/min alto = distribución no uniforme")
println("="^70)
