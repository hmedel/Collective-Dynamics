#!/usr/bin/env julia
# Kinetic Theory Analysis: Distribution Function f(φ, φ̇, t)
# Analyzes single-particle and two-particle distribution functions

using HDF5
using Statistics
using DataFrames
using CSV
using CairoMakie
using Printf
using StatsBase

println("="^80)
println("KINETIC THEORY: Distribution Function Analysis")
println("="^80)
println()

campaign_dir = "results/campaign_eccentricity_scan_20251116_014451"

# ============================================================================
# Configuration
# ============================================================================

# Select eccentricities to analyze
eccentricities_to_analyze = [0.0, 0.5, 0.9, 0.98, 0.99]

# Time snapshots to analyze
n_snapshots = 5  # Initial, 25%, 50%, 75%, final

# Phase space grid resolution
n_phi_bins = 50
n_phidot_bins = 50

println("Configuration:")
println("  Eccentricities: ", eccentricities_to_analyze)
println("  Time snapshots: $n_snapshots")
println("  Phase space grid: $n_phi_bins × $n_phidot_bins")
println()

# ============================================================================
# Helper Functions
# ============================================================================

"""
Compute 2D histogram (discretized distribution function)
"""
function compute_distribution_2d(phi, phidot, n_phi_bins, n_phidot_bins)
    # Create bins
    phi_edges = range(0, 2π, length=n_phi_bins+1)
    phidot_edges = range(minimum(phidot)*1.1, maximum(phidot)*1.1, length=n_phidot_bins+1)

    # Compute 2D histogram
    hist = fit(Histogram, (phi, phidot), (phi_edges, phidot_edges))

    # Normalize to get PDF
    counts = hist.weights
    total = sum(counts)
    pdf = counts ./ (total * step(phi_edges) * step(phidot_edges))

    return pdf, phi_edges, phidot_edges
end

"""
Compute marginal distributions
"""
function compute_marginals(phi, phidot, n_bins)
    # f_phi(φ) = ∫ f(φ, φ̇) dφ̇
    hist_phi = fit(Histogram, phi, range(0, 2π, length=n_bins+1))
    f_phi = hist_phi.weights ./ (sum(hist_phi.weights) * step(hist_phi.edges[1]))

    # f_phidot(φ̇) = ∫ f(φ, φ̇) dφ
    # Use explicit range for consistent bin count
    phidot_min = minimum(phidot)
    phidot_max = maximum(phidot)
    margin = 0.1 * (phidot_max - phidot_min)
    hist_phidot = fit(Histogram, phidot, range(phidot_min - margin, phidot_max + margin, length=n_bins+1))
    f_phidot = hist_phidot.weights ./ (sum(hist_phidot.weights) * step(hist_phidot.edges[1]))

    return f_phi, hist_phi.edges[1], f_phidot, hist_phidot.edges[1]
end

"""
Compute entropy from distribution
S = -∫ f(x) log(f(x)) dx
"""
function compute_entropy(pdf)
    entropy = 0.0
    for p in pdf
        if p > 0
            entropy -= p * log(p)
        end
    end
    return entropy
end

"""
Compute moments of distribution
"""
function compute_moments(phi, phidot)
    return (
        mean_phi = mean(phi),
        std_phi = std(phi),
        mean_phidot = mean(phidot),
        std_phidot = std(phidot),
        skewness_phi = moment(phi .- mean(phi), 3) / std(phi)^3,
        skewness_phidot = moment(phidot .- mean(phidot), 3) / std(phidot)^3,
        kurtosis_phi = moment(phi .- mean(phi), 4) / std(phi)^4 - 3,
        kurtosis_phidot = moment(phidot .- mean(phidot), 4) / std(phidot)^4 - 3
    )
end

"""
Helper to compute arbitrary moments
"""
function moment(x, n)
    return mean(x.^n)
end

# ============================================================================
# Analysis Loop
# ============================================================================

results_by_e = Dict()

