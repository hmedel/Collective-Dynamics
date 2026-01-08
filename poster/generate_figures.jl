#!/usr/bin/env julia
"""
Generate publication-quality figures for poster presentation.
Uses CairoMakie for vector graphics output.

Usage:
    julia --project=. poster/generate_figures.jl
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

# Set publication-quality defaults
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
        xgridwidth = 1,
        ygridwidth = 1,
    ),
    Legend = (
        labelsize = 22,
        framewidth = 2,
    ),
)

# Output directory
const OUTDIR = "poster/figures"
mkpath(OUTDIR)

# Color scheme for consistency
const COLORS = ColorSchemes.seaborn_colorblind
const COLOR_MEASURED = COLORS[1]      # Blue
const COLOR_PREDICTED = COLORS[2]     # Orange
const COLOR_CURVATURE = COLORS[3]     # Green
const COLOR_E05 = COLORS[1]           # Blue for e=0.5
const COLOR_E08 = COLORS[2]           # Orange for e=0.8
const COLOR_E09 = COLORS[3]           # Green for e=0.9

# ============================================================================
# FIGURE 1: SYSTEM SCHEMATIC
# ============================================================================

function figure1_system_schematic()
    println("Generating Figure 1: System Schematic...")

    a, b = 2.0, 0.872  # e = 0.9 ellipse
    e = sqrt(1 - (b/a)^2)

    fig = Figure(size = (1200, 900))

    # Main panel: Ellipse with curvature coloring
    ax1 = Axis(fig[1, 1],
        title = "Hard-Sphere Particles on Elliptical Manifold",
        xlabel = L"x",
        ylabel = L"y",
        aspect = DataAspect(),
    )

    # Draw ellipse colored by curvature
    φ_range = range(0, 2π, length=500)
    x_ellipse = [a * cos(φ) for φ in φ_range]
    y_ellipse = [b * sin(φ) for φ in φ_range]

    # Curvature for coloring
    g_φφ(φ) = a^2 * sin(φ)^2 + b^2 * cos(φ)^2
    κ(φ) = a * b / g_φφ(φ)^1.5
    κ_vals = [κ(φ) for φ in φ_range]
    κ_normalized = (κ_vals .- minimum(κ_vals)) ./ (maximum(κ_vals) - minimum(κ_vals))

    # Draw ellipse as colored segments
    for i in 1:(length(φ_range)-1)
        lines!(ax1, x_ellipse[i:i+1], y_ellipse[i:i+1],
            color = ColorSchemes.viridis[κ_normalized[i]],
            linewidth = 8)
    end

    # Add particles at cluster locations (φ ≈ 0 and φ ≈ π)
    n_particles_cluster1 = 18
    n_particles_cluster2 = 16
    n_particles_other = 6

    # Cluster 1 at φ ≈ 0 (right pole)
    φ_cluster1 = randn(n_particles_cluster1) * 0.15
    for φ in φ_cluster1
        scatter!(ax1, [a * cos(φ)], [b * sin(φ)],
            color = :red, markersize = 20, strokewidth = 2, strokecolor = :black)
    end

    # Cluster 2 at φ ≈ π (left pole)
    φ_cluster2 = π .+ randn(n_particles_cluster2) * 0.15
    for φ in φ_cluster2
        scatter!(ax1, [a * cos(φ)], [b * sin(φ)],
            color = :red, markersize = 20, strokewidth = 2, strokecolor = :black)
    end

    # Scattered particles elsewhere
    φ_other = [π/3, π/2, 2π/3, 4π/3, 3π/2, 5π/3]
    for φ in φ_other
        scatter!(ax1, [a * cos(φ)], [b * sin(φ)],
            color = :red, markersize = 20, strokewidth = 2, strokecolor = :black, alpha = 0.5)
    end

    # Labels for poles
    text!(ax1, a + 0.3, 0.0, text = L"\phi = 0" * "\n(HIGH κ)", fontsize = 20, align = (:left, :center))
    text!(ax1, -a - 0.3, 0.0, text = L"\phi = \pi" * "\n(HIGH κ)", fontsize = 20, align = (:right, :center))
    text!(ax1, 0.0, b + 0.3, text = L"\phi = \pi/2" * "\n(low κ)", fontsize = 20, align = (:center, :bottom))

    # Colorbar for curvature
    Colorbar(fig[1, 2],
        colormap = :viridis,
        label = L"Curvature $\kappa(\phi)$",
        limits = (minimum(κ_vals), maximum(κ_vals)),
        labelsize = 24,
        ticklabelsize = 20,
        width = 20,
    )

    # Inset: Metric profile
    ax2 = Axis(fig[2, 1:2],
        xlabel = L"\phi \; (\mathrm{rad})",
        ylabel = L"g_{\phi\phi}(\phi)",
        title = "Metric Tensor Component",
    )

    φ_plot = range(0, 2π, length=200)
    g_vals = [g_φφ(φ) for φ in φ_plot]

    lines!(ax2, φ_plot, g_vals, color = :black, linewidth = 3)
    band!(ax2, φ_plot, zeros(length(φ_plot)), g_vals, color = (:blue, 0.2))

    # Mark poles
    vlines!(ax2, [0, π, 2π], color = :red, linestyle = :dash, linewidth = 2)
    text!(ax2, 0.1, minimum(g_vals) + 0.1, text = "Poles\n(clusters)", fontsize = 18, color = :red)

    xlims!(ax2, 0, 2π)
    ax2.xticks = ([0, π/2, π, 3π/2, 2π], ["0", "π/2", "π", "3π/2", "2π"])

    # Parameters box
    params_text = """
    Parameters:
    • N = 40 particles
    • Semi-axes: a = 2.0, b = $(round(b, digits=2))
    • Eccentricity: e = $(round(e, digits=2))
    • Elastic collisions
    • Energy conservation: ΔE/E₀ ~ 10⁻⁹
    """

    Label(fig[1, 1, TopRight()], params_text,
        fontsize = 18,
        padding = (10, 10, 10, 10),
        halign = :right,
        valign = :top,
    )

    save(joinpath(OUTDIR, "figure1_system_schematic.pdf"), fig)
    save(joinpath(OUTDIR, "figure1_system_schematic.png"), fig, px_per_unit = 3)
    println("  Saved: figure1_system_schematic.pdf/png")

    return fig
end

# ============================================================================
# FIGURE 2: ORDER PARAMETERS TIME EVOLUTION
# ============================================================================

function figure2_order_parameters()
    println("Generating Figure 2: Order Parameters...")

    # Try to load actual data
    data_dir = "results/long_time_EN_scan_20260108_084402"
    example_dir = joinpath(data_dir, "e0.90_N040_E0.80_t500_seed01")
    h5_file = joinpath(example_dir, "trajectories.h5")

    if !isfile(h5_file)
        println("  Warning: Data file not found, using synthetic data")
        return figure2_synthetic()
    end

    # Load and compute order parameters
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

    fig = Figure(size = (1200, 600))

    ax = Axis(fig[1, 1],
        xlabel = L"Time $t$ (s)",
        ylabel = "Order Parameter",
        title = "Cluster Formation Dynamics (e = 0.9, E/N = 0.8)",
    )

    # Subsample for plotting
    step = max(1, length(times) ÷ 1000)
    idx = 1:step:length(times)

    lines!(ax, times[idx], ψ_t[idx],
        color = COLOR_MEASURED, linewidth = 2, label = L"\psi = |⟨e^{i\phi}⟩|  \; (\mathrm{polar})")
    lines!(ax, times[idx], S_t[idx],
        color = COLOR_PREDICTED, linewidth = 2, label = L"S = |⟨e^{2i\phi}⟩| \; (\mathrm{nematic})")

    # Threshold lines
    hlines!(ax, [0.3], color = COLOR_MEASURED, linestyle = :dash, linewidth = 1.5, alpha = 0.5)
    hlines!(ax, [0.4], color = COLOR_PREDICTED, linestyle = :dash, linewidth = 1.5, alpha = 0.5)

    # Annotations
    text!(ax, times[end] * 0.7, 0.32, text = "ψ threshold", fontsize = 16, color = COLOR_MEASURED)
    text!(ax, times[end] * 0.7, 0.42, text = "S threshold", fontsize = 16, color = COLOR_PREDICTED)

    axislegend(ax, position = :rt)
    ylims!(ax, 0, 1)

    # Add interpretation panel
    ax2 = Axis(fig[1, 2],
        xlabel = L"\psi",
        ylabel = L"S",
        title = "Order Parameter Phase Space",
        aspect = 1,
    )

    scatter!(ax2, ψ_t[idx], S_t[idx],
        color = times[idx], colormap = :viridis,
        markersize = 4, alpha = 0.5)

    # Reference lines
    lines!(ax2, [0, 1], [0, 1], color = :gray, linestyle = :dash, linewidth = 2)
    text!(ax2, 0.6, 0.5, text = "S = ψ", fontsize = 16, rotation = π/4, color = :gray)

    # Regions
    text!(ax2, 0.1, 0.7, text = "Two-cluster\n(S > ψ)", fontsize = 18, color = COLOR_PREDICTED)
    text!(ax2, 0.7, 0.3, text = "Single cluster\n(ψ > S)", fontsize = 18, color = COLOR_MEASURED)

    Colorbar(fig[1, 3], colormap = :viridis, label = "Time (s)",
        limits = (times[1], times[end]))

    save(joinpath(OUTDIR, "figure2_order_parameters.pdf"), fig)
    save(joinpath(OUTDIR, "figure2_order_parameters.png"), fig, px_per_unit = 3)
    println("  Saved: figure2_order_parameters.pdf/png")

    return fig
end

function figure2_synthetic()
    # Generate synthetic order parameter data for demo
    fig = Figure(size = (1200, 600))

    t = range(0, 500, length=1000)
    ψ_base = 0.2 .+ 0.3 * (1 .- exp.(-t/50))
    S_base = 0.3 .+ 0.35 * (1 .- exp.(-t/30))

    # Add fluctuations
    ψ_t = ψ_base .+ 0.1 * randn(length(t))
    S_t = S_base .+ 0.1 * randn(length(t))
    ψ_t = clamp.(ψ_t, 0, 1)
    S_t = clamp.(S_t, 0, 1)

    ax = Axis(fig[1, 1],
        xlabel = L"Time $t$ (s)",
        ylabel = "Order Parameter",
        title = "Cluster Formation Dynamics (Synthetic Example)",
    )

    lines!(ax, t, ψ_t, color = COLOR_MEASURED, linewidth = 2, label = L"\psi \; (\mathrm{polar})")
    lines!(ax, t, S_t, color = COLOR_PREDICTED, linewidth = 2, label = L"S \; (\mathrm{nematic})")

    axislegend(ax, position = :rb)

    save(joinpath(OUTDIR, "figure2_order_parameters.pdf"), fig)
    save(joinpath(OUTDIR, "figure2_order_parameters.png"), fig, px_per_unit = 3)
    println("  Saved: figure2_order_parameters.pdf/png (synthetic)")

    return fig
end

# ============================================================================
# FIGURE 3: DENSITY COMPARISON (MAIN RESULT)
# ============================================================================

function figure3_density_comparison()
    println("Generating Figure 3: Density Comparison (Main Result)...")

    fig = Figure(size = (1400, 500))

    # Load data for each eccentricity
    data_dir = "results/long_time_EN_scan_20260108_084402/metric_verification"

    eccentricities = [0.5, 0.8, 0.9]
    colors = [COLOR_E05, COLOR_E08, COLOR_E09]

    for (i, e) in enumerate(eccentricities)
        e_str = @sprintf("%.2f", e)
        csv_file = joinpath(data_dir, "density_comparison_e$(e_str).csv")

        ax = Axis(fig[1, i],
            xlabel = L"\phi \; (\mathrm{rad})",
            ylabel = i == 1 ? L"\rho(\phi)" : "",
            title = L"e = %$(e_str)",
        )

        if isfile(csv_file)
            df = CSV.read(csv_file, DataFrame)

            # Normalize
            ρ_m = df.rho_measured ./ maximum(df.rho_measured)
            ρ_p = df.rho_predicted ./ maximum(df.rho_predicted)

            # Plot as bars and line
            barplot!(ax, df.phi, ρ_m,
                color = (colors[i], 0.6),
                strokewidth = 1,
                strokecolor = colors[i],
                label = "Measured ρ(φ)")

            lines!(ax, df.phi, ρ_p,
                color = :black, linewidth = 3, linestyle = :dash,
                label = "Predicted √g")

            # Correlation annotation
            corr = cor(df.rho_measured, df.rho_predicted)
            text!(ax, π, 0.9,
                text = @sprintf("r = %.2f", corr),
                fontsize = 28,
                color = corr < 0 ? :red : :black,
                align = (:center, :center))

            if corr < 0
                text!(ax, π, 0.75,
                    text = "(NEGATIVE!)",
                    fontsize = 20,
                    color = :red,
                    align = (:center, :center))
            end
        else
            text!(ax, π, 0.5, text = "Data not found", align = (:center, :center))
        end

        ax.xticks = ([0, π, 2π], ["0", "π", "2π"])
        ylims!(ax, 0, 1.1)

        if i == 3
            axislegend(ax, position = :rt)
        end
    end

    # Add main message
    Label(fig[0, 1:3],
        "MAIN RESULT: Measured density is ANTI-CORRELATED with equilibrium prediction",
        fontsize = 28,
        color = :red,
        padding = (0, 0, 20, 0))

    save(joinpath(OUTDIR, "figure3_density_comparison.pdf"), fig)
    save(joinpath(OUTDIR, "figure3_density_comparison.png"), fig, px_per_unit = 3)
    println("  Saved: figure3_density_comparison.pdf/png")

    return fig
end

# ============================================================================
# FIGURE 4: CORRELATION SUMMARY
# ============================================================================

function figure4_correlation_summary()
    println("Generating Figure 4: Correlation Summary...")

    fig = Figure(size = (1200, 600))

    # Data from analysis
    eccentricities = [0.5, 0.8, 0.9]
    corr_sqrt_g = [-0.48, -0.81, -0.91]
    corr_inv_sqrt_g = [0.49, 0.83, 0.92]
    corr_kappa = [0.50, 0.83, 0.89]

    # Panel 1: Bar chart of correlations
    ax1 = Axis(fig[1, 1],
        xlabel = "Eccentricity e",
        ylabel = "Correlation Coefficient",
        title = "Correlation with Different Predictions",
        xticks = (1:3, ["0.5", "0.8", "0.9"]),
    )

    barwidth = 0.25
    positions_sqrt_g = (1:3) .- barwidth
    positions_inv = (1:3)
    positions_kappa = (1:3) .+ barwidth

    barplot!(ax1, positions_sqrt_g, corr_sqrt_g,
        color = :red, strokewidth = 2, strokecolor = :darkred,
        label = L"Corr(\rho, \sqrt{g})", width = barwidth)

    barplot!(ax1, positions_inv, corr_inv_sqrt_g,
        color = :blue, strokewidth = 2, strokecolor = :darkblue,
        label = L"Corr(\rho, 1/\sqrt{g})", width = barwidth)

    barplot!(ax1, positions_kappa, corr_kappa,
        color = :green, strokewidth = 2, strokecolor = :darkgreen,
        label = L"Corr(\rho, \kappa)", width = barwidth)

    hlines!(ax1, [0], color = :black, linewidth = 2)

    axislegend(ax1, position = :lb)
    ylims!(ax1, -1.1, 1.1)

    # Panel 2: Schematic interpretation
    ax2 = Axis(fig[1, 2],
        title = "Physical Interpretation",
        aspect = 1,
    )
    hidedecorations!(ax2)
    hidespines!(ax2)

    # Draw arrows and text
    text!(ax2, 0.5, 0.9,
        text = "Equilibrium Prediction:",
        fontsize = 24, align = (:center, :center))
    text!(ax2, 0.5, 0.8,
        text = L"\rho \propto \sqrt{g_{\phi\phi}} \quad \text{(MORE particles at low } \kappa \text{)}",
        fontsize = 22, align = (:center, :center), color = :red)
    text!(ax2, 0.5, 0.7,
        text = "WRONG!",
        fontsize = 28, align = (:center, :center), color = :red)

    text!(ax2, 0.5, 0.5,
        text = "─────────────────────────────",
        fontsize = 20, align = (:center, :center))

    text!(ax2, 0.5, 0.35,
        text = "Observed (This Work):",
        fontsize = 24, align = (:center, :center))
    text!(ax2, 0.5, 0.25,
        text = L"\rho \propto 1/\sqrt{g_{\phi\phi}} \propto \kappa^{2/3}",
        fontsize = 22, align = (:center, :center), color = :blue)
    text!(ax2, 0.5, 0.15,
        text = "(MORE particles at HIGH κ)",
        fontsize = 20, align = (:center, :center), color = :blue)

    text!(ax2, 0.5, 0.02,
        text = "NON-EQUILIBRIUM STEADY STATE",
        fontsize = 26, align = (:center, :center), color = :darkblue)

    xlims!(ax2, 0, 1)
    ylims!(ax2, 0, 1)

    save(joinpath(OUTDIR, "figure4_correlation_summary.pdf"), fig)
    save(joinpath(OUTDIR, "figure4_correlation_summary.png"), fig, px_per_unit = 3)
    println("  Saved: figure4_correlation_summary.pdf/png")

    return fig
end

# ============================================================================
# FIGURE 5: MECHANISM SCHEMATIC
# ============================================================================

function figure5_mechanism()
    println("Generating Figure 5: Physical Mechanism...")

    fig = Figure(size = (1200, 800))

    # Left panel: Ellipse with velocity arrows
    ax1 = Axis(fig[1, 1],
        title = "Velocity Reduction at High Curvature",
        aspect = DataAspect(),
    )
    hidedecorations!(ax1)

    a, b = 2.0, 0.872
    φ_range = range(0, 2π, length=100)

    # Draw ellipse
    x_ellipse = [a * cos(φ) for φ in φ_range]
    y_ellipse = [b * sin(φ) for φ in φ_range]
    lines!(ax1, x_ellipse, y_ellipse, color = :black, linewidth = 4)

    # Draw velocity arrows (larger at low κ, smaller at high κ)
    φ_arrows = [0, π/4, π/2, 3π/4, π, 5π/4, 3π/2, 7π/4]
    for φ in φ_arrows
        x = a * cos(φ)
        y = b * sin(φ)

        # Tangent direction
        dx = -a * sin(φ)
        dy = b * cos(φ)
        norm = sqrt(dx^2 + dy^2)
        dx /= norm
        dy /= norm

        # Arrow length proportional to 1/κ (velocity)
        g_φφ = a^2 * sin(φ)^2 + b^2 * cos(φ)^2
        κ = a * b / g_φφ^1.5
        arrow_len = 0.5 / κ  # Inverse of curvature

        color = κ > 1.5 ? :red : :blue

        arrows!(ax1, [x], [y], [dx * arrow_len], [dy * arrow_len],
            color = color, linewidth = 3, arrowsize = 15)
    end

    # Labels
    text!(ax1, a + 0.1, 0, text = "SLOW\n(trapped)", color = :red, fontsize = 20, align = (:left, :center))
    text!(ax1, 0, b + 0.2, text = "FAST\n(escapes)", color = :blue, fontsize = 20, align = (:center, :bottom))

    # Right panel: Traffic analogy
    ax2 = Axis(fig[1, 2],
        title = "Traffic Jam Analogy",
    )
    hidedecorations!(ax2)

    # Draw road with curve
    road_x = range(0, 2π, length=100)
    road_y = sin.(road_x)
    lines!(ax2, road_x, road_y, color = :gray, linewidth = 20)
    lines!(ax2, road_x, road_y .+ 0.2, color = :gray, linewidth = 2)
    lines!(ax2, road_x, road_y .- 0.2, color = :gray, linewidth = 2)

    # Cars (more at curves, fewer on straights)
    car_positions = [0.2, 0.3, 0.4,  # Start curve
                     π - 0.2, π - 0.1, π, π + 0.1, π + 0.2,  # Peak curve (many cars)
                     2π - 0.3, 2π - 0.2]  # End curve

    for x in car_positions
        y = sin(x)
        scatter!(ax2, [x], [y], marker = '🚗', markersize = 30)
    end

    # Sparse cars on straight section
    for x in [π/2 - 0.3, π/2 + 0.5, 3π/2 - 0.5, 3π/2 + 0.3]
        y = sin(x)
        scatter!(ax2, [x], [y], marker = '🚗', markersize = 30, alpha = 0.5)
    end

    text!(ax2, π, -0.5, text = "Sharp curve\n= Traffic jam", fontsize = 20, align = (:center, :top))
    text!(ax2, π/2, 1.3, text = "Straight\n= Fast", fontsize = 20, align = (:center, :bottom))

    xlims!(ax2, -0.5, 2π + 0.5)
    ylims!(ax2, -1.5, 2)

    # Bottom panel: Key message
    Label(fig[2, 1:2],
        """
        MECHANISM: Particles slow down at high-curvature regions → collisions trap them → clusters form
        This is NOT equilibrium! It's a COLLISION-DRIVEN non-equilibrium steady state.
        """,
        fontsize = 24,
        padding = (20, 20, 20, 20),
    )

    save(joinpath(OUTDIR, "figure5_mechanism.pdf"), fig)
    save(joinpath(OUTDIR, "figure5_mechanism.png"), fig, px_per_unit = 3)
    println("  Saved: figure5_mechanism.pdf/png")

    return fig
end

# ============================================================================
# FIGURE 6: SUMMARY GRAPHIC
# ============================================================================

function figure6_summary()
    println("Generating Figure 6: Summary Graphic...")

    fig = Figure(size = (1400, 900))

    # Title
    Label(fig[1, 1:3],
        "CURVATURE-INDUCED CLUSTERING: NON-EQUILIBRIUM STEADY STATE",
        fontsize = 36,
        color = :darkblue,
        padding = (0, 0, 20, 0))

    # Key numbers
    ax1 = Axis(fig[2, 1], title = "Clustering Rate", aspect = 1)
    hidedecorations!(ax1)
    hidespines!(ax1)

    text!(ax1, 0.5, 0.6, text = "100%", fontsize = 72, color = :blue, align = (:center, :center))
    text!(ax1, 0.5, 0.3, text = "of runs show\nclustering\nat e = 0.9", fontsize = 24, align = (:center, :center))

    ax2 = Axis(fig[2, 2], title = "Anti-Correlation", aspect = 1)
    hidedecorations!(ax2)
    hidespines!(ax2)

    text!(ax2, 0.5, 0.6, text = "r = -0.91", fontsize = 60, color = :red, align = (:center, :center))
    text!(ax2, 0.5, 0.3, text = "Correlation with\nequilibrium\nprediction", fontsize = 24, align = (:center, :center))

    ax3 = Axis(fig[2, 3], title = "Energy Conservation", aspect = 1)
    hidedecorations!(ax3)
    hidespines!(ax3)

    text!(ax3, 0.5, 0.6, text = "10⁻⁹", fontsize = 72, color = :green, align = (:center, :center))
    text!(ax3, 0.5, 0.3, text = "ΔE/E₀\nrelative error", fontsize = 24, align = (:center, :center))

    # Key findings
    findings_text = """
    KEY FINDINGS:

    1. Particles form TWO CLUSTERS at ellipse poles (high curvature)

    2. Density ρ(φ) ∝ 1/√g — OPPOSITE of equilibrium prediction

    3. Higher temperature → MORE clustering (counter-intuitive)

    4. This is a NON-EQUILIBRIUM STEADY STATE, not thermal equilibrium
    """

    Label(fig[3, 1:3], findings_text,
        fontsize = 28,
        padding = (40, 40, 20, 20),
        halign = :left)

    # Equation box
    eq_text = L"\text{Equilibrium: } \rho \propto \sqrt{g} \quad \text{(WRONG!)} \qquad \text{Observed: } \rho \propto 1/\sqrt{g} \propto \kappa^{2/3}"

    Label(fig[4, 1:3], eq_text,
        fontsize = 32,
        color = :darkred,
        padding = (20, 20, 20, 20))

    save(joinpath(OUTDIR, "figure6_summary.pdf"), fig)
    save(joinpath(OUTDIR, "figure6_summary.png"), fig, px_per_unit = 3)
    println("  Saved: figure6_summary.pdf/png")

    return fig
end

# ============================================================================
# MAIN
# ============================================================================

function main()
    println("="^70)
    println("GENERATING POSTER FIGURES")
    println("="^70)
    println("Output directory: $OUTDIR")
    println()

    figure1_system_schematic()
    figure2_order_parameters()
    figure3_density_comparison()
    figure4_correlation_summary()
    figure5_mechanism()
    figure6_summary()

    println()
    println("="^70)
    println("ALL FIGURES GENERATED SUCCESSFULLY")
    println("="^70)
    println()
    println("Files saved to: $OUTDIR/")
    println("  - figure1_system_schematic.pdf/png")
    println("  - figure2_order_parameters.pdf/png")
    println("  - figure3_density_comparison.pdf/png")
    println("  - figure4_correlation_summary.pdf/png")
    println("  - figure5_mechanism.pdf/png")
    println("  - figure6_summary.pdf/png")
end

main()
