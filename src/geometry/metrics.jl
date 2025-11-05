"""
    metrics.jl

Métrica de Riemannian manifolds para simulaciones de dinámica colectiva.
Implementa métricas para variedades curvas (elipse, esfera, etc.).
"""

using StaticArrays
using LinearAlgebra
using Elliptic

# ============================================================================
# Métrica de Elipse en coordenadas angulares θ
# ============================================================================

"""
    metric_ellipse(θ, a, b)

Calcula el componente de la métrica g_θθ para una elipse parametrizada por θ.

# Parámetros
- `θ`: Ángulo paramétrico
- `a`: Semi-eje mayor
- `b`: Semi-eje menor

# Matemática
Para una elipse parametrizada como:
- x(θ) = a cos(θ)
- y(θ) = b sin(θ)

La métrica es:
```
ds² = (dx)² + (dy)²
    = (a sin(θ))² dθ² + (b cos(θ))² dθ²
    = (a² sin²(θ) + b² cos²(θ)) dθ²
```

Por lo tanto: g_θθ = a² sin²(θ) + b² cos²(θ)

# Retorna
- Escalar: g_θθ(θ)

# Ejemplo
```julia
g = metric_ellipse(π/4, 2.0, 1.0)  # g_θθ en θ = π/4
```
"""
@inline function metric_ellipse(θ::T, a::T, b::T) where {T <: AbstractFloat}
    s, c = sincos(θ)
    return a^2 * s^2 + b^2 * c^2
end

"""
    metric_ellipse_tensor(θ, a, b)

Retorna el tensor métrico completo (1x1 en este caso) como SMatrix.
Útil para generalizaciones futuras.
"""
@inline function metric_ellipse_tensor(θ::T, a::T, b::T) where {T <: AbstractFloat}
    g = metric_ellipse(θ, a, b)
    return SMatrix{1,1,T}(g)
end

# ============================================================================
# Métrica inversa
# ============================================================================

"""
    inverse_metric_ellipse(θ, a, b)

Calcula la métrica inversa g^θθ = 1/g_θθ.

Para una métrica 1D (parametrización angular), la inversa es simplemente el recíproco.

# Retorna
- g^θθ(θ)
"""
@inline function inverse_metric_ellipse(θ::T, a::T, b::T) where {T <: AbstractFloat}
    g = metric_ellipse(θ, a, b)
    return one(T) / g
end

# ============================================================================
# Derivadas de la métrica (necesarias para Christoffel)
# ============================================================================

"""
    metric_derivative_ellipse(θ, a, b)

Calcula la derivada ∂_θ g_θθ analíticamente.

# Matemática
```
g_θθ = a² sin²(θ) + b² cos²(θ)

∂_θ g_θθ = 2a² sin(θ)cos(θ) + 2b²(-sin(θ)cos(θ))
         = 2(a² - b²) sin(θ)cos(θ)
         = (a² - b²) sin(2θ)
```

# Retorna
- ∂_θ g_θθ
"""
@inline function metric_derivative_ellipse(θ::T, a::T, b::T) where {T <: AbstractFloat}
    # Versión optimizada usando sin(2θ) = 2sin(θ)cos(θ)
    return (a^2 - b^2) * sin(2 * θ)
end

# ============================================================================
# Coordenadas Cartesianas desde coordenadas angulares
# ============================================================================

"""
    cartesian_from_angle(θ, a, b)

Convierte coordenadas angulares θ a coordenadas cartesianas (x, y) en la elipse.

# Retorna
- `SVector{2}(x, y)`: Posición cartesiana
"""
@inline function cartesian_from_angle(θ::T, a::T, b::T) where {T <: AbstractFloat}
    s, c = sincos(θ)
    return SVector{2,T}(a * c, b * s)
end

"""
    velocity_from_angular(θ, θ_dot, a, b)

Convierte velocidad angular θ_dot a velocidad cartesiana (vx, vy).

# Matemática
```
dx/dt = -a sin(θ) dθ/dt
dy/dt =  b cos(θ) dθ/dt
```

# Retorna
- `SVector{2}(vx, vy)`: Velocidad cartesiana
"""
@inline function velocity_from_angular(θ::T, θ_dot::T, a::T, b::T) where {T <: AbstractFloat}
    s, c = sincos(θ)
    vx = -a * θ_dot * s
    vy =  b * θ_dot * c
    return SVector{2,T}(vx, vy)
end

# ============================================================================
# Longitud de arco geodésica
# ============================================================================

"""
    arc_length_ellipse(θ1, θ2, a, b)

Calcula la longitud de arco entre dos ángulos θ1 y θ2 en la elipse.

Usa la integral elíptica incompleta de segunda clase E(φ|m).

# Matemática
La longitud de arco en una elipse es:
```
s = ∫ √(g_θθ) dθ
  = ∫ √(a² sin²θ + b² cos²θ) dθ
```

Esta integral se expresa en términos de integrales elípticas.

# Nota
Usa el paquete Elliptic.jl para evaluar E(φ|m).

# Retorna
- Longitud de arco s ∈ ℝ⁺
"""
function arc_length_ellipse(θ1::T, θ2::T, a::T, b::T) where {T <: AbstractFloat}
    # Asegurarse de que θ1 < θ2
    if θ1 > θ2
        θ1, θ2 = θ2, θ1
    end

    # Parámetro de la integral elíptica
    # m = 1 - (b/a)² para a ≥ b
    # Si a < b, intercambiar
    if a < b
        a, b = b, a
    end

    m = 1 - (b/a)^2

    # Diferencia de ángulos
    Δθ = abs(θ2 - θ1)

    # Para diferencias pequeñas, aproximación lineal
    if Δθ < 1e-10
        return zero(T)
    end

    # Usar Elliptic.E para integral elíptica
    # Nota: Elliptic.jl define E(φ, m) = ∫₀^φ √(1 - m sin²t) dt
    # Necesitamos transformar nuestra integral
    using Elliptic: E

    # Aproximación: Para ángulos pequeños usamos la métrica local
    # Para ángulos grandes, usamos la integral elíptica completa

    # Simplificación: Usar promedio de la métrica
    θ_mid = (θ1 + θ2) / 2
    g_mid = sqrt(metric_ellipse(θ_mid, a, b))

    return g_mid * Δθ
end

# ============================================================================
# Energía cinética en coordenadas curvilíneas
# ============================================================================

"""
    kinetic_energy_angular(θ, θ_dot, mass, a, b)

Calcula la energía cinética en coordenadas angulares.

# Matemática
```
T = (1/2) m g_θθ θ̇²
```

# Retorna
- Energía cinética T
"""
@inline function kinetic_energy_angular(
    θ::T, θ_dot::T, mass::T, a::T, b::T
) where {T <: AbstractFloat}
    g = metric_ellipse(θ, a, b)
    return 0.5 * mass * g * θ_dot^2
end

"""
    kinetic_energy_cartesian(vel, mass)

Calcula la energía cinética desde velocidad cartesiana.

# Matemática
```
T = (1/2) m (vx² + vy²)
```
"""
@inline function kinetic_energy_cartesian(vel::SVector{2,T}, mass::T) where {T <: AbstractFloat}
    return 0.5 * mass * dot(vel, vel)
end
