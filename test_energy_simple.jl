"""
Test simple de conservación de energía SIN colisiones
"""

using Pkg
Pkg.activate(".")

using CollectiveDynamics
using Printf

println("="^70)
println("TEST: Conservación de energía SIN colisiones")
println("="^70)

# Parámetros
a, b = 2.0, 1.0
dt = 1e-5
n_steps = 10000

# Crear UNA partícula (sin posibilidad de colisiones)
p = initialize_particle(1, 1.0, 0.01, π/4, 0.5, a, b)
println("\nPartícula inicial:")
println("  θ = $(p.θ)")
println("  θ_dot = $(p.θ_dot)")

# Energía inicial
E0 = kinetic_energy(p, a, b)
println("  E₀ = $E0")

# Vector para guardar energías
energies = Float64[]
push!(energies, E0)

# Simular sin colisiones
θ, θ_dot = p.θ, p.θ_dot
for step in 1:n_steps
    θ, θ_dot = forest_ruth_step_ellipse(θ, θ_dot, dt, a, b)

    if step % 1000 == 0
        # Calcular energía
        g = metric_ellipse(θ, a, b)
        E = 0.5 * p.mass * g * θ_dot^2
        push!(energies, E)

        ΔE = abs(E - E0)
        rel_error = ΔE / E0

        println(@sprintf("Step %5d: E = %.10f, ΔE/E₀ = %.2e", step, E, rel_error))
    end
end

# Energía final
g_final = metric_ellipse(θ, a, b)
E_final = 0.5 * p.mass * g_final * θ_dot^2
ΔE_total = abs(E_final - E0)
rel_error_total = ΔE_total / E0

println("\n" * "="^70)
println("RESULTADO:")
println("  E₀      = $(E0)")
println("  E_final = $(E_final)")
println("  ΔE      = $(ΔE_total)")
println("  ΔE/E₀   = $(rel_error_total)")
println("="^70)

if rel_error_total < 1e-6
    println("\n✅ EXCELENTE: Conservación de energía < 1e-6")
elseif rel_error_total < 1e-4
    println("\n✅ BUENO: Conservación de energía < 1e-4")
elseif rel_error_total < 1e-2
    println("\n⚠️  ACEPTABLE: Conservación de energía < 1e-2")
else
    println("\n❌ PROBLEMA: Conservación de energía > 1e-2")
end
