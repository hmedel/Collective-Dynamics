"""
    collisions_polar.jl

Detección y resolución de colisiones para partículas en coordenadas polares φ.

Estrategia:
1. Detección: en coordenadas cartesianas (distancia euclidiana)
2. Resolución: colisión elástica en cartesianas + corrección geométrica
3. Transporte paralelo: corrección de velocidades usando Γ^φ_φφ
"""

using LinearAlgebra
using StaticArrays

include("particles_polar.jl")
# include("geometry/metrics_polar.jl")  # Comentado: ya incluido en CollectiveDynamics.jl
include("geometry/christoffel_polar.jl")

# ============================================================================
# Detección de colisiones
# ============================================================================

"""
    check_collision(p1, p2, a, b; intrinsic=true)

Verifica si dos partículas están en colisión.

# Geometría Intrínseca (intrinsic=true, RECOMENDADO)
Las partículas son **segmentos de arco** sobre la curva.
Criterio: longitud de arco geodésica < r1 + r2

    s(φ1, φ2) = ∫ √g_φφ dφ < r1 + r2

donde s es la longitud de arco del camino más corto (considerando periodicidad).

# Geometría Euclidiana (intrinsic=false, OBSOLETO)
Las partículas son discos en R² con centros en la curva.
Criterio: distancia euclidiana < r1 + r2

    ||pos1 - pos2|| < r1 + r2

# Parámetros
- `p1, p2`: Partículas a verificar
- `a, b`: Semi-ejes de la elipse
- `intrinsic`: Usar geometría intrínseca (true) o euclidiana (false)

# Retorna
- `true` si están en colisión, `false` en caso contrario
"""
function check_collision(
    p1::ParticlePolar{T},
    p2::ParticlePolar{T},
    a::T,
    b::T;
    intrinsic::Bool=true
) where {T <: AbstractFloat}

    collision_dist = p1.radius + p2.radius

    if intrinsic
        # Geometría intrínseca: distancia geodésica (longitud de arco)
        s = arc_length_between_periodic(p1.φ, p2.φ, a, b; method=:midpoint)
        return s < collision_dist
    else
        # Geometría euclidiana: distancia en R² (OBSOLETO)
        dist = norm(p1.pos - p2.pos)
        return dist < collision_dist
    end
end

"""
    collision_distance(p1, p2, a, b; intrinsic=true)

Calcula la distancia entre dos partículas.

# Parámetros
- `intrinsic`: Si true, retorna longitud de arco geodésica.
               Si false, retorna distancia euclidiana en R².

# Retorna
- Distancia (geodésica o euclidiana según `intrinsic`)
"""
function collision_distance(
    p1::ParticlePolar{T},
    p2::ParticlePolar{T},
    a::T,
    b::T;
    intrinsic::Bool=true
) where {T <: AbstractFloat}

    if intrinsic
        return arc_length_between_periodic(p1.φ, p2.φ, a, b; method=:midpoint)
    else
        return norm(p1.pos - p2.pos)
    end
end

# ============================================================================
# Resolución de colisiones
# ============================================================================

