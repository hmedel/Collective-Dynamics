"""
    run_single_EN_scan_long.jl

Execute a single long-time simulation for E/N scan campaign.
Similar to run_single_EN_scan.jl but with configurable t_max.

Usage:
    julia --project=. run_single_EN_scan_long.jl <run_id> <N> <e> <E_per_N> <t_max> <seed> <campaign_dir>
"""

using Pkg
Pkg.activate(".")

using Random
using Printf
using Dates
using Statistics
using JSON

# Load project modules
const PROJECT_ROOT = dirname(dirname(@__DIR__))
include(joinpath(PROJECT_ROOT, "src", "geometry", "metrics_polar.jl"))
include(joinpath(PROJECT_ROOT, "src", "geometry", "christoffel_polar.jl"))
include(joinpath(PROJECT_ROOT, "src", "particles_polar.jl"))
include(joinpath(PROJECT_ROOT, "src", "collisions_polar.jl"))
include(joinpath(PROJECT_ROOT, "src", "integrators", "forest_ruth_polar.jl"))
include(joinpath(PROJECT_ROOT, "src", "simulation_polar.jl"))
include(joinpath(PROJECT_ROOT, "src", "io_hdf5.jl"))

# Parse arguments
if length(ARGS) < 7
    println("""
    Usage: julia run_single_EN_scan_long.jl <run_id> <N> <e> <E_per_N> <t_max> <seed> <campaign_dir>
    """)
    exit(1)
end

run_id = parse(Int, ARGS[1])
N = parse(Int, ARGS[2])
e = parse(Float64, ARGS[3])
E_per_N = parse(Float64, ARGS[4])
max_time = parse(Float64, ARGS[5])
seed = parse(Int, ARGS[6])
campaign_dir = ARGS[7]

# Geometry
b = 1.0
a = e ≈ 0.0 ? 1.0 : b / sqrt(1 - e^2)

# Fixed parameters
dt_max = 1e-5
dt_min = 1e-10
save_interval = 1.0  # Save every 1s for long runs
mass = 1.0

# Particle radius
N_max_ref = 100
perimeter = ellipse_perimeter(a, b)
radius = perimeter / (2 * N_max_ref)

# Max speed from E/N
max_speed = sqrt(E_per_N / 0.32)

# Projection settings
use_projection = true
projection_interval = e >= 0.8 || E_per_N >= 1.0 ? 5 : (e >= 0.5 ? 10 : 20)

function ellipse_perimeter(a, b)
    h = ((a - b) / (a + b))^2
    return π * (a + b) * (1 + 3h / (10 + sqrt(4 - 3h)))
end

# Output directory
output_subdir = @sprintf("e%.2f_N%03d_E%.2f_t%d_seed%02d", e, N, E_per_N, Int(max_time), seed)
output_dir = joinpath(campaign_dir, output_subdir)
mkpath(output_dir)

# Log
log_file = joinpath(output_dir, "run.log")
start_time = now()

open(log_file, "w") do io
    println(io, "="^80)
    println(io, "LONG-TIME E/N SCAN RUN")
    println(io, "="^80)
    println(io, "Start time: ", start_time)
    println(io, "Run ID: ", run_id)
    println(io, "")
    println(io, "Parameters:")
    println(io, "  N = ", N)
    println(io, "  e = ", e)
    println(io, "  E/N = ", E_per_N)
    println(io, "  t_max = ", max_time, "s")
    println(io, "  v_max = ", round(max_speed, digits=4))
    println(io, "  a = ", round(a, digits=4))
    println(io, "  b = ", b)
    println(io, "  radius = ", round(radius, digits=6))
    println(io, "  seed = ", seed)
    println(io, "")
end

println("Starting long-time E/N scan: e=$e, N=$N, E/N=$E_per_N, t_max=$max_time, seed=$seed")

# Initialize particles
Random.seed!(seed)
particles = generate_random_particles_polar(N, mass, radius, a, b; max_speed=max_speed)
println("Generated $N particles")

# Run simulation
println("Starting simulation (t_max=$max_time s)...")
sim_start = time()

result = simulate_ellipse_polar_adaptive(
    particles, a, b;
    max_time=max_time,
    dt_max=dt_max,
    dt_min=dt_min,
    save_interval=save_interval,
    use_projection=use_projection,
    projection_interval=projection_interval,
    verbose=false
)

sim_elapsed = time() - sim_start
println(@sprintf("Simulation completed in %.1f seconds (%.1fx real-time)", sim_elapsed, max_time/sim_elapsed))

