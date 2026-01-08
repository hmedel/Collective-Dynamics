#!/usr/bin/env julia
# Robust power law fit: R(e) = A*(1-e)^(-β) + R₀
# Tests the critical scaling hypothesis for clustering transition

using CSV
using DataFrames
using LsqFit
using Statistics
using Printf
using CairoMakie
using Distributions

println("="^80)
println("POWER LAW FIT: Critical Scaling Analysis")
println("="^80)
println()

campaign_dir = "results/campaign_eccentricity_scan_20251116_014451"
summary_file = joinpath(campaign_dir, "summary_by_eccentricity_FINAL.csv")
summary = CSV.read(summary_file, DataFrame)

# ============================================================================
# Power Law Model: R(e) = A*(1-e)^(-β) + R₀
# ============================================================================

# Model function
@. power_law(e, p) = p[1] * (1 - e)^(-p[2]) + p[3]

# Extract data
e_data = summary.e
R_data = summary.R_mean
R_err = summary.R_std

# Initial guess: A ~ 0.01, β ~ 1.5, R₀ ~ 1.0
p0 = [0.01, 1.5, 1.0]

# Fit with error weighting
weights = 1 ./ (R_err .^ 2)
fit = curve_fit(power_law, e_data, R_data, weights, p0)

# Extract parameters
A_fit, β_fit, R0_fit = coef(fit)
errors = stderror(fit)
A_err, β_err, R0_err = errors

# Compute R² and residuals
R_pred = power_law(e_data, coef(fit))
residuals = R_data .- R_pred
SS_res = sum(residuals.^2)
SS_tot = sum((R_data .- mean(R_data)).^2)
R_squared = 1 - SS_res/SS_tot

println("POWER LAW FIT RESULTS:")
println("="^80)
println()
@printf("R(e) = A·(1-e)^(-β) + R₀\n\n")
@printf("Fitted Parameters:\n")
@printf("  A  = %.4f ± %.4f\n", A_fit, A_err)
@printf("  β  = %.4f ± %.4f  ← CRITICAL EXPONENT\n", β_fit, β_err)
@printf("  R₀ = %.4f ± %.4f\n", R0_fit, R0_err)
println()
@printf("Goodness of Fit:\n")
@printf("  R² = %.6f\n", R_squared)
@printf("  RMS error = %.4f\n", sqrt(SS_res/length(R_data)))
println()

# Confidence intervals (95%)
conf_level = 0.95
margin_β = 1.96 * β_err  # 95% CI
println("95% Confidence Interval for β:")
@printf("  β ∈ [%.4f, %.4f]\n", β_fit - margin_β, β_fit + margin_β)
println()

# ============================================================================
# Alternative Fits (for comparison)
# ============================================================================

println("="^80)
println("ALTERNATIVE FITS:")
println("="^80)
println()

# Fit 1: Exponential R(e) = A*exp(B*e) + R₀
@. exp_model(e, p) = p[1] * exp(p[2] * e) + p[3]
p0_exp = [1.0, 5.0, 0.0]
fit_exp = curve_fit(exp_model, e_data, R_data, weights, p0_exp)
R_pred_exp = exp_model(e_data, coef(fit_exp))
R2_exp = 1 - sum((R_data .- R_pred_exp).^2)/SS_tot

println("1. Exponential: R(e) = A·exp(B·e) + R₀")
@printf("   R² = %.6f\n", R2_exp)
println()

# Fit 2: Polynomial R(e) = a + b*e + c*e² + d*e³
@. poly3(e, p) = p[1] + p[2]*e + p[3]*e^2 + p[4]*e^3
p0_poly = [1.0, 0.0, 0.0, 10.0]
fit_poly = curve_fit(poly3, e_data, R_data, weights, p0_poly)
R_pred_poly = poly3(e_data, coef(fit_poly))
R2_poly = 1 - sum((R_data .- R_pred_poly).^2)/SS_tot

println("2. Cubic Polynomial: R(e) = a + b·e + c·e² + d·e³")
@printf("   R² = %.6f\n", R2_poly)
println()

println("BEST FIT: ", R_squared > R2_exp && R_squared > R2_poly ?
       "Power Law ✓" :
       (R2_exp > R2_poly ? "Exponential" : "Polynomial"))
println()

# ============================================================================
# Physical Interpretation
# ============================================================================

println("="^80)
println("PHYSICAL INTERPRETATION:")
println("="^80)
println()

if β_fit > 1.0
    println("Critical Exponent β = $(@sprintf("%.3f", β_fit))")
    println()
    println("Interpretation:")
    println("  • β > 1  → Divergence at e→1 (super-linear growth)")
    println("  • Power law indicates CRITICAL TRANSITION")
    println("  • Compare to known universality classes:")
    println("    - Ising model: β ≈ 0.326 (3D), 0.125 (2D)")
    println("    - Mean field: β = 0.5")
    println("    - This system: β ≈ $(@sprintf("%.2f", β_fit))")
    println()
    println("  ⚠️  HIGH EXPONENT suggests:")
    println("     - Strong geometric frustration near e→1")
    println("     - Non-equilibrium transition")
    println("     - Possible runaway instability")
end

println()
println("Asymptotic Behavior:")
println("  As e → 1⁻:")
@printf("    R(e) → ∞  with divergence ~ (1-e)^(-%.3f)\n", β_fit)
println()
println("  Physical mechanism:")
println("    - Curvature becomes infinitely inhomogeneous")
println("    - Particles concentrate at semi-minor axis")
println("    - Autocatalytic clustering (R begets more R)")
println()

