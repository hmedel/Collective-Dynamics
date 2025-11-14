"""
    CollectiveDynamics.jl

Framework para simulaciones de dinámica colectiva en variedades curvas.

Implementa el algoritmo descrito en:
"Collision Dynamics on Curved Manifolds: A Simple Symplectic Computational Approach"
por J. Isaí García-Hernández y Héctor J. Medel-Cobaxín

# Características principales
- Geometría diferencial aplicada numéricamente
- Integrador simpléctico Forest-Ruth de 4to orden
- Transporte paralelo de velocidades
- Conservación rigurosa de energía y momento
- Optimizado con StaticArrays y Float64
- Preparado para paralelización CPU/GPU

# Ejemplo básico
```julia
using CollectiveDynamics

# Parámetros de la elipse
a, b = 2.0, 1.0

# Generar partículas
particles = generate_random_particles(40, 1.0, 0.05, a, b)

# Simular
data = simulate_ellipse(particles, a, b;
    n_steps=10000, dt=1e-5,
    collision_method=:parallel_transport
)

# Analizar conservación
print_conservation_summary(data.conservation)
```
"""
module CollectiveDynamics

# Dependencias estándar
using LinearAlgebra
using Random
using Statistics
using Printf

# Dependencias externas
using StaticArrays
using Elliptic
using ForwardDiff

# ============================================================================
# Includes
# ============================================================================

# Geometría diferencial
include("geometry/metrics.jl")
include("geometry/christoffel.jl")
include("geometry/parallel_transport.jl")

# Integradores
include("integrators/forest_ruth.jl")

# Partículas y colisiones
include("particles.jl")
include("collisions.jl")

# Tiempos adaptativos
include("adaptive_time.jl")

# Conservación
include("conservation.jl")

# Paralelización (opcional, requiere Threads)
include("parallel/collision_detection_parallel.jl")

# ============================================================================
# Exports - Geometría
# ============================================================================

# Métricas
export metric_ellipse,
       metric_ellipse_tensor,
       inverse_metric_ellipse,
       metric_derivative_ellipse,
       cartesian_from_angle,
       velocity_from_angular,
       arc_length_ellipse,
       kinetic_energy_angular,
       kinetic_energy_cartesian

# Christoffel
export christoffel_ellipse,
       christoffel_ellipse_alt,
       christoffel_numerical,
       christoffel_autodiff,
       geodesic_acceleration,
       compare_christoffel_methods

# Transporte paralelo
export parallel_transport_velocity,
       parallel_transport_velocity!,
       parallel_transport_path,
       parallel_transport_cartesian_velocity,
       verify_parallel_transport_norm,
       holonomy_angle

# ============================================================================
# Exports - Integradores
# ============================================================================

export ForestRuthCoefficients,
       get_coefficients,
       forest_ruth_step_ellipse,
       forest_ruth_step_ellipse!,
       forest_ruth_simplified,
       integrate_forest_ruth,
       verify_symplecticity

# ============================================================================
# Exports - Partículas
# ============================================================================

export Particle,
       update_particle,
       kinetic_energy,
       kinetic_energy_cartesian,
       conjugate_momentum,
       angular_momentum,  # Alias deprecado de conjugate_momentum
       initialize_particle,
       generate_random_particles,
       total_energy,
       center_of_mass

# ============================================================================
# Exports - Colisiones
# ============================================================================

export check_collision,
       check_collision_cartesian,
       resolve_collision_simple,
       resolve_collision_parallel_transport,
       resolve_collision_geodesic,
       detect_all_collisions,
       resolve_all_collisions!

# ============================================================================
# Exports - Tiempos Adaptativos
# ============================================================================

export time_to_collision,
       find_next_collision,
       find_next_collision_parallel

# ============================================================================
# Exports - Conservación
# ============================================================================

export ConservationData,
       record_conservation!,
       analyze_energy_conservation,
       analyze_momentum_conservation,
       analyze_angular_momentum,
       print_conservation_summary,
       verify_collision_conservation,
       get_energy_data,
       get_momentum_data

# ============================================================================
# High-Level Simulation Functions
# ============================================================================

"""
    SimulationData{T}

Estructura que contiene todos los datos de una simulación.

# Campos
- `particles::Vector{Vector{Particle{T}}}`: Historial de estados de partículas
- `conservation::ConservationData{T}`: Datos de conservación
- `times::Vector{T}`: Tiempos de cada snapshot
- `n_collisions::Vector{Int}`: Número de colisiones en cada paso
- `conserved_fractions::Vector{T}`: Fracción de colisiones conservadas
- `parameters::Dict{Symbol, Any}`: Parámetros de la simulación
"""
struct SimulationData{T <: AbstractFloat}
    particles::Vector{Vector{Particle{T}}}
    conservation::ConservationData{T}
    times::Vector{T}
    n_collisions::Vector{Int}
    conserved_fractions::Vector{T}
    parameters::Dict{Symbol, Any}
