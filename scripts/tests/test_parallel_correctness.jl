"""
test_parallel_correctness.jl

Test de correctitud para la versión paralela de detección de colisiones.

Verifica que find_next_collision_parallel produce EXACTAMENTE
los mismos resultados que find_next_collision (versión secuencial).

Uso:
    julia -t 24 --project=. test_parallel_correctness.jl
"""

using CollectiveDynamics
using Printf
using Statistics
using Random

# Incluir código paralelo
include("src/parallel/collision_detection_parallel.jl")

println("="^80)
println("TEST DE CORRECTITUD: DETECCIÓN DE COLISIONES PARALELA")
println("="^80)
println()

# Verificar que tenemos threads disponibles
n_threads = Threads.nthreads()
println("Threads disponibles: $n_threads")
if n_threads == 1
    @warn "Ejecutaste con 1 thread. Para probar paralelización usa: julia -t N"
end
println()

# ============================================================================
# Test 1: Conversión índice lineal ↔ par
# ============================================================================
println("Test 1: Conversión índice lineal ↔ par")
println("-"^80)

function test_linear_pair_conversion(n::Int)
    n_pairs = div(n * (n-1), 2)
    all_ok = true

    for idx in 1:n_pairs
        i, j = linear_to_pair(idx, n)

        # Verificar que i < j <= n
        if !(1 <= i < j <= n)
            println("❌ Error: idx=$idx → ($i,$j) no cumple 1 ≤ i < j ≤ n")
            all_ok = false
        end

        # Verificar conversión inversa
        idx_back = pair_to_linear(i, j, n)
        if idx != idx_back
            println("❌ Error: idx=$idx → ($i,$j) → idx=$idx_back (no coincide)")
            all_ok = false
        end
    end

    if all_ok
        println("  ✅ N=$n: Conversión correcta para todos los $n_pairs pares")
    else
        println("  ❌ N=$n: Errores encontrados")
    end

    return all_ok
end

# Test con varios tamaños
test_sizes = [5, 10, 20, 30, 50]
all_passed = true
for n in test_sizes
    passed = test_linear_pair_conversion(n)
    all_passed = all_passed && passed
end

println()
if all_passed
    println("✅ Test 1 PASADO: Conversión funciona correctamente")
else
    println("❌ Test 1 FALLIDO")
    exit(1)
end
println()

# ============================================================================
# Test 2: Correctitud de find_next_collision_parallel
# ============================================================================
println("Test 2: Correctitud vs versión secuencial")
println("-"^80)

function test_parallel_correctness(n_particles::Int, seed::Int=42)
    Random.seed!(seed)

    # Parámetros de la elipse
    a, b = 2.0, 1.0

    # Generar partículas aleatorias
    particles = generate_random_particles(n_particles, 1.0, 0.05, a, b)

    # Versión secuencial
    result_seq = find_next_collision(particles, a, b; max_time=1e-5, min_dt=1e-10)

    # Versión paralela
    result_par = find_next_collision_parallel(particles, a, b; max_time=1e-5, min_dt=1e-10)

    # Comparar resultados
    dt_match = isapprox(result_seq.dt, result_par.dt; rtol=1e-10)
    pair_match = result_seq.pair == result_par.pair
    found_match = result_seq.found == result_par.found

    all_match = dt_match && pair_match && found_match

    if all_match
        println(@sprintf("  ✅ N=%2d: Secuencial y paralela coinciden", n_particles))
        println(@sprintf("       dt=%.6e, par=%s, found=%s",
                        result_seq.dt, result_seq.pair, result_seq.found))
    else
        println(@sprintf("  ❌ N=%2d: DIFERENCIAS detectadas", n_particles))
        println("       Secuencial: dt=$(result_seq.dt), par=$(result_seq.pair), found=$(result_seq.found)")
        println("       Paralela:   dt=$(result_par.dt), par=$(result_par.pair), found=$(result_par.found)")
    end

    return all_match
end

# Test con varios tamaños
test_sizes = [10, 20, 30, 40, 50]
all_passed = true

