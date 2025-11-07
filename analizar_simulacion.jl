"""
    analizar_simulacion.jl

Script para analizar resultados de simulación usando Julia.

Uso:
    julia --project=. analizar_simulacion.jl results/simulation_20251106_175650/

Genera:
    - Estadísticas detalladas por consola
    - Gráficas de energía, velocidades, trayectorias
    - Análisis de colisiones
"""

using Pkg
Pkg.activate(".")

using DelimitedFiles
using Statistics
using Printf
using Plots  # Usaremos Plots.jl para visualización

# ============================================================================
# FUNCIONES DE CARGA
# ============================================================================

"""
Carga datos de trayectorias desde CSV.
"""
function cargar_trayectorias(dir_resultados)
    archivo = joinpath(dir_resultados, "trajectories.csv")

    if !isfile(archivo)
        error("No se encuentra $archivo")
    end

    data, header = readdlm(archivo, ',', Float64, '\n'; header=true)

    # Convertir a diccionario por columna
    columnas = Dict{String, Vector}()
    for (i, col_name) in enumerate(header[:])
        col_name_str = String(col_name)
        if col_name_str == "particle_id"
            columnas[col_name_str] = Int.(data[:, i])
        else
            columnas[col_name_str] = data[:, i]
        end
    end

    return columnas
end

"""
Carga datos de conservación desde CSV.
"""
function cargar_conservacion(dir_resultados)
    archivo = joinpath(dir_resultados, "conservation.csv")

    if !isfile(archivo)
        error("No se encuentra $archivo")
    end

    data, header = readdlm(archivo, ',', Float64, '\n'; header=true)

    return Dict(
        "time" => data[:, 1],
        "total_energy" => data[:, 2],
        "angular_momentum" => data[:, 3]
    )
end

"""
Carga datos de colisiones desde CSV.
"""
function cargar_colisiones(dir_resultados)
    archivo = joinpath(dir_resultados, "collisions_per_step.csv")

    if !isfile(archivo)
        error("No se encuentra $archivo")
    end

    data, header = readdlm(archivo, ',', Float64, '\n'; header=true)

    return Dict(
        "step" => Int.(data[:, 1]),
        "time" => data[:, 2],
        "n_collisions" => Int.(data[:, 3]),
        "conserved_fraction" => data[:, 4],
        "had_collision" => Int.(data[:, 5])
    )
end

# ============================================================================
# ANÁLISIS ESTADÍSTICO
# ============================================================================

"""
Imprime estadísticas generales de la simulación.
"""
function estadisticas_generales(traj, cons, coll)
    println()
    println("="^70)
    println("ESTADÍSTICAS GENERALES")
    println("="^70)

    # Información básica
    n_particulas = length(unique(traj["particle_id"]))
    n_frames = length(unique(traj["time"]))
    t_final = maximum(traj["time"])

    println("Partículas:         ", n_particulas)
    println("Frames guardados:   ", n_frames)
    println("Tiempo simulado:    ", @sprintf("%.3f s", t_final))
    println()

    # Energía
    E_inicial = cons["total_energy"][1]
    E_final = cons["total_energy"][end]
    ΔE = abs(E_final - E_inicial)
    error_rel = ΔE / E_inicial

    println("Energía inicial:    ", @sprintf("%.6e", E_inicial))
    println("Energía final:      ", @sprintf("%.6e", E_final))
    println("Error absoluto:     ", @sprintf("%.6e", ΔE))
    println("Error relativo:     ", @sprintf("%.6e", error_rel))

    if error_rel < 1e-6
        println("Conservación:       ✅ EXCELENTE (< 1e-6)")
    elseif error_rel < 1e-4
        println("Conservación:       ✅ BUENO (< 1e-4)")
    elseif error_rel < 1e-2
        println("Conservación:       ⚠️  ACEPTABLE (< 1e-2)")
    else
        println("Conservación:       ❌ ALTO (> 1e-2)")
    end
    println()

    # Momento Angular
    L_inicial = cons["angular_momentum"][1]
    L_final = cons["angular_momentum"][end]
    ΔL = abs(L_final - L_inicial)
    error_L = ΔL / max(abs(L_inicial), 1e-10)

    println("L inicial:          ", @sprintf("%+.6e", L_inicial))
    println("L final:            ", @sprintf("%+.6e", L_final))
    println("Error absoluto:     ", @sprintf("%.6e", ΔL))
    println("Error relativo:     ", @sprintf("%.6e", error_L))

    if error_L < 1e-6
        println("Conservación L:     ✅ EXCELENTE (< 1e-6)")
    elseif error_L < 1e-4
        println("Conservación L:     ✅ BUENO (< 1e-4)")
    elseif error_L < 1e-2
        println("Conservación L:     ⚠️  ACEPTABLE (< 1e-2)")
    else
        println("Conservación L:     ❌ ALTO (> 1e-2)")
    end
    println()

    # Colisiones
    total_coll = sum(coll["n_collisions"])
    frames_con_coll = sum(coll["had_collision"])

    println("Colisiones totales: ", total_coll)
    println("Frames con colisión:", frames_con_coll)

    if total_coll > 0
        conserved_mean = mean(coll["conserved_fraction"][coll["had_collision"] .== 1])
        println("Conservación media: ", @sprintf("%.4f", conserved_mean))
    end

    println("="^70)
    println()
