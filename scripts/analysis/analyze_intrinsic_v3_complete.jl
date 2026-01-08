#!/usr/bin/env julia
#=
Análisis Completo de Campaña Intrinsic v3
==========================================
Estudia:
1. Clustering como función de e, N, t
2. Evolución temporal y dinámica de nucleación
3. Espacio fase y correlaciones espaciales
4. Finite-size scaling
5. Exponentes críticos (transición fuera de equilibrio)
6. Factores de forma y función de estructura
=#

using HDF5
using Statistics
using LinearAlgebra
using Printf
using DelimitedFiles

# ============================================================================
# CONFIGURACIÓN
# ============================================================================

const CAMPAIGN_DIR = "results/intrinsic_v3_campaign_20251126_110434"
const OUTPUT_DIR = "results/analysis_intrinsic_v3"

# Crear directorio de salida
mkpath(OUTPUT_DIR)

# ============================================================================
# FUNCIONES DE ANÁLISIS
# ============================================================================

"""
Calcula el ratio de clustering R = σ(ρ)/⟨ρ⟩ para distribución angular
R ≈ 1: uniforme (gas), R >> 1: clustering fuerte
"""
function clustering_ratio(φ::Vector{Float64}; n_bins::Int=20)
    bins = range(0, 2π, length=n_bins+1)
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
Parámetro de orden orientacional Ψ = |⟨e^(i·φ)⟩|
"""
function orientational_order(φ::Vector{Float64})
    N = length(φ)
    return abs(sum(exp.(im .* φ))) / N
end

"""
Función de correlación de pares g(Δφ)
"""
function pair_correlation(φ::Vector{Float64}; n_bins::Int=50)
    N = length(φ)
    L = 2π
    Δφ_all = Float64[]
    for i in 1:N
        for j in i+1:N
            Δφ = abs(φ[i] - φ[j])
            Δφ = min(Δφ, L - Δφ)
            push!(Δφ_all, Δφ)
        end
    end
    bins = range(0, π, length=n_bins+1)
    bin_width = π / n_bins
    g_r = zeros(n_bins)
    for Δφ in Δφ_all
        idx = min(n_bins, max(1, Int(ceil(Δφ / bin_width))))
        g_r[idx] += 1
    end
    n_pairs = N * (N - 1) / 2
    for i in 1:n_bins
        expected = n_pairs * bin_width / π
        g_r[i] = expected > 0 ? g_r[i] / expected : 0.0
    end
    r_bins = collect(range(bin_width/2, π - bin_width/2, length=n_bins))
    return r_bins, g_r
end

"""
Factor de estructura S(k)
"""
function structure_factor(φ::Vector{Float64}; k_max::Int=20)
    N = length(φ)
    S_k = zeros(k_max)
    for k in 1:k_max
        sum_exp = sum(exp.(im * k .* φ))
        S_k[k] = abs2(sum_exp) / N
    end
    return collect(1:k_max), S_k
end

"""
Identifica clusters basándose en distancia angular
"""
function identify_clusters(φ::Vector{Float64}; threshold::Float64=0.3)
    N = length(φ)
    φ_sorted = sort(mod.(φ, 2π))
    gaps = diff(φ_sorted)
    push!(gaps, 2π - φ_sorted[end] + φ_sorted[1])
    clusters = Vector{Int}[]
    current_cluster = [1]
    for i in 1:N-1
        if gaps[i] < threshold
            push!(current_cluster, i+1)
        else
            push!(clusters, current_cluster)
            current_cluster = [i+1]
        end
    end
    if gaps[end] < threshold && length(clusters) > 0
        append!(clusters[1], current_cluster)
    else
        push!(clusters, current_cluster)
    end
    return clusters
end

"""
Carga un archivo HDF5
"""
function load_simulation(filepath::String)
    h5open(filepath, "r") do f
        time = read(f["trajectories/time"])
        φ = read(f["trajectories/phi"])
        φ_dot = read(f["trajectories/phidot"])
        energy = read(f["conservation/total_energy"])
        dE_E0 = read(f["conservation/dE_E0"])
        return (time=time, φ=φ, φ_dot=φ_dot, energy=energy, dE_E0=dE_E0)
    end
end

"""
Extrae parámetros del nombre del directorio
"""
function parse_dirname(dirname::String)
    m = match(r"e(\d+\.\d+)_N(\d+)_seed(\d+)", dirname)
    if m !== nothing
        return (e=parse(Float64, m.captures[1]), N=parse(Int, m.captures[2]), seed=parse(Int, m.captures[3]))
    end
    return nothing
end

# ============================================================================
# ANÁLISIS PRINCIPAL
# ============================================================================

function main()
    println("="^70)
    println("ANÁLISIS COMPLETO - CAMPAÑA INTRINSIC v3")
    println("="^70)
    println()

    # Encontrar todos los archivos HDF5
    h5_files = String[]
    for (root, dirs, files) in walkdir(CAMPAIGN_DIR)
        for f in files
            if endswith(f, ".h5")
                push!(h5_files, joinpath(root, f))
            end
        end
    end
    println("Archivos encontrados: $(length(h5_files))")
    println()

    # Estructuras para almacenar resultados
    results = Dict{Tuple{Float64, Int}, Vector{Dict}}()

    # Procesar cada archivo
    println("Cargando y analizando simulaciones...")
    for (i, filepath) in enumerate(h5_files)
        parent_dir = basename(dirname(filepath))
        params = parse_dirname(parent_dir)
        if params === nothing
            continue
        end

        try
            data = load_simulation(filepath)
            n_times = length(data.time)
            N = size(data.φ, 2)

            R_t = zeros(n_times)
            Ψ_t = zeros(n_times)
            n_clusters_t = zeros(Int, n_times)
            max_cluster_t = zeros(Int, n_times)

            for t_idx in 1:n_times
                φ_t = vec(data.φ[t_idx, :])
                R_t[t_idx] = clustering_ratio(φ_t)
                Ψ_t[t_idx] = orientational_order(φ_t)
                clusters = identify_clusters(φ_t)
                n_clusters_t[t_idx] = length(clusters)
                max_cluster_t[t_idx] = isempty(clusters) ? 0 : maximum(length.(clusters))
            end

            φ_final = vec(data.φ[end, :])
            k_vals, S_k = structure_factor(φ_final)
            r_bins, g_r = pair_correlation(φ_final)

            key = (params.e, params.N)
            if !haskey(results, key)
                results[key] = Vector{Dict}()
            end

            push!(results[key], Dict(
                :seed => params.seed, :time => data.time,
                :R => R_t, :Ψ => Ψ_t,
                :n_clusters => n_clusters_t, :max_cluster => max_cluster_t,
                :R_final => R_t[end], :Ψ_final => Ψ_t[end],
                :dE_E0_max => maximum(abs.(data.dE_E0)),
                :S_k => S_k, :k_vals => k_vals,
                :g_r => g_r, :r_bins => r_bins,
                :φ_final => φ_final
            ))

            if i % 20 == 0
                println("  Procesados: $i / $(length(h5_files))")
            end
        catch ex
            println("  ⚠ Error: $filepath - $ex")
        end
    end

    println("\nProcesadas $(sum(length(v) for v in values(results))) simulaciones.")
    println()

    # ========================================================================
    # REPORTE 1: ESTADÍSTICAS POR CONDICIÓN
    # ========================================================================
    println("="^70)
    println("1. ESTADÍSTICAS DE CLUSTERING POR CONDICIÓN")
    println("="^70)
    println()

    keys_sorted = sort(collect(keys(results)))
    println(@sprintf("%-6s %-4s %-4s %-14s %-14s %-12s", "e", "N", "n", "R_mean±std", "Ψ_mean±std", "max_dE/E0"))
    println("-"^70)

    summary_data = []
    for (e, N) in keys_sorted
        runs = results[(e, N)]
        n_runs = length(runs)
        R_finals = [r[:R_final] for r in runs]
        Ψ_finals = [r[:Ψ_final] for r in runs]
        dE_maxs = [r[:dE_E0_max] for r in runs]

        R_mean, R_std = mean(R_finals), std(R_finals)
        Ψ_mean, Ψ_std = mean(Ψ_finals), std(Ψ_finals)
        dE_max = maximum(dE_maxs)

        println(@sprintf("%-6.2f %-4d %-4d %6.2f±%-6.2f %6.3f±%-6.3f %-12.2e",
                        e, N, n_runs, R_mean, R_std, Ψ_mean, Ψ_std, dE_max))
        push!(summary_data, (e=e, N=N, n=n_runs, R_mean=R_mean, R_std=R_std, Ψ_mean=Ψ_mean, Ψ_std=Ψ_std, dE_max=dE_max))
    end

    # Guardar CSV
    open(joinpath(OUTPUT_DIR, "summary_by_condition.csv"), "w") do io
        println(io, "e,N,n_runs,R_mean,R_std,Psi_mean,Psi_std,dE_E0_max")
        for s in summary_data
            println(io, "$(s.e),$(s.N),$(s.n),$(s.R_mean),$(s.R_std),$(s.Ψ_mean),$(s.Ψ_std),$(s.dE_max)")
        end
    end

    # ========================================================================
    # REPORTE 2: R vs e (TRANSICIÓN)
    # ========================================================================
    println()
    println("="^70)
    println("2. DEPENDENCIA R(e) - EVIDENCIA DE TRANSICIÓN")
    println("="^70)
    println()

    e_values = sort(unique([k[1] for k in keys_sorted]))
    N_values = sort(unique([k[2] for k in keys_sorted]))

    for N in N_values
        println("N = $N:")
        e_list, R_list, R_err_list = Float64[], Float64[], Float64[]
        for e in e_values
            key = (e, N)
            if haskey(results, key) && !isempty(results[key])
                R_finals = [r[:R_final] for r in results[key]]
                push!(e_list, e)
                push!(R_list, mean(R_finals))
                push!(R_err_list, std(R_finals))
            end
        end
        for i in eachindex(e_list)
            println(@sprintf("  e=%.2f: R = %.3f ± %.3f", e_list[i], R_list[i], R_err_list[i]))
        end
        if length(e_list) >= 2
            println("  --- Gradiente dR/de ---")
            for i in 2:length(e_list)
                dR_de = (R_list[i] - R_list[i-1]) / (e_list[i] - e_list[i-1])
                println(@sprintf("    %.2f→%.2f: dR/de = %.2f", e_list[i-1], e_list[i], dR_de))
            end
        end
        println()
    end

    # ========================================================================
    # REPORTE 3: R vs N (FINITE-SIZE SCALING)
    # ========================================================================
    println("="^70)
    println("3. FINITE-SIZE SCALING: R(N)")
    println("="^70)
    println()

    print(@sprintf("%-6s", "e"))
    for N in N_values
        print(@sprintf(" N=%-5d", N))
    end
    println()
    println("-"^50)

    for e in e_values
        print(@sprintf("%-6.2f", e))
        for N in N_values
            key = (e, N)
            if haskey(results, key) && !isempty(results[key])
                R_mean = mean([r[:R_final] for r in results[key]])
                print(@sprintf(" %6.2f ", R_mean))
            else
                print("   --   ")
            end
        end
        println()
    end

    # ========================================================================
    # REPORTE 4: EVOLUCIÓN TEMPORAL
    # ========================================================================
    println()
    println("="^70)
    println("4. EVOLUCIÓN TEMPORAL - DINÁMICA DE CLUSTERING")
    println("="^70)
    println()

    for (e, N) in keys_sorted
        runs = results[(e, N)]
        if isempty(runs) continue end

        time_ref = runs[1][:time]
        n_times = length(time_ref)
        R_matrix = hcat([r[:R] for r in runs]...)
        R_mean = vec(mean(R_matrix, dims=2))

        # Tiempos característicos
        R_init = R_mean[1]
        R_final = R_mean[end]
        R_half = (R_init + R_final) / 2

        # Buscar tiempo de saturación (90% del valor final)
        R_90 = R_init + 0.9 * (R_final - R_init)
        t_90_idx = findfirst(x -> x >= R_90, R_mean)
        t_90 = t_90_idx !== nothing ? time_ref[t_90_idx] : NaN

        println(@sprintf("e=%.2f, N=%d: R(0)=%.2f → R(100)=%.2f, t_90%%=%.1f",
                        e, N, R_init, R_final, t_90))

        # Guardar evolución temporal
        filename = @sprintf("temporal_e%.2f_N%03d.csv", e, N)
        R_std = vec(std(R_matrix, dims=2))
        open(joinpath(OUTPUT_DIR, filename), "w") do io
            println(io, "time,R_mean,R_std")
            for t_idx in 1:n_times
                println(io, "$(time_ref[t_idx]),$(R_mean[t_idx]),$(R_std[t_idx])")
            end
        end
    end

    # ========================================================================
    # REPORTE 5: FACTOR DE ESTRUCTURA
    # ========================================================================
    println()
    println("="^70)
    println("5. FACTOR DE ESTRUCTURA S(k) - LONGITUDES CARACTERÍSTICAS")
    println("="^70)
    println()

    for (e, N) in keys_sorted
        runs = results[(e, N)]
        if isempty(runs) continue end

        k_vals = runs[1][:k_vals]
        S_k_matrix = hcat([r[:S_k] for r in runs]...)
        S_k_mean = vec(mean(S_k_matrix, dims=2))

        k_peak = k_vals[argmax(S_k_mean)]
        S_peak = maximum(S_k_mean)
        λ_char = 2π / k_peak  # Longitud característica

        println(@sprintf("e=%.2f, N=%d: k*=%d (λ=%.2f), S(k*)=%.1f",
                        e, N, k_peak, λ_char, S_peak))

        filename = @sprintf("Sk_e%.2f_N%03d.csv", e, N)
        open(joinpath(OUTPUT_DIR, filename), "w") do io
            println(io, "k,S_k_mean,S_k_std")
            S_k_std = vec(std(S_k_matrix, dims=2))
            for i in eachindex(k_vals)
                println(io, "$(k_vals[i]),$(S_k_mean[i]),$(S_k_std[i])")
            end
        end
    end

    # ========================================================================
    # REPORTE 6: CORRELACIÓN DE PARES
    # ========================================================================
    println()
    println("="^70)
    println("6. FUNCIÓN DE CORRELACIÓN g(Δφ)")
    println("="^70)
    println()

    for (e, N) in keys_sorted
        runs = results[(e, N)]
        if isempty(runs) continue end

        r_bins = runs[1][:r_bins]
        g_r_matrix = hcat([r[:g_r] for r in runs]...)
        g_r_mean = vec(mean(g_r_matrix, dims=2))

        g_contact = g_r_mean[1]
        g_far = mean(g_r_mean[end-5:end])

        println(@sprintf("e=%.2f, N=%d: g(0)=%.2f, g(π)=%.2f, ratio=%.2f",
                        e, N, g_contact, g_far, g_contact/max(g_far, 0.01)))

        filename = @sprintf("gr_e%.2f_N%03d.csv", e, N)
        open(joinpath(OUTPUT_DIR, filename), "w") do io
            println(io, "delta_phi,g_mean,g_std")
            g_r_std = vec(std(g_r_matrix, dims=2))
            for i in eachindex(r_bins)
                println(io, "$(r_bins[i]),$(g_r_mean[i]),$(g_r_std[i])")
            end
        end
    end

    # ========================================================================
    # REPORTE 7: ANÁLISIS DE EXPONENTES CRÍTICOS
    # ========================================================================
    println()
    println("="^70)
    println("7. ANÁLISIS DE EXPONENTES CRÍTICOS")
    println("="^70)
    println()

    # Hipótesis: R ~ (e - e_c)^β para e > e_c
    # Intentar ajuste para cada N

    println("Ajuste R ~ A*(e - e_c)^β:")
    println()

    for N in N_values
        e_data = Float64[]
        R_data = Float64[]

        for e in e_values
            key = (e, N)
            if haskey(results, key) && !isempty(results[key])
                push!(e_data, e)
                push!(R_data, mean([r[:R_final] for r in results[key]]))
            end
        end

        if length(e_data) >= 3
            # Estimar e_c como el punto donde R empieza a crecer significativamente
            # Usar diferencias finitas
            dR = diff(R_data) ./ diff(e_data)
            max_growth_idx = argmax(dR)

            # e_c aproximado
            e_c_approx = e_data[max_growth_idx]

            println(@sprintf("N=%d: Máximo crecimiento en e≈%.2f", N, e_c_approx))
            println(@sprintf("      dR/de = %.2f en e=%.2f→%.2f",
                           dR[max_growth_idx], e_data[max_growth_idx], e_data[max_growth_idx+1]))

            # Log-log plot para exponente
            if e_c_approx < e_data[end]
                idx_above = findall(e -> e > e_c_approx, e_data)
                if length(idx_above) >= 2
                    e_above = e_data[idx_above] .- e_c_approx
                    R_above = R_data[idx_above]
                    # R - R_c ~ (e - e_c)^β
                    R_c = R_data[max_growth_idx]
                    log_e = log.(e_above)
                    log_R = log.(R_above .- R_c .+ 0.01)

                    # Ajuste lineal simple
                    if length(log_e) >= 2
                        β_est = (log_R[end] - log_R[1]) / (log_e[end] - log_e[1])
                        println(@sprintf("      β estimado ≈ %.2f (log-log slope)", β_est))
                    end
                end
            end
        end
        println()
    end

    # ========================================================================
    # REPORTE 8: DISTRIBUCIÓN DE TAMAÑOS DE CLUSTER
    # ========================================================================
    println("="^70)
    println("8. DISTRIBUCIÓN DE TAMAÑOS DE CLUSTER")
    println("="^70)
    println()

    for (e, N) in keys_sorted
        runs = results[(e, N)]
        if isempty(runs) continue end

        all_sizes = Int[]
        for r in runs
            clusters = identify_clusters(r[:φ_final])
            append!(all_sizes, length.(clusters))
        end

        if !isempty(all_sizes)
            mean_size = mean(all_sizes)
            max_size = maximum(all_sizes)
            n_clusters_mean = mean([r[:n_clusters][end] for r in runs])

            println(@sprintf("e=%.2f, N=%d: ⟨n_cluster⟩=%.1f, ⟨size⟩=%.1f, max_size=%d",
                           e, N, n_clusters_mean, mean_size, max_size))
        end
    end

    # ========================================================================
    # GUARDAR RESUMEN FINAL
    # ========================================================================
    println()
    println("="^70)
    println("ARCHIVOS GENERADOS EN: $OUTPUT_DIR")
    println("="^70)

    # CSV maestro
    open(joinpath(OUTPUT_DIR, "all_results.csv"), "w") do io
        println(io, "e,N,seed,R_final,Psi_final,dE_E0_max,n_clusters,max_cluster")
        for (e, N) in keys_sorted
            for r in results[(e, N)]
                println(io, "$e,$N,$(r[:seed]),$(r[:R_final]),$(r[:Ψ_final]),$(r[:dE_E0_max]),$(r[:n_clusters][end]),$(r[:max_cluster][end])")
            end
        end
    end

    println("- summary_by_condition.csv")
    println("- all_results.csv")
    println("- temporal_e*_N*.csv")
    println("- Sk_e*_N*.csv")
    println("- gr_e*_N*.csv")
    println()
    println("="^70)
    println("ANÁLISIS COMPLETADO")
    println("="^70)

    return results
end

results = main()
