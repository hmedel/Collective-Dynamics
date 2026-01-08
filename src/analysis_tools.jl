"""
    analysis_tools.jl

Herramientas de análisis para investigación científica en coordenadas polares.
"""

using Statistics
using DelimitedFiles
using Printf

include("particles_polar.jl")
include("geometry/metrics_polar.jl")

# ============================================================================
# Análisis de Espacio Fase
# ============================================================================

"""
    analyze_phase_space_evolution(data, output_file)

Analiza la evolución del espacio fase (φ, φ̇) durante la simulación.

# Retorna
- Dispersión σ_φ, σ_φ̇ vs tiempo
- Compactification metrics
"""
function analyze_phase_space_evolution(data, output_file="phase_space_evolution.csv")
    times = data.times
    n_snapshots = length(times)

    # Preallocate
    σ_φ = zeros(n_snapshots)
    σ_φ_dot = zeros(n_snapshots)
    mean_φ = zeros(n_snapshots)
    mean_φ_dot = zeros(n_snapshots)

    for (i, snapshot) in enumerate(data.particles_history)
        φ_values = [p.φ for p in snapshot]
        φ_dot_values = [p.φ_dot for p in snapshot]

        mean_φ[i] = mean(φ_values)
        mean_φ_dot[i] = mean(φ_dot_values)
        σ_φ[i] = std(φ_values)
        σ_φ_dot[i] = std(φ_dot_values)
    end

    # Guardar
    results = hcat(times, mean_φ, σ_φ, mean_φ_dot, σ_φ_dot)
    writedlm(output_file, results, ',')

    println("Análisis de espacio fase guardado en: $output_file")
    println()
    println("Resultados:")
    println("  σ_φ inicial:     ", @sprintf("%.6f", σ_φ[1]))
    println("  σ_φ final:       ", @sprintf("%.6f", σ_φ[end]))
    println("  σ_φ_dot inicial: ", @sprintf("%.6f", σ_φ_dot[1]))
    println("  σ_φ_dot final:   ", @sprintf("%.6f", σ_φ_dot[end]))
    println()

    # Compactification ratio
    compactification_φ = σ_φ[end] / σ_φ[1]
    compactification_φ_dot = σ_φ_dot[end] / σ_φ_dot[1]

    println("Compactification ratios:")
    println("  φ:     ", @sprintf("%.3f", compactification_φ))
    println("  φ̇:     ", @sprintf("%.3f", compactification_φ_dot))
    println()

    return (times=times, σ_φ=σ_φ, σ_φ_dot=σ_φ_dot,
            mean_φ=mean_φ, mean_φ_dot=mean_φ_dot)
end

# ============================================================================
# Análisis de Curvatura
# ============================================================================

"""
    analyze_curvature_correlation(data, a, b, n_bins=16, output_file="curvature_correlation.csv")

Analiza correlación entre densidad de partículas y curvatura κ(φ).

# Retorna
- Densidad ρ(φ) vs curvatura κ(φ) por bin
"""
function analyze_curvature_correlation(data, a, b, n_bins=16, output_file="curvature_correlation.csv")
    # Usar snapshot final
    final_snapshot = data.particles_history[end]

    # Dividir φ ∈ [0, 2π] en n_bins
    φ_bins = range(0, 2π, length=n_bins+1)
    bin_centers = [(φ_bins[i] + φ_bins[i+1])/2 for i in 1:n_bins]

    # Contar partículas por bin
    counts = zeros(Int, n_bins)

    for p in final_snapshot
        φ_normalized = mod(p.φ, 2π)
        bin_idx = searchsortedfirst(φ_bins, φ_normalized)
        bin_idx = min(bin_idx, n_bins)  # Safety
        if bin_idx > 0
            counts[bin_idx] += 1
        end
    end

    # Calcular curvatura en cada bin center
    curvatures = [curvature_ellipse_polar(φ, a, b) for φ in bin_centers]

    # Densidad (normalizada)
    total_particles = length(final_snapshot)
    densities = counts ./ total_particles

    # Guardar
    results = hcat(bin_centers, curvatures, densities, counts)
    writedlm(output_file, results, ',')

    println("Análisis de correlación curvatura guardado en: $output_file")
    println()

    # Calcular correlación de Pearson
    correlation = cor(curvatures, densities)
    println("Correlación ρ(φ) vs κ(φ): ", @sprintf("%.4f", correlation))

    if abs(correlation) > 0.5
        println("  → FUERTE correlación!")
    elseif abs(correlation) > 0.3
        println("  → Correlación moderada")
    else
        println("  → Correlación débil/ninguna")
    end
    println()

    return (bin_centers=bin_centers, curvatures=curvatures,
            densities=densities, counts=counts, correlation=correlation)
end

# ============================================================================
# Análisis de Termalización
# ============================================================================

