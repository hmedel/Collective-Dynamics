"""
Análisis de densidad vs curvatura - ¿Hay acumulación en alta curvatura?

Hipótesis: Las partículas se acumulan donde la curvatura es mayor
(extremos del eje menor, φ ≈ π/2, 3π/2)

Esta sería la "transición de fase dinámica" - de distribución uniforme
a distribución correlacionada con la geometría.
"""

using Statistics
using Printf
using HDF5

campaign_dir = "results/intrinsic_v3_campaign_20251126_110434"

println("="^70)
println("DENSIDAD vs CURVATURA")
println("="^70)
println()

# Curvatura de la elipse en función de φ
function curvature(φ, a, b)
    return a * b / (a^2 * sin(φ)^2 + b^2 * cos(φ)^2)^(3/2)
end

# Dividir la elipse en regiones por curvatura
function density_by_curvature_region(φ, a, b; n_regions=4)
    N = length(φ)
    
    # Calcular curvatura para cada posición
    κ_particles = [curvature(p, a, b) for p in φ]
    
    # Definir regiones por percentiles de curvatura
    # En una elipse: alta κ cerca de φ = π/2, 3π/2
    #                baja κ cerca de φ = 0, π
    
    # Región 1: cerca de eje mayor (φ ≈ 0 o π) - curvatura BAJA
    # Región 2: cerca de eje menor (φ ≈ π/2 o 3π/2) - curvatura ALTA
    
    near_major = 0  # |cos(φ)| > 0.7
    near_minor = 0  # |sin(φ)| > 0.7
    
    for p in φ
        angle = mod(p, 2π)
        if abs(cos(angle)) > 0.7
            near_major += 1
        elseif abs(sin(angle)) > 0.7
            near_minor += 1
        end
    end
    
    # Fracción del perímetro: ~28% cerca de cada eje (|cos|>0.7 o |sin|>0.7)
    # Si distribución uniforme: near_major ≈ near_minor ≈ 0.28*N
    
    return (near_major=near_major, near_minor=near_minor,
            ratio_major=near_major/N, ratio_minor=near_minor/N)
end

println("Fracción de partículas en regiones de alta/baja curvatura:")
println("(Si uniforme: ~28% en cada región)")
println()
@printf("%-6s %-4s %-8s %-12s %-12s %-12s\n",
        "e", "N", "seeds", "f_major", "f_minor", "minor/major")
println("-"^60)

for e in [0.5, 0.7, 0.8, 0.9]
    a = 2.0
    b = a * sqrt(1 - e^2)
    
    for N in [30, 50]
        ratios_major = Float64[]
        ratios_minor = Float64[]
        
        for seed in 1:10
            e_str = @sprintf("%.2f", e)
            N_str = @sprintf("%03d", N)
            seed_str = @sprintf("%02d", seed)
            
            dir = joinpath(campaign_dir, "e$(e_str)_N$(N_str)_seed$(seed_str)")
            h5_file = joinpath(dir, "trajectories.h5")
            
            isfile(h5_file) || continue
            
            h5open(h5_file, "r") do f
                φ = read(f["trajectories/phi"])[end, :]
                
                dens = density_by_curvature_region(φ, a, b)
                push!(ratios_major, dens.ratio_major)
                push!(ratios_minor, dens.ratio_minor)
            end
        end
        
        if length(ratios_major) > 0
            mean_major = mean(ratios_major)
            mean_minor = mean(ratios_minor)
            ratio = mean_minor / mean_major
            
            @printf("%-6.2f %-4d %-8d %-12.3f %-12.3f %-12.2f\n",
                    e, N, length(ratios_major), mean_major, mean_minor, ratio)
        end
    end
end

println()
println("="^70)
println("CORRELACIÓN DENSIDAD-CURVATURA (análisis fino)")
println("="^70)
println()

# Dividir en más bins y correlacionar
function fine_density_curvature_correlation(φ, a, b; n_bins=20)
    N = length(φ)
    
    # Crear bins angulares
    bin_edges = range(0, 2π, length=n_bins+1)
    counts = zeros(n_bins)
    κ_bins = zeros(n_bins)
    
    for angle in φ
        ang = mod(angle, 2π)
        bin = min(n_bins, floor(Int, ang / (2π) * n_bins) + 1)
        counts[bin] += 1
    end
    
    # Curvatura media en cada bin
    for i in 1:n_bins
        φ_center = (bin_edges[i] + bin_edges[i+1]) / 2
        κ_bins[i] = curvature(φ_center, a, b)
    end
    
    # Normalizar densidad
    density = counts ./ (N / n_bins)  # 1 = uniforme
    
    # Correlación
    corr = cor(κ_bins, density)
    
    return (corr=corr, density=density, curvature=κ_bins)
end

println("Correlación densidad-curvatura:")
println("(Positivo = acumulación en alta curvatura)")
println()
@printf("%-6s %-4s %-8s %-15s\n", "e", "N", "seeds", "⟨corr(ρ,κ)⟩")
println("-"^40)

