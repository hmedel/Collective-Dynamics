"""
analizar_espacio_fase.jl

Análisis del espacio fase (θ, θ̇) para todas las partículas durante la simulación.

Genera visualizaciones de las trayectorias en el espacio fase, marcando colisiones
y superponiendo curvas de energía constante.

Uso:
    julia --project=. analizar_espacio_fase.jl results/simulation_XXXXXX/
"""

using Plots
using DelimitedFiles
using Printf
using ColorSchemes

# Verificar argumentos
if length(ARGS) < 1
    println("❌ Error: Proporciona el directorio de resultados")
    println()
    println("Uso:")
    println("  julia --project=. analizar_espacio_fase.jl results/simulation_XXXXXX/")
    exit(1)
end

dir_resultados = ARGS[1]

println("="^80)
println("ANÁLISIS DE ESPACIO FASE (θ, θ̇)")
println("="^80)
println()

# ============================================================================
# Cargar datos
# ============================================================================
println("📥 Cargando datos de trayectorias...")

archivo_traj = joinpath(dir_resultados, "trajectories.csv")
if !isfile(archivo_traj)
    println("❌ Error: No se encontró trajectories.csv")
    exit(1)
end

# Leer datos
data, header = readdlm(archivo_traj, ',', Float64, '\n'; header=true)

# Columnas: time, particle_id, theta, theta_dot, x, y, vx, vy, energy
time = data[:, 1]
particle_id = Int.(data[:, 2])
theta = data[:, 3]
theta_dot = data[:, 4]
energy_particle = data[:, 9]

n_total_points = length(time)
unique_ids = sort(unique(particle_id))
n_particles = length(unique_ids)

println("  ✅ $(n_total_points) puntos cargados")
println("  ✅ $(n_particles) partículas")
println()

# Cargar geometría
archivo_config = joinpath(dir_resultados, "config_used.toml")
if isfile(archivo_config)
    using TOML
    config = TOML.parsefile(archivo_config)
    a = config["geometry"]["a"]
    b = config["geometry"]["b"]
    println("  Geometría: a = $a, b = $b")
else
    a = 2.0
    b = 1.0
    println("  ⚠️  Usando geometría por defecto: a = $a, b = $b")
end
println()

# ============================================================================
# Organizar datos por partícula
# ============================================================================
println("📊 Organizando datos por partícula...")

# Diccionario para almacenar trayectorias
trayectorias = Dict{Int, NamedTuple}()

for id in unique_ids
    mask = particle_id .== id
    trayectorias[id] = (
        time = time[mask],
        theta = theta[mask],
        theta_dot = theta_dot[mask],
        energy = energy_particle[mask]
    )
end

println("  ✅ Trayectorias organizadas")
println()

# ============================================================================
# Cargar información de colisiones
# ============================================================================
println("📥 Cargando datos de colisiones...")

archivo_coll = joinpath(dir_resultados, "collisions_per_step.csv")
if isfile(archivo_coll)
    coll_data, _ = readdlm(archivo_coll, ',', '\n'; header=true)
    time_coll = Float64.(coll_data[:, 1])
    had_collision = Bool.(coll_data[:, 5])

    # Tiempos donde ocurrieron colisiones
    collision_times = time_coll[had_collision]
    n_collisions = length(collision_times)

    println("  ✅ $(n_collisions) colisiones detectadas")
else
    collision_times = Float64[]
    n_collisions = 0
    println("  ⚠️  No se encontró información de colisiones")
end
println()

# ============================================================================
# Gráfica 1: Espacio Fase Completo - Todas las Partículas
# ============================================================================
println("📊 Generando gráfica 1: Espacio fase completo...")

p1 = plot(
    xlabel = "θ (rad)",
    ylabel = "θ̇ (rad/s)",
    title = "Espacio Fase: Todas las Trayectorias",
    legend = :outerright,
    size = (1200, 800),
    dpi = 150
)

# Paleta de colores
colores = palette(:tab10, n_particles)

# Graficar cada partícula
for (idx, id) in enumerate(unique_ids)
    traj = trayectorias[id]
    plot!(p1, traj.theta, traj.theta_dot,
          label = "Partícula $id",
          linewidth = 1.5,
          color = colores[idx],
          alpha = 0.7)

    # Marcar inicio con círculo
    scatter!(p1, [traj.theta[1]], [traj.theta_dot[1]],
             marker = :circle,
             markersize = 6,
             color = colores[idx],
             label = "")

    # Marcar final con cuadrado
    scatter!(p1, [traj.theta[end]], [traj.theta_dot[end]],
             marker = :square,
             markersize = 6,
             color = colores[idx],
             label = "")
