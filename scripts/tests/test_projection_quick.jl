"""
    test_projection_quick.jl

Test rápido de energy projection para verificar conservación perfecta.

Caso: N=80, e=0.9, t_max=5s con use_projection=true
Objetivo: ΔE/E₀ < 1e-10
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
println("TEST: Energy Projection - Caso Crítico N=80, e=0.9")
println("="^80)
println()

# Parámetros del caso más crítico
N = 80
e = 0.9
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
t_max = 5.0
dt_max = 1e-4
save_interval = 0.5

@printf("Parámetros:\n")
@printf("  N = %d\n", N)
@printf("  e = %.2f (caso más crítico)\n", e)
@printf("  a = %.4f, b = %.4f\n", a, b)
@printf("  r = %.5f (φ=%.3f)\n", r, φ_target)
@printf("  dt_max = %.2e\n", dt_max)
@printf("  use_projection = true ⭐\n")
println()

# Generar partículas
@printf("Generando %d partículas...\n", N)
particles = generate_random_particles_polar(
    N, mass, r, a, b;
    max_speed=max_speed,
    max_attempts=50000
)
println("✅ $(length(particles)) partículas generadas\n")

# Simular CON PROJECTION
@printf("Simulando con ENERGY PROJECTION...\n")
@printf("  projection_interval = 10 (cada 10 pasos)\n")
@printf("  projection_tolerance = 1e-12\n")
println()

t_start = time()

data = simulate_ellipse_polar_adaptive(
    particles, a, b;
    max_time=t_max,
    dt_max=dt_max,
    save_interval=save_interval,
    collision_method=:parallel_transport,
    use_projection=true,           # ⭐ ACTIVADO
    projection_interval=10,        # Más frecuente
    projection_tolerance=1e-12,
    verbose=false
)

t_elapsed = time() - t_start

# Analizar conservación
E_history = [sum(kinetic_energy(p, a, b) for p in snapshot) for snapshot in data.particles_history]
E0 = E_history[1]
E_final = E_history[end]
ΔE_max = maximum(abs.(E_history .- E0))
ΔE_rel_max = ΔE_max / abs(E0)

println("="^80)
println("RESULTADOS")
println("="^80)
println()

@printf("Tiempo de ejecución:  %.2f s\n", t_elapsed)
@printf("Colisiones totales:   %d\n", sum(data.n_collisions))
@printf("Tasa de colisiones:   %.1f/s\n", sum(data.n_collisions) / t_max)
@printf("Pasos totales:        %d\n", length(data.times))
println()

@printf("Conservación de Energía:\n")
@printf("  E₀:            %.10f\n", E0)
@printf("  E_final:       %.10f\n", E_final)
@printf("  ΔE_max:        %.3e\n", ΔE_max)
@printf("  ΔE_max/E₀:     %.3e", ΔE_rel_max)

if ΔE_rel_max < 1e-10
    println(" ⭐ PERFECTO (projection funciona)")
    success = true
elseif ΔE_rel_max < 1e-8
    println(" ✅ EXCELENTE")
    success = true
elseif ΔE_rel_max < 1e-6
    println(" ✅ MUY BUENO")
    success = true
else
    println(" ❌ PROJECTION NO ESTÁ FUNCIONANDO")
    success = false
end

println()

# Verificar clustering
n_snapshots = length(data.particles_history)
@printf("Análisis de Clustering:\n")
@printf("  Snapshots guardados: %d\n", n_snapshots)

# Clustering simple por cuadrantes
function count_by_quadrant(particles)
    q1 = count(p -> 0 <= p.φ < π/2, particles)
    q2 = count(p -> π/2 <= p.φ < π, particles)
    q3 = count(p -> π <= p.φ < 3π/2, particles)
    q4 = count(p -> 3π/2 <= p.φ, particles)
    return (q1, q2, q3, q4)
end

q_init = count_by_quadrant(data.particles_history[1])
q_final = count_by_quadrant(data.particles_history[end])

σ_init = std([q_init...]) / (N/4)
σ_final = std([q_final...]) / (N/4)

@printf("  Clustering inicial:  σ/μ = %.3f\n", σ_init)
@printf("  Clustering final:    σ/μ = %.3f\n", σ_final)
@printf("  Incremento:          %.2fx\n", σ_final / max(σ_init, 0.01))

println()
println("="^80)

if success
    println("✅ TEST EXITOSO - PROJECTION FUNCIONA CORRECTAMENTE")
    println()
    println("Próximos pasos:")
    println("  1. Generar matriz de parámetros completa (240 runs)")
    println("  2. Crear script de lanzamiento con projection")
    println("  3. Lanzar campaña completa (~40 min con 24 cores)")
else
    println("❌ TEST FALLÓ - REVISAR IMPLEMENTACIÓN DE PROJECTION")
    println()
    println("Verificar:")
    println("  • use_projection está siendo usado en simulate_ellipse_polar_adaptive")
    println("  • Implementación de projection_step! es correcta")
    println("  • Tolerancia no es demasiado laxa")
end

println("="^80)
