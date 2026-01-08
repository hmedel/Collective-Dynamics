#!/usr/bin/env julia
"""
visualizar_resultados.jl

Genera visualizaciones de la simulación:
1. Conservación de energía y momento vs tiempo
2. Espacio fase unwrapped con todas las trayectorias

Uso:
    julia --project=. visualizar_resultados.jl results/analisis_completo_YYYYMMDD_HHMMSS/
"""

using Pkg
Pkg.activate(".")

using CollectiveDynamics
using Plots
using CSV
using DataFrames
using Statistics
using Printf

# Configuración de plots
gr()  # Backend GR (rápido)
default(
    fontfamily = "Computer Modern",
    titlefontsize = 12,
    guidefontsize = 10,
    tickfontsize = 8,
    legendfontsize = 8,
    dpi = 300
)

# =============================================================================
# ARGUMENTOS
# =============================================================================

if length(ARGS) < 1
    println("Uso: julia --project=. visualizar_resultados.jl <directorio_resultados>")
    println()
    println("Ejemplo:")
    println("  julia --project=. visualizar_resultados.jl results/analisis_completo_20251113_222033/")
    exit(1)
end

results_dir = ARGS[1]

if !isdir(results_dir)
    error("Directorio no existe: $results_dir")
end

println("="^70)
println("GENERANDO VISUALIZACIONES")
println("="^70)
println()
println("Directorio de resultados: $results_dir")
println()

# =============================================================================
# CARGAR DATOS
# =============================================================================

println("Cargando datos...")

# Conservación
conservation_file = joinpath(results_dir, "conservation.csv")
if !isfile(conservation_file)
    error("No se encuentra conservation.csv en $results_dir")
end
df_conservation = CSV.read(conservation_file, DataFrame)

# Partículas iniciales y finales
particles_initial_file = joinpath(results_dir, "particles_initial.csv")
particles_final_file = joinpath(results_dir, "particles_final.csv")

df_initial = CSV.read(particles_initial_file, DataFrame)
df_final = CSV.read(particles_final_file, DataFrame)

N_particles = nrow(df_initial)
println("✅ Datos cargados: $(nrow(df_conservation)) puntos temporales, $N_particles partículas")
println()

# =============================================================================
# CARGAR TODAS LAS TRAYECTORIAS PARA ESPACIO FASE
# =============================================================================

println("Reconstruyendo trayectorias completas desde snapshots...")

# Necesitamos cargar el SimulationData completo o reconstruir desde los snapshots
# Como los snapshots no están en CSV, vamos a generar una aproximación usando
# los datos iniciales y finales

# Para un espacio fase completo, necesitamos todos los snapshots
# Vamos a usar los datos del objeto SimulationData guardado

# Alternativamente, podemos re-ejecutar la simulación brevemente o
# usar interpolación. Por ahora, voy a crear un plot conceptual
# y luego mejorar si tienes el archivo .jld2

# =============================================================================
# PLOT 1: CONSERVACIÓN DE ENERGÍA
# =============================================================================

println("Generando plot de conservación de energía...")

times = df_conservation.time
energies = df_conservation.energy
E0 = energies[1]
delta_E_rel = df_conservation.delta_E_rel

p1 = plot(
    times, energies,
    xlabel = "Tiempo (s)",
    ylabel = "Energía Total",
    title = "Conservación de Energía",
    legend = false,
    linewidth = 2,
    color = :blue,
    grid = true,
    gridstyle = :dash,
    gridalpha = 0.3
)

# Línea de referencia E₀
hline!(p1, [E0], linestyle=:dash, color=:red, linewidth=1, label="E₀")

p2 = plot(
    times, delta_E_rel,
    xlabel = "Tiempo (s)",
    ylabel = "ΔE/E₀",
    title = "Error Relativo de Energía",
    legend = false,
    linewidth = 2,
    color = :red,
    grid = true,
    gridstyle = :dash,
    gridalpha = 0.3,
    yscale = :log10
)

