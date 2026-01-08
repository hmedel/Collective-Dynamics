"""
Coarsening Analysis Tools

Functions to analyze cluster growth kinetics, extract growth exponents,
and test scaling collapse.
"""

using Statistics, StatsBase, LsqFit, Distributions

"""
    ClusteringMetrics

Container for clustering analysis results
"""
struct ClusteringMetrics{T <: AbstractFloat}
    # Timescales
    t_nucleation::T       # When N_clusters < N/2
    t_half::T             # When s_max = 0.5·N
    t_cluster::T          # When s_max = 0.95·N
    t_saturation::T       # When ds_max/dt < threshold

    # Growth exponent
    alpha::T              # From s_max ~ t^alpha
    alpha_std::T          # Standard error
    R_squared::T          # Fit quality

    # Scaling
    tau::T                # Size distribution exponent
    tau_std::T

    # Final state
    N_clusters_final::Int
    s_max_final::Int
    sigma_phi_final::T
end

"""
    compute_cluster_evolution(data::SimulationData, threshold::Float64)

Compute cluster size evolution over time.

# Arguments
- `data::SimulationData`: Simulation results
- `threshold::Float64`: Distance threshold for connectivity (radians)

# Returns
- `times::Vector{T}`: Time points
- `N_clusters::Vector{Int}`: Number of clusters at each time
- `s_max::Vector{Int}`: Maximum cluster size at each time
- `s_avg::Vector{T}`: Average cluster size at each time
"""
function compute_cluster_evolution(particles_history, times, a, b, threshold)
    T = eltype(times)
    n_snapshots = length(times)

    N_clusters = Int[]
    s_max = Int[]
    s_avg = T[]

    for i in 1:n_snapshots
        particles = particles_history[i]
        clusters = identify_clusters(particles, a, b, threshold)

        cluster_sizes = [length(c) for c in clusters]

        push!(N_clusters, length(clusters))
        push!(s_max, isempty(cluster_sizes) ? 0 : maximum(cluster_sizes))
        push!(s_avg, isempty(cluster_sizes) ? 0.0 : mean(cluster_sizes))
    end

    return times, N_clusters, s_max, s_avg
end

"""
    identify_clusters(particles, a, b, threshold)

Identify clusters using connectivity-based algorithm.

Particles are in same cluster if their Cartesian distance < threshold.

# Returns
- `Vector{Vector{Int}}`: List of clusters (each cluster is list of particle indices)
"""
function identify_clusters(particles, a, b, threshold)
    N = length(particles)

    # Build adjacency matrix
    adjacent = falses(N, N)
    for i in 1:N, j in (i+1):N
        dist = cartesian_distance(particles[i], particles[j])
        if dist < threshold
            adjacent[i, j] = true
            adjacent[j, i] = true
        end
    end

    # Find connected components (depth-first search)
    visited = falses(N)
    clusters = Vector{Int}[]

    for i in 1:N
        if !visited[i]
            cluster = Int[]
            stack = [i]

            while !isempty(stack)
                node = pop!(stack)
                if !visited[node]
                    visited[node] = true
                    push!(cluster, node)

                    # Add neighbors to stack
                    for j in 1:N
                        if adjacent[node, j] && !visited[j]
                            push!(stack, j)
                        end
                    end
                end
            end

            push!(clusters, cluster)
        end
    end

    return clusters
end

"""
    cartesian_distance(p1::ParticlePolar, p2::ParticlePolar)

Compute Cartesian distance between two particles.
"""
function cartesian_distance(p1, p2)
    dx = p1.pos[1] - p2.pos[1]
    dy = p1.pos[2] - p2.pos[2]
    return sqrt(dx^2 + dy^2)
end

