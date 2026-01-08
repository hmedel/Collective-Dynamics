#!/usr/bin/env julia
# Spatial Correlation Analysis: g(Δφ)
# Pair correlation function to detect clustering structure

using HDF5
using Statistics
using CairoMakie
using Printf
using StatsBase

println("="^80)
println("SPATIAL CORRELATION ANALYSIS: g(Δφ)")
println("="^80)
println()

campaign_dir = "results/campaign_eccentricity_scan_20251116_014451"

# ============================================================================
# Configuration
# ============================================================================

eccentricities = [0.0, 0.5, 0.7, 0.9, 0.95, 0.98, 0.99]
n_bins = 120  # Angular resolution for g(Δφ)

println("Configuration:")
println("  Eccentricities: ", eccentricities)
println("  Angular bins: $n_bins")
println()

# ============================================================================
# Analysis Functions
# ============================================================================

"""
Compute pair correlation function g(Δφ)

g(Δφ) = ⟨ρ(φ)ρ(φ+Δφ)⟩ / ⟨ρ⟩²

where ρ(φ) is local density
"""
function pair_correlation(phi_positions, n_bins=120)
    N = length(phi_positions)

    # Create bins for Δφ
    delta_phi_edges = range(0, π, length=n_bins+1)
    delta_phi_centers = (delta_phi_edges[1:end-1] .+ delta_phi_edges[2:end]) ./ 2

    # Compute all pairwise distances (periodic on circle)
    distances = Float64[]

    for i in 1:N
        for j in i+1:N
            # Angular distance (shortest on circle)
            d = abs(phi_positions[i] - phi_positions[j])
            d = min(d, 2π - d)  # Periodic boundary

            push!(distances, d)
        end
    end

    # Histogram of distances
    hist = fit(Histogram, distances, delta_phi_edges)
    counts = hist.weights

    # Normalize by:
    # 1. Number of pairs
    # 2. "Area" of shell at distance Δφ (proportional to Δφ for uniform density)
    # For circle: area ~ Δφ

    g = zeros(n_bins)
    for i in 1:n_bins
        # Expected count for uniform distribution
        delta = delta_phi_centers[i]
        area_shell = 2 * delta  # Arc length at distance delta on both sides

        # Density of pairs at this distance
        if area_shell > 0
            expected_uniform = (N * (N-1) / 2) * (step(delta_phi_edges) / π)
            g[i] = counts[i] / expected_uniform
        else
            g[i] = 0.0
        end
    end

    return delta_phi_centers, g
end

"""
Compute structure factor S(k) via Fourier transform
S(k) = |∑ exp(i k φⱼ)|² / N
"""
function structure_factor(phi_positions, k_max=10)
    N = length(phi_positions)
    k_values = 0:k_max

    S = zeros(length(k_values))

    for (i, k) in enumerate(k_values)
        # Compute Fourier coefficient
        sum_real = sum(cos.(k .* phi_positions))
        sum_imag = sum(sin.(k .* phi_positions))

        S[i] = (sum_real^2 + sum_imag^2) / N
    end

    return k_values, S
end

"""
Compute correlation length ξ from exponential fit of g(r)
g(r) ~ exp(-r/ξ) for r > 0
"""
function correlation_length(delta_phi, g)
    # Find where g crosses 1 (decorrelation)
    # Only use positive Δφ > 0.1 to avoid artifacts near Δφ=0

    valid = (delta_phi .> 0.1) .& (g .> 0.1)

    if sum(valid) < 5
        return NaN
    end

    # Fit exponential decay: log(g) ~ -Δφ/ξ
    x = delta_phi[valid]
    y = log.(g[valid])

    # Linear fit
    slope = sum((x .- mean(x)) .* (y .- mean(y))) / sum((x .- mean(x)).^2)

    if slope < 0
        xi = -1 / slope
    else
        xi = NaN  # No decay
    end

    return xi
end

# ============================================================================
# Main Analysis Loop
# ============================================================================

results = Dict()

