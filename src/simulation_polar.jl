"""
    simulation_polar.jl

Sistema de simulación adaptativa para partículas en coordenadas polares φ.

Similar a simulate_ellipse_adaptive() pero usando la parametrización polar:
- r(φ) = ab/√(a²sin²φ + b²cos²φ)
- Métrica: g_φφ = r² + (dr/dφ)²
- Conserva: E = Σ (1/2) m g_φφ φ̇²
"""

using StaticArrays
using LinearAlgebra
using Statistics
using Printf

include("particles_polar.jl")
include("geometry/metrics_polar.jl")
include("geometry/christoffel_polar.jl")
include("integrators/forest_ruth_polar.jl")
include("collisions_polar.jl")

# ============================================================================
# Estructura de datos para conservación
# ============================================================================

"""
    ConservationDataPolar{T}

Almacena datos de conservación para coordenadas polares.
"""
mutable struct ConservationDataPolar{T <: AbstractFloat}
    times::Vector{T}
    energies::Vector{T}
    energy_errors::Vector{T}

    function ConservationDataPolar{T}() where {T <: AbstractFloat}
        new{T}(T[], T[], T[])
    end
end

"""
    record_conservation_polar!(data, particles, t, a, b)

Registra energía total y error relativo en tiempo t.
"""
function record_conservation_polar!(
    data::ConservationDataPolar{T},
    particles::Vector{ParticlePolar{T}},
    t::T,
    a::T,
    b::T
) where {T <: AbstractFloat}

    # Calcular energía total
    E_total = zero(T)
    for p in particles
        E_total += kinetic_energy(p, a, b)
    end

    # Calcular error relativo (comparado con t=0)
    E_error = if isempty(data.energies)
        zero(T)
    else
        abs(E_total - data.energies[1]) / data.energies[1]
    end

    push!(data.times, t)
    push!(data.energies, E_total)
    push!(data.energy_errors, E_error)

    return nothing
end

# ============================================================================
# Estructura de datos de simulación
# ============================================================================

"""
    SimulationDataPolar{T}

Resultados de simulación en coordenadas polares.
"""
struct SimulationDataPolar{T <: AbstractFloat}
    particles_history::Vector{Vector{ParticlePolar{T}}}
    conservation::ConservationDataPolar{T}
    times::Vector{T}
    params::Dict{Symbol, Any}
    dt_history::Vector{T}
    n_collisions::Vector{Int}
end

# ============================================================================
# Simulación adaptativa principal
# ============================================================================

