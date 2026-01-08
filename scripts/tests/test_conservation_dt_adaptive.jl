"""
    test_conservation_dt_adaptive.jl

Test de conservación con dt_max adaptativo para casos extremos.

Objetivo: Verificar que dt_max=1e-5 mejora la conservación para e≥0.95
"""

using Pkg
Pkg.activate(".")

using Printf

# Cargar módulos
include("src/geometry/metrics_polar.jl")
include("src/particles_polar.jl")
include("src/collisions_polar.jl")
include("src/integrators/forest_ruth_polar.jl")
include("src/simulation_polar.jl")

println("="^80)
println("TEST: Conservación de Energía con dt_max Adaptativo")
println("="^80)
println()

# ============================================================================
# Test 1: Caso extremo (e=0.99) con dt_max pequeño
# ============================================================================

println("TEST 1: Caso extremo - N=80, e=0.98, dt_max=1e-5")
println("-"^80)

N = 80
e = 0.98  # Máximo de la campaña (no 0.99)
φ_target = 0.30

# Semi-ejes
A = 2.0
b = sqrt(A * (1 - e^2) / π)
a = A / (π * b)

# Radio intrínseco
r = radius_from_packing(N, φ_target, a, b)

# Parámetros de simulación
mass = 1.0
max_speed = 1.0
t_max = 5.0  # Test corto
dt_max = 1e-5  # ⭐ dt_max REDUCIDO para e extremo
save_interval = 0.5

@printf("Parámetros:\n")
@printf("  N = %d\n", N)
@printf("  e = %.4f\n", e)
@printf("  a = %.4f, b = %.4f\n", a, b)
@printf("  r = %.5f (φ=%.3f)\n", r, φ_target)
@printf("  dt_max = %.2e (REDUCIDO)\n", dt_max)
println()

# Generar partículas
@printf("Generando %d partículas...\n", N)
particles = generate_random_particles_polar(
    N, mass, r, a, b;
    max_speed=max_speed,
    max_attempts=50000
)
println("✅ $(length(particles)) partículas generadas\n")

# Simular
@printf("Simulando (t_max=%.1fs, dt_max=%.2e)...\n", t_max, dt_max)
t_start = time()

data = simulate_ellipse_polar_adaptive(
    particles, a, b;
    max_time=t_max,
    dt_max=dt_max,
    save_interval=save_interval,
    collision_method=:parallel_transport,
    max_steps=1_000_000,
    verbose=false
)

t_elapsed = time() - t_start

# Analizar conservación
E_history = [sum(kinetic_energy(p, a, b) for p in snapshot) for snapshot in data.particles_history]
E0 = E_history[1]
E_final = E_history[end]
ΔE = E_final - E0
ΔE_rel = abs(ΔE) / abs(E0)

@printf("\nResultados:\n")
@printf("  Tiempo ejecución:  %.2f s\n", t_elapsed)
@printf("  Colisiones totales: %d\n", sum(data.n_collisions))
@printf("  Tasa colisiones:   %.1f/s\n", sum(data.n_collisions) / t_max)
@printf("\n")
@printf("  E₀:         %.10f\n", E0)
@printf("  E_final:    %.10f\n", E_final)
@printf("  ΔE:         %.3e\n", ΔE)
@printf("  ΔE/E₀:      %.3e", ΔE_rel)

if ΔE_rel < 1e-6
    println(" ⭐ EXCELENTE")
    success_1 = true
elseif ΔE_rel < 1e-4
    println(" ✅ BUENA")
    success_1 = true
elseif ΔE_rel < 1e-2
    println(" ⚠️  ACEPTABLE")
    success_1 = false
else
    println(" ❌ POBRE")
    success_1 = false
end

println()

# ============================================================================
# Test 2: Caso moderado (e=0.8) con dt_max estándar
# ============================================================================

println("="^80)
println("TEST 2: Caso moderado - N=80, e=0.8, dt_max=1e-4")
println("-"^80)

e2 = 0.8

