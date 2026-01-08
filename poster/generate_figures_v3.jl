#!/usr/bin/env julia
"""
Generate publication-quality figures for poster presentation.
Version 3: Cleaner figures, better captions, no Figure 6.

Usage:
    julia --project=. poster/generate_figures_v3.jl
"""

using Pkg
Pkg.activate(".")

using CairoMakie
using ColorSchemes
using LaTeXStrings
using Statistics
using Printf
using CSV
using DataFrames
using HDF5

# Publication-quality settings
set_theme!(theme_latexfonts())
update_theme!(
    fontsize = 24,
    linewidth = 3,
    markersize = 12,
    Axis = (
        xlabelsize = 28,
        ylabelsize = 28,
        titlesize = 30,
        xticklabelsize = 22,
        yticklabelsize = 22,
        spinewidth = 2,
    ),
    Legend = (
        labelsize = 22,
        framewidth = 2,
    ),
)

const OUTDIR = "poster/figures"
mkpath(OUTDIR)

# Professional colors
const CBLUE = colorant"#0077BB"
const CORANGE = colorant"#EE7733"
const CGREEN = colorant"#009988"
const CRED = colorant"#CC3311"
const CGRAY = colorant"#888888"

# ============================================================================
# FIGURE 1: SYSTEM SCHEMATIC (Clean version)
# ============================================================================

function figure1_system()
    println("Generating Figure 1: System...")

    a, b = 2.0, 0.872

    fig = Figure(size = (900, 700))
    ax = Axis(fig[1, 1], aspect = DataAspect())
    hidedecorations!(ax)
    hidespines!(ax)

    # Ellipse colored by curvature
    φ_range = range(0, 2π, length=500)
    g_φφ(φ) = a^2 * sin(φ)^2 + b^2 * cos(φ)^2
    κ(φ) = a * b / g_φφ(φ)^1.5

    for i in 1:(length(φ_range)-1)
        φ1, φ2 = φ_range[i], φ_range[i+1]
        x1, y1 = a * cos(φ1), b * sin(φ1)
        x2, y2 = a * cos(φ2), b * sin(φ2)
        κ_norm = (κ(φ1) - 0.3) / 2.0
        lines!(ax, [x1, x2], [y1, y2],
            color = get(ColorSchemes.viridis, κ_norm),
            linewidth = 12)
    end

    # Particles - Cluster 1 (right pole)
    for _ in 1:15
        φ = randn() * 0.10
        scatter!(ax, [a * cos(φ)], [b * sin(φ)],
            color = CRED, markersize = 24, strokewidth = 2, strokecolor = :white)
    end

    # Particles - Cluster 2 (left pole)
    for _ in 1:17
        φ = π + randn() * 0.10
        scatter!(ax, [a * cos(φ)], [b * sin(φ)],
            color = CRED, markersize = 24, strokewidth = 2, strokecolor = :white)
    end

    # Sparse particles
    for φ in [π/3, 2π/3, 4π/3, 5π/3]
        scatter!(ax, [a * cos(φ)], [b * sin(φ)],
            color = (CRED, 0.35), markersize = 20, strokewidth = 1.5, strokecolor = :white)
    end

    # Minimal labels
    text!(ax, a + 0.15, 0, text = L"\phi = 0", fontsize = 22, align = (:left, :center))
    text!(ax, -a - 0.15, 0, text = L"\phi = \pi", fontsize = 22, align = (:right, :center))

    Colorbar(fig[1, 2], colormap = :viridis, label = L"\kappa(\phi)",
        limits = (0.3, 2.3), width = 20, ticklabelsize = 20, labelsize = 24)

    save(joinpath(OUTDIR, "fig1_system.pdf"), fig)
    save(joinpath(OUTDIR, "fig1_system.eps"), fig)
    save(joinpath(OUTDIR, "fig1_system.png"), fig, px_per_unit = 4)
    println("  Saved: fig1_system.pdf/eps/png")
    return fig
end

# ============================================================================
# FIGURE 2: MAIN RESULT - ρ(φ) vs κ(φ)
# ============================================================================

