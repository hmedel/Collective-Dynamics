#!/usr/bin/env julia
"""
experiment_5_statistical.jl

EXPERIMENTO 5: Statistical Study with Multiple Seeds

Strategy:
- 4 eccentricities: a/b = 1.0, 2.0, 3.0, 5.0
- 15 seeds per case (60 simulations total)
- Shorter time: 15s (enough to see clustering)
- Measure: compactification ratio, t_1/2, cluster location

This will give proper error bars and statistical significance testing.
"""

using Pkg
Pkg.activate(".")

include("src/simulation_polar.jl")

using Printf
using Random
using Statistics
using DelimitedFiles

println("=" ^ 70)
println("EXPERIMENTO 5: Statistical Study (Multiple Seeds)")
println("=" ^ 70)
println()

# ============================================================================
# Configuration
# ============================================================================

# Eccentricity cases
a_values = [2.0, 2.0, 2.0, 2.0]
b_values = [2.0, 1.0, 2.0/3.0, 2.0/5.0]
case_labels = ["Circle", "Moderate", "High_ecc", "Extreme_ecc"]

# Simulation parameters
N = 40
mass = 1.0
radius = 0.05
max_time = 15.0  # Shorter: clustering happens in <10s
dt_max = 1e-5
dt_min = 1e-10
save_interval = 0.5

# Statistical parameters
n_seeds = 15  # Number of trials per case
seeds = collect(100:100+n_seeds-1)  # Seeds: 100, 101, ..., 114

println("CONFIGURACIÓN ESTADÍSTICA:")
println("  Casos:           4 (a/b = 1, 2, 3, 5)")
println("  Seeds por caso:  $n_seeds")
println("  Total trials:    $(4 * n_seeds)")
println("  Tiempo por run:  $max_time s")
println("  Tiempo estimado: ~$(4 * n_seeds * 2 / 60) min")
println()

# ============================================================================
# Main loop: all cases x all seeds
# ============================================================================

output_dir = "results_experiment_5_statistical"
mkpath(output_dir)

# Storage for results
all_results = []

total_runs = length(case_labels) * n_seeds
current_run = 0

for (case_idx, case_label) in enumerate(case_labels)
    a = a_values[case_idx]
    b = b_values[case_idx]
    ratio_ab = a / b
    ecc = b < a ? sqrt(1 - (b/a)^2) : 0.0

    println("=" ^ 70)
    println("CASO: $case_label (a/b = $(ratio_ab), e = $(round(ecc, digits=3)))")
    println("=" ^ 70)
    println()

    case_results = []

    for (seed_idx, seed) in enumerate(seeds)
        global current_run
        current_run += 1
        progress = 100 * current_run / total_runs

        print(@sprintf("  [%5.1f%%] Seed %d/%d... ", progress, seed_idx, n_seeds))
        flush(stdout)

        # Create particles
        Random.seed!(seed)

        particles = ParticlePolar{Float64}[]
        for i in 1:N
            φ = rand() * 2π
            φ_dot = (rand() - 0.5) * 2.0
            push!(particles, ParticlePolar(i, mass, radius, φ, φ_dot, a, b))
        end

        E_initial = sum(kinetic_energy(p, a, b) for p in particles)
        σ_φ_initial = std([p.φ for p in particles])

        # Run simulation
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
            verbose = false
        )

        t_elapsed = time() - t_start

        # Analyze results
        final_particles = data.particles_history[end]
        σ_φ_final = std([p.φ for p in final_particles])
        mean_φ_final = mean([p.φ for p in final_particles])
        compactification = σ_φ_final / σ_φ_initial

        # Energy conservation
        E_final = sum(kinetic_energy(p, a, b) for p in final_particles)
        ΔE_rel = abs(E_final - E_initial) / E_initial

        # Collision count
        total_collisions = sum(data.n_collisions)

        # Calculate t_1/2 (time to 50% compactification)
        times = data.times
        σ_φ_history = [std([p.φ for p in snapshot]) for snapshot in data.particles_history]

        σ_target = (σ_φ_initial + σ_φ_final) / 2
        idx_half = findfirst(σ -> σ <= σ_target, σ_φ_history)
        t_half = !isnothing(idx_half) ? times[idx_half] : NaN

        # Store results
        push!(case_results, (
            seed = seed,
            σ_φ_initial = σ_φ_initial,
            σ_φ_final = σ_φ_final,
            compactification = compactification,
            t_half = t_half,
            mean_φ_final = mean_φ_final,
            ΔE_rel = ΔE_rel,
            collisions = total_collisions,
            time_elapsed = t_elapsed
        ))

        println(@sprintf("σ_φ=%.4f, t_1/2=%.2fs (%.1fs)", σ_φ_final, t_half, t_elapsed))
    end

    # Case statistics
    compacts = [r.compactification for r in case_results]
    t_halfs = filter(!isnan, [r.t_half for r in case_results])
    σ_finals = [r.σ_φ_final for r in case_results]

    mean_compact = mean(compacts)
    std_compact = std(compacts)
    mean_t_half = !isempty(t_halfs) ? mean(t_halfs) : NaN
    std_t_half = !isempty(t_halfs) ? std(t_halfs) : NaN
    mean_σ_final = mean(σ_finals)
    std_σ_final = std(σ_finals)

    println()
    println("  ESTADÍSTICAS ($n_seeds seeds):")
    println(@sprintf("    Compactification: %.4f ± %.4f", mean_compact, std_compact))
    println(@sprintf("    t_1/2:            %.2f ± %.2f s", mean_t_half, std_t_half))
    println(@sprintf("    σ_φ final:        %.4f ± %.4f rad", mean_σ_final, std_σ_final))
    println()

    # Store case summary
    push!(all_results, (
        case = case_label,
        a_over_b = ratio_ab,
        eccentricity = ecc,
        n_seeds = n_seeds,
        mean_compact = mean_compact,
        std_compact = std_compact,
        mean_t_half = mean_t_half,
        std_t_half = std_t_half,
        mean_σ_final = mean_σ_final,
        std_σ_final = std_σ_final,
        individual_results = case_results
    ))

    # Save individual results for this case
    case_dir = joinpath(output_dir, case_label)
    mkpath(case_dir)

    case_csv = hcat(
        [r.seed for r in case_results],
        [r.compactification for r in case_results],
        [r.t_half for r in case_results],
        [r.σ_φ_final for r in case_results],
        [r.mean_φ_final for r in case_results],
        [r.ΔE_rel for r in case_results],
        [r.collisions for r in case_results]
    )

    writedlm(joinpath(case_dir, "individual_trials.csv"),
             vcat(["seed" "compact" "t_half" "sigma_final" "mean_phi" "dE_rel" "collisions"],
                  case_csv), ',')
