#!/usr/bin/env julia
"""
Generate relaunch commands for failed runs in extended campaign.
"""

using Printf

# Campaign parameters
campaign_dir = "results/extended_campaign_20251123_161354"
a = 2.0
max_time = 500.0
dt_max = 1e-5
dt_min = 1e-10
save_interval = 2.5

# Find failed runs (no summary.json)
run_dirs = filter(d -> startswith(d, "e"), readdir(campaign_dir))
failed_runs = String[]

for run_dir in run_dirs
    summary_path = joinpath(campaign_dir, run_dir, "summary.json")
    if !isfile(summary_path)
        push!(failed_runs, run_dir)
    end
end

println("Found $(length(failed_runs)) failed runs")

# Parse run info and generate commands
open("relaunch_commands.txt", "w") do f
    for (i, run_dir) in enumerate(sort(failed_runs))
        # Parse directory name: e0.70_N060_seed01
        parts = split(run_dir, "_")
        e_str = parts[1][2:end]  # "0.70"
        N_str = parts[2][2:end]  # "060"
        seed_str = parts[3][5:end]  # "01"

        e = parse(Float64, e_str)
        N = parse(Int, N_str)
        seed = parse(Int, seed_str)
        b = a * sqrt(1 - e^2)

        # Generate command
        cmd = @sprintf(
            "julia --project=. run_single_intrinsic_relaunch.jl %d %d %.2f %.1f %.16f %d %.1f %.0e %.0e %.1f %s",
            i, N, e, a, b, seed, max_time, dt_max, dt_min, save_interval, campaign_dir
        )

        println(f, cmd)
    end
end

println("Relaunch commands saved to relaunch_commands.txt")
println()
println("Summary by condition:")
for e in [0.70, 0.80, 0.90]
    for N in [40, 60, 80]
        pattern = @sprintf("e%.2f_N%03d", e, N)
        count_failed = count(r -> startswith(r, pattern), failed_runs)
        if count_failed > 0
            println("  e=$e N=$N: $count_failed runs to relaunch")
        end
    end
end
