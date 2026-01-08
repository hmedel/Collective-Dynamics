"""
    generate_intrinsic_v3_campaign_matrix.jl

Genera matriz de parámetros para campaña v3 (radio basado en perímetro).

CORRECCIÓN vs v2: N valores reducidos para garantizar colocación física.

Con N_max_ref = 100:
    - N partículas dan exactamente N% de cobertura
    - N_max práctico ≈ 85 (con holgura para colocación aleatoria)
    - N = [30, 40, 50, 60] garantiza que siempre caben

Configuración:
    - e = [0.5, 0.7, 0.8, 0.9]
    - N = [30, 40, 50, 60] (coberturas 30%, 40%, 50%, 60%)
    - Seeds = 10 por condición
    - Total: 4 × 4 × 10 = 160 runs
"""

using Printf

# Parámetros fijos
a = 2.0
max_time = 100.0
dt_max = 1e-5
dt_min = 1e-10
save_interval = 0.5
N_max_ref = 100  # Radio = Perímetro / (2 * N_max_ref)

# Configuración CORREGIDA
e_values = [0.5, 0.7, 0.8, 0.9]
N_values = [30, 40, 50, 60]  # Coberturas: 30%, 40%, 50%, 60% (todas < 85 límite)
n_seeds = 10

# Generar matriz
output_file = "parameter_matrix_intrinsic_v3.csv"

open(output_file, "w") do io
    # Header
    println(io, "run_id,N,e,a,seed,max_time,dt_max,dt_min,save_interval,N_max_ref")

    run_id = 1
    for e in e_values
        for N in N_values
            for seed in 1:n_seeds
                println(io, "$run_id,$N,$e,$a,$seed,$max_time,$dt_max,$dt_min,$save_interval,$N_max_ref")
                run_id += 1
            end
        end
    end

    println(stderr, "Generados $(run_id - 1) runs")
end

println("Matriz guardada en: $output_file")

# Resumen
println()
println("="^70)
println("CAMPAÑA INTRINSIC v3 - RADIO BASADO EN PERÍMETRO (CORREGIDA)")
println("="^70)
println()
println("N_max_ref = $N_max_ref")
println("Radio = Perímetro / (2 × N_max_ref)")
println("N_max práctico ≈ 85 (con holgura para colocación aleatoria)")
println()
println("Excentricidades: ", e_values)
println("N (= cobertura %): ", N_values)
println("Seeds por condición: ", n_seeds)
println()
println("Total runs: ", length(e_values) * length(N_values) * n_seeds)
println("="^70)