end

savefig(p1, joinpath(dir_resultados, "espacio_fase_completo.png"))
println("  ✅ espacio_fase_completo.png")

# ============================================================================
# Gráfica 2: Espacio Fase con Colisiones Marcadas
# ============================================================================
if n_collisions > 0
    println("📊 Generando gráfica 2: Espacio fase con colisiones...")

    p2 = plot(
        xlabel = "θ (rad)",
        ylabel = "θ̇ (rad/s)",
        title = "Espacio Fase con Colisiones (puntos rojos)",
        legend = :outerright,
        size = (1200, 800),
        dpi = 150
    )

    # Graficar trayectorias
    for (idx, id) in enumerate(unique_ids)
        traj = trayectorias[id]
        plot!(p2, traj.theta, traj.theta_dot,
              label = "Partícula $id",
              linewidth = 1.5,
              color = colores[idx],
              alpha = 0.6)
    end

    # Marcar colisiones
    # Para cada tiempo de colisión, encontrar estados cercanos de todas las partículas
    tolerance_time = 0.001  # 1 ms de tolerancia

    for t_coll in collision_times
        for id in unique_ids
            traj = trayectorias[id]
            # Encontrar índice más cercano a tiempo de colisión
            idx = argmin(abs.(traj.time .- t_coll))
            if abs(traj.time[idx] - t_coll) < tolerance_time
                scatter!(p2, [traj.theta[idx]], [traj.theta_dot[idx]],
                         marker = :circle,
                         markersize = 4,
                         color = :red,
                         alpha = 0.8,
                         label = "")
            end
        end
    end

    # Añadir leyenda para colisiones
    scatter!(p2, [NaN], [NaN],
             marker = :circle,
             markersize = 4,
             color = :red,
             label = "Colisiones")

    savefig(p2, joinpath(dir_resultados, "espacio_fase_colisiones.png"))
    println("  ✅ espacio_fase_colisiones.png")
end

# ============================================================================
# Gráfica 3: Espacio Fase Coloreado por Tiempo
# ============================================================================
println("📊 Generando gráfica 3: Espacio fase coloreado por tiempo...")

p3 = plot(
    xlabel = "θ (rad)",
    ylabel = "θ̇ (rad/s)",
    title = "Espacio Fase Coloreado por Tiempo",
    size = (1200, 800),
    dpi = 150
)

# Graficar cada partícula con color según tiempo
for id in unique_ids
    traj = trayectorias[id]

    # Normalizar tiempo para color
    t_norm = (traj.time .- traj.time[1]) ./ (traj.time[end] - traj.time[1])

    # Graficar segmentos con color según tiempo
    for i in 1:(length(traj.theta)-1)
        plot!(p3, traj.theta[i:i+1], traj.theta_dot[i:i+1],
              linewidth = 2,
              color = RGB(t_norm[i], 0, 1-t_norm[i]),
              alpha = 0.6,
              label = "")
    end
end

# Barra de color manual (leyenda)
scatter!(p3, [NaN], [NaN], marker = :none, label = "Tiempo:",
         markercolor = :white)
scatter!(p3, [NaN], [NaN], marker = :circle, markersize = 8,
         markercolor = RGB(0,0,1), label = "Inicial")
scatter!(p3, [NaN], [NaN], marker = :circle, markersize = 8,
         markercolor = RGB(1,0,0), label = "Final")

savefig(p3, joinpath(dir_resultados, "espacio_fase_tiempo.png"))
println("  ✅ espacio_fase_tiempo.png")

# ============================================================================
# Gráfica 4: Espacio Fase con Curvas de Energía Constante
# ============================================================================
println("📊 Generando gráfica 4: Curvas de energía constante...")

p4 = plot(
    xlabel = "θ (rad)",
    ylabel = "θ̇ (rad/s)",
    title = "Espacio Fase con Curvas de Energía Constante",
    legend = :outerright,
    size = (1200, 800),
    dpi = 150
)

# Función métrica
g(θ) = a^2 * sin(θ)^2 + b^2 * cos(θ)^2

# Función energía cinética: E = (1/2) m g(θ) θ̇²
# Despejando: θ̇ = ±√(2E / (m g(θ)))

# Calcular niveles de energía a graficar
energies_all = Float64[]
for id in unique_ids
    append!(energies_all, trayectorias[id].energy)
end

E_min = minimum(energies_all)
E_max = maximum(energies_all)
E_levels = range(E_min, E_max, length=8)

# Graficar curvas de energía constante
θ_range = range(0, 2π, length=500)

