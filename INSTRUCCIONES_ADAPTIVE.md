# Instrucciones: Sistema de Tiempos Adaptativos

Este documento explica cómo usar y probar el nuevo sistema de tiempos adaptativos implementado según el artículo.

## 🎯 Mejoras Implementadas

### 1. Forest-Ruth para Transporte Paralelo
**Archivo:** `src/geometry/parallel_transport.jl`

- Reemplazó RK4 con Forest-Ruth de 4to orden
- Usa los mismos coeficientes simplécticos que la integración geodésica
- Garantiza mejor conservación a largo plazo
- Consistencia numérica en todo el sistema

```julia
# Integra: dv/dθ = -Γ(θ) v(θ)
# Usando Forest-Ruth con 4 etapas
v_transported = parallel_transport_velocity(v_old, θ_initial, θ_final, a, b)
```

### 2. Tiempos Adaptativos (Algoritmo del Artículo)
**Archivo:** `src/adaptive_time.jl`

Implementa el algoritmo completo:

1. **Predicción:** Calcula tiempo hasta próxima colisión para cada par
2. **Selección:** Encuentra la colisión más próxima
3. **Ajuste:** Establece `dt = min(t_collision, dt_max)`
4. **Evolución:** Mueve todas las partículas ese `dt`
5. **Colisión:** Resuelve la colisión con transporte paralelo
6. **Iteración:** Repite hasta alcanzar `max_time`

**Características:**
- Vector de tiempos irregular (adaptativo)
- Tolerancia `dt_min` para partículas "pegadas"
- Detección exacta de colisiones
- Evita colisiones múltiples simultáneas

## 📦 Archivos Creados/Modificados

```
Collective-Dynamics/
├── src/
│   ├── adaptive_time.jl              [NUEVO] Predicción de colisiones
│   ├── geometry/parallel_transport.jl [MODIFICADO] Forest-Ruth
│   └── CollectiveDynamics.jl         [MODIFICADO] Nueva función simulate_ellipse_adaptive()
│
├── test_adaptive_time.jl             [NUEVO] Test comparativo
├── ejemplo_adaptativo.jl             [NUEVO] Ejemplo simple
└── INSTRUCCIONES_ADAPTIVE.md         [NUEVO] Este archivo
```

## 🚀 Cómo Ejecutar

### 1. Actualizar el repositorio

```bash
cd ~/Science/CollectiveDynamics/Collective1D/Collective-Dynamics
git pull origin claude/incomplete-task-recovery-011CUq95bFhkWKMNKHXgZaVN
```

### 2. Limpiar cache compilado

```bash
rm -rf ~/.julia/compiled/v1.12/CollectiveDynamics/
```

### 3. Reinstalar dependencias

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

### 4. Ejecutar tests

#### Test Comparativo (Fijo vs Adaptativo)
```bash
julia --project=. test_adaptive_time.jl
```

**Espera ver:**
- Comparación de conservación de energía
- Número de colisiones detectadas
- Distribución de pasos de tiempo
- Análisis de eficiencia

#### Ejemplo Simple
```bash
julia --project=. ejemplo_adaptativo.jl
```

**Espera ver:**
- Simulación de 10 partículas
- Análisis de conservación
- Estadísticas de dt
- Conclusiones sobre el método

#### Test de Colisión Garantizada (con Forest-Ruth)
```bash
julia --project=. test_collision_guaranteed.jl
```

**Espera ver:**
- Conservación < 1e-6 (excelente)
- Ahora usa Forest-Ruth para transporte paralelo

#### Suite de Tests Completa
```bash
julia --project=. test/runtests.jl
```

**Espera ver:**
- 82 tests pasando
- Tolerancias ajustadas para Forest-Ruth

## 💻 Uso Programático

### Simulación con Tiempos Adaptativos

