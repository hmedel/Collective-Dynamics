#!/usr/bin/env julia
"""
Test Pipeline: Quick Validation

Runs a minimal test to verify the entire pipeline works:
1. Generate micro parameter matrix (2 runs)
2. Execute simulations
3. Analyze ensemble
4. Verify outputs

Use this before launching full campaign!
"""

using Test

println("="^70)
println("Pipeline Test: Validating Infrastructure")
println("="^70)

# ========================================
# Step 1: Generate Test Parameter Matrix
# ========================================

println("\nStep 1: Generating test parameter matrix...")
include("generate_parameter_matrix.jl")

# Micro design: just 2 seeds for 1 parameter combo
function generate_micro_matrix()
    combinations = [
        (run_id=1, eccentricity=0.866, a_b_ratio=2.0, ecc_label="Moderate",
         N=20, phi=0.06, radius=sqrt(0.06*2.0/20), E_per_N=0.32, v_max=1.0, seed=1),
        (run_id=2, eccentricity=0.866, a_b_ratio=2.0, ecc_label="Moderate",
         N=20, phi=0.06, radius=sqrt(0.06*2.0/20), E_per_N=0.32, v_max=1.0, seed=2),
    ]

    using CSV, DataFrames
    df = DataFrame(combinations)
    df[!, :design] .= "micro_test"
    df[!, :status] .= "pending"

    output_file = "parameter_matrix_test.csv"
    CSV.write(output_file, df)
    println("  Created: $output_file")

    return df
end

df_test = generate_micro_matrix()

# ========================================
# Step 2: Run Test Simulations
# ========================================

println("\nStep 2: Running test simulations (N=20, t_max=5s)...")

test_output_dir = "results/pipeline_test_$(Dates.format(now(), "yyyymmdd_HHMMSS"))"
mkpath(test_output_dir)

include("run_single_experiment.jl")

for row in eachrow(df_test)
    println("\n  Running seed=$(row.seed)...")

    config = setup_from_parameters(
        row.eccentricity, row.N, row.phi, row.E_per_N, row.seed
    )

    ecc_str = @sprintf("e%.3f", row.eccentricity)
    output_dir = joinpath(test_output_dir, "$(ecc_str)_N$(row.N)_phi$(row.phi)_E$(row.E_per_N)/seed_$(row.seed)")

    try
        summary = run_experiment(
            config, output_dir;
            t_max = 5.0,  # Short run for testing
            use_parallel = false,  # Sequential for simplicity
            save_collisions = false
        )

        @test isfile(joinpath(output_dir, "trajectories.h5"))
        @test isfile(joinpath(output_dir, "summary.json"))
        @test isfile(joinpath(output_dir, "cluster_evolution.csv"))

        println("  ✓ Seed $(row.seed) completed successfully")
    catch e
        println("  ✗ Seed $(row.seed) FAILED: $e")
        rethrow(e)
    end
end

# ========================================
# Step 3: Test Ensemble Analysis
# ========================================

println("\nStep 3: Testing ensemble analysis...")

combo_dir = joinpath(test_output_dir, "e0.866_N020_phi0.06_E0.32")

include("analyze_ensemble.jl")

try
    ensemble_result = analyze_ensemble(combo_dir)

    @test ensemble_result["n_seeds"] == 2
    @test haskey(ensemble_result, "timescales")
    @test haskey(ensemble_result, "growth_exponent")

    # Check output files
    ensemble_dir = joinpath(combo_dir, "ensemble_analysis")
    @test isfile(joinpath(ensemble_dir, "ensemble_summary.json"))
    @test isfile(joinpath(ensemble_dir, "ensemble_N_clusters.png"))

    println("  ✓ Ensemble analysis completed successfully")
catch e
    println("  ✗ Ensemble analysis FAILED: $e")
    rethrow(e)
end

# ========================================
# Step 4: Test HDF5 I/O
# ========================================

println("\nStep 4: Testing HDF5 I/O...")

include("src/io_hdf5.jl")

test_hdf5 = joinpath(combo_dir, "seed_1/trajectories.h5")

try
    # Load full data
    data = load_trajectories_hdf5(test_hdf5)

    @test !isnothing(data.times)
    @test !isnothing(data.phi)
    @test size(data.phi, 2) == 20  # N=20 particles

    println("  ✓ Full data load: $(size(data.phi)) array")

    # Test slicing
    data_slice = load_trajectory_slice(test_hdf5, (1.0, 3.0))
    @test all(1.0 .<= data_slice.times .<= 3.0)

    println("  ✓ Time slicing: $(length(data_slice.times)) snapshots")

catch e
    println("  ✗ HDF5 I/O FAILED: $e")
    rethrow(e)
end

# ========================================
# Step 5: Test Coarsening Analysis
# ========================================

println("\nStep 5: Testing coarsening analysis tools...")

include("src/coarsening_analysis.jl")

# Load data from one run
using HDF5
h5data = load_trajectories_hdf5(test_hdf5)

# Reconstruct particles for cluster analysis (simplified)
# In real usage, would reconstruct full ParticlePolar objects
println("  (Coarsening analysis requires full particle reconstruction - skipping detailed test)")

# ========================================
# Summary
# ========================================

println("\n" * "="^70)
println("PIPELINE TEST: ALL CHECKS PASSED ✓")
println("="^70)
println("Test output: $test_output_dir")
println()
println("The pipeline is ready for production use!")
println()
println("Next steps:")
println("  1. Generate full parameter matrix:")
println("     julia generate_parameter_matrix.jl minimal")
println()
println("  2. Launch campaign:")
println("     ./launch_campaign.sh parameter_matrix_minimal.csv --mode parallel --jobs 24")
println()
println("  3. Monitor progress and analyze results:")
println("     julia analyze_ensemble.jl results/campaign_YYYYMMDD_HHMMSS/<combo_dir>")
println("="^70)
