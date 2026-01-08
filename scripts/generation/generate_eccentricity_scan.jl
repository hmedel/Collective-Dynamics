#!/usr/bin/env julia
# Genera matriz de parámetros para Eccentricity Scan (Experimento 1 para PRL)

using CSV
using DataFrames
using Printf

println("="^70)
println("GENERADOR DE MATRIZ DE PARÁMETROS: ECCENTRICITY SCAN")
println("="^70)
println()

# Parámetros del experimento
eccentricities = [0.0, 0.3, 0.5, 0.7, 0.8, 0.9, 0.95, 0.98, 0.99]
n_realizations = 20  # Múltiples seeds para estadística
a = 3.170233138523429  # Semi-eje mayor (fijo)
E_per_N = 0.32  # Energía por partícula (fija)
N = 80  # Número de partículas

# Parámetros de simulación
t_max = 200.0
dt_max = 1e-5
save_interval = 0.5
use_projection = true
projection_interval = 100

println("Configuración del experimento:")
println("  Eccentricities: $(length(eccentricities)) valores")
println("  Realizaciones por e: $n_realizations")
println("  Total runs: $(length(eccentricities) * n_realizations)")
println()
println("Sistema:")
@printf("  N = %d partículas\n", N)
@printf("  E/N = %.2f\n", E_per_N)
@printf("  a = %.3f (fijo)\n", a)
println()
println("Simulación:")
@printf("  t_max = %.1f s\n", t_max)
@printf("  dt_max = %.1e\n", dt_max)
@printf("  save_interval = %.1f s\n", save_interval)
println("  projection = $use_projection (interval = $projection_interval)")
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
    # Calcular b desde eccentricity
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
output_file = "parameter_matrix_eccentricity_scan.csv"
CSV.write(output_file, runs)

println("Matriz generada: $output_file")
println()
println("Resumen por eccentricity:")
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

# Estimación de tiempo
println()
println("Estimación de tiempo computacional:")
println("  ~45 min por run (N=80, t=200s, 24 cores)")
@printf("  Total secuencial: %.1f horas\n", nrow(runs) * 0.75)
@printf("  Total paralelo (24 jobs): %.1f horas\n", nrow(runs) * 0.75 / 24)
println()
println("Storage estimado: ~$(nrow(runs) * 0.5) GB")
println()
println("="^70)
println("Próximo paso:")
println("  ./launch_eccentricity_scan.sh")
println("="^70)
