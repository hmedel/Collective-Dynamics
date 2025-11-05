"""
    verify_installation.jl

Script de verificación automática para CollectiveDynamics.jl

Ejecutar con:
    julia --project=. verify_installation.jl
"""

println("""
╔════════════════════════════════════════════════════════════════════╗
║                                                                    ║
║           CollectiveDynamics.jl - Verificación de Instalación     ║
║                                                                    ║
╚════════════════════════════════════════════════════════════════════╝
""")

using Pkg
using Printf

# ============================================================================
# Estado de verificación
# ============================================================================

all_passed = true
tests_results = []

function test_step(name::String, test_func::Function)
    print(@sprintf("%-60s", name * "..."))
    try
        result = test_func()
        if result
            println(" ✅ PASS")
            push!(tests_results, (name, true, ""))
            return true
        else
            println(" ❌ FAIL")
            push!(tests_results, (name, false, "Test returned false"))
            global all_passed = false
            return false
        end
    catch e
        println(" ❌ ERROR")
        push!(tests_results, (name, false, string(e)))
        global all_passed = false
        return false
    end
end

# ============================================================================
# Tests de Verificación
# ============================================================================

println("\n🔍 VERIFICANDO INSTALACIÓN...\n")
println("━" ^ 70)

# Test 1: Versión de Julia
test_step("1. Verificar versión de Julia (≥ 1.9)") do
    version_str = string(VERSION)
    major, minor = VERSION.major, VERSION.minor
    if major > 1 || (major == 1 && minor >= 9)
        println("   → Julia v$version_str detectada")
        return true
    else
        println("   → Julia v$version_str (se requiere ≥ 1.9)")
        return false
    end
end

# Test 2: Proyecto activado
test_step("2. Verificar que el proyecto está activado") do
    if isfile("Project.toml")
        println("   → Project.toml encontrado")
        return true
    else
        println("   → Project.toml NO encontrado")
        return false
    end
end

# Test 3: Dependencias críticas
critical_packages = [
    "StaticArrays",
    "LinearAlgebra",
    "ForwardDiff",
    "Elliptic"
]

for pkg in critical_packages
    test_step("3. Cargar paquete: $pkg") do
        try
            # Intentar cargar el paquete
            if pkg == "LinearAlgebra"
                eval(:(using LinearAlgebra))
            elseif pkg == "StaticArrays"
                eval(:(using StaticArrays))
            elseif pkg == "ForwardDiff"
                eval(:(using ForwardDiff))
            elseif pkg == "Elliptic"
                eval(:(using Elliptic))
            end
            return true
        catch
            return false
        end
    end
end

# Test 4: Cargar módulo principal
test_step("4. Cargar módulo CollectiveDynamics") do
    # Asegurarse de que src/ esté en LOAD_PATH
    if !("src" in LOAD_PATH)
        push!(LOAD_PATH, joinpath(pwd(), "src"))
    end

    try
        eval(:(using CollectiveDynamics))
        return true
    catch e
        println("   → Error: $e")
        return false
    end
end

# Test 5: Verificar funciones principales
using CollectiveDynamics

test_step("5. Verificar función: metric_ellipse") do
    try
        result = metric_ellipse(π/4, 2.0, 1.0)
        return isfinite(result) && result > 0
    catch
        return false
    end
end

test_step("6. Verificar función: christoffel_ellipse") do
    try
        result = christoffel_ellipse(π/4, 2.0, 1.0)
        return isfinite(result)
    catch
        return false
    end
end

test_step("7. Verificar función: forest_ruth_step_ellipse") do
    try
        θ, θ_dot = forest_ruth_step_ellipse(0.0, 1.0, 0.01, 2.0, 1.0)
        return isfinite(θ) && isfinite(θ_dot)
    catch
        return false
    end
end

test_step("8. Verificar función: generate_random_particles") do
    try
        particles = generate_random_particles(5, 1.0, 0.05, 2.0, 1.0)
        return length(particles) == 5
    catch
        return false
    end
end

