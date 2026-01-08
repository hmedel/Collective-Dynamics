#!/usr/bin/env julia
"""
simulacion_analisis_completo.jl

Simulación con configuración óptima de Fase 1 y análisis detallado de dinámica.

Configuración:
- 40 partículas
- Tiempo total: 60 segundos
- Projection methods activados
- Análisis completo de conservación, distribución espacial, velocidades
"""

using Pkg
Pkg.activate(".")

using CollectiveDynamics
using Printf
using Statistics
using DataFrames
using CSV
using Random
using Dates
using JLD2

println("="^70)
println("SIMULACIÓN CON ANÁLISIS COMPLETO - CollectiveDynamics.jl")
println("="^70)
println()

# =============================================================================
# CONFIGURACIÓN
# =============================================================================

# Parámetros geométricos
a, b = 2.0, 1.0

# Parámetros de partículas
N = 40
mass = 1.0
radius = 0.05  # 5% del semi-eje menor

# Parámetros de simulación
max_time = 60.0
dt_max = 1e-5
dt_min = 1e-10
save_interval = 0.1  # Guardar cada 0.1 segundos

# Optimizaciones de Fase 1
use_projection = true
projection_interval = 100
projection_tolerance = 1e-12

# Paralelización (si está disponible)
use_parallel = Threads.nthreads() > 1

println("CONFIGURACIÓN:")
println("-"^70)
println("Geometría:        Elipse a=$a, b=$b")
println("Partículas:       $N")
println("Masa:             $mass")
println("Radio:            $radius ($(radius*100)% de b)")
println("Tiempo total:     $max_time s")
println("dt_max:           $dt_max")
println("Save interval:    $save_interval s")
println("Projection:       $(use_projection ? "Activado (cada $projection_interval pasos)" : "Desactivado")")
println("Parallel:         $(use_parallel ? "Activado ($(Threads.nthreads()) threads)" : "Desactivado")")
println("-"^70)
println()

# =============================================================================
# GENERACIÓN DE PARTÍCULAS
# =============================================================================

println("Generando $N partículas aleatorias...")
particles_initial = generate_random_particles(N, mass, radius, a, b;
    θ_dot_range=(-1.0, 1.0),
    rng=Random.MersenneTwister(42)  # Seed fijo para reproducibilidad
)

# Estadísticas iniciales
θ_initial = [p.θ for p in particles_initial]
θ_dot_initial = [p.θ_dot for p in particles_initial]

println("✅ Partículas generadas")
println("   Posiciones θ:  min=$(round(minimum(θ_initial), digits=3)), max=$(round(maximum(θ_initial), digits=3))")
println("   Velocidades θ̇: min=$(round(minimum(θ_dot_initial), digits=3)), max=$(round(maximum(θ_dot_initial), digits=3))")
println()

# Calcular energía y momento iniciales
E0 = sum(kinetic_energy_angular(p.θ, p.θ_dot, p.mass, a, b) for p in particles_initial)
P0 = sum(conjugate_momentum(p, a, b) for p in particles_initial)

println("CANTIDADES CONSERVADAS INICIALES:")
println("-"^70)
println("Energía total (E₀):           $(E0)")
println("Momento conjugado total (P₀): $(P0)")
println("-"^70)
println()

# =============================================================================
# SIMULACIÓN
# =============================================================================

println("="^70)
println("EJECUTANDO SIMULACIÓN")
println("="^70)
println()

t_start = time()

data = simulate_ellipse_adaptive(
    particles_initial, a, b;
    max_time = max_time,
    dt_max = dt_max,
    dt_min = dt_min,
    save_interval = save_interval,
    collision_method = :parallel_transport,
    tolerance = 1e-6,
    max_steps = 50_000_000,
    use_parallel = use_parallel,
    use_projection = use_projection,
    projection_interval = projection_interval,
    projection_tolerance = projection_tolerance,
    verbose = true
)

t_end = time()
elapsed = t_end - t_start

println()
println("="^70)
println("✅ SIMULACIÓN COMPLETADA EN $(round(elapsed, digits=2)) segundos")
println("="^70)
println()

