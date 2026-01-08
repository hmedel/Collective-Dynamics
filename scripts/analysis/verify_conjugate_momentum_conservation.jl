"""
verify_conjugate_momentum_conservation.jl

Verifica analíticamente si el momento conjugado p_θ = m g(θ) θ̇
se conserva para geodésicas en una elipse.

Teoría:
Para que p_θ se conserve, necesitamos dp_θ/dt = 0

dp_θ/dt = d/dt[m g(θ) θ̇]
        = m [g'(θ) θ̇² + g(θ) θ̈]

Para geodésicas: θ̈ = -Γ^θ_θθ θ̇²

Entonces: dp_θ/dt = m θ̇² [g'(θ) - g(θ) Γ^θ_θθ]

Para conservación: g'(θ) = g(θ) Γ^θ_θθ
"""

using CollectiveDynamics
using Printf

# Geometría
a = 2.0
b = 1.0

println("="^80)
println("VERIFICACIÓN TEÓRICA: ¿Se conserva p_θ = m g(θ) θ̇?")
println("="^80)
println()
println("Para una elipse con a = $a, b = $b")
println()

# Función métrica
g(θ) = a^2 * sin(θ)^2 + b^2 * cos(θ)^2

# Derivada de la métrica
function g_prime(θ)
    return 2 * a^2 * sin(θ) * cos(θ) - 2 * b^2 * cos(θ) * sin(θ)
end

# Símbolo de Christoffel
function Γ(θ)
    return (a^2 - b^2) * sin(θ) * cos(θ) / (a^2 * sin(θ)^2 + b^2 * cos(θ)^2)
end

# Verificar en varios puntos
println("Verificación en diferentes ángulos:")
println()
println(@sprintf("%-10s | %-15s | %-15s | %-15s | %s",
                 "θ", "g'(θ)", "g(θ)·Γ(θ)", "Diferencia", "¿Conserva?"))
println("-"^80)

test_angles = [0.0, π/6, π/4, π/3, π/2, 2π/3, 3π/4, 5π/6, π]

max_diff = 0.0
for θ in test_angles
    g_val = g(θ)
    g_prime_val = g_prime(θ)
    Γ_val = Γ(θ)

    lhs = g_prime_val
    rhs = g_val * Γ_val

    diff = abs(lhs - rhs)
    max_diff = max(max_diff, diff)

    conserves = diff < 1e-10
    status = conserves ? "✅ Sí" : "❌ No"

    println(@sprintf("%-10.6f | %+15.8e | %+15.8e | %15.8e | %s",
                     θ, lhs, rhs, diff, status))
end

println()
println("="^80)
println("CONCLUSIÓN TEÓRICA")
println("="^80)
println()

if max_diff < 1e-10
    println("✅ El momento conjugado p_θ = m g(θ) θ̇ SÍ se conserva")
    println()
    println("   Para todas las posiciones en la elipse:")
    println("   g'(θ) = g(θ) Γ^θ_θθ")
    println()
    println("   Por lo tanto: dp_θ/dt = m θ̇² [g'(θ) - g(θ)Γ] = 0")
else
    println("❌ El momento conjugado p_θ = m g(θ) θ̇ NO se conserva")
    println()
    println("   Discrepancia máxima: $(max_diff)")
    println()
    println("   La condición g'(θ) = g(θ) Γ^θ_θθ NO se satisface")
    println()
    println("   Por lo tanto: dp_θ/dt ≠ 0")
    println()
    println("   📌 Esto explica el error constante de ~9.5e-04 observado")
    println("      El error NO es numérico, es físico/matemático")
end

println()
println("="^80)
println("ANÁLISIS DETALLADO")
println("="^80)
println()

