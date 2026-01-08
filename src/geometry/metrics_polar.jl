"""
    metrics_polar.jl

Métrica Riemanniana para elipse en coordenadas POLARES VERDADERAS φ.

Parametrización:
    r(φ) = ab/√(a²sin²φ + b²cos²φ)
    x(φ) = r(φ)cos(φ)
    y(φ) = r(φ)sin(φ)

donde φ es el ángulo polar real (no el ángulo excéntrico).

Esta parametrización es más natural para análisis de curvatura y distribuciones angulares.
"""

using StaticArrays
using LinearAlgebra

# ============================================================================
# Función auxiliar r(φ)
# ============================================================================

"""
    radial_ellipse(φ, a, b)

Calcula el radio r(φ) en coordenadas polares para la elipse.

# Fórmula
```
r(φ) = ab/√(a²sin²φ + b²cos²φ)
```

# Parámetros
- `φ`: Ángulo polar verdadero
- `a`: Semi-eje mayor
- `b`: Semi-eje menor

# Retorna
- r(φ): Radio desde el origen
"""
@inline function radial_ellipse(φ::Real, a::Real, b::Real)
    T = promote_type(typeof(φ), typeof(a), typeof(b))
    φ_T, a_T, b_T = T(φ), T(a), T(b)
    s, c = sincos(φ_T)
    # Use abs() to handle tiny negative values from roundoff (~-1e-16)
    denominator = sqrt(abs(a_T^2 * s^2 + b_T^2 * c^2))
    return a_T * b_T / denominator
end

"""
    radial_derivative_ellipse(φ, a, b)

Calcula dr/dφ analíticamente.

# Derivación
Sea S = a²sin²φ + b²cos²φ, entonces r = ab/√S

    dr/dφ = -ab/(2S^(3/2)) · dS/dφ

    dS/dφ = 2a²sinφ·cosφ - 2b²cosφ·sinφ
          = 2sinφ·cosφ(a² - b²)
          = (a² - b²)sin(2φ)

    dr/dφ = -ab(a² - b²)sin(2φ)/(2S^(3/2))

# Retorna
- dr/dφ
"""
@inline function radial_derivative_ellipse(φ::Real, a::Real, b::Real)
    T = promote_type(typeof(φ), typeof(a), typeof(b))
    φ_T, a_T, b_T = T(φ), T(a), T(b)
    s, c = sincos(φ_T)
    S = a_T^2 * s^2 + b_T^2 * c^2
    sin2φ = sin(2 * φ_T)

    numerator = -a_T * b_T * (a_T^2 - b_T^2) * sin2φ
    denominator = 2 * S^(3/2)

    return numerator / denominator
end

# ============================================================================
# Métrica g_φφ
# ============================================================================

"""
    metric_ellipse_polar(φ, a, b)

Calcula la métrica g_φφ para elipse en coordenadas polares.

# Matemática
Para coordenadas polares (r, φ), la métrica es:

    ds² = dr² + r²dφ²

En nuestra parametrización con φ como coordenada única:

    g_φφ = (dr/dφ)² + r²

# Retorna
- g_φφ(φ)

# Ejemplo
```julia
g = metric_ellipse_polar(π/4, 2.0, 1.0)
```
"""
@inline function metric_ellipse_polar(φ::T, a::T, b::T) where {T <: Real}
    r = radial_ellipse(φ, a, b)
    dr_dφ = radial_derivative_ellipse(φ, a, b)

    return dr_dφ^2 + r^2
end

"""
    metric_ellipse_polar_expanded(φ, a, b)

Versión expandida de la métrica para verificación numérica.
Calcula directamente (dx/dφ)² + (dy/dφ)².
"""
@inline function metric_ellipse_polar_expanded(φ::T, a::T, b::T) where {T <: Real}
    r = radial_ellipse(φ, a, b)
    dr_dφ = radial_derivative_ellipse(φ, a, b)
    s, c = sincos(φ)

    # dx/dφ = (dr/dφ)cos(φ) - r·sin(φ)
    dx_dφ = dr_dφ * c - r * s

    # dy/dφ = (dr/dφ)sin(φ) + r·cos(φ)
    dy_dφ = dr_dφ * s + r * c

    return dx_dφ^2 + dy_dφ^2
