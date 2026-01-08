#!/usr/bin/env julia
using CollectiveDynamics
using HDF5
using Random
using ArgParse
using Printf

"""
Script de simulación para Experimento 3:
- Condiciones iniciales UNIFORMES
- φ equiespaciados en [0, 2π]
- Velocidades muestreadas de distribución térmica
"""

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--run-id"
            help = "Run ID"
            arg_type = Int
            required = true
        "--eccentricity"
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
            help = "Random seed (for velocities)"
            arg_type = Int
            required = true
        "--t-max"
            help = "Maximum simulation time"
            arg_type = Float64
            required = true
        "--dt-max"
            help = "Maximum timestep"
            arg_type = Float64
            required = true
        "--save-interval"
            help = "Save interval"
            arg_type = Float64
            required = true
        "--projection-interval"
            help = "Projection interval"
            arg_type = Int
            default = 100
        "--output-dir"
            help = "Output directory"
            arg_type = String
            required = true
        "--use-projection"
            help = "Use projection methods"
            action = :store_true
    end

    return parse_args(s)
end

function generate_uniform_particles(N::Int, E_per_N::Float64, a::Float64, b::Float64, seed::Int)
    """
    Genera partículas con condiciones iniciales UNIFORMES:
    - φ equiespaciados en [0, 2π]
    - Velocidades muestreadas de distribución térmica (para alcanzar E_total)
    """
    Random.seed!(seed)

    # Parámetros de partículas
    mass = 1.0
    radius = 0.05 * b  # 5% del eje menor

    # POSICIONES: equiespaciadas
    φ_positions = range(0, 2π, length=N+1)[1:N]  # Excluir 2π (duplicado de 0)

    # VELOCIDADES: distribución térmica
    # E_total = N * E_per_N
    # Para sistema térmico: E_kinetic = (1/2) Σ m g_φφ φ̇²
    # Aproximación: usar g_φφ promedio

    E_total = N * E_per_N

    # Calcular g_φφ promedio
    g_φφ_values = [metric_ellipse_polar(φ, a, b) for φ in φ_positions]
    g_φφ_mean = mean(g_φφ_values)

    # Velocidad térmica RMS: √(2E/(N*m*g_φφ_mean))
    v_rms = sqrt(2 * E_total / (N * mass * g_φφ_mean))

    # Muestrear velocidades de distribución normal
    φ̇_velocities = randn(N) .* v_rms

    # Crear partículas
    particles = ParticlePolar[]

    for i in 1:N
        φ = φ_positions[i]
        φ̇ = φ̇_velocities[i]

        # Calcular posición y velocidad cartesianas
        r = radial_ellipse(φ, a, b)
        x = r * cos(φ)
        y = r * sin(φ)

        # Velocidad cartesiana (aproximación para inicialización)
        vx = -r * sin(φ) * φ̇
        vy = r * cos(φ) * φ̇

        particle = ParticlePolar(
            id = Int32(i),
            mass = mass,
            radius = radius,
            φ = φ,
            φ_dot = φ̇,
            pos = SVector(x, y),
            vel = SVector(vx, vy)
        )

        push!(particles, particle)
    end

    return particles
end

# ==================== MAIN ====================

args = parse_commandline()

println("="^70)
println("EXPERIMENTO 3: Condiciones Iniciales Uniformes")
println("="^70)
println()

println("Parámetros:")
@printf("  Run ID:        %d\n", args["run-id"])
@printf("  Eccentricity:  %.3f\n", args["eccentricity"])
@printf("  a, b:          %.3f, %.3f\n", args["a"], args["b"])
@printf("  N particles:   %d\n", args["N"])
@printf("  E/N:           %.2f\n", args["E-per-N"])
@printf("  Seed:          %d\n", args["seed"])
@printf("  t_max:         %.1f s\n", args["t-max"])
@printf("  dt_max:        %.1e\n", args["dt-max"])
@printf("  save_interval: %.1f s\n", args["save-interval"])
@printf("  Projection:    %s (every %d steps)\n",
        args["use-projection"] ? "ON" : "OFF", args["projection-interval"])
println()