for e_target in eccentricities
    println("="^80)
    @printf("Analyzing e = %.2f\n", e_target)
    println("="^80)

    # Find all runs for this eccentricity
    files = filter(readdir(campaign_dir, join=true)) do f
        endswith(f, ".h5") && occursin(@sprintf("e%.3f", e_target), f)
    end

    if isempty(files)
        @warn "No files found for e = $e_target"
        continue
    end

    println("  Found $(length(files)) runs")

    # Collect g(Δφ) from all runs and ensemble average
    g_ensemble = zeros(n_bins)
    S_ensemble = zeros(11)  # k=0 to k=10
    xi_values = Float64[]

    for file in files
        h5open(file, "r") do f
            # Read final state
            phi_final = read(f["trajectories"]["phi"])[:, end]

            # Compute pair correlation
            delta_phi, g = pair_correlation(phi_final, n_bins)
            g_ensemble .+= g

            # Structure factor
            k_vals, S = structure_factor(phi_final, 10)
            S_ensemble .+= S

            # Correlation length
            xi = correlation_length(delta_phi, g)
            if !isnan(xi)
                push!(xi_values, xi)
            end
        end
    end

    # Ensemble average
    g_ensemble ./= length(files)
    S_ensemble ./= length(files)

    # Delta_phi grid (same for all runs)
    delta_phi_edges = range(0, π, length=n_bins+1)
    delta_phi_centers = (delta_phi_edges[1:end-1] .+ delta_phi_edges[2:end]) ./ 2

    # Compute ensemble correlation length
    xi_mean = isempty(xi_values) ? NaN : mean(xi_values)
    xi_std = isempty(xi_values) ? NaN : std(xi_values)

    println(@sprintf("  ⟨ξ⟩ = %.3f ± %.3f", xi_mean, xi_std))

    # Find peak in g(Δφ)
    peak_idx = argmax(g_ensemble[2:end]) + 1  # Skip Δφ=0
    peak_position = delta_phi_centers[peak_idx]
    peak_value = g_ensemble[peak_idx]

    println(@sprintf("  Peak: g(%.3f) = %.3f", peak_position, peak_value))

    # Identify clustering signature
    # Strong clustering: g(Δφ) has peak at Δφ ~ π (opposite side)
    if peak_position > π/2 && peak_value > 1.5
        println("  → CLUSTERING DETECTED (peak at opposite side)")
    elseif maximum(g_ensemble) < 1.2
        println("  → Uniform distribution (weak correlations)")
    end

    # Store results
    results[e_target] = (
        delta_phi = delta_phi_centers,
        g = g_ensemble,
        k_vals = collect(0:10),
        S = S_ensemble,
        xi_mean = xi_mean,
        xi_std = xi_std,
        peak_position = peak_position,
        peak_value = peak_value
    )

    println()
end

# ============================================================================
# Visualization
# ============================================================================

println("="^80)
println("VISUALIZATION")
println("="^80)
println()

println("Generating plots...")

# Plot 1: g(Δφ) for all eccentricities
fig1 = Figure(size = (1200, 800))

ax1 = Axis(fig1[1, 1],
    xlabel = "Angular Distance Δφ",
    ylabel = "Pair Correlation g(Δφ)",
    title = "Spatial Correlations vs Eccentricity"
)

colors = [:blue, :green, :cyan, :orange, :red, :darkred, :purple]

for (i, e_val) in enumerate(sort(collect(keys(results))))
    data = results[e_val]

    lines!(ax1, data.delta_phi, data.g,
        color = colors[i],
        linewidth = 3,
        label = @sprintf("e = %.2f", e_val)
    )
end

hlines!(ax1, [1.0],
    color = :black,
    linestyle = :dash,
    linewidth = 2,
    label = "Uniform (g=1)"
)

axislegend(ax1, position = :rt, nbanks = 2)

save(joinpath(campaign_dir, "Fig_PairCorrelation_vs_e.png"), fig1, px_per_unit = 2)
println("  ✅ Fig_PairCorrelation_vs_e.png")

# Plot 2: Structure Factor S(k)
fig2 = Figure(size = (1200, 800))

ax2 = Axis(fig2[1, 1],
    xlabel = "Wave Number k",
    ylabel = "Structure Factor S(k)",
    title = "Structure Factor vs Eccentricity"
)

for (i, e_val) in enumerate(sort(collect(keys(results))))
    data = results[e_val]

    scatterlines!(ax2, data.k_vals, data.S,
        color = colors[i],
        linewidth = 3,
        markersize = 12,
        label = @sprintf("e = %.2f", e_val)
    )
end

