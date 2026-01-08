"""
    particles_polar.jl

Definición de partículas en coordenadas polares verdaderas (φ).

Cambios respecto a particles.jl:
- θ (ángulo excéntrico) → φ (ángulo polar verdadero)
- θ_dot → φ_dot
- Usa métrica g_φφ = r² + (dr/dφ)²
"""

using StaticArrays
using LinearAlgebra
using Random

# include("geometry/metrics_polar.jl")  # Comentado: ya incluido en CollectiveDynamics.jl

"""
    ParticlePolar{T <: AbstractFloat}

Representa una partícula moviéndose en una elipse usando coordenadas polares verdaderas.

# Campos
- `id::Int32`: Identificador único
- `mass::T`: Masa
- `radius::T`: Radio de colisión
- `φ::T`: Ángulo polar verdadero [0, 2π)
- `φ_dot::T`: Velocidad angular (dφ/dt)
- `pos::SVector{2,T}`: Posición cartesiana (x, y)
- `vel::SVector{2,T}`: Velocidad cartesiana (vx, vy)

# Cantidades Conservadas
Para una partícula individual:
- Energía cinética: E = (1/2) m g_φφ φ̇²
  donde g_φφ = r² + (dr/dφ)²

Para el sistema completo (sin fuerzas externas):
- Energía total: E_total = Σ E_i  (se conserva)
- Momento conjugado P_φ = m g_φφ φ̇  (NO se conserva individualmente)
"""
struct ParticlePolar{T <: AbstractFloat}
    id::Int32
    mass::T
    radius::T
    φ::T           # Ángulo polar verdadero
    φ_dot::T       # Velocidad angular
    pos::SVector{2,T}   # Posición cartesiana
    vel::SVector{2,T}   # Velocidad cartesiana
end

# ============================================================================
# Constructores
# ============================================================================

"""
    ParticlePolar(id, mass, radius, φ, φ_dot, a, b)

Constructor principal que calcula posiciones y velocidades cartesianas.
"""
function ParticlePolar(
    id::Integer,
    mass::T,
    radius::T,
    φ::T,
    φ_dot::T,
    a::T,
    b::T
) where {T <: AbstractFloat}

    # Calcular posiciones cartesianas
    pos = cartesian_from_polar_angle(φ, a, b)

    # Calcular velocidades cartesianas
    vel = velocity_from_polar_angular(φ, φ_dot, a, b)

    return ParticlePolar{T}(Int32(id), mass, radius, φ, φ_dot, pos, vel)
end

"""
    ParticlePolar(id, mass, radius, φ, φ_dot, pos, vel)

Constructor directo con posiciones y velocidades cartesianas conocidas.
"""
function ParticlePolar(
    id::Integer,
    mass::T,
    radius::T,
    φ::T,
    φ_dot::T,
    pos::SVector{2,T},
    vel::SVector{2,T}
) where {T <: AbstractFloat}

    return ParticlePolar{T}(Int32(id), mass, radius, φ, φ_dot, pos, vel)
end

# ============================================================================
# Actualización de estado
# ============================================================================

"""
    update_particle_polar(p, φ_new, φ_dot_new, a, b)

Crea una nueva partícula con φ y φ_dot actualizados.
Recalcula posiciones y velocidades cartesianas.
"""
function update_particle_polar(
    p::ParticlePolar{T},
    φ_new::T,
    φ_dot_new::T,
    a::T,
    b::T
) where {T <: AbstractFloat}

    # Normalizar φ a [0, 2π)
    φ_normalized = mod(φ_new, 2π)

    # Calcular nuevas posiciones y velocidades cartesianas
    pos_new = cartesian_from_polar_angle(φ_normalized, a, b)
    vel_new = velocity_from_polar_angular(φ_normalized, φ_dot_new, a, b)

    return ParticlePolar(
        p.id, p.mass, p.radius,
        φ_normalized, φ_dot_new,
        pos_new, vel_new
    )
end

# ============================================================================
# Propiedades físicas
# ============================================================================

"""
    kinetic_energy(p, a, b)

Calcula energía cinética: E = (1/2) m g_φφ φ̇²
"""
function kinetic_energy(p::ParticlePolar{T}, a::T, b::T) where {T <: AbstractFloat}
    return kinetic_energy_polar(p.φ, p.φ_dot, p.mass, a, b)
end

