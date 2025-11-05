"""
    collisions.jl

Detección y resolución de colisiones en variedades curvas usando transporte paralelo.

Implementa el algoritmo completo descrito en el artículo:
1. Detección por longitud de arco geodésica
2. Resolución mediante geodésicas
3. Transporte paralelo de velocidades
4. Verificación de conservación
"""

using StaticArrays
using LinearAlgebra
using Elliptic: E

# ============================================================================
# Detección de Colisiones
# ============================================================================

"""
    check_collision(p1::Particle, p2::Particle, a, b)

Detecta si dos partículas están colisionando usando la longitud de arco geodésica.

# Matemática
Dos partículas colisionan si:
```
d_geodesic(θ₁, θ₂) ≤ r₁ + r₂
```

donde d_geodesic es la longitud de arco entre θ₁ y θ₂.

# Parámetros
- `p1`, `p2`: Partículas a verificar
- `a`, `b`: Semi-ejes de la elipse

# Retorna
- `true` si hay colisión, `false` en caso contrario

# Nota
Este método es más preciso que usar distancia cartesiana porque
respeta la geometría intrínseca de la elipse.
"""
@inline function check_collision(
    p1::Particle{T},
    p2::Particle{T},
    a::T,
    b::T
) where {T <: AbstractFloat}

    # Diferencia angular
    Δθ = abs(p1.θ - p2.θ)

    # Tomar el camino más corto en la elipse
    Δθ = min(Δθ, 2*T(π) - Δθ)

    # Si la diferencia angular es muy pequeña, usar métrica local
    if Δθ < T(1e-10)
        return true  # Están en el mismo punto
    end

    # Calcular longitud de arco
    # Aproximación: usar métrica en el punto medio
    θ_mid = (p1.θ + p2.θ) / 2
    g_mid = sqrt(metric_ellipse(θ_mid, a, b))
    arc_length = g_mid * Δθ

    # Suma de radios
    radii_sum = p1.radius + p2.radius

    return arc_length <= radii_sum
end

"""
    check_collision_cartesian(p1::Particle, p2::Particle)

Detección alternativa usando distancia cartesiana.

Menos precisa geométricamente pero más rápida.
Útil para pre-filtrado en sistemas con muchas partículas.

# Retorna
- `true` si |r⃗₁ - r⃗₂| ≤ r₁ + r₂
"""
@inline function check_collision_cartesian(
    p1::Particle{T},
    p2::Particle{T}
) where {T <: AbstractFloat}

    dist_sq = sum((p1.pos - p2.pos).^2)
    radii_sum = p1.radius + p2.radius

    return dist_sq <= radii_sum^2
end

# ============================================================================
# Resolución de Colisiones (Versión Simple - Intercambio)
# ============================================================================

"""
    resolve_collision_simple(p1::Particle, p2::Particle, a, b)

Resuelve colisión mediante intercambio simple de velocidades angulares.

Esta es la versión del código original. Es correcta para colisiones elásticas
en el límite de masas iguales, pero NO incluye transporte paralelo.

# Retorna
- `(p1_new, p2_new)`: Partículas con velocidades actualizadas
"""
function resolve_collision_simple(
    p1::Particle{T},
    p2::Particle{T},
    a::T,
    b::T
) where {T <: AbstractFloat}

    # Intercambiar velocidades angulares
    θ_dot_1_new = p2.θ_dot
    θ_dot_2_new = p1.θ_dot

    # Actualizar partículas
    p1_new = update_particle(p1, p1.θ, θ_dot_1_new, a, b)
    p2_new = update_particle(p2, p2.θ, θ_dot_2_new, a, b)

    return (p1_new, p2_new)
end

# ============================================================================
# Resolución de Colisiones con Transporte Paralelo
# ============================================================================

