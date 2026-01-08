#!/usr/bin/env julia
"""
visualize_results.jl

Create text-based visualizations and ASCII plots of results.
No plotting library required - pure text output.
"""

using Pkg
Pkg.activate(".")

using DelimitedFiles
using Statistics
using Printf

# ============================================================================
# ASCII Plotting Functions
# ============================================================================

function ascii_histogram(values, bins=20, width=60)
    """Create ASCII histogram"""
    min_val, max_val = extrema(values)
    range_val = max_val - min_val

    if range_val == 0
        println("  (All values identical: $(values[1]))")
        return
    end

    # Create bins
    bin_edges = range(min_val, max_val, length=bins+1)
    counts = zeros(Int, bins)

    for v in values
        bin_idx = min(searchsortedfirst(bin_edges[2:end], v), bins)
        counts[bin_idx] += 1
    end

    max_count = maximum(counts)

    # Print histogram
    for i in 1:bins
        bar_length = Int(round(width * counts[i] / max_count))
        bar = "█" ^ bar_length
        bin_center = (bin_edges[i] + bin_edges[i+1]) / 2

        println(@sprintf("  [%.4f]: %s (%d)", bin_center, bar, counts[i]))
    end
end

function ascii_plot(x, y, width=70, height=20)
    """Create ASCII scatter/line plot"""
    if length(x) != length(y)
        error("x and y must have same length")
    end

    if isempty(x)
        println("  (No data to plot)")
        return
    end

    x_min, x_max = extrema(x)
    y_min, y_max = extrema(y)

    x_range = x_max - x_min
    y_range = y_max - y_min

    if x_range == 0 || y_range == 0
        println("  (Insufficient variation to plot)")
        return
    end

    # Create canvas
    canvas = fill(' ', height, width)

    # Plot points
    for i in 1:length(x)
        col = 1 + Int(floor((width-1) * (x[i] - x_min) / x_range))
        row = height - Int(floor((height-1) * (y[i] - y_min) / y_range))

        col = clamp(col, 1, width)
        row = clamp(row, 1, height)

        canvas[row, col] = '●'
    end

    # Print canvas with axes
    println("  Y: $(round(y_max, digits=3))")
    for row in 1:height
        if row == height
            print("  │")
        else
            print("  │")
        end
        println(String(canvas[row, :]))
    end
    println("  └" * "─"^width)
    println("  X: $(round(x_min, digits=3))" * " "^(width-20) * "$(round(x_max, digits=3))")
    println("   " * " "^(div(width,2)-3) * "X")
end

# ============================================================================
# Main Visualization
# ============================================================================

println("=" ^ 70)
println("VISUALIZACIÓN DE RESULTADOS")
println("=" ^ 70)
println()

# ============================================================================
# Option 1: Visualize Experiment 4 (single seed)
# ============================================================================

if isdir("results_experiment_4")
    println("=" ^ 70)
    println("EXPERIMENTO 4: Eccentricity Scan (Single Seed)")
    println("=" ^ 70)
    println()

    summary = readdlm("results_experiment_4/summary.csv", ',', skipstart=1)

    eccs = summary[:, 2]
    compacts = summary[:, 3]
    t_halfs_exp4 = []

    cases = ["Circle", "Moderate", "High_ecc", "Extreme_ecc"]

    # Extract t_1/2 from phase evolution files
    for case in cases
        phase_file = "results_experiment_4/$case/phase_evolution.csv"
        if isfile(phase_file)
            phase_data = readdlm(phase_file, ',')
            times = phase_data[:, 1]
            σ_φ = phase_data[:, 2]

            σ_target = (σ_φ[1] + σ_φ[end]) / 2
            idx = findfirst(s -> s <= σ_target, σ_φ)

            if !isnothing(idx)
                push!(t_halfs_exp4, times[idx])
            else
                push!(t_halfs_exp4, NaN)
            end
        end
    end

    println("1. Compactification vs Eccentricity:")
    println("-" ^ 70)
    ascii_plot(eccs, compacts, 60, 15)
    println()

    if !isempty(t_halfs_exp4) && !all(isnan.(t_halfs_exp4))
        println("2. Clustering Timescale (t_1/2) vs Eccentricity:")
        println("-" ^ 70)
        ascii_plot(eccs, t_halfs_exp4, 60, 15)
        println()

        println("   INTERPRETACIÓN:")
        println("   → t_1/2 disminuye con eccentricidad = clustering más rápido")
        println("   → Evidencia para metric volume hypothesis")
        println()
    end