# Save trajectories
h5_file = joinpath(output_dir, "trajectories.h5")
save_trajectories_hdf5(h5_file, result)

# Calculate statistics
E_initial = result.conservation.energies[1]
E_final = result.conservation.energies[end]
dE_E0 = abs(E_final - E_initial) / abs(E_initial)

# Time evolution of clustering
times = result.times
n_times = length(times)

# Calculate σ_φ over time
sigma_phi_evolution = Float64[]
for t_idx in 1:n_times
    phi_t = [result.particles_history[t_idx][i].φ for i in 1:N]
    push!(sigma_phi_evolution, std(phi_t))
end

# Final state
final_particles = result.particles_history[end]
phi_values = [p.φ for p in final_particles]
phi_mean = mean(phi_values)
phi_std = std(phi_values)

# Clustering metrics at different thresholds
is_clustered_05 = phi_std < 0.5
is_clustered_10 = phi_std < 1.0
is_clustered_15 = phi_std < 1.5

# Time to reach different clustering levels (if ever)
t_cluster_05 = findfirst(x -> x < 0.5, sigma_phi_evolution)
t_cluster_10 = findfirst(x -> x < 1.0, sigma_phi_evolution)
t_cluster_15 = findfirst(x -> x < 1.5, sigma_phi_evolution)

t_cluster_05_val = isnothing(t_cluster_05) ? nothing : times[t_cluster_05]
t_cluster_10_val = isnothing(t_cluster_10) ? nothing : times[t_cluster_10]
t_cluster_15_val = isnothing(t_cluster_15) ? nothing : times[t_cluster_15]

# Save summary
summary = Dict(
    "run_id" => run_id,
    "N" => N,
    "eccentricity" => e,
    "E_per_N" => E_per_N,
    "t_max" => max_time,
    "v_max" => max_speed,
    "a" => a,
    "b" => b,
    "radius" => radius,
    "seed" => seed,
    "n_snapshots" => n_times,
    "total_collisions" => sum(result.n_collisions),
    "E_initial" => E_initial,
    "E_final" => E_final,
    "dE_E0" => dE_E0,
    "phi_mean_final" => phi_mean,
    "phi_std_final" => phi_std,
    "phi_std_initial" => sigma_phi_evolution[1],
    "is_clustered_05" => is_clustered_05,
    "is_clustered_10" => is_clustered_10,
    "is_clustered_15" => is_clustered_15,
    "t_cluster_05" => t_cluster_05_val,
    "t_cluster_10" => t_cluster_10_val,
    "t_cluster_15" => t_cluster_15_val,
    "wall_time_seconds" => sim_elapsed,
    "completed" => true
)

json_file = joinpath(output_dir, "summary.json")
open(json_file, "w") do io
    JSON.print(io, summary, 2)
end

# Save σ_φ evolution
sigma_file = joinpath(output_dir, "sigma_phi_evolution.csv")
open(sigma_file, "w") do io
    println(io, "time,sigma_phi")
    for (t, s) in zip(times, sigma_phi_evolution)
        println(io, "$t,$s")
    end
end

# Final log
end_time = now()
open(log_file, "a") do io
    println(io, "")
    println(io, "="^80)
    println(io, "RESULTS")
    println(io, "="^80)
    println(io, "Total collisions: ", sum(result.n_collisions))
    println(io, "Energy conservation: dE/E0 = ", @sprintf("%.2e", dE_E0))
    println(io, "Initial σ_φ: ", @sprintf("%.4f", sigma_phi_evolution[1]))
    println(io, "Final σ_φ: ", @sprintf("%.4f", phi_std))
    println(io, "Clustered (σ<0.5): ", is_clustered_05)
    println(io, "Clustered (σ<1.0): ", is_clustered_10)
    println(io, "t_cluster (σ<0.5): ", isnothing(t_cluster_05_val) ? "never" : @sprintf("%.1fs", t_cluster_05_val))
    println(io, "t_cluster (σ<1.0): ", isnothing(t_cluster_10_val) ? "never" : @sprintf("%.1fs", t_cluster_10_val))
    println(io, "Wall time: ", @sprintf("%.1f", sim_elapsed), " seconds")
    println(io, "End time: ", end_time)
    println(io, "="^80)
end

println(@sprintf("Done! dE/E0=%.2e, σ_φ=%.3f→%.3f, clustered=%s",
                 dE_E0, sigma_phi_evolution[1], phi_std, is_clustered_05))