end

export SimulationData

"""
    simulate_ellipse(particles_initial, a, b;
                     n_steps=1000, dt=1e-5,
                     save_every=10,
                     collision_method=:parallel_transport,
                     tolerance=1e-6,
                     verbose=true)

Simula dinámica de partículas en una elipse.

# Parámetros
- `particles_initial`: Estado inicial de las partículas
- `a`, `b`: Semi-ejes de la elipse
- `n_steps`: Número de pasos de tiempo
- `dt`: Paso de tiempo
- `save_every`: Guardar estado cada N pasos (para memoria)
- `collision_method`: `:simple`, `:parallel_transport`, o `:geodesic`
- `tolerance`: Tolerancia para verificar conservación
- `verbose`: Imprimir progreso

# Retorna
- `SimulationData`: Estructura con todos los resultados

# Ejemplo
```julia
particles = generate_random_particles(40, 1.0, 0.05, 2.0, 1.0)
data = simulate_ellipse(particles, 2.0, 1.0; n_steps=10000, dt=1e-5)
```
"""
function simulate_ellipse(
    particles_initial::Vector{Particle{T}},
    a::T,
    b::T;
    n_steps::Int = 1000,
    dt::T = T(1e-5),
    save_every::Int = 10,
    collision_method::Symbol = :parallel_transport,
    tolerance::T = T(1e-6),
    verbose::Bool = true
) where {T <: AbstractFloat}

    # Copiar partículas para no modificar el input
    particles = copy(particles_initial)

    # Inicializar estructuras de datos
    n_saves = div(n_steps, save_every) + 1
    particles_history = Vector{Vector{Particle{T}}}(undef, n_saves)
    times_saved = Vector{T}(undef, n_saves)
    n_collisions_vec = Vector{Int}(undef, n_steps)
    conserved_fractions_vec = Vector{T}(undef, n_steps)

    conservation_data = ConservationData{T}()

    # Guardar estado inicial
    particles_history[1] = copy(particles)
    times_saved[1] = zero(T)
    record_conservation!(conservation_data, particles, zero(T), a, b)

    save_idx = 2
    t = zero(T)

    if verbose
        println("=" ^ 70)
        println("INICIANDO SIMULACIÓN")
        println("=" ^ 70)
        println("Partículas:        ", length(particles))
        println("Pasos:             ", n_steps)
        println("dt:                ", dt)
        println("Duración total:    ", n_steps * dt)
        println("Método colisión:   ", collision_method)
        println("Semi-ejes (a, b):  ($a, $b)")
        println("=" ^ 70)
    end

    # Loop principal de simulación
    for step in 1:n_steps
        t = step * dt

        # Paso 1: Mover partículas (integración geodésica)
        @inbounds for i in 1:length(particles)
            p = particles[i]
            θ_new, θ_dot_new = forest_ruth_step_ellipse(p.θ, p.θ_dot, dt, a, b)
            particles[i] = update_particle(p, θ_new, θ_dot_new, a, b)
        end

        # Paso 2: Resolver colisiones
        n_coll, conserved_frac = resolve_all_collisions!(
            particles, a, b;
            method=collision_method,
            dt=dt,
            tolerance=tolerance
        )

        n_collisions_vec[step] = n_coll
        conserved_fractions_vec[step] = conserved_frac

        # Paso 3: Guardar datos
        if step % save_every == 0
            particles_history[save_idx] = copy(particles)
            times_saved[save_idx] = t
            record_conservation!(conservation_data, particles, t, a, b)
            save_idx += 1

            if verbose && (step % (n_steps ÷ 10) == 0)
                progress = 100 * step / n_steps
                println(@sprintf("Progreso: %.1f%% | Colisiones: %d | t = %.6f",
                        progress, n_coll, t))
            end
        end
    end

    # Guardar estado final si no se guardó
    if (n_steps % save_every) != 0
        particles_history[save_idx] = copy(particles)
        times_saved[save_idx] = t
        record_conservation!(conservation_data, particles, t, a, b)
    end

    if verbose
        println("=" ^ 70)
        println("SIMULACIÓN COMPLETADA")
        println("=" ^ 70)
    end

    # Crear diccionario de parámetros
    params = Dict{Symbol, Any}(
        :n_steps => n_steps,
        :dt => dt,
        :a => a,
        :b => b,
        :collision_method => collision_method,
        :tolerance => tolerance,
        :n_particles => length(particles_initial)
    )

    return SimulationData{T}(
        particles_history,
        conservation_data,
        times_saved,
        n_collisions_vec,
        conserved_fractions_vec,
        params
    )