end

# ============================================================================
# Métrica inversa
# ============================================================================

"""
    inverse_metric_ellipse_polar(φ, a, b)

Calcula la métrica inversa g^φφ = 1/g_φφ.
"""
@inline function inverse_metric_ellipse_polar(φ::T, a::T, b::T) where {T <: Real}
    g = metric_ellipse_polar(φ, a, b)
    return one(T) / g
end

# ============================================================================
# Derivadas de la métrica (para Christoffel)
# ============================================================================

"""
    metric_derivative_polar(φ, a, b)

Calcula ∂_φ g_φφ analíticamente.

# Matemática
    g_φφ = (dr/dφ)² + r²

    ∂_φ g_φφ = 2(dr/dφ)(d²r/dφ²) + 2r(dr/dφ)

Necesitamos d²r/dφ² (segunda derivada del radio).
"""
function metric_derivative_polar(φ::T, a::T, b::T) where {T <: Real}
    # Aproximación numérica usando diferencias finitas
    # (Para implementación analítica completa, derivar d²r/dφ²)

    h = sqrt(eps(T)) * max(one(T), abs(φ))
    g_plus = metric_ellipse_polar(φ + h, a, b)
    g_minus = metric_ellipse_polar(φ - h, a, b)

    return (g_plus - g_minus) / (2 * h)
end

# ============================================================================
# Coordenadas Cartesianas
# ============================================================================

"""
    cartesian_from_polar_angle(φ, a, b)

Convierte ángulo polar φ a coordenadas cartesianas (x, y).

# Retorna
- `SVector{2}(x, y)`
"""
@inline function cartesian_from_polar_angle(φ::T, a::T, b::T) where {T <: Real}
    r = radial_ellipse(φ, a, b)
    s, c = sincos(φ)
    return SVector(r * c, r * s)
end

"""
    velocity_from_polar_angular(φ, φ_dot, a, b)

Convierte velocidad angular φ̇ a velocidad cartesiana (vx, vy).

# Matemática
    dx/dt = (dx/dφ)(dφ/dt) = [(dr/dφ)cos(φ) - r·sin(φ)]·φ̇
    dy/dt = (dy/dφ)(dφ/dt) = [(dr/dφ)sin(φ) + r·cos(φ)]·φ̇

# Retorna
- `SVector{2}(vx, vy)`
"""
@inline function velocity_from_polar_angular(φ::T, φ_dot::T, a::T, b::T) where {T <: Real}
    r = radial_ellipse(φ, a, b)
    dr_dφ = radial_derivative_ellipse(φ, a, b)
    s, c = sincos(φ)

    vx = (dr_dφ * c - r * s) * φ_dot
    vy = (dr_dφ * s + r * c) * φ_dot

    return SVector(vx, vy)
end

# ============================================================================
# Energía cinética
# ============================================================================

"""
    kinetic_energy_polar(φ, φ_dot, mass, a, b)

Calcula energía cinética en coordenadas polares.

# Matemática
    T = (1/2) m g_φφ φ̇²

# Retorna
- Energía cinética T
"""
@inline function kinetic_energy_polar(
    φ::T, φ_dot::T, mass::T, a::T, b::T
) where {T <: Real}
    g = metric_ellipse_polar(φ, a, b)
    return 0.5 * mass * g * φ_dot^2
end

# ============================================================================
# Curvatura en coordenadas polares
# ============================================================================

