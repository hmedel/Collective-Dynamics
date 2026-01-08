#!/usr/bin/env julia
#
# analyze_finite_size_scaling.jl
#
# Análisis detallado de finite-size scaling para clustering dynamics
#
# Ajusta la forma funcional:
#   R_∞(N) = R_bulk + A/N^α
#
# Donde:
#   - R_bulk: Valor en el límite termodinámico (N → ∞)
#   - A: Amplitud de correcciones de tamaño finito
#   - α: Exponente crítico de scaling
#

using CSV
using DataFrames
using Statistics
using Plots
using LsqFit
using Printf

gr()

"""
    power_law_correction(N, p)

Modelo: R(N) = p[1] + p[2]/N^p[3]
  p[1] = R_bulk
  p[2] = A (amplitude)
  p[3] = α (exponent)
"""
function power_law_correction(N, p)
    R_bulk, A, alpha = p
    return R_bulk .+ A ./ (N .^ alpha)
end

"""
    fit_finite_size_scaling(N_values, R_values, R_errors)

Ajusta R_∞(N) = R_bulk + A/N^α usando least-squares.

# Returns
Named tuple: (R_bulk, A, alpha, R_bulk_err, A_err, alpha_err, fit, residuals)
"""
function fit_finite_size_scaling(N_values, R_values, R_errors)
    # Parámetros iniciales: [R_bulk, A, alpha]
    # Estimación inicial: R_bulk ≈ min(R), A ≈ (max(R) - min(R)) * N_max^0.5, alpha ≈ 0.5
    R_min = minimum(R_values)
    R_max = maximum(R_values)
    N_max = maximum(N_values)

    p0 = [R_min, (R_max - R_min) * sqrt(N_max), 0.5]

    # Pesos proporcionales a 1/error²
    weights = 1.0 ./ (R_errors .^ 2)

    try
        # Fit con errores ponderados
        fit_result = curve_fit(power_law_correction, N_values, R_values, weights, p0)

        params = fit_result.param
        errors = stderror(fit_result)

        # Residuales
        R_fit = power_law_correction(N_values, params)
        residuals = R_values .- R_fit

        # Chi-squared reducido
        chi2_reduced = sum(((R_values .- R_fit) ./ R_errors).^2) / (length(N_values) - 3)

        return (
            R_bulk = params[1],
            A = params[2],
            alpha = params[3],
            R_bulk_err = errors[1],
            A_err = errors[2],
            alpha_err = errors[3],
            fit_result = fit_result,
            residuals = residuals,
            chi2_reduced = chi2_reduced,
            success = true
        )
    catch e
        @warn "Fit failed: $e"
        return (success = false,)
    end
end

"""
    analyze_scaling_by_eccentricity(grouped_df)

Analiza finite-size scaling para cada valor de e.
"""
function analyze_scaling_by_eccentricity(grouped_df)
    println("="^80)
    println("FINITE-SIZE SCALING ANALYSIS")
    println("="^80)
    println()

    e_values = sort(unique(grouped_df.e))

    results = []

    for e in e_values
        println("Analyzing e = $e...")

        subset = filter(row -> row.e == e, grouped_df)
        sort!(subset, :N)

        N_vals = Float64.(subset.N)
        R_vals = subset.R_inf_mean
        R_errs = subset.R_inf_sem  # Usar SEM como error

        # Fit
        fit_res = fit_finite_size_scaling(N_vals, R_vals, R_errs)

        if fit_res.success
            @printf("  e = %.1f: R_bulk = %.4f ± %.4f, α = %.3f ± %.3f, χ²_red = %.3f\n",
                    e, fit_res.R_bulk, fit_res.R_bulk_err,
                    fit_res.alpha, fit_res.alpha_err,
                    fit_res.chi2_reduced)

            push!(results, (
                e = e,
                R_bulk = fit_res.R_bulk,
                R_bulk_err = fit_res.R_bulk_err,
                A = fit_res.A,
                A_err = fit_res.A_err,
                alpha = fit_res.alpha,
                alpha_err = fit_res.alpha_err,
                chi2_reduced = fit_res.chi2_reduced,
                fit_quality = fit_res.chi2_reduced < 2.0 ? "good" : "poor"
            ))
        else
            @printf("  e = %.1f: Fit failed\n", e)
        end
    end

    println()

    return DataFrame(results)
