# Análisis de Paralelización para Collective Dynamics

## Resumen Ejecutivo

El código tiene **3 cuellos de botella principales** que son ideales para paralelización con 24 hilos:

1. **Detección de colisiones** (`find_next_collision`): O(N²) - 435 pares con N=30
2. **Integración de partículas** (`forest_ruth_step`): O(N) - N operaciones independientes
3. **Cálculos de conservación** (`record_conservation`): O(N) - sumas paralelas

**Speedup esperado**: ~10-15x con 24 hilos para N≥30 partículas

---

## Análisis Detallado

### 1. Detección de Colisiones (Mayor Cuello de Botella)

**Código actual:**
```julia
# src/adaptive_time.jl líneas 234-244
@inbounds for i in 1:n
    for j in (i+1):n
        t_coll = time_to_collision(particles[i], particles[j], a, b; max_time=max_time)
        if isfinite(t_coll) && t_coll < t_min
            t_min = t_coll
            pair_min = (i, j)
            found = true
        end
    end
end
```

**Problema:**
- Loop doble: N(N-1)/2 pares
- Cada `time_to_collision` involucra bisección (50 iteraciones)
- Con N=30: 435 × 50 = 21,750 evaluaciones por paso
- Con N=100: 4,950 × 50 = 247,500 evaluaciones

**Oportunidad:**
- Cada par es **completamente independiente**
- Ideal para paralelización
- Solo necesitamos reducir para encontrar el mínimo

**Speedup esperado**: ~20x con 24 hilos

### 2. Integración de Partículas

**Código actual:**
```julia
# src/CollectiveDynamics.jl líneas 465-469
for i in 1:length(particles)
    p = particles[i]
    θ_new, θ_dot_new = forest_ruth_step_ellipse(p.θ, p.θ_dot, dt, a, b)
    particles[i] = update_particle(p, θ_new, θ_dot_new, a, b)
end
```

**Problema:**
- Loop secuencial sobre N partículas
- Cada evaluación Forest-Ruth: 4 sub-pasos + evaluaciones de Christoffel

**Oportunidad:**
- Cada partícula evoluciona **independientemente**
- No hay dependencias entre iteraciones
- Trivial de paralelizar

**Speedup esperado**: ~15x con 24 hilos (para N≥30)

### 3. Cálculos de Conservación

**Código actual:**
```julia
# Cálculo de energía total
total_energy = sum(kinetic_energy_angular(p, a, b) for p in particles)

# Cálculo de momento conjugado total
total_momentum = sum(conjugate_momentum(p, a, b) for p in particles)
```

**Oportunidad:**
- Operaciones de reducción (sumas)
- Fácil de paralelizar con `ThreadsX.sum` o manual

**Speedup esperado**: ~10x con 24 hilos

---

## Complejidad Computacional

### Por Paso de Tiempo

| Operación | Complejidad | % Tiempo (N=30) | % Tiempo (N=100) | Paralelizable |
|-----------|-------------|----------------|-----------------|---------------|
| `find_next_collision` | O(N²) | ~70% | ~85% | ✅ Sí |
| Forest-Ruth (N partículas) | O(N) | ~25% | ~12% | ✅ Sí |
| Resolver 1 colisión | O(1) | ~3% | ~2% | ❌ No |
| Conservación | O(N) | ~2% | ~1% | ✅ Sí |

**Conclusión**: Con N grande, la detección de colisiones domina completamente.

### Escalabilidad

Con N partículas:
- **Pares a verificar**: N(N-1)/2
- **N=10**: 45 pares
- **N=30**: 435 pares (config actual)
- **N=100**: 4,950 pares
- **N=1000**: 499,500 pares

→ La paralelización se vuelve **crítica** para N≥50

---

## Estrategias de Paralelización

### Opción 1: Threads.@threads (Recomendada)

**Pros:**
- Julia estándar (sin dependencias)
- Bajo overhead
- Control fino

**Cons:**
- Requiere cuidado con race conditions
- Manual para reducciones

**Ejemplo:**
```julia
function find_next_collision_parallel(particles, a, b; kwargs...)
    n = length(particles)

    # Thread-local minimums
    t_mins = fill(Inf, Threads.nthreads())
    pairs = [(0,0) for _ in 1:Threads.nthreads()]

    Threads.@threads for idx in 1:div(n*(n-1), 2)
        # Convertir índice lineal a (i, j)
        i, j = linear_to_pair(idx, n)

        t_coll = time_to_collision(particles[i], particles[j], a, b)

        tid = Threads.threadid()
        if t_coll < t_mins[tid]
            t_mins[tid] = t_coll
            pairs[tid] = (i, j)
        end
    end

    # Reducción final
    t_min = minimum(t_mins)
    idx = findfirst(==(t_min), t_mins)

    return (dt=t_min, pair=pairs[idx], found=isfinite(t_min))
end
```

### Opción 2: ThreadsX.jl

**Pros:**
- Abstracciones de alto nivel
- Reducción automática

**Cons:**
- Dependencia extra
- Menos control