for e in [0.5, 0.7, 0.8, 0.9]
    a = 2.0
    b = a * sqrt(1 - e^2)
    
    for N in [30, 50]
        corrs = Float64[]
        
        for seed in 1:10
            e_str = @sprintf("%.2f", e)
            N_str = @sprintf("%03d", N)
            seed_str = @sprintf("%02d", seed)
            
            dir = joinpath(campaign_dir, "e$(e_str)_N$(N_str)_seed$(seed_str)")
            h5_file = joinpath(dir, "trajectories.h5")
            
            isfile(h5_file) || continue
            
            h5open(h5_file, "r") do f
                φ = read(f["trajectories/phi"])[end, :]
                result = fine_density_curvature_correlation(φ, a, b)
                push!(corrs, result.corr)
            end
        end
        
        if length(corrs) > 0
            @printf("%-6.2f %-4d %-8d %-15.4f ± %.4f\n",
                    e, N, length(corrs), mean(corrs), std(corrs))
        end
    end
end

println()
println("="^70)
println("EVOLUCIÓN TEMPORAL DE LA CORRELACIÓN ρ-κ")
println("="^70)
println()

# Ver si la correlación crece con el tiempo
for e in [0.5, 0.9]
    a = 2.0
    b = a * sqrt(1 - e^2)
    N = 50
    
    e_str = @sprintf("%.2f", e)
    N_str = @sprintf("%03d", N)
    
    println("e = $e, N = $N:")
    
    # Promediar sobre seeds
    all_corrs = []
    
    for seed in 1:10
        seed_str = @sprintf("%02d", seed)
        dir = joinpath(campaign_dir, "e$(e_str)_N$(N_str)_seed$(seed_str)")
        h5_file = joinpath(dir, "trajectories.h5")
        
        isfile(h5_file) || continue
        
        h5open(h5_file, "r") do f
            times = read(f["trajectories/time"])
            φ_all = read(f["trajectories/phi"])
            
            corrs = Float64[]
            for i in 1:size(φ_all, 1)
                result = fine_density_curvature_correlation(φ_all[i, :], a, b)
                push!(corrs, result.corr)
            end
            push!(all_corrs, corrs)
        end
    end
    
    if length(all_corrs) > 0
        n_times = minimum(length.(all_corrs))
        avg_corr = zeros(n_times)
        for c in all_corrs
            avg_corr .+= c[1:n_times]
        end
        avg_corr ./= length(all_corrs)
        
        @printf("  t=0:   corr = %.4f\n", avg_corr[1])
        @printf("  t=25:  corr = %.4f\n", avg_corr[n_times÷4])
        @printf("  t=50:  corr = %.4f\n", avg_corr[n_times÷2])
        @printf("  t=75:  corr = %.4f\n", avg_corr[3n_times÷4])
        @printf("  t=100: corr = %.4f\n", avg_corr[end])
        println()
    end
end

println("="^70)
println("PERFIL ANGULAR DE DENSIDAD")
println("="^70)
println()

# Mostrar perfil de densidad vs φ para e=0.9
e = 0.9
a = 2.0
b = a * sqrt(1 - e^2)
N = 50

println("Perfil de densidad angular (e=$e, N=$N, promedio 10 seeds):")
println("φ = 0, π: eje mayor (curvatura BAJA)")
println("φ = π/2, 3π/2: eje menor (curvatura ALTA)")
println()

n_bins = 8
density_profile = zeros(n_bins)
n_samples = 0

for seed in 1:10
    e_str = @sprintf("%.2f", e)
    N_str = @sprintf("%03d", N)
    seed_str = @sprintf("%02d", seed)
    
    dir = joinpath(campaign_dir, "e$(e_str)_N$(N_str)_seed$(seed_str)")
    h5_file = joinpath(dir, "trajectories.h5")
    
    isfile(h5_file) || continue
    
    h5open(h5_file, "r") do f
        φ = read(f["trajectories/phi"])[end, :]
        
        for angle in φ
            ang = mod(angle, 2π)
            bin = min(n_bins, floor(Int, ang / (2π) * n_bins) + 1)
            density_profile[bin] += 1
        end
        global n_samples += 1
    end
end

if n_samples > 0
    density_profile ./= (n_samples * N / n_bins)  # Normalizar a 1 = uniforme
    
    bin_centers = [(i-0.5) * 2π / n_bins for i in 1:n_bins]
    
    for i in 1:n_bins
        φ_center = bin_centers[i]
        κ = curvature(φ_center, a, b)
        
        bar_len = round(Int, density_profile[i] * 20)
        bar = repeat("█", bar_len)
        
        region = if abs(cos(φ_center)) > 0.7
            "MAJOR"
        elseif abs(sin(φ_center)) > 0.7
            "MINOR"
        else
            "     "
        end
        
        @printf("φ=%.2f (κ=%.2f) [%s]: %.3f  %s\n", 
                φ_center, κ, region, density_profile[i], bar)
    end
end

println()
println("="^70)
