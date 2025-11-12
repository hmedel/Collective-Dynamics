"""
analizar_espacio_fase_unwrapped.jl

Análisis del espacio fase (θ, θ̇) con ángulo DESENROLLADO (unwrapped).

IMPORTANTE:
- θ no se reduce módulo 2π → vemos vueltas completas
- θ puede ser negativo o > 2π
- Permite ver topología del movimiento y winding numbers

Genera dos conjuntos de visualizaciones:
1. Espacio UNWRAPPED: θ ∈ ℝ (ángulo real sin reducir)
2. Espacio WRAPPED: θ ∈ [0, 2π) (reducido, para comparación)

Uso:
    julia --project=. analizar_espacio_fase_unwrapped.jl results/simulation_XXXXXX/
"""

using Plots
using DelimitedFiles
using Printf
using Statistics

# Verificar argumentos
if length(ARGS) < 1
    println("❌ Error: Proporciona el directorio de resultados")
    println()
    println("Uso:")
    println("  julia --project=. analizar_espacio_fase_unwrapped.jl results/simulation_XXXXXX/")
    exit(1)
end

dir_resultados = ARGS[1]

println("="^80)
println("ANÁLISIS DE ESPACIO FASE - ÁNGULO DESENROLLADO")
println("="^80)
println()

# ============================================================================
# Función para desenrollar ángulo
# ============================================================================
"""
    unwrap_angles(θ_array)

Desenrolla una serie de ángulos para evitar saltos de 2π.

Convierte [6.2, 0.1, 0.2, 6.1] → [6.2, 6.38, 6.48, 12.38]
"""
function unwrap_angles(θ_array::Vector{Float64})
    if isempty(θ_array)
        return Float64[]
    end

    θ_unwrapped = similar(θ_array)
    θ_unwrapped[1] = θ_array[1]

    cumulative_offset = 0.0

    for i in 2:length(θ_array)
        Δθ = θ_array[i] - θ_array[i-1]

        # Detectar salto > π
        if Δθ > π
            cumulative_offset -= 2π
        elseif Δθ < -π
            cumulative_offset += 2π
        end

        θ_unwrapped[i] = θ_array[i] + cumulative_offset
    end

    return θ_unwrapped
end

# ============================================================================
# Cargar datos
# ============================================================================
println("📥 Cargando datos de trayectorias...")

archivo_traj = joinpath(dir_resultados, "trajectories.csv")
if !isfile(archivo_traj)
    println("❌ Error: No se encontró trajectories.csv")
    exit(1)
end

data, _ = readdlm(archivo_traj, ',', Float64, '\n'; header=true)

time_all = data[:, 1]
particle_id = Int.(data[:, 2])
theta_wrapped = data[:, 3]  # θ módulo 2π del archivo
theta_dot_all = data[:, 4]
energy_particle = data[:, 9]

unique_ids = sort(unique(particle_id))
n_particles = length(unique_ids)

println("  ✅ $(length(time_all)) puntos cargados")
println("  ✅ $(n_particles) partículas")
println()

# Cargar geometría
using TOML
archivo_config = joinpath(dir_resultados, "config_used.toml")
if isfile(archivo_config)
    config = TOML.parsefile(archivo_config)
    a = config["geometry"]["a"]
    b = config["geometry"]["b"]
else
    a, b = 2.0, 1.0
end
println("  Geometría: a = $a, b = $b")
println()

# ============================================================================
# Desenrollar ángulos por partícula
# ============================================================================
println("🔄 Desenrollando ángulos...")

trayectorias_unwrapped = Dict{Int, NamedTuple}()
trayectorias_wrapped = Dict{Int, NamedTuple}()

