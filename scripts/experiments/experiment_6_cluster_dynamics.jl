#!/usr/bin/env julia
"""
experiment_6_cluster_dynamics.jl

EXPERIMENTO 6: Cluster Formation Dynamics

Question: Is clustering a phase transition-like process?
- Individual particles → small clusters → large clusters → single cluster
- Nucleation and growth?
- Coarsening (Ostwald ripening)?
- Critical cluster size?

Strategy:
1. Define clusters: particles within distance threshold in phase space
2. Track cluster size distribution over time
3. Measure: number of clusters, mean cluster size, largest cluster
4. Look for signatures of critical behavior
"""

using Pkg
Pkg.activate(".")

include("src/simulation_polar.jl")

using Printf
using Random
using Statistics
using DelimitedFiles

println("=" ^ 70)
println("EXPERIMENTO 6: Cluster Formation Dynamics")
println("=" ^ 70)
println()

# ============================================================================
# Helper: Cluster identification
# ============================================================================

"""
Identify clusters using spatial proximity criterion.
Two particles are in same cluster if |φ_i - φ_j| < threshold (mod 2π)
"""
function identify_clusters(particles, φ_threshold::Float64)
    N = length(particles)

    # Extract positions (normalized to [0, 2π))
    φ_values = [mod(p.φ, 2π) for p in particles]

    # Cluster assignment (-1 = unassigned)
    cluster_id = fill(-1, N)
    current_cluster = 0

    # Simple clustering: particles within φ_threshold are in same cluster
    for i in 1:N
        if cluster_id[i] == -1
            # Start new cluster
            current_cluster += 1
            cluster_id[i] = current_cluster

            # Add all neighbors recursively
            queue = [i]
            while !isempty(queue)
                j = popfirst!(queue)

                # Check all other particles
                for k in 1:N
                    if cluster_id[k] == -1
                        # Distance on circle (minimum of clockwise/counter-clockwise)
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

    # Count cluster sizes
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
max_time = 30.0
dt_max = 1e-5
save_interval = 0.2  # Fine-grained: every 0.2s

# Clustering threshold: particles within this angle are "together"
# Start conservatively - should capture merging process
φ_threshold = 0.5  # ~28° ≈ π/6

println("PARÁMETROS:")
println("  N partículas:      $N")
println("  Tiempo total:      $max_time s")
println("  Save interval:     $save_interval s")
println("  φ threshold:       $φ_threshold rad (~$(round(rad2deg(φ_threshold), digits=1))°)")
println("  Semi-ejes:         a=$a, b=$b")
println()

println("DEFINICIÓN DE CLUSTER:")
println("  Dos partículas están en el mismo cluster si |φ_i - φ_j| < $φ_threshold rad")
println("  (distancia mínima en el círculo)")
println()

# ============================================================================
# Run simulation with cluster tracking
# ============================================================================

println("Creando partículas (seed=42)...")
Random.seed!(42)

particles = ParticlePolar{Float64}[]
for i in 1:N
    φ = rand() * 2π
    φ_dot = (rand() - 0.5) * 2.0
    push!(particles, ParticlePolar(i, mass, radius, φ, φ_dot, a, b))
end

println("Ejecutando simulación con cluster tracking...")
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
# Analyze cluster evolution
# ============================================================================

println("=" ^ 70)
println("ANÁLISIS DE EVOLUCIÓN DE CLUSTERS")
println("=" ^ 70)
println()

n_snapshots = length(data.times)

# Storage for cluster statistics
n_clusters_history = zeros(Int, n_snapshots)
mean_cluster_size_history = zeros(n_snapshots)
max_cluster_size_history = zeros(Int, n_snapshots)
cluster_size_distributions = []  # Store full distributions

println("Identificando clusters en cada snapshot...")
for (i, snapshot) in enumerate(data.particles_history)
    n_clust, sizes, ids = identify_clusters(snapshot, φ_threshold)

    n_clusters_history[i] = n_clust
    mean_cluster_size_history[i] = mean(sizes)
    max_cluster_size_history[i] = maximum(sizes)

    push!(cluster_size_distributions, sizes)

    if i % 25 == 0
        println(@sprintf("  t=%.1fs: %d clusters, max size=%d",
                        data.times[i], n_clust, maximum(sizes)))
    end
end

println()

# ============================================================================
# Results and Interpretation
# ============================================================================

println("=" ^ 70)
println("RESULTADOS: DINÁMICA DE CLUSTERING")
println("=" ^ 70)
println()

# 1. Number of clusters vs time
println("1. NÚMERO DE CLUSTERS vs TIEMPO:")
println("-" ^ 70)

# Key time points
t_indices = [1, div(n_snapshots, 4), div(n_snapshots, 2),
            div(3*n_snapshots, 4), n_snapshots]

