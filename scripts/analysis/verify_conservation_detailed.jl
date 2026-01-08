#!/usr/bin/env julia
# Detailed verification of energy and momentum conservation
# Analyzes all 180 runs to ensure no conservation violations

using HDF5
using Statistics
using DataFrames
using CSV
using CairoMakie
using Printf

println("="^80)
println("DETAILED CONSERVATION VERIFICATION")
println("="^80)
println()

campaign_dir = "results/campaign_eccentricity_scan_20251116_014451"

# ============================================================================
# Analysis Functions
# ============================================================================

"""
Compute detailed conservation metrics
"""
function analyze_conservation(file)
    h5open(file, "r") do f
        # Read trajectories
        time = read(f["trajectories"]["time"])

        # Energy
        if haskey(f, "conservation") && haskey(f["conservation"], "energy")
            energy = read(f["conservation"]["energy"])
        else
            return nothing
        end

        E0 = energy[1]
        dE_abs = energy .- E0
        dE_rel = dE_abs ./ abs(E0)

        # Momentum (if available)
        if haskey(f["conservation"], "momentum_x") && haskey(f["conservation"], "momentum_y")
            px = read(f["conservation"]["momentum_x"])
            py = read(f["conservation"]["momentum_y"])

            p_total = sqrt.(px.^2 .+ py.^2)
            p0 = p_total[1]
            dp_abs = p_total .- p0
            dp_rel = dp_abs ./ max(abs(p0), 1e-10)
        else
            p_total = nothing
            dp_abs = nothing
            dp_rel = nothing
        end

        # Compute statistics
        return (
            time = time,
            energy = energy,
            dE_abs = dE_abs,
            dE_rel = dE_rel,
            dE_max = maximum(abs.(dE_rel)),
            dE_mean = mean(abs.(dE_rel)),
            dE_final = abs(dE_rel[end]),
            dE_drift = (energy[end] - E0) / abs(E0),  # Systematic drift
            dE_std = std(dE_rel),  # Fluctuations
            p_total = p_total,
            dp_abs = dp_abs,
            dp_rel = dp_rel,
            dp_max = isnothing(dp_rel) ? NaN : maximum(abs.(dp_rel)),
            dp_mean = isnothing(dp_rel) ? NaN : mean(abs.(dp_rel)),
            has_momentum = !isnothing(p_total)
        )
    end
end

# ============================================================================
# Main Analysis
# ============================================================================

results = []
n_violations_energy = 0
n_violations_momentum = 0
n_with_momentum = 0

println("Analyzing conservation in all runs...")
println()

files = filter(f -> endswith(f, ".h5"), readdir(campaign_dir, join=true))

for (i, file) in enumerate(files)
    filename = basename(file)

    # Parse parameters
    m = match(r"e([\d\.]+)_N(\d+)_E([\d\.]+)_seed(\d+)", filename)
    if m === nothing
        continue
    end

    e = parse(Float64, m.captures[1])
    N = parse(Int, m.captures[2])
    E_per_N = parse(Float64, m.captures[3])
    seed = parse(Int, m.captures[4])

    cons = analyze_conservation(file)
    if isnothing(cons)
        @warn "No conservation data in $filename"
        continue
    end

    # Check for violations
    energy_violated = cons.dE_max > 0.01  # 1% threshold
    momentum_violated = cons.has_momentum && cons.dp_max > 0.01

    if energy_violated
        n_violations_energy += 1
        println("⚠️  ENERGY VIOLATION: $filename")
        @printf("   ΔE/E₀ = %.6f (max)\n", cons.dE_max)
    end

    if momentum_violated
        n_violations_momentum += 1
        println("⚠️  MOMENTUM VIOLATION: $filename")
        @printf("   ΔP/P₀ = %.6f (max)\n", cons.dp_max)
    end

    if cons.has_momentum
        n_with_momentum += 1
    end

    push!(results, (
        file = filename,
        e = e,
        N = N,
        E_per_N = E_per_N,
        seed = seed,
        dE_max = cons.dE_max,
        dE_mean = cons.dE_mean,
        dE_final = cons.dE_final,
        dE_drift = cons.dE_drift,
        dE_std = cons.dE_std,
        dp_max = cons.dp_max,
        dp_mean = cons.dp_mean,
        energy_violated = energy_violated,
        momentum_violated = momentum_violated
    ))

    if i % 20 == 0
        @printf("Progress: %d/%d\n", i, length(files))
    end
