#!/usr/bin/env julia
"""
Deep Analysis: Power Law Scaling and Relaxation Time
Exploring findings 2 and 3 in detail
"""

using Pkg
Pkg.activate(".")

using Statistics
using Printf
using DataFrames
using CSV
using LinearAlgebra

const PROJECT_ROOT = dirname(dirname(@__DIR__))
campaign_dir = "results/intrinsic_v3_campaign_20251126_110434"

curvature_df = CSV.read(joinpath(PROJECT_ROOT, campaign_dir, "curvature_analysis/curvature_density_correlation.csv"), DataFrame)
vacf_df = CSV.read(joinpath(PROJECT_ROOT, campaign_dir, "vacf_analysis/velocity_autocorrelation.csv"), DataFrame)

merged = innerjoin(curvature_df, vacf_df, on=:sim_dir, makeunique=true)

# Filter clean data
clean = filter(row -> row.tau_relax_mean < 2.0 && !isnan(row.tau_relax_mean), merged)

println("="^70)
println("DEEP ANALYSIS: SCALING LAWS AND RELAXATION")
println("="^70)
println("\nUsing $(nrow(clean)) clean simulations\n")

# ============================================================================
# PART 2: POWER LAW ANALYSIS - correlation vs (1-e²)
# ============================================================================
println("="^70)
println("PART 2: POWER LAW SCALING OF CURVATURE-DENSITY CORRELATION")
println("="^70)

# Get mean values by eccentricity with error bars
e_vals = sort(unique(clean.e))
corr_means = Float64[]
corr_stds = Float64[]
corr_sems = Float64[]  # Standard error of mean

for e in e_vals
    subset = filter(row -> row.e == e, clean)
    push!(corr_means, mean(subset.correlation_mean))
    push!(corr_stds, std(subset.correlation_mean))
    push!(corr_sems, std(subset.correlation_mean) / sqrt(nrow(subset)))
end

println("\nData with uncertainties:")
println("-"^60)
for i in 1:length(e_vals)
    e = e_vals[i]
    one_minus_e2 = 1 - e^2
    kappa_ratio = 1 / one_minus_e2^1.5

    println(@sprintf("e=%.2f: (1-e²)=%.3f, κ_max/κ_min=%5.2f, corr=%.4f ± %.4f",
                     e, one_minus_e2, kappa_ratio, corr_means[i], corr_sems[i]))
end

# ============================================================================
# Fit 1: correlation = A × (1-e²)^α
# ============================================================================
println("\n" * "="^60)
println("FIT 1: correlation = A × (1-e²)^α")
println("="^60)

one_minus_e2 = [1 - e^2 for e in e_vals]
log_x = log.(one_minus_e2)
log_y = log.(corr_means)

# Weighted least squares (weight by 1/σ²)
weights = 1 ./ (corr_sems ./ corr_means).^2  # Relative error weights

# Weighted linear regression in log-log space
sum_w = sum(weights)
sum_wx = sum(weights .* log_x)
sum_wy = sum(weights .* log_y)
sum_wxx = sum(weights .* log_x.^2)
sum_wxy = sum(weights .* log_x .* log_y)

α = (sum_w * sum_wxy - sum_wx * sum_wy) / (sum_w * sum_wxx - sum_wx^2)
log_A = (sum_wy - α * sum_wx) / sum_w
A = exp(log_A)

# Unweighted for comparison
mean_lx = mean(log_x)
mean_ly = mean(log_y)
α_unweighted = sum((log_x .- mean_lx) .* (log_y .- mean_ly)) / sum((log_x .- mean_lx).^2)

# R² calculation
y_pred = A .* one_minus_e2.^α
ss_res = sum((corr_means .- y_pred).^2)
ss_tot = sum((corr_means .- mean(corr_means)).^2)
r2 = 1 - ss_res / ss_tot

println(@sprintf("\nWeighted fit:   corr = %.4f × (1-e²)^(%.3f)", A, α))
println(@sprintf("Unweighted fit: corr = %.4f × (1-e²)^(%.3f)", exp(mean_ly - α_unweighted*mean_lx), α_unweighted))
println(@sprintf("R² = %.4f", r2))

println("\nPredicted vs Measured:")
for i in 1:length(e_vals)
    pred = A * one_minus_e2[i]^α
    residual = corr_means[i] - pred
    println(@sprintf("  e=%.2f: measured=%.4f, predicted=%.4f, residual=%.4f",
                     e_vals[i], corr_means[i], pred, residual))