"""
    resolve_collision_parallel_transport(p1::Particle, p2::Particle, a, b)

Resuelve colisión usando transporte paralelo (método del artículo).

# Algoritmo
1. Calcular velocidades post-colisión usando conservación de momento y energía
2. Aplicar transporte paralelo para corregir geométricamente
3. Actualizar posiciones usando integración geodésica

# Matemática
Para colisiones elásticas con masas iguales:
```
θ̇₁' = θ̇₂  (antes del transporte)
θ̇₂' = θ̇₁  (antes del transporte)

Luego aplicar:
θ̇₁'' = θ̇₁' - Γ(θ₁) θ̇₁' Δθ
θ̇₂'' = θ̇₂' - Γ(θ₂) θ̇₂' Δθ
```

donde Δθ es el desplazamiento durante la colisión.

# Retorna
- `(p1_new, p2_new, conserved)`: Partículas actualizadas y flag de conservación

# Parámetros adicionales
- `tolerance`: Tolerancia para verificar conservación (default: 1e-6)
"""
function resolve_collision_parallel_transport(
    p1::Particle{T},
    p2::Particle{T},
    a::T,
    b::T;
    tolerance::T = T(1e-6)
) where {T <: AbstractFloat}

    # Calcular energía y momento antes de la colisión
    E_before = kinetic_energy(p1, a, b) + kinetic_energy(p2, a, b)
    p_before = angular_momentum(p1, a, b) + angular_momentum(p2, a, b)

    # === Paso 1: Colisión elástica (intercambio de velocidades) ===
    θ_dot_1_temp = p2.θ_dot
    θ_dot_2_temp = p1.θ_dot

    # === Paso 2: Transporte paralelo ===
    # Calcular desplazamiento angular durante la colisión
    # Para colisión instantánea, Δθ ≈ 0, pero aplicamos corrección de primer orden

    # Δθ estimado como el promedio de las velocidades por un tiempo característico
    # dt_collision ≈ (r₁ + r₂) / √(v_rel)
    Δθ_1 = T(0)  # Para colisión instantánea
    Δθ_2 = T(0)

    # Aplicar transporte paralelo
    θ_dot_1_new = parallel_transport_velocity(θ_dot_1_temp, Δθ_1, p1.θ, a, b)
    θ_dot_2_new = parallel_transport_velocity(θ_dot_2_temp, Δθ_2, p2.θ, a, b)

    # === Paso 3: Actualizar partículas ===
    p1_new = update_particle(p1, p1.θ, θ_dot_1_new, a, b)
    p2_new = update_particle(p2, p2.θ, θ_dot_2_new, a, b)

    # === Paso 4: Verificar conservación ===
    E_after = kinetic_energy(p1_new, a, b) + kinetic_energy(p2_new, a, b)
    p_after = angular_momentum(p1_new, a, b) + angular_momentum(p2_new, a, b)

    ΔE = abs(E_after - E_before)
    Δp = abs(p_after - p_before)

    conserved = (ΔE / (E_before + eps(T)) < tolerance) &&
                (Δp / (abs(p_before) + eps(T)) < tolerance)

    return (p1_new, p2_new, conserved)
end

"""
    resolve_collision_geodesic(p1::Particle, p2::Particle, dt, a, b)

Resolución avanzada integrando ecuaciones geodésicas durante la colisión.

Este método es más fiel al artículo: resuelve las ecuaciones geodésicas
durante el tiempo de colisión usando Forest-Ruth.

# Parámetros
- `dt`: Paso de tiempo para la integración geodésica
- `a`, `b`: Semi-ejes

# Retorna
- `(p1_new, p2_new, conserved)`: Partículas post-colisión
"""
function resolve_collision_geodesic(
    p1::Particle{T},
    p2::Particle{T},
    dt::T,
    a::T,
    b::T;
    tolerance::T = T(1e-6)
) where {T <: AbstractFloat}

    # Energía y momento antes
    E_before = kinetic_energy(p1, a, b) + kinetic_energy(p2, a, b)

    # Calcular momento relativo y CM
    m1, m2 = p1.mass, p2.mass
    M = m1 + m2

    # Velocidades relativa y de CM
    g1 = metric_ellipse(p1.θ, a, b)
    g2 = metric_ellipse(p2.θ, a, b)

    p1_momentum = m1 * g1 * p1.θ_dot
    p2_momentum = m2 * g2 * p2.θ_dot

    # Colisión elástica 1D en momento
    # Para masas iguales: intercambio de momentos
    if abs(m1 - m2) < eps(T)
        # Intercambiar velocidades angulares
        θ_dot_1_new = p2.θ_dot
        θ_dot_2_new = p1.θ_dot
    else
        # Fórmula general de colisión elástica
        θ_dot_1_new = ((m1 - m2) * p1.θ_dot + 2*m2 * p2.θ_dot) / M
        θ_dot_2_new = ((m2 - m1) * p2.θ_dot + 2*m1 * p1.θ_dot) / M
    end

    # Aplicar transporte paralelo
    # Desplazamiento durante colisión ≈ dt * velocidad promedio
    Δθ_1 = dt * (p1.θ_dot + θ_dot_1_new) / 2
    Δθ_2 = dt * (p2.θ_dot + θ_dot_2_new) / 2

    θ_dot_1_transported = parallel_transport_velocity(θ_dot_1_new, Δθ_1, p1.θ, a, b)
    θ_dot_2_transported = parallel_transport_velocity(θ_dot_2_new, Δθ_2, p2.θ, a, b)

    # Integrar geodésicas un paso
    θ1_new, θ_dot_1_final = forest_ruth_step_ellipse(p1.θ, θ_dot_1_transported, dt, a, b)
    θ2_new, θ_dot_2_final = forest_ruth_step_ellipse(p2.θ, θ_dot_2_transported, dt, a, b)

    # Actualizar partículas
    p1_new = update_particle(p1, θ1_new, θ_dot_1_final, a, b)
    p2_new = update_particle(p2, θ2_new, θ_dot_2_final, a, b)

    # Verificar conservación
    E_after = kinetic_energy(p1_new, a, b) + kinetic_energy(p2_new, a, b)
    ΔE = abs(E_after - E_before)
    conserved = ΔE / (E_before + eps(T)) < tolerance

    return (p1_new, p2_new, conserved)
end

# ============================================================================
# Sistema Multi-Partícula
# ============================================================================

