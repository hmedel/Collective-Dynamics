#!/usr/bin/env julia
using CSV
using DataFrames
using Printf

"""
Genera matriz de parámetros para Experimento 3:
- Condiciones iniciales UNIFORMES (todos los runs empiezan igual)
- Objetivo: Ver emergencia pura de clustering desde uniformidad
- Compara con runs actuales (ICs random)
"""

# Parámetros del experimento
eccentricities = [0.7, 0.9]
N_particles = 80
E_per_N = 0.32
t_max = 500.0  # Basado en análisis temporal
dt_max = 1e-5
save_interval = 1.0  # Más denso para análisis temporal
projection_interval = 100
n_realizations = 20  # Por eccentricidad

# Calcular a, b para cada eccentricidad
function ellipse_params(e, area=10.0)
    """
    Dados e y area, calcula a y b
    e = √(1 - b²/a²)
    area = π*a*b
    """
    # De e: b = a√(1-e²)
    # De area: a*b = area/π
    # → a * a√(1-e²) = area/π
    # → a² = area/(π√(1-e²))

    a = sqrt(area / (π * sqrt(1 - e^2)))
    b = a * sqrt(1 - e^2)

    return a, b
end

# Generar matriz
runs = []

let run_id = 1
    for e in eccentricities
    a, b = ellipse_params(e)

    for seed in 1:n_realizations
        push!(runs, Dict(
            "run_id" => run_id,
            "eccentricity" => e,
            "a" => a,
            "b" => b,
            "N" => N_particles,
            "E_per_N" => E_per_N,
            "seed" => seed,
            "t_max" => t_max,
            "dt_max" => dt_max,
            "save_interval" => save_interval,
            "use_projection" => true,
            "projection_interval" => projection_interval,
            "uniform_ICs" => true  # FLAG: usar condiciones iniciales uniformes
        ))

        run_id += 1
    end
    end
end

# Crear DataFrame
df = DataFrame(runs)

# Guardar
output_file = "parameter_matrix_uniform_ICs_experiment.csv"
CSV.write(output_file, df)

println("="^70)
println("MATRIZ DE PARÁMETROS GENERADA: Experimento 3 (ICs Uniformes)")
println("="^70)
println()
println("Total runs: $(nrow(df))")
println("Eccentricidades: $eccentricities")
println("Realizaciones por e: $n_realizations")
println()
println("Parámetros:")
println("  N = $N_particles")
println("  E/N = $E_per_N")
println("  t_max = $t_max s")
println("  save_interval = $save_interval s")
println("  ICs: UNIFORMES (φ equiespaciados, velocidades térmicas)")
println()
println("Archivo guardado: $output_file")
println("="^70)
println()

# Mostrar primeras y últimas filas
println("Primeras 5 filas:")
println(first(df, 5))
println()
println("Últimas 5 filas:")
println(last(df, 5))
println()

# Resumen por eccentricidad
println("Resumen por eccentricidad:")
println(combine(groupby(df, :eccentricity), nrow => :n_runs))
println()

# Estimación de tiempo
println("="^70)
println("ESTIMACIÓN DE TIEMPO COMPUTACIONAL")
println("="^70)
println()

time_per_run_200s = 7.5  # minutos (empírico)
factor = t_max / 200.0
time_per_run = time_per_run_200s * factor

total_time_sequential = nrow(df) * time_per_run
total_time_parallel_24 = total_time_sequential / 24

@printf("Tiempo por run (estimado): %.1f minutos\n", time_per_run)
@printf("Tiempo total (secuencial): %.1f horas\n", total_time_sequential / 60)
@printf("Tiempo total (24 cores):   %.1f horas\n", total_time_parallel_24 / 60)
println()
println("="^70)
