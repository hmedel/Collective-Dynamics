#!/usr/bin/env julia
# Test: Condiciones iniciales UNIFORMES para confirmar formación dinámica de clustering

using Pkg
Pkg.activate(".")

using CollectiveDynamics
using Random
using HDF5
using Statistics
using Printf
using StaticArrays

# Funciones geométricas (necesarias para generación de partículas)
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

"""
Genera partículas con distribución angular UNIFORME
"""
function generate_uniform_particles(N::Int, E_per_N::Real, a::Real, b::Real; seed::Int=1)
    Random.seed!(seed)

    # Parámetros
    mass = 1.0
    phi_fraction = 0.03  # Densidad baja (3% del perímetro ocupado)

    # Calcular radio de partícula
    # Perímetro aproximado de elipse (fórmula de Ramanujan)
    h = ((a - b)^2) / ((a + b)^2)
    perimeter = π * (a + b) * (1 + (3h)/(10 + sqrt(4 - 3h)))

    # Radio tal que N partículas ocupen phi_fraction del perímetro
    radius = (phi_fraction * perimeter) / (2N)

    println("  Generando $N partículas:")
    @printf("    Perímetro elipse: %.2f\n", perimeter)
    @printf("    Radio partícula: %.4f\n", radius)
    @printf("    Fracción ocupada: %.2f%%\n", phi_fraction * 100)
    println()

    # Velocidad inicial desde energía
    v_max = sqrt(2 * E_per_N)

    # Generar ángulos UNIFORMEMENTE distribuidos
    phi_angles = sort(rand(N) * 2π)

    # Velocidades angulares aleatorias (uniformemente distribuidas en velocidad)
    phi_dots = (rand(N) .- 0.5) * 2 * v_max

    particles = Vector{Particle{Float64}}(undef, N)

    for i in 1:N
        phi = phi_angles[i]
        phi_dot = phi_dots[i]

        # Posición Cartesiana
        r = radial_ellipse(phi, a, b)
        x = r * cos(phi)
        y = r * sin(phi)
        pos = [x, y]

        # Velocidad Cartesiana
        dr_dphi = radial_derivative_ellipse(phi, a, b)
        vx = dr_dphi * cos(phi) * phi_dot - r * sin(phi) * phi_dot
        vy = dr_dphi * sin(phi) * phi_dot + r * cos(phi) * phi_dot
        vel = [vx, vy]

        particles[i] = Particle(
            Int32(i),
            Float64(mass),
            Float64(radius),
            Float64(phi),
            Float64(phi_dot),
            SVector{2,Float64}(pos),
            SVector{2,Float64}(vel)
        )
    end

    # Verificar distribución uniforme
    println("  Verificación de uniformidad:")
    bins = range(0, 2π, length=9)  # 8 bins de 45°
    counts = zeros(Int, 8)
    for p in particles
        bin_idx = searchsortedfirst(bins, p.φ) - 1
        bin_idx = clamp(bin_idx, 1, 8)
        counts[bin_idx] += 1
    end

    expected = N / 8
    @printf("    Esperado por bin (45°): %.1f\n", expected)
    println("    Distribución real:")
    for (i, count) in enumerate(counts)
        deviation = abs(count - expected) / expected * 100
        bin_start = rad2deg(bins[i])
        @printf("      %3.0f°-%3.0f°: %2d partículas (desviación: %.1f%%)\n",
                bin_start, bin_start+45, count, deviation)
    end
    println()

    return particles, radius
end

# Parámetros de la simulación
println("="^70)
println("TEST: CONDICIONES INICIALES UNIFORMES")
println("="^70)
println()

# Geometría
e = 0.98
a = 3.170233138523429
b = a * sqrt(1 - e^2)

println("Geometría:")
@printf("  e = %.3f\n", e)
@printf("  a = %.3f\n", a)
@printf("  b = %.3f\n", b)
@printf("  a/b = %.2f\n", a/b)
println()

# Energía
E_per_N = 0.32

println("Energía:")
@printf("  E/N = %.2f\n", E_per_N)
println()

# Número de partículas (bajo para evitar crowding)
N = 40

println("Sistema:")
@printf("  N = %d partículas\n", N)
println()

# Generar partículas
particles, radius = generate_uniform_particles(N, E_per_N, a, b; seed=123)

println("Ejecutando simulación...")
println("  t_max = 100s")
println("  dt_max = 1e-5")
println("  save_interval = 0.5s")
println("  projection = ACTIVADO (cada 100 pasos)")
println()

# Ejecutar simulación
output_dir = "results/test_uniform_ICs"
mkpath(output_dir)

data = simulate_ellipse_adaptive(
    particles, a, b;
    max_time = 100.0,
    dt_max = 1e-5,
    save_interval = 0.5,
    collision_method = :parallel_transport,
    use_parallel = true,
    use_projection = true,
    projection_interval = 100
)

println()
println("Simulación completada!")
@printf("  Tiempo final: %.1fs\n", data.times[end])
@printf("  Total colisiones: %d\n", sum(data.n_collisions))
@printf("  Conservación ΔE/E₀: %.2e\n", abs(data.conservation.energies[end] - data.conservation.energies[1]) / data.conservation.energies[1])
println()

# Guardar resultados
output_file = joinpath(output_dir, "uniform_ICs_e$(round(e,digits=2))_N$(N)_E$(E_per_N).h5")
println("Guardando resultados: $output_file")

# Extraer trayectorias de phi desde particles_history
n_times = length(data.times)
phi_traj = zeros(N, n_times)
phidot_traj = zeros(N, n_times)

for (tidx, particle_vec) in enumerate(data.particles)
    for (pidx, p) in enumerate(particle_vec)
        phi_traj[pidx, tidx] = p.φ
        phidot_traj[pidx, tidx] = p.φ_dot
    end
end

h5open(output_file, "w") do file
    # Configuración
    config = create_group(file, "config")
    attributes(config)["a"] = a
    attributes(config)["b"] = b
    attributes(config)["eccentricity"] = e
    attributes(config)["N"] = N
    attributes(config)["E_per_N"] = E_per_N
    attributes(config)["radius"] = radius
    attributes(config)["seed"] = 123
    attributes(config)["v_max"] = sqrt(2*E_per_N)
    attributes(config)["initial_distribution"] = "uniform"

    # Trayectorias
    traj = create_group(file, "trajectories")
    traj["time"] = data.times
    traj["phi"] = phi_traj
    traj["phidot"] = phidot_traj

    # Conservación
    cons = create_group(file, "conservation")
    cons["energy"] = data.conservation.energies
    cons["momentum"] = data.conservation.conjugate_momenta
end

println("✅ Guardado exitosamente")
println()

println("="^70)
println("PRÓXIMO PASO: ANALIZAR RESULTADOS")
println("="^70)
println()
println("Archivo generado:")
println("  $output_file")
println()
println("Para analizar la evolución temporal, ejecutar:")
println("  julia --project=. analyze_uniform_ICs_results.jl")
println()
println("="^70)
