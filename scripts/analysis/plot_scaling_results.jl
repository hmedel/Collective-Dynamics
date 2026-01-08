#!/usr/bin/env julia
"""
Generate publication-quality plots for scaling analysis
"""

using Pkg
Pkg.activate(".")

using Statistics
using Printf
using DataFrames
using CSV
using Plots
gr()  # Use GR backend (default)

const PROJECT_ROOT = dirname(dirname(@__DIR__))
campaign_dir = "results/intrinsic_v3_campaign_20251126_110434"

# Load the scaling data
scaling_df = CSV.read(joinpath(PROJECT_ROOT, campaign_dir, "scaling_analysis/scaling_data.csv"), DataFrame)

println("="^60)
println("GENERATING PUBLICATION PLOTS")
println("="^60)

output_dir = joinpath(PROJECT_ROOT, campaign_dir, "scaling_analysis", "figures")
mkpath(output_dir)

# ============================================================================
# Figure 1: Curvature-Density Correlation vs ln(κ_max/κ_min)
# ============================================================================
println("\nPlot 1: Correlation vs ln(κ)")

e_vals = scaling_df.e
corr = scaling_df.corr_mean
corr_err = scaling_df.corr_sem
log_kappa = log.(scaling_df.kappa_ratio)

# Fit parameters (from analysis)
a_fit = 0.1411
b_fit = 0.0836
x_fit = range(minimum(log_kappa)-0.1, maximum(log_kappa)+0.3, length=100)
y_fit = a_fit .+ b_fit .* x_fit

p1 = plot(
    log_kappa, corr,
    seriestype=:scatter,
    xerror=zeros(length(log_kappa)),
    yerror=corr_err,
    markersize=10,
    markerstrokewidth=2,
    color=:blue,
    label="Data",
    xlabel="ln(κ_max/κ_min)",
    ylabel="⟨ρ,κ⟩ correlation",
    title="Curvature-Density Correlation",
    legend=:bottomright,
    grid=true,
    framestyle=:box,
    size=(600, 500),
    dpi=150
)

plot!(p1, x_fit, y_fit,
    linewidth=2,
    linestyle=:dash,
    color=:red,
    label="Fit: 0.141 + 0.084 × ln(κ)\nR² = 0.997"
)

# Add eccentricity labels
for i in 1:length(e_vals)
    annotate!(p1, log_kappa[i]+0.15, corr[i], text("e=$(e_vals[i])", 9, :left))
end

savefig(p1, joinpath(output_dir, "correlation_vs_ln_kappa.png"))
savefig(p1, joinpath(output_dir, "correlation_vs_ln_kappa.pdf"))
println("  Saved: correlation_vs_ln_kappa.png/pdf")

# ============================================================================
# Figure 2: Correlation vs Aspect Ratio (a/b)
# ============================================================================
println("Plot 2: Correlation vs aspect ratio")

aspect_ratio = scaling_df.aspect_ratio

# Expected scaling: corr ∝ a/b
# Fit: corr = c × (a/b) with c ≈ 0.15
c_fit = mean(corr ./ aspect_ratio)
ar_fit = range(1.0, maximum(aspect_ratio)+0.2, length=100)
y_ar_fit = c_fit .* ar_fit

p2 = plot(
    aspect_ratio, corr,
    seriestype=:scatter,
    yerror=corr_err,
    markersize=10,
    markerstrokewidth=2,
    color=:darkgreen,
    label="Data",
    xlabel="Aspect ratio a/b",
    ylabel="⟨ρ,κ⟩ correlation",
    title="Correlation Scales with Aspect Ratio",
    legend=:bottomright,
    grid=true,
    framestyle=:box,
    size=(600, 500),
    dpi=150
)

plot!(p2, ar_fit, y_ar_fit,
    linewidth=2,
    linestyle=:dash,
    color=:red,
    label="Linear: corr = $(round(c_fit, digits=3)) × (a/b)"
)

# Add e labels
for i in 1:length(e_vals)
    annotate!(p2, aspect_ratio[i]+0.05, corr[i], text("e=$(e_vals[i])", 9, :left))
end

savefig(p2, joinpath(output_dir, "correlation_vs_aspect_ratio.png"))
savefig(p2, joinpath(output_dir, "correlation_vs_aspect_ratio.pdf"))
println("  Saved: correlation_vs_aspect_ratio.png/pdf")

# ============================================================================
# Figure 3: Relaxation Time vs Eccentricity
# ============================================================================
println("Plot 3: τ_relax vs eccentricity")

tau = scaling_df.tau_mean
tau_err = scaling_df.tau_sem

# Fit: τ = 0.879 - 0.515 × e
e_fit = range(0.4, 1.0, length=100)
tau_fit = 0.879 .- 0.515 .* e_fit

p3 = plot(
    e_vals, tau,
    seriestype=:scatter,
    yerror=tau_err,
    markersize=10,
    markerstrokewidth=2,
    color=:purple,
    label="Data",
    xlabel="Eccentricity e",
    ylabel="τ_relax",
    title="Relaxation Time Decreases with Eccentricity",
    legend=:topright,
    grid=true,
    framestyle=:box,
    size=(600, 500),
    dpi=150,
    ylims=(0.2, 0.9)
)

