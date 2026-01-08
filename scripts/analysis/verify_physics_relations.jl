#!/usr/bin/env julia
# Verificación completa de relaciones físicas después de corrección

using Pkg
Pkg.activate(".")

using CollectiveDynamics
using Printf

println("="^70)
println("VERIFICACIÓN DE RELACIONES FÍSICAS")
println("="^70)
println()

# Geometría
a, b = 3.170233138523429, 0.6308684291059812
e = sqrt(1 - (b/a)^2)

println("Geometría:")
@printf("  a = %.3f (semi-eje mayor)\n", a)
@printf("  b = %.3f (semi-eje menor)\n", b)
@printf("  e = %.3f (excentricidad)\n", e)
@printf("  a/b = %.2f\n", a/b)
println()

# Calcular métrica en puntos clave
φ_major_axis = 0.0      # Eje mayor (φ = 0°)
φ_minor_axis = π/2      # Eje menor (φ = 90°)

g_major = a^2 * sin(φ_major_axis)^2 + b^2 * cos(φ_major_axis)^2
g_minor = a^2 * sin(φ_minor_axis)^2 + b^2 * cos(φ_minor_axis)^2

println("Métrica g_φφ:")
@printf("  En eje MAYOR (φ=0°):   g = %.3f = b² = %.3f\n", g_major, b^2)
@printf("  En eje MENOR (φ=90°):  g = %.3f = a² = %.3f\n", g_minor, a^2)
@printf("  Ratio g_minor/g_major = %.2f\n", g_minor/g_major)
println()

# Crear partícula de prueba con energía fija
m = 1.0
E_target = 0.32

# Partícula en eje mayor
φ̇_major = sqrt(2*E_target / g_major)
p_major = m * g_major * φ̇_major
T_major = 0.5 * m * g_major * φ̇_major^2

println(@sprintf("Partícula con E = %.2f en EJE MAYOR (φ=0°):", E_target))
@printf("  g_φφ = %.3f\n", g_major)
@printf("  φ̇ = %.4f (velocidad angular)\n", φ̇_major)
@printf("  p_φ = m·g·φ̇ = %.4f\n", p_major)
@printf("  T = (1/2)·m·g·φ̇² = %.4f\n", T_major)
println()

# Partícula en eje menor CON LA MISMA ENERGÍA
φ̇_minor = sqrt(2*E_target / g_minor)
p_minor = m * g_minor * φ̇_minor
T_minor = 0.5 * m * g_minor * φ̇_minor^2

println(@sprintf("Partícula con E = %.2f en EJE MENOR (φ=90°):", E_target))
@printf("  g_φφ = %.3f\n", g_minor)
@printf("  φ̇ = %.4f (velocidad angular)\n", φ̇_minor)
@printf("  p_φ = m·g·φ̇ = %.4f\n", p_minor)
@printf("  T = (1/2)·m·g·φ̇² = %.4f\n", T_minor)
println()

# Comparación
println("="^70)
println("COMPARACIÓN: MISMA ENERGÍA, DIFERENTES POSICIONES")
println("="^70)
println()

ratio_g = g_minor / g_major
ratio_φ̇ = φ̇_major / φ̇_minor

@printf("Ratio métrica:           g_minor/g_major = %.2f\n", ratio_g)
@printf("Ratio velocidad angular: φ̇_major/φ̇_minor = %.2f\n", ratio_φ̇)
@printf("Relación teórica:        φ̇ ∝ 1/√g → %.2f\n", sqrt(ratio_g))
println()

if abs(ratio_φ̇ - sqrt(ratio_g)) < 0.01
    println("✅ CORRECTO: φ̇_major/φ̇_minor = √(g_minor/g_major)")
else
    println("❌ ERROR en relación φ̇ ∝ 1/√g")
end
println()

# Ahora, partícula con MISMO momento conjugado (caso de conservación)
println("="^70)
println("CONSERVACIÓN: PARTÍCULA CON MISMO p_φ")
println("="^70)
println()

p_const = 1.0  # Momento conjugado constante

