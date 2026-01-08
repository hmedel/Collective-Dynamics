# Diseño de Campaña: Finite-Size Scaling

**Fecha**: 2025-11-19
**Objetivo**: Estudiar dinámica de clustering como función de N, e, y t con ICs uniformes

---

## Motivación

### Hallazgos Previos (N=80)
- ✅ Estado estacionario alcanzado en **t ~ 60**
- ✅ Clustering aumenta con e: R = 1.01 → 5.71 (+466%)
- ✅ Power law: R(e) ~ (1-e)^(-0.65)
- ⬜ **Pendiente**: Verificar si β depende de N

### Preguntas Científicas
1. ¿El exponente crítico β es universal (independiente de N)?
2. ¿El tiempo de relajación τ depende de N y e?
3. ¿La susceptibilidad χ_R diverge en e→1?
4. ¿Hay correcciones de tamaño finito al clustering?

---

## Diseño Experimental

### Parámetros a Variar

#### 1. Número de Partículas (N)
```
N = [40, 60, 80, 100, 120]
```

**Justificación**:
- N=40: Sistema pequeño (baseline)
- N=60: Intermedio
- N=80: Ya analizado (referencia)
- N=100: Grande
- N=120: Muy grande (test de convergencia)

**Rango**: Factor de 3× (40 → 120)

#### 2. Eccentricidad (e)
```
e = [0.0, 0.3, 0.5, 0.7, 0.8, 0.9, 0.95, 0.98, 0.99]
```

**Justificación**:
- Mismo rango que campaña N=80
- Permite comparación directa
- 9 puntos cubren rango completo

#### 3. Tiempo de Simulación (t)
```
t_max = 120.0  (tiempo final)
save_interval = 0.5  (guardado cada 0.5 unidades)
```

**Justificación**:
- t~60: Estado estacionario (basado en N=80)
- t=120: 2× tiempo de relajación (conservador)
- Permite verificar que steady-state no cambia
- Ahorra tiempo vs. t=100 previo

**Snapshots temporales**: 240 puntos (cada 0.5)

#### 4. Realizaciones por (N, e)
```
n_realizations = 10  (mínimo)
```

**Justificación**:
- 10 es suficiente para estadística robusta
- Total runs: 5 N × 9 e × 10 realiz = **450 runs**
- Menor que 20 por economía de tiempo
- Si σ es alta, se pueden agregar más después

### Parámetros Fijos

```toml
[geometry]
a = 2.0  # Semi-eje mayor
b = 1.0  # Semi-eje menor

[simulation]
method = "adaptive"  # Timestep adaptativo
dt_max = 1e-5
dt_min = 1e-10
collision_method = "parallel_transport"
use_parallel = true  # Aprovecha multi-core
tolerance = 1e-6

[particles.random]
E_per_N = 0.32  # Energía por partícula (mismo que antes)
radius = 0.05   # Radio como fracción de b
distribution = "uniform"  # ICs uniformes
```

---

## Matriz de Parámetros

### Total de Runs
```
N_values = 5
e_values = 9
realizations = 10

Total = 5 × 9 × 10 = 450 runs
```

### Estructura del CSV
```csv
run_id,N,e,a,b,E_per_N,radius,seed,t_max,save_interval
1,40,0.0,2.0,1.0,0.32,0.05,1,120.0,0.5
2,40,0.0,2.0,1.0,0.32,0.05,2,120.0,0.5
...
450,120,0.99,2.0,1.0,0.32,0.05,10,120.0,0.5
```

### Estimación de Tiempo

**Por run**:
- N=40: ~5 min
- N=60: ~10 min
- N=80: ~15 min (ya medido)
- N=100: ~25 min (estimado)
- N=120: ~35 min (estimado)

**Promedio ponderado**: ~18 min/run

**Total CPU time**: 450 runs × 18 min = 8100 min = **135 horas**

**Con 24 cores en paralelo**: 135 / 24 = **5.6 horas** ≈ **6 horas**

**Conservador (con overhead)**: **8-10 horas**

### Uso de Disco

**Por run HDF5**:
- N=40: ~10 MB
- N=80: ~20 MB
- N=120: ~30 MB

