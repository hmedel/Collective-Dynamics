#!/usr/bin/env julia

"""
Análisis de la distribución espacial de partículas vs curvatura de la elipse.

Verifica si las partículas tienden a acumularse en regiones de mayor curvatura.
"""

using JLD2
using Statistics
using Printf
using Plots
using DataFrames
using CSV

# Función para calcular la curvatura de una elipse en función de θ
function curvature_ellipse(θ::T, a::T, b::T) where {T <: AbstractFloat}
    """
    Curvatura de una elipse: κ(θ) = a*b / (a²sin²θ + b²cos²θ)^(3/2)

    Para a > b:
    - κ máxima en θ = π/2, 3π/2 (extremos del semieje menor)
    - κ mínima en θ = 0, π (extremos del semieje mayor)
    """
    numerator = a * b
    denominator = (a^2 * sin(θ)^2 + b^2 * cos(θ)^2)^(3/2)
    return numerator / denominator
end

# Función para calcular densidad local de partículas
function local_density(angles::Vector{T}, angle_bins::Vector{T}) where {T <: AbstractFloat}
    """
    Calcula densidad de partículas en bins angulares.
    Retorna densidad normalizada (suma = 1).
    """
    n_bins = length(angle_bins) - 1
    counts = zeros(Int, n_bins)

    for θ in angles
        θ_wrapped = mod(θ, 2π)
        for i in 1:n_bins
            if angle_bins[i] <= θ_wrapped < angle_bins[i+1]
                counts[i] += 1
                break
            end
        end
    end

    # Normalizar por área del bin (todos tienen el mismo tamaño angular)
    density = counts ./ sum(counts)
    return density
end

# Función principal de análisis
function analyze_curvature_correlation(data_file::String, a::Float64, b::Float64)
    println("="^70)
    println("ANÁLISIS: Distribución Espacial vs Curvatura")
    println("="^70)
    println()

    # Cargar datos
    println("Cargando datos desde: $data_file")
    data = load(data_file, "data")

    n_particles = length(data.particles[1])
    n_snapshots = length(data.particles)

    println("  Partículas: $n_particles")
    println("  Snapshots: $n_snapshots")
    println("  Semiejes: a=$a, b=$b")
    println()

    # Extraer ángulos inicial, intermedio y final
    θ_initial = [p.θ for p in data.particles[1]]
    θ_middle = [p.θ for p in data.particles[div(n_snapshots, 2)]]
    θ_final = [p.θ for p in data.particles[end]]

    # Crear bins angulares (36 bins = 10° cada uno)
    n_bins = 36
    angle_bins = range(0, 2π, length=n_bins+1)
    bin_centers = [(angle_bins[i] + angle_bins[i+1])/2 for i in 1:n_bins]

    # Calcular curvatura en cada bin
    curvatures = [curvature_ellipse(θ, a, b) for θ in bin_centers]

    # Calcular densidades
    density_initial = local_density(θ_initial, collect(angle_bins))
    density_middle = local_density(θ_middle, collect(angle_bins))
    density_final = local_density(θ_final, collect(angle_bins))

    # Estadísticas de curvatura
    κ_min = curvature_ellipse(0.0, a, b)
    κ_max = curvature_ellipse(π/2, a, b)

    println("Curvatura de la elipse:")
    @printf("  κ mínima (θ=0, π):       %.6f\n", κ_min)
    @printf("  κ máxima (θ=π/2, 3π/2):  %.6f\n", κ_max)
    @printf("  Ratio κ_max/κ_min:       %.2f\n", κ_max/κ_min)
    println()

    # Calcular correlación entre densidad y curvatura
    corr_initial = cor(density_initial, curvatures)
    corr_middle = cor(density_middle, curvatures)
    corr_final = cor(density_final, curvatures)

    println("Correlación densidad-curvatura:")
    @printf("  Inicial:   %.4f\n", corr_initial)
    @printf("  Medio:     %.4f\n", corr_middle)
    @printf("  Final:     %.4f\n", corr_final)
    println()

    if abs(corr_final) > 0.3
        if corr_final > 0
            println("  ⚠️  CORRELACIÓN POSITIVA SIGNIFICATIVA")
            println("  → Las partículas SÍ tienden a acumularse en regiones de mayor curvatura")
        else
            println("  ⚠️  CORRELACIÓN NEGATIVA SIGNIFICATIVA")
            println("  → Las partículas tienden a evitar regiones de mayor curvatura")
        end
    else
        println("  ✓ No hay correlación significativa")
        println("  → La distribución es aproximadamente uniforme respecto a la curvatura")
    end
    println()

    # Calcular dispersión espacial (desviación estándar de θ)
    σ_initial = std(θ_initial)
    σ_middle = std(θ_middle)
    σ_final = std(θ_final)

    println("Dispersión espacial (σ de θ):")
    @printf("  Inicial: %.4f rad\n", σ_initial)
    @printf("  Medio:   %.4f rad\n", σ_middle)
    @printf("  Final:   %.4f rad\n", σ_final)
    @printf("  Cambio:  %.2f%%\n", 100*(σ_final - σ_initial)/σ_initial)
    println()

    # Análisis por cuadrantes
    println("Densidad por cuadrantes:")
    quadrants = [
        ("Q1: [0°, 90°]     - baja curvatura → alta",   0.0, π/2),
        ("Q2: [90°, 180°]   - alta curvatura → baja",   π/2, π),
        ("Q3: [180°, 270°]  - baja curvatura → alta",   π, 3π/2),
        ("Q4: [270°, 360°]  - alta curvatura → baja",   3π/2, 2π)
    ]

    for (label, θ_min, θ_max) in quadrants
        count_initial = count(θ -> θ_min <= mod(θ, 2π) < θ_max, θ_initial)
        count_final = count(θ -> θ_min <= mod(θ, 2π) < θ_max, θ_final)

        @printf("  %s\n", label)
        @printf("    Inicial: %2d partículas (%.1f%%)\n",
                count_initial, 100*count_initial/n_particles)
        @printf("    Final:   %2d partículas (%.1f%%)\n",
                count_final, 100*count_final/n_particles)
        @printf("    Cambio:  %+d partículas\n", count_final - count_initial)
    end
    println()

    # Guardar datos para plotting
    return (
        bin_centers = bin_centers,
        curvatures = curvatures,
        density_initial = density_initial,
        density_middle = density_middle,
        density_final = density_final,
        corr_initial = corr_initial,
        corr_middle = corr_middle,
        corr_final = corr_final,
        θ_initial = θ_initial,
        θ_final = θ_final,
        a = a,
        b = b
    )