hlines!(ax2, [1.0],
    color = :black,
    linestyle = :dash,
    linewidth = 2
)

axislegend(ax2, position = :rt, nbanks = 2)

save(joinpath(campaign_dir, "Fig_StructureFactor_vs_e.png"), fig2, px_per_unit = 2)
println("  ✅ Fig_StructureFactor_vs_e.png")

# Plot 3: Correlation Length vs Eccentricity
fig3 = Figure(size = (1000, 700))

ax3 = Axis(fig3[1, 1],
    xlabel = "Eccentricity (e)",
    ylabel = "Correlation Length ξ",
    title = "Correlation Length vs Eccentricity"
)

e_vals = sort(collect(keys(results)))
xi_means = [results[e].xi_mean for e in e_vals]
xi_stds = [results[e].xi_std for e in e_vals]

errorbars!(ax3, e_vals, xi_means, xi_stds,
    whiskerwidth = 15,
    color = :gray
)

scatterlines!(ax3, e_vals, xi_means,
    color = :steelblue,
    linewidth = 3,
    markersize = 15,
    marker = :circle
)

save(joinpath(campaign_dir, "Fig_CorrelationLength_vs_e.png"), fig3, px_per_unit = 2)
println("  ✅ Fig_CorrelationLength_vs_e.png")

# Plot 4: Peak analysis
fig4 = Figure(size = (1400, 700))

ax4_1 = Axis(fig4[1, 1],
    xlabel = "Eccentricity (e)",
    ylabel = "Peak Position (Δφ)",
    title = "Location of g(Δφ) Peak"
)

ax4_2 = Axis(fig4[1, 2],
    xlabel = "Eccentricity (e)",
    ylabel = "Peak Height g_max",
    title = "Amplitude of Clustering Peak"
)

peak_positions = [results[e].peak_position for e in e_vals]
peak_values = [results[e].peak_value for e in e_vals]

scatterlines!(ax4_1, e_vals, peak_positions,
    color = :steelblue,
    linewidth = 3,
    markersize = 15
)

hlines!(ax4_1, [π/2, π],
    color = [:gray, :red],
    linestyle = :dash,
    linewidth = 2,
    label = ["π/2 (minor axis)", "π (opposite)"]
)

axislegend(ax4_1, position = :rb)

scatterlines!(ax4_2, e_vals, peak_values,
    color = :red,
    linewidth = 3,
    markersize = 15
)

hlines!(ax4_2, [1.0],
    color = :black,
    linestyle = :dash,
    linewidth = 2,
    label = "Uniform"
)

axislegend(ax4_2, position = :lt)

save(joinpath(campaign_dir, "Fig_PeakAnalysis_vs_e.png"), fig4, px_per_unit = 2)
println("  ✅ Fig_PeakAnalysis_vs_e.png")

# ============================================================================
# Summary Statistics
# ============================================================================

println()
println("="^80)
println("SUMMARY: Spatial Correlations")
println("="^80)
println()

println("Eccentricity | ξ (corr. length) | Peak Δφ | g_max | Interpretation")
println("-"^80)

for e_val in e_vals
    data = results[e_val]

    interpretation = if data.peak_value < 1.2
        "Uniform"
    elseif data.peak_position > 2.0
        "Strong clustering"
    elseif data.peak_value > 1.5
        "Moderate clustering"
    else
        "Weak structure"
    end

    @printf("%.2f         | %.3f ± %.3f     | %.3f   | %.3f  | %s\n",
            e_val, data.xi_mean, data.xi_std, data.peak_position, data.peak_value, interpretation)
end

println()
println("="^80)
println("SPATIAL CORRELATION ANALYSIS COMPLETED")
println("="^80)
println()

println("Key Findings:")
println("  • g(Δφ) reveals pair distribution on ellipse")
println("  • S(k) shows Fourier modes of density fluctuations")
println("  • ξ quantifies correlation length scale")
println("  • Peak in g(Δφ) indicates preferred separation")
println()
println("Interpretation:")
println("  • g(Δφ) = 1: Uncorrelated (uniform distribution)")
println("  • g(Δφ) > 1: Positive correlation (clustering)")
println("  • g(Δφ) < 1: Negative correlation (anticlustering)")
println("  • Peak at Δφ ~ π: Particles prefer opposite sides")
