#!/usr/bin/env julia
"""
Run Experimental Campaign from Parameter Matrix

Executes simulations from parameter_matrix CSV file.
Supports parallel execution and progress tracking.
"""

using CSV
using DataFrames
using Dates
using Random
using Printf
using JSON

# Load polar implementation
include("src/geometry/metrics_polar.jl")
include("src/geometry/christoffel_polar.jl")
include("src/particles_polar.jl")
include("src/integrators/forest_ruth_polar.jl")
include("src/collisions_polar.jl")
include("src/simulation_polar.jl")
include("src/io_hdf5.jl")
include("src/coarsening_analysis.jl")

"""
    run_single_simulation(params::DataFrameRow; verbose=false)

Run a single simulation from parameter matrix row.

# Arguments
- `params::DataFrameRow`: Row from parameter matrix with fields:
  - `run_id`, `N`, `phi`, `radius`, `v_max`, `seed`, `eccentricity`, `a_b_ratio`

- `verbose::Bool`: Print progress messages

# Returns
- `Dict`: Results containing file paths and summary metrics
"""
function run_single_simulation(params; verbose=false)

    # Extract parameters
    run_id = params.run_id
    N = params.N
    v_max = params.v_max
    radius = params.radius
    seed = params.seed
    a_b_ratio = params.a_b_ratio

    # Ellipse geometry
    a = a_b_ratio  # Keep semi-major axis = a/b ratio for consistency
    b = 1.0        # Semi-minor axis = 1

    # Simulation parameters (optimized for production)
    max_time = 100.0  # Long enough for coarsening dynamics
    dt_max = 1e-5
    dt_min = 1e-10
    save_interval = 0.1  # Save every 0.1 time units (1000 snapshots)
    max_steps = 50_000_000  # Safety limit

    # Create output directory
    output_dir = joinpath("results", "pilot_campaign", "run_$(lpad(run_id, 4, '0'))")
    mkpath(output_dir)

    if verbose
        println("\n" * "="^70)
        println("RUN $run_id")
        println("="^70)
        println("  N = $N, φ = $(params.phi), e = $(params.eccentricity)")
        println("  a/b = $a_b_ratio, seed = $seed")
        println("  Output: $output_dir")
        println("="^70)
    end

    # Start timer
    t_start = time()

    try
        # Generate particles
        Random.seed!(seed)
        particles = generate_random_particles_polar(N, v_max, radius, a, b)

        # Initial energy
        E0 = sum(kinetic_energy_polar(p.φ, p.φ_dot, p.mass, a, b) for p in particles)

        # Run simulation
        if verbose
            println("  Running simulation (max_time = $(max_time)s)...")
        end

        data = simulate_ellipse_polar_adaptive(
            particles, a, b;
            max_time = max_time,
            dt_max = dt_max,
            dt_min = dt_min,
            save_interval = save_interval,
            max_steps = max_steps,
            use_projection = true,
            projection_interval = 100,
            projection_tolerance = 1e-12,
            collision_method = :parallel_transport,
            verbose = false  # Suppress verbose output for batch runs
        )

        # Compute wall time
        wall_time = time() - t_start

        # Save trajectories to HDF5
        hdf5_file = joinpath(output_dir, "trajectories.h5")

        # Add config to data structure
        data_with_config = (
            particles_history = data.particles_history,
            times = data.times,
            n_collisions = data.n_collisions,
            conservation = data.conservation,
            config = Dict(
                :N => N,
                :a => a,
                :b => b,
                :eccentricity => params.eccentricity,
                :phi => params.phi,
                :radius => radius,
                :v_max => v_max,
                :E_per_N => params.E_per_N,
                :seed => seed,
                :max_time => max_time,
                :dt_max => dt_max,
                :run_id => run_id
            )
        )

        save_trajectories_hdf5(hdf5_file, data_with_config; compress=true)

        # Extract summary statistics
        n_snapshots = length(data.times)
        n_collisions_total = sum(data.n_collisions)
        final_time = data.times[end]

        # Conservation metrics
        dE_E0_final = data.conservation.energy_errors[end]
        dE_E0_max = maximum(abs.(data.conservation.energy_errors))

        # Analyze clustering (compute standard deviation of φ over time)
        sigma_phi_timeseries = Float64[]
        for particles_snapshot in data.particles_history
            phi_vals = [p.φ for p in particles_snapshot]
            push!(sigma_phi_timeseries, std(phi_vals))
        end

        # Coarsening analysis (if clustering occurs)
        sigma_phi_final = sigma_phi_timeseries[end]
        sigma_phi_max = maximum(sigma_phi_timeseries)

        # Create summary
        summary = Dict(
            "run_id" => run_id,
            "parameters" => Dict(
                "N" => N,
                "eccentricity" => params.eccentricity,
                "phi" => params.phi,
                "E_per_N" => params.E_per_N,
                "seed" => seed
            ),
            "runtime" => Dict(
                "wall_time_seconds" => wall_time,
                "n_snapshots" => n_snapshots,
                "final_time" => final_time,
                "n_collisions" => n_collisions_total
            ),
            "conservation" => Dict(
                "dE_E0_final" => dE_E0_final,
                "dE_E0_max" => dE_E0_max
            ),
            "clustering" => Dict(
                "sigma_phi_final" => sigma_phi_final,
                "sigma_phi_max" => sigma_phi_max
            ),
            "files" => Dict(
                "trajectories" => hdf5_file
            )
        )

        # Save summary to JSON
        json_file = joinpath(output_dir, "summary.json")
        open(json_file, "w") do io
            JSON.print(io, summary, 2)
        end

        if verbose
            println("  ✓ Completed in $(round(wall_time, digits=1))s")
            println("    Snapshots: $n_snapshots, Collisions: $n_collisions_total")
            println("    ΔE/E₀ (max): $(dE_E0_max)")
            println("    σ_φ (final): $(round(sigma_phi_final, digits=3))")
        end

        return summary

    catch e
        wall_time = time() - t_start

        error_summary = Dict(
            "run_id" => run_id,
            "status" => "failed",
            "error" => string(e),
            "wall_time_seconds" => wall_time
        )

        # Save error info
        error_file = joinpath(output_dir, "error.json")
        open(error_file, "w") do io
            JSON.print(io, error_summary, 2)
        end

        if verbose
            println("  ✗ FAILED after $(round(wall_time, digits=1))s")
            println("    Error: $e")
        end

        rethrow(e)
    end