"""
    curvature_ellipse_polar(φ, a, b)

Calcula la curvatura κ(φ) de la elipse en el punto φ.

# Fórmula
Para una curva en polares r(φ):

    κ = |r² + 2(dr/dφ)² - r(d²r/dφ²)| / (r² + (dr/dφ)²)^(3/2)

# Retorna
- κ(φ): Curvatura en el punto φ
"""
function curvature_ellipse_polar(φ::T, a::T, b::T) where {T <: Real}
    r = radial_ellipse(φ, a, b)

    # Primera derivada
    dr_dφ = radial_derivative_ellipse(φ, a, b)

    # Segunda derivada (numérica por ahora)
    h = sqrt(eps(T)) * max(one(T), abs(φ))
    dr_plus = radial_derivative_ellipse(φ + h, a, b)
    dr_minus = radial_derivative_ellipse(φ - h, a, b)
    d2r_dφ2 = (dr_plus - dr_minus) / (2 * h)

    # Curvatura
    numerator = abs(r^2 + 2 * dr_dφ^2 - r * d2r_dφ2)
    denominator = (r^2 + dr_dφ^2)^(3/2)

    return numerator / denominator
end

# ============================================================================
# Longitud de arco (geometría intrínseca)
# ============================================================================

"""
    arc_length_between(φ1, φ2, a, b; method=:midpoint)

Calcula la longitud de arco geodésica entre dos puntos en la elipse.

# Matemática
Para una curva parametrizada por φ, la longitud de arco es:

    s = ∫_{φ1}^{φ2} √g_φφ dφ

donde g_φφ = r² + (dr/dφ)²

# Parámetros
- `φ1, φ2`: Ángulos polares (en radianes)
- `a, b`: Semi-ejes de la elipse
- `method`: Método de integración
  - `:midpoint` - Punto medio (rápido, buena precisión para Δφ pequeño)
  - `:trapezoidal` - Regla del trapecio (más preciso para Δφ grandes)

# Retorna
- Longitud de arco s ≥ 0

# Ejemplo
```julia
s = arc_length_between(0.0, π/2, 2.0, 1.0; method=:midpoint)  # Cuarto de elipse
```
"""
function arc_length_between(
    φ1::T, φ2::T, a::T, b::T;
    method::Symbol=:midpoint
) where {T <: Real}

    # Manejar caso Δφ = 0
    if abs(φ2 - φ1) < eps(T)
        return zero(T)
    end

    # Asegurar φ1 < φ2
    if φ1 > φ2
        φ1, φ2 = φ2, φ1
    end

    if method == :midpoint
        # Aproximación de punto medio (muy eficiente para Δφ pequeño)
        φ_mid = (φ1 + φ2) / 2
        g_mid = metric_ellipse_polar(φ_mid, a, b)
        # Use abs() for numerical safety (g_mid should always be positive)
        return abs(φ2 - φ1) * sqrt(abs(g_mid))

    elseif method == :trapezoidal
        # Regla del trapecio
        n_points = max(10, ceil(Int, abs(φ2 - φ1) * 50))
        φ_vals = range(φ1, φ2, length=n_points)

        # Use abs() for numerical safety (metric should always be positive)
        integrand = sqrt.(abs.(metric_ellipse_polar.(φ_vals, a, b)))

        # Trapecio
        h = (φ2 - φ1) / (n_points - 1)
        s = h * (integrand[1]/2 + sum(integrand[2:end-1]) + integrand[end]/2)
        return s

    else
        error("Método desconocido: $method. Use :midpoint o :trapezoidal")
    end
end

"""
    angular_distance(φ1, φ2)

Calcula la distancia angular mínima entre dos ángulos en [0, 2π].
Considera la periodicidad del círculo.

# Ejemplo
```julia
Δφ = angular_distance(0.1, 2π - 0.1)  # → 0.2, no ~2π
```
"""
@inline function angular_distance(φ1::T, φ2::T) where {T <: Real}
    # Normalizar a [0, 2π)
    φ1_norm = mod(φ1, 2π)
    φ2_norm = mod(φ2, 2π)

    # Distancia directa
    Δφ_direct = abs(φ2_norm - φ1_norm)

    # Distancia dando la vuelta
    Δφ_wrap = 2π - Δφ_direct

    # Retornar la mínima
    return min(Δφ_direct, Δφ_wrap)
