#!/usr/bin/env julia
"""
Reprocess completed E/N scan simulations to generate summary.json files.
For runs that completed HDF5 but failed on post-processing.
"""

using Pkg
Pkg.activate(".")

using HDF5
using Statistics
using JSON
using Printf

campaign_dir = ARGS[1]

# Find directories with HDF5 but no summary.json
dirs_to_process = String[]
for dir in readdir(campaign_dir, join=true)
    if isdir(dir)
        h5_file = joinpath(dir, "trajectories.h5")
        json_file = joinpath(dir, "summary.json")
        if isfile(h5_file) && !isfile(json_file)
            push!(dirs_to_process, dir)
        end
    end
end

println("Found $(length(dirs_to_process)) directories to reprocess")

for (i, dir) in enumerate(dirs_to_process)
    try
        dir_name = basename(dir)
        # Parse directory name: e0.50_N040_E0.10_t500_seed01
        parts = split(dir_name, "_")
        e = parse(Float64, replace(parts[1], "e" => ""))
        N = parse(Int, replace(parts[2], "N" => ""))
        E_per_N = parse(Float64, replace(parts[3], "E" => ""))
        t_max = parse(Float64, replace(parts[4], "t" => ""))
        seed = parse(Int, replace(parts[5], "seed" => ""))

        h5_file = joinpath(dir, "trajectories.h5")

        h5open(h5_file, "r") do fid
            # Read data
            times = read(fid, "trajectories/time")
            phi = read(fid, "trajectories/phi")  # Shape: (n_times, N)
            total_energy = read(fid, "conservation/total_energy")

            n_times = length(times)

            # Energy conservation
            E_initial = total_energy[1]
            E_final = total_energy[end]
            dE_E0 = abs(E_final - E_initial) / abs(E_initial)

            # Calculate σ_φ over time - phi is (n_times, N)
            sigma_phi_evolution = [std(phi[t, :]) for t in 1:n_times]

            # Final state
            phi_final = phi[end, :]
            phi_mean = mean(phi_final)
            phi_std = std(phi_final)

            # Clustering metrics
            is_clustered_05 = phi_std < 0.5
            is_clustered_10 = phi_std < 1.0
            is_clustered_15 = phi_std < 1.5

            # Time to cluster
            t_cluster_05 = findfirst(x -> x < 0.5, sigma_phi_evolution)
            t_cluster_10 = findfirst(x -> x < 1.0, sigma_phi_evolution)
            t_cluster_15 = findfirst(x -> x < 1.5, sigma_phi_evolution)

            t_cluster_05 = isnothing(t_cluster_05) ? nothing : times[t_cluster_05]
            t_cluster_10 = isnothing(t_cluster_10) ? nothing : times[t_cluster_10]
            t_cluster_15 = isnothing(t_cluster_15) ? nothing : times[t_cluster_15]

            # Save summary
            summary = Dict(
                "run_id" => i,
                "N" => N,
                "eccentricity" => e,
                "E_per_N" => E_per_N,
                "t_max" => times[end],
                "seed" => seed,
                "n_snapshots" => n_times,
                "E_initial" => E_initial,
                "E_final" => E_final,
                "dE_E0" => dE_E0,
                "phi_mean_final" => phi_mean,
                "phi_std_final" => phi_std,
                "phi_std_initial" => sigma_phi_evolution[1],
                "is_clustered_05" => is_clustered_05,
                "is_clustered_10" => is_clustered_10,
                "is_clustered_15" => is_clustered_15,
                "t_cluster_05" => t_cluster_05,
                "t_cluster_10" => t_cluster_10,
                "t_cluster_15" => t_cluster_15,
                "completed" => true
            )

            json_file = joinpath(dir, "summary.json")
            open(json_file, "w") do io
                JSON.print(io, summary, 2)
            end

            # Save σ_φ evolution
            sigma_file = joinpath(dir, "sigma_phi_evolution.csv")
            open(sigma_file, "w") do io
                println(io, "time,sigma_phi")
                for (t, s) in zip(times, sigma_phi_evolution)
                    println(io, "$t,$s")
                end
            end
        end

        @printf("[%d/%d] %s: σ_φ=%.3f, clustered=%s\n",
                i, length(dirs_to_process), dir_name,
                JSON.parsefile(joinpath(dir, "summary.json"))["phi_std_final"],
                JSON.parsefile(joinpath(dir, "summary.json"))["is_clustered_05"])

    catch ex
        println("Error processing $dir: $ex")
    end
end

println("\nReprocessing complete!")
