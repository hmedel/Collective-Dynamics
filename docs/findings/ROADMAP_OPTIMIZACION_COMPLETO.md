# Roadmap de Optimización Completo - CollectiveDynamics.jl

**Fecha:** 2025-11-13
**Objetivos del Usuario:**
1. ✅ Aumentar precisión (mejor conservación de energía/momento)
2. ✅ Escalar a más partículas (N >> 100)
3. ✅ Generalizar a curvas 3D embebidas en ℝ³ (curvatura + torsión)

**Estado actual:**
- ✅ Paralelización CPU (colisiones): 2-8x speedup
- ✅ Conservación: ΔE/E₀ ~ 1e-6 con Float64
- ⚠️ Límite práctico: N ~ 100 partículas (O(N²) domina)
- ⚠️ Código específico para elipse (2D)

---

## Fase 1: Optimizaciones Inmediatas (1-2 semanas)

### Objetivo: Preparar infraestructura para escalar

#### 1.1 Preallocación de Memoria ⭐ PRIORIDAD ALTA
**Speedup:** ~1.1-1.2x
**Esfuerzo:** Bajo (2-3 horas)
**Impacto a futuro:** Crítico para N grande

**Problema actual:**
```julia
# simulate_ellipse_adaptive usa push! dinámico
particles_history = Vector{Vector{Particle{T}}}()
push!(particles_history, copy(particles))  # Realoca cada vez
```

**Solución:**
```julia
# Preallocación basada en estimación
expected_saves = ceil(Int, max_time / save_interval) + 100
particles_history = Vector{Vector{Particle{T}}}(undef, expected_saves)

# Índice manual
save_idx = 1
particles_history[save_idx] = copy(particles)
save_idx += 1

# Si se queda corto, resize! (raro)
```

**Beneficios:**
- ~10-20% menos allocations
- Menos GC pauses (crítico para sims largas)
- Predictibilidad de memoria

**Archivo a modificar:** `src/CollectiveDynamics.jl:424-435`

---

#### 1.2 Memory Pool para Particle Arrays ⭐ PRIORIDAD MEDIA
**Speedup:** ~1.05-1.1x
**Esfuerzo:** Medio (1 día)

**Problema:** Cada `copy(particles)` aloca nuevo array.

**Solución:**
```julia
# Nuevo archivo: src/memory_pool.jl
struct ParticlePool{T <: AbstractFloat}
    pool::Vector{Vector{Particle{T}}}
    in_use::BitVector
    size::Int
end

function ParticlePool{T}(max_snapshots::Int, n_particles::Int) where T
    pool = [Vector{Particle{T}}(undef, n_particles) for _ in 1:max_snapshots]
    in_use = falses(max_snapshots)
    ParticlePool{T}(pool, in_use, n_particles)
end

function acquire!(pool::ParticlePool{T}) where T
    idx = findfirst(.!pool.in_use)
    isnothing(idx) && error("Pool exhausted")
    pool.in_use[idx] = true
    return pool.pool[idx], idx
end

function release!(pool::ParticlePool, idx::Int)
    pool.in_use[idx] = false
end

# Uso en simulate_ellipse_adaptive:
pool = ParticlePool{T}(expected_saves, length(particles))
arr, idx = acquire!(pool)
copyto!(arr, particles)  # Más rápido que copy()
particles_history[save_idx] = arr
```

**Beneficios:**
- Elimina allocations en loop principal
- ~5-10% menos tiempo en GC
- Escalable a N grande

---

#### 1.3 Reducir Allocations en Conservation ⭐ PRIORIDAD BAJA
**Speedup:** ~1.02-1.05x
**Esfuerzo:** Bajo (2 horas)

**Problema:**
```julia
# src/conservation.jl crea vectores intermedios
total_energy = sum(kinetic_energy_angular(p, a, b) for p in particles)
```

