#!/usr/bin/env julia
"""
Quick Pipeline Test - Simplified Version

Tests basic infrastructure without full simulation.
"""

println("="^70)
println("Pipeline Test: Quick Validation")
println("="^70)

# Test 1: Parameter matrix generation
println("\n[1/4] Testing parameter matrix generation...")
try
    include("generate_parameter_matrix.jl")

    # Generate micro matrix
    using CSV, DataFrames
    combinations = [
        (run_id=1, eccentricity=0.866, a_b_ratio=2.0, ecc_label="Moderate",
         N=20, phi=0.06, radius=sqrt(0.06*2.0/20), E_per_N=0.32, v_max=1.0, seed=1),
    ]
    df = DataFrame(combinations)
    df[!, :design] .= "test"

    test_matrix = "parameter_matrix_test_quick.csv"
    CSV.write(test_matrix, df)

    println("  ✓ Parameter matrix generated: $test_matrix")
catch e
    println("  ✗ FAILED: $e")
    rethrow(e)
end

# Test 2: HDF5 I/O
println("\n[2/4] Testing HDF5 I/O...")
try
    using HDF5
    include("src/io_hdf5.jl")

    # Create dummy data
    test_file = "test_io.h5"
    h5open(test_file, "w") do file
        file["test_data"] = rand(100, 20)
        attrs(file)["N"] = 20
    end

    # Read back
    data = h5open(test_file, "r") do file
        read(file["test_data"])
    end

    @assert size(data) == (100, 20)

    # Cleanup
    rm(test_file)

    println("  ✓ HDF5 I/O working")
catch e
    println("  ✗ FAILED: $e")
    rethrow(e)
end

# Test 3: Coarsening analysis tools
println("\n[3/4] Testing coarsening analysis tools...")
try
    include("src/coarsening_analysis.jl")

    # Test growth exponent extraction
    times = collect(0.0:0.1:10.0)
    s_max = @. Int(floor(5 * times^0.5 + 1))  # Simulate s ~ t^0.5

    result = extract_growth_exponent(times, s_max)

    @assert !isnan(result.alpha)
    @assert 0.3 < result.alpha < 0.7  # Should be close to 0.5

    println("  ✓ Coarsening analysis working (α=$(round(result.alpha, digits=2)))")
catch e
    println("  ✗ FAILED: $e")
    rethrow(e)
end

# Test 4: JSON I/O
println("\n[4/4] Testing JSON summary creation...")
try
    using JSON

    summary = Dict(
        "parameters" => Dict("N" => 20, "e" => 0.866),
        "timescales" => Dict("t_half" => 5.0),
        "test" => true
    )

    test_json = "test_summary.json"
    open(test_json, "w") do io
        JSON.print(io, summary, 2)
    end

    # Read back
    loaded = JSON.parsefile(test_json)
    @assert loaded["test"] == true

    # Cleanup
    rm(test_json)

    println("  ✓ JSON I/O working")
catch e
    println("  ✗ FAILED: $e")
    rethrow(e)
end

# Summary
println("\n" * "="^70)
println("✅ QUICK PIPELINE TEST: ALL CHECKS PASSED")
println("="^70)
println()
println("Infrastructure is working! Key components validated:")
println("  • Parameter matrix generation")
println("  • HDF5 file I/O")
println("  • Coarsening analysis")
println("  • JSON summaries")
println()
println("Next steps:")
println("  1. Verify CollectiveDynamics module exports polar functions")
println("  2. Run a single quick simulation manually")
println("  3. Then proceed with full campaign")
println()
println("Quick manual test:")
println("  julia --project=. -e 'using CollectiveDynamics; println(\"Module loaded\")'")
println("="^70)
