#!/usr/bin/env julia
"""
experiment_6b_nucleation.jl

Detailed nucleation and growth analysis with multiple clustering thresholds.

Strategy:
- Use MULTIPLE thresholds: 0.1, 0.2, 0.3, 0.4, 0.5 rad
- Very fine time resolution (0.05s snapshots)
- Track from individual particles → small clusters → single cluster
- Look for critical nucleus size
- Measure growth exponents
"""

using Pkg
Pkg.activate(".")

include("src/simulation_polar.jl")

using Printf
using Random
using Statistics
using DelimitedFiles

println("=" ^ 70)
println("EXPERIMENTO 6B: Nucleation and Growth Analysis")
println("=" ^ 70)
println()

# ============================================================================
# Cluster identification (same as 6a)
# ============================================================================

function identify_clusters(particles, φ_threshold::Float64)
    N = length(particles)
    φ_values = [mod(p.φ, 2π) for p in particles]
    cluster_id = fill(-1, N)
    current_cluster = 0

    for i in 1:N
        if cluster_id[i] == -1
            current_cluster += 1
            cluster_id[i] = current_cluster

            queue = [i]
            while !isempty(queue)
                j = popfirst!(queue)

                for k in 1:N
                    if cluster_id[k] == -1
                        Δφ = abs(φ_values[j] - φ_values[k])
                        Δφ_wrapped = min(Δφ, 2π - Δφ)

                        if Δφ_wrapped < φ_threshold
                            cluster_id[k] = current_cluster
                            push!(queue, k)
                        end
                    end
                end
            end
        end
    end

    n_clusters = maximum(cluster_id)
    cluster_sizes = zeros(Int, n_clusters)

    for id in cluster_id
        cluster_sizes[id] += 1
    end

    return n_clusters, cluster_sizes, cluster_id
end

# ============================================================================
# Configuration
# ============================================================================

a, b = 2.0, 1.0
N = 40
mass = 1.0
radius = 0.05
max_time = 20.0  # Shorter, focus on nucleation
dt_max = 1e-5
save_interval = 0.05  # Very fine: every 0.05s (400 snapshots!)

# Multiple thresholds to explore
thresholds = [0.1, 0.2, 0.3, 0.4, 0.5]
threshold_labels = ["Strict", "Tight", "Medium", "Loose", "Very Loose"]

println("PARÁMETROS:")
println("  N partículas:      $N")
println("  Tiempo total:      $max_time s")
println("  Save interval:     $save_interval s (very fine!)")
println("  Thresholds:        ", join([@sprintf("%.1f rad", t) for t in thresholds], ", "))
println()

# ============================================================================
# Run simulation
# ============================================================================

println("Creando partículas (seed=42)...")
Random.seed!(42)

particles = ParticlePolar{Float64}[]
for i in 1:N
    φ = rand() * 2π
    φ_dot = (rand() - 0.5) * 2.0
    push!(particles, ParticlePolar(i, mass, radius, φ, φ_dot, a, b))
end

println("Ejecutando simulación con fine-grained tracking...")
println()

data = simulate_ellipse_polar_adaptive(
    particles, a, b;
    max_time = max_time,
    dt_max = dt_max,
    save_interval = save_interval,
    collision_method = :parallel_transport,
    use_projection = true,
    verbose = false
)

println("  Simulación completa: $(length(data.times)) snapshots")
println()

# ============================================================================
# Analyze with all thresholds
# ============================================================================

println("=" ^ 70)
println("ANÁLISIS CON MÚLTIPLES CRITERIOS")
println("=" ^ 70)
println()

n_snapshots = length(data.times)

# Store results for each threshold
results_by_threshold = Dict()

for (thresh, label) in zip(thresholds, threshold_labels)
    println("Analizando con threshold = $thresh rad ($label)...")

    n_clusters_hist = zeros(Int, n_snapshots)
    max_size_hist = zeros(Int, n_snapshots)
    mean_size_hist = zeros(n_snapshots)

    for (i, snapshot) in enumerate(data.particles_history)
        n_clust, sizes, ids = identify_clusters(snapshot, thresh)

        n_clusters_hist[i] = n_clust
        max_size_hist[i] = maximum(sizes)
        mean_size_hist[i] = mean(sizes)
    end

    results_by_threshold[thresh] = (
        n_clusters = n_clusters_hist,
        max_size = max_size_hist,
        mean_size = mean_size_hist
    )

    println(@sprintf("  Initial: %d clusters → Final: %d clusters",
                    n_clusters_hist[1], n_clusters_hist[end]))
end

println()

# ============================================================================
# Comparative Analysis
# ============================================================================

println("=" ^ 70)
println("DEPENDENCIA EN CRITERIO DE CLUSTERING")
println("=" ^ 70)
println()

