# Concepto: E/N como Baño Térmico Efectivo (No Termalización)

**Date**: 2025-11-15
**Context**: Collective dynamics on elliptical manifolds
**Key Distinction**: Sistema determinístico con transiciones de fase fuera de equilibrio

---

## La Distinción Crucial

### ❌ Lo que NO es nuestro sistema

**NO es un sistema termalizado**:
- No hay termostato (no hay acoplamiento a baño térmico real)
- No hay fluctuaciones estocásticas (es completamente determinístico)
- No está en equilibrio termodinámico
- La distribución de velocidades NO es Boltzmanniana (inicialmente)

**Distribución inicial de velocidades**:
```
φ̇_inicial ~ Uniform[-v_max, v_max]  (no φ̇ ~ exp(-E/kT))
```

Esto es una **caja plana**, no una distribución térmica gaussiana.

### ✅ Lo que SÍ es nuestro sistema

**Es un sistema fuera de equilibrio con transiciones de fase**:
- Determinístico microcanónico (E_total conservado)
- Exhibe clustering espontáneo (ruptura de simetría)
- Muestra timescales característicos (τ_cluster, τ_nucleation)
- Comportamiento tipo fase: gas → líquido → cristal
- **Driven by collisions, not thermal fluctuations**

**Energía inicial E/N actúa como**:
```
"Baño térmico efectivo" = Energía cinética inicial por partícula
```

No es temperatura real, pero **controla la actividad del sistema**.

---

## Analogía: Baño Térmico Efectivo

### Concepto Físico

En sistemas termodinámicos:
```
Baño térmico real:
  - Intercambia energía con el sistema
  - Fija temperatura T
  - Genera fluctuaciones δE ~ √(k_B T)
```

En nuestro sistema:
```
"Baño térmico efectivo":
  - Energía inicial fija "nivel de actividad"
  - E/N permanece constante (microcanónico)
  - Colisiones redistribuyen energía entre partículas
  - Sistema evoluciona determinísticamente
```

**Interpretación**:
> La energía inicial E/N es como sumergir el sistema en un "baño térmico ficticio" al tiempo t=0, y luego desconectar ese baño. El sistema recuerda su "temperatura inicial" vía E/N conservado.

### Parámetro de Control

E/N actúa como **parámetro de control** análogo a temperatura:

| Parámetro | Sistema Térmico | Nuestro Sistema |
|:----------|:----------------|:----------------|
| **Controla** | Fluctuaciones térmicas | Velocidades típicas |
| **Fija** | <E_kinética> | E_total (conservado) |
| **Efecto** | Mayor T → más agitación | Mayor E/N → más actividad |
| **Transiciones** | Fusión, evaporación | Clustering, de-clustering |

**Crucial**: E/N no fluctúa (microcanónico), pero **determina** si el sistema puede formar clusters.

---

## Quasi-Thermalization: ¿Ocurre?

### Hipótesis: Relajación hacia Distribución Térmica

**Pregunta científica**:
Aunque las condiciones iniciales NO son térmicas (uniform distribution), ¿las colisiones pueden relajar el sistema hacia algo parecido a equilibrio térmico local?

**Test propuesto**: Analizar distribución de velocidades

#### Estado Inicial (t=0)

Distribución de φ̇:
```
P(φ̇) = 1 / (2v_max)  para φ̇ ∈ [-v_max, v_max]  (uniforme)
```

Distribución de energías individuales:
```
P(E_i) depende de g_φφ(φ_i), no es térmica
```

#### Estado Final (t → ∞)

**Si hay quasi-thermalization**, esperaríamos:
```
P(φ̇) → algo parecido a Gaussiana centrada en φ̇_cluster
P(E_i) → algo parecido a exp(-E_i / T_eff) con T_eff = E_total/N
```

**Si NO hay thermalization** (más probable):
```
P(φ̇) sigue siendo no-térmica
Distribución depende de historia de colisiones y geometría
```

### Evidencia de Experimentos Actuales

De COMPLETE_FINDINGS_SUMMARY.md (Experimento 2):

```
Thermalization de energías:
  σ_E: 0.373 → 0.265  (29% reduction)
  E_min: 0.000185 → 0.037638 (+20x)
  E_max: 1.601554 → 1.127245 (-30%)
```

**Interpretación**:
- Energías se compactan (redistribution)
- NO alcanza equilibrio completo en t=30s
- τ_relax > 30s (no saturado)

**Conclusión parcial**: Hay **partial energy redistribution** (como en gas molecular), pero NO full thermalization.

---

## Precedentes en la Literatura

### 1. Granular Gases (Kudrolli, Jaeger, etc.)

**Sistema**:
- Partículas macroscópicas vibrando
- Colisiones inelásticas (pierden energía)
- Energía inyectada por vibración de piso

**Temperatura granular**:
```
T_granular ≡ <m v²> / k_B
```

