#!/usr/bin/env julia
# Detailed phase space plot for e=0.90, N=80, all particles, temporal evolution

using HDF5
using CairoMakie
using Statistics
using Printf
using StatsBase

println("="^80)
println("PLOT DETALLADO: Espacio Fase e=0.90 (N=80, todas las partículas)")
println("="^80)
println()

campaign_dir = "results/campaign_eccentricity_scan_20251116_014451"

# Find e=0.90 files
files = filter(readdir(campaign_dir, join=true)) do f
    endswith(f, ".h5") && occursin("e0.900", f)
end

if isempty(files)
    println("❌ No se encontraron archivos para e=0.90")
    exit(1)
end

println("Archivos encontrados: $(length(files))")
println("Usando: $(basename(files[1]))")
println()

# Unwrap function
function unwrap_angles(phi::Vector{Float64})
    phi_unwrapped = similar(phi)
    phi_unwrapped[1] = phi[1]

    for i in 2:length(phi)
        delta = phi[i] - phi[i-1]
        if delta > π
            delta -= 2π
        elseif delta < -π
            delta += 2π
        end
        phi_unwrapped[i] = phi_unwrapped[i-1] + delta
    end

    return phi_unwrapped
end

# Read data
h5open(files[1], "r") do f
    phi = read(f["trajectories"]["phi"])  # [N_particles × N_frames]
    phidot = read(f["trajectories"]["phidot"])
    time = read(f["trajectories"]["time"])

    N_particles, N_frames = size(phi)

    println("Datos cargados:")
    println("  N_particles: $N_particles")
    println("  N_frames: $N_frames")
    println("  Tiempo total: $(time[end]) s")
    println()

    # ========================================================================
    # PLOT 1: Todas las trayectorias con gradiente temporal
    # ========================================================================

    println("Generando Plot 1: Todas las trayectorias con color temporal...")

    fig1 = Figure(size = (1400, 1000))

    ax1 = Axis(fig1[1, 1],
        xlabel = "φ (unwrapped) [rad]",
        ylabel = "φ̇ [rad/s]",
        title = "Phase Space Evolution: e=0.90, N=80 (all particles)",
        xlabelsize = 24,
        ylabelsize = 24,
        titlesize = 26
    )

    # Subsample for performance (plot every N-th point)
    subsample_factor = max(1, N_frames ÷ 2000)

    println("  Subsampling: cada $subsample_factor frames")

    # Plot each particle with time-based color
    for p in 1:N_particles
        phi_unwrap = unwrap_angles(phi[p, :])

        # Subsample
        indices = 1:subsample_factor:N_frames
        phi_plot = phi_unwrap[indices]
        phidot_plot = phidot[p, indices]
        time_plot = time[indices]

        # Use scatterlines with color mapped to time
        scatterlines!(ax1, phi_plot, phidot_plot,
            color = time_plot,
            colormap = :viridis,
            linewidth = 0.8,
            markersize = 0,
            alpha = 0.4
        )
    end

    # Add colorbar
    Colorbar(fig1[1, 2],
        limits = (time[1], time[end]),
        colormap = :viridis,
        label = "Time [s]",
        labelsize = 22
    )

    # Reference line
    hlines!(ax1, [0.0], color = :white, linestyle = :dash, linewidth = 2, alpha = 0.5)

    output1 = joinpath(campaign_dir, "e090_phase_space_all_particles_temporal.png")
    save(output1, fig1, px_per_unit = 2)
    println("  ✅ $output1")
    println()

    # ========================================================================
    # PLOT 2: Snapshots en diferentes tiempos
    # ========================================================================

    println("Generando Plot 2: Snapshots en diferentes tiempos...")

    fig2 = Figure(size = (1800, 1200))

    # Select time snapshots
    n_snapshots = 6
    snapshot_indices = round.(Int, range(1, N_frames, length=n_snapshots))

    n_cols = 3
    n_rows = 2

    for (idx, snap_idx) in enumerate(snapshot_indices)
        row = div(idx - 1, n_cols) + 1
        col = mod(idx - 1, n_cols) + 1

        ax = Axis(fig2[row, col],
            xlabel = "φ [rad]",
            ylabel = "φ̇ [rad/s]",
            title = @sprintf("t = %.1f s", time[snap_idx]),
            titlesize = 20
        )

        # Plot all particles at this time
        phi_snap = phi[:, snap_idx]
        phidot_snap = phidot[:, snap_idx]

        scatter!(ax, phi_snap, phidot_snap,
            color = :steelblue,
            markersize = 12,
            strokewidth = 1,
            strokecolor = :black,
            alpha = 0.7
        )

        # Mark clustering regions
        vspan!(ax, 0, π/4, color = (:red, 0.1))
        vspan!(ax, π - π/4, π + π/4, color = (:red, 0.1))
        vspan!(ax, 2π - π/4, 2π, color = (:red, 0.1))

        vspan!(ax, π/2 - π/4, π/2 + π/4, color = (:blue, 0.1))
        vspan!(ax, 3π/2 - π/4, 3π/2 + π/4, color = (:blue, 0.1))

        xlims!(ax, 0, 2π)
        hlines!(ax, [0.0], color = :gray, linestyle = :dash, linewidth = 1)
    end

    Label(fig2[0, :],
        text = "Phase Space Snapshots: e=0.90, N=80",
        fontsize = 26,
        font = :bold
    )

    output2 = joinpath(campaign_dir, "e090_phase_space_snapshots.png")
    save(output2, fig2, px_per_unit = 2)
    println("  ✅ $output2")
    println()

    # ========================================================================
    # PLOT 3: Trayectorias individuales destacadas + todas en background
    # ========================================================================

    println("Generando Plot 3: Partículas destacadas sobre fondo...")

    fig3 = Figure(size = (1400, 1000))

    ax3 = Axis(fig3[1, 1],
        xlabel = "φ (unwrapped) [rad]",
        ylabel = "φ̇ [rad/s]",
        title = "Phase Space: Selected Particles (e=0.90)",
        xlabelsize = 24,
        ylabelsize = 24,
        titlesize = 26
    )

    # Plot all particles in gray (background)
    for p in 1:N_particles
        phi_unwrap = unwrap_angles(phi[p, :])

        indices = 1:subsample_factor:N_frames
        phi_plot = phi_unwrap[indices]
        phidot_plot = phidot[p, indices]

        lines!(ax3, phi_plot, phidot_plot,
            color = (:gray, 0.15),
            linewidth = 0.5
        )
    end

    # Highlight specific particles
    particles_to_highlight = [1, 20, 40, 60, 80]
    colors_highlight = [:red, :blue, :green, :orange, :purple]

    for (i, p) in enumerate(particles_to_highlight)
        phi_unwrap = unwrap_angles(phi[p, :])

        indices = 1:subsample_factor:N_frames
        phi_plot = phi_unwrap[indices]
        phidot_plot = phidot[p, indices]

        lines!(ax3, phi_plot, phidot_plot,
            color = colors_highlight[i],
            linewidth = 2.5,
            alpha = 0.8,
            label = "Particle $p"
        )

        # Mark initial position
        scatter!(ax3, [phi_plot[1]], [phidot_plot[1]],
            color = colors_highlight[i],
            marker = :circle,
            markersize = 15,
            strokewidth = 2,
            strokecolor = :black
        )

        # Mark final position
        scatter!(ax3, [phi_plot[end]], [phidot_plot[end]],
            color = colors_highlight[i],
            marker = :star5,
            markersize = 18,
            strokewidth = 2,
            strokecolor = :black
        )
    end

    hlines!(ax3, [0.0], color = :black, linestyle = :dash, linewidth = 2, alpha = 0.3)

    axislegend(ax3, position = :rt, labelsize = 14)

    output3 = joinpath(campaign_dir, "e090_phase_space_highlighted_particles.png")
    save(output3, fig3, px_per_unit = 2)
    println("  ✅ $output3")
    println()

    # ========================================================================
    # PLOT 4: Densidad en espacio fase (heatmap)
    # ========================================================================

    println("Generando Plot 4: Mapa de densidad en espacio fase...")

    fig4 = Figure(size = (1400, 1000))

    ax4 = Axis(fig4[1, 1],
        xlabel = "φ [rad]",
        ylabel = "φ̇ [rad/s]",
        title = "Phase Space Density: e=0.90 (final state)",
        xlabelsize = 24,
        ylabelsize = 24,
        titlesize = 26
    )

    # Use final state
    phi_final = phi[:, end]
    phidot_final = phidot[:, end]

    # Create 2D histogram
    nbins_phi = 50
    nbins_phidot = 50

    phi_edges = range(0, 2π, length=nbins_phi+1)
    phidot_edges = range(minimum(phidot_final)*1.2, maximum(phidot_final)*1.2, length=nbins_phidot+1)

    h = fit(Histogram, (phi_final, phidot_final), (phi_edges, phidot_edges))

    # Create grid centers
    phi_centers = [(phi_edges[i] + phi_edges[i+1])/2 for i in 1:nbins_phi]
    phidot_centers = [(phidot_edges[i] + phidot_edges[i+1])/2 for i in 1:nbins_phidot]

    heatmap!(ax4,
        phi_centers,
        phidot_centers,
        h.weights',
        colormap = :hot
    )

    # Overlay scatter
    scatter!(ax4, phi_final, phidot_final,
        color = (:white, 0.3),
        markersize = 8,
        strokewidth = 0.5,
        strokecolor = :white
    )

    # Mark clustering regions
    vlines!(ax4, [0, π/2, π, 3π/2, 2π], color = :cyan, linestyle = :dash, linewidth = 2, alpha = 0.5)
    hlines!(ax4, [0.0], color = :cyan, linestyle = :dash, linewidth = 2, alpha = 0.5)

    Colorbar(fig4[1, 2],
        limits = (0, maximum(h.weights)),
        colormap = :hot,
        label = "Particle count",
        labelsize = 22
    )

    xlims!(ax4, 0, 2π)

    output4 = joinpath(campaign_dir, "e090_phase_space_density.png")
    save(output4, fig4, px_per_unit = 2)
    println("  ✅ $output4")
    println()

    # ========================================================================
    # PLOT 5: Evolución temporal completa (unwrapped, todas las partículas)
    # ========================================================================

    println("Generando Plot 5: Evolución completa unwrapped...")

    fig5 = Figure(size = (1600, 1000))

    ax5 = Axis(fig5[1, 1],
        xlabel = "φ (unwrapped) [rad]",
        ylabel = "φ̇ [rad/s]",
        title = "Complete Phase Space Evolution: e=0.90, N=80",
        xlabelsize = 24,
        ylabelsize = 24,
        titlesize = 26
    )

    # Plot all particles with semi-transparency
    for p in 1:N_particles
        phi_unwrap = unwrap_angles(phi[p, :])

        # Use more points for smoothness
        subsample = max(1, N_frames ÷ 1000)
        indices = 1:subsample:N_frames

        lines!(ax5, phi_unwrap[indices], phidot[p, indices],
            color = (:steelblue, 0.3),
            linewidth = 1.0
        )

        # Mark initial and final
        scatter!(ax5, [phi_unwrap[1]], [phidot[p, 1]],
            color = :green,
            markersize = 6,
            alpha = 0.5
        )

        scatter!(ax5, [phi_unwrap[end]], [phidot[p, end]],
            color = :red,
            markersize = 6,
            alpha = 0.5
        )
    end

    hlines!(ax5, [0.0], color = :black, linestyle = :dash, linewidth = 2)

    # Add legend
    scatter!(ax5, [NaN], [NaN], color = :green, markersize = 12, label = "Initial state")
    scatter!(ax5, [NaN], [NaN], color = :red, markersize = 12, label = "Final state")
    axislegend(ax5, position = :rt, labelsize = 16)

    output5 = joinpath(campaign_dir, "e090_phase_space_complete_unwrapped.png")
    save(output5, fig5, px_per_unit = 2)
    println("  ✅ $output5")
    println()

    # ========================================================================
    # Print statistics
    # ========================================================================

    println("="^80)
    println("ESTADÍSTICAS DEL ESPACIO FASE:")
    println("="^80)
    println()

    # Initial state
    phi_init = phi[:, 1]
    phidot_init = phidot[:, 1]

    println("Estado inicial (t=0):")
    @printf("  φ:   mean=%.3f, std=%.3f, range=[%.3f, %.3f]\n",
            mean(phi_init), std(phi_init), minimum(phi_init), maximum(phi_init))
    @printf("  φ̇:  mean=%.3f, std=%.3f, range=[%.3f, %.3f]\n",
            mean(phidot_init), std(phidot_init), minimum(phidot_init), maximum(phidot_init))
    println()

    # Final state
    println("Estado final (t=$(time[end])):")
    @printf("  φ:   mean=%.3f, std=%.3f, range=[%.3f, %.3f]\n",
            mean(phi_final), std(phi_final), minimum(phi_final), maximum(phi_final))
    @printf("  φ̇:  mean=%.3f, std=%.3f, range=[%.3f, %.3f]\n",
            mean(phidot_final), std(phidot_final), minimum(phidot_final), maximum(phidot_final))
    println()

    # Clustering analysis
    bin_width = π/4
    n_mayor = count(φ -> (φ < bin_width || φ > 2π - bin_width ||
                          abs(φ - π) < bin_width), phi_final)
    n_menor = count(φ -> abs(φ - π/2) < bin_width ||
                          abs(φ - 3π/2) < bin_width, phi_final)
    R = n_mayor / max(n_menor, 1)

    println("Clustering (estado final):")
    @printf("  Partículas en eje mayor: %d / %d (%.1f%%)\n", n_mayor, N_particles, 100*n_mayor/N_particles)
    @printf("  Partículas en eje menor: %d / %d (%.1f%%)\n", n_menor, N_particles, 100*n_menor/N_particles)
    @printf("  Clustering ratio R: %.2f\n", R)
    println()

    # Order parameter
    mean_cos = mean(cos.(phi_final))
    mean_sin = mean(sin.(phi_final))
    Psi = sqrt(mean_cos^2 + mean_sin^2)

    @printf("Order parameter Ψ: %.4f\n", Psi)
    println()

    println("="^80)
end

println()
println("="^80)
println("PLOTS COMPLETADOS:")
println("="^80)
println()
println("  1. e090_phase_space_all_particles_temporal.png")
println("     → Todas las trayectorias con gradiente de color temporal")
println()
println("  2. e090_phase_space_snapshots.png")
println("     → 6 snapshots en diferentes tiempos")
println()
println("  3. e090_phase_space_highlighted_particles.png")
println("     → 5 partículas destacadas sobre fondo")
println()
println("  4. e090_phase_space_density.png")
println("     → Mapa de densidad (heatmap) del estado final")
println()
println("  5. e090_phase_space_complete_unwrapped.png")
println("     → Evolución completa unwrapped (todas las partículas)")
println()
println("="^80)
