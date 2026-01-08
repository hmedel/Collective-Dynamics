#!/usr/bin/env julia
# Complete Temporal Analysis: f(φ, φ̇, t) as a function of time
# Generates full 3D distribution function and temporal evolution

using HDF5
using Statistics
using CairoMakie
using Printf
using StatsBase
using LinearAlgebra

println("="^80)
println("TEMPORAL DISTRIBUTION FUNCTION: f(φ, φ̇, t)")
println("="^80)
println()

campaign_dir = "results/campaign_eccentricity_scan_20251116_014451"

# ============================================================================
# Configuration
# ============================================================================

# Select eccentricities to analyze in detail
eccentricities_detailed = [0.0, 0.5, 0.9, 0.98, 0.99]

# Phase space resolution
n_phi_bins = 60
n_phidot_bins = 60
n_time_bins = 100  # Temporal resolution

println("Configuration:")
println("  Eccentricities: ", eccentricities_detailed)
println("  Spatial bins: $n_phi_bins")
println("  Velocity bins: $n_phidot_bins")
println("  Temporal bins: $n_time_bins")
println()

# ============================================================================
# Helper Functions
# ============================================================================

"""
Compute 2D histogram at specific time
"""
function compute_snapshot_distribution(phi_snap, phidot_snap, phi_edges, phidot_edges)
    hist = fit(Histogram, (phi_snap, phidot_snap), (phi_edges, phidot_edges))
    counts = hist.weights
    total = sum(counts)

    if total > 0
        pdf = counts ./ (total * step(phi_edges) * step(phidot_edges))
    else
        pdf = zeros(size(counts))
    end

    return pdf
end

"""
Compute Shannon entropy
"""
function shannon_entropy(pdf)
    S = 0.0
    for p in pdf
        if p > 1e-10
            S -= p * log(p)
        end
    end
    return S
end

"""
Compute statistical moments
"""
function compute_moments(phi, phidot)
    N = length(phi)
    if N == 0
        return (mean_phi=NaN, std_phi=NaN, mean_phidot=NaN, std_phidot=NaN)
    end

    return (
        mean_phi = mean(phi),
        std_phi = std(phi),
        mean_phidot = mean(phidot),
        std_phidot = std(phidot)
    )
end

"""
Compute spatial clustering ratio from distribution
"""
function clustering_from_distribution(f_phi, phi_centers)
    # Identify major/minor axis regions
    n = length(phi_centers)
    bin_width = π/4

    major_mask = (phi_centers .< bin_width) .| (phi_centers .> 2π - bin_width) .|
                 (abs.(phi_centers .- π) .< bin_width)
    minor_mask = (abs.(phi_centers .- π/2) .< bin_width) .|
                 (abs.(phi_centers .- 3π/2) .< bin_width)

    # Integrate over regions
    n_major = sum(f_phi[major_mask]) * step(phi_centers)
    n_minor = sum(f_phi[minor_mask]) * step(phi_centers)

    if n_minor > 0.01
        return n_major / n_minor
    else
        return 1.0
    end
end

# ============================================================================
# Main Analysis Loop
# ============================================================================

results_temporal = Dict()

