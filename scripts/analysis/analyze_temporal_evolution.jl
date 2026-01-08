#!/usr/bin/env julia
using HDF5
using Statistics
using DataFrames
using CSV
using CairoMakie
using Printf

"""
Análisis temporal detallado R(t) para determinar:
1. ¿Cómo evoluciona R(t) hacia estado final?
2. ¿Hay saturación o sigue creciendo?
3. ¿Qué t_max es necesario para equilibración?
4. ¿Diferencias entre runs con R alto vs bajo?
"""

campaign_dir = "results/campaign_eccentricity_scan_20251116_014451"

println("="^70)
println("ANÁLISIS TEMPORAL DETALLADO: R(t)")
println("="^70)
println()

function clustering_ratio(phi_positions, bin_width=π/4)
    n_mayor = count(φ -> (φ < bin_width || φ > 2π - bin_width ||
                          abs(φ - π) < bin_width), phi_positions)
    n_menor = count(φ -> abs(φ - π/2) < bin_width ||
                          abs(φ - 3π/2) < bin_width, phi_positions)
    return n_mayor / max(n_menor, 1)
end

function extract_R_trajectory(filename)
    """Extrae trayectoria completa R(t) de un archivo HDF5"""
    h5open(filename, "r") do f
        phi = read(f["trajectories"]["phi"])
        time = read(f["trajectories"]["time"])

        N_particles, N_frames = size(phi)

        # Calcular R(t) para cada frame
        R_t = [clustering_ratio(phi[:, i]) for i in 1:N_frames]

        return time, R_t
    end
end

# ==================== ANÁLISIS POR ECCENTRICIDAD ====================

results_summary = DataFrame(
    e = Float64[],
    seed = Int[],
    R_initial = Float64[],
    R_final = Float64[],
    R_mean = Float64[],
    R_trend = String[],  # "growing", "saturated", "fluctuating"
    growth_rate = Float64[],  # Slope in last 100s
    saturation_time = Float64[]  # When reaches 90% of final value
)

# Analizar solo e=0.5, 0.7, 0.9 (representativos)
eccentricities_to_analyze = [0.5, 0.7, 0.9]

