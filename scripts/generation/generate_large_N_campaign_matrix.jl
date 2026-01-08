"""
    generate_large_N_campaign_matrix.jl

Genera matriz de parámetros para campaña con N grande.
Objetivo: observar clustering con detección de colisiones intrínseca.

Configuración:
- e = [0.8, 0.9] (alta excentricidad para efecto de curvatura)
- N = [80, 100, 120] para e=0.8
- N = [100, 120, 150] para e=0.9
- Seeds = 10 por condición
- Total: 60 runs
"""

using Printf

# Parámetros fijos
a = 2.0
max_time = 100.0
dt_max = 1e-5
dt_min = 1e-10
save_interval = 0.5

# Configuración por excentricidad
configs = [
    (0.8, [80, 100, 120]),
    (0.9, [100, 120, 150]),
]

n_seeds = 10

# Generar matriz
output_file = "parameter_matrix_large_N_campaign.csv"

open(output_file, "w") do io
    # Header
    println(io, "run_id,N,e,a,b,seed,max_time,dt_max,dt_min,save_interval")

    run_id = 1
    for (e, N_vals) in configs
        b = a * sqrt(1 - e^2)

        for N in N_vals
            for seed in 1:n_seeds
                println(io, "$run_id,$N,$e,$a,$b,$seed,$max_time,$dt_max,$dt_min,$save_interval")
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
println("RESUMEN DE LA CAMPAÑA")
println("="^60)

total = 0
for (e, N_vals) in configs
    b = a * sqrt(1 - e^2)
    println()
    println("e = $e (b = $(round(b, digits=3))):")
    for N in N_vals
        coverage = N * 2 * 0.05 * b / (π * (a + b) * (1 + 3*((a-b)/(a+b))^2 / (10 + sqrt(4 - 3*((a-b)/(a+b))^2)))) * 100
        println("  N = $N: cobertura ≈ $(round(Int, coverage))%")
        total += n_seeds
    end
end

println()
println("Total runs: $total")
println("Seeds por condición: $n_seeds")
println("="^60)
