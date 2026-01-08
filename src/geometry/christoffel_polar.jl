"""
    christoffel_polar.jl

Símbolos de Christoffel para elipse en coordenadas polares verdaderas φ.

Para una métrica 1D g_φφ(φ), el único símbolo de Christoffel no trivial es:

    Γ^φ_φφ = (1/2) g^φφ ∂_φ g_φφ
           = (∂_φ g_φφ) / (2 g_φφ)

Este símbolo se usa en:
1. Ecuación geodésica
2. Transporte paralelo de velocidades durante colisiones
"""

# include("metrics_polar.jl")  # Comentado: ya incluido en CollectiveDynamics.jl

# ============================================================================
# Símbolos de Christoffel
# ============================================================================

"""
    christoffel_polar_analytic(φ, a, b)

Calcula Γ^φ_φφ para elipse en coordenadas polares.

# Matemática
    Γ^φ_φφ = (∂_φ g_φφ) / (2 g_φφ)

donde:
    g_φφ = r² + (dr/dφ)²

    ∂_φ g_φφ = 2r(dr/dφ) + 2(dr/dφ)(d²r/dφ²)
             = 2(dr/dφ)[r + d²r/dφ²]

# Retorna
- Γ^φ_φφ(φ)
"""
function christoffel_polar_analytic(φ::T, a::T, b::T) where {T <: Real}
    g_φφ = metric_ellipse_polar(φ, a, b)
    dg_dφ = metric_derivative_polar(φ, a, b)

    return dg_dφ / (2 * g_φφ)
end

"""
    christoffel_polar_numerical(φ, a, b; h=nothing)

Calcula Γ^φ_φφ numéricamente usando diferencias finitas.

Útil para verificar la implementación analítica.

# Parámetros
- `h`: Paso para diferencias finitas (default: √ε)
"""
function christoffel_polar_numerical(
    φ::T, a::T, b::T;
    h::Union{Nothing,T}=nothing
) where {T <: Real}

    if isnothing(h)
        h = sqrt(eps(T)) * max(one(T), abs(φ))
    end

    g_φφ = metric_ellipse_polar(φ, a, b)
    g_inv = one(T) / g_φφ

    # ∂_φ g_φφ por diferencias finitas centradas
    g_plus = metric_ellipse_polar(φ + h, a, b)
    g_minus = metric_ellipse_polar(φ - h, a, b)
    dg_dφ = (g_plus - g_minus) / (2 * h)

    return 0.5 * g_inv * dg_dφ
end

# ============================================================================
# Alias para compatibilidad
# ============================================================================

"""
    christoffel_ellipse_polar(φ, a, b)

Alias para christoffel_polar_analytic. Mantiene consistencia con
nomenclatura del código anterior.
"""
const christoffel_ellipse_polar = christoffel_polar_analytic

# ============================================================================
# Verificación y tests
# ============================================================================

"""
    verify_christoffel_polar(φ, a, b; tol=1e-10)

Verifica que las implementaciones analítica y numérica coincidan.

# Retorna
- `(analytic, numerical, error)`: Tupla con valores y error absoluto
"""
function verify_christoffel_polar(
    φ::T, a::T, b::T;
    tol::T=T(1e-10)
) where {T <: Real}

    Γ_analytic = christoffel_polar_analytic(φ, a, b)
    Γ_numerical = christoffel_polar_numerical(φ, a, b)

    error = abs(Γ_analytic - Γ_numerical)

    return (
        analytic = Γ_analytic,
        numerical = Γ_numerical,
        error = error,
        passed = error < tol
    )
end