# =============================================================================
# ANÁLISIS DE CONSERVACIÓN
# =============================================================================

println("="^70)
println("ANÁLISIS DE CONSERVACIÓN")
println("="^70)
println()

# Extraer energías y momentos
energies = data.conservation.energies
momenta = data.conservation.conjugate_momenta
times = data.conservation.times

# Estadísticas de energía
E_final = energies[end]
ΔE_abs = abs(E_final - E0)
ΔE_rel = ΔE_abs / abs(E0)
E_max = maximum(energies)
E_min = minimum(energies)
E_std = std(energies)

println("ENERGÍA:")
println("-"^70)
println("E₀ (inicial):        $(E0)")
println("E_final:             $(E_final)")
println("ΔE (absoluto):       $(ΔE_abs)")
println("ΔE/E₀ (relativo):    $(ΔE_rel)")
println("E_max:               $(E_max)")
println("E_min:               $(E_min)")
println("σ(E):                $(E_std)")
println()

if ΔE_rel < 1e-10
    println("✅✅✅ Conservación EXCELENTE (ΔE/E₀ < 1e-10)")
elseif ΔE_rel < 1e-8
    println("✅✅ Conservación MUY BUENA (ΔE/E₀ < 1e-8)")
elseif ΔE_rel < 1e-6
    println("✅ Conservación BUENA (ΔE/E₀ < 1e-6)")
else
    println("⚠️  Conservación podría mejorar")
end
println()

# Estadísticas de momento
P_final = momenta[end]
ΔP_abs = abs(P_final - P0)
ΔP_rel = ΔP_abs / abs(P0)
P_max = maximum(momenta)
P_min = minimum(momenta)
P_std = std(momenta)

println("MOMENTO CONJUGADO:")
println("-"^70)
println("P₀ (inicial):        $(P0)")
println("P_final:             $(P_final)")
println("ΔP (absoluto):       $(ΔP_abs)")
println("ΔP/P₀ (relativo):    $(ΔP_rel)")
println("P_max:               $(P_max)")
println("P_min:               $(P_min)")
println("σ(P):                $(P_std)")
println()

# =============================================================================
# ANÁLISIS DE COLISIONES
# =============================================================================

println("="^70)
println("ANÁLISIS DE COLISIONES")
println("="^70)
println()

n_collisions = data.n_collisions
total_collisions = sum(n_collisions)
collision_rate = total_collisions / max_time
n_steps_total = length(n_collisions)

# Encontrar ventanas de tiempo con más colisiones
collision_counts = [sum(n_collisions[max(1, i-100):min(end, i+100)]) for i in 1:100:length(n_collisions)]
max_collision_window = maximum(collision_counts)

println("Total de colisiones:        $(total_collisions)")
println("Tasa de colisión promedio:  $(round(collision_rate, digits=3)) colisiones/s")
println("Pasos totales:              $(n_steps_total)")
println("Colisiones por paso:        $(round(total_collisions / n_steps_total, digits=4))")
println("Ventana más activa:         $(max_collision_window) colisiones")
println()

# Histograma de colisiones por snapshot
collision_histogram = Dict{Int, Int}()
for nc in n_collisions
    collision_histogram[nc] = get(collision_histogram, nc, 0) + 1
end

println("Distribución de colisiones por paso:")
for (nc, count) in sort(collect(collision_histogram))
    if nc <= 5  # Mostrar solo las primeras categorías
        percentage = count / length(n_collisions) * 100
        println("  $nc colisiones: $count pasos ($(round(percentage, digits=2))%)")
    end
end
println()

# =============================================================================
# ANÁLISIS DE DINÁMICA ESPACIAL
# =============================================================================

println("="^70)
println("ANÁLISIS DE DINÁMICA ESPACIAL")
println("="^70)
println()

# Estado final de las partículas
particles_final = data.particles[end]

# Distribución angular
θ_final = [p.θ for p in particles_final]
θ_dot_final = [p.θ_dot for p in particles_final]

