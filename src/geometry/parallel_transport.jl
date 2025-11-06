"""
    parallel_transport.jl

Implementación del transporte paralelo de vectores tangentes en variedades curvas.

Este módulo implementa la ecuación fundamental del artículo (Ecuación clave):
    v'^i = v^i - Γ^i_{jk} v^j Δq^k

El transporte paralelo es esencial para mantener la consistencia geométrica
durante las colisiones en espacios curvos.
"""

using StaticArrays
using LinearAlgebra

# ============================================================================
# Transporte Paralelo en Elipse (1D)
# ============================================================================

"""
    parallel_transport_velocity(v_old, Δθ, θ, a, b)

Transporta paralelo una velocidad angular a lo largo de la elipse.

# Matemática (del Artículo - Ecuación fundamental)
```
v'^i = v^i - Γ^i_{jk} v^j Δq^k
```

Para coordenadas angulares (1D):
```
θ̇' = θ̇ - Γ^θ_θθ θ̇ Δθ
```

Esto asegura que el vector velocidad permanezca tangente a la variedad
después de moverse a lo largo de una geodésica.

# Parámetros
- `v_old`: Velocidad angular antes del transporte (θ̇)
- `Δθ`: Desplazamiento angular a lo largo de la geodésica
- `θ`: Posición angular actual (donde se evalúa Γ)
- `a`, `b`: Semi-ejes de la elipse

# Retorna
- `v_new`: Velocidad angular transportada θ̇'

# Nota Física
El transporte paralelo NO conserva la magnitud del vector en espacios curvos.
Sin embargo, en la elipse parametrizada angularmente, la corrección
es proporcional a la curvatura local.

# Ejemplo
```julia
θ = π/4
θ_dot_old = 1.0
Δθ = 0.01
θ_dot_new = parallel_transport_velocity(θ_dot_old, Δθ, θ, 2.0, 1.0)
```
"""
@inline function parallel_transport_velocity(
    v_old::T, Δθ::T, θ::T, a::T, b::T
) where {T <: Real}

    # Símbolo de Christoffel en el punto θ
    Γ = christoffel_ellipse(θ, a, b)

    # Ecuación de transporte paralelo
    # v' = v - Γ v Δθ
    v_new = v_old - Γ * v_old * Δθ

    return v_new
end

"""
    parallel_transport_velocity!(v, Δθ, θ, a, b)

Versión in-place del transporte paralelo (modifica v).

# Ejemplo
```julia
θ_dot = 1.0
parallel_transport_velocity!(Ref(θ_dot), 0.01, π/4, 2.0, 1.0)
# θ_dot ahora contiene el valor transportado
```
"""
@inline function parallel_transport_velocity!(
    v::Ref{T}, Δθ::T, θ::T, a::T, b::T
) where {T <: Real}

    Γ = christoffel_ellipse(θ, a, b)
    v[] = v[] - Γ * v[] * Δθ

    return nothing
end

# ============================================================================
# Transporte Paralelo con Múltiples Pasos
# ============================================================================

"""
    parallel_transport_path(v_initial, θ_path, a, b)

Transporta un vector a lo largo de un camino discretizado θ_path.

Útil para caminos geodésicos complejos o cuando Δθ es grande y necesita
subdivisión para mantener precisión.

# Parámetros
- `v_initial`: Velocidad angular inicial
- `θ_path`: Vector de posiciones angulares [θ₀, θ₁, ..., θₙ]
- `a`, `b`: Semi-ejes de la elipse

# Retorna
- Vector de velocidades transportadas en cada punto del camino

# Ejemplo
```julia
θ_path = range(0, π/2, length=100)
v_initial = 1.0
v_transported = parallel_transport_path(v_initial, θ_path, 2.0, 1.0)
```
"""
function parallel_transport_path(
    v_initial::T,
    θ_path::AbstractVector{T},
    a::T,
    b::T
) where {T <: Real}

    n = length(θ_path)
    v_transported = Vector{T}(undef, n)
    v_transported[1] = v_initial

    for i in 2:n
        θ = θ_path[i-1]
        Δθ = θ_path[i] - θ_path[i-1]

        v_transported[i] = parallel_transport_velocity(
            v_transported[i-1], Δθ, θ, a, b
        )
    end

    return v_transported
end

# ============================================================================
# Transporte Paralelo de Vectores Cartesianos
# ============================================================================

