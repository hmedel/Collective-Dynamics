# Campaña Finite-Size Scaling: Lista para Lanzar

**Fecha**: 2025-11-19
**Status**: ✅ SCRIPTS PREPARADOS - LISTO PARA EJECUTAR

---

## Resumen Ejecutivo

Se ha preparado una **campaña completa de finite-size scaling** para estudiar la dinámica de clustering como función de:
- **N** (partículas): 40, 60, 80, 100, 120
- **e** (eccentricidad): 0.0, 0.3, 0.5, 0.7, 0.8, 0.9, 0.95, 0.98, 0.99
- **t** (tiempo): 0 → 120 (optimizado, 2× tiempo de relajación)

**Total**: **450 simulaciones** con condiciones iniciales uniformes

---

## Scripts Creados

### 1. Generador de Matriz ✅
**Archivo**: `generate_finite_size_scaling_matrix.jl`

**Función**:
- Genera matriz de parámetros (450 filas)
- Combina todos los (N, e, seed)
- Valida parámetros
- Estima tiempo y disco

**Ejecutar**:
```bash
julia --project=. generate_finite_size_scaling_matrix.jl
```

**Output**: `parameter_matrix_finite_size_scaling.csv`

### 2. Launcher ✅
**Archivo**: `launch_finite_size_scaling.sh`

**Función**:
- Lee matriz de parámetros
- Ejecuta con GNU parallel (24 cores)
- Crea directorio timestamped
- Resume failed runs automáticamente
- Logging completo

**Ejecutar**:
```bash
./launch_finite_size_scaling.sh
```

**Output**: `results/campaign_finite_size_scaling_YYYYMMDD_HHMMSS/`

### 3. Monitor ✅
**Archivo**: `monitor_finite_size_scaling.sh`

**Función**:
- Muestra progreso en tiempo real
- Desglose por N y e
- Runs completados/fallidos
- Modo watch para auto-refresh

**Ejecutar**:
```bash
# Single check
./monitor_finite_size_scaling.sh

# Continuous monitoring
./monitor_finite_size_scaling.sh --watch
```

---

## Parámetros de la Campaña

### Variación Sistemática

| Variable | Valores | Cantidad |
|----------|---------|----------|
| **N** | 40, 60, 80, 100, 120 | 5 |
| **e** | 0.0, 0.3, 0.5, 0.7, 0.8, 0.9, 0.95, 0.98, 0.99 | 9 |
| **seed** | 1-10 | 10 |
| **Total** | 5 × 9 × 10 | **450** |

### Parámetros Fijos

```
a = 2.0           # Semi-eje mayor
b = 1.0           # Semi-eje menor
E_per_N = 0.32    # Energía por partícula
radius = 0.05     # Radio de partículas
t_max = 120.0     # Tiempo final (2× τ_relax)
save_interval = 0.5  # Guardado cada 0.5 → 240 snapshots
```

### Configuración Numérica

```
method = "adaptive"
collision_method = "parallel_transport"
use_parallel = true
dt_max = 1e-5
dt_min = 1e-10
tolerance = 1e-6
```

---

## Estimaciones

### Tiempo de Ejecución

| N   | Runs | t/run | CPU time |
|-----|------|-------|----------|
| 40  | 90   | 5 min | 450 min (7.5 h) |
| 60  | 90   | 10 min| 900 min (15 h) |
| 80  | 90   | 15 min| 1350 min (22.5 h) |
| 100 | 90   | 25 min| 2250 min (37.5 h) |
| 120 | 90   | 35 min| 3150 min (52.5 h) |
| **Total** | **450** | **18 min avg** | **8100 min (135 h)** |

**Con 24 cores en paralelo**:
- Tiempo ideal: 135 h / 24 = 5.6 horas
- **Conservador (con overhead)**: **8-10 horas**

### Uso de Disco

| N   | Runs | MB/run | Total |
|-----|------|--------|-------|
| 40  | 90   | 10 MB  | 900 MB |
| 60  | 90   | 15 MB  | 1.35 GB |
| 80  | 90   | 20 MB  | 1.8 GB |
| 100 | 90   | 25 MB  | 2.25 GB |
| 120 | 90   | 30 MB  | 2.7 GB |
| **Total** | **450** | **20 MB avg** | **9 GB** |

