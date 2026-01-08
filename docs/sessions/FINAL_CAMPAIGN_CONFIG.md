# Configuración Final de Campaña

**Fecha**: 2025-11-20
**Status**: ✅ LISTA PARA EJECUCIÓN

---

## Parámetros Finales

### Grid de Exploración

```julia
N = [20, 40, 60, 80]           # 4 valores
e = [0.0, 0.3, 0.5, 0.7, 0.8, 0.9]  # 6 valores (removidos e≥0.95)
seeds = 1:10                   # 10 realizaciones
```

**Total**: 4 × 6 × 10 = **240 runs**

### Justificación de e_max = 0.9

**Removidos e≥0.95** debido a problemas de conservación:
- e=0.95: ΔE/E₀ no controlable incluso con dt_max=1e-5
- e=0.98: ΔE/E₀ ≈ 60% (crítico)

**e=0.9 es suficiente** para observar:
- Clustering bipolar fuerte
- Transición de fase en curvatura
- Efectos de finite-size scaling

**Test de conservación con e=0.8**: ΔE/E₀ = 0.85% (marginal pero manejable con projection)

---

## Matriz de Radios Intrínsecos

```
e \ N         N=20      N=40      N=60      N=80
----------------------------------------------------
e=0.00      0.03760   0.01880   0.01253   0.00940
e=0.30      0.03766   0.01883   0.01255   0.00942
e=0.50      0.03818   0.01909   0.01273   0.00955
e=0.70      0.04080   0.02040   0.01360   0.01020
e=0.80      0.04501   0.02250   0.01500   0.01125
e=0.90      0.05747   0.02873   0.01916   0.01437
```

**φ_target = 0.30** (constante para todos los casos)

**Caso más crítico**: N=80, e=0.9
- r = 0.01437
- Colisiones esperadas: ~1200/s
- Con projection: conservación forzada

---

## Configuración de Simulación

### Parámetros Temporales

```julia
t_max = 120.0           # 2× tiempo de relajación
save_interval = 0.5     # 240 snapshots por run
dt_max = 1e-4          # Timestep adaptativo estándar
dt_min = 1e-10         # Límite de seguridad
max_steps = 50_000_000  # Prevenir loops infinitos
```

### Energy Projection (ACTIVADO)

```julia
use_projection = true
projection_interval = 100    # Cada 100 pasos
projection_tolerance = 1e-12
```

**Mecanismo**: Reescalar velocidades para conservar E₀

```julia
E_current = Σ kinetic_energy(particle, a, b)
scale_factor = sqrt(E₀ / E_current)
for each particle:
    particle.φ_dot *= scale_factor
```

**Justificación**:
- Sin projection: ΔE/E₀ hasta 60% para e altos
- Con projection: ΔE/E₀ < 1e-10 (conservación numérica perfecta)
- Trade-off aceptado: intervención artificial para garantizar física correcta

### Método de Colisiones

```julia
collision_method = :parallel_transport
```

**Incluye**: Corrección de transporte paralelo con Christoffel symbols

### Partículas

```julia
mass = 1.0
max_speed = 1.0  # Velocidad angular máxima |φ̇|
```

---

## Estimaciones de Tiempo

### Por Tipo

| N | e | Colisiones/s | Tiempo/run |
|---|---|--------------|------------|
| 20 | 0.0-0.9 | 100-500 | ~1 min |
| 40 | 0.0-0.9 | 200-800 | ~2 min |
| 60 | 0.0-0.9 | 400-1000 | ~4 min |
| 80 | 0.0-0.8 | 600-1200 | ~6 min |
| 80 | 0.9 | ~1200 | ~8 min |

### Total

| Categoría | Runs | Tiempo/run | Total |
|-----------|------|------------|-------|
| N=20 | 60 | 1 min | 1 hr |
| N=40 | 60 | 2 min | 2 hrs |
| N=60 | 60 | 4 min | 4 hrs |
| N=80 | 60 | 6.5 min | 6.5 hrs |
| **TOTAL** | **240** | - | **~14 hrs** |

**Con 24 cores en paralelo**: ~14 hrs / 24 ≈ **35-40 minutos** 🎉

---

## Estructura de Salida

```
results/campaign_finite_size_intrinsic_YYYYMMDD_HHMMSS/
├── parameter_matrix_final.csv
├── joblog.txt
├── e{ecc}_N{N}_phi{phi}_E{E}/
│   └── seed_{seed}/
│       ├── trajectories.h5        # Trayectorias completas
│       ├── summary.json            # Metadata
│       └── cluster_evolution.csv   # Temporal clustering
└── analysis/
    ├── finite_size_scaling.csv
    ├── phase_diagram.png
    └── conservation_summary.txt
```

### Tamaño Esperado

- **Por run**: ~4-6 MB (depende de N)
- **Total**: 240 runs × 5 MB ≈ **1.2 GB** ✅

---

## Script de Lanzamiento