for e_val in eccentricities_to_analyze
    println("\n" * "="^70)
    println("ECCENTRICIDAD: e = $e_val")
    println("="^70)
    println()

    e_str = @sprintf("e%.3f", e_val)
    files = filter(readdir(campaign_dir, join=true)) do f
        endswith(f, ".h5") && occursin("_$(e_str)_", f)
    end

    if isempty(files)
        println("  ⚠️  No hay archivos")
        continue
    end

    println("Procesando $(length(files)) runs...")

    # Extraer todas las trayectorias
    trajectories = []

    for (i, file) in enumerate(files)
        try
            # Extraer seed del filename
            m = match(r"seed(\d+)", basename(file))
            seed = m !== nothing ? parse(Int, m.captures[1]) : i

            time, R_t = extract_R_trajectory(file)

            # Análisis de tendencia
            R_initial = R_t[1]
            R_final = R_t[end]
            R_mean = mean(R_t)

            # Calcular slope en últimos 100s (o último cuarto)
            last_quarter_idx = div(3*length(R_t), 4)
            t_last = time[last_quarter_idx:end]
            R_last = R_t[last_quarter_idx:end]

            # Simple linear fit: slope ≈ ΔR/Δt
            growth_rate = (R_last[end] - R_last[1]) / (t_last[end] - t_last[1])

            # Clasificar tendencia
            if abs(growth_rate) < 0.001  # < 0.001/s
                trend = "saturated"
            elseif growth_rate > 0.001
                trend = "growing"
            else
                trend = "decreasing"
            end

            # Tiempo de saturación: cuando alcanza 90% del valor final
            target = 0.1 * R_initial + 0.9 * R_final
            saturation_idx = findfirst(R_t .>= target)
            saturation_time = saturation_idx !== nothing ? time[saturation_idx] : NaN

            push!(results_summary, (
                e = e_val,
                seed = seed,
                R_initial = R_initial,
                R_final = R_final,
                R_mean = R_mean,
                R_trend = trend,
                growth_rate = growth_rate,
                saturation_time = saturation_time
            ))

            push!(trajectories, (time=time, R=R_t, seed=seed, R_final=R_final))

        catch err
            @warn "Error en $(basename(file)): $err"
        end
    end

    if isempty(trajectories)
        println("  ⚠️  No se procesaron trayectorias")
        continue
    end

    # Estadísticas de tendencias
    trends = [r.R_trend for r in eachrow(results_summary[results_summary.e .== e_val, :])]
    n_growing = count(trends .== "growing")
    n_saturated = count(trends .== "saturated")
    n_decreasing = count(trends .== "decreasing")

    println("\n📈 TENDENCIAS (últimos 100s):")
    @printf("  Creciendo:    %2d/%d (%.1f%%) - slope > 0.001/s\n",
            n_growing, length(trends), 100*n_growing/length(trends))
    @printf("  Saturado:     %2d/%d (%.1f%%) - |slope| < 0.001/s\n",
            n_saturated, length(trends), 100*n_saturated/length(trends))
    @printf("  Decreciendo:  %2d/%d (%.1f%%) - slope < -0.001/s\n",
            n_decreasing, length(trends), 100*n_decreasing/length(trends))

    # Tasa de crecimiento promedio
    growth_rates = [r.growth_rate for r in eachrow(results_summary[results_summary.e .== e_val, :])]
    @printf("\n  Tasa de crecimiento promedio: %.4f ± %.4f /s\n",
            mean(growth_rates), std(growth_rates))

    # Tiempo de saturación
    sat_times = [r.saturation_time for r in eachrow(results_summary[results_summary.e .== e_val, :])
                 if !isnan(r.saturation_time)]
    if !isempty(sat_times)
        @printf("  Tiempo de saturación (90%%): %.1f ± %.1f s\n",
                mean(sat_times), std(sat_times))
    end

    # ==================== PLOT: R(t) para todos los runs ====================

    println("\nGenerando plot R(t)...")

    fig = Figure(size=(1200, 800), fontsize=14)
    ax = Axis(fig[1,1],
        xlabel = "Time (s)",
        ylabel = "Clustering Ratio R(t)",
        title = "Temporal Evolution of Clustering (e=$e_val, N=80)",
        xlabelsize = 18,
        ylabelsize = 18,
        titlesize = 20
    )

    # Plot todas las trayectorias con transparencia
    for traj in trajectories
        lines!(ax, traj.time, traj.R, alpha=0.3, color=:gray, linewidth=1)
    end

    # Calcular media y std en cada punto temporal
    # (interpolando a grid común)
    t_common = range(0, 200, length=200)
    R_matrix = zeros(length(trajectories), length(t_common))

    for (i, traj) in enumerate(trajectories)
        # Interpolación simple: nearest neighbor
        for (j, t) in enumerate(t_common)
            idx = argmin(abs.(traj.time .- t))
            R_matrix[i, j] = traj.R[idx]
        end
    end

    R_mean_t = [mean(R_matrix[:, j]) for j in 1:length(t_common)]
    R_std_t = [std(R_matrix[:, j]) for j in 1:length(t_common)]

    # Plot media con banda de confianza
    band!(ax, t_common, R_mean_t .- R_std_t, R_mean_t .+ R_std_t,
          color=(:blue, 0.2), label="Mean ± std")
    lines!(ax, t_common, R_mean_t, color=:blue, linewidth=3, label="Mean R(t)")

    # Línea horizontal en R_final promedio
    R_final_mean = mean([traj.R_final for traj in trajectories])
    hlines!(ax, [R_final_mean], linestyle=:dash, color=:red, linewidth=2,
            label="Mean R(t=200s) = $(round(R_final_mean, digits=2))")

    axislegend(ax, position=:rb, framevisible=true)

    save(joinpath(campaign_dir, "R_temporal_evolution_e$(e_val).png"), fig, px_per_unit=2)
    println("  ✓ Guardado: R_temporal_evolution_e$(e_val).png")

    # ==================== PLOT: Comparar R alto vs R bajo ====================

    println("Generando plot comparativo (R alto vs bajo)...")

    # Dividir en terciles
    R_finals = sort([traj.R_final for traj in trajectories])
    tercile_low = R_finals[div(length(R_finals), 3)]
    tercile_high = R_finals[div(2*length(R_finals), 3)]

    traj_low = filter(t -> t.R_final <= tercile_low, trajectories)
    traj_high = filter(t -> t.R_final >= tercile_high, trajectories)

    fig2 = Figure(size=(1200, 800), fontsize=14)
    ax2 = Axis(fig2[1,1],
        xlabel = "Time (s)",
        ylabel = "Clustering Ratio R(t)",
        title = "Low vs High R_final Trajectories (e=$e_val)",
        xlabelsize = 18,
        ylabelsize = 18,
        titlesize = 20
    )

    # Plot low R
    for traj in traj_low
        lines!(ax2, traj.time, traj.R, alpha=0.5, color=:blue, linewidth=1.5)
    end

    # Plot high R
    for traj in traj_high
        lines!(ax2, traj.time, traj.R, alpha=0.5, color=:red, linewidth=1.5)
    end

    # Dummy lines for legend
    lines!(ax2, [NaN], [NaN], color=:blue, linewidth=2,
           label="Low R (R < $(round(tercile_low, digits=2)))")
    lines!(ax2, [NaN], [NaN], color=:red, linewidth=2,
           label="High R (R > $(round(tercile_high, digits=2)))")

    axislegend(ax2, position=:rb, framevisible=true)

    save(joinpath(campaign_dir, "R_temporal_comparison_e$(e_val).png"), fig2, px_per_unit=2)
    println("  ✓ Guardado: R_temporal_comparison_e$(e_val).png")

    # ==================== ANÁLISIS: ¿Divergen temprano o tarde? ====================

    println("\n🔍 ANÁLISIS DE DIVERGENCIA:")

    # Calcular tiempo cuando trajectories divergen significativamente
    # (cuando std/mean > threshold)
    cv_t = [std(R_matrix[:, j]) / mean(R_matrix[:, j]) for j in 1:length(t_common)]

    # Encontrar primer momento donde CV > 20%
    divergence_idx = findfirst(cv_t .> 0.2)
    if divergence_idx !== nothing
        t_divergence = t_common[divergence_idx]
        @printf("  Tiempo de divergencia (CV > 20%%): %.1f s\n", t_divergence)
        @printf("  → Runs comienzan a diferenciarse en t ≈ %.0f s\n", t_divergence)
    else
        println("  → Runs similares durante todo el tiempo")
    end

    # Comparar velocidades de crecimiento
    slopes_low = [r.growth_rate for r in eachrow(results_summary)
                  if r.e == e_val && r.R_final <= tercile_low]
    slopes_high = [r.growth_rate for r in eachrow(results_summary)
                   if r.e == e_val && r.R_final >= tercile_high]

    if !isempty(slopes_low) && !isempty(slopes_high)
        @printf("\n  Tasa de crecimiento (últimos 100s):\n")
        @printf("    R bajo:  %.4f ± %.4f /s\n", mean(slopes_low), std(slopes_low))
        @printf("    R alto:  %.4f ± %.4f /s\n", mean(slopes_high), std(slopes_high))

        if mean(slopes_high) > mean(slopes_low) + 0.001
            println("    ⚠️  R alto SIGUE CRECIENDO más rápido → necesita más tiempo")
        elseif abs(mean(slopes_high)) < 0.001 && abs(mean(slopes_low)) < 0.001
            println("    ✓ Ambos grupos saturados")
        end
    end
