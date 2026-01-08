#!/usr/bin/env julia
"""
Phase Diagram Classification Analysis

Classifies each simulation into gas/liquid/crystal phases based on:
- Order parameter: φ_cluster = s_max/N (largest cluster fraction)
- Clustering time: τ_cluster (half-life time)
- Final number of clusters: N_clusters_final
- Spatial compactness: σ_φ (angular spread)

Phase Criteria:
- **Gas**: φ_cluster < 0.3, N_clusters ~ N (many small clusters)
- **Liquid**: 0.3 ≤ φ_cluster < 0.8 (intermediate clustering)
- **Crystal**: φ_cluster ≥ 0.8 (single dominant cluster)

Scientific Goal: Build phase diagram in (E/N, e) parameter space

Usage:
    julia analyze_phase_classification.jl results/campaign_EN_scan_*/
"""

using HDF5
using JSON
using Statistics
using DataFrames
using CSV
using Plots
using Printf

"""
    classify_phase(φ_cluster_final::Float64, τ_cluster::Float64,
                   N_clusters_final::Int, N::Int)

Classify simulation into gas/liquid/crystal phase.

Criteria:
- Gas: φ_cluster < 0.3 OR τ_cluster > 50s OR N_clusters > 0.5N
- Crystal: φ_cluster ≥ 0.8 AND τ_cluster < 20s AND N_clusters ≤ 3
- Liquid: Everything else (intermediate)

Returns: "gas", "liquid", or "crystal"
"""
function classify_phase(φ_cluster_final::Float64, τ_cluster::Float64,
                       N_clusters_final::Int, N::Int)
    # Gas phase: weakly clustered
    if φ_cluster_final < 0.3 || τ_cluster > 50.0 || N_clusters_final > 0.5 * N
        return "gas"
    end

    # Crystal phase: strongly clustered
    if φ_cluster_final ≥ 0.8 && τ_cluster < 20.0 && N_clusters_final ≤ 3
        return "crystal"
    end

    # Liquid phase: intermediate
    return "liquid"
end

"""
    extract_phase_metrics(summary_json::String)

Extract key metrics from summary.json for phase classification.

Returns named tuple with:
- φ_cluster_final: largest cluster fraction at t_final
- τ_cluster: clustering half-life time
- N_clusters_final: number of clusters at t_final
- σ_φ_final: angular spread at t_final
- compactification_rate: rate of compactification
"""
function extract_phase_metrics(summary_json::String)
    data = JSON.parsefile(summary_json)

    # Extract metrics
    φ_cluster_final = get(data, "largest_cluster_fraction_final", NaN)
    τ_cluster = get(data, "clustering_halflife_time", NaN)
    N_clusters_final = get(data, "N_clusters_final", 0)
    σ_φ_final = get(data, "sigma_phi_final", NaN)

    # Extract N from parameters
    N = get(data["parameters"], "N", 40)

    # Calculate compactification rate (if available)
    if haskey(data, "compactification_rate")
        compact_rate = data["compactification_rate"]
    else
        compact_rate = NaN
    end

    return (
        φ_cluster_final = φ_cluster_final,
        τ_cluster = τ_cluster,
        N_clusters_final = N_clusters_final,
        N = N,
        σ_φ_final = σ_φ_final,
        compactification_rate = compact_rate,
        E_per_N = get(data["parameters"], "E_per_N", NaN),
        eccentricity = get(data["parameters"], "eccentricity", NaN),
        phi = get(data["parameters"], "phi", NaN),
        seed = get(data["parameters"], "seed", 0)
    )
end

