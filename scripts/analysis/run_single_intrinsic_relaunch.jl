"""
    run_single_intrinsic_relaunch.jl

Ejecuta una simulación para runs fallidos con radio ADAPTADO según N y e.

Cambios respecto al original:
- Radio adaptado: 0.05*b para N≤40, 0.03*b para N=60, 0.025*b para N=80
- max_steps aumentado a 50M

Uso:
    julia --project=. run_single_intrinsic_relaunch.jl <run_id> <N> <e> <a> <b> <seed> <max_time> <dt_max> <dt_min> <save_interval> <campaign_dir>
"""

using Pkg
Pkg.activate(".")

using Random
using Printf
using Dates
using JSON

# Cargar módulos del código
include("src/geometry/metrics_polar.jl")
include("src/geometry/christoffel_polar.jl")
include("src/particles_polar.jl")
include("src/collisions_polar.jl")
include("src/integrators/forest_ruth_polar.jl")
include("src/simulation_polar.jl")
include("src/io_hdf5.jl")

# ============================================================================
# Parsear argumentos de línea de comandos
# ============================================================================

if length(ARGS) < 11
    println("""
    Uso: julia run_single_intrinsic_relaunch.jl <run_id> <N> <e> <a> <b> <seed> <max_time> <dt_max> <dt_min> <save_interval> <campaign_dir>

    Argumentos:
        run_id        - ID único del run
        N             - Número de partículas
        e             - Excentricidad
        a             - Semi-eje mayor
        b             - Semi-eje menor
        seed          - Semilla para RNG
        max_time      - Tiempo máximo de simulación
        dt_max        - Paso de tiempo máximo
        dt_min        - Paso de tiempo mínimo
        save_interval - Intervalo de guardado
        campaign_dir  - Directorio de salida
    """)
    exit(1)
end

# Parsear argumentos
run_id = parse(Int, ARGS[1])
N = parse(Int, ARGS[2])
e = parse(Float64, ARGS[3])
a = parse(Float64, ARGS[4])
b = parse(Float64, ARGS[5])
seed = parse(Int, ARGS[6])
max_time = parse(Float64, ARGS[7])
dt_max = parse(Float64, ARGS[8])
dt_min = parse(Float64, ARGS[9])
save_interval = parse(Float64, ARGS[10])
campaign_dir = ARGS[11]

# Parámetros fijos para la campaña intrinsic
mass = 1.0
max_speed = 1.0
use_projection = true

# ============================================================================
# RADIO ADAPTADO según N
# ============================================================================
# El problema original: para N≥60 con e bajo, el radio 0.05*b es demasiado grande
# y las partículas no caben en la curva.
#
# Solución: reducir radio para N grande
# - N ≤ 40: 0.05 * b (original)
# - N = 60: 0.03 * b (reducido)
# - N ≥ 80: 0.025 * b (más reducido)

radius_fraction = if N <= 40
    0.05
elseif N <= 60
    0.03
else
    0.025
end

radius = radius_fraction * b

# Ajustar parámetros de precisión según excentricidad
if e >= 0.8
    projection_interval = 5   # Más frecuente para e altos
elseif e >= 0.5
    projection_interval = 10
else
    projection_interval = 20  # Menos frecuente para casos simples
end

# ============================================================================
# Crear directorio de salida
# ============================================================================

output_subdir = @sprintf("e%.2f_N%03d_seed%02d", e, N, seed)
output_dir = joinpath(campaign_dir, output_subdir)
mkpath(output_dir)

# ============================================================================
# Log de inicio
# ============================================================================

log_file = joinpath(output_dir, "run.log")
open(log_file, "w") do io
    println(io, "="^80)
    println(io, "INTRINSIC CAMPAIGN RELAUNCH")
    println(io, "="^80)
    println(io, "Fecha:           ", Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))
    println(io, "Run ID:          ", run_id)
    println(io, "N:               ", N)
    println(io, "Eccentricity:    ", e)
    println(io, "Seed:            ", seed)
    println(io, "Semi-axes (a,b): ", (a, b))
    println(io, "Radius:          ", radius, " (", radius_fraction*100, "% of b)")
    println(io, "max_time:        ", max_time)
    println(io, "dt_max:          ", dt_max)
    println(io, "dt_min:          ", dt_min)
    println(io, "save_interval:   ", save_interval)
    println(io, "use_projection:  ", use_projection)
    println(io, "proj_interval:   ", projection_interval)
    println(io, "="^80)
    println(io)
end

# ============================================================================
# Generar partículas
# ============================================================================

rng = MersenneTwister(seed)

# Aumentar max_attempts para runs difíciles
max_attempts = if N >= 80
    1_000_000
elseif N >= 60
    500_000