**Solución:**
```julia
function compute_total_energy(particles, a, b)
    E = zero(eltype(particles[1].θ))
    @inbounds for p in particles
        E += kinetic_energy_angular(p, a, b)
    end
    return E
end
```

**Beneficios:**
- Elimina allocations en comprehensions
- Marginal pero útil para sims largas

---

## Fase 2: Spatial Hashing (2-3 semanas) ⭐⭐⭐ CRÍTICO

### Objetivo: Romper la barrera O(N²) → O(N)

**Speedup esperado:**
- N=100: ~5-10x
- N=500: ~50-100x
- N=1000: ~100-200x

**Esfuerzo:** Alto (2-3 semanas)
**Prioridad:** 🔴 **CRÍTICA** para escalar a N>100

---

### 2.1 Diseño de Spatial Hash

**Concepto:**
```
Elipse (a,b) → Grid de celdas (cell_size × cell_size)
Cada partícula → celda según (x,y)
Colisiones: solo revisar pares en celdas vecinas (3×3 = 9 celdas)
```

**Estructura de datos:**
```julia
# Nuevo archivo: src/spatial_hash.jl

struct SpatialHash{T <: AbstractFloat}
    cell_size::T
    n_cells_x::Int
    n_cells_y::Int
    cells::Vector{Vector{Int}}  # cells[cell_idx] = [particle_indices...]

    # Bounding box de la elipse
    x_min::T
    x_max::T
    y_min::T
    y_max::T
end

function SpatialHash{T}(a::T, b::T, n_particles::Int) where T
    # Elipse: -a ≤ x ≤ a, -b ≤ y ≤ b
    x_min, x_max = -a, a
    y_min, y_max = -b, b

    # Heurística: cell_size ~ 2 × radio_partícula_promedio
    # Para elipse con N partículas uniformes:
    perimeter = π * (3(a+b) - sqrt((3a+b)*(a+3b)))
    avg_spacing = perimeter / n_particles
    cell_size = 2 * avg_spacing

    n_cells_x = ceil(Int, (x_max - x_min) / cell_size)
    n_cells_y = ceil(Int, (y_max - y_min) / cell_size)

    cells = [Int[] for _ in 1:(n_cells_x * n_cells_y)]

    SpatialHash{T}(cell_size, n_cells_x, n_cells_y, cells,
                   x_min, x_max, y_min, y_max)
end

function cell_index(hash::SpatialHash{T}, x::T, y::T) where T
    # Convertir (x,y) → (cell_x, cell_y) → linear index
    cell_x = clamp(floor(Int, (x - hash.x_min) / hash.cell_size) + 1, 1, hash.n_cells_x)
    cell_y = clamp(floor(Int, (y - hash.y_min) / hash.cell_size) + 1, 1, hash.n_cells_y)
    return (cell_y - 1) * hash.n_cells_x + cell_x
end

function insert_particle!(hash::SpatialHash{T}, particle_idx::Int, p::Particle{T}) where T
    idx = cell_index(hash, p.pos[1], p.pos[2])
    push!(hash.cells[idx], particle_idx)
end

function clear!(hash::SpatialHash)
    for cell in hash.cells
        empty!(cell)
    end
end

function rebuild!(hash::SpatialHash{T}, particles::Vector{Particle{T}}) where T
    clear!(hash)
    @inbounds for i in 1:length(particles)
        insert_particle!(hash, i, particles[i])
    end
end

function get_neighbor_cells(hash::SpatialHash, cell_idx::Int)
    # Retornar índices de las 9 celdas vecinas (3×3)
    cell_x = mod(cell_idx - 1, hash.n_cells_x) + 1
    cell_y = div(cell_idx - 1, hash.n_cells_x) + 1

    neighbors = Int[]
    for dy in -1:1, dx in -1:1
        nx = cell_x + dx
        ny = cell_y + dy

        # Boundary check
        if 1 ≤ nx ≤ hash.n_cells_x && 1 ≤ ny ≤ hash.n_cells_y
            push!(neighbors, (ny - 1) * hash.n_cells_x + nx)
        end
    end

    return neighbors
end
```