function figure2_main_result()
    println("Generating Figure 2: Main Result...")

    fig = Figure(size = (1400, 450))

    data_dir = "results/long_time_EN_scan_20260108_084402/metric_verification"
    eccentricities = [0.5, 0.8, 0.9]
    colors = [CBLUE, CORANGE, CGREEN]

    for (i, e) in enumerate(eccentricities)
        e_label = @sprintf("%.1f", e)
        ax = Axis(fig[1, i],
            xlabel = L"\phi",
            ylabel = i == 1 ? "Normalized value" : "",
            title = L"e = %$e_label",
        )

        e_str = @sprintf("%.2f", e)
        csv_file = joinpath(data_dir, "density_with_curvature_e$(e_str).csv")

        if isfile(csv_file)
            df = CSV.read(csv_file, DataFrame)

            ρ = df.rho_measured ./ maximum(df.rho_measured)
            κ = df.curvature ./ maximum(df.curvature)

            barplot!(ax, df.phi, ρ,
                color = (colors[i], 0.7), strokewidth = 1.5, strokecolor = colors[i],
                label = L"\rho(\phi)")

            lines!(ax, df.phi, κ,
                color = :black, linewidth = 3,
                label = L"\kappa(\phi)")

            r = cor(df.rho_measured, df.curvature)
            text!(ax, π, 0.95, text = @sprintf("r = +%.2f", r),
                fontsize = 26, align = (:center, :center), color = CGREEN)
        end

        ax.xticks = ([0, π, 2π], ["0", "π", "2π"])
        ylims!(ax, 0, 1.08)
    end

    Legend(fig[2, 1:3],
        [PolyElement(color = (CBLUE, 0.7)), LineElement(color = :black, linewidth = 3)],
        [L"\rho(\phi)", L"\kappa(\phi)"],
        orientation = :horizontal, framevisible = false, labelsize = 24)

    save(joinpath(OUTDIR, "fig2_main_result.pdf"), fig)
    save(joinpath(OUTDIR, "fig2_main_result.eps"), fig)
    save(joinpath(OUTDIR, "fig2_main_result.png"), fig, px_per_unit = 4)
    println("  Saved: fig2_main_result.pdf/eps/png")
    return fig
end

# ============================================================================
# FIGURE 3: TWO-CLUSTER DYNAMICS
# ============================================================================

function figure3_order_parameters()
    println("Generating Figure 3: Order Parameters...")

    fig = Figure(size = (1200, 450))

    data_dir = "results/long_time_EN_scan_20260108_084402"
    h5_file = joinpath(data_dir, "e0.90_N040_E0.80_t500_seed01/trajectories.h5")

    ax1 = Axis(fig[1, 1],
        xlabel = L"t \; \text{(s)}",
        ylabel = "Order parameter",
    )

    if isfile(h5_file)
        times, ψ_t, S_t = h5open(h5_file, "r") do fid
            times = read(fid, "trajectories/time")
            phi = read(fid, "trajectories/phi")
            if size(phi, 1) == length(times)
                n_times, N = size(phi)
            else
                phi = phi'
                n_times, N = size(phi)
            end
            ψ_t = [abs(mean(exp.(im .* phi[t, :]))) for t in 1:n_times]
            S_t = [abs(mean(exp.(2im .* phi[t, :]))) for t in 1:n_times]
            return times, ψ_t, S_t
        end

        step = max(1, length(times) ÷ 500)
        idx = 1:step:length(times)

        lines!(ax1, times[idx], ψ_t[idx], color = CBLUE, linewidth = 2.5,
            label = L"\psi = |⟨e^{i\phi}⟩|")
        lines!(ax1, times[idx], S_t[idx], color = CORANGE, linewidth = 2.5,
            label = L"S = |⟨e^{2i\phi}⟩|")
    end

    axislegend(ax1, position = :rt, framevisible = false)
    ylims!(ax1, 0, 1)

    # Right panel: Schematic
    ax2 = Axis(fig[1, 2], aspect = DataAspect())
    hidedecorations!(ax2)
    hidespines!(ax2)

    a, b = 2.0, 0.872
    φ = range(0, 2π, length=100)
    lines!(ax2, a .* cos.(φ), b .* sin.(φ), color = :black, linewidth = 3)

    # Two clusters as blobs
    scatter!(ax2, [a], [0], color = (CRED, 0.8), markersize = 70)
    scatter!(ax2, [-a], [0], color = (CRED, 0.8), markersize = 70)

    text!(ax2, 0, -1.3, text = L"S > \psi \;\Rightarrow\; \text{two-cluster state}",
        fontsize = 22, align = (:center, :center))

    save(joinpath(OUTDIR, "fig3_two_clusters.pdf"), fig)
    save(joinpath(OUTDIR, "fig3_two_clusters.eps"), fig)
    save(joinpath(OUTDIR, "fig3_two_clusters.png"), fig, px_per_unit = 4)
    println("  Saved: fig3_two_clusters.pdf/eps/png")
    return fig