"""
    conjugate_momentum(p, a, b)

Calcula momento conjugado: P_φ = m g_φφ φ̇

CONSERVACIÓN: Esta cantidad SÍ se conserva para cada partícula individual
en movimiento geodésico libre (sin colisiones externas). Con colisiones
elásticas en presencia de parallel transport, también se conserva el total.
"""
function conjugate_momentum(p::ParticlePolar{T}, a::T, b::T) where {T <: AbstractFloat}
    g_φφ = metric_ellipse_polar(p.φ, a, b)
    return p.mass * g_φφ * p.φ_dot
end

"""
    angular_momentum(p, a, b)

Calcula momento angular: L = m r² φ̇

NOTA: Esto tampoco se conserva en general para la elipse.
"""
function angular_momentum(p::ParticlePolar{T}, a::T, b::T) where {T <: AbstractFloat}
    r = radial_ellipse(p.φ, a, b)
    return p.mass * r^2 * p.φ_dot
end

# ============================================================================
# Generación de partículas aleatorias
# ============================================================================

"""
    generate_random_particles_polar(
        N, mass, radius, a, b;
        max_speed=1.0,
        rng=Random.default_rng(),
        max_attempts=10000
    )

Genera N partículas con ángulos polares φ aleatorios y velocidades φ̇ aleatorias.

# Parámetros
- `N`: Número de partículas
- `mass`: Masa de cada partícula
- `radius`: Radio de colisión (fracción de b recomendada: 0.03-0.1)
- `a, b`: Semi-ejes de la elipse
- `max_speed`: Velocidad angular máxima |φ̇|
- `rng`: Generador aleatorio
- `max_attempts`: Intentos máximos para colocar cada partícula sin solapamiento

# Retorna
- Vector de ParticlePolar
"""
function generate_random_particles_polar(
    N::Int,
    mass::T,
    radius::T,
    a::T,
    b::T;
    max_speed::T = T(1.0),
    rng = Random.default_rng(),
    max_attempts::Int = 10000
) where {T <: AbstractFloat}

    particles = ParticlePolar{T}[]

    for id in 1:N
        placed = false

        for attempt in 1:max_attempts
            # Ángulo polar aleatorio
            φ = T(2π * rand(rng))

            # Velocidad angular aleatoria
            φ_dot = T(max_speed * (2 * rand(rng) - 1))

            # Crear partícula candidata
            candidate = ParticlePolar(id, mass, radius, φ, φ_dot, a, b)

            # Verificar que no se solape con partículas existentes
            # Usa distancia INTRÍNSECA (longitud de arco geodésica)
            no_overlap = true
            for p in particles
                # Longitud de arco entre partículas
                s = arc_length_between_periodic(candidate.φ, p.φ, a, b; method=:midpoint)
                if s < (candidate.radius + p.radius)
                    no_overlap = false
                    break
                end
            end

            if no_overlap
                push!(particles, candidate)
                placed = true
                break
            end
        end

        if !placed
            error("No se pudo generar posición válida para partícula $id después de $max_attempts intentos. " *
                  "Considere reducir el radio o aumentar el tamaño de la elipse.")
        end
    end

    return particles
end

# ============================================================================
# Conversión desde ParticlePolar antiguo (θ) si existe
# ============================================================================

"""
    particle_eccentric_to_polar(p_old, a, b)

Convierte una partícula con ángulo excéntrico θ a ángulo polar φ.

NOTA: Requiere que el tipo antiguo sea Particle{T} con campos θ, θ_dot.
Esta función es para migración de datos existentes.
"""
function particle_eccentric_to_polar(p_old, a::T, b::T) where {T <: AbstractFloat}
    # Convertir θ → φ
    φ = polar_angle_from_eccentric(T(p_old.θ), a, b)

    # Convertir θ̇ → φ̇
    # Relación: dx/dt = (dx/dθ)(dθ/dt) = (dx/dφ)(dφ/dt)
    # Necesitamos: φ̇ = (dx/dθ)/(dx/dφ) · θ̇
    #
    # Como tenemos las velocidades cartesianas en p_old.vel,
    # podemos calcular φ̇ directamente invirtiendo:
    # vel = velocity_from_polar_angular(φ, φ_dot, a, b)

    # Por simplicidad, usamos aproximación numérica
    # (idealmente derivar fórmula analítica θ̇ → φ̇)

    # Aproximación: medir cuánto cambia φ por cambio en θ
    h = T(1e-8)
    φ_plus = polar_angle_from_eccentric(T(p_old.θ) + h, a, b)
    dφ_dθ = (φ_plus - φ) / h

    φ_dot = dφ_dθ * T(p_old.θ_dot)

    # Crear nueva partícula polar
    return ParticlePolar(
        p_old.id,
        T(p_old.mass),
        T(p_old.radius),
        φ,
        φ_dot,
        a, b
    )
end