end

"""
Estadísticas por partícula.
"""
function estadisticas_por_particula(traj)
    println()
    println("="^70)
    println("ESTADÍSTICAS POR PARTÍCULA")
    println("="^70)
    println()

    particulas = unique(traj["particle_id"])

    @printf("%-4s | %-12s | %-12s | %-12s | %-12s\n",
            "ID", "E_media", "E_std", "θ̇_media", "θ̇_std")
    println("-"^70)

    for pid in sort(particulas)
        idx = traj["particle_id"] .== pid

        E_vals = traj["energy"][idx]
        θ_dot_vals = traj["theta_dot"][idx]

        @printf("%-4d | %.6e | %.6e | %+.6e | %.6e\n",
                pid, mean(E_vals), std(E_vals),
                mean(θ_dot_vals), std(θ_dot_vals))
    end

    println("="^70)
    println()
end

# ============================================================================
# VISUALIZACIÓN
# ============================================================================

"""
Crea todas las gráficas de análisis.
"""
function crear_graficas(traj, cons, coll, dir_salida)
    println("📊 Generando gráficas...")

    # Tema
    theme(:default)

    particulas = sort(unique(traj["particle_id"]))

    # ========================================================================
    # Gráfica 1: Energías individuales
    # ========================================================================
    p1 = plot(title="Energía Individual por Partícula",
              xlabel="Tiempo (s)", ylabel="Energía (J)",
              legend=:outerright, size=(1200, 600))

    for pid in particulas
        idx = traj["particle_id"] .== pid
        plot!(p1, traj["time"][idx], traj["energy"][idx],
              label="Partícula $pid", alpha=0.7, linewidth=2)
    end

    savefig(p1, joinpath(dir_salida, "energia_individual.png"))
    println("  ✅ energia_individual.png")

    # ========================================================================
    # Gráfica 2: Velocidades angulares
    # ========================================================================
    p2 = plot(title="Velocidades Angulares",
              xlabel="Tiempo (s)", ylabel="θ̇ (rad/s)",
              legend=:outerright, size=(1200, 600))

    for pid in particulas
        idx = traj["particle_id"] .== pid
        plot!(p2, traj["time"][idx], traj["theta_dot"][idx],
              label="Partícula $pid", alpha=0.7, linewidth=2)
    end

    savefig(p2, joinpath(dir_salida, "velocidades_angulares.png"))
    println("  ✅ velocidades_angulares.png")

    # ========================================================================
    # Gráfica 3: Trayectorias en el espacio
    # ========================================================================
    p3 = plot(title="Trayectorias en el Espacio (x-y)",
              xlabel="X", ylabel="Y",
              aspect_ratio=:equal, legend=:outerright,
              size=(900, 800))

    for pid in particulas
        idx = traj["particle_id"] .== pid
        plot!(p3, traj["x"][idx], traj["y"][idx],
              label="Partícula $pid", alpha=0.6, linewidth=2)
    end

    savefig(p3, joinpath(dir_salida, "trayectorias.png"))
    println("  ✅ trayectorias.png")

    # ========================================================================
    # Gráfica 4: Conservación de energía total
    # ========================================================================
    p4 = plot(title="Conservación de Energía Total",
              xlabel="Tiempo (s)", ylabel="Energía Total (J)",
              legend=false, size=(1200, 600))

    plot!(p4, cons["time"], cons["total_energy"],
          linewidth=2, color=:blue)

    # Añadir línea de referencia
    E0 = cons["total_energy"][1]
    hline!(p4, [E0], linestyle=:dash, color=:red, linewidth=1,
           label="Energía inicial")

    savefig(p4, joinpath(dir_salida, "conservacion_energia.png"))
    println("  ✅ conservacion_energia.png")

    # ========================================================================
    # Gráfica 5: Conservación de momento angular
    # ========================================================================
    p5 = plot(title="Conservación de Momento Angular",
              xlabel="Tiempo (s)", ylabel="L (kg·m²/s)",
              legend=false, size=(1200, 600))

    plot!(p5, cons["time"], cons["angular_momentum"],
          linewidth=2, color=:purple)

    # Añadir línea de referencia
    L0 = cons["angular_momentum"][1]
    hline!(p5, [L0], linestyle=:dash, color=:red, linewidth=1,
           label="L inicial")

    savefig(p5, joinpath(dir_salida, "conservacion_momento_angular.png"))
    println("  ✅ conservacion_momento_angular.png")

    # ========================================================================
    # Gráfica 6: Eventos de colisión
    # ========================================================================
    if sum(coll["had_collision"]) > 0
        idx_coll = coll["had_collision"] .== 1

        p6 = scatter(coll["time"][idx_coll], coll["n_collisions"][idx_coll],
                     title="Eventos de Colisión",
                     xlabel="Tiempo (s)", ylabel="Número de Colisiones",
                     legend=false, markersize=8, color=:red, alpha=0.6,
                     size=(1200, 600))

        savefig(p6, joinpath(dir_salida, "eventos_colision.png"))
        println("  ✅ eventos_colision.png")
    else
        println("  ⚠️  Sin colisiones - no se genera eventos_colision.png")
    end

    # ========================================================================
    # Gráfica 7: Error de energía relativo
    # ========================================================================
    E0 = cons["total_energy"][1]
    error_rel = abs.(cons["total_energy"] .- E0) ./ E0

    p7 = plot(title="Error Relativo de Energía",
              xlabel="Tiempo (s)", ylabel="|ΔE/E₀|",
              yscale=:log10, legend=false, size=(1200, 600))

    plot!(p7, cons["time"], error_rel, linewidth=2, color=:blue)

    # Líneas de referencia
    hline!(p7, [1e-6], linestyle=:dash, color=:green, linewidth=1,
           label="Excelente (1e-6)")
    hline!(p7, [1e-4], linestyle=:dash, color=:orange, linewidth=1,
           label="Bueno (1e-4)")
    hline!(p7, [1e-2], linestyle=:dash, color=:red, linewidth=1,
           label="Aceptable (1e-2)")

    savefig(p7, joinpath(dir_salida, "error_energia.png"))
    println("  ✅ error_energia.png")

    println()
