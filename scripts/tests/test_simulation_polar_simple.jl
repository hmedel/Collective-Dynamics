#!/usr/bin/env julia
"""
test_simulation_polar_simple.jl

Test de integración simple: simulación completa con 5 partículas.
Verifica que todo el sistema funcione end-to-end.
"""

using Pkg
Pkg.activate(".")

include("src/simulation_polar.jl")

using Printf

println("=" ^ 70)
println("TEST: Simulación Polar Completa (Integración)")
println("=" ^ 70)
println()

# Parámetros
a, b = 2.0, 1.0
mass = 1.0
radius = 0.05
N = 5

# Crear partículas aleatorias
println("Creando $N partículas...")
particles = ParticlePolar{Float64}[]
for i in 1:N
    φ = rand() * 2π
    φ_dot = (rand() - 0.5) * 2.0  # Velocidades aleatorias [-1, 1]
    push!(particles, ParticlePolar(i, mass, radius, φ, φ_dot, a, b))
end

E_initial = sum(kinetic_energy(p, a, b) for p in particles)
println("Energía inicial: ", @sprintf("%.6f", E_initial))
println()

# Ejecutar simulación corta
println("Ejecutando simulación...")
println("  Tiempo: 0.1 s")
println("  dt_max: 1e-5")
println("  Método: parallel_transport")
println()

data = simulate_ellipse_polar_adaptive(
    particles, a, b;
    max_time = 0.1,
    dt_max = 1e-5,
    dt_min = 1e-10,
    save_interval = 0.01,
    collision_method = :parallel_transport,
    use_projection = false,
    verbose = true
)

println()
println("=" ^ 70)
println("RESULTADOS")
println("=" ^ 70)
println()

# Verificar conservación
print_conservation_summary_polar(data.conservation)

println()
println("Datos guardados:")
println("  Snapshots:  ", length(data.particles_history))
println("  Timesteps:  ", length(data.dt_history))
println("  Colisiones: ", sum(data.n_collisions))

# Verificar que las partículas siguen en la elipse
println()
println("Verificando que partículas están en la elipse...")
final_particles = data.particles_history[end]
ellipse_errors = Float64[]

for p in final_particles
    ellipse_eq = (p.pos[1] / a)^2 + (p.pos[2] / b)^2
    error = abs(ellipse_eq - 1.0)
    push!(ellipse_errors, error)
end

max_ellipse_error = maximum(ellipse_errors)

@printf("  Error máximo: %.2e ", max_ellipse_error)
println(max_ellipse_error < 1e-10 ? "✅" : "⚠️")

println()
println("=" ^ 70)
println("✅ TEST DE INTEGRACIÓN COMPLETADO")
println("=" ^ 70)
println()

# Resumen
E_final_error = data.conservation.energy_errors[end]
if E_final_error < 1e-4 && max_ellipse_error < 1e-10
    println("🎉 SISTEMA COMPLETO FUNCIONA CORRECTAMENTE")
    println()
    println("Próximos pasos:")
    println("  1. Probar con más partículas (40)")
    println("  2. Tiempos más largos (10s)")
    println("  3. Comparar con implementación θ")
else
    println("⚠️  Revisar conservación o constraint de elipse")
end
println()