---

### 2.2 Detección de Colisiones con Spatial Hash

**Nueva función:**
```julia
# En src/adaptive_time.jl

function find_next_collision_spatial(
    particles::Vector{Particle{T}},
    a::T,
    b::T,
    hash::SpatialHash{T};
    max_time::T = T(1e-5),
    min_dt::T = T(1e-10)
) where {T <: AbstractFloat}

    # Reconstruir hash (O(N))
    rebuild!(hash, particles)

    t_min = max_time
    pair_min = (0, 0)
    found = false

    # Para cada celda (O(N_cells))
    for (cell_idx, particle_indices) in enumerate(hash.cells)
        isempty(particle_indices) && continue

        # Obtener celdas vecinas
        neighbor_cells = get_neighbor_cells(hash, cell_idx)

        # Revisar pares dentro de esta celda y vecinas
        for i in particle_indices
            # Pares dentro de la misma celda
            for j in particle_indices
                if i < j
                    t_coll = time_to_collision(particles[i], particles[j], a, b; max_time=max_time)
                    if isfinite(t_coll) && t_coll < t_min
                        t_min = t_coll
                        pair_min = (i, j)
                        found = true
                    end
                end
            end

            # Pares con partículas en celdas vecinas
            for neighbor_idx in neighbor_cells
                neighbor_idx == cell_idx && continue  # Ya revisado

                for j in hash.cells[neighbor_idx]
                    if i < j
                        t_coll = time_to_collision(particles[i], particles[j], a, b; max_time=max_time)
                        if isfinite(t_coll) && t_coll < t_min
                            t_min = t_coll
                            pair_min = (i, j)
                            found = true
                        end
                    end
                end
            end
        end
    end

    return (dt = found ? max(t_min, min_dt) : max_time,
            pair = pair_min,
            found = found)
end
```

**Complejidad:**
- Rebuild hash: O(N)
- Revisar celdas: O(N_cells) ≈ O(N) si densidad uniforme
- Pares por celda: O(k²) donde k = partículas/celda ≈ constante
- **Total: O(N)** vs O(N²) actual

**Speedup esperado:**
- N=100: ~10x (100²/100 = 100)
- N=1000: ~100x (1000²/1000 = 1000)

---

### 2.3 Versión Paralela de Spatial Hash

**Combinar con threading:**
```julia
function find_next_collision_spatial_parallel(
    particles::Vector{Particle{T}},
    a::T,
    b::T,
    hash::SpatialHash{T};
    kwargs...
) where {T <: AbstractFloat}

    rebuild!(hash, particles)

    n_threads = Threads.nthreads()
    t_mins = fill(T(Inf), n_threads)
    pairs = [(0, 0) for _ in 1:n_threads]

    # Paralelizar sobre celdas
    Threads.@threads for cell_idx in 1:length(hash.cells)
        tid = Threads.threadid()

        # ... revisar colisiones en celda cell_idx ...

        if t_coll < t_mins[tid]
            t_mins[tid] = t_coll
            pairs[tid] = (i, j)
        end
    end

    # Reducción
    t_min, idx = findmin(t_mins)

    return (dt = t_min, pair = pairs[idx], found = isfinite(t_min))
end
```

**Speedup combinado (Spatial + Parallel):**
- N=1000: ~100x (spatial) × 10x (parallel) = **1000x** 🚀

---

### 2.4 Integración en simulate_ellipse_adaptive