test_step("9. Verificar función: simulate_ellipse") do
    try
        particles = generate_random_particles(3, 1.0, 0.05, 2.0, 1.0)
        data = simulate_ellipse(
            particles, 2.0, 1.0;
            n_steps=10,
            dt=1e-6,
            verbose=false
        )
        return length(data.particles) >= 2
    catch e
        println("   → Error: $e")
        return false
    end
end

# Test 10: Conservación de energía (test crítico)
test_step("10. Verificar conservación de energía (test rápido)") do
    try
        particles = generate_random_particles(5, 1.0, 0.05, 2.0, 1.0)
        data = simulate_ellipse(
            particles, 2.0, 1.0;
            n_steps=100,
            dt=1e-6,
            collision_method=:parallel_transport,
            verbose=false
        )

        E_analysis = analyze_energy_conservation(data.conservation)

        # Verificar que el error relativo sea razonable
        if E_analysis.max_rel_error < 0.01  # 1% tolerancia para test rápido
            println("   → Error relativo: $(E_analysis.max_rel_error)")
            return true
        else
            println("   → Error relativo muy alto: $(E_analysis.max_rel_error)")
            return false
        end
    catch e
        println("   → Error: $e")
        return false
    end
end

# ============================================================================
# Resumen
# ============================================================================

println("\n" * "━" ^ 70)
println("\n📊 RESUMEN DE VERIFICACIÓN\n")

n_passed = count(x -> x[2], tests_results)
n_total = length(tests_results)

if all_passed
    println("""
    ╔════════════════════════════════════════════════════════════════════╗
    ║                                                                    ║
    ║                  ✅ TODAS LAS VERIFICACIONES PASARON               ║
    ║                                                                    ║
    ║        CollectiveDynamics.jl está correctamente instalado         ║
    ║                                                                    ║
    ╚════════════════════════════════════════════════════════════════════╝
    """)

    println("\n🚀 PRÓXIMOS PASOS:")
    println("━" ^ 70)
    println("1. Ejecutar tests completos:")
    println("   julia --project=. test/runtests.jl")
    println()
    println("2. Ejecutar ejemplo de simulación:")
    println("   julia --project=. examples/ellipse_simulation.jl")
    println()
    println("3. Modo interactivo:")
    println("   julia --project=.")
    println("   julia> using CollectiveDynamics")
    println("   julia> version_info()")
    println("━" ^ 70)

else
    println("""
    ╔════════════════════════════════════════════════════════════════════╗
    ║                                                                    ║
    ║               ❌ ALGUNAS VERIFICACIONES FALLARON                   ║
    ║                                                                    ║
    ║                  ($n_passed/$n_total tests pasaron)                       ║
    ║                                                                    ║
    ╚════════════════════════════════════════════════════════════════════╝
    """)

    println("\n❌ TESTS QUE FALLARON:")
    println("━" ^ 70)
    for (name, passed, error) in tests_results
        if !passed
            println("  • $name")
            if !isempty(error)
                println("    Error: $error")
            end
        end
    end
    println("━" ^ 70)

    println("\n🔧 SOLUCIONES SUGERIDAS:")
    println("━" ^ 70)
    println("1. Reinstalar dependencias:")
    println("   julia --project=. -e 'using Pkg; Pkg.resolve(); Pkg.instantiate()'")
    println()
    println("2. Actualizar Julia a versión 1.9+:")
    println("   https://julialang.org/downloads/")
    println()
    println("3. Verificar que estás en el directorio correcto:")
    println("   cd Collective-Dynamics")
    println("   git checkout claude/incomplete-task-recovery-011CUq95bFhkWKMNKHXgZaVN")
    println()
    println("4. Consultar INSTALL.md para instrucciones detalladas")
    println("━" ^ 70)
end

println("\n📞 ¿Necesitas ayuda?")
println("━" ^ 70)
println("  • Abre un issue: https://github.com/hmedel/Collective-Dynamics/issues")
println("  • Consulta INSTALL.md para más detalles")
println("  • Contacto: hmedel@tec.mx")
println("━" ^ 70)

# Retornar código de salida apropiado
if all_passed
    println("\n✅ Verificación completa - Sistema listo para usar")
    exit(0)
else
    println("\n❌ Verificación falló - Revisa los errores arriba")
    exit(1)
end
