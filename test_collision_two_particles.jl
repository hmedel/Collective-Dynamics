"""
Test de conservación de energía con DOS partículas colisionando
"""

using Pkg
Pkg.activate(".")

using CollectiveDynamics
using Printf

println("="^70)
println("TEST: Conservación de energía con 2 partículas colisionando")
println("="^70)

# Parámetros
a, b = 2.0, 1.0
dt = 1e-5
n_steps = 1000

# Crear DOS partículas que van a colisionar
# Partícula 1: moviéndose hacia la derecha
p1 = initialize_particle(1, 1.0, 0.1, π/4, 0.5, a, b)
# Partícula 2: moviéndose hacia la izquierda (va a colisionar con p1)
p2 = initialize_particle(2, 1.0, 0.1, π/4 + 0.3, -0.5, a, b)

particles = [p1, p2]

println("\nPartículas iniciales:")
println("  p1: θ=$(p1.θ), θ_dot=$(p1.θ_dot)")
println("  p2: θ=$(p2.θ), θ_dot=$(p2.θ_dot)")

# Energía y momento inicial
E0 = total_energy(particles, a, b)
p0 = angular_momentum(particles[1], a, b) + angular_momentum(particles[2], a, b)

println("\nCantidades conservadas iniciales:")
println("  E₀ = $E0")
println("  p₀ = $p0")

# Vectores para guardar
energies = Float64[]
momenta = Float64[]
n_collisions_total = 0

push!(energies, E0)
push!(momenta, p0)

# Simular
for step in 1:n_steps
    # Paso 1: Integrar
    for i in 1:length(particles)
        p = particles[i]
        θ_new, θ_dot_new = forest_ruth_step_ellipse(p.θ, p.θ_dot, dt, a, b)
        particles[i] = update_particle(p, θ_new, θ_dot_new, a, b)
    end

    # Paso 2: Resolver colisiones
    n_coll, conserved_frac = resolve_all_collisions!(
        particles, a, b;
        method=:simple,  # Usar nuestro método mejorado
        dt=dt,
        tolerance=1e-8
    )

    n_collisions_total += n_coll

    # Guardar cada 100 pasos
    if step % 100 == 0
        E = total_energy(particles, a, b)
        p_total = angular_momentum(particles[1], a, b) + angular_momentum(particles[2], a, b)

        push!(energies, E)
        push!(momenta, p_total)

        ΔE = abs(E - E0)
        Δp = abs(p_total - p0)
        rel_error_E = ΔE / E0
        rel_error_p = Δp / abs(p0)

        println(@sprintf("Step %4d: E=%.10f (ΔE/E₀=%.2e), p=%.6f (Δp/p₀=%.2e), colisiones=%d",
                step, E, rel_error_E, p_total, rel_error_p, n_coll))
    end
end

# Resultado final
E_final = total_energy(particles, a, b)
p_final = angular_momentum(particles[1], a, b) + angular_momentum(particles[2], a, b)

ΔE_total = abs(E_final - E0)
Δp_total = abs(p_final - p0)
rel_error_E = ΔE_total / E0
rel_error_p = Δp_total / abs(p0)

println("\n" * "="^70)
println("RESULTADO:")
println("  Colisiones totales: $n_collisions_total")
println("\nEnergía:")
println("  E₀      = $E0")
println("  E_final = $E_final")
println("  ΔE      = $ΔE_total")
println("  ΔE/E₀   = $rel_error_E")
println("\nMomento generalizado:")
println("  p₀      = $p0")
println("  p_final = $p_final")
println("  Δp      = $Δp_total")
println("  Δp/p₀   = $rel_error_p")
println("="^70)

if rel_error_E < 1e-6
    println("\n✅ EXCELENTE: Conservación de energía < 1e-6")
elseif rel_error_E < 1e-4
    println("\n✅ BUENO: Conservación de energía < 1e-4")
elseif rel_error_E < 1e-2
    println("\n⚠️  ACEPTABLE: Conservación de energía < 1e-2")
else
    println("\n❌ PROBLEMA: Conservación de energía > 1e-2")
    println("   Posible causa: múltiples colisiones, dt muy pequeño, o error en fórmulas")
end
