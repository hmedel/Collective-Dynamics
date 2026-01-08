#!/usr/bin/env julia
"""
experiment_1_long_time.jl

EXPERIMENTO 1: Simulación de Tiempo Largo (100 segundos)

Objetivo: Verificar conservación y estabilidad numérica a largo plazo
Pregunta: ¿Se mantiene ΔE/E₀ < 10⁻⁸ después de ~20,000 colisiones?
"""

using Pkg
Pkg.activate(".")

include("src/simulation_polar.jl")

using Printf
using Random
using Statistics
using DelimitedFiles

println("=" ^ 70)
println("EXPERIMENTO 1: Simulación de Tiempo Largo")
println("=" ^ 70)
println()

# ============================================================================
# Configuración
# ============================================================================

a, b = 2.0, 1.0
N = 40
mass = 1.0
radius = 0.05
max_time = 100.0  # ← 10x más largo que tests anteriores
dt_max = 1e-5
dt_min = 1e-10
save_interval = 0.1  # Guardar cada 0.1s (1000 snapshots)

println("PARÁMETROS:")
println("  N partículas:    $N")
println("  Tiempo total:    $max_time s (10x más largo)")
println("  dt_max:          $dt_max")
println("  Save interval:   $save_interval s")
println("  Semi-ejes:       a=$a, b=$b")
println("  Projection:      Activado (cada 100 pasos)")
println()

println("ESTIMACIONES:")
expected_collisions = 2_300 * 10  # Extrapolando desde 10s
expected_time = 46.7 * 10  # Extrapolando desde 10s (φ)
println("  Colisiones esperadas: ~$(expected_collisions)")
println("  Tiempo esperado:      ~$(expected_time) s (~$(expected_time/60) min)")
println()

# ============================================================================
# Crear partículas (seed para reproducibilidad)
# ============================================================================

println("Creando partículas (seed=42)...")
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
# Ejecutar simulación
# ============================================================================

println("=" ^ 70)
println("EJECUTANDO SIMULACIÓN (esto tomará ~7-8 minutos)")
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

# Gráfica de ΔE/E₀ vs tiempo
E_errors = data.conservation.energy_errors
times = data.conservation.times

println()
println("Evolución temporal:")
println("  t=0s:     ΔE/E₀ = ", @sprintf("%.2e", E_errors[1]))
println("  t=10s:    ΔE/E₀ = ", @sprintf("%.2e", E_errors[101]))  # ~100 snapshots
println("  t=50s:    ΔE/E₀ = ", @sprintf("%.2e", E_errors[501]))
println("  t=100s:   ΔE/E₀ = ", @sprintf("%.2e", E_errors[end]))
println()

# 2. Colisiones
println("2. ESTADÍSTICAS DE COLISIONES")
println("-" ^ 70)

total_collisions = sum(data.n_collisions)
collision_rate = total_collisions / max_time

println("  Total colisiones:  ", total_collisions)
println("  Tasa promedio:     ", @sprintf("%.2f colisiones/s", collision_rate))
println()

# Evolución de tasa de colisiones
println("  Tasa en diferentes intervalos:")
# Dividir en 10 intervalos de 10s cada uno
for i in 1:10
    t_start_interval = (i-1) * 10.0
    t_end_interval = i * 10.0

    # Encontrar índices correspondientes
    idx_start = findfirst(t -> t >= t_start_interval, times)
    idx_end = findfirst(t -> t >= t_end_interval, times)

    if !isnothing(idx_start) && !isnothing(idx_end)
        step_start = sum(data.n_collisions[1:idx_start])
        step_end = sum(data.n_collisions[1:idx_end])
        colls_interval = step_end - step_start
        rate_interval = colls_interval / 10.0

        println(@sprintf("    [%3.0f-%3.0fs]: %4d colisiones (%.1f/s)",
                        t_start_interval, t_end_interval, colls_interval, rate_interval))
    end
end
println()

# 3. Timesteps
println("3. ESTADÍSTICAS DE TIMESTEPS")
println("-" ^ 70)

println("  Total pasos:    ", length(data.dt_history))
println("  dt promedio:    ", @sprintf("%.2e", mean(data.dt_history)))
println("  dt mínimo:      ", @sprintf("%.2e", minimum(data.dt_history)))
println("  dt máximo:      ", @sprintf("%.2e", maximum(data.dt_history)))
println("  dt std:         ", @sprintf("%.2e", std(data.dt_history)))
println()

# 4. Constraint de elipse
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

# 5. Distribución de energías individuales
println("5. DISTRIBUCIÓN DE ENERGÍAS (Termalización)")
println("-" ^ 70)

# Inicial
initial_energies = [kinetic_energy(p, a, b) for p in data.particles_history[1]]
E_mean_initial = mean(initial_energies)
E_std_initial = std(initial_energies)

# Final
final_energies = [kinetic_energy(p, a, b) for p in final_particles]
E_mean_final = mean(final_energies)
E_std_final = std(final_energies)

println("  Energía por partícula:")
println("    Inicial: μ=", @sprintf("%.6f", E_mean_initial), ", σ=", @sprintf("%.6f", E_std_initial))
println("    Final:   μ=", @sprintf("%.6f", E_mean_final), ", σ=", @sprintf("%.6f", E_std_final))
println()

# Ratio de dispersión (medida de termalización)
thermalization_ratio = E_std_final / E_std_initial
println("  Ratio σ_final/σ_initial: ", @sprintf("%.3f", thermalization_ratio))
if thermalization_ratio > 1.2
    println("  → Energías se DISPERSARON (termalización)")
elseif thermalization_ratio < 0.8
    println("  → Energías se COMPACTARON")
else
    println("  → Distribución similar")
end
println()

