#!/usr/bin/env julia
"""
Generate Parameter Matrix for Comprehensive Experimental Campaign

Creates a CSV file with all parameter combinations for the experimental sweep.
Supports both minimal and full factorial designs.
"""

using CSV, DataFrames

"""
    generate_parameter_matrix(design=:minimal; output_file="parameter_matrix.csv")

Generate parameter matrix for experimental campaign.

# Arguments
- `design::Symbol`: Either `:minimal` or `:full`
  - `:minimal`: 6 e × 3 N × 3 φ × 3 E × 10 seeds = 1,620 runs
  - `:full`: 6 e × 5 N × 5 φ × 5 E × 15 seeds = 11,250 runs
  - `:pilot`: 6 e × 3 N × 3 φ × 1 E × 10 seeds = 540 runs (quick test)

- `output_file::String`: Path to output CSV file

# Returns
- `DataFrame`: Parameter combinations with columns:
  - run_id, eccentricity, a_b_ratio, N, phi, radius, E_per_N, v_max, seed
"""
function generate_parameter_matrix(design=:minimal; output_file="parameter_matrix.csv")

    # ========================================
    # Parameter Definitions
    # ========================================

    # 1. Eccentricity (geometry)
    eccentricities_all = [
        (e=0.000, a_b=1.0, label="Circle"),
        (e=0.745, a_b=1.5, label="Low"),
        (e=0.866, a_b=2.0, label="Moderate"),
        (e=0.943, a_b=3.0, label="High"),
        (e=0.968, a_b=4.0, label="VeryHigh"),
        (e=0.980, a_b=5.0, label="Extreme"),
    ]

    # 2. System size
    N_minimal = [20, 40, 80]
    N_full = [20, 40, 80, 160, 320]

    # 3. Packing fraction (controlled via radius)
    # φ = N·π·r² / (π·a·b) with a·b = 2.0 (semi-axes product)
    # Solve for r: r = sqrt(φ·a·b / N)
    phi_minimal = [0.04, 0.06, 0.09]   # Low, Moderate, High
    phi_full = [0.02, 0.04, 0.06, 0.09, 0.12]  # Dilute to Dense

    # 4. Energy per particle (controlled via v_max)
    # E/N ≈ (1/3) · v_max² · ⟨g_φφ⟩ for uniform distribution
    # Approximate: E/N ≈ 0.32 · v_max² for a·b = 2.0
    E_per_N_minimal = [0.18, 0.32, 0.72]  # Cool, Warm, Hot
    E_per_N_full = [0.08, 0.18, 0.32, 0.72, 1.28]  # Cold to VeryHot

    # Conversion: v_max ≈ sqrt(E_per_N / 0.32)
    v_max_from_E(E_per_N) = sqrt(E_per_N / 0.32)

    # 5. Seeds
    n_seeds_minimal = 10
    n_seeds_full = 15
    n_seeds_pilot = 10

    # ========================================
    # Select Design
    # ========================================

    if design == :minimal
        N_values = N_minimal
        phi_values = phi_minimal
        E_values = E_per_N_minimal
        n_seeds = n_seeds_minimal
    elseif design == :full
        N_values = N_full
        phi_values = phi_full
        E_values = E_per_N_full
        n_seeds = n_seeds_full
    elseif design == :pilot
        N_values = N_minimal
        phi_values = phi_minimal
        E_values = [0.32]  # Just warm case
        n_seeds = n_seeds_pilot
    else
        error("Unknown design: $design. Use :minimal, :full, or :pilot")
    end

    # ========================================
    # Generate Combinations
    # ========================================

    combinations = []
    run_id = 1

    for ecc in eccentricities_all
        for N in N_values
            for phi in phi_values
                # Calculate radius for this (N, phi) combination
                # Assume a·b = 2.0 as baseline (will scale with actual a, b)
                a_b_product = 2.0  # For a/b ratio, a·b stays constant
                radius = sqrt(phi * a_b_product / N)

                for E_per_N in E_values
                    v_max = v_max_from_E(E_per_N)

                    for seed in 1:n_seeds
                        push!(combinations, (
                            run_id = run_id,
                            eccentricity = ecc.e,
                            a_b_ratio = ecc.a_b,
                            ecc_label = ecc.label,
                            N = N,
                            phi = phi,
                            radius = radius,
                            E_per_N = E_per_N,
                            v_max = v_max,
                            seed = seed
                        ))
                        run_id += 1
                    end
                end
            end
        end
    end

    # Convert to DataFrame
    df = DataFrame(combinations)
    n_runs = nrow(df)

    # Add metadata columns
    df[!, :design] .= string(design)
    df[!, :status] .= "pending"
    df[!, :date_started] = Vector{Union{String,Missing}}(fill("", n_runs))
    df[!, :date_finished] = Vector{Union{String,Missing}}(fill("", n_runs))
    df[!, :wall_time_seconds] = Vector{Union{Float64,Missing}}(fill(NaN, n_runs))

    # ========================================
    # Summary Statistics
    # ========================================
    n_params = nrow(unique(select(df, [:eccentricity, :N, :phi, :E_per_N])))

    println("="^70)
    println("Parameter Matrix Generated: $design Design")
    println("="^70)
    println()
    println("Total runs: $n_runs")
    println("Unique parameter combinations: $n_params")
    println("Seeds per combination: $n_seeds")
    println()
    println("Parameter ranges:")
    println("  Eccentricity:    $(length(eccentricities_all)) values")
    println("  N:               $(length(N_values)) values → $(N_values)")
    println("  φ (packing):     $(length(phi_values)) values → $(round.(phi_values, digits=3))")
    println("  E/N (energy):    $(length(E_values)) values → $(round.(E_values, digits=3))")
    println()

    # Estimate computational cost
    # Assume 7.5 min per run for N=40 baseline, scale with N²
    baseline_time = 7.5  # minutes for N=40
    total_time_minutes = sum(df.N.^2) / (40^2) * baseline_time
    total_time_hours = total_time_minutes / 60
    total_time_days = total_time_hours / 24

    # With parallelization (24 cores)
    parallel_time_hours = total_time_hours / 24

    println("Estimated computational cost:")
    println("  Total CPU time:  $(round(total_time_days, digits=1)) days")
    println("  Wall time (24 cores): $(round(parallel_time_hours, digits=1)) hours")
    println()

    # ========================================
    # Save to File
    # ========================================

    CSV.write(output_file, df)
    println("Saved to: $output_file")
    println("="^70)

    return df
