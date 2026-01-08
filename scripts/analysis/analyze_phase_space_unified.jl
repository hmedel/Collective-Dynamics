#!/usr/bin/env julia
# Unified Phase Space Analysis
# Creates a single phase space plot with ALL particles from ALL seeds projected

using Pkg
Pkg.activate(".")

using HDF5
using Statistics
using Printf
using Plots
gr()

const CAMPAIGN_DIR = "results/intrinsic_v3_campaign_20251126_110434"
const OUTPUT_DIR = "results/analysis_complete"

println("="^60)
println("UNIFIED PHASE SPACE ANALYSIS")
println("="^60)

function load_trajectories(campaign_dir, e, N, seed)
    dir_name = @sprintf("e%.2f_N%03d_seed%02d", e, N, seed)
    h5_path = joinpath(campaign_dir, dir_name, "trajectories.h5")

    if !isfile(h5_path)
        return nothing
    end

    h5open(h5_path, "r") do f
        traj = f["trajectories"]
        theta = read(traj, "phi")
        theta_dot = read(traj, "phidot")
        time = read(traj, "time")
        return (theta=theta, theta_dot=theta_dot, time=time)
    end
end

function unwrap_angle(theta_series)
    unwrapped = similar(theta_series)
    unwrapped[1] = theta_series[1]

    for i in 2:length(theta_series)
        diff = theta_series[i] - theta_series[i-1]
        if diff > π
            diff -= 2π
        elseif diff < -π
            diff += 2π
        end
        unwrapped[i] = unwrapped[i-1] + diff
    end

    return unwrapped
end

# ============================================================================
# Figure A: Single unified phase space per eccentricity (ALL particles, ALL seeds)
# ============================================================================
println("\nCreating unified phase space plots...")

N_fixed = 50
n_seeds = 10

for e in [0.5, 0.7, 0.8, 0.9]
    println("  Processing e = $e...")

    p = plot(xlabel="θ (unwrapped, radians)", ylabel="θ̇ (angular velocity)",
        title="Unified Phase Space: e=$e, N=$N_fixed\n(All particles from $n_seeds seeds)",
        legend=false, size=(1200, 800), dpi=200)

    # Collect all trajectories
    all_theta = Float64[]
    all_theta_dot = Float64[]

    for seed in 1:n_seeds
        traj = load_trajectories(CAMPAIGN_DIR, e, N_fixed, seed)
        if isnothing(traj)
            continue
        end

        n_particles = size(traj.theta, 1)
        n_times = size(traj.theta, 2)
        step = max(1, n_times ÷ 200)  # Subsample heavily for clarity
        idx = 1:step:n_times

        for part in 1:n_particles
            theta_unwrapped = unwrap_angle(traj.theta[part, :])
            append!(all_theta, theta_unwrapped[idx])
            append!(all_theta_dot, traj.theta_dot[part, idx])
        end
    end

    # Create 2D histogram for density visualization
    scatter!(p, all_theta, all_theta_dot,
        markersize=0.3, markerstrokewidth=0, alpha=0.3,
        color=:black, label="")

    savefig(p, joinpath(OUTPUT_DIR, "unified_phase_space_e$(Int(e*10)).png"))
end

println("  Saved unified phase space plots")

# ============================================================================
# Figure B: Combined 4-panel unified phase space
# ============================================================================
println("\nCreating combined 4-panel figure...")

plots_array = []

for e in [0.5, 0.7, 0.8, 0.9]
    p = plot(xlabel="θ", ylabel="θ̇",
        title="e = $e",
        legend=false)

    for seed in 1:5  # Use 5 seeds for clarity
        traj = load_trajectories(CAMPAIGN_DIR, e, N_fixed, seed)
        if isnothing(traj)
            continue
        end

        n_particles = size(traj.theta, 1)
        n_times = size(traj.theta, 2)
        step = max(1, n_times ÷ 300)
        idx = 1:step:n_times

        particle_colors = cgrad(:turbo, n_particles, categorical=true)

        for part in 1:n_particles
            theta_unwrapped = unwrap_angle(traj.theta[part, :])
            plot!(p, theta_unwrapped[idx], traj.theta_dot[part, idx],
                color=particle_colors[part], alpha=0.4, linewidth=0.5,
                label="")
        end
    end

    push!(plots_array, p)
end

fig_combined = plot(plots_array..., layout=(2,2), size=(1400, 1200), dpi=200,
    plot_title="Unified Phase Space: All Particles Projected (N=$N_fixed, 5 seeds each)")
savefig(fig_combined, joinpath(OUTPUT_DIR, "fig9_unified_phase_space_comparison.png"))
println("  Saved fig9_unified_phase_space_comparison.png")

# ============================================================================
# Figure C: Phase portrait evolution (snapshots in time)
# ============================================================================
println("\nCreating phase portrait evolution...")

function plot_snapshot(traj, t_idx, e, a)
    b_eff = a * sqrt(1 - e^2)
    n_particles = size(traj.theta, 1)

    θ = traj.theta[:, t_idx]
    θ_dot = traj.theta_dot[:, t_idx]

    p = plot(xlabel="θ", ylabel="θ̇", title="t = $(round(traj.time[t_idx], digits=2))",
        legend=false, xlim=(-0.5, 2π+0.5), aspect_ratio=:auto)

    # Color by position
    colors = cgrad(:viridis, n_particles, categorical=true)

    for i in 1:n_particles
        scatter!(p, [mod(θ[i], 2π)], [θ_dot[i]],
            color=colors[i], markersize=8, markerstrokewidth=0.5)
    end

    return p
