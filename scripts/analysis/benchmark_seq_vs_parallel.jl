#!/usr/bin/env julia
"""
benchmark_seq_vs_parallel.jl

Script automatizado para comparar rendimiento secuencial vs paralelo
con diferentes tamaños de N (número de partículas).

Uso:
    # Secuencial (1 thread)
    julia --project=. benchmark_seq_vs_parallel.jl sequential

    # Paralelo (24 threads)
    julia -t 24 --project=. benchmark_seq_vs_parallel.jl parallel

    # Ambos (ejecutar automáticamente, requiere jq para manipular TOML)
    ./benchmark_seq_vs_parallel.jl both

Salida:
    - Resultados en results/benchmark_YYYYMMDD_HHMMSS/
    - Archivo CSV con tiempos y speedups
    - Validación de conservación de energía
"""

using Pkg
Pkg.activate(".")

using CollectiveDynamics
using Printf
using Dates
using TOML
using CSV
using DataFrames
using Random
using Statistics

# ============================================================================
# Configuración
# ============================================================================

const CONFIGS = [
    ("config/benchmark_N50.toml", 50),
    ("config/benchmark_N70.toml", 70),
    ("config/benchmark_N100.toml", 100),
]

const N_RUNS = 1  # Número de repeticiones (aumentar para reducir varianza)

# ============================================================================
# Funciones Auxiliares
# ============================================================================

"""
Ejecuta una simulación y mide el tiempo de ejecución.
"""
function run_benchmark(config_path::String, mode::Symbol)
    @assert mode in [:sequential, :parallel] "mode debe ser :sequential o :parallel"

    # Leer configuración
    config = read_config(config_path)

    # Modificar use_parallel según el modo
    config["simulation"]["use_parallel"] = (mode == :parallel)

    # Cargar parámetros
    a = Float64(config["geometry"]["a"])
    b = Float64(config["geometry"]["b"])
    max_time = Float64(config["simulation"]["max_time"])
    dt_max = Float64(config["simulation"]["dt_max"])
    dt_min = Float64(config["simulation"]["dt_min"])
    max_steps = Int(config["simulation"]["max_steps"])
    use_parallel = config["simulation"]["use_parallel"]

    # Generar partículas
    n_particles = Int(config["particles"]["random"]["n_particles"])
    mass = Float64(config["particles"]["random"]["mass"])
    radius = Float64(config["particles"]["random"]["radius"])
    seed = Int(config["particles"]["random"]["seed"])
    theta_dot_min = Float64(config["particles"]["random"]["theta_dot_min"])
    theta_dot_max = Float64(config["particles"]["random"]["theta_dot_max"])

    # Crear RNG con seed para reproducibilidad
    rng = Random.MersenneTwister(seed)

    particles = generate_random_particles(
        n_particles, mass, radius, a, b;
        θ_dot_range=(theta_dot_min, theta_dot_max),
        rng=rng
    )

    # Medir tiempo de ejecución
    println("\n" * "="^70)
    println("Ejecutando: N=$(n_particles), mode=$(mode), threads=$(Threads.nthreads())")
    println("="^70)

    # JIT warmup (para evitar que compile durante benchmark)
    if mode == :sequential
        println("Warming up JIT...")
        _ = simulate_ellipse_adaptive(particles[1:min(10, n_particles)], a, b;
            max_time=0.001, dt_max=dt_max, use_parallel=false, verbose=false)
    end

    # Benchmark real
    flush(stdout)
    t_start = time()

    data = simulate_ellipse_adaptive(
        particles, a, b;
        max_time=max_time,
        dt_max=dt_max,
        dt_min=dt_min,
        max_steps=max_steps,
        use_parallel=use_parallel,
        verbose=true
    )

    t_end = time()
    elapsed = t_end - t_start

    println("\n✅ Simulación completada en $(round(elapsed, digits=2)) segundos")

    # Análisis de conservación
    if !isempty(data.conservation.energies)
        E0 = data.conservation.energies[1]
        Ef = data.conservation.energies[end]
        ΔE = abs(Ef - E0)
        rel_error = ΔE / abs(E0)

        println("   Energía inicial: $(E0)")
        println("   Energía final:   $(Ef)")
        println("   Error relativo:  $(rel_error)")

        if rel_error < 1e-6
            println("   ✅ Conservación excelente (ΔE/E₀ < 1e-6)")
        elseif rel_error < 1e-4
            println("   ✅ Conservación buena (ΔE/E₀ < 1e-4)")
        else
            println("   ⚠️  Conservación degradada (ΔE/E₀ = $(rel_error))")
        end
    end

    return (
        elapsed = elapsed,
        n_particles = n_particles,
        mode = mode,
        threads = Threads.nthreads(),
        energy_conservation = !isempty(data.conservation.energies) ?
            abs(data.conservation.energies[end] - data.conservation.energies[1]) /
            abs(data.conservation.energies[1]) : NaN,
        n_steps = length(data.times),
        max_time = max_time,
    )