end

"""
    plot_scaling_curves(grouped_df, scaling_results, output_dir)

Plot R_∞(N) con fits para cada e.
"""
function plot_scaling_curves(grouped_df, scaling_results, output_dir)
    println("Generando plots de scaling...")

    e_values = sort(unique(grouped_df.e))
    colors = [:blue, :red, :green, :purple, :orange, :brown]
    markers = [:circle, :square, :diamond, :utriangle, :dtriangle, :pentagon]

    # Plot individual para cada e
    for (i, e) in enumerate(e_values)
        subset = filter(row -> row.e == e, grouped_df)
        sort!(subset, :N)

        fit_res = filter(row -> row.e == e, scaling_results)

        if nrow(fit_res) == 0
            continue
        end

        R_bulk = fit_res[1, :R_bulk]
        A = fit_res[1, :A]
        alpha = fit_res[1, :alpha]

        # Data points
        p = scatter(
            subset.N, subset.R_inf_mean,
            yerror = subset.R_inf_sem,
            xlabel = "Number of Particles N",
            ylabel = "Cluster Radius R_∞",
            title = @sprintf("Finite-Size Scaling: e = %.1f", e),
            label = "Data",
            marker = :circle,
            markersize = 8,
            color = colors[i],
            markerstrokewidth = 2,
            size = (800, 600),
            dpi = 150,
            legend = :best,
            grid = true,
            minorgrid = true,
            framestyle = :box
        )

        # Fit curve
        N_fit = range(minimum(subset.N), maximum(subset.N) * 1.2, length=100)
        R_fit = R_bulk .+ A ./ (N_fit .^ alpha)

        plot!(p, N_fit, R_fit,
              label = @sprintf("Fit: R_bulk = %.3f, α = %.2f", R_bulk, alpha),
              linewidth = 3,
              color = colors[i],
              linestyle = :dash
        )

        # Límite asintótico
        hline!(p, [R_bulk],
               label = @sprintf("R_bulk = %.3f", R_bulk),
               linewidth = 2,
               color = :black,
               linestyle = :dot
        )

        filename = @sprintf("scaling_e%.1f.png", e)
        savefig(p, joinpath(output_dir, filename))
        println("  ✅ Saved: $filename")
    end

    # Plot combinado: todas las e
    p_all = plot(
        xlabel = "Number of Particles N",
        ylabel = "Cluster Radius R_∞",
        title = "Finite-Size Scaling: All Eccentricities",
        legend = :outerright,
        size = (1000, 600),
        dpi = 150,
        grid = true,
        minorgrid = true,
        framestyle = :box
    )

    for (i, e) in enumerate(e_values)
        subset = filter(row -> row.e == e, grouped_df)
        sort!(subset, :N)

        fit_res = filter(row -> row.e == e, scaling_results)

        if nrow(fit_res) == 0
            continue
        end

        R_bulk = fit_res[1, :R_bulk]
        A = fit_res[1, :A]
        alpha = fit_res[1, :alpha]

        # Data
        scatter!(p_all, subset.N, subset.R_inf_mean,
                yerror = subset.R_inf_sem,
                label = @sprintf("e = %.1f (α=%.2f)", e, alpha),
                marker = markers[i],
                markersize = 6,
                color = colors[i],
                markerstrokewidth = 1
        )

        # Fit
        N_fit = range(minimum(subset.N), maximum(subset.N) * 1.1, length=50)
        R_fit = R_bulk .+ A ./ (N_fit .^ alpha)

        plot!(p_all, N_fit, R_fit,
              label = nothing,
              linewidth = 2,
              color = colors[i],
              linestyle = :dash,
              alpha = 0.7
        )
    end

    savefig(p_all, joinpath(output_dir, "scaling_all_e.png"))
    println("  ✅ Saved: scaling_all_e.png")
end

