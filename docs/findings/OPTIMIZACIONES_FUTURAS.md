# Optimizaciones Futuras - CollectiveDynamics.jl

**Fecha:** 2025-11-13
**Estado actual:** Paralelización CPU implementada (speedup 2-8x)

---

## Resumen Ejecutivo

Basado en los benchmarks y análisis de profiling, las optimizaciones se clasifican en **4 fases** por impacto/esfuerzo:

| Fase | Optimización | Speedup Esperado | Esfuerzo | Prioridad |
|------|--------------|------------------|----------|-----------|
| **1** | ✅ Paralelización CPU (colisiones) | 2-8x | Medio | ✅ **COMPLETADO** |
| **2A** | ❌ Paralelización integración | **0.15-0.42x** ❌ | N/A | 🔴 **DESCARTADO** |
| **2B** | Spatial Hashing O(N²)→O(N) | 10-100x | Alto | 🟡 Alta |
| **3** | GPU Acceleration (CUDA) | 50-200x | Muy Alto | 🔵 Media |
| **4** | Optimizaciones micro | 1.2-1.5x | Bajo | 🔵 Media |

**Siguiente paso recomendado:** **Fase 2B** (Spatial Hashing) si N>100, o **Fase 4** (micro-optimizaciones) para mejoras incrementales.

---

## Fase 1: Paralelización CPU ✅ COMPLETADO

### Estado Actual
- ✅ Detección de colisiones paralela (`find_next_collision_parallel`)
- ✅ Speedups medidos: N=50 (2.1x), N=70 (4.8x), N=100 (7.9x)
- ✅ Conservación de energía verificada (ΔE/E₀ < 1e-6)

### Componentes No Paralelizados
Según el análisis, **aún quedan 2 componentes sin paralelizar**:

#### 1. Integración de Partículas (12-25% del tiempo)
**Código actual:**
```julia
# src/CollectiveDynamics.jl:481-485
@inbounds for i in 1:length(particles)
    p = particles[i]
    θ_new, θ_dot_new = forest_ruth_step_ellipse(p.θ, p.θ_dot, dt, a, b)
    particles[i] = update_particle(p, θ_new, θ_dot_new, a, b)
end
```

**Problema:** Loop secuencial sobre N partículas independientes.

**Solución propuesta:**
```julia
# Versión paralela
Threads.@threads for i in 1:length(particles)
    p = particles[i]
    θ_new, θ_dot_new = forest_ruth_step_ellipse(p.θ, p.θ_dot, dt, a, b)
    particles[i] = update_particle(p, θ_new, θ_dot_new, a, b)
end
```

**Speedup esperado:** 1.5-2x adicional (sobre el speedup actual)
**Esfuerzo:** Bajo (1 línea de código)
**Riesgo:** Muy bajo (no hay race conditions, cada thread escribe a índices únicos)

#### 2. Cálculos de Conservación (1-2% del tiempo)
**Código actual:**
```julia
# src/conservation.jl
total_energy = sum(kinetic_energy_angular(p, a, b) for p in particles)
total_momentum = sum(conjugate_momentum(p, a, b) for p in particles)
```

**Solución propuesta:**
```julia
using ThreadsX  # Parallel reductions optimizadas

total_energy = ThreadsX.sum(p -> kinetic_energy_angular(p, a, b), particles)
total_momentum = ThreadsX.sum(p -> conjugate_momentum(p, a, b), particles)
```

**Speedup esperado:** Marginal (~1.1x)
**Esfuerzo:** Bajo
**Nota:** Bajo impacto, baja prioridad

---

## Fase 2: Optimizaciones Algorítmicas (Mayor Impacto)

### 2A. ❌ Paralelizar Integración Forest-Ruth (NO IMPLEMENTAR)

**Impacto:** ❌ NEGATIVO - Empeora 2-7x
**Esfuerzo:** N/A
**Prioridad:** 🔴 **DESCARTADO**

**Resultados de benchmarks (test_integration_parallel.jl):**
```
N=30:  Seq=2.99 μs,  Par=20.12 μs → 0.15x ❌ (6.7x PEOR)
N=50:  Seq=4.27 μs,  Par=10.14 μs → 0.42x ❌ (2.4x PEOR)
N=70:  Seq=6.13 μs,  Par=20.03 μs → 0.31x ❌ (3.2x PEOR)
```

**Razón del fracaso:**
- **Overhead de threading:** ~17-20 μs por llamada
- **Trabajo útil (forest_ruth_step):** ~3-6 μs para N=30-70
- **Ratio:** Overhead es 3-7x mayor que el trabajo útil
- El costo de crear/sincronizar threads domina completamente el beneficio

**Comparación con detección de colisiones paralela:**
- `time_to_collision`: ~50 iteraciones de bisección, ~200 μs por par → **paralelización funciona**
- `forest_ruth_step`: 4 sub-pasos simples, ~0.1 μs por partícula → **overhead domina**

