"""
animar_espacio_fase.jl

Crea una animación del espacio fase (θ, θ̇) mostrando la evolución temporal
de todas las partículas.

La animación muestra:
- Trayectorias pasadas (líneas desvanecidas)
- Posiciones actuales (puntos grandes)
- Colisiones (flash rojo)

Uso:
    julia --project=. animar_espacio_fase.jl results/simulation_XXXXXX/ [fps]

Argumentos:
    results/simulation_XXXXXX/  - Directorio de resultados
    fps (opcional)              - Cuadros por segundo (default: 30)

Ejemplo:
    julia --project=. animar_espacio_fase.jl results/simulation_20251111_004024/ 30
"""

using Plots
using DelimitedFiles
using Printf

# Verificar argumentos
if length(ARGS) < 1
    println("❌ Error: Proporciona el directorio de resultados")
    println()
    println("Uso:")
    println("  julia --project=. animar_espacio_fase.jl results/simulation_XXXXXX/ [fps]")
    exit(1)
end

dir_resultados = ARGS[1]
fps = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 30

println("="^80)
println("ANIMACIÓN DEL ESPACIO FASE")
println("="^80)
println()
println("Configuración:")
println("  FPS: $fps")
println("  Directorio: $dir_resultados")
println()

# ============================================================================
# Cargar datos
# ============================================================================
println("📥 Cargando datos...")

archivo_traj = joinpath(dir_resultados, "trajectories.csv")
if !isfile(archivo_traj)
    println("❌ Error: No se encontró trajectories.csv")
    exit(1)
end

data, _ = readdlm(archivo_traj, ',', Float64, '\n'; header=true)

time_all = data[:, 1]
particle_id = Int.(data[:, 2])
theta_all = data[:, 3]
theta_dot_all = data[:, 4]

unique_ids = sort(unique(particle_id))
n_particles = length(unique_ids)
unique_times = sort(unique(time_all))
n_frames_data = length(unique_times)

println("  ✅ $(length(time_all)) puntos")
println("  ✅ $n_particles partículas")
println("  ✅ $n_frames_data frames de datos")
println()

# Cargar colisiones
archivo_coll = joinpath(dir_resultados, "collisions_per_step.csv")
collision_times = Float64[]
if isfile(archivo_coll)
    coll_data, _ = readdlm(archivo_coll, ',', '\n'; header=true)
    time_coll = Float64.(coll_data[:, 1])
    had_collision = Bool.(coll_data[:, 5])
    collision_times = time_coll[had_collision]
    println("  ✅ $(length(collision_times)) colisiones")
else
    println("  ⚠️  No hay información de colisiones")
end
println()

# ============================================================================
# Organizar datos por frame
# ============================================================================
println("📊 Organizando datos por frame...")

# Crear estructura para cada frame
frames_data = Dict{Float64, Dict{Int, Tuple{Float64, Float64}}}()

for t in unique_times
    mask = time_all .== t
    frame_data = Dict{Int, Tuple{Float64, Float64}}()

    for id in unique_ids
        id_mask = mask .& (particle_id .== id)
        if any(id_mask)
            idx = findfirst(id_mask)
            frame_data[id] = (theta_all[idx], theta_dot_all[idx])
        end
    end

    frames_data[t] = frame_data
end

println("  ✅ $(length(frames_data)) frames organizados")
println()

# ============================================================================
# Configuración de animación
# ============================================================================
println("🎬 Configurando animación...")

# Límites del espacio fase
θ_min, θ_max = minimum(theta_all), maximum(theta_all)
θ̇_min, θ̇_max = minimum(theta_dot_all), maximum(theta_dot_all)

# Añadir margen
θ_margin = (θ_max - θ_min) * 0.1
θ̇_margin = (θ̇_max - θ̇_min) * 0.1

xlims = (θ_min - θ_margin, θ_max + θ_margin)
ylims = (θ̇_min - θ̇_margin, θ̇_max + θ̇_margin)

# Colores para cada partícula
using ColorSchemes
colores = palette(:tab10, n_particles)

