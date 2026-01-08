# Test Campaign Status

**Fecha**: 2025-11-19 21:20
**Status**: 🔄 EN EJECUCIÓN (4/5 runs activos)

---

## Resumen

Campaña de prueba con **5 corridas** para validar la infraestructura de finite-size scaling antes del lanzamiento completo (450 runs).

---

## Corridas de Prueba

| Run ID | N   | e    | φ     | Seed | Status |
|--------|-----|------|-------|------|--------|
| 1      | 40  | 0.0  | 0.05  | 1    | ✅ Ejecutando |
| 50     | 40  | 0.8  | 0.05  | 10   | ✅ Ejecutando |
| 180    | 60  | 0.99 | 0.075 | 10   | ✅ Ejecutando |
| 360    | 100 | 0.99 | 0.125 | 10   | ✅ Ejecutando |
| 445    | 120 | 0.99 | 0.150 | 5    | ❌ FALLÓ (packing demasiado alto) |

---

## Problemas Encontrados y Solucionados

### 1. Error de Parseo CSV ✅
**Problema**: GNU parallel no pasaba correctamente los parámetros
```bash
# Incorrecto
parallel --colsep ',' "$RUN_SCRIPT" {%} "$CAMPAIGN_DIR"

# Correcto
parallel "$RUN_SCRIPT" {} "$CAMPAIGN_DIR"
```

### 2. Comando `bc` no disponible ✅
**Problema**: Cálculo de φ fallaba porque `bc` no está instalado
```bash
# Incorrecto
phi=$(echo "$N * $radius * $radius / ($a * $b)" | bc -l)

# Correcto (usando awk)
phi=$(awk -v n=$N -v r=$radius -v a=$a -v b=$b 'BEGIN {printf "%.6f", n * r * r / (a * b)}')
```

### 3. Argumentos faltantes ✅
**Problema**: `run_single_experiment.jl` requiere `--phi` pero la matriz tiene `radius`
**Solución**: Calcular φ = N × r² / (a × b) en el script de lanzamiento

### 4. Packing fraction demasiado alto (N=120, e=0.99)
**Problema**: φ=0.15 es demasiado alto para elipse muy excéntrica (e=0.99)
**Error**: "No se pudo generar posición válida para partícula 113 después de 10000 intentos"
**Solución**: Para la campaña completa, considerar:
- Reducir radio a 0.04 para N≥100 con e≥0.95
- O limitar N_max a 100 para e≥0.99

---

## Parámetros de las Simulaciones

```
t_max = 120.0          # 2× tiempo de relajación
save_interval = 0.5    # 240 snapshots por run
method = adaptive      # Timestep adaptativo
collision_method = parallel_transport
use_parallel = true    # Detección de colisiones paralela
```

---

## Tiempo Estimado por Corrida

Basado en experiencia previa (N=80, t_max=100):

| N   | Tiempo estimado |
|-----|-----------------|
| 40  | ~2-3 min        |
| 60  | ~5-8 min        |
| 100 | ~15-20 min      |
| 120 | ~25-30 min      |

**Total para test (4 runs exitosos)**: ~45-60 minutos

---

## Scripts Creados

### 1. `generate_finite_size_scaling_matrix.jl` ✅
- Genera matriz de 450 runs (5 N × 9 e × 10 seeds)
- Valida parámetros
- Estima tiempo (8-10 hrs) y disco (10-12 GB)
- **Output**: `parameter_matrix_finite_size_scaling.csv`

### 2. `launch_finite_size_scaling.sh` ✅
- Lanzador principal para campaña completa
- GNU parallel con 24 cores
- Resume failed runs automáticamente
- **Input**: `parameter_matrix_finite_size_scaling.csv`

### 3. `launch_test_campaign.sh` ✅
- Lanzador de prueba (5 runs)
- Misma lógica que el principal
- **Input**: `parameter_matrix_test.csv`

### 4. `monitor_finite_size_scaling.sh` ✅
- Monitoreo en tiempo real
- Desglose por N y e
- Modo watch para auto-refresh

---

