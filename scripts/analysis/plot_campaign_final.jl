#!/usr/bin/env julia
# Generate publication-ready plots from complete campaign

using CSV
using DataFrames
using CairoMakie
using Statistics
using Printf

println("="^80)
println("GENERACIÓN DE PLOTS PUBLICATION-READY")
println("="^80)
println()

campaign_dir = "results/campaign_eccentricity_scan_20251116_014451"

# Read data
summary_file = joinpath(campaign_dir, "summary_by_eccentricity_FINAL.csv")
all_data_file = joinpath(campaign_dir, "all_results_FINAL.csv")

if !isfile(summary_file) || !isfile(all_data_file)
    println("❌ ERROR: Archivos de análisis no encontrados")
    println("   Ejecutar primero: analyze_full_campaign_final.jl")
    exit(1)
end

summary = CSV.read(summary_file, DataFrame)
all_data = CSV.read(all_data_file, DataFrame)

println("Datos cargados:")
println("  - $(nrow(summary)) eccentricidades")
println("  - $(nrow(all_data)) runs totales")
println()

# Set publication theme
set_theme!(
    fontsize = 18,
    linewidth = 2,
    markersize = 12,
    figure_padding = 10,
    fonts = (regular = "CMU Serif", bold = "CMU Serif Bold")
)

# ============================================================================
# PLOT 1: R vs e with error bars (MAIN FIGURE)
# ============================================================================

println("Generando Plot 1: R vs e (figura principal)...")

fig1 = Figure(resolution = (900, 700))

ax1 = Axis(fig1[1, 1],
    xlabel = "Eccentricity (e)",
    ylabel = "Clustering Ratio (R)",
    title = "Geometric Clustering on Ellipses (N=80, E/N=0.32)",
    xlabelsize = 22,
    ylabelsize = 22,
    titlesize = 24
)

# Error bars
errorbars!(ax1, summary.e, summary.R_mean, summary.R_std,
    whiskerwidth = 15,
    color = :gray,
    linewidth = 2
)

# Line connecting means
lines!(ax1, summary.e, summary.R_mean,
    color = :steelblue,
    linewidth = 3,
    linestyle = :dash
)

# Points
scatter!(ax1, summary.e, summary.R_mean,
    color = :steelblue,
    markersize = 15,
    strokewidth = 2,
    strokecolor = :black
)

# Reference line R=1 (uniform)
hlines!(ax1, [1.0],
    color = :red,
    linestyle = :dash,
    linewidth = 2,
    alpha = 0.5
)

# Annotate key points
text!(ax1, 0.02, 1.05,
    text = "Uniform (circle)",
    fontsize = 14,
    color = :red
)

# Highlight transition region
vspan!(ax1, 0.8, 0.98,
    color = (:orange, 0.15)
)

text!(ax1, 0.88, maximum(summary.R_mean) * 0.9,
    text = "Transition\nregion",
    fontsize = 14,
    align = (:center, :center)
)

save(joinpath(campaign_dir, "Fig1_R_vs_eccentricity.png"), fig1, px_per_unit = 2)
println("  ✅ Fig1_R_vs_eccentricity.png")

# ============================================================================
# PLOT 2: Gradient dR/de vs e (ACCELERATION VISUALIZATION)
# ============================================================================

println("Generando Plot 2: dR/de vs e (aceleración)...")

fig2 = Figure(resolution = (900, 700))

ax2 = Axis(fig2[1, 1],
    xlabel = "Eccentricity (e)",
    ylabel = "Gradient dR/de",
    title = "Acceleration of Clustering Transition",
    xlabelsize = 22,
    ylabelsize = 22,
    titlesize = 24
)

# Compute gradients at midpoints
e_mid = [(summary.e[i] + summary.e[i+1])/2 for i in 1:nrow(summary)-1]
gradients = [
    (summary.R_mean[i+1] - summary.R_mean[i]) /
    (summary.e[i+1] - summary.e[i])
    for i in 1:nrow(summary)-1
]

# Plot
scatter!(ax2, e_mid, gradients,
    color = :crimson,
    markersize = 18,
    strokewidth = 2,
    strokecolor = :black
)

lines!(ax2, e_mid, gradients,
    color = :crimson,
    linewidth = 3,
    alpha = 0.6
)

# Reference line (initial gradient)
hlines!(ax2, [gradients[1]],
    color = :gray,
    linestyle = :dash,
    linewidth = 2
)

text!(ax2, 0.1, gradients[1] * 1.3,
    text = "Initial gradient",
    fontsize = 14,
    color = :gray
)

