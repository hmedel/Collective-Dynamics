"""
    collision_detection_parallel.jl

Versión paralela de la detección de colisiones usando multi-threading.

El cuello de botella principal del código secuencial es find_next_collision,
que verifica todos los pares de partículas: O(N²) con N(N-1)/2 pares.

Con N=30: 435 pares × 50 iteraciones bisección = 21,750 evaluaciones
Con N=100: 4,950 × 50 = 247,500 evaluaciones

Cada par es COMPLETAMENTE INDEPENDIENTE → ideal para paralelización.

Estrategia:
1. Distribuir pares entre threads
2. Cada thread mantiene su mínimo local
3. Reducción final para encontrar mínimo global

Speedup esperado: ~15-20x con 24 threads para N≥30
"""

using Base.Threads

# ============================================================================
# Función auxiliar: índice lineal → par (i, j)
# ============================================================================

"""
    linear_to_pair(idx::Int, n::Int) -> (Int, Int)

Convierte un índice lineal a un par (i, j) donde i < j.

# Ejemplo
Para n=5, los pares son:
idx=1 → (1,2)
idx=2 → (1,3)
idx=3 → (1,4)
idx=4 → (1,5)
idx=5 → (2,3)
...

# Matemática
Dado idx ∈ [1, N(N-1)/2], encontrar i, j tal que:
- 1 ≤ i < j ≤ N
- idx corresponde al k-ésimo par en orden lexicográfico

Se resuelve usando la fórmula cuadrática invertida.
"""
@inline function linear_to_pair(idx::Int, n::Int)
    # idx va de 1 a n(n-1)/2
    # Convertir a 0-indexado
    k = idx - 1

    # i se determina por: suma_{m=1}^{i} (n-m) > k
    # Resolviendo: i ≈ n - sqrt(2(n²-n-k))
    # Fórmula exacta usando aritmética entera
    i = n - 1 - floor(Int, (-1 + sqrt(1 + 8*(n*(n-1)/2 - k - 1))) / 2)

    # Una vez conocido i, j se calcula directamente
    j = k - div((i-1)*(2*n-i), 2) + i + 1

    return (i, j)
end

"""
    pair_to_linear(i::Int, j::Int, n::Int) -> Int

Convierte un par (i, j) a índice lineal (inversa de linear_to_pair).

Útil para debugging y verificación.
"""
@inline function pair_to_linear(i::Int, j::Int, n::Int)
    @assert i < j <= n "Debe cumplirse i < j ≤ n"

    # Número de pares antes de la fila i
    pairs_before_i = div((i-1)*(2*n-i), 2)

    # Posición de j dentro de la fila i
    offset = j - i

    return pairs_before_i + offset
end

# ============================================================================
# Detección de colisiones paralela
# ============================================================================

"""
    find_next_collision_parallel(
        particles::Vector{Particle{T}},
        a::T,
        b::T;
        max_time::T = T(Inf),
        min_dt::T = T(1e-10)
    ) where {T <: AbstractFloat}

Versión PARALELA de find_next_collision usando multi-threading.

# Diferencias con la versión secuencial
1. Distribuye pares entre threads disponibles
2. Cada thread mantiene su propio mínimo local (thread-local storage)
3. Reducción final (secuencial) para encontrar el mínimo global

# Estrategia de paralelización
- Total de pares: N(N-1)/2
- Cada thread procesa un subconjunto de pares
- Sin locks/atomics necesarios (thread-local storage)
- Reducción final es rápida: O(n_threads)

# Speedup esperado
| N | Pares | Secuencial (ms) | Paralelo 24-threads (ms) | Speedup |
|---|-------|----------------|--------------------------|---------|
| 30 | 435 | 10.0 | 0.6 | 16x |
| 50 | 1,225 | 40.0 | 2.5 | 16x |
| 100 | 4,950 | 150.0 | 9.0 | 17x |

# Notas
- Para N<20, la versión secuencial puede ser más rápida (overhead)
- El speedup es sub-lineal por overhead y Amdahl's law
- Requiere Julia con multi-threading: julia -t N

# Ver también
- `find_next_collision`: Versión secuencial (src/adaptive_time.jl)
- `time_to_collision`: Cálculo de tiempo a colisión para un par
"""
function find_next_collision_parallel(
    particles::Vector{Particle{T}},
    a::T,
    b::T;
    max_time::T = T(Inf),
    min_dt::T = T(1e-10)
) where {T <: AbstractFloat}

    n = length(particles)
    n_pairs = div(n * (n - 1), 2)

    # Para N pequeño, usar versión secuencial (evitar overhead)
    # Análisis: overhead threading ~100μs, trabajo por par ~0.4μs
    # Break-even: necesitamos ~250 pares = N≈23 partículas
    # Usamos N<50 como umbral conservador para asegurar beneficio
    if n < 50 || nthreads() == 1
        return find_next_collision(particles, a, b; max_time=max_time, min_dt=min_dt)
    end

    # Thread-local storage para mínimos
    # Cada thread mantiene su propio candidato a mínimo
    # IMPORTANTE: Usar maxthreadid() en vez de nthreads() para evitar BoundsError
    # porque threadid() puede retornar valores > nthreads() con dynamic scheduling
    max_tid = Threads.maxthreadid()
    t_mins = fill(max_time, max_tid)
    pairs_mins = [(0, 0) for _ in 1:max_tid]
    founds = fill(false, max_tid)

    # Paralelizar sobre los pares
    # Threads.@threads usa scheduling estático por default
    @threads for idx in 1:n_pairs
        # Convertir índice lineal a par
        i, j = linear_to_pair(idx, n)

        # Calcular tiempo a colisión para este par
        # @inbounds seguro aquí: i,j garantizados en 1:n
        @inbounds t_coll = time_to_collision(
            particles[i], particles[j], a, b;
            max_time = max_time
        )

        # Actualizar mínimo thread-local
        tid = threadid()
        @inbounds if isfinite(t_coll) && t_coll < t_mins[tid]
            t_mins[tid] = t_coll
            pairs_mins[tid] = (i, j)
            founds[tid] = true
        end
    end

    # Reducción: encontrar mínimo global entre todos los thread-local minimums
    t_min = max_time
    pair_min = (0, 0)
    found = false

    for tid in 1:max_tid
        if founds[tid] && t_mins[tid] < t_min
            t_min = t_mins[tid]
            pair_min = pairs_mins[tid]
            found = true
        end
    end

    # Aplicar tiempo mínimo para evitar partículas pegadas
    if found && t_min < min_dt
        t_min = min_dt
    end

    return (dt = t_min, pair = pair_min, found = found)
