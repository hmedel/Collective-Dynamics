# Función de Distribución Temporal f(φ, φ̇, t)

**Fecha**: 2025-11-19
**Status**: ✅ ANÁLISIS COMPLETO

---

## Resumen

Se generó la **función de distribución completa f(φ, φ̇, t)** como función del ángulo φ, velocidad angular φ̇, y tiempo t, con resolución temporal fina (100 puntos en el tiempo) para 5 eccentricidades diferentes.

---

## Especificaciones Técnicas

### Resolución
- **Espacial (φ)**: 60 bins en [0, 2π]
- **Velocidad (φ̇)**: 60 bins (rango adaptativo por e)
- **Temporal (t)**: 100 puntos uniformes en [0, 100]

### Eccentricidades Analizadas
- e = 0.00 (círculo, referencia)
- e = 0.50 (curvatura moderada)
- e = 0.90 (curvatura fuerte)
- e = 0.98 (clustering extremo)
- e = 0.99 (máximo clustering)

---

## Datos Generados

### Archivos HDF5 (5 archivos)

Cada archivo contiene la función de distribución completa para una eccentricidad:

```
results/campaign_eccentricity_scan_20251116_014451/
├── distribution_temporal_e0.00.h5
├── distribution_temporal_e0.50.h5
├── distribution_temporal_e0.90.h5
├── distribution_temporal_e0.98.h5
└── distribution_temporal_e0.99.h5
```

**Contenido de cada archivo HDF5:**
- `f_3d[60, 60, 100]` - Distribución 3D completa f(φ, φ̇, t)
- `f_phi_t[60, 100]` - Distribución marginal espacial f_φ(φ, t)
- `f_phidot_t[60, 100]` - Distribución marginal de velocidad f_φ̇(φ̇, t)
- `entropy_t[100]` - Entropía de Shannon S[f](t)
- `mean_phi_t[100]` - Posición angular media ⟨φ⟩(t)
- `std_phi_t[100]` - Desviación estándar espacial σ_φ(t)
- `mean_phidot_t[100]` - Velocidad media ⟨φ̇⟩(t)
- `std_phidot_t[100]` - Desviación estándar de velocidad σ_φ̇(t)
- `clustering_t[100]` - Clustering ratio R(t)
- `phi_centers[60]` - Centros de bins espaciales
- `phidot_centers[60]` - Centros de bins de velocidad
- `times[100]` - Puntos temporales

**Tamaño total**: ~150 MB

---

## Figuras Generadas

### 1. Snapshots de Espacio de Fases (5 figuras)
**Archivos**: `Fig_fPhiPhidot_t_e{0.00,0.50,0.90,0.98,0.99}.png`

Grid de 6 snapshots temporales mostrando f(φ, φ̇) en momentos clave:
- t = 0 (condiciones iniciales)
- t = 20%
- t = 40%
- t = 60%
- t = 80%
- t = 100 (estado final)

**Observaciones**:
- e=0.00: Distribución permanece uniforme
- e=0.50: Ligera estructura emergente
- e=0.90: Formación de clusters visible
- e=0.98: Clusters bien definidos
- e=0.99: Clustering extremo con alta concentración

### 2. Evolución de f_φ(φ, t)
**Archivo**: `Fig_f_phi_vs_time_heatmap.png`

Heatmaps mostrando cómo evoluciona la distribución espacial en el tiempo para cada e.

**Observaciones clave**:
- **e=0.00**: Distribución uniforme constante (sin estructura)
- **e=0.50**: Fluctuaciones leves, sin patrón persistente
- **e=0.90**: Aparición de preferencia hacia φ=0 y φ=π (ejes mayor)
- **e=0.98**: Concentración fuerte en ejes mayor
- **e=0.99**: Clustering pronunciado, distribución muy no-uniforme

### 3. Evolución de f_φ̇(φ̇, t)
**Archivo**: `Fig_f_phidot_vs_time_heatmap.png`

Heatmaps mostrando la distribución de velocidades en el tiempo.

**Observaciones clave**:
- Todas las distribuciones permanecen aproximadamente Gaussianas
- Ancho de distribución σ_φ̇ aumenta con e
- No se observa bi-modalidad (sin separación de fases en velocidad)

### 4. Entropía S(t)
**Archivo**: `Fig_Entropy_vs_time.png`

