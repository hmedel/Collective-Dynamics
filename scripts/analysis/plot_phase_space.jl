#!/usr/bin/env julia
"""
plot_phase_space.jl

Create visualizations of phase space dynamics:
1. φ(t) trajectories for all particles
2. φ̇(t) trajectories for all particles
3. Phase space (φ, φ̇) evolution
4. Unwrapped φ to see continuous motion
"""

using Pkg
Pkg.activate(".")

include("src/simulation_polar.jl")

using DelimitedFiles
using Statistics
using Printf

# Try to load Plots.jl, fall back to ASCII if not available
PLOTS_AVAILABLE = false
try
    using Plots
    global PLOTS_AVAILABLE = true
    println("✓ Plots.jl available - will create graphical plots")
catch
    println("⚠ Plots.jl not available - using ASCII visualization")
    println("  To get graphical plots: Pkg.add(\"Plots\")")
end

println()

# ============================================================================
# Helper: ASCII phase space visualization
# ============================================================================

function ascii_phase_space(φ_matrix, φ_dot_matrix, title="Phase Space")
    """
    Create ASCII visualization of phase space
    φ_matrix: n_snapshots × n_particles
    φ_dot_matrix: n_snapshots × n_particles
    """
    println(title)
    println("=" ^ 70)

    # Flatten for range calculation
    φ_all = vec(φ_matrix)
    φ_dot_all = vec(φ_dot_matrix)

    φ_min, φ_max = extrema(φ_all)
    φ_dot_min, φ_dot_max = extrema(φ_dot_all)

    width = 60
    height = 20

    # Normalize to [0, 2π] for φ
    φ_range = 2π
    φ_dot_range = φ_dot_max - φ_dot_min

    if φ_dot_range == 0
        println("  (No velocity variation)")
        return
    end

    # Create canvas
    canvas = fill('.', height, width)

    # Plot final snapshot (most compact)
    φ_final = φ_matrix[end, :]
    φ_dot_final = φ_dot_matrix[end, :]

    for i in 1:length(φ_final)
        φ_norm = mod(φ_final[i], 2π)
        col = 1 + Int(floor((width-1) * φ_norm / φ_range))
        row = height - Int(floor((height-1) * (φ_dot_final[i] - φ_dot_min) / φ_dot_range))

        col = clamp(col, 1, width)
        row = clamp(row, 1, height)

        canvas[row, col] = '●'
    end

    # Print
    println(@sprintf("  φ̇ = %.2f", φ_dot_max))
    for row in 1:height
        print("  │")
        println(String(canvas[row, :]))
    end
    println("  └" * "─"^width)
    println("   φ=0" * " "^(width-10) * "φ=2π")
    println(@sprintf("  φ̇ = %.2f", φ_dot_min))
    println()
end

# ============================================================================
# Load and visualize Experiment 2 data (has full snapshots)
# ============================================================================

exp2_dir = "results_experiment_2"