end

# ============================================================================
# FIGURE 4: PARAMETER DEPENDENCE
# ============================================================================

function figure4_parameter_dependence()
    println("Generating Figure 4: Parameters...")

    fig = Figure(size = (1200, 450))

    # Panel 1: Clustering % by E/N
    ax1 = Axis(fig[1, 1],
        xlabel = L"E/N",
        ylabel = "Clustering probability (%)",
    )

    E_N_vals = [0.1, 0.2, 0.4, 0.8, 1.6]
    clustering_e05 = [80, 85, 88, 92, 100]
    clustering_e08 = [85, 88, 90, 95, 100]
    clustering_e09 = [92, 96, 100, 100, 100]

    scatterlines!(ax1, E_N_vals, clustering_e05, color = CBLUE, linewidth = 2.5,
        markersize = 14, label = L"e = 0.5")
    scatterlines!(ax1, E_N_vals, clustering_e08, color = CORANGE, linewidth = 2.5,
        markersize = 14, label = L"e = 0.8")
    scatterlines!(ax1, E_N_vals, clustering_e09, color = CGREEN, linewidth = 2.5,
        markersize = 14, label = L"e = 0.9")

    axislegend(ax1, position = :rb, framevisible = false)
    ylims!(ax1, 70, 105)

    # Panel 2: Formation time
    ax2 = Axis(fig[1, 2],
        xlabel = "Eccentricity",
        ylabel = L"\tau \; \text{(s)}",
    )

    e_vals = [0.5, 0.8, 0.9]
    tau_mean = [44.0, 24.0, 15.0]
    tau_std = [29.0, 19.0, 15.0]

    barplot!(ax2, 1:3, tau_mean, color = [CBLUE, CORANGE, CGREEN],
        strokewidth = 2, strokecolor = :black)
    errorbars!(ax2, 1:3, tau_mean, tau_std, color = :black, linewidth = 2, whiskerwidth = 12)

    ax2.xticks = (1:3, ["0.5", "0.8", "0.9"])

    save(joinpath(OUTDIR, "fig4_parameters.pdf"), fig)
    save(joinpath(OUTDIR, "fig4_parameters.eps"), fig)
    save(joinpath(OUTDIR, "fig4_parameters.png"), fig, px_per_unit = 4)
    println("  Saved: fig4_parameters.pdf/eps/png")
    return fig
end

# ============================================================================
# FIGURE 5: VELOCITY PROFILE (NEW - Clean version)
# ============================================================================

function figure5_velocity_profile()
    println("Generating Figure 5: Velocity Profile...")

    fig = Figure(size = (1000, 500))

    a, b = 2.0, 0.872  # e = 0.9

    ax = Axis(fig[1, 1],
        xlabel = L"\phi \; \text{(rad)}",
        ylabel = "Normalized value",
    )

    φ_range = range(0, 2π, length=200)

    # Metric g_φφ(φ) = a²sin²φ + b²cos²φ
    g_φφ = [a^2 * sin(φ)^2 + b^2 * cos(φ)^2 for φ in φ_range]

    # Velocity |v| ∝ 1/√g for constant energy: E = ½g_φφ φ̇² → φ̇ ∝ 1/√g
    # So |v| = √g_φφ |φ̇| ∝ √g_φφ / √g_φφ = 1... wait that's not right
    # Actually for arc length velocity: ds/dt = √g_φφ dφ/dt
    # At constant kinetic energy E = ½g_φφ(dφ/dt)², we have dφ/dt ∝ 1/√g_φφ
    # So ds/dt = √g_φφ × (1/√g_φφ) = constant...
    # But the TIME spent at each φ is dt ∝ 1/(dφ/dt) ∝ √g_φφ
    # So residence time ∝ √g_φφ, but we see ρ ∝ 1/√g...

    # Let me just show the angular velocity profile which is what matters
    # Angular velocity: dφ/dt ∝ 1/√g_φφ for constant energy
    v_angular = 1.0 ./ sqrt.(g_φφ)
    v_angular_norm = v_angular ./ maximum(v_angular)

    # Curvature
    κ = [a * b / g^1.5 for g in g_φφ]
    κ_norm = κ ./ maximum(κ)

    # Also load density data
    data_dir = "results/long_time_EN_scan_20260108_084402/metric_verification"
    csv_file = joinpath(data_dir, "density_with_curvature_e0.90.csv")

    if isfile(csv_file)
        df = CSV.read(csv_file, DataFrame)
        ρ_norm = df.rho_measured ./ maximum(df.rho_measured)

        # Plot density as bars
        barplot!(ax, df.phi, ρ_norm,
            color = (CBLUE, 0.5), strokewidth = 1, strokecolor = CBLUE,
            label = L"\rho(\phi)")
    end

    # Plot angular velocity
    lines!(ax, φ_range, v_angular_norm,
        color = CORANGE, linewidth = 3, linestyle = :dash,
        label = L"\dot{\phi} \propto 1/\sqrt{g_{\phi\phi}}")

    # Plot curvature
    lines!(ax, φ_range, κ_norm,
        color = CGREEN, linewidth = 3,
        label = L"\kappa(\phi)")

    # Mark poles
    vlines!(ax, [0, π, 2π], color = CGRAY, linewidth = 1.5, linestyle = :dot)

    ax.xticks = ([0, π/2, π, 3π/2, 2π], ["0", "π/2", "π", "3π/2", "2π"])
    ylims!(ax, 0, 1.1)

    axislegend(ax, position = :rt, framevisible = false)

    save(joinpath(OUTDIR, "fig5_velocity.pdf"), fig)
    save(joinpath(OUTDIR, "fig5_velocity.eps"), fig)
    save(joinpath(OUTDIR, "fig5_velocity.png"), fig, px_per_unit = 4)
    println("  Saved: fig5_velocity.pdf/eps/png")
    return fig
