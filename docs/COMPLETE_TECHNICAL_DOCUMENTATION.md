# 📚 Documentación Técnica Completa - CollectiveDynamics.jl

## Tabla de Contenidos

1. [Sistema de Partículas](#sistema-de-partículas)
2. [Colisiones en Variedades Curvas](#colisiones-en-variedades-curvas)
3. [Conservación y Análisis](#conservación-y-análisis)
4. [Arquitectura del Sistema](#arquitectura-del-sistema)
5. [Guía de Desarrollo](#guía-de-desarrollo)
6. [API Reference Completa](#api-reference-completa)

---

# Sistema de Partículas

## Archivo: `src/particles.jl`

### Estructura de Datos Optimizada

#### Diseño del Struct

```julia
struct Particle{T <: AbstractFloat}
    id::Int32                    # ID único (Int32 suficiente)
    mass::T                      # Masa
    radius::T                    # Radio (detección colisiones)
    θ::T                         # Posición angular
    θ_dot::T                     # Velocidad angular
    pos::SVector{2, T}           # Posición cartesiana (x, y)
    vel::SVector{2, T}           # Velocidad cartesiana (vx, vy)
end
```

#### Decisiones de Diseño

**1. Struct Immutable**
- **Pro:** Stack allocation, mejor cache locality
- **Pro:** Thread-safe por defecto
- **Con:** Necesita crear nueva instancia para actualizar
- **Solución:** Función `update_particle` muy rápida

**2. Int32 para ID**
- Suficiente para 2.1B partículas
- Ocupa mitad de memoria que Int64
- Mejor cache performance

**3. SVector para Posición/Velocidad**
- ~10x más rápido que `Vector{T}`
- Stack allocation (no heap)
- SIMD-friendly

**4. Redundancia: Angular + Cartesiana**
- **Trade-off:** Memoria vs velocidad
- **Beneficio:** Evita conversiones repetidas
- **Costo:** 4 floats extra por partícula
- **Para 1000 partículas:** 32KB extra (despreciable)

#### Layout en Memoria

```
Particle{Float64}:
┌─────────┬──────┬────────┬─────┬────────┬───────────┬───────────┐
│ id      │ mass │ radius │  θ  │ θ_dot  │   pos     │   vel     │
│ (4B)    │ (8B) │  (8B)  │(8B) │  (8B)  │ (16B)     │  (16B)    │
└─────────┴──────┴────────┴─────┴────────┴───────────┴───────────┘
Total: 68 bytes (con padding)

Para 10,000 partículas: 680 KB (cabe en L3 cache)
```

### Operaciones sobre Partículas

#### Actualización de Estado

```julia
@inline function update_particle(
    p::Particle{T},
    θ_new::T,
    θ_dot_new::T,
    a::T,
    b::T
) where {T <: AbstractFloat}

    pos_new = cartesian_from_angle(θ_new, a, b)
    vel_new = velocity_from_angular(θ_new, θ_dot_new, a, b)

    return Particle{T}(
        p.id, p.mass, p.radius,
        θ_new, θ_dot_new,
        pos_new, vel_new
    )
end
```

**Performance:**
- Sin alocaciones heap
- ~2 ns en CPU moderna
- Compiler puede inline completamente

#### Energía y Momento

**Energía Cinética (coordenadas angulares):**
```julia
@inline function kinetic_energy(p::Particle{T}, a::T, b::T) where {T}
    g = metric_ellipse(p.θ, a, b)
    return 0.5 * p.mass * g * p.θ_dot^2
end
```

**Energía Cinética (coordenadas cartesianas):**
```julia
@inline function kinetic_energy_cartesian(p::Particle{T}) where {T}
    return 0.5 * p.mass * dot(p.vel, p.vel)
end
```

**Invariante:** Ambas deben dar el mismo resultado (verificado en tests).

**Momento Angular:**
```julia
@inline function angular_momentum(p::Particle{T}, a::T, b::T) where {T}
    g = metric_ellipse(p.θ, a, b)
    return p.mass * g * p.θ_dot
end
```

**Nota:** NO es constante en elipse (solo en círculos).

### Inicialización de Partículas

#### Generación sin Superposición

**Algoritmo:**
1. Generar ángulo aleatorio θ
2. Verificar distancia geodésica con partículas existentes
3. Si d < 2r, rechazar y reintentar
4. Máximo 10,000 intentos antes de error

**Implementación:**
```julia
function generate_random_particles(
    n::Int,
    mass::T,
    radius_fraction::T,
    a::T,
    b::T;
    θ_dot_range::Tuple{T,T} = (T(-1e5), T(1e5)),
    max_attempts::Int = 10000,
    rng::AbstractRNG = Random.GLOBAL_RNG
) where {T <: AbstractFloat}

    radius = radius_fraction * min(a, b)
    particles = Vector{Particle{T}}(undef, n)
    min_arc_distance = 2 * radius

    θ_positions = Vector{T}(undef, n)

    for i in 1:n
        valid_position = false
        attempts = 0

        while !valid_position && attempts < max_attempts
            attempts += 1
            θ_candidate = rand(rng, T) * 2 * T(π)

            # Verificar superposición
            overlapping = false
            for j in 1:(i-1)
                Δθ = abs(θ_candidate - θ_positions[j])
                Δθ = min(Δθ, 2*T(π) - Δθ)

                θ_mid = (θ_candidate + θ_positions[j]) / 2
                g_mid = sqrt(metric_ellipse(θ_mid, a, b))
                arc_length = g_mid * Δθ

                if arc_length < min_arc_distance
                    overlapping = true
                    break
                end
            end

            if !overlapping
                θ_dot = θ_dot_range[1] + rand(rng, T) * (θ_dot_range[2] - θ_dot_range[1])
                particles[i] = initialize_particle(i, mass, radius, θ_candidate, θ_dot, a, b)
                θ_positions[i] = θ_candidate
                valid_position = true
            end
        end

        if !valid_position
            error("No se pudo generar posición válida para partícula $i")
        end
    end

    return particles
end
```

**Optimizaciones:**
- Type-stable (no `Any[]`)
- Pre-aloca arrays
- Usa RNG pasado como parámetro (reproducibilidad)
- Early exit en loop de superposición

**Mejora Futura: Spatial Hashing**
```julia
# Para n > 1000, usar spatial hashing
# Complejidad: O(n) en vez de O(n²)
function generate_random_particles_fast(...)
    # Dividir elipse en bins angulares
    # Solo verificar partículas en bins adyacentes
end
```

---

# Colisiones en Variedades Curvas

## Archivo: `src/collisions.jl`

### Fundamentos Teóricos

#### Detección de Colisiones

**Condición:**
```math
d_{geodesic}(θ_1, θ_2) \leq r_1 + r_2
```

**Aproximación para elipse:**
```math
d_{geodesic} \approx \sqrt{g_{θθ}(\frac{θ_1 + θ_2}{2})} \cdot |\theta_1 - \theta_2|
```

donde tomamos el camino más corto: `min(Δθ, 2π - Δθ)`.

**Implementación:**
```julia
@inline function check_collision(
    p1::Particle{T},
    p2::Particle{T},
    a::T,
    b::T
) where {T <: AbstractFloat}

    Δθ = abs(p1.θ - p2.θ)
    Δθ = min(Δθ, 2*T(π) - Δθ)

    if Δθ < T(1e-10)
        return true
    end

    θ_mid = (p1.θ + p2.θ) / 2
    g_mid = sqrt(metric_ellipse(θ_mid, a, b))
    arc_length = g_mid * Δθ

    return arc_length <= (p1.radius + p2.radius)
end
```

**Detección Alternativa (Cartesiana):**
```julia
@inline function check_collision_cartesian(p1::Particle{T}, p2::Particle{T}) where {T}
    dist_sq = sum((p1.pos - p2.pos).^2)
    radii_sum = p1.radius + p2.radius
    return dist_sq <= radii_sum^2
end
```

**Trade-off:**
- **Geodésica:** Geométricamente correcta, ligeramente más cara
- **Cartesiana:** Muy rápida, suficiente para pre-filtrado

### Métodos de Resolución

#### Método 1: Intercambio Simple

**Algoritmo:**
```
Para colisión entre p1 y p2:
  θ̇₁' = θ̇₂
  θ̇₂' = θ̇₁
```

**Válido para:**
- Masas iguales
- Colisiones elásticas
- Aproximación de primer orden

**Implementación:**
```julia
function resolve_collision_simple(
    p1::Particle{T},
    p2::Particle{T},
    a::T,
    b::T
) where {T <: AbstractFloat}

    θ_dot_1_new = p2.θ_dot
    θ_dot_2_new = p1.θ_dot

    p1_new = update_particle(p1, p1.θ, θ_dot_1_new, a, b)
    p2_new = update_particle(p2, p2.θ, θ_dot_2_new, a, b)

    return (p1_new, p2_new)
end
```

**Conservación:**
- ✅ Momento total
- ✅ Energía (para masas iguales)
- ❌ NO incluye corrección geométrica

#### Método 2: Transporte Paralelo (Artículo)

**Algoritmo:**
```
1. Intercambiar velocidades (colisión elástica)
2. Aplicar transporte paralelo a cada velocidad
3. Verificar conservación
```

**Ecuación clave:**
```math
\dot{\theta}_i' = \dot{\theta}_i - \Gamma^{\theta}_{\theta\theta}(\theta_i) \dot{\theta}_i \Delta\theta_i
```

**Implementación:**
```julia
function resolve_collision_parallel_transport(
    p1::Particle{T},
    p2::Particle{T},
    a::T,
    b::T;
    tolerance::T = T(1e-6)
) where {T <: AbstractFloat}

    # Energía/momento antes
    E_before = kinetic_energy(p1, a, b) + kinetic_energy(p2, a, b)
    p_before = angular_momentum(p1, a, b) + angular_momentum(p2, a, b)

    # Intercambio de velocidades
    θ_dot_1_temp = p2.θ_dot
    θ_dot_2_temp = p1.θ_dot

    # Transporte paralelo (Δθ = 0 para colisión instantánea)
    # Para colisión finita, usar Δθ estimado
    Δθ_1 = T(0)
    Δθ_2 = T(0)

    θ_dot_1_new = parallel_transport_velocity(θ_dot_1_temp, Δθ_1, p1.θ, a, b)
    θ_dot_2_new = parallel_transport_velocity(θ_dot_2_temp, Δθ_2, p2.θ, a, b)

    # Actualizar partículas
    p1_new = update_particle(p1, p1.θ, θ_dot_1_new, a, b)
    p2_new = update_particle(p2, p2.θ, θ_dot_2_new, a, b)

    # Verificar conservación
    E_after = kinetic_energy(p1_new, a, b) + kinetic_energy(p2_new, a, b)
    p_after = angular_momentum(p1_new, a, b) + angular_momentum(p2_new, a, b)

    ΔE = abs(E_after - E_before)
    Δp = abs(p_after - p_before)

    conserved = (ΔE / (E_before + eps(T)) < tolerance) &&
                (Δp / (abs(p_before) + eps(T)) < tolerance)

    return (p1_new, p2_new, conserved)
end
```

**Mejora:** Para colisiones no instantáneas, estimar Δθ:
```julia
# Tiempo de colisión ~ distancia / velocidad relativa
dt_collision = (p1.radius + p2.radius) / abs(p1.θ_dot - p2.θ_dot)
Δθ_1 = 0.5 * (p1.θ_dot + θ_dot_1_temp) * dt_collision
```

#### Método 3: Integración Geodésica Completa

**Algoritmo:**
```
1. Calcular velocidades post-colisión (conservación p, E)
2. Aplicar transporte paralelo
3. Integrar geodésicas con Forest-Ruth
4. Verificar conservación
```

**Implementación:**
```julia
function resolve_collision_geodesic(
    p1::Particle{T},
    p2::Particle{T},
    dt::T,
    a::T,
    b::T;
    tolerance::T = T(1e-6)
) where {T <: AbstractFloat}

    E_before = kinetic_energy(p1, a, b) + kinetic_energy(p2, a, b)

    # Colisión elástica
    m1, m2 = p1.mass, p2.mass
    M = m1 + m2

    if abs(m1 - m2) < eps(T)
        θ_dot_1_new = p2.θ_dot
        θ_dot_2_new = p1.θ_dot
    else
        θ_dot_1_new = ((m1 - m2) * p1.θ_dot + 2*m2 * p2.θ_dot) / M
        θ_dot_2_new = ((m2 - m1) * p2.θ_dot + 2*m1 * p1.θ_dot) / M
    end

    # Transporte paralelo
    Δθ_1 = dt * (p1.θ_dot + θ_dot_1_new) / 2
    Δθ_2 = dt * (p2.θ_dot + θ_dot_2_new) / 2

    θ_dot_1_transported = parallel_transport_velocity(θ_dot_1_new, Δθ_1, p1.θ, a, b)
    θ_dot_2_transported = parallel_transport_velocity(θ_dot_2_new, Δθ_2, p2.θ, a, b)

    # Integrar geodésicas
    θ1_new, θ_dot_1_final = forest_ruth_step_ellipse(p1.θ, θ_dot_1_transported, dt, a, b)
    θ2_new, θ_dot_2_final = forest_ruth_step_ellipse(p2.θ, θ_dot_2_transported, dt, a, b)

    p1_new = update_particle(p1, θ1_new, θ_dot_1_final, a, b)
    p2_new = update_particle(p2, θ2_new, θ_dot_2_final, a, b)

    # Verificar conservación
    E_after = kinetic_energy(p1_new, a, b) + kinetic_energy(p2_new, a, b)
    ΔE = abs(E_after - E_before)
    conserved = ΔE / (E_before + eps(T)) < tolerance

    return (p1_new, p2_new, conserved)
end
```

### Sistema Multi-Partícula

#### Detección Global

**Naive O(n²):**
```julia
function detect_all_collisions(
    particles::Vector{Particle{T}},
    a::T,
    b::T
) where {T <: AbstractFloat}

    n = length(particles)
    collisions = Tuple{Int, Int}[]

    @inbounds for i in 1:n
        for j in (i+1):n
            if check_collision(particles[i], particles[j], a, b)
                push!(collisions, (i, j))
            end
        end
    end

    return collisions
end
```

**Mejora: Spatial Hashing O(n)**

```julia
# TODO: Implementar para n > 1000
function detect_collisions_spatial_hash(particles, a, b)
    # 1. Dividir espacio en celdas
    # 2. Asignar partículas a celdas
    # 3. Solo verificar partículas en celdas adyacentes
end
```

#### Resolución Global

```julia
function resolve_all_collisions!(
    particles::Vector{Particle{T}},
    a::T,
    b::T;
    method::Symbol = :parallel_transport,
    dt::T = T(1e-6),
    tolerance::T = T(1e-6)
) where {T <: AbstractFloat}

    collision_pairs = detect_all_collisions(particles, a, b)
    n_collisions = length(collision_pairs)

    if n_collisions == 0
        return 0, 1.0
    end

    n_conserved = 0

    for (i, j) in collision_pairs
        p1 = particles[i]
        p2 = particles[j]

        if method == :simple
            p1_new, p2_new = resolve_collision_simple(p1, p2, a, b)
            conserved = true

        elseif method == :parallel_transport
            p1_new, p2_new, conserved = resolve_collision_parallel_transport(
                p1, p2, a, b; tolerance=tolerance
            )

        elseif method == :geodesic
            p1_new, p2_new, conserved = resolve_collision_geodesic(
                p1, p2, dt, a, b; tolerance=tolerance
            )
        end

        particles[i] = p1_new
        particles[j] = p2_new

        if conserved
            n_conserved += 1
        end
    end

    conserved_frac = n_conserved / n_collisions

    return n_collisions, conserved_frac
end
```

**Problema: Colisiones Simultáneas**

Si partículas A-B y B-C colisionan simultáneamente, procesamiento secuencial puede introducir errores.

**Solución (no implementada):**
```julia
# Resolver colisiones en grafos independientes
function resolve_collision_graph!(collision_pairs)
    # 1. Construir grafo de colisiones
    # 2. Encontrar componentes conexas
    # 3. Resolver cada componente independientemente
end
```

---

# Conservación y Análisis

## Archivo: `src/conservation.jl`

### Estructura de Datos

```julia
mutable struct ConservationData{T <: AbstractFloat}
    times::Vector{T}
    energies::Vector{T}
    momenta::Vector{SVector{2,T}}
    angular_momenta::Vector{T}
    n_particles::Vector{Int}
end
```

**Uso:**
```julia
data = ConservationData{Float64}()

for t in simulation
    record_conservation!(data, particles, t, a, b)
end

analyze_energy_conservation(data)
```

### Registro de Cantidades Conservadas

```julia
function record_conservation!(
    data::ConservationData{T},
    particles::Vector{Particle{T}},
    t::T,
    a::T,
    b::T
) where {T <: AbstractFloat}

    E = total_energy(particles, a, b)
    p_cart = total_linear_momentum(particles)
    L = sum(p -> angular_momentum(p, a, b), particles)

    push!(data.times, t)
    push!(data.energies, E)
    push!(data.momenta, p_cart)
    push!(data.angular_momenta, L)
    push!(data.n_particles, length(particles))

    return nothing
end
```

### Análisis Estadístico

#### Energía

```julia
function analyze_energy_conservation(data::ConservationData{T}) where {T}
    E_initial = data.energies[1]
    E_final = data.energies[end]
    E_mean = mean(data.energies)
    E_std = std(data.energies)

    rel_errors = abs.((data.energies .- E_initial) ./ E_initial)
    max_rel_error = maximum(rel_errors)

    rel_drift = (E_final - E_initial) / E_initial

    return (
        E_initial = E_initial,
        E_final = E_final,
        E_mean = E_mean,
        E_std = E_std,
        max_rel_error = max_rel_error,
        rel_drift = rel_drift,
        is_conserved = max_rel_error < T(1e-4)  # Criterio del artículo
    )
end
```

#### Momento Lineal

```julia
function analyze_momentum_conservation(data::ConservationData{T}) where {T}
    p_initial = data.momenta[1]
    p_final = data.momenta[end]

    p_magnitudes = [norm(p) for p in data.momenta]
    p_mag_mean = mean(p_magnitudes)
    p_mag_std = std(p_magnitudes)

    if norm(p_initial) > eps(T)
        rel_variation = maximum(abs.((p_magnitudes .- norm(p_initial)) ./ norm(p_initial)))
    else
        rel_variation = maximum(p_magnitudes)
    end

    return (
        p_initial = p_initial,
        p_final = p_final,
        p_mag_mean = p_mag_mean,
        p_mag_std = p_mag_std,
        rel_variation = rel_variation
    )
end
```

**Nota Física:** En elipse, momento lineal NO se conserva (no hay simetría traslacional). Lo monitoreamos como medida de precisión numérica.

#### Verificación Instantánea de Colisiones

```julia
function verify_collision_conservation(
    p1_before::Particle{T},
    p2_before::Particle{T},
    p1_after::Particle{T},
    p2_after::Particle{T},
    a::T,
    b::T;
    tolerance::T = T(1e-6)
) where {T}

    E_before = kinetic_energy(p1_before, a, b) + kinetic_energy(p2_before, a, b)
    E_after = kinetic_energy(p1_after, a, b) + kinetic_energy(p2_after, a, b)
    ΔE = abs(E_after - E_before)

    energy_conserved = ΔE / (E_before + eps(T)) < tolerance

    L_before = angular_momentum(p1_before, a, b) + angular_momentum(p2_before, a, b)
    L_after = angular_momentum(p1_after, a, b) + angular_momentum(p2_after, a, b)
    ΔL = abs(L_after - L_before)

    momentum_conserved = ΔL / (abs(L_before) + eps(T)) < tolerance

    return (
        energy_conserved = energy_conserved,
        momentum_conserved = momentum_conserved,
        ΔE = ΔE,
        ΔE_rel = ΔE / (E_before + eps(T)),
        ΔL = ΔL,
        ΔL_rel = ΔL / (abs(L_before) + eps(T))
    )
end
```

---

# Arquitectura del Sistema

## Diagrama de Módulos

```
CollectiveDynamics.jl
├── Geometry
│   ├── Metrics              [metrics.jl]
│   ├── Christoffel          [christoffel.jl]
│   └── ParallelTransport    [parallel_transport.jl]
├── Integrators
│   └── ForestRuth           [forest_ruth.jl]
├── Particles                [particles.jl]
├── Collisions               [collisions.jl]
├── Conservation             [conservation.jl]
└── Main                     [CollectiveDynamics.jl]
```

## Flujo de Datos

```
Inicialización:
  generate_random_particles()
      ↓
  Vector{Particle}

Loop de Simulación:
  particles → forest_ruth_step_ellipse() → particles'
      ↓
  detect_all_collisions()
      ↓
  resolve_all_collisions!() → particles''
      ↓
  record_conservation!()
      ↓
  repeat

Análisis:
  ConservationData
      ↓
  analyze_energy_conservation()
  analyze_momentum_conservation()
      ↓
  Estadísticas + Plots
```

## Dependencias entre Módulos

```
Particles
  ↓ usa
Geometry (metrics, christoffel)

ForestRuth
  ↓ usa
Geometry (christoffel)

Collisions
  ↓ usa
Geometry (parallel_transport)
Particles (update_particle)
ForestRuth (para método geodésico)

Conservation
  ↓ usa
Particles (kinetic_energy, momentum)
```

---

# Guía de Desarrollo

## Setup del Entorno

```bash
# Clonar repo
git clone https://github.com/hmedel/Collective-Dynamics.git
cd Collective-Dynamics

# Activar proyecto
julia --project=.

# Instalar dependencias
julia> using Pkg; Pkg.instantiate()

# Ejecutar tests
julia> Pkg.test()
```

## Workflow de Desarrollo

### 1. Crear Nueva Rama

```bash
git checkout -b feature/mi-nueva-caracteristica
```

### 2. Desarrollo Iterativo

```julia
# Modo desarrollo con Revise.jl
using Revise
using CollectiveDynamics

# Editar código...
# Probar cambios (sin reiniciar Julia)
```

### 3. Tests

```julia
# Tests específicos
include("test/runtests.jl")

# O con Pkg.test()
using Pkg
Pkg.test("CollectiveDynamics")
```

### 4. Benchmarks

```julia
using BenchmarkTools

# Benchmark función específica
@benchmark my_function($args...)

# Profile
using Profile
@profile my_function(args...)
Profile.print()
```

### 5. Commit y Push

```bash
git add .
git commit -m "Add: descripción del cambio"
git push origin feature/mi-nueva-caracteristica
```

## Añadir Nueva Geometría

**Ejemplo: Esfera**

### 1. Crear `src/geometry/sphere.jl`

```julia
# Métrica para esfera
function metric_sphere(θ::T, φ::T, R::T) where {T}
    g_θθ = R^2
    g_φφ = R^2 * sin(θ)^2
    return SMatrix{2,2,T}(g_θθ, 0, 0, g_φφ)
end

# Christoffel (múltiples componentes)
function christoffel_sphere(θ, φ, R)
    # Γ^θ_φφ, Γ^φ_θφ, etc.
    # ...
end
```

### 2. Extender Partícula

```julia
struct ParticleSphere{T} <: AbstractParticle
    id::Int32
    mass::T
    radius::T
    θ::T              # Latitud
    φ::T              # Longitud
    θ_dot::T
    φ_dot::T
    pos::SVector{3,T}  # Coordenadas cartesianas 3D
    vel::SVector{3,T}
end
```

### 3. Adaptar Integrador

```julia
function forest_ruth_step_sphere(
    θ, φ, θ_dot, φ_dot, dt, R
)
    # Similar a elipse pero con 2 coordenadas
    # Christoffel tiene más componentes
end
```

### 4. Tests

```julia
@testset "Esfera" begin
    # Verificar métrica, Christoffel, etc.
end
```

## Optimización de Performance

### Herramientas

```julia
using Profile
using ProfileView
using BenchmarkTools

# Profile
@profile simulate_ellipse(particles, a, b; n_steps=1000)
ProfileView.view()

# Benchmark comparativo
suite = BenchmarkGroup()
suite["method1"] = @benchmarkable ...
suite["method2"] = @benchmarkable ...
results = run(suite)
```

### Checklist de Optimización

- [ ] Type stability (`@code_warntype`)
- [ ] Evitar alocaciones en loops
- [ ] Usar `@inline` en funciones pequeñas
- [ ] Usar `@simd` cuando sea posible
- [ ] `SVector` para vectores pequeños
- [ ] Pre-alocar arrays
- [ ] Evitar variables globales

---

# API Reference Completa

## Módulo: `CollectiveDynamics`

### Exports Principales

#### Geometría

```julia
# Métricas
metric_ellipse(θ, a, b) → Float64
metric_derivative_ellipse(θ, a, b) → Float64
inverse_metric_ellipse(θ, a, b) → Float64

# Conversiones
cartesian_from_angle(θ, a, b) → SVector{2}
velocity_from_angular(θ, θ_dot, a, b) → SVector{2}

# Christoffel
christoffel_ellipse(θ, a, b) → Float64
christoffel_numerical(metric_func, q[, h]) → Float64
christoffel_autodiff(metric_func, q) → Float64

# Transporte Paralelo
parallel_transport_velocity(v_old, Δθ, θ, a, b) → Float64
parallel_transport_path(v_initial, θ_path, a, b) → Vector{Float64}
```

#### Integradores

```julia
# Forest-Ruth
forest_ruth_step_ellipse(θ, θ_dot, dt, a, b) → (θ_new, θ_dot_new)
integrate_forest_ruth(θ₀, θ_dot₀, dt, n_steps, a, b) → (θ_traj, θ_dot_traj)

# Verificación
verify_symplecticity(θ₀, θ_dot₀, dt, n_steps, a, b) → NamedTuple
```

#### Partículas

```julia
# Tipos
Particle{T}

# Inicialización
initialize_particle(id, mass, radius, θ, θ_dot, a, b) → Particle
generate_random_particles(n, mass, radius_fraction, a, b) → Vector{Particle}

# Propiedades
kinetic_energy(p::Particle, a, b) → Float64
angular_momentum(p::Particle, a, b) → Float64
linear_momentum_cartesian(p::Particle) → SVector{2}

# Sistema
total_energy(particles, a, b) → Float64
total_linear_momentum(particles) → SVector{2}
center_of_mass(particles) → SVector{2}
```

#### Colisiones

```julia
# Detección
check_collision(p1, p2, a, b) → Bool
detect_all_collisions(particles, a, b) → Vector{Tuple{Int,Int}}

# Resolución
resolve_collision_simple(p1, p2, a, b) → (p1_new, p2_new)
resolve_collision_parallel_transport(p1, p2, a, b) → (p1_new, p2_new, conserved)
resolve_collision_geodesic(p1, p2, dt, a, b) → (p1_new, p2_new, conserved)

# Sistema
resolve_all_collisions!(particles, a, b; method, dt, tolerance) → (n_collisions, conserved_frac)
```

#### Conservación

```julia
# Tipos
ConservationData{T}

# Registro
record_conservation!(data, particles, t, a, b) → Nothing

# Análisis
analyze_energy_conservation(data) → NamedTuple
analyze_momentum_conservation(data) → NamedTuple
analyze_angular_momentum(data) → NamedTuple

# Utilidades
print_conservation_summary(data)
get_energy_data(data) → (times, energies, rel_errors)
get_momentum_data(data) → (times, px, py, p_mag)
```

#### Simulación

```julia
# High-level
SimulationData{T}

simulate_ellipse(
    particles_initial, a, b;
    n_steps=1000,
    dt=1e-5,
    save_every=10,
    collision_method=:parallel_transport,
    tolerance=1e-6,
    verbose=true
) → SimulationData
```

### Parámetros Comunes

| Parámetro | Tipo | Descripción | Típico |
|-----------|------|-------------|--------|
| `a`, `b` | Float64 | Semi-ejes elipse | 2.0, 1.0 |
| `θ` | Float64 | Ángulo [0, 2π] | - |
| `θ_dot` | Float64 | Velocidad angular | -1e5 a 1e5 |
| `dt` | Float64 | Paso de tiempo | 1e-8 a 1e-5 |
| `tolerance` | Float64 | Tolerancia numérica | 1e-6 |
| `method` | Symbol | :simple, :parallel_transport, :geodesic | - |

---

## Convenciones de Código

### Nomenclatura

- **Funciones:** `snake_case`
- **Tipos:** `PascalCase`
- **Constantes:** `UPPER_SNAKE_CASE`
- **Variables locales:** `snake_case`
- **Parámetros de tipo:** `T`, `U`, etc.

### Anotaciones de Tipo

```julia
# ✅ Bueno
function my_function(x::T, y::T) where {T <: AbstractFloat}
    return x + y
end

# ❌ Evitar
function my_function(x, y)  # No type annotations
    return x + y
end
```

### Documentación

```julia
"""
    my_function(x, y; option=default)

Brief description.

# Arguments
- `x::Float64`: Description of x
- `y::Float64`: Description of y
- `option::Symbol`: Description of option (default: `default`)

# Returns
- `Float64`: Description of return value

# Examples
\```julia
result = my_function(1.0, 2.0)
\```
"""
function my_function(x, y; option=default)
    # ...
end
```

---

**Última actualización:** 2024
**Autores:** J. Isaí García-Hernández, Héctor J. Medel-Cobaxín