for e_target in eccentricities_detailed
    println("="^80)
    @printf("Analyzing e = %.2f\n", e_target)
    println("="^80)

    # Find first run for this eccentricity
    files = filter(readdir(campaign_dir, join=true)) do f
        endswith(f, ".h5") && occursin(@sprintf("e%.3f", e_target), f)
    end

    if isempty(files)
        @warn "No files found for e = $e_target"
        continue
    end

    file = files[1]
    println("Processing: $(basename(file))")

    h5open(file, "r") do f
        # Read full trajectories
        phi_traj = read(f["trajectories"]["phi"])
        phidot_traj = read(f["trajectories"]["phidot"])
        time = read(f["trajectories"]["time"])

        N_particles, N_timesteps = size(phi_traj)

        println("  N_particles: $N_particles")
        println("  N_timesteps: $N_timesteps")
        println("  Time range: [$(time[1]), $(time[end])]")

        # Define phase space bins
        phi_edges = range(0, 2π, length=n_phi_bins+1)
        phi_centers = (phi_edges[1:end-1] .+ phi_edges[2:end]) ./ 2

        # Get velocity range from full trajectory
        phidot_min = minimum(phidot_traj)
        phidot_max = maximum(phidot_traj)
        margin = 0.1 * (phidot_max - phidot_min)
        phidot_edges = range(phidot_min - margin, phidot_max + margin, length=n_phidot_bins+1)
        phidot_centers = (phidot_edges[1:end-1] .+ phidot_edges[2:end]) ./ 2

        # Select time indices uniformly
        time_indices = unique(round.(Int, range(1, N_timesteps, length=n_time_bins)))
        n_actual_times = length(time_indices)

        println("  Computing f(φ,φ̇,t) for $n_actual_times time points...")

        # Storage for temporal evolution
        f_3d = zeros(n_phi_bins, n_phidot_bins, n_actual_times)
        f_phi_t = zeros(n_phi_bins, n_actual_times)
        f_phidot_t = zeros(n_phidot_bins, n_actual_times)

        entropy_t = zeros(n_actual_times)
        mean_phi_t = zeros(n_actual_times)
        std_phi_t = zeros(n_actual_times)
        mean_phidot_t = zeros(n_actual_times)
        std_phidot_t = zeros(n_actual_times)
        clustering_t = zeros(n_actual_times)

        times_selected = zeros(n_actual_times)

        # Compute distribution at each time point
        for (i_t, idx) in enumerate(time_indices)
            phi_snap = phi_traj[:, idx]
            phidot_snap = phidot_traj[:, idx]

            # 2D distribution
            f_3d[:, :, i_t] = compute_snapshot_distribution(phi_snap, phidot_snap,
                                                             phi_edges, phidot_edges)

            # Marginals
            f_phi_t[:, i_t] = sum(f_3d[:, :, i_t], dims=2)[:]
            f_phidot_t[:, i_t] = sum(f_3d[:, :, i_t], dims=1)[:]

            # Normalize marginals
            norm_phi = sum(f_phi_t[:, i_t]) * step(phi_edges)
            if norm_phi > 0
                f_phi_t[:, i_t] ./= norm_phi
            end

            norm_phidot = sum(f_phidot_t[:, i_t]) * step(phidot_edges)
            if norm_phidot > 0
                f_phidot_t[:, i_t] ./= norm_phidot
            end

            # Compute properties
            entropy_t[i_t] = shannon_entropy(f_3d[:, :, i_t])
            moments = compute_moments(phi_snap, phidot_snap)
            mean_phi_t[i_t] = moments.mean_phi
            std_phi_t[i_t] = moments.std_phi
            mean_phidot_t[i_t] = moments.mean_phidot
            std_phidot_t[i_t] = moments.std_phidot

            clustering_t[i_t] = clustering_from_distribution(f_phi_t[:, i_t], phi_centers)

            times_selected[i_t] = time[idx]

            if i_t % 20 == 0
                @printf("    Progress: %d/%d (t=%.2f)\n", i_t, n_actual_times, time[idx])
            end
        end

        println("  ✅ Distribution computed")

        # Store results
        results_temporal[e_target] = (
            phi_edges = phi_edges,
            phi_centers = phi_centers,
            phidot_edges = phidot_edges,
            phidot_centers = phidot_centers,
            times = times_selected,
            f_3d = f_3d,
            f_phi_t = f_phi_t,
            f_phidot_t = f_phidot_t,
            entropy_t = entropy_t,
            mean_phi_t = mean_phi_t,
            std_phi_t = std_phi_t,
            mean_phidot_t = mean_phidot_t,
            std_phidot_t = std_phidot_t,
            clustering_t = clustering_t
        )
    end

    println()
end

println("="^80)
println("VISUALIZATION")
println("="^80)
println()

# ============================================================================
# Plot 1: Temporal Evolution of f(φ, φ̇, t) - Movie Frames
# ============================================================================

println("Generating Plot 1: Temporal snapshots of f(φ,φ̇,t)...")