println("DISTRIBUCIÓN ANGULAR (t=$(max_time)s):")
println("-"^70)
println("θ:  min=$(round(minimum(θ_final), digits=3)), max=$(round(maximum(θ_final), digits=3)), μ=$(round(mean(θ_final), digits=3)), σ=$(round(std(θ_final), digits=3))")
println("θ̇: min=$(round(minimum(θ_dot_final), digits=3)), max=$(round(maximum(θ_dot_final), digits=3)), μ=$(round(mean(θ_dot_final), digits=3)), σ=$(round(std(θ_dot_final), digits=3))")
println()

# Comparar con estado inicial
Δθ_mean = mean(θ_final) - mean(θ_initial)
Δθ_dot_mean = mean(θ_dot_final) - mean(θ_dot_initial)

println("CAMBIOS EN DISTRIBUCIÓN:")
println("-"^70)
println("Δμ(θ):  $(round(Δθ_mean, digits=3))")
println("Δμ(θ̇): $(round(Δθ_dot_mean, digits=3))")
println()

# Energías individuales
E_individual_final = [kinetic_energy_angular(p.θ, p.θ_dot, p.mass, a, b) for p in particles_final]
E_individual_initial = [kinetic_energy_angular(p.θ, p.θ_dot, p.mass, a, b) for p in particles_initial]

println("ENERGÍAS INDIVIDUALES:")
println("-"^70)
println("Inicial: min=$(round(minimum(E_individual_initial), digits=4)), max=$(round(maximum(E_individual_initial), digits=4)), μ=$(round(mean(E_individual_initial), digits=4))")
println("Final:   min=$(round(minimum(E_individual_final), digits=4)), max=$(round(maximum(E_individual_final), digits=4)), μ=$(round(mean(E_individual_final), digits=4))")
println()

# =============================================================================
# EVOLUCIÓN TEMPORAL
# =============================================================================

println("="^70)
println("EVOLUCIÓN TEMPORAL")
println("="^70)
println()

n_snapshots = length(data.particles)
println("Snapshots guardados: $(n_snapshots)")
println("Intervalo entre snapshots: $(save_interval) s")
println()

# Calcular dispersión angular en función del tiempo
function angular_dispersion(particles)
    positions = [p.pos for p in particles]
    # Calcular dispersión radial en coordenadas cartesianas
    center_x = mean([pos[1] for pos in positions])
    center_y = mean([pos[2] for pos in positions])
    dispersions = [sqrt((pos[1] - center_x)^2 + (pos[2] - center_y)^2) for pos in positions]
    return mean(dispersions)
end

dispersions = [angular_dispersion(snap) for snap in data.particles]
println("Dispersión espacial:")
println("  Inicial: $(round(dispersions[1], digits=4))")
println("  Final:   $(round(dispersions[end], digits=4))")
println("  Máxima:  $(round(maximum(dispersions), digits=4))")
println("  Mínima:  $(round(minimum(dispersions), digits=4))")
println()

# =============================================================================
# GUARDAR RESULTADOS
# =============================================================================

println("="^70)
println("GUARDANDO RESULTADOS")
println("="^70)
println()

# Crear directorio de resultados
timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
output_dir = "results/analisis_completo_$(timestamp)"
mkpath(output_dir)

# 1. Resumen de conservación
conservation_df = DataFrame(
    time = times,
    energy = energies,
    momentum = momenta,
    delta_E = abs.(energies .- E0),
    delta_P = abs.(momenta .- P0),
    delta_E_rel = abs.(energies .- E0) ./ abs(E0),
    delta_P_rel = abs.(momenta .- P0) ./ abs(P0)
)
CSV.write("$(output_dir)/conservation.csv", conservation_df)
println("✅ $(output_dir)/conservation.csv")

# 2. Estado inicial y final de partículas
initial_df = DataFrame(
    id = [p.id for p in particles_initial],
    theta = [p.θ for p in particles_initial],
    theta_dot = [p.θ_dot for p in particles_initial],
    x = [p.pos[1] for p in particles_initial],
    y = [p.pos[2] for p in particles_initial],
    vx = [p.vel[1] for p in particles_initial],
    vy = [p.vel[2] for p in particles_initial],
    energy = E_individual_initial
)
CSV.write("$(output_dir)/particles_initial.csv", initial_df)
println("✅ $(output_dir)/particles_initial.csv")