"""
    parallel_transport_cartesian_velocity(vel_cart_old, θ_old, θ_new, a, b)

Transporta un vector velocidad cartesiano a lo largo de la elipse.

Este método:
1. Proyecta la velocidad cartesiana al espacio tangente angular
2. Aplica transporte paralelo en coordenadas angulares
3. Convierte de vuelta a coordenadas cartesianas

# Parámetros
- `vel_cart_old`: Velocidad cartesiana (vx, vy) antes del transporte
- `θ_old`: Posición angular inicial
- `θ_new`: Posición angular final
- `a`, `b`: Semi-ejes

# Retorna
- `SVector{2}`: Velocidad cartesiana transportada

# Matemática
```
1. Extraer componente tangencial: θ̇ = (vel · tangent) / |tangent|²
2. Transportar θ̇ → θ̇'
3. Reconstruir: vel' = θ̇' * tangent(θ_new)
```

# Nota
Esta función es útil cuando trabajamos con colisiones en coordenadas
cartesianas pero queremos mantener la corrección geométrica.
"""
function parallel_transport_cartesian_velocity(
    vel_cart_old::SVector{2,T},
    θ_old::T,
    θ_new::T,
    a::T,
    b::T
) where {T <: Real}

    # 1. Vector tangente en θ_old
    s_old, c_old = sincos(θ_old)
    tangent_old = SVector{2,T}(-a * s_old, b * c_old)

    # Norma al cuadrado del tangente
    tangent_norm_sq = a^2 * s_old^2 + b^2 * c_old^2

    # 2. Proyección de velocidad cartesiana a velocidad angular
    # vel = θ̇ * tangent
    # θ̇ = (vel · tangent) / |tangent|²
    θ_dot_old = dot(vel_cart_old, tangent_old) / tangent_norm_sq

    # 3. Transporte paralelo de θ̇
    Δθ = θ_new - θ_old
    θ_dot_new = parallel_transport_velocity(θ_dot_old, Δθ, θ_old, a, b)

    # 4. Reconstruir velocidad cartesiana en θ_new
    s_new, c_new = sincos(θ_new)
    vel_cart_new = SVector{2,T}(-a * θ_dot_new * s_new, b * θ_dot_new * c_new)

    return vel_cart_new
end

# ============================================================================
# Verificación de Transporte Paralelo
# ============================================================================

"""
    verify_parallel_transport_norm(v_old, v_new, θ_old, θ_new, a, b)

Verifica cómo cambia la norma del vector durante el transporte paralelo.

En espacios curvos, la norma (medida con la métrica) puede cambiar.
Esta función calcula:
```
|v_old|²_{g(θ_old)} vs |v_new|²_{g(θ_new)}
```

# Retorna
- NamedTuple(norm_old, norm_new, ratio)

# Nota Teórica
El transporte paralelo preserva el producto interno en variedades planas,
pero en variedades curvas la norma puede cambiar porque la métrica cambia
con la posición.
"""
function verify_parallel_transport_norm(
    v_old::T, v_new::T, θ_old::T, θ_new::T, a::T, b::T
) where {T <: Real}

    # Métrica en puntos antiguo y nuevo
    g_old = metric_ellipse(θ_old, a, b)
    g_new = metric_ellipse(θ_new, a, b)

    # Normas con la métrica
    norm_old = sqrt(g_old) * abs(v_old)
    norm_new = sqrt(g_new) * abs(v_new)

    ratio = norm_new / norm_old

    return (norm_old = norm_old, norm_new = norm_new, ratio = ratio)
end

"""
    holonomy_angle(θ_path, a, b)

Calcula el ángulo de holonomía al transportar un vector a lo largo de un camino cerrado.

# Matemática
La holonomía mide cuánto rota un vector al ser transportado paralelamente
a lo largo de un loop cerrado. En espacios planos es cero; en espacios curvos
es proporcional a la curvatura encerrada.

# Parámetros
- `θ_path`: Camino cerrado (θ_path[end] ≈ θ_path[1])
- `a`, `b`: Semi-ejes

# Retorna
- Ángulo de holonomía (en unidades de la velocidad angular)

# Ejemplo
```julia
# Camino que da una vuelta completa a la elipse
θ_path = range(0, 2π, length=1000)
holonomy = holonomy_angle(θ_path, 2.0, 1.0)
```
"""
function holonomy_angle(
    θ_path::AbstractVector{T},
    a::T,
    b::T
) where {T <: Real}

    # Transportar un vector unitario alrededor del loop
    v_initial = one(T)
    v_final = parallel_transport_path(v_initial, θ_path, a, b)[end]

    # El ángulo de holonomía es el cambio logarítmico
    # (para vectores tangentes en 1D)
    holonomy = log(abs(v_final / v_initial))

    return holonomy
end

# ============================================================================
# Import de funciones necesarias
# ============================================================================

# Incluir localmente si no están definidas
if !@isdefined(christoffel_ellipse)
    @inline function christoffel_ellipse(θ::T1, a::T2, b::T3) where {T1<:Real, T2<:Real, T3<:Real}
        s, c = sincos(θ)
        numerator = (a^2 - b^2) * s * c
        denominator = a^2 * s^2 + b^2 * c^2
        return abs(denominator) < eps(typeof(denominator)) ? zero(denominator) : numerator / denominator
    end
end

if !@isdefined(metric_ellipse)
    @inline function metric_ellipse(θ::T1, a::T2, b::T3) where {T1<:Real, T2<:Real, T3<:Real}
        s, c = sincos(θ)
        return a^2 * s^2 + b^2 * c^2
    end
end