end

# ============================================================================
# MAIN
# ============================================================================

function main()
    # Verificar argumentos
    if length(ARGS) < 1
        println("Uso: julia --project=. analizar_simulacion.jl <directorio_resultados>")
        println()
        println("Ejemplo:")
        println("  julia --project=. analizar_simulacion.jl results/simulation_20251106_175650/")
        exit(1)
    end

    dir_resultados = ARGS[1]

    # Verificar que existe
    if !isdir(dir_resultados)
        println("❌ Error: Directorio no encontrado: $dir_resultados")
        exit(1)
    end

    println()
    println("="^70)
    println("ANÁLISIS DE SIMULACIÓN")
    println("="^70)
    println("Directorio: $dir_resultados")

    # Cargar datos
    println()
    println("📥 Cargando datos...")
    traj = cargar_trayectorias(dir_resultados)
    cons = cargar_conservacion(dir_resultados)
    coll = cargar_colisiones(dir_resultados)
    println("  ✅ Datos cargados correctamente")

    # Estadísticas
    estadisticas_generales(traj, cons, coll)
    estadisticas_por_particula(traj)

    # Crear directorio para gráficas
    dir_graficas = joinpath(dir_resultados, "analisis")
    if !isdir(dir_graficas)
        mkdir(dir_graficas)
    end

    # Generar gráficas
    crear_graficas(traj, cons, coll, dir_graficas)

    println()
    println("="^70)
    println("✅ ANÁLISIS COMPLETADO")
    println("="^70)
    println()
    println("Gráficas guardadas en:")
    println("  📁 $dir_graficas/")
    println()
    println("Archivos generados:")
    println("  - energia_individual.png")
    println("  - velocidades_angulares.png")
    println("  - trayectorias.png")
    println("  - conservacion_energia.png")
    println("  - error_energia.png")
    if sum(coll["had_collision"]) > 0
        println("  - eventos_colision.png")
    end
    println()
end

# Ejecutar
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
