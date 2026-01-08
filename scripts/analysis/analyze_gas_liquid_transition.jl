#!/usr/bin/env julia
#=
Análisis de Transición Gas-Líquido
===================================
Compara todas las campañas disponibles para buscar evidencia de
transición de fase tipo gas→líquido en función de la excentricidad.

Indicadores de transición gas-líquido:
1. Compresibilidad isotérmica: χ = N(⟨ρ²⟩ - ⟨ρ⟩²)/⟨ρ⟩²
2. Función de correlación g(r) - pico a distancia característica
3. Factor de estructura S(k→0) - diverge en transición
4. Parámetro de orden: fracción en clusters vs gas
5. Coexistencia de fases (bimodalidad en distribución de densidad)
=#

using HDF5
using Statistics
using LinearAlgebra
using Printf

# ============================================================================
# FUNCIONES DE ANÁLISIS TERMODINÁMICO
# ============================================================================

"""
Compresibilidad isotérmica normalizada
χ = N * Var(ρ) / ⟨ρ⟩² = N * (⟨n²⟩ - ⟨n⟩²) / ⟨n⟩²
donde n es el número de partículas por bin
"""
function compressibility(φ::Vector{Float64}; n_bins::Int=20)
    N = length(φ)
    counts = zeros(n_bins)
    for angle in φ
        idx = min(n_bins, max(1, Int(ceil(mod(angle, 2π) / (2π/n_bins)))))
        counts[idx] += 1
    end
    mean_n = mean(counts)
    var_n = var(counts)
    return mean_n > 0 ? N * var_n / mean_n^2 : 0.0
end

"""
Factor de estructura S(k) con énfasis en k→0
S(0) ~ χ_T (compresibilidad)
"""
function structure_factor_full(φ::Vector{Float64}; k_max::Int=30)
    N = length(φ)
    S_k = zeros(k_max)
    for k in 1:k_max
        sum_cos = sum(cos.(k .* φ))
        sum_sin = sum(sin.(k .* φ))
        S_k[k] = (sum_cos^2 + sum_sin^2) / N
    end
    return S_k
end

"""
Función de correlación de pares con mejor resolución
"""
function pair_correlation_detailed(φ::Vector{Float64}; n_bins::Int=100)
    N = length(φ)
    L = 2π
    g_r = zeros(n_bins)
    bin_width = π / n_bins

    for i in 1:N
        for j in i+1:N
            Δφ = abs(φ[i] - φ[j])
            Δφ = min(Δφ, L - Δφ)
            idx = min(n_bins, max(1, Int(ceil(Δφ / bin_width))))
            g_r[idx] += 2  # Contar ambas direcciones
        end
    end

    # Normalizar
    ρ_avg = N / L
    for i in 1:n_bins
        r = (i - 0.5) * bin_width
        # En 1D periódico, el volumen del shell es simplemente bin_width
        # pero hay que considerar que hay 2 direcciones
        shell_volume = 2 * bin_width
        ideal_count = N * ρ_avg * shell_volume / 2
        g_r[i] = ideal_count > 0 ? g_r[i] / (N * ideal_count / N) : 0.0
    end

    r_bins = [(i - 0.5) * bin_width for i in 1:n_bins]
    return r_bins, g_r
end

"""
Detecta bimodalidad en la distribución de densidad local
(indicador de coexistencia gas-líquido)
"""
function density_bimodality(φ::Vector{Float64}; n_bins::Int=20, n_density_bins::Int=15)
    N = length(φ)

    # Calcular densidad local en cada bin angular
    counts = zeros(n_bins)
    for angle in φ
        idx = min(n_bins, max(1, Int(ceil(mod(angle, 2π) / (2π/n_bins)))))
        counts[idx] += 1
    end

    # Histograma de densidades
    if maximum(counts) == minimum(counts)
        return 0.0, counts
    end

    # Normalizar a densidad
    densities = counts ./ (2π/n_bins)

    # Calcular bimodalidad usando coeficiente de Sarle
    n = length(densities)
    μ = mean(densities)
    σ = std(densities)

    if σ < 1e-10
        return 0.0, densities
    end

    # Skewness y kurtosis
    skew = mean(((densities .- μ) ./ σ).^3)
    kurt = mean(((densities .- μ) ./ σ).^4)

    # Coeficiente de bimodalidad: BC = (skew² + 1) / kurt
    # BC > 5/9 ≈ 0.555 sugiere bimodalidad
    BC = (skew^2 + 1) / kurt

    return BC, densities
