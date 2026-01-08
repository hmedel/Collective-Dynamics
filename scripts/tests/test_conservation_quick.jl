#!/usr/bin/env julia
# Test rápido de conservación después de corrección del momento conjugado

using Pkg
Pkg.activate(".")

using CollectiveDynamics
using Printf

println("="^70)
println("TEST: CONSERVACIÓN CON CORRECCIÓN DE MOMENTO CONJUGADO")
println("="^70)
println()

# Geometría
a, b = 3.170233138523429, 0.6308684291059812
e = sqrt(1 - (b/a)^2)

println("Geometría:")
@printf("  e = %.3f\n", e)
@printf("  a = %.3f\n", a)
@printf("  b = %.3f\n", b)
@printf("  a/b = %.2f\n", a/b)
println()

# Sistema pequeño para prueba rápida
N = 10
E_per_N = 0.32

println("Sistema:")
@printf("  N = %d partículas\n", N)
@printf("  E/N = %.2f\n", E_per_N)
println()

# Generar partículas
using Random
particles = generate_random_particles(N, E_per_N, 0.05, a, b; rng=MersenneTwister(123))

# Calcular momento conjugado total inicial
P0 = sum(conjugate_momentum(p, a, b) for p in particles)
E0 = sum(kinetic_energy(p, a, b) for p in particles)

println("Estado inicial:")
@printf("  E₀ = %.6f\n", E0)
@printf("  P₀ = %.6f\n", P0)
println()

# Ejecutar simulación CORTA con dt_max pequeño y projection activado
println("Ejecutando simulación...")
println("  t_max = 10s (corta para prueba)")
println("  dt_max = 1e-6 (10× más fino)")
println("  projection = ACTIVADO (cada 100 pasos)")
println()

data = simulate_ellipse_adaptive(
    particles, a, b;
    max_time = 10.0,
    dt_max = 1e-6,
    save_interval = 0.5,
    collision_method = :parallel_transport,
    use_parallel = false,  # No paralelizar para N pequeño
    use_projection = true,  # ← ACTIVAR CORRECCIÓN
    projection_interval = 100
)

println()
println("="^70)
println("RESULTADOS")
println("="^70)
println()

# Calcular conservación final
particles_final = data.particles[end]
Pf = sum(conjugate_momentum(p, a, b) for p in particles_final)
Ef = sum(kinetic_energy(p, a, b) for p in particles_final)

println("Estado final:")
@printf("  Ef = %.6f\n", Ef)
@printf("  Pf = %.6f\n", Pf)
println()

ΔE_rel = abs(Ef - E0) / E0
ΔP_rel = abs(Pf - P0) / abs(P0)

println("Conservación:")
@printf("  ΔE/E₀ = %.2e\n", ΔE_rel)
@printf("  ΔP/P₀ = %.2e\n", ΔP_rel)
println()

# Clasificar conservación
if ΔE_rel < 1e-6
    println("✅ EXCELENTE conservación de energía (< 1e-6)")
elseif ΔE_rel < 1e-4
    println("✅ BUENA conservación de energía (< 1e-4)")
elseif ΔE_rel < 1e-2
    println("⚠️  Conservación ACEPTABLE (< 1e-2)")
else
    println("❌ Conservación POBRE (> 1e-2)")
end

if ΔP_rel < 1e-6
    println("✅ EXCELENTE conservación de momento (< 1e-6)")
elseif ΔP_rel < 1e-4
    println("✅ BUENA conservación de momento (< 1e-4)")
elseif ΔP_rel < 1e-2
    println("⚠️  Conservación ACEPTABLE (< 1e-2)")
else
    println("❌ Conservación POBRE (> 1e-2)")
end

println()
println("="^70)

# Comparar con resultado anterior (sin corrección)
println()
println("COMPARACIÓN:")
println("  Antes (sin corrección): ΔE/E₀ = 3.35e-03 (LÍMITE)")
@printf("  Ahora (con corrección): ΔE/E₀ = %.2e", ΔE_rel)
if ΔE_rel < 3.35e-3
    println(" → ✅ MEJORA")
else
    println(" → ❌ NO MEJORÓ")
end

println()
println("="^70)
