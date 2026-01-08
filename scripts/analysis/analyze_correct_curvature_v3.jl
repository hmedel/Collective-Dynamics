"""
CORRECCIÓN: Análisis de densidad vs curvatura

Para una elipse con a > b:
- En φ = 0, π (eje X, mayor): κ = b/a² = MENOR curvatura
- En φ = π/2, 3π/2 (eje Y, menor): κ = a/b² = MAYOR curvatura

El perfil anterior muestra que HAY MÁS PARTÍCULAS donde κ es MAYOR (MAJOR).
Pero "MAJOR" en mi código era cerca de cos(φ)≈1, que es eje X = curvatura BAJA.

Hay confusión en la nomenclatura. Vamos a corregir.
"""

using Statistics
using Printf
using HDF5

campaign_dir = "results/intrinsic_v3_campaign_20251126_110434"

println("="^70)
println("ANÁLISIS CORREGIDO: DENSIDAD vs CURVATURA")
println("="^70)
println()

# Curvatura de elipse: κ(φ) = ab / (a²sin²φ + b²cos²φ)^(3/2)
# Para a > b:
#   κ(0) = κ(π) = ab/b³ = a/b² (MÁXIMA)
#   κ(π/2) = κ(3π/2) = ab/a³ = b/a² (MÍNIMA)

function curvature(φ, a, b)
    return a * b / (a^2 * sin(φ)^2 + b^2 * cos(φ)^2)^(3/2)
end

# Verificar
a, b = 2.0, 1.0
println("Verificación de curvatura (a=$a, b=$b):")
@printf("  κ(0) = %.4f (eje mayor, donde X es máxima)\n", curvature(0, a, b))
@printf("  κ(π/2) = %.4f (eje menor, donde Y es máxima)\n", curvature(π/2, a, b))
@printf("  κ(π) = %.4f\n", curvature(π, a, b))
@printf("  κ(3π/2) = %.4f\n", curvature(3π/2, a, b))
println()
println("→ Curvatura MÁXIMA en φ=0,π (extremos del eje X, semi-eje a)")
println("→ Curvatura MÍNIMA en φ=π/2,3π/2 (extremos del eje Y, semi-eje b)")
println()

println("="^70)
println("PERFIL DE DENSIDAD CORREGIDO")
println("="^70)
println()

n_bins = 16

for e in [0.5, 0.9]
    a_val = 2.0
    b_val = a_val * sqrt(1 - e^2)
    N = 50
    
    println("--- e = $e (a=$a_val, b=$(round(b_val, digits=3))) ---")
    @printf("κ_max = %.3f (en φ=0,π), κ_min = %.3f (en φ=π/2,3π/2)\n",
            curvature(0, a_val, b_val), curvature(π/2, a_val, b_val))
    println()
    
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
            n_samples += 1
        end
    end
    
    if n_samples > 0
        density_profile ./= (n_samples * N / n_bins)
        
        println("φ (rad)  κ        ρ/ρ₀    Región        Perfil")
        println("-"^70)
        
        for i in 1:n_bins
            φ_center = (i - 0.5) * 2π / n_bins
            κ = curvature(φ_center, a_val, b_val)
            
            # Clasificar región
            region = if φ_center < π/4 || φ_center > 7π/4
                "HIGH κ (eje X+)"
            elseif φ_center > 3π/4 && φ_center < 5π/4
                "HIGH κ (eje X-)"
            elseif φ_center > π/4 && φ_center < 3π/4
                "LOW κ (eje Y+)"
            else
                "LOW κ (eje Y-)"
            end
            
            bar_len = round(Int, density_profile[i] * 15)
            bar = repeat("█", bar_len)
            
            @printf("%.2f     %.3f    %.3f   %-15s %s\n", 
                    φ_center, κ, density_profile[i], region, bar)
        end
        println()
    end
end

println("="^70)
println("RESUMEN: ¿DÓNDE SE ACUMULAN LAS PARTÍCULAS?")
println("="^70)
println()

for e in [0.5, 0.7, 0.8, 0.9]
    a_val = 2.0
    b_val = a_val * sqrt(1 - e^2)
    
    for N in [30, 50]
        high_κ = Float64[]  # φ cerca de 0, π
        low_κ = Float64[]   # φ cerca de π/2, 3π/2
        
        for seed in 1:10
            e_str = @sprintf("%.2f", e)
            N_str = @sprintf("%03d", N)
            seed_str = @sprintf("%02d", seed)
            
            dir = joinpath(campaign_dir, "e$(e_str)_N$(N_str)_seed$(seed_str)")
            h5_file = joinpath(dir, "trajectories.h5")
            
            isfile(h5_file) || continue
            
            h5open(h5_file, "r") do f
                φ = read(f["trajectories/phi"])[end, :]
                N_part = length(φ)
                
                n_high = 0
                n_low = 0
                
                for angle in φ
                    ang = mod(angle, 2π)
                    # HIGH κ: cerca de 0 o π (dentro de π/4)
                    if ang < π/4 || ang > 7π/4 || (ang > 3π/4 && ang < 5π/4)
                        n_high += 1
                    # LOW κ: cerca de π/2 o 3π/2 (dentro de π/4)  
                    elseif (ang > π/4 && ang < 3π/4) || (ang > 5π/4 && ang < 7π/4)
                        n_low += 1
                    end
                end
                
                push!(high_κ, n_high / N_part)
                push!(low_κ, n_low / N_part)
            end
        end
        
        if length(high_κ) > 0
            # Fracción esperada si uniforme: 0.5 (mitad del perímetro cada región)
            @printf("e=%.1f, N=%2d: f(HIGH κ)=%.3f, f(LOW κ)=%.3f, ratio=%.2f\n",
                    e, N, mean(high_κ), mean(low_κ), mean(high_κ)/mean(low_κ))
        end
    end
end

println()
println("Si ratio > 1: ACUMULACIÓN en regiones de ALTA curvatura")
println("Si ratio < 1: ACUMULACIÓN en regiones de BAJA curvatura")
println("Si ratio ≈ 1: Distribución uniforme")
println()

println("="^70)