# Análisis más detallado
println("Calculemos explícitamente g'(θ) y g(θ)·Γ(θ):")
println()
println("g(θ) = a² sin²(θ) + b² cos²(θ)")
println("     = $(a^2) sin²(θ) + $(b^2) cos²(θ)")
println()
println("g'(θ) = 2a² sin(θ)cos(θ) - 2b² cos(θ)sin(θ)")
println("      = 2(a² - b²) sin(θ)cos(θ)")
println("      = 2($(a^2) - $(b^2)) sin(θ)cos(θ)")
println("      = $(2*(a^2 - b^2)) sin(θ)cos(θ)")
println()
println("Γ^θ_θθ = (a² - b²) sin(θ)cos(θ) / [a² sin²(θ) + b² cos²(θ)]")
println("       = $(a^2 - b^2) sin(θ)cos(θ) / g(θ)")
println()
println("g(θ)·Γ(θ) = (a² - b²) sin(θ)cos(θ)")
println("          = $(a^2 - b^2) sin(θ)cos(θ)")
println()
println("Comparación:")
println("  g'(θ)     = $(2*(a^2 - b^2)) sin(θ)cos(θ)")
println("  g(θ)·Γ(θ) = $(a^2 - b^2) sin(θ)cos(θ)")
println()

ratio = 2*(a^2 - b^2) / (a^2 - b^2)
println("  Ratio: g'(θ) / [g(θ)·Γ(θ)] = $(ratio)")
println()

if abs(ratio - 2.0) < 1e-10
    println("  ❗ Hay un factor de 2 de diferencia")
    println()
    println("  Esto significa:")
    println("    dp_θ/dt = m θ̇² [g'(θ) - g(θ)Γ]")
    println("            = m θ̇² [(a²-b²)sin(θ)cos(θ)]")
    println("            ≠ 0")
    println()
    println("  El momento conjugado NO se conserva exactamente")
end

println()
println("="^80)
println("PRUEBA NUMÉRICA")
println("="^80)
println()

# Prueba numérica con una partícula
using Random
Random.seed!(42)

θ₀ = π/4
θ̇₀ = 0.5
m = 1.0

p = initialize_particle(1, m, 0.05, θ₀, θ̇₀, a, b)
p_θ_initial = conjugate_momentum(p, a, b)

println("Partícula de prueba:")
println("  θ₀ = $(θ₀)")
println("  θ̇₀ = $(θ̇₀)")
println("  p_θ inicial = $(p_θ_initial)")
println()

# Integrar un paso muy pequeño
dt = 1e-10
θ₁, θ̇₁ = forest_ruth_step_ellipse(θ₀, θ̇₀, dt, a, b)

p_new = Particle(
    id = 1,
    mass = m,
    radius = 0.05,
    θ = θ₁,
    θ_dot = θ̇₁,
    pos = SVector{2,Float64}(a * cos(θ₁), b * sin(θ₁)),
    vel = SVector{2,Float64}(0.0, 0.0)  # No importa para este test
)

p_θ_final = conjugate_momentum(p_new, a, b)

Δp_θ = p_θ_final - p_θ_initial
rate = Δp_θ / dt

println("Después de dt = $(dt):")
println("  θ₁ = $(θ₁)")
println("  θ̇₁ = $(θ̇₁)")
println("  p_θ final = $(p_θ_final)")
println("  Δp_θ = $(Δp_θ)")
println("  dp_θ/dt ≈ $(rate)")
println()

# Calcular teóricamente dp_θ/dt
g_val = g(θ₀)
g_prime_val = g_prime(θ₀)
Γ_val = Γ(θ₀)

dp_dt_theory = m * θ̇₀^2 * (g_prime_val - g_val * Γ_val)

println("Comparación con teoría:")
println("  dp_θ/dt numérico:  $(rate)")
println("  dp_θ/dt teórico:   $(dp_dt_theory)")
println("  Diferencia:        $(abs(rate - dp_dt_theory))")
println()

if abs(rate - dp_dt_theory) < 1e-6
    println("  ✅ El integrador calcula correctamente dp_θ/dt")
else
    println("  ❌ Posible error en el integrador")
end

println()
println("="^80)
