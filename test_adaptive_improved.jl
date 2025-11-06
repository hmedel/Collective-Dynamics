"""
Test mejorado del sistema de tiempos adaptativos.

En lugar de partículas que colisionan constantemente, este test usa
partículas con trayectorias que se cruzan ocasionalmente, demostrando
mejor el valor del sistema adaptativo.
"""

using Pkg
Pkg.activate(".")

using CollectiveDynamics
using Printf
using Statistics

println("="^70)
println("TEST MEJORADO: Sistema de Tiempos Adaptativos")
println("="^70)
println()
println("Configuración:")
println("  - 5 partículas con radios pequeños")
println("  - Velocidades variadas")
println("  - Colisiones ocasionales (no constantes)")
println("="^70)
println()

# Parámetros de la elipse
a, b = 2.0, 1.0

# Crear 5 partículas con configuración que NO colisione constantemente
particles = Particle{Float64}[]

# Partículas bien separadas espacialmente
push!(particles, CollectiveDynamics.initialize_particle(1, 1.0, 0.05, 0.0, 0.5, a, b))
push!(particles, CollectiveDynamics.initialize_particle(2, 1.0, 0.05, π/2, -0.3, a, b))
push!(particles, CollectiveDynamics.initialize_particle(3, 1.0, 0.05, π, 0.7, a, b))
push!(particles, CollectiveDynamics.initialize_particle(4, 1.0, 0.05, 3π/2, -0.4, a, b))
push!(particles, CollectiveDynamics.initialize_particle(5, 1.0, 0.05, π/4, 0.6, a, b))

# Energía inicial
E0 = CollectiveDynamics.total_energy(particles, a, b)
println(@sprintf("💡 Energía inicial: E₀ = %.6f", E0))
println()

# ============================================================================
# Test 1: Simulación con dt fijo
# ============================================================================

println("="^70)
println("TEST 1: Simulación con dt FIJO")
println("="^70)
println()

data_fixed = simulate_ellipse(
    particles, a, b;
    n_steps=1000,
    dt=1e-5,
    save_every=100,
    collision_method=:parallel_transport,
    verbose=false
)

E_analysis_fixed = analyze_energy_conservation(data_fixed.conservation)
total_collisions_fixed = sum(data_fixed.n_collisions)

println(@sprintf("  Pasos totales:       %d", 1000))
println(@sprintf("  Colisiones totales:  %d", total_collisions_fixed))
println(@sprintf("  Error energía:       ΔE/E₀ = %.6e", E_analysis_fixed.max_rel_error))
println()

# ============================================================================
# Test 2: Simulación con dt adaptativo
# ============================================================================

println("="^70)
println("TEST 2: Simulación con dt ADAPTATIVO")
println("="^70)
println()

data_adaptive = simulate_ellipse_adaptive(
    particles, a, b;
    max_time=1000*1e-5,  # Mismo tiempo total
    dt_max=1e-5,
    dt_min=1e-10,
    save_interval=100*1e-5,
    collision_method=:parallel_transport,
    verbose=false
)

E_analysis_adaptive = analyze_energy_conservation(data_adaptive.conservation)
total_collisions_adaptive = sum(data_adaptive.n_collisions)

println(@sprintf("  Pasos totales:       %d", length(data_adaptive.parameters[:dt_history])))
println(@sprintf("  Colisiones totales:  %d", total_collisions_adaptive))
println(@sprintf("  Error energía:       ΔE/E₀ = %.6e", E_analysis_adaptive.max_rel_error))

if haskey(data_adaptive.parameters, :dt_history)
    dt_hist = data_adaptive.parameters[:dt_history]
    println(@sprintf("  dt promedio:         %.6e", mean(dt_hist)))
    println(@sprintf("  dt mínimo:           %.6e", minimum(dt_hist)))
    println(@sprintf("  dt máximo:           %.6e", maximum(dt_hist)))
end
println()

# ============================================================================
# Comparación
# ============================================================================

println("="^70)
println("COMPARACIÓN")
println("="^70)
println()

println(@sprintf("  Colisiones - Fijo:       %d", total_collisions_fixed))
println(@sprintf("  Colisiones - Adaptativo: %d", total_collisions_adaptive))
println()
println(@sprintf("  Error energía - Fijo:       %.6e", E_analysis_fixed.max_rel_error))
println(@sprintf("  Error energía - Adaptativo: %.6e", E_analysis_adaptive.max_rel_error))
println()

# Análisis del sistema adaptativo
if haskey(data_adaptive.parameters, :dt_history)
    dt_hist = data_adaptive.parameters[:dt_history]
    n_steps_adaptive = length(dt_hist)
    n_steps_fixed = 1000

    println("📊 Eficiencia del Sistema Adaptativo:")
    println(@sprintf("  Pasos con dt fijo:      %d", n_steps_fixed))
    println(@sprintf("  Pasos con dt adaptativo: %d", n_steps_adaptive))

    if n_steps_adaptive < n_steps_fixed
        println(@sprintf("  Reducción: %.1f%%", 100 * (n_steps_fixed - n_steps_adaptive) / n_steps_fixed))
    elseif n_steps_adaptive > n_steps_fixed
        ratio = Float64(n_steps_adaptive) / n_steps_fixed
        println(@sprintf("  Incremento: %.1fx", ratio))
        if ratio < 10
            println("  (Aceptable - mayor precisión en detección)")
        end
    end
    println()

    # Distribución de dt
    unique_dts = sort(unique(dt_hist), rev=true)
    n_unique = length(unique_dts)
    println(@sprintf("  Valores únicos de dt: %d", n_unique))

    if n_unique > 1
        println("  → El sistema está adaptando dt correctamente")
    else
        println("  ⚠️ Advertencia: dt constante (posible problema)")
    end
end

println()
println("="^70)
println("✅ Test completado")
println("="^70)
println()

println("Notas:")
println("  • El sistema adaptativo puede usar más pasos que dt fijo")
println("  • Esto es normal si detecta colisiones con mayor precisión")
println("  • Lo importante es que dt varíe según la dinámica")
println("  • Y que no se quede 'stuck' con dt_min constantemente")
println()
