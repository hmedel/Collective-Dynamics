"""
    forest_ruth.jl

Integrador simpléctico Forest-Ruth de 4to orden para sistemas Hamiltonianos.

El método Forest-Ruth es un integrador de composición que preserva la estructura
simpléctica del espacio de fases, garantizando conservación de energía a largo plazo.

Referencia: Forest & Ruth (1990), "Fourth-order symplectic integration"
DOI: 10.1016/0167-2789(90)90019-L
"""

using StaticArrays

# ============================================================================
# Coeficientes de Forest-Ruth
# ============================================================================

"""
Coeficientes del integrador Forest-Ruth de 4to orden.

Según el artículo:
```
γ₁ = γ₄ = 1 / (2(2 - 2^{1/3}))
γ₂ = γ₃ = (1 - 2^{1/3}) / (2(2 - 2^{1/3}))
```

Estos coeficientes satisfacen:
- γ₁ + γ₂ + γ₃ + γ₄ = 1 (completitud)
- Son simétricos: γ₁ = γ₄, γ₂ = γ₃
- Producen error O(Δt⁴)
"""
struct ForestRuthCoefficients{T <: AbstractFloat}
    γ₁::T
    γ₂::T
    γ₃::T
    γ₄::T

    function ForestRuthCoefficients{T}() where {T <: AbstractFloat}
        cbrt2 = T(2)^(one(T)/3)
        denominator = 2 * (2 - cbrt2)

        γ₁ = one(T) / denominator
        γ₂ = (one(T) - cbrt2) / denominator
        γ₃ = γ₂  # Simetría
        γ₄ = γ₁  # Simetría

        # Verificar que suman 1
        sum_γ = γ₁ + γ₂ + γ₃ + γ₄
        @assert abs(sum_γ - one(T)) < eps(T) * 10 "Coeficientes no suman 1: $sum_γ"

        new{T}(γ₁, γ₂, γ₃, γ₄)
    end
end

# Constructor por defecto
ForestRuthCoefficients() = ForestRuthCoefficients{Float64}()

"""
    get_coefficients(::Type{T}) where T

Retorna coeficientes Forest-Ruth como tupla para el tipo T.
"""
@inline function get_coefficients(::Type{T}) where {T <: AbstractFloat}
    cbrt2 = T(2)^(one(T)/3)
    denominator = 2 * (2 - cbrt2)

    γ₁ = one(T) / denominator
    γ₂ = (one(T) - cbrt2) / denominator

    return (γ₁, γ₂, γ₂, γ₁)  # (γ₁, γ₂, γ₃, γ₄)
end

# ============================================================================
# Integrador Forest-Ruth para Elipse
# ============================================================================

"""
    forest_ruth_step_ellipse(θ, θ_dot, dt, a, b)

Realiza un paso del integrador Forest-Ruth para una partícula en la elipse.

# Matemática
Para un Hamiltoniano H = T + V separable en cinético y potencial:

Paso de Forest-Ruth:
```
1. q₁ = q₀ + γ₁ dt p₀
2. p₁ = p₀ + γ₁ dt F(q₁)
3. q₂ = q₁ + γ₂ dt p₁
4. p₂ = p₁ + γ₂ dt F(q₂)
... (repetir para γ₃, γ₄)
```

Para movimiento geodésico en la elipse (V = 0):
```
F(θ) = -Γ^θ_θθ θ̇²  (aceleración geodésica)
```

# Parámetros
- `θ`: Posición angular actual
- `θ_dot`: Velocidad angular actual
- `dt`: Paso de tiempo
- `a`, `b`: Semi-ejes de la elipse

# Retorna
- `(θ_new, θ_dot_new)`: Estado actualizado después del paso

# Ejemplo
```julia
θ, θ_dot = 0.0, 1.0
θ_new, θ_dot_new = forest_ruth_step_ellipse(θ, θ_dot, 0.01, 2.0, 1.0)
```

# Nota
Este método preserva la estructura simpléctica, garantizando:
- Conservación de energía (error bounded por O(dt⁴))
- Reversibilidad temporal
- Conservación del volumen en espacio de fases
"""
function forest_ruth_step_ellipse(
    θ::T,
    θ_dot::T,
    dt::T,
    a::T,
    b::T
) where {T <: AbstractFloat}

    # Coeficientes
    γ₁, γ₂, γ₃, γ₄ = get_coefficients(T)

    # Estado inicial
    q = θ
    p = θ_dot

    # ===== Paso 1: γ₁ =====
    # Actualizar posición
    q = q + γ₁ * dt * p

    # Calcular fuerza (aceleración geodésica)
    Γ = christoffel_ellipse(q, a, b)
    F = -Γ * p^2

    # Actualizar momento
    p = p + γ₁ * dt * F

    # ===== Paso 2: γ₂ =====
    q = q + γ₂ * dt * p
    Γ = christoffel_ellipse(q, a, b)
    F = -Γ * p^2
    p = p + γ₂ * dt * F

    # ===== Paso 3: γ₃ =====
    q = q + γ₃ * dt * p
    Γ = christoffel_ellipse(q, a, b)
    F = -Γ * p^2
    p = p + γ₃ * dt * F

    # ===== Paso 4: γ₄ =====
    q = q + γ₄ * dt * p
    Γ = christoffel_ellipse(q, a, b)
    F = -Γ * p^2
    p = p + γ₄ * dt * F

    # Normalizar θ al rango [0, 2π]
    q = mod2pi(q)

    return (q, p)
end