plot!(p3, e_fit, tau_fit,
    linewidth=2,
    linestyle=:dash,
    color=:red,
    label="Fit: τ = 0.88 - 0.52×e\nR² = 0.75"
)

savefig(p3, joinpath(output_dir, "tau_vs_eccentricity.png"))
savefig(p3, joinpath(output_dir, "tau_vs_eccentricity.pdf"))
println("  Saved: tau_vs_eccentricity.png/pdf")

# ============================================================================
# Figure 4: Effective Temperature vs Curvature Ratio
# ============================================================================
println("Plot 4: T_eff vs κ ratio")

T_eff = scaling_df.T_eff_normalized
kappa = scaling_df.kappa_ratio

p4 = plot(
    kappa, T_eff,
    seriestype=:scatter,
    markersize=10,
    markerstrokewidth=2,
    color=:red,
    label="T_eff ∝ 1/τ",
    xlabel="κ_max/κ_min",
    ylabel="T_eff / T_eff(e=0.5)",
    title="Geometry-Induced Effective Heating",
    legend=:topleft,
    grid=true,
    framestyle=:box,
    size=(600, 500),
    dpi=150
)

# Add percentage increase
for i in 1:length(e_vals)
    pct = round(100*(T_eff[i]-1), digits=0)
    label = pct >= 0 ? "+$(Int(pct))%" : "$(Int(pct))%"
    annotate!(p4, kappa[i], T_eff[i]+0.05, text(label, 10, :center))
end

savefig(p4, joinpath(output_dir, "Teff_vs_kappa.png"))
savefig(p4, joinpath(output_dir, "Teff_vs_kappa.pdf"))
println("  Saved: Teff_vs_kappa.png/pdf")

# ============================================================================
# Figure 5: Combined 2-panel figure for publication
# ============================================================================
println("Plot 5: Combined publication figure")

p_combined = plot(
    plot(log_kappa, corr,
        seriestype=:scatter,
        yerror=corr_err,
        markersize=8,
        markerstrokewidth=2,
        color=:blue,
        label="",
        xlabel="ln(κ_max/κ_min)",
        ylabel="⟨ρ,κ⟩ correlation",
        title="(a) Curvature-Density Correlation",
        grid=true,
        framestyle=:box
    ),
    plot(e_vals, tau,
        seriestype=:scatter,
        yerror=tau_err,
        markersize=8,
        markerstrokewidth=2,
        color=:purple,
        label="",
        xlabel="Eccentricity e",
        ylabel="τ_relax",
        title="(b) Velocity Relaxation Time",
        grid=true,
        framestyle=:box,
        ylims=(0.2, 0.9)
    ),
    layout=(1,2),
    size=(1000, 400),
    dpi=150,
    margin=5Plots.mm
)

# Add fit lines
plot!(p_combined[1], x_fit, y_fit, linewidth=2, linestyle=:dash, color=:red, label="")
plot!(p_combined[2], e_fit, tau_fit, linewidth=2, linestyle=:dash, color=:red, label="")

savefig(p_combined, joinpath(output_dir, "combined_scaling_figure.png"))
savefig(p_combined, joinpath(output_dir, "combined_scaling_figure.pdf"))
println("  Saved: combined_scaling_figure.png/pdf")

# ============================================================================
# Figure 6: Log-log plot to show power law
# ============================================================================
println("Plot 6: Log-log power law plot")

# corr vs (1-e²) in log-log
one_minus_e2 = scaling_df.one_minus_e2
log_ome2 = log.(one_minus_e2)
log_corr = log.(corr)

# Fit: log(corr) = log(A) + α × log(1-e²)
# From analysis: A = 0.159, α = -0.49
A_fit = 0.159
alpha_fit = -0.49
x_ll = range(minimum(log_ome2)-0.2, maximum(log_ome2)+0.2, length=100)
y_ll = log(A_fit) .+ alpha_fit .* x_ll

p6 = plot(
    log_ome2, log_corr,
    seriestype=:scatter,
    markersize=10,
    markerstrokewidth=2,
    color=:darkblue,
    label="Data",
    xlabel="ln(1-e²)",
    ylabel="ln(correlation)",
    title="Power Law: corr ~ (1-e²)^α",
    legend=:topright,
    grid=true,
    framestyle=:box,
    size=(600, 500),
    dpi=150
)

plot!(p6, x_ll, y_ll,
    linewidth=2,
    linestyle=:dash,
    color=:red,
    label="α = -0.49 (≈ -1/2)\nR² = 0.98"
)

for i in 1:length(e_vals)
    annotate!(p6, log_ome2[i]+0.05, log_corr[i]+0.03, text("e=$(e_vals[i])", 9, :left))
end

savefig(p6, joinpath(output_dir, "power_law_loglog.png"))
savefig(p6, joinpath(output_dir, "power_law_loglog.pdf"))
println("  Saved: power_law_loglog.png/pdf")

println("\n" * "="^60)
println("ALL PLOTS SAVED TO: $output_dir")
println("="^60)
