#!/usr/bin/env julia
using CSV
using DataFrames
using CairoMakie

campaign_dir = "results/campaign_eccentricity_scan_20251116_014451"

println("="^70)
println("GENERANDO PLOTS: Análisis Parcial (e=0.0-0.9)")
println("="^70)
println()

# Leer datos
summary = CSV.read(joinpath(campaign_dir, "summary_by_eccentricity_PARTIAL.csv"), DataFrame)
all_data = CSV.read(joinpath(campaign_dir, "all_results_PARTIAL.csv"), DataFrame)

println("Datos cargados:")
println("  - Summary: $(nrow(summary)) eccentricidades")
println("  - All data: $(nrow(all_data)) simulaciones")
println()

# ==================== PLOT 1: R vs e ====================
println("Generando Plot 1: Clustering Ratio R(e)...")

fig1 = Figure(resolution=(900, 700), fontsize=16)
ax1 = Axis(fig1[1,1],
    xlabel = "Eccentricity (e)",
    ylabel = "Clustering Ratio (R)",
    title = "Clustering vs Eccentricity\n(N=80, E/N=0.32, t_max=200s)",
    xlabelsize = 20,
    ylabelsize = 20,
    titlesize = 22
)

# Scatter de todas las realizaciones (background)
scatter!(ax1, all_data.e, all_data.R,
    alpha=0.3, markersize=8, color=:gray, label="Individual runs")

# Línea de tendencia con error bars
errorbars!(ax1, summary.e, summary.R_mean, summary.R_std,
    whiskerwidth=12, linewidth=2, color=:red)
scatter!(ax1, summary.e, summary.R_mean,
    markersize=14, color=:red, label="Mean ± std")
lines!(ax1, summary.e, summary.R_mean,
    linestyle=:dash, linewidth=2, color=:red)

# Línea base R=1 (no clustering)
hlines!(ax1, [1.0], linestyle=:dot, linewidth=1.5, color=:black, label="R=1 (uniform)")

axislegend(ax1, position=:lt, framevisible=true)

save(joinpath(campaign_dir, "R_vs_eccentricity_PARTIAL.png"), fig1, px_per_unit=2)
println("  ✓ Guardado: R_vs_eccentricity_PARTIAL.png")

# ==================== PLOT 2: Ψ vs e ====================
println("Generando Plot 2: Order Parameter Ψ(e)...")

fig2 = Figure(resolution=(900, 700), fontsize=16)
ax2 = Axis(fig2[1,1],
    xlabel = "Eccentricity (e)",
    ylabel = "Order Parameter (Ψ)",
    title = "Order Parameter vs Eccentricity\n(N=80, E/N=0.32, t_max=200s)",
    xlabelsize = 20,
    ylabelsize = 20,
    titlesize = 22
)

# Scatter de todas las realizaciones
scatter!(ax2, all_data.e, all_data.Psi,
    alpha=0.3, markersize=8, color=:gray, label="Individual runs")

# Media con error bars
errorbars!(ax2, summary.e, summary.Psi_mean, summary.Psi_std,
    whiskerwidth=12, linewidth=2, color=:blue)
scatter!(ax2, summary.e, summary.Psi_mean,
    markersize=14, color=:blue, label="Mean ± std")
lines!(ax2, summary.e, summary.Psi_mean,
    linestyle=:dash, linewidth=2, color=:blue)

axislegend(ax2, position=:lt, framevisible=true)

save(joinpath(campaign_dir, "Psi_vs_eccentricity_PARTIAL.png"), fig2, px_per_unit=2)
println("  ✓ Guardado: Psi_vs_eccentricity_PARTIAL.png")

# ==================== PLOT 3: R y Ψ combinados ====================
println("Generando Plot 3: R y Ψ combinados...")

fig3 = Figure(resolution=(900, 700), fontsize=16)
ax3 = Axis(fig3[1,1],
    xlabel = "Eccentricity (e)",
    ylabel = "Clustering Ratio (R)",
    title = "Clustering Metrics vs Eccentricity",
    xlabelsize = 20,
    ylabelsize = 20,
    titlesize = 22
)

# R(e) en eje izquierdo
errorbars!(ax3, summary.e, summary.R_mean, summary.R_std,
    whiskerwidth=12, linewidth=2, color=:red)
scatter!(ax3, summary.e, summary.R_mean,
    markersize=14, color=:red, marker=:circle, label="R (clustering)")
lines!(ax3, summary.e, summary.R_mean,
    linestyle=:dash, linewidth=2, color=:red)