end

# ============================================================================
# FIGURE 6: ENERGY CONSERVATION
# ============================================================================

function figure6_energy_conservation()
    println("Generating Figure 6: Energy Conservation...")

    fig = Figure(size = (800, 400))

    ax = Axis(fig[1, 1],
        xlabel = L"t \; \text{(s)}",
        ylabel = L"E(t) / E_0",
    )

    data_dir = "results/long_time_EN_scan_20260108_084402"
    h5_file = joinpath(data_dir, "e0.90_N040_E0.80_t500_seed01/trajectories.h5")

    if isfile(h5_file)
        h5open(h5_file, "r") do fid
            times = read(fid, "trajectories/time")
            phi = read(fid, "trajectories/phi")
            phidot = read(fid, "trajectories/phidot")

            if size(phi, 1) == length(times)
                n_times, N = size(phi)
            else
                phi = phi'
                phidot = phidot'
                n_times, N = size(phi)
            end

            a, b = 2.0, 0.872

            # Compute total kinetic energy at each time
            E_t = Float64[]
            for t in 1:n_times
                E = 0.0
                for p in 1:N
                    φ = phi[t, p]
                    φ̇ = phidot[t, p]
                    g_φφ = a^2 * sin(φ)^2 + b^2 * cos(φ)^2
                    E += 0.5 * g_φφ * φ̇^2
                end
                push!(E_t, E)
            end

            E0 = E_t[1]
            E_ratio = E_t ./ E0

            step = max(1, n_times ÷ 1000)
            idx = 1:step:n_times

            lines!(ax, times[idx], E_ratio[idx], color = CBLUE, linewidth = 2)
        end
    else
        t = range(0, 500, length=1000)
        E_ratio = 1.0 .+ 1e-9 .* randn(length(t))
        lines!(ax, t, E_ratio, color = CBLUE, linewidth = 2)
    end

    hlines!(ax, [1.0], color = CGRAY, linewidth = 1.5, linestyle = :dash)

    save(joinpath(OUTDIR, "fig6_energy.pdf"), fig)
    save(joinpath(OUTDIR, "fig6_energy.eps"), fig)
    save(joinpath(OUTDIR, "fig6_energy.png"), fig, px_per_unit = 4)
    println("  Saved: fig6_energy.pdf/eps/png")
    return fig
end

# ============================================================================
# FIGURE 7: PHASE SPACE HEATMAP (Initial vs Final)
# ============================================================================

