#!/usr/bin/env julia
#
# generate_extended_campaign_matrix.jl
#
# Generate parameter matrix for extended time campaign
# Focus: High eccentricity, longer times (t_max=500)
#

using Printf
using CSV
using DataFrames

println("="^60)
println("EXTENDED TIME CAMPAIGN - Parameter Matrix Generator")
println("="^60)

# Parameters - focused on interesting regime
N_values = [40, 60, 80]           # Moderate to large N
e_values = [0.7, 0.8, 0.9]        # High eccentricity only
n_seeds = 10                       # 10 seeds per condition
a = 2.0                            # Semi-major axis
radius_fraction = 0.05             # Particle radius as fraction of b

# Simulation parameters - EXTENDED
max_time = 500.0                   # 5x longer!
dt_max = 1e-5
dt_min = 1e-10
save_interval = 2.5                # Save every 2.5 time units (200 snapshots)

# Generate matrix
runs = DataFrame(
    run_id = Int[],
    N = Int[],
    e = Float64[],
    a = Float64[],
    b = Float64[],
    seed = Int[],
    max_time = Float64[],
    dt_max = Float64[],
    dt_min = Float64[],
    save_interval = Float64[]
)

run_id = 0
for N in N_values
    for e in e_values
        b = a * sqrt(1 - e^2)
        for seed in 1:n_seeds
            global run_id += 1
            push!(runs, (run_id, N, e, a, b, seed, max_time, dt_max, dt_min, save_interval))
        end
    end
end

# Summary
println("\nCampaign Configuration:")
println("-"^60)
println("  N values:        ", N_values)
println("  e values:        ", e_values)
println("  Seeds/condition: ", n_seeds)
println("  max_time:        ", max_time)
println("  save_interval:   ", save_interval)
println("  Total runs:      ", nrow(runs))
println()

# Estimate runtime
# Previous: t=100 took ~12 minutes for e=0.9, N=80
# Extended: t=500 should take ~60 minutes per run
est_time_per_run = 60  # minutes
n_cores = 24
total_time_hours = (nrow(runs) * est_time_per_run) / (n_cores * 60)
@printf("Estimated runtime: %.1f hours (with %d cores)\n", total_time_hours, n_cores)

# Save matrix
output_file = "parameter_matrix_extended_campaign.csv"
CSV.write(output_file, runs)
println("\n✅ Saved: $output_file")

# Print first few rows
println("\nFirst 5 runs:")
println(first(runs, 5))