for id in unique_ids
    mask = particle_id .== id

    t_part = time_all[mask]
    θ_part_wrapped = theta_wrapped[mask]
    θ̇_part = theta_dot_all[mask]
    E_part = energy_particle[mask]

    # Desenrollar
    θ_part_unwrapped = unwrap_angles(θ_part_wrapped)

    trayectorias_unwrapped[id] = (
        time = t_part,
        theta = θ_part_unwrapped,
        theta_dot = θ̇_part,
        energy = E_part
    )

    trayectorias_wrapped[id] = (
        time = t_part,
        theta = θ_part_wrapped,
        theta_dot = θ̇_part,
        energy = E_part
    )
end

println("  ✅ Ángulos desenrollados")
println()

# ============================================================================
# Calcular estadísticas de winding
# ============================================================================
println("📊 Calculando estadísticas de vueltas...")

winding_numbers = Dict{Int, Float64}()
for id in unique_ids
    θ_inicial = trayectorias_unwrapped[id].theta[1]
    θ_final = trayectorias_unwrapped[id].theta[end]

    # Número de vueltas = (θ_final - θ_inicial) / 2π
    winding = (θ_final - θ_inicial) / (2π)
    winding_numbers[id] = winding
end

println("Número de vueltas por partícula:")
for id in sort(collect(keys(winding_numbers)))
    w = winding_numbers[id]
    dirección = w > 0 ? "→" : "←"
    println(@sprintf("  Partícula %2d: %+.2f vueltas %s", id, abs(w), dirección))
end
println()

# ============================================================================
# Cargar colisiones
# ============================================================================
println("📥 Cargando datos de colisiones...")

archivo_coll = joinpath(dir_resultados, "collisions_per_step.csv")
collision_times = Float64[]
n_collisions = 0

if isfile(archivo_coll)
    coll_data, _ = readdlm(archivo_coll, ',', '\n'; header=true)
    time_coll = Float64.(coll_data[:, 1])
    had_collision = Bool.(coll_data[:, 5])
    collision_times = time_coll[had_collision]
    n_collisions = length(collision_times)
    println("  ✅ $(n_collisions) colisiones detectadas")
else
    println("  ⚠️  No se encontró información de colisiones")
end
println()

# ============================================================================
# Paleta de colores
# ============================================================================
using ColorSchemes
colores = palette(:tab10, n_particles)

# ============================================================================
# GRÁFICA 1: Espacio Fase UNWRAPPED
# ============================================================================
println("📊 Generando gráfica 1: Espacio fase unwrapped...")

# Calcular límites
θ_unwrapped_all = vcat([trayectorias_unwrapped[id].theta for id in unique_ids]...)
θ̇_all = theta_dot_all

p1 = plot(
    xlabel = "θ (rad) - Ángulo Desenrollado",
    ylabel = "θ̇ (rad/s)",
    title = "Espacio Fase: Ángulo Desenrollado (Vueltas Completas)",
    legend = :outerright,
    size = (1400, 800),
    dpi = 150
)

# Graficar cada partícula
for (idx, id) in enumerate(unique_ids)
    traj = trayectorias_unwrapped[id]

    plot!(p1, traj.theta, traj.theta_dot,
          label = @sprintf("Part %d (%.1f vueltas)", id, winding_numbers[id]),
          linewidth = 2,
          color = colores[idx],
          alpha = 0.7)

    # Marcar inicio
    scatter!(p1, [traj.theta[1]], [traj.theta_dot[1]],
             marker = :circle,
             markersize = 8,
             color = colores[idx],
             markerstrokewidth = 2,
             markerstrokecolor = :white,
             label = "")

    # Marcar final
    scatter!(p1, [traj.theta[end]], [traj.theta_dot[end]],
             marker = :square,
             markersize = 8,
             color = colores[idx],
             markerstrokewidth = 2,
             markerstrokecolor = :white,
             label = "")
end

# Marcar líneas de 2π (vueltas completas)
θ_min = minimum(θ_unwrapped_all)
θ_max = maximum(θ_unwrapped_all)
n_lines_start = floor(Int, θ_min / (2π))
n_lines_end = ceil(Int, θ_max / (2π))

