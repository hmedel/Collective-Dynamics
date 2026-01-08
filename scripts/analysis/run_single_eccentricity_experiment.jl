#!/usr/bin/env julia
# Run single experiment from eccentricity scan

using Pkg
Pkg.activate(".")

using CollectiveDynamics
using Random
using HDF5
using Statistics
using Printf
using StaticArrays
using ArgParse

# Parse command-line arguments
function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table s begin
        "--run-id"
            help = "Run ID"
            arg_type = Int
            required = true
        "--eccentricity", "-e"
            help = "Eccentricity"
            arg_type = Float64
            required = true
        "--a"
            help = "Semi-major axis"
            arg_type = Float64
            required = true
        "--b"
            help = "Semi-minor axis"
            arg_type = Float64
            required = true
        "--N"
            help = "Number of particles"
            arg_type = Int
            required = true
        "--E-per-N"
            help = "Energy per particle"
            arg_type = Float64
            required = true
        "--seed"
            help = "Random seed"
            arg_type = Int
            required = true
        "--t-max"
            help = "Maximum simulation time"
            arg_type = Float64
            default = 200.0
        "--dt-max"
            help = "Maximum timestep"
            arg_type = Float64
            default = 1e-5
        "--save-interval"
            help = "Save interval"
            arg_type = Float64
            default = 0.5
        "--use-projection"
            help = "Use energy projection"
            action = :store_true
        "--projection-interval"
            help = "Projection interval"
            arg_type = Int
            default = 100
        "--output-dir"
            help = "Output directory"
            arg_type = String
            default = "results/eccentricity_scan"
    end
    return parse_args(s)
end

# Funciones geométricas
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
    h = ((a - b)^2) / ((a + b)^2)
    perimeter = π * (a + b) * (1 + (3h)/(10 + sqrt(4 - 3h)))
    radius = (phi_fraction * perimeter) / (2N)

    # Velocidad inicial desde energía
    v_max = sqrt(2 * E_per_N)

    # Generar ángulos UNIFORMEMENTE distribuidos
    phi_angles = sort(rand(N) * 2π)

    # Velocidades angulares aleatorias
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

    return particles, radius
end

# Main
function main()
    args = parse_commandline()

    println("="^70)
    println("ECCENTRICITY SCAN - RUN $(args["run-id"])")
    println("="^70)
    println()

    # Extraer parámetros
    run_id = args["run-id"]
    e = args["eccentricity"]
    a = args["a"]
    b = args["b"]
    N = args["N"]
    E_per_N = args["E-per-N"]
    seed = args["seed"]
    t_max = args["t-max"]
    dt_max = args["dt-max"]
    save_interval = args["save-interval"]
    use_projection = args["use-projection"]
    projection_interval = args["projection-interval"]
    output_dir = args["output-dir"]

    println("Geometría:")
    @printf("  e = %.3f\n", e)
    @printf("  a = %.6f\n", a)
    @printf("  b = %.6f\n", b)
    @printf("  a/b = %.2f\n", e == 0.0 ? 1.0 : a/b)
    println()

    println("Sistema:")
    @printf("  N = %d partículas\n", N)
    @printf("  E/N = %.3f\n", E_per_N)
    @printf("  Seed = %d\n", seed)
    println()

    println("Simulación:")
    @printf("  t_max = %.1f s\n", t_max)
    @printf("  dt_max = %.1e\n", dt_max)
    @printf("  save_interval = %.1f s\n", save_interval)
    println("  projection = $use_projection (interval = $projection_interval)")
    println()

    # Generar partículas uniformes
    println("Generando partículas con distribución uniforme...")
    particles, radius = generate_uniform_particles(N, E_per_N, a, b; seed=seed)

    # Verificar uniformidad (opcional, comentar para producción)
    # println("Verificando distribución:")
    # bins = range(0, 2π, length=9)
    # counts = zeros(Int, 8)
    # for p in particles
    #     bin_idx = searchsortedfirst(bins, p.φ) - 1
    #     bin_idx = clamp(bin_idx, 1, 8)
    #     counts[bin_idx] += 1
    # end
    # expected = N / 8
    # @printf("  Esperado por bin: %.1f\n", expected)
    # println("  Distribución:", counts)
    # println()

    # Ejecutar simulación
    println("Ejecutando simulación...")
    flush(stdout)

    data = simulate_ellipse_adaptive(
        particles, a, b;
        max_time = t_max,
        dt_max = dt_max,
        save_interval = save_interval,
        collision_method = :parallel_transport,
        use_parallel = true,
        use_projection = use_projection,
        projection_interval = projection_interval
    )

    println()
    println("Simulación completada!")
    @printf("  Tiempo final: %.1f s\n", data.times[end])
    @printf("  Total colisiones: %d\n", sum(data.n_collisions))

    # Conservación
    ΔE_rel = abs(data.conservation.energies[end] - data.conservation.energies[1]) / data.conservation.energies[1]
    @printf("  Conservación ΔE/E₀: %.2e\n", ΔE_rel)
    println()

    # Crear directorio de salida
    mkpath(output_dir)

    # Nombre de archivo
    output_file = joinpath(
        output_dir,
        @sprintf("run_%04d_e%.3f_N%d_E%.2f_seed%d.h5", run_id, e, N, E_per_N, seed)
    )

    println("Guardando resultados: $output_file")

    # Extraer trayectorias
    n_times = length(data.times)
    phi_traj = zeros(N, n_times)
    phidot_traj = zeros(N, n_times)

    for (tidx, particle_vec) in enumerate(data.particles)
        for (pidx, p) in enumerate(particle_vec)
            phi_traj[pidx, tidx] = p.φ
            phidot_traj[pidx, tidx] = p.φ_dot
        end
    end

    # Guardar en HDF5
    h5open(output_file, "w") do file
        # Configuración
        config = create_group(file, "config")
        attributes(config)["run_id"] = run_id
        attributes(config)["a"] = a
        attributes(config)["b"] = b
        attributes(config)["eccentricity"] = e
        attributes(config)["N"] = N
        attributes(config)["E_per_N"] = E_per_N
        attributes(config)["radius"] = radius
        attributes(config)["seed"] = seed
        attributes(config)["v_max"] = sqrt(2*E_per_N)
        attributes(config)["t_max"] = t_max
        attributes(config)["dt_max"] = dt_max
        attributes(config)["save_interval"] = save_interval
        attributes(config)["use_projection"] = use_projection
        attributes(config)["projection_interval"] = projection_interval
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

        # Metadata
        meta = create_group(file, "metadata")
        attributes(meta)["conservation_Delta_E_rel"] = ΔE_rel
        attributes(meta)["total_collisions"] = sum(data.n_collisions)
        attributes(meta)["final_time"] = data.times[end]
    end

    println("✅ Guardado exitosamente")
    println()
    println("="^70)

    return 0
end

# Execute
exit(main())
