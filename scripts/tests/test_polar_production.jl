#!/usr/bin/env julia
"""
test_polar_production.jl

Test de producción: 40 partículas, 10 segundos
Simulación completa en coordenadas polares φ para comparar con implementación θ.
"""

using Pkg
Pkg.activate(".")

include("src/simulation_polar.jl")

using Printf
using Random
using Statistics

println("=" ^ 70)
println("TEST DE PRODUCCIÓN: Coordenadas Polares φ")
println("=" ^ 70)
println()

# ============================================================================
# Configuración
# ============================================================================

# Parámetros geométricos
a, b = 2.0, 1.0

# Parámetros de partículas
N = 40
mass = 1.0
radius = 0.05

# Parámetros de simulación
max_time = 10.0
dt_max = 1e-5
dt_min = 1e-10
save_interval = 0.01

println("CONFIGURACIÓN:")
println("  N partículas:    $N")
println("  Tiempo total:    $max_time s")
println("  dt_max:          $dt_max")
println("  Semi-ejes (a,b): ($a, $b)")
println("  Radio partícula: $radius")
println("  Parametrización: Polar (φ)")
println()

# ============================================================================
# Crear partículas (con seed para reproducibilidad)
# ============================================================================

println("Creando partículas aleatorias (seed=12345)...")
Random.seed!(12345)

particles = ParticlePolar{Float64}[]
for i in 1:N
    φ = rand() * 2π
    φ_dot = (rand() - 0.5) * 2.0  # Velocidades en [-1, 1]
    push!(particles, ParticlePolar(i, mass, radius, φ, φ_dot, a, b))
end

# Estadísticas iniciales
E_initial = sum(kinetic_energy(p, a, b) for p in particles)
φ_dots_initial = [p.φ_dot for p in particles]

println("  Energía inicial:         ", @sprintf("%.10f", E_initial))
println("  φ̇ promedio:              ", @sprintf("%.6f", mean(φ_dots_initial)))
println("  φ̇ std:                   ", @sprintf("%.6f", std(φ_dots_initial)))
println()

# ============================================================================
# Ejecutar simulación (SIN projection)
# ============================================================================

println("=" ^ 70)
println("EJECUTANDO SIMULACIÓN (sin projection methods)")
println("=" ^ 70)
println()

# Medir tiempo de ejecución
t_start = time()

data = simulate_ellipse_polar_adaptive(
    particles, a, b;
    max_time = max_time,
    dt_max = dt_max,
    dt_min = dt_min,
    save_interval = save_interval,
    collision_method = :parallel_transport,
    use_projection = false,
    verbose = true
)

t_elapsed = time() - t_start

println()
println("Tiempo de ejecución: ", @sprintf("%.2f s", t_elapsed))
println()

# ============================================================================
# Análisis de Resultados
# ============================================================================

println("=" ^ 70)
println("ANÁLISIS DE RESULTADOS")
println("=" ^ 70)
println()

# 1. Conservación de energía
println("1. CONSERVACIÓN DE ENERGÍA")
println("-" ^ 70)
print_conservation_summary_polar(data.conservation)

# 2. Estadísticas de timesteps
println()
println("2. ESTADÍSTICAS DE TIMESTEPS")
println("-" ^ 70)
println("  Total de pasos:    ", length(data.dt_history))
println("  dt promedio:       ", @sprintf("%.2e", mean(data.dt_history)))
println("  dt mínimo:         ", @sprintf("%.2e", minimum(data.dt_history)))
println("  dt máximo:         ", @sprintf("%.2e", maximum(data.dt_history)))
println("  dt std:            ", @sprintf("%.2e", std(data.dt_history)))
println()

# 3. Colisiones
println("3. COLISIONES")
println("-" ^ 70)
total_collisions = sum(data.n_collisions)
collision_rate = total_collisions / max_time

println("  Total colisiones:  ", total_collisions)
println("  Tasa colisión:     ", @sprintf("%.2f colisiones/s", collision_rate))
println()

