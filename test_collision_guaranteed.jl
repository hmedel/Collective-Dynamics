"""
Test de colisión GARANTIZADA entre 2 partículas
Con partículas grandes para asegurar colisión
"""

using Pkg
Pkg.activate(".")

using CollectiveDynamics
using Printf

function test_collision()
    println("="^70)
    println("TEST: Colisión garantizada entre 2 partículas")
    println("="^70)

    # Parámetros
    a, b = 2.0, 1.0
    dt = 1e-4  # dt más grande para evitar problemas numéricos

    # Crear DOS partículas GRANDES en posiciones CERCANAS
    # Partícula 1: en π/4
    p1 = initialize_particle(1, 1.0, 0.4, π/4, 0.8, a, b)
    # Partícula 2: muy cerca, moviéndose hacia p1
    p2 = initialize_particle(2, 1.0, 0.4, π/4 + 0.4, -0.8, a, b)

    particles = [p1, p2]

    println("\n📍 Configuración inicial:")
    println("  Partícula 1: θ=$(p1.θ), θ_dot=$(p1.θ_dot), radio=$(p1.radius)")
    println("  Partícula 2: θ=$(p2.θ), θ_dot=$(p2.θ_dot), radio=$(p2.radius)")
    println("  Separación angular: $(abs(p2.θ - p1.θ))")
    println("  Suma de radios: $(p1.radius + p2.radius)")

    # Energía inicial
    E0 = total_energy(particles, a, b)
    println("\n⚡ Energía inicial: E₀ = $E0")

    # Simular por pasos cortos hasta detectar colisión
    n_collisions_total = 0
    E_before_collision = 0.0
    E_after_collision = 0.0

    for step in 1:100
        # Paso 1: Integrar
        for i in 1:length(particles)
            p = particles[i]
            θ_new, θ_dot_new = forest_ruth_step_ellipse(p.θ, p.θ_dot, dt, a, b)
            particles[i] = update_particle(p, θ_new, θ_dot_new, a, b)
        end

        # Energía antes de resolver colisiones
        E_before = total_energy(particles, a, b)

        # Paso 2: Resolver colisiones
        n_coll, conserved_frac = resolve_all_collisions!(
            particles, a, b;
            method=:simple,
            dt=dt,
            tolerance=1e-8
        )

        # Energía después de resolver colisiones
        E_after = total_energy(particles, a, b)

        if n_coll > 0
            println("\n💥 COLISIÓN DETECTADA en paso $step")
            println("  Energía antes:   E = $(E_before)")
            println("  Energía después: E = $(E_after)")
            println("  ΔE = $(abs(E_after - E_before))")
            println("  ΔE/E₀ = $(abs(E_after - E_before)/E0)")
            println("  Conservada: $(conserved_frac)")

            E_before_collision = E_before
            E_after_collision = E_after
            n_collisions_total += n_coll
        end

        if step % 20 == 0
            E = total_energy(particles, a, b)
            sep = abs(particles[2].θ - particles[1].θ)
            println(@sprintf("  Paso %3d: E=%.8f, separación=%.4f, colisiones=%d",
                    step, E, sep, n_coll))
        end
    end

    # Resultado final
    E_final = total_energy(particles, a, b)
    ΔE_total = abs(E_final - E0)
    rel_error = ΔE_total / E0

    println("\n" * "="^70)
    println("📊 RESULTADO:")
    println("  Colisiones totales: $n_collisions_total")
    println("\n  Energía inicial:  E₀ = $E0")
    println("  Energía final:    Ef = $E_final")
    println("  Error total:      ΔE/E₀ = $rel_error")

    if n_collisions_total > 0
        println("\n  Durante la colisión:")
        println("    ΔE por colisión = $(abs(E_after_collision - E_before_collision))")
        println("    ΔE/E₀ colisión  = $(abs(E_after_collision - E_before_collision)/E0)")
    end
    println("="^70)

    # Evaluación
    if n_collisions_total == 0
        println("\n❌ PROBLEMA: No hubo colisiones!")
        println("   Aumentar radios de partículas o reducir separación inicial")
    elseif rel_error < 1e-6
        println("\n✅ EXCELENTE: Conservación total < 1e-6")
    elseif rel_error < 1e-4
        println("\n✅ BUENO: Conservación total < 1e-4")
    else
        println("\n⚠️  ERROR ALTO: Conservación total > 1e-4")
    end

    return (n_collisions_total, rel_error)
end

# Ejecutar test
test_collision()
