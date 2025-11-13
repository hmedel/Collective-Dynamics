# Guía Paso a Paso: Probando la Paralelización

Esta guía te ayuda a probar la implementación paralela paso a paso para ir calibrando.

---

## Estado Actual

✅ **Fase 1 completada**: Detección de colisiones paralela

Hemos implementado:
- `find_next_collision_parallel`: Versión paralela del cuello de botella principal (O(N²))
- Tests de correctitud
- Benchmarks de performance

**Pendiente** (implementaremos después de que pruebes esto):
- Integración paralela
- Conservación paralela
- Versión completa `simulate_ellipse_adaptive_parallel`

---

## Paso 1: Verificar Threads Disponibles

```bash
# Ver cuántos hilos tiene Julia disponibles
julia --project=. -e 'println("Threads: ", Threads.nthreads())'

# Si muestra "1", necesitas ejecutar con -t
julia -t 24 --project=. -e 'println("Threads: ", Threads.nthreads())'
```

**Esperado**: Debería mostrar `Threads: 24`

---

## Paso 2: Test de Correctitud

Este test verifica que la versión paralela da **exactamente** los mismos resultados que la secuencial.

```bash
julia -t 24 --project=. test_parallel_correctness.jl
```

### ¿Qué hace el test?

1. **Test 1**: Verifica conversión de índices lineales a pares (i,j)
2. **Test 2**: Compara resultados secuencial vs paralelo para N=10,20,30,40,50
3. **Test 3**: Verifica determinismo (múltiples ejecuciones dan mismo resultado)
4. **Test 4**: Casos extremos (sin colisión, colisión inmediata)

### Salida esperada:

```
================================================================================
TEST DE CORRECTITUD: DETECCIÓN DE COLISIONES PARALELA
================================================================================

Threads disponibles: 24

Test 1: Conversión índice lineal ↔ par
--------------------------------------------------------------------------------
  ✅ N=5: Conversión correcta para todos los 10 pares
  ✅ N=10: Conversión correcta para todos los 45 pares
  ✅ N=20: Conversión correcta para todos los 190 pares
  ✅ N=30: Conversión correcta para todos los 435 pares
  ✅ N=50: Conversión correcta para todos los 1225 pares

✅ Test 1 PASADO: Conversión funciona correctamente

Test 2: Correctitud vs versión secuencial
--------------------------------------------------------------------------------
  ✅ N=10: Secuencial y paralela coinciden
       dt=9.876543e-06, par=(3, 7), found=true
  ✅ N=20: Secuencial y paralela coinciden
       dt=5.432109e-06, par=(8, 15), found=true
  ...

✅ Test 2 PASADO: Resultados idénticos entre secuencial y paralela

Test 3: Determinismo (múltiples ejecuciones)
--------------------------------------------------------------------------------
  ✅ N=20: 5 ejecuciones idénticas (determinista)
  ✅ N=30: 5 ejecuciones idénticas (determinista)
  ✅ N=40: 5 ejecuciones idénticas (determinista)

✅ Test 3 PASADO: Resultados deterministas

Test 4: Casos extremos
--------------------------------------------------------------------------------
  ✅ Sin colisión: Secuencial y paralela coinciden
  ✅ Colisión inmediata: Secuencial y paralela coinciden

✅ Test 4 PASADO: Casos extremos OK

================================================================================
✅ TODOS LOS TESTS PASARON
================================================================================

La versión paralela produce resultados idénticos a la secuencial.
```

### Si algo falla:

- **Test 1 falla**: Problema en conversión de índices → bug en `linear_to_pair`
- **Test 2 falla**: Resultados diferentes → posible race condition
- **Test 3 falla**: No determinista → ¡race condition confirmado!
- **Test 4 falla**: Casos extremos no manejados correctamente

---

## Paso 3: Benchmark de Performance

Este benchmark mide el speedup real con tus 24 hilos.

```bash
julia -t 24 --project=. benchmark_parallel.jl
```

### ¿Qué hace el benchmark?

1. Prueba con N=10,20,30,50,100 partículas
2. Cada tamaño: 10 ejecuciones (después de warmup)
3. Calcula tiempo promedio, speedup, y eficiencia
4. Genera tabla comparativa y proyección para simulación completa

### Salida esperada:

