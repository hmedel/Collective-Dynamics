#!/usr/bin/env julia
using HDF5
using CairoMakie
using Statistics
using Printf

"""
Plots de espacio fase unwrapped (φ, φ̇):
- Todas las trayectorias de partículas en un solo plot
- φ unwrapped (continuo, sin saltos en 2π)
- Colormap por tiempo para ver evolución
- Identificar clusters en espacio fase
"""

campaign_dir = "results/campaign_eccentricity_scan_20251116_014451"

println("="^70)
println("ANÁLISIS DE ESPACIO FASE UNWRAPPED")
println("="^70)
println()

function unwrap_angle(φ_trajectory)
    """
    Unwrap trayectoria angular:
    - Detecta saltos > π
    - Añade/resta 2π para continuidad
    """
    φ_unwrapped = copy(φ_trajectory)
    offset = 0.0

    for i in 2:length(φ_trajectory)
        dφ = φ_trajectory[i] - φ_trajectory[i-1]

        # Detectar salto
        if dφ > π
            offset -= 2π
        elseif dφ < -π
            offset += 2π
        end

        φ_unwrapped[i] = φ_trajectory[i] + offset
    end

    return φ_unwrapped
end

function plot_phase_space_single_run(filename, e_val, output_name)
    """
    Plot espacio fase de un solo run:
    - Todas las partículas
    - Colormap por tiempo
    """
    h5open(filename, "r") do f
        phi = read(f["trajectories"]["phi"])
        phidot = read(f["trajectories"]["phidot"])
        time = read(f["trajectories"]["time"])

        N_particles, N_frames = size(phi)

        println("  Procesando: N=$N_particles partículas, $(N_frames) frames")

        # Unwrap cada trayectoria de partícula
        phi_unwrapped = similar(phi)
        for i in 1:N_particles
            phi_unwrapped[i, :] = unwrap_angle(phi[i, :])
        end

        # ==================== PLOT 1: Todas las trayectorias ====================

        fig = Figure(size=(1400, 900), fontsize=14)

        # Plot principal: espacio fase completo
        ax = Axis(fig[1:2, 1],
            xlabel = "Angular Position φ (rad, unwrapped)",
            ylabel = "Angular Velocity φ̇ (rad/s)",
            title = "Phase Space Evolution (e=$e_val, N=$N_particles, t_max=$(time[end])s)",
            xlabelsize = 18,
            ylabelsize = 18,
            titlesize = 20
        )

        # Colormap: tiempo
        times_normalized = (time .- time[1]) ./ (time[end] - time[1])
        colors = cgrad(:viridis)

        # Plot cada partícula
        for i in 1:N_particles
            # Submuestrear si hay muchos frames
            step = max(1, div(N_frames, 500))
            indices = 1:step:N_frames

            for j in 1:(length(indices)-1)
                idx1, idx2 = indices[j], indices[j+1]
                t_color = times_normalized[idx1]

                lines!(ax, phi_unwrapped[i, idx1:idx2], phidot[i, idx1:idx2],
                       color=colors[t_color], linewidth=0.8, alpha=0.6)
            end
        end

        # Colorbar
        Colorbar(fig[1, 2], limits=(0, time[end]), colormap=:viridis,
                label="Time (s)", labelsize=16)

        # ==================== PLOT 2: Estado inicial vs final ====================

        ax2 = Axis(fig[2, 2],
            xlabel = "φ (rad)",
            ylabel = "φ̇ (rad/s)",
            title = "Initial vs Final State",
            xlabelsize = 16,
            ylabelsize = 16
        )

        # Estado inicial (t=0)
        scatter!(ax2, phi_unwrapped[:, 1], phidot[:, 1],
                markersize=8, color=(:blue, 0.6), label="t=0s")

        # Estado final (t=t_max)
        scatter!(ax2, phi_unwrapped[:, end], phidot[:, end],
                markersize=8, color=(:red, 0.6), label="t=$(time[end])s")

        axislegend(ax2, position=:rb)

        # ==================== PLOT 3: Proyección φ vs tiempo ====================

        ax3 = Axis(fig[3, 1:2],
            xlabel = "Time (s)",
            ylabel = "φ (rad, unwrapped)",
            title = "Angular Position vs Time",
            xlabelsize = 16,
            ylabelsize = 16
        )

        # Plot todas las trayectorias φ(t)
        for i in 1:N_particles
            lines!(ax3, time, phi_unwrapped[i, :], alpha=0.3, color=:gray, linewidth=0.5)
        end

        # Resaltar algunas trayectorias
        sample_particles = [1, div(N_particles, 2), N_particles]
        for (idx, i) in enumerate(sample_particles)
            lines!(ax3, time, phi_unwrapped[i, :], linewidth=2,
                   label="Particle $i")
        end

        axislegend(ax3, position=:lt, nbanks=3)

        save(output_name, fig, px_per_unit=2)
        println("  ✓ Guardado: $(basename(output_name))")

        # ==================== ANÁLISIS DE CLUSTERS EN ESPACIO FASE ====================

        println("\n  📊 ANÁLISIS DE CLUSTERS (estado final):")

        # Estado final
        φ_final = phi_unwrapped[:, end]
        φ̇_final = phidot[:, end]

        # Normalizar a rango [0, 2π] para análisis
        φ_final_wrapped = mod.(φ_final, 2π)

        # Estadísticas
        @printf("    φ: mean=%.2f, std=%.2f, range=[%.2f, %.2f]\n",
                mean(φ_final_wrapped), std(φ_final_wrapped),
                minimum(φ_final_wrapped), maximum(φ_final_wrapped))
        @printf("    φ̇: mean=%.4f, std=%.4f, range=[%.4f, %.4f]\n",
                mean(φ̇_final), std(φ̇_final),
                minimum(φ̇_final), maximum(φ̇_final))

        # Dispersión en espacio fase
        σ_φ = std(φ_final_wrapped)
        σ_φ̇ = std(φ̇_final)

        @printf("\n    Dispersión espacio fase:\n")
        @printf("      σ_φ = %.3f rad (%.1f°)\n", σ_φ, rad2deg(σ_φ))
        @printf("      σ_φ̇ = %.4f rad/s\n", σ_φ̇)

        # Compacidad relativa (vs estado inicial)
        φ_initial_wrapped = mod.(phi_unwrapped[:, 1], 2π)
        φ̇_initial = phidot[:, 1]
        σ_φ_initial = std(φ_initial_wrapped)
        σ_φ̇_initial = std(φ̇_initial)

        @printf("\n    Compactificación vs t=0:\n")
        @printf("      σ_φ: %.3f → %.3f (%.1f%% cambio)\n",
                σ_φ_initial, σ_φ, 100*(σ_φ - σ_φ_initial)/σ_φ_initial)
        @printf("      σ_φ̇: %.4f → %.4f (%.1f%% cambio)\n",
                σ_φ̇_initial, σ_φ̇, 100*(σ_φ̇ - σ_φ̇_initial)/σ_φ̇_initial)
    end
