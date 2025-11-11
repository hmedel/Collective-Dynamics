"""
analizar_error_colisiones.jl

Analiza cómo el error del momento conjugado se relaciona con las colisiones.

Uso:
    julia --project=. analizar_error_colisiones.jl results/simulation_XXXXXX/
"""

using DelimitedFiles
using Printf
using Plots

if length(ARGS) < 1
    println("❌ Error: Proporciona el directorio de resultados")
    exit(1)
end

dir_resultados = ARGS[1]

println("="^80)
println("ANÁLISIS: Error de Momento Conjugado vs Colisiones")
println("="^80)
println()

# ============================================================================
# Cargar datos
# ============================================================================
println("📥 Cargando datos...")

# Conservación
archivo_cons = joinpath(dir_resultados, "conservation.csv")
cons_data, _ = readdlm(archivo_cons, ',', Float64, '\n'; header=true)

time_cons = cons_data[:, 1]
energy = cons_data[:, 2]
conjugate_momentum = cons_data[:, 3]

# Colisiones por paso
archivo_coll = joinpath(dir_resultados, "collisions_per_step.csv")
if !isfile(archivo_coll)
    println("❌ Error: No se encontró collisions_per_step.csv")
    exit(1)
end

coll_data, _ = readdlm(archivo_coll, ',', '\n'; header=true)
time_coll = Float64.(coll_data[:, 1])
n_collisions = Int.(coll_data[:, 3])
collisions_cumulative = cumsum(n_collisions)

println("  ✅ $(length(time_cons)) puntos de conservación")
println("  ✅ $(length(time_coll)) pasos de tiempo")
println("  ✅ $(collisions_cumulative[end]) colisiones totales")
println()

# ============================================================================
# Análisis de errores
# ============================================================================
E_initial = energy[1]
P_initial = conjugate_momentum[1]

errors_E = abs.(energy .- E_initial) ./ E_initial
errors_P = abs.(conjugate_momentum .- P_initial) ./ abs(P_initial)

error_E_final = errors_E[end]
error_P_final = errors_P[end]

println("ERRORES FINALES:")
println("-"^80)
println(@sprintf("  Energía:          %.3e (%.4f%%)", error_E_final, error_E_final*100))
println(@sprintf("  Momento conjugado: %.3e (%.4f%%)", error_P_final, error_P_final*100))
println()

ratio = error_P_final / error_E_final
println(@sprintf("  Ratio error_P / error_E: %.2f", ratio))

if ratio > 1.2
    println("  ⚠️  Momento conjugado se conserva PEOR que energía")
    println("     Esto sugiere que las colisiones no preservan p_θ perfectamente")
elseif ratio < 0.8
    println("  ✅ Momento conjugado se conserva MEJOR que energía")
else
    println("  ✅ Ambos se conservan similarmente")
end
println()

# ============================================================================
# Análisis de crecimiento del error
# ============================================================================
println("ANÁLISIS DE CRECIMIENTO:")
println("-"^80)

# Regresión lineal simple: error vs tiempo
function fit_linear(x, y)
    n = length(x)
    mean_x = sum(x) / n
    mean_y = sum(y) / n

    num = sum((x .- mean_x) .* (y .- mean_y))
    den = sum((x .- mean_x).^2)

    slope = num / den
    intercept = mean_y - slope * mean_x

    return slope, intercept
end

slope_E, _ = fit_linear(time_cons, errors_E)
slope_P, _ = fit_linear(time_cons, errors_P)

println("Crecimiento del error con el tiempo:")
println(@sprintf("  d(error_E)/dt = %.3e /s", slope_E))
println(@sprintf("  d(error_P)/dt = %.3e /s", slope_P))
println()

# Interpolar colisiones acumulativas a tiempos de conservación
using Interpolations
itp = LinearInterpolation(time_coll, collisions_cumulative, extrapolation_bc=Line())
coll_at_cons_times = itp.(time_cons)

# Analizar error vs colisiones acumulativas
slope_E_coll, _ = fit_linear(coll_at_cons_times, errors_E)
slope_P_coll, _ = fit_linear(coll_at_cons_times, errors_P)

