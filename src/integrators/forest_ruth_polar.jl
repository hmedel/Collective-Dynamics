"""
    forest_ruth_polar.jl

Integrador symplectic Forest-Ruth de 4to orden para coordenadas polares φ.

Ecuación de movimiento (geodésica):
    d²φ/dt² + Γ^φ_φφ (dφ/dt)² = 0

donde:
    Γ^φ_φφ = (∂_φ g_φφ) / (2 g_φφ)

El integrador Forest-Ruth preserva la estructura simpléctica del espacio fase.
"""

# include("../geometry/metrics_polar.jl")  # Comentado: ya incluido en CollectiveDynamics.jl
include("../geometry/christoffel_polar.jl")
include("../particles_polar.jl")

# ============================================================================
# Coeficientes de Forest-Ruth
# ============================================================================

const θ_FR = 1 / (2 - 2^(1/3))
const γ_FR_1 = θ_FR / 2
const γ_FR_2 = (1 - 2^(1/3)) * θ_FR / 2
const γ_FR_3 = γ_FR_2
const γ_FR_4 = γ_FR_1

const ρ_FR_1 = θ_FR
const ρ_FR_2 = -2^(1/3) * θ_FR
const ρ_FR_3 = θ_FR

# ============================================================================
# Paso de integración
# ============================================================================

"""
    forest_ruth_step_polar(φ, φ_dot, dt, a, b)

Realiza un paso del integrador Forest-Ruth en coordenadas polares.

# Parámetros
- `φ`: Ángulo polar actual
- `φ_dot`: Velocidad angular actual
- `dt`: Paso de tiempo
- `a, b`: Semi-ejes de la elipse

# Retorna
- `(φ_new, φ_dot_new)`: Estado actualizado

# Matemática
El integrador aplica 4 actualizaciones de posición y 3 de velocidad:

    φ₁ = φ₀ + γ₁·dt·φ̇₀
    φ̇₁ = φ̇₀ - ρ₁·dt·Γ^φ_φφ(φ₁)·φ̇₀²

    φ₂ = φ₁ + γ₂·dt·φ̇₁
    φ̇₂ = φ̇₁ - ρ₂·dt·Γ^φ_φφ(φ₂)·φ̇₁²

    φ₃ = φ₂ + γ₃·dt·φ̇₂
    φ̇₃ = φ̇₂ - ρ₃·dt·Γ^φ_φφ(φ₃)·φ̇₂²

    φ₄ = φ₃ + γ₄·dt·φ̇₃

Los coeficientes están diseñados para error O(dt⁵).
"""
function forest_ruth_step_polar(
    φ::T,
    φ_dot::T,
    dt::T,
    a::T,
    b::T
) where {T <: AbstractFloat}

    # Paso 1: Actualizar posición
    φ_1 = φ + γ_FR_1 * dt * φ_dot

    # Calcular Christoffel en φ₁
    Γ_1 = christoffel_ellipse_polar(φ_1, a, b)

    # Actualizar velocidad
    φ_dot_1 = φ_dot - ρ_FR_1 * dt * Γ_1 * φ_dot^2

    # Paso 2: Actualizar posición
    φ_2 = φ_1 + γ_FR_2 * dt * φ_dot_1

    # Calcular Christoffel en φ₂
    Γ_2 = christoffel_ellipse_polar(φ_2, a, b)

    # Actualizar velocidad
    φ_dot_2 = φ_dot_1 - ρ_FR_2 * dt * Γ_2 * φ_dot_1^2

    # Paso 3: Actualizar posición
    φ_3 = φ_2 + γ_FR_3 * dt * φ_dot_2

    # Calcular Christoffel en φ₃
    Γ_3 = christoffel_ellipse_polar(φ_3, a, b)

    # Actualizar velocidad
    φ_dot_3 = φ_dot_2 - ρ_FR_3 * dt * Γ_3 * φ_dot_2^2

    # Paso 4: Actualizar posición final
    φ_4 = φ_3 + γ_FR_4 * dt * φ_dot_3

    # Normalizar φ a [0, 2π)
    φ_final = mod(φ_4, 2π)

    return (φ_final, φ_dot_3)
end

"""
    integrate_particle_polar!(p, dt, a, b)

Integra una partícula un paso de tiempo dt usando Forest-Ruth.

# Parámetros
- `p::ParticlePolar`: Partícula a integrar
- `dt`: Paso de tiempo
- `a, b`: Semi-ejes de la elipse

# Retorna
- Nueva ParticlePolar con estado actualizado
"""
function integrate_particle_polar(
    p::ParticlePolar{T},
    dt::T,
    a::T,
    b::T
) where {T <: AbstractFloat}

    # Realizar paso de integración
    φ_new, φ_dot_new = forest_ruth_step_polar(p.φ, p.φ_dot, dt, a, b)

    # Crear nueva partícula con estado actualizado
    return update_particle_polar(p, φ_new, φ_dot_new, a, b)
end

"""
    integrate_system_polar(particles, dt, a, b)

Integra todo el sistema de partículas un paso de tiempo.

# Parámetros
- `particles`: Vector de ParticlePolar
- `dt`: Paso de tiempo
- `a, b`: Semi-ejes de la elipse

# Retorna
- Nuevo vector de ParticlePolar con todos los estados actualizados
"""
function integrate_system_polar(
    particles::Vector{ParticlePolar{T}},
    dt::T,
    a::T,
    b::T
) where {T <: AbstractFloat}

    return [integrate_particle_polar(p, dt, a, b) for p in particles]
end

# ============================================================================
# Verificación de propiedades del integrador
# ============================================================================

"""
    verify_forest_ruth_coefficients()

Verifica las propiedades de los coeficientes de Forest-Ruth.

Condiciones necesarias:
1. Σ γᵢ = 1  (posiciones suman un paso completo)
2. Σ ρᵢ = 1  (velocidades suman un paso completo)
3. Simetría: γ₁=γ₄, γ₂=γ₃

# Retorna
- NamedTuple con verificaciones
"""
function verify_forest_ruth_coefficients()
    sum_γ = γ_FR_1 + γ_FR_2 + γ_FR_3 + γ_FR_4
    sum_ρ = ρ_FR_1 + ρ_FR_2 + ρ_FR_3

    symmetry_γ = (γ_FR_1 ≈ γ_FR_4) && (γ_FR_2 ≈ γ_FR_3)

    return (
        sum_γ = sum_γ,
        sum_ρ = sum_ρ,
        γ_sums_to_one = isapprox(sum_γ, 1.0, atol=1e-15),
        ρ_sums_to_one = isapprox(sum_ρ, 1.0, atol=1e-15),
        symmetry_holds = symmetry_γ,
        all_checks_pass = isapprox(sum_γ, 1.0, atol=1e-15) &&
                          isapprox(sum_ρ, 1.0, atol=1e-15) &&
                          symmetry_γ
    )
end
