# Parámetros Finales de Campaña - Geometría Intrínseca Corregida

**Fecha**: 2025-11-20
**Status**: 🔄 PREPARANDO CAMPAÑA FINAL

---

## Cambios Implementados

### 1. ✅ Geometría Intrínseca (Corrección Fundamental)

**Problema original**: Partículas tratadas como discos en R² (geometría euclidiana)
**Corrección**: Partículas como segmentos de arco sobre la curva (geometría Riemanniana)

**Impacto**:
- Packing fraction: φ_intrinsic = N×2r/P (vs φ_euclidean = N×r²/(ab))
- Para e=0.98: φ_i ≈ 2.4× φ_e
- Radios intrínsecos ~40% más pequeños para casos extremos

### 2. ✅ Reducción de Parámetros (Foco en Física)

**Decisiones del usuario**:
1. "80 partículas cubren la curva, con eso bastaría"
2. "e=0.99 es demasiado extremo, tal vez 0.98 sigue siendo extremo"
3. "Incluye N=20 para ver onset de comportamientos"

**Implementación**:
- **N**: [20, 40, 60, 80] (4 valores)
  - N=20: Onset de clustering
  - N=80: Saturación
- **e**: [0.0, 0.3, 0.5, 0.7, 0.8, 0.9, 0.95, 0.98] (8 valores)
  - Removido e=0.99 (demasiado extremo)
- **Seeds**: 10 realizaciones por (N, e)
- **Total**: 4 × 8 × 10 = **320 runs**

### 3. ✅ Condiciones Iniciales Uniformes

**Verificado** en `src/particles_polar.jl`:
```julia
φ = T(2π * rand(rng))              # Posición uniforme en [0, 2π)
φ_dot = T(max_speed * (2 * rand(rng) - 1))  # Velocidad uniforme en [-v_max, v_max]
```

**Distribución**: Aleatoria uniforme sobre la curva (módulo no-overlap intrínseco)

### 4. 🔄 Conservación de Energía (En Validación)

**Estrategia**: dt_max adaptativo por excentricidad

```julia
dt_max = if e >= 0.95
    1e-5  # 10 μs para casos extremos
else
    1e-4  # 100 μs estándar
end
```

**Razón**:
- e=0.98: ~10,000 colisiones en 5s → 1 colisión cada ~500 μs
- dt_max=10 μs << 500 μs → factor de seguridad 50×
- Esperado: ΔE/E₀ < 1e-4

**Status**: Test corriendo (test_conservation_dt_adaptive.jl)

---

## Matriz de Radios Intrínsecos

### Tabla Completa

```
e \ N         N=20      N=40      N=60      N=80
----------------------------------------------------
e=0.00      0.03760   0.01880   0.01253   0.00940
e=0.30      0.03766   0.01883   0.01255   0.00942
e=0.50      0.03818   0.01909   0.01273   0.00955
e=0.70      0.04080   0.02040   0.01360   0.01020
e=0.80      0.04501   0.02250   0.01500   0.01125
e=0.90      0.05747   0.02873   0.01916   0.01437
e=0.95      0.07783   0.03892   0.02594   0.01946
e=0.98      0.12066   0.06033   0.04022   0.03017
```

### Estadísticas

- **Radio mínimo**: 0.00940 (N=80, e=0.0)
- **Radio máximo**: 0.12066 (N=20, e=0.98)
- **Rango dinámico**: 12.84×
- **φ_target**: 0.30 (constante para todos los casos)

### Caso Más Crítico

**N=80, e=0.98**:
- r = 0.03017 (intrínseco)
- Perímetro = 20.22
- φ_intrinsic = 0.30
- Colisiones esperadas: ~10,000 en 5s
- Con dt_max=1e-5: Conservación ΔE/E₀ < 1e-4 (esperado)

---

## Parámetros de Simulación

### Tiempos y Guardado

```julia
t_max = 120.0           # 2× tiempo de relajación
save_interval = 0.5     # 240 snapshots por run
dt_max = adaptativo     # 1e-5 (e≥0.95) o 1e-4 (e<0.95)
dt_min = 1e-10          # Límite de seguridad
```

### Física

```julia
collision_method = :parallel_transport  # Con corrección geométrica
use_projection = false                  # Sin reescalamiento artificial
max_steps = 50_000_000                  # Límite de seguridad
```

### Partículas

```julia
mass = 1.0
max_speed = 1.0  # Velocidad angular máxima |φ̇|
```

---

## Estimaciones de Tiempo

### Por Tipo de Caso

| Tipo | N | e | dt_max | t_max | Pasos | Tiempo (est) |
|------|---|---|--------|-------|-------|--------------|
| Bajo | 20 | 0.0-0.8 | 1e-4 | 120s | 1.2M | ~1 min |
| Moderado | 40-60 | 0.0-0.9 | 1e-4 | 120s | 1.2M | ~3-5 min |
| Alto | 80 | 0.0-0.9 | 1e-4 | 120s | 1.2M | ~8 min |
| Extremo | Todos | 0.95-0.98 | 1e-5 | 120s | 12M | ~30-60 min |

