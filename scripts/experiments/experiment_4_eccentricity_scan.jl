#!/usr/bin/env julia
"""
experiment_4_eccentricity_scan.jl

EXPERIMENTO 4: Eccentricity Dependence Study

Test metric volume hypothesis:
- a/b = 1.0 (circle): No clustering expected (uniform metric)
- a/b = 2.0: Strong clustering (current case, σ_φ → 0.014)
- a/b = 3.0: Stronger clustering expected
- a/b = 5.0: Very strong clustering expected

Prediction: Compactification scales with metric variation
"""

using Pkg
Pkg.activate(".")

include("src/simulation_polar.jl")

using Printf
using Random
using Statistics
using DelimitedFiles

println("=" ^ 70)
println("EXPERIMENTO 4: Eccentricity Scan (Metric Volume Test)")
println("=" ^ 70)
println()

# ============================================================================
# Configuration
# ============================================================================

# Test different eccentricities
a_values = [2.0, 2.0, 2.0, 2.0]
b_values = [2.0, 1.0, 2.0/3.0, 2.0/5.0]  # a/b = 1, 2, 3, 5
labels = ["Circle", "Moderate", "High_ecc", "Extreme_ecc"]

N = 40
mass = 1.0
radius = 0.05
max_time = 30.0  # 30s per run
dt_max = 1e-5
dt_min = 1e-10
save_interval = 0.5

println("CONFIGURACIÓN:")
println("  N partículas:    $N")
println("  Tiempo total:    $max_time s por caso")
println("  Save interval:   $save_interval s")
println()

println("CASOS A SIMULAR:")
println("-" ^ 70)
for (i, label) in enumerate(labels)
    a = a_values[i]
    b = b_values[i]
    ratio = a/b
    ecc = b < a ? sqrt(1 - (b/a)^2) : 0.0

    # Metric variation
    g_min = b^2  # Approximation at φ = 0
    g_max = a^2  # Approximation at φ = π/2
    g_ratio = g_max / g_min

    println(@sprintf("%d. %s: a/b = %.2f, e = %.3f, g_max/g_min ≈ %.1f",
                    i, label, ratio, ecc, g_ratio))
end
println()

# ============================================================================
# Run all cases
# ============================================================================

output_dir = "results_experiment_4"
mkpath(output_dir)

results_summary = []

for (case_idx, label) in enumerate(labels)
    a = a_values[case_idx]
    b = b_values[case_idx]
    ratio_ab = a/b

    println("=" ^ 70)
    println("CASO $case_idx/$length(labels): $label (a/b = $(ratio_ab))")
    println("=" ^ 70)
    println()

    # Create particles (same seed for all cases!)
    println("Creando partículas (seed=42)...")
    Random.seed!(42)

    particles = ParticlePolar{Float64}[]
    for i in 1:N
        φ = rand() * 2π
        φ_dot = (rand() - 0.5) * 2.0
        push!(particles, ParticlePolar(i, mass, radius, φ, φ_dot, a, b))
    end

    E_initial = sum(kinetic_energy(p, a, b) for p in particles)
    println("  Energía inicial: ", @sprintf("%.6f", E_initial))

    # Initial dispersion
    φ_initial = [p.φ for p in particles]
    σ_φ_initial = std(φ_initial)
    println("  σ_φ inicial:     ", @sprintf("%.6f rad", σ_φ_initial))
    println()

    # Run simulation
    println("Ejecutando simulación ($max_time s)...")
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
        verbose = false  # Quiet for batch run
    )

    t_elapsed = time() - t_start

    println("  Completado en: ", @sprintf("%.2f s", t_elapsed))
    println()

    # Analyze results
    final_particles = data.particles_history[end]
    φ_final = [p.φ for p in final_particles]
    σ_φ_final = std(φ_final)
    mean_φ_final = mean(φ_final)

    compactification_ratio = σ_φ_final / σ_φ_initial

    # Energy conservation
    E_final = sum(kinetic_energy(p, a, b) for p in final_particles)
    ΔE_rel = abs(E_final - E_initial) / E_initial

    # Collision count
    total_collisions = sum(data.n_collisions)

    println("RESULTADOS:")
    println("  σ_φ final:       ", @sprintf("%.6f rad", σ_φ_final))
    println("  Compactification:", @sprintf("%.4f", compactification_ratio))
    println("  mean_φ final:    ", @sprintf("%.3f rad (%.1f°)", mean_φ_final, rad2deg(mean_φ_final)))
    println("  ΔE/E₀:           ", @sprintf("%.2e", ΔE_rel))
    println("  Colisiones:      ", total_collisions)
    println()

    # Save individual case data
    case_dir = joinpath(output_dir, label)
    mkpath(case_dir)

    # Phase space evolution
    times = data.times
    σ_φ_history = [std([p.φ for p in snapshot]) for snapshot in data.particles_history]
    mean_φ_history = [mean([p.φ for p in snapshot]) for snapshot in data.particles_history]

    phase_evolution = hcat(times, σ_φ_history, mean_φ_history)
    writedlm(joinpath(case_dir, "phase_evolution.csv"), phase_evolution, ',')

    # Final positions
    final_positions = hcat(φ_final, [p.φ_dot for p in final_particles])
    writedlm(joinpath(case_dir, "final_phase_space.csv"), final_positions, ',')

    # Store summary
    push!(results_summary, (
        label = label,
        a_over_b = ratio_ab,
        eccentricity = b < a ? sqrt(1 - (b/a)^2) : 0.0,
        σ_φ_initial = σ_φ_initial,
        σ_φ_final = σ_φ_final,
        compactification = compactification_ratio,
        mean_φ_final = mean_φ_final,
        ΔE_rel = ΔE_rel,
        collisions = total_collisions,
        time_elapsed = t_elapsed
    ))

    println()
