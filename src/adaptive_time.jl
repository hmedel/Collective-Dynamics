"""
    adaptive_time.jl

Sistema de tiempos adaptativos para colisiones en variedades curvas.

Como se describe en el artículo, el algoritmo debe:
1. Calcular el tiempo hasta la próxima colisión para cada par de partículas
2. Ajustar dt al tiempo de la colisión más próxima
3. Evolucionar el sistema ese tiempo
4. Resolver colisiones que ocurran
5. Repetir

Incluye detección de partículas "pegadas" (stuck) para evitar timesteps
infinitesimales que detengan la simulación.
"""

using StaticArrays
using LinearAlgebra

# ============================================================================
# Predicción de Tiempo a Colisión
# ============================================================================

"""
    time_to_collision(p1::Particle, p2::Particle, a, b; max_time=Inf)

Predice el tiempo hasta que dos partículas colisionen.

# Algoritmo
Resuelve numéricamente para encontrar t tal que:
```
d_geodesic(θ₁(t), θ₂(t)) = r₁ + r₂
```

donde θᵢ(t) son las posiciones evolucionadas bajo geodésicas.

# Aproximación
Para tiempos cortos, asumimos velocidades angulares aproximadamente constantes:
```
θᵢ(t) ≈ θᵢ(0) + θ̇ᵢ(0) * t
```

Esto es válido porque dt es pequeño y la aceleración geodésica
Γ θ̇² es de segundo orden.

# Parámetros
- `p1`, `p2`: Partículas
- `a`, `b`: Semi-ejes de la elipse
- `max_time`: Tiempo máximo a considerar (default: Inf)

# Retorna
- `t`: Tiempo hasta colisión (Inf si no colisionan en [0, max_time])

# Notas
- Si las partículas se alejan, retorna Inf
- Si ya están colisionando, retorna 0
- Usa bisección para encontrar el tiempo exacto
"""
@inline function time_to_collision(
    p1::Particle{T},
    p2::Particle{T},
    a::T,
    b::T;
    max_time::T = T(Inf)
) where {T <: AbstractFloat}

    # Si ya están colisionando, tiempo = 0
    if check_collision(p1, p2, a, b)
        return zero(T)
    end

    θ1, θ2 = p1.θ, p2.θ
    θ_dot1, θ_dot2 = p1.θ_dot, p2.θ_dot
    r_sum = p1.radius + p2.radius

    # Velocidad relativa (aproximada)
    θ_rel = θ2 - θ1
    θ_dot_rel = θ_dot2 - θ_dot1

    # Si se alejan (aproximación de primer orden), no colisionan
    # Derivada de la separación: d/dt(θ2 - θ1) = θ_dot2 - θ_dot1
    if abs(θ_dot_rel) < eps(T)
        # Velocidades iguales, no se acercan
        return T(Inf)
    end

    # Estimación inicial: tiempo cuando θ_rel → 0 (si se mueven en círculo)
    # Más precisamente, necesitamos resolver numéricamente

    # Función objetivo: distancia geodésica - suma de radios
    function separation_at_time(t::T)
        # Posiciones aproximadas (velocidades constantes)
        θ1_t = θ1 + θ_dot1 * t
        θ2_t = θ2 + θ_dot2 * t

        # Diferencia angular (tomando camino más corto)
        Δθ = abs(θ2_t - θ1_t)
        Δθ = min(Δθ, T(2π) - Δθ)

        # Distancia geodésica aproximada
        θ_mid = (θ1_t + θ2_t) / 2
        g_mid = sqrt(metric_ellipse(θ_mid, a, b))
        d_geo = g_mid * Δθ

        return d_geo - r_sum
    end

    # Distancia inicial
    sep_0 = separation_at_time(zero(T))

    # Si sep_0 <= 0, ya están colisionando
    if sep_0 <= zero(T)
        return zero(T)
    end

    # Distancia a max_time
    if isfinite(max_time)
        sep_max = separation_at_time(max_time)
        # Si sep_max > 0, no colisionan en el intervalo
        if sep_max > zero(T)
            return T(Inf)
        end
    end

    # Buscar tiempo de colisión usando bisección
    t_min = zero(T)
    t_max = isfinite(max_time) ? max_time : T(10.0)  # Límite razonable si max_time es Inf

    # Si sep(t_max) > 0, buscar hacia adelante
    while separation_at_time(t_max) > zero(T) && t_max < T(100.0)
        t_max *= 2
    end

    # Si aún no cruza, no hay colisión
    if separation_at_time(t_max) > zero(T)
        return T(Inf)
    end

    # Bisección para encontrar t_collision
    tolerance = eps(T) * 100
    max_iterations = 50

    for _ in 1:max_iterations
        t_mid = (t_min + t_max) / 2
        sep_mid = separation_at_time(t_mid)

        if abs(sep_mid) < tolerance || (t_max - t_min) < tolerance
            return t_mid
        end

        if sep_mid > zero(T)
            t_min = t_mid
        else
            t_max = t_mid
        end
    end

    # Retornar mejor estimación
    return (t_min + t_max) / 2
end

"""
    find_next_collision(particles::Vector{Particle}, a, b; max_time=Inf, min_dt=1e-10)

Encuentra la próxima colisión en el sistema de partículas.

# Parámetros
- `particles`: Vector de partículas
- `a`, `b`: Semi-ejes
- `max_time`: Tiempo máximo a buscar
- `min_dt`: Tiempo mínimo para evitar partículas pegadas

# Retorna
- `NamedTuple`:
  - `dt`: Tiempo hasta la próxima colisión
  - `pair`: Tupla (i, j) de índices que colisionan
  - `found`: Boolean indicando si se encontró colisión

# Notas
Si ninguna colisión ocurre en [0, max_time], retorna dt = max_time y found = false.
Si el tiempo a colisión es < min_dt, se considera partículas "pegadas" y se usa min_dt.
"""
function find_next_collision(
    particles::Vector{Particle{T}},
    a::T,
    b::T;
    max_time::T = T(Inf),
    min_dt::T = T(1e-10)
) where {T <: AbstractFloat}

    n = length(particles)
    t_min = max_time
    pair_min = (0, 0)
    found = false

    # Buscar tiempo mínimo sobre todos los pares
    @inbounds for i in 1:n
        for j in (i+1):n
            t_coll = time_to_collision(particles[i], particles[j], a, b; max_time=max_time)

            if isfinite(t_coll) && t_coll < t_min
                t_min = t_coll
                pair_min = (i, j)
                found = true
            end
        end
    end

    # Aplicar tiempo mínimo para evitar partículas pegadas
    if found && t_min < min_dt
        t_min = min_dt
    end

    return (dt = t_min, pair = pair_min, found = found)
end

# ============================================================================
# Imports de funciones necesarias
# ============================================================================

if !@isdefined(Particle)
    @warn "Particle type not defined, adaptive_time.jl needs particles.jl"
end

if !@isdefined(check_collision)
    function check_collision(p1::Particle{T}, p2::Particle{T}, a::T, b::T) where {T <: AbstractFloat}
        Δθ = abs(p1.θ - p2.θ)
        Δθ = min(Δθ, 2*T(π) - Δθ)
        θ_mid = (p1.θ + p2.θ) / 2
        g_mid = sqrt(metric_ellipse(θ_mid, a, b))
        arc_length = g_mid * Δθ
        return arc_length <= (p1.radius + p2.radius)
    end
end

if !@isdefined(metric_ellipse)
    @inline function metric_ellipse(θ::Real, a::Real, b::Real)
        s, c = sincos(θ)
        return a^2 * s^2 + b^2 * c^2
    end
end
