#!/usr/bin/env julia
"""
    run_simulation.jl

Script principal para ejecutar simulaciones desde archivos de configuración.

# Uso
```bash
julia --project=. run_simulation.jl config/simulation_example.toml
```

O con argumentos adicionales:
```bash
julia --project=. run_simulation.jl config/simulation_example.toml --verbose --threads=4
```

Este script:
1. Lee la configuración desde archivo TOML
2. Crea/carga partículas según especificado
3. Ejecuta la simulación (adaptativa o dt fijo)
4. Guarda todos los resultados en directorio timestamped
5. Genera resumen y estadísticas
"""

using Pkg
Pkg.activate(".")

using CollectiveDynamics
using Printf
using Dates

# ============================================================================
# FUNCIONES AUXILIARES
# ============================================================================

function print_banner()
    println()
    println("="^70)
    println("  COLLECTIVE DYNAMICS - Sistema de Simulación")
    println("  Dinámica en Variedades Curvas (Elipse)")
    println("="^70)
    println()
end

function print_usage()
    println("""
    Uso:
      julia --project=. run_simulation.jl <config_file.toml>

    Ejemplo:
      julia --project=. run_simulation.jl config/simulation_example.toml

    El archivo de configuración especifica:
      - Geometría de la elipse (a, b)
      - Método de simulación (adaptive/fixed)
      - Parámetros de partículas
      - Directorio y formatos de salida

    Ver config/simulation_example.toml para un ejemplo completo.
    """)
end

"""
    run_simulation_from_config(config_file::String)

Ejecuta simulación completa desde archivo de configuración.
"""
function run_simulation_from_config(config_file::String)
    print_banner()

    # 1. Leer y validar configuración
    println("📖 Leyendo configuración...")
    config = read_config(config_file)
    validate_config(config)
    println()

    # 2. Extraer parámetros de geometría
    a = Float64(config["geometry"]["a"])
    b = Float64(config["geometry"]["b"])

    println("📐 Geometría: Elipse con a = $a, b = $b")
    println()

    # 3. Crear/cargar partículas
    particles = create_particles_from_config(config, a, b)

    # Mostrar energía inicial
    E0 = total_energy(particles, a, b)
    println(@sprintf("💡 Energía inicial: E₀ = %.6f", E0))
    println()

    # 4. Preparar parámetros de simulación
    sim_config = config["simulation"]
    method = sim_config["method"]
    max_time = Float64(sim_config["max_time"])
    save_interval = Float64(sim_config["save_interval"])
    collision_method = Symbol(sim_config["collision_method"])
    tolerance = Float64(sim_config["tolerance"])
    verbose = sim_config["verbose"]

    # 5. Ejecutar simulación
    println("="^70)
    println("🚀 EJECUTANDO SIMULACIÓN")
    println("="^70)
    println()

    start_time = now()

    if method == "adaptive"
        # Método adaptativo
        dt_max = Float64(sim_config["dt_max"])
        dt_min = Float64(sim_config["dt_min"])

        data = simulate_ellipse_adaptive(
            particles, a, b;
            max_time = max_time,
            dt_max = dt_max,
            dt_min = dt_min,
            save_interval = save_interval,
            collision_method = collision_method,
            tolerance = tolerance,
            verbose = verbose
        )

    elseif method == "fixed"
        # Método de dt fijo
        dt = Float64(sim_config["dt_fixed"])
        n_steps = Int(round(max_time / dt))

        data = simulate_ellipse(
            particles, a, b;
            n_steps = n_steps,
            dt = dt,
            save_interval = save_interval,
            collision_method = collision_method,
            tolerance = tolerance,
            verbose = verbose
        )

    else
        error("Método desconocido: $method")
    end

    end_time = now()
    elapsed = Dates.value(end_time - start_time) / 1000.0  # Segundos

    println()
    println("="^70)
    println("✅ SIMULACIÓN COMPLETADA")
    println("="^70)
    println(@sprintf("⏱️  Tiempo de ejecución: %.2f segundos", elapsed))
    println()

    # 6. Crear directorio de salida
    output_dir = create_output_directory(config)

    # 7. Guardar resultados
    save_simulation_results(data, config, config_file, output_dir)

    println()
    println("="^70)
    println("🎉 PROCESO COMPLETO")
    println("="^70)
    println()
    println("Resultados guardados en:")
    println("  📁 $output_dir")
    println()

    # Mostrar resumen rápido
    E_analysis = analyze_energy_conservation(data.conservation)
    println("Resumen rápido:")
    println(@sprintf("  • Pasos: %d", length(data.times)))
    println(@sprintf("  • Colisiones: %d", sum(data.n_collisions)))
    println(@sprintf("  • Error energía: %.3e", E_analysis.max_rel_error))

    if E_analysis.max_rel_error < 1e-6
        println("  • Conservación: ✅ EXCELENTE (< 1e-6)")
    elseif E_analysis.max_rel_error < 1e-4
        println("  • Conservación: ✅ BUENO (< 1e-4)")
    elseif E_analysis.max_rel_error < 1e-2
        println("  • Conservación: ⚠️  ACEPTABLE (< 1e-2)")
    else
        println("  • Conservación: ❌ ALTO (> 1e-2)")
    end

    println()
    println("Para ver detalles completos, consulta:")
    println("  📄 $(joinpath(output_dir, "summary.txt"))")
    println()

    return output_dir
end

# ============================================================================
# MAIN
# ============================================================================

function main()
    # Verificar argumentos
    if length(ARGS) < 1
        println("❌ Error: Falta archivo de configuración")
        println()
        print_usage()
        exit(1)
    end

    config_file = ARGS[1]

    # Verificar que existe el archivo
    if !isfile(config_file)
        println("❌ Error: Archivo no encontrado: $config_file")
        exit(1)
    end

    # Ejecutar simulación
    try
        output_dir = run_simulation_from_config(config_file)
        exit(0)  # Éxito
    catch e
        println()
        println("="^70)
        println("❌ ERROR DURANTE LA SIMULACIÓN")
        println("="^70)
        println()
        println("Tipo de error: ", typeof(e))
        println("Mensaje: ", e)
        println()
        println("Stack trace:")
        showerror(stdout, e, catch_backtrace())
        println()
        exit(1)  # Error
    end
end

# Ejecutar si se llama como script
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
