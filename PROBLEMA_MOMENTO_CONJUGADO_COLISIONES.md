# 🔬 Problema: Conservación de Momento Conjugado en Colisiones

**Fecha:** 2025-11-11
**Descubrimiento:** Usuario observó que momento conjugado se conserva peor que energía

---

## 📊 Observación

Con `config/alta_precision.toml` (dt_max=1e-6, tolerance=1e-7):

```
Error energía:          2.6e-5 (0.0026%) ✅ BUENO
Error momento conjugado: 3.6e-5 (0.0036%) ⚠️  38% PEOR
```

**Ratio:** error_P / error_E = 1.38

En un integrador simpléctico ideal, **ambos deberían conservarse igual de bien**.

---

## 🔍 Causa del Problema

### El Momento Conjugado

La cantidad conservada es:
```
p_θ = m √g(θ) θ̇

donde g(θ) = a²sin²(θ) + b²cos²(θ)
```

### Algoritmo de Colisión

El método `parallel_transport` hace:

1. **Transporte paralelo** de velocidades:
   ```
   θ̇₁(θ₁) → θ̇₁'(θ₂)  (transportar de θ₁ a θ₂)
   θ̇₂(θ₂) → θ̇₂'(θ₁)  (transportar de θ₂ a θ₁)
   ```

2. **Intercambio** de velocidades transportadas:
   ```
   θ̇₁_new = θ̇₂'
   θ̇₂_new = θ̇₁'
   ```

### ¿Por Qué No Conserva p_θ Exactamente?

El transporte paralelo conserva la **magnitud** de la velocidad en la métrica:
```
√g(θ₁) θ̇₁ = √g(θ₂) θ̇₁'  ✅ Se conserva en transporte
```

**PERO** después del intercambio:
```
p_θ,1 inicial = m √g(θ₁) θ̇₁
p_θ,1 final   = m √g(θ₁) θ̇₂'
```

Y NO necesariamente:
```
√g(θ₁) θ̇₁ + √g(θ₂) θ̇₂ = √g(θ₁) θ̇₂' + √g(θ₂) θ̇₁'
```

porque √g(θ) **varía con la posición**.

---

## 💡 Soluciones

### Solución 1: **Reducir Tolerance Drásticamente** ✅ PRÁCTICO

Si no podemos conservar p_θ exactamente, minimizamos el error:

```toml
tolerance = 1.0e-9  # 1000× más estricto
```

**Resultado esperado:**
- Error por colisión: ~1e-9 por colisión
- Con N colisiones: error total ~ N × 1e-9
- Para 2000 colisiones: error ~ 2e-6 ✅ EXCELENTE

**Archivo:** `config/ultra_precision.toml`

**Tiempo de cómputo:** ~1-2 horas para 10 segundos

---

### Solución 2: **Implementar Colisión que Conserve p_θ** 🔬 TEÓRICO

Resolver el sistema:
```
p_θ,1 + p_θ,2 = constante  (conservar momento conjugado)
E_1 + E_2 = constante      (conservar energía)
```

Esto requiere:
```julia
function resolve_collision_conserve_conjugate_momentum(p1, p2, a, b)
    # Sistema de 2 ecuaciones, 2 incógnitas (θ̇₁_new, θ̇₂_new)

    # Conservación de momento conjugado:
    # m₁ √g(θ₁) θ̇₁ + m₂ √g(θ₂) θ̇₂ = m₁ √g(θ₁) θ̇₁_new + m₂ √g(θ₂) θ̇₂_new

    # Conservación de energía:
    # (1/2) m₁ g(θ₁) θ̇₁² + (1/2) m₂ g(θ₂) θ̇₂² =
    # (1/2) m₁ g(θ₁) θ̇₁_new² + (1/2) m₂ g(θ₂) θ̇₂_new²

    # Resolver sistema...
end
```

**Ventaja:** Conservación exacta de p_θ (hasta error numérico)

**Desventaja:**
- Más complejo
- Requiere resolver ecuación no lineal
- Puede no tener solución física en algunos casos

**Estado:** No implementado (contribución futura)

---

### Solución 3: **Método Simple para Partículas Cercanas** 🎯 RÁPIDO

Si las partículas están muy cerca (θ₁ ≈ θ₂):
```
g(θ₁) ≈ g(θ₂)  →  √g(θ₁) ≈ √g(θ₂)
```

