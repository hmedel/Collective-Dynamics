"""
    christoffel.jl

Símbolos de Christoffel para variedades curvas.
Implementa el cálculo analítico y numérico de los símbolos de conexión de Levi-Civita.
"""

using StaticArrays
using ForwardDiff

# ============================================================================
# Símbolos de Christoffel para Elipse (Analítico)
# ============================================================================

"""
    christoffel_ellipse(θ, a, b)

Calcula el símbolo de Christoffel Γ^θ_θθ para una elipse analíticamente.

# Matemática
Para una métrica 1D g_θθ, el símbolo de Christoffel es:

```
Γ^θ_θθ = (1/2) g^θθ ∂_θ g_θθ
       = (1/2g_θθ) ∂_θ g_θθ
```

Para la elipse:
```
g_θθ = a² sin²(θ) + b² cos²(θ)
∂_θ g_θθ = (a² - b²) sin(2θ)

Γ^θ_θθ = (a² - b²) sin(2θ) / (2(a² sin²(θ) + b² cos²(θ)))
       = (a² - b²) sin(θ)cos(θ) / (a² sin²(θ) + b² cos²(θ))
```

# Parámetros
- `θ`: Ángulo paramétrico
- `a`: Semi-eje mayor
- `b`: Semi-eje menor

# Retorna
- Γ^θ_θθ(θ): Símbolo de Christoffel

# Ejemplo
```julia
Γ = christoffel_ellipse(π/4, 2.0, 1.0)
```

# Nota sobre el signo
El símbolo de Christoffel puede ser positivo o negativo dependiendo del cuadrante.
Esto es correcto geométricamente y representa la curvatura local.
"""
@inline function christoffel_ellipse(θ::T, a::T, b::T) where {T <: Real}
    s, c = sincos(θ)

    # Numerador: (a² - b²) sin(θ)cos(θ)
    numerator = (a^2 - b^2) * s * c

    # Denominador: a² sin²(θ) + b² cos²(θ)
    denominator = a^2 * s^2 + b^2 * c^2

    # Evitar división por cero (aunque matemáticamente no debería ocurrir)
    if abs(denominator) < eps(T)
        return zero(T)
    end

    return numerator / denominator
end

"""
    christoffel_ellipse_alt(θ, a, b)

Versión alternativa usando la derivada de la métrica desde metrics.jl.
"""
@inline function christoffel_ellipse_alt(θ::T, a::T, b::T) where {T <: Real}
    g = metric_ellipse(θ, a, b)
    ∂g = metric_derivative_ellipse(θ, a, b)

    if abs(g) < eps(T)
        return zero(T)
    end

    return ∂g / (2 * g)
end

# ============================================================================
# Símbolos de Christoffel Numéricos (Diferencias Finitas)
# ============================================================================

"""
    christoffel_numerical(metric_func, q, h=1e-6)

Calcula símbolos de Christoffel numéricamente usando diferencias finitas centradas.

Este método es genérico y funciona para cualquier métrica, no solo la elipse.
Útil para verificar resultados analíticos o cuando no hay forma cerrada.

# Matemática (Artículo)
```
∂_k g_{ij} ≈ (g_{ij}(q + Δq^k) - g_{ij}(q - Δq^k)) / (2Δq^k)

Γ^i_{jk} = (1/2) g^{il} (∂_j g_{lk} + ∂_k g_{lj} - ∂_l g_{jk})
```

# Parámetros
- `metric_func`: Función que toma coordenadas y retorna g_ij (escalar para 1D)
- `q`: Coordenada(s) actual(es)
- `h`: Paso de diferencia finita (default: 1e-6)

# Retorna
- Γ (para 1D: Γ^q_qq)

# Ejemplo
```julia
metric_fn(θ) = metric_ellipse(θ, 2.0, 1.0)
Γ_num = christoffel_numerical(metric_fn, π/4)
```
"""
function christoffel_numerical(
    metric_func::Function,
    q::T,
    h::T = T(1e-6)
) where {T <: Real}

    # Diferencias finitas centradas para la derivada de la métrica
    g_plus = metric_func(q + h)
    g_minus = metric_func(q - h)
    ∂g = (g_plus - g_minus) / (2 * h)

    # Métrica en el punto actual
    g = metric_func(q)

    if abs(g) < eps(T)
        return zero(T)
    end

    # Para 1D: Γ^q_qq = (1/2g) ∂_q g
    return ∂g / (2 * g)