for n in n_lines_start:n_lines_end
    vline!(p1, [n * 2π],
           linestyle = :dash,
           color = :gray,
           alpha = 0.3,
           linewidth = 1,
           label = "")
end

# Anotar las líneas
annotate!(p1, 0, maximum(θ̇_all)*0.95,
          text("Líneas grises: múltiplos de 2π", 10, :gray))

savefig(p1, joinpath(dir_resultados, "espacio_fase_unwrapped.png"))
println("  ✅ espacio_fase_unwrapped.png")

# ============================================================================
# GRÁFICA 2: Espacio Fase WRAPPED (para comparación)
# ============================================================================
println("📊 Generando gráfica 2: Espacio fase wrapped (reducido)...")

p2 = plot(
    xlabel = "θ (rad) - Reducido [0, 2π)",
    ylabel = "θ̇ (rad/s)",
    title = "Espacio Fase: Ángulo Reducido Módulo 2π",
    legend = :outerright,
    size = (1400, 800),
    dpi = 150,
    xlims = (0, 2π)
)

for (idx, id) in enumerate(unique_ids)
    traj = trayectorias_wrapped[id]

    plot!(p2, traj.theta, traj.theta_dot,
          label = @sprintf("Partícula %d", id),
          linewidth = 2,
          color = colores[idx],
          alpha = 0.7)

    scatter!(p2, [traj.theta[1]], [traj.theta_dot[1]],
             marker = :circle,
             markersize = 8,
             color = colores[idx],
             markerstrokewidth = 2,
             markerstrokecolor = :white,
             label = "")

    scatter!(p2, [traj.theta[end]], [traj.theta_dot[end]],
             marker = :square,
             markersize = 8,
             color = colores[idx],
             markerstrokewidth = 2,
             markerstrokecolor = :white,
             label = "")
end

# Marcar líneas de 0 y 2π
vline!(p2, [0, 2π],
       linestyle = :dash,
       color = :red,
       alpha = 0.5,
       linewidth = 2,
       label = "")

annotate!(p2, π, maximum(θ̇_all)*0.95,
          text("⚠️ Saltos artificiales en 0/2π", 10, :red))

savefig(p2, joinpath(dir_resultados, "espacio_fase_wrapped.png"))
println("  ✅ espacio_fase_wrapped.png")

# ============================================================================
# GRÁFICA 3: Comparación Lado a Lado
# ============================================================================
println("📊 Generando gráfica 3: Comparación unwrapped vs wrapped...")

p3 = plot(p1, p2, layout = (2, 1), size = (1400, 1200))

savefig(p3, joinpath(dir_resultados, "espacio_fase_comparacion.png"))
println("  ✅ espacio_fase_comparacion.png")

# ============================================================================
# GRÁFICA 4: θ(t) - Evolución Temporal del Ángulo
# ============================================================================
println("📊 Generando gráfica 4: Evolución temporal θ(t)...")

p4 = plot(
    xlabel = "Tiempo (s)",
    ylabel = "θ (rad) - Desenrollado",
    title = "Evolución Temporal del Ángulo",
    legend = :outerright,
    size = (1400, 800),
    dpi = 150
)

for (idx, id) in enumerate(unique_ids)
    traj = trayectorias_unwrapped[id]

    plot!(p4, traj.time, traj.theta,
          label = @sprintf("Partícula %d", id),
          linewidth = 2,
          color = colores[idx],
          alpha = 0.7)
end

# Marcar colisiones
if n_collisions > 0
    for t_coll in collision_times
        vline!(p4, [t_coll],
               linestyle = :dot,
               color = :red,
               alpha = 0.3,
               linewidth = 1,
               label = "")
    end

    vline!(p4, [collision_times[1]],
           linestyle = :dot,
           color = :red,
           alpha = 0.3,
           linewidth = 1,
           label = "Colisiones")
end

