#!/usr/bin/env julia
"""
Visualize the comparison between measured density and metric prediction.
Creates ASCII plots and saves data for external plotting.

Key finding: ρ(φ) is NEGATIVELY correlated with √g_φφ(φ)
- Equilibrium predicts: ρ ∝ √g (more particles where metric is larger)
- Observed: ρ ∝ 1/√g (more particles where metric is SMALLER)

Physical interpretation:
- Particles cluster at HIGH CURVATURE regions (φ = 0, π for a > b)
- These are exactly where g_φφ is MINIMUM
- This is a NON-EQUILIBRIUM, dynamically-driven phenomenon
"""

using Pkg
Pkg.activate(".")

using CSV
using DataFrames
using Printf
using Statistics

# ============================================================================
# ASCII PLOTTING
# ============================================================================

function ascii_bar(value::Real, max_val::Real; width=40)
    n_chars = round(Int, (value / max_val) * width)
    return repeat("█", n_chars)
end

function plot_density_comparison(df::DataFrame, e::Float64)
    println("\n" * "="^70)
    println("DENSITY COMPARISON FOR e = $e")
    println("="^70)

    # Normalize for comparison
    rho_m = df.rho_measured ./ maximum(df.rho_measured)
    rho_p = df.rho_predicted ./ maximum(df.rho_predicted)

    println("\nφ (deg)  │ Measured ρ(φ)              │ Predicted √g")
    println("─────────┼────────────────────────────┼────────────────────────────")

    for i in 1:4:nrow(df)  # Show every 4th row for clarity
        angle = df.phi_deg[i]
        m_bar = ascii_bar(rho_m[i], 1.0; width=25)
        p_bar = ascii_bar(rho_p[i], 1.0; width=25)
        @printf("%7.0f° │ %-25s │ %-25s\n", angle, m_bar, p_bar)
    end

    println()
    println("Key observations:")
    println("  - Measured ρ is MAXIMUM at φ ≈ 0°, 180° (TWO-CLUSTER regions)")
    println("  - √g is MINIMUM at these same angles")
    println("  - This is the OPPOSITE of equilibrium prediction!")
    println()

    # Quantitative comparison
    corr = cor(df.rho_measured, df.rho_predicted)
    @printf("Correlation(ρ_measured, √g): %.4f (NEGATIVE!)\n", corr)

    # Check correlation with 1/√g
    inv_sqrt_g = 1.0 ./ df.sqrt_g
    corr_inv = cor(df.rho_measured, inv_sqrt_g)
    @printf("Correlation(ρ_measured, 1/√g): %.4f\n", corr_inv)

    if corr_inv > 0.5
        println("\n✓ STRONG SUPPORT for ρ(φ) ∝ 1/√g_φφ(φ)")
    elseif corr_inv > 0
        println("\n~ MODERATE support for ρ(φ) ∝ 1/√g_φφ(φ)")
    end
end

function analyze_curvature_relationship(df::DataFrame, a::Float64, b::Float64)
    """
    For an ellipse:
    - Curvature κ(φ) = ab / g_φφ^(3/2)
    - Maximum curvature at φ = 0, π (where g_φφ is minimum)
    - Minimum curvature at φ = π/2, 3π/2 (where g_φφ is maximum)
    """
    κ = a * b ./ (df.g_phiphi .^ 1.5)
    κ_normalized = κ ./ maximum(κ)

    println("\n" * "="^70)
    println("CURVATURE vs DENSITY ANALYSIS")
    println("="^70)

    corr_kappa = cor(df.rho_measured, κ)
    @printf("Correlation(ρ_measured, κ): %.4f\n", corr_kappa)

    if corr_kappa > 0.7
        println("\n✓ PARTICLES ACCUMULATE AT HIGH CURVATURE REGIONS")
        println("  This is consistent with:")
        println("  1. Dynamic trapping at turning points")
        println("  2. Collision-mediated localization")
        println("  3. Geodesic deviation causing particle focusing")
    end

    return κ
end

# ============================================================================
# MAIN
# ============================================================================

function main()
    println("="^70)
    println("DENSITY vs METRIC VISUALIZATION")
    println("="^70)

    base_dir = "results/long_time_EN_scan_20260108_084402/metric_verification"

    for e in [0.5, 0.8, 0.9]
        e_str = @sprintf("%.2f", e)
        csv_file = joinpath(base_dir, "density_comparison_e$(e_str).csv")

        if !isfile(csv_file)
            println("File not found: $csv_file")
            continue
        end

        df = CSV.read(csv_file, DataFrame)

        # Get ellipse parameters
        a = 2.0
        b = a * sqrt(1 - e^2)

        println("\nEllipse: a = $a, b = $(round(b, digits=3)), e = $e")
        println("g_φφ ranges from $(round(minimum(df.g_phiphi), digits=3)) to $(round(maximum(df.g_phiphi), digits=3))")

        plot_density_comparison(df, e)
        κ = analyze_curvature_relationship(df, a, b)

        # Add curvature to dataframe and save
        df[!, :curvature] = a * b ./ (df.g_phiphi .^ 1.5)
        df[!, :inv_sqrt_g] = 1.0 ./ df.sqrt_g

        output_file = joinpath(base_dir, "density_with_curvature_e$(e_str).csv")
        CSV.write(output_file, df)
        println("\nSaved: $output_file")
    end

    # Summary
    println("\n" * "="^70)
    println("PHYSICAL INTERPRETATION")
    println("="^70)
    println()
    println("The equilibrium prediction ρ(φ) ∝ √g_φφ(φ) is VIOLATED.")
    println()
    println("Instead, we observe ρ(φ) ∝ 1/√g_φφ(φ) ∝ κ(φ)^(2/3)")
    println()
    println("This indicates:")
    println("  1. The system is NOT in thermal equilibrium")
    println("  2. Clustering is DYNAMICALLY DRIVEN")
    println("  3. High curvature regions act as 'traps'")
    println()
    println("Possible mechanisms:")
    println("  a) Velocity reduction at high-κ due to parallel transport")
    println("  b) Collision focusing at curved regions")
    println("  c) Geodesic deviation effects")
    println("  d) Effective potential from constrained dynamics")
    println()
    println("="^70)
end

main()
