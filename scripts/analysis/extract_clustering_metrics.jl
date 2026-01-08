#!/usr/bin/env julia
#
# extract_clustering_metrics.jl
#
# Extrae métricas de clustering R(t) y Ψ(t) de todos los runs
# de la campaña final para análisis de finite-size scaling
#

using HDF5
using Statistics
using DataFrames
using CSV
using Printf
using LinearAlgebra

"""
    calculate_cluster_radius(phi)

Calcula el radio efectivo del cluster basado en la dispersión angular.

Para partículas en un anillo con ángulos φᵢ, el "radio del cluster" R
se define como la distancia RMS al centro de masa angular.

Si las partículas están uniformemente distribuidas: R → R_max
Si las partículas están agrupadas: R → 0

Retorna R normalizado por el radio del anillo.
"""
function calculate_cluster_radius(phi::Vector{T}) where T
    N = length(phi)

    if N == 0
        return 0.0
    end

    # Convertir a coordenadas cartesianas en el círculo unitario
    x = cos.(phi)
    y = sin.(phi)

    # Centro de masa
    x_cm = mean(x)
    y_cm = mean(y)

    # Distancia RMS al centro de masa
    r_cm_sq = x_cm^2 + y_cm^2
    r_cm = sqrt(r_cm_sq)

    # Radio del cluster: dispersión alrededor del CM
    # Para distribución uniforme: R ≈ 1/√2 ≈ 0.707
    # Para cluster perfecto: R → 0
    R = sqrt(mean((x .- x_cm).^2 + (y .- y_cm).^2))

    return R
end

"""
    calculate_order_parameter(phi)

Calcula el parámetro de orden Ψ (Kuramoto order parameter).

Ψ = |⟨e^(iφ)⟩| = |1/N ∑ e^(iφⱼ)|

Propiedades:
- Ψ = 1: Sincronización perfecta (todas las partículas en el mismo ángulo)
- Ψ = 0: Distribución uniforme
- 0 < Ψ < 1: Clustering parcial

Ref: Kuramoto (1975), Strogatz (2000)
"""
function calculate_order_parameter(phi::Vector{T}) where T
    N = length(phi)

    if N == 0
        return 0.0
    end

    # Calcular ⟨e^(iφ)⟩
    z = mean(exp.(im .* phi))

    # |z| es el parámetro de orden
    Psi = abs(z)

    return Psi
end

"""
    calculate_angular_dispersion(phi)

Calcula la dispersión angular σ_φ (std).

Útil para detectar clustering: valores bajos indican agrupamiento fuerte.
"""
function calculate_angular_dispersion(phi::Vector{T}) where T
    # Para ángulos, usar dispersión circular
    # σ = √(-2 ln(|⟨e^(iφ)⟩|))

    N = length(phi)
    if N == 0
        return 0.0
    end

    z = mean(exp.(im .* phi))
    R_bar = abs(z)

    if R_bar ≈ 0.0
        return π  # Máxima dispersión
    elseif R_bar ≈ 1.0
        return 0.0  # Mínima dispersión
    else
        sigma = sqrt(-2 * log(R_bar))
        return sigma
    end
end

"""
    extract_clustering_timeseries(h5_file)

Extrae series temporales de métricas de clustering de un archivo HDF5.

Returns: (times, R_t, Psi_t, sigma_t)
"""
function extract_clustering_timeseries(h5_file::String)
    h5open(h5_file, "r") do file
        # Leer trayectorias
        times = read(file["trajectories/time"])
        phi = read(file["trajectories/phi"])  # [n_snapshots, N]

        n_snapshots, N = size(phi)

        # Arrays para métricas
        R_t = zeros(n_snapshots)
        Psi_t = zeros(n_snapshots)
        sigma_t = zeros(n_snapshots)

        # Calcular métricas en cada snapshot
        for i in 1:n_snapshots
            phi_snapshot = phi[i, :]

            R_t[i] = calculate_cluster_radius(phi_snapshot)
            Psi_t[i] = calculate_order_parameter(phi_snapshot)
            sigma_t[i] = calculate_angular_dispersion(phi_snapshot)
        end

        return times, R_t, Psi_t, sigma_t
    end
end