if isdir(exp2_dir)
    println("=" ^ 70)
    println("EXPERIMENT 2: Phase Space Evolution (30s, a/b=2.0)")
    println("=" ^ 70)
    println()

    # We need to reconstruct from saved data
    # Check if we have the simulation data saved
    phase_file = joinpath(exp2_dir, "phase_space_evolution.csv")

    if isfile(phase_file)
        println("Loading phase space evolution data...")
        phase_data = readdlm(phase_file, ',')

        times = phase_data[:, 1]
        σ_φ = phase_data[:, 2]
        mean_φ = phase_data[:, 3]
        σ_φ_dot = phase_data[:, 4]
        mean_φ_dot = phase_data[:, 5]

        println("  Loaded $(length(times)) snapshots")
        println()

        # Plot 1: Dispersion vs time
        if PLOTS_AVAILABLE
            p1 = plot(times, σ_φ,
                     xlabel="Time (s)", ylabel="σ_φ (rad)",
                     title="Spatial Compactification",
                     legend=false, linewidth=2, color=:blue)

            savefig(p1, "plot_sigma_phi_vs_time.png")
            println("  ✓ Saved: plot_sigma_phi_vs_time.png")
        else
            # ASCII version
            println("1. Spatial Compactification σ_φ(t):")
            println("-" ^ 70)
            println(@sprintf("  Initial: %.4f rad", σ_φ[1]))
            println(@sprintf("  Final:   %.4f rad", σ_φ[end]))
            println(@sprintf("  Ratio:   %.4f (%.1f%% reduction)",
                            σ_φ[end]/σ_φ[1], 100*(1 - σ_φ[end]/σ_φ[1])))
            println()

            # Mini ASCII plot
            n_points = min(40, length(times))
            indices = round.(Int, range(1, length(times), length=n_points))

            println("  Time evolution (每点 = $(round(times[end]/n_points, digits=1))s):")
            max_σ = maximum(σ_φ)
            for i in indices
                bar_len = Int(round(40 * σ_φ[i] / max_σ))
                bar = "█"^bar_len
                println(@sprintf("    t=%4.1fs: %s %.4f", times[i], bar, σ_φ[i]))
            end
            println()
        end

        # Plot 2: Mean position migration
        if PLOTS_AVAILABLE
            p2 = plot(times, rad2deg.(mod.(mean_φ, 2π)),
                     xlabel="Time (s)", ylabel="⟨φ⟩ (degrees)",
                     title="Cluster Migration",
                     legend=false, linewidth=2, color=:red)

            savefig(p2, "plot_mean_phi_vs_time.png")
            println("  ✓ Saved: plot_mean_phi_vs_time.png")
        else
            println("2. Cluster Position ⟨φ⟩(t):")
            println("-" ^ 70)
            println(@sprintf("  Initial: %.1f°", rad2deg(mod(mean_φ[1], 2π))))
            println(@sprintf("  Final:   %.1f°", rad2deg(mod(mean_φ[end], 2π))))
            println(@sprintf("  Migration: %.1f°", rad2deg(abs(mean_φ[end] - mean_φ[1]))))
            println()
        end

        # Plot 3: Velocity dispersion
        if PLOTS_AVAILABLE
            p3 = plot(times, σ_φ_dot,
                     xlabel="Time (s)", ylabel="σ_φ̇",
                     title="Velocity Dispersion",
                     legend=false, linewidth=2, color=:green)

            savefig(p3, "plot_sigma_phidot_vs_time.png")
            println("  ✓ Saved: plot_sigma_phidot_vs_time.png")
        else
            println("3. Velocity Dispersion σ_φ̇(t):")
            println("-" ^ 70)
            println(@sprintf("  Initial: %.4f", σ_φ_dot[1]))
            println(@sprintf("  Final:   %.4f", σ_φ_dot[end]))
            println(@sprintf("  Ratio:   %.4f", σ_φ_dot[end]/σ_φ_dot[1]))
            println("  → Velocities do NOT compress (unlike positions)")
            println()
        end
    end

    # Try to load curvature correlation
    curv_file = joinpath(exp2_dir, "curvature_correlation.csv")
    if isfile(curv_file)
        curv_data = readdlm(curv_file, ',')

        φ_bins = curv_data[:, 1]
        κ_values = curv_data[:, 2]
        densities = curv_data[:, 3]

        if PLOTS_AVAILABLE
            p4 = scatter(φ_bins, densities,
                        xlabel="φ (rad)", ylabel="Particle density",
                        title="Final Spatial Distribution",
                        legend=false, markersize=8, color=:purple)
            plot!(p4, φ_bins, densities, linewidth=2, alpha=0.3, color=:purple)

            savefig(p4, "plot_density_vs_phi.png")
            println("  ✓ Saved: plot_density_vs_phi.png")

            # Curvature vs density
            p5 = scatter(κ_values, densities,
                        xlabel="Curvature κ", ylabel="Particle density",
                        title="Density vs Curvature (correlation test)",
                        legend=false, markersize=8, color=:orange)

            savefig(p5, "plot_density_vs_curvature.png")
            println("  ✓ Saved: plot_density_vs_curvature.png")
        else
            println("4. Final Spatial Distribution:")
            println("-" ^ 70)

            # Find max density bin
            max_idx = argmax(densities)
            println(@sprintf("  Peak density at φ = %.2f rad (%.1f°)",
                            φ_bins[max_idx], rad2deg(φ_bins[max_idx])))
            println(@sprintf("  Curvature there: κ = %.4f", κ_values[max_idx]))
            println()

            # Show distribution
            total_particles = sum(densities)
            for i in 1:length(φ_bins)
                count = densities[i]
                if count > 0
                    bar = "█"^Int(round(count))
                    println(@sprintf("  φ=%.2f: %s (%.0f particles)",
                                    φ_bins[i], bar, count))
                end
            end
            println()
        end
    end
