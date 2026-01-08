#!/usr/bin/env julia
"""
Run Single Experiment from Parameter Matrix

Executes one simulation with specified parameters and saves results in HDF5 format.
Designed for batch processing via SLURM or GNU parallel.

Usage:
    julia --project=. --threads=24 run_single_experiment.jl \
        --eccentricity 0.866 --N 40 --phi 0.06 --E_per_N 0.32 --seed 42 \
        --output_dir results/campaign_main

Or from parameter matrix row:
    julia --project=. run_single_experiment.jl --param_file parameter_matrix.csv --run_id 123
"""

using ArgParse
using HDF5
using JSON
using Dates
using Random
using Printf
using CSV
using DataFrames

# Load polar implementation (not in CollectiveDynamics module yet)
include("src/geometry/metrics_polar.jl")
include("src/geometry/christoffel_polar.jl")
include("src/particles_polar.jl")
include("src/integrators/forest_ruth_polar.jl")
include("src/collisions_polar.jl")
include("src/simulation_polar.jl")
include("src/io_hdf5.jl")
include("src/coarsening_analysis.jl")

function parse_commandline()
    s = ArgParseSettings(description="Run single experiment from campaign")

    @add_arg_table! s begin
        "--eccentricity", "-e"
            help = "Eccentricity (0 to ~0.98)"
            arg_type = Float64
        "--N", "-n"
            help = "Number of particles"
            arg_type = Int
        "--phi"
            help = "Packing fraction"
            arg_type = Float64
        "--E_per_N"
            help = "Energy per particle"
            arg_type = Float64
        "--seed", "-s"
            help = "Random seed"
            arg_type = Int
        "--output_dir", "-o"
            help = "Output directory"
            arg_type = String
            default = "results/campaign_default"
        "--param_file"
            help = "Parameter matrix CSV file"
            arg_type = String
        "--run_id"
            help = "Run ID from parameter matrix"
            arg_type = Int
        "--t_max"
            help = "Maximum simulation time"
            arg_type = Float64
            default = 50.0
        "--use_parallel"
            help = "Use parallel collision detection"
            action = :store_true
        "--save_collisions"
            help = "Save collision events"
            action = :store_true
    end

    return parse_args(s)
end

"""
    get_save_interval(t_max::Float64)

Choose save interval based on total simulation time:
- For t_max <= 10s: 0.01s (high resolution)
- For t_max <= 50s: 0.05s (medium resolution)
- For t_max > 50s: 0.1s (coarse resolution)
"""
function get_save_interval(t_max::Float64)
    if t_max <= 10.0
        return 0.01
    elseif t_max <= 50.0
        return 0.05
    else
        return 0.1
    end
end

"""
    sanitize_for_json(obj)

Recursively replace NaN and Inf with nothing (serializes as null in JSON).
This prevents JSON serialization errors when metrics contain NaN/Inf values.
"""
function sanitize_for_json(obj)
    if obj isa AbstractDict
        return Dict(k => sanitize_for_json(v) for (k, v) in obj)
    elseif obj isa AbstractArray
        return [sanitize_for_json(x) for x in obj]
    elseif obj isa AbstractFloat
        return (isnan(obj) || isinf(obj)) ? nothing : obj
    else
        return obj
    end
end

"""
    setup_from_parameters(ecc, N, phi, E_per_N, seed)

Create simulation configuration from campaign parameters.
"""
function setup_from_parameters(ecc::Float64, N::Int, phi::Float64, E_per_N::Float64, seed::Int)
    # Convert eccentricity to (a, b)
    # Keep a·b = 2.0 constant
    a_b_product = 2.0
    a_over_b = ecc ≈ 0.0 ? 1.0 : 1.0 / sqrt(1 - ecc^2)

    # Solve: a·b = 2 and a/b = ratio
    # → a = sqrt(2 · ratio), b = sqrt(2 / ratio)
    a = sqrt(a_b_product * a_over_b)
    b = sqrt(a_b_product / a_over_b)

    # Calculate particle radius from packing fraction
    # φ = N·π·r² / (π·a·b) → r = sqrt(φ·a·b / N)
    radius = sqrt(phi * a_b_product / N)

    # Calculate v_max from E_per_N
    # Approximate: E/N ≈ 0.32 · v_max² for a·b = 2
    v_max = sqrt(E_per_N / 0.32)

    config = Dict{Symbol, Any}(
        :a => a,
        :b => b,
        :N => N,
        :radius => radius,
        :v_max => v_max,
        :seed => seed,
        :eccentricity => ecc,
        :phi => phi,
        :E_per_N => E_per_N
    )

    return config
end