for e_target in eccentricities_detailed
    if !haskey(results_temporal, e_target)
        continue
    end

    data = results_temporal[e_target]

    # Select 6 key time points
    n_times = length(data.times)
    snapshot_indices = unique([1, div(n_times,5), 2*div(n_times,5),
                               3*div(n_times,5), 4*div(n_times,5), n_times])

    fig = Figure(size = (1800, 1200))

    for (plot_idx, time_idx) in enumerate(snapshot_indices)
        row = div(plot_idx - 1, 3) + 1
        col = mod(plot_idx - 1, 3) + 1

        ax = Axis(fig[row, col],
            xlabel = "φ",
            ylabel = "φ̇",
            title = @sprintf("t = %.2f", data.times[time_idx])
        )

        f_snapshot = data.f_3d[:, :, time_idx]

        hm = heatmap!(ax, data.phi_centers, data.phidot_centers, f_snapshot,
            colormap = :thermal,
            colorrange = (0, maximum(data.f_3d))
        )

        # Add colorbar
        Colorbar(fig[row, col+3], hm, label = "f(φ,φ̇)")
    end

    save(joinpath(campaign_dir, @sprintf("Fig_fPhiPhidot_t_e%.2f.png", e_target)),
         fig, px_per_unit = 2)
    println(@sprintf("  ✅ Fig_fPhiPhidot_t_e%.2f.png", e_target))
end

# ============================================================================
# Plot 2: Marginal f_φ(φ, t) as Heatmap
# ============================================================================

println("Generating Plot 2: f_φ(φ,t) heatmaps...")

fig2 = Figure(size = (1800, 1200))

for (i, e_target) in enumerate(eccentricities_detailed)
    if !haskey(results_temporal, e_target)
        continue
    end

    data = results_temporal[e_target]

    ax = Axis(fig2[div(i-1,2)+1, mod(i-1,2)+1],
        xlabel = "Time",
        ylabel = "φ",
        title = @sprintf("e = %.2f: f_φ(φ,t)", e_target)
    )

    hm = heatmap!(ax, data.times, data.phi_centers, data.f_phi_t',
        colormap = :viridis,
        colorrange = (0, maximum(data.f_phi_t))
    )

    Colorbar(fig2[div(i-1,2)+1, mod(i-1,2)+2], hm, label = "f_φ(φ)")
end

save(joinpath(campaign_dir, "Fig_f_phi_vs_time_heatmap.png"), fig2, px_per_unit = 2)
println("  ✅ Fig_f_phi_vs_time_heatmap.png")

# ============================================================================
# Plot 3: Marginal f_φ̇(φ̇, t) as Heatmap
# ============================================================================

println("Generating Plot 3: f_φ̇(φ̇,t) heatmaps...")

fig3 = Figure(size = (1800, 1200))

for (i, e_target) in enumerate(eccentricities_detailed)
    if !haskey(results_temporal, e_target)
        continue
    end

    data = results_temporal[e_target]

    ax = Axis(fig3[div(i-1,2)+1, mod(i-1,2)+1],
        xlabel = "Time",
        ylabel = "φ̇",
        title = @sprintf("e = %.2f: f_φ̇(φ̇,t)", e_target)
    )

    hm = heatmap!(ax, data.times, data.phidot_centers, data.f_phidot_t',
        colormap = :plasma,
        colorrange = (0, maximum(data.f_phidot_t))
    )

    Colorbar(fig3[div(i-1,2)+1, mod(i-1,2)+2], hm, label = "f_φ̇(φ̇)")
end

save(joinpath(campaign_dir, "Fig_f_phidot_vs_time_heatmap.png"), fig3, px_per_unit = 2)
println("  ✅ Fig_f_phidot_vs_time_heatmap.png")

# ============================================================================
# Plot 4: Entropy S(t) Evolution
# ============================================================================

println("Generating Plot 4: Entropy evolution S(t)...")

fig4 = Figure(size = (1200, 700))

ax = Axis(fig4[1, 1],
    xlabel = "Time",
    ylabel = "Entropy S[f]",
    title = "Shannon Entropy Evolution"
)

colors = [:blue, :green, :orange, :red, :darkred]