end

export simulate_ellipse

"""
    simulate_ellipse_adaptive(particles_initial, a, b;
                              max_time=1.0,
                              dt_max=1e-5,
                              dt_min=1e-10,
                              save_interval=0.01,
                              collision_method=:parallel_transport,
                              tolerance=1e-6,
                              max_steps=10_000_000,
                              use_parallel=false,
                              verbose=true)

Simula dinámica de partículas en una elipse usando **tiempos adaptativos**.

Este es el algoritmo descrito en el artículo:
1. En cada paso, calcular el tiempo hasta la próxima colisión
2. Ajustar dt a ese tiempo (limitado por dt_max y dt_min)
3. Evolucionar todas las partículas ese tiempo
4. Resolver colisiones que ocurran
5. Repetir hasta alcanzar max_time o max_steps

# Diferencia con simulate_ellipse
- `simulate_ellipse`: usa dt fijo, puede perder colisiones o tener múltiples simultáneas
- `simulate_ellipse_adaptive`: ajusta dt para detectar colisiones exactas

# Parámetros
- `particles_initial`: Estado inicial de las partículas
- `a`, `b`: Semi-ejes de la elipse
- `max_time`: Tiempo total de simulación
- `dt_max`: Paso de tiempo máximo permitido
- `dt_min`: Paso de tiempo mínimo (evita partículas "pegadas")
- `save_interval`: Intervalo de tiempo para guardar estados
- `collision_method`: `:simple`, `:parallel_transport`, o `:geodesic`
- `tolerance`: Tolerancia para verificar conservación
- `max_steps`: Número máximo de pasos de integración (seguridad contra loops infinitos)
- `use_parallel`: Usar detección paralela de colisiones (requiere `julia -t N`, N≥30 recomendado)
- `verbose`: Imprimir progreso

# Retorna
- `SimulationData`: Estructura con todos los resultados

# Ejemplo
```julia
particles = generate_random_particles(40, 1.0, 0.05, 2.0, 1.0)
data = simulate_ellipse_adaptive(particles, 2.0, 1.0;
                                 max_time=1.0, dt_max=1e-5,
                                 max_steps=50_000_000, verbose=true)
```

# Ventajas
- Detección exacta de colisiones
- Mejor conservación de energía
- Evita colisiones múltiples simultáneas
- Manejo automático de partículas "pegadas"
- Control de límite de iteraciones para simulaciones largas

# Notas
- Más lento que `simulate_ellipse` debido al cálculo de tiempos
- Ideal para sistemas con pocas partículas o alta precisión requerida
- El vector de tiempos es irregular (no uniforme)
- Si alcanza max_steps antes de max_time, la simulación se detiene con un warning
"""
function simulate_ellipse_adaptive(
    particles_initial::Vector{Particle{T}},
    a::T,
    b::T;
    max_time::T = T(1.0),
    dt_max::T = T(1e-5),
    dt_min::T = T(1e-10),
    save_interval::T = T(0.01),
    collision_method::Symbol = :parallel_transport,
    tolerance::T = T(1e-6),
    max_steps::Int = 10_000_000,
    use_parallel::Bool = false,
    verbose::Bool = true
) where {T <: AbstractFloat}

    # Copiar partículas para no modificar el input
    particles = copy(particles_initial)

    # Inicializar estructuras de datos
    particles_history = Vector{Vector{Particle{T}}}()
    times_saved = Vector{T}()
    n_collisions_vec = Vector{Int}()
    conserved_fractions_vec = Vector{T}()
    dt_history = Vector{T}()  # Historial de pasos de tiempo usados

    conservation_data = ConservationData{T}()

    # Guardar estado inicial
    push!(particles_history, copy(particles))
    push!(times_saved, zero(T))
    record_conservation!(conservation_data, particles, zero(T), a, b)

    t = zero(T)
    t_next_save = save_interval
    step = 0

    if verbose
        println("=" ^ 70)
        println("SIMULACIÓN CON TIEMPOS ADAPTATIVOS")
        println("=" ^ 70)
        println("Partículas:        ", length(particles))
        println("Tiempo total:      ", max_time)
        println("dt_max:            ", dt_max)
        println("dt_min:            ", dt_min)
        println("Método colisión:   ", collision_method)
        println("Semi-ejes (a, b):  ($a, $b)")
        println("=" ^ 70)
    end

    # Loop principal de simulación
    while t < max_time
        step += 1

        # Paso 1: Encontrar próxima colisión
        # Usar versión paralela si está habilitada y hay threads disponibles
        collision_info = if use_parallel && Threads.nthreads() > 1
            find_next_collision_parallel(
                particles, a, b;
                max_time = dt_max,
                min_dt = dt_min
            )
        else
            find_next_collision(
                particles, a, b;
                max_time = dt_max,
                min_dt = dt_min
            )
        end

        # Paso de tiempo: mínimo entre próxima colisión y dt_max
        dt = min(collision_info.dt, max_time - t)

        # Guardar dt usado
        push!(dt_history, dt)

        # Paso 2: Mover partículas
        @inbounds for i in 1:length(particles)
            p = particles[i]
            θ_new, θ_dot_new = forest_ruth_step_ellipse(p.θ, p.θ_dot, dt, a, b)
            particles[i] = update_particle(p, θ_new, θ_dot_new, a, b)
        end

        t += dt

        # Paso 3: Resolver colisiones si hay
        n_coll = 0
        conserved_frac = one(T)

        if collision_info.found && collision_info.dt <= dt + eps(T)
            # Hay colisión, resolverla
            i, j = collision_info.pair
            p1 = particles[i]
            p2 = particles[j]

            if collision_method == :simple
                p1_new, p2_new = resolve_collision_simple(p1, p2, a, b)
                conserved = true

            elseif collision_method == :parallel_transport
                p1_new, p2_new, conserved = resolve_collision_parallel_transport(
                    p1, p2, a, b; tolerance=tolerance
                )

            elseif collision_method == :geodesic
                p1_new, p2_new, conserved = resolve_collision_geodesic(
                    p1, p2, dt, a, b; tolerance=tolerance
                )
            else
                error("Método desconocido: $collision_method")
            end

            particles[i] = p1_new
            particles[j] = p2_new
            n_coll = 1
            conserved_frac = conserved ? one(T) : zero(T)
        end

        push!(n_collisions_vec, n_coll)
        push!(conserved_fractions_vec, conserved_frac)

        # Paso 4: Guardar datos si es tiempo
        if t >= t_next_save || abs(t - max_time) < eps(T)
            push!(particles_history, copy(particles))
            push!(times_saved, t)
            record_conservation!(conservation_data, particles, t, a, b)
            t_next_save += save_interval

            if verbose && (length(times_saved) % 10 == 0)
                progress = 100 * t / max_time
                avg_dt = mean(dt_history[max(1, end-99):end])
                println(@sprintf("Progreso: %.1f%% | t = %.6f | dt_avg = %.2e | Colisiones totales: %d",
                        progress, t, avg_dt, sum(n_collisions_vec)))
            end
        end

        # Seguridad: evitar loops infinitos
        if step > max_steps
            @warn "Alcanzado límite de pasos ($max_steps). Deteniendo simulación."
            break
        end
    end

    if verbose
        println("=" ^ 70)
        println("SIMULACIÓN COMPLETADA")
        println("=" ^ 70)
        println("Pasos totales:       ", step)
        println("Colisiones totales:  ", sum(n_collisions_vec))
        println("dt promedio:         ", mean(dt_history))
        println("dt mínimo:           ", minimum(dt_history))
        println("dt máximo:           ", maximum(dt_history))
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
        :tolerance => tolerance,
        :n_particles => length(particles_initial),
        :adaptive => true,
        :dt_history => dt_history
    )

    return SimulationData{T}(
        particles_history,
        conservation_data,
        times_saved,
        n_collisions_vec,
        conserved_fractions_vec,
        params
    )
end

export simulate_ellipse_adaptive

# ============================================================================
# Entrada/Salida (después de SimulationData)
# ============================================================================

include("io.jl")

# ============================================================================
# Versión Info
# ============================================================================

"""
    version_info()

Imprime información sobre el módulo y sus dependencias.
"""
function version_info()
    println("CollectiveDynamics.jl")
    println("Versión: 0.1.0")
    println("Autores: J. Isaí García-Hernández, Héctor J. Medel-Cobaxín")
    println("\nDependencias:")
    println("  - StaticArrays")
    println("  - ForwardDiff")
    println("  - Elliptic")
    println("\nOptimizaciones:")
    println("  ✓ Float64 (precision suficiente)")
    println("  ✓ StaticArrays (stack allocation)")
    println("  ✓ @inline functions")
    println("  ✓ Type stability")
    println("\nPróximas características:")
    println("  ⧗ Paralelización CPU (Threads.jl)")
    println("  ⧗ Paralelización GPU (CUDA.jl)")
    println("  ⧗ Visualización (GLMakie.jl)")
end

export version_info

end # module CollectiveDynamics