```julia
function simulate_ellipse_adaptive(
    particles_initial::Vector{Particle{T}},
    a::T,
    b::T;
    use_spatial_hash::Bool = true,  # Nuevo parámetro
    use_parallel::Bool = false,
    kwargs...
) where {T <: AbstractFloat}

    particles = copy(particles_initial)
    n = length(particles)

    # Decidir método de colisión
    if use_spatial_hash && n > 50
        hash = SpatialHash{T}(a, b, n)

        collision_finder = if use_parallel && Threads.nthreads() > 1
            (particles, a, b) -> find_next_collision_spatial_parallel(particles, a, b, hash; kwargs...)
        else
            (particles, a, b) -> find_next_collision_spatial(particles, a, b, hash; kwargs...)
        end
    else
        # Fallback a O(N²) original
        collision_finder = use_parallel ? find_next_collision_parallel : find_next_collision
    end

    # Loop principal
    while t < max_time
        collision_info = collision_finder(particles, a, b)
        # ... resto igual ...
    end
end
```

---

## Fase 3: Generalización a Curvas 3D (1-2 meses)

### Objetivo: Preparar código para curvas en ℝ³

**Cambios arquitectónicos necesarios:**

#### 3.1 Abstracción de Geometría

**Crear interfaz genérica:**
```julia
# Nuevo archivo: src/geometry/manifold.jl

abstract type Manifold{T <: AbstractFloat, N} end  # N = dimensión parámetro

# Curva en R³: N=1 (parámetro s), embedded en R³
struct Curve3D{T} <: Manifold{T, 1}
    # Funciones que definen la curva
    position::Function      # s → (x,y,z)
    tangent::Function       # s → T (vector tangente)
    normal::Function        # s → N (vector normal)
    binormal::Function      # s → B (vector binormal)
    curvature::Function     # s → κ(s)
    torsion::Function       # s → τ(s)
    arc_length::T           # Longitud total de la curva
end

# Elipse actual: caso especial
struct Ellipse2D{T} <: Manifold{T, 1}
    a::T  # Semi-eje mayor
    b::T  # Semi-eje menor
end

# Interface común
function metric(m::Manifold{T}, params...) where T
    error("Not implemented for $(typeof(m))")
end

function christoffel(m::Manifold{T}, params...) where T
    error("Not implemented for $(typeof(m))")
end

function cartesian_position(m::Manifold{T}, params...) where T
    error("Not implemented for $(typeof(m))")
end

# Implementación para Ellipse2D
function metric(m::Ellipse2D{T}, θ::T) where T
    return metric_ellipse(θ, m.a, m.b)
end

function christoffel(m::Ellipse2D{T}, θ::T) where T
    return christoffel_ellipse(θ, m.a, m.b)
end

function cartesian_position(m::Ellipse2D{T}, θ::T) where T
    return cartesian_from_angle(θ, m.a, m.b)
end

# Implementación para Curve3D
function metric(m::Curve3D{T}, s::T) where T
    # g_ss = |dr/ds|² (para curva parametrizada por longitud de arco = 1)
    return one(T)
end

function christoffel(m::Curve3D{T}, s::T) where T
    # Γ^s_ss = κ(s) * n_tangent / |tangent|²
    # Para curva parametrizada por arc length: simplificado
    κ = m.curvature(s)
    return κ
end

function cartesian_position(m::Curve3D{T}, s::T) where T
    return m.position(s)
end
```

---

#### 3.2 Partícula Genérica

```julia
# Modificar src/particles.jl

struct Particle{T <: AbstractFloat, N}  # N = dim parámetro
    id::Int32
    mass::T
    radius::T

    # Coordenadas en el espacio parámetro
    q::SVector{N, T}        # θ para elipse, s para curva 3D
    q_dot::SVector{N, T}    # θ̇ para elipse, ṡ para curva 3D

    # Coordenadas cartesianas (R² para elipse, R³ para curva 3D)
    pos::SVector{3, T}      # Siempre R³ (z=0 para curvas planas)
    vel::SVector{3, T}
end

# Constructores especializados
function Particle(id::Int, mass::T, radius::T, θ::T, θ_dot::T,
                  pos::SVector{2,T}, vel::SVector{2,T}) where T
    # Caso 2D: convertir a 3D con z=0
    pos3d = SVector{3,T}(pos[1], pos[2], zero(T))
    vel3d = SVector{3,T}(vel[1], vel[2], zero(T))

    return Particle{T, 1}(id, mass, radius,
                         SVector{1,T}(θ), SVector{1,T}(θ_dot),
                         pos3d, vel3d)
end
```