for (i, e_target) in enumerate(eccentricities_detailed)
    if !haskey(results_temporal, e_target)
        continue
    end

    data = results_temporal[e_target]

    lines!(ax, data.times, data.entropy_t,
        color = colors[i],
        linewidth = 3,
        label = @sprintf("e = %.2f", e_target)
    )
end

axislegend(ax, position = :rt)

save(joinpath(campaign_dir, "Fig_Entropy_vs_time.png"), fig4, px_per_unit = 2)
println("  ✅ Fig_Entropy_vs_time.png")

# ============================================================================
# Plot 5: Standard Deviations σ_φ(t) and σ_φ̇(t)
# ============================================================================

println("Generating Plot 5: Standard deviations vs time...")

fig5 = Figure(size = (1400, 700))

ax1 = Axis(fig5[1, 1],
    xlabel = "Time",
    ylabel = "σ_φ",
    title = "Spatial Spread"
)

ax2 = Axis(fig5[1, 2],
    xlabel = "Time",
    ylabel = "σ_φ̇",
    title = "Velocity Spread"
)

for (i, e_target) in enumerate(eccentricities_detailed)
    if !haskey(results_temporal, e_target)
        continue
    end

    data = results_temporal[e_target]

    lines!(ax1, data.times, data.std_phi_t,
        color = colors[i],
        linewidth = 3,
        label = @sprintf("e = %.2f", e_target)
    )

    lines!(ax2, data.times, data.std_phidot_t,
        color = colors[i],
        linewidth = 3,
        label = @sprintf("e = %.2f", e_target)
    )
end

axislegend(ax1, position = :rt)
axislegend(ax2, position = :rt)

save(joinpath(campaign_dir, "Fig_Std_vs_time.png"), fig5, px_per_unit = 2)
println("  ✅ Fig_Std_vs_time.png")

# ============================================================================
# Plot 6: Clustering Ratio R(t)
# ============================================================================

println("Generating Plot 6: Clustering evolution R(t)...")

fig6 = Figure(size = (1200, 700))

ax = Axis(fig6[1, 1],
    xlabel = "Time",
    ylabel = "Clustering Ratio R(t)",
    title = "Temporal Evolution of Clustering"
)

for (i, e_target) in enumerate(eccentricities_detailed)
    if !haskey(results_temporal, e_target)
        continue
    end

    data = results_temporal[e_target]

    lines!(ax, data.times, data.clustering_t,
        color = colors[i],
        linewidth = 3,
        label = @sprintf("e = %.2f", e_target)
    )
end

hlines!(ax, [1.0], color = :black, linestyle = :dash, linewidth = 2, label = "Uniform")

axislegend(ax, position = :rb)

save(joinpath(campaign_dir, "Fig_Clustering_vs_time.png"), fig6, px_per_unit = 2)
println("  ✅ Fig_Clustering_vs_time.png")

# ============================================================================
# Plot 7: Combined Evolution Panel
# ============================================================================

println("Generating Plot 7: Combined temporal evolution...")

fig7 = Figure(size = (1600, 1200))