end

"""
    arc_length_between_periodic(φ1, φ2, a, b; method=:midpoint)

Calcula la longitud de arco considerando periodicidad (camino más corto).

Para partículas en una elipse cerrada, puede ser más corto ir en dirección
opuesta si los ángulos están cerca de 0/2π.

# Retorna
- Longitud de arco del camino más corto
"""
function arc_length_between_periodic(
    φ1::T, φ2::T, a::T, b::T;
    method::Symbol=:midpoint
) where {T <: Real}

    # Normalizar ángulos
    φ1_norm = mod(φ1, 2π)
    φ2_norm = mod(φ2, 2π)

    # Distancia angular en ambas direcciones
    Δφ_direct = abs(φ2_norm - φ1_norm)
    Δφ_wrap = 2π - Δφ_direct

    # Calcular longitud en ambas direcciones
    if Δφ_direct <= Δφ_wrap
        # Camino directo es más corto
        return arc_length_between(φ1_norm, φ2_norm, a, b; method=method)
    else
        # Camino envolvente es más corto
        # Perímetro total menos el arco directo
        perimeter = ellipse_perimeter(a, b)
        s_direct = arc_length_between(φ1_norm, φ2_norm, a, b; method=method)
        return perimeter - s_direct
    end
end

"""
    ellipse_perimeter(a, b; method=:ramanujan)

Calcula el perímetro de una elipse.

# Métodos
- `:ramanujan` - Aproximación de Ramanujan II (error < 10⁻¹⁰ para e < 0.99)
- `:integral` - Integración numérica exacta

# Fórmula de Ramanujan II
```
P ≈ π(a + b)[1 + 3h/(10 + √(4 - 3h))]
donde h = ((a-b)/(a+b))²
```

# Retorna
- Perímetro P
"""
function ellipse_perimeter(a::T, b::T; method::Symbol=:ramanujan) where {T <: Real}

    if a == b
        # Círculo
        return 2π * a
    end

    if method == :ramanujan
        # Aproximación de Ramanujan II
        h = ((a - b) / (a + b))^2
        # Use max(1, ...) for numerical safety (should be in [1,4])
        P = π * (a + b) * (1 + 3*h / (10 + sqrt(max(1.0, 4 - 3*h))))
        return P

    else  # :integral
        # Integración numérica exacta
        return arc_length_between(zero(T), 2π, a, b; method=:trapezoidal)
    end
end

# ============================================================================
# Packing Fraction Intrínseco
# ============================================================================

"""
    intrinsic_packing_fraction(N, radius, a, b)

Calcula la fracción de empaquetamiento intrínseca (sobre la curva).

# Definición
Para partículas como segmentos de arco de longitud `2*radius` cada una:

    φ_intrinsic = N × 2 × radius / Perimeter

# Parámetros
- `N`: Número de partículas
- `radius`: Radio de cada partícula (mitad de longitud del segmento)
- `a, b`: Semi-ejes de la elipse

# Retorna
- φ_intrinsic ∈ [0, 1]

# Nota
φ_intrinsic > 0.5 indica packing muy alto (difícil generar ICs aleatorias)
φ_intrinsic > 0.9 indica packing casi imposible
"""
function intrinsic_packing_fraction(N::Int, radius::T, a::T, b::T) where {T <: Real}
    perimeter = ellipse_perimeter(a, b)
    total_length = N * 2 * radius
    return total_length / perimeter
end

"""
    radius_from_packing(N, φ_target, a, b)

Calcula el radio de partícula para alcanzar un packing fraction objetivo.

# Matemática
    φ = N × 2r / P
    r = φ × P / (2N)

# Parámetros
- `N`: Número de partículas
- `φ_target`: Packing fraction deseado (típicamente 0.3-0.5)
- `a, b`: Semi-ejes de la elipse

# Retorna
- radio óptimo

# Ejemplo
```julia
# Para N=100 partículas con φ=0.4 en elipse (3, 0.5):
r = radius_from_packing(100, 0.4, 3.0, 0.5)
```
"""
function radius_from_packing(N::Int, φ_target::T, a::T, b::T) where {T <: Real}
    perimeter = ellipse_perimeter(a, b)
    return φ_target * perimeter / (2 * N)