# Historia de posiciones (para dibujar trayectorias desvanecidas)
history_length = 50  # Número de puntos pasados a mostrar

println("  Límites: θ ∈ $xlims, θ̇ ∈ $ylims")
println("  Historial: $history_length puntos")
println()

# ============================================================================
# Crear animación
# ============================================================================
println("🎬 Generando animación...")
println("  (Esto puede tomar varios minutos)")
println()

# Progreso
n_frames = min(n_frames_data, 500)  # Limitar a 500 frames para no tardar demasiado
frame_skip = max(1, div(n_frames_data, n_frames))
times_to_animate = unique_times[1:frame_skip:end]

anim = @animate for (frame_idx, t) in enumerate(times_to_animate)
    p = plot(
        xlabel = "θ (rad)",
        ylabel = "θ̇ (rad/s)",
        title = @sprintf("Espacio Fase - t = %.3f s", t),
        xlims = xlims,
        ylims = ylims,
        legend = false,
        size = (1000, 800),
        dpi = 100
    )

    # Verificar si hay colisión en este tiempo
    has_collision = any(abs.(collision_times .- t) .< 0.01)

    # Dibujar trayectorias pasadas para cada partícula
    for (idx, id) in enumerate(unique_ids)
        # Obtener historial
        past_positions = Tuple{Float64, Float64}[]

        for t_past in reverse(times_to_animate[max(1, frame_idx-history_length):frame_idx])
            if haskey(frames_data, t_past) && haskey(frames_data[t_past], id)
                push!(past_positions, frames_data[t_past][id])
            end
        end

        if !isempty(past_positions)
            θ_hist = [pos[1] for pos in past_positions]
            θ̇_hist = [pos[2] for pos in past_positions]

            # Dibujar trayectoria con alpha decreciente
            for i in 1:(length(θ_hist)-1)
                alpha_val = i / length(θ_hist) * 0.6
                plot!(p, θ_hist[i:i+1], θ̇_hist[i:i+1],
                      linewidth = 2,
                      color = colores[idx],
                      alpha = alpha_val,
                      label = "")
            end
        end
    end

    # Dibujar posiciones actuales
    for (idx, id) in enumerate(unique_ids)
        if haskey(frames_data, t) && haskey(frames_data[t], id)
            θ_current, θ̇_current = frames_data[t][id]

            marker_color = has_collision ? :red : colores[idx]
            marker_size = has_collision ? 12 : 8

            scatter!(p, [θ_current], [θ̇_current],
                     marker = :circle,
                     markersize = marker_size,
                     color = marker_color,
                     markerstrokewidth = 2,
                     markerstrokecolor = :white,
                     alpha = 0.9,
                     label = "")
        end
    end

    # Añadir texto de colisión si hay
    if has_collision
        annotate!(p, θ_min + θ_margin, θ̇_max - θ̇_margin,
                  text("¡COLISIÓN!", 16, :red, :bold))
    end

    # Mostrar progreso
    if frame_idx % 10 == 0
        progress = 100.0 * frame_idx / length(times_to_animate)
        print("\r  Progreso: $(round(progress, digits=1))%")
    end
end

println("\r  Progreso: 100.0%    ")
println()

# ============================================================================
# Guardar animación
# ============================================================================
println("💾 Guardando animación...")

archivo_gif = joinpath(dir_resultados, "espacio_fase_animacion.gif")

try
    gif(anim, archivo_gif, fps=fps)
    println("  ✅ Guardado: espacio_fase_animacion.gif")
    println()
    println("="^80)
    println("✅ ANIMACIÓN COMPLETADA")
    println("="^80)
    println()
    println("Archivo: $archivo_gif")
    println("FPS: $fps")
    println("Frames: $(length(times_to_animate))")
    println()
    println("Abre el archivo GIF para ver la animación.")
    println()
    println("="^80)
catch e
    println("  ❌ Error al guardar GIF: $e")
    println()
    println("  ℹ️  Intenta instalar ImageMagick si no lo tienes:")
    println("     using Pkg; Pkg.add(\"ImageMagick\")")
end