else
    100_000
end

try
    particles = generate_random_particles_polar(
        N, mass, radius, a, b;
        max_speed=max_speed,
        max_attempts=max_attempts,
        rng=rng
    )

    open(log_file, "a") do io
        println(io, "$(length(particles)) partículas generadas exitosamente")
        println(io)
    end

    # ========================================================================
    # Simular con energy projection
    # ========================================================================

    t_start = time()

    data = simulate_ellipse_polar_adaptive(
        particles, a, b;
        max_time=max_time,
        dt_max=dt_max,
        save_interval=save_interval,
        collision_method=:parallel_transport,
        use_projection=use_projection,
        projection_interval=projection_interval,
        projection_tolerance=1e-12,
        max_steps=50_000_000,  # 5x higher limit for relaunch
        verbose=false
    )

    t_elapsed = time() - t_start

    # ========================================================================
    # Calcular conservación de energía
    # ========================================================================

    E_history = [sum(kinetic_energy(p, a, b) for p in snapshot)
                 for snapshot in data.particles_history]
    E0 = E_history[1]
    E_final = E_history[end]
    ΔE_max = maximum(abs.(E_history .- E0))
    ΔE_rel_max = ΔE_max / abs(E0)

    # ========================================================================
    # Guardar datos
    # ========================================================================

    # HDF5 con trayectorias
    hdf5_file = joinpath(output_dir, "trajectories.h5")
    save_trajectories_hdf5(hdf5_file, data; compress=true)

    # Metadata en JSON
    metadata = Dict(
        "run_id" => run_id,
        "N" => N,
        "eccentricity" => e,
        "seed" => seed,
        "a" => a,
        "b" => b,
        "radius" => radius,
        "radius_fraction" => radius_fraction,
        "max_time" => max_time,
        "dt_max" => dt_max,
        "dt_min" => dt_min,
        "save_interval" => save_interval,
        "use_projection" => use_projection,
        "projection_interval" => projection_interval,
        "elapsed_time_s" => t_elapsed,
        "total_collisions" => sum(data.n_collisions),
        "E0" => E0,
        "E_final" => E_final,
        "ΔE_max" => ΔE_max,
        "ΔE_rel_max" => ΔE_rel_max,
        "n_snapshots" => length(data.times),
        "campaign_type" => "intrinsic_relaunch"
    )

    json_file = joinpath(output_dir, "summary.json")
    open(json_file, "w") do io
        JSON.print(io, metadata, 2)
    end

    # ========================================================================
    # Log final
    # ========================================================================

    open(log_file, "a") do io
        println(io, "="^80)
        println(io, "RUN COMPLETADO")
        println(io, "="^80)
        println(io, "Tiempo ejecución:  ", @sprintf("%.2f s", t_elapsed))
        println(io, "Colisiones totales:", sum(data.n_collisions))
        println(io, "Snapshots:         ", length(data.times))
        println(io)
        println(io, "Conservación de Energía:")
        println(io, "  E₀:          ", @sprintf("%.10f", E0))
        println(io, "  E_final:     ", @sprintf("%.10f", E_final))
        println(io, "  ΔE_max:      ", @sprintf("%.3e", ΔE_max))
        println(io, "  ΔE_max/E₀:   ", @sprintf("%.3e", ΔE_rel_max))

        if ΔE_rel_max < 1e-5
            println(io, "  Status:      EXCELENTE")
        elseif ΔE_rel_max < 1e-4
            println(io, "  Status:      BUENO")
        elseif ΔE_rel_max < 1e-3
            println(io, "  Status:      ACEPTABLE")
        else
            println(io, "  Status:      POBRE")
        end
        println(io)
        println(io, "Archivos guardados:")
        println(io, "  - trajectories.h5")
        println(io, "  - summary.json")
        println(io, "  - run.log")
        println(io, "="^80)
    end

    # Salida a stdout (para GNU parallel log)
    @printf("DONE: run_id=%d N=%d e=%.2f seed=%d radius=%.4f ΔE/E₀=%.3e\n", run_id, N, e, seed, radius, ΔE_rel_max)
    exit(0)

catch err
    # ========================================================================
    # Manejo de errores
    # ========================================================================

    open(log_file, "a") do io
        println(io, "="^80)
        println(io, "ERROR EN SIMULACIÓN")
        println(io, "="^80)
        println(io, "Error: ", err)
        println(io, "Stacktrace:")
        for (exc, bt) in Base.catch_stack()
            showerror(io, exc, bt)
            println(io)
        end
        println(io, "="^80)
    end

    @printf("ERROR: run_id=%d N=%d e=%.2f seed=%d - %s\n", run_id, N, e, seed, err)
    exit(1)
end
