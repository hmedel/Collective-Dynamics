"""
    ellipse_simulation.jl

Ejemplo completo de simulación de partículas en una elipse.

Este script demuestra:
1. Inicialización de partículas
2. Simulación con transporte paralelo
3. Análisis de conservación
4. Comparación de métodos de colisión

Uso:
    julia examples/ellipse_simulation.jl
"""

using CollectiveDynamics
using Random
using Printf

println("""
╔════════════════════════════════════════════════════════════════════╗
║                                                                    ║
║        Simulación de Dinámica Colectiva en Elipse                 ║
║                                                                    ║
║   Implementación del algoritmo de García-Hernández & Medel-Cobaxín║
║                                                                    ║
╚════════════════════════════════════════════════════════════════════╝
""")

# ============================================================================
# Parámetros de la Simulación
# ============================================================================

# Geometría de la elipse
a = 2.0  # Semi-eje mayor
b = 1.0  # Semi-eje menor

# Partículas
n_particles = 40
mass = 1.0
radius_fraction = 0.05

# Simulación
n_steps = 100_000
dt = 1e-8
save_every = 100

# Método de colisión
collision_method = :parallel_transport  # :simple, :parallel_transport, :geodesic

# Semilla para reproducibilidad
Random.seed!(1234)

println("\n📋 PARÁMETROS:")
println("━" ^ 70)
println(@sprintf("  Elipse (a, b):        (%.2f, %.2f)", a, b))
println(@sprintf("  Excentricidad:        %.4f", sqrt(1 - (b/a)^2)))
println(@sprintf("  Partículas:           %d", n_particles))
println(@sprintf("  Radio partículas:     %.4f", radius_fraction * min(a, b)))
println(@sprintf("  Pasos de tiempo:      %d", n_steps))
println(@sprintf("  dt:                   %.2e", dt))
println(@sprintf("  Duración total:       %.6f", n_steps * dt))
println(@sprintf("  Método colisión:      %s", collision_method))
println("━" ^ 70)

# ============================================================================
# Generar Partículas Iniciales
# ============================================================================

println("\n🔧 Generando partículas iniciales...")

# Rango de velocidades angulares
θ_dot_range = (-1e5, 1e5)

particles_initial = generate_random_particles(
    n_particles,
    mass,
    radius_fraction,
    a,
    b;
    θ_dot_range=θ_dot_range,
    rng=MersenneTwister(1234)
)

println("✅ Partículas generadas exitosamente")

# Verificar estado inicial
E_initial = total_energy(particles_initial, a, b)
p_initial = total_linear_momentum(particles_initial)

println("\n📊 ESTADO INICIAL:")
println("━" ^ 70)
println(@sprintf("  Energía total:        %.6e", E_initial))
println(@sprintf("  |Momento lineal|:     %.6e", LinearAlgebra.norm(p_initial)))
println(@sprintf("  Centro de masa:       (%.6f, %.6f)",
        center_of_mass(particles_initial)...))
println("━" ^ 70)

# ============================================================================
# Ejecutar Simulación
# ============================================================================

println("\n🚀 Iniciando simulación...\n")

data = simulate_ellipse(
    particles_initial,
    a,
    b;
    n_steps=n_steps,
    dt=dt,
    save_every=save_every,
    collision_method=collision_method,
    tolerance=1e-6,
    verbose=true
)

# ============================================================================
# Análisis de Resultados
# ============================================================================

println("\n📊 ANÁLISIS DE RESULTADOS\n")

# Conservación
print_conservation_summary(data.conservation)

# Estadísticas de colisiones
total_collisions = sum(data.n_collisions)
avg_collisions_per_step = total_collisions / n_steps
avg_conserved_fraction = Statistics.mean(
    data.conserved_fractions[data.n_collisions .> 0]
)

println("\n📊 COLISIONES:")
println("━" ^ 70)
println(@sprintf("  Total de colisiones:  %d", total_collisions))
println(@sprintf("  Colisiones por paso:  %.4f", avg_collisions_per_step))
println(@sprintf("  Fracción conservada:  %.6f", avg_conserved_fraction))
println("━" ^ 70)

# ============================================================================
# Comparación de Métodos (opcional)
# ============================================================================

println("\n🔬 Comparando métodos de resolución de colisiones...\n")

methods_to_test = [:simple, :parallel_transport]
comparison_steps = 10_000

comparison_results = Dict{Symbol, NamedTuple}()

for method in methods_to_test
    println("  Probando método: $method...")

    data_test = simulate_ellipse(
        particles_initial,
        a,
        b;
        n_steps=comparison_steps,
        dt=dt,
        save_every=comparison_steps,  # Solo guardar inicio y fin
        collision_method=method,
        tolerance=1e-6,
        verbose=false
    )

    E_analysis = analyze_energy_conservation(data_test.conservation)

    comparison_results[method] = (
        max_rel_error=E_analysis.max_rel_error,
        rel_drift=E_analysis.rel_drift,
        is_conserved=E_analysis.is_conserved
    )
end

println("\n📊 COMPARACIÓN DE MÉTODOS:")
println("━" ^ 70)
println(@sprintf("%-25s %15s %15s %12s", "Método", "Error rel. max", "Drift rel.", "Conserva?"))
println("━" ^ 70)

for method in methods_to_test
    result = comparison_results[method]
    conserved_str = result.is_conserved ? "✅ SÍ" : "❌ NO"
    println(@sprintf("%-25s %15.2e %15.2e %12s",
            String(method),
            result.max_rel_error,
            result.rel_drift,
            conserved_str))
end
println("━" ^ 70)

# ============================================================================
# Guardar Resultados
# ============================================================================

println("\n💾 Guardando resultados...")

# Guardar datos de conservación
using DataFrames, CSV

df_conservation = DataFrame(
    time = data.conservation.times,
    energy = data.conservation.energies,
    momentum_x = [p[1] for p in data.conservation.momenta],
    momentum_y = [p[2] for p in data.conservation.momenta],
    angular_momentum = data.conservation.angular_momenta
)

output_file = "ellipse_simulation_results.csv"
CSV.write(output_file, df_conservation)

println("✅ Resultados guardados en: $output_file")

# ============================================================================
# Resumen Final
# ============================================================================

println("""

╔════════════════════════════════════════════════════════════════════╗
║                                                                    ║
║                    SIMULACIÓN COMPLETADA                           ║
║                                                                    ║
╚════════════════════════════════════════════════════════════════════╝

Próximos pasos:
  1. Visualizar resultados con GLMakie.jl
  2. Probar con diferentes geometrías (a/b)
  3. Escalar a más partículas
  4. Implementar paralelización CPU/GPU

Para más información:
  julia> using CollectiveDynamics
  julia> ?simulate_ellipse

""")