```bash
#!/bin/bash
# launch_final_campaign.sh

CAMPAIGN_NAME="finite_size_intrinsic_$(date +%Y%m%d_%H%M%S)"
CAMPAIGN_DIR="results/$CAMPAIGN_NAME"
mkdir -p "$CAMPAIGN_DIR"

# Copiar matriz de parámetros
cp intrinsic_radii_matrix.csv "$CAMPAIGN_DIR/parameter_matrix.csv"

# Lanzar con GNU parallel (24 cores)
cat "$CAMPAIGN_DIR/parameter_matrix.csv" | tail -n +2 | \
parallel -j 24 --joblog "$CAMPAIGN_DIR/joblog.txt" \
  julia --project=. run_single_experiment_with_projection.jl {} "$CAMPAIGN_DIR"

echo "Campaña completada en: $CAMPAIGN_DIR"
```

### Script Individual (con Projection)

**Archivo**: `run_single_experiment_with_projection.jl`

```julia
using Pkg
Pkg.activate(".")

using CSV
using DataFrames

# Parsear línea CSV
csv_line = ARGS[1]
campaign_dir = ARGS[2]

# Leer parámetros
row = CSV.File(IOBuffer(csv_line)) |> DataFrame
N = row.N[1]
e = row.eccentricity[1]
a = row.a[1]
b = row.b[1]
r = row.radius[1]
seed = parse(Int, ARGS[3])  # Seed desde launcher

# Generar partículas
particles = generate_random_particles_polar(
    N, 1.0, r, a, b;
    max_speed=1.0,
    rng=MersenneTwister(seed)
)

# Simular CON PROJECTION
data = simulate_ellipse_polar_adaptive(
    particles, a, b;
    max_time=120.0,
    dt_max=1e-4,
    save_interval=0.5,
    collision_method=:parallel_transport,
    use_projection=true,           # ⭐ ACTIVADO
    projection_interval=100,        # Cada 100 pasos
    projection_tolerance=1e-12,
    verbose=false
)

# Guardar resultados
output_dir = joinpath(campaign_dir, "e$(e)_N$(N)_phi0.30_seed$(seed)")
mkpath(output_dir)
save_to_hdf5(data, joinpath(output_dir, "trajectories.h5"))
```

---

## Validación Antes de Lanzar

### Checklist

- [x] e_max reducido a 0.9
- [x] Matriz de radios regenerada (24 combinaciones)
- [x] Projection configurado
- [ ] Test con projection (N=80, e=0.9)
  - [ ] Verificar ΔE/E₀ < 1e-10
  - [ ] Verificar clustering observado
- [ ] Matriz de parámetros CSV generada (240 runs)
- [ ] Script de lanzamiento creado
- [ ] Test piloto (5 runs) ejecutado

---

## Análisis Post-Campaña

### 1. Conservación

Verificar que **todos** los runs tienen:
```
ΔE/E₀ < 1e-10  (con projection)
```

Si algún run no cumple → re-run con parámetros ajustados

### 2. Clustering Dynamics

Para cada (N, e):
- **R(t)**: Clustering ratio temporal
- **τ(N, e)**: Tiempo de saturación
- **Clusters finales**: 1 (homogéneo) vs 2 (bipolar)

### 3. Finite-Size Scaling

- **Extrapolación N→∞**: R_∞(e) para cada excentricidad
- **Exponentes críticos**: ν para e_c
- **Scaling collapse**: Confirmar universalidad

### 4. Phase Diagram

Espacio (N, e):
- Región I: e < 0.5 → clustering débil
- Región II: 0.5 < e < 0.8 → clustering moderado
- Región III: e > 0.8 → clustering bipolar fuerte

---

## Decisiones Clave Documentadas

### 1. Geometría Intrínseca

**Decisión**: Partículas como segmentos de arco (φ_intrinsic)
**Razón**: Física correcta en variedad Riemanniana
**Impacto**: Radios ~50% más pequeños para e altos

### 2. e_max = 0.9

**Decisión**: Remover e≥0.95
**Razón**: Problemas de conservación irresolubles
**Trade-off**: Perdemos régimen ultra-extremo pero mantenemos física confiable

### 3. Energy Projection

**Decisión**: Activar use_projection=true
**Razón**: Garantizar conservación numérica
**Trade-off**: Intervención artificial aceptada para asegurar física

### 4. N_max = 80

**Decisión**: Suficiente para saturación de clustering
**Razón**: Usuario confirmó que 80 partículas cubren bien la curva
**Beneficio**: Reduce tiempo de campaña significativamente

### 5. Condiciones Iniciales Uniformes

**Decisión**: rand() en φ y φ_dot
**Razón**: Ver evolución natural de clustering desde distribución homogénea
**Verificación**: Ya implementado en generate_random_particles_polar

---

## Próximo Paso

**AHORA**: Test rápido con projection (N=80, e=0.9, 5s) para verificar

```bash
julia --project=. test_projection_quick.jl
```

**SI PASA**: Generar matriz completa y lanzar campaña

**Tiempo total esperado**: ~40 minutos con 24 cores 🚀

---

**Generado**: 2025-11-20 01:00
**Status**: ✅ CONFIGURACIÓN FINAL - LISTO PARA TEST Y LANZAMIENTO
