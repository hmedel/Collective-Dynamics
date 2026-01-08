"""
    run_single_EN_scan.jl

Execute a single simulation for E/N (temperature) scan campaign.

This script varies the energy per particle (effective temperature) to study
phase transitions and thermalization.

Usage:
    julia --project=. run_single_EN_scan.jl <run_id> <N> <e> <E_per_N> <seed> <campaign_dir>

Arguments:
    run_id      - Unique run ID
    N           - Number of particles
    e           - Eccentricity
    E_per_N     - Energy per particle (effective temperature)
    seed        - Random seed
    campaign_dir - Output directory
"""

using Pkg
Pkg.activate(".")

using Random
using Printf
using Dates
using JSON

# Load project modules (relative to project root)
const PROJECT_ROOT = dirname(dirname(@__DIR__))
include(joinpath(PROJECT_ROOT, "src", "geometry", "metrics_polar.jl"))
include(joinpath(PROJECT_ROOT, "src", "geometry", "christoffel_polar.jl"))
include(joinpath(PROJECT_ROOT, "src", "particles_polar.jl"))
include(joinpath(PROJECT_ROOT, "src", "collisions_polar.jl"))
include(joinpath(PROJECT_ROOT, "src", "integrators", "forest_ruth_polar.jl"))
include(joinpath(PROJECT_ROOT, "src", "simulation_polar.jl"))
include(joinpath(PROJECT_ROOT, "src", "io_hdf5.jl"))

# ============================================================================
# Parse command line arguments
# ============================================================================

if length(ARGS) < 6
    println("""
    Usage: julia run_single_EN_scan.jl <run_id> <N> <e> <E_per_N> <seed> <campaign_dir>

    Arguments:
        run_id       - Unique run ID
        N            - Number of particles
        e            - Eccentricity
        E_per_N      - Energy per particle (effective temperature)
        seed         - Random seed
        campaign_dir - Output directory

    Example:
        julia --project=. run_single_EN_scan.jl 1 40 0.866 0.32 1 results/EN_scan/
    """)
    exit(1)
end

# Parse arguments
run_id = parse(Int, ARGS[1])
N = parse(Int, ARGS[2])
e = parse(Float64, ARGS[3])
E_per_N = parse(Float64, ARGS[4])
seed = parse(Int, ARGS[5])
campaign_dir = ARGS[6]

# ============================================================================
# Derived parameters
# ============================================================================

# Geometry from eccentricity
# e² = 1 - b²/a², with b=1 → a = 1/√(1-e²)
b = 1.0
a = e ≈ 0.0 ? 1.0 : b / sqrt(1 - e^2)

# Fixed simulation parameters
max_time = 100.0        # Simulation time
dt_max = 1e-5           # Maximum timestep
dt_min = 1e-10          # Minimum timestep
save_interval = 0.5     # Save interval
mass = 1.0              # Particle mass

# Particle radius (fixed fraction of perimeter)
N_max_ref = 100         # Reference for radius calculation
perimeter = ellipse_perimeter(a, b)
radius = perimeter / (2 * N_max_ref)

# Max speed from E/N
# For uniform velocity distribution: E/N ≈ 0.32 * v_max²
# v_max = sqrt(E_per_N / 0.32)
max_speed = sqrt(E_per_N / 0.32)

# Projection settings (more frequent for high e or high E)
use_projection = true
if e >= 0.8 || E_per_N >= 1.0
    projection_interval = 5
elseif e >= 0.5 || E_per_N >= 0.4
    projection_interval = 10
else
    projection_interval = 20
end

# ============================================================================
# Helper function for ellipse perimeter
# ============================================================================

function ellipse_perimeter(a, b)
    # Ramanujan's approximation
    h = ((a - b) / (a + b))^2
    return π * (a + b) * (1 + 3h / (10 + sqrt(4 - 3h)))
end

# ============================================================================
# Create output directory
# ============================================================================

output_subdir = @sprintf("e%.2f_N%03d_E%.2f_seed%02d", e, N, E_per_N, seed)
output_dir = joinpath(campaign_dir, output_subdir)
mkpath(output_dir)

