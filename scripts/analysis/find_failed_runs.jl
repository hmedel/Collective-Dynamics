#!/usr/bin/env julia

# Find runs that failed to complete (no summary.json)
using Printf

campaign_dir = "results/extended_campaign_20251123_161354"
run_dirs = filter(d -> startswith(d, "e"), readdir(campaign_dir))

failed_runs = String[]
completed_runs = String[]

for run_dir in run_dirs
    summary_path = joinpath(campaign_dir, run_dir, "summary.json")
    if isfile(summary_path)
        push!(completed_runs, run_dir)
    else
        push!(failed_runs, run_dir)
    end
end

println("=" ^ 60)
println("EXTENDED CAMPAIGN STATUS")
println("=" ^ 60)
println("Completed: $(length(completed_runs)) / $(length(run_dirs))")
println("Failed:    $(length(failed_runs))")
println()

# Group by eccentricity and N
println("Completed by condition:")
for e in [0.70, 0.80, 0.90]
    for N in [40, 60, 80]
        pattern = @sprintf("e%.2f_N%03d", e, N)
        completed = count(r -> startswith(r, pattern), completed_runs)
        total = count(r -> startswith(r, pattern), run_dirs)
        status = completed == total ? "✓" : (completed > 0 ? "⚠" : "✗")
        println("  e=$e N=$N: $completed/$total $status")
    end
end

println()
println("Failed runs:")
for r in sort(failed_runs)
    println("  $r")
end

# Write failed runs to file for relaunch
open("failed_runs.txt", "w") do f
    for r in sort(failed_runs)
        println(f, r)
    end
end
println()
println("Failed runs saved to failed_runs.txt")
