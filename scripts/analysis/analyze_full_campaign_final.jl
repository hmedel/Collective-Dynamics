#!/usr/bin/env julia
# Complete analysis of full campaign: 180 runs (9 eccentricities × 20 realizations)

using HDF5
using Statistics
using DataFrames
using CSV
using Printf

println("="^80)
println("ANÁLISIS COMPLETO: Eccentricity Scan Campaign (180 runs)")
println("="^80)
println()

campaign_dir = "results/campaign_eccentricity_scan_20251116_014451"

# Analysis functions
function clustering_ratio(phi_positions, bin_width=π/4)
    n_mayor = count(φ -> (φ < bin_width || φ > 2π - bin_width ||
                          abs(φ - π) < bin_width), phi_positions)
    n_menor = count(φ -> abs(φ - π/2) < bin_width ||
                          abs(φ - 3π/2) < bin_width, phi_positions)
    return n_mayor / max(n_menor, 1)
end

function order_parameter(phi_positions)
    mean_cos = mean(cos.(phi_positions))
    mean_sin = mean(sin.(phi_positions))
    return sqrt(mean_cos^2 + mean_sin^2)
end

# Collect all results
results = []

println("Leyendo archivos HDF5...")
file_count = 0

for file in sort(readdir(campaign_dir, join=true))
    !endswith(file, ".h5") && continue

    filename = basename(file)

    # Parse parameters from filename
    m = match(r"e([\d\.]+)_N(\d+)_E([\d\.]+)_seed(\d+)", filename)
    if m === nothing
        @warn "No se pudo parsear: $filename"
        continue
    end

    e = parse(Float64, m.captures[1])
    N = parse(Int, m.captures[2])
    E_per_N = parse(Float64, m.captures[3])
    seed = parse(Int, m.captures[4])

    try
        h5open(file, "r") do f
            # Read final state
            phi_final = read(f["trajectories"]["phi"])[:, end]

            # Compute metrics
            R_cluster = clustering_ratio(phi_final)
            Psi = order_parameter(phi_final)

            # Energy conservation
            if haskey(f, "conservation") && haskey(f["conservation"], "energy")
                energy = read(f["conservation"]["energy"])
                dE_rel = maximum(abs.(energy .- energy[1])) / abs(energy[1])
            else
                dE_rel = NaN
            end

            push!(results, (
                e = e,
                N = N,
                E_per_N = E_per_N,
                seed = seed,
                R = R_cluster,
                Psi = Psi,
                dE_rel = dE_rel,
                file = filename
            ))

            global file_count += 1
        end
    catch err
        @warn "Error leyendo $filename: $err"
    end
end

println("Total archivos procesados: $file_count")
println()

if file_count == 0
    println("❌ No se encontraron archivos HDF5 válidos")
    exit(1)
end

# Create DataFrame
df = DataFrame(results)

# Summary by eccentricity
grouped = groupby(df, :e)
summary = combine(grouped,
    :R => mean => :R_mean,
    :R => std => :R_std,
    :R => minimum => :R_min,
    :R => median => :R_median,
    :R => maximum => :R_max,
    :Psi => mean => :Psi_mean,
    :Psi => std => :Psi_std,
    :dE_rel => (x -> mean(skipmissing(x))) => :dE_mean,
    :dE_rel => (x -> maximum(skipmissing(x))) => :dE_max,
    nrow => :n_samples
)

sort!(summary, :e)

# Display summary
println("="^80)
println("RESUMEN POR ECCENTRICIDAD:")
println("="^80)
@printf("%-6s | %-5s | %-15s | %-15s | %-12s | %-12s\n",
        "e", "N", "R (mean±std)", "Ψ (mean±std)", "ΔE/E₀ (mean)", "ΔE/E₀ (max)")
println("-"^80)

for row in eachrow(summary)
    @printf("%.2f | %5d | %5.2f ± %4.2f | %6.4f ± %6.4f | %10.2e | %10.2e\n",
            row.e, row.n_samples,
            row.R_mean, row.R_std,
            row.Psi_mean, row.Psi_std,
            row.dE_mean, row.dE_max)
end
println("="^80)
println()

# Trend analysis
println("ANÁLISIS DE TENDENCIA:")
println("-"^80)

sorted_e = summary.e
R_means = summary.R_mean

# Compute gradients
println("\nGradiente dR/de:")
for i in 2:length(sorted_e)
    de = sorted_e[i] - sorted_e[i-1]
    dR = R_means[i] - R_means[i-1]
    gradient = dR / de

    @printf("  e=%.2f → %.2f:  dR/de = %6.2f  (ΔR = %+.2f)\n",
            sorted_e[i-1], sorted_e[i], gradient, dR)
end
println()

# Check monotonicity
if all(diff(R_means) .>= 0)
    println("✅ HIPÓTESIS CONFIRMADA: R(e) es monotónica creciente")
else
    println("⚠️  WARNING: Tendencia no monotónica detectada")
    non_mono = findall(diff(R_means) .< 0)
    for idx in non_mono
        println("   Decremento en: e=$(sorted_e[idx]) → $(sorted_e[idx+1])")
    end
end
println()

# Energy conservation check
println("CONSERVACIÓN DE ENERGÍA:")
println("-"^80)

n_excellent = count(df.dE_rel .< 1e-4)
n_good = count(1e-4 .<= df.dE_rel .< 1e-2)
n_poor = count(df.dE_rel .>= 1e-2)
n_total = file_count