for e_target in eccentricities_to_analyze
    println("="^80)
    @printf("Analyzing e = %.2f\n", e_target)
    println("="^80)

    # Find files for this eccentricity
    files = filter(readdir(campaign_dir, join=true)) do f
        endswith(f, ".h5") && occursin(@sprintf("e%.3f", e_target), f)
    end

    if isempty(files)
        @warn "No files found for e = $e_target"
        continue
    end

    println("Found $(length(files)) runs")

    # We'll analyze just the first run for detailed temporal evolution
    # and ensemble-average over all runs for final state

    # ========================================================================
    # Temporal Evolution (single run)
    # ========================================================================

    file = files[1]

    h5open(file, "r") do f
        phi_traj = read(f["trajectories"]["phi"])
        phidot_traj = read(f["trajectories"]["phidot"])
        time = read(f["trajectories"]["time"])

        N_particles, N_timesteps = size(phi_traj)

        # Select snapshots
        snapshot_indices = unique([
            1,
            div(N_timesteps, 4),
            div(N_timesteps, 2),
            3*div(N_timesteps, 4),
            N_timesteps
        ])

        println("\nTemporal Evolution (single run):")
        println("  N_particles: $N_particles")
        println("  N_timesteps: $N_timesteps")
        println("  Time range: [$(time[1]), $(time[end])]")

        temporal_data = []

        for (i, idx) in enumerate(snapshot_indices)
            phi_snap = phi_traj[:, idx]
            phidot_snap = phidot_traj[:, idx]
            t = time[idx]

            # Compute distribution
            pdf_2d, phi_edges, phidot_edges = compute_distribution_2d(
                phi_snap, phidot_snap, n_phi_bins, n_phidot_bins
            )

            # Marginals
            f_phi, phi_edges_1d, f_phidot, phidot_edges_1d = compute_marginals(
                phi_snap, phidot_snap, n_phi_bins
            )

            # Moments
            moments = compute_moments(phi_snap, phidot_snap)

            # Entropy
            S_2d = compute_entropy(pdf_2d)
            S_phi = compute_entropy(f_phi)
            S_phidot = compute_entropy(f_phidot)

            push!(temporal_data, (
                time = t,
                idx = idx,
                pdf_2d = pdf_2d,
                phi_edges = phi_edges,
                phidot_edges = phidot_edges,
                f_phi = f_phi,
                phi_edges_1d = phi_edges_1d,
                f_phidot = f_phidot,
                phidot_edges_1d = phidot_edges_1d,
                moments = moments,
                entropy_2d = S_2d,
                entropy_phi = S_phi,
                entropy_phidot = S_phidot
            ))

            @printf("  t = %.4f: S_2D = %.4f, ⟨φ⟩ = %.4f, σ_φ = %.4f\n",
                    t, S_2d, moments.mean_phi, moments.std_phi)
        end

        results_by_e[e_target] = (
            temporal = temporal_data,
            time_full = time
        )
    end

    # ========================================================================
    # Ensemble Statistics (all runs, final state only)
    # ========================================================================

    println("\nEnsemble Statistics (all runs, final state):")

    ensemble_phi = Float64[]
    ensemble_phidot = Float64[]

    for file in files
        h5open(file, "r") do f
            phi_final = read(f["trajectories"]["phi"])[:, end]
            phidot_final = read(f["trajectories"]["phidot"])[:, end]

            append!(ensemble_phi, phi_final)
            append!(ensemble_phidot, phidot_final)
        end
    end

    # Compute ensemble-averaged distribution
    pdf_ensemble, phi_edges_ens, phidot_edges_ens = compute_distribution_2d(
        ensemble_phi, ensemble_phidot, n_phi_bins, n_phidot_bins
    )

    f_phi_ens, phi_edges_1d_ens, f_phidot_ens, phidot_edges_1d_ens = compute_marginals(
        ensemble_phi, ensemble_phidot, n_phi_bins
    )

    moments_ens = compute_moments(ensemble_phi, ensemble_phidot)
    S_ens = compute_entropy(pdf_ensemble)

    println("  Total points: $(length(ensemble_phi))")
    @printf("  S_ensemble = %.4f\n", S_ens)
    @printf("  ⟨φ⟩ = %.4f ± %.4f\n", moments_ens.mean_phi, moments_ens.std_phi)
    @printf("  ⟨φ̇⟩ = %.4f ± %.4f\n", moments_ens.mean_phidot, moments_ens.std_phidot)

    # Store ensemble data
    results_by_e[e_target] = merge(results_by_e[e_target], (
        ensemble_pdf = pdf_ensemble,
        ensemble_phi_edges = phi_edges_ens,
        ensemble_phidot_edges = phidot_edges_ens,
        ensemble_f_phi = f_phi_ens,
        ensemble_f_phidot = f_phidot_ens,
        ensemble_moments = moments_ens,
        ensemble_entropy = S_ens
    ))
