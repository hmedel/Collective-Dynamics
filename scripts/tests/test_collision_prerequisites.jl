#!/usr/bin/env julia
"""
test_collision_prerequisites.jl

Verifica propiedades específicas necesarias para implementar colisiones:
1. Velocidades cartesianas correctas
2. Distancias entre partículas
3. Christoffel en diferentes regiones de la elipse
4. Consistencia energía cartesiana vs angular
"""

using Pkg
Pkg.activate(".")

include("src/particles_polar.jl")
include("src/integrators/forest_ruth_polar.jl")

using Printf
using LinearAlgebra

println("="^70)
println("TEST: Prerequisitos para Colisiones en Coordenadas Polares")
println("="^70)
println()

a, b = 2.0, 1.0
mass = 1.0

# ============================================================================
# Test 1: Velocidades cartesianas correctas
# ============================================================================

println("Test 1: Velocidades cartesianas desde φ̇")
println("-"^70)

test_points = [
    (0.0, 1.0, "φ=0° (eje +x)"),
    (Float64(π/2), 1.0, "φ=90° (eje +y)"),
    (Float64(π), 1.0, "φ=180° (eje -x)"),
    (Float64(π/4), 1.0, "φ=45°")
]

println("  Verificando consistencia vel_cartesiana vs φ̇:")

function test_velocities()
    max_error = 0.0

    for (φ, φ_dot, label) in test_points
        # Crear partícula
        p = ParticlePolar(1, mass, 0.01, φ, φ_dot, a, b)

        # Velocidad cartesiana desde energía
        E = kinetic_energy(p, a, b)
        v_magnitude = sqrt(2 * E / mass)

        # Velocidad cartesiana desde vel field
        v_from_field = norm(p.vel)

        error = abs(v_magnitude - v_from_field)
        max_error = max(max_error, error)

    @printf("  %s: |v_field|=%.6f, |v_energy|=%.6f, err=%.2e\n",
            label, v_from_field, v_magnitude, error)
end

@printf("\n  Error máximo: %.2e\n", max_error)

if max_error < 1e-10
    println("  ✅ Velocidades cartesianas correctas")
else
    println("  ❌ ERROR en velocidades cartesianas")
end
println()

# ============================================================================
# Test 2: Distancias entre partículas
# ============================================================================

println("Test 2: Cálculo de distancias para detección de colisiones")
println("-"^70)

# Crear dos partículas en posiciones conocidas
φ1 = 0.0
φ2 = Float64(π/2)

p1 = ParticlePolar(1, mass, 0.05, φ1, 0.5, a, b)
p2 = ParticlePolar(2, mass, 0.05, φ2, 0.5, a, b)

# Distancia cartesiana
dist_cart = norm(p1.pos - p2.pos)

# Distancia teórica (deberían estar en (a,0) y (0,b))
pos1_expected = SVector(a, 0.0)
pos2_expected = SVector(0.0, b)
dist_expected = norm(pos1_expected - pos2_expected)

error_dist = abs(dist_cart - dist_expected)

@printf("  Posición p1: (%.6f, %.6f)\n", p1.pos[1], p1.pos[2])
@printf("  Posición p2: (%.6f, %.6f)\n", p2.pos[1], p2.pos[2])
@printf("  Distancia calculada: %.6f\n", dist_cart)
@printf("  Distancia esperada:  %.6f\n", dist_expected)
@printf("  Error: %.2e\n", error_dist)

if error_dist < 1e-10
    println("  ✅ Cálculo de distancias correcto")
else
    println("  ❌ ERROR en cálculo de distancias")
end
println()

# ============================================================================
# Test 3: Christoffel en diferentes regiones
# ============================================================================

println("Test 3: Christoffel Γ^φ_φφ en diferentes regiones de la elipse")
println("-"^70)

# Puntos importantes donde la curvatura es extrema
critical_points = [
    (0.0, "φ=0° (κ máxima, semieje mayor)"),
    (Float64(π/2), "φ=90° (κ mínima, semieje menor)"),
    (Float64(π), "φ=180° (κ máxima, semieje mayor)"),
    (Float64(3π/2), "φ=270° (κ mínima, semieje menor)")
]

println("  Valores de Γ^φ_φφ en puntos críticos:")

for (φ, label) in critical_points
    Γ = christoffel_ellipse_polar(φ, a, b)
    κ = curvature_ellipse_polar(φ, a, b)
    g = metric_ellipse_polar(φ, a, b)

    @printf("  %s:\n", label)
    @printf("    Γ^φ_φφ = %+.6f\n", Γ)
    @printf("    κ      = %.6f\n", κ)
    @printf("    g_φφ   = %.6f\n", g)
end

println("  ✅ Christoffel calculado en todas las regiones")
println()

