#!/usr/bin/env julia
# Genera matriz de parámetros para PILOTO del Eccentricity Scan

using CSV
using DataFrames
using Printf

println("="^70)
println("PILOTO: ECCENTRICITY SCAN")
println("="^70)
println()

# Parámetros del experimento PILOTO (reducido)
eccentricities = [0.0, 0.5, 0.98]  # Control (círculo), medio, extremo
n_realizations = 3  # Solo 3 seeds para validar
a = 3.170233138523429
E_per_N = 0.32
N = 80

# Parámetros de simulación (tiempo reducido para testing)
t_max = 50.0  # Reducido de 200s
dt_max = 1e-5
save_interval = 0.5
use_projection = true
projection_interval = 100

println("Configuración del PILOTO:")
println("  Eccentricities: $eccentricities")
println("  Realizaciones por e: $n_realizations")
println("  Total runs: $(length(eccentricities) * n_realizations)")
println()
println("Sistema:")
@printf("  N = %d partículas\n", N)
@printf("  E/N = %.2f\n", E_per_N)
@printf("  a = %.3f\n", a)
println()
println("Simulación (REDUCIDA para piloto):")
@printf("  t_max = %.1f s (reducido de 200s)\n", t_max)
@printf("  dt_max = %.1e\n", dt_max)
println("  projection = $use_projection")
println()

# Generar matriz
runs = DataFrame(
    run_id = Int[],
    eccentricity = Float64[],
    a = Float64[],
    b = Float64[],
    N = Int[],
    E_per_N = Float64[],
    seed = Int[],
    t_max = Float64[],
    dt_max = Float64[],
    save_interval = Float64[],
    use_projection = Bool[],
    projection_interval = Int[]
)

run_id = 1
for e in eccentricities
    b = a * sqrt(1 - e^2)

    for seed in 1:n_realizations
        global run_id
        push!(runs, (
            run_id,
            e,
            a,
            b,
            N,
            E_per_N,
            seed,
            t_max,
            dt_max,
            save_interval,
            use_projection,
            projection_interval
        ))
        run_id += 1
    end
end

# Guardar
output_file = "parameter_matrix_eccentricity_scan_pilot.csv"
CSV.write(output_file, runs)

println("Matriz generada: $output_file")
println()
println("Resumen:")
println("="^70)
@printf("%-6s | %-8s | %-8s | %-8s | %-10s\n", "e", "a", "b", "a/b", "# Runs")
println("-"^70)

for e in eccentricities
    b = a * sqrt(1 - e^2)
    ratio = e == 0.0 ? 1.0 : a / b
    @printf("%.2f | %.3f | %.3f | %8.2f | %4d\n", e, a, b, ratio, n_realizations)
end
println("="^70)
println()
println("Total runs: $(nrow(runs))")

# Estimación
println()
println("Estimación de tiempo:")
println("  ~20 min por run (N=80, t=50s)")
@printf("  Total secuencial: %.1f horas\n", nrow(runs) * 0.33)
@printf("  Total paralelo (9 jobs): %.1f minutos\n", nrow(runs) * 20 / 9)
println()
println("="^70)
println("Próximo paso:")
println("  ./launch_eccentricity_scan.sh parameter_matrix_eccentricity_scan_pilot.csv 9")
println("="^70)