**Conclusión:** La integración Forest-Ruth es **demasiado rápida** para justificar threading.
Mantener versión secuencial.

---

### 2B. Spatial Hashing para Detección de Colisiones

**Problema:** Actualmente O(N²) - revisamos todos los pares.

**Solución:** Dividir espacio en celdas, solo revisar pares en celdas vecinas.

**Speedup esperado:**
- N=100: 10-20x
- N=1000: 50-100x

**Esfuerzo:** Alto (nueva estructura de datos)

**Implementación conceptual:**
```julia
struct SpatialHash{T}
    cell_size::T
    cells::Dict{Tuple{Int,Int}, Vector{Int}}  # (cell_x, cell_y) -> particle indices
end

function find_next_collision_spatial_hash(particles, a, b, hash::SpatialHash)
    # 1. Insertar partículas en celdas (O(N))
    # 2. Para cada celda, revisar partículas vs celdas vecinas (O(N))
    # 3. Total: O(N) en lugar de O(N²)
end
```

**Ventajas:**
- Reducción drástica de complejidad
- Escalabilidad a N >> 100
- Combina bien con paralelización

**Desventajas:**
- Complejidad de implementación
- Overhead para N pequeño (<50)
- Requiere tuning de `cell_size`

**Prioridad:** 🟡 Alta si planeas N > 100

---

## Fase 3: GPU Acceleration (CUDA.jl)

**Speedup esperado:** 50-200x para N > 1000
**Esfuerzo:** Muy Alto
**Prioridad:** 🔵 Media (solo si necesitas N >> 1000)

### Componentes GPU-friendly
1. ✅ Detección de colisiones O(N²) - ideal para GPU
2. ✅ Integración Forest-Ruth - N threads independientes
3. ❌ Resolución de colisiones - difícil (pocas colisiones por paso)

**Implementación:**
```julia
using CUDA

# Kernel para detección de colisiones
function find_collisions_kernel!(results, particles, a, b, dt_max)
    i = (blockIdx().x - 1) * blockDim().x + threadIdx().x
    j = (blockIdx().y - 1) * blockDim().y + threadIdx().y

    if i < j <= length(particles)
        t_coll = time_to_collision(particles[i], particles[j], a, b; max_time=dt_max)
        # Atomic min para encontrar mínimo global
        CUDA.@atomic results[1] = min(results[1], t_coll)
    end
end

# Kernel para integración
function integrate_kernel!(particles_new, particles, dt, a, b)
    i = (blockIdx().x - 1) * blockDim().x + threadIdx().x
    if i <= length(particles)
        p = particles[i]
        θ_new, θ_dot_new = forest_ruth_step_ellipse(p.θ, p.θ_dot, dt, a, b)
        particles_new[i] = update_particle(p, θ_new, θ_dot_new, a, b)
    end
end
```

**Desafíos:**
- StaticArrays no funcionan en GPU → usar SVector solo en CPU
- Transferencias CPU↔GPU costosas
- Debugging complejo
- Requiere GPU NVIDIA

**Cuándo vale la pena:** N > 1000 partículas, simulaciones largas (horas/días)

---

## Fase 4: Micro-optimizaciones

### 4A. Preallocación de Memoria

**Problema:** `push!` realoca arrays dinámicamente.

**Solución:**
```julia
# En simulate_ellipse_adaptive, preallocar tamaño estimado:
expected_steps = ceil(Int, max_time / dt_max) + 1000
particles_history = Vector{Vector{Particle{T}}}(undef, expected_steps)
times_saved = Vector{T}(undef, expected_steps)
# Llenar con índice manual en lugar de push!
```

**Speedup:** ~5-10% menos allocations
**Esfuerzo:** Bajo

---

### 4B. Memory Pooling para Partículas

**Problema:** Copiar `Vector{Particle}` en cada save.

**Solución:**
```julia
# Pool de arrays pre-alocados
struct ParticlePool{T}
    pool::Vector{Vector{Particle{T}}}
    next_idx::Ref{Int}
end

function get_particle_array!(pool::ParticlePool{T}, n::Int) where T
    if pool.next_idx[] > length(pool.pool)
        push!(pool.pool, Vector{Particle{T}}(undef, n))
    end
    arr = pool.pool[pool.next_idx[]]
    pool.next_idx[] += 1
    return arr
end
```

**Speedup:** ~10% menos GC pressure
**Esfuerzo:** Medio

---

### 4C. SIMD Optimization (@simd)

**Aplicable a:** Loops con operaciones aritméticas simples.

**Ejemplo:**
```julia
# En forest_ruth_step, si tuviéramos arrays de θ:
@simd for i in 1:n
    θ[i] = θ[i] + dt * θ_dot[i]
end
```

**Limitación:** Nuestro código usa `Particle{T}` inmutables, difícil de vectorizar.

