#!/usr/bin/env julia
"""
Create phase space visualization data for animation.
Outputs CSV files that can be plotted with any tool.

Usage:
    julia --project=. scripts/analysis/create_phase_space_animation.jl <h5_file> [output_dir]
"""

using Pkg
Pkg.activate(".")

using HDF5
using Statistics
using Printf

function create_animation_data(h5_file::String, output_dir::String)
    mkpath(output_dir)

    println("Creating phase space animation data...")
    println("Input: $h5_file")
    println("Output: $output_dir")

    h5open(h5_file, "r") do fid
        times = read(fid, "trajectories/time")
        phi = read(fid, "trajectories/phi")
        phidot = read(fid, "trajectories/phidot")

        # Handle data orientation
        if size(phi, 1) == length(times)
            n_times, N = size(phi)
        else
            phi = phi'
            phidot = phidot'
            n_times, N = size(phi)
        end

        println("N = $N particles, $n_times frames")

        # Create frame-by-frame output
        frames_file = joinpath(output_dir, "phase_space_frames.csv")
        open(frames_file, "w") do io
            println(io, "frame,time,particle,phi,phidot")
            for t_idx in 1:n_times
                for p in 1:N
                    @printf(io, "%d,%.4f,%d,%.6f,%.6f\n",
                            t_idx, times[t_idx], p, phi[t_idx, p], phidot[t_idx, p])
                end
            end
        end
        println("Saved: $frames_file")

        # Create density grid over time (for heatmap animation)
        n_phi_bins = 36
        n_phidot_bins = 20

        phidot_min = minimum(phidot) * 1.1
        phidot_max = maximum(phidot) * 1.1

        density_file = joinpath(output_dir, "density_evolution.csv")
        open(density_file, "w") do io
            println(io, "frame,time,phi_bin,phidot_bin,phi_center,phidot_center,count")

            for t_idx in 1:n_times
                H = zeros(Int, n_phi_bins, n_phidot_bins)

                for p in 1:N
                    i = clamp(ceil(Int, phi[t_idx, p] / 2π * n_phi_bins), 1, n_phi_bins)
                    j = clamp(ceil(Int, (phidot[t_idx, p] - phidot_min) / (phidot_max - phidot_min) * n_phidot_bins), 1, n_phidot_bins)
                    H[i, j] += 1
                end

                for i in 1:n_phi_bins
                    for j in 1:n_phidot_bins
                        if H[i, j] > 0
                            phi_c = (i - 0.5) / n_phi_bins * 2π
                            phidot_c = phidot_min + (j - 0.5) / n_phidot_bins * (phidot_max - phidot_min)
                            @printf(io, "%d,%.4f,%d,%d,%.4f,%.4f,%d\n",
                                    t_idx, times[t_idx], i, j, phi_c, phidot_c, H[i, j])
                        end
                    end
                end
            end
        end
        println("Saved: $density_file")

        # Create angular density over time (1D projection)
        angular_file = joinpath(output_dir, "angular_density.csv")
        n_bins = 36
        open(angular_file, "w") do io
            println(io, "frame,time,bin,phi_center,count,density")

            for t_idx in 1:n_times
                counts = zeros(Int, n_bins)
                for p in 1:N
                    i = clamp(ceil(Int, phi[t_idx, p] / 2π * n_bins), 1, n_bins)
                    counts[i] += 1
                end

                uniform_density = N / n_bins
                for i in 1:n_bins
                    phi_c = (i - 0.5) / n_bins * 2π
                    density = counts[i] / uniform_density  # Normalized (1 = uniform)
                    @printf(io, "%d,%.4f,%d,%.4f,%d,%.4f\n",
                            t_idx, times[t_idx], i, phi_c, counts[i], density)
                end
            end
        end
        println("Saved: $angular_file")

        # Summary statistics per frame
        stats_file = joinpath(output_dir, "frame_statistics.csv")
        open(stats_file, "w") do io
            println(io, "frame,time,phi_mean,phi_std,phidot_mean,phidot_std,psi,S")

            for t_idx in 1:n_times
                φ = phi[t_idx, :]
                φ̇ = phidot[t_idx, :]

                # Order parameters
                ψ = abs(mean(exp.(im .* φ)))
                S = abs(mean(exp.(2im .* φ)))

                @printf(io, "%d,%.4f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
                        t_idx, times[t_idx], mean(φ), std(φ), mean(φ̇), std(φ̇), ψ, S)
            end
        end
        println("Saved: $stats_file")
    end

    println("\nAnimation data ready!")
    println("Use your favorite plotting tool to visualize.")
end

# Main
if length(ARGS) < 1
    println("Usage: julia create_phase_space_animation.jl <h5_file> [output_dir]")
    exit(1)
end

h5_file = ARGS[1]
output_dir = length(ARGS) >= 2 ? ARGS[2] : joinpath(dirname(h5_file), "animation_data")

create_animation_data(h5_file, output_dir)
