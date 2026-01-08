#!/usr/bin/env julia
"""
test_polar_projection.jl

Test de producción con PROJECTION METHODS:
40 partículas, 10 segundos, con corrección de energía cada 100 pasos.

Objetivo: ΔE/E₀ < 1e-10
"""

using Pkg
Pkg.activate(".")

include("src/simulation_polar.jl")

using Printf
using Random
using Statistics

println("=" ^ 70)
println("TEST CON PROJECTION METHODS: Coordenadas Polares φ")
println("=" ^ 70)
println()

# ============================================================================
# Configuración (idéntica a test sin projection)
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

# Projection methods
use_projection = true
projection_interval = 100
projection_tolerance = 1e-12

println("CONFIGURACIÓN:")
println("  N partículas:      $N")
println("  Tiempo total:      $max_time s")
println("  dt_max:            $dt_max")
println("  Semi-ejes (a,b):   ($a, $b)")
println("  Parametrización:   Polar (φ)")
println()
println("PROJECTION METHODS:")
println("  Activado:          SÍ")
println("  Intervalo:         Cada $projection_interval pasos")
println("  Tolerancia:        $projection_tolerance")
println()

# ============================================================================
# Crear MISMAS partículas (mismo seed)
# ============================================================================

println("Creando partículas (seed=12345, idéntico a test sin projection)...")
Random.seed!(12345)

particles = ParticlePolar{Float64}[]
for i in 1:N
    φ = rand() * 2π
    φ_dot = (rand() - 0.5) * 2.0
    push!(particles, ParticlePolar(i, mass, radius, φ, φ_dot, a, b))
end

E_initial = sum(kinetic_energy(p, a, b) for p in particles)
println("  Energía inicial: ", @sprintf("%.10f", E_initial))
println("  (debe coincidir con test sin projection)")
println()

# ============================================================================
# Ejecutar simulación CON projection
# ============================================================================

println("=" ^ 70)
println("EJECUTANDO SIMULACIÓN (CON PROJECTION METHODS)")
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
    use_projection = use_projection,
    projection_interval = projection_interval,
    projection_tolerance = projection_tolerance,
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
println("ANÁLISIS DE RESULTADOS (CON PROJECTION)")
println("=" ^ 70)
println()

# 1. Conservación de energía
println("1. CONSERVACIÓN DE ENERGÍA")
println("-" ^ 70)
print_conservation_summary_polar(data.conservation)

# 2. Comparar con resultado sin projection
println()
println("2. COMPARACIÓN: Sin Projection vs Con Projection")
println("-" ^ 70)

# Valores del test anterior (hardcoded para comparación)
E_error_without_projection = 3.19e-04
E_error_with_projection = data.conservation.energy_errors[end]

println("  Sin projection:  ΔE/E₀ = ", @sprintf("%.2e", E_error_without_projection))
println("  Con projection:  ΔE/E₀ = ", @sprintf("%.2e", E_error_with_projection))

improvement_factor = E_error_without_projection / E_error_with_projection
println("  Mejora:          ", @sprintf("%.1fx mejor", improvement_factor))
println()

# 3. Verificar que projection no rompió el constraint
println("3. VERIFICACIÓN: Constraint de Elipse")
println("-" ^ 70)

final_particles = data.particles_history[end]
ellipse_errors = Float64[]

for p in final_particles
    ellipse_eq = (p.pos[1] / a)^2 + (p.pos[2] / b)^2
    error = abs(ellipse_eq - 1.0)
    push!(ellipse_errors, error)
end

max_ellipse_error = maximum(ellipse_errors)

println("  Error máximo:   ", @sprintf("%.2e", max_ellipse_error))
@printf("  Estado:         ")
println(max_ellipse_error < 1e-10 ? "✅ PERFECTO" : "⚠️  Revisar")
println()

# 4. Colisiones
println("4. COLISIONES")
println("-" ^ 70)
total_collisions = sum(data.n_collisions)
println("  Total colisiones:  ", total_collisions)
println("  (debe ser similar al test sin projection)")
println()

# ============================================================================
# Resumen Final
# ============================================================================

println("=" ^ 70)
println("RESUMEN FINAL: PROJECTION METHODS")
println("=" ^ 70)
println()

E_final_error = data.conservation.energy_errors[end]

println("Comparación directa (mismas condiciones iniciales):")
println()
println("┌────────────────────────────┬─────────────────┬─────────────────┐")
println("│ Métrica                    │ Sin Projection  │ Con Projection  │")
println("├────────────────────────────┼─────────────────┼─────────────────┤")
@printf("│ ΔE/E₀ final                │ %.2e        │ %.2e        │\n",
        E_error_without_projection, E_final_error)
println("│ Colisiones                 │ 2321            │ ", @sprintf("%-15d", total_collisions), " │")
println("│ Pasos totales              │ ~1,001,000      │ ", @sprintf("%-15d", length(data.dt_history)), " │")
@printf("│ Tiempo ejecución (s)       │ 44.0            │ %-15.1f │\n", t_elapsed)
println("└────────────────────────────┴─────────────────┴─────────────────┘")
println()

# Clasificación de conservación
@printf("Conservación de energía: ΔE/E₀ = %.2e ", E_final_error)
if E_final_error < 1e-10
    println("✅ EXCELENTE (objetivo alcanzado!)")
elseif E_final_error < 1e-6
    println("✅ MUY BUENO")
elseif E_final_error < 1e-4
    println("⚠️  ACEPTABLE")
else
    println("❌ POBRE (projection no funcionó)")
end

println()
println("=" ^ 70)
println("✅ TEST CON PROJECTION COMPLETADO")
println("=" ^ 70)
println()

if E_final_error < 1e-10
    println("🎉 PROJECTION METHODS FUNCIONAN PERFECTAMENTE!")
    println()
    println("El sistema polar φ conserva energía a nivel de máquina (< 1e-10)")
    println("con projection methods cada $projection_interval pasos.")
else
    println("⚠️  Projection methods mejoraron conservación pero no alcanzaron")
    println("el objetivo de ΔE/E₀ < 1e-10. Revisar implementación.")
end
println()