println("Crecimiento del error con colisiones:")
println(@sprintf("  d(error_E)/d(n_coll) = %.3e /colisión", slope_E_coll))
println(@sprintf("  d(error_P)/d(n_coll) = %.3e /colisión", slope_P_coll))
println()

# Determinar cuál domina
ratio_slopes = (slope_P_coll / collisions_cumulative[end]) / (slope_P / time_cons[end])

if ratio_slopes > 2.0
    println("✅ DIAGNÓSTICO: El error viene principalmente de las COLISIONES")
    println("   Razón: El error por colisión domina sobre el error por tiempo")
    println()
    println("📌 SOLUCIÓN RECOMENDADA:")
    println("   • Reducir tolerance de 1e-7 → 1e-8 o 1e-9")
    println("   • Esto debería mejorar significativamente")
elseif ratio_slopes < 0.5
    println("✅ DIAGNÓSTICO: El error viene principalmente del INTEGRADOR")
    println("   Razón: El error crece con tiempo, no con colisiones")
    println()
    println("📌 SOLUCIÓN RECOMENDADA:")
    println("   • Reducir dt_max de 1e-6 → 5e-7 o 1e-7")
else
    println("✅ DIAGNÓSTICO: Ambos contribuyen significativamente")
    println("   Razón: Error tiene componente temporal y por colisión")
    println()
    println("📌 SOLUCIÓN RECOMENDADA:")
    println("   • Reducir ambos: dt_max → 5e-7 y tolerance → 1e-8")
end
println()

# ============================================================================
# Gráficas de diagnóstico
# ============================================================================
println("📊 Generando gráficas de diagnóstico...")

# Gráfica 1: Error vs Tiempo
p1 = plot(
    xlabel = "Tiempo (s)",
    ylabel = "Error Relativo",
    title = "Error vs Tiempo",
    yscale = :log10,
    legend = :topleft,
    size = (1000, 600)
)

plot!(p1, time_cons, errors_E, label = "Energía", linewidth = 2, color = :blue)
plot!(p1, time_cons, errors_P, label = "Momento Conjugado", linewidth = 2, color = :purple)

# Líneas de ajuste lineal
fit_E = slope_E .* time_cons .+ errors_E[1]
fit_P = slope_P .* time_cons .+ errors_P[1]

plot!(p1, time_cons, fit_E, label = "Ajuste E", linestyle = :dash, color = :blue, linewidth = 1)
plot!(p1, time_cons, fit_P, label = "Ajuste P", linestyle = :dash, color = :purple, linewidth = 1)

savefig(p1, joinpath(dir_resultados, "error_vs_tiempo_analisis.png"))
println("  ✅ error_vs_tiempo_analisis.png")

# Gráfica 2: Error vs Colisiones
p2 = plot(
    xlabel = "Número de Colisiones Acumuladas",
    ylabel = "Error Relativo",
    title = "Error vs Colisiones",
    yscale = :log10,
    legend = :topleft,
    size = (1000, 600)
)

plot!(p2, coll_at_cons_times, errors_E, label = "Energía", linewidth = 2, color = :blue)
plot!(p2, coll_at_cons_times, errors_P, label = "Momento Conjugado", linewidth = 2, color = :purple)

savefig(p2, joinpath(dir_resultados, "error_vs_colisiones.png"))
println("  ✅ error_vs_colisiones.png")

# Gráfica 3: Tasa de colisiones vs Tiempo
p3 = plot(
    xlabel = "Tiempo (s)",
    ylabel = "Colisiones Acumuladas",
    title = "Evolución de Colisiones",
    legend = false,
    size = (1000, 600)
)

plot!(p3, time_coll, collisions_cumulative, linewidth = 2, color = :red)

savefig(p3, joinpath(dir_resultados, "colisiones_vs_tiempo.png"))
println("  ✅ colisiones_vs_tiempo.png")

println()
println("="^80)
println("✅ ANÁLISIS COMPLETADO")
println("="^80)
println()
println("Ver gráficas en: $dir_resultados")
println()
println("="^80)
