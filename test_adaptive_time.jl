"""
Test script para el sistema de tiempos adaptativos.

Compara:
1. Simulación con dt fijo
2. Simulación con dt adaptativo

Y verifica:
- Conservación de energía
- Número de colisiones detectadas
- Historial de pasos de tiempo
"""

using Pkg
Pkg.activate(".")

using CollectiveDynamics
using Printf

println("="^70)
println("TEST: Sistema de Tiempos Adaptativos")
println("="^70)

# Parámetros de la elipse
a, b = 2.0, 1.0

# Crear partículas con colisiones garantizadas
println("\n📍 Configuración:")
println("  2 partículas moviéndose una hacia la otra")
println("  Radio grande (0.4) para garantizar colisión")

p1 = CollectiveDynamics.initialize_particle(1, 1.0, 0.4, 0.7853981633974483, 0.8, a, b)
p2 = CollectiveDynamics.initialize_particle(2, 1.0, 0.4, 1.1853981633974482, -0.8, a, b)

particles = [p1, p2]

# Energía inicial
E0 = CollectiveDynamics.total_energy(particles, a, b)
println(@sprintf("  Energía inicial: E₀ = %.10f", E0))

# ============================================================================
# Test 1: Simulación con dt fijo
# ============================================================================

println("\n" * "="^70)
println("TEST 1: Simulación con dt FIJO")
println("="^70)

data_fixed = simulate_ellipse(
    particles, a, b;
    n_steps=100,
    dt=1e-6,
    save_every=10,
    collision_method=:parallel_transport,
    verbose=false
)

E_analysis_fixed = analyze_energy_conservation(data_fixed.conservation)
total_collisions_fixed = sum(data_fixed.n_collisions)

println(@sprintf("  Pasos totales:       %d", 100))
println(@sprintf("  Colisiones totales:  %d", total_collisions_fixed))
println(@sprintf("  Error energía:       ΔE/E₀ = %.6e", E_analysis_fixed.max_rel_error))

# ============================================================================
# Test 2: Simulación con dt adaptativo
# ============================================================================

println("\n" * "="^70)
println("TEST 2: Simulación con dt ADAPTATIVO")
println("="^70)

data_adaptive = simulate_ellipse_adaptive(
    particles, a, b;
    max_time=100*1e-6,  # Mismo tiempo total que dt fijo
    dt_max=1e-6,
    dt_min=1e-10,
    save_interval=10*1e-6,
    collision_method=:parallel_transport,
    verbose=false
)

E_analysis_adaptive = analyze_energy_conservation(data_adaptive.conservation)
total_collisions_adaptive = sum(data_adaptive.n_collisions)

println(@sprintf("  Pasos totales:       %d", length(data_adaptive.parameters[:dt_history])))
println(@sprintf("  Colisiones totales:  %d", total_collisions_adaptive))
println(@sprintf("  Error energía:       ΔE/E₀ = %.6e", E_analysis_adaptive.max_rel_error))
println(@sprintf("  dt promedio:         %.6e", mean(data_adaptive.parameters[:dt_history])))
println(@sprintf("  dt mínimo:           %.6e", minimum(data_adaptive.parameters[:dt_history])))
println(@sprintf("  dt máximo:           %.6e", maximum(data_adaptive.parameters[:dt_history])))

# ============================================================================
# Comparación
# ============================================================================

println("\n" * "="^70)
println("COMPARACIÓN")
println("="^70)

println(@sprintf("  Colisiones - Fijo:       %d", total_collisions_fixed))
println(@sprintf("  Colisiones - Adaptativo: %d", total_collisions_adaptive))
println()
println(@sprintf("  Error energía - Fijo:       %.6e", E_analysis_fixed.max_rel_error))
println(@sprintf("  Error energía - Adaptativo: %.6e", E_analysis_adaptive.max_rel_error))

# Mejora relativa
if E_analysis_fixed.max_rel_error > 0
    improvement = (E_analysis_fixed.max_rel_error - E_analysis_adaptive.max_rel_error) / E_analysis_fixed.max_rel_error * 100
    println()
    println(@sprintf("  🎯 Mejora en conservación: %.1f%%", improvement))
end

# Historial de dt
println("\n📊 Historial de pasos de tiempo (adaptativo):")
dt_hist = data_adaptive.parameters[:dt_history]
n_unique = length(unique(dt_hist))
println(@sprintf("  Valores únicos de dt: %d", n_unique))

if n_unique <= 10
    println("  Valores de dt:")
    for dt_val in sort(unique(dt_hist), rev=true)
        count = sum(dt_hist .== dt_val)
        println(@sprintf("    dt = %.6e  (usado %d veces)", dt_val, count))
    end
end

println("\n" * "="^70)
println("✅ Test completado")
println("="^70)