"""
    extract_asymptotic_clustering(h5_file; t_equilibrium=60.0)

Extrae métricas de clustering en el estado asintótico (promediadas después de equilibrio).

# Arguments
- `h5_file`: Ruta al archivo HDF5
- `t_equilibrium`: Tiempo después del cual se considera que el sistema ha equilibrado

# Returns
Named tuple con: (R_inf, Psi_inf, sigma_inf, t_eq_start, n_samples)
"""
function extract_asymptotic_clustering(h5_file::String; t_equilibrium=60.0)
    times, R_t, Psi_t, sigma_t = extract_clustering_timeseries(h5_file)

    # Encontrar índice donde t >= t_equilibrium
    idx_eq = findfirst(t -> t >= t_equilibrium, times)

    if isnothing(idx_eq)
        # No hay datos después de t_equilibrium, usar últimos 20%
        idx_eq = floor(Int, 0.8 * length(times))
    end

    # Promediar en el régimen asintótico
    R_inf = mean(R_t[idx_eq:end])
    Psi_inf = mean(Psi_t[idx_eq:end])
    sigma_inf = mean(sigma_t[idx_eq:end])

    R_inf_std = std(R_t[idx_eq:end])
    Psi_inf_std = std(Psi_t[idx_eq:end])
    sigma_inf_std = std(sigma_t[idx_eq:end])

    return (
        R_inf = R_inf,
        Psi_inf = Psi_inf,
        sigma_inf = sigma_inf,
        R_inf_std = R_inf_std,
        Psi_inf_std = Psi_inf_std,
        sigma_inf_std = sigma_inf_std,
        t_eq_start = times[idx_eq],
        n_samples = length(times) - idx_eq + 1
    )
end

