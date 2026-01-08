"""
plot_conservation.jl

Script simple para graficar energía total y momento conjugado vs tiempo.

Uso:
    julia --project=. plot_conservation.jl results/simulation_XXXXXX/

Genera dos gráficas:
    - energia_vs_tiempo.png
    - momento_conjugado_vs_tiempo.png
"""

using Plots
using DelimitedFiles
using Printf

# Verificar argumentos
if length(ARGS) < 1
    println("❌ Error: Debes proporcionar el directorio de resultados")
    println()
    println("Uso:")
    println("  julia --project=. plot_conservation.jl results/simulation_XXXXXX/")
    println()
    println("Ejemplo:")
    println("  julia --project=. plot_conservation.jl results/simulation_20251108_010937/")
    exit(1)
end

dir_resultados = ARGS[1]

# Verificar que existe
if !isdir(dir_resultados)
    println("❌ Error: Directorio no encontrado: $dir_resultados")
    exit(1)
end

println("="^70)
println("GRÁFICAS DE CONSERVACIÓN")
println("="^70)
println()
println("Directorio: $dir_resultados")
println()

# ============================================================================
# Cargar datos de conservación
# ============================================================================
archivo_cons = joinpath(dir_resultados, "conservation.csv")

if !isfile(archivo_cons)
    println("❌ Error: No se encontró conservation.csv")
    exit(1)
end

println("📥 Cargando datos de conservación...")
data, header = readdlm(archivo_cons, ',', Float64, '\n'; header=true)

time = data[:, 1]
energy = data[:, 2]
conjugate_momentum = data[:, 3]

n_points = length(time)
println("  ✅ $n_points puntos cargados")
println()

# ============================================================================
# Calcular estadísticas
# ============================================================================
E_initial = energy[1]
E_final = energy[end]
P_initial = conjugate_momentum[1]
P_final = conjugate_momentum[end]

ΔE = abs(E_final - E_initial)
ΔP = abs(P_final - P_initial)

error_E = ΔE / E_initial
error_P = ΔP / abs(P_initial)

println("ESTADÍSTICAS:")
println("-"^70)
println()
println("ENERGÍA TOTAL:")
println("  Inicial:        $(E_initial)")
println("  Final:          $(E_final)")
println("  Diferencia abs: $(ΔE)")
println("  Error relativo: $(error_E) ($(error_E*100)%)")
println()

println("MOMENTO CONJUGADO:")
println("  Inicial:        $(P_initial)")
println("  Final:          $(P_final)")
println("  Diferencia abs: $(ΔP)")
println("  Error relativo: $(error_P) ($(error_P*100)%)")
println()

# ============================================================================
# Gráfica 1: Energía Total vs Tiempo
# ============================================================================
println("📊 Generando gráfica de energía...")

p1 = plot(
    time, energy,
    xlabel = "Tiempo (s)",
    ylabel = "Energía Total (J)",
    title = "Conservación de Energía",
    legend = false,
    linewidth = 2,
    color = :blue,
    size = (1000, 600),
    dpi = 150
)

# Línea de referencia (valor inicial)
hline!(p1, [E_initial],
       linestyle = :dash,
       color = :red,
       linewidth = 1,
       label = "E₀")

# Anotación con error
annotate!(p1, time[end]*0.7, maximum(energy),
          text(@sprintf("Error: %.2e (%.3f%%)", error_E, error_E*100), 10, :left))

archivo_E = joinpath(dir_resultados, "energia_vs_tiempo.png")
savefig(p1, archivo_E)
println("  ✅ Guardado: energia_vs_tiempo.png")

# ============================================================================
# Gráfica 2: Momento Conjugado vs Tiempo
# ============================================================================
println("📊 Generando gráfica de momento conjugado...")

p2 = plot(
    time, conjugate_momentum,
    xlabel = "Tiempo (s)",
    ylabel = "Momento Conjugado p_θ",
    title = "Conservación de Momento Conjugado (p_θ = m √g(θ) θ̇)",
    legend = false,
    linewidth = 2,
    color = :purple,
    size = (1000, 600),
    dpi = 150
)

# Línea de referencia
hline!(p2, [P_initial],
       linestyle = :dash,
       color = :red,
       linewidth = 1,
       label = "P₀")

# Anotación con error
annotate!(p2, time[end]*0.7, maximum(conjugate_momentum),
          text(@sprintf("Error: %.2e (%.3f%%)", error_P, error_P*100), 10, :left))

archivo_P = joinpath(dir_resultados, "momento_conjugado_vs_tiempo.png")
savefig(p2, archivo_P)
println("  ✅ Guardado: momento_conjugado_vs_tiempo.png")

# ============================================================================
# Gráfica 3: Errores relativos vs Tiempo
# ============================================================================
println("📊 Generando gráfica de errores relativos...")

# Calcular errores relativos en cada punto
errors_E = abs.(energy .- E_initial) ./ E_initial
errors_P = abs.(conjugate_momentum .- P_initial) ./ abs(P_initial)

p3 = plot(
    xlabel = "Tiempo (s)",
    ylabel = "Error Relativo",
    title = "Evolución de Errores de Conservación",
    yscale = :log10,
    size = (1000, 600),
    dpi = 150,
    legend = :topleft
)

plot!(p3, time, errors_E,
      label = "Energía",
      linewidth = 2,
      color = :blue)

plot!(p3, time, errors_P,
      label = "Momento Conjugado",
      linewidth = 2,
      color = :purple)

# Líneas de referencia
hline!(p3, [1e-6], linestyle = :dash, color = :green, linewidth = 1, label = "Excelente (1e-6)")
hline!(p3, [1e-4], linestyle = :dash, color = :orange, linewidth = 1, label = "Bueno (1e-4)")
hline!(p3, [1e-2], linestyle = :dash, color = :red, linewidth = 1, label = "Aceptable (1e-2)")

archivo_err = joinpath(dir_resultados, "errores_vs_tiempo.png")
savefig(p3, archivo_err)
println("  ✅ Guardado: errores_vs_tiempo.png")

println()
println("="^70)
println("✅ GRÁFICAS GENERADAS")
println("="^70)
println()
println("Archivos creados en: $dir_resultados")
println("  📈 energia_vs_tiempo.png")
println("  📈 momento_conjugado_vs_tiempo.png")
println("  📈 errores_vs_tiempo.png")
println()
println("Abre las imágenes para visualizar la conservación.")
println()
println("="^70)
