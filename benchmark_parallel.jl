"""
benchmark_parallel.jl

Benchmark para medir el speedup de la versión paralela de detección de colisiones.

Compara el tiempo de ejecución entre:
- find_next_collision (secuencial)
- find_next_collision_parallel (paralela)

Uso:
    julia -t 24 --project=. benchmark_parallel.jl

IMPORTANTE: Ejecutar con múltiples threads para ver speedup.
            julia -t 1  → No hay paralelización
            julia -t 24 → Speedup máximo con 24 hilos
"""

using CollectiveDynamics
using Printf
using Statistics
using Random

# Incluir código paralelo
include("src/parallel/collision_detection_parallel.jl")

println("="^80)
println("BENCHMARK: DETECCIÓN DE COLISIONES PARALELA")
println("="^80)
println()

# Verificar threads
n_threads = Threads.nthreads()
println("Threads disponibles: $n_threads")
if n_threads == 1
    @warn "Ejecutaste con 1 thread. Para ver speedup usa: julia -t N"
    println()
end
println()

# ============================================================================
# Función de benchmark
# ============================================================================

function benchmark_collision_detection(n_particles::Int; n_runs::Int=10, warmup::Int=2)
    Random.seed!(42)
    a, b = 2.0, 1.0

    # Ajustar radio según N para evitar overlap físico
    # Máximo teórico: perímetro/diámetro ≈ 48 partículas con r=0.05
    # Reducir radio para N>40
    radius_fraction = n_particles <= 40 ? 0.05 : 0.03

    # Generar partículas
    particles = generate_random_particles(n_particles, 1.0, radius_fraction, a, b)

    println(@sprintf("N = %d partículas (%d pares)", n_particles, div(n_particles*(n_particles-1), 2)))
    println("-"^80)

    # ========================================
    # Warmup (compilación JIT)
    # ========================================
    for _ in 1:warmup
        find_next_collision(particles, a, b; max_time=1e-5)
        find_next_collision_parallel(particles, a, b; max_time=1e-5)
    end

    # ========================================
    # Benchmark secuencial
    # ========================================
    times_seq = zeros(n_runs)
    for i in 1:n_runs
        t_start = time_ns()
        result = find_next_collision(particles, a, b; max_time=1e-5)
        t_end = time_ns()
        times_seq[i] = (t_end - t_start) / 1e6  # Convertir a millisegundos
    end

    mean_seq = mean(times_seq)
    std_seq = std(times_seq)

    println(@sprintf("  Secuencial:   %.3f ± %.3f ms", mean_seq, std_seq))

    # ========================================
    # Benchmark paralelo
    # ========================================
    times_par = zeros(n_runs)
    for i in 1:n_runs
        t_start = time_ns()
        result = find_next_collision_parallel(particles, a, b; max_time=1e-5)
        t_end = time_ns()
        times_par[i] = (t_end - t_start) / 1e6
    end

    mean_par = mean(times_par)
    std_par = std(times_par)

    println(@sprintf("  Paralela:     %.3f ± %.3f ms", mean_par, std_par))

    # ========================================
    # Speedup
    # ========================================
    speedup = mean_seq / mean_par
    efficiency = speedup / n_threads * 100  # Porcentaje de eficiencia

    println()
    println(@sprintf("  Speedup:      %.2fx", speedup))
    println(@sprintf("  Eficiencia:   %.1f%% (%d threads)", efficiency, n_threads))
    println()

    return (
        n = n_particles,
        time_seq = mean_seq,
        time_par = mean_par,
        speedup = speedup,
        efficiency = efficiency
    )
end

# ============================================================================
# Ejecutar benchmarks
# ============================================================================

# Tamaños a probar
test_sizes = [10, 20, 30, 50, 100]

results = []

for n in test_sizes
    result = benchmark_collision_detection(n; n_runs=10, warmup=2)
    push!(results, result)
end