end

println()
println("="^80)
println("CONSERVATION SUMMARY")
println("="^80)
println()

df = DataFrame(results)

@printf("Total runs analyzed: %d\n", nrow(df))
@printf("Runs with momentum data: %d\n", n_with_momentum)
println()

# Energy conservation statistics
println("ENERGY CONSERVATION:")
println("-"^80)
@printf("Violations (ΔE/E₀ > 1%%): %d / %d (%.1f%%)\n",
        n_violations_energy, nrow(df), 100*n_violations_energy/nrow(df))
println()
@printf("Maximum ΔE/E₀: %.6e\n", maximum(df.dE_max))
@printf("Mean ΔE/E₀:    %.6e\n", mean(df.dE_max))
@printf("Median ΔE/E₀:  %.6e\n", median(df.dE_max))
println()

# Energy conservation by category
excellent = count(df.dE_max .< 1e-4)
good = count(1e-4 .<= df.dE_max .< 1e-2)
poor = count(df.dE_max .>= 1e-2)

println("Distribution by quality:")
@printf("  Excellent (ΔE/E₀ < 10⁻⁴): %d / %d (%.1f%%)\n",
        excellent, nrow(df), 100*excellent/nrow(df))
@printf("  Good (10⁻⁴ ≤ ΔE/E₀ < 10⁻²): %d / %d (%.1f%%)\n",
        good, nrow(df), 100*good/nrow(df))
@printf("  Poor (ΔE/E₀ ≥ 10⁻²): %d / %d (%.1f%%)\n",
        poor, nrow(df), 100*poor/nrow(df))
println()

# Momentum conservation
if n_with_momentum > 0
    println("MOMENTUM CONSERVATION:")
    println("-"^80)

    df_with_momentum = filter(row -> !isnan(row.dp_max), df)

    @printf("Violations (ΔP/P₀ > 1%%): %d / %d (%.1f%%)\n",
            n_violations_momentum, nrow(df_with_momentum),
            100*n_violations_momentum/nrow(df_with_momentum))
    println()
    @printf("Maximum ΔP/P₀: %.6e\n", maximum(df_with_momentum.dp_max))
    @printf("Mean ΔP/P₀:    %.6e\n", mean(df_with_momentum.dp_max))
    @printf("Median ΔP/P₀:  %.6e\n", median(df_with_momentum.dp_max))
    println()
end

# Energy conservation vs eccentricity
println("ENERGY CONSERVATION BY ECCENTRICITY:")
println("-"^80)
grouped = groupby(df, :e)
for group in grouped
    e_val = group.e[1]
    @printf("e = %.2f:  ΔE/E₀ = %.2e ± %.2e  (max: %.2e)\n",
            e_val, mean(group.dE_max), std(group.dE_max), maximum(group.dE_max))
end
println()

# ============================================================================
# Visualization
# ============================================================================

println("Generating plots...")

# Plot 1: Distribution of ΔE/E₀
fig1 = Figure(size = (1200, 800))

ax1 = Axis(fig1[1, 1],
    xlabel = "ΔE/E₀ (max)",
    ylabel = "Count",
    title = "Distribution of Energy Conservation Errors",
    yscale = log10
)

hist!(ax1, df.dE_max, bins = 50, color = :steelblue)

vlines!(ax1, [1e-4], color = :green, linestyle = :dash, linewidth = 2, label = "Excellent")
vlines!(ax1, [1e-2], color = :red, linestyle = :dash, linewidth = 2, label = "Poor threshold")

axislegend(ax1, position = :rt)

# Plot 2: ΔE vs Eccentricity
ax2 = Axis(fig1[1, 2],
    xlabel = "Eccentricity (e)",
    ylabel = "ΔE/E₀ (max)",
    title = "Energy Conservation vs Eccentricity",
    yscale = log10
)

scatter!(ax2, df.e, df.dE_max,
    markersize = 8,
    alpha = 0.5,
    color = :steelblue
)