"""
    extract_all_campaigns(campaign_dir; save_timeseries=false, t_equilibrium=60.0)

Extrae métricas de clustering de todos los runs en la campaña.

# Arguments
- `campaign_dir`: Directorio de la campaña
- `save_timeseries`: Si es true, guarda series temporales completas (archivos grandes)
- `t_equilibrium`: Tiempo para considerar estado asintótico

# Outputs
- campaign_clustering_asymptotic.csv: Métricas asintóticas por run
- campaign_clustering_timeseries/*.csv: Series temporales (si save_timeseries=true)
"""
function extract_all_campaigns(campaign_dir::String;
                                save_timeseries=false,
                                t_equilibrium=60.0)

    println("="^80)
    println("EXTRACCIÓN DE MÉTRICAS DE CLUSTERING")
    println("="^80)
    println("Campaign: ", campaign_dir)
    println("t_equilibrium: ", t_equilibrium)
    println("save_timeseries: ", save_timeseries)
    println()

    # Buscar todos los runs
    run_dirs = filter(readdir(campaign_dir, join=true)) do path
        isdir(path) && occursin(r"^e\d", basename(path))
    end

    println("Runs encontrados: ", length(run_dirs))
    println()

    # Arrays para métricas asintóticas
    results = []

    # Crear directorios de salida
    output_dir = joinpath(campaign_dir, "clustering_analysis")
    mkpath(output_dir)

    if save_timeseries
        ts_dir = joinpath(output_dir, "timeseries")
        mkpath(ts_dir)
    end

    # Procesar cada run
    println("Extrayendo métricas...")
    for (i, run_dir) in enumerate(run_dirs)
        h5_file = joinpath(run_dir, "trajectories.h5")

        if !isfile(h5_file)
            continue
        end

        run_name = basename(run_dir)

        # Parsear nombre: e{e}_N{N}_seed{seed}
        m = match(r"e(\d+\.\d+)_N(\d+)_seed(\d+)", run_name)
        if isnothing(m)
            @warn "Could not parse run name: $run_name"
            continue
        end

        e = parse(Float64, m.captures[1])
        N = parse(Int, m.captures[2])
        seed = parse(Int, m.captures[3])

        # Extraer métricas asintóticas
        asym = extract_asymptotic_clustering(h5_file; t_equilibrium=t_equilibrium)

        # Guardar en DataFrame
        push!(results, (
            run_name = run_name,
            N = N,
            e = e,
            seed = seed,
            R_inf = asym.R_inf,
            Psi_inf = asym.Psi_inf,
            sigma_inf = asym.sigma_inf,
            R_inf_std = asym.R_inf_std,
            Psi_inf_std = asym.Psi_inf_std,
            sigma_inf_std = asym.sigma_inf_std,
            t_eq_start = asym.t_eq_start,
            n_samples = asym.n_samples
        ))

        # Guardar series temporales si se requiere
        if save_timeseries
            times, R_t, Psi_t, sigma_t = extract_clustering_timeseries(h5_file)

            ts_df = DataFrame(
                time = times,
                R = R_t,
                Psi = Psi_t,
                sigma = sigma_t
            )

            ts_file = joinpath(ts_dir, "$(run_name)_timeseries.csv")
            CSV.write(ts_file, ts_df)
        end

        if i % 50 == 0
            print("\rProcesados: $i/$(length(run_dirs))")
        end
    end
    println("\rProcesados: $(length(run_dirs))/$(length(run_dirs))")
    println()

    # Convertir a DataFrame
    df = DataFrame(results)

    # Ordenar por N, e, seed
    sort!(df, [:N, :e, :seed])

    # Guardar métricas asintóticas
    asym_file = joinpath(output_dir, "campaign_clustering_asymptotic.csv")
    CSV.write(asym_file, df)
    println("✅ Métricas asintóticas guardadas: $asym_file")

    # Calcular estadísticas agrupadas por (N, e)
    grouped_stats = combine(groupby(df, [:N, :e])) do group
        (
            R_inf_mean = mean(group.R_inf),
            R_inf_std_mean = sqrt(mean(group.R_inf_std.^2)),  # Error propagado
            R_inf_sem = std(group.R_inf) / sqrt(nrow(group)),  # SEM entre seeds

            Psi_inf_mean = mean(group.Psi_inf),
            Psi_inf_std_mean = sqrt(mean(group.Psi_inf_std.^2)),
            Psi_inf_sem = std(group.Psi_inf) / sqrt(nrow(group)),

            sigma_inf_mean = mean(group.sigma_inf),
            sigma_inf_std_mean = sqrt(mean(group.sigma_inf_std.^2)),
            sigma_inf_sem = std(group.sigma_inf) / sqrt(nrow(group)),

            n_realizations = nrow(group)
        )
    end

    # Guardar estadísticas agrupadas
    grouped_file = joinpath(output_dir, "campaign_clustering_grouped.csv")
    CSV.write(grouped_file, grouped_stats)
    println("✅ Estadísticas agrupadas guardadas: $grouped_file")

    println()
    println("="^80)
    println("RESUMEN")
    println("="^80)
    println("Total runs procesados: ", nrow(df))
    println("Combinaciones (N, e): ", nrow(grouped_stats))
    println()

    # Mostrar tabla resumen
    println("Tabla resumen (N × e) - R_∞:")
    println("-"^80)

    N_values = sort(unique(df.N))
    e_values = sort(unique(df.e))

    @printf("%-8s", "N \\ e")
    for e in e_values
        @printf("%10.1f", e)
    end
    println()
    println("-"^80)

    for N in N_values
        @printf("%-8d", N)
        for e in e_values
            subset = filter(row -> row.N == N && row.e == e, grouped_stats)
            if nrow(subset) > 0
                R_mean = subset[1, :R_inf_mean]
                @printf("%10.4f", R_mean)
            else
                @printf("%10s", "-")
            end
        end
        println()
    end
    println()

    println("="^80)
    println("✅ EXTRACCIÓN COMPLETADA")
    println("="^80)

    return df, grouped_stats
end

# Main execution
if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) < 1
        println("Usage: julia extract_clustering_metrics.jl <campaign_dir> [--save-timeseries] [--t-eq=60.0]")
        println()
        println("Options:")
        println("  --save-timeseries    Save full time series for each run (large files)")
        println("  --t-eq=<time>        Equilibration time (default: 60.0)")
        exit(1)
    end

    campaign_dir = ARGS[1]

    if !isdir(campaign_dir)
        println("❌ Error: Campaign directory not found: $campaign_dir")
        exit(1)
    end

    # Parse options
    save_ts = any(arg -> arg == "--save-timeseries", ARGS)

    t_eq = 60.0
    for arg in ARGS
        if startswith(arg, "--t-eq=")
            t_eq = parse(Float64, split(arg, "=")[2])
        end
    end

    df, grouped = extract_all_campaigns(campaign_dir;
                                         save_timeseries=save_ts,
                                         t_equilibrium=t_eq)
end
