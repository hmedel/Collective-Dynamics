# ¿Por Qué NO se Conserva el Momento Lineal?

**Fecha:** 2025-11-07
**Autor:** Análisis del sistema físico
**Conclusión:** ✅ El comportamiento observado es CORRECTO

---

## 🎯 Resumen Ejecutivo

**Pregunta:** ¿Por qué el momento lineal cartesiano tiene un error >100% mientras que la energía se conserva con error <0.02%?

**Respuesta:** Porque el modelo físico implementado **NO debe conservar momento lineal**. Esto es correcto y esperado.

---

## 📐 Modelo Físico Implementado

### Ecuación de Movimiento

El código usa **geodésicas en una variedad Riemanniana** (elipse):

```julia
# src/integrators/forest_ruth.jl:141-142
Γ = christoffel_ellipse(q, a, b)
F = -Γ * p^2  # Aceleración geodésica
```

Esto integra la ecuación:
```
θ̈ = -Γ(θ) θ̇²
```

donde Γ(θ) es el símbolo de Christoffel de la métrica elíptica.

### Interpretación Física

Las partículas **NO son libres en R²**, sino que:
- Están confinadas a la superficie 1D de una elipse embebida en R²
- Siguen geodésicas (caminos de "mínima energía") en esa geometría
- La geometría curva induce una aceleración efectiva

**Analogía:** Como cuentas deslizándose sin fricción en un alambre elíptico, pero donde el "alambre" es la geometría intrínseca.

---

## 🔬 Teorema de Noether y Conservación

El teorema de Noether establece:

> **Cada simetría continua → Una ley de conservación**

### Simetrías del Sistema

| Simetría | ¿Presente? | Conservación Asociada | ¿Se Conserva? |
|----------|------------|----------------------|---------------|
| Traslación temporal | ✅ Sí | Energía | ✅ Sí (error 1.6×10⁻⁴) |
| Traslación espacial en x | ❌ No | Momento px | ❌ No (error >100%) |
| Traslación espacial en y | ❌ No | Momento py | ❌ No (error >100%) |
| Rotación (si a=b) | ⚠️ Solo círculo | Momento angular | ⚠️ Parcial |

### ¿Por Qué NO Hay Simetría Traslacional?

**Ejemplo:** Mover todas las partículas 1cm hacia la derecha:
- ❌ Ya NO están en la elipse
- ❌ El Hamiltoniano cambia (partículas fuera de la variedad)
- ❌ NO es una simetría del sistema

Por lo tanto, **no debe haber conservación de momento lineal**.

---

## 🔍 Comparación con el Código Original de Isaí

### Código Original (Elipse40.jl)

```julia
function θ_dot(t, u)
    x, v = u
    dxdt = v
    dvdt = 0  # ← Sin aceleración angular
    return [dxdt, dvdt]
end
```

**Física:** θ̈ = 0 (movimiento uniforme en θ)

### Nuestro Código

```julia
Γ = christoffel_ellipse(q, a, b)
F = -Γ * p^2  # ← Con aceleración geodésica
p = p + γ₁ * dt * F
```

**Física:** θ̈ = -Γθ̇² (geodésicas en variedad Riemanniana)

### Conservación en Ambos Modelos

| Cantidad | Código de Isaí | Nuestro Código | ¿Se Conserva? |
|----------|----------------|----------------|---------------|
| Energía total | ✅ | ✅ | **SÍ** |
| Momento lineal px | ❌ | ❌ | **NO** |
| Momento lineal py | ❌ | ❌ | **NO** |

**Ambos modelos son correctos** - simplemente representan físicas ligeramente diferentes:
- **Isaí:** Partículas en alambre (fuerzas de constricción externas)
- **Nuestro:** Partículas libres en geometría curva (sin fuerzas externas, pero métrica no-euclidiana)

---

## 📊 Resultados de la Simulación

### Energía (Debe Conservarse)

```
Energía inicial:  30.159535 J
Energía final:    30.154697 J
Error relativo:   1.604 × 10⁻⁴  (0.016%)
```

✅ **EXCELENTE** - Error dentro del ruido numérico esperado

### Momento Lineal (NO Debe Conservarse)

```
Componente px:
  Inicial:  +2.1129 kg·m/s
  Final:    -3.6039 kg·m/s
  Error:    270%

Componente py:
  Inicial:  -1.9071 kg·m/s
  Final:    +1.3030 kg·m/s
  Error:    168%
```

✅ **ESPERADO** - El momento cambia libremente porque no hay simetría traslacional

---

## 🤔 Preguntas Frecuentes

### 1. "Pero no hay fuerzas externas, ¿por qué cambia el momento?"

Hay dos formas de verlo:

**Perspectiva 1 - Geometría intrínseca:**
- Las partículas están en una variedad curva 1D (la elipse)
- No hay fuerzas externas EN LA VARIEDAD
- El momento se mide EN R² (espacio ambiente)
- La curvatura induce cambios de momento en R²

