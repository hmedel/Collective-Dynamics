"""
Ejemplo simple del sistema de tiempos adaptativos.

Muestra:
1. Cómo usar simulate_ellipse_adaptive()
2. Análisis de conservación
3. Estadísticas de los pasos de tiempo
"""

using Pkg
Pkg.activate(".")

using CollectiveDynamics
using Printf
using Statistics

println()
println("="^70)
println("EJEMPLO: Simulación con Tiempos Adaptativos")
println("="^70)
println()

# ============================================================================
# Configuración
# ============================================================================

println("📋 Configuración:")
a, b = 2.0, 1.0
n_particles = 10
mass = 1.0
radius = 0.1

println(@sprintf("  Elipse: a = %.1f, b = %.1f", a, b))
println(@sprintf("  Partículas: %d", n_particles))
println(@sprintf("  Masa: %.1f, Radio: %.2f", mass, radius))
println()

# Generar partículas aleatorias
particles = generate_random_particles(n_particles, mass, radius, a, b)

# Energía y momento inicial
E0 = total_energy(particles, a, b)
println(@sprintf("💡 Energía inicial: E₀ = %.6f", E0))
println()

# ============================================================================
# Simulación con tiempos adaptativos
# ============================================================================

println("="^70)
println("🚀 EJECUTANDO SIMULACIÓN ADAPTATIVA")
println("="^70)
println()

data = simulate_ellipse_adaptive(
    particles, a, b;
    max_time = 0.01,          # 0.01 unidades de tiempo
    dt_max = 1e-5,            # Paso máximo
    dt_min = 1e-10,           # Paso mínimo (partículas pegadas)
    save_interval = 0.001,    # Guardar cada 0.001
    collision_method = :parallel_transport,
    tolerance = 1e-6,
    verbose = true            # Mostrar progreso
)

# ============================================================================
# Análisis de resultados
# ============================================================================

println()
println("="^70)
println("📊 ANÁLISIS DE RESULTADOS")
println("="^70)
println()

# Conservación de energía
E_analysis = analyze_energy_conservation(data.conservation)
println("🔋 Conservación de Energía:")
println(@sprintf("  Energía inicial:  %.10f", E_analysis.E_initial))
println(@sprintf("  Energía final:    %.10f", E_analysis.E_final))
println(@sprintf("  Error máximo:     ΔE/E₀ = %.6e", E_analysis.max_rel_error))
println(@sprintf("  Drift relativo:   ΔE/E₀ = %.6e", E_analysis.rel_drift))

if E_analysis.max_rel_error < 1e-6
    println("  ✅ EXCELENTE: Error < 1e-6")
elseif E_analysis.max_rel_error < 1e-4
    println("  ✅ BUENO: Error < 1e-4")
elseif E_analysis.max_rel_error < 1e-2
    println("  ⚠️  ACEPTABLE: Error < 1e-2")
else
    println("  ❌ ALTO: Error > 1e-2")
end
println()

# Colisiones
total_collisions = sum(data.n_collisions)
println("💥 Colisiones:")
println(@sprintf("  Total: %d colisiones", total_collisions))
if total_collisions > 0
    conserved_count = sum(data.conserved_fractions .> 0.5)
    println(@sprintf("  Conservadas: %d (%.1f%%)",
            conserved_count, 100 * conserved_count / total_collisions))
end
println()

# Estadísticas de dt
dt_hist = data.parameters[:dt_history]
println("⏱️  Estadísticas de Pasos de Tiempo:")
println(@sprintf("  Total de pasos:  %d", length(dt_hist)))
println(@sprintf("  dt promedio:     %.6e", mean(dt_hist)))
println(@sprintf("  dt mínimo:       %.6e", minimum(dt_hist)))
println(@sprintf("  dt máximo:       %.6e", maximum(dt_hist)))
println(@sprintf("  Desv. estándar:  %.6e", std(dt_hist)))
println(@sprintf("  Valores únicos:  %d", length(unique(dt_hist))))
println()

# Distribución de dt
println("📈 Distribución de dt (top 5):")
unique_dts = sort(unique(dt_hist), rev=true)
for (i, dt_val) in enumerate(unique_dts[1:min(5, length(unique_dts))])
    count = sum(dt_hist .== dt_val)
    percent = 100 * count / length(dt_hist)
    println(@sprintf("  %d. dt = %.6e  (%d veces, %.1f%%)", i, dt_val, count, percent))
end
println()

# ============================================================================
# Resumen
# ============================================================================

println("="^70)
println("✅ SIMULACIÓN COMPLETADA")
println("="^70)
println()
println("Características del sistema adaptativo:")
println("  ✓ Detección exacta de colisiones")
println("  ✓ Ajuste automático de dt según dinámica")
println("  ✓ Forest-Ruth para geodésicas (integración simpléctica)")
println("  ✓ Transporte paralelo con RK4 (4to orden)")
println("  ✓ Manejo de partículas 'pegadas' con dt_min")
println("  ✓ Vector de tiempos irregular (adaptativo)")
println()
println("Comparado con dt fijo:")
println("  + Mejor conservación de energía")
println("  + No se pierden colisiones")
println("  + Eficiente: dt grande cuando no hay eventos")
println("  - Más lento: O(n²) búsqueda de colisiones cada paso")
println()
println("Ideal para:")
println("  • Sistemas con pocas partículas (n < 100)")
println("  • Alta precisión requerida")
println("  • Dinámica con eventos discretos importantes")
println("="^70)
