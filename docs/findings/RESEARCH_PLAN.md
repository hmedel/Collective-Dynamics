# Plan de Investigación Científica: Dinámica Colectiva en Elipses

**Fecha**: 2025-11-14
**Sistema**: Parametrización polar (φ) con projection methods
**Objetivo**: Estudiar fenómenos físicos en sistemas de partículas confinadas a variedades curvas

---

## Motivación Científica

El usuario observó **compactificación** en el espacio fase (φ, φ̇) durante simulaciones anteriores de 60 segundos. Este fenómeno sugiere posibles efectos de:

1. **Curvatura variable**: κ(φ) varía entre κ_max = 2.0 (φ=0°) y κ_min = 0.25 (φ=90°)
2. **Confinamiento efectivo**: Partículas pueden preferir regiones de alta/baja curvatura
3. **Termalización**: Redistribución de energía a través de colisiones
4. **Conservación restricta**: Solo E conservada (no P_φ) → dinámica no-trivial

---

## Experimentos Planificados

### Experimento 1: Simulación Larga (100 segundos)

**Objetivo**: Verificar conservación y estabilidad numérica a largo plazo

**Parámetros**:
- N = 40 partículas
- Tiempo = 100 segundos (10x más que tests anteriores)
- a, b = 2.0, 1.0
- Projection: Activado (cada 100 pasos)
- dt_max = 1e-5

**Métricas**:
- ΔE/E₀ vs tiempo
- Número total de colisiones
- Distribución final de energías por partícula
- Tiempo de ejecución

**Pregunta**: ¿Se mantiene conservación < 10⁻⁸ después de 100s y ~20,000 colisiones?

---

### Experimento 2: Análisis de Espacio Fase

**Objetivo**: Caracterizar compactificación y estructura del espacio fase

**Análisis**:

1. **Trayectorias en (φ, φ̇)**:
   - Graficar todas las trayectorias
   - Identificar regiones densas vs vacías
   - Medir dispersión σ_φ, σ_φ̇ vs tiempo

2. **Unwrapped Phase Space**:
   - φ_unwrapped = φ + 2πN (número de vueltas)
   - Visualizar trayectorias continuas
   - Detectar drift neto en φ

3. **Distribuciones**:
   - Histograma de φ (distribución espacial)
   - Histograma de φ̇ (distribución de velocidades)
   - Evolución temporal de ambos

**Preguntas**:
- ¿Se compactan las trayectorias con el tiempo?
- ¿Hay regiones preferidas en φ?
- ¿La distribución de φ̇ se termaliza (Maxwell-Boltzmann)?

---

### Experimento 3: Correlación con Curvatura

**Objetivo**: Verificar si partículas prefieren regiones de alta/baja curvatura

**Análisis**:

1. **Densidad vs Curvatura**:
   - Dividir elipse en bins de φ
   - Calcular curvatura κ(φ) en cada bin
   - Medir densidad de partículas ρ(φ) vs tiempo
   - Correlación: ρ(φ) ∝ κ(φ)^α ?

2. **Colisiones vs Curvatura**:
   - Mapear ubicación de cada colisión en φ
   - Histograma de colisiones por región
   - ¿Más colisiones en regiones de alta curvatura?

3. **Energía Cinética vs Curvatura**:
   - Medir <E_k>(φ) (energía promedio en cada región)
   - Correlación con κ(φ)?

**Pregunta**: ¿La curvatura κ(φ) influye en la distribución espacial o energética de partículas?

---

### Experimento 4: Termalización

**Objetivo**: Estudiar redistribución de energía y relajación a equilibrio

**Análisis**:

1. **Distribución de Energías Individuales**:
   - Inicializar: Todas con E_i ≈ E_0/N (uniforme)
   - Medir: Evolución de distribución P(E_i) vs tiempo
   - Comparar con: Maxwell-Boltzmann (termalización completa)

2. **Tiempo de Relajación**:
   - Medir: Varianza σ²_E vs tiempo
   - Definir: τ_relax = tiempo para alcanzar equilibrio
   - Dependencia con N?

3. **Tasa de Colisión**:
   - Medir: Colisiones por segundo vs tiempo
   - ¿Se estabiliza o cambia?

**Pregunta**: ¿El sistema termaliza? ¿En qué escala de tiempo?

---

### Experimento 5: Dependencia con N

**Objetivo**: Estudiar escalado con número de partículas

**Serie**: N = 10, 20, 40, 80

Para cada N:
- Misma densidad: radio ∝ 1/√N
- Mismo tiempo simulado: 10 segundos
- Medir:
  - Conservación ΔE/E₀
  - Colisiones totales
  - Tiempo de ejecución
  - Tiempo de termalización τ_relax

**Pregunta**: ¿Cómo escala el sistema con N?

---

### Experimento 6: Dependencia con Excentricidad

**Objetivo**: Efecto de curvatura variable

**Serie**: a/b = 1.0 (círculo), 2.0, 3.0, 5.0

Para cada a/b:
- N = 40 partículas
- Tiempo = 10 segundos
- Medir:
  - Conservación
  - Compactificación en espacio fase
  - Correlación densidad-curvatura
  - Tasa de colisiones