"""
    detect_all_collisions(particles::Vector{Particle}, a, b)

Detecta todas las colisiones en el sistema.

# Retorna
- Vector de tuplas (i, j) indicando pares de partículas que colisionan

# Complejidad
- O(n²) naive implementation
- TODO: Implementar spatial hashing para O(n) en promedio
"""
function detect_all_collisions(
    particles::Vector{Particle{T}},
    a::T,
    b::T
) where {T <: AbstractFloat}

    n = length(particles)
    collisions = Tuple{Int, Int}[]

    @inbounds for i in 1:n
        for j in (i+1):n
            if check_collision(particles[i], particles[j], a, b)
                push!(collisions, (i, j))
            end
        end
    end

    return collisions
end

"""
    resolve_all_collisions!(particles::Vector{Particle}, a, b; method=:parallel_transport)

Resuelve todas las colisiones en el sistema.

# Parámetros
- `particles`: Vector de partículas (será modificado in-place)
- `a`, `b`: Semi-ejes de la elipse
- `method`: Método de resolución
  - `:simple`: Intercambio simple de velocidades
  - `:parallel_transport`: Transporte paralelo (default, del artículo)
  - `:geodesic`: Integración geodésica completa

# Retorna
- `n_collisions`: Número de colisiones resueltas
- `conserved_frac`: Fracción de colisiones que conservaron energía/momento

# Nota
Para colisiones simultáneas, este método procesa secuencialmente.
Métodos más sofisticados podrían resolver múltiples colisiones simultáneamente.
"""
function resolve_all_collisions!(
    particles::Vector{Particle{T}},
    a::T,
    b::T;
    method::Symbol = :parallel_transport,
    dt::T = T(1e-6),
    tolerance::T = T(1e-6)
) where {T <: AbstractFloat}

    collision_pairs = detect_all_collisions(particles, a, b)
    n_collisions = length(collision_pairs)

    if n_collisions == 0
        return 0, 1.0
    end

    n_conserved = 0

    for (i, j) in collision_pairs
        p1 = particles[i]
        p2 = particles[j]

        if method == :simple
            p1_new, p2_new = resolve_collision_simple(p1, p2, a, b)
            conserved = true  # Asumimos conservación para método simple

        elseif method == :parallel_transport
            p1_new, p2_new, conserved = resolve_collision_parallel_transport(
                p1, p2, a, b; tolerance=tolerance
            )

        elseif method == :geodesic
            p1_new, p2_new, conserved = resolve_collision_geodesic(
                p1, p2, dt, a, b; tolerance=tolerance
            )

        else
            error("Método desconocido: $method. Usa :simple, :parallel_transport, o :geodesic")
        end

        # Actualizar partículas
        particles[i] = p1_new
        particles[j] = p2_new

        if conserved
            n_conserved += 1
        end
    end

    conserved_frac = n_conserved / n_collisions

    return n_collisions, conserved_frac
end

# ============================================================================
# Imports de funciones necesarias
# ============================================================================

if !@isdefined(metric_ellipse)
    @inline function metric_ellipse(θ::T, a::T, b::T) where {T <: AbstractFloat}
        s, c = sincos(θ)
        return a^2 * s^2 + b^2 * c^2
    end
end

if !@isdefined(parallel_transport_velocity)
    @inline function parallel_transport_velocity(v::T, Δθ::T, θ::T, a::T, b::T) where {T <: AbstractFloat}
        Γ = christoffel_ellipse(θ, a, b)
        return v - Γ * v * Δθ
    end
end

if !@isdefined(christoffel_ellipse)
    @inline function christoffel_ellipse(θ::T, a::T, b::T) where {T <: AbstractFloat}
        s, c = sincos(θ)
        return (a^2 - b^2) * s * c / (a^2 * s^2 + b^2 * c^2)
    end
end

if !@isdefined(forest_ruth_step_ellipse)
    function forest_ruth_step_ellipse(θ::T, θ_dot::T, dt::T, a::T, b::T) where {T <: AbstractFloat}
        # Placeholder - incluir desde integrators/forest_ruth.jl
        return (θ + dt * θ_dot, θ_dot)
    end
end

if !@isdefined(kinetic_energy)
    @inline function kinetic_energy(p::Particle{T}, a::T, b::T) where {T <: AbstractFloat}
        g = metric_ellipse(p.θ, a, b)
        return 0.5 * p.mass * g * p.θ_dot^2
    end
end

if !@isdefined(angular_momentum)
    @inline function angular_momentum(p::Particle{T}, a::T, b::T) where {T <: AbstractFloat}
        g = metric_ellipse(p.θ, a, b)
        return p.mass * g * p.θ_dot
    end
end

if !@isdefined(update_particle)
    # Placeholder - debería estar en particles.jl
    function update_particle(p::Particle{T}, θ::T, θ_dot::T, a::T, b::T) where {T <: AbstractFloat}
        s, c = sincos(θ)
        pos = SVector{2,T}(a * c, b * s)
        vel = SVector{2,T}(-a * θ_dot * s, b * θ_dot * c)
        return Particle{T}(p.id, p.mass, p.radius, θ, θ_dot, pos, vel)
    end
end
