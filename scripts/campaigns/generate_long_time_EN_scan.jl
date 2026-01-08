#!/usr/bin/env julia
"""
Generate parameter matrix for long-time E/N scan experiment.

Based on initial E/N scan results:
- Clustering rate was low (max 10%) with t_max=100s
- E/N ≈ 3.2 shows no clustering (upper limit)
- e = 0.87 shows most clustering

This follow-up experiment uses:
- Longer simulation time: t_max = 500s
- Focus on transition region: E/N = 0.1 to 1.6
- Multiple eccentricities: e = 0.5, 0.8, 0.9
- Fewer seeds (5) to reduce total runtime
"""

using Printf
using DataFrames
using CSV

# Output file
output_file = "config/matrices/parameter_matrix_long_time_EN_scan.csv"

# Fixed parameters
N = 40
phi_target = 0.10  # Lower packing fraction for faster simulations
t_max = 500.0      # 5x longer than previous

# Parameter ranges - focused on transition region
E_per_N_values = [0.1, 0.2, 0.4, 0.8, 1.6]  # 5 values
e_values = [0.5, 0.8, 0.9]                   # 3 eccentricities
n_seeds = 5                                   # 5 seeds per combination

# Total runs
total_runs = length(E_per_N_values) * length(e_values) * n_seeds
println("Designing long-time E/N scan experiment")
println("="^60)
println("Parameters:")
println("  E/N values: ", E_per_N_values)
println("  Eccentricities: ", e_values)
println("  Seeds per combination: ", n_seeds)
println("  t_max: ", t_max, "s (5x longer)")
println("  N: ", N)
println("  φ_target: ", phi_target)
println("  Total runs: ", total_runs)
println()

# Helper function for ellipse perimeter (Ramanujan)
function ellipse_perimeter(a, b)
    h = ((a - b) / (a + b))^2
    return π * (a + b) * (1 + 3h / (10 + sqrt(4 - 3h)))
end

# Helper function for intrinsic radius
function get_intrinsic_radius(N, e, phi_target)
    # Semi-axes with normalized area A=2
    A = 2.0
    b = sqrt(A * (1 - e^2) / π)
    a = e ≈ 0.0 ? 1.0 : A / (π * b)
    P = ellipse_perimeter(a, b)
    r = phi_target * P / (2 * N)
    return r, a, b
end

# Generate parameter matrix
rows = []
global run_id = 1

for E_per_N in E_per_N_values
    for e in e_values
        for seed in 1:n_seeds
            r, a, b = get_intrinsic_radius(N, e, phi_target)

            # Max speed from E/N
            # E/N ≈ 0.32 * v_max² for uniform distribution
            v_max = sqrt(E_per_N / 0.32)

            # Eccentricity label
            if e ≤ 0.3
                ecc_label = "Low"
            elseif e ≤ 0.6
                ecc_label = "Moderate"
            elseif e ≤ 0.85
                ecc_label = "High"
            else
                ecc_label = "Extreme"
            end

            push!(rows, (
                run_id = run_id,
                E_per_N = E_per_N,
                eccentricity = e,
                a = a,
                b = b,
                ecc_label = ecc_label,
                N = N,
                phi = phi_target,
                radius = r,
                v_max = v_max,
                t_max = t_max,
                seed = seed,
                design = "long_time_EN_scan",
                status = "pending"
            ))

            global run_id += 1
        end
    end
end

# Create DataFrame and save
df = DataFrame(rows)
CSV.write(output_file, df)

println("Generated $total_runs parameter combinations")
println("Saved to: $output_file")

# Estimate runtime
estimated_time_per_run = 30 * 60  # ~30 min per run with t_max=500s
n_parallel = 24
total_time_hours = (total_runs / n_parallel) * estimated_time_per_run / 3600
println()
println("Estimated runtime with $n_parallel parallel jobs: $(round(total_time_hours, digits=1)) hours")

# Summary table
println()
println("="^60)
println("EXPERIMENT DESIGN SUMMARY")
println("="^60)
println()
println("Cross-tabulation (runs per cell):")
print("         ")
for E in E_per_N_values
    @printf(" E=%.1f", E)
end
println()
for e in e_values
    @printf("e=%.1f:  ", e)
    for E in E_per_N_values
        @printf("   %d  ", n_seeds)
    end
    println()
end
println()
println("Total: $total_runs runs × $(t_max)s = $(total_runs * t_max / 3600) hours of simulated time")