final_df = DataFrame(
    id = [p.id for p in particles_final],
    theta = [p.θ for p in particles_final],
    theta_dot = [p.θ_dot for p in particles_final],
    x = [p.pos[1] for p in particles_final],
    y = [p.pos[2] for p in particles_final],
    vx = [p.vel[1] for p in particles_final],
    vy = [p.vel[2] for p in particles_final],
    energy = E_individual_final
)
CSV.write("$(output_dir)/particles_final.csv", final_df)
println("✅ $(output_dir)/particles_final.csv")

# 3. Colisiones
collisions_df = DataFrame(
    step = 1:length(n_collisions),
    n_collisions = n_collisions
)
CSV.write("$(output_dir)/collisions.csv", collisions_df)
println("✅ $(output_dir)/collisions.csv")

# 4. Evolución espacial
dispersion_df = DataFrame(
    snapshot = 1:length(dispersions),
    time = collect(0:save_interval:(n_snapshots-1)*save_interval),
    dispersion = dispersions
)
CSV.write("$(output_dir)/spatial_dispersion.csv", dispersion_df)
println("✅ $(output_dir)/spatial_dispersion.csv")

# 5. Guardar SimulationData completo para análisis posterior
using JLD2
jld2_file = "$(output_dir)/simulation_data.jld2"
jldsave(jld2_file; data=data)
println("✅ $(output_dir)/simulation_data.jld2")

# 6. Resumen ejecutivo
summary_file = "$(output_dir)/RESUMEN.txt"
open(summary_file, "w") do io
    println(io, "="^70)
    println(io, "RESUMEN DE SIMULACIÓN - CollectiveDynamics.jl")
    println(io, "="^70)
    println(io)
    println(io, "Fecha: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))")
    println(io, "Tiempo de ejecución: $(round(elapsed, digits=2)) s")
    println(io)
    println(io, "CONFIGURACIÓN:")
    println(io, "-"^70)
    println(io, "Elipse: a=$a, b=$b")
    println(io, "Partículas: $N")
    println(io, "Tiempo simulado: $max_time s")
    println(io, "dt_max: $dt_max")
    println(io, "Projection: $(use_projection ? "Activado (c/$projection_interval)" : "Desactivado")")
    println(io, "Parallel: $(use_parallel ? "Activado ($(Threads.nthreads()) threads)" : "Desactivado")")
    println(io)
    println(io, "CONSERVACIÓN:")
    println(io, "-"^70)
    println(io, "ΔE/E₀: $(ΔE_rel)")
    println(io, "ΔP/P₀: $(ΔP_rel)")
    println(io, "Calidad: $(ΔE_rel < 1e-9 ? "EXCELENTE" : ΔE_rel < 1e-6 ? "BUENA" : "REGULAR")")
    println(io)
    println(io, "COLISIONES:")
    println(io, "-"^70)
    println(io, "Total: $(total_collisions)")
    println(io, "Tasa: $(round(collision_rate, digits=3)) colisiones/s")
    println(io)
    println(io, "DINÁMICA:")
    println(io, "-"^70)
    println(io, "Dispersión inicial: $(round(dispersions[1], digits=4))")
    println(io, "Dispersión final: $(round(dispersions[end], digits=4))")
    println(io)
end
println("✅ $(output_dir)/RESUMEN.txt")

println()
println("="^70)
println("✅ ANÁLISIS COMPLETO")
println("="^70)
println()
println("Todos los resultados guardados en: $(output_dir)/")
println()
println("Archivos generados:")
println("  - conservation.csv         (evolución de E, P)")
println("  - particles_initial.csv    (estado inicial)")
println("  - particles_final.csv      (estado final)")
println("  - collisions.csv           (historial de colisiones)")
println("  - spatial_dispersion.csv   (dispersión espacial)")
println("  - simulation_data.jld2     (datos completos para visualización)")
println("  - RESUMEN.txt              (resumen ejecutivo)")
println()
println("="^70)
println()
println("Para generar visualizaciones:")
println("  julia --project=. visualizar_resultados.jl $(output_dir)")
println("="^70)