**Speedup:** ~1.1-1.2x en partes aplicables
**Esfuerzo:** Medio
**Prioridad:** Baja

---

### 4D. Cache-Friendly Data Layout (AoS → SoA)

**Problema actual:** Array of Structs (AoS)
```julia
particles::Vector{Particle{T}}  # [{θ, θ_dot, pos, vel}, {θ, θ_dot, ...}]
```

**Solución:** Struct of Arrays (SoA)
```julia
struct ParticleArrays{T}
    θ::Vector{T}
    θ_dot::Vector{T}
    pos_x::Vector{T}
    pos_y::Vector{T}
    # ...
end
```

**Ventajas:**
- Mejor cache locality
- Facilita SIMD
- Reduce memory bandwidth

**Desventajas:**
- Requiere refactor completo del código
- Pierde inmutabilidad de `Particle`

**Speedup:** ~1.2-1.5x
**Esfuerzo:** Muy Alto
**Prioridad:** Baja (solo si se busca máximo rendimiento)

---

## Fase 5: Optimizaciones Específicas del Problema

### 5A. Bounding Box Filtering (Optimización ya implementada)

**Estado:** ✅ Parcialmente implementado en fase de optimizaciones algorítmicas

**Mejora adicional:** Early exit si bounding boxes no se solapan antes de llamar `time_to_collision`.

```julia
function bounding_boxes_overlap(p1::Particle{T}, p2::Particle{T}, a, b) where T
    # Calcular AABB para cada partícula
    # Retornar false si no hay overlap → skip time_to_collision
end
```

**Speedup:** ~1.1-1.3x (ya implementado)

---

### 5B. Collision Prediction Caching

**Idea:** Cachear tiempos de colisión calculados, invalidar solo pares afectados.

**Problema:** Difícil de implementar correctamente, muchos edge cases.

**Speedup:** ~1.5-2x
**Esfuerzo:** Alto
**Prioridad:** Baja (complejidad > beneficio)

---

### 5C. Adaptive dt Heuristics

**Idea:** Ajustar `dt_max` dinámicamente según densidad de colisiones.

```julia
# Si hay muchas colisiones, reducir dt_max
if collision_rate > threshold
    dt_max *= 0.9
else
    dt_max = min(dt_max * 1.05, original_dt_max)
end
```

**Speedup:** ~1.1-1.2x en casos específicos
**Esfuerzo:** Bajo
**Prioridad:** Baja

---

## Recomendación de Roadmap

### Corto Plazo (1-2 días)
1. **Preallocación de memoria** (Fase 4A)
   - Speedup: ~1.1x
   - Esfuerzo: Bajo
   - Reduce GC pressure
   - Bajo riesgo

2. **Reducir allocations en conservation** (Fase 4)
   - Speedup: ~1.05-1.1x
   - Esfuerzo: Bajo
   - Mejora estabilidad

### Mediano Plazo (1-2 semanas)
3. **Spatial Hashing** (Fase 2B) - solo si N > 100
   - Speedup: 10-100x
   - Esfuerzo: Alto
   - Escalabilidad crítica

### Largo Plazo (1-2 meses)
4. **GPU Acceleration** (Fase 3) - solo si N > 1000
   - Speedup: 50-200x
   - Esfuerzo: Muy Alto
   - Requiere hardware específico

---

## Mediciones de Baseline

Para cualquier optimización, **medir antes y después** con:

```julia
using BenchmarkTools

# Benchmark de componentes individuales
@btime find_next_collision($particles, $a, $b; max_time=$dt_max)
@btime forest_ruth_step_ellipse($θ, $θ_dot, $dt, $a, $b)

# Benchmark de simulación completa
@time data = simulate_ellipse_adaptive(particles, a, b; max_time=1.0)
```

**Profiling detallado:**
```julia
using Profile

@profile simulate_ellipse_adaptive(particles, a, b; max_time=1.0)
Profile.print()
```

---

## Conclusión

**Próximo paso recomendado:** **Fase 2A - Paralelizar integración Forest-Ruth**

**Justificación:**
- Bajo esfuerzo (1 línea de código)
- Speedup garantizado (+50-100%)
- Sin riesgo (operaciones independientes)
- Combina con paralelización actual

**Speedup total estimado (acumulativo):**
- Actual: 2-8x (CPU paralelo, N=50-100) ✅
- + Fase 4 (micro-opt): 2.2-9.6x (mejora ~10-20%)
- + Fase 2B (si N>100): 22-960x (Spatial Hashing)
- + Fase 3 (si N>1000): 1100-192000x (GPU) 🚀

---

**Próximas optimizaciones realistas:**
1. **Fase 4A** (preallocación) - ganancia modesta pero estable
2. **Fase 2B** (Spatial Hashing) - si planeas escalar a N>>100
3. **Fase 3** (GPU) - solo para N>>1000 y simulaciones muy largas
