# Análisis: Problema de Conservación de Energía

**Fecha**: 2025-11-20
**Status**: 🔴 CRÍTICO - ΔE/E₀ ≈ 100% para e=0.99

---

## Resultado del Test

```
Caso: N=120, e=0.99, r=0.0283 (intrínseco), t_max=10s
Resultado: ΔE/E₀ = 9.95e-01 ≈ 100% ❌ INACEPTABLE

Estadísticas:
- Colisiones totales: 75,753
- Tasa de colisiones: ~7,575/s
- Período entre colisiones: ~132 μs
- dt_avg: 69 μs
- dt_max usado: 100 μs
```

**Diagnóstico**: Con colisiones cada 132 μs y dt_avg=69 μs, las partículas están en colisión casi continua. Los errores numéricos se acumulan catastróficamente.

---

## Causas Identificadas

### 1. Radios Intrínsecos Muy Pequeños

Con geometría intrínseca corregida:

| N | e | r (euclidiano) | r (intrínseco) | Reducción |
|---|---|----------------|----------------|-----------|
| 120 | 0.99 | 0.050 | 0.0283 | **43%** |
| 80 | 0.99 | 0.050 | 0.0424 | 15% |

**Problema**: r=0.0283 es extremadamente pequeño para N=120 → solapamientos frecuentes

### 2. Excentricidad Extrema (e=0.99)

Para e=0.99:
- Perímetro ≈ 22.6 (vs 5.0 para círculo)
- Partículas se concentran en zonas de baja curvatura (extremos eje mayor)
- Clustering bipolar → alta densidad local → colisiones masivas

### 3. dt_max Inadecuado

```
dt_max = 1e-4 s  (100 μs)
Período colisión ~ 132 μs
→ dt_max ≈ 0.76 × T_collision
```

**Problema**: El timestep es comparable al período entre colisiones. El integrador no puede resolver la dinámica correctamente.

---

## Soluciones Propuestas

### Solución 1: Reducir N_max ✅ RECOMENDADO

**Decisión del usuario**: "Si 80 partículas cubren la curva, con eso bastaría"

**Implementación**:
```julia
N_values = [40, 60, 80]  # Antes: [40, 60, 80, 100, 120]
```

**Impacto**:
- Total runs: 270 (vs 450)
- Caso más crítico: N=80, e=0.99, r=0.0424
- Colisiones esperadas: ~40% menos que N=120
- Conservación: Mejor (menos partículas → menos colisiones)

**Ventaja clave**: φ=0.30 más razonable para todos los casos

### Solución 2: Reducir dt_max para e ≥ 0.95 ✅ NECESARIO

**Propuesta**:
```julia
dt_max = if e >= 0.95
    1e-5  # 10 μs para casos extremos
else
    1e-4  # 100 μs para casos normales
end
```

**Justificación**:
- Para e=0.99: dt_max=10 μs << T_collision=132 μs
- Factor de seguridad ~13×
- Integrador puede resolver dinámica correctamente

**Costo**: Tiempo de simulación ~10× mayor para e≥0.95 (aceptable)

### Solución 3: Activar Energy Projection ⚠️ EXPERIMENTAL

El código ya tiene soporte para energy projection:

```julia
data = simulate_ellipse_polar_adaptive(
    particles, a, b;
    use_projection = true,
    projection_interval = 100,  # Cada 100 pasos
    projection_tolerance = 1e-12
)
```

**Mecanismo**: Reescalar velocidades para conservar E₀

**Pros**: Fuerza conservación exacta
**Contras**: Puede enmascarar problemas físicos subyacentes

**Decisión**: Usar solo después de Soluciones 1 y 2

### Solución 4: Aumentar φ_target para e ≥ 0.9 ❌ NO RECOMENDADO

**Idea**: Usar φ=0.25 en vez de 0.30 para e≥0.9

**Problema**: Introduce heterogeneidad en densidad → dificulta análisis

**Veredicto**: Mejor reducir N_max (Solución 1)

---

## Plan de Acción

### Paso 1: Actualizar Parámetros de Campaña

**Archivo**: `calculate_intrinsic_radii.jl`

```julia
N_values = [40, 60, 80]  # Reducido de [40, 60, 80, 100, 120]
e_values = [0.0, 0.3, 0.5, 0.7, 0.8, 0.9, 0.95, 0.98, 0.99]
φ_target = 0.30
```

**Total runs**: 3 × 9 × 10 = **270 simulaciones**

### Paso 2: Implementar dt_max Adaptativo

**Archivo**: `run_single_experiment.jl` o script de lanzamiento