"""
    plot_scaling_collapse(grouped_df, scaling_results, output_dir)

Intenta colapsar las curvas usando scaling variables.

Si existe un exponente universal α, entonces:
  (R_∞ - R_bulk) * N^α  vs  N/ξ(e)
debería colapsar para todas las e.
"""
function plot_scaling_collapse(grouped_df, scaling_results, output_dir)
    println("Generando scaling collapse...")

    e_values = sort(unique(grouped_df.e))
    colors = [:blue, :red, :green, :purple, :orange, :brown]
    markers = [:circle, :square, :diamond, :utriangle, :dtriangle, :pentagon]

    # Usar α promedio para el collapse
    alpha_mean = mean(scaling_results.alpha)

    p = plot(
        xlabel = "N",
        ylabel = "(R∞ - R_bulk) × N^α",
        title = @sprintf("Scaling Collapse (α = %.2f)", alpha_mean),
        legend = :best,
        size = (800, 600),
        dpi = 150,
        grid = true,
        minorgrid = true,
        framestyle = :box,
        xscale = :log10,
        yscale = :log10
    )

    for (i, e) in enumerate(e_values)
        subset = filter(row -> row.e == e, grouped_df)
        sort!(subset, :N)

        fit_res = filter(row -> row.e == e, scaling_results)

        if nrow(fit_res) == 0
            continue
        end

        R_bulk = fit_res[1, :R_bulk]

        # Variable colapsada
        N_vals = subset.N
        R_vals = subset.R_inf_mean
        R_scaled = (R_vals .- R_bulk) .* (N_vals .^ alpha_mean)

        # Filtrar valores válidos (positivos para log scale)
        valid_idx = R_scaled .> 0

        scatter!(p, N_vals[valid_idx], R_scaled[valid_idx],
                label = @sprintf("e = %.1f", e),
                marker = markers[i],
                markersize = 6,
                color = colors[i],
                markerstrokewidth = 1
        )
    end

    savefig(p, joinpath(output_dir, "scaling_collapse.png"))
    println("  ✅ Saved: scaling_collapse.png")
end

"""
    plot_R_bulk_vs_e(scaling_results, output_dir)

Plot del límite termodinámico R_bulk(e).
"""
function plot_R_bulk_vs_e(scaling_results, output_dir)
    println("Generando plot: R_bulk vs e...")

    p = plot(
        xlabel = "Eccentricity e",
        ylabel = "Thermodynamic Limit R_bulk",
        title = "Bulk Clustering vs Eccentricity",
        legend = false,
        size = (800, 600),
        dpi = 150,
        grid = true,
        minorgrid = true,
        framestyle = :box
    )

    scatter!(p, scaling_results.e, scaling_results.R_bulk,
            yerror = scaling_results.R_bulk_err,
            marker = :circle,
            markersize = 8,
            color = :blue,
            markerstrokewidth = 2
    )

    # Línea suave
    plot!(p, scaling_results.e, scaling_results.R_bulk,
          linewidth = 2,
          color = :blue,
          alpha = 0.5
    )

    savefig(p, joinpath(output_dir, "R_bulk_vs_e.png"))
    println("  ✅ Saved: R_bulk_vs_e.png")
end

"""
    plot_alpha_vs_e(scaling_results, output_dir)

Plot del exponente crítico α(e).
"""
function plot_alpha_vs_e(scaling_results, output_dir)
    println("Generando plot: α vs e...")

    p = plot(
        xlabel = "Eccentricity e",
        ylabel = "Scaling Exponent α",
        title = "Critical Exponent vs Eccentricity",
        legend = false,
        size = (800, 600),
        dpi = 150,
        grid = true,
        minorgrid = true,
        framestyle = :box
    )

    scatter!(p, scaling_results.e, scaling_results.alpha,
            yerror = scaling_results.alpha_err,
            marker = :diamond,
            markersize = 8,
            color = :red,
            markerstrokewidth = 2
    )

    # Línea suave
    plot!(p, scaling_results.e, scaling_results.alpha,
          linewidth = 2,
          color = :red,
          alpha = 0.5
    )

    # Referencia α = 0.5 (mean-field universal)
    hline!(p, [0.5],
           label = "Mean-field (α = 0.5)",
           linewidth = 2,
           color = :black,
           linestyle = :dash
    )

    savefig(p, joinpath(output_dir, "alpha_vs_e.png"))
    println("  ✅ Saved: alpha_vs_e.png")
