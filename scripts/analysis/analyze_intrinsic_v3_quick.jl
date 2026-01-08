"""
Análisis rápido de campaña intrinsic v3
"""

using Statistics
using Printf
using JSON

campaign_dir = "results/intrinsic_v3_campaign_20251126_110434"

# Recolectar datos de todos los runs exitosos
data = []

for dir in readdir(campaign_dir, join=true)
    isdir(dir) || continue
    summary_file = joinpath(dir, "summary.json")
    isfile(summary_file) || continue
    
    try
        s = JSON.parsefile(summary_file)
        push!(data, s)
    catch
        continue
    end
end

println("="^70)
println("ANÁLISIS CAMPAÑA INTRINSIC v3")
println("="^70)
println("Runs exitosos: $(length(data))")
println()

# Agrupar por (e, N)
groups = Dict()
for d in data
    key = (d["eccentricity"], d["N"])
    if !haskey(groups, key)
        groups[key] = []
    end
    push!(groups[key], d)
end

# Tabla de resumen
println("="^70)
println("RESUMEN POR CONDICIÓN")
println("="^70)
println()
@printf("%-6s %-4s %-6s %-12s %-12s %-10s %-10s\n", 
        "e", "N", "runs", "ΔE/E₀", "colisiones", "t_sim(s)", "col/t")
println("-"^70)

for e in [0.5, 0.7, 0.8, 0.9]
    for N in [30, 40, 50, 60]
        key = (e, N)
        haskey(groups, key) || continue
        g = groups[key]
        
        dE = mean([d["ΔE_rel_max"] for d in g])
        col = mean([d["total_collisions"] for d in g])
        tsim = mean([d["elapsed_time_s"] for d in g])
        col_rate = col / 100.0  # colisiones por unidad de tiempo simulado
        
        @printf("%-6.2f %-4d %-6d %-12.2e %-12.0f %-10.0f %-10.1f\n",
                e, N, length(g), dE, col, tsim, col_rate)
    end
end

println()
println("="^70)
println("ANÁLISIS DE COLISIONES")
println("="^70)
println()

# Tasa de colisiones vs N² (debería escalar así para gas ideal)
println("Escalamiento de colisiones con N:")
println()
for e in [0.5, 0.7, 0.8, 0.9]
    print("e = $e: ")
    cols = []
    Ns = []
    for N in [30, 40, 50, 60]
        key = (e, N)
        haskey(groups, key) || continue
        g = groups[key]
        push!(cols, mean([d["total_collisions"] for d in g]))
        push!(Ns, N)
    end
    
    if length(cols) >= 2
        # Fit col ~ N^α
        log_N = log.(Ns)
        log_col = log.(cols)
        α = (log_col[end] - log_col[1]) / (log_N[end] - log_N[1])
        @printf("col ∝ N^%.2f (esperado: N² = 2.0)\n", α)
    end
end

println()
println("="^70)
println("EFECTO DE LA EXCENTRICIDAD")
println("="^70)
println()

# Para N=50 fijo, ver cómo cambian las métricas con e
println("N = 50 fijo:")
println()
for e in [0.5, 0.7, 0.8, 0.9]
    key = (e, 50)
    haskey(groups, key) || continue
    g = groups[key]
    
    col = mean([d["total_collisions"] for d in g])
    dE = mean([d["ΔE_rel_max"] for d in g])
    
    @printf("  e = %.1f: %.0f colisiones, ΔE/E₀ = %.2e\n", e, col, dE)
end

println()
println("="^70)
