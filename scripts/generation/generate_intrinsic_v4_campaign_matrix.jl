"""
    generate_intrinsic_v4_campaign_matrix.jl

Genera matriz de parámetros para campaña v4 con partículas MÁS PEQUEÑAS.

Objetivo: Explorar régimen de alta excentricidad (e=0.9) y alta densidad (N=60-80)
que falló en v3 por traslape de partículas.

Cambio clave:
    v3: N_max_ref = 100 → radio grande, falla en e=0.9, N≥60
    v4: N_max_ref = 200 → radio 50% menor, permite mayor densidad

Con N_max_ref = 200:
    - El radio es la MITAD que en v3
    - N = 60 → 30% cobertura (vs 60% en v3)
    - N = 80 → 40% cobertura
    - N = 100 → 50% cobertura

Configuración:
    - e = [0.8, 0.9, 0.95]  (alta excentricidad)
    - N = [60, 80, 100]
    - Seeds = 5 por condición (prueba inicial)
    - Total: 3 × 3 × 5 = 45 runs
"""

using Printf

# Parámetros fijos
a = 2.0
max_time = 100.0
dt_max = 1e-5
dt_min = 1e-10
save_interval = 0.5
N_max_ref = 200  # CLAVE: Radio = Perímetro / (2 * 200) = mitad que v3

# Configuración para alta excentricidad
# Nota: e=0.95 con N=120 falla, así que limitamos a N=100 para ese caso
e_values = [0.8, 0.9, 0.95]
N_values = [60, 80, 100]  # 120 no cabe en e=0.95
n_seeds = 5

# Generar matriz
output_file = "parameter_matrix_intrinsic_v4.csv"

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
println("CAMPAÑA INTRINSIC v4 - PARTÍCULAS PEQUEÑAS (N_max_ref=200)")
println("="^70)
println()
println("N_max_ref = $N_max_ref (vs 100 en v3)")
println("Radio = Perímetro / (2 × $N_max_ref) = MITAD del radio de v3")
println()
println("Excentricidades: ", e_values)
println("N (partículas): ", N_values)
println("Coberturas efectivas: ", [N/N_max_ref for N in N_values])
println("Seeds por condición: ", n_seeds)
println()
println("Total runs: ", length(e_values) * length(N_values) * n_seeds)
println("="^70)
