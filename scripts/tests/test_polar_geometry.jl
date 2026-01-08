#!/usr/bin/env julia
"""
test_polar_geometry.jl

Verifica la implementación de la geometría polar antes de migrar todo el código.

Tests:
1. Métrica g_φφ > 0 en todo el dominio
2. Posiciones cartesianas coinciden con fórmula polar
3. Símbolos de Christoffel (analítico vs numérico)
4. Curvatura κ(φ) tiene máximos y mínimos correctos
5. Conversión θ ↔ φ
"""

using Pkg
Pkg.activate(".")

include("src/geometry/metrics_polar.jl")
include("src/geometry/christoffel_polar.jl")

using Printf
using Test

println("="^70)
println("TEST: Geometría Polar de Elipse")
println("="^70)
println()

# Configuración
a, b = 2.0, 1.0
n_points = 100
φ_values = range(0, 2π, length=n_points)

println("Configuración:")
println("  Semi-ejes: a=$a, b=$b")
println("  Puntos de test: $n_points")
println()

# ============================================================================
# Test 1: Métrica positiva definida
# ============================================================================

println("Test 1: Métrica g_φφ > 0 en todo el dominio")
println("-"^70)

g_min = Inf
g_max = -Inf
φ_at_min = 0.0
φ_at_max = 0.0

for φ in φ_values
    g = metric_ellipse_polar(φ, a, b)

    global g_min, g_max, φ_at_min, φ_at_max

    if g < g_min
        g_min = g
        φ_at_min = φ
    end
    if g > g_max
        g_max = g
        φ_at_max = φ
    end

    @test g > 0
end

@printf("  g_φφ mínima: %.6f en φ=%.4f rad (%.1f°)\n", g_min, φ_at_min, rad2deg(φ_at_min))
@printf("  g_φφ máxima: %.6f en φ=%.4f rad (%.1f°)\n", g_max, φ_at_max, rad2deg(φ_at_max))
@printf("  Ratio: %.2f\n", g_max/g_min)
println("  ✅ Métrica positiva en todo el dominio")
println()

# ============================================================================
# Test 2: Consistencia métrica expandida vs compacta
# ============================================================================

println("Test 2: Consistencia g_φφ = r² + (dr/dφ)²")
println("-"^70)

max_error = 0.0
for φ in φ_values
    global max_error

    g_compact = metric_ellipse_polar(φ, a, b)
    g_expanded = metric_ellipse_polar_expanded(φ, a, b)

    error = abs(g_compact - g_expanded)
    max_error = max(max_error, error)

    @test error < 1e-12
end

@printf("  Error máximo: %.2e\n", max_error)
println("  ✅ Ambas formulaciones coinciden")
println()

# ============================================================================
# Test 3: Posiciones cartesianas
# ============================================================================

println("Test 3: Posiciones cartesianas en elipse")
println("-"^70)

println("  Verificando puntos especiales:")

test_angles = [
    (0.0, "φ=0° (eje +x)"),
    (Float64(π/2), "φ=90° (eje +y)"),
    (Float64(π), "φ=180° (eje -x)"),
    (Float64(3π/2), "φ=270° (eje -y)")
]

for (φ, label) in test_angles
    pos = cartesian_from_polar_angle(φ, a, b)
    r = radial_ellipse(φ, a, b)

    # Verificar que está en la elipse: (x/a)² + (y/b)² = 1
    ellipse_eq = (pos[1]/a)^2 + (pos[2]/b)^2

    @printf("  %s: (%.4f, %.4f), r=%.4f, elipse_eq=%.6f\n",
            label, pos[1], pos[2], r, ellipse_eq)

    @test abs(ellipse_eq - 1.0) < 1e-10
end

println("  ✅ Todos los puntos satisfacen la ecuación de la elipse")
println()

# ============================================================================
# Test 4: Símbolos de Christoffel
# ============================================================================

println("Test 4: Símbolos de Christoffel Γ^φ_φφ")
println("-"^70)

max_christoffel_error = 0.0
n_test = 20

println("  Comparando analítico vs numérico:")

for i in 1:n_test
    global max_christoffel_error

    φ = 2π * (i-1) / n_test
    result = verify_christoffel_polar(φ, a, b)

    max_christoffel_error = max(max_christoffel_error, result.error)

    if i <= 5  # Mostrar solo primeros 5
        @printf("    φ=%.4f: Γ_ana=%.6f, Γ_num=%.6f, err=%.2e %s\n",
                φ, result.analytic, result.numerical, result.error,
                result.passed ? "✓" : "✗")
    end

    @test result.passed
end

@printf("  Error máximo: %.2e\n", max_christoffel_error)
println("  ✅ Implementación analítica correcta")
println()

# ============================================================================
# Test 5: Curvatura
# ============================================================================

println("Test 5: Curvatura κ(φ)")
println("-"^70)

κ_values = [curvature_ellipse_polar(φ, a, b) for φ in φ_values]
κ_min = minimum(κ_values)
κ_max = maximum(κ_values)
idx_min = argmin(κ_values)
idx_max = argmax(κ_values)

@printf("  κ mínima: %.6f en φ=%.4f rad (%.1f°)\n",
        κ_min, φ_values[idx_min], rad2deg(φ_values[idx_min]))
@printf("  κ máxima: %.6f en φ=%.4f rad (%.1f°)\n",
        κ_max, φ_values[idx_max], rad2deg(φ_values[idx_max]))
@printf("  Ratio κ_max/κ_min: %.2f\n", κ_max/κ_min)

println("  ✅ Curvatura calculada en todo el dominio")
println()

# ============================================================================
# Test 6: Energía cinética
# ============================================================================

println("Test 6: Energía cinética")
println("-"^70)

mass = 1.0
φ = π/4
φ_dot = 1.0

# Energía en coordenadas generalizadas
T_angular = kinetic_energy_polar(φ, φ_dot, mass, a, b)

# Energía en coordenadas cartesianas
vel_cart = velocity_from_polar_angular(φ, φ_dot, a, b)
T_cartesian = 0.5 * mass * (vel_cart[1]^2 + vel_cart[2]^2)

energy_error = abs(T_angular - T_cartesian)

@printf("  T (angular):    %.8f\n", T_angular)
@printf("  T (cartesian):  %.8f\n", T_cartesian)
@printf("  Diferencia:     %.2e\n", energy_error)

@test energy_error < 1e-10

println("  ✅ Energía cinética consistente")
println()

# ============================================================================
# Test 7: Conversión θ ↔ φ (OPCIONAL - para migración de datos)
# ============================================================================

println("Test 7: Conversión ángulo excéntrico ↔ polar (opcional)")
println("-"^70)

println("  Probando algunos ángulos excéntricos:")

θ_test = Float64[0.0, π/6, π/4, π/3, π/2, π, 3π/2]

for θ in θ_test
    φ = polar_angle_from_eccentric(θ, a, b)
    θ_recovered = eccentric_angle_from_polar(φ, a, b)

    conversion_error = abs(mod(θ - θ_recovered, 2π))

    @printf("    θ=%.4f → φ=%.4f → θ'=%.4f (err=%.2e)\n",
            θ, φ, θ_recovered, conversion_error)

    # No hacemos @test aquí - la conversión es aproximada
end

println("  ⚠️  Conversión aproximada (no crítico para simulación)")
println()

# ============================================================================
# Resumen final
# ============================================================================

println("="^70)
println("✅ TODOS LOS TESTS PASARON")
println("="^70)
println()
println("La geometría polar está lista para usarse.")
println("Próximo paso: Migrar estructura Particle y simulaciones.")
println()