end

println()
println("="^80)
println("VISUALIZATION")
println("="^80)
println()

# ============================================================================
# Plot 1: Phase Space Distributions (Grid of e × time)
# ============================================================================

println("Generating Plot 1: Phase space distribution evolution...")

fig1 = Figure(size = (1800, length(eccentricities_to_analyze)*300))

for (row, e_target) in enumerate(eccentricities_to_analyze)
    if !haskey(results_by_e, e_target)
        continue
    end

    data = results_by_e[e_target]

    # Show 4 snapshots: initial, mid, late, final
    snapshot_indices = [1, 2, 3, 5]

    for (col, snap_idx) in enumerate(snapshot_indices)
        snap = data.temporal[snap_idx]

        ax = Axis(fig1[row, col],
            xlabel = col == length(snapshot_indices) ? "φ" : "",
            ylabel = row == 1 ? "φ̇" : "",
            title = @sprintf("e=%.2f, t=%.3f", e_target, snap.time)
        )

        # Plot 2D distribution
        phi_centers = (snap.phi_edges[1:end-1] .+ snap.phi_edges[2:end]) ./ 2
        phidot_centers = (snap.phidot_edges[1:end-1] .+ snap.phidot_edges[2:end]) ./ 2

        hm = heatmap!(ax, phi_centers, phidot_centers, snap.pdf_2d,
            colormap = :viridis,
            colorrange = (0, maximum(snap.pdf_2d))
        )

        if col == length(snapshot_indices)
            Colorbar(fig1[row, col+1], hm, label = "f(φ,φ̇)")
        end
    end
end

save(joinpath(campaign_dir, "Fig_DistributionFunction_PhaseSpace.png"), fig1, px_per_unit = 2)
println("  ✅ Fig_DistributionFunction_PhaseSpace.png")

# ============================================================================
# Plot 2: Marginal Distributions
# ============================================================================

println("Generating Plot 2: Marginal distributions...")

fig2 = Figure(size = (1400, 800))

# f_phi(φ) for all e
ax1 = Axis(fig2[1, 1],
    xlabel = "Angular Position (φ)",
    ylabel = "Probability Density f_φ(φ)",
    title = "Spatial Distribution (Final State, Ensemble)"
)

# f_phidot(φ̇) for all e
ax2 = Axis(fig2[1, 2],
    xlabel = "Angular Velocity (φ̇)",
    ylabel = "Probability Density f_φ̇(φ̇)",
    title = "Velocity Distribution (Final State, Ensemble)"
)

colors = [:blue, :green, :orange, :red, :darkred]

for (i, e_target) in enumerate(eccentricities_to_analyze)
    if !haskey(results_by_e, e_target)
        continue
    end

    data = results_by_e[e_target]

    # f_phi
    phi_centers = (data.ensemble_phi_edges[1:end-1] .+ data.ensemble_phi_edges[2:end]) ./ 2
    lines!(ax1, phi_centers, data.ensemble_f_phi,
        color = colors[i],
        linewidth = 3,
        label = @sprintf("e=%.2f", e_target)
    )

    # f_phidot
    phidot_centers = (data.ensemble_phidot_edges[1:end-1] .+ data.ensemble_phidot_edges[2:end]) ./ 2
    lines!(ax2, phidot_centers, data.ensemble_f_phidot,
        color = colors[i],
        linewidth = 3,
        label = @sprintf("e=%.2f", e_target)
    )
end

# Add uniform reference for f_phi
hlines!(ax1, [1/(2π)], color = :black, linestyle = :dash, linewidth = 2, label = "Uniform")

axislegend(ax1, position = :rt)
axislegend(ax2, position = :rt)

save(joinpath(campaign_dir, "Fig_DistributionFunction_Marginals.png"), fig2, px_per_unit = 2)
println("  ✅ Fig_DistributionFunction_Marginals.png")

# ============================================================================
# Plot 3: Entropy Evolution
# ============================================================================

println("Generating Plot 3: Entropy evolution...")

fig3 = Figure(size = (1000, 700))

ax = Axis(fig3[1, 1],
    xlabel = "Time",
    ylabel = "Entropy S = -∫ f log(f)",
    title = "Information-Theoretic Entropy Evolution"
)