**Preguntas**:
- ¿Mayor excentricidad → mayor compactificación?
- ¿Círculo (κ constante) se comporta diferente?

---

### Experimento 7: Condiciones Iniciales

**Objetivo**: Sensibilidad a distribución inicial

**Casos**:

1. **Uniforme en φ, φ̇**:
   - φ_i ~ Uniform(0, 2π)
   - φ̇_i ~ Uniform(-1, 1)

2. **Localizado en φ**:
   - Todas las partículas en φ ∈ [0, π/4]
   - Velocidades aleatorias

3. **Bi-modal en φ̇**:
   - Mitad con φ̇ > 0 (horario)
   - Mitad con φ̇ < 0 (antihorario)

**Pregunta**: ¿El estado final depende de condiciones iniciales? ¿Hay atractor único?

---

## Herramientas de Análisis Necesarias

### 1. Análisis de Espacio Fase

```julia
"""
Analiza espacio fase (φ, φ̇) y genera plots.
"""
function analyze_phase_space(data, output_dir)
    # 1. Plot trayectorias
    # 2. Histogramas φ, φ̇
    # 3. Densidad 2D
    # 4. Unwrapped trajectories
    # 5. Dispersión vs tiempo
end
```

### 2. Análisis de Curvatura

```julia
"""
Correlaciona densidad de partículas con curvatura.
"""
function analyze_curvature_correlation(data, a, b)
    # 1. Dividir en bins de φ
    # 2. Calcular κ(φ) por bin
    # 3. Medir ρ(φ, t)
    # 4. Correlación ρ vs κ
end
```

### 3. Análisis de Termalización

```julia
"""
Estudia redistribución de energía.
"""
function analyze_thermalization(data)
    # 1. Distribución P(E_i) vs tiempo
    # 2. Varianza σ²_E vs tiempo
    # 3. Comparar con Maxwell-Boltzmann
    # 4. Calcular τ_relax
end
```

### 4. Estadísticas de Colisiones

```julia
"""
Analiza ubicación y frecuencia de colisiones.
"""
function analyze_collision_statistics(data, a, b)
    # 1. Histograma espacial de colisiones
    # 2. Tasa de colisión vs tiempo
    # 3. Mapa de densidad de colisiones
end
```

---

## Cronograma de Ejecución

### Sesión 1: Simulación Larga (HOY)

1. ✅ Crear research plan
2. ⏳ Ejecutar simulación 100s
3. ⏳ Verificar conservación
4. ⏳ Análisis preliminar

### Sesión 2: Análisis de Espacio Fase

1. Crear herramientas de análisis
2. Generar plots de trayectorias
3. Estudiar compactificación
4. Documentar hallazgos

### Sesión 3: Curvatura y Termalización

1. Implementar análisis de correlación
2. Estudiar termalización
3. Calcular tiempos característicos

### Sesión 4: Estudios Paramétricos

1. Variar N (escalabilidad)
2. Variar a/b (excentricidad)
3. Variar condiciones iniciales
4. Síntesis de resultados

---

## Resultados Esperados

### Hipótesis Preliminares

1. **Conservación a largo plazo**: ΔE/E₀ < 10⁻⁷ después de 100s (projection methods mantienen conservación)

2. **Compactificación**: Dispersión σ_φ̇ disminuye con tiempo (termalización)

3. **Correlación con curvatura**: Densidad ρ(φ) puede ser NO uniforme, con preferencia por regiones de curvatura específica

4. **Termalización**: Distribución P(E_i) se aproxima a Maxwell-Boltzmann después de τ_relax ~ 10-50 segundos

5. **Escalado con N**: Tiempo de termalización τ_relax ∝ 1/N (más partículas → más colisiones → termalización más rápida)

### Posibles Descubrimientos

- **Segregación espacial**: Partículas se acumulan en regiones de curvatura específica
- **Estados metaestables**: Sistema puede quedar atrapado en configuraciones quasi-estables
- **Efectos de memoria**: Condiciones iniciales pueden influir en estado final (no-ergódico)
- **Transiciones de fase**: Cambio cualitativo en comportamiento al variar parámetros

---

## Publicación Potencial

### Título Tentativo

"Collective Dynamics on Curved Manifolds: Curvature Effects and Thermalization in Elliptical Confinement"

### Contribuciones

1. **Metodológica**: Projection methods para conservación exacta en variedades curvas
2. **Numérica**: Comparación θ vs φ parametrization (2x speedup)
3. **Física**: Caracterización de efectos de curvatura en dinámica colectiva
4. **Computacional**: Framework verificado para simulaciones en variedades

---

## Recursos Computacionales

**Por simulación**:
- 40 partículas, 100s: ~5 minutos
- 80 partículas, 100s: ~20 minutos (estimado)

**Total estimado** (todos los experimentos):
- ~10-15 simulaciones
- ~2-3 horas de cómputo total
- Factible en una sesión de trabajo

---

**Próximo paso**: Ejecutar Experimento 1 (simulación 100s)