---

#### 3.3 Integrador Genérico

```julia
# Modificar src/integrators/forest_ruth.jl

function forest_ruth_step(
    q::SVector{N, T},
    q_dot::SVector{N, T},
    dt::T,
    manifold::Manifold{T, N}
) where {T, N}

    coeffs = get_coefficients(T)

    # Paso 1
    q1 = q .+ coeffs.γ₁ * dt .* q_dot
    Γ1 = christoffel(manifold, q1...)
    q_dot1 = q_dot .- coeffs.ρ₁ * dt .* Γ1 .* q_dot .* q_dot

    # Pasos 2, 3, 4 similar...

    return q4, q_dot4
end

# Versión específica para elipse (backward compatibility)
function forest_ruth_step_ellipse(θ::T, θ_dot::T, dt::T, a::T, b::T) where T
    manifold = Ellipse2D{T}(a, b)
    q = SVector{1,T}(θ)
    q_dot = SVector{1,T}(θ_dot)

    q_new, q_dot_new = forest_ruth_step(q, q_dot, dt, manifold)

    return q_new[1], q_dot_new[1]
end
```

---

#### 3.4 Ejemplo: Hélice en R³

```julia
# examples/helix_simulation.jl

using CollectiveDynamics

# Definir hélice: (a*cos(s), a*sin(s), b*s)
function helix_position(s::T, a::T, b::T) where T
    return SVector{3,T}(a*cos(s), a*sin(s), b*s)
end

function helix_tangent(s::T, a::T, b::T) where T
    # dr/ds
    return SVector{3,T}(-a*sin(s), a*cos(s), b)
end

function helix_curvature(s::T, a::T, b::T) where T
    # κ = a / (a² + b²)
    return a / (a^2 + b^2)
end

function helix_torsion(s::T, a::T, b::T) where T
    # τ = b / (a² + b²)
    return b / (a^2 + b^2)
end

# Crear manifold
a, b = 1.0, 0.5
arc_length = 4π  # 2 vueltas

helix = Curve3D{Float64}(
    s -> helix_position(s, a, b),
    s -> helix_tangent(s, a, b),
    s -> helix_normal(s, a, b),      # Calcular con Frenet-Serret
    s -> helix_binormal(s, a, b),    # B = T × N
    s -> helix_curvature(s, a, b),
    s -> helix_torsion(s, a, b),
    arc_length
)

# Generar partículas en la hélice
particles = generate_random_particles(30, 1.0, 0.1, helix)

# Simular
data = simulate_manifold_adaptive(particles, helix;
                                  max_time=1.0,
                                  dt_max=1e-5)
```

---

## Fase 4: Aumentar Precisión (en paralelo con Fase 2-3)

### Objetivo: Mejorar conservación de cantidades

**Opciones:**

#### 4.1 Float64 → BigFloat (Precisión Arbitraria)
**Conservación:** ΔE/E₀ ~ 1e-15 o mejor
**Speedup:** **0.01-0.1x** ❌ (10-100x más lento)
**Uso:** Solo para validación, no producción

```julia
# Config TOML
[simulation]
precision = "BigFloat"  # "Float64", "Float32", "BigFloat"
```

---

#### 4.2 Double-Double o Quad-Double (DoubleFloats.jl)
**Conservación:** ΔE/E₀ ~ 1e-30
**Speedup:** **0.1-0.3x** (3-10x más lento)
**Uso:** Balance razonable precisión/velocidad

```julia
using DoubleFloats

T = Double64  # ~32 dígitos de precisión
particles = generate_random_particles(30, T(1.0), T(0.05), T(2.0), T(1.0))
```

---

#### 4.3 Integradores de Mayor Orden
**Conservación:** Mejor que Forest-Ruth 4º orden
**Speedup:** ~0.5-0.8x (más pasos internos)

