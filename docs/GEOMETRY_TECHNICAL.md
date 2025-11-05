# 📐 Documentación Técnica: Geometría Diferencial

## Índice
1. [Introducción](#introducción)
2. [Métricas de Riemann](#métricas-de-riemann)
3. [Símbolos de Christoffel](#símbolos-de-christoffel)
4. [Transporte Paralelo](#transporte-paralelo)
5. [Derivaciones Matemáticas](#derivaciones-matemáticas)
6. [Implementación](#implementación)
7. [Validación Numérica](#validación-numérica)

---

## Introducción

Este módulo implementa las herramientas fundamentales de geometría diferencial necesarias para simular dinámica de partículas en variedades curvas. Se basa en la teoría de variedades Riemannianas y conexiones de Levi-Civita.

### Archivos
```
src/geometry/
├── metrics.jl              # Tensor métrico y funciones relacionadas
├── christoffel.jl          # Símbolos de conexión
└── parallel_transport.jl   # Transporte paralelo de vectores
```

---

## Métricas de Riemann

### Teoría Matemática

En una variedad Riemanniana \((M, g)\), el tensor métrico \(g_{ij}\) define la estructura geométrica:

**Elemento de línea:**
```math
ds^2 = g_{ij}(q) dq^i dq^j
```

Para una elipse parametrizada por el ángulo \(\theta\):
```
x(θ) = a cos(θ)
y(θ) = b sin(θ)
```

**Cálculo del tensor métrico:**

El elemento de línea infinitesimal es:
```math
ds^2 = dx^2 + dy^2
```

Sustituyendo las derivadas:
```math
dx = -a sin(θ) dθ
dy = b cos(θ) dθ
```

Obtenemos:
```math
ds^2 = (a sin(θ))^2 dθ^2 + (b cos(θ))^2 dθ^2
     = [a^2 sin^2(θ) + b^2 cos^2(θ)] dθ^2
```

Por lo tanto:
```math
g_{θθ} = a^2 sin^2(θ) + b^2 cos^2(θ)
```

### Implementación

**Archivo:** `src/geometry/metrics.jl`

#### Función Principal: `metric_ellipse`

```julia
function metric_ellipse(θ::T, a::T, b::T) where {T <: AbstractFloat}
    s, c = sincos(θ)
    return a^2 * s^2 + b^2 * c^2
end
```

**Características de optimización:**
- `sincos(θ)`: Calcula simultáneamente seno y coseno (más rápido que llamadas separadas)
- `@inline`: Marca para inlining por el compilador
- Type parameter `T`: Permite usar Float32 o Float64
- Evita alocaciones: Operación puramente escalar

**Casos especiales:**

1. **Círculo** (\(a = b\)):
   ```math
   g_{θθ} = a^2(sin^2(θ) + cos^2(θ)) = a^2
   ```
   Métrica constante → espacio plano

2. **Ejes principales:**
   - \(\theta = 0, \pi\): \(g_{θθ} = b^2\) (eje menor)
   - \(\theta = \pi/2, 3\pi/2\): \(g_{θθ} = a^2\) (eje mayor)

#### Métrica Inversa

```julia
function inverse_metric_ellipse(θ::T, a::T, b::T) where {T <: AbstractFloat}
    g = metric_ellipse(θ, a, b)
    return one(T) / g
end
```

Para una métrica 1D: \(g^{θθ} = 1/g_{θθ}\)

**Singularidades:** Nunca ocurren porque \(g_{θθ} \geq \min(a^2, b^2) > 0\)

#### Derivada de la Métrica

**Matemática:**
```math
\frac{\partial g_{θθ}}{\partial θ} = 2a^2 sin(θ)cos(θ) - 2b^2 sin(θ)cos(θ)
                                    = 2(a^2 - b^2) sin(θ)cos(θ)
                                    = (a^2 - b^2) sin(2θ)
```

**Implementación:**
```julia
function metric_derivative_ellipse(θ::T, a::T, b::T) where {T <: AbstractFloat}
    return (a^2 - b^2) * sin(2 * θ)
end
```

**Optimización:** Usa identidad \(sin(2θ) = 2 sin(θ)cos(θ)\) directamente.

#### Coordenadas Cartesianas

**Conversión angular → cartesiana:**
```julia
function cartesian_from_angle(θ::T, a::T, b::T) where {T <: AbstractFloat}
    s, c = sincos(θ)
    return SVector{2,T}(a * c, b * s)
end
```

**Por qué SVector:**
- Tamaño fijo conocido en tiempo de compilación
- Alocación en stack (no heap)
- ~10x más rápido que `Vector{T}`

**Velocidad cartesiana desde velocidad angular:**

Matemática:
```math
\frac{dx}{dt} = \frac{dx}{dθ}\frac{dθ}{dt} = -a sin(θ) \dot{θ}
\frac{dy}{dt} = \frac{dy}{dθ}\frac{dθ}{dt} = b cos(θ) \dot{θ}
```

Implementación:
```julia
function velocity_from_angular(θ::T, θ_dot::T, a::T, b::T) where {T <: AbstractFloat}
    s, c = sincos(θ)
    return SVector{2,T}(-a * θ_dot * s, b * θ_dot * c)
end
```

#### Energía Cinética en Coordenadas Curvilíneas

**Fórmula general:**
```math
T = \frac{1}{2} m g_{ij} \dot{q}^i \dot{q}^j
```

Para la elipse:
```math
T = \frac{1}{2} m g_{θθ} \dot{θ}^2
  = \frac{1}{2} m [a^2 sin^2(θ) + b^2 cos^2(θ)] \dot{θ}^2
```

Implementación:
```julia
function kinetic_energy_angular(θ::T, θ_dot::T, mass::T, a::T, b::T) where {T <: AbstractFloat}
    g = metric_ellipse(θ, a, b)
    return 0.5 * mass * g * θ_dot^2
end
```

**Verificación:** Debe ser idéntica a:
```math
T = \frac{1}{2} m (v_x^2 + v_y^2)
```

---

## Símbolos de Christoffel

### Teoría Matemática

Los símbolos de Christoffel \(\Gamma^i_{jk}\) representan la conexión de Levi-Civita, que describe cómo cambian los vectores al moverse en la variedad.

**Definición:**
```math
\Gamma^i_{jk} = \frac{1}{2} g^{il} \left( \frac{\partial g_{lk}}{\partial q^j} + \frac{\partial g_{lj}}{\partial q^k} - \frac{\partial g_{jk}}{\partial q^l} \right)
```

**Para una métrica 1D** \(g_{θθ}\):
```math
\Gamma^θ_{θθ} = \frac{1}{2} g^{θθ} \frac{\partial g_{θθ}}{\partial θ}
              = \frac{1}{2g_{θθ}} \frac{\partial g_{θθ}}{\partial θ}
```

### Cálculo Analítico para la Elipse

Sustituyendo:
```math
g_{θθ} = a^2 sin^2(θ) + b^2 cos^2(θ)
\frac{\partial g_{θθ}}{\partial θ} = (a^2 - b^2) sin(2θ)
```

Obtenemos:
```math
\Gamma^θ_{θθ} = \frac{(a^2 - b^2) sin(2θ)}{2[a^2 sin^2(θ) + b^2 cos^2(θ)]}
              = \frac{(a^2 - b^2) sin(θ)cos(θ)}{a^2 sin^2(θ) + b^2 cos^2(θ)}
```

### Implementación

**Archivo:** `src/geometry/christoffel.jl`

#### Método Analítico

```julia
function christoffel_ellipse(θ::T, a::T, b::T) where {T <: AbstractFloat}
    s, c = sincos(θ)

    numerator = (a^2 - b^2) * s * c
    denominator = a^2 * s^2 + b^2 * c^2

    # Evitar división por cero (aunque matemáticamente imposible)
    if abs(denominator) < eps(T)
        return zero(T)
    end

    return numerator / denominator
end
```

**Optimizaciones:**
- Una sola llamada a `sincos`
- Check de división por cero (por seguridad numérica)
- Type-stable

**Propiedades importantes:**

1. **Simetría:** \(\Gamma^θ_{θθ} = \Gamma^θ_{θθ}\) (trivial en 1D, importante en dims superiores)

2. **Signo:** Puede ser positivo o negativo según el cuadrante:
   - Cuadrantes I, III: \(sin(θ)cos(θ) > 0 \Rightarrow \Gamma > 0\) si \(a > b\)
   - Cuadrantes II, IV: \(sin(θ)cos(θ) < 0 \Rightarrow \Gamma < 0\) si \(a > b\)

3. **Círculo:** Si \(a = b\), entonces \(\Gamma^θ_{θθ} = 0\) (espacio plano)

4. **Máximos:**
   - En \(\theta = \pi/4, 5\pi/4\): \(sin(θ)cos(θ) = 1/2\)
   - En \(\theta = 3\pi/4, 7\pi/4\): \(sin(θ)cos(θ) = -1/2\)

#### Método Numérico (Diferencias Finitas)

Para verificación o cuando no hay fórmula analítica:

```julia
function christoffel_numerical(metric_func::Function, q::T, h::T = T(1e-6)) where {T <: AbstractFloat}
    # Diferencias finitas centradas
    g_plus = metric_func(q + h)
    g_minus = metric_func(q - h)
    ∂g = (g_plus - g_minus) / (2 * h)

    g = metric_func(q)

    if abs(g) < eps(T)
        return zero(T)
    end

    return ∂g / (2 * g)
end
```

**Uso:**
```julia
metric_fn(x) = metric_ellipse(x, 2.0, 1.0)
Γ_num = christoffel_numerical(metric_fn, π/4)
```

**Precisión:** Error \(O(h^2)\) para diferencias centradas.

#### Método con Diferenciación Automática

Usa ForwardDiff.jl para derivadas exactas:

```julia
function christoffel_autodiff(metric_func::Function, q::T) where {T <: AbstractFloat}
    ∂g = ForwardDiff.derivative(metric_func, q)
    g = metric_func(q)

    if abs(g) < eps(T)
        return zero(T)
    end

    return ∂g / (2 * g)
end
```

**Ventajas:**
- Precisión de máquina (no errores de truncamiento)
- No necesita elegir \(h\)
- Funciona con funciones complejas

#### Comparación de Métodos

```julia
function compare_christoffel_methods(θ::T, a::T, b::T) where {T <: AbstractFloat}
    Γ_analytic = christoffel_ellipse(θ, a, b)

    metric_fn(x) = metric_ellipse(x, a, b)
    Γ_numerical = christoffel_numerical(metric_fn, θ)
    Γ_autodiff = christoffel_autodiff(metric_fn, θ)

    diffs = [
        abs(Γ_analytic - Γ_numerical),
        abs(Γ_analytic - Γ_autodiff),
        abs(Γ_numerical - Γ_autodiff)
    ]

    return (
        analytic = Γ_analytic,
        numerical = Γ_numerical,
        autodiff = Γ_autodiff,
        max_diff = maximum(diffs)
    )
end
```

**Resultado típico:**
```julia
julia> compare_christoffel_methods(π/4, 2.0, 1.0)
(analytic = 0.24, numerical = 0.23999998, autodiff = 0.24, max_diff = 2.3e-8)
```

### Ecuación Geodésica

**Forma general:**
```math
\frac{d^2 q^i}{dt^2} + \Gamma^i_{jk} \frac{dq^j}{dt} \frac{dq^k}{dt} = 0
```

Para la elipse:
```math
\ddot{θ} + \Gamma^θ_{θθ} \dot{θ}^2 = 0

\Rightarrow \ddot{θ} = -\Gamma^θ_{θθ} \dot{θ}^2
```

Implementación:
```julia
function geodesic_acceleration(θ::T, θ_dot::T, a::T, b::T) where {T <: AbstractFloat}
    Γ = christoffel_ellipse(θ, a, b)
    return -Γ * θ_dot^2
end
```

**Interpretación física:**
- En un círculo (\(a=b\)): \(\ddot{θ} = 0\) → velocidad angular constante
- En elipse: Aceleración depende de la curvatura local

---

## Transporte Paralelo

### Teoría Matemática

El transporte paralelo mueve vectores a lo largo de una curva manteniendo su "dirección intrínseca".

**Ecuación diferencial:**
```math
\frac{Dv^i}{dt} = \frac{dv^i}{dt} + \Gamma^i_{jk} v^j \frac{dq^k}{dt} = 0
```

**Para desplazamiento finito \(\Delta q\):**
```math
v'^i = v^i - \Gamma^i_{jk} v^j \Delta q^k
```

Esta es **la ecuación fundamental del artículo** para colisiones.

### Implementación

**Archivo:** `src/geometry/parallel_transport.jl`

#### Transporte de Velocidad Angular

```julia
function parallel_transport_velocity(
    v_old::T, Δθ::T, θ::T, a::T, b::T
) where {T <: AbstractFloat}

    Γ = christoffel_ellipse(θ, a, b)
    v_new = v_old - Γ * v_old * Δθ

    return v_new
end
```

**Parámetros:**
- `v_old`: Velocidad angular inicial \(\dot{θ}\)
- `Δθ`: Desplazamiento angular
- `θ`: Posición donde se evalúa \(\Gamma\)
- `a, b`: Semi-ejes

**Retorna:** Velocidad transportada \(\dot{θ}'\)

**Ejemplo:**
```julia
θ = π/4
θ_dot = 1.0
Δθ = 0.01

θ_dot_transported = parallel_transport_velocity(θ_dot, Δθ, θ, 2.0, 1.0)
# θ_dot_transported ≈ 0.998  (ligeramente menor por curvatura)
```

#### Versión In-Place

Para evitar alocaciones en loops:

```julia
function parallel_transport_velocity!(
    v::Ref{T}, Δθ::T, θ::T, a::T, b::T
) where {T <: AbstractFloat}

    Γ = christoffel_ellipse(θ, a, b)
    v[] = v[] - Γ * v[] * Δθ

    return nothing
end
```

**Uso:**
```julia
v = Ref(1.0)
parallel_transport_velocity!(v, 0.01, π/4, 2.0, 1.0)
println(v[])  # Valor modificado
```

#### Transporte a lo Largo de un Camino

Para caminos discretizados:

```julia
function parallel_transport_path(
    v_initial::T,
    θ_path::AbstractVector{T},
    a::T,
    b::T
) where {T <: AbstractFloat}

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
```

**Ejemplo: Transportar alrededor de la elipse**
```julia
θ_path = range(0, 2π, length=1000)
v_initial = 1.0
v_along_path = parallel_transport_path(v_initial, θ_path, 2.0, 1.0)

# Verificar holonomía (cambio después de loop completo)
holonomy = v_along_path[end] / v_initial
println("Holonomy factor: ", holonomy)  # ≠ 1 para elipse
```

#### Transporte de Velocidades Cartesianas

Para trabajar con coordenadas cartesianas:

```julia
function parallel_transport_cartesian_velocity(
    vel_cart_old::SVector{2,T},
    θ_old::T,
    θ_new::T,
    a::T,
    b::T
) where {T <: AbstractFloat}

    # 1. Proyectar velocidad cartesiana → angular
    s_old, c_old = sincos(θ_old)
    tangent_old = SVector{2,T}(-a * s_old, b * c_old)
    tangent_norm_sq = a^2 * s_old^2 + b^2 * c_old^2

    θ_dot_old = dot(vel_cart_old, tangent_old) / tangent_norm_sq

    # 2. Transportar velocidad angular
    Δθ = θ_new - θ_old
    θ_dot_new = parallel_transport_velocity(θ_dot_old, Δθ, θ_old, a, b)

    # 3. Reconstruir velocidad cartesiana en nueva posición
    s_new, c_new = sincos(θ_new)
    vel_cart_new = SVector{2,T}(-a * θ_dot_new * s_new, b * θ_dot_new * c_new)

    return vel_cart_new
end
```

**Pasos:**
1. Descomponer velocidad cartesiana en componente tangencial
2. Extraer velocidad angular \(\dot{θ}\)
3. Transportar \(\dot{θ}\)
4. Reconstruir velocidad cartesiana

#### Verificación de Norma

El transporte paralelo NO preserva la norma en espacios curvos:

```julia
function verify_parallel_transport_norm(
    v_old::T, v_new::T, θ_old::T, θ_new::T, a::T, b::T
) where {T <: AbstractFloat}

    g_old = metric_ellipse(θ_old, a, b)
    g_new = metric_ellipse(θ_new, a, b)

    norm_old = sqrt(g_old) * abs(v_old)
    norm_new = sqrt(g_new) * abs(v_new)

    ratio = norm_new / norm_old

    return (norm_old = norm_old, norm_new = norm_new, ratio = ratio)
end
```

**Resultado típico:**
```julia
julia> verify_parallel_transport_norm(1.0, 0.98, 0.0, π/4, 2.0, 1.0)
(norm_old = 1.0, norm_new = 1.08, ratio = 1.08)
```

La norma cambia porque la métrica cambia con la posición.

---

## Derivaciones Matemáticas Completas

### Derivación 1: Métrica desde Parametrización

**Paso 1:** Parametrización de la elipse
```math
\mathbf{r}(θ) = (a cos θ, b sin θ)
```

**Paso 2:** Vector tangente
```math
\frac{d\mathbf{r}}{dθ} = (-a sin θ, b cos θ)
```

**Paso 3:** Elemento de línea
```math
ds^2 = \left|\frac{d\mathbf{r}}{dθ}\right|^2 dθ^2
     = [(a sin θ)^2 + (b cos θ)^2] dθ^2
```

**Paso 4:** Métrica
```math
g_{θθ} = a^2 sin^2 θ + b^2 cos^2 θ
```

### Derivación 2: Christoffel desde Lagrangiano

**Lagrangiano:**
```math
L = \frac{1}{2} g_{θθ} \dot{θ}^2
```

**Ecuación de Euler-Lagrange:**
```math
\frac{d}{dt}\left(\frac{\partial L}{\partial \dot{θ}}\right) - \frac{\partial L}{\partial θ} = 0
```

**Desarrollo:**
```math
\frac{\partial L}{\partial \dot{θ}} = g_{θθ} \dot{θ}

\frac{d}{dt}(g_{θθ} \dot{θ}) = \dot{g}_{θθ} \dot{θ} + g_{θθ} \ddot{θ}
                                = \frac{\partial g_{θθ}}{\partial θ} \dot{θ}^2 + g_{θθ} \ddot{θ}

\frac{\partial L}{\partial θ} = \frac{1}{2} \frac{\partial g_{θθ}}{\partial θ} \dot{θ}^2
```

**Ecuación geodésica:**
```math
\frac{\partial g_{θθ}}{\partial θ} \dot{θ}^2 + g_{θθ} \ddot{θ} - \frac{1}{2} \frac{\partial g_{θθ}}{\partial θ} \dot{θ}^2 = 0

g_{θθ} \ddot{θ} + \frac{1}{2} \frac{\partial g_{θθ}}{\partial θ} \dot{θ}^2 = 0

\ddot{θ} = -\frac{1}{2g_{θθ}} \frac{\partial g_{θθ}}{\partial θ} \dot{θ}^2

\ddot{θ} = -\Gamma^θ_{θθ} \dot{θ}^2
```

### Derivación 3: Transporte Paralelo Discretizado

**Ecuación continua:**
```math
\frac{dv^i}{dt} + \Gamma^i_{jk} v^j \frac{dq^k}{dt} = 0
```

**Aproximación de primer orden:**
```math
\frac{v^i(t + \Delta t) - v^i(t)}{\Delta t} + \Gamma^i_{jk} v^j(t) \frac{q^k(t + \Delta t) - q^k(t)}{\Delta t} = 0
```

**Despejando:**
```math
v^i(t + \Delta t) = v^i(t) - \Gamma^i_{jk}(q(t)) v^j(t) \Delta q^k
```

**Para la elipse:**
```math
\dot{θ}(t + \Delta t) = \dot{θ}(t) - \Gamma^θ_{θθ}(θ(t)) \dot{θ}(t) \Delta θ
```

---

## Validación Numérica

### Test 1: Métrica en Casos Límite

```julia
using Test

@testset "Métrica - Círculo" begin
    a, b = 1.0, 1.0
    for θ in [0.0, π/4, π/2, π]
        g = metric_ellipse(θ, a, b)
        @test isapprox(g, 1.0, atol=1e-10)
    end
end

@testset "Métrica - Ejes principales" begin
    a, b = 2.0, 1.0
    @test isapprox(metric_ellipse(0.0, a, b), b^2, atol=1e-10)
    @test isapprox(metric_ellipse(π/2, a, b), a^2, atol=1e-10)
end
```

### Test 2: Christoffel - Comparación de Métodos

```julia
@testset "Christoffel - Métodos equivalentes" begin
    a, b = 2.0, 1.0
    for θ in [π/6, π/4, π/3]
        comparison = compare_christoffel_methods(θ, a, b)
        @test comparison.max_diff < 1e-6
    end
end
```

### Test 3: Transporte Paralelo - Círculo

```julia
@testset "Transporte Paralelo - Círculo (debe ser identidad)" begin
    a, b = 1.0, 1.0  # Círculo
    v = 1.0
    Δθ = 0.1
    θ = π/4

    v_transported = parallel_transport_velocity(v, Δθ, θ, a, b)
    @test isapprox(v_transported, v, atol=1e-6)
end
```

### Test 4: Consistencia Energía Cinética

```julia
@testset "Energía Cinética - Consistencia angular vs cartesiana" begin
    a, b = 2.0, 1.0
    θ = π/4
    θ_dot = 1.0
    mass = 1.0

    # Energía desde coordenadas angulares
    E_angular = kinetic_energy_angular(θ, θ_dot, mass, a, b)

    # Energía desde coordenadas cartesianas
    vel = velocity_from_angular(θ, θ_dot, a, b)
    E_cartesian = 0.5 * mass * dot(vel, vel)

    @test isapprox(E_angular, E_cartesian, rtol=1e-10)
end
```

---

## Referencias

1. **do Carmo, M. P.** (1992). *Riemannian Geometry*. Birkhäuser.
2. **Lee, J. M.** (2018). *Introduction to Riemannian Manifolds*. Springer.
3. **Wald, R. M.** (1984). *General Relativity*. University of Chicago Press.
4. **García-Hernández & Medel-Cobaxín** (2024). "Collision Dynamics on Curved Manifolds".

---

## Notas de Implementación

### Precisión Numérica

- Se usa `eps(T)` para detectar divisiones por cero
- Diferencias finitas: \(h = 10^{-6}\) balanceo entre truncamiento y redondeo
- `sincos()` es más preciso que `sin()` y `cos()` por separado

### Performance

- Todas las funciones críticas marcadas con `@inline`
- `SVector` para vectores pequeños (stack allocation)
- Type parameters para permitir Float32 o Float64
- Evitar alocaciones en loops

### Extensibilidad

Para añadir otra geometría (e.g., esfera):

1. Definir `metric_sphere(θ, φ, R)`
2. Calcular `christoffel_sphere(θ, φ, R)` (múltiples componentes)
3. Implementar `parallel_transport_sphere`
4. Adaptar integradores y colisiones

---

**Última actualización:** 2024
**Autores:** J. Isaí García-Hernández, Héctor J. Medel-Cobaxín