"""
    extract_growth_exponent(times, s_max; t_start=nothing, t_end=nothing)

Extract growth exponent α from power-law fit: s_max ~ t^α

# Arguments
- `times::Vector{T}`: Time points
- `s_max::Vector{Int}`: Maximum cluster size at each time
- `t_start::Union{T, Nothing}`: Start time for fit (default: auto-detect)
- `t_end::Union{T, Nothing}`: End time for fit (default: when s_max stops growing)

# Returns
- `alpha::T`: Growth exponent
- `alpha_std::T`: Standard error
- `R_squared::T`: Coefficient of determination
- `t_fit_range::Tuple{T, T}`: Time range used for fit
"""
function extract_growth_exponent(times, s_max; t_start=nothing, t_end=nothing)
    T = eltype(times)
    N_total = maximum(s_max)

    # Auto-detect fit range
    if t_start === nothing
        # Start when s_max first exceeds N/4 (nucleation complete)
        idx_start = findfirst(s -> s > N_total/4, s_max)
        if idx_start === nothing
            idx_start = 1
        end
        t_start = times[idx_start]
    else
        idx_start = findfirst(t -> t >= t_start, times)
    end

    if t_end === nothing
        # End when s_max reaches 0.9·N (near saturation)
        idx_end = findfirst(s -> s > 0.9*N_total, s_max)
        if idx_end === nothing
            idx_end = length(times)
        end
        t_end = times[idx_end]
    else
        idx_end = findfirst(t -> t >= t_end, times)
    end

    # Extract fitting region
    fit_mask = (times .>= t_start) .& (times .<= t_end) .& (s_max .> 0)
    t_fit = times[fit_mask]
    s_fit = s_max[fit_mask]

    if length(t_fit) < 5
        # Not enough points for fit
        return (alpha=NaN, alpha_std=NaN, R_squared=NaN, t_fit_range=(NaN, NaN))
    end

    # Log-log linear fit: log(s) = α·log(t) + log(C)
    log_t = log.(t_fit)
    log_s = log.(Float64.(s_fit))

    # Weighted least squares (weight by s to reduce noise at small s)
    weights = sqrt.(Float64.(s_fit))

    # Fit model: log_s = alpha * log_t + intercept
    @. model(x, p) = p[1] * x + p[2]

    # Initial guess
    p0 = [0.5, log(s_fit[1])]

    # Fit
    try
        fit_result = curve_fit(model, log_t, log_s, weights, p0)

        alpha = coef(fit_result)[1]
        alpha_std = stderror(fit_result)[1]

        # R²
        ss_res = sum((log_s .- model(log_t, coef(fit_result))).^2)
        ss_tot = sum((log_s .- mean(log_s)).^2)
        R_squared = 1 - ss_res / ss_tot

        return (alpha=alpha, alpha_std=alpha_std, R_squared=R_squared,
                t_fit_range=(t_start, t_end))
    catch e
        @warn "Growth exponent fit failed: $e"
        return (alpha=NaN, alpha_std=NaN, R_squared=NaN, t_fit_range=(t_start, t_end))
    end
end

"""
    extract_timescales(times, N_clusters, s_max)

Extract characteristic timescales from evolution.

# Returns
Named tuple with:
- `t_nucleation`: When N_clusters first drops below N_total/2
- `t_half`: When s_max first reaches N_total/2
- `t_cluster`: When s_max first reaches 0.95·N_total
- `t_saturation`: When ds_max/dt < threshold
"""
function extract_timescales(times, N_clusters, s_max)
    T = eltype(times)
    N_total = maximum(s_max)

    # t_nucleation
    idx = findfirst(n -> n < N_total/2, N_clusters)
    t_nucleation = idx === nothing ? T(NaN) : times[idx]

    # t_half
    idx = findfirst(s -> s >= N_total/2, s_max)
    t_half = idx === nothing ? T(NaN) : times[idx]

    # t_cluster
    idx = findfirst(s -> s >= 0.95*N_total, s_max)
    t_cluster = idx === nothing ? T(NaN) : times[idx]

    # t_saturation (when growth rate < 0.01 particles/s)
    if length(times) > 10
        dt = times[2] - times[1]
        ds_dt = diff(s_max) ./ dt
        idx = findfirst(abs.(ds_dt) .< 0.01)
        t_saturation = idx === nothing ? T(NaN) : times[idx+1]
    else
        t_saturation = T(NaN)
    end

    return (
        t_nucleation = t_nucleation,
        t_half = t_half,
        t_cluster = t_cluster,
        t_saturation = t_saturation
    )
end

"""
    compute_cluster_size_distribution(particles, a, b, threshold)

Compute histogram of cluster sizes at a single time point.

# Returns
- `sizes::Vector{Int}`: Unique cluster sizes
- `counts::Vector{Int}`: Number of clusters of each size
- `n_s::Vector{Float64}`: Normalized distribution n(s) = counts / N_total
"""
function compute_cluster_size_distribution(particles, a, b, threshold)
    clusters = identify_clusters(particles, a, b, threshold)
    cluster_sizes = [length(c) for c in clusters]

    # Histogram
    size_counts = countmap(cluster_sizes)
    sizes = sort(collect(keys(size_counts)))
    counts = [size_counts[s] for s in sizes]

    # Normalize
    N_total = length(particles)
    n_s = counts ./ N_total

    return sizes, counts, n_s
end