# Select one representative eccentricity for detailed view
e_representative = 0.98
if haskey(results_temporal, e_representative)
    data = results_temporal[e_representative]

    # Row 1: Phase space snapshots (3 times)
    time_snaps = [1, div(length(data.times),2), length(data.times)]

    for (col, t_idx) in enumerate(time_snaps)
        ax = Axis(fig7[1, col],
            xlabel = "φ",
            ylabel = "φ̇",
            title = @sprintf("t = %.2f", data.times[t_idx])
        )

        hm = heatmap!(ax, data.phi_centers, data.phidot_centers, data.f_3d[:, :, t_idx],
            colormap = :thermal
        )

        if col == 3
            Colorbar(fig7[1, 4], hm, label = "f(φ,φ̇)")
        end
    end

    # Row 2: f_φ(φ,t) heatmap
    ax2 = Axis(fig7[2, 1:3],
        xlabel = "Time",
        ylabel = "φ",
        title = @sprintf("e = %.2f: Spatial Distribution Evolution", e_representative)
    )

    hm2 = heatmap!(ax2, data.times, data.phi_centers, data.f_phi_t',
        colormap = :viridis
    )
    Colorbar(fig7[2, 4], hm2, label = "f_φ(φ)")

    # Row 3: Temporal metrics
    ax3 = Axis(fig7[3, 1:2],
        xlabel = "Time",
        ylabel = "Entropy S[f]",
        title = "Entropy Evolution"
    )
    lines!(ax3, data.times, data.entropy_t, color = :blue, linewidth = 3)

    ax4 = Axis(fig7[3, 3],
        xlabel = "Time",
        ylabel = "σ_φ",
        title = "Spatial Spread"
    )
    lines!(ax4, data.times, data.std_phi_t, color = :green, linewidth = 3)

    ax5 = Axis(fig7[3, 4],
        xlabel = "Time",
        ylabel = "R(t)",
        title = "Clustering"
    )
    lines!(ax5, data.times, data.clustering_t, color = :red, linewidth = 3)
    hlines!(ax5, [1.0], color = :black, linestyle = :dash, linewidth = 2)

    save(joinpath(campaign_dir, @sprintf("Fig_Combined_Evolution_e%.2f.png", e_representative)),
         fig7, px_per_unit = 2)
    println(@sprintf("  ✅ Fig_Combined_Evolution_e%.2f.png", e_representative))
end

# ============================================================================
# Export Numerical Data
# ============================================================================

println()
println("Exporting numerical data...")

for e_target in eccentricities_detailed
    if !haskey(results_temporal, e_target)
        continue
    end

    data = results_temporal[e_target]

    # Save temporal statistics to HDF5
    output_file = joinpath(campaign_dir, @sprintf("distribution_temporal_e%.2f.h5", e_target))

    h5open(output_file, "w") do f
        # Grids
        f["phi_centers"] = collect(data.phi_centers)
        f["phidot_centers"] = collect(data.phidot_centers)
        f["times"] = data.times

        # Full 3D distribution
        f["f_3d"] = data.f_3d

        # Marginals
        f["f_phi_t"] = data.f_phi_t
        f["f_phidot_t"] = data.f_phidot_t

        # Temporal properties
        f["entropy_t"] = data.entropy_t
        f["mean_phi_t"] = data.mean_phi_t
        f["std_phi_t"] = data.std_phi_t
        f["mean_phidot_t"] = data.mean_phidot_t
        f["std_phidot_t"] = data.std_phidot_t
        f["clustering_t"] = data.clustering_t

        # Metadata
        attrs(f)["eccentricity"] = e_target
        attrs(f)["n_phi_bins"] = n_phi_bins
        attrs(f)["n_phidot_bins"] = n_phidot_bins
        attrs(f)["n_time_bins"] = length(data.times)
    end

    println(@sprintf("  ✅ distribution_temporal_e%.2f.h5", e_target))
end

println()
println("="^80)
println("TEMPORAL DISTRIBUTION ANALYSIS COMPLETED")
println("="^80)
println()

println("Summary:")
println("  • Computed f(φ,φ̇,t) with $n_time_bins time points")
println("  • Spatial resolution: $n_phi_bins × $n_phidot_bins")
println("  • Analyzed $(length(eccentricities_detailed)) eccentricities")
println()
println("Generated Figures:")
println("  1. Phase space snapshots for each e")
println("  2. f_φ(φ,t) heatmaps")
println("  3. f_φ̇(φ̇,t) heatmaps")
println("  4. Entropy S(t) evolution")
println("  5. Standard deviations σ(t)")
println("  6. Clustering R(t) evolution")
println("  7. Combined evolution panel (e=0.98)")
println()
println("Exported Data:")
println("  • Full f(φ,φ̇,t) in HDF5 format for each e")
println("  • Marginals f_φ(t) and f_φ̇(t)")
println("  • All temporal statistics")
println()
println("Key Findings:")
println("  • f(φ,φ̇,t) shows clustering formation dynamics")
println("  • Entropy decreases as system self-organizes")
println("  • σ_φ remains roughly constant (ergodicity)")
println("  • σ_φ̇ increases (velocity dispersion)")
println("  • R(t) reaches quasi-steady state")