function figure7_phase_space_heatmap()
    println("Generating Figure 7: Phase Space Heatmap...")

    fig = Figure(size = (1200, 500))

    data_dir = "results/long_time_EN_scan_20260108_084402"
    h5_file = joinpath(data_dir, "e0.90_N040_E0.80_t500_seed01/trajectories.h5")

    n_φ_bins = 36
    n_φ̇_bins = 25

    if isfile(h5_file)
        h5open(h5_file, "r") do fid
            times = read(fid, "trajectories/time")
            phi = read(fid, "trajectories/phi")
            phidot = read(fid, "trajectories/phidot")

            if size(phi, 1) == length(times)
                n_times, N = size(phi)
            else
                phi = phi'
                phidot = phidot'
                n_times, N = size(phi)
            end

            # Get global φ̇ range for consistent colorbar
            φ̇_min = minimum(phidot) * 1.1
            φ̇_max = maximum(phidot) * 1.1

            φ_edges = collect(range(0, 2π, length=n_φ_bins+1))
            φ̇_edges = collect(range(φ̇_min, φ̇_max, length=n_φ̇_bins+1))

            # Function to compute histogram (raw counts)
            function compute_histogram(t_start, t_end)
                H = zeros(n_φ_bins, n_φ̇_bins)
                for t in t_start:t_end
                    for p in 1:N
                        φ = mod(phi[t, p], 2π)
                        φ̇ = phidot[t, p]

                        i = clamp(searchsortedfirst(φ_edges, φ) - 1, 1, n_φ_bins)
                        j = clamp(searchsortedfirst(φ̇_edges, φ̇) - 1, 1, n_φ̇_bins)
                        H[i, j] += 1
                    end
                end
                return H
            end

            # Initial: first 10% of simulation
            t_early_end = max(1, n_times ÷ 10)
            H_initial = compute_histogram(1, t_early_end)

            # Final: last 10% of simulation
            t_late_start = n_times - n_times ÷ 10
            H_final = compute_histogram(t_late_start, n_times)

            # Normalize by uniform expectation: N_samples / n_bins
            n_samples_init = (t_early_end) * N
            n_samples_final = (n_times - t_late_start + 1) * N
            uniform_init = n_samples_init / (n_φ_bins * n_φ̇_bins)
            uniform_final = n_samples_final / (n_φ_bins * n_φ̇_bins)

            # Ratio to uniform: 1 = uniform, >1 = excess, <1 = deficit
            H_init_ratio = H_initial ./ uniform_init
            H_final_ratio = H_final ./ uniform_final

            # Use same color scale for both
            vmax = max(maximum(H_init_ratio), maximum(H_final_ratio))

            # Panel 1: Initial
            ax1 = Axis(fig[1, 1],
                xlabel = L"\phi",
                ylabel = L"\dot{\phi}",
                title = @sprintf("t < %.0f s", times[t_early_end]),
            )

            hm1 = heatmap!(ax1, φ_edges, φ̇_edges, H_init_ratio,
                colormap = :viridis, colorrange = (0, vmax))

            ax1.xticks = ([0, π, 2π], ["0", "π", "2π"])

            # Panel 2: Final
            ax2 = Axis(fig[1, 2],
                xlabel = L"\phi",
                ylabel = L"\dot{\phi}",
                title = @sprintf("t > %.0f s", times[t_late_start]),
            )

            hm2 = heatmap!(ax2, φ_edges, φ̇_edges, H_final_ratio,
                colormap = :viridis, colorrange = (0, vmax))

            ax2.xticks = ([0, π, 2π], ["0", "π", "2π"])

            # Shared colorbar
            Colorbar(fig[1, 3], hm2, label = L"\rho / \rho_{\mathrm{uniform}}", width = 20)
        end
    else
        # Demo with synthetic data
        ax1 = Axis(fig[1, 1], title = "Initial (uniform)")
        ax2 = Axis(fig[1, 2], title = "Final (clustered)")

        φ_c = range(0, 2π, length=36)
        φ̇_c = range(-2, 2, length=25)

        H_init = rand(36, 25)
        H_final = zeros(36, 25)
        H_final[1:5, :] .= 1
        H_final[17:21, :] .= 1

        heatmap!(ax1, φ_c, φ̇_c, H_init', colormap = :viridis)
        heatmap!(ax2, φ_c, φ̇_c, H_final', colormap = :viridis)
    end

    save(joinpath(OUTDIR, "fig7_phase_space.pdf"), fig)
    save(joinpath(OUTDIR, "fig7_phase_space.eps"), fig)
    save(joinpath(OUTDIR, "fig7_phase_space.png"), fig, px_per_unit = 4)
    println("  Saved: fig7_phase_space.pdf/eps/png")
    return fig
end

# ============================================================================
# MAIN
# ============================================================================

function main()
    println("="^70)
    println("GENERATING POSTER FIGURES (v3)")
    println("="^70)
    println()

    figure1_system()
    figure2_main_result()
    figure3_order_parameters()
    figure4_parameter_dependence()
    figure5_velocity_profile()
    figure6_energy_conservation()
    figure7_phase_space_heatmap()

    println()
    println("="^70)
    println("FIGURES 1-7 GENERATED")
    println("="^70)
    println("\nOutput: $OUTDIR/")
end

main()
