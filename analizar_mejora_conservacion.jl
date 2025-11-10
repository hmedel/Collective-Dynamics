"""
analizar_mejora_conservacion.jl

Analiza cómo mejorar la conservación en tu simulación.

Uso:
    julia --project=. analizar_mejora_conservacion.jl results/simulation_XXXXXX/

Lee los resultados actuales y sugiere parámetros mejorados.
"""

using DelimitedFiles
using Printf
using TOML

# Verificar argumentos
if length(ARGS) < 1
    println("❌ Error: Debes proporcionar el directorio de resultados")
    println()
    println("Uso:")
    println("  julia --project=. analizar_mejora_conservacion.jl results/simulation_XXXXXX/")
    exit(1)
end

dir_resultados = ARGS[1]

println("="^80)
println("ANÁLISIS DE MEJORA DE CONSERVACIÓN")
println("="^80)
println()

# ============================================================================
# Cargar configuración usada
# ============================================================================
config_file = joinpath(dir_resultados, "config_used.toml")

if !isfile(config_file)
    println("❌ Error: No se encontró config_used.toml")
    exit(1)
end

config = TOML.parsefile(config_file)

# Parámetros actuales
a = config["geometry"]["a"]
b = config["geometry"]["b"]
max_time = config["simulation"]["max_time"]
dt_max_actual = config["simulation"]["dt_max"]
tolerance_actual = config["simulation"]["tolerance"]
collision_method = config["simulation"]["collision_method"]

println("CONFIGURACIÓN ACTUAL:")
println("-"^80)
println("  Geometría: a = $a, b = $b")
println("  Tiempo total: $max_time s")
println("  dt_max: $dt_max_actual")
println("  Tolerancia: $tolerance_actual")
println("  Método colisión: $collision_method")
println()

# ============================================================================
# Cargar resultados de conservación
# ============================================================================
archivo_cons = joinpath(dir_resultados, "conservation.csv")
data, _ = readdlm(archivo_cons, ',', Float64, '\n'; header=true)

energy = data[:, 2]
conjugate_momentum = data[:, 3]

E_initial = energy[1]
E_final = energy[end]
P_initial = conjugate_momentum[1]
P_final = conjugate_momentum[end]

error_E = abs(E_final - E_initial) / E_initial
error_P = abs(P_final - P_initial) / abs(P_initial)

println("ERRORES ACTUALES:")
println("-"^80)
println(@sprintf("  Error energía:          %.3e (%.4f%%)", error_E, error_E*100))
println(@sprintf("  Error momento conjugado: %.3e (%.4f%%)", error_P, error_P*100))
println()

# Clasificar
function clasificar_error(err)
    if err < 1e-6
        return "✅ EXCELENTE"
    elseif err < 1e-4
        return "✅ BUENO"
    elseif err < 1e-2
        return "⚠️  ACEPTABLE"
    else
        return "❌ MALO"
    end
end

println("  Estado energía:          $(clasificar_error(error_E))")
println("  Estado momento conjugado: $(clasificar_error(error_P))")
println()

# ============================================================================
# Leer estadísticas de colisiones
# ============================================================================
archivo_summary = joinpath(dir_resultados, "summary.txt")
n_collisions = 0

if isfile(archivo_summary)
    for line in eachline(archivo_summary)
        if contains(line, "Colisiones totales:")
            n_collisions = parse(Int, split(line, ":")[2])
            break
        end
    end
end

tiene_colisiones = n_collisions > 0

println("COLISIONES:")
println("-"^80)
println("  Total de colisiones: $n_collisions")
println("  Sistema: $(tiene_colisiones ? "Con colisiones" : "Sin colisiones")")
println()

# ============================================================================
# Análisis y recomendaciones
# ============================================================================
println("="^80)
println("ANÁLISIS Y RECOMENDACIONES")
println("="^80)
println()

# Determinar causa principal del error
if !tiene_colisiones
    # Sin colisiones - error viene del integrador
    println("📊 DIAGNÓSTICO:")
    println("  • Sin colisiones → error viene del integrador Forest-Ruth")
    println("  • El error escala como O(dt⁴)")
    println()

    # Calcular dt_max necesario para diferentes niveles
    function dt_para_error_objetivo(error_actual, dt_actual, error_objetivo)
        # error ∝ dt⁴, entonces: error_nuevo/error_actual = (dt_nuevo/dt_actual)⁴
        ratio = (error_objetivo / error_actual)^(1/4)
        return dt_actual * ratio
    end

    println("🎯 PARA MEJORAR LA CONSERVACIÓN:")
    println()

    # Opción 1: Excelente
    if error_E > 1e-6
        dt_excelente = dt_para_error_objetivo(error_E, dt_max_actual, 1e-6)
        factor_excelente = dt_max_actual / dt_excelente
        pasos_excelente = Int(ceil(max_time / dt_excelente * 1.5))

        println("Opción 1: CONSERVACIÓN EXCELENTE (error < 1e-6)")
        println("-"^80)
        println(@sprintf("  dt_max recomendado: %.2e", dt_excelente))
        println(@sprintf("  Factor de reducción: %.1fx más pequeño", factor_excelente))
        println(@sprintf("  Pasos estimados: ~%d", pasos_excelente))
        println(@sprintf("  max_steps sugerido: %d", pasos_excelente))
        println(@sprintf("  Tiempo de cómputo estimado: %.1fx más lento", factor_excelente))
        println()
    end

    # Opción 2: Buena
    if error_E > 1e-4
        dt_bueno = dt_para_error_objetivo(error_E, dt_max_actual, 1e-4)
        factor_bueno = dt_max_actual / dt_bueno
        pasos_bueno = Int(ceil(max_time / dt_bueno * 1.5))

        println("Opción 2: CONSERVACIÓN BUENA (error < 1e-4)")
        println("-"^80)
        println(@sprintf("  dt_max recomendado: %.2e", dt_bueno))
        println(@sprintf("  Factor de reducción: %.1fx más pequeño", factor_bueno))
        println(@sprintf("  Pasos estimados: ~%d", pasos_bueno))
        println(@sprintf("  max_steps sugerido: %d", pasos_bueno))
        println(@sprintf("  Tiempo de cómputo estimado: %.1fx más lento", factor_bueno))
        println()
    end

