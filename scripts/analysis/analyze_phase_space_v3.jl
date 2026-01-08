"""
Análisis del espacio de fases φ vs φ̇ - Campaña v3

En una elipse, la curvatura varía con φ:
- φ = 0, π (extremos del eje mayor): curvatura MÍNIMA
- φ = π/2, 3π/2 (extremos del eje menor): curvatura MÁXIMA

La pregunta clave: ¿Hay correlación entre posición y velocidad?
"""

using Statistics
using Printf
using HDF5

campaign_dir = "results/intrinsic_v3_campaign_20251126_110434"

println("="^70)
println("ANÁLISIS DEL ESPACIO DE FASES")
println("="^70)
println()

# Función para calcular densidad por región
function density_by_region(φ, φ_dot)
    N = length(φ)
    
    # Regiones: cerca de eje mayor (φ ≈ 0, π) vs eje menor (φ ≈ π/2, 3π/2)
    near_major = Float64[]  # φ cerca de 0 o π
    near_minor = Float64[]  # φ cerca de π/2 o 3π/2
    
    for i in 1:N
        angle = mod(φ[i], 2π)
        # Distancia al punto más cercano del eje mayor
        d_major = min(angle, abs(angle - π), 2π - angle)
        # Distancia al punto más cercano del eje menor  
        d_minor = min(abs(angle - π/2), abs(angle - 3π/2))
        
        if d_major < π/4
            push!(near_major, φ_dot[i])
        elseif d_minor < π/4
            push!(near_minor, φ_dot[i])
        end
    end
    
    return (near_major=near_major, near_minor=near_minor)
end

# Curvatura de la elipse
function curvature(φ, a, b)
    return a * b / (a^2 * sin(φ)^2 + b^2 * cos(φ)^2)^(3/2)
end

println("DENSIDAD Y VELOCIDAD POR REGIÓN")
println("(Eje mayor = curvatura mínima, Eje menor = curvatura máxima)")
println()
@printf("%-6s %-4s | %-12s %-12s | %-12s %-12s\n",
        "", "", "EJE MAYOR", "", "EJE MENOR", "")
@printf("%-6s %-4s | %-12s %-12s | %-12s %-12s\n",
        "e", "N", "n_part", "⟨|v|⟩", "n_part", "⟨|v|⟩")
println("-"^70)

for e in [0.5, 0.7, 0.8, 0.9]
    a = 2.0
    b = a * sqrt(1 - e^2)
    
    for N in [30, 50]
        e_str = @sprintf("%.2f", e)
        N_str = @sprintf("%03d", N)
        
        dir = joinpath(campaign_dir, "e$(e_str)_N$(N_str)_seed01")
        h5_file = joinpath(dir, "trajectories.h5")
        
        isfile(h5_file) || continue
        
        h5open(h5_file, "r") do f
            φ_all = read(f["trajectories/phi"])
            φ_dot_all = read(f["trajectories/phidot"])
            
            # Último snapshot
            φ = φ_all[end, :]
            φ_dot = φ_dot_all[end, :]
            
            regions = density_by_region(φ, φ_dot)
            
            n_major = length(regions.near_major)
            n_minor = length(regions.near_minor)
            v_major = n_major > 0 ? mean(abs.(regions.near_major)) : 0.0
            v_minor = n_minor > 0 ? mean(abs.(regions.near_minor)) : 0.0
            
            @printf("%-6.2f %-4d | %-12d %-12.4f | %-12d %-12.4f\n",
                    e, N, n_major, v_major, n_minor, v_minor)
        end
    end
end

println()
println("="^70)
println("CORRELACIÓN POSICIÓN-VELOCIDAD")
println("="^70)
println()

# Calcular correlación entre cos(φ) y |φ̇|
# cos(φ) ~ curvatura (para elipse con a > b)

@printf("%-6s %-4s %-15s %-15s\n",
        "e", "N", "corr(cos φ, |v|)", "corr(κ, |v|)")
println("-"^55)

for e in [0.5, 0.7, 0.8, 0.9]
    a = 2.0
    b = a * sqrt(1 - e^2)
    
    for N in [30, 50]
        e_str = @sprintf("%.2f", e)
        N_str = @sprintf("%03d", N)
        
        dir = joinpath(campaign_dir, "e$(e_str)_N$(N_str)_seed01")
        h5_file = joinpath(dir, "trajectories.h5")
        
        isfile(h5_file) || continue
        
        h5open(h5_file, "r") do f
            φ_all = read(f["trajectories/phi"])
            φ_dot_all = read(f["trajectories/phidot"])
            
            # Último snapshot
            φ = φ_all[end, :]
            φ_dot = φ_all[end, :]
            
            cos_φ = cos.(φ)
            abs_v = abs.(φ_dot)
            κ = [curvature(p, a, b) for p in φ]
            
            corr_cos = cor(cos_φ, abs_v)
            corr_κ = cor(κ, abs_v)
            
            @printf("%-6.2f %-4d %-15.4f %-15.4f\n",
                    e, N, corr_cos, corr_κ)
        end
    end
end

println()
println("="^70)
println("PROMEDIO SOBRE MÚLTIPLES SEEDS")  
println("="^70)
println()

# Promediar sobre todas las seeds para cada (e, N)
@printf("%-6s %-4s %-8s %-15s %-15s\n",
        "e", "N", "seeds", "⟨corr(κ,|v|)⟩", "σ")
println("-"^55)

for e in [0.5, 0.7, 0.8, 0.9]
    a = 2.0
    b = a * sqrt(1 - e^2)
    
    for N in [30, 50]
        correlations = Float64[]
        
        for seed in 1:10
            e_str = @sprintf("%.2f", e)
            N_str = @sprintf("%03d", N)
            seed_str = @sprintf("%02d", seed)
            
            dir = joinpath(campaign_dir, "e$(e_str)_N$(N_str)_seed$(seed_str)")
            h5_file = joinpath(dir, "trajectories.h5")
            
            isfile(h5_file) || continue
            
            h5open(h5_file, "r") do f
                φ = read(f["trajectories/phi"])[end, :]
                φ_dot = read(f["trajectories/phidot"])[end, :]
                
                κ = [curvature(p, a, b) for p in φ]
                abs_v = abs.(φ_dot)
                
                push!(correlations, cor(κ, abs_v))
            end
        end
        
        if length(correlations) > 0
            @printf("%-6.2f %-4d %-8d %-15.4f %-15.4f\n",
                    e, N, length(correlations), 
                    mean(correlations), std(correlations))
        end
    end
end

println("="^70)
