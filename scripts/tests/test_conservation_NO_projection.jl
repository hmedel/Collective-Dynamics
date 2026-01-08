#!/usr/bin/env julia
# Test de conservación SIN projection

using Pkg
Pkg.activate(".")

using CollectiveDynamics
using Printf

println("="^70)
println("TEST: CONSERVACIÓN SIN PROJECTION")
println("="^70)
println()

# Geometría (misma que antes)
a, b = 3.170233138523429, 0.6308684291059812
e = sqrt(1 - (b/a)^2)

println("Geometría:")
@printf("  e = %.3f\n", e)
@printf("  a = %.3f\n", a)
@printf("  b = %.3f\n", b)
@printf("  a/b = %.2f\n", a/b)
println()

# Sistema pequeño
N = 10
E_per_N = 0.32

println("Sistema:")
@printf("  N = %d partículas\n", N)
@printf("  E/N = %.2f\n", E_per_N)
println()

# Generar partículas (misma semilla)
using Random
particles = generate_random_particles(N, E_per_N, 0.05, a, b; rng=MersenneTwister(123))

# Estado inicial
P0 = sum(conjugate_momentum(p, a, b) for p in particles)
E0 = sum(kinetic_energy(p, a, b) for p in particles)

println("Estado inicial:")
@printf("  E₀ = %.6f\n", E0)
@printf("  P₀ = %.6f\n", P0)
println()

# Ejecutar simulación SIN PROJECTION
println("Ejecutando simulación...")
println("  t_max = 10s")
println("  dt_max = 1e-6")
println("  projection = DESACTIVADO ← CLAVE")
println()

data = simulate_ellipse_adaptive(
    particles, a, b;
    max_time = 10.0,
    dt_max = 1e-6,
    save_interval = 0.5,
    collision_method = :parallel_transport,
    use_parallel = false,
    use_projection = false,  # ← DESACTIVADO
    projection_interval = 100
)

println()
println("="^70)
println("RESULTADOS")
println("="^70)
println()

# Estado final
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

println("="^70)
println("COMPARACIÓN:")
println("  CON projection:    ΔE/E₀ = 4.43e-08,  ΔP/P₀ = 2.77e-04")
@printf("  SIN projection:    ΔE/E₀ = %.2e,  ΔP/P₀ = %.2e\n", ΔE_rel, ΔP_rel)
println("="^70)