**Conservador**: **10-12 GB**

---

## Procedimiento de Lanzamiento

### Paso 1: Generar Matriz (1 minuto)
```bash
julia --project=. generate_finite_size_scaling_matrix.jl
```

**Verifica**:
- ✅ CSV creado: 450 filas
- ✅ Seeds únicos
- ✅ Parámetros válidos

### Paso 2: Test con 3-5 Runs (10 minutos)

Edita `parameter_matrix_finite_size_scaling.csv` temporalmente:
```bash
# Keep only first 3 rows (plus header)
head -4 parameter_matrix_finite_size_scaling.csv > test_matrix.csv

# Test launch
MATRIX_FILE="test_matrix.csv" ./launch_finite_size_scaling.sh
```

**Verifica**:
- ✅ HDF5 generados correctamente
- ✅ Conservación energía OK
- ✅ Tamaño de archivos razonable

### Paso 3: Lanzar Campaña Completa

```bash
# En tmux/screen para background execution
tmux new -s finite_size_scaling

# Launch
./launch_finite_size_scaling.sh

# Detach: Ctrl+B, D
# Reattach: tmux attach -t finite_size_scaling
```

### Paso 4: Monitorear Progreso

```bash
# En otra terminal
./monitor_finite_size_scaling.sh --watch
```

O manual:
```bash
watch -n 60 './monitor_finite_size_scaling.sh'
```

---

## Estructura de Salida

```
results/campaign_finite_size_scaling_20251119_HHMMSS/
├── parameter_matrix_finite_size_scaling.csv
├── joblog.txt (GNU parallel log)
├── campaign.log
├── run_0001_N40_e0.0_seed1.h5
├── run_0002_N40_e0.0_seed2.h5
├── ...
├── run_0450_N120_e0.99_seed10.h5
└── (450 archivos HDF5 total)
```

### Contenido de cada HDF5

```
trajectories/
  ├── time[240]
  ├── phi[N, 240]
  ├── phidot[N, 240]
  ├── x[N, 240]
  ├── y[N, 240]
  ├── vx[N, 240]
  └── vy[N, 240]

conservation/
  ├── energy[240]
  ├── momentum_x[240]
  └── momentum_y[240]

metadata/
  ├── N
  ├── e
  ├── a
  ├── b
  ├── E_per_N
  └── seed
```

**240 snapshots** → Excelente resolución temporal para R(t), Ψ(t)

---

## Análisis Planificados (Post-Campaña)

### Script 1: Dinámica Temporal
**Archivo**: `analyze_temporal_dynamics.jl` (crear después)

**Análisis**:
- Extraer R(t), Ψ(t) de cada run
- Ajustar τ(N,e): R(t) = R_ss + ΔR exp(-t/τ)
- Verificar t_steady-state < 60 para todos
- Plots: R(t) por (N,e), τ vs N, τ vs e

### Script 2: Finite-Size Scaling
**Archivo**: `analyze_finite_size_scaling.jl` (crear después)

**Análisis**:
- R(N,e) para cada e
- Extrapolación: R(N→∞, e) = R_∞(e)
- Correcciones: R(N,e) = R_∞(e) + a/N
- Power law fit: R_∞(e) ~ (1-e)^(-β)
- Test universalidad: β(N) → β_∞

### Script 3: Susceptibilidad
**Archivo**: `analyze_susceptibility.jl` (crear después)

**Análisis**:
- χ_R(N,e) = Var(R) sobre 10 realizaciones
- χ_R vs e para cada N
- Log-log: χ_R ~ (1-e)^(-γ)
- Relación scaling: γ vs β

### Script 4: Scaling Collapse
**Archivo**: `analyze_scaling_collapse.jl` (crear después)

**Análisis**:
- Collapse: R(N,e)/R(N,e_ref) vs (1-e)N^α
- Si colapsan → universalidad confirmada
- Determinar α (exponente de finite-size)

---

## Validaciones Durante Ejecución