end

# ==================== GUARDAR RESULTADOS ====================

CSV.write(joinpath(campaign_dir, "temporal_analysis_summary.csv"), results_summary)
println("\n✓ Guardado: temporal_analysis_summary.csv")

# ==================== RECOMENDACIONES FINALES ====================

println("\n" * "="^70)
println("RECOMENDACIONES BASADAS EN ANÁLISIS TEMPORAL")
println("="^70)
println()

for e_val in eccentricities_to_analyze
    subset = results_summary[results_summary.e .== e_val, :]

    if nrow(subset) == 0
        continue
    end

    println("e = $e_val:")

    # Porcentaje creciendo
    pct_growing = 100 * count(subset.R_trend .== "growing") / nrow(subset)

    # Tasa promedio
    avg_growth = mean(subset.growth_rate)

    if pct_growing > 50
        # Más de la mitad sigue creciendo
        # Estimar tiempo necesario para saturar
        # Asumiendo que crece hasta saturar a R_final + 50%
        current_R = mean(subset.R_final)
        target_R = current_R * 1.5  # Estimación conservadora
        time_needed = (target_R - current_R) / abs(avg_growth)

        @printf("  ⚠️  %.0f%% de runs SIGUEN CRECIENDO\n", pct_growing)
        @printf("  → Tasa actual: %.4f/s\n", avg_growth)
        @printf("  → Tiempo estimado para saturar: %.0f s adicionales\n", time_needed)
        @printf("  → RECOMENDACIÓN: t_max = %d s\n", ceil(Int, 200 + time_needed))
    elseif pct_growing > 20
        @printf("  ⚠️  %.0f%% de runs aún crecen\n", pct_growing)
        @printf("  → RECOMENDACIÓN: t_max = 500 s (2.5× actual)\n")
    else
        @printf("  ✓ Solo %.0f%% de runs creciendo\n", pct_growing)
        @printf("  → RECOMENDACIÓN: t_max = 200-300 s es adecuado\n")
    end

    println()
