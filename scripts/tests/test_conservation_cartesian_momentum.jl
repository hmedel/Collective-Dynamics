#!/usr/bin/env julia
# Test de conservación de momento CARTESIANO

using Pkg
Pkg.activate(".")

using CollectiveDynamics
using Printf

println("="^70)
println("TEST: CONSERVACIÓN DE MOMENTO CARTESIANO")
println("="^70)
println()

# Geometría
a, b = 3.170233138523429, 0.6308684291059812

# Sistema pequeño
N = 10
E_per_N = 0.32

# Generar partículas (misma semilla)
using Random
particles = generate_random_particles(N, E_per_N, 0.05, a, b; rng=MersenneTwister(123))

# Momento cartesiano inicial
px_0 = sum(p.vel[1] * p.mass for p in particles)
py_0 = sum(p.vel[2] * p.mass for p in particles)
p_cart_0 = sqrt(px_0^2 + py_0^2)

# Momento conjugado y energía iniciales
P0 = sum(conjugate_momentum(p, a, b) for p in particles)
E0 = sum(kinetic_energy(p, a, b) for p in particles)

println("Estado inicial:")
@printf("  E₀ = %.6f\n", E0)
@printf("  P₀ (conjugado φ) = %.6f\n", P0)
@printf("  px₀ = %.6f\n", px_0)
@printf("  py₀ = %.6f\n", py_0)
@printf("  |p_cart|₀ = %.6f\n", p_cart_0)
println()

# Simulación CON projection
println("Simulación CON projection...")
data_proj = simulate_ellipse_adaptive(
    particles, a, b;
    max_time = 10.0,
    dt_max = 1e-6,
    save_interval = 0.5,
    collision_method = :parallel_transport,
    use_parallel = false,
    use_projection = true,
    projection_interval = 100
)

# Estado final CON projection
particles_proj = data_proj.particles[end]
px_f_proj = sum(p.vel[1] * p.mass for p in particles_proj)
py_f_proj = sum(p.vel[2] * p.mass for p in particles_proj)
p_cart_f_proj = sqrt(px_f_proj^2 + py_f_proj^2)

Pf_proj = sum(conjugate_momentum(p, a, b) for p in particles_proj)
Ef_proj = sum(kinetic_energy(p, a, b) for p in particles_proj)

println()
println("="^70)
println("RESULTADOS CON PROJECTION")
println("="^70)

ΔE_proj = abs(Ef_proj - E0) / E0
ΔP_proj = abs(Pf_proj - P0) / abs(P0)
Δpx_proj = abs(px_f_proj - px_0) / (abs(px_0) + 1e-10)
Δpy_proj = abs(py_f_proj - py_0) / (abs(py_0) + 1e-10)
Δp_cart_proj = abs(p_cart_f_proj - p_cart_0) / p_cart_0

@printf("  ΔE/E₀            = %.2e\n", ΔE_proj)
@printf("  ΔP/P₀ (conj-φ)   = %.2e\n", ΔP_proj)
@printf("  Δpx/px₀          = %.2e\n", Δpx_proj)
@printf("  Δpy/py₀          = %.2e\n", Δpy_proj)
@printf("  Δ|p_cart|/|p₀|   = %.2e\n", Δp_cart_proj)
println()

# Simulación SIN projection
println("Simulación SIN projection...")
particles = generate_random_particles(N, E_per_N, 0.05, a, b; rng=MersenneTwister(123))

data_no_proj = simulate_ellipse_adaptive(
    particles, a, b;
    max_time = 10.0,
    dt_max = 1e-6,
    save_interval = 0.5,
    collision_method = :parallel_transport,
    use_parallel = false,
    use_projection = false
)

# Estado final SIN projection
particles_no_proj = data_no_proj.particles[end]
px_f_no = sum(p.vel[1] * p.mass for p in particles_no_proj)
py_f_no = sum(p.vel[2] * p.mass for p in particles_no_proj)
p_cart_f_no = sqrt(px_f_no^2 + py_f_no^2)

Pf_no = sum(conjugate_momentum(p, a, b) for p in particles_no_proj)
Ef_no = sum(kinetic_energy(p, a, b) for p in particles_no_proj)

println()
println("="^70)
println("RESULTADOS SIN PROJECTION")
println("="^70)

ΔE_no = abs(Ef_no - E0) / E0
ΔP_no = abs(Pf_no - P0) / abs(P0)
Δpx_no = abs(px_f_no - px_0) / (abs(px_0) + 1e-10)
Δpy_no = abs(py_f_no - py_0) / (abs(py_0) + 1e-10)
Δp_cart_no = abs(p_cart_f_no - p_cart_0) / p_cart_0

@printf("  ΔE/E₀            = %.2e\n", ΔE_no)
@printf("  ΔP/P₀ (conj-φ)   = %.2e\n", ΔP_no)
@printf("  Δpx/px₀          = %.2e\n", Δpx_no)
@printf("  Δpy/py₀          = %.2e\n", Δpy_no)
@printf("  Δ|p_cart|/|p₀|   = %.2e\n", Δp_cart_no)
println()

println("="^70)
println("CONCLUSIÓN:")
println("El momento CARTESIANO (px, py) debería conservarse mejor que")
println("el momento conjugado P_φ, ya que las colisiones son elásticas")
println("en coordenadas cartesianas.")
println("="^70)