save(joinpath(campaign_dir, "Fig2_gradient_acceleration.png"), fig2, px_per_unit = 2)
println("  ✅ Fig2_gradient_acceleration.png")

# ============================================================================
# PLOT 3: R vs Ψ (SPATIAL-ORIENTATIONAL DECOUPLING)
# ============================================================================

println("Generando Plot 3: R vs Ψ (desacoplamiento)...")

fig3 = Figure(resolution = (900, 700))

ax3 = Axis(fig3[1, 1],
    xlabel = "Order Parameter (Ψ)",
    ylabel = "Clustering Ratio (R)",
    title = "Spatial vs Orientational Order",
    xlabelsize = 22,
    ylabelsize = 22,
    titlesize = 24
)

# Color by eccentricity
colors = summary.e

scatter!(ax3, summary.Psi_mean, summary.R_mean,
    color = colors,
    colormap = :thermal,
    markersize = 20,
    strokewidth = 2,
    strokecolor = :black
)

# Error bars
errorbars!(ax3, summary.Psi_mean, summary.R_mean,
    summary.R_std,
    direction = :y,
    whiskerwidth = 10,
    color = :gray,
    linewidth = 1.5
)

errorbars!(ax3, summary.Psi_mean, summary.R_mean,
    summary.Psi_std,
    direction = :x,
    whiskerwidth = 10,
    color = :gray,
    linewidth = 1.5
)

# Reference lines
hlines!(ax3, [1.0], color = :gray, linestyle = :dash, linewidth = 1.5)
vlines!(ax3, [0.3], color = :gray, linestyle = :dash, linewidth = 1.5)

text!(ax3, 0.31, 1.1,
    text = "Crystal\nthreshold",
    fontsize = 12,
    align = (:left, :bottom)
)

# Colorbar
Colorbar(fig3[1, 2],
    limits = (0, 1),
    colormap = :thermal,
    label = "Eccentricity (e)",
    labelsize = 20
)

save(joinpath(campaign_dir, "Fig3_R_vs_Psi.png"), fig3, px_per_unit = 2)
println("  ✅ Fig3_R_vs_Psi.png")

# ============================================================================
# PLOT 4: Energy conservation
# ============================================================================

println("Generando Plot 4: Conservación de energía...")

fig4 = Figure(resolution = (900, 700))

ax4 = Axis(fig4[1, 1],
    xlabel = "Eccentricity (e)",
    ylabel = "Relative Energy Error (ΔE/E₀)",
    title = "Energy Conservation Quality",
    xlabelsize = 22,
    ylabelsize = 22,
    titlesize = 24,
    yscale = log10
)

# Mean and max
scatter!(ax4, summary.e, summary.dE_mean,
    color = :green,
    marker = :circle,
    markersize = 15,
    label = "Mean"
)

scatter!(ax4, summary.e, summary.dE_max,
    color = :orange,
    marker = :utriangle,
    markersize = 15,
    label = "Max"
)

# Threshold lines
hlines!(ax4, [1e-4],
    color = :blue,
    linestyle = :dash,
    linewidth = 2,
    label = "Excellent (10⁻⁴)"
)

hlines!(ax4, [1e-2],
    color = :red,
    linestyle = :dash,
    linewidth = 2,
    label = "Acceptable (10⁻²)"
)

axislegend(ax4, position = :lt, labelsize = 14)

save(joinpath(campaign_dir, "Fig4_energy_conservation.png"), fig4, px_per_unit = 2)
println("  ✅ Fig4_energy_conservation.png")

# ============================================================================
# PLOT 5: All realizations scatter
# ============================================================================

println("Generando Plot 5: Todas las realizaciones...")

fig5 = Figure(resolution = (900, 700))

ax5 = Axis(fig5[1, 1],
    xlabel = "Eccentricity (e)",
    ylabel = "Clustering Ratio (R)",
    title = "All Realizations (20 per eccentricity)",
    xlabelsize = 22,
    ylabelsize = 22,
    titlesize = 24
)

# Individual points
scatter!(ax5, all_data.e, all_data.R,
    color = (:steelblue, 0.3),
    markersize = 10
)

# Mean line
lines!(ax5, summary.e, summary.R_mean,
    color = :red,
    linewidth = 4,
    label = "Mean"
)

# Error band
band!(ax5,
    summary.e,
    summary.R_mean .- summary.R_std,
    summary.R_mean .+ summary.R_std,
    color = (:red, 0.2),
    label = "±1σ"
)