end

# ============================================================================
# Create detailed trajectory plots if we can re-run a short simulation
# ============================================================================

println("=" ^ 70)
println("CREATING DETAILED PHASE SPACE PLOTS")
println("=" ^ 70)
println()

println("Running short simulation with full trajectory tracking...")
println("  (10 particles, 10 seconds, for clear visualization)")
println()

using Random
Random.seed!(42)

# Small system for clear trajectories
a, b = 2.0, 1.0
N_viz = 10
mass = 1.0
radius = 0.05
max_time = 10.0
save_interval = 0.05  # Fine-grained for smooth plots

particles = ParticlePolar{Float64}[]
for i in 1:N_viz
    φ = rand() * 2π
    φ_dot = (rand() - 0.5) * 2.0
    push!(particles, ParticlePolar(i, mass, radius, φ, φ_dot, a, b))
end

data = simulate_ellipse_polar_adaptive(
    particles, a, b;
    max_time = max_time,
    dt_max = 1e-5,
    save_interval = save_interval,
    collision_method = :parallel_transport,
    use_projection = true,
    verbose = false
)

println("  Simulation complete: $(length(data.times)) snapshots")
println()

# Extract trajectories
n_snapshots = length(data.times)
n_particles = length(data.particles_history[1])

φ_traj = zeros(n_snapshots, n_particles)
φ_dot_traj = zeros(n_snapshots, n_particles)

for (i, snapshot) in enumerate(data.particles_history)
    for (j, p) in enumerate(snapshot)
        φ_traj[i, j] = p.φ
        φ_dot_traj[i, j] = p.φ_dot
    end
end

# Save trajectory data
traj_dir = "phase_space_plots"
mkpath(traj_dir)

# Save for external plotting
writedlm(joinpath(traj_dir, "times.csv"), data.times, ',')
writedlm(joinpath(traj_dir, "phi_trajectories.csv"), φ_traj, ',')
writedlm(joinpath(traj_dir, "phidot_trajectories.csv"), φ_dot_traj, ',')

println("  ✓ Trajectory data saved to $traj_dir/")
println()