# Líneas de referencia de calidad
hline!(p2, [1e-6], linestyle=:dash, color=:orange, linewidth=1, alpha=0.5, label="Bueno (1e-6)")
hline!(p2, [1e-8], linestyle=:dash, color=:green, linewidth=1, alpha=0.5, label="Muy bueno (1e-8)")
hline!(p2, [1e-10], linestyle=:dash, color=:blue, linewidth=1, alpha=0.5, label="Excelente (1e-10)")

plot_energy = plot(p1, p2, layout=(2, 1), size=(800, 600))

energy_file = joinpath(results_dir, "conservacion_energia.png")
savefig(plot_energy, energy_file)
println("✅ $energy_file")

# =============================================================================
# PLOT 2: CONSERVACIÓN DE MOMENTO
# =============================================================================

println("Generando plot de conservación de momento...")

momenta = df_conservation.momentum
P0 = momenta[1]
delta_P_rel = df_conservation.delta_P_rel

p3 = plot(
    times, momenta,
    xlabel = "Tiempo (s)",
    ylabel = "Momento Conjugado Total",
    title = "Conservación de Momento Conjugado",
    legend = false,
    linewidth = 2,
    color = :green,
    grid = true,
    gridstyle = :dash,
    gridalpha = 0.3
)

hline!(p3, [P0], linestyle=:dash, color=:red, linewidth=1, label="P₀")

p4 = plot(
    times, delta_P_rel,
    xlabel = "Tiempo (s)",
    ylabel = "ΔP/P₀",
    title = "Error Relativo de Momento",
    legend = false,
    linewidth = 2,
    color = :purple,
    grid = true,
    gridstyle = :dash,
    gridalpha = 0.3,
    yscale = :log10
)

hline!(p4, [1e-6], linestyle=:dash, color=:orange, linewidth=1, alpha=0.5)
hline!(p4, [1e-8], linestyle=:dash, color=:green, linewidth=1, alpha=0.5)
hline!(p4, [1e-10], linestyle=:dash, color=:blue, linewidth=1, alpha=0.5)

plot_momentum = plot(p3, p4, layout=(2, 1), size=(800, 600))

momentum_file = joinpath(results_dir, "conservacion_momento.png")
savefig(plot_momentum, momentum_file)
println("✅ $momentum_file")

# =============================================================================
# PLOT 3: CONSERVACIÓN COMBINADA
# =============================================================================

println("Generando plot combinado de conservación...")

plot_combined = plot(
    times, [delta_E_rel delta_P_rel],
    xlabel = "Tiempo (s)",
    ylabel = "Error Relativo",
    title = "Conservación de Energía y Momento",
    label = ["ΔE/E₀" "ΔP/P₀"],
    linewidth = 2,
    color = [:blue :green],
    grid = true,
    gridstyle = :dash,
    gridalpha = 0.3,
    yscale = :log10,
    legend = :topright,
    size = (800, 500)
)

hline!(plot_combined, [1e-6], linestyle=:dash, color=:orange, linewidth=1, alpha=0.3, label="")
hline!(plot_combined, [1e-8], linestyle=:dash, color=:green, linewidth=1, alpha=0.3, label="")
hline!(plot_combined, [1e-10], linestyle=:dash, color=:blue, linewidth=1, alpha=0.3, label="")

combined_file = joinpath(results_dir, "conservacion_combinada.png")
savefig(plot_combined, combined_file)
println("✅ $combined_file")

# =============================================================================
# PLOT 4: ESPACIO FASE UNWRAPPED - NECESITA CARGAR DATA COMPLETA
# =============================================================================

println()
println("Generando espacio fase unwrapped...")
println("Nota: Para trayectorias completas, necesitamos el objeto SimulationData.")
println("      Buscando archivo .jld2 o regenerando simulación...")
println()

# Intentar cargar desde JLD2 si existe
using JLD2

jld2_file = joinpath(results_dir, "simulation_data.jld2")
data = nothing

if isfile(jld2_file)
    println("✅ Encontrado archivo JLD2: $jld2_file")
    data = load(jld2_file, "data")