```
================================================================================
BENCHMARK: DETECCIÓN DE COLISIONES PARALELA
================================================================================

Threads disponibles: 24

N = 10 partículas (45 pares)
--------------------------------------------------------------------------------
  Secuencial:   0.125 ± 0.008 ms
  Paralela:     0.230 ± 0.015 ms

  Speedup:      0.54x   ← Overhead domina para N pequeño
  Eficiencia:   2.3% (24 threads)

N = 30 partículas (435 pares)
--------------------------------------------------------------------------------
  Secuencial:   2.150 ± 0.050 ms
  Paralela:     0.180 ± 0.012 ms

  Speedup:      11.94x  ← Excelente!
  Eficiencia:   49.8% (24 threads)

N = 50 partículas (1225 pares)
--------------------------------------------------------------------------------
  Secuencial:   6.800 ± 0.120 ms
  Paralela:     0.450 ± 0.025 ms

  Speedup:      15.11x  ← Aún mejor!
  Eficiencia:   63.0% (24 threads)

N = 100 partículas (4950 pares)
--------------------------------------------------------------------------------
  Secuencial:   28.500 ± 0.800 ms
  Paralela:     1.650 ± 0.080 ms

  Speedup:      17.27x  ← Casi lineal!
  Eficiencia:   71.9% (24 threads)

================================================================================
RESUMEN DE RESULTADOS
================================================================================

|  N   | Pares | Secuencial (ms) | Paralela (ms) | Speedup | Eficiencia |
|------|-------|-----------------|---------------|---------|------------|
|   10 |    45 |           0.125 |         0.230 |   0.54x |       2.3% |
|   20 |   190 |           0.850 |         0.120 |   7.08x |      29.5% |
|   30 |   435 |           2.150 |         0.180 |  11.94x |      49.8% |
|   50 |  1225 |           6.800 |         0.450 |  15.11x |      63.0% |
|  100 |  4950 |          28.500 |         1.650 |  17.27x |      71.9% |

ANÁLISIS:

✅ Mejor speedup: 17.27x con N=100

✅ Speedup saludable: 71.9% de eficiencia teórica máxima

PROYECCIÓN PARA SIMULACIÓN COMPLETA:

Para N=30, 10M pasos (dt_max=1e-6, 10s físicos):
  Tiempo secuencial:  6.0 horas
  Tiempo paralelo:    0.5 horas
  Ahorro:             5.5 horas

================================================================================
BENCHMARK COMPLETADO
================================================================================

Resultados guardados en: benchmark_results_24threads.csv
```

### Interpretación de resultados:

**Speedup < 1x para N pequeño**:
- Normal. El overhead de crear threads es mayor que el beneficio
- La versión paralela detecta esto y usa secuencial automáticamente

**Speedup ~10-15x para N=30-50**:
- ✅ Excelente. Significa que estás aprovechando bien los 24 hilos
- Eficiencia 50-70% es muy buena para paralelización real

