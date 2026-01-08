#!/usr/bin/env julia
# Análisis completo de la campaña de eccentricity scan

using HDF5
using Statistics
using DataFrames
using CSV
using Printf

campaign_dir = "results/campaign_eccentricity_scan_20251116_014451"

println("="^70)
println("ANÁLISIS CAMPAÑA COMPLETA: Eccentricity Scan")
println("="^70)
println()

# Funciones de análisis
function clustering_ratio(phi_positions, bin_width=π/4)
    """
    Ratio de partículas en eje mayor vs eje menor
    Mayor eje: φ ≈ 0, π, 2π (curvatura alta)
    Menor eje: φ ≈ π/2, 3π/2 (curvatura baja)
    """
    n_mayor = count(φ -> (φ < bin_width || φ > 2π - bin_width ||
                          abs(φ - π) < bin_width), phi_positions)
    n_menor = count(φ -> abs(φ - π/2) < bin_width ||
                          abs(φ - 3π/2) < bin_width, phi_positions)
    return n_mayor / max(n_menor, 1)
end

function order_parameter(phi_positions)
    """
    Parámetro de orden tipo Kuramoto
    Ψ = |⟨exp(iφ)⟩|
    Ψ = 0: gas (distribución uniforme)
    Ψ = 1: cristal perfecto (todas en mismo φ)
    """
    mean_cos = mean(cos.(phi_positions))
    mean_sin = mean(sin.(phi_positions))
    return sqrt(mean_cos^2 + mean_sin^2)
end

# Analizar todos los HDF5
println("Leyendo archivos HDF5...")
results = []
n_files = 0

for file in sort(readdir(campaign_dir, join=true))
    !endswith(file, ".h5") && continue
    
    n_files += 1
    filename = basename(file)
    
    # Extraer parámetros del nombre de archivo
    m = match(r"e([\d\.]+)_N\d+_E[\d\.]+_seed(\d+)", filename)
    if m === nothing
        @warn "No se pudo parsear: $filename"
        continue
    end
    
    e = parse(Float64, m.captures[1])
    seed = parse(Int, m.captures[2])
    
    h5open(file, "r") do f
        # Leer estado final
        phi_final = read(f["trajectories"]["phi"])[:, end]
        
        # Métricas
        R_cluster = clustering_ratio(phi_final)
        Psi = order_parameter(phi_final)
        
        # Energía (si está disponible)
        if haskey(f, "conservation")
            energy = read(f["conservation"]["total_energy"])
            dE_rel = maximum(abs.(energy .- energy[1])) / energy[1]
        else
            dE_rel = NaN
        end
        
        push!(results, (e=e, seed=seed, R=R_cluster, Psi=Psi, 
                       dE_rel=dE_rel, file=filename))
    end
    
    # Progress indicator
    if n_files % 20 == 0
        print(".")
    end
end

println()
println("Total simulaciones analizadas: $(length(results))")
println()

# Crear DataFrame
df = DataFrame(results)

# Agrupar por eccentricidad
grouped = groupby(df, :e)
summary = combine(grouped,
    :R => mean => :R_mean,
    :R => std => :R_std,
    :Psi => mean => :Psi_mean,
    :Psi => std => :Psi_std,
    :dE_rel => mean => :dE_mean,
    :dE_rel => maximum => :dE_max,
    nrow => :n_samples
)

# Ordenar por eccentricidad
sort!(summary, :e)

# Mostrar resumen
println("RESUMEN POR ECCENTRICIDAD:")
println("-"^70)
@printf("%-6s | %-5s | %-12s | %-12s | %-12s\n", 
        "e", "N", "R (mean±std)", "Ψ (mean±std)", "ΔE/E₀ (max)")
println("-"^70)

for row in eachrow(summary)
    @printf("%.2f | %5d | %.2f ± %.2f | %.4f ± %.4f | %.2e\n",
            row.e, row.n_samples, row.R_mean, row.R_std,
            row.Psi_mean, row.Psi_std, row.dE_max)
end
println("="^70)

# Guardar resultados
CSV.write(joinpath(campaign_dir, "summary_by_eccentricity.csv"), summary)
CSV.write(joinpath(campaign_dir, "all_results.csv"), df)

println()
println("Archivos guardados:")
println("  - $(campaign_dir)/summary_by_eccentricity.csv")
println("  - $(campaign_dir)/all_results.csv")
println()

# Verificar tendencia
sorted_e = sort(unique(df.e))
R_by_e = [mean(df[df.e .== e, :R]) for e in sorted_e]

println("ANÁLISIS DE TENDENCIA:")
println("-"^70)

# Check monotonicity
is_monotonic = all(diff(R_by_e) .>= 0)

if is_monotonic
    println("✅ HIPÓTESIS CONFIRMADA: R aumenta monotónicamente con e")
    println()
    for (i, e_val) in enumerate(sorted_e)
        R_val = R_by_e[i]
        @printf("  e = %.2f → R = %.2f\n", e_val, R_val)
    end
else
    println("⚠️  WARNING: Tendencia no monotónica detectada")
    println()
    for (i, e_val) in enumerate(sorted_e)
        R_val = R_by_e[i]
        trend = i > 1 ? (R_val > R_by_e[i-1] ? "↑" : "↓") : " "
        @printf("  e = %.2f → R = %.2f %s\n", e_val, R_val, trend)
    end
end

println()
println("="^70)
println()

# Estadísticas de conservación
println("CONSERVACIÓN DE ENERGÍA:")
println("-"^70)

bad_conservation = filter(row -> row.dE_rel > 1e-4, df)
n_bad = nrow(bad_conservation)
total = nrow(df)

if n_bad == 0
    println("✅ EXCELENTE: Todas las simulaciones conservan energía")
    println("   ΔE/E₀ < 10⁻⁴ para todas las $(total) simulaciones")
else
    pct_bad = 100 * n_bad / total
    @printf("⚠️  %d/%d simulaciones (%.1f%%) con ΔE/E₀ > 10⁻⁴\n", 
            n_bad, total, pct_bad)
    
    if n_bad <= 10
        println("\nCasos problemáticos:")
        for row in eachrow(bad_conservation)
            @printf("  %s: ΔE/E₀ = %.2e\n", row.file, row.dE_rel)
        end
    end
end

println()
println("="^70)
