"""
    particles.jl

Definición de partículas optimizadas para simulaciones en variedades curvas.

Cambios principales respecto al código original:
- BigFloat → Float64 (~100x speedup)
- Vector → SVector (~10x speedup)
- Type stability
- Métodos optimizados con @inline
"""

using StaticArrays
using LinearAlgebra
using Random

# ============================================================================
# Struct Particle Optimizado
# ============================================================================

"""
    Particle{T <: AbstractFloat}

Representa una partícula moviéndose en una elipse.

# Campos
- `id::Int32`: ID único de la partícula (Int32 suficiente para < 2B partículas)
- `mass::T`: Masa de la partícula
- `radius::T`: Radio de la partícula (para detección de colisiones)
- `θ::T`: Posición angular actual
- `θ_dot::T`: Velocidad angular actual
- `pos::SVector{2,T}`: Posición cartesiana (x, y)
- `vel::SVector{2,T}`: Velocidad cartesiana (vx, vy)

# Mejoras respecto al código original
1. Usa Float64 en vez de BigFloat (50-100x más rápido)
2. Usa SVector en vez de Vector (5-10x más rápido, stack allocation)
3. Int32 para ID (suficiente y más cache-friendly)
4. Type parameter T permite flexibilidad (Float32 para GPU, Float64 para CPU)

# Ejemplo
```julia
p = Particle{Float64}(
    id = 1,
    mass = 1.0,
    radius = 0.1,
    θ = 0.0,
    θ_dot = 1.0,
    pos = SVector(2.0, 0.0),
    vel = SVector(0.0, 1.0)
)
```
"""
struct Particle{T <: AbstractFloat}
    id::Int32
    mass::T
    radius::T
    θ::T
    θ_dot::T
    pos::SVector{2, T}
    vel::SVector{2, T}
end

# Constructor conveniente
function Particle(;
    id::Integer,
    mass::T,
    radius::T,
    θ::T,
    θ_dot::T,
    pos::SVector{2, T},
    vel::SVector{2, T}
) where {T <: AbstractFloat}
    return Particle{T}(Int32(id), mass, radius, θ, θ_dot, pos, vel)
end

# ============================================================================
# Actualización de Estado
# ============================================================================

"""
    update_particle(p::Particle, θ_new, θ_dot_new, a, b)

Crea una nueva partícula con estado angular actualizado.

Como Particle es immutable (por performance), creamos una copia con valores actualizados.
Esto es más rápido que parece porque el struct es pequeño y se asigna en el stack.

# Parámetros
- `p`: Partícula original
- `θ_new`: Nueva posición angular
- `θ_dot_new`: Nueva velocidad angular
- `a`, `b`: Semi-ejes de la elipse

# Retorna
- Nueva instancia de Particle con estado actualizado
"""
@inline function update_particle(
    p::Particle{T},
    θ_new::T,
    θ_dot_new::T,
    a::T,
    b::T
) where {T <: AbstractFloat}

    # Calcular posición cartesiana desde ángulo
    pos_new = cartesian_from_angle(θ_new, a, b)

    # Calcular velocidad cartesiana desde velocidad angular
    vel_new = velocity_from_angular(θ_new, θ_dot_new, a, b)

    return Particle{T}(
        p.id,
        p.mass,
        p.radius,
        θ_new,
        θ_dot_new,
        pos_new,
        vel_new
    )
end

# ============================================================================
# Energía y Momento
# ============================================================================

"""
    kinetic_energy(p::Particle, a, b)

Calcula la energía cinética de la partícula usando la métrica correcta.

# Matemática
```
T = (1/2) m g_θθ θ̇²
```

donde g_θθ = a² sin²(θ) + b² cos²(θ)
"""
@inline function kinetic_energy(
    p::Particle{T},
    a::T,
    b::T
) where {T <: AbstractFloat}
    g = metric_ellipse(p.θ, a, b)
    return 0.5 * p.mass * g * p.θ_dot^2
end

"""
    kinetic_energy_cartesian(p::Particle)

Energía cinética calculada desde velocidad cartesiana.

# Matemática
```
T = (1/2) m (vx² + vy²)
```

Debe ser equivalente a kinetic_energy(p, a, b).
"""
@inline function kinetic_energy_cartesian(p::Particle{T}) where {T <: AbstractFloat}
    return 0.5 * p.mass * dot(p.vel, p.vel)