if PLOTS_AVAILABLE
    # Plot 1: φ(t) for all particles
    p_phi = plot(xlabel="Time (s)", ylabel="φ (rad)",
                 title="Angular Position Trajectories",
                 legend=false, size=(800, 600))

    for j in 1:n_particles
        plot!(p_phi, data.times, φ_traj[:, j],
              linewidth=1.5, alpha=0.7)
    end

    savefig(p_phi, joinpath(traj_dir, "phi_vs_time.png"))
    println("  ✓ Saved: $traj_dir/phi_vs_time.png")

    # Plot 2: φ̇(t) for all particles
    p_phidot = plot(xlabel="Time (s)", ylabel="φ̇ (rad/s)",
                    title="Angular Velocity Trajectories",
                    legend=false, size=(800, 600))

    for j in 1:n_particles
        plot!(p_phidot, data.times, φ_dot_traj[:, j],
              linewidth=1.5, alpha=0.7)
    end

    savefig(p_phidot, joinpath(traj_dir, "phidot_vs_time.png"))
    println("  ✓ Saved: $traj_dir/phidot_vs_time.png")

    # Plot 3: Phase space (φ, φ̇) trajectories
    p_phase = plot(xlabel="φ (rad)", ylabel="φ̇ (rad/s)",
                   title="Phase Space Trajectories",
                   legend=false, size=(800, 800),
                   xlims=(0, 2π))

    for j in 1:n_particles
        plot!(p_phase, φ_traj[:, j], φ_dot_traj[:, j],
              linewidth=1, alpha=0.5)
        # Mark initial and final positions
        scatter!(p_phase, [φ_traj[1, j]], [φ_dot_traj[1, j]],
                markersize=8, color=:green, markershape=:circle)
        scatter!(p_phase, [φ_traj[end, j]], [φ_dot_traj[end, j]],
                markersize=8, color=:red, markershape=:star)
    end

    savefig(p_phase, joinpath(traj_dir, "phase_space.png"))
    println("  ✓ Saved: $traj_dir/phase_space.png")

    # Plot 4: Unwrapped φ (continuous, not mod 2π)
    φ_unwrapped = zeros(n_snapshots, n_particles)
    for j in 1:n_particles
        φ_unwrapped[1, j] = φ_traj[1, j]
        for i in 2:n_snapshots
            Δφ = φ_traj[i, j] - φ_traj[i-1, j]
            # Unwrap: if jumped by >π, add/subtract 2π
            if Δφ > π
                Δφ -= 2π
            elseif Δφ < -π
                Δφ += 2π
            end
            φ_unwrapped[i, j] = φ_unwrapped[i-1, j] + Δφ
        end
    end

    p_unwrap = plot(xlabel="Time (s)", ylabel="φ (unwrapped, rad)",
                    title="Continuous Angular Motion",
                    legend=false, size=(800, 600))

    for j in 1:n_particles
        plot!(p_unwrap, data.times, φ_unwrapped[:, j],
              linewidth=1.5, alpha=0.7)
    end

    savefig(p_unwrap, joinpath(traj_dir, "phi_unwrapped.png"))
    println("  ✓ Saved: $traj_dir/phi_unwrapped.png")

    # Plot 5: Animation-style multi-panel showing evolution
    time_indices = [1, div(n_snapshots, 4), div(n_snapshots, 2),
                   div(3*n_snapshots, 4), n_snapshots]

    p_evolution = plot(layout=(1, 5), size=(2000, 400),
                      title=["t=$(round(data.times[i], digits=1))s" for i in time_indices'],
                      xlabel="φ", ylabel="φ̇")

    for (panel, idx) in enumerate(time_indices)
        scatter!(p_evolution[panel],
                mod.(φ_traj[idx, :], 2π), φ_dot_traj[idx, :],
                markersize=10, color=:blue, legend=false,
                xlims=(0, 2π))
    end

    savefig(p_evolution, joinpath(traj_dir, "phase_space_evolution.png"))
    println("  ✓ Saved: $traj_dir/phase_space_evolution.png")

    println()
    println("=" ^ 70)
    println("✅ ALL PLOTS CREATED")
    println("=" ^ 70)
    println()
    println("Graphical plots saved in: $traj_dir/")
    println()
    println("Files created:")
    println("  1. phi_vs_time.png           - φ(t) trajectories")
    println("  2. phidot_vs_time.png        - φ̇(t) trajectories")
    println("  3. phase_space.png           - (φ, φ̇) phase portrait")
    println("  4. phi_unwrapped.png         - Continuous φ(t)")
    println("  5. phase_space_evolution.png - Time evolution panels")
    println()

else
    # ASCII visualization
    println("PHASE SPACE VISUALIZATION (ASCII):")
    println()

    # Show initial state
    ascii_phase_space(φ_traj[1:1, :], φ_dot_traj[1:1, :], "Initial State (t=0)")

    # Show middle state
    mid_idx = div(n_snapshots, 2)
    ascii_phase_space(φ_traj[mid_idx:mid_idx, :], φ_dot_traj[mid_idx:mid_idx, :],
                     "Middle State (t=$(round(data.times[mid_idx], digits=1))s)")

    # Show final state
    ascii_phase_space(φ_traj[end:end, :], φ_dot_traj[end:end, :], "Final State (t=$(max_time)s)")

    println("RAW DATA SAVED:")
    println("  To create plots externally (Python, MATLAB, etc.):")
    println("    - times.csv")
    println("    - phi_trajectories.csv (each column = one particle)")
    println("    - phidot_trajectories.csv")
    println()
    println("  Location: $traj_dir/")
    println()
end

println("=" ^ 70)
println("✅ PHASE SPACE ANALYSIS COMPLETE")
println("=" ^ 70)
println()