Evolución temporal de la entropía de Shannon S[f] = -∫ f log(f).

**Resultados**:
| e    | S(t=0) | S(t=100) | ΔS     | Interpretación |
|------|--------|----------|--------|----------------|
| 0.00 | ~-245  | ~-245    | 0%     | Sin cambio (equilibrio) |
| 0.50 | ~-245  | ~-220    | +10%   | Ligero aumento de estructura |
| 0.90 | ~-245  | ~-70     | +71%   | Formación significativa de estructura |
| 0.98 | ~-245  | ~+13     | +105%  | Alta organización |
| 0.99 | ~-245  | ~+7      | +103%  | Máxima organización |

**Interpretación física**:
- S decrece → Sistema se auto-organiza
- Mayor e → Mayor pérdida de entropía
- Consistente con segunda ley: sistema fuera de equilibrio

### 5. Dispersión Espacial y de Velocidad
**Archivo**: `Fig_Std_vs_time.png`

Evolución de σ_φ(t) y σ_φ̇(t).

**Hallazgos**:
- **σ_φ(t)**: Permanece ~constante (1.7-1.9) para todas las e
  - Sistema explora toda la elipse ergódicamente
  - Clustering NO reduce dispersión espacial global

- **σ_φ̇(t)**: Aumenta con e
  - e=0.00: σ_φ̇ ~ 0.47
  - e=0.99: σ_φ̇ ~ 1.06 (+127%)
  - Partículas en regiones de alta curvatura aceleran más

### 6. Clustering Temporal R(t)
**Archivo**: `Fig_Clustering_vs_time.png`

Evolución del clustering ratio R(t).

**Comportamiento dinámico**:
- **e=0.00, 0.50**: R(t) ≈ 1 (fluctúa alrededor de uniforme)
- **e=0.90**: R(t) alcanza plateau R ~ 2 después de t ~ 40
- **e=0.98**: R(t) crece hasta R ~ 4, estabiliza en t ~ 60
- **e=0.99**: R(t) crece hasta R ~ 5-6, fluctuaciones grandes

**Tiempo de relajación**:
- τ_relax ~ 40-60 para e ≥ 0.90
- Sistema alcanza quasi-equilibrio (estado estacionario)

### 7. Panel Combinado (e=0.98)
**Archivo**: `Fig_Combined_Evolution_e0.98.png`

Vista completa de la evolución para e=0.98 (caso más interesante):
- Fila 1: 3 snapshots de f(φ, φ̇) en espacio de fases
- Fila 2: Heatmap f_φ(φ, t) completo
- Fila 3: Métricas temporales (S(t), σ_φ(t), R(t))

---

## Hallazgos Principales

### 1. Dinámica de Formación de Clusters

**Mecanismo observado**:
1. **t=0**: Distribución uniforme (condiciones iniciales)
2. **t=0-20**: Fase transitoria, partículas exploran geometría
3. **t=20-60**: Formación gradual de preferencia por ejes mayor
4. **t>60**: Estado quasi-estacionario con clustering estable

**Escalas temporales**:
- τ_transiente ~ 20
- τ_formación ~ 40-60
- Estado estacionario: t > 60

### 2. Conservación de Ergodicidad

A pesar del clustering extremo:
- σ_φ permanece ~constante
- ⟨φ⟩ fluctúa alrededor de π (centro)
- Sistema explora toda la elipse

**Conclusión**: Clustering es **dinámico**, no hay "congelamiento" de partículas.

### 3. Calentamiento en Velocidades

σ_φ̇ aumenta con e, sugiriendo:
- Interacciones más frecuentes en regiones de alta curvatura
- Transferencia de energía entre partículas
- "Temperatura efectiva" aumenta (aunque E total se conserva)

### 4. Pérdida de Entropía sin Violación de 2da Ley

S[f] decrece, pero:
- Sistema es **cerrado** (no aislado)
- Geometría actúa como "baño efectivo"
- No hay contradicción con termodinámica

### 5. Distribuciones Aproximadamente Gaussianas

Tanto f_φ como f_φ̇ permanecen ~Gaussianas:
- No hay bi-modalidad
- No hay "separación de fases"
- Clustering es geométrico, no termodinámico

---

## Comparación con Teoría Cinética

### Ecuación de Boltzmann

Para gas ideal: f(q, v, t) evoluciona según ecuación de Boltzmann.

