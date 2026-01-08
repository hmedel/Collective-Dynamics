# Plan Experimental para Publicación de Alto Impacto

**Fecha:** 2025-11-16
**Objetivo:** Physical Review Letters o journal equivalente

---

## Concepto Central

**"Geometry-Induced Spontaneous Clustering in Curved Manifolds"**

### Mensaje Clave

La curvatura inhomogénea de una variedad actúa como un "baño térmico efectivo" que induce clustering espontáneo desde distribuciones uniformes, **sin necesidad de interacciones atractivas**.

**Novedad**:
- Clustering puramente geométrico (no por interacciones)
- Mecanismo: φ̇ ∝ 1/g → tiempo de residencia τ(φ) ∝ g(φ)
- Distribución estacionaria: ρ(φ) ∝ g(φ) (análogo a Boltzmann geométrico)

---

## Experimentos Propuestos

### Experimento 1: Eccentricity Scan ⭐ (Más Importante)

**Objetivo**: Demostrar que clustering escala con excentricidad (curvatura)

**Parámetros**:
```
Geometría:
  - Eccentricities: e = [0.0, 0.3, 0.5, 0.7, 0.8, 0.9, 0.95, 0.98, 0.99]
  - Semi-eje mayor: a = 3.17 (fijo)
  - Semi-eje menor: b = a·√(1-e²)

Sistema:
  - N = 40-80 partículas
  - E/N = 0.32 (fijo)
  - ICs: UNIFORMES (crítico para estadística)
  - Realizaciones: 10-20 por cada e (diferentes seeds)

Simulación:
  - t_max = 200s
  - dt_max = 1e-5
  - use_projection = true
  - projection_interval = 100
  - save_interval = 0.5s
```

**Métricas**:
1. **Clustering ratio**:
   ```
   R(t) = ρ_mayor(t) / ρ_menor(t)

   donde:
   - ρ_mayor = fracción en bins [0°±22.5°, 180°±22.5°]
   - ρ_menor = fracción en bins [90°±22.5°, 270°±22.5°]
   ```

2. **Distribución estacionaria**:
   ```
   ρ_eq(φ) = promedio de ρ(φ,t) para t ∈ [150s, 200s]
   ```

3. **Tiempo de relajación**:
   ```
   τ_relax = tiempo para alcanzar 90% de R_eq
   ```

4. **Correlación curvatura-densidad**:
   ```
   Calcular R² entre g(φ) y ρ_eq(φ)
   ```

**Hipótesis**:
- e=0 (círculo): R_eq ≈ 1 (no clustering)
- e→1 (elipse extrema): R_eq >> 1 (clustering fuerte)
- Scaling law: R_eq ∝ e^α (determinar α)

---

### Experimento 2: Energy Scan

**Objetivo**: Verificar dependencia del clustering con energía cinética

**Parámetros**:
```
Geometría:
  - e = 0.98 (fijo, high eccentricity)
  - a = 3.17

Sistema:
  - N = 40-80
  - E/N = [0.1, 0.32, 1.0, 3.0, 10.0]
  - ICs: UNIFORMES
  - Realizaciones: 10-20 por cada E/N

Simulación:
  - t_max = 200s
  - Resto igual que Exp. 1
```

**Métricas**: Mismas que Experimento 1

**Hipótesis**:
- E/N bajo → clustering fuerte (partículas lentas, sensibles a curvatura)
- E/N alto → clustering débil (partículas rápidas, menos tiempo en cada región)
- Posible scaling: R_eq ∝ (E/N)^(-β)

---

### Experimento 3: Tiempo de Residencia vs Curvatura

**Objetivo**: Confirmar cuantitativamente τ(φ) ∝ g(φ)

**Método**:
1. Usar datos de Experimento 1 (e=0.98, E/N=0.32)
2. Dividir elipse en N_bins = 72 bins angulares (Δφ = 5°)
3. Para cada trayectoria, medir tiempo de residencia:
   ```
   τ_i = Σ_t [1 si φ(t) ∈ bin_i, 0 si no]
   ```