end

"""
    filter_parameter_matrix(df::DataFrame; eccentricity=nothing, N=nothing, phi=nothing, E_per_N=nothing)

Filter parameter matrix by specific values.

# Example
```julia
df = CSV.read("parameter_matrix.csv", DataFrame)
df_subset = filter_parameter_matrix(df; N=40, eccentricity=0.866)  # Just moderate ellipse, N=40
```
"""
function filter_parameter_matrix(df::DataFrame; eccentricity=nothing, N=nothing, phi=nothing, E_per_N=nothing)
    result = copy(df)

    if eccentricity !== nothing
        result = filter(row -> row.eccentricity ≈ eccentricity, result)
    end

    if N !== nothing
        result = filter(row -> row.N == N, result)
    end

    if phi !== nothing
        result = filter(row -> row.phi ≈ phi, result)
    end

    if E_per_N !== nothing
        result = filter(row -> row.E_per_N ≈ E_per_N, result)
    end

    return result
end

# ========================================
# Main Execution
# ========================================

if abspath(PROGRAM_FILE) == @__FILE__
    # Parse command line arguments
    if length(ARGS) == 0
        design = :minimal
        output = "parameter_matrix_minimal.csv"
    elseif length(ARGS) == 1
        design = Symbol(ARGS[1])
        output = "parameter_matrix_$(design).csv"
    else
        design = Symbol(ARGS[1])
        output = ARGS[2]
    end

    # Generate matrix
    df = generate_parameter_matrix(design; output_file=output)

    # Show first few rows
    println()
    println("First 10 runs:")
    println(first(df, 10))
end