else
    # Con colisiones - más complejo
    println("📊 DIAGNÓSTICO:")
    println("  • Sistema con colisiones ($n_collisions total)")
    println("  • Error puede venir de:")
    println("    1. Integrador Forest-Ruth (error ∝ dt⁴)")
    println("    2. Resolución de colisiones (error ∝ tolerancia)")
    println()

    println("🎯 PARA MEJORAR LA CONSERVACIÓN:")
    println()

    println("Opción 1: Reducir dt_max")
    println("-"^80)
    dt_reducido = dt_max_actual / 10
    println(@sprintf("  dt_max actual:      %.2e", dt_max_actual))
    println(@sprintf("  dt_max recomendado: %.2e (10× más pequeño)", dt_reducido))
    println("  Mejora esperada: ~10,000× en error del integrador")
    println()

    println("Opción 2: Reducir tolerancia en colisiones")
    println("-"^80)
    tol_reducida = tolerance_actual / 10
    println(@sprintf("  Tolerancia actual:      %.2e", tolerance_actual))
    println(@sprintf("  Tolerancia recomendada: %.2e (10× más estricta)", tol_reducida))
    println("  Mejora esperada: Mejor conservación en colisiones")
    println()

    println("Opción 3: Combinación (RECOMENDADO)")
    println("-"^80)
    dt_combinado = dt_max_actual / 5
    tol_combinada = tolerance_actual / 10
    println(@sprintf("  dt_max: %.2e → %.2e", dt_max_actual, dt_combinado))
    println(@sprintf("  tolerance: %.2e → %.2e", tolerance_actual, tol_combinada))
    println("  Mejora esperada: Mejor en ambos aspectos")
    println()
end

# ============================================================================
# Generar archivo de configuración mejorado
# ============================================================================
println("="^80)
println("ARCHIVO DE CONFIGURACIÓN MEJORADO")
println("="^80)
println()

config_mejorado_file = joinpath(dir_resultados, "config_mejorado.toml")

# Calcular parámetros mejorados
if !tiene_colisiones
    # Sin colisiones: reducir dt_max para error < 1e-6
    dt_nuevo = dt_para_error_objetivo(error_E, dt_max_actual, 1e-6)
    tol_nueva = tolerance_actual
else
    # Con colisiones: reducir ambos
    dt_nuevo = dt_max_actual / 5
    tol_nueva = tolerance_actual / 10
end

max_steps_nuevo = Int(ceil(max_time / dt_nuevo * 2.0))

# Crear configuración mejorada
config_mejorado = copy(config)
config_mejorado["simulation"]["dt_max"] = dt_nuevo
config_mejorado["simulation"]["tolerance"] = tol_nueva
config_mejorado["simulation"]["max_steps"] = max_steps_nuevo

# Guardar
open(config_mejorado_file, "w") do io
    TOML.print(io, config_mejorado)
end

println("✅ Configuración mejorada guardada en:")
println("   $config_mejorado_file")
println()
println("Para ejecutar con parámetros mejorados:")
println("   julia --project=. run_simulation.jl $config_mejorado_file")
println()

# ============================================================================
# Resumen
# ============================================================================
println("="^80)
println("RESUMEN DE CAMBIOS PROPUESTOS")
println("="^80)
println()
println(@sprintf("dt_max:    %.2e → %.2e (factor %.1fx)",
                 dt_max_actual, dt_nuevo, dt_max_actual/dt_nuevo))
println(@sprintf("tolerance: %.2e → %.2e (factor %.1fx)",
                 tolerance_actual, tol_nueva, tolerance_actual/tol_nueva))
println(@sprintf("max_steps: %d → %d",
                 get(config["simulation"], "max_steps", 10_000_000), max_steps_nuevo))
println()
println("Mejora estimada:")
if !tiene_colisiones
    mejora = (dt_max_actual / dt_nuevo)^4
    println(@sprintf("  Error esperado: %.2e → %.2e (mejora %.0fx)",
                     error_E, error_E/mejora, mejora))
else
    println("  Depende de cuánto contribuye cada componente")
    println("  Reducción significativa esperada en ambos errores")
end
println()
println("="^80)