**Opciones:**
- **Yoshida 6º orden:** Error O(dt⁶)
- **Forest-Ruth 8º orden:** Error O(dt⁸)
- **Adaptive Runge-Kutta:** RK45, RK78 con control de error

```julia
# Nuevo archivo: src/integrators/yoshida6.jl

function yoshida6_step(q, q_dot, dt, manifold)
    # Coeficientes Yoshida 6º orden (8 sub-pasos)
    w1 = -1.17767998417887
    w2 = 0.235573213359357
    w3 = 0.784513610477560
    w0 = 1 - 2*(w1 + w2 + w3)

    # 8 pasos Forest-Ruth básicos con coeficientes especiales
    # ...
end
```

---

#### 4.4 Corrección de Conservación (Projection Methods)

**Idea:** Proyectar solución sobre variedad de energía constante cada N pasos.

```julia
function project_onto_energy_surface!(particles, E0, a, b; tolerance=1e-12)
    # Calcular energía actual
    E = total_energy(particles, a, b)
    ΔE = E - E0

    if abs(ΔE) > tolerance
        # Escalar velocidades para preservar energía
        scale_factor = sqrt(E0 / E)
        for i in 1:length(particles)
            p = particles[i]
            θ_dot_new = p.θ_dot * scale_factor
            particles[i] = update_particle(p, p.θ, θ_dot_new, a, b)
        end
    end
end

# Usar cada 100 pasos
if step % 100 == 0
    project_onto_energy_surface!(particles, E0, a, b)
end
```

**Ventajas:**
- Conservación exacta (dentro de tolerancia)
- Overhead mínimo (~1-2%)

**Desventajas:**
- No es "físico" (forzamos conservación)
- Puede introducir artefactos

---

## Fase 5: GPU Acceleration (3-6 meses)

### Objetivo: Speedup masivo para N >> 1000

**Tecnologías:**
- CUDA.jl (NVIDIA GPUs)
- AMDGPU.jl (AMD GPUs)
- KernelAbstractions.jl (portable)

**Speedup esperado:**
- N=1000: ~50-100x
- N=10000: ~200-500x

**Implementación:**
```julia
# src/gpu/collision_detection_cuda.jl

using CUDA

function find_collisions_kernel!(
    result_times::CuDeviceVector{T},
    result_pairs::CuDeviceVector{Tuple{Int,Int}},
    positions::CuDeviceMatrix{T},
    velocities::CuDeviceMatrix{T},
    radii::CuDeviceVector{T},
    n::Int,
    dt_max::T
) where T

    # Thread ID en grid 2D
    i = (blockIdx().x - 1) * blockDim().x + threadIdx().x
    j = (blockIdx().y - 1) * blockDim().y + threadIdx().y

    if i < j <= n
        # Calcular time_to_collision para par (i,j)
        t = time_to_collision_device(positions[:,i], velocities[:,i], radii[i],
                                     positions[:,j], velocities[:,j], radii[j],
                                     dt_max)

        # Atomic min para encontrar mínimo global
        if isfinite(t)
            old_min = CUDA.@atomic result_times[1] = min(result_times[1], t)

            # Si este thread actualizó el mínimo, guardar par
            if old_min > t
                result_pairs[1] = (i, j)
            end
        end
    end

    return nothing
end

function find_next_collision_gpu(particles::Vector{Particle{T}}, ...) where T
    n = length(particles)

    # Transferir a GPU
    positions_gpu = CuArray([p.pos for p in particles])
    velocities_gpu = CuArray([p.vel for p in particles])
    radii_gpu = CuArray([p.radius for p in particles])

    result_times = CuArray([T(Inf)])
    result_pairs = CuArray([(0, 0)])

    # Launch kernel
    threads = (16, 16)
    blocks = (cld(n, threads[1]), cld(n, threads[2]))

    @cuda threads=threads blocks=blocks find_collisions_kernel!(
        result_times, result_pairs,
        positions_gpu, velocities_gpu, radii_gpu,
        n, dt_max
    )

    # Transferir resultado a CPU
    t_min = Array(result_times)[1]
    pair = Array(result_pairs)[1]

    return (dt=t_min, pair=pair, found=isfinite(t_min))
end
```

