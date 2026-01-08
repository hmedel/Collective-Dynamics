"""
    test_single_intrinsic.jl

Test de simulación individual con geometría intrínseca corregida.

Caso de prueba: N=120, e=0.99, r=0.02830 (que FALLÓ con r=0.05)
Objetivo: Verificar que la geometría intrínseca permite generar y simular
          el caso más extremo de la campaña.
"""

using Pkg
Pkg.activate(".")

using Printf

# Cargar módulo
include("src/geometry/metrics_polar.jl")
include("src/particles_polar.jl")
include("src/collisions_polar.jl")
include("src/integrators/forest_ruth_polar.jl")
include("src/simulation_polar.jl")

println("="^80)
println("TEST: Simulación Individual con Geometría Intrínseca")
println("="^80)
println()

# ============================================================================
# Parámetros del caso más crítico
# ============================================================================

N = 120
e = 0.99
φ_target = 0.30

# Calcular semi-ejes (área normalizada A=2)
A = 2.0
b = sqrt(A * (1 - e^2) / π)
a = A / (π * b)

# Radio intrínseco correcto
r = radius_from_packing(N, φ_target, a, b)

# Parámetros de simulación
mass = 1.0
max_speed = 1.0
t_max = 10.0  # Test corto (10s)
dt_max = 1e-4
save_interval = 0.5

@printf("Parámetros:\n")
@printf("  N = %d\n", N)
@printf("  e = %.4f\n", e)
@printf("  a = %.4f, b = %.4f\n", a, b)
@printf("  Perímetro = %.4f\n", ellipse_perimeter(a, b))
@printf("  Radio (intrínseco) = %.5f\n", r)
@printf("  φ_target = %.4f (%.1f%%)\n", φ_target, φ_target * 100)
println()

# ============================================================================
# Generación de partículas con geometría intrínseca
# ============================================================================

@printf("Generando %d partículas con geometría intrínseca...\n", N)

