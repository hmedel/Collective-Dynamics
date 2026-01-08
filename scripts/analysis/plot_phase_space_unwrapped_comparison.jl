#!/usr/bin/env julia
# Phase space plots (φ_unwrapped vs φ̇) for different eccentricities

using HDF5
using CairoMakie
using Statistics
using Printf

println("="^80)
println("GENERANDO PLOTS DE ESPACIO FASE (UNWRAPPED)")
println("="^80)
println()

campaign_dir = "results/campaign_eccentricity_scan_20251116_014451"

# Select representative eccentricities
eccentricities = [0.0, 0.5, 0.8, 0.9, 0.95, 0.98, 0.99]

# Function to unwrap angles
function unwrap_angles(phi::Vector{Float64})
    phi_unwrapped = similar(phi)
    phi_unwrapped[1] = phi[1]

    for i in 2:length(phi)
        delta = phi[i] - phi[i-1]

        # Detect wrapping
        if delta > π
            delta -= 2π
        elseif delta < -π
            delta += 2π
        end

        phi_unwrapped[i] = phi_unwrapped[i-1] + delta
    end

    return phi_unwrapped
end

# Create figure with subplots
println("Creando grid de plots...")
fig = Figure(resolution = (1800, 1200))

# Settings
n_cols = 3
n_rows = ceil(Int, length(eccentricities) / n_cols)

colors = [:steelblue, :crimson, :forestgreen, :orange, :purple, :brown, :magenta]

for (idx, e_target) in enumerate(eccentricities)
    println("Procesando e=$e_target...")

    row = div(idx - 1, n_cols) + 1
    col = mod(idx - 1, n_cols) + 1

    ax = Axis(fig[row, col],
        xlabel = "φ (unwrapped)",
        ylabel = "φ̇",
        title = @sprintf("e = %.2f", e_target),
        titlesize = 20
    )

    # Find files for this eccentricity
    e_str = @sprintf("%.3f", e_target)
    files = filter(readdir(campaign_dir, join=true)) do f
        endswith(f, ".h5") && occursin("e$e_str", f)
    end

    if isempty(files)
        # Try with 2 decimals
        e_str = @sprintf("%.2f", e_target)
        files = filter(readdir(campaign_dir, join=true)) do f
            endswith(f, ".h5") && occursin("e$e_str", f)
        end
    end

    n_files = min(length(files), 3)  # Max 3 trajectories per subplot

    if n_files == 0
        text!(ax, 0, 0,
            text = "No data available",
            fontsize = 16,
            align = (:center, :center)
        )
        continue
    end

    println("  Encontrados $n_files archivos")

    # Plot trajectories
    for (file_idx, file) in enumerate(files[1:n_files])
        try
            h5open(file, "r") do f
                # Read all trajectories (all particles)
                phi = read(f["trajectories"]["phi"])  # [N_particles × N_frames]
                phidot = read(f["trajectories"]["phidot"])

                N_particles, N_frames = size(phi)

                # Sample a few particles for clarity
                particles_to_plot = min(5, N_particles)
                particle_indices = round.(Int, range(1, N_particles, length=particles_to_plot))

                for (p_idx, p) in enumerate(particle_indices)
                    phi_unwrap = unwrap_angles(phi[p, :])

                    # Subsample for performance
                    step = max(1, N_frames ÷ 1000)
                    phi_plot = phi_unwrap[1:step:end]
                    phidot_plot = phidot[p, 1:step:end]

                    alpha = file_idx == 1 ? 0.4 : 0.2
                    linewidth = file_idx == 1 ? 1.5 : 1.0

                    lines!(ax, phi_plot, phidot_plot,
                        color = (colors[idx], alpha),
                        linewidth = linewidth
                    )
                end
            end
        catch err
            @warn "Error leyendo $file: $err"
        end
    end

    # Add reference lines
    hlines!(ax, [0.0], color = :gray, linestyle = :dash, linewidth = 1)
end

# Add overall title
Label(fig[0, :],
    text = "Phase Space Evolution: φ (unwrapped) vs φ̇",
    fontsize = 26,
    font = :bold
)

# Save
output_file = joinpath(campaign_dir, "phase_space_unwrapped_comparison.png")
save(output_file, fig, px_per_unit = 2)

println()
println("="^80)
println("✅ Plot guardado: $output_file")
println("="^80)
println()

# ============================================================================
# PLOT 2: Single particle trajectories comparison
# ============================================================================

println("Generando plot de partícula individual...")

fig2 = Figure(resolution = (1400, 1000))