"""
    classify_campaign_phases(campaign_dir::String)

Classify all simulations in a campaign into phases.

Returns DataFrame with classification results.
"""
function classify_campaign_phases(campaign_dir::String)
    println("="^70)
    println("Phase Classification Analysis")
    println("="^70)
    println("Campaign: $campaign_dir")
    println()

    # Find all ensemble directories (e.g., e0.866_N40_phi0.06_E0.32)
    ensemble_dirs = filter(isdir, readdir(campaign_dir, join=true))
    ensemble_dirs = filter(d -> occursin(r"^e[0-9]", basename(d)), ensemble_dirs)

    n_ensembles = length(ensemble_dirs)
    println("Found $n_ensembles ensemble directories")
    println()

    # Collect results
    results = DataFrame()

    for (i, ens_dir) in enumerate(ensemble_dirs)
        ens_name = basename(ens_dir)
        println("[$i/$n_ensembles] Processing: $ens_name")

        # Find all seed directories
        seed_dirs = filter(isdir, readdir(ens_dir, join=true))
        seed_dirs = filter(d -> occursin("seed_", basename(d)), seed_dirs)

        for seed_dir in seed_dirs
            summary_file = joinpath(seed_dir, "summary.json")

            if !isfile(summary_file)
                @warn "  Missing summary.json in $(basename(seed_dir))"
                continue
            end

            # Extract metrics
            metrics = extract_phase_metrics(summary_file)

            # Classify phase
            phase = classify_phase(metrics.φ_cluster_final,
                                  metrics.τ_cluster,
                                  metrics.N_clusters_final,
                                  metrics.N)

            # Add to results
            push!(results, (
                ensemble = ens_name,
                seed = metrics.seed,
                E_per_N = metrics.E_per_N,
                eccentricity = metrics.eccentricity,
                phi = metrics.phi,
                N = metrics.N,
                phase = phase,
                φ_cluster_final = metrics.φ_cluster_final,
                τ_cluster = metrics.τ_cluster,
                N_clusters_final = metrics.N_clusters_final,
                σ_φ_final = metrics.σ_φ_final,
                compactification_rate = metrics.compactification_rate
            ))
        end
    end

    if isempty(results)
        error("No data collected!")
    end

    println()
    println("Collected $(nrow(results)) simulations")
    println()

    # Compute phase statistics
    phase_counts = combine(groupby(results, :phase), nrow => :count)
    println("Phase distribution:")
    for row in eachrow(phase_counts)
        frac = row.count / nrow(results) * 100
        println("  $(row.phase): $(row.count) ($(round(frac, digits=1))%)")
    end
    println()

    # Save results
    output_file = joinpath(campaign_dir, "phase_classification.csv")
    CSV.write(output_file, results)
    println("Saved classification results to: $output_file")

    # Generate summary by (E/N, e)
    if :E_per_N in names(results) && :eccentricity in names(results)
        summary = generate_phase_diagram_summary(results, campaign_dir)
    end

    return results
end

"""
    generate_phase_diagram_summary(results::DataFrame, output_dir::String)

Generate phase diagram summary: fraction of each phase vs (E/N, e).

Saves CSV and creates visualization.
"""
function generate_phase_diagram_summary(results::DataFrame, output_dir::String)
    println()
    println("Generating phase diagram summary...")

    # Group by (E/N, eccentricity)
    grouped = groupby(results, [:E_per_N, :eccentricity])

    # Compute phase fractions
    summary = combine(grouped) do df
        n_total = nrow(df)
        n_gas = count(==(="gas"), df.phase)
        n_liquid = count(==(="liquid"), df.phase)
        n_crystal = count(==(="crystal"), df.phase)

        (
            n_total = n_total,
            frac_gas = n_gas / n_total,
            frac_liquid = n_liquid / n_total,
            frac_crystal = n_crystal / n_total,
            mean_φ_cluster = mean(df.φ_cluster_final),
            std_φ_cluster = std(df.φ_cluster_final),
            mean_τ_cluster = mean(skipmissing(df.τ_cluster)),
            std_τ_cluster = std(skipmissing(df.τ_cluster))
        )
    end

    # Determine dominant phase (majority vote)
    summary[!, :dominant_phase] = map(eachrow(summary)) do row
        fracs = [row.frac_gas, row.frac_liquid, row.frac_crystal]
        phases = ["gas", "liquid", "crystal"]
        phases[argmax(fracs)]
    end

    # Save
    summary_file = joinpath(output_dir, "phase_diagram_summary.csv")
    CSV.write(summary_file, summary)
    println("  Saved summary to: $summary_file")

    # Create phase diagram plot
    plot_phase_diagram(summary, output_dir)

    return summary
end

