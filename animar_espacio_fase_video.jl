"""
animar_espacio_fase_video.jl

Genera un VIDEO (MP4) animado del espacio fase con ÁNGULOS DESENROLLADOS.

IMPORTANTE:
- θ no se reduce módulo 2π → vemos vueltas completas
- θ puede ser negativo o > 2π
- Permite ver topología del movimiento y winding numbers
- Formato MP4 (mejor calidad y menor tamaño que GIF)

Características visuales:
- Rastro desvaneciente (últimos N puntos)
- Flash rojo en colisiones
- Marcadores grandes para posiciones actuales
- Líneas de 2π para marcar vueltas completas

Uso:
    julia --project=. animar_espacio_fase_video.jl results/simulation_XXXXXX/ [fps] [trail_length]

Argumentos opcionales:
    fps          : Cuadros por segundo (default: 30)
    trail_length : Longitud del rastro en puntos (default: 50)
"""

using Plots
using DelimitedFiles
using Printf
using Statistics
using ColorSchemes

# ============================================================================
# Función para desenrollar ángulos
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
# Verificar argumentos
# ============================================================================
if length(ARGS) < 1
    println("❌ Error: Proporciona el directorio de resultados")
    println()
    println("Uso:")
    println("  julia --project=. animar_espacio_fase_video.jl results/simulation_XXXXXX/ [fps] [trail_length]")
    println()
    println("Ejemplos:")
    println("  julia --project=. animar_espacio_fase_video.jl results/simulation_20251111_001524/")
    println("  julia --project=. animar_espacio_fase_video.jl results/simulation_20251111_001524/ 60 100")
    exit(1)
end

dir_resultados = ARGS[1]
fps = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 30
trail_length = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 50

println("="^80)
println("ANIMACIÓN DE ESPACIO FASE - ÁNGULO DESENROLLADO (VIDEO MP4)")
println("="^80)
println()
println("Directorio: $dir_resultados")
println("FPS: $fps")
println("Longitud del rastro: $trail_length puntos")
println()

# ============================================================================
# Cargar datos de trayectorias
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

trayectorias = Dict{Int, NamedTuple}()

for id in unique_ids
    mask = particle_id .== id

    t_part = time_all[mask]
    θ_part_wrapped = theta_wrapped[mask]
    θ̇_part = theta_dot_all[mask]

    # Desenrollar
    θ_part_unwrapped = unwrap_angles(θ_part_wrapped)

    trayectorias[id] = (
        time = t_part,
        theta = θ_part_unwrapped,
        theta_dot = θ̇_part
    )
end

println("  ✅ Ángulos desenrollados")
println()

# ============================================================================
# Calcular winding numbers
# ============================================================================
println("📊 Calculando estadísticas de vueltas...")

winding_numbers = Dict{Int, Float64}()
for id in unique_ids
    θ_inicial = trayectorias[id].theta[1]
    θ_final = trayectorias[id].theta[end]
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
# Cargar información de colisiones
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
# Preparar datos para animación
# ============================================================================
println("🎬 Preparando animación...")

# Encontrar todos los tiempos únicos
unique_times = sort(unique(time_all))
n_frames = length(unique_times)

println("  Total de frames: $n_frames")
println("  Duración del video: $(n_frames/fps) segundos")
println()

# Calcular límites del espacio fase
θ_unwrapped_all = vcat([trayectorias[id].theta for id in unique_ids]...)
θ̇_all = theta_dot_all

θ_min = minimum(θ_unwrapped_all)
θ_max = maximum(θ_unwrapped_all)
θ̇_min = minimum(θ̇_all)
θ̇_max = maximum(θ̇_all)

# Añadir margen 5%
θ_range = θ_max - θ_min
θ̇_range = θ̇_max - θ̇_min

xlims_val = (θ_min - 0.05*θ_range, θ_max + 0.05*θ_range)
ylims_val = (θ̇_min - 0.05*θ̇_range, θ̇_max + 0.05*θ̇_range)

# Paleta de colores
colores = palette(:tab10, n_particles)

# ============================================================================
# Función para detectar colisión en tiempo dado
# ============================================================================
function collision_at_time(t::Float64, collision_times::Vector{Float64}, tolerance::Float64 = 0.01)
    for t_coll in collision_times
        if abs(t - t_coll) < tolerance
            return true
        end
    end
    return false
end

# ============================================================================
# Crear animación
# ============================================================================
println("🎥 Generando video MP4...")
println("   (Esto puede tomar varios minutos dependiendo del número de frames)")
println()

# Calcular líneas de 2π
n_lines_start = floor(Int, θ_min / (2π))
n_lines_end = ceil(Int, θ_max / (2π))
multiples_2pi = [n * 2π for n in n_lines_start:n_lines_end]

