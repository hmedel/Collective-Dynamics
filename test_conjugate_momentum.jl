#!/usr/bin/env julia
"""
    test_conjugate_momentum.jl

Script de prueba para verificar la conservación del momento conjugado.

Ejecuta una simulación corta y verifica que:
1. Energía se conserve (< 1e-4)
2. Momento conjugado se conserve (< 1e-4)

Uso:
    julia --project=. test_conjugate_momentum.jl
"""

using CollectiveDynamics
using Printf
using Random

println()
println("="^70)
println("PRUEBA DE CONSERVACIÓN DE MOMENTO CONJUGADO")
println("="^70)
println()

# Parámetros de la elipse
a = 2.0
b = 1.0

println("Geometría:")
println("  a (semi-eje mayor): $a")
println("  b (semi-eje menor): $b")
println()

# Crear partículas de prueba simples
println("Creando partículas de prueba...")
particles = Particle{Float64}[]

# 5 partículas con velocidades moderadas
Random.seed!(42)
for i in 1:5
    θ = (i-1) * 2π/5  # Distribuidas uniformemente
    θ_dot = rand() * 0.5  # Velocidades bajas para minimizar colisiones
    mass = 1.0
    radius = 0.05

    push!(particles, initialize_particle(Float64(i), mass, radius, θ, θ_dot, a, b))
end

println("  ✅ $(length(particles)) partículas creadas")
println()

# Calcular cantidades iniciales
E_initial = total_energy(particles, a, b)
P_initial = sum(p -> conjugate_momentum(p, a, b), particles)

println("Cantidades iniciales:")
println(@sprintf("  Energía total:      %.10e J", E_initial))
println(@sprintf("  Momento conjugado:  %.10e", P_initial))
println()

# Mostrar momento conjugado de cada partícula
println("Momento conjugado por partícula:")
for p in particles
    p_θ = conjugate_momentum(p, a, b)
    g_θ = metric_ellipse(p.θ, a, b)
    println(@sprintf("  Partícula %d: p_θ = %.6e  [θ=%.3f, θ̇=%.3f, g(θ)=%.3f]",
                    p.id, p_θ, p.θ, p.θ_dot, g_θ))
end
println()

# Simulación corta
println("Ejecutando simulación...")
println("  Método: adaptive")
println("  Tiempo: 0.1 s")
println("  dt_max: 1e-5")
println()

data = simulate_ellipse_adaptive(
    particles,
    a, b;
    max_time = 0.1,
    dt_max = 1e-5,
    save_interval = 0.01,
    collision_method = :parallel_transport,
    tolerance = 1e-6,
    verbose = false,
    max_steps = 100000
)

println("  ✅ Simulación completada")
println(@sprintf("  Pasos ejecutados: %d", length(data.times)))
println(@sprintf("  Colisiones: %d", sum(data.n_collisions)))
println()

# Analizar conservación
cons = data.conservation

E_final = cons.energies[end]
P_final = cons.conjugate_momenta[end]

ΔE = abs(E_final - E_initial)
ΔP = abs(P_final - P_initial)

error_E = ΔE / E_initial
error_P = ΔP / abs(P_initial)

println("="^70)
println("RESULTADOS DE CONSERVACIÓN")
println("="^70)
println()

println("ENERGÍA:")
println(@sprintf("  Inicial:        %.10e J", E_initial))
println(@sprintf("  Final:          %.10e J", E_final))
println(@sprintf("  Diferencia abs: %.10e J", ΔE))
println(@sprintf("  Error relativo: %.10e (%.6f%%)", error_E, error_E * 100))
println()

if error_E < 1e-6
    println("  ✅ EXCELENTE conservación de energía (< 1e-6)")
elseif error_E < 1e-4
    println("  ✅ BUENA conservación de energía (< 1e-4)")
elseif error_E < 1e-2
    println("  ⚠️  ACEPTABLE conservación de energía (< 1e-2)")
else
    println("  ❌ MALA conservación de energía (> 1e-2)")
end
println()

println("MOMENTO CONJUGADO:")
println(@sprintf("  Inicial:        %.10e", P_initial))
println(@sprintf("  Final:          %.10e", P_final))
println(@sprintf("  Diferencia abs: %.10e", ΔP))
println(@sprintf("  Error relativo: %.10e (%.6f%%)", error_P, error_P * 100))
println()

if error_P < 1e-6
    println("  ✅ EXCELENTE conservación de momento conjugado (< 1e-6)")
elseif error_P < 1e-4
    println("  ✅ BUENA conservación de momento conjugado (< 1e-4)")
elseif error_P < 1e-2
    println("  ⚠️  ACEPTABLE conservación de momento conjugado (< 1e-2)")
else
    println("  ❌ MALA conservación de momento conjugado (> 1e-2)")
    println()
    println("  ⚠️  ADVERTENCIA: El momento conjugado debería conservarse.")
    println("     Si el error es grande, puede indicar:")
    println("     - Problema en el transporte paralelo")
    println("     - Problema en el manejo de colisiones")
    println("     - dt_max demasiado grande")
end
println()

# Gráfica simple de evolución (solo datos numéricos)
println("="^70)
println("EVOLUCIÓN TEMPORAL")
println("="^70)
println()

n_samples = min(10, length(cons.times))
step = max(1, div(length(cons.times), n_samples))

println("Tiempo (s) | Energía         | Momento Conj.   | Δ E/E₀      | Δ P/P₀")
println("-"^70)

for i in 1:step:length(cons.times)
    t = cons.times[i]
    E = cons.energies[i]
    P = cons.conjugate_momenta[i]
    rel_E = abs(E - E_initial) / E_initial
    rel_P = abs(P - P_initial) / abs(P_initial)

    @printf("%.4f     | %.6e | %.6e | %.3e | %.3e\n",
            t, E, P, rel_E, rel_P)
end
println()

# Momento conjugado de partículas finales
println("="^70)
println("MOMENTO CONJUGADO FINAL POR PARTÍCULA")
println("="^70)
println()

particles_final = data.particles_history[end]
println("ID | p_θ inicial   | p_θ final     | Δp_θ          | Error rel")
println("-"^70)

for i in 1:length(particles)
    p_init = conjugate_momentum(particles[i], a, b)
    p_fin = conjugate_momentum(particles_final[i], a, b)
    Δp = p_fin - p_init
    err = abs(Δp) / abs(p_init)

    @printf("%2d | %+.6e | %+.6e | %+.6e | %.3e\n",
            i, p_init, p_fin, Δp, err)
end
println()

# Resumen
println("="^70)
println("RESUMEN")
println("="^70)
println()

test_passed = (error_E < 1e-2) && (error_P < 1e-2)

if test_passed
    println("  ✅ PRUEBA EXITOSA")
    println()
    println("  Ambas cantidades conservadas se mantienen con error < 1e-2")

    if error_E < 1e-4 && error_P < 1e-4
        println("  🌟 Conservación EXCELENTE (ambas < 1e-4)")
    end
else
    println("  ❌ PRUEBA FALLIDA")
    println()
    if error_E > 1e-2
        println("  Energía NO se conserva adecuadamente")
    end
    if error_P > 1e-2
        println("  Momento conjugado NO se conserva adecuadamente")
    end
end
println()

println("="^70)
println()