# ============================================================================
# Resumen en tabla
# ============================================================================
println("="^80)
println("RESUMEN DE RESULTADOS")
println("="^80)
println()
println("| N    | Pares | Secuencial (ms) | Paralela (ms) | Speedup | Eficiencia |")
println("|------|-------|-----------------|---------------|---------|------------|")

for r in results
    n_pairs = div(r.n * (r.n - 1), 2)
    println(@sprintf("| %4d | %5d | %15.3f | %13.3f | %7.2fx | %9.1f%% |",
                    r.n, n_pairs, r.time_seq, r.time_par, r.speedup, r.efficiency))
end

println()

# ============================================================================
# Análisis
# ============================================================================
println("ANÁLISIS:")
println()

# Encontrar mejor speedup
best_idx = argmax([r.speedup for r in results])
best = results[best_idx]

println(@sprintf("✅ Mejor speedup: %.2fx con N=%d", best.speedup, best.n))
println()

# Advertencia si speedup es bajo
if n_threads > 1
    expected_min_speedup = n_threads * 0.3  # Al menos 30% de eficiencia

    if best.speedup < expected_min_speedup
        println("⚠️  ADVERTENCIA: Speedup más bajo de lo esperado")
        println("   Posibles causas:")
        println("   - Overhead de threads domina para N pequeño")
        println("   - Contención de memoria/cache")
        println("   - Compilación JIT no completada")
        println()
        println("   Recomendaciones:")
        println("   - Probar con N mayor (≥100)")
        println("   - Verificar que Julia usó los threads: Threads.nthreads()")
        println("   - Incrementar n_runs para promediar mejor")
        println()
    else
        println(@sprintf("✅ Speedup saludable: %.1f%% de eficiencia teórica máxima",
                        best.speedup / n_threads * 100))
        println()
    end
else
    println("ℹ️  Ejecutaste con 1 thread. Para ver speedup:")
    println("   julia -t 24 --project=. benchmark_parallel.jl")
    println()
end

# Estimación para simulación completa
println("PROYECCIÓN PARA SIMULACIÓN COMPLETA:")
println()

n_sim = 30  # Típico
result_30 = findfirst(r -> r.n == n_sim, results)

if !isnothing(result_30)
    r = results[result_30]

    # Simulación típica: 10s física, dt_max=1e-6 → ~10M pasos
    # Cada paso hace find_next_collision
    n_steps = 10_000_000
    time_per_step_seq = r.time_seq / 1000  # Convertir a segundos
    time_per_step_par = r.time_par / 1000

    total_seq_hours = (n_steps * time_per_step_seq) / 3600
    total_par_hours = (n_steps * time_per_step_par) / 3600

    println(@sprintf("Para N=%d, 10M pasos (dt_max=1e-6, 10s físicos):", n_sim))
    println(@sprintf("  Tiempo secuencial:  %.1f horas", total_seq_hours))
    println(@sprintf("  Tiempo paralelo:    %.1f horas", total_par_hours))
    println(@sprintf("  Ahorro:             %.1f horas", total_seq_hours - total_par_hours))
    println()
end

println("="^80)
println("BENCHMARK COMPLETADO")
println("="^80)
println()

# Guardar resultados en archivo CSV
using DelimitedFiles

output_file = "benchmark_results_$(n_threads)threads.csv"
header = ["N", "Pares", "Tiempo_Seq_ms", "Tiempo_Par_ms", "Speedup", "Eficiencia_%"]
data_matrix = hcat(
    [r.n for r in results],
    [div(r.n*(r.n-1), 2) for r in results],
    [r.time_seq for r in results],
    [r.time_par for r in results],
    [r.speedup for r in results],
    [r.efficiency for r in results]
)

open(output_file, "w") do io
    writedlm(io, [header], ',')
    writedlm(io, data_matrix, ',')
end

println("Resultados guardados en: $output_file")
println()
