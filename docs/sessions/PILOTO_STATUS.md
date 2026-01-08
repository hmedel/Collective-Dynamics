# Estado del Piloto: Eccentricity Scan

**Fecha:** 2025-11-16 06:28 UTC
**Campaign ID:** campaign_eccentricity_scan_20251116_002247

---

## Configuración

```
Eccentricities: e = [0.0, 0.5, 0.98]
  - e=0.0  → Círculo (control negativo, esperado: NO clustering)
  - e=0.5  → Elipse moderada (esperado: clustering intermedio)
  - e=0.98 → Elipse extrema (esperado: clustering fuerte)

Realizaciones: 3 seeds por eccentricity
Total runs: 9

Parámetros:
  - N = 80 partículas
  - E/N = 0.32
  - t_max = 50s (reducido para piloto)
  - dt_max = 1e-5
  - use_projection = true (cada 100 pasos)
```

---

## Monitoreo

### Comandos de Monitoreo

```bash
# Ver progreso (cuenta archivos HDF5 generados)
ls results/campaign_eccentricity_scan_20251116_002247/*.h5 2>/dev/null | wc -l

# Ver simulaciones corriendo
ps aux | grep "run_single_eccentricity" | grep -v grep | wc -l

# Ver joblog
cat results/campaign_eccentricity_scan_20251116_002247/joblog.txt
```

### Estado Actual

- **Lanzado**: 06:56 UTC (relanzado desde project root)
- **Tiempo estimado**: ~20 min total (9 jobs en paralelo)
- **ETA finalización**: ~07:16 UTC
- **Status**: ✅ 9 simulaciones corriendo en paralelo
- **Progreso**: Los archivos HDF5 se generan al finalizar cada simulación

---

## Métricas Críticas a Verificar

### 1. Conservación de Energía

**Objetivo**: ΔE/E₀ < 1e-4 (buena conservación)

**Qué esperar**:
- Con projection cada 100 pasos → esperado: ΔE/E₀ ~ 1e-4 a 1e-5
- Si ΔE/E₀ > 1e-3 → revisar código

**Cómo verificar**:
```julia
# Leer un HDF5
using HDF5
h5open("results/campaign_eccentricity_scan_20251116_002247/run_0001_e0.000_N80_E0.32_seed1.h5", "r") do file
    read(attributes(file["metadata"]), "conservation_Delta_E_rel")
end
```

### 2. Clustering vs Eccentricity

**Hipótesis**:
- e=0.0  → R_final ≈ 1 (sin clustering)
- e=0.5  → R_final ~ 2-5 (moderado)
- e=0.98 → R_final > 10 (fuerte)

**Cómo verificar**: Correr `analyze_phase_transition.jl` en cada HDF5

### 3. Transición de Fase

**Qué buscar**:
- Parámetro de orden Ψ: 0 (inicial) → ? (final)
- Evolución temporal suave (no oscilaciones violentas)
- Detección de clusters

---

## Análisis Posterior

Una vez completadas las 9 simulaciones:

### Paso 1: Análisis Individual
```bash
julia --project=. analyze_phase_transition.jl \
    results/campaign_eccentricity_scan_20251116_002247/run_0001_e0.000_N80_E0.32_seed1.h5 \
    analysis_pilot
```

Revisar figuras generadas en `analysis_pilot/`:
- `phase_transition_e*.png` - Evolución temporal
- `phase_space_e*.png` - Espacio fase (φ, φ̇)
- `angular_distribution_e*.png` - Distribución angular

### Paso 2: Análisis Agregado
```bash
julia --project=. analyze_campaign_phase_transition.jl \
    results/campaign_eccentricity_scan_20251116_002247 \
    campaign_analysis_pilot
```

Revisar:
- `campaign_results.csv` - Todos los resultados
- `summary_by_eccentricity.csv` - Promedios y std por e
- `scaling_laws.png` - Ψ vs e, R vs e, etc.

### Paso 3: Decisión

**Si todo funciona bien** (conservación buena, tendencias correctas):
→ Lanzar campaña completa (180 runs, ~9 horas)

**Si hay problemas**:
→ Revisar código, ajustar parámetros, correr otro piloto

---

## Criterios de Éxito

✅ **Conservación**: ΔE/E₀ < 1e-3 para todos los runs
✅ **Tendencia**: R_final aumenta con e
✅ **Control negativo**: e=0.0 → R ≈ 1
✅ **Física**: Clustering en eje mayor (no menor)
✅ **Estabilidad**: No explosiones numéricas

---

## Próximos Pasos si Piloto es Exitoso

1. **Generar matriz completa**:
   ```bash
   julia --project=. generate_eccentricity_scan.jl
   ```

2. **Lanzar campaña completa**:
   ```bash
   ./launch_eccentricity_scan.sh parameter_matrix_eccentricity_scan.csv 24
   ```

3. **Análisis completo** (cuando termine):
   ```bash
   julia --project=. analyze_campaign_phase_transition.jl \
       results/campaign_eccentricity_scan_YYYYMMDD_HHMMSS \
       campaign_analysis_final
   ```

4. **Generar figuras para paper** (publication-ready)

---

## Notas

- El piloto usa t_max=50s (reducido) para validar rápido
- La campaña completa usará t_max=200s para mejor estadística
- Cada run guarda trayectorias completas (φ, φ̇ vs t)
- Los análisis están diseñados para operar sin supervisión