"""
    simulate_ellipse_polar_adaptive(particles, a, b; kwargs...)

Simula partículas en elipse usando coordenadas polares φ con timesteps adaptativos.

# Parámetros
- `particles`: Vector{ParticlePolar{T}} - Partículas iniciales
- `a`, `b`: Semi-ejes de la elipse

# Opciones
- `max_time`: Tiempo total de simulación (default: 1.0)
- `dt_max`: Timestep máximo (default: 1e-5)
- `dt_min`: Timestep mínimo (default: 1e-10)
- `save_interval`: Intervalo para guardar datos (default: 0.01)
- `collision_method`: :parallel_transport o :simple (default: :parallel_transport)
- `max_steps`: Máximo número de pasos (default: 10_000_000)
- `use_projection`: Usar projection methods (default: false)
- `projection_interval`: Cada cuántos pasos proyectar (default: 100)
- `projection_tolerance`: Tolerancia para projection (default: 1e-12)
- `verbose`: Mostrar progreso (default: true)

# Retorna
- `SimulationDataPolar{T}` con historial completo

# Algoritmo
1. Encontrar próxima colisión (time_to_collision_polar)
2. Integrar hasta colisión o dt_max (forest_ruth_polar)
3. Resolver colisión si ocurre (resolve_collision_polar)
4. Aplicar projection methods si está habilitado
5. Guardar datos cada save_interval
6. Repetir hasta max_time
"""
function simulate_ellipse_polar_adaptive(
    particles_initial::Vector{ParticlePolar{T}},
    a::T,
    b::T;
    max_time::T = T(1.0),
    dt_max::T = T(1e-5),
    dt_min::T = T(1e-10),
    save_interval::T = T(0.01),
    collision_method::Symbol = :parallel_transport,
    max_steps::Int = 10_000_000,
    use_projection::Bool = false,
    projection_interval::Int = 100,
    projection_tolerance::T = T(1e-12),
    verbose::Bool = true
) where {T <: AbstractFloat}

    # Copiar partículas para no modificar el input
    particles = copy(particles_initial)

    # Inicializar estructuras de datos con PREALLOCACIÓN
    expected_saves = ceil(Int, max_time / save_interval) + 100
    expected_steps = ceil(Int, max_time / dt_max) * 2 + 10000

    particles_history = Vector{Vector{ParticlePolar{T}}}(undef, expected_saves)
    times_saved = Vector{T}(undef, expected_saves)
    n_collisions_vec = Vector{Int}(undef, expected_steps)
    dt_history = Vector{T}(undef, expected_steps)

    conservation_data = ConservationDataPolar{T}()

    # Guardar estado inicial
    save_idx = 1
    step_idx = 0
    particles_history[save_idx] = copy(particles)
    times_saved[save_idx] = zero(T)
    record_conservation_polar!(conservation_data, particles, zero(T), a, b)
    save_idx += 1

    # Guardar energía inicial para projection
    E0 = zero(T)
    if use_projection
        for p in particles
            E0 += kinetic_energy(p, a, b)
        end
    end

    t = zero(T)
    t_next_save = save_interval
    step = 0

    if verbose
        println("=" ^ 70)
        println("SIMULACIÓN POLAR CON TIEMPOS ADAPTATIVOS")
        println("=" ^ 70)
        println("Partículas:        ", length(particles))
        println("Tiempo total:      ", max_time)
        println("dt_max:            ", dt_max)
        println("dt_min:            ", dt_min)
        println("Método colisión:   ", collision_method)
        println("Semi-ejes (a, b):  ($a, $b)")
        println("Parametrización:   Polar (φ)")
        if use_projection
            println("Projection:        Activado (cada $projection_interval pasos)")
            println("Tolerancia proj:   ", projection_tolerance)
        end
        println("=" ^ 70)
    end

    # Loop principal de simulación
    while t < max_time
        step += 1
        step_idx += 1

        # Verificar si necesitamos expandir arrays
        if step_idx > length(dt_history)
            resize!(dt_history, step_idx + 1000)
            resize!(n_collisions_vec, step_idx + 1000)
        end

        # Paso 1: Encontrar próxima colisión (usando geometría intrínseca)
        i_col, j_col, t_col = find_next_collision_polar(particles, a, b, dt_max; intrinsic=true)

        # Determinar timestep
        dt = if i_col > 0 && t_col < dt_max
            max(t_col, dt_min)  # Usar tiempo de colisión (con mínimo)
        else
            dt_max  # No hay colisión cercana
        end

        # No exceder max_time
        dt = min(dt, max_time - t)

        # Guardar dt usado
        dt_history[step_idx] = dt

        # Paso 2: Integrar todas las partículas
        for i in 1:length(particles)
            p = particles[i]
            particles[i] = integrate_particle_polar(p, dt, a, b)
        end

        t += dt

        # Paso 3: Resolver colisiones si hay
        n_coll = 0

        if i_col > 0 && t_col <= dt + eps(T)
            # Hay colisión, resolverla
            p1_new, p2_new = resolve_collision_polar(
                particles[i_col],
                particles[j_col],
                a, b;
                method = collision_method
            )

            particles[i_col] = p1_new
            particles[j_col] = p2_new
            n_coll = 1
        end

        # Guardar colisiones
        n_collisions_vec[step_idx] = n_coll

        # Paso 3.5: Aplicar projection si está habilitado
        if use_projection && (step % projection_interval == 0)
            project_energy_polar!(particles, E0, a, b;
                                tolerance = projection_tolerance,
                                max_iter = 10)
        end

        # Paso 4: Guardar datos si es tiempo
        if t >= t_next_save || abs(t - max_time) < eps(T)
            # Verificar si necesitamos expandir array de saves
            if save_idx > length(particles_history)
                resize!(particles_history, save_idx + 100)
                resize!(times_saved, save_idx + 100)
            end

            particles_history[save_idx] = copy(particles)
            times_saved[save_idx] = t
            record_conservation_polar!(conservation_data, particles, t, a, b)
            t_next_save += save_interval

            if verbose && (save_idx % 10 == 0)
                progress = 100 * t / max_time
                avg_dt = mean(@view dt_history[max(1, step_idx-99):step_idx])
                total_collisions = sum(@view n_collisions_vec[1:step_idx])
                E_current = conservation_data.energies[end]
                E_error = conservation_data.energy_errors[end]

                println(@sprintf("Progreso: %.1f%% | t = %.6f | dt_avg = %.2e | Colisiones: %d | ΔE/E₀ = %.2e",
                        progress, t, avg_dt, total_collisions, E_error))
            end

            save_idx += 1
        end

        # Seguridad: evitar loops infinitos
        if step > max_steps
            @warn "Alcanzado límite de pasos ($max_steps). Deteniendo simulación."
            break
        end
    end

    # Truncar arrays al tamaño real
    resize!(particles_history, save_idx - 1)
    resize!(times_saved, save_idx - 1)
    resize!(dt_history, step_idx)
    resize!(n_collisions_vec, step_idx)

    if verbose
        println("=" ^ 70)
        println("SIMULACIÓN COMPLETADA")
        println("=" ^ 70)
        println("Pasos totales:       ", step)
        println("Colisiones totales:  ", sum(n_collisions_vec))
        println("dt promedio:         ", mean(dt_history))
        println("dt mínimo:           ", minimum(dt_history))
        println("dt máximo:           ", maximum(dt_history))

        # Resumen de conservación
        E_final_error = conservation_data.energy_errors[end]
        println()
        println("Conservación de energía:")
        @printf("  ΔE/E₀ final: %.2e ", E_final_error)
        if E_final_error < 1e-10
            println("✅ EXCELENTE")
        elseif E_final_error < 1e-6
            println("✅ BUENO")
        elseif E_final_error < 1e-4
            println("⚠️  ACEPTABLE")
        else
            println("❌ POBRE")
        end
        println("=" ^ 70)
    end

    # Crear diccionario de parámetros
    params = Dict{Symbol, Any}(
        :max_time => max_time,
        :dt_max => dt_max,
        :dt_min => dt_min,
        :a => a,
        :b => b,
        :collision_method => collision_method,
        :n_particles => length(particles_initial),
        :adaptive => true,
        :parametrization => :polar,
        :use_projection => use_projection,
        :projection_interval => projection_interval
    )

    return SimulationDataPolar{T}(
        particles_history,
        conservation_data,
        times_saved,
        params,
        dt_history,
        n_collisions_vec
    )
