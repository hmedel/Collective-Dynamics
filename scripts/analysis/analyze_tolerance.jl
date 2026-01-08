"""
analyze_tolerance.jl

Analiza el efecto de la tolerancia adaptativa en la conservación.

Nota: La tolerancia actual solo afecta la resolución de colisiones, NO el timestep
del integrador. Sin embargo, es útil verificar si tolerancias más estrictas
mejoran la conservación general del sistema.
"""

using CollectiveDynamics
using Printf
using Random
using Statistics

# Geometría
a = 2.0
b = 1.0

# Crear partículas de prueba
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
println("ANÁLISIS: Efecto de la Tolerancia en Conservación")
println("="^80)
println()
println("Configuración:")
println("  Geometría: a = $a, b = $b")
println("  Partículas: $(length(particles_template))")
println("  dt_max: 1e-5 (valor actual)")
println("  Tiempo de simulación: 0.1 s")
println()
println("="^80)
println()

# Array de tolerancias a probar
tolerances = [
    1e-4,   # Relajada
    1e-5,   # Moderada
    1e-6,   # Actual
    1e-7,   # Estricta
    1e-8,   # Muy estricta
]

dt_max = 1e-5

println(@sprintf("%-12s | %-12s | %-12s | %s",
                 "Tolerancia", "ΔE/E₀", "ΔP/P₀", "Estado"))
println("-"^80)

results = []

for tol in tolerances
    # Copiar partículas
    particles = copy(particles_template)

    # Ejecutar simulación
    data = simulate_ellipse_adaptive(
        particles, a, b;
        max_time = 0.1,
        dt_max = dt_max,
        save_interval = 0.1,
        collision_method = :parallel_transport,
        tolerance = tol,
        verbose = false
    )

    # Calcular errores
    cons = data.conservation

    E_final = cons.energies[end]
    P_final = cons.conjugate_momenta[end]

    error_E = abs(E_final - E_initial) / E_initial
    error_P = abs(P_final - P_initial) / abs(P_initial)

    # Clasificar
    if error_P < 1e-6
        estado = "✅ EXCELENTE"
    elseif error_P < 1e-4
        estado = "✅ BUENO"
    elseif error_P < 1e-2
        estado = "⚠️  ACEPTABLE"
    else
        estado = "❌ MALO"
    end

    println(@sprintf("%-12.1e | %-12.2e | %-12.2e | %s",
                     tol, error_E, error_P, estado))

    push!(results, (tol = tol, error_E = error_E, error_P = error_P))
end

println()
println("="^80)
println("CONCLUSIÓN")
println("="^80)
println()

# Verificar si la tolerancia tiene efecto significativo
error_P_values = [r.error_P for r in results]
variation = (maximum(error_P_values) - minimum(error_P_values)) / mean(error_P_values)

if variation < 0.1
    println("❗ La tolerancia tiene POCO EFECTO en la conservación del momento conjugado.")
    println()
    println("   Esto es esperado porque:")
    println("   • La tolerancia solo afecta la resolución de colisiones")
    println("   • Esta simulación NO tiene colisiones")
    println("   • La deriva proviene del integrador Forest-Ruth, no de las colisiones")
    println()
    println("   RECOMENDACIÓN: Reducir dt_max para mejorar conservación")
    println("                  (ver analyze_dt_convergence.jl)")
else
    println("✓ La tolerancia SÍ afecta la conservación.")
    println()
    println("   Variación observada: $(variation*100)%")
    println()
    best = results[end]
    println("   Mejor resultado con tolerancia = $(best.tol):")
    println("     Error P: $(best.error_P)")
end

println()
println("="^80)