---

## Roadmap de Implementación Recomendado

### Mes 1-2: Optimizaciones Base
- ✅ Semana 1: Preallocación + Memory Pool
- ✅ Semana 2: Reducir allocations
- ✅ Semana 3-4: Tests y benchmarks
- **Resultado:** ~1.2-1.3x speedup base

### Mes 3-4: Spatial Hashing
- ✅ Semana 5-6: Implementar SpatialHash
- ✅ Semana 7: Versión paralela
- ✅ Semana 8: Benchmarks N=100-1000
- **Resultado:** ~10-100x speedup para N>100

### Mes 5-6: Generalización 3D (en paralelo)
- ✅ Semana 9-10: Abstracción Manifold
- ✅ Semana 11: Implementar Curve3D
- ✅ Semana 12: Ejemplos (hélice, toro, etc.)
- **Resultado:** Framework genérico

### Mes 7-12: GPU (opcional, largo plazo)
- ✅ Mes 7-8: CUDA.jl setup + kernels básicos
- ✅ Mes 9-10: Integrar con pipeline
- ✅ Mes 11-12: Optimización y profiling
- **Resultado:** ~50-500x speedup para N>>1000

---

## Priorización por Caso de Uso

### Caso A: N=50-200, precisión alta, curvas 2D
**Prioridad:**
1. 🔴 Fase 4.4: Projection methods (mejor conservación)
2. 🟡 Fase 1: Micro-optimizaciones
3. 🟡 Fase 2: Spatial hashing (preparar para escalar)

### Caso B: N=200-1000, precisión media, curvas 2D
**Prioridad:**
1. 🔴 Fase 2: Spatial hashing (crítico)
2. 🟡 Fase 1: Micro-optimizaciones
3. 🔵 Fase 4.2: DoubleFloats (si necesitas precisión)

### Caso C: N>1000, precisión media, curvas 2D/3D
**Prioridad:**
1. 🔴 Fase 2: Spatial hashing
2. 🔴 Fase 3: Generalización 3D
3. 🟡 Fase 5: GPU (largo plazo)

### Caso D: Generalización 3D es prioridad
**Prioridad:**
1. 🔴 Fase 3: Abstracción Manifold
2. 🟡 Fase 1: Micro-optimizaciones
3. 🟡 Fase 2: Spatial hashing (adaptado a 3D)

---

## Siguiente Paso Recomendado

Dado tus objetivos (precisión + escalabilidad + 3D), propongo:

**Opción 1: Empezar con fundamentos (conservador)**
1. Implementar Fase 1 (1-2 semanas)
2. Implementar Fase 4.4 (projection methods, 1 semana)
3. Benchmarks para validar mejoras
4. Decidir: ¿Spatial Hash o 3D primero?

**Opción 2: Ir directo a 3D (ambicioso)**
1. Implementar Fase 3.1-3.2 (abstracción, 2-3 semanas)
2. Implementar ejemplo hélice (1 semana)
3. Implementar Fase 1 en paralelo
4. Spatial hashing adaptado a 3D después

**Opción 3: Maximizar velocidad primero (pragmático)**
1. Implementar Fase 2 (Spatial Hash, 2-3 semanas)
2. Benchmarks N=100-1000
3. Fase 3 (3D) después con infraestructura rápida
4. Proyección de conservación al final

---

## ¿Qué prefieres?

**A)** Opción 1 (fundamentos + conservación)
**B)** Opción 2 (generalización 3D primero)
**C)** Opción 3 (velocidad primero, 3D después)
**D)** Otra combinación personalizada

Basado en tu elección, podemos empezar a implementar el primer paso ahora mismo.