@printf("  Excelente (ΔE/E₀ < 10⁻⁴): %3d / %3d  (%.1f%%)\n",
        n_excellent, n_total, 100*n_excellent/n_total)
@printf("  Aceptable (ΔE/E₀ < 10⁻²): %3d / %3d  (%.1f%%)\n",
        n_good, n_total, 100*n_good/n_total)
@printf("  Pobre     (ΔE/E₀ ≥ 10⁻²): %3d / %3d  (%.1f%%)\n",
        n_poor, n_total, 100*n_poor/n_total)
println()

if n_poor > 0
    println("⚠️  Runs con conservación pobre:")
    poor_runs = df[df.dE_rel .>= 1e-2, :]
    for row in eachrow(poor_runs)
        @printf("    %s: ΔE/E₀ = %.2e\n", row.file, row.dE_rel)
    end
    println()
end

# Phase transition analysis
println("ANÁLISIS DE TRANSICIÓN:")
println("-"^80)

# Check for crystallization (Psi > 0.3)
crystallized = combine(groupby(df, :e),
    :Psi => (x -> count(x .> 0.3)) => :n_crystallized,
    nrow => :n_total
)
crystallized.fraction = crystallized.n_crystallized ./ crystallized.n_total

println("\nFracción de runs con Ψ > 0.3 (cristalización):")
for row in eachrow(crystallized)
    pct = 100 * row.fraction
    marker = pct > 0 ? "  ← CRISTALIZACIÓN!" : ""
    @printf("  e=%.2f: %2d/%2d (%.0f%%)%s\n",
            row.e, row.n_crystallized, row.n_total, pct, marker)
end
println()

# Strong clustering threshold (R > 3)
strong_clustering = combine(groupby(df, :e),
    :R => (x -> count(x .> 3.0)) => :n_strong,
    nrow => :n_total
)
strong_clustering.fraction = strong_clustering.n_strong ./ strong_clustering.n_total

println("Fracción de runs con R > 3 (clustering fuerte):")
for row in eachrow(strong_clustering)
    pct = 100 * row.fraction
    marker = pct > 50 ? "  ← MAYORÍA" : ""
    @printf("  e=%.2f: %2d/%2d (%.0f%%)%s\n",
            row.e, row.n_strong, row.n_total, pct, marker)
end
println()

# Statistical significance of differences
println("INCREMENTOS ESTADÍSTICAMENTE SIGNIFICATIVOS:")
println("-"^80)

for i in 2:nrow(summary)
    e1, e2 = summary.e[i-1], summary.e[i]
    R1, R2 = summary.R_mean[i-1], summary.R_mean[i]
    σ1, σ2 = summary.R_std[i-1], summary.R_std[i]

    # Approximate t-statistic (assuming equal n=20)
    n = summary.n_samples[i]
    pooled_std = sqrt((σ1^2 + σ2^2) / 2)
    t_stat = abs(R2 - R1) / (pooled_std * sqrt(2/n))

    # Rough significance (t > 2 is ~95% confidence)
    sig = t_stat > 2.0 ? "***" : (t_stat > 1.0 ? "*" : "")

    @printf("  %.2f → %.2f:  ΔR = %+.2f ± %.2f   (t = %.2f) %s\n",
            e1, e2, R2-R1, pooled_std*sqrt(2/n), t_stat, sig)
end
println("\n  *** = estadísticamente significativo (p < 0.05)")
println("    * = tendencia (p < 0.15)")
println()

# Save results
println("="^80)
println("GUARDANDO RESULTADOS:")
println("="^80)

output_summary = joinpath(campaign_dir, "summary_by_eccentricity_FINAL.csv")
output_all = joinpath(campaign_dir, "all_results_FINAL.csv")

CSV.write(output_summary, summary)
CSV.write(output_all, df)

println("  ✅ $output_summary")
println("  ✅ $output_all")
println()

# Final verdict
println("="^80)
println("CONCLUSIONES:")
println("="^80)
println()

if all(diff(R_means) .>= 0) && n_excellent/n_total > 0.95
    println("  ✅ CAMPAÑA EXITOSA")
    println("     - Tendencia R(e) monotónica confirmada")
    println("     - Conservación energética excelente (>95%)")
    println("     - Datos listos para publicación")
else
    println("  ⚠️  REVISAR RESULTADOS")
    println("     - Verificar tendencias anómalas")
    println("     - Chequear conservación energética")
end
println()

# Highlight key findings
println("HALLAZGOS PRINCIPALES:")
println("-"^80)

e_max_idx = argmax(summary.R_mean)
e_max_R = summary.e[e_max_idx]
R_max = summary.R_mean[e_max_idx]

@printf("  • Clustering máximo: R = %.2f ± %.2f en e = %.2f\n",
        R_max, summary.R_std[e_max_idx], e_max_R)

R_increase = (R_max - summary.R_mean[1]) / summary.R_mean[1] * 100
@printf("  • Incremento total: %.0f%% (e=0 → e=%.2f)\n", R_increase, e_max_R)

max_gradient_idx = argmax([diff(R_means)./diff(sorted_e); 0.0])
if max_gradient_idx < length(sorted_e)
    @printf("  • Mayor aceleración: e = %.2f → %.2f\n",
            sorted_e[max_gradient_idx], sorted_e[max_gradient_idx+1])
end

n_cryst_total = sum(crystallized.n_crystallized)
if n_cryst_total > 0
    @printf("  • Cristalización detectada: %d/%d runs totales\n",
            n_cryst_total, n_total)
end

println()
println("="^80)
println("Análisis completado exitosamente")
println("="^80)