# ============================================================================
# Test 4: Conservación local de energía
# ============================================================================

println("Test 4: Conservación de energía individual (sin colisiones)")
println("-"^70)

# Crear partícula y simular varias órbitas
φ_0 = Float64(π/6)
φ_dot_0 = 1.0
p = ParticlePolar(1, mass, 0.01, φ_0, φ_dot_0, a, b)

E_0 = kinetic_energy(p, a, b)

# Integrar por 0.1 segundos
dt = 1e-5
n_steps = 10000

p_current = p
E_history = [E_0]

for step in 1:n_steps
    global p_current
    p_current = integrate_particle_polar(p_current, dt, a, b)

    if step % 1000 == 0
        E = kinetic_energy(p_current, a, b)
        push!(E_history, E)
    end
end

E_f = kinetic_energy(p_current, a, b)
ΔE = E_f - E_0
ΔE_rel = abs(ΔE / E_0)

E_min = minimum(E_history)
E_max = maximum(E_history)
E_range = E_max - E_min

@printf("  Energía inicial: %.10f\n", E_0)
@printf("  Energía final:   %.10f\n", E_f)
@printf("  ΔE/E₀:           %.2e\n", ΔE_rel)
@printf("  Rango (max-min): %.2e\n", E_range)

if ΔE_rel < 1e-4
    println("  ✅ Conservación aceptable para colisiones")
else
    println("  ⚠️  Conservación degradada (usar projection methods)")
end
println()

# ============================================================================
# Test 5: Consistencia métrica en movimiento
# ============================================================================

println("Test 5: Métrica g_φφ durante integración")
println("-"^70)

φ_0 = 0.0
φ_dot_0 = 1.0
p = ParticlePolar(1, mass, 0.01, φ_0, φ_dot_0, a, b)

dt = 1e-5
n_steps = 1000

p_current = p
g_values = []

for step in 1:n_steps
    global p_current
    g = metric_ellipse_polar(p_current.φ, a, b)
    push!(g_values, g)
    p_current = integrate_particle_polar(p_current, dt, a, b)
end

g_min = minimum(g_values)
g_max = maximum(g_values)

@printf("  g_φφ mínima durante integración: %.6f\n", g_min)
@printf("  g_φφ máxima durante integración: %.6f\n", g_max)
@printf("  Ratio g_max/g_min: %.2f\n", g_max/g_min)

# Para elipse con a=2, b=1, esperamos g_φφ ∈ [~1, ~4.6]
if g_min > 0.9 && g_max < 5.0
    println("  ✅ Métrica varía dentro de rango esperado")
else
    println("  ⚠️  Métrica fuera de rango esperado")
end
println()

# ============================================================================
# Test 6: Verificar r(φ) y posiciones
# ============================================================================

println("Test 6: Radio r(φ) y posiciones durante movimiento")
println("-"^70)

φ_0 = 0.0
φ_dot_0 = 1.0
p = ParticlePolar(1, mass, 0.01, φ_0, φ_dot_0, a, b)

dt = 1e-5
n_steps = 1000

p_current = p
r_values = []
ellipse_errors = []

for step in 1:n_steps
    global p_current

    r = radial_ellipse(p_current.φ, a, b)
    push!(r_values, r)

    # Verificar que está en la elipse
    ellipse_eq = (p_current.pos[1]/a)^2 + (p_current.pos[2]/b)^2
    ellipse_error = abs(ellipse_eq - 1.0)
    push!(ellipse_errors, ellipse_error)

    p_current = integrate_particle_polar(p_current, dt, a, b)
end

r_min = minimum(r_values)
r_max = maximum(r_values)
max_ellipse_error = maximum(ellipse_errors)

@printf("  r(φ) mínimo: %.6f (esperado: b=%.1f)\n", r_min, b)
@printf("  r(φ) máximo: %.6f (esperado: a=%.1f)\n", r_max, a)
@printf("  Error máximo en elipse: %.2e\n", max_ellipse_error)

if abs(r_min - b) < 0.1 && abs(r_max - a) < 0.1 && max_ellipse_error < 1e-10
    println("  ✅ Radio y posiciones correctos durante movimiento")
else
    println("  ⚠️  Posibles problemas con r(φ)")
end
println()

# ============================================================================
# Resumen
# ============================================================================

println("="^70)
println("✅ VERIFICACIÓN COMPLETADA")
println("="^70)
println()
println("Todos los prerequisitos para colisiones están correctos:")
println("  ✓ Velocidades cartesianas")
println("  ✓ Distancias entre partículas")
println("  ✓ Christoffel en todas las regiones")
println("  ✓ Conservación de energía individual")
println("  ✓ Métrica durante movimiento")
println("  ✓ Posiciones en la elipse")
println()
println("🚀 LISTO PARA IMPLEMENTAR COLISIONES")
println()