# 6. Distribución espacial
println("6. DISTRIBUCIÓN ESPACIAL")
println("-" ^ 70)

# Dividir elipse en 8 sectores
n_sectors = 8
sector_counts = zeros(Int, n_sectors)

for p in final_particles
    # φ ∈ [0, 2π]
    φ_normalized = mod(p.φ, 2π)
    sector = floor(Int, φ_normalized / (2π / n_sectors)) + 1
    sector = min(sector, n_sectors)  # Safety
    sector_counts[sector] += 1
end

println("  Partículas por sector (φ):")
for i in 1:n_sectors
    φ_start = (i-1) * (2π / n_sectors)
    φ_end = i * (2π / n_sectors)
    println(@sprintf("    Sector %d [%.2f-%.2f]: %2d partículas",
                    i, φ_start, φ_end, sector_counts[i]))
end

# Uniformidad (ideal: 40/8 = 5 por sector)
expected_per_sector = N / n_sectors
chi_squared = sum((sector_counts .- expected_per_sector).^2 ./ expected_per_sector)
println()
println("  Test χ²: ", @sprintf("%.3f", chi_squared))
println("  (χ² < 14.1 para distribución uniforme a 95% confianza)")
println()

# ============================================================================
# Guardar Datos
# ============================================================================

println("=" ^ 70)
println("GUARDANDO DATOS")
println("=" ^ 70)
println()

# Crear directorio de resultados
results_dir = "results_experiment_1"
mkpath(results_dir)

# 1. Serie temporal de energía
energy_data = hcat(times, data.conservation.energies, E_errors)
writedlm(joinpath(results_dir, "energy_vs_time.csv"), energy_data, ',')
println("  ✓ energy_vs_time.csv")

# 2. Historial de timesteps
writedlm(joinpath(results_dir, "dt_history.csv"), data.dt_history, ',')
println("  ✓ dt_history.csv")

# 3. Estadísticas de colisiones por intervalo
collision_stats = zeros(10, 3)  # [t_start, t_end, n_collisions]
for i in 1:10
    collision_stats[i, 1] = (i-1) * 10.0
    collision_stats[i, 2] = i * 10.0

    idx_start = findfirst(t -> t >= collision_stats[i,1], times)
    idx_end = findfirst(t -> t >= collision_stats[i,2], times)

    if !isnothing(idx_start) && !isnothing(idx_end)
        collision_stats[i, 3] = sum(data.n_collisions[1:idx_end]) - sum(data.n_collisions[1:idx_start])
    end
end
writedlm(joinpath(results_dir, "collisions_by_interval.csv"), collision_stats, ',')
println("  ✓ collisions_by_interval.csv")

# 4. Distribución final de energías
writedlm(joinpath(results_dir, "final_energies.csv"), final_energies, ',')
println("  ✓ final_energies.csv")

# 5. Distribución espacial final
final_positions = hcat([p.φ for p in final_particles], [p.φ_dot for p in final_particles])
writedlm(joinpath(results_dir, "final_phase_space.csv"), final_positions, ',')
println("  ✓ final_phase_space.csv")

# 6. Resumen
summary_file = joinpath(results_dir, "summary.txt")
open(summary_file, "w") do io
    println(io, "Experimento 1: Simulación de Tiempo Largo (100s)")
    println(io, "=" ^ 70)
    println(io)
    println(io, "Parámetros:")
    println(io, "  N = $N")
    println(io, "  max_time = $max_time s")
    println(io, "  a, b = $a, $b")
    println(io)
    println(io, "Resultados:")
    println(io, "  Energía inicial:      ", @sprintf("%.10f", E_initial))
    println(io, "  ΔE/E₀ final:          ", @sprintf("%.2e", E_errors[end]))
    println(io, "  Colisiones totales:   $total_collisions")
    println(io, "  Pasos totales:        ", length(data.dt_history))
    println(io, "  Tiempo ejecución:     ", @sprintf("%.2f s", t_elapsed))
    println(io, "  Max ellipse error:    ", @sprintf("%.2e", max_ellipse_error))
    println(io)
    println(io, "Termalización:")
    println(io, "  σ_E inicial: ", @sprintf("%.6f", E_std_initial))
    println(io, "  σ_E final:   ", @sprintf("%.6f", E_std_final))
    println(io, "  Ratio:       ", @sprintf("%.3f", thermalization_ratio))
end
println("  ✓ summary.txt")
println()

# ============================================================================
# Resumen Final
# ============================================================================

println("=" ^ 70)
println("RESUMEN: EXPERIMENTO 1")
println("=" ^ 70)
println()

println("Simulación de 100 segundos completada exitosamente!")
println()

println("Conservación de energía:")
@printf("  ΔE/E₀ = %.2e ", E_errors[end])
if E_errors[end] < 1e-10
    println("✅ EXCELENTE")
elseif E_errors[end] < 1e-8
    println("✅ MUY BUENO")
elseif E_errors[end] < 1e-6
    println("✅ BUENO")
else
    println("⚠️  REVISAR")
end

println()
println("Colisiones:")
println("  Total: $total_collisions (", @sprintf("%.1f/s", collision_rate), ")")

println()
println("Performance:")
println("  Tiempo real: ", @sprintf("%.2f s (%.2f min)", t_elapsed, t_elapsed/60))

println()
println("Datos guardados en: $results_dir/")

println()
println("=" ^ 70)
println("✅ EXPERIMENTO 1 COMPLETADO")
println("=" ^ 70)
println()

println("Próximos pasos:")
println("  1. Analizar energy_vs_time.csv (plot ΔE/E₀ vs t)")
println("  2. Verificar estabilidad de tasa de colisiones")
println("  3. Proceder a Experimento 2 (análisis de espacio fase)")
println()
