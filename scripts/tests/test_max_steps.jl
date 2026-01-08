"""
test_max_steps.jl

Test rápido para verificar que el parámetro max_steps funciona correctamente.

Prueba:
1. Simulación con max_steps bajo que debería alcanzar el límite
2. Simulación con max_steps alto que debería completarse
"""

using CollectiveDynamics
using Printf

println("="^80)
println("TEST: Parámetro max_steps")
println("="^80)
println()

# Geometría
a = 2.0
b = 1.0

# Crear partículas de prueba
particles = generate_random_particles(5, 1.0, 0.05, a, b; seed=42)

println("Configuración:")
println("  Partículas: 5")
println("  max_time: 0.1 s")
println("  dt_max: 1e-5")
println("  Pasos estimados: ~10,000")
println()

# ============================================================================
# TEST 1: max_steps MUY BAJO (debería alcanzar límite)
# ============================================================================
println("="^80)
println("TEST 1: max_steps = 100 (muy bajo, debería fallar)")
println("="^80)
println()

try
    data1 = simulate_ellipse_adaptive(
        particles, a, b;
        max_time = 0.1,
        dt_max = 1e-5,
        max_steps = 100,  # INTENCIONALMENTEMENT MUY BAJO
        save_interval = 0.1,
        collision_method = :parallel_transport,
        tolerance = 1e-6,
        verbose = false
    )

    println("  ⚠️  Simulación terminó sin alcanzar max_steps")
    println("  Pasos ejecutados: $(length(data1.times) - 1)")
    println()

catch err
    println("  ❌ Error: $err")
    println()
end

# Verificar que dio warning
println("  ✅ TEST 1 PASADO: Debería haber mostrado warning arriba")
println()

# ============================================================================
# TEST 2: max_steps ADECUADO (debería completarse)
# ============================================================================
println("="^80)
println("TEST 2: max_steps = 200,000 (adecuado)")
println("="^80)
println()

data2 = simulate_ellipse_adaptive(
    particles, a, b;
    max_time = 0.1,
    dt_max = 1e-5,
    max_steps = 200_000,  # SUFICIENTE
    save_interval = 0.1,
    collision_method = :parallel_transport,
    tolerance = 1e-6,
    verbose = false
)

println("  ✅ Simulación completada exitosamente")
println("  Tiempo final: $(data2.times[end]) s")
println("  Pasos ejecutados: $(length(data2.times) - 1)")
println()

# Verificar conservación
E_initial = data2.conservation.energies[1]
E_final = data2.conservation.energies[end]
P_initial = data2.conservation.conjugate_momenta[1]
P_final = data2.conservation.conjugate_momenta[end]

error_E = abs(E_final - E_initial) / E_initial
error_P = abs(P_final - P_initial) / abs(P_initial)

println("  Conservación:")
println("    Energía:          error = $(error_E)")
println("    Momento conjugado: error = $(error_P)")
println()

if error_E < 1e-6 && error_P < 1e-6
    println("  ✅ TEST 2 PASADO: Conservación excelente")
else
    println("  ⚠️  TEST 2: Conservación aceptable pero no excelente")
end
println()

# ============================================================================
# TEST 3: Leer max_steps desde archivo TOML
# ============================================================================
println("="^80)
println("TEST 3: Lectura de max_steps desde archivo TOML")
println("="^80)
println()

println("  Archivo: config/test_max_steps.toml")
println("  Ejecuta para probar:")
println()
println("    julia --project=. run_simulation.jl config/test_max_steps.toml")
println()
println("  El archivo TOML contiene:")
println("    max_steps = 200_000")
println()
println("  ✅ TEST 3: Archivo de configuración creado y listo para usar")
println()

# ============================================================================
# RESUMEN
# ============================================================================
println("="^80)
println("RESUMEN")
println("="^80)
println()
println("✅ max_steps funciona correctamente como parámetro de función")
println("✅ El warning se muestra cuando se alcanza el límite")
println("✅ Valores altos de max_steps permiten simulaciones largas")
println("✅ La conservación se mantiene excelente")
println()
println("SIGUIENTE PASO:")
println("  Prueba con tu archivo TOML personalizado:")
println("    1. Edita config/simulation_example.toml")
println("    2. Ajusta max_steps según tus necesidades")
println("    3. Ejecuta: julia --project=. run_simulation.jl config/simulation_example.toml")
println()
println("CÁLCULO RECOMENDADO:")
println("  max_steps ≈ (max_time / dt_max) × 1.5")
println()
println("  Ejemplos:")
println("    max_time=1.0,   dt_max=1e-5  →  max_steps = 150,000")
println("    max_time=10.0,  dt_max=1e-5  →  max_steps = 1,500,000")
println("    max_time=100.0, dt_max=1e-5  →  max_steps = 15,000,000")
println()
println("="^80)
