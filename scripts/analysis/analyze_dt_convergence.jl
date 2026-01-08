"""
analyze_dt_convergence.jl

Analiza cómo la conservación del momento conjugado depende del tamaño del paso
de tiempo dt_max en el integrador Forest-Ruth.

Objetivo: Determinar el dt_max óptimo para conservación excelente (<1e-6).
"""

using CollectiveDynamics
using Printf
using Random
using Statistics

# Geometría
a = 2.0
b = 1.0

# Crear partículas de prueba consistentes
Random.seed!(42)
particles_template = Particle{Float64}[]

for i in 1:5
    θ = (i-1) * 2π/5
    θ_dot = rand() * 0.5
    mass = 1.0
    radius = 0.05
    push!(particles_template, initialize_particle(i, mass, radius, θ, θ_dot, a, b))
end

# Calcular cantidad conservada inicial
E_initial = total_energy(particles_template, a, b)
P_initial = sum(p -> conjugate_momentum(p, a, b), particles_template)

println("="^80)
println("ANÁLISIS DE CONVERGENCIA: dt_max vs Conservación de Momento Conjugado")
println("="^80)
println()
println("Configuración:")
println("  Geometría: a = $a, b = $b")
println("  Partículas: $(length(particles_template))")
println("  Tiempo de simulación: 0.1 s")
println("  Energía inicial: $(E_initial)")
println("  Momento conjugado inicial: $(P_initial)")
println()
println("="^80)
println()

# Array de valores dt_max a probar (desde grande a pequeño)
dt_values = [
    1e-3,   # Muy grande
    1e-4,   # Grande
    1e-5,   # Actual (test original)
    1e-6,   # Pequeño
    1e-7,   # Muy pequeño
    1e-8,   # Extremadamente pequeño
]

# Almacenar resultados
results = []

println(@sprintf("%-12s | %-12s | %-12s | %-12s | %-12s | %s",
                 "dt_max", "ΔE/E₀", "ΔP/P₀", "Pasos", "Tiempo (s)", "Estado"))
println("-"^80)

for dt_max in dt_values
    # Copiar partículas
    particles = copy(particles_template)

    # Tiempo de ejecución
    t_start = time()

    # Ejecutar simulación
    data = simulate_ellipse_adaptive(
        particles, a, b;
        max_time = 0.1,
        dt_max = dt_max,
        save_interval = 0.1,  # Solo guardar inicio y final
        collision_method = :parallel_transport,
        tolerance = 1e-6,
        verbose = false
    )

    t_elapsed = time() - t_start

    # Calcular errores
    cons = data.conservation

    E_final = cons.energies[end]
    P_final = cons.conjugate_momenta[end]

    error_E = abs(E_final - E_initial) / E_initial
    error_P = abs(P_final - P_initial) / abs(P_initial)

    n_steps = length(cons.times) - 1

    # Clasificar resultado
    if error_P < 1e-6
        estado = "✅ EXCELENTE"
    elseif error_P < 1e-4
        estado = "✅ BUENO"
    elseif error_P < 1e-2
        estado = "⚠️  ACEPTABLE"
    else
        estado = "❌ MALO"
    end

    # Imprimir resultado
    println(@sprintf("%-12.1e | %-12.2e | %-12.2e | %-12d | %-12.6f | %s",
                     dt_max, error_E, error_P, n_steps, t_elapsed, estado))

    # Guardar para análisis posterior
    push!(results, (
        dt_max = dt_max,
        error_E = error_E,
        error_P = error_P,
        n_steps = n_steps,
        t_elapsed = t_elapsed,
        estado = estado
    ))
end

println()
println("="^80)
println("ANÁLISIS DE RESULTADOS")
println("="^80)
println()

# Encontrar el dt_max más grande que da error < 1e-6
excellent_results = filter(r -> r.error_P < 1e-6, results)

if !isempty(excellent_results)
    best = excellent_results[1]  # El primero (mayor dt_max)
    println("✅ Para conservación EXCELENTE (error < 1e-6):")
    println("   dt_max recomendado: $(best.dt_max)")
    println("   Error alcanzado: $(best.error_P)")
    println("   Pasos necesarios: $(best.n_steps)")
    println("   Tiempo de cómputo: $(best.t_elapsed) s")
    println()
end

# Encontrar el dt_max más grande que da error < 1e-4
good_results = filter(r -> r.error_P < 1e-4, results)

if !isempty(good_results)
    best = good_results[1]
    println("✅ Para conservación BUENA (error < 1e-4):")
    println("   dt_max recomendado: $(best.dt_max)")
    println("   Error alcanzado: $(best.error_P)")
    println("   Pasos necesarios: $(best.n_steps)")
    println("   Tiempo de cómputo: $(best.t_elapsed) s")
    println()
end

# Mostrar relación entre dt_max y error
println("ORDEN DE CONVERGENCIA:")
println()
println("Si el integrador Forest-Ruth es orden 4, esperaríamos:")
println("  error_P ∝ dt⁴")
println()
println("Verificación empírica:")
println()

for i in 2:length(results)
    dt_ratio = results[i-1].dt_max / results[i].dt_max
    error_ratio = results[i-1].error_P / results[i].error_P
    expected_ratio = dt_ratio^4

    println(@sprintf("  dt_max: %.1e → %.1e (×%.1f)",
                     results[i].dt_max, results[i-1].dt_max, dt_ratio))
    println(@sprintf("    Error observado: %.2e → %.2e (×%.2f)",
                     results[i].error_P, results[i-1].error_P, error_ratio))
    println(@sprintf("    Error esperado O(dt⁴): ×%.2f", expected_ratio))

    if abs(error_ratio - expected_ratio) / expected_ratio < 0.5
        println("    ✅ Consistente con orden 4")
    else
        println("    ⚠️  Desviación del orden 4 esperado")
    end
    println()
end

println("="^80)
println("RECOMENDACIONES")
println("="^80)
println()
println("1. Para simulaciones sin colisiones:")
if !isempty(excellent_results)
    println("   • Usar dt_max = $(excellent_results[1].dt_max) para conservación excelente")
end
if !isempty(good_results)
    println("   • Usar dt_max = $(good_results[1].dt_max) para conservación buena")
end
println()
println("2. Para simulaciones con colisiones:")
println("   • El dt_max se ajusta automáticamente cerca de colisiones")
println("   • Usar valores más pequeños si se observa deriva")
println()
println("3. Balance costo-precisión:")
println("   • Cada factor 10 en dt_max → ~10000× en error (orden 4)")
println("   • Cada factor 10 en dt_max → ~10× menos pasos")
println()
println("="^80)