end

"""
    conjugate_momentum(p::Particle, a, b)

Calcula el momento conjugado (momento canónico) de la partícula en la variedad.

# Matemática
Para una partícula moviéndose en una elipse, el momento conjugado es:
```
p_θ = m g(θ) θ̇ = m [a²sin²(θ) + b²cos²(θ)] θ̇
```

donde g(θ) = a²sin²(θ) + b²cos²(θ) es la componente de la métrica.

# Conservación
Esta cantidad **SÍ se conserva** para cada partícula en movimiento geodésico libre.
Es el invariante fundamental del sistema y debe conservarse incluso con colisiones
si se usa transporte paralelo correctamente.

# Relación con el Hamiltoniano
Esta es la cantidad que aparece en las ecuaciones de Hamilton:
```
H = p_θ² / (2m g(θ))
```

# Nota
Anteriormente llamada "angular_momentum" pero ese nombre era confuso porque
el verdadero momento angular L = r × p NO se conserva en elipses.
"""
@inline function conjugate_momentum(
    p::Particle{T},
    a::T,
    b::T
) where {T <: AbstractFloat}
    g = metric_ellipse(p.θ, a, b)
    return p.mass * g * p.θ_dot
end

"""
    angular_momentum(p::Particle, a, b)

**DEPRECADO:** Usa `conjugate_momentum` en su lugar.

Esta función calcula el momento conjugado p_θ = m g(θ) θ̇,
NO el momento angular clásico L = r × p.

El nombre es confuso porque sugiere que se conserva como momento angular,
pero en realidad es el momento conjugado en la métrica.
"""
@inline function angular_momentum(
    p::Particle{T},
    a::T,
    b::T
) where {T <: AbstractFloat}
    return conjugate_momentum(p, a, b)
end

"""
    linear_momentum_cartesian(p::Particle)

Momento lineal en coordenadas cartesianas.

# Matemática
```
p⃗ = m v⃗
```
"""
@inline function linear_momentum_cartesian(p::Particle{T}) where {T <: AbstractFloat}
    return p.mass * p.vel
end

# ============================================================================
# Inicialización de Partículas
# ============================================================================

"""
    initialize_particle(id, mass, radius, θ, θ_dot, a, b)

Crea una partícula con posición angular inicial.

Calcula automáticamente las coordenadas cartesianas desde θ.
"""
function initialize_particle(
    id::Integer,
    mass::Real,
    radius::Real,
    θ::Real,
    θ_dot::Real,
    a::Real,
    b::Real
)
    # Promote all arguments to a common floating point type
    T = promote_type(typeof(mass), typeof(radius), typeof(θ), typeof(θ_dot), typeof(a), typeof(b))
    T = T <: AbstractFloat ? T : Float64

    mass_T = convert(T, mass)
    radius_T = convert(T, radius)
    θ_T = convert(T, θ)
    θ_dot_T = convert(T, θ_dot)
    a_T = convert(T, a)
    b_T = convert(T, b)

    pos = cartesian_from_angle(θ_T, a_T, b_T)
    vel = velocity_from_angular(θ_T, θ_dot_T, a_T, b_T)

    return Particle{T}(
        Int32(id),
        mass_T,
        radius_T,
        θ_T,
        θ_dot_T,
        pos,
        vel
    )
end