end

function plot_phase_space_all_runs(e_val, max_runs=5)
    """
    Plot espacio fase combinado de múltiples runs
    """
    e_str = @sprintf("e%.3f", e_val)
    files = filter(readdir(campaign_dir, join=true)) do f
        endswith(f, ".h5") && occursin("_$(e_str)_", f)
    end

    if isempty(files)
        println("  ⚠️  No hay archivos para e=$e_val")
        return
    end

    # Tomar subset de runs
    files_subset = files[1:min(max_runs, length(files))]

    println("\n  Procesando $(length(files_subset)) runs combinados...")

    fig = Figure(size=(1600, 1000), fontsize=14)

    ax = Axis(fig[1, 1],
        xlabel = "Angular Position φ (rad, unwrapped)",
        ylabel = "Angular Velocity φ̇ (rad/s)",
        title = "Phase Space: Multiple Runs (e=$e_val, $(length(files_subset)) runs)",
        xlabelsize = 18,
        ylabelsize = 18,
        titlesize = 20
    )

    colors_runs = cgrad(:tab10, length(files_subset), categorical=true)

    for (run_idx, file) in enumerate(files_subset)
        h5open(file, "r") do f
            phi = read(f["trajectories"]["phi"])
            phidot = read(f["trajectories"]["phidot"])

            N_particles, N_frames = size(phi)

            # Unwrap
            phi_unwrapped = similar(phi)
            for i in 1:N_particles
                phi_unwrapped[i, :] = unwrap_angle(phi[i, :])
            end

            # Plot solo estado final de cada run
            scatter!(ax, phi_unwrapped[:, end], phidot[:, end],
                    markersize=6, alpha=0.7, color=colors_runs[run_idx],
                    label="Run $run_idx")
        end
    end

    axislegend(ax, position=:rt, nbanks=2)

    output_name = joinpath(campaign_dir, "phase_space_multiple_runs_e$(e_val).png")
    save(output_name, fig, px_per_unit=2)
    println("  ✓ Guardado: $(basename(output_name))")
end

# ==================== ANÁLISIS PRINCIPAL ====================

# Analizar runs representativos para cada eccentricidad
eccentricities = [0.5, 0.7, 0.9]

for e_val in eccentricities
    println("\n" * "="^70)
    println("ECCENTRICIDAD: e = $e_val")
    println("="^70)

    e_str = @sprintf("e%.3f", e_val)
    files = filter(readdir(campaign_dir, join=true)) do f
        endswith(f, ".h5") && occursin("_$(e_str)_", f)
    end

    if isempty(files)
        println("  ⚠️  No hay archivos")
        continue
    end

    # Plot primer run (representativo)
    println("\n📊 PLOT RUN INDIVIDUAL:")
    output_single = joinpath(campaign_dir, "phase_space_unwrapped_e$(e_val)_run1.png")
    plot_phase_space_single_run(files[1], e_val, output_single)

    # Plot múltiples runs combinados
    println("\n📊 PLOT MÚLTIPLES RUNS:")
    plot_phase_space_all_runs(e_val, 5)
end

println("\n" * "="^70)
println("ANÁLISIS COMPLETADO")
println("="^70)
println()

println("Archivos generados:")
for e_val in eccentricities
    println("  • phase_space_unwrapped_e$(e_val)_run1.png")
    println("  • phase_space_multiple_runs_e$(e_val).png")
end

println()
println("="^70)