**Similitud**: T_granular no es temperatura termodinámica real, pero controla clustering.

**Diferencia**: Nuestro sistema tiene colisiones **elásticas** (conserva E).

### 2. Active Matter (Vicsek model, etc.)

**Sistema**:
- Partículas autopropulsadas
- Alineación de velocidades
- Transición de fase: disordered → flocking

**Parámetro de control**: Noise intensity η (no temperatura)

**Similitud**: Transición de fase fuera de equilibrio sin termalización.

### 3. Driven Dissipative Systems

**Sistema**:
- Energía inyectada continuamente
- Disipación balanceada
- Steady state ≠ equilibrio térmico

**"Effective temperature"**:
```
T_eff definida por fluctuation-dissipation relation
```

**Similitud**: Sistema no está en equilibrio pero tiene "temperatura efectiva".

### 4. Molecular Dynamics (sin termostato)

**Sistema**:
- Gas molecular microcanónico (E conservado)
- Sin termostato, sin fluctuaciones externas
- Distribución inicial arbitraria

**Relajación**:
- Después de suficientes colisiones → distribución de Maxwell-Boltzmann
- Tiempo de relajación τ_relax ∝ 1 / (collision rate)
- **Thermalization emerge from collisions alone**

**Similitud fuerte**: Nuestro sistema es análogo, PERO con geometría no-trivial.

---

## Conexión con Nuestros Resultados

### Transición de Fase Fuera de Equilibrio

**Fenómeno observado**:
- Estado inicial: Gas (partículas distribuidas uniformemente)
- Estado final: Cluster (partículas compactadas espacialmente)
- Transición: Espontánea, sin fuerza externa

**NO es**:
- Transición de equilibrio (como fusión o condensación)
- Temperatura T no está definida termodinámicamente
- No hay función de partición canónica

**SÍ es**:
- Transición de fase dinámica (DOPT: Dynamical Phase Transition)
- Controlada por E/N (parámetro de control)
- Análoga a transiciones en sistemas activos o granulares

### Papel de E/N

**E/N alto** (sistema "caliente"):
```
Velocidades altas → colisiones frecuentes y violentas
→ Clusters se rompen fácilmente
→ Estado: GAS (N_clusters ~ N)
```

**E/N intermedio** (sistema "tibio"):
```
Velocidades moderadas → colisiones suficientes
→ Clusters transitorios forman y se rompen
→ Estado: LÍQUIDO (N_clusters ~ N/10)
```

**E/N bajo** (sistema "frío"):
```
Velocidades bajas → colisiones gentles
→ Clusters estables
→ Estado: CRISTAL (N_clusters = 1)
```

**Importante**: Estos nombres (gas/líquido/cristal) son **analógicos**, no literales.

---

## Refined Framework

### Definición Precisa de T_eff

En lugar de llamarlo "temperatura efectiva", usamos:

```
E/N ≡ Energía cinética promedio por partícula (conservada)
```

**Interpretación física**:
1. **Control de actividad**: Mayor E/N → mayor velocidad típica
2. **Parámetro de fase**: E/N determina si clustering ocurre
3. **Análogo de temperatura**: Juega rol similar a T, pero NO es T termodinámico

**Lenguaje preferido**:
- ✅ "E/N actúa como un parámetro de control análogo a temperatura"
- ✅ "E/N inicial fija el 'nivel térmico efectivo' del sistema"
- ✅ "Baño térmico ficticio al t=0 que determina dinámica posterior"
- ❌ "El sistema está termalizado" (falso)
- ❌ "T = E/N es la temperatura del sistema" (confuso)

---

## Tests Experimentales Propuestos

### Test 1: Distribución de Velocidades

**Objetivo**: Verificar si hay relajación hacia distribución térmica

**Método**:
1. Extraer P(φ̇) en diferentes tiempos t
2. Comparar con:
   - Uniforme (inicial)
   - Gaussiana (térmica)
   - Otra distribución

**Script**:
```julia
function analyze_velocity_distribution(data, times_to_check)
    for t in times_to_check
        idx = findfirst(data.times .≈ t)
        phidot = [p.φ_dot for p in data.particles_history[idx]]

        # Fit Gaussian
        μ, σ = mean(phidot), std(phidot)

        # Kolmogorov-Smirnov test
        D_stat = ks_test(phidot, Normal(μ, σ))

        println("t=$t: μ=$μ, σ=$σ, D=$D_stat")
    end
end
```

**Resultado esperado**:
- Si D_stat pequeño → distribución es aproximadamente Gaussiana → quasi-thermal
- Si D_stat grande → distribución NO es térmica → non-equilibrium

### Test 2: Fluctuation-Dissipation Relation

**Objetivo**: Verificar si se cumple FDR (signature de equilibrio térmico)

En equilibrio térmico:
```
<(ΔE)²> / k_B T = C_V  (capacidad calorífica)
```