```julia
function get_dt_max(e::Float64)
    if e >= 0.95
        return 1e-5  # 10 μs para e extremo
    else
        return 1e-4  # 100 μs estándar
    end
end
```

### Paso 3: Test de Validación

**Casos críticos**:
1. N=80, e=0.99, dt_max=1e-5 → ΔE/E₀ < 1e-4 ✓
2. N=60, e=0.95, dt_max=1e-5 → ΔE/E₀ < 1e-4 ✓
3. N=80, e=0.8, dt_max=1e-4 → ΔE/E₀ < 1e-6 ✓

**Criterio de éxito**: ΔE/E₀ < 1e-4 para todos los casos

### Paso 4: Regenerar Matriz de Parámetros

```bash
julia --project=. calculate_intrinsic_radii.jl  # Con N_max=80
julia --project=. generate_finite_size_scaling_matrix.jl  # Con dt_max adaptativo
```

### Paso 5: Lanzar Campaña Corregida

```bash
./launch_finite_size_scaling.sh parameter_matrix_finite_size_scaling_corrected.csv
```

---

## Matriz de Radios Actualizada (N_max = 80)

```
e \ N         N=40      N=60      N=80
--------------------------------------------
e=0.00      0.01880   0.01253   0.00940
e=0.30      0.01883   0.01255   0.00942
e=0.50      0.01909   0.01273   0.00955
e=0.70      0.02040   0.01360   0.01020
e=0.80      0.02250   0.01500   0.01125
e=0.90      0.02873   0.01916   0.01437
e=0.95      0.03892   0.02594   0.01946
e=0.98      0.06033   0.04022   0.03017
e=0.99      0.08491   0.05661   0.04245
```

**Caso más crítico ahora**: N=80, e=0.99, r=0.04245
- Colisiones esperadas: ~40% menos que N=120
- Con dt_max=1e-5: conservación debería ser buena

---

## Estimaciones de Tiempo

### Con dt_max Adaptativo

| Caso | dt_max | t_max | Pasos esperados | Tiempo (est) |
|------|--------|-------|-----------------|--------------|
| N=40, e=0.0 | 1e-4 | 120s | 1.2M | ~3 min |
| N=80, e=0.8 | 1e-4 | 120s | 1.2M | ~10 min |
| N=80, e=0.99 | 1e-5 | 120s | 12M | ~100 min |

**Total campaña (270 runs)**:
- Runs "normales" (e<0.95): 225 runs × 5 min ≈ 19 hrs
- Runs "extremos" (e≥0.95): 45 runs × 80 min ≈ 60 hrs
- **Total estimado: ~80 hrs** (~3.3 días) con 24 cores

**Viable**: Sí, con ejecución en background

---

## Otras Cantidades Conservadas

Además de energía, verificar:

### 1. Momento Conjugado Total

```julia
P_φ_total = Σ (m_i × g_φφ(φ_i) × φ̇_i)
```

**Debe conservarse** para sistema cerrado

### 2. Momento Angular Total (NO se conserva)

```julia
L_total = Σ (m_i × r²(φ_i) × φ̇_i)
```

**No se conserva** para elipse (solo para círculo)

### 3. Distribución de Velocidades

Verificar que distribución no deriva sistemáticamente (sesgo)

---

## Checklist de Verificación

Antes de lanzar campaña completa:

- [ ] N_max reducido a 80
- [ ] Matriz de radios regenerada (3 × 9 = 27 combinaciones)
- [ ] dt_max adaptativo implementado
- [ ] Test de conservación: N=80, e=0.99, dt_max=1e-5
  - [ ] ΔE/E₀ < 1e-4
  - [ ] ΔP_φ/P_φ₀ < 1e-4
  - [ ] No drift en distribución de φ̇
- [ ] Test de conservación: N=80, e=0.8, dt_max=1e-4
  - [ ] ΔE/E₀ < 1e-6
- [ ] Matriz de parámetros final generada (270 runs)
- [ ] Script de lanzamiento actualizado
- [ ] Estimación de tiempo confirmada (~80 hrs)

---

## Decisión Final

**RECOMENDACIÓN**:
1. ✅ Reducir N_max a 80 (suficiente para cubrir la curva)
2. ✅ Implementar dt_max adaptativo (1e-5 para e≥0.95, 1e-4 otherwise)
3. ✅ Regenerar matriz con 270 runs
4. ⚠️ Verificar conservación antes de lanzar campaña completa

**Criterio de aceptación**: ΔE/E₀ < 1e-4 para TODOS los casos

---

**Generado**: 2025-11-20 00:00
**Status**: 🔴 ACCIÓN REQUERIDA - Implementar soluciones antes de campaña