end

println("="^70)
println("RESUMEN GENERAL:")
println("="^70)
println()

# Análisis global
all_growing = count(results_summary.R_trend .== "growing")
total = nrow(results_summary)

@printf("Total runs analizados: %d\n", total)
@printf("Runs creciendo en últimos 100s: %d/%d (%.1f%%)\n\n",
        all_growing, total, 100*all_growing/total)

if all_growing / total > 0.5
    println("🚨 CONCLUSIÓN: Sistema NO equilibrado")
    println("   → Más de 50% de runs siguen creciendo")
    println("   → t_max = 200s es INSUFICIENTE")
    println()
    println("📋 ACCIÓN REQUERIDA:")
    println("   1. Lanzar Experimento A: 10 runs × 1000s (e=0.9)")
    println("   2. Analizar coalescencia de clusters vs tiempo")
    println("   3. Determinar t_max óptimo empíricamente")
elseif all_growing / total > 0.2
    println("⚠️  CONCLUSIÓN: Equilibración parcial")
    println("   → 20-50% de runs siguen evolucionando")
    println("   → t_max = 200s probablemente corto")
    println()
    println("📋 RECOMENDACIÓN:")
    println("   1. Probar t_max = 500s para e ≥ 0.7")
    println("   2. Verificar saturación en runs de prueba")
else
    println("✓ CONCLUSIÓN: Sistema razonablemente equilibrado")
    println("   → < 20% de runs creciendo")
    println("   → t_max = 200s es adecuado para e ≤ 0.5")
    println()
    println("📋 RECOMENDACIÓN:")
    println("   1. Mantener t_max = 200s para e ≤ 0.5")
    println("   2. Aumentar a t_max = 300-500s para e ≥ 0.7")
end

println()
println("="^70)