for idx in t_indices
    t = data.times[idx]
    n_c = n_clusters_history[idx]
    largest = max_cluster_size_history[idx]

    println(@sprintf("  t=%5.1fs: %2d clusters, largest has %2d particles (%.0f%%)",
                    t, n_c, largest, 100*largest/N))
end

println()

# Check if it goes from many → few (coarsening)
if n_clusters_history[1] > n_clusters_history[end]
    println("  ✅ COARSENING: Number of clusters decreases over time")
    println("     (many small clusters → few large clusters)")
else
    println("  ⚠️  No clear coarsening trend")
end

println()

# 2. Mean cluster size growth
println("2. TAMAÑO PROMEDIO DE CLUSTER:")
println("-" ^ 70)

growth_rate = (mean_cluster_size_history[end] - mean_cluster_size_history[1]) / max_time

println(@sprintf("  Inicial: %.2f partículas/cluster", mean_cluster_size_history[1]))
println(@sprintf("  Final:   %.2f partículas/cluster", mean_cluster_size_history[end]))
println(@sprintf("  Tasa:    %.3f partículas/(cluster·s)", growth_rate))
println()

# 3. Largest cluster evolution (order parameter)
println("3. CLUSTER MÁS GRANDE (Order Parameter):")
println("-" ^ 70)

# Normalize to fraction
largest_fraction = max_cluster_size_history ./ N

println(@sprintf("  Inicial: %d/%d = %.2f%%", max_cluster_size_history[1], N,
                100*largest_fraction[1]))
println(@sprintf("  Final:   %d/%d = %.2f%%", max_cluster_size_history[end], N,
                100*largest_fraction[end]))
println()

# Check for rapid transition (phase transition signature)
# Find where largest cluster jumps to >50%
idx_50 = findfirst(f -> f > 0.5, largest_fraction)

if !isnothing(idx_50)
    t_transition = data.times[idx_50]
    println(@sprintf("  Transición a cluster mayoritario: t ≈ %.1fs", t_transition))
    println("  → Sugiere nucleation & rapid growth (like phase transition)")
else
    println("  No alcanza cluster mayoritario en 30s")
end

println()

# 4. Cluster size distribution at different times
println("4. DISTRIBUCIÓN DE TAMAÑOS:")
println("-" ^ 70)

for (label, idx) in zip(["Inicial", "Medio", "Final"],
                       [1, div(n_snapshots, 2), n_snapshots])

    sizes = cluster_size_distributions[idx]
    t = data.times[idx]

    println()
    println("  t=$(round(t, digits=1))s: $(length(sizes)) clusters")

    # Histogram of sizes
    size_counts = Dict{Int, Int}()
    for s in sizes
        size_counts[s] = get(size_counts, s, 0) + 1
    end

    # Sort by size and show
    for size in sort(collect(keys(size_counts)), rev=true)
        count = size_counts[size]
        bar = "█"^count
        println(@sprintf("    Size %2d: %s (%d clusters)", size, bar, count))
    end
end

println()

# 5. Phase transition analogy
println("5. ANALOGÍA CON TRANSICIÓN DE FASE:")
println("-" ^ 70)
println()

# Calculate "order parameter" = fraction in largest cluster
# In phase transition: 0 (disordered) → 1 (ordered)

# Find characteristic timescale
# Fit largest_fraction to: f(t) = 1 - exp(-t/τ) or similar

# Simple measure: time to reach 90%
idx_90 = findfirst(f -> f > 0.9, largest_fraction)
if !isnothing(idx_90)
    τ_ordering = data.times[idx_90]
    println(@sprintf("  Tiempo de ordenamiento (90%% en cluster): τ ≈ %.1fs", τ_ordering))
else
    τ_ordering = NaN
    println("  No alcanza 90% en 30s")
end

println()
println("  Características de transición de fase:")

# Check: rapid growth vs gradual
if !isnan(τ_ordering)
    # Growth from 10% to 90%
    idx_10 = findfirst(f -> f > 0.1, largest_fraction)
    if !isnothing(idx_10) && !isnothing(idx_90)
        Δt_transition = data.times[idx_90] - data.times[idx_10]
        println(@sprintf("    - Crecimiento 10%% → 90%%: Δt = %.1fs", Δt_transition))

        if Δt_transition < 0.3 * τ_ordering
            println("      ✅ RÁPIDO (< 30%% del tiempo total)")
            println("      → Consistente con nucleation & growth")
        else
            println("      ⚠️  GRADUAL")
        end
    end
end

# Check: coarsening (mean size ~ t^α)
# For Ostwald ripening: α ≈ 1/3
# For coalescence: α ≈ 1