# Plot single particle from each eccentricity
ax2 = Axis(fig2[1, 1],
    xlabel = "φ (unwrapped) [rad]",
    ylabel = "φ̇ [rad/s]",
    title = "Single Particle Trajectories (different e)",
    xlabelsize = 22,
    ylabelsize = 22,
    titlesize = 24
)

legend_entries = []
legend_labels = String[]

for (idx, e_target) in enumerate(eccentricities)
    e_str = @sprintf("%.3f", e_target)
    files = filter(readdir(campaign_dir, join=true)) do f
        endswith(f, ".h5") && occursin("e$e_str", f)
    end

    if isempty(files)
        e_str = @sprintf("%.2f", e_target)
        files = filter(readdir(campaign_dir, join=true)) do f
            endswith(f, ".h5") && occursin("e$e_str", f)
        end
    end

    if !isempty(files)
        h5open(files[1], "r") do f
            phi = read(f["trajectories"]["phi"])
            phidot = read(f["trajectories"]["phidot"])

            # Plot first particle
            phi_unwrap = unwrap_angles(phi[1, :])

            # Subsample
            N_frames = length(phi_unwrap)
            step = max(1, N_frames ÷ 500)
            phi_plot = phi_unwrap[1:step:end]
            phidot_plot = phidot[1, 1:step:end]

            l = lines!(ax2, phi_plot, phidot_plot,
                color = colors[idx],
                linewidth = 2,
                alpha = 0.8
            )

            push!(legend_entries, l)
            push!(legend_labels, @sprintf("e = %.2f", e_target))
        end
    end
end

axislegend(ax2, legend_entries, legend_labels,
    position = :rt,
    labelsize = 14
)

hlines!(ax2, [0.0], color = :gray, linestyle = :dash, linewidth = 1.5)

output_file2 = joinpath(campaign_dir, "phase_space_single_particle_comparison.png")
save(output_file2, fig2, px_per_unit = 2)

println("✅ Plot guardado: $output_file2")
println()

# ============================================================================
# PLOT 3: Final state distribution in phase space
# ============================================================================

println("Generando plot de estado final...")

fig3 = Figure(resolution = (1800, 1200))

for (idx, e_target) in enumerate(eccentricities)
    row = div(idx - 1, n_cols) + 1
    col = mod(idx - 1, n_cols) + 1

    ax = Axis(fig3[row, col],
        xlabel = "φ [rad]",
        ylabel = "φ̇ [rad/s]",
        title = @sprintf("e = %.2f (final state)", e_target),
        titlesize = 18
    )

    e_str = @sprintf("%.3f", e_target)
    files = filter(readdir(campaign_dir, join=true)) do f
        endswith(f, ".h5") && occursin("e$e_str", f)
    end

    if isempty(files)
        e_str = @sprintf("%.2f", e_target)
        files = filter(readdir(campaign_dir, join=true)) do f
            endswith(f, ".h5") && occursin("e$e_str", f)
        end
    end

    # Collect all final states
    phi_final_all = Float64[]
    phidot_final_all = Float64[]

    for file in files[1:min(length(files), 10)]  # Max 10 runs
        try
            h5open(file, "r") do f
                phi = read(f["trajectories"]["phi"])
                phidot = read(f["trajectories"]["phidot"])

                append!(phi_final_all, phi[:, end])
                append!(phidot_final_all, phidot[:, end])
            end
        catch
        end
    end

    if !isempty(phi_final_all)
        scatter!(ax, phi_final_all, phidot_final_all,
            color = (colors[idx], 0.4),
            markersize = 8
        )

        # Add reference lines for clustering regions
        vspan!(ax, 0, π/4, color = (:red, 0.1))
        vspan!(ax, 2π - π/4, 2π, color = (:red, 0.1))
        vspan!(ax, π - π/4, π + π/4, color = (:red, 0.1))

        vspan!(ax, π/2 - π/4, π/2 + π/4, color = (:blue, 0.1))
        vspan!(ax, 3π/2 - π/4, 3π/2 + π/4, color = (:blue, 0.1))

        xlims!(ax, 0, 2π)
    end
end

Label(fig3[0, :],
    text = "Final State Distribution in Phase Space",
    fontsize = 26,
    font = :bold
)

output_file3 = joinpath(campaign_dir, "phase_space_final_states.png")
save(output_file3, fig3, px_per_unit = 2)

println("✅ Plot guardado: $output_file3")
println()

println("="^80)
println("PLOTS COMPLETADOS:")
println("  1. phase_space_unwrapped_comparison.png")
println("  2. phase_space_single_particle_comparison.png")
println("  3. phase_space_final_states.png")
println("="^80)