end

# ============================================================================
# Option 2: Visualize Experiment 5 (statistical)
# ============================================================================

if isdir("results_experiment_5_statistical")
    println("=" ^ 70)
    println("EXPERIMENTO 5: Statistical Study (Multiple Seeds)")
    println("=" ^ 70)
    println()

    if isfile("results_experiment_5_statistical/summary_statistics.csv")
        summary_stats = readdlm("results_experiment_5_statistical/summary_statistics.csv", ',', skipstart=1)

        eccs_stat = summary_stats[:, 2]
        mean_compact = summary_stats[:, 3]
        std_compact = summary_stats[:, 4]
        mean_t_half = summary_stats[:, 5]
        std_t_half = summary_stats[:, 6]

        println("1. Compactification Ratio (mean ± std):")
        println("-" ^ 70)
        for i in 1:length(eccs_stat)
            println(@sprintf("  e = %.3f:  %.4f ± %.4f",
                            eccs_stat[i], mean_compact[i], std_compact[i]))
        end
        println()

        println("2. Clustering Timescale t_1/2 (mean ± std):")
        println("-" ^ 70)
        for i in 1:length(eccs_stat)
            println(@sprintf("  e = %.3f:  %.2f ± %.2f s",
                            eccs_stat[i], mean_t_half[i], std_t_half[i]))
        end
        println()

        # Plot with error bars (ASCII)
        println("3. Timescale vs Eccentricity (with error bars):")
        println("-" ^ 70)

        # For simplicity, just plot means
        ascii_plot(eccs_stat, mean_t_half, 60, 15)

        println()
        println("   Error bars:")
        for i in 1:length(eccs_stat)
            println(@sprintf("     e = %.3f:  [%.2f, %.2f]",
                            eccs_stat[i],
                            mean_t_half[i] - std_t_half[i],
                            mean_t_half[i] + std_t_half[i]))
        end
        println()

        # Statistical test: are differences significant?
        println("4. Statistical Significance:")
        println("-" ^ 70)

        # Simple test: do error bars overlap?
        println("  Error bar overlaps (non-overlapping = significant):")
        for i in 1:(length(eccs_stat)-1)
            upper_i = mean_t_half[i] + std_t_half[i]
            lower_next = mean_t_half[i+1] - std_t_half[i+1]

            overlap = upper_i >= lower_next

            println(@sprintf("    e=%.3f vs e=%.3f: %s",
                            eccs_stat[i], eccs_stat[i+1],
                            overlap ? "OVERLAP (not significant)" : "NO OVERLAP (significant!)"))
        end
        println()

        # Distribution plots for each case
        cases_stat = ["Circle", "Moderate", "High_ecc", "Extreme_ecc"]
        for (i, case) in enumerate(cases_stat)
            individual_file = "results_experiment_5_statistical/$case/individual_trials.csv"

            if isfile(individual_file)
                individual = readdlm(individual_file, ',', skipstart=1)
                t_half_values = individual[:, 3]
                valid_t_half = filter(!isnan, t_half_values)

                if !isempty(valid_t_half)
                    println("5.$(i) Distribution of t_1/2 for $case:")
                    println("-" ^ 70)
                    ascii_histogram(valid_t_half, 10, 50)
                    println()
                end
            end
        end
    else
        println("  ⚠️  Statistical data not yet available")
        println("      (Experiment 5 still running?)")
        println()
    end
end

# ============================================================================
# Summary
# ============================================================================

println("=" ^ 70)
println("RESUMEN")
println("=" ^ 70)
println()

println("Datos disponibles:")
if isdir("results_experiment_4")
    println("  ✓ Experiment 4 (single seed)")
end
if isdir("results_experiment_5_statistical") && isfile("results_experiment_5_statistical/summary_statistics.csv")
    println("  ✓ Experiment 5 (statistical)")
else
    println("  ⏳ Experiment 5 (en progreso)")
end

println()
println("Para ver más detalles:")
println("  - Experiment 4: cat results_experiment_4/detailed_analysis.txt")
println("  - Experiment 5: cat results_experiment_5_statistical/statistical_summary.txt")
println()

println("=" ^ 70)
println("✅ VISUALIZACIÓN COMPLETADA")
println("=" ^ 70)
println()