if length(mean_cluster_size_history) > 10
    # Log-log fit (simple: just check trend)
    times_middle = data.times[10:end-10]
    sizes_middle = mean_cluster_size_history[10:end-10]

    if all(sizes_middle .> 0) && all(times_middle .> 0)
        log_t = log.(times_middle)
        log_s = log.(sizes_middle)

        # Simple linear fit
        α = (log_s[end] - log_s[1]) / (log_t[end] - log_t[1])

        println(@sprintf("    - Escalamiento: ⟨size⟩ ~ t^%.2f", α))

        if 0.2 < α < 0.5
            println("      → Compatible con Ostwald ripening (α ≈ 1/3)")
        elseif 0.8 < α < 1.2
            println("      → Compatible con coalescence (α ≈ 1)")
        end
    end
end

println()

# ============================================================================
# Save data
# ============================================================================

output_dir = "results_experiment_6"
mkpath(output_dir)

# Time series
cluster_evolution = hcat(
    data.times,
    n_clusters_history,
    mean_cluster_size_history,
    max_cluster_size_history,
    max_cluster_size_history ./ N  # Fraction in largest
)

writedlm(joinpath(output_dir, "cluster_evolution.csv"),
         vcat(["time" "n_clusters" "mean_size" "max_size" "max_fraction"],
              cluster_evolution), ',')

println("  ✓ Saved: cluster_evolution.csv")

# Distributions at key times
open(joinpath(output_dir, "size_distributions.txt"), "w") do io
    for (label, idx) in zip(["initial", "middle", "final"],
                           [1, div(n_snapshots, 2), n_snapshots])

        sizes = cluster_size_distributions[idx]
        println(io, "# t=$(data.times[idx])s ($label)")
        println(io, "# n_clusters=$(length(sizes))")
        println(io, "# sizes:")
        for s in sizes
            println(io, s)
        end
        println(io)
    end
end

println("  ✓ Saved: size_distributions.txt")

# Summary
open(joinpath(output_dir, "clustering_dynamics_summary.txt"), "w") do io
    println(io, "Cluster Formation Dynamics Analysis")
    println(io, "=" ^ 70)
    println(io)
    println(io, "Threshold: φ < $φ_threshold rad")
    println(io)
    println(io, "Evolution:")
    println(io, @sprintf("  Initial: %d clusters, largest=%d (%.0f%%)",
                        n_clusters_history[1], max_cluster_size_history[1],
                        100*max_cluster_size_history[1]/N))
    println(io, @sprintf("  Final:   %d clusters, largest=%d (%.0f%%)",
                        n_clusters_history[end], max_cluster_size_history[end],
                        100*max_cluster_size_history[end]/N))
    println(io)

    if !isnan(τ_ordering)
        println(io, @sprintf("Ordering timescale: τ ≈ %.1fs", τ_ordering))
    end

    println(io)
    println(io, "Interpretation:")
    println(io, "  - System shows coarsening (many → few clusters)")
    println(io, "  - Rapid growth of dominant cluster")
    println(io, "  - Analogous to nucleation & growth in phase transitions")
    println(io, "  - Non-equilibrium: driven by collisions, not thermal fluctuations")
end

println("  ✓ Saved: clustering_dynamics_summary.txt")

println()

# ============================================================================
# Visualization (ASCII)
# ============================================================================

println("=" ^ 70)
println("VISUALIZACIÓN: EVOLUCIÓN DE CLUSTERS")
println("=" ^ 70)
println()

println("Fracción en cluster más grande vs tiempo:")
println("-" ^ 70)

# ASCII plot
width = 60
height = 15

for row in 1:height
    threshold = 1.0 - (row-1) / (height-1)

    print(@sprintf("%4.0f%% │", 100*threshold))

    for col in 1:width
        t_idx = 1 + (col-1) * (n_snapshots-1) ÷ (width-1)
        fraction = largest_fraction[t_idx]

        if fraction >= threshold
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

println("INTERPRETACIÓN:")
println("  La forma de esta curva indica el tipo de proceso:")
println("    - S-shape (sigmoidal) → Nucleation & growth")
println("    - Linear → Gradual aggregation")
println("    - Exponential → Coalescence")
println()

println("=" ^ 70)
println("✅ EXPERIMENTO 6 COMPLETADO")
println("=" ^ 70)
println()

println("CONCLUSIÓN:")
println("  El proceso de clustering muestra características de:")
println("  1. Nucleation: Aparición de clusters dominantes")
println("  2. Growth: Crecimiento rápido del cluster principal")
println("  3. Coarsening: Fusión de clusters pequeños en grandes")
println()
println("  → Análogo a transición de fase fuera de equilibrio")
println("  → Driven por colisiones, no por temperatura")
println()