# Semi-ejes
b2 = sqrt(A * (1 - e2^2) / π)
a2 = A / (π * b2)

# Radio intrínseco
r2 = radius_from_packing(N, φ_target, a2, b2)

# dt_max estándar
dt_max2 = 1e-4

@printf("Parámetros:\n")
@printf("  N = %d\n", N)
@printf("  e = %.4f\n", e2)
@printf("  a = %.4f, b = %.4f\n", a2, b2)
@printf("  r = %.5f (φ=%.3f)\n", r2, φ_target)
@printf("  dt_max = %.2e (ESTÁNDAR)\n", dt_max2)
println()

# Generar partículas
@printf("Generando %d partículas...\n", N)
particles2 = generate_random_particles_polar(
    N, mass, r2, a2, b2;
    max_speed=max_speed,
    max_attempts=50000
)
println("✅ $(length(particles2)) partículas generadas\n")

# Simular
@printf("Simulando (t_max=%.1fs, dt_max=%.2e)...\n", t_max, dt_max2)
t_start2 = time()

data2 = simulate_ellipse_polar_adaptive(
    particles2, a2, b2;
    max_time=t_max,
    dt_max=dt_max2,
    save_interval=save_interval,
    collision_method=:parallel_transport,
    max_steps=1_000_000,
    verbose=false
)

t_elapsed2 = time() - t_start2

# Analizar conservación
E_history2 = [sum(kinetic_energy(p, a2, b2) for p in snapshot) for snapshot in data2.particles_history]
E0_2 = E_history2[1]
E_final2 = E_history2[end]
ΔE2 = E_final2 - E0_2
ΔE_rel2 = abs(ΔE2) / abs(E0_2)

@printf("\nResultados:\n")
@printf("  Tiempo ejecución:  %.2f s\n", t_elapsed2)
@printf("  Colisiones totales: %d\n", sum(data2.n_collisions))
@printf("  Tasa colisiones:   %.1f/s\n", sum(data2.n_collisions) / t_max)
@printf("\n")
@printf("  E₀:         %.10f\n", E0_2)
@printf("  E_final:    %.10f\n", E_final2)
@printf("  ΔE:         %.3e\n", ΔE2)
@printf("  ΔE/E₀:      %.3e", ΔE_rel2)

if ΔE_rel2 < 1e-6
    println(" ⭐ EXCELENTE")
    success_2 = true
elseif ΔE_rel2 < 1e-4
    println(" ✅ BUENA")
    success_2 = true
elseif ΔE_rel2 < 1e-2
    println(" ⚠️  ACEPTABLE")
    success_2 = false
else
    println(" ❌ POBRE")
    success_2 = false
end

println()

# ============================================================================
# Resumen
# ============================================================================

println("="^80)
println("RESUMEN DE CONSERVACIÓN")
println("="^80)
println()

@printf("Test 1 (N=80, e=0.98, dt=1e-5):  ΔE/E₀ = %.3e %s\n",
    ΔE_rel,
    success_1 ? "✅" : "❌")

@printf("Test 2 (N=80, e=0.8,  dt=1e-4):  ΔE/E₀ = %.3e %s\n",
    ΔE_rel2,
    success_2 ? "✅" : "❌")

println()

if success_1 && success_2
    println("✅ AMBOS TESTS PASARON - CONSERVACIÓN ACEPTABLE")
    println()
    println("📊 RECOMENDACIÓN:")
    println("   • Usar dt_max = 1e-5 para e ≥ 0.95")
    println("   • Usar dt_max = 1e-4 para e < 0.95")
    println()
    println("✅ LISTO PARA CAMPAÑA COMPLETA (270 runs)")
else
    println("❌ ALGÚN TEST FALLÓ - REQUIERE AJUSTES ADICIONALES")
    println()
    println("Posibles soluciones:")
    println("   • Reducir dt_max aún más")
    println("   • Activar energy projection")
    println("   • Reducir φ_target")
end

println()
println("="^80)