```julia
using CollectiveDynamics

# Parámetros
a, b = 2.0, 1.0
particles = generate_random_particles(40, 1.0, 0.05, a, b)

# Simulación adaptativa (NUEVO!)
data = simulate_ellipse_adaptive(
    particles, a, b;
    max_time = 1.0,           # Tiempo total de simulación
    dt_max = 1e-5,            # Paso de tiempo máximo
    dt_min = 1e-10,           # Paso de tiempo mínimo (stuck particles)
    save_interval = 0.01,     # Guardar estado cada 0.01 unidades
    collision_method = :parallel_transport,
    tolerance = 1e-6,
    verbose = true
)

# Análisis
E_analysis = analyze_energy_conservation(data.conservation)
println("Error energía: ", E_analysis.max_rel_error)

# Estadísticas de dt
dt_history = data.parameters[:dt_history]
println("dt promedio: ", mean(dt_history))
println("dt mínimo: ", minimum(dt_history))
println("dt máximo: ", maximum(dt_history))
```

### Comparación: Fijo vs Adaptativo

```julia
# Método 1: dt FIJO (tradicional)
data_fixed = simulate_ellipse(
    particles, a, b;
    n_steps = 1000,
    dt = 1e-5,
    collision_method = :parallel_transport
)

# Método 2: dt ADAPTATIVO (artículo)
data_adaptive = simulate_ellipse_adaptive(
    particles, a, b;
    max_time = 1000 * 1e-5,  # Mismo tiempo total
    dt_max = 1e-5,
    collision_method = :parallel_transport
)

# Comparar
println("Colisiones detectadas:")
println("  Fijo:       ", sum(data_fixed.n_collisions))
println("  Adaptativo: ", sum(data_adaptive.n_collisions))

println("Error de energía:")
println("  Fijo:       ", analyze_energy_conservation(data_fixed.conservation).max_rel_error)
println("  Adaptativo: ", analyze_energy_conservation(data_adaptive.conservation).max_rel_error)
```

## 🔍 Funciones Nuevas

### `time_to_collision(p1, p2, a, b)`
Predice cuándo dos partículas colisionarán.

```julia
p1 = particles[1]
p2 = particles[2]
t_collision = time_to_collision(p1, p2, a, b; max_time=1e-4)

if isfinite(t_collision)
    println("Colisión en t = ", t_collision)
else
    println("No colisionan en el intervalo")
end
```

### `find_next_collision(particles, a, b)`
Encuentra la próxima colisión en todo el sistema.

```julia
collision_info = find_next_collision(
    particles, a, b;
    max_time = 1e-5,
    min_dt = 1e-10
)

if collision_info.found
    i, j = collision_info.pair
    println("Próxima colisión: partículas ", i, " y ", j)
    println("Tiempo: ", collision_info.dt)
else
    println("No hay colisiones en el intervalo")
end
```

### `simulate_ellipse_adaptive(particles, a, b; ...)`
Simulación con tiempos adaptativos (algoritmo del artículo).

Ver ejemplo completo arriba.

## 📊 Resultados Esperados

### Conservación de Energía

| Método | Error típico | Observaciones |
|--------|-------------|---------------|
| **dt fijo** | ~15% | Puede perder colisiones o tener múltiples simultáneas |
| **dt adaptativo** | ~1-10% | Detección exacta, sin colisiones simultáneas |
| **2 partículas (test)** | < 1e-6 | Perfecto con Forest-Ruth |

### Eficiencia Computacional

- **dt fijo:** O(n) por paso, pasos fijos
- **dt adaptativo:** O(n²) por paso (búsqueda de colisiones), pasos variables

**Recomendación:**
- **Pocas partículas (n < 50):** Usar adaptativo (mejor precisión)
- **Muchas partículas (n > 100):** Usar fijo o implementar spatial hashing

## 🎓 Teoría: ¿Por qué Forest-Ruth?

El transporte paralelo resuelve:

```
dv/dθ = -Γ(θ) v(θ)
```

