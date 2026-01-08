#!/usr/bin/env julia
"""
Reprocess HDF5 Files - Extract Analysis from Existing Simulations

This script reads existing HDF5 trajectory files and generates the missing
summary.json and cluster_evolution.csv files using the fixed analysis code.

Usage:
    julia --project=. reprocess_hdf5.jl results/campaign_20251114_151101

This will find all HDF5 files that are missing summary.json and reprocess them.
"""

using HDF5
using JSON
using DataFrames
using CSV
using Printf
using Dates

# Load required packages
using StaticArrays

# Load source files directly (polar coordinate system)
include("src/geometry/metrics_polar.jl")
include("src/particles_polar.jl")
include("src/coarsening_analysis.jl")

"""
    sanitize_for_json(obj)

Recursively replace NaN and Inf with nothing (serializes as null in JSON).
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
    reprocess_hdf5(hdf5_file::String)

Read HDF5, run analysis, generate summary.json and cluster_evolution.csv
"""
function reprocess_hdf5(hdf5_file::String)
    output_dir = dirname(hdf5_file)

    # Check if already processed
    json_file = joinpath(output_dir, "summary.json")
    if isfile(json_file)
        println("  ⏭️  Already has summary.json, skipping")
        return :skipped
    end

    println("  📊 Loading HDF5...")

    # Read HDF5
    h5open(hdf5_file, "r") do file
        # Read trajectory data
        traj = file["trajectories"]
        times = read(traj["time"])
        phi_matrix = read(traj["phi"])
        phidot_matrix = read(traj["phidot"])

        n_snapshots, n_particles = size(phi_matrix)

        # Read metadata
        meta = file["metadata"]
        a = attrs(meta)["a"]
        b = attrs(meta)["b"]
        ecc = attrs(meta)["eccentricity"]
        seed = haskey(attrs(meta), "seed") ? attrs(meta)["seed"] : 0

        # Read config
        config_group = file["config"]
        phi_packing = haskey(attrs(config_group), "phi") ? attrs(config_group)["phi"] : 0.06
        E_per_N = haskey(attrs(config_group), "E_per_N") ? attrs(config_group)["E_per_N"] : 0.32

        # Reconstruct particles_history from matrices
        particles_history = []
        for i in 1:n_snapshots
            particles = []
            for j in 1:n_particles
                # Use constructor that calculates Cartesian coordinates
                p = ParticlePolar(
                    j,          # id
                    1.0,        # mass
                    0.05,       # radius (default)
                    phi_matrix[i, j],      # φ
                    phidot_matrix[i, j],   # φ_dot
                    a, b        # ellipse parameters
                )
                push!(particles, p)
            end
            push!(particles_history, particles)
        end

        # Read conservation
        cons = file["conservation"]
        energy_errors = read(cons["dE_E0"])

        println("  🔬 Analyzing clustering dynamics...")

        # Run analysis
        metrics, evolution = analyze_full_clustering_dynamics(
            particles_history,
            times,
            a, b;
            threshold = 0.2
        )

        println("  💾 Saving results...")

        # Create summary
        config = Dict(
            :eccentricity => ecc,
            :N => n_particles,
            :phi => phi_packing,
            :E_per_N => E_per_N,
            :seed => seed,
            :a => a,
            :b => b
        )

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
                "dE_E0_final" => energy_errors[end],
                "dE_E0_max" => maximum(abs.(energy_errors))
            ),
            "timestamp" => Dates.format(now(), "yyyy-mm-dd HH:MM:SS"),
            "reprocessed" => true
        )

        # Sanitize and save JSON
        summary_sanitized = sanitize_for_json(summary)
        open(json_file, "w") do io
            JSON.print(io, summary_sanitized, 2)
        end

        # Save evolution CSV
        evolution_df = DataFrame(
            time = evolution.times,
            N_clusters = evolution.N_clusters,
            s_max = evolution.s_max,
            s_avg = evolution.s_avg
        )
        csv_file = joinpath(output_dir, "cluster_evolution.csv")
        CSV.write(csv_file, evolution_df)

        println("  ✅ Complete: $(basename(output_dir))")
        return :success
    end
end

"""
    main()

Find and reprocess all HDF5 files missing summary.json
"""
function main()
    if length(ARGS) < 1
        println("Usage: julia --project=. reprocess_hdf5.jl <campaign_dir>")
        println("Example: julia --project=. reprocess_hdf5.jl results/campaign_20251114_151101")
        exit(1)
    end

    campaign_dir = ARGS[1]

    if !isdir(campaign_dir)
        println("Error: Directory not found: $campaign_dir")
        exit(1)
    end

    println("="^70)
    println("HDF5 Reprocessing Tool")
    println("="^70)
    println("Campaign: $campaign_dir")
    println()

    # Find all HDF5 files
    println("Scanning for HDF5 files...")
    hdf5_files = String[]
    for (root, dirs, files) in walkdir(campaign_dir)
        for file in files
            if endswith(file, ".h5")
                push!(hdf5_files, joinpath(root, file))
            end
        end
    end

    println("Found $(length(hdf5_files)) HDF5 files")
    println()

    # Filter for files missing summary.json
    to_process = String[]
    for hdf5 in hdf5_files
        json_file = joinpath(dirname(hdf5), "summary.json")
        if !isfile(json_file)
            push!(to_process, hdf5)
        end
    end

    println("Files needing reprocessing: $(length(to_process))")
    println("Files already processed: $(length(hdf5_files) - length(to_process))")
    println()

    if isempty(to_process)
        println("✅ All files already processed!")
        return
    end

    # Process each file
    stats = Dict(:success => 0, :failed => 0, :skipped => 0)

    println("Starting reprocessing...")
    println("-"^70)

    for (i, hdf5) in enumerate(to_process)
        println("[$i/$(length(to_process))] $(basename(dirname(hdf5)))")

        try
            result = reprocess_hdf5(hdf5)
            stats[result] += 1
        catch e
            println("  ❌ ERROR: $e")
            stats[:failed] += 1
        end

        println()
    end

    # Summary
    println("="^70)
    println("Reprocessing Complete!")
    println("="^70)
    println("Success: $(stats[:success])")
    println("Failed:  $(stats[:failed])")
    println("Skipped: $(stats[:skipped])")
    println("="^70)
end

main()
