#!/usr/bin/env julia
# Generate parameter matrix for finite-size scaling campaign
# Varies: N (particles), e (eccentricity), with uniform ICs

using DataFrames
using CSV
using Printf

println("="^80)
println("FINITE-SIZE SCALING CAMPAIGN: Parameter Matrix Generator")
println("="^80)
println()

# ============================================================================
# Campaign Parameters
# ============================================================================

# Particle numbers to test
N_values = [40, 60, 80, 100, 120]

# Eccentricities (same as previous campaign for comparison)
e_values = [0.0, 0.3, 0.5, 0.7, 0.8, 0.9, 0.95, 0.98, 0.99]

# Fixed parameters
a = 2.0  # Semi-major axis
b = 1.0  # Semi-minor axis
E_per_N = 0.32  # Energy per particle
radius = 0.05  # Particle radius (fraction of b)

# Temporal parameters (optimized based on t_steady-state ~ 60)
t_max = 120.0  # Run for 2× relaxation time
save_interval = 0.5  # Save every 0.5 time units → 240 snapshots

# Statistical ensemble
n_realizations = 10  # 10 independent runs per (N,e)

# ============================================================================
# Generate Matrix
# ============================================================================

println("Campaign Configuration:")
println("  N values: ", N_values)
println("  e values: ", e_values)
println("  Realizations per (N,e): $n_realizations")
println("  Time: t_max = $t_max, save_interval = $save_interval")
println()

function generate_runs()
    runs = []
    run_id = 0

    for N in N_values
        for e in e_values
            for seed in 1:n_realizations
                run_id += 1
                push!(runs, (
                    run_id = run_id,
                    N = N,
                    e = e,
                    a = a,
                    b = b,
                    E_per_N = E_per_N,
                    radius = radius,
                    seed = seed,
                    t_max = t_max,
                    save_interval = save_interval,
                    method = "adaptive",
                    collision_method = "parallel_transport",
                    use_parallel = true
                ))
            end
        end
    end

    return DataFrame(runs)
end

df = generate_runs()

println("="^80)
println("PARAMETER MATRIX SUMMARY")
println("="^80)
println()

total_runs = nrow(df)
println("Total runs: $total_runs")
println()

# Runs per N
println("Distribution by N:")
for N in N_values
    n_runs = count(df.N .== N)
    @printf("  N = %3d: %3d runs\n", N, n_runs)
end
println()

# Runs per e
println("Distribution by e:")
for e in e_values
    n_runs = count(df.e .== e)
    @printf("  e = %.2f: %3d runs\n", e, n_runs)
end
println()

# Time estimates
println("="^80)
println("TIME ESTIMATES")
println("="^80)
println()

# Rough estimates based on N (empirical from N=80 campaign)
time_per_run = Dict(
    40 => 5,    # minutes
    60 => 10,
    80 => 15,
    100 => 25,
    120 => 35
)

# Calculate time estimates using functional approach
cpu_times = [count(df.N .== N) * time_per_run[N] for N in N_values]
for (N, cpu_time) in zip(N_values, cpu_times)
    n_runs_N = count(df.N .== N)
    @printf("  N = %3d: %3d runs × %2d min = %4d min (%.1f hours)\n",
            N, n_runs_N, time_per_run[N], cpu_time, cpu_time/60)
end

total_cpu_minutes = sum(cpu_times)
println()
println("Total CPU time: $(round(Int, total_cpu_minutes)) minutes = $(round(total_cpu_minutes/60, digits=1)) hours")
println()

# Parallelization
n_cores = 24
wall_time_hours = total_cpu_minutes / 60 / n_cores
println("With $n_cores cores in parallel:")
@printf("  Wall time: %.1f hours\n", wall_time_hours)
@printf("  Conservatively (with overhead): %.1f hours\n", wall_time_hours * 1.5)
println()

# Disk usage
println("="^80)
println("DISK USAGE ESTIMATES")
println("="^80)
println()

# HDF5 size depends on N (empirical)
size_per_run_MB = Dict(
    40 => 10,
    60 => 15,
    80 => 20,
    100 => 25,
    120 => 30
)

# Calculate disk usage using functional approach
disk_sizes = [count(df.N .== N) * size_per_run_MB[N] for N in N_values]
for (N, disk_MB) in zip(N_values, disk_sizes)
    n_runs_N = count(df.N .== N)
    @printf("  N = %3d: %3d runs × %2d MB = %5d MB (%.2f GB)\n",
            N, n_runs_N, size_per_run_MB[N], disk_MB, disk_MB/1024)
end

total_disk_MB = sum(disk_sizes)
println()
@printf("Total disk: %.0f MB = %.2f GB\n", total_disk_MB, total_disk_MB/1024)
@printf("Conservatively: %.1f GB\n", total_disk_MB/1024 * 1.2)
println()

# ============================================================================
# Save Matrix
# ============================================================================

output_file = "parameter_matrix_finite_size_scaling.csv"
CSV.write(output_file, df)

println("="^80)
println("MATRIX SAVED")
println("="^80)
println()
println("  ✅ $output_file")
println("  Rows: $total_runs")
println("  Columns: $(ncol(df))")
println()

# Preview
println("Preview (first 10 rows):")
println(first(df, 10))
println()

println("Preview (last 5 rows):")
println(last(df, 5))
println()

# Validation
println("="^80)
println("VALIDATION")
println("="^80)
println()

# Check unique run_ids
if length(unique(df.run_id)) == nrow(df)
    println("✅ All run_ids are unique")
else
    println("⚠️  WARNING: Duplicate run_ids found!")
end

# Check seeds are in valid range
if all(1 .<= df.seed .<= n_realizations)
    println("✅ All seeds in valid range [1, $n_realizations]")
else
    println("⚠️  WARNING: Some seeds out of range!")
end

# Check N values
if all(in(N_values), df.N)
    println("✅ All N values are valid")
else
    println("⚠️  WARNING: Invalid N values found!")
end

# Check e values
if all(in(e_values), df.e)
    println("✅ All e values are valid")
else
    println("⚠️  WARNING: Invalid e values found!")
end

println()
println("="^80)
println("READY TO LAUNCH")
println("="^80)
println()
println("Next steps:")
println("  1. Review parameter matrix: cat $output_file | head -20")
println("  2. Test with 3-5 runs first")
println("  3. Launch full campaign: ./launch_finite_size_scaling.sh")
println()
println("Expected completion time: $(round(wall_time_hours * 1.5, digits=1)) hours")
println("Expected disk usage: $(round(total_disk_MB/1024 * 1.2, digits=1)) GB")