# Add mean line
for e_val in unique(df.e)
    subset = filter(row -> row.e == e_val, df)
    mean_dE = mean(subset.dE_max)
    scatter!(ax2, [e_val], [mean_dE],
        markersize = 15,
        color = :red,
        marker = :x,
        strokewidth = 3
    )
end

hlines!(ax2, [1e-4, 1e-2],
    color = [:green, :red],
    linestyle = :dash,
    linewidth = 2
)

save(joinpath(campaign_dir, "Fig_Conservation_Distribution.png"), fig1, px_per_unit = 2)
println("  ✅ Fig_Conservation_Distribution.png")

# Plot 3: Energy drift vs fluctuations
fig2 = Figure(size = (1000, 700))

ax = Axis(fig2[1, 1],
    xlabel = "Systematic Drift (ΔE_final/E₀)",
    ylabel = "Fluctuations (σ_ΔE/E₀)",
    title = "Energy Error: Drift vs Fluctuations",
    xscale = log10,
    yscale = log10
)

scatter!(ax, abs.(df.dE_drift), df.dE_std,
    markersize = 10,
    color = df.e,
    colormap = :thermal,
    alpha = 0.6
)

Colorbar(fig2[1, 2], label = "Eccentricity (e)")

# Reference lines
lines!(ax, [1e-10, 1e-1], [1e-10, 1e-1],
    color = :black,
    linestyle = :dash,
    linewidth = 2,
    label = "Drift = Fluctuations"
)

axislegend(ax, position = :rb)

save(joinpath(campaign_dir, "Fig_Conservation_DriftVsFluctuations.png"), fig2, px_per_unit = 2)
println("  ✅ Fig_Conservation_DriftVsFluctuations.png")

# Plot 4: Temporal evolution of worst cases
println("Analyzing worst conservation cases...")

worst_files = sort(df, :dE_max, rev=true)[1:min(5, nrow(df)), :file]

fig3 = Figure(size = (1400, 900))

for (i, filename) in enumerate(worst_files)
    filepath = joinpath(campaign_dir, filename)
    cons = analyze_conservation(filepath)

    if isnothing(cons)
        continue
    end

    # Parse eccentricity
    m = match(r"e([\d\.]+)", filename)
    e_val = parse(Float64, m.captures[1])

    row = div(i-1, 2) + 1
    col = mod(i-1, 2) + 1

    ax = Axis(fig3[row, col],
        xlabel = "Time",
        ylabel = "ΔE/E₀",
        title = @sprintf("e=%.2f, ΔE_max=%.2e", e_val, cons.dE_max)
    )

    lines!(ax, cons.time, cons.dE_rel,
        color = :steelblue,
        linewidth = 2
    )

    hlines!(ax, [0], color = :black, linestyle = :dash, linewidth = 1)
    hlines!(ax, [1e-4, -1e-4], color = :green, linestyle = :dash, linewidth = 1)
    hlines!(ax, [1e-2, -1e-2], color = :red, linestyle = :dash, linewidth = 1)
end

save(joinpath(campaign_dir, "Fig_Conservation_WorstCases.png"), fig3, px_per_unit = 2)
println("  ✅ Fig_Conservation_WorstCases.png")

# ============================================================================
# Save Results
# ============================================================================

CSV.write(joinpath(campaign_dir, "conservation_analysis_detailed.csv"), df)
println("  ✅ conservation_analysis_detailed.csv")

println()
println("="^80)
println("CONSERVATION VERIFICATION COMPLETED")
println("="^80)
println()

if n_violations_energy > 0
    println("⚠️  WARNING: Found $n_violations_energy energy conservation violations")
    println("   Review worst cases in Fig_Conservation_WorstCases.png")
else
    println("✅ All runs pass energy conservation test (ΔE/E₀ < 1%)")
end

if n_violations_momentum > 0
    println("⚠️  WARNING: Found $n_violations_momentum momentum conservation violations")
else
    println("✅ All runs pass momentum conservation test")
end

println()
println("Next steps:")
println("  1. If violations found: investigate numerical method")
println("  2. Check if violations correlate with high e")
println("  3. Consider tighter tolerance for adaptive timestep")
