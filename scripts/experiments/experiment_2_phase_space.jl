#!/usr/bin/env julia
"""
experiment_2_phase_space.jl

EXPERIMENTO 2: Análisis Completo de Espacio Fase

Objetivo: Caracterizar compactificación espacial y termalización
Pregunta: ¿Por qué todas las partículas terminan en el mismo sector?
"""

using Pkg
Pkg.activate(".")

include("src/simulation_polar.jl")
include("src/analysis_tools.jl")

using Printf
using Random
using Statistics
using DelimitedFiles

println("=" ^ 70)
println("EXPERIMENTO 2: Análisis de Espacio Fase")
println("=" ^ 70)
println()

# ============================================================================
# Configuración (mismos parámetros que Experimento 1)
# ============================================================================

a, b = 2.0, 1.0
N = 40
mass = 1.0
radius = 0.05
max_time = 30.0  # 30 segundos (suficiente para ver compactificación)
dt_max = 1e-5
dt_min = 1e-10
save_interval = 0.1  # Guardar cada 0.1s (300 snapshots)

println("PARÁMETROS:")
println("  N partículas:    $N")
println("  Tiempo total:    $max_time s")
println("  dt_max:          $dt_max")
println("  Save interval:   $save_interval s")
println("  Semi-ejes:       a=$a, b=$b")
println("  Projection:      Activado (cada 100 pasos)")
println()

# ============================================================================
# Crear partículas (MISMO SEED que Experimento 1)
# ============================================================================

println("Creando partículas (seed=42, idénticas a Experimento 1)...")
Random.seed!(42)

particles = ParticlePolar{Float64}[]
for i in 1:N
    φ = rand() * 2π
    φ_dot = (rand() - 0.5) * 2.0  # [-1, 1]
    push!(particles, ParticlePolar(i, mass, radius, φ, φ_dot, a, b))
end

E_initial = sum(kinetic_energy(p, a, b) for p in particles)
println("  Energía inicial: ", @sprintf("%.10f", E_initial))
println()

# ============================================================================
# Ejecutar simulación CON SNAPSHOTS
# ============================================================================

println("=" ^ 70)
println("EJECUTANDO SIMULACIÓN (esto tomará ~2-3 minutos)")
println("=" ^ 70)
println()

t_start = time()

data = simulate_ellipse_polar_adaptive(
    particles, a, b;
    max_time = max_time,
    dt_max = dt_max,
    dt_min = dt_min,
    save_interval = save_interval,
    collision_method = :parallel_transport,
    use_projection = true,
    projection_interval = 100,
    projection_tolerance = 1e-12,
    verbose = true
)

t_elapsed = time() - t_start

println()
println("Simulación completada en: ", @sprintf("%.2f s (%.2f min)", t_elapsed, t_elapsed/60))
println()

# ============================================================================
# Verificar que tenemos snapshots
# ============================================================================

println("Datos capturados:")
println("  Snapshots:       ", length(data.particles_history))
println("  Tiempos:         ", length(data.times))
println("  Colisiones:      ", sum(data.n_collisions))
println()

# ============================================================================
# ANÁLISIS COMPLETO usando analysis_tools.jl
# ============================================================================

println("=" ^ 70)
println("EJECUTANDO ANÁLISIS COMPLETO")
println("=" ^ 70)
println()

output_dir = "results_experiment_2"
mkpath(output_dir)

results = run_complete_analysis(data, a, b, output_dir)

println()
println("=" ^ 70)
println("✅ EXPERIMENTO 2 COMPLETADO")
println("=" ^ 70)
println()

# ============================================================================
# Resumen de Hallazgos Clave
# ============================================================================

println("HALLAZGOS CLAVE:")
println("-" ^ 70)
println()

