# Sistema de Tiempos Adaptativos - Referencia Rápida

**Estado:** ✅ COMPLETO Y VERIFICADO
**Fecha:** 2025-11-06

---

## 🚀 Uso Básico

```julia
using CollectiveDynamics

# Generar partículas
particles = generate_random_particles(10, 1.0, 0.05, 2.0, 1.0)

# Simular con tiempos adaptativos
data = simulate_ellipse_adaptive(
    particles, 2.0, 1.0;
    max_time = 1.0,
    dt_max = 1e-5,
    dt_min = 1e-10,
    collision_method = :parallel_transport
)

# Analizar
E = analyze_energy_conservation(data.conservation)
println("Error: ", E.max_rel_error)  # Esperado: < 1e-6
```

---

## 📊 Tests Disponibles

```bash
# Test 1: Conservación perfecta
julia --project=. test_collision_guaranteed.jl

# Test 2: Sistema adaptativo (5 partículas)
julia --project=. test_adaptive_improved.jl

# Test 3: Ejemplo completo
julia --project=. ejemplo_adaptativo.jl
```

**Esperado:** Error < 1e-6 en todos ✅

---

## 🔧 Métodos Numéricos Usados

| Componente | Método | Por Qué |
|------------|--------|---------|
| **Geodésicas** | Forest-Ruth | Hamiltoniano separable |
| **Transporte Paralelo** | RK4 | EDO escalar 1er orden |
| **Colisiones** | Bisección | Raíz de d(t) = r_sum |

---

## ⚙️ Parámetros Importantes

```julia
# Rango de velocidades (DEFAULT = (-1.0, 1.0))
particles = generate_random_particles(
    10, 1.0, 0.05, 2.0, 1.0;
    θ_dot_range = (-1.0, 1.0)  # ✅ Realista
)

# Parámetros de simulación
dt_max = 1e-5   # Paso máximo
dt_min = 1e-10  # Paso mínimo (partículas pegadas)
```

**⚠️ NO usar velocidades > 100:** Causa inestabilidad numérica

---

## ✅ Cuándo Usar Sistema Adaptativo

**✅ SÍ - Ideal para:**
- Pocas partículas (n < 50)
- Colisiones ocasionales
- Alta precisión necesaria
- Análisis de eventos discretos

**❌ NO - Usar dt fijo:**
- Muchas partículas (n > 100)
- Sistema muy denso
- Velocidad > precisión
- Monte Carlo

---

## 🐛 Bugs Corregidos

1. ✅ Forest-Ruth en transporte paralelo (78% error)
2. ✅ Partículas pegadas (1M steps)
3. ✅ Wraparound cerca de θ=0/2π
4. ✅ Scoping de variables
5. ✅ Velocidades absurdas (±1e5)
6. ✅ Tiempos espurios (machine epsilon)

---

## 📚 Documentación Completa

| Archivo | Contenido |
|---------|-----------|
| `IMPLEMENTACION_COMPLETA_ADAPTIVE.md` | Resumen ejecutivo completo |
| `SOLUCION_FINAL_ADAPTIVE.md` | Guía detallada del sistema |
| `ERRORES_CORREGIDOS.md` | Análisis del error Forest-Ruth |
| `RESUMEN_FIXES_WRAPAROUND.md` | Fixes de wraparound |
| `STATUS_SISTEMA_ADAPTATIVO.md` | Estado y checklist |

---

## 🎯 Verificar Resultados

```julia
# Después de simular:
data = simulate_ellipse_adaptive(...)

# 1. Energía
E = analyze_energy_conservation(data.conservation)
@assert E.max_rel_error < 1e-6  # ✅ Debe pasar

# 2. Adaptación activa
dt_hist = data.parameters[:dt_history]
@assert length(unique(dt_hist)) > 1  # ✅ dt variando

# 3. No stuck
@assert mean(dt_hist) / minimum(dt_hist) > 100  # ✅ No en dt_min
```

---

## 💡 Tips

### Aumentar Colisiones (Para Testing)
```julia
particles = generate_random_particles(
    20, 1.0, 0.1, 2.0, 1.0;  # Radio 0.1 (más grande)
    θ_dot_range = (-2.0, 2.0)  # Velocidades mayores
)
```

### Velocidades Personalizadas
```julia
# Por especie
particles = [
    initialize_particle(1, 1.0, 0.05, 0.0, 0.5, a, b),    # Lenta
    initialize_particle(2, 1.0, 0.05, π, 2.0, a, b),      # Rápida
]
```

### Guardar Solo Colisiones
```julia
data = simulate_ellipse_adaptive(
    particles, a, b;
    save_interval = Inf,  # No guardar frames intermedios
    verbose = false       # Sin output
)
# Usar data.n_collisions y data.conservation
```

---

## 🔍 Troubleshooting

### "99% pérdida de energía"
→ Velocidades demasiado altas. Usar `θ_dot_range = (-1.0, 1.0)`

### "1M steps warning"
→ Partículas pegadas. FIXED en commit `ee3955c` + `5e87d2b`

### "UndefVarError: θ_dot1"
→ Scoping issue. FIXED en commit `19d7fe4`

### "dt_min = machine epsilon"
→ Colisión espuria. FIXED en commit `7aaf533`

---

## 📈 Performance Esperado

```
n = 10 partículas:
  Pasos: ~1000-2000
  Tiempo: ~1-2 segundos
  Colisiones: 0-50 (depende de densidad)
  Error energía: < 1e-8

n = 50 partículas:
  Pasos: ~5000-10000
  Tiempo: ~30-60 segundos
  Colisiones: 100-500
  Error energía: < 1e-6
```

---

## ⚡ Comandos Rápidos

```bash
# Pull latest
git pull origin claude/incomplete-task-recovery-011CUq95bFhkWKMNKHXgZaVN

# Run all tests
julia --project=. test_collision_guaranteed.jl
julia --project=. test_adaptive_improved.jl
julia --project=. ejemplo_adaptativo.jl

# Check git log
git log --oneline -10
```

---

## 🎓 Conceptos Clave

**Forest-Ruth:** Para sistemas Hamiltonianos SEPARABLES
- H = T(p) + V(q)
- Geodésicas en elipse ✅
- Transporte paralelo ❌

**RK4:** Para EDOs generales de 1er orden
- dv/dθ = -Γ(θ) v
- Transporte paralelo ✅

**Wraparound:** En dominio periódico [0, 2π]
```julia
Δθ_signed = mod(Δθ_raw + π, 2π) - π  # [-π, π]
```

---

## 📞 Soporte

**Si algo falla:**
1. Verificar branch: `claude/incomplete-task-recovery-011CUq95bFhkWKMNKHXgZaVN`
2. Pull latest: `git pull origin ...`
3. Ver documentación completa: `IMPLEMENTACION_COMPLETA_ADAPTIVE.md`
4. Revisar commit log: `git log --oneline`

---

**Última actualización:** 2025-11-06
**Último commit:** `b9279c7`
**Estado:** ✅ LISTO PARA USO