end

# ============================================================================
# Statistical Comparison
# ============================================================================

println()
println("=" ^ 70)
println("COMPARACIÓN ESTADÍSTICA")
println("=" ^ 70)
println()

println("Resumen de Todos los Casos:")
println("-" ^ 70)
println(@sprintf("%-15s  %6s  %6s  %15s  %15s",
                "Caso", "a/b", "e", "Compact", "t_1/2 (s)"))
println("-" ^ 70)

for r in all_results
    println(@sprintf("%-15s  %6.2f  %6.3f  %7.4f±%.4f  %6.2f±%.2f",
                    r.case, r.a_over_b, r.eccentricity,
                    r.mean_compact, r.std_compact,
                    r.mean_t_half, r.std_t_half))
end

println()

# Trend analysis
println("ANÁLISIS DE TENDENCIAS:")
println("-" ^ 70)

eccs = [r.eccentricity for r in all_results]
t_halfs_mean = [r.mean_t_half for r in all_results]
compacts_mean = [r.mean_compact for r in all_results]

# Check if t_1/2 decreases with eccentricity
if length(t_halfs_mean) >= 2
    # Simple trend: is it monotonically decreasing?
    decreasing = all(t_halfs_mean[i] >= t_halfs_mean[i+1] for i in 1:(length(t_halfs_mean)-1))

    if decreasing
        println("  ✅ t_1/2 DISMINUYE con eccentricidad (clustering más rápido)")
        println("     → FUERTE evidencia para metric volume hypothesis")
    else
        println("  ⚠️  t_1/2 NO es monótonamente decreciente")
        println("     → Necesita análisis más detallado")
    end

    # Calculate Pearson correlation
    if all(.!isnan.(t_halfs_mean)) && all(.!isnan.(eccs)) && length(unique(eccs)) > 1
        corr_t_ecc = cor(eccs, t_halfs_mean)
        println(@sprintf("  Correlación e vs t_1/2: %.4f", corr_t_ecc))

        if corr_t_ecc < -0.7
            println("     → Correlación negativa FUERTE (mayor e → menor t_1/2)")
        end
    end
end

println()

# ============================================================================
# Save Summary
# ============================================================================

open(joinpath(output_dir, "statistical_summary.txt"), "w") do io
    println(io, "Experiment 5: Statistical Study")
    println(io, "=" ^ 70)
    println(io)
    println(io, "Configuración:")
    println(io, "  Seeds per case: $n_seeds")
    println(io, "  Time per run:   $max_time s")
    println(io)
    println(io, @sprintf("%-15s  %6s  %6s  %15s  %15s",
                        "Caso", "a/b", "e", "Compact", "t_1/2 (s)"))
    println(io, "-" ^ 70)

    for r in all_results
        println(io, @sprintf("%-15s  %6.2f  %6.3f  %7.4f±%.4f  %6.2f±%.2f",
                            r.case, r.a_over_b, r.eccentricity,
                            r.mean_compact, r.std_compact,
                            r.mean_t_half, r.std_t_half))
    end

    println(io)
    println(io, "Interpretación:")
    println(io, "  Error bars permiten:")
    println(io, "  1. Verificar si diferencias son estadísticamente significativas")
    println(io, "  2. Cuantificar variabilidad por initial conditions")
    println(io, "  3. Publicar resultados con confianza científica")
end

# Save CSV
summary_csv = hcat(
    [r.a_over_b for r in all_results],
    [r.eccentricity for r in all_results],
    [r.mean_compact for r in all_results],
    [r.std_compact for r in all_results],
    [r.mean_t_half for r in all_results],
    [r.std_t_half for r in all_results]
)

writedlm(joinpath(output_dir, "summary_statistics.csv"),
         vcat(["a/b" "e" "mean_compact" "std_compact" "mean_t_half" "std_t_half"],
              summary_csv), ',')

println("=" ^ 70)
println("✅ EXPERIMENTO 5 COMPLETADO")
println("=" ^ 70)
println()
println("Resultados guardados en: $output_dir/")
println()
println("Archivos generados:")
println("  - statistical_summary.txt      (resumen con error bars)")
println("  - summary_statistics.csv       (datos para plotting)")
println("  - */individual_trials.csv      (todos los seeds por caso)")
println()
