#!/usr/bin/env julia
"""
Proper Clustering Analysis with Physics-Based Metrics
======================================================

Analyzes clustering using:
1. Pair correlation function g(Δφ) - spatial correlations
2. Order parameter ψ = |⟨e^(iφ)⟩| - collective alignment
3. Nematic order S = |⟨e^(2iφ)⟩| - two-cluster detection
4. DBSCAN cluster detection - identify actual groups
5. Phase space density evolution (φ, φ̇)

Usage:
    julia --project=. scripts/analysis/analyze_clustering_proper.jl <h5_file> [output_dir]
"""

using Pkg
Pkg.activate(".")

using HDF5
using Statistics
using LinearAlgebra
using Printf

# ============================================================================
# PAIR CORRELATION FUNCTION g(Δφ)
# ============================================================================

"""
Calculate pair correlation function g(Δφ) for angular positions on a circle.

For uniform distribution: g(Δφ) = 1 for all Δφ
Peaks at small Δφ indicate clustering.
"""
function pair_correlation(φ::Vector{Float64}; n_bins=30)
    N = length(φ)

    # Maximum meaningful separation on circle is π
    Δφ_max = π
    bin_width = Δφ_max / n_bins
    bin_centers = [(i - 0.5) * bin_width for i in 1:n_bins]
    counts = zeros(n_bins)

    # Count all pairs
    for i in 1:N
        for j in (i+1):N
            # Minimum angular separation (periodic BC)
            Δ = abs(φ[i] - φ[j])
            Δ = min(Δ, 2π - Δ)

            if Δ < Δφ_max
                bin_idx = min(n_bins, max(1, ceil(Int, Δ / bin_width)))
                counts[bin_idx] += 2  # Count both i→j and j→i
            end
        end
    end

    # Normalize to g(Δφ)
    # For uniform distribution on circle [0, 2π), probability of separation Δφ is:
    # P(Δφ) = (2π - 2Δφ) / (2π)² for Δφ < π (but simpler: uniform in [0, π] gives P=1/π)
    # Expected pairs in bin: N(N-1) * bin_width / π
    n_pairs = N * (N - 1)
    expected = n_pairs * bin_width / π

    g = counts ./ expected

    return bin_centers, g
end

# ============================================================================
# ORDER PARAMETERS
# ============================================================================

"""
Polar order parameter ψ = |⟨e^(iφ)⟩|.

ψ = 1: All particles at same position (perfect cluster)
ψ = 0: Uniform distribution (no clustering)

Also returns the mean angle θ = arg(⟨e^(iφ)⟩).
"""
function polar_order(φ::Vector{Float64})
    z = mean(exp.(im .* φ))
    return abs(z), angle(z)
end

"""
Nematic order parameter S = |⟨e^(2iφ)⟩|.

S ≈ 1: Particles clustered at two opposite points (φ and φ+π)
S ≈ 0: Uniform or single cluster
"""
function nematic_order(φ::Vector{Float64})
    return abs(mean(exp.(2im .* φ)))
end

"""
Higher-order order parameters for k-cluster detection.
ψ_k = |⟨e^(ikφ)⟩| detects k equally-spaced clusters.
"""
function multipole_order(φ::Vector{Float64}, k::Int)
    return abs(mean(exp.(k * im .* φ)))
end

# ============================================================================
# CLUSTER DETECTION (DBSCAN-like)
# ============================================================================

"""
Angular distance respecting periodic boundary.
"""
function angular_dist(φ1, φ2)
    Δ = abs(φ1 - φ2)
    return min(Δ, 2π - Δ)
end

"""
DBSCAN clustering for angular data.
Returns: n_clusters, cluster_sizes, labels
"""
function angular_dbscan(φ::Vector{Float64}; eps=0.4, min_pts=2)
    N = length(φ)
    labels = zeros(Int, N)  # 0=unvisited, -1=noise, >0=cluster
    cluster_id = 0

    function neighbors(i)
        [j for j in 1:N if j != i && angular_dist(φ[i], φ[j]) < eps]
    end

    for i in 1:N
        labels[i] != 0 && continue

        nbrs = neighbors(i)

        if length(nbrs) < min_pts
            labels[i] = -1  # Noise
            continue
        end

        cluster_id += 1
        labels[i] = cluster_id

        seeds = Set(nbrs)
        while !isempty(seeds)
            j = pop!(seeds)
            labels[j] == -1 && (labels[j] = cluster_id)
            labels[j] != 0 && continue
            labels[j] = cluster_id

            j_nbrs = neighbors(j)
            length(j_nbrs) >= min_pts && union!(seeds, j_nbrs)
        end
    end

    n_clusters = cluster_id
    sizes = [count(==(c), labels) for c in 1:n_clusters]
    n_noise = count(==(-1), labels)

    return n_clusters, sizes, n_noise, labels