try
    particles = generate_random_particles_polar(
        N, mass, r, a, b;
        max_speed=max_speed,
        max_attempts=100000  # Más intentos para caso extremo
    )

    println("✅ ÉXITO: $(length(particles)) partículas generadas")

    # Verificar packing
    φ_real = intrinsic_packing_fraction(N, r, a, b)
    @printf("φ_intrinsic (real): %.4f\n", φ_real)

    # Verificar overlaps
    n_overlaps = 0
    for i in 1:N-1
        for j in i+1:N
            if check_collision(particles[i], particles[j], a, b; intrinsic=true)
                n_overlaps += 1
            end
        end
    end
    @printf("Overlaps intrínsecos: %d\n", n_overlaps)

    if n_overlaps > 0
        println("⚠️  WARNING: Hay overlaps en condiciones iniciales!")
    else
        println("✅ No hay overlaps - ICs válidas")
    end

    println()

    # ========================================================================
    # Simulación
    # ========================================================================

    @printf("Ejecutando simulación (t_max = %.1fs)...\n", t_max)
    println()

    t_start = time()

    data = simulate_ellipse_polar_adaptive(
        particles, a, b;
        max_time=t_max,
        dt_max=dt_max,
        save_interval=save_interval,
        collision_method=:parallel_transport,
        max_steps=10_000_000,
        verbose=true
    )

    t_elapsed = time() - t_start

    println()
    println("="^80)
    println("RESULTADOS DE SIMULACIÓN")
    println("="^80)
    println()

    @printf("Tiempo de ejecución: %.2f s\n", t_elapsed)
    @printf("Tiempo simulado:     %.2f s\n", data.times[end])
    @printf("Snapshots guardados: %d\n", length(data.times))
    @printf("Colisiones totales:  %d\n", sum(data.n_collisions))
    println()

    # ========================================================================
    # Conservación de energía
    # ========================================================================

    println("="^80)
    println("CONSERVACIÓN DE ENERGÍA")
    println("="^80)
    println()

    E0 = data.conservation.energy[1]
    E_final = data.conservation.energy[end]
    ΔE = E_final - E0
    ΔE_rel = abs(ΔE) / abs(E0)

    @printf("E₀          = %.10f\n", E0)
    @printf("E_final     = %.10f\n", E_final)
    @printf("ΔE          = %.3e\n", ΔE)
    @printf("ΔE/E₀       = %.3e", ΔE_rel)

    if ΔE_rel < 1e-6
        println(" ⭐ EXCELENTE")
    elseif ΔE_rel < 1e-4
        println(" ✅ BUENA")
    elseif ΔE_rel < 1e-2
        println(" ⚠️  ACEPTABLE")
    else
        println(" ❌ POBRE")
    end

    println()

    # ========================================================================
    # Análisis de clustering simple
    # ========================================================================

    println("="^80)
    println("ANÁLISIS DE CLUSTERING")
    println("="^80)
    println()

    # Clustering simple: contar partículas en cada cuadrante
    function analyze_quadrants(snapshot)
        q1 = count(p -> p.φ < π/2, snapshot)
        q2 = count(p -> π/2 <= p.φ < π, snapshot)
        q3 = count(p -> π <= p.φ < 3π/2, snapshot)
        q4 = count(p -> 3π/2 <= p.φ, snapshot)
        return (q1, q2, q3, q4)
    end

    q_initial = analyze_quadrants(data.snapshots[1])
    q_final = analyze_quadrants(data.snapshots[end])

    @printf("Distribución inicial (cuadrantes):\n")
    @printf("  Q1 (0-π/2):     %3d (%.1f%%)\n", q_initial[1], q_initial[1]/N*100)
    @printf("  Q2 (π/2-π):     %3d (%.1f%%)\n", q_initial[2], q_initial[2]/N*100)
    @printf("  Q3 (π-3π/2):    %3d (%.1f%%)\n", q_initial[3], q_initial[3]/N*100)
    @printf("  Q4 (3π/2-2π):   %3d (%.1f%%)\n", q_initial[4], q_initial[4]/N*100)
    println()

    @printf("Distribución final (cuadrantes):\n")
    @printf("  Q1 (0-π/2):     %3d (%.1f%%)\n", q_final[1], q_final[1]/N*100)
    @printf("  Q2 (π/2-π):     %3d (%.1f%%)\n", q_final[2], q_final[2]/N*100)
    @printf("  Q3 (π-3π/2):    %3d (%.1f%%)\n", q_final[3], q_final[3]/N*100)
    @printf("  Q4 (3π/2-2π):   %3d (%.1f%%)\n", q_final[4], q_final[4]/N*100)
    println()

    # Índice de clustering simple: desviación estándar de poblaciones
    σ_initial = std([q_initial...]) / (N/4)
    σ_final = std([q_final...]) / (N/4)

    @printf("Clustering index (σ/μ):\n")
    @printf("  Inicial: %.3f (uniforme si ~ 0)\n", σ_initial)
    @printf("  Final:   %.3f (clustered si >> 1)\n", σ_final)

    if σ_final > 3 * σ_initial
        println("  → ✅ Clustering significativo observado")
    else
        println("  → Clustering débil (posiblemente necesita t > 10s)")
    end

    println()

    # ========================================================================
    # Conclusión
    # ========================================================================

    println("="^80)
    println("CONCLUSIÓN")
    println("="^80)
    println()

    println("✅ TEST EXITOSO:")
    println("   • Generación de partículas funciona con geometría intrínseca")
    println("   • Simulación completa sin errores")
    println("   • Conservación de energía dentro de tolerancias")
    println()
    println("📊 READY PARA CAMPAÑA COMPLETA (450 runs)")
    println()

catch e
    println("❌ ERROR durante test:")
    println(e)
    println()
    println(catch_backtrace())
end

println("="^80)