for n in test_sizes
    passed = test_parallel_correctness(n)
    all_passed = all_passed && passed
end

println()
if all_passed
    println("✅ Test 2 PASADO: Resultados idénticos entre secuencial y paralela")
else
    println("❌ Test 2 FALLIDO: Diferencias encontradas")
    exit(1)
end
println()

# ============================================================================
# Test 3: Múltiples ejecuciones (verificar determinismo)
# ============================================================================
println("Test 3: Determinismo (múltiples ejecuciones)")
println("-"^80)

function test_determinism(n_particles::Int, n_runs::Int=10)
    Random.seed!(42)
    a, b = 2.0, 1.0
    particles = generate_random_particles(n_particles, 1.0, 0.05, a, b)

    # Ejecutar múltiples veces
    results = [find_next_collision_parallel(particles, a, b; max_time=1e-5, min_dt=1e-10)
               for _ in 1:n_runs]

    # Verificar que todos son idénticos
    first_result = results[1]
    all_same = all(r.dt == first_result.dt &&
                   r.pair == first_result.pair &&
                   r.found == first_result.found
                   for r in results)

    if all_same
        println(@sprintf("  ✅ N=%2d: %d ejecuciones idénticas (determinista)", n_particles, n_runs))
    else
        println(@sprintf("  ❌ N=%2d: Resultados varían entre ejecuciones", n_particles))
        println("       Primera: dt=$(first_result.dt), par=$(first_result.pair)")
        for (i, r) in enumerate(results[2:end])
            if r != first_result
                println("       Run $i: dt=$(r.dt), par=$(r.pair)")
            end
        end
    end

    return all_same
end

all_passed = true
for n in [20, 30, 40]
    passed = test_determinism(n, 5)
    all_passed = all_passed && passed
end

println()
if all_passed
    println("✅ Test 3 PASADO: Resultados deterministas")
else
    println("❌ Test 3 FALLIDO: No determinista (¡race condition!)")
    exit(1)
end
println()

# ============================================================================
# Test 4: Casos extremos
# ============================================================================
println("Test 4: Casos extremos")
println("-"^80)

function test_edge_cases()
    a, b = 2.0, 1.0
    all_ok = true

    # Caso 1: Partículas sin colisión
    p1 = Particle(1, 0.0, 0.1, 1.0, 0.05)
    p2 = Particle(2, π, -0.1, 1.0, 0.05)
    particles = [p1, p2]

    result_seq = find_next_collision(particles, a, b; max_time=1e-6)
    result_par = find_next_collision_parallel(particles, a, b; max_time=1e-6)

    if result_seq.dt ≈ result_par.dt
        println("  ✅ Sin colisión: Secuencial y paralela coinciden")
    else
        println("  ❌ Sin colisión: Diferencia")
        all_ok = false
    end

    # Caso 2: Colisión inmediata
    p1 = Particle(1, 0.0, 0.0, 1.0, 0.1)
    p2 = Particle(2, 0.05, 0.0, 1.0, 0.1)  # Muy cerca
    particles = [p1, p2]

    result_seq = find_next_collision(particles, a, b; max_time=1e-6)
    result_par = find_next_collision_parallel(particles, a, b; max_time=1e-6)

    if result_seq.dt ≈ result_par.dt
        println("  ✅ Colisión inmediata: Secuencial y paralela coinciden")
    else
        println("  ❌ Colisión inmediata: Diferencia")
        all_ok = false
    end

    return all_ok
end

if test_edge_cases()
    println()
    println("✅ Test 4 PASADO: Casos extremos OK")
else
    println()
    println("❌ Test 4 FALLIDO")
    exit(1)
end
println()

# ============================================================================
# Resumen Final
# ============================================================================
println("="^80)
println("✅ TODOS LOS TESTS PASARON")
println("="^80)
println()
println("La versión paralela produce resultados idénticos a la secuencial.")
println("Puedes usar find_next_collision_parallel con confianza.")
println()
println("Siguiente paso: Ejecutar benchmarks para medir speedup")
println("  julia -t 24 --project=. benchmark_parallel.jl")
println()