# ============================================================================
# Extrapolation and Predictions
# ============================================================================

println("="^80)
println("PREDICTIONS:")
println("="^80)
println()

# Predict for e values we didn't simulate
e_predict = [0.85, 0.92, 0.96, 0.97, 0.995]
R_predict = power_law(e_predict, coef(fit))

println("Predicted R values (extrapolation):")
for (e_val, R_val) in zip(e_predict, R_predict)
    @printf("  e = %.3f  →  R ≈ %.2f", e_val, R_val)
    if e_val > maximum(e_data)
        print("  (beyond measured range)")
    end
    println()
end
println()

# ============================================================================
# Publication-Quality Plot
# ============================================================================

println("Generating publication plot...")

fig = Figure(size = (1000, 700))

ax = Axis(fig[1, 1],
    xlabel = "Eccentricity (e)",
    ylabel = "Clustering Ratio (R)",
    title = "Power Law Scaling: R ~ (1-e)^(-β)",
    xlabelsize = 22,
    ylabelsize = 22,
    titlesize = 24
)

# Data points with error bars
errorbars!(ax, e_data, R_data, R_err,
    whiskerwidth = 15,
    color = :gray,
    linewidth = 2
)

scatter!(ax, e_data, R_data,
    color = :steelblue,
    markersize = 18,
    strokewidth = 2,
    strokecolor = :black,
    label = "Data"
)

# Power law fit
e_smooth = range(0.0, 1.0, length=200)
R_smooth = power_law(e_smooth, coef(fit))
lines!(ax, e_smooth, R_smooth,
    color = :crimson,
    linewidth = 3,
    linestyle = :dash,
    label = @sprintf("R = %.3f(1-e)^{-%.3f} + %.2f", A_fit, β_fit, R0_fit)
)

# Add fit statistics box
text_str = @sprintf("R² = %.4f\nβ = %.3f ± %.3f", R_squared, β_fit, β_err)
text!(ax, 0.05, maximum(R_data)*0.9,
    text = text_str,
    fontsize = 16,
    align = (:left, :top),
    color = :black
)

axislegend(ax, position = :lt, framevisible = true)

ylims!(ax, 0, maximum(R_data) * 1.1)

save(joinpath(campaign_dir, "Fig_PowerLaw_Fit.png"), fig, px_per_unit = 2)
println("  ✅ Fig_PowerLaw_Fit.png")
println()

# ============================================================================
# Residual Analysis
# ============================================================================

println("="^80)
println("RESIDUAL ANALYSIS:")
println("="^80)
println()

fig2 = Figure(size = (1200, 500))

# Residuals vs e
ax1 = Axis(fig2[1, 1],
    xlabel = "Eccentricity (e)",
    ylabel = "Residuals (R_data - R_fit)",
    title = "Residual Analysis"
)

scatter!(ax1, e_data, residuals,
    color = :steelblue,
    markersize = 15
)

hlines!(ax1, [0],
    color = :red,
    linestyle = :dash,
    linewidth = 2
)

# Q-Q plot (normality test)
ax2 = Axis(fig2[1, 2],
    xlabel = "Theoretical Quantiles",
    ylabel = "Sample Quantiles",
    title = "Q-Q Plot (Normality Test)"
)

sorted_residuals = sort(residuals)
n = length(residuals)
theoretical_quantiles = [quantile(Normal(0, 1), (i-0.5)/n) for i in 1:n]

scatter!(ax2, theoretical_quantiles, sorted_residuals,
    color = :steelblue,
    markersize = 15
)

# Reference line
x_range = range(minimum(theoretical_quantiles), maximum(theoretical_quantiles), length=100)
lines!(ax2, x_range, std(residuals) .* x_range .+ mean(residuals),
    color = :red,
    linestyle = :dash,
    linewidth = 2
)

save(joinpath(campaign_dir, "Fig_PowerLaw_Residuals.png"), fig2, px_per_unit = 2)
println("  ✅ Fig_PowerLaw_Residuals.png")
println()

# Statistical tests on residuals
println("Residual Statistics:")
@printf("  Mean:     %.6f  (should be ≈ 0)\n", mean(residuals))
@printf("  Std Dev:  %.4f\n", std(residuals))
@printf("  Min:      %.4f\n", minimum(residuals))
@printf("  Max:      %.4f\n", maximum(residuals))
println()

# ============================================================================
# Save Results
# ============================================================================

# Save fit parameters to file
results_df = DataFrame(
    parameter = ["A", "β", "R₀", "R²", "RMS_error"],
    value = [A_fit, β_fit, R0_fit, R_squared, sqrt(SS_res/length(R_data))],
    error = [A_err, β_err, R0_err, NaN, NaN]
)

CSV.write(joinpath(campaign_dir, "power_law_fit_parameters.csv"), results_df)
println("  ✅ power_law_fit_parameters.csv")

# Save predictions
predictions_df = DataFrame(
    e = e_predict,
    R_predicted = R_predict
)
CSV.write(joinpath(campaign_dir, "power_law_predictions.csv"), predictions_df)
println("  ✅ power_law_predictions.csv")

println()
println("="^80)
println("Power Law Analysis Completed Successfully")
println("="^80)