**Antes (RK4):**
- Método de Runge-Kutta de 4to orden
- NO es simpléctico
- Puede acumular error de energía a largo plazo

**Ahora (Forest-Ruth):**
- Integrador simpléctico de 4to orden
- Preserva estructura del espacio de fases
- Consistente con integración geodésica
- Mejor conservación a largo plazo

**Coeficientes (mismos que geodésicas):**
```
γ₁ = γ₄ = 1 / (2(2 - 2^{1/3}))
γ₂ = γ₃ = (1 - 2^{1/3}) / (2(2 - 2^{1/3}))
```

## 📝 Notas Importantes

### Partículas "Pegadas"
Si dos partículas quedan muy juntas, `time_to_collision → 0`, lo que causa:
- Pasos de tiempo infinitesimales
- Loop infinito
- Simulación detenida

**Solución implementada:**
- Parámetro `dt_min` (default: 1e-10)
- Si `t_collision < dt_min`, usar `dt = dt_min`
- Permite que partículas se separen eventualmente

### Vector de Tiempos Irregular
A diferencia de `simulate_ellipse` (tiempos uniformes), `simulate_ellipse_adaptive` genera:

```julia
times = [0.0, 1.2e-6, 3.7e-6, 4.1e-6, ...]  # Irregular!
```

Esto es **correcto** y esperado. Refleja la naturaleza adaptativa del algoritmo.

### Guardar Resultados
Para guardar estados intermedios, usa `save_interval` en lugar de `save_every`:

```julia
# dt fijo: guardar cada N pasos
simulate_ellipse(..., save_every=10)

# dt adaptativo: guardar cada T unidades de tiempo
simulate_ellipse_adaptive(..., save_interval=0.01)
```

## 🐛 Solución de Problemas

### Error: "No method matching time_to_collision"
```bash
# Limpiar cache y reinstalar
rm -rf ~/.julia/compiled/v1.12/CollectiveDynamics/
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

### Simulación muy lenta
El método adaptativo es O(n²) por paso. Para muchas partículas:
- Usa `simulate_ellipse` (dt fijo) en su lugar
- O implementa spatial hashing (TODO futuro)

### Error: "reached step limit (1M)"
La simulación no converge. Posibles causas:
- `dt_min` muy pequeño
- Partículas realmente pegadas
- Aumenta `dt_min` a 1e-8 o 1e-7

## 📚 Referencias

- **Artículo:** "Collision Dynamics on Curved Manifolds"
- **Forest-Ruth:** Forest & Ruth (1990), DOI: 10.1016/0167-2789(90)90019-L
- **Código:** `src/adaptive_time.jl`, `src/geometry/parallel_transport.jl`

## ✅ Checklist de Verificación

Después de correr los tests, deberías ver:

- [ ] `test_adaptive_time.jl`: Comparación exitosa, mejor conservación con adaptativo
- [ ] `ejemplo_adaptativo.jl`: Simulación completa con análisis
- [ ] `test_collision_guaranteed.jl`: Error < 1e-6 con Forest-Ruth
- [ ] `test/runtests.jl`: 82/82 tests pasando

Si todos pasan, ¡el sistema está funcionando correctamente! 🎉

## 🔄 Próximos Pasos (Opcional)

Para mejorar aún más:

1. **Spatial Hashing:** Reducir búsqueda de colisiones de O(n²) a O(n)
2. **Paralelización:** Usar `Threads.@threads` para búsqueda de colisiones
3. **GPU:** Implementar `time_to_collision` en CUDA.jl
4. **Visualización:** Crear animación mostrando dt adaptativo en tiempo real

---

**Fecha:** 2025-11-06
**Autor:** Claude (implementación basada en especificaciones del usuario)
**Commits:** `8b3a3a0` (Forest-Ruth + Adaptive), `4c91e27` (RK4), `fd9b1c6` (Tests)