axislegend(ax5, position = :lt, labelsize = 16)

save(joinpath(campaign_dir, "Fig5_all_realizations.png"), fig5, px_per_unit = 2)
println("  ✅ Fig5_all_realizations.png")

# ============================================================================
# PLOT 6: Histograms by e
# ============================================================================

println("Generando Plot 6: Histogramas de R por e...")

fig6 = Figure(resolution = (1200, 900))

# Select representative eccentricities
e_selected = [0.0, 0.5, 0.8, 0.9, 0.95, 0.98, 0.99]

n_plots = length(e_selected)
n_cols = 3
n_rows = ceil(Int, n_plots / n_cols)

for (idx, e_val) in enumerate(e_selected)
    row = div(idx - 1, n_cols) + 1
    col = mod(idx - 1, n_cols) + 1

    ax = Axis(fig6[row, col],
        xlabel = "R",
        ylabel = "Frequency",
        title = @sprintf("e = %.2f", e_val),
        titlesize = 16
    )

    # Get data for this e
    data_e = filter(row -> row.e == e_val, all_data)

    if nrow(data_e) > 0
        hist!(ax, data_e.R,
            bins = 10,
            color = (:steelblue, 0.6),
            strokewidth = 1,
            strokecolor = :black
        )

        # Mean line
        vlines!(ax, [mean(data_e.R)],
            color = :red,
            linewidth = 3,
            linestyle = :dash
        )
    end
end

save(joinpath(campaign_dir, "Fig6_histograms_by_e.png"), fig6, px_per_unit = 2)
println("  ✅ Fig6_histograms_by_e.png")

# ============================================================================
# PLOT 7: Combined R and Psi vs e (dual axis)
# ============================================================================

println("Generando Plot 7: R y Ψ vs e (doble eje)...")

fig7 = Figure(resolution = (1000, 700))

ax7_R = Axis(fig7[1, 1],
    xlabel = "Eccentricity (e)",
    ylabel = "Clustering Ratio (R)",
    xlabelsize = 22,
    ylabelsize = 22,
    yaxisposition = :left
)

ax7_Psi = Axis(fig7[1, 1],
    ylabel = "Order Parameter (Ψ)",
    ylabelsize = 22,
    yaxisposition = :right,
    yticklabelcolor = :crimson,
    ylabelcolor = :crimson
)

# Hide x-axis for second axis
hidexdecorations!(ax7_Psi, label = false, ticklabels = false, ticks = false)

# Plot R on left axis
lines!(ax7_R, summary.e, summary.R_mean,
    color = :steelblue,
    linewidth = 3,
    label = "R (clustering)"
)

scatter!(ax7_R, summary.e, summary.R_mean,
    color = :steelblue,
    markersize = 15,
    strokewidth = 2,
    strokecolor = :black
)

errorbars!(ax7_R, summary.e, summary.R_mean, summary.R_std,
    color = :steelblue,
    whiskerwidth = 10,
    linewidth = 2
)

# Plot Psi on right axis
lines!(ax7_Psi, summary.e, summary.Psi_mean,
    color = :crimson,
    linewidth = 3,
    label = "Ψ (order)"
)

scatter!(ax7_Psi, summary.e, summary.Psi_mean,
    color = :crimson,
    markersize = 15,
    strokewidth = 2,
    strokecolor = :black
)

# Link x-axes
linkxaxes!(ax7_R, ax7_Psi)

save(joinpath(campaign_dir, "Fig7_R_and_Psi_dual_axis.png"), fig7, px_per_unit = 2)
println("  ✅ Fig7_R_and_Psi_dual_axis.png")

# ============================================================================
# Summary
# ============================================================================

println()
println("="^80)
println("PLOTS GENERADOS EXITOSAMENTE")
println("="^80)
println()
println("Figuras guardadas en: $campaign_dir")
println()
println("  1. Fig1_R_vs_eccentricity.png      - Figura principal (R vs e)")
println("  2. Fig2_gradient_acceleration.png  - Aceleración (dR/de)")
println("  3. Fig3_R_vs_Psi.png               - Desacoplamiento espacial-orientacional")
println("  4. Fig4_energy_conservation.png    - Conservación de energía")
println("  5. Fig5_all_realizations.png       - Todas las realizaciones")
println("  6. Fig6_histograms_by_e.png        - Distribuciones por e")
println("  7. Fig7_R_and_Psi_dual_axis.png    - R y Ψ en mismo plot")
println()
println("="^80)