end

# ============================================================================
# Projection Methods para coordenadas polares
# ============================================================================

"""
    project_energy_polar!(particles, E_target, a, b; kwargs...)

Proyecta el sistema para conservar energía exacta E_target.

# Método
Escala todas las velocidades angulares φ̇ proporcionalmente:
    λ = √(E_target / E_current)
    φ̇ᵢ → λ φ̇ᵢ

Esto preserva las direcciones pero ajusta las magnitudes para
que E = Σ (1/2) m g_φφ φ̇² = E_target exactamente.

# Parámetros
- `particles`: Vector{ParticlePolar{T}} (se modifica in-place)
- `E_target`: Energía objetivo
- `a`, `b`: Semi-ejes
- `tolerance`: Tolerancia para convergencia (default: 1e-12)
- `max_iter`: Máximo número de iteraciones (default: 10)

# Retorna
- `true` si convergió, `false` si no
"""
function project_energy_polar!(
    particles::Vector{ParticlePolar{T}},
    E_target::T,
    a::T,
    b::T;
    tolerance::T = T(1e-12),
    max_iter::Int = 10
) where {T <: AbstractFloat}

    for iter in 1:max_iter
        # Calcular energía actual
        E_current = zero(T)
        for p in particles
            E_current += kinetic_energy(p, a, b)
        end

        # Verificar convergencia
        error = abs(E_current - E_target) / E_target
        if error < tolerance
            return true
        end

        # Calcular factor de escala
        λ = sqrt(E_target / E_current)

        # Escalar todas las velocidades angulares
        for i in 1:length(particles)
            p = particles[i]
            φ_dot_new = λ * p.φ_dot
            particles[i] = update_particle_polar(p, p.φ, φ_dot_new, a, b)
        end
    end

    # No convergió
    @warn "Projection methods no convergió después de $max_iter iteraciones"
    return false
end

"""
    print_conservation_summary_polar(data)

Imprime resumen de conservación para datos polares.
"""
function print_conservation_summary_polar(data::ConservationDataPolar{T}) where {T <: AbstractFloat}
    println("=" ^ 70)
    println("RESUMEN DE CONSERVACIÓN (Coordenadas Polares)")
    println("=" ^ 70)

    E0 = data.energies[1]
    Ef = data.energies[end]
    ΔE = Ef - E0
    ΔE_rel = abs(ΔE / E0)

    println("Energía inicial:  ", @sprintf("%.10f", E0))
    println("Energía final:    ", @sprintf("%.10f", Ef))
    println("ΔE (absoluto):    ", @sprintf("%.2e", abs(ΔE)))
    @printf("ΔE/E₀:            %.2e ", ΔE_rel)

    if ΔE_rel < 1e-10
        println("✅ EXCELENTE")
    elseif ΔE_rel < 1e-6
        println("✅ BUENO")
    elseif ΔE_rel < 1e-4
        println("⚠️  ACEPTABLE")
    else
        println("❌ POBRE")
    end

    # Estadísticas de error
    E_errors = data.energy_errors
    max_error = maximum(E_errors)
    mean_error = mean(E_errors)

    println()
    println("Estadísticas de error:")
    println("  Error máximo:   ", @sprintf("%.2e", max_error))
    println("  Error promedio: ", @sprintf("%.2e", mean_error))

    println("=" ^ 70)
end