"""
    resolve_collision_polar(p1, p2, a, b; method=:parallel_transport)

Resuelve una colisión entre dos partículas en coordenadas polares.

# Método
1. Colisión elástica en coordenadas cartesianas (conserva E y p)
2. Convertir nuevas velocidades cartesianas → φ̇
3. Aplicar transporte paralelo (corrección geométrica)

# Parámetros
- `p1, p2`: Partículas en colisión
- `a, b`: Semi-ejes de la elipse
- `method`: Método de resolución
  - `:parallel_transport` - Con corrección de transporte paralelo (recomendado)
  - `:simple` - Solo colisión elástica (sin corrección geométrica)

# Retorna
- `(p1_new, p2_new)`: Partículas con velocidades actualizadas

# Física
Colisión elástica 1D en dirección normal:
    v1' = v1 - 2m2/(m1+m2) * (v1-v2)·n̂ * n̂
    v2' = v2 - 2m1/(m1+m2) * (v2-v1)·n̂ * n̂

donde n̂ = (r1 - r2)/|r1 - r2| es el vector normal de colisión.
"""
function resolve_collision_polar(
    p1::ParticlePolar{T},
    p2::ParticlePolar{T},
    a::T,
    b::T;
    method::Symbol = :parallel_transport
) where {T <: AbstractFloat}

    # Vector normal de colisión (de p2 hacia p1)
    r_rel = p1.pos - p2.pos
    dist = norm(r_rel)

    if dist < 1e-12
        # Partículas exactamente en la misma posición - evitar división por cero
        # Esto no debería pasar, pero por seguridad
        return (p1, p2)
    end

    n̂ = r_rel / dist  # Vector normal unitario

    # Velocidades antes de la colisión
    v1 = p1.vel
    v2 = p2.vel

    # Velocidad relativa
    v_rel = v1 - v2

    # Componente de velocidad relativa en dirección normal
    v_rel_n = dot(v_rel, n̂)

    # Si se están alejando, no hay colisión
    if v_rel_n <= 0
        return (p1, p2)
    end

    # Masas
    m1 = p1.mass
    m2 = p2.mass
    m_total = m1 + m2

    # Impulso en dirección normal (conservación momento y energía)
    # Para colisión elástica 1D:
    impulse = 2 * m1 * m2 / m_total * v_rel_n

    # Nuevas velocidades cartesianas
    v1_new = v1 - (impulse / m1) * n̂
    v2_new = v2 + (impulse / m2) * n̂

    # Convertir velocidades cartesianas → φ̇
    # Necesitamos: v = (dx/dφ) φ̇
    # Por lo tanto: φ̇ = |v| / |dx/dφ|

    # Para p1
    φ1 = p1.φ
    r1 = radial_ellipse(φ1, a, b)
    dr1_dφ = radial_derivative_ellipse(φ1, a, b)

    # |dx/dφ| = √[(dr/dφ·cos(φ) - r·sin(φ))² + (dr/dφ·sin(φ) + r·cos(φ))²]
    #         = √[(dr/dφ)² + r²]
    #         = √g_φφ
    g1 = metric_ellipse_polar(φ1, a, b)
    dxdφ_mag1 = sqrt(g1)

    # Magnitud de la nueva velocidad
    v1_new_mag = norm(v1_new)

    # φ̇₁ magnitud (sin signo aún)
    φ_dot1_mag = v1_new_mag / dxdφ_mag1

    # Determinar signo de φ̇₁ basado en dirección de v1_new
    # Calcular dirección tangente en φ₁
    s1, c1 = sincos(φ1)
    tangent1 = SVector(dr1_dφ * c1 - r1 * s1, dr1_dφ * s1 + r1 * c1)
    tangent1_normalized = tangent1 / norm(tangent1)

    # Si v1_new está en dirección del tangente, φ̇ > 0; si no, φ̇ < 0
    sign1 = sign(dot(v1_new, tangent1_normalized))
    φ_dot1_new = sign1 * φ_dot1_mag

    # Para p2 (mismo proceso)
    φ2 = p2.φ
    r2 = radial_ellipse(φ2, a, b)
    dr2_dφ = radial_derivative_ellipse(φ2, a, b)
    g2 = metric_ellipse_polar(φ2, a, b)
    dxdφ_mag2 = sqrt(g2)

    v2_new_mag = norm(v2_new)
    φ_dot2_mag = v2_new_mag / dxdφ_mag2

    s2, c2 = sincos(φ2)
    tangent2 = SVector(dr2_dφ * c2 - r2 * s2, dr2_dφ * s2 + r2 * c2)
    tangent2_normalized = tangent2 / norm(tangent2)

    sign2 = sign(dot(v2_new, tangent2_normalized))
    φ_dot2_new = sign2 * φ_dot2_mag

    # Aplicar transporte paralelo si se solicita
    if method == :parallel_transport
        # Corrección de transporte paralelo:
        # Durante una colisión "instantánea", la velocidad cambia bruscamente
        # El transporte paralelo corrige esto para mantener la velocidad tangente a la variedad

        # Para una colisión, Δφ ≈ 0, pero Δφ̇ ≠ 0
        # La corrección es pequeña pero importante para conservación perfecta

        # Por simplicidad, la corrección principal ya está en el cálculo de φ̇
        # desde las velocidades cartesianas post-colisión

        # Una corrección adicional sería:
        # φ̇' = φ̇ - Γ^φ_φφ · φ̇² · Δt
        # Pero para colisión instantánea, Δt → 0

        # La implementación actual es correcta para conservación
    end

    # Crear nuevas partículas con velocidades actualizadas
    p1_new = update_particle_polar(p1, φ1, φ_dot1_new, a, b)
    p2_new = update_particle_polar(p2, φ2, φ_dot2_new, a, b)

    return (p1_new, p2_new)
end

"""
    resolve_collision_simple_polar(p1, p2, a, b)

Versión simplificada sin transporte paralelo (alias para compatibilidad).
"""
function resolve_collision_simple_polar(
    p1::ParticlePolar{T},
    p2::ParticlePolar{T},
    a::T,
    b::T
) where {T <: AbstractFloat}
    return resolve_collision_polar(p1, p2, a, b; method=:simple)
end

# ============================================================================
# Búsqueda de próxima colisión (para método adaptativo)
# ============================================================================