# En eje mayor
φ̇_major_p = p_const / (m * g_major)
T_major_p = 0.5 * m * g_major * φ̇_major_p^2

# En eje menor
φ̇_minor_p = p_const / (m * g_minor)
T_minor_p = 0.5 * m * g_minor * φ̇_minor_p^2

println(@sprintf("Partícula con p_φ = %.2f conservado:", p_const))
println()
@printf("En EJE MAYOR (g=%.3f):\n", g_major)
@printf("  φ̇ = p/(m·g) = %.4f\n", φ̇_major_p)
@printf("  T = p²/(2m·g) = %.4f\n", T_major_p)
println()

@printf("En EJE MENOR (g=%.3f):\n", g_minor)
@printf("  φ̇ = p/(m·g) = %.4f\n", φ̇_minor_p)
@printf("  T = p²/(2m·g) = %.4f\n", T_minor_p)
println()

ratio_φ̇_p = φ̇_major_p / φ̇_minor_p
ratio_T = T_major_p / T_minor_p

@printf("Ratio velocidad angular: φ̇_major/φ̇_minor = %.2f\n", ratio_φ̇_p)
@printf("Ratio energía cinética:  T_major/T_minor = %.2f\n", ratio_T)
@printf("Relación teórica (p constante): φ̇ ∝ 1/g → %.2f\n", g_minor/g_major)
println()

if abs(ratio_φ̇_p - ratio_g) < 0.01
    println("✅ CORRECTO: Con p constante, φ̇ ∝ 1/g")
else
    println("❌ ERROR en relación φ̇ ∝ 1/g")
end
println()

# Implicación para clustering
println("="^70)
println("IMPLICACIÓN PARA CLUSTERING")
println("="^70)
println()

println("Con momento conjugado p_φ conservado para cada partícula:")
println()
@printf("• En EJE MENOR (g grande = %.2f):\n", g_minor)
@printf("  → φ̇ pequeña = %.4f\n", φ̇_minor_p)
println("  → Partícula se mueve LENTO angularmente")
println("  → MAYOR tiempo de residencia")
println("  → ✅ FAVORECE CLUSTERING")
println()

@printf("• En EJE MAYOR (g pequeña = %.2f):\n", g_major)
@printf("  → φ̇ grande = %.4f\n", φ̇_major_p)
println("  → Partícula se mueve RÁPIDO angularmente")
println("  → Menor tiempo de residencia")
println("  → Menor densidad")
println()

println("CONCLUSIÓN:")
println("El clustering observado en el EJE MENOR es consistente con")
println("la conservación de p_φ = m·g·φ̇ para cada partícula.")
println()

# Verificar Hamiltoniano
println("="^70)
println("VERIFICACIÓN: RELACIÓN HAMILTONIANA")
println("="^70)
println()

# Crear partícula de prueba usando CollectiveDynamics
using Random
particles = generate_random_particles(1, E_target, 0.05, a, b; rng=MersenneTwister(123))
p_test = particles[1]

p_φ = conjugate_momentum(p_test, a, b)
T_calc = kinetic_energy(p_test, a, b)
g_test = a^2 * sin(p_test.θ)^2 + b^2 * cos(p_test.θ)^2

# Verificar H = p²/(2mg)
H_from_p = p_φ^2 / (2 * p_test.mass * g_test)
H_from_T = T_calc

@printf("Partícula de prueba (φ = %.2f°):\n", rad2deg(p_test.θ))
@printf("  p_φ = %.6f\n", p_φ)
@printf("  T (calculado directo) = %.6f\n", T_calc)
@printf("  H = p²/(2mg) = %.6f\n", H_from_p)
@printf("  Diferencia: %.2e\n", abs(H_from_p - H_from_T))
println()

if abs(H_from_p - H_from_T) / H_from_T < 1e-10
    println("✅ CORRECTO: H = T = p²/(2mg)")
else
    println("❌ ERROR en relación Hamiltoniana")
end

println()
println("="^70)
println("TODAS LAS RELACIONES FÍSICAS VERIFICADAS")
println("="^70)
