#!/usr/bin/env julia
# Análisis de resultados de condiciones iniciales uniformes
# Verifica formación dinámica de clustering desde estado uniforme

using HDF5
using Statistics
using Printf

println("="^70)
println("ANÁLISIS: FORMACIÓN DINÁMICA DE CLUSTERING")
println("="^70)
println()

# Buscar archivo HDF5
output_dir = "results/test_uniform_ICs"
h5_files = filter(f -> endswith(f, ".h5"), readdir(output_dir, join=true))

if isempty(h5_files)
    println("❌ ERROR: No se encontró archivo HDF5")
    exit(1)
end

h5_file = h5_files[1]
println("📁 Archivo: $(basename(h5_file))")
println()

# Leer datos
h5open(h5_file, "r") do file
    # Configuración
    config = file["config"]
    a = read(attributes(config)["a"])
    b = read(attributes(config)["b"])
    e = read(attributes(config)["eccentricity"])
    N = read(attributes(config)["N"])
    E_per_N = read(attributes(config)["E_per_N"])

    println("Configuración:")
    @printf("  N = %d\n", N)
    @printf("  e = %.3f\n", e)
    @printf("  E/N = %.2f\n", E_per_N)
    @printf("  a/b = %.2f\n", a/b)
    println()

    # Trayectorias
    traj = file["trajectories"]
    time = read(traj["time"])
    phi = read(traj["phi"])  # [N, n_timesteps]

    n_times = length(time)

    println("Datos:")
    @printf("  Tiempo final: %.1fs\n", time[end])
    @printf("  Timesteps guardados: %d\n", n_times)
    @printf("  Intervalo de guardado: %.2fs\n", time[2] - time[1])
    println()

    # Conservación
    cons = file["conservation"]
    energy = read(cons["energy"])

    ΔE_rel = abs(energy[end] - energy[1]) / energy[1]
    @printf("Conservación energía: ΔE/E₀ = %.2e\n", ΔE_rel)
    println()

    # Análisis temporal de distribución
    println("="^70)
    println("EVOLUCIÓN TEMPORAL DE CLUSTERING")
    println("="^70)
    println()

    # Seleccionar snapshots clave
    indices = Int[]
    labels = String[]

    # t=0
    push!(indices, 1)
    push!(labels, "Inicial (t=0s)")

    # t = 25%, 50%, 75%, 100%
    for frac in [0.25, 0.5, 0.75, 1.0]
        idx = round(Int, frac * n_times)
        idx = clamp(idx, 1, n_times)
        push!(indices, idx)
        push!(labels, @sprintf("t=%.0f%%", frac*100))
    end

    # Para cada snapshot
    for (idx, label) in zip(indices, labels)
        phi_snap = mod.(phi[:, idx], 2π)
        t_snap = time[idx]

        # Calcular densidad en regiones clave
        ϵ = 0.35  # ±20° en radianes

        # Eje mayor (φ ≈ 0° y 180°)
        near_major = sum((abs.(phi_snap) .< ϵ) .|
                        (abs.(phi_snap .- π) .< ϵ) .|
                        (abs.(phi_snap .- 2π) .< ϵ))

        # Eje menor (φ ≈ 90° y 270°)
        near_minor = sum((abs.(phi_snap .- π/2) .< ϵ) .|
                        (abs.(phi_snap .- 3π/2) .< ϵ))

        pct_major = 100 * near_major / N
        pct_minor = 100 * near_minor / N

        @printf("%-20s (t=%5.1fs):  ", label, t_snap)
        @printf("MAYOR: %5.1f%%    MENOR: %5.1f%%", pct_major, pct_minor)

        if pct_major > pct_minor + 5.0  # Umbral de significancia
            ratio = pct_major / (pct_minor + 0.01)
            @printf("    → ✅ Clustering en MAYOR (%.1fx)", ratio)
        elseif pct_minor > pct_major + 5.0
            ratio = pct_minor / (pct_major + 0.01)
            @printf("    → ⚠️  Clustering en menor (%.1fx)", ratio)
        else
            @printf("    → ⚪ Distribución balanceada")
        end
        println()
    end

    println()
    println("="^70)
    println("ANÁLISIS DETALLADO: INICIAL vs FINAL")
    println("="^70)
    println()

    # Distribución inicial (t=0)
    phi_inicial = mod.(phi[:, 1], 2π)
    bins_inicial = range(0, 2π, length=9)
    counts_inicial = zeros(Int, 8)

    for p in phi_inicial
        bin_idx = searchsortedfirst(bins_inicial, p) - 1
        bin_idx = clamp(bin_idx, 1, 8)
        counts_inicial[bin_idx] += 1
    end

    println("Distribución INICIAL (t=0s):")
    expected = N / 8
    max_dev_inicial = 0.0
    for (i, count) in enumerate(counts_inicial)
        deviation = abs(count - expected) / expected * 100
        max_dev_inicial = max(max_dev_inicial, deviation)
        bin_start = rad2deg(bins_inicial[i])
        @printf("  %3.0f°-%3.0f°: %2d partículas (%.1f%%, desv: %.1f%%)\n",
                bin_start, bin_start+45, count, 100*count/N, deviation)
    end
    @printf("\n  Desviación máxima del uniforme: %.1f%%\n", max_dev_inicial)
    println()

    # Distribución final (t=100s)
    phi_final = mod.(phi[:, end], 2π)
    counts_final = zeros(Int, 8)

    for p in phi_final
        bin_idx = searchsortedfirst(bins_inicial, p) - 1
        bin_idx = clamp(bin_idx, 1, 8)
        counts_final[bin_idx] += 1
    end

    println("Distribución FINAL (t=$(round(time[end],digits=1))s):")
    max_dev_final = 0.0
    for (i, count) in enumerate(counts_final)
        deviation = abs(count - expected) / expected * 100
        max_dev_final = max(max_dev_final, deviation)
        bin_start = rad2deg(bins_inicial[i])

        # Marcar bins del eje mayor
        is_major = (i == 1) || (i == 5)  # 0° y 180°
        marker = is_major ? "← EJE MAYOR" : ""

        @printf("  %3.0f°-%3.0f°: %2d partículas (%.1f%%, desv: %.1f%%) %s\n",
                bin_start, bin_start+45, count, 100*count/N, deviation, marker)
    end
    @printf("\n  Desviación máxima del uniforme: %.1f%%\n", max_dev_final)
    println()

    # Comparación cuantitativa
    println("="^70)
    println("CONCLUSIÓN")
    println("="^70)
    println()

    # Calcular densidades en ejes (±20°)
    ϵ = 0.35

    # Estado inicial
    phi_i = mod.(phi[:, 1], 2π)
    major_i = sum((abs.(phi_i) .< ϵ) .| (abs.(phi_i .- π) .< ϵ) .| (abs.(phi_i .- 2π) .< ϵ))
    minor_i = sum((abs.(phi_i .- π/2) .< ϵ) .| (abs.(phi_i .- 3π/2) .< ϵ))

    # Estado final
    phi_f = mod.(phi[:, end], 2π)
    major_f = sum((abs.(phi_f) .< ϵ) .| (abs.(phi_f .- π) .< ϵ) .| (abs.(phi_f .- 2π) .< ϵ))
    minor_f = sum((abs.(phi_f .- π/2) .< ϵ) .| (abs.(phi_f .- 3π/2) .< ϵ))

    pct_major_i = 100 * major_i / N
    pct_minor_i = 100 * minor_i / N
    pct_major_f = 100 * major_f / N
    pct_minor_f = 100 * minor_f / N

    println("Estado INICIAL (t=0s):")
    @printf("  Eje MAYOR: %.1f%%\n", pct_major_i)
    @printf("  Eje MENOR: %.1f%%\n", pct_minor_i)
    @printf("  Ratio: %.2fx\n", pct_major_i / (pct_minor_i + 0.01))
    println()

    println("Estado FINAL (t=$(round(time[end],digits=1))s):")
    @printf("  Eje MAYOR: %.1f%%\n", pct_major_f)
    @printf("  Eje MENOR: %.1f%%\n", pct_minor_f)
    @printf("  Ratio: %.2fx\n", pct_major_f / (pct_minor_f + 0.01))
    println()

    println("CAMBIO (final - inicial):")
    @printf("  Δ(Eje MAYOR): %+.1f%%\n", pct_major_f - pct_major_i)
    @printf("  Δ(Eje MENOR): %+.1f%%\n", pct_minor_f - pct_minor_i)
    println()

    # Verificar formación dinámica
    clustering_formed = (pct_major_f - pct_major_i) > 10.0  # Incremento >10%
    ratio_final = pct_major_f / (pct_minor_f + 0.01)

    if clustering_formed && ratio_final > 3.0
        println("✅ CONFIRMADO: Formación dinámica de clustering")
        println("   → Partículas SE ACUMULAN en eje mayor (alta curvatura)")
        println("   → Incremento significativo desde estado uniforme")
        println("   → Ratio final mayor/menor: $(round(ratio_final, digits=1))×")
        println()
        println("   MECANISMO VALIDADO:")
        println("   κ alta (eje mayor) → frenado centrípeto → mayor permanencia → clustering")
    elseif ratio_final > 3.0
        println("✅ Clustering detectado (ratio: $(round(ratio_final, digits=1))×)")
        println("⚠️  Pero podría estar presente desde t=0 (ICs sesgadas)")
    else
        println("⚠️  No se observa clustering significativo")
        println("   Ratio final: $(round(ratio_final, digits=2))×")
        println("   (Se esperaba >3× para clustering claro)")
    end

    println()
    println("="^70)
    println("Archivo analizado: $h5_file")
    println("="^70)
end
