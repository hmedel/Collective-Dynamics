#!/usr/bin/env julia
# Verificación de la relación curvatura-velocidad en parametrización polar

using Printf

# Parámetros de la elipse
a, b = 2.0, 1.0

# Funciones básicas de geometría
function radial_ellipse(φ, a, b)
    s, c = sincos(φ)
    return a * b / sqrt(a^2 * s^2 + b^2 * c^2)
end

function radial_derivative_ellipse(φ, a, b)
    s, c = sincos(φ)
    S = a^2 * s^2 + b^2 * c^2
    sin2φ = sin(2φ)
    return -a * b * (a^2 - b^2) * sin2φ / (2 * S^(3/2))
end

function metric_ellipse_polar(φ, a, b)
    r = radial_ellipse(φ, a, b)
    dr_dφ = radial_derivative_ellipse(φ, a, b)
    return dr_dφ^2 + r^2
end

function geometric_curvature(φ, a, b)
    s, c = sincos(φ)
    S = a^2 * s^2 + b^2 * c^2
    return a * b / S^(3/2)
end

# Calcular en puntos clave
println("="^70)
println("RELACIÓN CURVATURA-VELOCIDAD EN ELIPSE (a=$a, b=$b)")
println("="^70)
println()

angles = [
    (0.0, "Eje mayor (+x)"),
    (π/2, "Eje menor (+y)"),
    (π, "Eje mayor (-x)"),
    (3π/2, "Eje menor (-y)")
]

for (φ, label) in angles
    r = radial_ellipse(φ, a, b)
    dr_dφ = radial_derivative_ellipse(φ, a, b)
    g_φφ = metric_ellipse_polar(φ, a, b)
    κ = geometric_curvature(φ, a, b)

    # Velocidad tangencial proporcional a √g_φφ (si φ̇ constante)
    v_tangent_rel = sqrt(g_φφ)

    println("φ = $(label)")
    @printf("  r(φ) = %.4f\n", r)
    @printf("  dr/dφ = %.4f\n", dr_dφ)
    @printf("  g_φφ = %.4f\n", g_φφ)
    @printf("  κ (curvatura geométrica) = %.4f\n", κ)
    @printf("  v_tangent ∝ √g_φφ = %.4f\n", v_tangent_rel)
    println()
end

println("="^70)
println("RESULTADO CLAVE:")
println("="^70)
println()
println("En el EJE MENOR (φ = π/2, 3π/2):")
println("  • r es MÍNIMO (r = $b)")
println("  • g_φφ es MÍNIMO")
println("  • Velocidad tangencial es MÍNIMA")
println("  • Pero κ (curvatura geométrica) es MÍNIMA (~0.25)")
println()
println("En el EJE MAYOR (φ = 0, π):")
println("  • r es MÁXIMO (r = $a)")
println("  • g_φφ es MÁXIMO")
println("  • Velocidad tangencial es MÁXIMA")
println("  • Y κ (curvatura geométrica) es MÁXIMA (~2.0)")
println()
println("="^70)
println("CONCLUSIÓN:")
println("="^70)
println()
println("❌ INCORRECTO: 'Alta curvatura → velocidad baja'")
println()
println("✅ CORRECTO: 'r pequeño → g_φφ pequeño → velocidad baja'")
println()
println("El clustering ocurre en el EJE MENOR donde:")
println("  1. r es pequeño")
println("  2. g_φφ es pequeño")
println("  3. Velocidad tangencial es baja")
println("  4. Pero la curvatura geométrica κ es BAJA (no alta!)")
println()
println("El mecanismo NO es causado por alta curvatura geométrica,")
println("sino por el radio pequeño que genera una métrica pequeña.")
println("="^70)