savefig(p4, joinpath(dir_resultados, "theta_vs_tiempo.png"))
println("  ✅ theta_vs_tiempo.png")

# ============================================================================
# GRÁFICA 5: Winding Number vs Tiempo
# ============================================================================
println("📊 Generando gráfica 5: Número de vueltas vs tiempo...")

p5 = plot(
    xlabel = "Tiempo (s)",
    ylabel = "Número de Vueltas",
    title = "Evolución del Número de Vueltas",
    legend = :outerright,
    size = (1400, 800),
    dpi = 150
)

for (idx, id) in enumerate(unique_ids)
    traj = trayectorias_unwrapped[id]

    # Calcular winding acumulativo
    θ_0 = traj.theta[1]
    winding_vs_time = (traj.theta .- θ_0) ./ (2π)

    plot!(p5, traj.time, winding_vs_time,
          label = @sprintf("Partícula %d", id),
          linewidth = 2,
          color = colores[idx],
          alpha = 0.7)
end

# Línea horizontal en 0
hline!(p5, [0],
       linestyle = :dash,
       color = :gray,
       alpha = 0.5,
       linewidth = 1,
       label = "")

savefig(p5, joinpath(dir_resultados, "winding_vs_tiempo.png"))
println("  ✅ winding_vs_tiempo.png")

# ============================================================================
# Estadísticas
# ============================================================================
println()
println("="^80)
println("ESTADÍSTICAS DEL ESPACIO FASE")
println("="^80)
println()

println("ÁNGULO UNWRAPPED:")
println(@sprintf("  θ mínimo:  %+.3f rad  (%.2f vueltas)", minimum(θ_unwrapped_all), minimum(θ_unwrapped_all)/(2π)))
println(@sprintf("  θ máximo:  %+.3f rad  (%.2f vueltas)", maximum(θ_unwrapped_all), maximum(θ_unwrapped_all)/(2π)))
println(@sprintf("  Rango:     %.3f rad  (%.2f vueltas)",
                 maximum(θ_unwrapped_all) - minimum(θ_unwrapped_all),
                 (maximum(θ_unwrapped_all) - minimum(θ_unwrapped_all))/(2π)))
println()

println("VELOCIDAD ANGULAR:")
println(@sprintf("  θ̇ mínimo:  %+.3f rad/s", minimum(θ̇_all)))
println(@sprintf("  θ̇ máximo:  %+.3f rad/s", maximum(θ̇_all)))
println(@sprintf("  <θ̇>:      %+.3f rad/s", mean(θ̇_all)))
println()

println("WINDING NUMBERS:")
total_winding = sum(values(winding_numbers))
println(@sprintf("  Total system: %+.2f vueltas netas", total_winding))
println(@sprintf("  Promedio:     %+.2f vueltas/partícula", total_winding/n_particles))
max_winding = maximum(abs.(values(winding_numbers)))
println(@sprintf("  Máximo |w|:   %.2f vueltas", max_winding))
println()

if n_collisions > 0
    println("COLISIONES:")
    println(@sprintf("  Total: %d", n_collisions))
    println(@sprintf("  Tasa:  %.2f col/s", n_collisions / (time_all[end] - time_all[1])))
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
println("  📈 espacio_fase_unwrapped.png    - Ángulo desenrollado (RECOMENDADO)")
println("  📈 espacio_fase_wrapped.png      - Ángulo reducido (comparación)")
println("  📈 espacio_fase_comparacion.png  - Ambos lado a lado")
println("  📈 theta_vs_tiempo.png           - Evolución θ(t)")
println("  📈 winding_vs_tiempo.png         - Número de vueltas vs tiempo")
println()
println("INTERPRETACIÓN:")
println("  • Gráfica unwrapped muestra movimiento REAL (sin saltos artificiales)")
println("  • Gráfica wrapped muestra saltos en 0/2π (artefacto de reducción)")
println("  • Winding numbers indican dirección predominante del movimiento")
println()
println("="^80)