end

"""
Fracción de partículas en fase "líquida" (clusters densos)
"""
function liquid_fraction(φ::Vector{Float64}; density_threshold::Float64=1.5)
    N = length(φ)
    n_bins = 20
    bin_width = 2π / n_bins

    counts = zeros(n_bins)
    for angle in φ
        idx = min(n_bins, max(1, Int(ceil(mod(angle, 2π) / bin_width))))
        counts[idx] += 1
    end

    # Densidad promedio
    ρ_avg = N / n_bins

    # Contar partículas en bins "densos"
    n_liquid = 0
    for i in 1:n_bins
        if counts[i] > density_threshold * ρ_avg
            n_liquid += counts[i]
        end
    end

    return n_liquid / N
end

"""
Clustering ratio mejorado
"""
function clustering_ratio(φ::Vector{Float64}; n_bins::Int=20)
    counts = zeros(n_bins)
    for angle in φ
        idx = min(n_bins, max(1, Int(ceil(mod(angle, 2π) / (2π/n_bins)))))
        counts[idx] += 1
    end
    density = counts ./ (2π/n_bins)
    mean_ρ = mean(density)
    std_ρ = std(density)
    return mean_ρ > 0 ? std_ρ / mean_ρ : 0.0
end

"""
Parámetro de orden orientacional
"""
function orientational_order(φ::Vector{Float64})
    N = length(φ)
    return abs(sum(exp.(im .* φ))) / N
end

"""
Carga simulación
"""
function load_sim(filepath::String)
    h5open(filepath, "r") do f
        # Intentar diferentes estructuras de HDF5
        if haskey(f, "trajectories")
            time = read(f["trajectories/time"])
            φ = read(f["trajectories/phi"])
            return (time=time, φ=φ)
        elseif haskey(f, "phi")
            φ = read(f["phi"])
            time = haskey(f, "time") ? read(f["time"]) : collect(1:size(φ,1))
            return (time=time, φ=φ)
        else
            error("Estructura HDF5 no reconocida")
        end
    end
end

# ============================================================================
# RECOLECTAR DATOS DE TODAS LAS CAMPAÑAS
# ============================================================================

function collect_all_data()
    println("="^70)
    println("ANÁLISIS DE TRANSICIÓN GAS-LÍQUIDO")
    println("="^70)
    println()

    # Buscar todos los archivos HDF5 relevantes
    campaigns = [
        "results/intrinsic_v3_campaign_20251126_110434",
        "results/final_campaign_20251120_202723",
        "results/campaign_eccentricity_scan_20251116_014451",
        "results/extended_campaign_20251123_161354"
    ]

    all_results = Dict{Float64, Vector{Dict}}()  # e -> [results...]

    for campaign_dir in campaigns
        if !isdir(campaign_dir)
            continue
        end

        println("Procesando: $campaign_dir")

        for (root, dirs, files) in walkdir(campaign_dir)
            for f in files
                if !endswith(f, ".h5")
                    continue
                end

                filepath = joinpath(root, f)

                # Extraer excentricidad del path
                e_match = match(r"e(\d+\.?\d*)", root * "/" * f)
                if e_match === nothing
                    continue
                end

                e_str = e_match.captures[1]
                # Manejar formato e0.95 vs e0950
                if !contains(e_str, ".")
                    e = parse(Float64, e_str) / 1000
                else
                    e = parse(Float64, e_str)
                end

                try
                    data = load_sim(filepath)
                    φ_final = vec(data.φ[end, :])
                    N = length(φ_final)

                    # Calcular todas las métricas
                    R = clustering_ratio(φ_final)
                    Ψ = orientational_order(φ_final)
                    χ = compressibility(φ_final)
                    S_k = structure_factor_full(φ_final)
                    BC, _ = density_bimodality(φ_final)
                    f_liq = liquid_fraction(φ_final)

                    if !haskey(all_results, e)
                        all_results[e] = Vector{Dict}()
                    end

                    push!(all_results[e], Dict(
                        :N => N,
                        :R => R,
                        :Ψ => Ψ,
                        :χ => χ,
                        :S_k => S_k,
                        :S_0 => S_k[1],
                        :BC => BC,
                        :f_liq => f_liq,
                        :φ => φ_final
                    ))
                catch ex
                    # Silenciosamente ignorar archivos problemáticos
                end
            end
        end
    end

    return all_results