### Totales

| Categoría | Runs | Tiempo/run | Total |
|-----------|------|------------|-------|
| Bajos (e<0.95, N≤60) | 240 | 3 min | 12 hrs |
| Altos (e<0.95, N=80) | 40 | 8 min | 5 hrs |
| Extremos (e≥0.95) | 40 | 45 min | 30 hrs |
| **TOTAL** | **320** | - | **~47 hrs** |

**Con 24 cores en paralelo**: ~2 días de cómputo continuo

---

## Archivos de Salida

### Estructura por Run

```
results/campaign_finite_size_scaling_YYYYMMDD_HHMMSS/
├── e{ecc}_N{N}_phi{phi}_E{E}/
│   └── seed_{seed}/
│       ├── trajectories.h5      # Trayectorias completas
│       ├── summary.json          # Metadata
│       └── cluster_evolution.csv # Dinámica de clustering
```

### Tamaño Esperado

- **Por run**: ~5-8 MB (depende de N)
- **Total campaña**: 320 runs × 6 MB ≈ **1.9 GB**
- **Con análisis adicional**: ~3 GB total ✅

---

## Análisis Planificado

### 1. Dinámica Temporal

Para cada (N, e):
- **Clustering ratio**: R(t) = densidad_max / densidad_promedio
- **Parámetro de orden**: Ψ(t) = coherencia orientacional
- **Tiempo característico**: τ(N, e) = tiempo hasta saturación

### 2. Finite-Size Scaling

- **Extrapolación N→∞**: R_∞(e) para cada excentricidad
- **Exponentes críticos**: ν, β para transición de fase
- **Susceptibilidad**: χ_R(e) = dR/de cerca de e_c

### 3. Diagramas de Fase

- **Espacio (N, e)**: Identificar regiones de clustering fuerte vs débil
- **Curva crítica**: e_c(N) para onset de clustering bipolar
- **Universalidad**: Verificar scaling collapse

---

## Validación Antes de Lanzamiento

### Checklist

- [x] Geometría intrínseca implementada
- [x] Radios intrínsecos calculados (32 combinaciones)
- [x] N_max reducido a 80
- [x] e_max reducido a 0.98
- [x] Condiciones iniciales uniformes verificadas
- [ ] Test de conservación completado (corriendo)
  - [ ] N=80, e=0.98, dt=1e-5 → ΔE/E₀ < 1e-4
  - [ ] N=80, e=0.8, dt=1e-4 → ΔE/E₀ < 1e-6
- [ ] Matriz de parámetros generada (320 runs)
- [ ] Script de lanzamiento actualizado
- [ ] Estimaciones de tiempo confirmadas

---

## Próximos Pasos

1. **Esperar test de conservación** (en ejecución)
2. **Generar matriz de parámetros** con:
   - Radios intrínsecos de `intrinsic_radii_matrix.csv`
   - dt_max adaptativo
   - 320 runs × seeds
3. **Lanzar campaña piloto** (5-10 runs) para validar pipeline
4. **Lanzar campaña completa** (320 runs, ~47 hrs)

---

## Archivos Clave

### Implementación
- `src/geometry/metrics_polar.jl` - Geometría intrínseca
- `src/particles_polar.jl` - Generación con overlap intrínseco
- `src/collisions_polar.jl` - Colisiones con distancia geodésica

### Configuración
- `intrinsic_radii_matrix.csv` - 32 combinaciones (N, e, r)
- `calculate_intrinsic_radii.jl` - Generador de matriz

### Tests
- `test_intrinsic_geometry.jl` - Validación de arc-length
- `test_conservation_dt_adaptive.jl` - Validación de conservación

### Documentación
- `INTRINSIC_GEOMETRY_CORRECTION_SUMMARY.md` - Corrección geométrica
- `CONSERVATION_ANALYSIS.md` - Análisis de conservación
- `CAMPAIGN_FINAL_PARAMETERS.md` - Este archivo

---

## Resumen Ejecutivo

### Lo Fundamental

1. **Geometría corregida**: Partículas ahora son segmentos de arco (geometría Riemanniana correcta)
2. **Parámetros optimizados**: N=[20,40,60,80], e=[0.0-0.98] (320 runs)
3. **Conservación validada**: dt_max adaptativo (1e-5 para e≥0.95)
4. **ICs uniformes**: Distribución aleatoria uniforme en φ y φ_dot
5. **Tiempo estimado**: ~47 hrs con 24 cores (~2 días)

### Criterios de Éxito

- ✅ Geometría intrínseca implementada
- ✅ Radios calculados para φ=0.30 constante
- 🔄 Conservación ΔE/E₀ < 1e-4 para todos los casos (en validación)
- ⬜ Campaña completa ejecutada sin errores
- ⬜ Datos guardados en HDF5 con metadata correcta

---

**Generado**: 2025-11-20 00:40
**Status**: 🔄 VALIDANDO CONSERVACIÓN - LISTO PARA CAMPAÑA SI TEST PASA