4. Calcular g_φφ(φ_i) teórico en centro de cada bin
5. Plot: τ(φ) vs g(φ)

**Predicción**:
- Correlación lineal perfecta (R² > 0.95)
- Pendiente relacionada con energía: τ ∝ g/E

---

### Experimento 4: Distribución Estacionaria

**Objetivo**: Verificar ρ_eq(φ) ∝ g(φ) (Boltzmann geométrico)

**Método**:
1. Usar datos de Experimento 1
2. Para cada e, calcular:
   ```
   ρ_eq(φ_i) = ⟨N_i⟩ / (N·Δφ)

   donde ⟨N_i⟩ = número promedio de partículas en bin_i
                  promediado sobre t ∈ [150s, 200s]
   ```
3. Normalizar g(φ):
   ```
   g_norm(φ) = g(φ) / ∫_0^(2π) g(φ') dφ'
   ```
4. Comparar ρ_eq(φ) vs g_norm(φ)

**Predicción**:
```
ρ_eq(φ) / g(φ) ≈ const
```

---

## Análisis Estadístico

### Para Cada Experimento:

1. **Múltiples realizaciones** (10-20 seeds diferentes)
2. **Promedios y desviaciones estándar**:
   ```
   ⟨R⟩ ± σ_R
   ⟨τ_relax⟩ ± σ_τ
   ```
3. **Tests estadísticos**:
   - ANOVA para comparar diferentes e o E/N
   - Regresión lineal para scaling laws
   - R² para correlaciones

---

## Figuras para el Paper

### Figure 1: Main Result - Evolution & Clustering
```
Panel A: Heatmap de densidad ρ(φ,t)
         Mostrar evolución temporal desde uniforme → clustered
         Eje X: tiempo (0-200s)
         Eje Y: φ (0-2π)
         Color: densidad normalizada

Panel B: Clustering ratio R(t) vs tiempo
         Curvas para e = [0.0, 0.5, 0.9, 0.98]
         Mostrar saturación a valores diferentes
         Incluir barras de error (±σ_R)

Panel C: Distribución angular ρ(φ) en equilibrio
         Para e=0.98
         Comparar con g_norm(φ) (línea superpuesta)
         Mostrar bins de eje mayor y menor
```

### Figure 2: Scaling Laws
```
Panel A: R_eq vs eccentricity e
         Log-log plot para ver scaling
         Fit: R_eq = A·e^α
         Reportar α ± δα

Panel B: τ_relax vs e
         Mostrar cómo tiempo para alcanzar equilibrio depende de e

Panel C: Residence time correlation
         τ(φ) vs g(φ) para e=0.98
         Demostrar correlación lineal perfecta
         Reportar R² > 0.95
```

### Figure 3: Energy Dependence
```
Panel A: R_eq vs E/N para e=0.98
         Log-log plot
         Fit: R_eq = B·(E/N)^(-β)

Panel B: Data collapse
         R_eq·(E/N)^β vs e
         Todas las curvas colapsan → universal scaling

Panel C: Phase diagram
         Clustering "strength" en plano (e, E/N)
         Heatmap de R_eq
```

### Figure 4: Validation & Mechanism
```
Panel A: Energy conservation
         ΔE/E₀ vs tiempo
         Demostrar ΔE/E₀ < 1e-4 (excelente conservación)

Panel B: Comparison θ vs φ
         Conservación ANTES (parametrización paramétrica θ)
         vs DESPUÉS (parametrización polar φ)
         Mostrar mejora ~100,000×

Panel C: Mechanism diagram
         Esquema mostrando:
         - g(φ) (métrica)
         - φ̇(φ) ∝ 1/g
         - τ(φ) ∝ g
         - ρ_eq(φ) ∝ g
```

---

## Estructura del Paper (PRL)

### Title
**"Geometry-Induced Spontaneous Clustering on Curved Manifolds"**