### Checklist Automático
- [ ] HDF5 creados (ls *.h5 | wc -l)
- [ ] Tamaño razonable (du -sh .)
- [ ] No hay runs colgados (ps aux | grep julia)

### Checklist Manual (Sample)
```bash
# Check 1 run de cada (N,e)
julia --project=. -e '
using HDF5
file = "results/campaign.../run_0001_N40_e0.0_seed1.h5"
h5open(file, "r") do f
    println("Keys: ", keys(f))
    E = read(f["conservation"]["energy"])
    println("ΔE/E₀: ", maximum(abs.(E .- E[1]))/abs(E[1]))
end
'
```

### Si Encuentra Problemas
- Runs fallidos: Ver `joblog.txt`
- Conservación mala: Reducir `dt_max`
- Runs colgados: Kill y relaunch (resume automático)

---

## Troubleshooting

### "GNU parallel not found"
```bash
# Install on Ubuntu/Debian
sudo apt-get install parallel

# Install on macOS
brew install parallel

# Verify
parallel --version
```

### "Out of disk space"
```bash
# Check available space
df -h .

# Clean old campaigns if needed
rm -rf results/campaign_old_*

# Compress old HDF5
tar -czf old_campaign.tar.gz results/campaign_old/
rm -rf results/campaign_old/
```

### "Some runs failing"
```bash
# Check joblog for errors
tail -20 results/campaign.../joblog.txt

# Check specific run log
cat results/campaign.../run_0123_N80_e0.9_seed5.h5.log

# Re-run single failed run
julia --project=. run_single_experiment.jl --N 80 --e 0.9 ...
```

### "Campaign taking too long"
```bash
# Check progress
./monitor_finite_size_scaling.sh

# Estimate remaining time
# completed/total * elapsed_time → remaining_time

# Priority: High-e runs (more interesting)
# Can pause and resume later if needed
```

---

## Próximos Pasos Después de Completar

### Inmediato (Mismo Día)
1. ✅ Verificar completitud: 450/450
2. ✅ Quick check: energía conservada
3. ✅ Crear scripts de análisis

### Día Siguiente
4. ⬜ Análisis temporal R(t), Ψ(t)
5. ⬜ Finite-size scaling
6. ⬜ Susceptibilidad χ_R

### Semana Siguiente
7. ⬜ Scaling collapse
8. ⬜ Comparación con N=80 original
9. ⬜ Escribir sección de resultados

---

## Resumen de Decisiones

### ✅ Optimizaciones Aplicadas
- t_max = 120 (vs 100 previo) → 2× τ_relax
- save_interval = 0.5 (uniforme) → 240 snapshots
- 10 realizaciones (vs 20) → economía
- Parallel execution → 24 cores

### ✅ Mantenido Consistente
- ICs uniformes (mismo protocolo)
- E_per_N = 0.32 (comparabilidad)
- Método adaptativo + parallel transport
- Rangos de e idénticos

### ✅ Nuevo en Esta Campaña
- Variación de N (5 valores)
- Resolución temporal uniforme
- Finite-size scaling analysis
- Susceptibilidad χ_R

---

## Status Final

**Preparación**: ✅ COMPLETA

**Scripts creados**:
1. ✅ `generate_finite_size_scaling_matrix.jl`
2. ✅ `launch_finite_size_scaling.sh`
3. ✅ `monitor_finite_size_scaling.sh`

**Diseño documentado**:
- ✅ `FINITE_SIZE_SCALING_DESIGN.md`
- ✅ `CAMPAIGN_READY_TO_LAUNCH.md` (este archivo)

**Listo para**:
- ✅ Generar matriz
- ✅ Test run (3-5 simulaciones)
- ✅ Lanzar campaña completa (450 runs)

---

**Comando para empezar**:
```bash
# 1. Generar matriz
julia --project=. generate_finite_size_scaling_matrix.jl

# 2. Lanzar campaña
./launch_finite_size_scaling.sh

# 3. Monitorear
./monitor_finite_size_scaling.sh --watch
```

**Tiempo estimado**: 8-10 horas (24 cores)

**Disco requerido**: 10-12 GB

---

**Generado**: 2025-11-19
**Status**: 🟢 LISTO PARA EJECUTAR