end

"""
    main_analysis(campaign_dir)

Ejecuta el análisis completo de finite-size scaling.
"""
function main_analysis(campaign_dir::String)
    println("="^80)
    println("FINITE-SIZE SCALING ANALYSIS")
    println("="^80)
    println("Campaign: ", campaign_dir)
    println()

    # Leer datos agrupados
    grouped_file = joinpath(campaign_dir, "clustering_analysis", "campaign_clustering_grouped.csv")

    if !isfile(grouped_file)
        println("❌ Error: Grouped data not found.")
        println("   Run extract_clustering_metrics.jl first.")
        return
    end

    grouped_df = CSV.read(grouped_file, DataFrame)

    # Análisis de scaling
    scaling_results = analyze_scaling_by_eccentricity(grouped_df)

    # Crear directorio para plots de scaling
    scaling_dir = joinpath(campaign_dir, "clustering_analysis", "scaling_analysis")
    mkpath(scaling_dir)

    # Guardar resultados
    results_file = joinpath(scaling_dir, "finite_size_scaling_results.csv")
    CSV.write(results_file, scaling_results)
    println("✅ Resultados guardados: $results_file")
    println()

    # Generar plots
    plot_scaling_curves(grouped_df, scaling_results, scaling_dir)
    plot_scaling_collapse(grouped_df, scaling_results, scaling_dir)
    plot_R_bulk_vs_e(scaling_results, scaling_dir)
    plot_alpha_vs_e(scaling_results, scaling_dir)

    # Resumen
    println()
    println("="^80)
    println("SUMMARY")
    println("="^80)
    println()

    println("Scaling Parameters:")
    println("-"^80)
    @printf("%-10s %15s %15s %15s %15s\n", "e", "R_bulk", "α", "A", "χ²_red")
    println("-"^80)
    for row in eachrow(scaling_results)
        @printf("%-10.1f %15.4f %15.3f %15.4f %15.3f\n",
                row.e, row.R_bulk, row.alpha, row.A, row.chi2_reduced)
    end
    println()

    # Estadísticas de α
    println("Critical Exponent Statistics:")
    @printf("  Mean α:   %.3f ± %.3f\n", mean(scaling_results.alpha), std(scaling_results.alpha))
    @printf("  Min α:    %.3f (e = %.1f)\n",
            minimum(scaling_results.alpha),
            scaling_results[argmin(scaling_results.alpha), :e])
    @printf("  Max α:    %.3f (e = %.1f)\n",
            maximum(scaling_results.alpha),
            scaling_results[argmax(scaling_results.alpha), :e])
    println()

    # Estadísticas de R_bulk
    println("Thermodynamic Limit Statistics:")
    @printf("  Mean R_bulk:   %.3f\n", mean(scaling_results.R_bulk))
    @printf("  Min R_bulk:    %.3f (e = %.1f)\n",
            minimum(scaling_results.R_bulk),
            scaling_results[argmin(scaling_results.R_bulk), :e])
    @printf("  Max R_bulk:    %.3f (e = %.1f)\n",
            maximum(scaling_results.R_bulk),
            scaling_results[argmax(scaling_results.R_bulk), :e])
    println()

    println("="^80)
    println("✅ FINITE-SIZE SCALING ANALYSIS COMPLETE")
    println("="^80)
    println("Output directory: $scaling_dir")
    println()

    return scaling_results
end

# Main execution
if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) < 1
        println("Usage: julia analyze_finite_size_scaling.jl <campaign_dir>")
        exit(1)
    end

    campaign_dir = ARGS[1]

    if !isdir(campaign_dir)
        println("❌ Error: Campaign directory not found: $campaign_dir")
        exit(1)
    end

    scaling_results = main_analysis(campaign_dir)
end
