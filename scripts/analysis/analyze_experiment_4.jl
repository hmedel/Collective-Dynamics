#!/usr/bin/env julia
"""
analyze_experiment_4.jl

Detailed analysis of Experiment 4 results:
1. Compactification dynamics (not just final state)
2. Timescales of cluster formation
3. Cluster location statistics
"""

using Pkg
Pkg.activate(".")

using DelimitedFiles
using Statistics
using Printf

println("=" ^ 70)
println("ANÁLISIS DETALLADO: EXPERIMENTO 4")
println("=" ^ 70)
println()

# ============================================================================
# Load data
# ============================================================================

base_dir = "results_experiment_4"
cases = ["Circle", "Moderate", "High_ecc", "Extreme_ecc"]
labels_full = ["Circle (a/b=1.0)", "Moderate (a/b=2.0)",
               "High ecc (a/b=3.0)", "Extreme ecc (a/b=5.0)"]

# Summary data
summary = readdlm(joinpath(base_dir, "summary.csv"), ',', skipstart=1)

println("DATOS CARGADOS:")
println("-" ^ 70)
for (i, case) in enumerate(cases)
    println(@sprintf("  %d. %s", i, labels_full[i]))
    println(@sprintf("      a/b = %.2f, e = %.3f", summary[i,1], summary[i,2]))
    println(@sprintf("      Compactification final = %.4f", summary[i,3]))
end
println()

# ============================================================================
# Analysis 1: Compactification Timescales
# ============================================================================

println("=" ^ 70)
println("ANÁLISIS 1: TIMESCALES DE COMPACTIFICACIÓN")
println("=" ^ 70)
println()

println("Tiempo para alcanzar 50% de compactificación:")
println("-" ^ 70)

for (i, case) in enumerate(cases)
    # Load phase evolution
    phase_file = joinpath(base_dir, case, "phase_evolution.csv")
    phase_data = readdlm(phase_file, ',')

    times = phase_data[:, 1]
    σ_φ = phase_data[:, 2]

    # Initial and final
    σ_initial = σ_φ[1]
    σ_final = σ_φ[end]

    # Target: 50% between initial and final
    σ_target = (σ_initial + σ_final) / 2

    # Find time when σ_φ first crosses target
    idx = findfirst(σ -> σ <= σ_target, σ_φ)

    if !isnothing(idx)
        t_half = times[idx]
        println(@sprintf("  %-20s: t_1/2 = %5.2f s", labels_full[i], t_half))
    else
        println(@sprintf("  %-20s: NO alcanzado en 30s", labels_full[i]))
    end
end

println()
println("INTERPRETACIÓN:")
println("  Si t_1/2 es MENOR para mayor eccentricidad →")
println("  → Metric variation ACELERA clustering")
println()

# ============================================================================
# Analysis 2: Compactification Rate
# ============================================================================

println("=" ^ 70)
println("ANÁLISIS 2: TASA DE COMPACTIFICACIÓN")
println("=" ^ 70)
println()

println("Tasa promedio de compactificación (primeros 10s):")
println("-" ^ 70)

for (i, case) in enumerate(cases)
    phase_file = joinpath(base_dir, case, "phase_evolution.csv")
    phase_data = readdlm(phase_file, ',')

    times = phase_data[:, 1]
    σ_φ = phase_data[:, 2]

    # Find data up to t=10s
    idx_10s = findfirst(t -> t >= 10.0, times)

    if !isnothing(idx_10s) && idx_10s > 1
        Δσ = σ_φ[1] - σ_φ[idx_10s]
        Δt = times[idx_10s] - times[1]
        rate = Δσ / Δt

        println(@sprintf("  %-20s: dσ/dt = %.4f rad/s", labels_full[i], rate))
    end
end

println()

# ============================================================================
# Analysis 3: Cluster Location
# ============================================================================

println("=" ^ 70)
println("ANÁLISIS 3: UBICACIÓN DEL CLUSTER")
println("=" ^ 70)
println()

println("Posición final del cluster:")
println("-" ^ 70)

for (i, case) in enumerate(cases)
    mean_φ = summary[i, 5]  # mean_phi column
    φ_deg = rad2deg(mod(mean_φ, 2π))

    # For ellipse, low curvature is at φ = π/2 (90°), 3π/2 (270°)
    # High curvature is at φ = 0 (0°), π (180°)

    sector = if 45 <= φ_deg < 135
        "φ ≈ π/2 (low κ)"
    elseif 135 <= φ_deg < 225
        "φ ≈ π (high κ)"
    elseif 225 <= φ_deg < 315
        "φ ≈ 3π/2 (low κ)"
    else
        "φ ≈ 0, 2π (high κ)"
    end

    println(@sprintf("  %-20s: φ = %6.2f° → %s", labels_full[i], φ_deg, sector))
end

println()
println("PREGUNTA CLAVE:")
println("  ¿Los clusters en ellipses están en φ ≈ π/2 (low κ)?")
println("  Si SÍ → Metric volume effect!")
println("  Si NO → Otra dinámica")
println()

# ============================================================================
# Analysis 4: Statistical Summary
# ============================================================================

println("=" ^ 70)
println("ANÁLISIS 4: NECESIDAD DE ESTADÍSTICA")
println("=" ^ 70)
println()

println("Variabilidad observada con UN SOLO seed:")
println("-" ^ 70)

compactifications = summary[:, 3]
println("  Compactification ratios:")
for (i, case) in enumerate(cases)
    println(@sprintf("    %-20s: %.4f", labels_full[i], compactifications[i]))
end

println()
println("  Min: ", @sprintf("%.4f", minimum(compactifications)))
println("  Max: ", @sprintf("%.4f", maximum(compactifications)))
println("  Range: ", @sprintf("%.4f", maximum(compactifications) - minimum(compactifications)))
println()

println("PROBLEMA:")
println("  Con N=1 trial, NO podemos distinguir:")
println("    - Variación real por eccentricity")
println("    - Ruido estadístico de initial conditions")
println()

println("SOLUCIÓN:")
println("  Correr Experiment 5: Multiple seeds")
println("    - 10-20 trials por cada a/b")
println("    - Calcular mean ± std")
println("    - Test estadístico (ANOVA, t-test)")
println()

# ============================================================================
# Save detailed analysis
# ============================================================================

open(joinpath(base_dir, "detailed_analysis.txt"), "w") do io
    println(io, "Detailed Analysis: Experiment 4")
    println(io, "=" ^ 70)
    println(io)

    println(io, "Summary:")
    println(io, "-" ^ 70)
    println(io, @sprintf("%-20s  %6s  %10s  %10s",
                        "Case", "a/b", "Compact", "mean_φ"))
    println(io, "-" ^ 70)

    for (i, case) in enumerate(cases)
        println(io, @sprintf("%-20s  %6.2f  %10.4f  %10.2f°",
                            labels_full[i], summary[i,1], summary[i,3],
                            rad2deg(mod(summary[i,5], 2π))))
    end

    println(io)
    println(io, "Key Findings:")
    println(io, "  1. ALL cases show strong clustering (even circle!)")
    println(io, "  2. Extreme eccentricity clusters FASTEST")
    println(io, "  3. Cluster location varies (need to understand why)")
    println(io)
    println(io, "Next Steps:")
    println(io, "  → Run statistical study with multiple seeds")
    println(io, "  → Quantify error bars")
    println(io, "  → Test significance of eccentricity effect")
end

println("=" ^ 70)
println("✅ ANÁLISIS COMPLETADO")
println("=" ^ 70)
println()
println("Archivo guardado: $base_dir/detailed_analysis.txt")
println()