end

"""
    run_campaign(matrix_file::String; start_run=1, end_run=nothing, update_csv=true)

Run campaign from parameter matrix CSV file.

# Arguments
- `matrix_file::String`: Path to parameter matrix CSV
- `start_run::Int`: First run_id to execute (default: 1)
- `end_run::Int`: Last run_id to execute (default: all)
- `update_csv::Bool`: Update CSV file with progress (default: true)

# Example
```julia
# Run all simulations
run_campaign("parameter_matrix_pilot.csv")

# Run first 10 simulations
run_campaign("parameter_matrix_pilot.csv"; end_run=10)

# Run specific range
run_campaign("parameter_matrix_pilot.csv"; start_run=50, end_run=100)
```
"""
function run_campaign(matrix_file::String; start_run=1, end_run=nothing, update_csv=true)

    # Load parameter matrix (disable pooling to allow updates)
    df = CSV.read(matrix_file, DataFrame; pool=false, stringtype=String)

    if end_run === nothing
        end_run = maximum(df.run_id)
    end

    # Filter to requested range
    df_subset = filter(row -> start_run <= row.run_id <= end_run, df)

    n_runs = nrow(df_subset)

    println("="^70)
    println("CAMPAIGN EXECUTION")
    println("="^70)
    println("Matrix file: $matrix_file")
    println("Runs: $start_run to $end_run ($n_runs simulations)")
    println("="^70)

    # Track progress
    n_completed = 0
    n_failed = 0
    campaign_start = time()

    for (i, row) in enumerate(eachrow(df_subset))
        run_id = row.run_id

        println("\n[$i/$n_runs] Run $run_id")

        try
            # Run simulation
            summary = run_single_simulation(row; verbose=true)

            n_completed += 1

            # Save progress to JSON
            if update_csv && (i % 10 == 0 || i == n_runs)
                progress_file = "results/pilot_campaign/campaign_progress.json"
                progress_data = Dict(
                    "n_completed" => n_completed,
                    "n_failed" => n_failed,
                    "last_completed_run" => run_id,
                    "timestamp" => Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
                )
                open(progress_file, "w") do io
                    JSON.print(io, progress_data, 2)
                end
                println("  Progress saved to $progress_file")
            end

        catch e
            println("  ✗ Run $run_id FAILED: $e")
            n_failed += 1

            # Continue with next run
        end

        # Progress report
        elapsed = time() - campaign_start
        avg_time_per_run = elapsed / i
        remaining_runs = n_runs - i
        eta_seconds = remaining_runs * avg_time_per_run
        eta_hours = eta_seconds / 3600

        println("  Progress: $i/$n_runs ($(round(100*i/n_runs, digits=1))%)")
        println("  Completed: $n_completed, Failed: $n_failed")
        println("  Avg time/run: $(round(avg_time_per_run, digits=1))s")
        println("  ETA: $(round(eta_hours, digits=2)) hours")
    end

    # Final summary
    campaign_time = time() - campaign_start
    campaign_hours = campaign_time / 3600

    println("\n" * "="^70)
    println("CAMPAIGN COMPLETED")
    println("="^70)
    println("Total runs:     $n_runs")
    println("Completed:      $n_completed")
    println("Failed:         $n_failed")
    println("Wall time:      $(round(campaign_hours, digits=2)) hours")
    println("Avg time/run:   $(round(campaign_time/n_runs, digits=1))s")
    println("="^70)

    return (completed=n_completed, failed=n_failed, wall_time=campaign_time)
end

# ========================================
# Main Execution
# ========================================

if abspath(PROGRAM_FILE) == @__FILE__
    # Parse command line arguments
    if length(ARGS) == 0
        println("Usage:")
        println("  julia run_campaign.jl <matrix_file> [start_run] [end_run]")
        println()
        println("Example:")
        println("  julia run_campaign.jl parameter_matrix_pilot.csv")
        println("  julia run_campaign.jl parameter_matrix_pilot.csv 1 10")
        exit(1)
    end

    matrix_file = ARGS[1]
    start_run = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 1
    end_run = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : nothing

    # Run campaign
    result = run_campaign(matrix_file; start_run=start_run, end_run=end_run, update_csv=true)

    println()
    println("Campaign finished!")
    println("Results saved in: results/pilot_campaign/")
end
