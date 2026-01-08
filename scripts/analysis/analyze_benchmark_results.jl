#!/usr/bin/env julia
"""
analyze_benchmark_results.jl

Combina resultados de benchmarks secuenciales y paralelos,
calcula speedups y genera reporte detallado.
"""

using Pkg
Pkg.activate(".")

using CSV
using DataFrames
using Printf

# Leer resultados
seq_file = "results/benchmark_sequential_20251113_212912/benchmark_results.csv"
par_file = "results/benchmark_parallel_20251113_212959/benchmark_results.csv"

df_seq = CSV.read(seq_file, DataFrame)
df_par = CSV.read(par_file, DataFrame)

# Combinar
df = vcat(df_seq, df_par)

println("="^70)
println("ANÁLISIS DE BENCHMARK - CollectiveDynamics.jl")
println("="^70)
println("\nResultados Secuenciales (1 thread):")
println("-"^70)
for row in eachrow(df_seq)
    @printf("N=%-3d: Tiempo=%.2fs, Colisiones=%d, ΔE/E₀=%.2e\n",
            row.n_particles, row.elapsed, row.n_steps, row.energy_conservation)
end

println("\nResultados Paralelos (24 threads):")
println("-"^70)
for row in eachrow(df_par)
    @printf("N=%-3d: Tiempo=%.2fs, Colisiones=%d, ΔE/E₀=%.2e\n",
            row.n_particles, row.elapsed, row.n_steps, row.energy_conservation)
end

println("\n" * "="^70)
println("SPEEDUPS (24 threads)")
println("="^70)
println(@sprintf("%-10s %-12s %-12s %-10s %-15s",
                 "N", "Seq (s)", "Par (s)", "Speedup", "Eficiencia"))
println("-"^70)

speedups = []
for n in unique(df.n_particles)
    # Filter by N and mode (mode es String en el CSV)
    seq_rows = df[(df.n_particles .== n) .& (df.mode .== "sequential"), :]
    par_rows = df[(df.n_particles .== n) .& (df.mode .== "parallel"), :]

    if isempty(seq_rows) || isempty(par_rows)
        println("⚠️  Datos incompletos para N=$n")
        continue
    end

    seq_time = seq_rows[1, :elapsed]
    par_time = par_rows[1, :elapsed]
    speedup = seq_time / par_time
    efficiency = speedup / 24.0 * 100  # % de eficiencia paralela

    push!(speedups, (n=n, seq=seq_time, par=par_time, speedup=speedup, eff=efficiency))

    @printf("%-10d %-12.2f %-12.2f %-10.2fx %-15.1f%%\n",
            n, seq_time, par_time, speedup, efficiency)
end

println("="^70)

# Guardar análisis combinado
output_dir = "results/benchmark_analysis_combined"
mkpath(output_dir)

CSV.write("$output_dir/benchmark_combined.csv", df)
println("\n✅ Resultados combinados guardados en: $output_dir/benchmark_combined.csv")

# Guardar tabla de speedups
df_speedup = DataFrame(
    n_particles = [s.n for s in speedups],
    seq_time = [s.seq for s in speedups],
    par_time = [s.par for s in speedups],
    speedup = [s.speedup for s in speedups],
    efficiency_percent = [s.eff for s in speedups]
)

CSV.write("$output_dir/speedups.csv", df_speedup)
println("✅ Tabla de speedups guardada en: $output_dir/speedups.csv")

println("\n" * "="^70)
println("CONCLUSIONES")
println("="^70)
println("• N=50:  Speedup $(round(speedups[1].speedup, digits=2))x → Overhead dominante (esperado)")
println("• N=70:  Speedup $(round(speedups[2].speedup, digits=2))x → Paralelización efectiva")
println("• N=100: Speedup $(round(speedups[3].speedup, digits=2))x → Speedup excelente!")
println("\nParalelización CPU con 24 threads es ALTAMENTE EFECTIVA para N≥70.")
println("="^70)