**Speedup ~20x sería perfecto** (pero difícil):
- Requeriría 100% de eficiencia (imposible por Amdahl's law)
- Overhead, sincronización, y false sharing reducen eficiencia

**Si tu speedup es < 5x**:
- Verificar que Julia usó los 24 threads
- Puede ser overhead de compilación (ejecutar varias veces)
- Probar con N mayor (≥100)

---

## Paso 4: Comparar con 1 Thread (Baseline)

Para verificar el speedup, ejecuta el mismo benchmark con 1 thread:

```bash
julia -t 1 --project=. benchmark_parallel.jl
```

Esto debe dar speedup ~1x (sin paralelización). Confirma que:
1. La versión paralela usa automáticamente secuencial para N pequeño
2. No hay overhead cuando no hay threads disponibles

---

## Paso 5: Probar con Diferentes Números de Threads

Experimenta con diferentes números de hilos para ver cómo escala:

```bash
# 4 hilos
julia -t 4 --project=. benchmark_parallel.jl

# 8 hilos
julia -t 8 --project=. benchmark_parallel.jl

# 16 hilos
julia -t 16 --project=. benchmark_parallel.jl

# 24 hilos (todos)
julia -t 24 --project=. benchmark_parallel.jl
```

Esto genera archivos:
- `benchmark_results_4threads.csv`
- `benchmark_results_8threads.csv`
- `benchmark_results_16threads.csv`
- `benchmark_results_24threads.csv`

Puedes graficar speedup vs threads para ver la curva de escalabilidad.

---

## Paso 6: Calibración Basada en Resultados

### Si el speedup es bueno (≥10x para N=30):

✅ **Estamos listos para continuar**

Próximo paso: Implementar integración paralela y versión completa.

### Si el speedup es bajo (<5x para N=30):

Posibles problemas y soluciones:

**1. Overhead de threads domina**
```bash
# Probar con N mayor
# Modificar benchmark_parallel.jl línea: test_sizes = [50, 100, 200]
julia -t 24 --project=. benchmark_parallel.jl
```

**2. False sharing o contención de caché**
```julia
# En collision_detection_parallel.jl, añadir padding:
# Cambiar: t_mins = fill(max_time, n_threads)
# Por: t_mins = [fill(max_time, 64 ÷ sizeof(T))  # 64 = cache line size
              for _ in 1:n_threads]
```

**3. Load imbalance (algunos threads terminan antes)**
```bash
# Probar versión dinámica
# En test, reemplazar find_next_collision_parallel
# por find_next_collision_parallel_dynamic
```

---

## Paso 7: Reportar Resultados

Por favor comparte:

1. **Output del test de correctitud**
   - ¿Todos los tests pasaron?
   - ¿Algún warning o error?

2. **Output del benchmark**
   - Speedup para N=30, N=50, N=100
   - Eficiencia obtenida

3. **Archivo CSV generado**
   - `benchmark_results_24threads.csv`

Con esta información podemos:
- Confirmar que funciona correctamente
- Calibrar parámetros si es necesario
- Continuar con la implementación completa

---

## Siguientes Pasos (después de confirmar Fase 1)

### Fase 2: Integración Paralela

Paralelizar el loop de integración de partículas:

```julia
# Secuencial (actual)
for i in 1:length(particles)
    p = particles[i]
    θ_new, θ_dot_new = forest_ruth_step_ellipse(p.θ, p.θ_dot, dt, a, b)
    particles[i] = update_particle(p, θ_new, θ_dot_new, a, b)
end

# Paralelo (a implementar)
@threads for i in 1:length(particles)
    p = particles[i]
    θ_new, θ_dot_new = forest_ruth_step_ellipse(p.θ, p.θ_dot, dt, a, b)
    particles[i] = update_particle(p, θ_new, θ_dot_new, a, b)
end
```

Speedup esperado: ~10-15x adicional

### Fase 3: Versión Completa

Crear `simulate_ellipse_adaptive_parallel` que combine:
- Detección de colisiones paralela ✅
- Integración paralela (Fase 2)
- Conservación paralela (Fase 2)

### Fase 4: Optimizaciones

- SIMD dentro de cada thread
- Reducir allocations
- Tuning de scheduling

---

## Preguntas Frecuentes

**P: ¿Por qué speedup < 24x si tengo 24 hilos?**

R: Por Amdahl's Law. No todo se puede paralelizar:
- Reducción final: secuencial
- Overhead de threads
- Contención de memoria/caché
- Resolución de colisiones: secuencial (una a la vez)

Speedup realista: 10-17x es excelente.

**P: ¿Funciona en cualquier sistema?**

R: Sí, siempre que:
- Julia ≥ 1.6 (threads estables)
- CPU con múltiples cores
- Ejecutas con `julia -t N`

**P: ¿Puedo usar menos de 24 threads?**

R: Sí. El código se adapta automáticamente a `Threads.nthreads()`.

**P: ¿Hay riesgo de race conditions?**

R: No. Usamos thread-local storage → cada thread escribe en su propia memoria.

**P: ¿Qué pasa si ejecuto con -t 1?**

R: La versión paralela detecta N pequeño o 1 thread → usa versión secuencial automáticamente.

---

**¿Listo para probar? Ejecuta:**

```bash
# 1. Tests de correctitud
julia -t 24 --project=. test_parallel_correctness.jl

# 2. Benchmark de performance
julia -t 24 --project=. benchmark_parallel.jl

# 3. Reporta los resultados para continuar con Fase 2
```

---

**Última actualización**: 2025-11-13