## Próximos Pasos

### Inmediato (Hoy)
1. ⏳ Esperar completitud del test (4 runs, ~45-60 min)
2. ⬜ Verificar HDF5 generados correctamente
3. ⬜ Quick check: energía conservada, tamaño de archivos
4. ⬜ Validar estructura de datos (trajectories, conservation, metadata)

### Si Test es Exitoso
5. ⬜ **Decisión**: Reducir parámetros para N≥100, e≥0.95
   - Opción A: radius = 0.04 (en vez de 0.05)
   - Opción B: Limitar N_max = 100
   - Opción C: Excluir combinaciones (N≥100, e≥0.98)

6. ⬜ Regenerar matriz completa con ajustes
7. ⬜ Lanzar campaña completa (450 runs, 8-10 hrs)

### Análisis (Post-Campaña)
8. ⬜ Temporal dynamics: R(t), Ψ(t), τ(N,e)
9. ⬜ Finite-size scaling: R(N,e), R_∞(e)
10. ⬜ Susceptibility: χ_R vs e
11. ⬜ Scaling collapse: universalidad

---

## Validaciones Durante Test

### Checklist Automático
```bash
# Verificar HDF5 creados
find results/test_campaign_*/ -name "*.h5" | wc -l  # Esperado: 4

# Tamaño total
du -sh results/test_campaign_*/               # Esperado: ~50-100 MB

# Procesos Julia activos
ps aux | grep julia | wc -l                    # Durante: 4, después: 0
```

### Checklist Manual
```bash
# Verificar conservación de energía
julia --project=. -e '
using HDF5
h5open("results/test_campaign_*/e0.000_N40_phi0.05_E0.32/seed_1/simulation.h5", "r") do f
    E = read(f["conservation"]["energy"])
    println("ΔE/E₀: ", maximum(abs.(E .- E[1]))/abs(E[1]))
end
'

# Verificar estructura HDF5
h5ls -r results/test_campaign_*/e0.000_N40_phi0.05_E0.32/seed_1/simulation.h5
```

---

## Directorio de Salida

```
results/test_campaign_20251119_212025/
├── parameter_matrix_test.csv
├── joblog.txt
├── run_0001_N40_e0.0_seed1.h5.log
├── run_0050_N40_e0.8_seed10.h5.log
├── run_0180_N60_e0.99_seed10.h5.log
├── run_0360_N100_e0.99_seed10.h5.log
├── run_0445_N120_e0.99_seed5.h5.log (FALLÓ)
├── run_single.sh
└── e{ecc}_N{N}_phi{phi}_E{E}/
    └── seed_{seed}/
        ├── simulation.h5
        ├── config.toml
        └── summary.txt
```

---

## Estado Actual

**Directorio**: `results/test_campaign_20251119_212025/`
**Hora inicio**: 21:20:25
**Runs completados**: 0/4 (en progreso)
**Runs fallidos**: 1/5 (N=120, packing alto)

**Monitoreo**:
```bash
# Ver progreso
watch -n 10 'find results/test_campaign_*/ -name "*.h5" | wc -l'

# Ver procesos
ps aux | grep julia | grep -v grep
```

---

## Notas Técnicas

### Packing Fraction
Para elipse con semi-ejes (a, b) y N partículas con radio r:
```
φ = N × r² / (a × b)
```

Con a=2, b=1, r=0.05:
- N=40:  φ = 0.05  ✅
- N=60:  φ = 0.075 ✅
- N=80:  φ = 0.10  ✅
- N=100: φ = 0.125 ✅
- N=120: φ = 0.15  ❌ (demasiado alto para e=0.99)

### Límite Teórico
Para e=0.99: b_eff ~ b × √(1-e²) ~ 0.14 b
Esto reduce el área efectiva disponible, haciendo que φ_eff >> φ_nominal

**Recomendación**: Para e ≥ 0.95, usar r = 0.04 o N_max = 100

---

**Generado**: 2025-11-19 21:20
**Status**: 🔄 TEST EN PROGRESO (4/5 corridas ejecutando)