"""
    analyze_thermalization(data, a, b, output_file="thermalization.csv")

Estudia redistribución de energía entre partículas.

# Retorna
- Varianza de energía σ²_E vs tiempo
- Distribución de energías inicial vs final
"""
function analyze_thermalization(data, a, b, output_file="thermalization.csv")
    times = data.times
    n_snapshots = length(times)

    # Para cada snapshot, calcular distribución de energías
    E_means = zeros(n_snapshots)
    E_stds = zeros(n_snapshots)
    E_mins = zeros(n_snapshots)
    E_maxs = zeros(n_snapshots)

    for (i, snapshot) in enumerate(data.particles_history)
        energies = [kinetic_energy(p, a, b) for p in snapshot]

        E_means[i] = mean(energies)
        E_stds[i] = std(energies)
        E_mins[i] = minimum(energies)
        E_maxs[i] = maximum(energies)
    end

    # Guardar
    results = hcat(times, E_means, E_stds, E_mins, E_maxs)
    writedlm(output_file, results, ',')

    println("Análisis de termalización guardado en: $output_file")
    println()

    println("Dispersión de energía:")
    println("  σ_E inicial: ", @sprintf("%.6f", E_stds[1]))
    println("  σ_E final:   ", @sprintf("%.6f", E_stds[end]))

    thermalization_ratio = E_stds[end] / E_stds[1]
    println("  Ratio:       ", @sprintf("%.3f", thermalization_ratio))

    if thermalization_ratio > 1.2
        println("  → Sistema se TERMALIZÓ (dispersión aumentó)")
    elseif thermalization_ratio < 0.8
        println("  → Energías se COMPACTARON")
    else
        println("  → Distribución similar")
    end
    println()

    # Estimar tiempo de termalización (cuando σ_E se estabiliza)
    # Criterio: primera vez que |dσ_E/dt| < threshold
    threshold = 0.01 * E_stds[1] / times[end]  # 1% per unit time

    τ_relax = nothing
    for i in 2:(n_snapshots-1)
        dσ_dt = abs(E_stds[i+1] - E_stds[i]) / (times[i+1] - times[i])
        if dσ_dt < threshold && i > 10  # Skip initial transient
            τ_relax = times[i]
            break
        end
    end

    if !isnothing(τ_relax)
        println("Tiempo de relajación estimado: τ ≈ ", @sprintf("%.2f s", τ_relax))
    else
        println("Tiempo de relajación: τ > ", @sprintf("%.2f s", times[end]))
    end
    println()

    return (times=times, E_means=E_means, E_stds=E_stds,
            E_mins=E_mins, E_maxs=E_maxs, τ_relax=τ_relax)
end

# ============================================================================
# Estadísticas de Colisiones
# ============================================================================

"""
    analyze_collision_statistics(data, output_file="collision_stats.csv")

Analiza frecuencia y distribución temporal de colisiones.

# Retorna
- Tasa de colisión vs tiempo
- Estadísticas acumulativas
"""
function analyze_collision_statistics(data, output_file="collision_stats.csv")
    # Calcular tasa de colisión en ventanas deslizantes
    window_size = 100  # Promediar sobre 100 snapshots

    times = data.times
    n_snapshots = length(times)

    # Acumular colisiones
    cumulative_collisions = cumsum(data.n_collisions)

    # Calcular tasa en ventanas
    collision_rates = zeros(n_snapshots - window_size)
    time_centers = zeros(n_snapshots - window_size)

    for i in 1:(n_snapshots - window_size)
        t_start = times[i]
        t_end = times[i + window_size]
        Δt = t_end - t_start

        coll_start = i > 1 ? cumulative_collisions[i-1] : 0
        coll_end = cumulative_collisions[i + window_size]
        Δcoll = coll_end - coll_start

        collision_rates[i] = Δcoll / Δt
        time_centers[i] = (t_start + t_end) / 2
    end

    # Guardar
    results = hcat(time_centers, collision_rates)
    writedlm(output_file, results, ',')

    println("Estadísticas de colisiones guardadas en: $output_file")
    println()

    total_collisions = cumulative_collisions[end]
    total_time = times[end]
    avg_rate = total_collisions / total_time

    println("Colisiones:")
    println("  Total:        $total_collisions")
    println("  Tasa promedio:", @sprintf("%.2f/s", avg_rate))
    println("  Tasa inicial: ", @sprintf("%.2f/s", collision_rates[1]))
    println("  Tasa final:   ", @sprintf("%.2f/s", collision_rates[end]))
    println()

    return (time_centers=time_centers, collision_rates=collision_rates,
            total_collisions=total_collisions, avg_rate=avg_rate)
end

# ============================================================================
# Análisis Completo
# ============================================================================

"""
    run_complete_analysis(data, a, b, output_dir="analysis_results")

Ejecuta todos los análisis y guarda resultados.
"""
function run_complete_analysis(data, a, b, output_dir="analysis_results")
    mkpath(output_dir)

    println("=" ^ 70)
    println("ANÁLISIS COMPLETO DEL SISTEMA")
    println("=" ^ 70)
    println()

    # 1. Espacio fase
    println("1. Analizando espacio fase...")
    println("-" ^ 70)
    phase_results = analyze_phase_space_evolution(
        data,
        joinpath(output_dir, "phase_space_evolution.csv")
    )

    # 2. Curvatura
    println("2. Analizando correlación con curvatura...")
    println("-" ^ 70)
    curv_results = analyze_curvature_correlation(
        data, a, b,
        16,  # 16 bins
        joinpath(output_dir, "curvature_correlation.csv")
    )

    # 3. Termalización
    println("3. Analizando termalización...")
    println("-" ^ 70)
    therm_results = analyze_thermalization(
        data, a, b,
        joinpath(output_dir, "thermalization.csv")
    )

    # 4. Colisiones
    println("4. Analizando colisiones...")
    println("-" ^ 70)
    coll_results = analyze_collision_statistics(
        data,
        joinpath(output_dir, "collision_stats.csv")
    )

    println("=" ^ 70)
    println("✅ ANÁLISIS COMPLETO TERMINADO")
    println("=" ^ 70)
    println()
    println("Todos los resultados guardados en: $output_dir/")
    println()

    return (phase=phase_results, curvature=curv_results,
            thermalization=therm_results, collisions=coll_results)
end