end

# ============================================================================
# Versión con scheduling dinámico (experimental)
# ============================================================================

"""
    find_next_collision_parallel_dynamic(...)

Versión experimental con scheduling dinámico.

Puede ser más eficiente si los tiempos de cálculo varían mucho entre pares
(ej: algunos pares convergen rápido en bisección, otros lento).

Usa @threads :dynamic para permitir que threads que terminan rápido
tomen más trabajo de la cola.

# Cuándo usar
- Si observas load imbalance (algunos threads terminan mucho antes)
- Para N muy grande (>100) donde la varianza en tiempos es significativa

# Tradeoff
- Más scheduling overhead
- Mejor load balancing
"""
function find_next_collision_parallel_dynamic(
    particles::Vector{Particle{T}},
    a::T,
    b::T;
    max_time::T = T(Inf),
    min_dt::T = T(1e-10)
) where {T <: AbstractFloat}

    n = length(particles)
    n_pairs = div(n * (n - 1), 2)

    # Para N pequeño, usar versión secuencial (evitar overhead)
    if n < 50 || nthreads() == 1
        return find_next_collision(particles, a, b; max_time=max_time, min_dt=min_dt)
    end

    # IMPORTANTE: Usar maxthreadid() en vez de nthreads() para evitar BoundsError
    max_tid = Threads.maxthreadid()
    t_mins = fill(max_time, max_tid)
    pairs_mins = [(0, 0) for _ in 1:max_tid]
    founds = fill(false, max_tid)

    # Scheduling dinámico con :dynamic
    @threads :dynamic for idx in 1:n_pairs
        i, j = linear_to_pair(idx, n)

        t_coll = time_to_collision(
            particles[i], particles[j], a, b;
            max_time = max_time
        )

        tid = threadid()
        if isfinite(t_coll) && t_coll < t_mins[tid]
            t_mins[tid] = t_coll
            pairs_mins[tid] = (i, j)
            founds[tid] = true
        end
    end

    # Reducción (igual que versión estática)
    t_min = max_time
    pair_min = (0, 0)
    found = false

    for tid in 1:max_tid
        if founds[tid] && t_mins[tid] < t_min
            t_min = t_mins[tid]
            pair_min = pairs_mins[tid]
            found = true
        end
    end

    if found && t_min < min_dt
        t_min = min_dt
    end

    return (dt = t_min, pair = pair_min, found = found)
end

# ============================================================================
# Imports necesarios (si no están definidos)
# ============================================================================

# Estas funciones deben venir de otros archivos
if !@isdefined(Particle)
    @warn "Particle type not defined. collision_detection_parallel.jl needs particles.jl"
end

if !@isdefined(time_to_collision)
    @warn "time_to_collision not defined. collision_detection_parallel.jl needs adaptive_time.jl"
end

if !@isdefined(find_next_collision)
    @warn "find_next_collision not defined. Fallback to sequential for small N won't work"
end