# ============================================================================
# Log start
# ============================================================================

log_file = joinpath(output_dir, "run.log")
start_time = now()

open(log_file, "w") do io
    println(io, "="^80)
    println(io, "E/N SCAN CAMPAIGN RUN")
    println(io, "="^80)
    println(io, "Start time: ", start_time)
    println(io, "Run ID: ", run_id)
    println(io, "")
    println(io, "Parameters:")
    println(io, "  N = ", N)
    println(io, "  e = ", e)
    println(io, "  E/N = ", E_per_N, " (effective temperature)")
    println(io, "  v_max = ", round(max_speed, digits=4))
    println(io, "  a = ", round(a, digits=4))
    println(io, "  b = ", b)
    println(io, "  radius = ", round(radius, digits=6))
    println(io, "  seed = ", seed)
    println(io, "  max_time = ", max_time)
    println(io, "  dt_max = ", dt_max)
    println(io, "  projection_interval = ", projection_interval)
    println(io, "")
end

println("Starting E/N scan run: e=$e, N=$N, E/N=$E_per_N, seed=$seed")

# ============================================================================
# Initialize particles
# ============================================================================

Random.seed!(seed)

particles = generate_random_particles_polar(
    N, mass, radius, a, b;
    max_speed=max_speed
)

println("Generated $N particles with max_speed=$max_speed")

# ============================================================================
# Run simulation
# ============================================================================

println("Starting simulation...")
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
println(@sprintf("Simulation completed in %.1f seconds", sim_elapsed))

# ============================================================================
# Save results
# ============================================================================

# Save trajectories to HDF5
h5_file = joinpath(output_dir, "trajectories.h5")
save_trajectories_hdf5(h5_file, result)
println("Saved trajectories to: $h5_file")

# Calculate summary statistics
E_initial = result.conservation.total_energy[1]
E_final = result.conservation.total_energy[end]
dE_E0 = abs(E_final - E_initial) / abs(E_initial)

# Final state analysis
final_particles = result.particles_history[end]
phi_values = [p.φ for p in final_particles]
phi_mean = mean(phi_values)
phi_std = std(phi_values)

# Clustering metric (simple)
# σ_φ < 0.5 suggests clustering
is_clustered = phi_std < 0.5

# Save summary JSON
summary = Dict(
    "run_id" => run_id,
    "N" => N,
    "eccentricity" => e,
    "E_per_N" => E_per_N,
    "v_max" => max_speed,
    "a" => a,
    "b" => b,
    "radius" => radius,
    "seed" => seed,
    "max_time" => max_time,
    "n_snapshots" => length(result.times),
    "total_collisions" => sum(result.n_collisions),
    "E_initial" => E_initial,
    "E_final" => E_final,
    "dE_E0" => dE_E0,
    "phi_mean_final" => phi_mean,
    "phi_std_final" => phi_std,
    "is_clustered" => is_clustered,
    "wall_time_seconds" => sim_elapsed,
    "completed" => true
)

json_file = joinpath(output_dir, "summary.json")
open(json_file, "w") do io
    JSON.print(io, summary, 2)
end
println("Saved summary to: $json_file")

# ============================================================================
# Final log
# ============================================================================

end_time = now()

open(log_file, "a") do io
    println(io, "")
    println(io, "="^80)
    println(io, "RESULTS")
    println(io, "="^80)
    println(io, "Total collisions: ", sum(result.n_collisions))
    println(io, "Energy conservation: dE/E0 = ", @sprintf("%.2e", dE_E0))
    println(io, "Final σ_φ: ", @sprintf("%.4f", phi_std))
    println(io, "Clustered: ", is_clustered)
    println(io, "Wall time: ", @sprintf("%.1f", sim_elapsed), " seconds")
    println(io, "End time: ", end_time)
    println(io, "="^80)
end

println(@sprintf("Done! dE/E0=%.2e, σ_φ=%.3f, clustered=%s", dE_E0, phi_std, is_clustered))