end

# Función para generar visualizaciones
function plot_curvature_analysis(results, output_dir::String)
    println("Generando visualizaciones...")

    # Plot 1: Densidad vs Ángulo + Curvatura
    p1 = plot(layout=(2,1), size=(1200, 800))

    # Subplot 1a: Densidad en diferentes tiempos
    plot!(p1[1], results.bin_centers * 180/π, results.density_initial,
          label="Inicial", linewidth=2, marker=:circle, markersize=3)
    plot!(p1[1], results.bin_centers * 180/π, results.density_middle,
          label="Medio", linewidth=2, marker=:square, markersize=3)
    plot!(p1[1], results.bin_centers * 180/π, results.density_final,
          label="Final", linewidth=2, marker=:diamond, markersize=3)
    xlabel!(p1[1], "Ángulo θ (grados)")
    ylabel!(p1[1], "Densidad de partículas (normalizada)")
    title!(p1[1], "Distribución Angular de Partículas")

    # Subplot 1b: Curvatura vs ángulo
    plot!(p1[2], results.bin_centers * 180/π, results.curvatures,
          label="Curvatura κ(θ)", linewidth=2, color=:red, marker=:circle, markersize=3)
    xlabel!(p1[2], "Ángulo θ (grados)")
    ylabel!(p1[2], "Curvatura κ")
    title!(p1[2], "Curvatura de la Elipse (a=$(results.a), b=$(results.b))")

    # Marcar puntos de curvatura extrema
    vline!(p1[2], [0, 180], label="κ mínima", linestyle=:dash, color=:blue, linewidth=1)
    vline!(p1[2], [90, 270], label="κ máxima", linestyle=:dash, color=:orange, linewidth=1)

    savefig(p1, joinpath(output_dir, "distribucion_angular_curvatura.png"))
    println("  ✓ distribucion_angular_curvatura.png")

    # Plot 2: Scatter density vs curvature
    p2 = plot(layout=(1,3), size=(1800, 500))

    scatter!(p2[1], results.curvatures, results.density_initial,
             xlabel="Curvatura κ", ylabel="Densidad",
             title="Inicial (r=$(round(results.corr_initial, digits=3)))",
             legend=false, markersize=5, alpha=0.6)

    scatter!(p2[2], results.curvatures, results.density_middle,
             xlabel="Curvatura κ", ylabel="Densidad",
             title="Medio (r=$(round(results.corr_middle, digits=3)))",
             legend=false, markersize=5, alpha=0.6)

    scatter!(p2[3], results.curvatures, results.density_final,
             xlabel="Curvatura κ", ylabel="Densidad",
             title="Final (r=$(round(results.corr_final, digits=3)))",
             legend=false, markersize=5, alpha=0.6)

    plot!(p2, suptitle="Correlación Densidad-Curvatura")

    savefig(p2, joinpath(output_dir, "correlacion_densidad_curvatura.png"))
    println("  ✓ correlacion_densidad_curvatura.png")

    # Plot 3: Histogramas inicial vs final
    p3 = plot(layout=(2,1), size=(1200, 800))

    histogram!(p3[1], results.θ_initial * 180/π,
               bins=36, normalize=:probability,
               xlabel="Ángulo θ (grados)", ylabel="Frecuencia",
               title="Distribución Inicial",
               legend=false, alpha=0.7)

    histogram!(p3[2], results.θ_final * 180/π,
               bins=36, normalize=:probability,
               xlabel="Ángulo θ (grados)", ylabel="Frecuencia",
               title="Distribución Final",
               legend=false, alpha=0.7, color=:orange)

    # Marcar regiones de alta curvatura
    for i in [1,2]
        vspan!(p3[i], [80, 100], label="Alta κ", alpha=0.2, color=:red)
        vspan!(p3[i], [260, 280], label="", alpha=0.2, color=:red)
    end

    savefig(p3, joinpath(output_dir, "histogramas_distribucion.png"))
    println("  ✓ histogramas_distribucion.png")

    # Plot 4: Posiciones en la elipse (2D)
    p4 = plot(size=(800, 800), aspect_ratio=:equal)

    # Dibujar elipse
    θ_ellipse = range(0, 2π, length=200)
    x_ellipse = results.a .* cos.(θ_ellipse)
    y_ellipse = results.b .* sin.(θ_ellipse)
    plot!(p4, x_ellipse, y_ellipse, label="Elipse", linewidth=2, color=:black)

    # Posiciones iniciales
    x_initial = results.a .* cos.(results.θ_initial)
    y_initial = results.b .* sin.(results.θ_initial)
    scatter!(p4, x_initial, y_initial,
             label="Inicial", markersize=6, alpha=0.6, color=:blue)

    # Posiciones finales
    x_final = results.a .* cos.(results.θ_final)
    y_final = results.b .* sin.(results.θ_final)
    scatter!(p4, x_final, y_final,
             label="Final", markersize=6, alpha=0.6, color=:red, marker=:square)

    # Marcar puntos de curvatura extrema
    scatter!(p4, [results.a, -results.a], [0, 0],
             label="κ mínima", markersize=10, color=:green, marker=:star5)
    scatter!(p4, [0, 0], [results.b, -results.b],
             label="κ máxima", markersize=10, color=:orange, marker=:star5)

    xlabel!(p4, "x")
    ylabel!(p4, "y")
    title!(p4, "Posiciones en la Elipse: Inicial vs Final")

    savefig(p4, joinpath(output_dir, "posiciones_2d_elipse.png"))
    println("  ✓ posiciones_2d_elipse.png")

    println()
end

# Script principal
function main()
    # Configuración
    data_file = "results/analisis_completo_20251113_232211/simulation_data.jld2"
    output_dir = dirname(data_file)
    a = 2.0
    b = 1.0

    if !isfile(data_file)
        println("ERROR: No se encontró el archivo de datos: $data_file")
        println("Por favor ejecuta primero: julia --project=. simulacion_analisis_completo.jl")
        return
    end

    # Análisis
    results = analyze_curvature_correlation(data_file, a, b)

    # Visualizaciones
    plot_curvature_analysis(results, output_dir)

    println("="^70)
    println("ANÁLISIS COMPLETADO")
    println("="^70)
    println("Resultados guardados en: $output_dir")
    println()
end

# Ejecutar
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