**Ejemplo:**
```julia
using ThreadsX

results = ThreadsX.map(1:n) do i
    map((i+1):n) do j
        t = time_to_collision(particles[i], particles[j], a, b)
        (t=t, pair=(i,j))
    end
end

flat_results = reduce(vcat, results)
best = argmin(r -> r.t, flat_results)
```

### Opción 3: FLoops.jl

**Pros:**
- Backend-agnóstico (Threads, CUDA, etc.)
- Syntax sugar para reducciones

**Cons:**
- Más complejo
- Overhead adicional

---

## Implementación Propuesta

### Fase 1: Versión Paralela Básica

1. **Crear `src/parallel/`** con:
   - `collision_detection_parallel.jl`
   - `integration_parallel.jl`
   - `conservation_parallel.jl`

2. **Añadir `simulate_ellipse_adaptive_parallel`**:
   - Reemplaza `find_next_collision` → `find_next_collision_parallel`
   - Reemplaza loop de integración → `Threads.@threads`
   - Mantiene compatibilidad con versión secuencial

3. **Tests de correctitud**:
   - Verificar resultados idénticos a versión secuencial
   - Verificar conservación no empeora

4. **Benchmarks**:
   - Comparar tiempo secuencial vs paralelo
   - Medir speedup vs número de hilos
   - Identificar overhead para N pequeño

### Fase 2: Optimizaciones

1. **Reducir overhead**:
   - Usar arrays preallocados
   - Minimizar allocations en hot loops

2. **Load balancing**:
   - Scheduling dinámico para pares

3. **SIMD**:
   - Vectorizar operaciones dentro de cada hilo

### Fase 3: GPU (Futuro)

1. **CUDA.jl** para N muy grande (>1000)
2. Kernels para detección de colisiones
3. Integración GPU con CuArrays

---

## Uso Propuesto

### Configuración de Hilos

```bash
# Ejecutar con 24 hilos
julia -t 24 --project=. run_simulation.jl config/ultra_precision.toml

# O con variable de entorno
export JULIA_NUM_THREADS=24
julia --project=. run_simulation.jl config/ultra_precision.toml

# Verificar hilos disponibles
julia> Threads.nthreads()
24
```

### API en Julia

```julia
# Versión secuencial (existente)
data = simulate_ellipse_adaptive(
    particles, a, b;
    max_time=10.0,
    collision_method=:parallel_transport
)

# Versión paralela (nueva)
data = simulate_ellipse_adaptive_parallel(
    particles, a, b;
    max_time=10.0,
    collision_method=:parallel_transport,
    nthreads=24  # Opcional, usa Threads.nthreads() por default
)
```

---

## Riesgos y Mitigación

### Riesgo 1: Race Conditions

**Problema**: Múltiples hilos escribiendo a misma variable

**Mitigación**:
- Thread-local storage para reducciones
- Atomic operations donde necesario
- Tests exhaustivos de correctitud

### Riesgo 2: False Sharing

**Problema**: Múltiples hilos accediendo misma cache line

**Mitigación**:
- Padding en arrays thread-local
- Alignment correcto de estructuras

### Riesgo 3: Overhead para N Pequeño

**Problema**: Paralelización más lenta que secuencial para N<20

**Mitigación**:
- Detección automática: usar versión secuencial si N<threshold
- Threshold configurable por usuario

---

## Benchmarks Estimados

### Hardware: 24 cores/48 threads típico (AMD Threadripper o similar)

| N particles | Secuencial (s/step) | Paralelo 24-threads (s/step) | Speedup |
|-------------|-------------------|----------------------------|---------|
| 10 | 0.001 | 0.002 | 0.5x ❌ |
| 30 | 0.010 | 0.001 | 10x ✅ |
| 50 | 0.040 | 0.003 | 13x ✅ |
| 100 | 0.150 | 0.010 | 15x ✅ |
| 200 | 0.600 | 0.035 | 17x ✅ |
| 500 | 3.800 | 0.200 | 19x ✅ |
| 1000 | 15.000 | 0.750 | 20x ✅ |

**Para simulación completa (10s física, dt_max=1e-6):**
- Steps totales: ~10,000,000
- N=30 secuencial: ~27 horas
- N=30 paralelo (24 threads): ~2.7 horas ⚡
- **Speedup: 10x**

---

## Próximos Pasos

### Implementación Inmediata (1-2 días)

1. ✅ Análisis completado
2. ⏳ Implementar `find_next_collision_parallel`
3. ⏳ Implementar loop de integración paralelo
4. ⏳ Tests de correctitud
5. ⏳ Benchmarks básicos

### Optimización (1 semana)

6. ⏳ Reducir allocations
7. ⏳ Load balancing dinámico
8. ⏳ Documentación completa

### Extensión (futuro)

9. ⏳ Versión GPU con CUDA.jl
10. ⏳ Multi-nodo con MPI (para clusters)

---

## Referencias

- Julia Multithreading: https://docs.julialang.org/en/v1/manual/multi-threading/
- ThreadsX.jl: https://github.com/tkf/ThreadsX.jl
- Parallel Computing Best Practices: https://juliafolds.github.io/data-parallelism/

---

**Última actualización**: 2025-11-13