# 4. Verificar constraint de elipse
println("4. VERIFICACIÓN: Partículas en la Elipse")
println("-" ^ 70)

final_particles = data.particles_history[end]
ellipse_errors = Float64[]

for p in final_particles
    ellipse_eq = (p.pos[1] / a)^2 + (p.pos[2] / b)^2
    error = abs(ellipse_eq - 1.0)
    push!(ellipse_errors, error)
end

max_ellipse_error = maximum(ellipse_errors)
mean_ellipse_error = mean(ellipse_errors)

println("  Error máximo:   ", @sprintf("%.2e", max_ellipse_error))
println("  Error promedio: ", @sprintf("%.2e", mean_ellipse_error))
@printf("  Estado:         ")
println(max_ellipse_error < 1e-10 ? "✅ EXCELENTE" : "⚠️  Revisar")
println()

# 5. Distribución final de velocidades
println("5. DISTRIBUCIÓN FINAL DE VELOCIDADES")
println("-" ^ 70)

φ_dots_final = [p.φ_dot for p in final_particles]
energies_final = [kinetic_energy(p, a, b) for p in final_particles]

println("  φ̇ promedio:     ", @sprintf("%.6f", mean(φ_dots_final)))
println("  φ̇ std:          ", @sprintf("%.6f", std(φ_dots_final)))
println("  E promedio/partícula: ", @sprintf("%.6f", mean(energies_final)))
println()

# 6. Resumen de datos guardados
println("6. DATOS GUARDADOS")
println("-" ^ 70)
println("  Snapshots temporales:  ", length(data.particles_history))
println("  Puntos de tiempo:      ", length(data.times))
println("  Historial de dt:       ", length(data.dt_history))
println()

# ============================================================================
# Resumen Final
# ============================================================================

println("=" ^ 70)
println("RESUMEN FINAL")
println("=" ^ 70)
println()

E_final_error = data.conservation.energy_errors[end]

println("Sistema: 40 partículas, 10 segundos, parametrización polar (φ)")
println()
println("Resultados clave:")
@printf("  ✓ Conservación energía:  ΔE/E₀ = %.2e ", E_final_error)
if E_final_error < 1e-10
    println("(EXCELENTE)")
elseif E_final_error < 1e-6
    println("(BUENO)")
elseif E_final_error < 1e-4
    println("(ACEPTABLE)")
else
    println("(POBRE)")
end

@printf("  ✓ Constraint elipse:     max error = %.2e ", max_ellipse_error)
println(max_ellipse_error < 1e-10 ? "(PERFECTO)" : "(OK)")

println("  ✓ Colisiones totales:    $total_collisions")
println("  ✓ Tiempo de ejecución:   ", @sprintf("%.2f s", t_elapsed))
println()

# Guardamos esta información para comparar luego
println("Guardando resultados para comparación posterior...")

using DelimitedFiles

# Guardar datos clave
results_summary = [
    "parametrization" "polar";
    "N" N;
    "max_time" max_time;
    "total_collisions" total_collisions;
    "E_initial" E_initial;
    "E_final_error_rel" E_final_error;
    "max_ellipse_error" max_ellipse_error;
    "total_steps" length(data.dt_history);
    "execution_time_s" t_elapsed
]

writedlm("results_polar_40p_10s.txt", results_summary)

# Guardar serie temporal de energía
energy_timeseries = hcat(data.conservation.times, data.conservation.energies, data.conservation.energy_errors)
writedlm("energy_polar_40p_10s.csv", energy_timeseries, ',')

println("  ✓ results_polar_40p_10s.txt")
println("  ✓ energy_polar_40p_10s.csv")
println()

println("=" ^ 70)
println("✅ TEST DE PRODUCCIÓN COMPLETADO")
println("=" ^ 70)
println()
println("Próximo paso: Ejecutar con projection methods (Option B)")
println()