end

# ============================================================================
# PHASE SPACE ANALYSIS
# ============================================================================

"""
Calculate local phase space density using 2D histogram.
"""
function phase_space_histogram(φ, φ̇; n_φ=36, n_φ̇=20)
    φ_edges = range(0, 2π, length=n_φ+1)

    φ̇_min, φ̇_max = extrema(φ̇)
    margin = 0.1 * (φ̇_max - φ̇_min)
    φ̇_edges = range(φ̇_min - margin, φ̇_max + margin, length=n_φ̇+1)

    H = zeros(n_φ, n_φ̇)

    for (p, v) in zip(φ, φ̇)
        i = clamp(ceil(Int, p / 2π * n_φ), 1, n_φ)
        j = clamp(ceil(Int, (v - φ̇_edges[1]) / (φ̇_edges[end] - φ̇_edges[1]) * n_φ̇), 1, n_φ̇)
        H[i, j] += 1
    end

    return φ_edges, φ̇_edges, H
end

# ============================================================================
# MAIN ANALYSIS
# ============================================================================

function analyze_h5(h5_file::String, output_dir::String)
    mkpath(output_dir)

    println("="^70)
    println("PROPER CLUSTERING ANALYSIS")
    println("="^70)
    println("Input: $h5_file")
    println("Output: $output_dir")
    println()

    h5open(h5_file, "r") do fid
        times = read(fid, "trajectories/time")
        phi = read(fid, "trajectories/phi")      # (n_times, N) or (N, n_times)
        phidot = read(fid, "trajectories/phidot")

        # Detect data orientation
        if size(phi, 1) == length(times)
            # (n_times, N) format
            n_times, N = size(phi)
        else
            # (N, n_times) format - transpose
            phi = phi'
            phidot = phidot'
            n_times, N = size(phi)
        end

        println("N = $N particles")
        println("n_times = $n_times snapshots")
        println("t ∈ [$(times[1]), $(times[end])]")
        println()

        # ============== TIME EVOLUTION ==============

        # Storage for time series
        ψ_t = Float64[]          # Polar order
        S_t = Float64[]          # Nematic order
        g_small_t = Float64[]    # g(Δφ) at small separations
        n_clusters_t = Int[]     # Number of clusters
        σ_φ_t = Float64[]        # Standard deviation

        println("Computing time evolution...")

        for t_idx in 1:n_times
            φ_t = phi[t_idx, :]
            φ̇_t = phidot[t_idx, :]

            # Order parameters
            ψ, _ = polar_order(φ_t)
            S = nematic_order(φ_t)
            push!(ψ_t, ψ)
            push!(S_t, S)

            # Pair correlation at small Δφ
            centers, g = pair_correlation(φ_t)
            # Average g for Δφ < 0.5 rad (~30°)
            mask = centers .< 0.5
            g_small = sum(mask) > 0 ? mean(g[mask]) : 1.0
            push!(g_small_t, g_small)

            # Cluster count
            n_clust, _, _, _ = angular_dbscan(φ_t; eps=0.5, min_pts=2)
            push!(n_clusters_t, n_clust)

            # Standard deviation
            push!(σ_φ_t, std(φ_t))
        end

        # ============== SUMMARY ==============

        println()
        println("="^70)
        println("RESULTS SUMMARY")
        println("="^70)

        println("\n--- Polar Order ψ = |⟨e^(iφ)⟩| ---")
        println("  (ψ=0: uniform, ψ=1: all particles same position)")
        @printf("  Initial:  %.4f\n", ψ_t[1])
        @printf("  Final:    %.4f\n", ψ_t[end])
        @printf("  Maximum:  %.4f at t=%.1f\n", maximum(ψ_t), times[argmax(ψ_t)])
        @printf("  Mean:     %.4f ± %.4f\n", mean(ψ_t), std(ψ_t))

        println("\n--- Nematic Order S = |⟨e^(2iφ)⟩| ---")
        println("  (S≈1: two opposite clusters, S≈0: uniform or single cluster)")
        @printf("  Initial:  %.4f\n", S_t[1])
        @printf("  Final:    %.4f\n", S_t[end])
        @printf("  Maximum:  %.4f\n", maximum(S_t))

        println("\n--- Pair Correlation g(Δφ<0.5) ---")
        println("  (g=1: uniform, g>1: clustering at small separations)")
        @printf("  Initial:  %.4f\n", g_small_t[1])
        @printf("  Final:    %.4f\n", g_small_t[end])
        @printf("  Maximum:  %.4f\n", maximum(g_small_t))

        println("\n--- Cluster Count (DBSCAN, eps=0.5) ---")
        @printf("  Initial:  %d\n", n_clusters_t[1])
        @printf("  Final:    %d\n", n_clusters_t[end])
        @printf("  Range:    %d - %d\n", minimum(n_clusters_t), maximum(n_clusters_t))

        println("\n--- σ_φ (position spread) ---")
        @printf("  Initial:  %.4f\n", σ_φ_t[1])
        @printf("  Final:    %.4f\n", σ_φ_t[end])
        @printf("  Minimum:  %.4f\n", minimum(σ_φ_t))

        # ============== INTERPRETATION ==============

        println("\n" * "="^70)
        println("INTERPRETATION")
        println("="^70)

        if maximum(ψ_t) > 0.6
            println("✓ STRONG CLUSTERING detected (ψ_max > 0.6)")
        elseif maximum(ψ_t) > 0.3
            println("~ MODERATE clustering tendency (0.3 < ψ_max < 0.6)")
        else
            println("✗ NO significant clustering (ψ_max < 0.3)")
        end

        if maximum(S_t) > 0.5 && maximum(S_t) > maximum(ψ_t)
            println("⚑ TWO-CLUSTER state detected (high nematic order)")
        end

        if maximum(g_small_t) > 2.0
            println("⚑ HIGH local density at small separations (g > 2)")
        end

        # ============== SAVE DATA ==============

        # Time series
        ts_file = joinpath(output_dir, "time_series.csv")
        open(ts_file, "w") do io
            println(io, "time,psi,S,g_small,n_clusters,sigma_phi")
            for i in 1:n_times
                @printf(io, "%.6f,%.6f,%.6f,%.6f,%d,%.6f\n",
                        times[i], ψ_t[i], S_t[i], g_small_t[i], n_clusters_t[i], σ_φ_t[i])
            end
        end
        println("\nSaved: $ts_file")

        # Pair correlation at sample times
        sample_idx = unique([1, n_times÷4, n_times÷2, 3n_times÷4, n_times])
        gc_file = joinpath(output_dir, "pair_correlation.csv")
        open(gc_file, "w") do io
            println(io, "time,delta_phi,g")
            for idx in sample_idx
                centers, g = pair_correlation(phi[idx, :])
                for (c, gv) in zip(centers, g)
                    @printf(io, "%.4f,%.6f,%.6f\n", times[idx], c, gv)
                end
            end
        end
        println("Saved: $gc_file")

        # Phase space snapshots
        ps_file = joinpath(output_dir, "phase_space.csv")
        open(ps_file, "w") do io
            println(io, "time,particle,phi,phidot")
            for idx in sample_idx
                for p in 1:N
                    @printf(io, "%.4f,%d,%.6f,%.6f\n",
                            times[idx], p, phi[idx, p], phidot[idx, p])
                end
            end
        end
        println("Saved: $ps_file")

        println("\n" * "="^70)
    end
end

# ============================================================================
# MAIN
# ============================================================================

if length(ARGS) < 1
    println("Usage: julia analyze_clustering_proper.jl <h5_file> [output_dir]")
    println()
    println("Metrics computed:")
    println("  ψ = |⟨e^(iφ)⟩|     Polar order (0=uniform, 1=single cluster)")
    println("  S = |⟨e^(2iφ)⟩|    Nematic order (detects 2-cluster states)")
    println("  g(Δφ)              Pair correlation function")
    println("  n_clusters         DBSCAN cluster count")
    exit(1)
end

h5_file = ARGS[1]
output_dir = length(ARGS) >= 2 ? ARGS[2] : joinpath(dirname(h5_file), "clustering_analysis")

analyze_h5(h5_file, output_dir)