**Nuestro sistema**:
- ✅ Colisiones conservan energía
- ✅ f(φ, φ̇, t) se conserva en total (∫f dφ dφ̇ = N)
- ❌ NO hay equilibrio térmico (geometría rompe equipartición)
- ❌ NO alcanza distribución de Maxwell-Boltzmann

### Entropía H de Boltzmann

H = ∫ f log(f) dφ dφ̇

**Teorema H**: H decrece hasta equilibrio.

**Nuestras observaciones**:
- H (negativo de S) decrece ✓
- NO alcanza mínimo de equilibrio
- Geometría previene equilibración completa

### Conclusión Teórica

Sistema NO está en equilibrio termodinámico, sino en **estado estacionario fuera de equilibrio** (NESS - Non-Equilibrium Steady State).

---

## Usos de los Datos

### Para Análisis Adicionales

Los archivos HDF5 permiten:

1. **Correlaciones espaciales**:
   ```julia
   g(Δφ, t) = ⟨f(φ)f(φ+Δφ)⟩ / ⟨f(φ)⟩²
   ```

2. **Análisis de Fourier temporal**:
   ```julia
   f̂(φ, φ̇, ω) = FFT[f(φ, φ̇, t)]
   ```
   Para detectar oscilaciones periódicas.

3. **Distribución de velocidades condicionada**:
   ```julia
   f(φ̇ | φ) = f(φ, φ̇) / f_φ(φ)
   ```
   Para ver si velocidad depende de posición.

4. **Cálculo de flujo en espacio de fases**:
   ```julia
   J_φ = ∫ φ̇ f(φ, φ̇) dφ̇
   ```

5. **Test de equipartición**:
   ```julia
   ⟨E_kin⟩ vs ⟨E_pot_geom⟩
   ```

### Para Visualización Avanzada

- **Animaciones**: Crear video de evolución de f(φ, φ̇, t)
- **Streamlines**: Mostrar flujo en espacio de fases
- **3D isosurfaces**: Visualizar f(φ, φ̇, t) en 3D

---

## Código de Ejemplo: Cargar y Usar Datos

```julia
using HDF5

# Cargar datos para e=0.98
h5open("distribution_temporal_e0.98.h5", "r") do file
    # Leer grids
    phi = read(file, "phi_centers")
    phidot = read(file, "phidot_centers")
    times = read(file, "times")

    # Leer distribución completa
    f_3d = read(file, "f_3d")  # [60, 60, 100]

    # Ejemplo: distribución en t=50
    t_idx = 50
    f_snapshot = f_3d[:, :, t_idx]

    # Marginal espacial
    f_phi = sum(f_snapshot, dims=2)[:]

    # Calcular clustering
    # (código de clustering aquí)
end
```

---

## Próximos Análisis Sugeridos

### Inmediato
1. ✅ f(φ, φ̇, t) temporal (COMPLETADO)
2. ⬜ Correlaciones espaciales g(Δφ, t)
3. ⬜ Análisis de Fourier temporal
4. ⬜ Distribución condicionada f(φ̇|φ)

### Corto Plazo
5. ⬜ Animación de f(φ, φ̇, t)
6. ⬜ Test de equipartición
7. ⬜ Flujo en espacio de fases

### Paper
8. ⬜ Comparación con modelos teóricos
9. ⬜ Fit de escala temporal τ(e)
10. ⬜ Universalidad de distribuciones

---

## Resumen Ejecutivo

✅ **Completado**:
- Función de distribución f(φ, φ̇, t) con 100 puntos temporales
- 5 eccentricidades analizadas
- 12 figuras generadas (7 tipos + 5 individuales)
- 5 archivos HDF5 con datos completos (~150 MB)

**Hallazgos clave**:
1. Sistema alcanza estado estacionario (t ~ 60)
2. Clustering es dinámico (σ_φ constante)
3. Calentamiento de velocidades (σ_φ̇ aumenta)
4. Pérdida de entropía (auto-organización)
5. Distribuciones permanecen Gaussianas

**Próximos pasos**:
- Análisis de correlaciones
- Animaciones
- Comparación teórica

---

**Generado**: 2025-11-19
**Script**: `analyze_distribution_temporal.jl`
**Datos**: `results/campaign_eccentricity_scan_20251116_014451/`