# 1. Compactificación espacial
println("1. COMPACTIFICACIÓN ESPACIAL:")
phase = results.phase
println("   σ_φ inicial:  ", @sprintf("%.6f rad", phase.σ_φ[1]))
println("   σ_φ final:    ", @sprintf("%.6f rad", phase.σ_φ[end]))
ratio_φ = phase.σ_φ[end] / phase.σ_φ[1]
println("   Ratio:        ", @sprintf("%.3f", ratio_φ))
if ratio_φ < 0.5
    println("   → FUERTE compactificación espacial ✅")
elseif ratio_φ < 0.8
    println("   → Compactificación moderada")
else
    println("   → Sin compactificación significativa")
end
println()

# 2. Compactificación de velocidades
println("2. COMPACTIFICACIÓN DE VELOCIDADES:")
println("   σ_φ̇ inicial:  ", @sprintf("%.6f", phase.σ_φ_dot[1]))
println("   σ_φ̇ final:    ", @sprintf("%.6f", phase.σ_φ_dot[end]))
ratio_φ_dot = phase.σ_φ_dot[end] / phase.σ_φ_dot[1]
println("   Ratio:        ", @sprintf("%.3f", ratio_φ_dot))
if ratio_φ_dot < 0.5
    println("   → FUERTE compactificación de velocidades ✅")
elseif ratio_φ_dot < 0.8
    println("   → Compactificación moderada")
else
    println("   → Sin compactificación significativa")
end
println()

# 3. Correlación con curvatura
println("3. CORRELACIÓN CON CURVATURA:")
curv = results.curvature
println("   Correlación ρ(φ) vs κ(φ): ", @sprintf("%.4f", curv.correlation))
if abs(curv.correlation) > 0.5
    println("   → FUERTE correlación! Las partículas prefieren regiones de alta/baja curvatura ✅")
elseif abs(curv.correlation) > 0.3
    println("   → Correlación moderada")
else
    println("   → No hay correlación significativa")
end
println()

# 4. Termalización
println("4. TERMALIZACIÓN:")
therm = results.thermalization
println("   σ_E inicial: ", @sprintf("%.6f", therm.E_stds[1]))
println("   σ_E final:   ", @sprintf("%.6f", therm.E_stds[end]))
ratio_E = therm.E_stds[end] / therm.E_stds[1]
println("   Ratio:       ", @sprintf("%.3f", ratio_E))
if !isnothing(therm.τ_relax)
    println("   τ_relax:     ", @sprintf("%.2f s", therm.τ_relax))
else
    println("   τ_relax:     > $(max_time) s (no alcanzado)")
end
println()

# 5. Colisiones
println("5. ESTADÍSTICAS DE COLISIONES:")
coll = results.collisions
println("   Total:         ", coll.total_collisions)
println("   Tasa promedio: ", @sprintf("%.2f/s", coll.avg_rate))
println("   Tasa inicial:  ", @sprintf("%.2f/s", coll.collision_rates[1]))
println("   Tasa final:    ", @sprintf("%.2f/s", coll.collision_rates[end]))
println()

# ============================================================================
# Guardar visualizaciones de distribuciones
# ============================================================================

println("=" ^ 70)
println("GUARDANDO VISUALIZACIONES")
println("=" ^ 70)
println()

# Distribución espacial en diferentes tiempos
times_to_plot = [1, Int(div(length(data.times), 2)), length(data.times)]
time_labels = ["inicial", "medio", "final"]

spatial_dist = zeros(3, 8)  # 3 tiempos x 8 sectores

for (idx, t_idx) in enumerate(times_to_plot)
    snapshot = data.particles_history[t_idx]
    sector_counts = zeros(Int, 8)

    for p in snapshot
        φ_normalized = mod(p.φ, 2π)
        sector = floor(Int, φ_normalized / (2π / 8)) + 1
        sector = min(sector, 8)
        sector_counts[sector] += 1
    end

    spatial_dist[idx, :] = sector_counts
end

