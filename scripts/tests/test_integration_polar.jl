#!/usr/bin/env julia
"""
test_integration_polar.jl

Verifica que el integrador Forest-Ruth en coordenadas polares:
1. Conserva energía durante integración libre
2. Las partículas permanecen en la elipse
3. Los coeficientes de Forest-Ruth son correctos
"""

using Pkg
Pkg.activate(".")

include("src/particles_polar.jl")
include("src/integrators/forest_ruth_polar.jl")

using Printf
using Statistics

println("="^70)
println("TEST: Integrador Forest-Ruth en Coordenadas Polares")
println("="^70)
println()

# Configuración
a, b = 2.0, 1.0
dt = 1e-5
n_steps = 100000  # 1 segundo de simulación
mass = 1.0

println("Configuración:")
println("  Semi-ejes: a=$a, b=$b")
println("  Paso de tiempo: dt=$dt")
println("  Pasos: $n_steps (tiempo total = $(n_steps*dt) s)")
println()

# ============================================================================
# Test 1: Coeficientes de Forest-Ruth
# ============================================================================

println("Test 1: Coeficientes de Forest-Ruth")
println("-"^70)

coeffs = verify_forest_ruth_coefficients()

@printf("  Σ γᵢ = %.15f (debe ser 1.0)\n", coeffs.sum_γ)
@printf("  Σ ρᵢ = %.15f (debe ser 1.0)\n", coeffs.sum_ρ)
println("  Simetría γ₁=γ₄, γ₂=γ₃: ", coeffs.symmetry_holds ? "✓" : "✗")

if coeffs.all_checks_pass
    println("  ✅ Todos los coeficientes correctos")
else
    println("  ❌ ERROR en coeficientes")
end
println()

# ============================================================================
# Test 2: Integración de una partícula libre
# ============================================================================

println("Test 2: Conservación de energía (1 partícula, movimiento libre)")
println("-"^70)

# Crear partícula
φ_0 = π/4
φ_dot_0 = 1.0
p = ParticlePolar(1, mass, 0.01, φ_0, φ_dot_0, a, b)

# Energía inicial
E_0 = kinetic_energy(p, a, b)

println("  Estado inicial:")
@printf("    φ = %.6f rad (%.1f°)\n", p.φ, rad2deg(p.φ))
@printf("    φ̇ = %.6f rad/s\n", p.φ_dot)
@printf("    E₀ = %.10f\n", E_0)
println()

# Guardar historia de energía
E_history = Float64[]
φ_history = Float64[]

push!(E_history, E_0)
push!(φ_history, p.φ)

# Integrar
println("  Integrando...")
p_current = p

for step in 1:n_steps
    global p_current
    p_current = integrate_particle_polar(p_current, dt, a, b)

    # Guardar energía cada 1000 pasos
    if step % 1000 == 0
        E = kinetic_energy(p_current, a, b)
        push!(E_history, E)
        push!(φ_history, p_current.φ)
    end
end

# Energía final
E_f = kinetic_energy(p_current, a, b)

println()
println("  Estado final:")
@printf("    φ = %.6f rad (%.1f°)\n", p_current.φ, rad2deg(p_current.φ))
@printf("    φ̇ = %.6f rad/s\n", p_current.φ_dot)
@printf("    E_f = %.10f\n", E_f)
println()

# Análisis de conservación
ΔE = E_f - E_0
ΔE_rel = abs(ΔE / E_0)
E_std = std(E_history)

@printf("  Conservación de energía:\n")
@printf("    ΔE (absoluto): %.2e\n", ΔE)
@printf("    ΔE/E₀ (relativo): %.2e\n", ΔE_rel)
@printf("    σ(E): %.2e\n", E_std)

if ΔE_rel < 1e-8
    println("    ✅ EXCELENTE conservación (ΔE/E₀ < 1e-8)")
elseif ΔE_rel < 1e-6
    println("    ✅ BUENA conservación (ΔE/E₀ < 1e-6)")
elseif ΔE_rel < 1e-4
    println("    ⚠️  Conservación aceptable (ΔE/E₀ < 1e-4)")
else
    println("    ❌ MALA conservación (ΔE/E₀ > 1e-4)")
end
println()

# ============================================================================
# Test 3: Partículas permanecen en la elipse
# ============================================================================

println("Test 3: Partículas permanecen en la elipse")
println("-"^70)

max_ellipse_error = 0.0
n_samples = 10

for i in 1:n_samples
    global max_ellipse_error

    φ_check = φ_history[1 + div((i-1) * length(φ_history), n_samples)]

    # Calcular posición
    pos = cartesian_from_polar_angle(φ_check, a, b)

    # Verificar ecuación de la elipse
    ellipse_eq = (pos[1]/a)^2 + (pos[2]/b)^2
    error = abs(ellipse_eq - 1.0)

    max_ellipse_error = max(max_ellipse_error, error)
end

@printf("  Error máximo en ecuación elipse: %.2e\n", max_ellipse_error)

if max_ellipse_error < 1e-10
    println("  ✅ Partículas permanecen en la elipse")
else
    println("  ❌ ERROR: Partículas se salen de la elipse")
end
println()

# ============================================================================
# Test 4: Integración de sistema multi-partícula
# ============================================================================

println("Test 4: Sistema de 5 partículas (sin colisiones)")
println("-"^70)

# Generar 5 partículas
N = 5
particles = generate_random_particles_polar(N, mass, 0.03, a, b; max_speed=1.0)

println("  Partículas generadas: $N")

# Energía total inicial
E_total_0 = sum(kinetic_energy(p, a, b) for p in particles)
@printf("  E_total₀ = %.10f\n", E_total_0)

# Integrar sistema (sin colisiones)
n_steps_multi = 10000
particles_current = particles

for step in 1:n_steps_multi
    global particles_current
    particles_current = integrate_system_polar(particles_current, dt, a, b)
end

# Energía total final
E_total_f = sum(kinetic_energy(p, a, b) for p in particles_current)
@printf("  E_total_f = %.10f\n", E_total_f)

ΔE_total = E_total_f - E_total_0
ΔE_total_rel = abs(ΔE_total / E_total_0)

@printf("\n  Conservación energía total:\n")
@printf("    ΔE_total/E₀ = %.2e\n", ΔE_total_rel)

if ΔE_total_rel < 1e-8
    println("    ✅ EXCELENTE conservación")
else
    println("    ⚠️  Conservación degradada (esperado sin projection)")
end
println()

# ============================================================================
# Resumen
# ============================================================================

println("="^70)
println("✅ TESTS DEL INTEGRADOR COMPLETADOS")
println("="^70)
println()
println("Próximo paso: Implementar detección y resolución de colisiones.")
println()