# Generar partículas con ICs uniformes
println("Generando partículas con ICs UNIFORMES...")
particles = generate_uniform_particles(
    args["N"],
    args["E-per-N"],
    args["a"],
    args["b"],
    args["seed"]
)

println("  ✓ $(length(particles)) partículas generadas")
println("  ✓ Posiciones φ: equiespaciadas")
println("  ✓ Velocidades: distribución térmica (seed=$(args["seed"]))")
println()

# Verificar energía inicial
E_initial = sum(kinetic_energy_polar(p, args["a"], args["b"]) for p in particles)
E_per_N_actual = E_initial / args["N"]

@printf("Energía inicial:\n")
@printf("  E_total:   %.6f\n", E_initial)
@printf("  E/N:       %.6f (target: %.6f, error: %.2f%%)\n",
        E_per_N_actual, args["E-per-N"],
        100*abs(E_per_N_actual - args["E-per-N"])/args["E-per-N"])
println()

# Verificar uniformidad de posiciones
φ_values = [p.φ for p in particles]
@printf("Distribución de posiciones:\n")
@printf("  φ_min, φ_max: %.3f, %.3f rad\n", minimum(φ_values), maximum(φ_values))
@printf("  Δφ promedio:  %.3f rad (esperado: %.3f)\n",
        mean(diff(sort(φ_values))), 2π/args["N"])
println()

# Ejecutar simulación
println("Iniciando simulación...")
println("-"^70)

try
    data = simulate_ellipse_adaptive(
        particles,
        args["a"],
        args["b"];
        max_time = args["t-max"],
        dt_max = args["dt-max"],
        save_interval = args["save-interval"],
        use_projection = args["use-projection"],
        projection_interval = args["projection-interval"],
        collision_method = :parallel_transport,
        max_steps = 100_000_000  # Alto para simulaciones largas
    )

    println("-"^70)
    println("Simulación completada")
    println()

    # Resumen de conservación
    print_conservation_summary(data.conservation)
    println()

    # Guardar resultados
    output_dir = args["output-dir"]
    mkpath(output_dir)

    filename = @sprintf("run_%04d_e%.3f_N%d_E%.2f_seed%d_UNIFORM.h5",
                       args["run-id"], args["eccentricity"], args["N"],
                       E_initial, args["seed"])
    output_file = joinpath(output_dir, filename)

    println("Guardando resultados en: $output_file")

    h5open(output_file, "w") do file
        # Metadata
        attributes(file)["run_id"] = args["run-id"]
        attributes(file)["eccentricity"] = args["eccentricity"]
        attributes(file)["a"] = args["a"]
        attributes(file)["b"] = args["b"]
        attributes(file)["N"] = args["N"]
        attributes(file)["E_per_N_target"] = args["E-per-N"]
        attributes(file)["E_total"] = E_initial
        attributes(file)["seed"] = args["seed"]
        attributes(file)["t_max"] = args["t-max"]
        attributes(file)["initial_conditions"] = "UNIFORM"  # FLAG

        # Trayectorias
        traj_group = create_group(file, "trajectories")
        traj_group["phi"] = data.trajectories.phi
        traj_group["phidot"] = data.trajectories.phidot
        traj_group["time"] = data.trajectories.time

        # Conservación
        cons_group = create_group(file, "conservation")
        cons_group["energy"] = data.conservation.energy
        cons_group["momentum"] = hcat(data.conservation.momentum_x,
                                      data.conservation.momentum_y)

        # Config
        config_group = create_group(file, "config")
        attributes(config_group)["dt_max"] = args["dt-max"]
        attributes(config_group)["save_interval"] = args["save-interval"]
        attributes(config_group)["use_projection"] = args["use-projection"]
        attributes(config_group)["projection_interval"] = args["projection-interval"]
    end

    println("✓ Resultados guardados")
    println()
    println("="^70)
    println("RUN COMPLETADO EXITOSAMENTE")
    println("="^70)

catch e
    println()
    println("="^70)
    println("ERROR EN SIMULACIÓN")
    println("="^70)
    println(e)
    println()
    rethrow(e)
end