end

# ============================================================================
# Símbolos de Christoffel usando Diferenciación Automática
# ============================================================================

"""
    christoffel_autodiff(metric_func, q)

Calcula símbolos de Christoffel usando diferenciación automática (ForwardDiff.jl).

Más preciso que diferencias finitas y sin necesidad de elegir h.

# Ejemplo
```julia
metric_fn(θ) = metric_ellipse(θ, 2.0, 1.0)
Γ_ad = christoffel_autodiff(metric_fn, π/4)
```
"""
function christoffel_autodiff(
    metric_func::Function,
    q::T
) where {T <: Real}

    # Derivada automática de la métrica
    ∂g = ForwardDiff.derivative(metric_func, q)

    # Métrica en el punto
    g = metric_func(q)

    if abs(g) < eps(T)
        return zero(T)
    end

    return ∂g / (2 * g)
end

# ============================================================================
# Ecuación Geodésica
# ============================================================================

"""
    geodesic_acceleration(θ, θ_dot, a, b)

Calcula la aceleración geodésica θ̈ desde la ecuación geodésica.

# Matemática
La ecuación geodésica es:
```
d²θ/dt² + Γ^θ_θθ (dθ/dt)² = 0

⟹ θ̈ = -Γ^θ_θθ θ̇²
```

# Parámetros
- `θ`: Posición angular actual
- `θ_dot`: Velocidad angular actual
- `a`, `b`: Semi-ejes de la elipse

# Retorna
- θ̈: Aceleración angular

# Nota
Para movimiento libre (sin fuerzas externas), esta es la única aceleración.
Si hay colisiones u otras fuerzas, se añaden términos adicionales.
"""
@inline function geodesic_acceleration(
    θ::T, θ_dot::T, a::T, b::T
) where {T <: Real}
    Γ = christoffel_ellipse(θ, a, b)
    return -Γ * θ_dot^2
end

# ============================================================================
# Verificación de identidades geométricas
# ============================================================================

"""
    verify_christoffel_symmetry(θ, a, b)

Verifica que Γ^i_{jk} = Γ^i_{kj} (simetría en índices inferiores).

Para 1D esto siempre es verdadero, pero es útil para depuración
y para extensiones a dimensiones superiores.

# Retorna
- `true` si la simetría se satisface dentro de tolerancia numérica
"""
function verify_christoffel_symmetry(θ::T, a::T, b::T, tol::T = T(1e-10)) where {T <: Real}
    # Para 1D, Γ^θ_θθ es trivialmente simétrico
    # Esta función es un placeholder para extensiones futuras
    return true
end

"""
    compare_christoffel_methods(θ, a, b)

Compara los tres métodos de cálculo de Christoffel:
1. Analítico
2. Diferencias finitas
3. Diferenciación automática

Útil para debugging y verificación.

# Retorna
- NamedTuple con (analytic, numerical, autodiff, max_diff)
"""
function compare_christoffel_methods(θ::T, a::T, b::T) where {T <: Real}
    # Analítico
    Γ_analytic = christoffel_ellipse(θ, a, b)

    # Numérico
    metric_fn(x) = metric_ellipse(x, a, b)
    Γ_numerical = christoffel_numerical(metric_fn, θ)

    # Auto-diff
    Γ_autodiff = christoffel_autodiff(metric_fn, θ)

    # Máxima diferencia
    diffs = [
        abs(Γ_analytic - Γ_numerical),
        abs(Γ_analytic - Γ_autodiff),
        abs(Γ_numerical - Γ_autodiff)
    ]
    max_diff = maximum(diffs)

    return (
        analytic = Γ_analytic,
        numerical = Γ_numerical,
        autodiff = Γ_autodiff,
        max_diff = max_diff
    )
end

# ============================================================================
# Import de la función de métrica (para que funcione standalone)
# ============================================================================

# Incluir localmente si metrics.jl no está cargado
if !@isdefined(metric_ellipse)
    @inline function metric_ellipse(θ::T, a::T, b::T) where {T <: Real}
        s, c = sincos(θ)
        return a^2 * s^2 + b^2 * c^2
    end

    @inline function metric_derivative_ellipse(θ::T, a::T, b::T) where {T <: Real}
        return (a^2 - b^2) * sin(2 * θ)
    end
end
