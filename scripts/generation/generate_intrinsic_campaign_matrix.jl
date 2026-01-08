#!/usr/bin/env julia

"""
Genera matriz de parámetros para campaña CORREGIDA con distancias intrínsecas.

Mejoras sobre campaña anterior:
1. ✅ Usa detección de colisiones con arc-length (intrínseca)
2. ✅ Más seeds (30 por condición, antes 10) para mejor estadística
3. ✅ Mismos parámetros físicos para comparabilidad

Total: 4 N × 6 e × 30 seeds = 720 runs (~3x más datos)
"""

using CSV
using DataFrames
using Printf

println("="^70)
println("GENERACIÓN DE MATRIZ - CAMPAÑA CORREGIDA (INTRINSIC)")
println("="^70)
println()

# Parámetros físicos (iguales a campaña anterior para comparar)
N_values = [20, 40, 60, 80]
e_values = [0.0, 0.3, 0.5, 0.7, 0.8, 0.9]
n_seeds = 30  # ← AUMENTADO de 10 a 30

# Parámetros de la elipse
a = 2.0

# Parámetros de simulación (iguales a campaña anterior)
max_time = 100.0
dt_max = 1e-5
dt_min = 1e-10
save_interval = 0.5

# Generar matriz
runs = []

global run_id = 1
for N in N_values
    global run_id
    for e in e_values
        # Calcular b desde a y e
        b = a * sqrt(1 - e^2)

        for seed in 1:n_seeds
            push!(runs, (
                run_id = run_id,
                N = N,
                e = e,
                a = a,
                b = b,
                seed = seed,
                max_time = max_time,
                dt_max = dt_max,
                dt_min = dt_min,
                save_interval = save_interval
            ))
            run_id += 1
        end
    end
end

df = DataFrame(runs)

# Guardar CSV
output_file = "parameter_matrix_intrinsic_campaign.csv"
CSV.write(output_file, df)

println("✅ Matriz generada: $output_file")
println()
println("Estadísticas:")
println("  - Total runs:     ", nrow(df))
println("  - N values:       ", N_values)
println("  - e values:       ", e_values)
println("  - Seeds por (N,e):", n_seeds)
println("  - Condiciones:    ", length(N_values) * length(e_values))
println()

# Estadísticas por condición
println("Runs por condición:")
for N in N_values
    for e in e_values
        count = nrow(filter(row -> row.N == N && row.e == e, df))
        b = round(a * sqrt(1 - e^2), digits=3)
        println(@sprintf("  N=%2d, e=%.1f (b=%.3f): %3d runs", N, e, b, count))
    end
end

println()
println("="^70)
println("DIFERENCIAS vs CAMPAÑA ANTERIOR")
println("="^70)
println("  ✅ Colisiones: Euclidiana → Intrínseca (arc-length)")
println("  ✅ Seeds:      10 → 30 (mejor estadística)")
println("  ✅ Total runs: 240 → 720 (3x más datos)")
println("  ⚠️  Tiempo estimado: ~3-4 horas (24 cores)")
println()
println("="^70)