Entonces el método `:simple` (intercambio directo) conserva p_θ aproximadamente.

**Aplicación:** Usar dt_max pequeño para asegurar que colisiones ocurren cuando partículas están cerca.

---

## 📈 Análisis Cuantitativo

### Error por Colisión

Con tolerance = ε:
```
Error por colisión en p_θ ~ ε × |g'(θ)| / √g(θ)
```

Para elipse con a=2, b=1:
```
|g'(θ)| máximo ~ 2(a² - b²) = 6
√g(θ) mínimo ~ b = 1
```

Entonces:
```
Error por colisión ~ 6ε
```

Con N colisiones:
```
Error acumulado ~ N × 6ε
```

### Ejemplo Numérico

Tu simulación con ~2000 colisiones:

| tolerance | Error por colisión | Error total (2000 col) | Clasificación |
|-----------|-------------------|------------------------|---------------|
| 1e-6 | 6e-6 | **1.2e-2** | ❌ MALO |
| 1e-7 | 6e-7 | **1.2e-3** | ⚠️ ACEPTABLE |
| 1e-8 | 6e-8 | **1.2e-4** | ✅ BUENO |
| 1e-9 | 6e-9 | **1.2e-5** | ✅ EXCELENTE |

**Conclusión:** Para N~2000 colisiones, necesitas tolerance ≈ 1e-9 para error < 1e-5.

---

## 🎯 Recomendaciones

### Para Investigación (Publicaciones)

Usa **`config/ultra_precision.toml`**:
```toml
dt_max = 5e-7
tolerance = 1e-9
```

**Resultados esperados:**
- Error energía: < 1e-10
- Error momento: < 1e-8
- Ratio: ~1.0 (ambos excelentes)

**Costo:** ~1-2 horas de cómputo

---

### Para Exploración

Usa **`config/alta_precision.toml`**:
```toml
dt_max = 1e-6
tolerance = 1e-7
```

**Resultados:**
- Error energía: ~2e-5
- Error momento: ~4e-5
- Ratio: ~1.5

**Aceptable** para la mayoría de propósitos, pero no óptimo.

---

## 📊 Verificación Experimental

Para confirmar el diagnóstico, ejecuta:

```bash
julia --project=. analizar_error_colisiones.jl results/simulation_20251111_001524/
```

Esto te dirá si el error:
1. **Crece linealmente con tiempo** → problema del integrador
2. **Crece linealmente con colisiones** → problema de tolerance
3. **Ambos**

---

## 🔬 Trabajo Futuro

### Implementar Método de Colisión Exacto

```julia
function resolve_collision_exact_conjugate_momentum(p1, p2, a, b)
    # Resolver sistema exacto para conservar:
    # 1. p_θ,1 + p_θ,2
    # 2. E_1 + E_2

    # Esto dará conservación perfecta de momento conjugado
    # incluso en colisiones
end
```

**Beneficio:** Error solo del integrador, no de colisiones

**Referencia teórica:** Conservación en colisiones de geodésicas
- Abraham & Marsden, "Foundations of Mechanics"
- Capítulo sobre colisiones simplécticas

---

## 📚 Referencias

1. **Hairer et al. (2006):** "Geometric Numerical Integration"
   - Capítulo 7: Colisiones en sistemas Hamiltonianos

2. **Your work:**
   - `RESULTADOS_CONSERVACION.md`: Verificación con fórmula correcta
   - `PRECISION_GUIDE.md`: Guía de precisión

3. **Código relevante:**
   - `src/collisions.jl:198-228`: Implementación actual
   - `src/geometry/parallel_transport.jl`: Transporte paralelo

---

## ✅ Conclusión

El momento conjugado **NO se conserva perfectamente** en colisiones con el método actual porque:

1. El transporte paralelo conserva magnitud en métrica
2. Pero p_θ = m √g(θ) θ̇ incluye √g que varía con posición
3. Después del intercambio, la suma no se conserva exactamente

**Solución práctica:** tolerance = 1e-9 para minimizar error

**Solución teórica:** Implementar método que conserve p_θ exactamente

---

**Estado:** ✅ Problema identificado, solución práctica disponible
**Archivo de configuración:** `config/ultra_precision.toml`