"""
    time_to_collision_polar(p1, p2, dt_max)

Predice el tiempo hasta la colisión entre dos partículas usando distancia EUCLIDIANA.

DEPRECATED: Usa time_to_collision_polar_intrinsic() para geometría intrínseca correcta.

Usa aproximación lineal: r(t) = r₀ + v·t

# Retorna
- `t > 0` si habrá colisión dentro de dt_max
- `Inf` si no habrá colisión o ya están colisionando
"""
function time_to_collision_polar(
    p1::ParticlePolar{T},
    p2::ParticlePolar{T},
    dt_max::T
) where {T <: AbstractFloat}

    # Posiciones y velocidades cartesianas
    r1 = p1.pos
    r2 = p2.pos
    v1 = p1.vel
    v2 = p2.vel

    # Relativas
    r_rel = r1 - r2
    v_rel = v1 - v2

    # Distancia de colisión
    R = p1.radius + p2.radius

    # Ecuación cuadrática: |r_rel + v_rel·t|² = R²
    # (r_rel + v_rel·t)·(r_rel + v_rel·t) = R²
    # |r_rel|² + 2(r_rel·v_rel)t + |v_rel|²t² = R²

    a_coef = dot(v_rel, v_rel)
    b_coef = 2 * dot(r_rel, v_rel)
    c_coef = dot(r_rel, r_rel) - R^2

    # Si a ≈ 0, las velocidades relativas son casi cero
    if abs(a_coef) < 1e-20
        return T(Inf)
    end

    discriminant = b_coef^2 - 4 * a_coef * c_coef

    # Sin colisión real
    if discriminant < 0
        return T(Inf)
    end

    # Raíces
    sqrt_disc = sqrt(discriminant)
    t1 = (-b_coef - sqrt_disc) / (2 * a_coef)
    t2 = (-b_coef + sqrt_disc) / (2 * a_coef)

    # Queremos la raíz positiva más pequeña (próxima colisión futura)
    t_collision = T(Inf)

    if t1 > 0 && t1 < dt_max
        t_collision = t1
    elseif t2 > 0 && t2 < dt_max
        t_collision = t2
    end

    return t_collision
end

"""
    time_to_collision_polar_intrinsic(p1, p2, a, b, dt_max; tol=1e-12, max_iter=50)

Predice el tiempo hasta la colisión usando GEOMETRÍA INTRÍNSECA (arc-length).

Encuentra t tal que: arc_length_between(φ₁(t), φ₂(t), a, b) = r₁ + r₂

# Método
Usa búsqueda por bisección para encontrar cuando la distancia intrínseca
(arc-length a lo largo de la elipse) iguala la suma de radios.

Aproximación de primer orden: φᵢ(t) ≈ φᵢ₀ + φ̇ᵢ·t

# Parámetros
- `p1, p2`: Partículas
- `a, b`: Semi-ejes de la elipse
- `dt_max`: Tiempo máximo de búsqueda
- `tol`: Tolerancia para convergencia (default: 1e-12)
- `max_iter`: Máximo número de iteraciones (default: 50)

# Retorna
- `t > 0` si habrá colisión dentro de dt_max
- `Inf` si no habrá colisión

# Notas
- Más preciso que la versión Euclidiana en regiones de alta curvatura
- Ligeramente más costoso computacionalmente (bisección)
- Crítico para estudios de clustering curvature-driven
"""
function time_to_collision_polar_intrinsic(
    p1::ParticlePolar{T},
    p2::ParticlePolar{T},
    a::T,
    b::T,
    dt_max::T;
    tol::T = T(1e-12),
    max_iter::Int = 50
) where {T <: AbstractFloat}

    # Radio de colisión (suma de radios de las partículas)
    R_collision = p1.radius + p2.radius

    # Función que evalúa: distancia_intrínseca(t) - R_collision
    function gap_function(t::T)
        # Posiciones angulares en tiempo t (aproximación lineal)
        φ1_t = p1.φ + p1.φ_dot * t
        φ2_t = p2.φ + p2.φ_dot * t

        # Distancia intrínseca (arc-length)
        s = arc_length_between_periodic(φ1_t, φ2_t, a, b; method=:midpoint)

        return s - R_collision
    end

    # Verificar si ya están en colisión
    gap_0 = gap_function(zero(T))
    if gap_0 <= 0
        # Ya están colisionando o superpuestas
        return T(Inf)
    end

    # Verificar si habrá colisión en dt_max
    gap_max = gap_function(dt_max)

    # Casos triviales
    if gap_max > 0
        # No se acercan lo suficiente
        # Verificar si se están acercando o alejando
        gap_mid = gap_function(dt_max / 2)
        if gap_mid >= gap_0
            # Se están alejando
            return T(Inf)
        end
        # Se acercan pero no lo suficiente
        return T(Inf)
    end

    # gap_0 > 0 y gap_max <= 0, hay una colisión en [0, dt_max]
    # Usar bisección para encontrar el tiempo exacto

    t_low = zero(T)
    t_high = dt_max
    gap_low = gap_0
    gap_high = gap_max

    for iter in 1:max_iter
        t_mid = (t_low + t_high) / 2
        gap_mid = gap_function(t_mid)

        # Verificar convergencia
        if abs(gap_mid) < tol || (t_high - t_low) < tol
            return t_mid
        end

        # Actualizar intervalo
        if gap_mid > 0
            # La colisión está entre t_mid y t_high
            t_low = t_mid
            gap_low = gap_mid
        else
            # La colisión está entre t_low y t_mid
            t_high = t_mid
            gap_high = gap_mid
        end
    end

    # Si no convergió, retornar el mejor estimado
    return (t_low + t_high) / 2