# Ψ(e) en eje derecho (escalado)
ax3_right = Axis(fig3[1,1],
    ylabel = "Order Parameter (Ψ)",
    ylabelsize = 20,
    yaxisposition = :right,
    yticklabelcolor = :blue,
    ylabelcolor = :blue
)

errorbars!(ax3_right, summary.e, summary.Psi_mean, summary.Psi_std,
    whiskerwidth=12, linewidth=2, color=:blue)
scatter!(ax3_right, summary.e, summary.Psi_mean,
    markersize=14, color=:blue, marker=:utriangle, label="Ψ (order)")
lines!(ax3_right, summary.e, summary.Psi_mean,
    linestyle=:dash, linewidth=2, color=:blue)

# Ocultar grid del eje derecho
hidespines!(ax3_right)
hidexdecorations!(ax3_right)

# Leyendas
Legend(fig3[1,2], ax3, framevisible=true)

save(joinpath(campaign_dir, "R_and_Psi_vs_eccentricity_PARTIAL.png"), fig3, px_per_unit=2)
println("  ✓ Guardado: R_and_Psi_vs_eccentricity_PARTIAL.png")

# ==================== PLOT 4: Conservación de energía ====================
println("Generando Plot 4: Conservación de energía...")

fig4 = Figure(resolution=(900, 700), fontsize=16)
ax4 = Axis(fig4[1,1],
    xlabel = "Eccentricity (e)",
    ylabel = "Relative Energy Error (ΔE/E₀)",
    title = "Energy Conservation vs Eccentricity",
    xlabelsize = 20,
    ylabelsize = 20,
    titlesize = 22,
    yscale = log10
)

# Scatter de todas las realizaciones
scatter!(ax4, all_data.e, all_data.dE_rel,
    alpha=0.5, markersize=10, color=:green)

# Media con error bars
errorbars!(ax4, summary.e, summary.dE_mean, summary.dE_std,
    whiskerwidth=12, linewidth=2, color=:darkgreen)
scatter!(ax4, summary.e, summary.dE_mean,
    markersize=14, color=:darkgreen, marker=:diamond, label="Mean ± std")

# Líneas de referencia
hlines!(ax4, [1e-4], linestyle=:dash, linewidth=2, color=:orange,
    label="Good threshold (10⁻⁴)")
hlines!(ax4, [1e-2], linestyle=:dash, linewidth=2, color=:red,
    label="Poor threshold (10⁻²)")

axislegend(ax4, position=:lt, framevisible=true)

save(joinpath(campaign_dir, "energy_conservation_PARTIAL.png"), fig4, px_per_unit=2)
println("  ✓ Guardado: energy_conservation_PARTIAL.png")

# ==================== PLOT 5: Histogramas de R por eccentricidad ====================
println("Generando Plot 5: Histogramas de R...")

fig5 = Figure(resolution=(1200, 900), fontsize=14)

eccentricities = sort(unique(all_data.e))
n_rows = 2
n_cols = 3

for (i, e_val) in enumerate(eccentricities)
    row = div(i-1, n_cols) + 1
    col = mod(i-1, n_cols) + 1

    ax = Axis(fig5[row, col],
        xlabel = "Clustering Ratio (R)",
        ylabel = "Count",
        title = "e = $(round(e_val, digits=2))"
    )

    data_e = all_data[all_data.e .== e_val, :R]
    hist!(ax, data_e, bins=10, color=(:blue, 0.5), strokewidth=1, strokecolor=:black)

    # Línea vertical en la media
    vlines!(ax, [Statistics.mean(data_e)], color=:red, linewidth=2, linestyle=:dash)
end

Label(fig5[0, :], "Distribution of Clustering Ratio by Eccentricity (20 realizations each)",
    fontsize=20, font=:bold)

save(joinpath(campaign_dir, "R_histograms_PARTIAL.png"), fig5, px_per_unit=2)
println("  ✓ Guardado: R_histograms_PARTIAL.png")

println()
println("="^70)
println("PLOTS GENERADOS EXITOSAMENTE")
println("="^70)
println()
println("Archivos creados en: $campaign_dir")
println("  1. R_vs_eccentricity_PARTIAL.png")
println("  2. Psi_vs_eccentricity_PARTIAL.png")
println("  3. R_and_Psi_vs_eccentricity_PARTIAL.png")
println("  4. energy_conservation_PARTIAL.png")
println("  5. R_histograms_PARTIAL.png")
println()
println("="^70)