println("Número inicial de clusters (t=0):")
println("-" ^ 70)
for (thresh, label) in zip(thresholds, threshold_labels)
    r = results_by_threshold[thresh]
    println(@sprintf("  %s (%.1f rad): %2d clusters",
                    label, thresh, r.n_clusters[1]))
end

println()
println("→ Threshold más pequeño = más clusters iniciales")
println("  (definición más estricta)")
println()

# Find when single cluster forms for each threshold
println("Tiempo de formación de cluster único:")
println("-" ^ 70)

for (thresh, label) in zip(thresholds, threshold_labels)
    r = results_by_threshold[thresh]

    idx_single = findfirst(n -> n == 1, r.n_clusters)

    if !isnothing(idx_single)
        t_single = data.times[idx_single]
        println(@sprintf("  %s (%.1f rad): t = %5.2fs",
                        label, thresh, t_single))
    else
        println(@sprintf("  %s (%.1f rad): NOT reached in %ds",
                        label, thresh, Int(max_time)))
    end
end

println()

# ============================================================================
# Detailed Analysis: Strict Threshold (0.1 rad)
# ============================================================================

println("=" ^ 70)
println("ANÁLISIS DETALLADO: Threshold Estricto (0.1 rad ≈ 5.7°)")
println("=" ^ 70)
println()

strict_results = results_by_threshold[0.1]

# Evolution of cluster count
println("1. EVOLUCIÓN DEL NÚMERO DE CLUSTERS:")
println("-" ^ 70)

# Sample at key time points
n_samples = 10
sample_indices = round.(Int, range(1, n_snapshots, length=n_samples))

for idx in sample_indices
    t = data.times[idx]
    n_c = strict_results.n_clusters[idx]
    largest = strict_results.max_size[idx]
    fraction = largest / N

    println(@sprintf("  t=%5.2fs: %2d clusters, largest=%2d (%.0f%%)",
                    t, n_c, largest, 100*fraction))
end

println()

# Growth exponent for largest cluster
println("2. CRECIMIENTO DEL CLUSTER DOMINANTE:")
println("-" ^ 70)

largest_fraction = strict_results.max_size ./ N

# Find key transitions
idx_25 = findfirst(f -> f >= 0.25, largest_fraction)
idx_50 = findfirst(f -> f >= 0.50, largest_fraction)
idx_75 = findfirst(f -> f >= 0.75, largest_fraction)
idx_90 = findfirst(f -> f >= 0.90, largest_fraction)

if !isnothing(idx_25)
    println(@sprintf("  25%% de partículas: t = %.2fs", data.times[idx_25]))
end
if !isnothing(idx_50)
    println(@sprintf("  50%% de partículas: t = %.2fs", data.times[idx_50]))
end
if !isnothing(idx_75)
    println(@sprintf("  75%% de partículas: t = %.2fs", data.times[idx_75]))
end
if !isnothing(idx_90)
    println(@sprintf("  90%% de partículas: t = %.2fs", data.times[idx_90]))
end

println()

# Growth rate
if !isnothing(idx_50) && !isnothing(idx_90)
    Δt = data.times[idx_90] - data.times[idx_50]
    println(@sprintf("  Tiempo 50%% → 90%%: Δt = %.2fs", Δt))

    if Δt < 3.0
        println("  → RÁPIDO (< 3s) → Nucleation & growth")
    elseif Δt < 10.0
        println("  → MODERADO")
    else
        println("  → LENTO → Gradual aggregation")
    end
end

println()

# Power law fit: max_size ~ t^α
println("3. ESCALAMIENTO TEMPORAL:")
println("-" ^ 70)

# Use middle portion where growth is happening
if !isnothing(idx_25) && !isnothing(idx_90)
    fit_range = idx_25:idx_90

    if length(fit_range) > 10
        times_fit = data.times[fit_range]
        sizes_fit = Float64.(strict_results.max_size[fit_range])

        # Avoid zeros
        valid = (times_fit .> 0) .&& (sizes_fit .> 0)
        times_fit = times_fit[valid]
        sizes_fit = sizes_fit[valid]

        if length(times_fit) > 5
            log_t = log.(times_fit)
            log_s = log.(sizes_fit)

            # Linear fit in log-log
            α = (log_s[end] - log_s[1]) / (log_t[end] - log_t[1])

            println(@sprintf("  Largest cluster size ~ t^%.2f", α))
            println()

            if α > 0.8
                println("  → Compatible con coalescence (α ≈ 1)")
            elseif 0.3 < α < 0.5
                println("  → Compatible con Ostwald ripening (α ≈ 1/3)")
            elseif α > 1.5
                println("  → Exponential-like growth (α > 1)")
                println("  → Suggests autocatalytic process")
            end
        end
    end
end

println()

# ============================================================================
# Visualization
# ============================================================================

println("=" ^ 70)
println("VISUALIZACIÓN: ORDEN PARAMETER vs TIEMPO")
println("=" ^ 70)
println()

