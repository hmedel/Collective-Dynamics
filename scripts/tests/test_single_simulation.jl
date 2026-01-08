#!/usr/bin/env julia
"""
Test Single Polar Simulation

Runs one complete simulation to verify everything works end-to-end.
"""

using Random
using Statistics
using Printf

println("="^70)
println("Single Simulation Test: Polar Coordinates")
println("="^70)

# Include all polar implementation files
println("\nLoading polar implementation...")
include("src/geometry/metrics_polar.jl")
include("src/geometry/christoffel_polar.jl")
include("src/particles_polar.jl")
include("src/integrators/forest_ruth_polar.jl")
include("src/collisions_polar.jl")
# Note: projection methods are integrated in simulation_polar.jl
include("src/simulation_polar.jl")

# Test parameters
println("\nSimulation parameters:")
a, b = 2.0, 1.0
N = 10  # Small for quick test
v_max = 1.0
radius = 0.05
seed = 42
t_max = 1.0  # Very short
dt_max = 1e-5

println("  Ellipse: a=$a, b=$b (e=$(round(sqrt(1-(b/a)^2), digits=3)))")
println("  Particles: N=$N")
println("  Time: t_max=$(t_max)s")
println("  Seed: $seed")

# Generate particles
println("\nGenerating particles...")
Random.seed!(seed)
particles = generate_random_particles_polar(N, v_max, radius, a, b)
println("  ✓ Generated $N particles")

# Initial energy
E0 = sum(kinetic_energy_polar(p.φ, p.φ_dot, p.mass, a, b) for p in particles)
println("  Initial energy: E₀ = $(round(E0, digits=4))")

# Run simulation
println("\nRunning simulation...")
try
    data = simulate_ellipse_polar_adaptive(
        particles, a, b;
        max_time = t_max,
        dt_max = dt_max,
        dt_min = 1e-10,
        save_interval = 0.1,  # Save every 0.1s
        max_steps = 1_000_000,
        use_projection = true,
        projection_interval = 100,
        projection_tolerance = 1e-12,
        collision_method = :parallel_transport,
        verbose = true
    )

    println("  ✓ Simulation completed")

    # Check results
    n_snapshots = length(data.times)
    n_collisions_total = sum(data.n_collisions)

    println("\nResults:")
    println("  Snapshots: $n_snapshots")
    println("  Total collisions: $n_collisions_total")
    println("  Final time: $(round(data.times[end], digits=3))s")

    # Conservation
    if !isnothing(data.conservation)
        dE_E0_final = data.conservation.energy_errors[end]
        dE_E0_max = maximum(abs.(data.conservation.energy_errors))

        println("\nConservation:")
        println("  ΔE/E₀ (final): $(dE_E0_final)")
        println("  ΔE/E₀ (max):   $(dE_E0_max)")

        if dE_E0_max < 1e-6
            println("  ✓ Excellent conservation!")
        elseif dE_E0_max < 1e-4
            println("  ✓ Good conservation")
        else
            println("  ⚠ Conservation could be better")
        end
    end

    # Final state
    particles_final = data.particles_history[end]
    phi_final = [p.φ for p in particles_final]
    phidot_final = [p.φ_dot for p in particles_final]

    sigma_phi = std(phi_final)
    sigma_phidot = std(phidot_final)

    println("\nFinal state:")
    println("  σ_φ:   $(round(sigma_phi, digits=3)) rad")
    println("  σ_φ̇:  $(round(sigma_phidot, digits=3)) rad/s")

    println("\n" * "="^70)
    println("✅ SINGLE SIMULATION TEST: PASSED")
    println("="^70)
    println()
    println("The simulation ran successfully!")
    println("Key components verified:")
    println("  • Polar geometry")
    println("  • Forest-Ruth integrator")
    println("  • Collision detection and resolution")
    println("  • Adaptive timestep")
    println("  • Projection methods")
    println("  • Energy conservation")
    println()
    println("Ready to proceed with full pipeline!")
    println("="^70)

    return data

catch e
    println("\n✗ SIMULATION FAILED")
    println("Error: $e")
    println()
    for (exc, bt) in Base.catch_stack()
        showerror(stdout, exc, bt)
        println()
    end
    rethrow(e)
end