else
    # Si no hay JLD2, necesitamos regenerar o usar solo inicial/final
    println("⚠️  No se encuentra archivo .jld2")
    println("    Generando espacio fase con estados inicial y final únicamente...")
end

# Función para unwrap ángulos
function unwrap_angles(angles::Vector{T}) where T
    unwrapped = similar(angles)
    unwrapped[1] = angles[1]

    for i in 2:length(angles)
        diff = angles[i] - angles[i-1]

        # Detectar salto en 2π
        if diff > π
            unwrapped[i] = unwrapped[i-1] + (diff - 2π)
        elseif diff < -π
            unwrapped[i] = unwrapped[i-1] + (diff + 2π)
        else
            unwrapped[i] = unwrapped[i-1] + diff
        end
    end

    return unwrapped
end

if data !== nothing
    # Tenemos data completa
    n_snapshots = length(data.particles)
    n_particles = length(data.particles[1])

    println("Procesando $(n_particles) partículas × $(n_snapshots) snapshots...")

    # Crear plot de espacio fase
    p_phase = plot(
        xlabel = "θ (unwrapped)",
        ylabel = "θ̇",
        title = "Espacio Fase Unwrapped - $(n_particles) Partículas",
        legend = false,
        grid = true,
        gridstyle = :dash,
        gridalpha = 0.3,
        size = (900, 700)
    )

    # Para cada partícula, extraer trayectoria
    for particle_id in 1:n_particles
        # Extraer θ y θ̇ en todos los tiempos
        θ_trajectory = [data.particles[snap][particle_id].θ for snap in 1:n_snapshots]
        θ_dot_trajectory = [data.particles[snap][particle_id].θ_dot for snap in 1:n_snapshots]

        # Unwrap θ
        θ_unwrapped = unwrap_angles(θ_trajectory)

        # Plot con color diferente por partícula (o alpha bajo para todas)
        plot!(p_phase, θ_unwrapped, θ_dot_trajectory,
              linewidth = 1,
              alpha = 0.6,
              color = :auto)
    end

    phase_file = joinpath(results_dir, "espacio_fase_unwrapped.png")
    savefig(p_phase, phase_file)
    println("✅ $phase_file")

else
    # Solo tenemos inicial y final - plot simplificado
    println("Generando espacio fase simplificado (inicial → final)...")

    p_phase_simple = plot(
        xlabel = "θ",
        ylabel = "θ̇",
        title = "Espacio Fase - Estados Inicial y Final",
        legend = :topright,
        grid = true,
        gridstyle = :dash,
        gridalpha = 0.3,
        size = (800, 600)
    )

    # Estado inicial
    scatter!(p_phase_simple, df_initial.theta, df_initial.theta_dot,
             label = "Inicial",
             markersize = 6,
             markercolor = :blue,
             markeralpha = 0.6)

    # Estado final
    scatter!(p_phase_simple, df_final.theta, df_final.theta_dot,
             label = "Final",
             markersize = 6,
             markercolor = :red,
             markeralpha = 0.6)

    phase_file = joinpath(results_dir, "espacio_fase_simple.png")
    savefig(p_phase_simple, phase_file)
    println("✅ $phase_file")

    println()
    println("⚠️  Para espacio fase completo con trayectorias:")
    println("    1. Ejecuta la simulación con save_jld2=true en config")
    println("    2. O guarda el objeto SimulationData manualmente")
end

# =============================================================================
# RESUMEN
# =============================================================================

println()
println("="^70)
println("✅ VISUALIZACIONES COMPLETADAS")
println("="^70)
println()
println("Archivos generados en: $results_dir")
println()
println("  1. conservacion_energia.png       - E(t) y ΔE/E₀")
println("  2. conservacion_momento.png       - P(t) y ΔP/P₀")
println("  3. conservacion_combinada.png     - Errores relativos")

if data !== nothing
    println("  4. espacio_fase_unwrapped.png     - Trayectorias completas")
else
    println("  4. espacio_fase_simple.png        - Estados inicial/final")
    println()
    println("     💡 Tip: Para trayectorias completas, necesitas SimulationData")
end

println()
println("="^70)