"""
    run_experiment(config, output_dir; t_max=50.0, use_parallel=false, save_collisions=false)

Execute simulation with given configuration.
"""
function run_experiment(config, output_dir; t_max=50.0, use_parallel=false, save_collisions=false)
    # Create output directory
    mkpath(output_dir)

    # Extract parameters
    a = config[:a]
    b = config[:b]
    N = config[:N]
    radius = config[:radius]
    v_max = config[:v_max]
    seed = config[:seed]

    println("="^70)
    println("Running Experiment")
    println("="^70)
    println("Geometry: a=$a, b=$b (e=$(round(config[:eccentricity], digits=3)))")
    println("Particles: N=$N, r=$radius (φ=$(round(config[:phi], digits=4)))")
    println("Energy: E/N≈$(round(config[:E_per_N], digits=3)), v_max=$v_max")
    println("Seed: $seed")
    println("Parallel: $use_parallel")
    println("Output: $output_dir")
    println("="^70)

    # Generate particles
    println("\nGenerating initial conditions...")
    Random.seed!(seed)
    particles = generate_random_particles_polar(N, v_max, radius, a, b)

    # Determine save interval
    save_interval = get_save_interval(t_max)
    expected_snapshots = ceil(Int, t_max / save_interval) + 1
    println("Save interval: $(save_interval)s (~$(expected_snapshots) snapshots)")

    # Run simulation
    println("\nStarting simulation...")
    start_time = time()

    data = simulate_ellipse_polar_adaptive(
        particles, a, b;
        max_time = t_max,
        dt_max = 1e-5,
        dt_min = 1e-10,
        save_interval = save_interval,
        max_steps = 50_000_000,
        use_projection = true,
        projection_interval = 100,
        projection_tolerance = 1e-12,
        collision_method = :parallel_transport,
        verbose = false  # Suppress verbose output for batch runs
    )

    wall_time = time() - start_time
    println("\nSimulation completed in $(round(wall_time, digits=1))s")
    println("  Total collisions: $(sum(data.n_collisions))")
    println("  Final ΔE/E₀: $(data.conservation.energy_errors[end])")

    # Save results
    println("\nSaving results...")

    # 1. Save trajectories (HDF5)
    hdf5_file = joinpath(output_dir, "trajectories.h5")
    data_for_hdf5 = (
        particles_history = data.particles_history,
        times = data.times,
        conservation = data.conservation,
        config = config
    )
    save_trajectories_hdf5(hdf5_file, data_for_hdf5; compress=true)

    # 2. Analyze clustering dynamics
    println("Analyzing clustering dynamics...")
    metrics, evolution = analyze_full_clustering_dynamics(
        data.particles_history,
        data.times,
        a, b;
        threshold = 0.2  # 0.2 rad ≈ 11.5°
    )

    # 3. Save summary (JSON)
    summary = Dict(
        "parameters" => config,
        "timescales" => Dict(
            "t_nucleation" => metrics.t_nucleation,
            "t_half" => metrics.t_half,
            "t_cluster" => metrics.t_cluster,
            "t_saturation" => metrics.t_saturation
        ),
        "growth_exponent" => Dict(
            "alpha" => metrics.alpha,
            "alpha_std" => metrics.alpha_std,
            "R_squared" => metrics.R_squared
        ),
        "final_state" => Dict(
            "N_clusters" => metrics.N_clusters_final,
            "s_max" => metrics.s_max_final,
            "sigma_phi" => metrics.sigma_phi_final
        ),
        "conservation" => Dict(
            "dE_E0_final" => data.conservation.energy_errors[end],
            "dE_E0_max" => maximum(abs.(data.conservation.energy_errors))
        ),
        "performance" => Dict(
            "wall_time_seconds" => wall_time,
            "total_collisions" => sum(data.n_collisions),
            "n_snapshots" => length(data.times)
        ),
        "timestamp" => Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
    )

    json_file = joinpath(output_dir, "summary.json")
    # Sanitize NaN/Inf before JSON serialization
    summary_sanitized = sanitize_for_json(summary)
    open(json_file, "w") do io
        JSON.print(io, summary_sanitized, 2)
    end
    println("Saved summary: $json_file")

    # 4. Save evolution data (CSV for easy plotting)
    evolution_df = DataFrame(
        time = evolution.times,
        N_clusters = evolution.N_clusters,
        s_max = evolution.s_max,
        s_avg = evolution.s_avg
    )
    csv_file = joinpath(output_dir, "cluster_evolution.csv")
    CSV.write(csv_file, evolution_df)
    println("Saved evolution: $csv_file")

    # 5. Save collision events (optional)
    if save_collisions
        # TODO: Implement detailed collision tracking
        println("Collision events: not yet implemented")
    end

    println("\n" * "="^70)
    println("Experiment Complete!")
    println("="^70)
    println("Output directory: $output_dir")
    println("Key results:")
    println("  t_1/2 = $(round(metrics.t_half, digits=2))s")
    println("  α = $(round(metrics.alpha, digits=3)) ± $(round(metrics.alpha_std, digits=3))")
    println("  Final clusters: $(metrics.N_clusters_final)")
    println("="^70)

    return summary
end

# ========================================
# Main Execution
# ========================================

function main()
    args = parse_commandline()

    # Determine parameters source
    if args["param_file"] !== nothing && args["run_id"] !== nothing
        # Load from parameter matrix
        param_df = CSV.read(args["param_file"], DataFrame)
        row = param_df[param_df.run_id .== args["run_id"], :][1, :]

        ecc = row.eccentricity
        N = row.N
        phi = row.phi
        E_per_N = row.E_per_N
        seed = row.seed

        # Output directory from matrix design
        ecc_str = @sprintf("e%.3f", ecc)
        output_dir = joinpath(args["output_dir"], "$(ecc_str)_N$(N)_phi$(phi)_E$(E_per_N)/seed_$(seed)")

    elseif all(haskey(args, k) && args[k] !== nothing for k in ["eccentricity", "N", "phi", "E_per_N", "seed"])
        # Direct specification
        ecc = args["eccentricity"]
        N = args["N"]
        phi = args["phi"]
        E_per_N = args["E_per_N"]
        seed = args["seed"]

        ecc_str = @sprintf("e%.3f", ecc)
        output_dir = joinpath(args["output_dir"], "$(ecc_str)_N$(N)_phi$(phi)_E$(E_per_N)/seed_$(seed)")

    else
        error("Must provide either (--param_file and --run_id) or (--eccentricity, --N, --phi, --E_per_N, --seed)")
    end

    # Setup configuration
    config = setup_from_parameters(ecc, N, phi, E_per_N, seed)

    # Run experiment
    summary = run_experiment(
        config, output_dir;
        t_max = args["t_max"],
        use_parallel = args["use_parallel"],
        save_collisions = args["save_collisions"]
    )

    return summary
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