end

"""
Ejecuta benchmarks para todos los configs y modos.
"""
function run_all_benchmarks(mode::Symbol)
    results = []

    for (config_path, n) in CONFIGS
        println("\n" * "#"^70)
        println("# Config: $(config_path) (N=$(n))")
        println("#"^70)

        for run in 1:N_RUNS
            if N_RUNS > 1
                println("\n--- Run $(run)/$(N_RUNS) ---")
            end

            result = run_benchmark(config_path, mode)
            push!(results, result)
        end
    end

    return results
end

"""
Guarda resultados en CSV.
"""
function save_results(results::Vector, output_file::String)
    df = DataFrame(results)
    CSV.write(output_file, df)
    println("\n✅ Resultados guardados en: $(output_file)")
    return df
end

"""
Imprime tabla de resumen.
"""
function print_summary(df::DataFrame)
    println("\n" * "="^70)
    println("RESUMEN DE BENCHMARKS")
    println("="^70)

    # Agrupar por N y mode
    gdf = groupby(df, [:n_particles, :mode])
    summary = combine(gdf, :elapsed => mean => :time_mean, :elapsed => std => :time_std)

    println("\n$(summary)")

    # Calcular speedups si hay datos secuenciales y paralelos
    if :sequential in df.mode && :parallel in df.mode
        println("\n" * "="^70)
        println("SPEEDUPS")
        println("="^70)

        for n in unique(df.n_particles)
            seq_time = mean(df[df.n_particles .== n .&& df.mode .== :sequential, :elapsed])
            par_time = mean(df[df.n_particles .== n .&& df.mode .== :parallel, :elapsed])
            speedup = seq_time / par_time

            @printf("N=%3d: Seq=%.2fs, Par=%.2fs → Speedup=%.2fx\n", n, seq_time, par_time, speedup)
        end
    end
end

# ============================================================================
# Main
# ============================================================================

function main()
    args = ARGS

    if length(args) == 0
        println("Uso: julia --project=. benchmark_seq_vs_parallel.jl [sequential|parallel]")
        println("     julia -t 24 --project=. benchmark_seq_vs_parallel.jl parallel")
        return
    end

    mode_str = args[1]
    mode = Symbol(mode_str)

    if mode ∉ [:sequential, :parallel]
        error("Modo inválido: $(mode_str). Use 'sequential' o 'parallel'")
    end

    println("\n" * "🚀"^35)
    println("Benchmark Secuencial vs Paralelo - CollectiveDynamics.jl")
    println("🚀"^35)
    println("\nModo: $(mode)")
    println("Threads disponibles: $(Threads.nthreads())")
    println("Fecha: $(Dates.now())")

    # Ejecutar benchmarks
    results = run_all_benchmarks(mode)

    # Guardar resultados
    timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
    output_dir = "results/benchmark_$(mode)_$(timestamp)"
    mkpath(output_dir)

    output_file = joinpath(output_dir, "benchmark_results.csv")
    df = save_results(results, output_file)

    # Imprimir resumen
    print_summary(df)

    println("\n✅ Benchmark completado!")
    println("   Resultados: $(output_file)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