**Promedio**: ~20 MB/run

**Total**: 450 × 20 MB = **9 GB**

**Conservador**: **10-12 GB**

---

## Análisis Planificados

### 1. Dinámica Temporal R(t), Ψ(t)
- Extraer R(t) y Ψ(t) de cada run
- Ajustar tiempo de relajación: R(t) = R_ss + (R_0 - R_ss)exp(-t/τ)
- Estudiar τ(N, e)
- Verificar t_steady-state < 60 para todos los (N,e)

### 2. Finite-Size Scaling
- R(N, e) para cada e fijo
- Extrapolar R(N→∞, e)
- Identificar correcciones: R(N,e) = R_∞(e) + a/N + b/N²
- Verificar universalidad de β

### 3. Susceptibilidad χ_R
```
χ_R(e) = ⟨R²⟩ - ⟨R⟩² = Var(R)
```
- Para cada (N, e): calcular Var(R) sobre 10 realizaciones
- Plot χ_R vs e para cada N
- Buscar divergencia χ_R ~ (1-e)^(-γ) cerca de e→1
- Relacionar γ con β (teoría de scaling)

### 4. Scaling Collapse
Test de universalidad:
```
R(N,e) / R(N,e_ref) vs (1-e)N^α
```
Si datos colapsan → α caracteriza finite-size scaling

### 5. Entropía S(N,e,t)
- Cómo evoluciona S con N
- ¿S_final escala con N?

---

## Implementación

### Scripts Necesarios

#### 1. Generador de Matriz
```julia
generate_finite_size_scaling_matrix.jl
```
- Genera `parameter_matrix_finite_size_scaling.csv`
- 450 filas con todos los parámetros

#### 2. Launcher
```bash
launch_finite_size_scaling.sh
```
- Lee CSV
- Usa GNU parallel con 24 cores
- Guarda en `results/campaign_finite_size_scaling_TIMESTAMP/`

#### 3. Monitor
```bash
monitor_finite_size_scaling.sh
```
- Cuenta runs completados
- Estima tiempo restante
- Muestra status por (N, e)

#### 4. Analizadores
```julia
analyze_temporal_dynamics.jl      # R(t), Ψ(t), τ(N,e)
analyze_finite_size_scaling.jl    # R(N,e), extrapolación
analyze_susceptibility.jl         # χ_R(N,e)
analyze_scaling_collapse.jl       # Test de universalidad
```

---

## Cronograma

### Día 1: Preparación
- ✅ Diseño de campaña (este documento)
- ⬜ Generar scripts
- ⬜ Test con 3-5 runs
- ⬜ Validar guardado correcto

### Día 2: Ejecución
- ⬜ Lanzar campaña completa (8-10 horas)
- ⬜ Monitorear progreso
- ⬜ Verificar no hay errores

### Día 3-4: Análisis
- ⬜ Análisis temporal R(t), Ψ(t)
- ⬜ Finite-size scaling
- ⬜ Susceptibilidad
- ⬜ Scaling collapse

### Día 5: Resultados
- ⬜ Generar figuras finales
- ⬜ Comparar con N=80
- ⬜ Escribir conclusiones

---

## Validaciones

### Pre-ejecución
- [ ] CSV generado correctamente (450 filas)
- [ ] Parámetros consistentes (E_per_N, radius)
- [ ] Seeds únicos por run
- [ ] Directorio de salida creado

### Durante ejecución
- [ ] Conservación energía aceptable
- [ ] Ningún run cuelga
- [ ] Archivos HDF5 válidos
- [ ] Espacio en disco suficiente

### Post-ejecución
- [ ] 450/450 runs completados
- [ ] Todos los HDF5 leíbles
- [ ] R y Ψ en rangos esperados
- [ ] t_steady-state < 60 verificado

---

## Resultados Esperados

### 1. Universalidad de β
**Hipótesis**: β ≈ 0.65 independiente de N

**Test**: Ajustar R(e) ~ (1-e)^(-β) para cada N
- Si β(N) → β_∞ constante → **Universal** ✓
- Si β(N) varía significativamente → **No universal** ✗