end

# ============================================================================
# Comparative Analysis
# ============================================================================

println("=" ^ 70)
println("ANÁLISIS COMPARATIVO")
println("=" ^ 70)
println()

println("Resumen de Compactificación:")
println("-" ^ 70)
println(@sprintf("%-15s  %6s  %6s  %10s  %10s",
                "Caso", "a/b", "e", "σ_φ_final", "Ratio"))
println("-" ^ 70)

for r in results_summary
    println(@sprintf("%-15s  %6.2f  %6.3f  %10.6f  %10.4f",
                    r.label, r.a_over_b, r.eccentricity, r.σ_φ_final, r.compactification))
end

println()

# Test hypothesis: compactification should increase with eccentricity
compactifications = [r.compactification for r in results_summary]
eccentricities = [r.eccentricity for r in results_summary]

println("HIPÓTESIS: Clustering aumenta con excentricidad")
println("-" ^ 70)

# Check if compactification decreases with eccentricity
if eccentricities[1] < eccentricities[end]  # Sorted by eccentricity?
    if compactifications[1] > compactifications[end]
        println("  ✅ CONFIRMADO: Mayor eccentricidad → mayor clustering")
        println("     (menor compactification ratio)")
    else
        println("  ❌ NO confirmado: Tendencia opuesta o no clara")
    end
else
    # Need to check correlation
    if length(unique(eccentricities)) > 1
        # Simple trend check
        trend_increasing = all(compactifications[i] >= compactifications[i-1]
                              for i in 2:length(compactifications)
                              if eccentricities[i] < eccentricities[i-1])

        if !trend_increasing
            println("  ✅ CONFIRMADO: Mayor eccentricidad → mayor clustering")
        else
            println("  ❌ NO confirmado")
        end
    end
end

println()

# Cluster location analysis
println("Ubicación Final del Cluster:")
println("-" ^ 70)

for r in results_summary
    φ_deg = rad2deg(mod(r.mean_φ_final, 2π))
    sector = if 45 <= φ_deg < 135
        "Near φ=π/2 (low κ, large metric) ✅"
    elseif φ_deg < 45 || φ_deg >= 315
        "Near φ=0 (high κ, small metric)"
    elseif 135 <= φ_deg < 225
        "Near φ=π (high κ, small metric)"
    else
        "Near φ=3π/2 (low κ, large metric) ✅"
    end

    println(@sprintf("  %-15s: φ = %5.1f°  → %s",
                    r.label, φ_deg, sector))
end

println()

# Save summary table
open(joinpath(output_dir, "summary.txt"), "w") do io
    println(io, "Experiment 4: Eccentricity Scan")
    println(io, "=" ^ 70)
    println(io)
    println(io, @sprintf("%-15s  %6s  %6s  %10s  %10s  %10s",
                        "Caso", "a/b", "e", "σ_φ_final", "Compact", "mean_φ"))
    println(io, "-" ^ 70)

    for r in results_summary
        println(io, @sprintf("%-15s  %6.2f  %6.3f  %10.6f  %10.4f  %10.3f",
                            r.label, r.a_over_b, r.eccentricity,
                            r.σ_φ_final, r.compactification, r.mean_φ_final))
    end

    println(io)
    println(io, "Conservation:")
    for r in results_summary
        println(io, @sprintf("  %-15s: ΔE/E₀ = %.2e", r.label, r.ΔE_rel))
    end

    println(io)
    println(io, "Colisiones:")
    for r in results_summary
        println(io, @sprintf("  %-15s: %d", r.label, r.collisions))
    end
end

# Save CSV for plotting
summary_csv = hcat(
    [r.a_over_b for r in results_summary],
    [r.eccentricity for r in results_summary],
    [r.compactification for r in results_summary],
    [r.σ_φ_final for r in results_summary],
    [r.mean_φ_final for r in results_summary],
    [r.ΔE_rel for r in results_summary],
    [r.collisions for r in results_summary]
)

writedlm(joinpath(output_dir, "summary.csv"),
         vcat(["a/b" "e" "compact_ratio" "sigma_phi_final" "mean_phi" "dE_rel" "collisions"],
              summary_csv), ',')

println("=" ^ 70)
println("✅ EXPERIMENTO 4 COMPLETADO")
println("=" ^ 70)
println()

println("Resultados guardados en: $output_dir/")
println()
println("Archivos generados:")
println("  - summary.txt         (tabla resumen)")
println("  - summary.csv         (datos para plotting)")
println("  - */phase_evolution.csv (evolución temporal por caso)")
println("  - */final_phase_space.csv (estado final por caso)")
println()

println("CONCLUSIÓN:")
if compactifications[1] > compactifications[end] * 1.5
    println("  La hipótesis del volumen métrico es APOYADA:")
    println("  → Mayor excentricidad → mayor variación de métrica → mayor clustering")
elseif compactifications[1] > compactifications[end]
    println("  Tendencia compatible con hipótesis de volumen métrico (moderada)")
else
    println("  Resultados requieren análisis adicional")
end

println()