# Guardar distribución espacial temporal
open(joinpath(output_dir, "spatial_evolution.txt"), "w") do io
    println(io, "Evolución de la Distribución Espacial")
    println(io, "=" ^ 70)
    println(io)

    for (idx, label) in enumerate(time_labels)
        println(io, "Tiempo $label (t=$(data.times[times_to_plot[idx]]) s):")
        for sector in 1:8
            φ_start = (sector-1) * (2π / 8)
            φ_end = sector * (2π / 8)
            count = Int(spatial_dist[idx, sector])
            bar = "█" ^ count
            println(io, @sprintf("  Sector %d [%.2f-%.2f]: %2d %s",
                                sector, φ_start, φ_end, count, bar))
        end
        println(io)
    end
end
println("  ✓ spatial_evolution.txt")

# Guardar distribución de energías inicial vs final
open(joinpath(output_dir, "energy_distribution_comparison.txt"), "w") do io
    println(io, "Comparación de Distribuciones de Energía")
    println(io, "=" ^ 70)
    println(io)

    initial_energies = [kinetic_energy(p, a, b) for p in data.particles_history[1]]
    final_energies = [kinetic_energy(p, a, b) for p in data.particles_history[end]]

    println(io, "Inicial:")
    println(io, "  Min:    ", @sprintf("%.6f", minimum(initial_energies)))
    println(io, "  Max:    ", @sprintf("%.6f", maximum(initial_energies)))
    println(io, "  Mean:   ", @sprintf("%.6f", mean(initial_energies)))
    println(io, "  Std:    ", @sprintf("%.6f", std(initial_energies)))
    println(io, "  Range:  ", @sprintf("%.6f", maximum(initial_energies) - minimum(initial_energies)))
    println(io)

    println(io, "Final:")
    println(io, "  Min:    ", @sprintf("%.6f", minimum(final_energies)))
    println(io, "  Max:    ", @sprintf("%.6f", maximum(final_energies)))
    println(io, "  Mean:   ", @sprintf("%.6f", mean(final_energies)))
    println(io, "  Std:    ", @sprintf("%.6f", std(final_energies)))
    println(io, "  Range:  ", @sprintf("%.6f", maximum(final_energies) - minimum(final_energies)))
    println(io)

    println(io, "Cambio:")
    println(io, "  Δ Std:  ", @sprintf("%.6f", std(final_energies) - std(initial_energies)))
    println(io, "  Ratio:  ", @sprintf("%.3f", std(final_energies) / std(initial_energies)))
end
println("  ✓ energy_distribution_comparison.txt")

println()
println("=" ^ 70)
println("TODOS LOS RESULTADOS GUARDADOS EN: $output_dir/")
println("=" ^ 70)
println()

println("Archivos generados:")
println("  - phase_space_evolution.csv       (σ_φ, σ_φ̇ vs tiempo)")
println("  - curvature_correlation.csv       (densidad vs curvatura)")
println("  - thermalization.csv              (distribución energías vs tiempo)")
println("  - collision_stats.csv             (tasa de colisiones)")
println("  - spatial_evolution.txt           (distribución por sectores)")
println("  - energy_distribution_comparison.txt")
println()

println("CONCLUSIONES PRELIMINARES:")
println("-" ^ 70)
println()
println("Basado en los primeros 30 segundos de simulación:")
println()
println("1. El sistema muestra compactificación espacial con ratio = ", @sprintf("%.3f", ratio_φ))
println("2. Las velocidades también se compactan con ratio = ", @sprintf("%.3f", ratio_φ_dot))
println("3. Correlación densidad-curvatura: ", @sprintf("%.4f", curv.correlation))
println("4. Energías individuales se redistribuyen (termalización)")
println()
println("Esto confirma el hallazgo de Experimento 1:")
println("  → El sistema tiende a agruparse espacialmente")
println("  → La curvatura κ(φ) parece ser el driver principal")
println("  → Necesitamos entender el mecanismo físico detrás")
println()