En nuestro sistema microcanónico:
```
Variance de E_i debería relacionarse con E/N si hay thermalization
```

**Test**:
```julia
σ²_E = var([E_i for each particle])
E_mean = E_total / N

ratio = σ²_E / E_mean
# Si ratio ≈ constante → thermal-like
# Si ratio varía → non-thermal
```

### Test 3: Collision-Driven Relaxation Time

**Objetivo**: Medir τ_relax para distribución de energías

De Experimento 2: σ_E disminuye con tiempo, τ_relax > 30s

**Propuesta**: Run longer simulations (t=500s) y medir:
```
σ_E(t) ~ σ_E(∞) + [σ_E(0) - σ_E(∞)] exp(-t/τ_relax)
```

**Predicción**:
- Si τ_relax ~ 100-1000s → relaxation es muy lenta
- Comparar con τ_collision ~ 1/f_collision ~ 0.005s
- Ratio τ_relax / τ_collision ~ 10⁴-10⁵ (muchas colisiones necesarias)

---

## Implicaciones para Paper

### Framing Científico

**Abstract/Introduction**:
> "We study a deterministic hard-sphere gas confined to an elliptical manifold. Although the system is not thermalized, the conserved energy per particle E/N acts as an effective control parameter analogous to temperature in equilibrium systems. We observe spontaneous clustering transitions reminiscent of phase transitions, driven by collision dynamics and geometric effects."

**Evitar**:
- "The system thermalizes" (falso)
- "We measure temperature T" (no hay T termodinámica)
- "Canonical ensemble" (es microcanónico)

**Preferir**:
- "E/N serves as a thermal-like control parameter"
- "Non-equilibrium phase transition"
- "Collision-driven clustering dynamics"
- "Microcanonical ensemble with conserved energy"

### Comparación con Literatura

**Conectar con**:
1. **Granular gases**: Temperatura granular, clustering
2. **Active matter**: Flocking transitions, noise-driven
3. **DOPT (Dynamical Phase Transitions)**: Fuera de equilibrio
4. **Kinetic theory**: Boltzmann equation on curved manifolds

**Distinguir de**:
1. Equilibrium statistical mechanics (canonical ensemble)
2. Thermalized systems (con termostato)
3. Dissipative systems (pérdida de energía)

---

## Propuesta: Verificación Experimental

### Experimento: Distribution Evolution

**Objetivo**: Medir P(φ̇, t) y P(E_i, t) para verificar relajación

**Parámetros**:
- N = 40
- E/N = 0.32 (fixed)
- t_max = 500s (muy largo para ver relajación completa)
- Save distribution cada 10s

**Análisis**:
1. Fit P(φ̇) a diferentes funciones:
   - Uniform
   - Gaussian
   - Exponential
   - Custom fit

2. Measure:
   - Kurtosis κ(t)
   - Skewness γ(t)
   - KS distance to Gaussian

3. Test:
   - ¿P(φ̇) → Gaussiana para t → ∞?
   - ¿τ_relax cuánto es?
   - ¿Depende de E/N?

**Resultado posible**:
- **Caso A**: P(φ̇) → Gaussiana (quasi-thermalization occurs)
  → E/N puede interpretarse más fuertemente como "temperatura efectiva"

- **Caso B**: P(φ̇) NO → Gaussiana (remains non-thermal)
  → E/N es parámetro de control, pero no temperatura en sentido estricto

**Valor científico**: Responde pregunta fundamental sobre naturaleza del sistema.

---

## Conclusión

### Resumen del Concepto

**E/N como "Baño Térmico Efectivo"**:
✅ Controla nivel de actividad (análogo a temperatura)
✅ Determina transiciones de fase (gas/líquido/cristal)
✅ Parámetro de control bien definido
✅ Permite predicciones cuantitativas

❌ NO es temperatura termodinámica real
❌ Sistema NO está en equilibrio térmico
❌ NO hay termalización completa (probablemente)

**Lenguaje científico apropiado**:
> "The conserved energy per particle E/N acts as an effective thermal bath parameter, controlling the system's activity level and determining whether spontaneous clustering occurs. While not a true thermodynamic temperature, E/N plays an analogous role in this microcanonical, collision-driven system."

### Valor de esta Distinción

**Importancia**:
1. **Honestidad científica**: No confundir sistema microcanónico con térmico
2. **Claridad conceptual**: Entender verdadera naturaleza de transiciones
3. **Literatura correcta**: Situar trabajo en contexto de DOPT, no equilibrium stat mech
4. **Experimentos apropiados**: Diseñar tests para verification (no asumir thermalization)

**Próximo paso crítico**:
Medir P(φ̇, t) y verificar experimentalmente si hay quasi-thermalization o no.

---

**Status**: Conceptualmente refinado
**Next**: Experimento de distribución de velocidades
**Impact**: Clarifica naturaleza fundamental del sistema
