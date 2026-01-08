"""
    run_single_final_campaign.jl

Ejecuta una sola simulación para la campaña final de finite-size scaling.

Uso:
    julia --project=. run_single_final_campaign.jl <run_id> <campaign_dir>

Lee parámetros desde parameter_matrix_final_campaign.csv y ejecuta la simulación
correspondiente con geometría intrínseca y energy projection activado.
"""

using Pkg
Pkg.activate(".")

using CSV
using DataFrames
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
# Parsear argumentos
# ============================================================================

if length(ARGS) < 2
    println("Uso: julia run_single_final_campaign.jl <run_id> <campaign_dir>")
    exit(1)
end

run_id = parse(Int, ARGS[1])
campaign_dir = ARGS[2]

# ============================================================================
# Leer parámetros desde CSV
# ============================================================================

parameter_file = "parameter_matrix_final_campaign.csv"
if !isfile(parameter_file)
    error("No se encontró el archivo de parámetros: $parameter_file")
end

df = CSV.read(parameter_file, DataFrame)

# Buscar run_id
row_idx = findfirst(df.run_id .== run_id)
if isnothing(row_idx)
    error("Run ID $run_id no encontrado en la matriz de parámetros")
end

row = df[row_idx, :]

# Extraer parámetros
N = row.N
e = row.eccentricity
seed = row.seed
a = row.a
b = row.b
r = row.radius
t_max = row.t_max
save_interval = row.save_interval
use_projection = row.use_projection
mass = row.mass
max_speed = row.max_speed

# Ajustar precisión según excentricidad
if e >= 0.8
    dt_max = 5e-5          # Más fino para e altos
    projection_interval = 5  # Más frecuente
elseif e >= 0.5
    dt_max = 1e-4
    projection_interval = 10
else
    dt_max = 1e-4
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
    println(io, "RUN INICIADO")
    println(io, "="^80)
    println(io, "Fecha:           ", Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))
    println(io, "Run ID:          ", run_id)
    println(io, "N:               ", N)
    println(io, "Eccentricity:    ", e)
    println(io, "Seed:            ", seed)
    println(io, "Semi-axes (a,b): ", (a, b))
    println(io, "Radius (intrins):", r)
    println(io, "t_max:           ", t_max)
    println(io, "dt_max:          ", dt_max)
    println(io, "use_projection:  ", use_projection)
    println(io, "proj_interval:   ", projection_interval)
    println(io, "="^80)
    println(io)
end

# ============================================================================
# Generar partículas
# ============================================================================

rng = MersenneTwister(seed)

# Ajustar max_attempts según packing fraction
# Para φ alto (N=80), necesitamos muchos más intentos
max_attempts = if N >= 80
    500_000  # Alta densidad requiere muchos intentos
elseif N >= 60
    200_000
else
    50_000
end

try
    particles = generate_random_particles_polar(
        N, mass, r, a, b;
        max_speed=max_speed,
        max_attempts=max_attempts,
        rng=rng
    )

    open(log_file, "a") do io
        println(io, "✅ $(length(particles)) partículas generadas exitosamente")
        println(io)
    end

    # ========================================================================
    # Simular con energy projection
    # ========================================================================

    t_start = time()

    data = simulate_ellipse_polar_adaptive(
        particles, a, b;
        max_time=t_max,
        dt_max=dt_max,
        save_interval=save_interval,
        collision_method=:parallel_transport,
        use_projection=use_projection,
        projection_interval=projection_interval,
        projection_tolerance=1e-12,
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
        "radius_intrinsic" => r,
        "phi_intrinsic" => row.phi_intrinsic,
        "t_max" => t_max,
        "dt_max" => dt_max,
        "save_interval" => save_interval,
        "use_projection" => use_projection,
        "projection_interval" => projection_interval,
        "elapsed_time_s" => t_elapsed,
        "total_collisions" => sum(data.n_collisions),
        "E0" => E0,
        "E_final" => E_final,
        "ΔE_max" => ΔE_max,
        "ΔE_rel_max" => ΔE_rel_max,
        "n_snapshots" => length(data.times)
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
            println(io, "  Status:      ✅ EXCELENTE")
        elseif ΔE_rel_max < 1e-4
            println(io, "  Status:      ✅ BUENO")
        elseif ΔE_rel_max < 1e-3
            println(io, "  Status:      ⚠️  ACEPTABLE")
        else
            println(io, "  Status:      ❌ POBRE")
        end
        println(io)
        println(io, "Archivos guardados:")
        println(io, "  - trajectories.h5")
        println(io, "  - summary.json")
        println(io, "  - run.log")
        println(io, "="^80)
    end

    # Salida a stdout (para GNU parallel log)
    println("DONE: run_id=$run_id N=$N e=$e seed=$seed ΔE/E₀=$(ΔE_rel_max)")
    exit(0)

catch err
    # ========================================================================
    # Manejo de errores
    # ========================================================================

    open(log_file, "a") do io
        println(io, "="^80)
        println(io, "❌ ERROR EN SIMULACIÓN")
        println(io, "="^80)
        println(io, "Error: ", err)
        println(io, "Stacktrace:")
        for (exc, bt) in Base.catch_stack()
            showerror(io, exc, bt)
            println(io)
        end
        println(io, "="^80)
    end

    println("ERROR: run_id=$run_id N=$N e=$e seed=$seed - $(err)")
    exit(1)
end