### Abstract (150 palabras)
```
We report spontaneous clustering in a system of hard particles confined
to elliptic manifolds, emerging purely from geometric effects without
attractive interactions. Using symplectic integrators that preserve the
Riemannian structure, we demonstrate that particles accumulate in regions
of high metric curvature g_φφ, with residence time τ(φ) ∝ g(φ). The
stationary distribution follows ρ_eq(φ) ∝ g(φ), analogous to a geometric
Boltzmann distribution. Clustering strength scales as R ∝ e^α with
eccentricity e, vanishing for circles (e=0) and diverging as e→1. This
mechanism represents a new class of emergent collective phenomena driven
by manifold geometry rather than interaction potentials, with implications
for understanding confinement effects in curved spaces ranging from
biological membranes to cosmological settings.
```

### Introduction
- Collective dynamics on manifolds (biological, cosmological contexts)
- Previous work: interactions drive clustering
- Our finding: **geometry alone** induces clustering
- Connection to differential geometry and statistical mechanics

### Model & Methods
- Hamiltonian on Riemannian manifold
- Forest-Ruth symplectic integrator
- Parallel transport during collisions
- Energy conservation validation (ΔE/E₀ < 1e-4)

### Results
1. **Clustering from uniform ICs** (Fig 1)
2. **Scaling laws** (Fig 2)
3. **Energy dependence** (Fig 3)
4. **Mechanism validation** (Fig 4)

### Discussion
- Geometric Boltzmann distribution
- Comparison with interaction-driven clustering
- Universality of mechanism
- Applications: biology, soft matter, cosmology

### Conclusions
- First demonstration of pure geometric clustering
- Quantitative prediction: ρ_eq ∝ g
- Opens new direction: geometric statistical mechanics

---

## Timeline de Implementación

### Semana 1: Setup
- [ ] Implementar generador de ICs uniformes (HECHO ✓)
- [ ] Crear scripts para eccentricity scan
- [ ] Crear scripts para energy scan
- [ ] Setup paralelización (GNU parallel)

### Semana 2-3: Simulaciones
- [ ] Experimento 1: Eccentricity scan (9 valores × 20 realizaciones = 180 runs)
- [ ] Experimento 2: Energy scan (5 valores × 20 realizaciones = 100 runs)
- [ ] Total: ~280 simulaciones (~100s cada una)

### Semana 4: Análisis
- [ ] Calcular métricas (R, τ_relax, correlaciones)
- [ ] Fitting de scaling laws
- [ ] Tests estadísticos
- [ ] Experimento 3: Tiempo de residencia
- [ ] Experimento 4: Distribución estacionaria

### Semana 5: Figuras
- [ ] Generar todas las figuras del paper
- [ ] Verificar calidad (publication-ready)
- [ ] Escribir captions

### Semana 6: Escritura
- [ ] Draft completo del paper
- [ ] Supplementary material
- [ ] Referencias

---

## Recursos Computacionales

### Estimación:
```
- 280 simulaciones × 100s cada una
- ~10⁷ pasos por simulación
- Con N=80, ~45 min por run (24 cores)
- Tiempo total: ~280 × 0.75h = 210 horas
- Con 24 cores en paralelo: ~9 horas de wall time
```

### Storage:
```
- ~500 MB por simulación (HDF5 comprimido)
- Total: ~140 GB
```

---

## Criterios de Éxito para PRL

1. ✅ **Novedad**: Clustering puramente geométrico (no reportado antes)
2. ✅ **Cuantitativo**: Scaling laws con R² > 0.95
3. ✅ **Universal**: Funciona para rango amplio de parámetros
4. ✅ **Robusto**: Estadística con 10-20 realizaciones
5. ✅ **Validado**: Conservación excelente (ΔE/E₀ < 1e-4)
6. ✅ **Impacto**: Aplicable a múltiples campos (física, biología, cosmología)

---

## Próximos Pasos Inmediatos

1. **Crear script para eccentricity scan**
   - Generar matriz de parámetros
   - Setup GNU parallel para 24 cores

2. **Validar con e=0 (círculo)**
   - Confirmar R_eq ≈ 1 (control negativo)

3. **Correr piloto completo**
   - e = [0.0, 0.5, 0.98] × 5 realizaciones
   - Verificar que todo funciona

4. **Launch full campaign**
   - 280 simulaciones en paralelo