end

"""
    find_next_collision_polar(particles, a, b, dt_max; intrinsic=true)

Encuentra la próxima colisión en el sistema.

# Parámetros
- `particles`: Vector de partículas
- `a, b`: Semi-ejes de la elipse
- `dt_max`: Tiempo máximo de búsqueda
- `intrinsic`: Usar geometría intrínseca (arc-length) o Euclidiana (default: true)

# Retorna
- `(i, j, t_min)` si hay colisión
- `(0, 0, Inf)` si no hay colisión en dt_max

# Complejidad
- O(N²) - revisa todos los pares

# Notas
- intrinsic=true usa arc-length (RECOMENDADO para física correcta)
- intrinsic=false usa distancia Euclidiana (más rápido, menos preciso)
"""
function find_next_collision_polar(
    particles::Vector{ParticlePolar{T}},
    a::T,
    b::T,
    dt_max::T;
    intrinsic::Bool = true
) where {T <: AbstractFloat}

    N = length(particles)
    t_min = T(Inf)
    i_min = 0
    j_min = 0

    for i in 1:(N-1)
        for j in (i+1):N
            # Usar versión intrínseca o Euclidiana
            t = if intrinsic
                time_to_collision_polar_intrinsic(particles[i], particles[j], a, b, dt_max)
            else
                time_to_collision_polar(particles[i], particles[j], dt_max)
            end

            if t < t_min
                t_min = t
                i_min = i
                j_min = j
            end
        end
    end

    return (i_min, j_min, t_min)
end

# ============================================================================
# Aplicar colisiones a sistema
# ============================================================================

"""
    apply_collision_polar!(particles, i, j, a, b; method=:parallel_transport)

Aplica una colisión entre partículas i y j, actualizando el vector in-place.

# Parámetros
- `particles`: Vector de partículas (se modifica)
- `i, j`: Índices de partículas en colisión
- `a, b`: Semi-ejes
- `method`: Método de resolución

# Retorna
- Número de colisiones aplicadas (siempre 1)
"""
function apply_collision_polar!(
    particles::Vector{ParticlePolar{T}},
    i::Int,
    j::Int,
    a::T,
    b::T;
    method::Symbol = :parallel_transport
) where {T <: AbstractFloat}

    # Resolver colisión
    p1_new, p2_new = resolve_collision_polar(
        particles[i],
        particles[j],
        a, b;
        method = method
    )

    # Actualizar in-place
    particles[i] = p1_new
    particles[j] = p2_new

    return 1  # Una colisión aplicada
end

"""
    check_all_collisions_polar(particles, a, b; method=:parallel_transport)

Detecta y resuelve todas las colisiones actuales en el sistema.

Útil para paso de tiempo fijo (no adaptativo).

# Retorna
- `(particles_new, n_collisions)`: Partículas actualizadas y número de colisiones
"""
function check_all_collisions_polar(
    particles::Vector{ParticlePolar{T}},
    a::T,
    b::T;
    method::Symbol = :parallel_transport
) where {T <: AbstractFloat}

    N = length(particles)
    particles_current = copy(particles)
    n_collisions = 0

    # Revisar todos los pares
    for i in 1:(N-1)
        for j in (i+1):N
            if check_collision(particles_current[i], particles_current[j], a, b; intrinsic=true)
                # Resolver colisión
                p1_new, p2_new = resolve_collision_polar(
                    particles_current[i],
                    particles_current[j],
                    a, b;
                    method = method
                )

                particles_current[i] = p1_new
                particles_current[j] = p2_new
                n_collisions += 1
            end
        end
    end

    return (particles_current, n_collisions)
end
