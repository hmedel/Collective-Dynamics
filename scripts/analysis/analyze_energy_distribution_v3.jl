"""
Análisis de distribución de energía - Campaña v3

Pregunta: ¿La energía se distribuye uniformemente entre partículas?
¿O hay partículas "calientes" y "frías"?
"""

using Statistics
using Printf
using HDF5

campaign_dir = "results/intrinsic_v3_campaign_20251126_110434"

println("="^70)
println("DISTRIBUCIÓN DE ENERGÍA ENTRE PARTÍCULAS")
println("="^70)
println()

# Calcular energía cinética de cada partícula
# En coordenadas polares: KE_i = (1/2) m g_φφ φ̇²
# donde g_φφ = a²sin²φ + b²cos²φ

function kinetic_energy(φ, φ_dot, a, b, mass=1.0)
    g_φφ = a^2 * sin(φ)^2 + b^2 * cos(φ)^2
    return 0.5 * mass * g_φφ * φ_dot^2
end

@printf("%-6s %-4s %-10s %-10s %-10s %-10s %-10s\n",
        "e", "N", "⟨KE⟩", "σ_KE", "min_KE", "max_KE", "max/min")
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
            φ = read(f["trajectories/phi"])[end, :]
            φ_dot = read(f["trajectories/phidot"])[end, :]
            
            KEs = [kinetic_energy(φ[i], φ_dot[i], a, b) for i in 1:length(φ)]
            
            @printf("%-6.2f %-4d %-10.4f %-10.4f %-10.4f %-10.4f %-10.1f\n",
                    e, N, mean(KEs), std(KEs), minimum(KEs), maximum(KEs),
                    maximum(KEs)/max(minimum(KEs), 1e-10))
        end
    end
end

println()
println("="^70)
println("EVOLUCIÓN TEMPORAL DE LA DISTRIBUCIÓN DE ENERGÍA")
println("="^70)
println()

# Para e=0.9, N=50, ver cómo evoluciona la distribución
e, N = 0.9, 50
a = 2.0
b = a * sqrt(1 - e^2)

e_str = @sprintf("%.2f", e)
N_str = @sprintf("%03d", N)
dir = joinpath(campaign_dir, "e$(e_str)_N$(N_str)_seed01")
h5_file = joinpath(dir, "trajectories.h5")

if isfile(h5_file)
    println("Run: e=$e, N=$N")
    println()
    
    h5open(h5_file, "r") do f
        times = read(f["trajectories/time"])
        φ_all = read(f["trajectories/phi"])
        φ_dot_all = read(f["trajectories/phidot"])
        
        @printf("%-8s %-10s %-10s %-10s %-10s\n",
                "t", "⟨KE⟩", "σ_KE", "σ/⟨KE⟩", "Gini")
        println("-"^50)
        
        for i in [1, 50, 100, 150, 200]
            i > size(φ_all, 1) && continue
            
            φ = φ_all[i, :]
            φ_dot = φ_dot_all[i, :]
            
            KEs = [kinetic_energy(φ[j], φ_dot[j], a, b) for j in 1:length(φ)]
            
            # Coeficiente de Gini (desigualdad)
            sorted_KE = sort(KEs)
            n = length(sorted_KE)
            gini = sum((2*k - n - 1) * sorted_KE[k] for k in 1:n) / (n * sum(sorted_KE))
            
            @printf("%-8.1f %-10.4f %-10.4f %-10.4f %-10.4f\n",
                    times[i], mean(KEs), std(KEs), std(KEs)/mean(KEs), gini)
        end
    end
end

println()
println("="^70)
println("COMPARACIÓN: EQUIPARTICIÓN vs REAL")
println("="^70)
println()

# Si hubiera equipartición perfecta, cada partícula tendría E_total/N
println("Razón σ_KE/⟨KE⟩ promediada sobre seeds:")
println("(Equipartición perfecta → 0, Maxwell-Boltzmann → ~0.71)")
println()

@printf("%-6s %-4s %-8s %-15s\n", "e", "N", "seeds", "σ_KE/⟨KE⟩")
println("-"^40)

for e in [0.5, 0.7, 0.8, 0.9]
    a = 2.0
    b = a * sqrt(1 - e^2)
    
    for N in [30, 50]
        ratios = Float64[]
        
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
                
                KEs = [kinetic_energy(φ[i], φ_dot[i], a, b) for i in 1:length(φ)]
                push!(ratios, std(KEs)/mean(KEs))
            end
        end
        
        if length(ratios) > 0
            @printf("%-6.2f %-4d %-8d %-15.4f ± %.4f\n",
                    e, N, length(ratios), mean(ratios), std(ratios))
        end
    end
end

println("="^70)
