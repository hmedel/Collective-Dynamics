"""
    generate_intrinsic_v2_campaign_matrix.jl

Genera matriz de parámetros para campaña v2 (radio basado en perímetro).

Con N_max_ref = 100:
    - N partículas dan exactamente N% de cobertura
    - Independiente de la excentricidad

Configuración:
    - e = [0.5, 0.7, 0.8, 0.9]
    - N = [50, 60, 70, 80] (coberturas 50%, 60%, 70%, 80%)
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

# Configuración
e_values = [0.5, 0.7, 0.8, 0.9]
N_values = [50, 60, 70, 80]  # Coberturas directas: 50%, 60%, 70%, 80%
n_seeds = 10

# Generar matriz
output_file = "parameter_matrix_intrinsic_v2.csv"

open(output_file, "w") do io
    # Header (sin b, se calcula desde e)
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
println("="^60)
println("CAMPAÑA INTRINSIC v2 - RADIO BASADO EN PERÍMETRO")
println("="^60)
println()
println("N_max_ref = $N_max_ref")
println("Radio = Perímetro / (2 × N_max_ref)")
println()
println("Excentricidades: ", e_values)
println("N (= cobertura %): ", N_values)
println("Seeds por condición: ", n_seeds)
println()
println("Total runs: ", length(e_values) * length(N_values) * n_seeds)
println("="^60)