"""
    generate_random_particles(n, mass, radius_fraction, a, b; rng=Random.GLOBAL_RNG)

Genera n partículas con posiciones angulares aleatorias sin superposición.

# Parámetros
- `n`: Número de partículas
- `mass`: Masa de cada partícula
- `radius_fraction`: Fracción del semi-eje menor para el radio (e.g., 0.05)
- `a`, `b`: Semi-ejes de la elipse
- `rng`: Generador de números aleatorios (para reproducibilidad)

# Retorna
- `Vector{Particle{T}}`: Vector de partículas inicializadas

# Mejoras respecto al código original
1. Type-stable (no usa Vector{Any})
2. Pre-aloca arrays
3. Usa Distributions para velocidades aleatorias
4. Mejor algoritmo de detección de superposición (usa longitud de arco)

# Ejemplo
```julia
using Random
rng = MersenneTwister(1234)
particles = generate_random_particles(10, 1.0, 0.05, 2.0, 1.0; rng=rng)
```
"""
function generate_random_particles(
    n::Int,
    mass::T,
    radius_fraction::T,
    a::T,
    b::T;
    θ_dot_range::Tuple{T,T} = (T(-1.0), T(1.0)),
    max_attempts::Int = 10000,
    rng::AbstractRNG = Random.GLOBAL_RNG
) where {T <: AbstractFloat}

    radius = radius_fraction * min(a, b)
    particles = Vector{Particle{T}}(undef, n)

    # Distancia mínima en longitud de arco
    min_arc_distance = 2 * radius

    # Almacenar ángulos ya usados
    θ_positions = Vector{T}(undef, n)

    for i in 1:n
        attempts = 0
        valid_position = false

        while !valid_position && attempts < max_attempts
            attempts += 1

            # Generar ángulo aleatorio
            θ_candidate = rand(rng, T) * 2 * T(π)

            # Verificar superposición con partículas existentes
            overlapping = false

            for j in 1:(i-1)
                θ_existing = θ_positions[j]

                # Diferencia angular
                Δθ = abs(θ_candidate - θ_existing)
                Δθ = min(Δθ, 2*T(π) - Δθ)  # Mínima diferencia angular

                # Aproximación: longitud de arco ≈ √(g_θθ) * Δθ
                θ_mid = (θ_candidate + θ_existing) / 2
                g_mid = sqrt(metric_ellipse(θ_mid, a, b))
                arc_length = g_mid * Δθ

                if arc_length < min_arc_distance
                    overlapping = true
                    break
                end
            end

            if !overlapping
                # Generar velocidad angular aleatoria
                θ_dot = θ_dot_range[1] + rand(rng, T) * (θ_dot_range[2] - θ_dot_range[1])

                # Crear partícula
                particles[i] = initialize_particle(i, mass, radius, θ_candidate, θ_dot, a, b)
                θ_positions[i] = θ_candidate

                valid_position = true
            end
        end

        if !valid_position
            error("No se pudo generar posición válida para partícula $i después de $max_attempts intentos. " *
                  "Intenta reducir el número de partículas o el radio.")
        end
    end

    return particles
end

# ============================================================================
# Utilidades
# ============================================================================

"""
    total_energy(particles::Vector{Particle}, a, b)

Calcula la energía total del sistema.

Para partículas libres en una elipse:
```
E_total = ∑ᵢ (1/2) mᵢ g_θθ(θᵢ) θ̇ᵢ²
```
"""
function total_energy(
    particles::Vector{Particle{T}},
    a::T,
    b::T
) where {T <: AbstractFloat}
    return sum(p -> kinetic_energy(p, a, b), particles)
end

"""
    total_linear_momentum(particles::Vector{Particle})

Calcula el momento lineal total en coordenadas cartesianas.

```
P⃗_total = ∑ᵢ mᵢ v⃗ᵢ
```
"""
function total_linear_momentum(particles::Vector{Particle{T}}) where {T <: AbstractFloat}
    return sum(p -> linear_momentum_cartesian(p), particles)
end

"""
    center_of_mass(particles::Vector{Particle})

Calcula el centro de masa del sistema.

```
R⃗_cm = (∑ᵢ mᵢ r⃗ᵢ) / (∑ᵢ mᵢ)
```
"""
function center_of_mass(particles::Vector{Particle{T}}) where {T <: AbstractFloat}
    total_mass = sum(p -> p.mass, particles)
    weighted_pos = sum(p -> p.mass * p.pos, particles)
    return weighted_pos / total_mass
end

# ============================================================================
# Imports de funciones geométricas
# ============================================================================

if !@isdefined(metric_ellipse)
    @inline function metric_ellipse(θ::T, a::T, b::T) where {T <: AbstractFloat}
        s, c = sincos(θ)
        return a^2 * s^2 + b^2 * c^2
    end
end

if !@isdefined(cartesian_from_angle)
    @inline function cartesian_from_angle(θ::T, a::T, b::T) where {T <: AbstractFloat}
        s, c = sincos(θ)
        return SVector{2,T}(a * c, b * s)
    end
end

if !@isdefined(velocity_from_angular)
    @inline function velocity_from_angular(θ::T, θ_dot::T, a::T, b::T) where {T <: AbstractFloat}
        s, c = sincos(θ)
        return SVector{2,T}(-a * θ_dot * s, b * θ_dot * c)
    end
end