**Perspectiva 2 - Fuerzas de constricción:**
- Las partículas "quieren" moverse en línea recta en R²
- La constricción a la elipse requiere una fuerza normal
- Esta fuerza rompe la conservación de momento

Ambas son equivalentes - depende de tu framework conceptual.

### 2. "¿Entonces el código está correcto?"

✅ **SÍ**, completamente. El error >100% en momento lineal **NO es un bug**, es la física correcta del sistema.

Lo que importa verificar:
- ✅ Energía conservada → Correcto (1.6×10⁻⁴)
- ✅ Integradores simplécticos → Correcto (Forest-Ruth)
- ✅ Colisiones conservan energía → Correcto

### 3. "¿Cómo sé que no es un bug en las colisiones?"

Las colisiones usan **transporte paralelo**, que:
- ✅ Preserva la norma de vectores en la métrica
- ✅ Garantiza conservación de energía local
- ❌ NO preserva momento en R² (y no debe)

Si las colisiones conservaran momento en R², **romperían** la conservación de energía en la métrica.

### 4. "¿Se conserva algo más?"

Para verificar completamente el sistema, faltaría analizar:

1. **Momento angular respecto al origen:**
   ```
   L = ∑ᵢ rᵢ × pᵢ
   ```
   No necesariamente se conserva (elipse no es circular)

2. **Momento conjugado en la variedad:**
   ```
   p_θ = m g(θ) θ̇
   ```
   Este SÍ podría tener propiedades de conservación

3. **Adiabatic invariants** (si los hay)

---

## 🎓 Física Fundamental

### Sistema Hamiltoniano en Variedad

El Hamiltoniano del sistema es:
```
H = ∑ᵢ ½ mᵢ g(θᵢ) θ̇ᵢ²
```

donde g(θ) = a²sin²θ + b²cos²θ es la métrica.

**Conservación garantizada:**
- ✅ Energía: ∂H/∂t = 0 (no depende explícitamente del tiempo)

**NO garantizada:**
- ❌ px, py: Sistema no es invariante bajo traslaciones en R²

### Ecuaciones de Hamilton

```
θ̇ᵢ = ∂H/∂pᵢ
ṗᵢ = -∂H/∂θᵢ  ← Esto genera la aceleración geodésica
```

La derivada ∂H/∂θ es NO-NULA debido a la métrica variable g(θ), lo que genera la aceleración.

---

## 📖 Comparación con Sistemas Conocidos

### 1. Partícula Libre en R²

```
H = (px² + py²)/(2m)
Simetrías: traslación x, y
Conserva: px, py, E
```

### 2. Péndulo

```
H = p²/(2mL²) + mgL(1 - cosθ)
Simetrías: solo tiempo
Conserva: E (NO momento angular)
```

### 3. Nuestro Sistema (Geodésicas en Elipse)

```
H = ∑ᵢ pᵢ²/(2mᵢgᵢ(θ))
Simetrías: solo tiempo
Conserva: E (NO px, py)
```

Nuestro sistema es más parecido al péndulo que a la partícula libre.

---

## ✅ Conclusiones

### 1. El Sistema es Correcto

✅ Conservación de energía excelente (1.6×10⁻⁴)
✅ Integrador simpléctico apropiado
✅ Colisiones físicamente consistentes

### 2. El Momento NO Debe Conservarse

❌ No hay simetría traslacional
❌ Teorema de Noether no lo garantiza
✅ Cambio >100% es **esperado y correcto**

### 3. Recomendaciones

1. **NO cambiar las colisiones** para forzar conservación de momento - eso rompería la energía

2. **Verificar momento angular** (si se necesita otra cantidad conservada)

3. **Documentar claramente** que el sistema modela geodésicas en variedad curva

4. **Ajustar umbrales de diagnóstico** para no marcar como "error" el comportamiento correcto:

```julia
# EN LUGAR DE:
if max_error_p > 1e-2
    println("❌ ERROR en conservación")

# USAR:
println("ℹ️  Momento lineal no se conserva (esperado en variedad curva)")
println("   Energía es la cantidad relevante: error = ", error_E)
```

---

## 📚 Referencias

1. **Teorema de Noether:**
   Emmy Noether (1918). "Invariante Variationsprobleme"

2. **Geometría Riemanniana:**
   Do Carmo, M. P. "Riemannian Geometry"

3. **Integradores Simplécticos:**
   Forest, E., & Ruth, R. D. (1990). "Fourth-order symplectic integration"

4. **Mechanics on Manifolds:**
   Abraham, R., & Marsden, J. E. "Foundations of Mechanics"

---

**Autor:** Análisis basado en simulación con 20 partículas, 1M pasos, 699 colisiones
**Validación:** Error de energía 1.604×10⁻⁴ confirma corrección del modelo
**Fecha:** 2025-11-07