for E_level in E_levels
    θ_dot_positive = zeros(length(θ_range))
    θ_dot_negative = zeros(length(θ_range))

    # Asumir m = 1.0 (masa típica)
    m = 1.0

    for (i, θ_val) in enumerate(θ_range)
        g_val = g(θ_val)
        if g_val > 0 && E_level > 0
            θ_dot_val = sqrt(2 * E_level / (m * g_val))
            θ_dot_positive[i] = θ_dot_val
            θ_dot_negative[i] = -θ_dot_val
        end
    end

    # Graficar ambas ramas
    plot!(p4, θ_range, θ_dot_positive,
          linestyle = :dash,
          linewidth = 1,
          color = :gray,
          alpha = 0.5,
          label = "")

    plot!(p4, θ_range, θ_dot_negative,
          linestyle = :dash,
          linewidth = 1,
          color = :gray,
          alpha = 0.5,
          label = "")
end

# Añadir leyenda para curvas de energía
plot!(p4, [NaN], [NaN],
      linestyle = :dash,
      linewidth = 1,
      color = :gray,
      label = "E = const")

# Graficar trayectorias encima
for (idx, id) in enumerate(unique_ids)
    traj = trayectorias[id]
    plot!(p4, traj.theta, traj.theta_dot,
          label = "Partícula $id",
          linewidth = 2,
          color = colores[idx],
          alpha = 0.8)
end

savefig(p4, joinpath(dir_resultados, "espacio_fase_energia.png"))
println("  ✅ espacio_fase_energia.png")

# ============================================================================
# Gráfica 5: Mapa de Densidad (Heatmap) del Espacio Fase
# ============================================================================
println("📊 Generando gráfica 5: Mapa de densidad...")

# Crear grid para histograma 2D
θ_bins = range(0, 2π, length=100)
θ_dot_bins = range(minimum(theta_dot), maximum(theta_dot), length=100)

# Calcular histograma 2D
hist_data = zeros(length(θ_dot_bins)-1, length(θ_bins)-1)

for i in 1:length(theta)
    θ_idx = searchsortedfirst(θ_bins, theta[i]) - 1
    θ_dot_idx = searchsortedfirst(θ_dot_bins, theta_dot[i]) - 1

    if 1 <= θ_idx < length(θ_bins) && 1 <= θ_dot_idx < length(θ_dot_bins)
        hist_data[θ_dot_idx, θ_idx] += 1
    end
end

p5 = heatmap(
    θ_bins[1:end-1],
    θ_dot_bins[1:end-1],
    hist_data,
    xlabel = "θ (rad)",
    ylabel = "θ̇ (rad/s)",
    title = "Densidad de Estados en Espacio Fase",
    color = :viridis,
    size = (1000, 800),
    dpi = 150
)

savefig(p5, joinpath(dir_resultados, "espacio_fase_densidad.png"))
println("  ✅ espacio_fase_densidad.png")

# ============================================================================
# Estadísticas del Espacio Fase
# ============================================================================
println()
println("="^80)
println("ESTADÍSTICAS DEL ESPACIO FASE")
println("="^80)
println()

println("Rangos:")
println(@sprintf("  θ:    [%.3f, %.3f] rad", minimum(theta), maximum(theta)))
println(@sprintf("  θ̇:   [%.3f, %.3f] rad/s", minimum(theta_dot), maximum(theta_dot)))
println(@sprintf("  E:    [%.3e, %.3e] J", E_min, E_max))
println()

println("Promedios:")
println(@sprintf("  <θ>:  %.3f rad", mean(theta)))
println(@sprintf("  <θ̇>: %.3f rad/s", mean(theta_dot)))
println()

println("Desviaciones estándar:")
println(@sprintf("  σ_θ:  %.3f rad", std(theta)))
println(@sprintf("  σ_θ̇: %.3f rad/s", std(theta_dot)))
println()

if n_collisions > 0
    println("Colisiones:")
    println(@sprintf("  Total: %d", n_collisions))
    println(@sprintf("  Tasa: %.2f colisiones/s", n_collisions / (time[end] - time[1])))
    println()
end

# ============================================================================
# Resumen
# ============================================================================
println("="^80)
println("✅ ANÁLISIS COMPLETADO")
println("="^80)
println()
println("Gráficas generadas en: $dir_resultados")
println("  📈 espacio_fase_completo.png     - Todas las trayectorias")
if n_collisions > 0
    println("  📈 espacio_fase_colisiones.png   - Con colisiones marcadas")
end
println("  📈 espacio_fase_tiempo.png       - Coloreado por tiempo")
println("  📈 espacio_fase_energia.png      - Con curvas E = const")
println("  📈 espacio_fase_densidad.png     - Mapa de densidad")
println()
println("="^80)