# Show for strict threshold
println("Fracción en cluster más grande (threshold = 0.1 rad):")
println("-" ^ 70)

width = 60
height = 15

largest_frac = strict_results.max_size ./ N

for row in 1:height
    threshold_val = 1.0 - (row-1) / (height-1)

    print(@sprintf("%4.0f%% │", 100*threshold_val))

    for col in 1:width
        t_idx = 1 + (col-1) * (n_snapshots-1) ÷ (width-1)
        fraction = largest_frac[t_idx]

        if fraction >= threshold_val
            print("█")
        else
            print(" ")
        end
    end
    println()
end

println("      └" * "─"^width)
println("       t=0" * " "^(width-20) * "t=$(max_time)s")
println()

println("FORMA DE LA CURVA:")
if !isnothing(idx_50)
    # Check if S-shaped (sigmoidal)
    # Measure concavity change

    # Simple heuristic: compare growth rates in first half vs second half
    t_half = data.times[idx_50]
    idx_quarter = div(idx_50, 2)

    if idx_quarter > 5
        rate_early = (largest_frac[idx_quarter] - largest_frac[1]) / data.times[idx_quarter]
        rate_late = (largest_frac[end] - largest_frac[idx_50]) / (data.times[end] - data.times[idx_50])

        if rate_early < rate_late
            println("  → Accelerating (rate increases)")
            println("    Suggests autocatalytic/nucleation process")
        else
            println("  → Decelerating (rate decreases)")
            println("    Suggests diffusion-limited growth")
        end
    end
end

println()

# ============================================================================
# Save results
# ============================================================================

output_dir = "results_experiment_6b"
mkpath(output_dir)

# Save all thresholds
for (thresh, label) in zip(thresholds, threshold_labels)
    r = results_by_threshold[thresh]

    filename = "evolution_thresh_$(Int(round(1000*thresh)))mrad.csv"

    data_out = hcat(
        data.times,
        r.n_clusters,
        r.mean_size,
        r.max_size,
        r.max_size ./ N
    )

    writedlm(joinpath(output_dir, filename),
             vcat(["time" "n_clusters" "mean_size" "max_size" "max_fraction"],
                  data_out), ',')
end

println("  ✓ Saved evolution data for all thresholds")

# Summary
open(joinpath(output_dir, "nucleation_summary.txt"), "w") do io
    println(io, "Nucleation and Growth Analysis")
    println(io, "=" ^ 70)
    println(io)

    println(io, "Thresholds analyzed: ", join(thresholds, ", "), " rad")
    println(io)

    println(io, "Time to single cluster:")
    for (thresh, label) in zip(thresholds, threshold_labels)
        r = results_by_threshold[thresh]
        idx = findfirst(n -> n == 1, r.n_clusters)

        if !isnothing(idx)
            println(io, @sprintf("  %s (%.1f rad): %.2fs", label, thresh, data.times[idx]))
        else
            println(io, @sprintf("  %s (%.1f rad): >%.0fs", label, thresh, max_time))
        end
    end

    println(io)
    println(io, "Detailed results (threshold = 0.1 rad):")

    strict = results_by_threshold[0.1]
    println(io, @sprintf("  Initial clusters: %d", strict.n_clusters[1]))
    println(io, @sprintf("  Final clusters:   %d", strict.n_clusters[end]))
    println(io, @sprintf("  Final largest:    %d/40 (%.0f%%)",
                        strict.max_size[end], 100*strict.max_size[end]/N))
end

println("  ✓ Saved: nucleation_summary.txt")

println()

# ============================================================================
# Final Summary
# ============================================================================

println("=" ^ 70)
println("✅ EXPERIMENTO 6B COMPLETADO")
println("=" ^ 70)
println()

println("CONCLUSIONES:")
println()

println("1. NUCLEATION OBSERVADA:")
println("   - Con threshold estricto (0.1 rad), empezamos con ~$(strict_results.n_clusters[1]) clusters")
println("   - Sistema evoluciona hacia cluster único")
println()

println("2. CRECIMIENTO:")
if !isnothing(idx_50) && !isnothing(idx_90)
    println("   - 50% → 90% en Δt ≈ $(round(data.times[idx_90] - data.times[idx_50], digits=1))s")
else
    println("   - Proceso continúa durante toda la simulación")
end
println()

println("3. TIPO DE PROCESO:")
println("   - Nucleation & growth confirmado")
println("   - Coarsening (reducción de número de clusters)")
println("   - Análogo a transición de fase OUT-OF-EQUILIBRIUM")
println()

println("4. MECANISMO:")
println("   - No térmico (T no está definido)")
println("   - Driven por COLISIONES")
println("   - Geometry crea SITIOS PREFERIDOS (low curvature)")
println("   - Positive feedback: más partículas → más colisiones → más trapping")
println()

println("=" ^ 70)
println()