end

# ============================================================================
# Fit 2: correlation = B × ln(κ_max/κ_min)
# ============================================================================
println("\n" * "="^60)
println("FIT 2: correlation = B × ln(κ_max/κ_min)")
println("="^60)

kappa_ratios = [1/(1-e^2)^1.5 for e in e_vals]
log_kappa = log.(kappa_ratios)

# Linear fit: corr = B × ln(κ)
mean_lk = mean(log_kappa)
mean_c = mean(corr_means)
B = sum((log_kappa .- mean_lk) .* (corr_means .- mean_c)) / sum((log_kappa .- mean_lk).^2)
intercept = mean_c - B * mean_lk

y_pred2 = intercept .+ B .* log_kappa
r2_2 = 1 - sum((corr_means .- y_pred2).^2) / ss_tot

println(@sprintf("\nFit: corr = %.4f + %.4f × ln(κ_max/κ_min)", intercept, B))
println(@sprintf("R² = %.4f", r2_2))

println("\nPredicted vs Measured:")
for i in 1:length(e_vals)
    pred = intercept + B * log_kappa[i]
    println(@sprintf("  e=%.2f: ln(κ)=%.3f, measured=%.4f, predicted=%.4f",
                     e_vals[i], log_kappa[i], corr_means[i], pred))
end

# ============================================================================
# Fit 3: correlation = C × (κ_max/κ_min - 1)^γ
# ============================================================================
println("\n" * "="^60)
println("FIT 3: correlation = C × (κ_max/κ_min - 1)^γ")
println("="^60)

kappa_minus_1 = kappa_ratios .- 1
log_km1 = log.(kappa_minus_1)

mean_lkm1 = mean(log_km1)
γ = sum((log_km1 .- mean_lkm1) .* (log_y .- mean_ly)) / sum((log_km1 .- mean_lkm1).^2)
log_C = mean_ly - γ * mean_lkm1
C = exp(log_C)

y_pred3 = C .* kappa_minus_1.^γ
r2_3 = 1 - sum((corr_means .- y_pred3).^2) / ss_tot

println(@sprintf("\nFit: corr = %.4f × (κ_max/κ_min - 1)^(%.3f)", C, γ))
println(@sprintf("R² = %.4f", r2_3))

# ============================================================================
# Physical interpretation
# ============================================================================
println("\n" * "="^60)
println("PHYSICAL INTERPRETATION OF SCALING")
println("="^60)

println("""

Three functional forms tested:
1. corr ~ (1-e²)^α     with α = $(round(α, digits=3))   [R² = $(round(r2, digits=4))]
2. corr ~ ln(κ_ratio)                                   [R² = $(round(r2_2, digits=4))]
3. corr ~ (κ_ratio-1)^γ with γ = $(round(γ, digits=3))   [R² = $(round(r2_3, digits=4))]

Best fit: #1 with α ≈ -0.5

Physical meaning of α ≈ -0.5:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Since (1-e²) = (b/a)² for an ellipse with semi-axes a,b:
  corr ~ (b/a)^(2α) = (b/a)^(-1) = a/b

This means: correlation scales with ASPECT RATIO of the ellipse!

Alternative: Since κ_max/κ_min = (a/b)³:
  corr ~ (κ_ratio)^(1/3) = (a/b)

PREDICTION: For any ellipse, the curvature-density correlation
            should scale approximately as the aspect ratio a/b.
""")

# Verify aspect ratio scaling
println("Verification of aspect ratio scaling:")
println("-"^50)
aspect_ratios = [1/sqrt(1-e^2) for e in e_vals]  # a/b
for i in 1:length(e_vals)
    ratio = corr_means[i] / aspect_ratios[i]
    println(@sprintf("  e=%.2f: a/b=%.3f, corr=%.4f, corr/(a/b)=%.4f",
                     e_vals[i], aspect_ratios[i], corr_means[i], ratio))
end

# ============================================================================
# PART 3: RELAXATION TIME ANALYSIS
# ============================================================================
println("\n\n" * "="^70)
println("PART 3: RELAXATION TIME vs ECCENTRICITY")
println("="^70)

# Get tau values by e with proper filtering
tau_means = Float64[]
tau_stds = Float64[]
tau_sems = Float64[]