"""
    forest_ruth_step_ellipse!(θ, θ_dot, dt, a, b)

Versión in-place del integrador Forest-Ruth.

Modifica θ y θ_dot directamente usando referencias.
"""
function forest_ruth_step_ellipse!(
    θ::Ref{T},
    θ_dot::Ref{T},
    dt::T,
    a::T,
    b::T
) where {T <: AbstractFloat}

    θ_new, θ_dot_new = forest_ruth_step_ellipse(θ[], θ_dot[], dt, a, b)
    θ[] = θ_new
    θ_dot[] = θ_dot_new

    return nothing
end

# ============================================================================
# Variante Simplificada (del código original)
# ============================================================================

"""
    forest_ruth_simplified(θ, θ_dot, dt)

Versión simplificada del Forest-Ruth para sistemas sin fuerzas (θ̈ = 0).

Esta es la versión usada en el código original Elipse40.jl.
Solo funciona para movimiento uniforme sin aceleración.

# Coeficientes simplificados
```
w₁ = 1 / (2 - 2^{1/3})
w₀ = -2^{1/3} / (2 - 2^{1/3})
```

# Nota
Esta versión NO incluye la aceleración geodésica y es menos precisa
que la versión completa para movimiento en espacios curvos.
"""
function forest_ruth_simplified(
    θ::T,
    θ_dot::T,
    dt::T
) where {T <: AbstractFloat}

    cbrt2 = T(2)^(one(T)/3)
    w₁ = one(T) / (2 - cbrt2)
    w₀ = -cbrt2 / (2 - cbrt2)

    # Paso 1
    θ₁ = θ + w₁ * dt * θ_dot

    # Paso 2
    θ₂ = θ₁ + w₀ * dt * θ_dot

    # Paso 3
    θ_new = θ₂ + w₁ * dt * θ_dot

    return (θ_new, θ_dot)
end

# ============================================================================
# Integración Multi-Paso
# ============================================================================

"""
    integrate_forest_ruth(θ₀, θ_dot₀, dt, n_steps, a, b)

Integra la trayectoria usando Forest-Ruth por n_steps pasos.

# Retorna
- Vector de posiciones θ(t)
- Vector de velocidades θ̇(t)

# Ejemplo
```julia
θ_traj, θ_dot_traj = integrate_forest_ruth(0.0, 1.0, 0.01, 1000, 2.0, 1.0)
```
"""
function integrate_forest_ruth(
    θ₀::T,
    θ_dot₀::T,
    dt::T,
    n_steps::Int,
    a::T,
    b::T
) where {T <: AbstractFloat}

    θ_traj = Vector{T}(undef, n_steps + 1)
    θ_dot_traj = Vector{T}(undef, n_steps + 1)

    θ_traj[1] = θ₀
    θ_dot_traj[1] = θ_dot₀

    θ = θ₀
    θ_dot = θ_dot₀

    for i in 1:n_steps
        θ, θ_dot = forest_ruth_step_ellipse(θ, θ_dot, dt, a, b)
        θ_traj[i+1] = θ
        θ_dot_traj[i+1] = θ_dot
    end

    return θ_traj, θ_dot_traj
end

# ============================================================================
# Verificación de Propiedades Simplécticas
# ============================================================================

"""
    verify_symplecticity(θ₀, θ_dot₀, dt, n_steps, a, b)

Verifica que el integrador preserve el volumen del espacio de fases.

Un integrador simpléctico debe satisfacer:
```
det(∂(θₙ, pₙ)/∂(θ₀, p₀)) = 1
```

# Retorna
- NamedTuple(jacobian_det, is_symplectic)

# Método
Calcula el Jacobiano numéricamente usando diferencias finitas.
"""
function verify_symplecticity(
    θ₀::T,
    θ_dot₀::T,
    dt::T,
    n_steps::Int,
    a::T,
    b::T;
    ε::T = T(1e-8)
) where {T <: AbstractFloat}

    # Función que integra desde (θ₀, θ_dot₀) → (θₙ, θ_dotₙ)
    function integrate_to_end(θ_init, θ_dot_init)
        θ, θ_dot = θ_init, θ_dot_init
        for _ in 1:n_steps
            θ, θ_dot = forest_ruth_step_ellipse(θ, θ_dot, dt, a, b)
        end
        return SVector{2,T}(θ, θ_dot)
    end

    # Estado de referencia
    state_ref = integrate_to_end(θ₀, θ_dot₀)

    # Perturbación en θ₀
    state_dθ = integrate_to_end(θ₀ + ε, θ_dot₀)
    ∂θₙ_∂θ₀ = (state_dθ[1] - state_ref[1]) / ε
    ∂pₙ_∂θ₀ = (state_dθ[2] - state_ref[2]) / ε

    # Perturbación en θ_dot₀
    state_dp = integrate_to_end(θ₀, θ_dot₀ + ε)
    ∂θₙ_∂p₀ = (state_dp[1] - state_ref[1]) / ε
    ∂pₙ_∂p₀ = (state_dp[2] - state_ref[2]) / ε

    # Jacobiano
    jac_det = ∂θₙ_∂θ₀ * ∂pₙ_∂p₀ - ∂θₙ_∂p₀ * ∂pₙ_∂θ₀

    is_symplectic = abs(jac_det - one(T)) < T(1e-6)

    return (jacobian_det = jac_det, is_symplectic = is_symplectic)
end

# ============================================================================
# Import de funciones necesarias
# ============================================================================

if !@isdefined(christoffel_ellipse)
    @inline function christoffel_ellipse(θ::T, a::T, b::T) where {T <: AbstractFloat}
        s, c = sincos(θ)
        numerator = (a^2 - b^2) * s * c
        denominator = a^2 * s^2 + b^2 * c^2
        return abs(denominator) < eps(T) ? zero(T) : numerator / denominator
    end
end
