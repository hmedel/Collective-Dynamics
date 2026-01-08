#!/usr/bin/env julia
"""
Generate Parameter Matrix for E/N Temperature Scan

Critical experiment to establish temperature-dependent phase behavior.
This scan varies E/N (effective temperature) while keeping N, φ fixed.

Scientific Goal: Determine critical temperature T_c where clustering transitions occur
"""

using CSV, DataFrames

"""
    generate_EN_scan_matrix(; output_file="parameter_matrix_EN_scan.csv")

Generate parameter matrix for E/N (temperature) scan.

# Design
- **E/N**: [0.05, 0.1, 0.2, 0.4, 0.8, 1.6, 3.2] (7 values - wide range)
- **Eccentricity**: [0.0, 0.866, 0.968] (3 values - circle, moderate, extreme)
- **N**: 40 (fixed - standard size)
- **φ**: 0.06 (fixed - moderate packing)
- **Seeds**: 10 per combination
- **Total**: 7 × 3 × 10 = 210 runs

# Scientific Questions
1. Is there a critical E/N (T_c) where clustering transitions occur?
2. How does τ_cluster scale with E/N?
3. Does the system exhibit critical exponents?
4. What is the phase boundary in (E/N, e) space?

# Returns
- `DataFrame`: Parameter combinations for all runs
"""
function generate_EN_scan_matrix(; output_file="parameter_matrix_EN_scan.csv")

    # ========================================
    # Parameter Definitions
    # ========================================

    # 1. Energy per particle (MAIN VARIABLE - "effective temperature")
    # Wide logarithmic spacing from "cold" to "hot"
    E_per_N_values = [0.05, 0.1, 0.2, 0.4, 0.8, 1.6, 3.2]

    # Physical interpretation:
    # 0.05 - Very cold (likely full clustering)
    # 0.1  - Cold (strong clustering expected)
    # 0.2  - Cool (moderate clustering)
    # 0.4  - Warm (transition region?)
    # 0.8  - Hot (weak clustering?)
    # 1.6  - Very hot (gas phase?)
    # 3.2  - Extreme (definitely gas phase)

    # 2. Eccentricity (three key cases)
    eccentricities = [
        (e=0.000, a_b=1.0, label="Circle"),
        (e=0.866, a_b=2.0, label="Moderate"),
        (e=0.968, a_b=4.0, label="Extreme"),
    ]

    # 3. Fixed parameters
    N_fixed = 40           # Standard system size
    phi_fixed = 0.06       # Moderate packing fraction
    n_seeds = 10           # Statistical ensemble size

    # ========================================
    # Conversion Functions
    # ========================================

    # Calculate radius for given (N, φ, a, b)
    # φ = N·π·r² / (π·a·b) → r = sqrt(φ·a·b / N)
    function calc_radius(N, phi, a, b)
        return sqrt(phi * a * b / N)
    end

    # Calculate v_max from E/N
    # E/N ≈ 0.32 · v_max² for uniform distribution
    v_max_from_E(E_per_N) = sqrt(E_per_N / 0.32)

    # Calculate semi-axes from eccentricity
    # e² = 1 - b²/a², with b=1 → a = 1/√(1-e²)
    function calc_semi_axes(e)
        b = 1.0
        if e ≈ 0.0
            a = 1.0
        else
            a = b / sqrt(1 - e^2)
        end
        return a, b
    end

    # ========================================
    # Generate Combinations
    # ========================================

    combinations = []
    run_id = 1

    for E_per_N in E_per_N_values
        for ecc in eccentricities
            # Calculate geometry
            a, b = calc_semi_axes(ecc.e)
            radius = calc_radius(N_fixed, phi_fixed, a, b)
            v_max = v_max_from_E(E_per_N)

            for seed in 1:n_seeds
                push!(combinations, (
                    run_id = run_id,
                    E_per_N = E_per_N,
                    eccentricity = ecc.e,
                    a_b_ratio = ecc.a_b,
                    ecc_label = ecc.label,
                    N = N_fixed,
                    phi = phi_fixed,
                    radius = radius,
                    v_max = v_max,
                    seed = seed
                ))
                run_id += 1
            end
        end
    end

    # Convert to DataFrame
    df = DataFrame(combinations)
    n_runs = nrow(df)

    # Add metadata columns
    df[!, :design] .= "EN_scan"
    df[!, :status] .= "pending"
    df[!, :date_started] = Vector{Union{String,Missing}}(fill("", n_runs))
    df[!, :date_finished] = Vector{Union{String,Missing}}(fill("", n_runs))
    df[!, :wall_time_seconds] = Vector{Union{Float64,Missing}}(fill(NaN, n_runs))

    # ========================================
    # Summary Statistics
    # ========================================

    println("="^70)
    println("E/N Temperature Scan - Parameter Matrix Generated")
    println("="^70)
    println()
    println("📊 EXPERIMENT DESIGN")
    println("  Purpose: Establish temperature-dependent phase behavior")
    println("  Type: E/N scan (effective temperature variation)")
    println()
    println("Total runs: $n_runs")
    println("Unique E/N values: $(length(E_per_N_values))")
    println("Eccentricities tested: $(length(eccentricities))")
    println("Seeds per combination: $n_seeds")
    println()
    println("Parameter ranges:")
    println("  E/N (temperature): $(E_per_N_values)")
    println("  Eccentricity e:    $(round.([ecc.e for ecc in eccentricities], digits=3))")
    println("  N (fixed):         $N_fixed")
    println("  φ (fixed):         $phi_fixed")
    println()

    # Temperature interpretation
    println("Temperature interpretation (T_eff = 2·E/N):")
    for E in E_per_N_values
        T_eff = 2 * E
        regime = if E < 0.2
            "Very Cold → Full clustering expected"
        elseif E < 0.5
            "Cool → Moderate clustering"
        elseif E < 1.0
            "Warm → Transition region (critical?)"
        elseif E < 2.0
            "Hot → Weak clustering or gas phase"
        else
            "Very Hot → Gas phase (no clustering)"
        end
        println("  E/N = $(E)  →  T_eff = $(T_eff)  →  $regime")
    end
    println()

    # Estimate computational cost
    # Baseline: 6 min per run for N=40, t_max=100s
    baseline_time = 6.0  # minutes for N=40
    total_time_minutes = n_runs * baseline_time
    total_time_hours = total_time_minutes / 60

    # With parallelization (24 cores)
    parallel_time_hours = total_time_hours / 24
    parallel_time_days = parallel_time_hours / 24

    println("⏱️  COMPUTATIONAL COST ESTIMATE")
    println("  Baseline: 6 min/run for N=40, t_max=100s")
    println("  Total CPU time:        $(round(total_time_hours, digits=1)) hours")
    println("  Wall time (24 cores):  $(round(parallel_time_hours, digits=1)) hours ($(round(parallel_time_days, digits=2)) days)")
    println("  Recommended: Run with GNU parallel + nohup for long execution")
    println()

    # Scientific impact
    println("🎯 SCIENTIFIC IMPACT")
    println("  This scan enables:")
    println("  ✅ Determination of critical temperature T_c")
    println("  ✅ Phase diagram in (E/N, e) space")
    println("  ✅ Scaling laws: τ_cluster(T), N_clusters(T)")
    println("  ✅ Critical exponents (if near critical point)")
    println("  ✅ Connection to statistical mechanics phase transitions")
    println()

    # ========================================
    # Save to File
    # ========================================

    CSV.write(output_file, df)
    println("💾 Saved to: $output_file")
    println("="^70)
    println()
    println("Next steps:")
    println("  1. Review parameter matrix: head $output_file")
    println("  2. Launch campaign: ./launch_campaign.sh $output_file")
    println("  3. Monitor progress: ./monitor_campaign.sh")
    println()

    return df
end

# ========================================
# Main Execution
# ========================================

if abspath(PROGRAM_FILE) == @__FILE__
    # Parse command line arguments
    if length(ARGS) == 0
        output = "parameter_matrix_EN_scan.csv"
    else
        output = ARGS[1]
    end

    # Generate matrix
    df = generate_EN_scan_matrix(output_file=output)

    # Show sample of runs
    println("Sample runs from each E/N value:")
    println()
    for E in unique(df.E_per_N)
        subset = filter(row -> row.E_per_N ≈ E, df)
        println("E/N = $E:")
        println(first(subset, 3))
        println()
    end
end