# Crear animación
anim = @animate for (frame_idx, t) in enumerate(unique_times)
    # Crear plot base
    p = plot(
        xlabel = "θ (rad) - Ángulo Desenrollado",
        ylabel = "θ̇ (rad/s)",
        title = @sprintf("Espacio Fase Unwrapped - t = %.3f s", t),
        legend = :outerright,
        size = (1400, 800),
        xlims = xlims_val,
        ylims = ylims_val,
        dpi = 150
    )

    # Marcar líneas de 2π
    for θ_2pi in multiples_2pi
        vline!(p, [θ_2pi],
               linestyle = :dash,
               color = :gray,
               alpha = 0.2,
               linewidth = 1,
               label = "")
    end

    # Detectar si hay colisión en este frame
    is_collision_frame = collision_at_time(t, collision_times, 0.01)

    # Para cada partícula
    for (idx, id) in enumerate(unique_ids)
        traj = trayectorias[id]

        # Encontrar índice más cercano al tiempo actual
        time_diffs = abs.(traj.time .- t)
        current_idx = argmin(time_diffs)

        # Si el tiempo no coincide exactamente, skip
        if time_diffs[current_idx] > 1e-6
            continue
        end

        # Calcular rango de índices para el rastro
        start_idx = max(1, current_idx - trail_length)
        end_idx = current_idx

        # Graficar rastro desvaneciente
        if end_idx > start_idx
            θ_trail = traj.theta[start_idx:end_idx]
            θ̇_trail = traj.theta_dot[start_idx:end_idx]

            # Calcular alphas desvanecientes
            n_trail_points = length(θ_trail)
            alphas = range(0.1, 0.7, length=n_trail_points)

            # Graficar segmentos con alpha variable
            for i in 1:(n_trail_points-1)
                plot!(p, θ_trail[i:i+1], θ̇_trail[i:i+1],
                      linewidth = 2,
                      color = colores[idx],
                      alpha = alphas[i],
                      label = "")
            end
        end

        # Posición actual
        θ_current = traj.theta[current_idx]
        θ̇_current = traj.theta_dot[current_idx]

        # Si hay colisión, hacer flash rojo
        if is_collision_frame
            scatter!(p, [θ_current], [θ̇_current],
                     marker = :circle,
                     markersize = 12,
                     color = :red,
                     markerstrokewidth = 3,
                     markerstrokecolor = :white,
                     label = "")
        else
            # Marcador normal
            scatter!(p, [θ_current], [θ̇_current],
                     marker = :circle,
                     markersize = 8,
                     color = colores[idx],
                     markerstrokewidth = 2,
                     markerstrokecolor = :white,
                     label = (frame_idx == 1 ? @sprintf("Part %d (%.1f vueltas)", id, winding_numbers[id]) : ""))
        end
    end

    # Añadir anotación de colisión si aplica
    if is_collision_frame
        annotate!(p, xlims_val[1] + 0.05*(xlims_val[2] - xlims_val[1]),
                     ylims_val[2] - 0.05*(ylims_val[2] - ylims_val[1]),
                  text("⚡ COLISIÓN", 14, :red, :bold))
    end

    # Añadir info de líneas de 2π
    annotate!(p, xlims_val[1] + 0.05*(xlims_val[2] - xlims_val[1]),
                 ylims_val[2] - 0.10*(ylims_val[2] - ylims_val[1]),
              text("Líneas grises: múltiplos de 2π", 10, :gray))

    # Mostrar progreso
    if frame_idx % 100 == 0 || frame_idx == n_frames
        print("\r  Procesando frame $frame_idx / $n_frames ($(round(100*frame_idx/n_frames, digits=1))%)")
    end
end

println()
println()

# ============================================================================
# Guardar video MP4
# ============================================================================
println("💾 Guardando video MP4...")

archivo_mp4 = joinpath(dir_resultados, "espacio_fase_unwrapped_animacion.mp4")

try
    mp4(anim, archivo_mp4, fps=fps)
    println("  ✅ espacio_fase_unwrapped_animacion.mp4")

    # Obtener tamaño del archivo
    filesize_mb = stat(archivo_mp4).size / (1024^2)
    println()
    println("📊 Información del video:")
    println(@sprintf("  Tamaño: %.2f MB", filesize_mb))
    println(@sprintf("  Frames: %d", n_frames))
    println(@sprintf("  FPS: %d", fps))
    println(@sprintf("  Duración: %.2f segundos", n_frames/fps))
    println()
catch e
    println("  ❌ Error al generar MP4:")
    println("  $e")
    println()
    println("  NOTA: Asegúrate de tener ffmpeg instalado:")
    println("    sudo apt-get install ffmpeg")
    println()
    exit(1)
end

# ============================================================================
# Resumen
# ============================================================================
println("="^80)
println("✅ ANIMACIÓN COMPLETADA")
println("="^80)
println()
println("Video generado en: $dir_resultados")
println("  🎥 espacio_fase_unwrapped_animacion.mp4")
println()
println("CARACTERÍSTICAS:")
println("  • Ángulos desenrollados (θ ∈ ℝ) - vueltas completas visibles")
println("  • Rastro desvaneciente de últimos $trail_length puntos")
println("  • Flash rojo en colisiones")
println("  • Líneas grises marcan múltiplos de 2π")
println("  • Formato MP4 de alta calidad")
println()
println("REPRODUCIR:")
println("  En Linux:")
println("    vlc $archivo_mp4")
println("    mpv $archivo_mp4")
println()
println("  En macOS:")
println("    open $archivo_mp4")
println()
println("  En Windows:")
println("    start $archivo_mp4")
println()
println("="^80)