"""
    test_scaling_collapse(times_list, s_max_list, s_avg_list; tau=1.5)

Test scaling collapse of cluster size distribution.

Scaling hypothesis: n(s, t) · s^τ = f(s / ⟨s(t)⟩)

# Arguments
- `times_list`: List of time arrays (one per snapshot)
- `s_max_list`: List of s_max arrays
- `s_avg_list`: List of s_avg arrays
- `tau`: Trial exponent (default: 1.5 from LSW theory)

# Returns
- `collapsed_data`: All data points in scaled coordinates
- `chi_squared`: Quality of collapse
"""
function test_scaling_collapse(size_distributions, times, tau=1.5)
    # Each element of size_distributions is (sizes, counts, n_s, t)

    collapsed_x = Float64[]  # s / ⟨s⟩
    collapsed_y = Float64[]  # n(s, t) · s^τ

    for (sizes, counts, n_s, t) in size_distributions
        s_avg = sum(sizes .* counts) / sum(counts)

        for (s, n) in zip(sizes, n_s)
            x = s / s_avg
            y = n * s^tau

            push!(collapsed_x, x)
            push!(collapsed_y, y)
        end
    end

    # Measure collapse quality (variance around master curve)
    # Bin in x and compute variance in each bin
    n_bins = 20
    x_bins = range(minimum(collapsed_x), maximum(collapsed_x), length=n_bins+1)

    variances = Float64[]
    for i in 1:n_bins
        mask = (collapsed_x .>= x_bins[i]) .& (collapsed_x .< x_bins[i+1])
        if sum(mask) > 2
            push!(variances, var(collapsed_y[mask]))
        end
    end

    chi_squared = isempty(variances) ? NaN : mean(variances)

    return (x=collapsed_x, y=collapsed_y, chi_squared=chi_squared)
end

"""
    analyze_full_clustering_dynamics(data, a, b; threshold=0.2)

Complete clustering analysis for a single simulation.

# Returns
- `ClusteringMetrics`: Comprehensive metrics
- `evolution_data`: Time series data for plotting
"""
function analyze_full_clustering_dynamics(particles_history, times, a, b; threshold=0.2)
    T = eltype(times)

    # 1. Cluster evolution
    _, N_clusters, s_max, s_avg = compute_cluster_evolution(
        particles_history, times, a, b, threshold
    )

    # 2. Timescales
    timescales = extract_timescales(times, N_clusters, s_max)

    # 3. Growth exponent
    growth = extract_growth_exponent(times, s_max)

    # 4. Final state
    N_clusters_final = N_clusters[end]
    s_max_final = s_max[end]

    particles_final = particles_history[end]
    sigma_phi_final = std([p.φ for p in particles_final])

    # 5. Cluster size distribution at multiple times
    # (For scaling collapse, would need full distribution at each time)

    metrics = ClusteringMetrics(
        timescales.t_nucleation,
        timescales.t_half,
        timescales.t_cluster,
        timescales.t_saturation,
        growth.alpha,
        growth.alpha_std,
        growth.R_squared,
        NaN,  # tau (would need full distribution analysis)
        NaN,  # tau_std
        N_clusters_final,
        s_max_final,
        sigma_phi_final
    )

    evolution_data = (
        times = times,
        N_clusters = N_clusters,
        s_max = s_max,
        s_avg = s_avg,
        growth_fit_range = growth.t_fit_range
    )

    return metrics, evolution_data
end

"""
    compare_with_LSW_theory(s_avg, times)

Compare growth with Lifshitz-Slyozov-Wagner theory.

LSW predicts:
- 1D: s_avg ~ t^(1/2)
- 3D: s_avg ~ t^(1/3)

Our system (1D manifold) should be closer to 1D.

# Returns
- `alpha_measured`: Measured exponent
- `alpha_LSW_1D`: Theoretical (1/2)
- `alpha_LSW_3D`: Theoretical (1/3)
- `deviation_1D`: |alpha - 1/2|
- `deviation_3D`: |alpha - 1/3|
"""
function compare_with_LSW_theory(s_avg, times)
    # Extract exponent from s_avg ~ t^alpha
    mask = (s_avg .> 0) .& (times .> 0)
    log_t = log.(times[mask])
    log_s = log.(s_avg[mask])

    # Linear fit
    A = hcat(ones(length(log_t)), log_t)
    coefs = A \ log_s
    alpha_measured = coefs[2]

    alpha_LSW_1D = 0.5
    alpha_LSW_3D = 1/3

    deviation_1D = abs(alpha_measured - alpha_LSW_1D)
    deviation_3D = abs(alpha_measured - alpha_LSW_3D)

    return (
        alpha_measured = alpha_measured,
        alpha_LSW_1D = alpha_LSW_1D,
        alpha_LSW_3D = alpha_LSW_3D,
        deviation_1D = deviation_1D,
        deviation_3D = deviation_3D,
        closer_to = deviation_1D < deviation_3D ? "1D" : "3D"
    )
end