"""
    plot_phase_diagram(summary::DataFrame, output_dir::String)

Create 2D phase diagram in (E/N, e) space.
"""
function plot_phase_diagram(summary::DataFrame, output_dir::String)
    println()
    println("Creating phase diagram plot...")

    # Extract unique E/N and e values
    E_values = sort(unique(summary.E_per_N))
    e_values = sort(unique(summary.eccentricity))

    # Create heatmap matrix for dominant phase
    # Map phases to numbers: gas=1, liquid=2, crystal=3
    phase_to_num = Dict("gas" => 1, "liquid" => 2, "crystal" => 3)

    n_E = length(E_values)
    n_e = length(e_values)

    phase_matrix = fill(NaN, n_e, n_E)

    for row in eachrow(summary)
        i_e = findfirst(==(row.eccentricity), e_values)
        i_E = findfirst(==(row.E_per_N), E_values)

        if !isnothing(i_e) && !isnothing(i_E)
            phase_matrix[i_e, i_E] = phase_to_num[row.dominant_phase]
        end
    end

    # Create plot
    p = heatmap(E_values, e_values, phase_matrix,
                xlabel="E/N (Effective Temperature)",
                ylabel="Eccentricity e",
                title="Phase Diagram",
                color=:viridis,
                clims=(0.5, 3.5),
                colorbar_ticks=([1, 2, 3], ["Gas", "Liquid", "Crystal"]),
                xscale=:log10,
                size=(800, 600),
                margin=5Plots.mm)

    # Add grid
    hline!(p, e_values, color=:white, alpha=0.3, linewidth=0.5, label="")
    vline!(p, E_values, color=:white, alpha=0.3, linewidth=0.5, label="")

    savefig(p, joinpath(output_dir, "phase_diagram.png"))
    println("  ✓ Saved: phase_diagram.png")

    # Also create order parameter heatmap
    φ_matrix = fill(NaN, n_e, n_E)

    for row in eachrow(summary)
        i_e = findfirst(==(row.eccentricity), e_values)
        i_E = findfirst(==(row.E_per_N), E_values)

        if !isnothing(i_e) && !isnothing(i_E)
            φ_matrix[i_e, i_E] = row.mean_φ_cluster
        end
    end

    p2 = heatmap(E_values, e_values, φ_matrix,
                 xlabel="E/N (Effective Temperature)",
                 ylabel="Eccentricity e",
                 title="Order Parameter ⟨φ_cluster⟩",
                 color=:thermal,
                 clims=(0, 1),
                 xscale=:log10,
                 size=(800, 600),
                 margin=5Plots.mm)

    savefig(p2, joinpath(output_dir, "order_parameter_heatmap.png"))
    println("  ✓ Saved: order_parameter_heatmap.png")

    println()
    println("Phase diagram plots saved to: $output_dir")
end

"""
    find_critical_temperature(summary::DataFrame, eccentricity::Float64)

Estimate critical temperature T_c for given eccentricity.

Uses order parameter crossing: φ_cluster(T_c) ≈ 0.5
"""
function find_critical_temperature(summary::DataFrame, eccentricity::Float64; tol=0.05)
    # Filter by eccentricity
    subset = filter(row -> abs(row.eccentricity - eccentricity) < tol, summary)

    if isempty(subset)
        @warn "No data for eccentricity ≈ $eccentricity"
        return NaN
    end

    # Sort by E/N
    sort!(subset, :E_per_N)

    # Find crossing point where φ_cluster ≈ 0.5
    for i in 1:(nrow(subset)-1)
        φ_low = subset.mean_φ_cluster[i]
        φ_high = subset.mean_φ_cluster[i+1]

        if φ_low > 0.5 && φ_high < 0.5  # Decreasing
            E_low = subset.E_per_N[i]
            E_high = subset.E_per_N[i+1]

            # Linear interpolation
            T_c = E_low + (0.5 - φ_low) / (φ_high - φ_low) * (E_high - E_low)
            return T_c
        elseif φ_low < 0.5 && φ_high > 0.5  # Increasing (unlikely)
            E_low = subset.E_per_N[i]
            E_high = subset.E_per_N[i+1]

            T_c = E_low + (0.5 - φ_low) / (φ_high - φ_low) * (E_high - E_low)
            return T_c
        end
    end

    @warn "No critical point found for e=$eccentricity (φ_cluster doesn't cross 0.5)"
    return NaN
end

# ========================================
# Main Execution
# ========================================

if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) < 1
        println("Usage: julia analyze_phase_classification.jl <campaign_dir>")
        println()
        println("Example:")
        println("  julia analyze_phase_classification.jl results/campaign_EN_scan_20251115_123456/")
        exit(1)
    end

    campaign_dir = ARGS[1]

    # Run classification
    results = classify_campaign_phases(campaign_dir)

    # Find critical temperatures for each eccentricity
    if :eccentricity in names(results)
        println()
        println("="^70)
        println("Critical Temperature Estimates")
        println("="^70)

        summary = CSV.read(joinpath(campaign_dir, "phase_diagram_summary.csv"), DataFrame)

        for e in sort(unique(summary.eccentricity))
            T_c = find_critical_temperature(summary, e)

            if !isnan(T_c)
                println("  e = $(round(e, digits=3))  →  T_c (E/N) ≈ $(round(T_c, digits=3))")
            end
        end
    end

    println()
    println("="^70)
    println("Analysis Complete!")
    println("="^70)
    println()
    println("Results saved to:")
    println("  - phase_classification.csv")
    println("  - phase_diagram_summary.csv")
    println("  - phase_diagram.png")
    println("  - order_parameter_heatmap.png")
end