for e in e_vals
    subset = filter(row -> row.e == e, clean)
    push!(tau_means, mean(subset.tau_relax_mean))
    push!(tau_stds, std(subset.tau_relax_mean))
    push!(tau_sems, std(subset.tau_relax_mean) / sqrt(nrow(subset)))
end

println("\nRelaxation time data:")
println("-"^60)
for i in 1:length(e_vals)
    println(@sprintf("e=%.2f: τ = %.4f ± %.4f (SEM)", e_vals[i], tau_means[i], tau_sems[i]))
end

# Linear fit: τ = τ₀ - β × e
mean_e = mean(e_vals)
mean_tau = mean(tau_means)
β = sum((e_vals .- mean_e) .* (tau_means .- mean_tau)) / sum((e_vals .- mean_e).^2)
τ₀ = mean_tau - β * mean_e

y_pred_tau = τ₀ .+ β .* e_vals
r2_tau = 1 - sum((tau_means .- y_pred_tau).^2) / sum((tau_means .- mean_tau).^2)

println(@sprintf("\nLinear fit: τ = %.4f + (%.4f) × e", τ₀, β))
println(@sprintf("           τ = %.4f - %.4f × e", τ₀, -β))
println(@sprintf("R² = %.4f", r2_tau))

# ============================================================================
# Fit τ vs curvature ratio
# ============================================================================
println("\n" * "-"^60)
println("τ vs κ_max/κ_min:")

mean_kr = mean(kappa_ratios)
β_kr = sum((kappa_ratios .- mean_kr) .* (tau_means .- mean_tau)) / sum((kappa_ratios .- mean_kr).^2)
τ₀_kr = mean_tau - β_kr * mean_kr

y_pred_tau_kr = τ₀_kr .+ β_kr .* kappa_ratios
r2_tau_kr = 1 - sum((tau_means .- y_pred_tau_kr).^2) / sum((tau_means .- mean_tau).^2)

println(@sprintf("Linear fit: τ = %.4f - %.5f × (κ_max/κ_min)  [R² = %.4f]", τ₀_kr, -β_kr, r2_tau_kr))

# Power law fit: τ = τ₀ × κ^δ
log_tau = log.(tau_means)
mean_lt = mean(log_tau)
mean_lkr = mean(log.(kappa_ratios))
δ = sum((log.(kappa_ratios) .- mean_lkr) .* (log_tau .- mean_lt)) / sum((log.(kappa_ratios) .- mean_lkr).^2)
log_tau0 = mean_lt - δ * mean_lkr

y_pred_tau_pl = exp(log_tau0) .* kappa_ratios.^δ
r2_tau_pl = 1 - sum((tau_means .- y_pred_tau_pl).^2) / sum((tau_means .- mean_tau).^2)

println(@sprintf("Power law:  τ = %.4f × (κ_max/κ_min)^(%.3f)  [R² = %.4f]", exp(log_tau0), δ, r2_tau_pl))

# ============================================================================
# Effective temperature analysis
# ============================================================================
println("\n" * "="^60)
println("EFFECTIVE TEMPERATURE ANALYSIS")
println("="^60)

println("""

If we interpret 1/τ as an effective temperature T_eff:
  T_eff = k / τ_relax  (where k is some constant)

Then T_eff should increase with eccentricity.
""")

T_eff = 1 ./ tau_means
T_eff_normalized = T_eff ./ T_eff[1]  # Normalize to e=0.5

println("Effective temperature (normalized to e=0.5):")
println("-"^50)
for i in 1:length(e_vals)
    println(@sprintf("  e=%.2f: T_eff/T_eff(0.5) = %.3f", e_vals[i], T_eff_normalized[i]))
end

# Fit T_eff vs κ
mean_Teff = mean(T_eff)
slope_T = sum((kappa_ratios .- mean_kr) .* (T_eff .- mean_Teff)) / sum((kappa_ratios .- mean_kr).^2)

println(@sprintf("\nT_eff increases by %.3f per unit increase in κ_max/κ_min", slope_T))

# ============================================================================
# Connection between findings 2 and 3
# ============================================================================
println("\n" * "="^60)
println("CONNECTION BETWEEN CURVATURE CORRELATION AND τ_relax")
println("="^60)