end

"""
    radius_from_max_particles(a, b; max_particles=100)

Calcula el radio de partícula tal que exactamente `max_particles` partículas
cubren completamente el perímetro de la elipse.

# Matemática
Si `max_particles` partículas de diámetro `d` cubren el perímetro `P`:
    max_particles × d = P
    d = P / max_particles
    r = d / 2 = P / (2 × max_particles)

# Parámetros
- `a, b`: Semi-ejes de la elipse
- `max_particles`: Número de partículas que cubrirían completamente la curva (default: 100)

# Retorna
- Radio fijo independiente del número real de partículas N

# Ejemplo
```julia
# Para una elipse con perímetro P=10, max_particles=100:
# r = 10 / 200 = 0.05
r = radius_from_max_particles(2.0, 1.0; max_particles=100)

# Con N=20 partículas de este tamaño:
# φ = 20 × 2 × 0.05 / 10 = 0.20 (20% del perímetro ocupado)

# Con N=80 partículas de este tamaño:
# φ = 80 × 2 × 0.05 / 10 = 0.80 (80% del perímetro ocupado)
```

# Nota
Este método garantiza tamaño de partícula consistente independiente de N,
útil para estudios de finite-size scaling donde se varía N pero se quiere
mantener el "tamaño característico" de las partículas fijo.
"""
function radius_from_max_particles(a::T, b::T; max_particles::Int=100) where {T <: Real}
    perimeter = ellipse_perimeter(a, b)
    return perimeter / (2 * max_particles)
end

"""
    max_particles_for_radius(radius, φ_max, a, b)

Calcula el número máximo de partículas que caben con un radio dado.

# Matemática
    N_max = floor(φ_max × P / (2r))

# Parámetros
- `radius`: Radio de partícula
- `φ_max`: Packing fraction máximo permitido (ej. 0.5)
- `a, b`: Semi-ejes de la elipse

# Retorna
- N_max (entero)
"""
function max_particles_for_radius(radius::T, φ_max::T, a::T, b::T) where {T <: Real}
    perimeter = ellipse_perimeter(a, b)
    return floor(Int, φ_max * perimeter / (2 * radius))
end

# ============================================================================
# Conversión θ ↔ φ (para transición desde código anterior)
# ============================================================================

"""
    polar_angle_from_eccentric(θ, a, b)

Convierte ángulo excéntrico θ a ángulo polar φ.

# Matemática
Dado:
    x = a·cos(θ), y = b·sin(θ)  (excéntrico)

Queremos:
    φ = atan(y, x)

# Retorna
- φ ∈ [0, 2π)
"""
@inline function polar_angle_from_eccentric(θ::T, a::T, b::T) where {T <: Real}
    s, c = sincos(θ)
    x = a * c
    y = b * s
    φ = atan(y, x)
    return φ < 0 ? φ + 2π : φ
end

"""
    eccentric_angle_from_polar(φ, a, b)

Convierte ángulo polar φ a ángulo excéntrico θ (aproximación iterativa).

# Nota
No hay fórmula cerrada en general. Usa Newton-Raphson.
"""
function eccentric_angle_from_polar(φ::T, a::T, b::T;
                                    max_iter::Int=10,
                                    tol::T=T(1e-12)) where {T <: Real}
    # Aproximación inicial
    θ = φ

    for _ in 1:max_iter
        φ_calc = polar_angle_from_eccentric(θ, a, b)
        error = φ - φ_calc

        if abs(error) < tol
            return θ
        end

        # Corrección (gradiente descendiente simple)
        θ += error * 0.5
        θ = mod(θ, 2π)
    end

    return θ
end