### 2. Correcciones de Tamaño Finito
**Hipótesis**: R(N,e) = R_∞(e) + a(e)/N

**Test**: Plot R vs 1/N para e fijo
- Extrapolación linear → R_∞(e)
- Comparar con R(N=80)

### 3. Divergencia de Susceptibilidad
**Hipótesis**: χ_R ~ (1-e)^(-γ) con γ > 0

**Test**: Log-log plot χ_R vs (1-e)
- Pendiente = -γ
- Comparar γ con β (relaciones de scaling)

### 4. Tiempo de Relajación
**Hipótesis**: τ(N,e) aumenta con N y e

**Test**: Ajustar exponencial a R(t)
- τ(N) ~ N^α (difusión?)
- τ(e) ~ (1-e)^(-δ) (critical slowing down?)

---

## Contingencias

### Si τ > 60 para algunos (N,e)
- Extender t_max a 180 para esos casos
- Re-correr solo runs que no alcanzaron steady-state

### Si 10 realizaciones no son suficientes
- Identificar (N,e) con alta varianza
- Agregar 10 realizaciones más solo para esos
- Total extra: <50 runs

### Si corridas toman más de 10 horas
- Pausar y re-lanzar en batch
- Priorizar e > 0.9 (más interesantes)
- Completar e < 0.9 después

---

## Comparación con Campaña N=80

| Aspecto | N=80 Campaign | Finite-Size Campaign |
|---------|---------------|----------------------|
| Runs | 180 | 450 |
| N valores | 1 (fijo 80) | 5 (40-120) |
| e valores | 9 | 9 |
| Realizaciones | 20 | 10 |
| t_max | 100 | 120 |
| save_interval | variable | 0.5 (uniforme) |
| Tiempo CPU | ~45 horas | ~135 horas |
| Tiempo real (24 cores) | ~2 horas | ~6 horas |
| Disco | ~4 GB | ~10 GB |

**Ventajas nueva campaña**:
- ✅ Finite-size scaling
- ✅ Verificación de universalidad
- ✅ Mejor resolución temporal (uniform save_interval)
- ✅ Tiempo optimizado (120 vs 100)

**Costo**:
- ❌ Menos realizaciones por punto (10 vs 20)
- ❌ Más tiempo total de CPU (×3)

**Mitigación**:
- 10 realizaciones es suficiente si σ/√10 es pequeño
- Basado en N=80: σ/√20 ya es pequeño → σ/√10 aceptable
- Si no, agregar realizaciones después

---

## Output Final Esperado

### Archivos
```
results/campaign_finite_size_scaling_YYYYMMDD_HHMMSS/
├── parameter_matrix.csv (450 rows)
├── run_*_N*_e*_seed*.h5 (450 files, ~10 GB)
├── summary_by_N_and_e.csv
├── temporal_dynamics_all.csv (R(t), Ψ(t) por run)
├── finite_size_scaling_results.csv (R_∞(e), correcciones)
├── susceptibility_results.csv (χ_R(N,e))
└── scaling_collapse_analysis.csv
```

### Figuras (estimado: 15-20)
1. R(t) vs t para diferentes (N,e)
2. Ψ(t) vs t
3. τ vs N para cada e
4. τ vs e para cada N
5. R vs N para cada e (finite-size scaling)
6. R_∞(e) extrapolado
7. β(N) vs N (test de universalidad)
8. χ_R vs e para cada N
9. χ_R vs (1-e) log-log (divergencia)
10. Scaling collapse R/R_ref vs (1-e)N^α
11. S(N,e) final state
12. Comparación N=80 vs N=40,60,100,120
13. Phase diagram N-e (color = R)
14. Time to steady-state vs (N,e)
15. Energy conservation quality vs (N,e)

---

## Conclusión

Esta campaña nos permitirá:
1. ✅ Verificar universalidad de β
2. ✅ Cuantificar correcciones de tamaño finito
3. ✅ Medir susceptibilidad y buscar divergencia
4. ✅ Caracterizar dinámica temporal τ(N,e)
5. ✅ Validar t_steady-state ~ 60 para optimización

**Status**: Diseño completo, listo para implementación

**Próximo paso**: Generar scripts y lanzar campaña
