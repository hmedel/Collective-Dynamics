"""
    estadisticas_simulacion.jl

Script simple para ver estadísticas sin generar gráficas.
No requiere paquetes adicionales - solo biblioteca estándar.

Uso:
    julia --project=. estadisticas_simulacion.jl results/simulation_20251106_175650/
"""

using DelimitedFiles
using Statistics
using Printf

# ============================================================================
# CARGA DE DATOS
# ============================================================================

function cargar_csv(archivo)
    if !isfile(archivo)
        error("No se encuentra $archivo")
    end
    return readdlm(archivo, ',', Float64, '\n'; header=true)
end

# ============================================================================
# ANÁLISIS
# ============================================================================

function analizar(dir_resultados)
    println()
    println("="^70)
    println("ANÁLISIS DETALLADO DE SIMULACIÓN")
    println("="^70)
    println("Directorio: $dir_resultados")
    println()

    # ========================================================================
    # 1. TRAYECTORIAS
    # ========================================================================
    println("📥 Cargando trayectorias...")
    traj_data, traj_header = cargar_csv(joinpath(dir_resultados, "trajectories.csv"))

    n_filas = size(traj_data, 1)
    particulas_id = unique(Int.(traj_data[:, 2]))  # Columna particle_id
    n_particulas = length(particulas_id)
    tiempos = unique(traj_data[:, 1])
    n_frames = length(tiempos)
    t_final = maximum(tiempos)

    println("  ✅ $n_filas filas cargadas")
    println("  • Partículas: $n_particulas")
    println("  • Frames guardados: $n_frames")
    println("  • Tiempo simulado: $(round(t_final, digits=3)) s")
    println()

    # ========================================================================
    # 2. CONSERVACIÓN
    # ========================================================================
    println("📥 Cargando datos de conservación...")
    cons_data, cons_header = cargar_csv(joinpath(dir_resultados, "conservation.csv"))

    E_inicial = cons_data[1, 2]
    E_final = cons_data[end, 2]
    ΔE = abs(E_final - E_inicial)
    error_rel = ΔE / E_inicial

    println("  ✅ $(size(cons_data, 1)) puntos cargados")
    println()

    println("="^70)
    println("CONSERVACIÓN DE ENERGÍA")
    println("="^70)
    println(@sprintf("  Energía inicial:    %.10e J", E_inicial))
    println(@sprintf("  Energía final:      %.10e J", E_final))
    println(@sprintf("  Diferencia abs:     %.10e J", ΔE))
    println(@sprintf("  Error relativo:     %.10e", error_rel))
    println()

    if error_rel < 1e-6
        println("  Estado: ✅ EXCELENTE (error < 1e-6)")
    elseif error_rel < 1e-4
        println("  Estado: ✅ BUENO (error < 1e-4)")
    elseif error_rel < 1e-2
        println("  Estado: ⚠️  ACEPTABLE (error < 1e-2)")
    else
        println("  Estado: ❌ ALTO (error > 1e-2)")
    end
    println()

    # Momento
    px_inicial = cons_data[1, 3]
    py_inicial = cons_data[1, 4]
    px_final = cons_data[end, 3]
    py_final = cons_data[end, 4]

    p_inicial = sqrt(px_inicial^2 + py_inicial^2)
    p_final = sqrt(px_final^2 + py_final^2)
    Δp = abs(p_final - p_inicial)

    println("CONSERVACIÓN DE MOMENTO")
    println("="^70)
    println(@sprintf("  Momento inicial:    %.10e", p_inicial))
    println(@sprintf("  Momento final:      %.10e", p_final))
    println(@sprintf("  Diferencia abs:     %.10e", Δp))
    println()

    # ========================================================================
    # 3. COLISIONES
    # ========================================================================
    println("📥 Cargando datos de colisiones...")
    coll_data, coll_header = cargar_csv(joinpath(dir_resultados, "collisions_per_step.csv"))

    total_colisiones = sum(Int.(coll_data[:, 3]))  # n_collisions
    frames_con_colision = sum(Int.(coll_data[:, 5]))  # had_collision

    println("  ✅ $(size(coll_data, 1)) pasos cargados")
    println()

    println("="^70)
    println("ESTADÍSTICAS DE COLISIONES")
    println("="^70)
    println("  Total de colisiones:     $total_colisiones")
    println("  Frames con colisión:     $frames_con_colision")

    if total_colisiones > 0
        idx_con_coll = Int.(coll_data[:, 5]) .== 1
        conserved_fracs = coll_data[idx_con_coll, 4]

        println(@sprintf("  Conservación media:      %.4f", mean(conserved_fracs)))
        println(@sprintf("  Conservación mínima:     %.4f", minimum(conserved_fracs)))

        # Mostrar tiempos de colisión
        tiempos_coll = coll_data[idx_con_coll, 2]
        n_coll_por_frame = Int.(coll_data[idx_con_coll, 3])

        println()
        println("  Primeras 10 colisiones:")
        println("  " * "-"^60)
        @printf("  %-6s | %-15s | %-15s\n", "Frame", "Tiempo (s)", "N° Colisiones")
        println("  " * "-"^60)

        for i in 1:min(10, length(tiempos_coll))
            @printf("  %-6d | %15.6f | %15d\n",
                    i, tiempos_coll[i], n_coll_por_frame[i])
        end
    else
        println("  ⚠️  No hubo colisiones en esta simulación")
    end
    println()

    # ========================================================================
    # 4. ESTADÍSTICAS POR PARTÍCULA
    # ========================================================================
    println("="^70)
    println("ESTADÍSTICAS POR PARTÍCULA")
    println("="^70)
    println()

    # Columnas: time, particle_id, theta, theta_dot, x, y, vx, vy, energy
    @printf("%-4s | %-12s | %-12s | %-12s | %-12s\n",
            "ID", "E_media", "E_desv", "θ̇_media", "θ̇_desv")
    println("-"^70)

    for pid in sort(particulas_id)
        idx = Int.(traj_data[:, 2]) .== pid

        energias = traj_data[idx, 9]      # energy
        theta_dots = traj_data[idx, 4]    # theta_dot

        @printf("%-4d | %.6e | %.6e | %+.6e | %.6e\n",
                pid,
                mean(energias), std(energias),
                mean(theta_dots), std(theta_dots))
    end

    println("="^70)
    println()

    # ========================================================================
    # 5. RANGOS DE VALORES
    # ========================================================================
    println("="^70)
    println("RANGOS DE VALORES")
    println("="^70)
    println()

    # Para todas las partículas
    energias_todas = traj_data[:, 9]
    theta_dots_todas = traj_data[:, 4]
    thetas_todas = traj_data[:, 3]

    println("Energía individual:")
    println(@sprintf("  Mínima:  %.6e J", minimum(energias_todas)))
    println(@sprintf("  Máxima:  %.6e J", maximum(energias_todas)))
    println(@sprintf("  Media:   %.6e J", mean(energias_todas)))
    println(@sprintf("  Desv:    %.6e J", std(energias_todas)))
    println()

    println("Velocidad angular (θ̇):")
    println(@sprintf("  Mínima:  %+.6f rad/s", minimum(theta_dots_todas)))
    println(@sprintf("  Máxima:  %+.6f rad/s", maximum(theta_dots_todas)))
    println(@sprintf("  Media:   %+.6f rad/s", mean(theta_dots_todas)))
    println(@sprintf("  Desv:    %.6f rad/s", std(theta_dots_todas)))
    println()

    println("Posición angular (θ):")
    println(@sprintf("  Mínima:  %.4f rad", minimum(thetas_todas)))
    println(@sprintf("  Máxima:  %.4f rad", maximum(thetas_todas)))
    println(@sprintf("  Rango:   %.4f rad (%.2f revoluciones)",
            maximum(thetas_todas) - minimum(thetas_todas),
            (maximum(thetas_todas) - minimum(thetas_todas)) / (2π)))
    println()

    # ========================================================================
    # RESUMEN FINAL
    # ========================================================================
    println("="^70)
    println("✅ ANÁLISIS COMPLETADO")
    println("="^70)
    println()
    println("Archivos analizados:")
    println("  • trajectories.csv       ($n_filas filas)")
    println("  • conservation.csv       ($(size(cons_data, 1)) puntos)")
    println("  • collisions_per_step.csv ($(size(coll_data, 1)) pasos)")
    println()

    if error_rel < 1e-4
        println("🎯 Resultado: Simulación exitosa con buena conservación")
    elseif error_rel < 1e-2
        println("⚠️  Resultado: Simulación aceptable, considerar reducir dt")
    else
        println("❌ Resultado: Problemas de conservación - revisar parámetros")
    end
    println()
end

# ============================================================================
# MAIN
# ============================================================================

function main()
    if length(ARGS) < 1
        println("Uso: julia --project=. estadisticas_simulacion.jl <directorio_resultados>")
        println()
        println("Ejemplo:")
        println("  julia --project=. estadisticas_simulacion.jl results/simulation_20251106_175650/")
        exit(1)
    end

    dir_resultados = ARGS[1]

    if !isdir(dir_resultados)
        println("❌ Error: Directorio no encontrado: $dir_resultados")
        exit(1)
    end

    analizar(dir_resultados)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