end

a = 2.0
e_snapshot = 0.9

traj = load_trajectories(CAMPAIGN_DIR, e_snapshot, 50, 1)
if !isnothing(traj)
    n_times = size(traj.theta, 2)

    # Select 6 time snapshots
    time_indices = round.(Int, range(1, n_times, length=6))

    snapshot_plots = [plot_snapshot(traj, t_idx, e_snapshot, a) for t_idx in time_indices]

    fig_evolution = plot(snapshot_plots..., layout=(2,3), size=(1400, 800), dpi=200,
        plot_title="Phase Space Evolution: e=$e_snapshot, N=50")
    savefig(fig_evolution, joinpath(OUTPUT_DIR, "fig10_phase_evolution.png"))
    println("  Saved fig10_phase_evolution.png")
end

# ============================================================================
# Figure D: Curvature-density correlation quantitative
# ============================================================================
println("\nCreating curvature-density correlation analysis...")

function curvature_ellipse(θ, a, b)
    return a * b / (a^2 * sin(θ)^2 + b^2 * cos(θ)^2)^1.5
end

a = 2.0
n_bins = 36  # 10-degree bins

correlation_data = []

for e in [0.5, 0.7, 0.8, 0.9]
    b_eff = a * sqrt(1 - e^2)

    # Compute curvature in each bin
    bin_edges = range(0, 2π, length=n_bins+1)
    bin_centers = (bin_edges[1:end-1] .+ bin_edges[2:end]) ./ 2
    curvatures = [curvature_ellipse(θ, a, b_eff) for θ in bin_centers]

    # Collect particle positions from all seeds
    all_theta_final = Float64[]

    for seed in 1:10
        traj = load_trajectories(CAMPAIGN_DIR, e, 50, seed)
        if !isnothing(traj)
            append!(all_theta_final, mod.(traj.theta[:, end], 2π))
        end
    end

    # Compute density in each bin
    densities = zeros(n_bins)
    for θ in all_theta_final
        bin_idx = min(n_bins, max(1, ceil(Int, θ / (2π / n_bins))))
        densities[bin_idx] += 1
    end
    densities ./= sum(densities)  # Normalize

    # Compute correlation
    corr = cor(curvatures, densities)

    push!(correlation_data, (e=e, curvatures=curvatures, densities=densities,
        bin_centers=bin_centers, correlation=corr))
end

# Plot
p_corr = plot(xlabel="θ (radians)", ylabel="Value (normalized)",
    title="Curvature vs Particle Density", legend=:topright)

colors_e = [:blue, :green, :orange, :red]

for (idx, data) in enumerate(correlation_data)
    # Normalize curvature for comparison
    κ_norm = data.curvatures ./ maximum(data.curvatures)
    ρ_norm = data.densities ./ maximum(data.densities)

    plot!(p_corr, data.bin_centers, κ_norm,
        color=colors_e[idx], linewidth=2, linestyle=:solid,
        label="κ (e=$(data.e))")
    plot!(p_corr, data.bin_centers, ρ_norm,
        color=colors_e[idx], linewidth=2, linestyle=:dash,
        label="ρ (e=$(data.e))")
end

# Scatter plot of correlation
p_scatter = plot(xlabel="Curvature κ (normalized)", ylabel="Density ρ (normalized)",
    title="Curvature-Density Correlation", legend=:topleft)

for (idx, data) in enumerate(correlation_data)
    κ_norm = data.curvatures ./ maximum(data.curvatures)
    ρ_norm = data.densities ./ maximum(data.densities)

    scatter!(p_scatter, κ_norm, ρ_norm,
        color=colors_e[idx], markersize=6,
        label="e=$(data.e), r=$(round(data.correlation, digits=3))")
end

# Add trend line for e=0.9
if length(correlation_data) >= 4
    data = correlation_data[4]
    κ_norm = data.curvatures ./ maximum(data.curvatures)
    ρ_norm = data.densities ./ maximum(data.densities)
    slope = cor(κ_norm, ρ_norm) * std(ρ_norm) / std(κ_norm)
    intercept = mean(ρ_norm) - slope * mean(κ_norm)
    x_line = range(0, 1, length=50)
    y_line = slope .* x_line .+ intercept
    plot!(p_scatter, x_line, y_line, color=:red, linewidth=2, linestyle=:dot, label="Trend (e=0.9)")
end

fig_corr = plot(p_corr, p_scatter, layout=(1,2), size=(1400, 500), dpi=200)
savefig(fig_corr, joinpath(OUTPUT_DIR, "fig11_curvature_density_correlation.png"))
println("  Saved fig11_curvature_density_correlation.png")

# Print correlation coefficients
println("\n" * "="^60)
println("CURVATURE-DENSITY CORRELATION COEFFICIENTS")
println("="^60)
for data in correlation_data
    println("  e = $(data.e): r = $(round(data.correlation, digits=4))")
end

# ============================================================================
# Summary
# ============================================================================
println("\n" * "="^60)
println("NEW FIGURES GENERATED:")
println("="^60)
println("  • unified_phase_space_e5.png  (e=0.5)")
println("  • unified_phase_space_e7.png  (e=0.7)")
println("  • unified_phase_space_e8.png  (e=0.8)")
println("  • unified_phase_space_e9.png  (e=0.9)")
println("  • fig9_unified_phase_space_comparison.png")
println("  • fig10_phase_evolution.png")
println("  • fig11_curvature_density_correlation.png")
println("="^60)