end

# ============================================================================
# ANÁLISIS PRINCIPAL
# ============================================================================

function main()
    all_results = collect_all_data()

    e_values = sort(collect(keys(all_results)))
    println("\nExcentricidades encontradas: ", e_values)
    println("Total de simulaciones: ", sum(length(v) for v in values(all_results)))
    println()

    # ========================================================================
    # TABLA RESUMEN: INDICADORES DE TRANSICIÓN
    # ========================================================================

    println("="^80)
    println("INDICADORES DE TRANSICIÓN GAS → LÍQUIDO")
    println("="^80)
    println()
    println(@sprintf("%-6s %-5s %-10s %-10s %-10s %-10s %-10s %-10s",
                    "e", "n", "R", "Ψ", "χ", "S(k=1)", "BC", "f_liq"))
    println("-"^80)

    summary = []

    for e in e_values
        runs = all_results[e]
        n = length(runs)

        R_mean = mean([r[:R] for r in runs])
        R_std = std([r[:R] for r in runs])
        Ψ_mean = mean([r[:Ψ] for r in runs])
        χ_mean = mean([r[:χ] for r in runs])
        S_0_mean = mean([r[:S_0] for r in runs])
        BC_mean = mean([r[:BC] for r in runs])
        f_liq_mean = mean([r[:f_liq] for r in runs])

        println(@sprintf("%-6.3f %-5d %5.2f±%-4.2f %-10.3f %-10.2f %-10.2f %-10.3f %-10.3f",
                        e, n, R_mean, R_std, Ψ_mean, χ_mean, S_0_mean, BC_mean, f_liq_mean))

        push!(summary, (e=e, n=n, R=R_mean, R_std=R_std, Ψ=Ψ_mean,
                       χ=χ_mean, S_0=S_0_mean, BC=BC_mean, f_liq=f_liq_mean))
    end

    # ========================================================================
    # ANÁLISIS DE TRANSICIÓN
    # ========================================================================

    println()
    println("="^80)
    println("ANÁLISIS DE TRANSICIÓN")
    println("="^80)
    println()

    # Buscar punto de inflexión en R(e)
    if length(summary) >= 3
        R_vals = [s.R for s in summary]
        e_vals = [s.e for s in summary]

        # Derivada numérica dR/de
        println("Gradiente dR/de:")
        max_gradient = 0.0
        e_transition = 0.0

        for i in 2:length(e_vals)
            dR_de = (R_vals[i] - R_vals[i-1]) / (e_vals[i] - e_vals[i-1])
            println(@sprintf("  e=%.3f→%.3f: dR/de = %.2f", e_vals[i-1], e_vals[i], dR_de))
            if dR_de > max_gradient
                max_gradient = dR_de
                e_transition = (e_vals[i] + e_vals[i-1]) / 2
            end
        end

        println()
        println(@sprintf("Máximo gradiente: dR/de = %.2f en e ≈ %.3f", max_gradient, e_transition))
    end

    # Buscar divergencia en compresibilidad
    println()
    println("Compresibilidad χ(e):")
    for s in summary
        bar = repeat("█", Int(round(min(s.χ, 50))))
        println(@sprintf("  e=%.3f: χ=%6.2f %s", s.e, s.χ, bar))
    end

    # Buscar bimodalidad
    println()
    println("Coeficiente de bimodalidad BC(e):")
    println("  (BC > 0.555 sugiere coexistencia gas-líquido)")
    for s in summary
        marker = s.BC > 0.555 ? " ← BIMODAL" : ""
        println(@sprintf("  e=%.3f: BC=%.3f%s", s.e, s.BC, marker))
    end

    # Fracción líquida
    println()
    println("Fracción en fase líquida f_liq(e):")
    for s in summary
        bar = repeat("█", Int(round(s.f_liq * 50)))
        println(@sprintf("  e=%.3f: f_liq=%.3f %s", s.e, s.f_liq, bar))
    end

    # ========================================================================
    # INTERPRETACIÓN FÍSICA
    # ========================================================================

    println()
    println("="^80)
    println("INTERPRETACIÓN FÍSICA")
    println("="^80)
    println()

    # Clasificar fases
    println("Clasificación de fases por excentricidad:")
    println()

    for s in summary
        phase = if s.R < 1.2 && s.f_liq < 0.3
            "GAS (uniforme)"
        elseif s.R > 2.0 && s.f_liq > 0.5
            "LÍQUIDO (clustering fuerte)"
        elseif s.BC > 0.555
            "COEXISTENCIA gas-líquido"
        elseif 1.2 <= s.R <= 2.0
            "FLUIDO (transición)"
        else
            "INDETERMINADO"
        end

        println(@sprintf("  e=%.3f: %s (R=%.2f, f_liq=%.2f, BC=%.3f)",
                        s.e, phase, s.R, s.f_liq, s.BC))
    end

    # ========================================================================
    # COMPARACIÓN CON TRANSICIÓN GAS-LÍQUIDO CLÁSICA
    # ========================================================================

    println()
    println("="^80)
    println("COMPARACIÓN CON TRANSICIÓN GAS-LÍQUIDO CLÁSICA")
    println("="^80)
    println()

    println("""
    En una transición gas-líquido clásica esperaríamos:

    1. ✓/✗ Discontinuidad en densidad (1er orden) o divergencia en χ (2do orden)
    2. ✓/✗ Coexistencia de fases (regiones densas y diluidas)
    3. ✓/✗ Pico en S(k) a k* correspondiente a distancia interpartícula
    4. ✓/✗ Histéresis (dependencia de historia)

    Observaciones en este sistema:
    """)

    # Verificar cada criterio
    χ_max = maximum([s.χ for s in summary])
    χ_min = minimum([s.χ for s in summary])
    has_χ_peak = χ_max / χ_min > 2

    has_bimodal = any(s.BC > 0.555 for s in summary)

    R_max = maximum([s.R for s in summary])
    R_min = minimum([s.R for s in summary])
    has_R_jump = R_max / R_min > 2

    println(@sprintf("    1. Pico en χ: χ_max/χ_min = %.2f %s",
                    χ_max/χ_min, has_χ_peak ? "✓" : "✗"))
    println(@sprintf("    2. Bimodalidad: %s", has_bimodal ? "✓ Detectada" : "✗ No detectada"))
    println(@sprintf("    3. Salto en R: R_max/R_min = %.2f %s",
                    R_max/R_min, has_R_jump ? "✓" : "✗"))

    # ========================================================================
    # GUARDAR DATOS
    # ========================================================================

    mkpath("results/analysis_gas_liquid")

    open("results/analysis_gas_liquid/summary.csv", "w") do io
        println(io, "e,n,R_mean,R_std,Psi,chi,S0,BC,f_liq")
        for s in summary
            println(io, "$(s.e),$(s.n),$(s.R),$(s.R_std),$(s.Ψ),$(s.χ),$(s.S_0),$(s.BC),$(s.f_liq)")
        end
    end

    println()
    println("Datos guardados en: results/analysis_gas_liquid/summary.csv")

    return summary, all_results
end

summary, all_results = main()