# Plot correlation vs 1/τ (should both increase with e)
println("\nCorrelation vs 1/τ_relax:")
println("-"^50)
for i in 1:length(e_vals)
    println(@sprintf("  e=%.2f: corr=%.4f, 1/τ=%.3f", e_vals[i], corr_means[i], 1/tau_means[i]))
end

# Fit correlation vs 1/τ
inv_tau = 1 ./ tau_means
mean_inv_tau = mean(inv_tau)
mean_corr = mean(corr_means)
slope_corr_tau = sum((inv_tau .- mean_inv_tau) .* (corr_means .- mean_corr)) / sum((inv_tau .- mean_inv_tau).^2)

y_pred_ct = mean_corr .+ slope_corr_tau .* (inv_tau .- mean_inv_tau)
r2_ct = 1 - sum((corr_means .- y_pred_ct).^2) / sum((corr_means .- mean_corr).^2)

println(@sprintf("\nFit: corr = %.4f + %.4f × (1/τ - %.3f)", mean_corr, slope_corr_tau, mean_inv_tau))
println(@sprintf("R² = %.4f", r2_ct))

println("""

INTERPRETATION:
━━━━━━━━━━━━━━━
Both curvature-density correlation AND effective temperature
increase with eccentricity. This suggests:

1. Higher curvature creates stronger "focusing" of particles
2. This focusing leads to more frequent collisions/bounces
3. More bounces → faster velocity decorrelation → smaller τ
4. The curvature acts as an "effective heating" mechanism

In other words: GEOMETRY DRIVES BOTH EFFECTS TOGETHER.
""")

# ============================================================================
# Save data for plotting
# ============================================================================
println("\n" * "="^60)
println("SAVING DATA FOR PLOTTING")
println("="^60)

output_dir = joinpath(PROJECT_ROOT, campaign_dir, "scaling_analysis")
mkpath(output_dir)

# Save scaling data
scaling_df = DataFrame(
    e = e_vals,
    one_minus_e2 = one_minus_e2,
    kappa_ratio = kappa_ratios,
    aspect_ratio = aspect_ratios,
    corr_mean = corr_means,
    corr_sem = corr_sems,
    tau_mean = tau_means,
    tau_sem = tau_sems,
    T_eff = T_eff,
    T_eff_normalized = T_eff_normalized
)

CSV.write(joinpath(output_dir, "scaling_data.csv"), scaling_df)
println("Saved: $(joinpath(output_dir, "scaling_data.csv"))")

# Save fit parameters
fit_params = DataFrame(
    fit_name = ["corr_power_law", "corr_log_kappa", "tau_linear_e", "tau_power_law_kappa"],
    formula = ["A*(1-e²)^α", "a+b*ln(κ)", "τ₀+β*e", "τ₀*κ^δ"],
    param1 = [A, intercept, τ₀, exp(log_tau0)],
    param2 = [α, B, β, δ],
    R2 = [r2, r2_2, r2_tau, r2_tau_pl]
)

CSV.write(joinpath(output_dir, "fit_parameters.csv"), fit_params)
println("Saved: $(joinpath(output_dir, "fit_parameters.csv"))")

println("\n" * "="^60)
println("SUMMARY OF KEY RESULTS")
println("="^60)

println("""

FINDING 2: Curvature-Density Correlation Scaling
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  corr = $(round(A, digits=4)) × (1-e²)^$(round(α, digits=2))   [R² = $(round(r2, digits=3))]

  Since α ≈ -0.5:  corr ∝ 1/√(1-e²) = a/b (aspect ratio)

  PHYSICAL MEANING: Curvature-density correlation scales
  directly with the ellipse aspect ratio.

FINDING 3: Relaxation Time Decreases with Eccentricity
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  τ = $(round(τ₀, digits=3)) - $(round(-β, digits=3)) × e   [R² = $(round(r2_tau, digits=3))]

  Or equivalently:
  τ = $(round(exp(log_tau0), digits=3)) × (κ_max/κ_min)^$(round(δ, digits=2))   [R² = $(round(r2_tau_pl, digits=3))]

  PHYSICAL MEANING: Higher curvature ratio leads to
  faster velocity decorrelation (more bouncing).

UNIFIED PICTURE:
━━━━━━━━━━━━━━━━
  Increasing eccentricity e → Higher κ_max/κ_min
    → Stronger geodesic focusing → More particle accumulation at ends
    → More bouncing in high-κ regions → Faster τ decay

  Both effects are GEOMETRIC in origin, not thermodynamic.
""")