for (i, e_target) in enumerate(eccentricities_to_analyze)
    if !haskey(results_by_e, e_target)
        continue
    end

    data = results_by_e[e_target]
    times = [snap.time for snap in data.temporal]
    entropies = [snap.entropy_2d for snap in data.temporal]

    scatterlines!(ax, times, entropies,
        color = colors[i],
        linewidth = 3,
        marker = :circle,
        markersize = 12,
        label = @sprintf("e=%.2f", e_target)
    )
end

axislegend(ax, position = :rb)

save(joinpath(campaign_dir, "Fig_DistributionFunction_Entropy.png"), fig3, px_per_unit = 2)
println("  ✅ Fig_DistributionFunction_Entropy.png")

# ============================================================================
# Plot 4: Moments Evolution
# ============================================================================

println("Generating Plot 4: Statistical moments evolution...")

fig4 = Figure(size = (1600, 1000))

# σ_φ vs time
ax1 = Axis(fig4[1, 1],
    xlabel = "Time",
    ylabel = "σ_φ (Spatial Spread)",
    title = "Standard Deviation of Position"
)

# σ_φ̇ vs time
ax2 = Axis(fig4[1, 2],
    xlabel = "Time",
    ylabel = "σ_φ̇ (Velocity Spread)",
    title = "Standard Deviation of Velocity"
)

# Skewness
ax3 = Axis(fig4[2, 1],
    xlabel = "Time",
    ylabel = "Skewness (φ)",
    title = "Asymmetry of Spatial Distribution"
)

# Kurtosis
ax4 = Axis(fig4[2, 2],
    xlabel = "Time",
    ylabel = "Kurtosis (φ)",
    title = "Tail Weight of Spatial Distribution"
)

for (i, e_target) in enumerate(eccentricities_to_analyze)
    if !haskey(results_by_e, e_target)
        continue
    end

    data = results_by_e[e_target]
    times = [snap.time for snap in data.temporal]

    std_phi = [snap.moments.std_phi for snap in data.temporal]
    std_phidot = [snap.moments.std_phidot for snap in data.temporal]
    skew_phi = [snap.moments.skewness_phi for snap in data.temporal]
    kurt_phi = [snap.moments.kurtosis_phi for snap in data.temporal]

    lines!(ax1, times, std_phi, color = colors[i], linewidth = 3,
           label = @sprintf("e=%.2f", e_target))
    lines!(ax2, times, std_phidot, color = colors[i], linewidth = 3)
    lines!(ax3, times, skew_phi, color = colors[i], linewidth = 3)
    lines!(ax4, times, kurt_phi, color = colors[i], linewidth = 3)
end

# Reference lines
hlines!(ax3, [0], color = :black, linestyle = :dash, linewidth = 2, label = "Gaussian")
hlines!(ax4, [0], color = :black, linestyle = :dash, linewidth = 2, label = "Gaussian")

axislegend(ax1, position = :rt)

save(joinpath(campaign_dir, "Fig_DistributionFunction_Moments.png"), fig4, px_per_unit = 2)
println("  ✅ Fig_DistributionFunction_Moments.png")

# ============================================================================
# Summary Statistics Table
# ============================================================================

println()
println("="^80)
println("SUMMARY: Distribution Function Statistics")
println("="^80)
println()

summary_data = []

for e_target in sort(collect(keys(results_by_e)))
    data = results_by_e[e_target]
    ens = data.ensemble_moments

    push!(summary_data, (
        e = e_target,
        entropy = data.ensemble_entropy,
        mean_phi = ens.mean_phi,
        std_phi = ens.std_phi,
        skewness_phi = ens.skewness_phi,
        kurtosis_phi = ens.kurtosis_phi,
        std_phidot = ens.std_phidot
    ))
end

df_summary = DataFrame(summary_data)

println(df_summary)
println()

# Save to CSV
CSV.write(joinpath(campaign_dir, "distribution_function_summary.csv"), df_summary)
println("  ✅ distribution_function_summary.csv")

println()
println("="^80)
println("Distribution Function Analysis Completed")
println("="^80)
println()
println("Key Insights:")
println("  • f(φ,φ̇,t) reveals clustering dynamics in phase space")
println("  • Marginal f_φ(φ) shows spatial structure")
println("  • Entropy S[f] quantifies information content")
println("  • Higher moments detect non-Gaussian features")
println()
println("Generated Figures:")
println("  1. Phase space distributions (e × time grid)")
println("  2. Marginal distributions f_φ and f_φ̇")
println("  3. Entropy evolution")
println("  4. Statistical moments (σ, skewness, kurtosis)")
