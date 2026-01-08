# Migración a Coordenadas Polares Verdaderas

## Estado Actual

### ✅ Completado

1. **Geometría Polar** (`src/geometry/metrics_polar.jl`)
   - Métrica: `g_φφ = r² + (dr/dφ)²`
   - Radio: `r(φ) = ab/√(a²sin²φ + b²cos²φ)`
   - Posiciones cartesianas: `(x,y) = r(φ)(cos φ, sin φ)`
   - Velocidades cartesianas desde φ̇
   - Energía cinética: `T = (1/2)m g_φφ φ̇²`
   - Curvatura κ(φ)
   - **Tests pasados**: Métrica, consistencia, puntos en elipse

2. **Símbolos de Christoffel** (`src/geometry/christoffel_polar.jl`)
   - Γ^φ_φφ analítico y numérico
   - **Tests pasados**: Coincidencia analítico-numérico (error < 1e-16)

3. **Tests de verificación** (`test_polar_geometry.jl`)
   - Todos los tests principales pasando
   - Curvatura correcta: κ_max(φ=0°) = 2.0, κ_min(φ=90°) = 0.25

### 🔄 Pendiente (esperando cantidad conservada del usuario)

4. **Estructura Particle**
   - Cambiar `θ` → `φ` (ángulo polar verdadero)
   - ¿El momento conjugado cambia? **Usuario lo confirmará**

5. **Cantidad Conservada**
   - **CRÍTICO**: El usuario indicó que la cantidad conservada es DIFERENTE
   - Esperando definición de la nueva cantidad conservada
   - Posibles opciones:
     * Momento angular L = m r² φ̇
     * Momento conjugado P_φ = ∂L/∂φ̇ = m g_φφ φ̇
     * Otra cantidad (usuario especificará)

6. **Integrador Forest-Ruth**
   - Actualizar para usar φ, φ̇ y nueva métrica g_φφ
   - Actualizar Christoffel Γ^φ_φφ

7. **Colisiones**
   - Transporte paralelo con Γ^φ_φφ
   - Detección en coordenadas cartesianas (no cambia)
   - Resolución debe preservar la nueva cantidad conservada

8. **Análisis y visualización**
   - Distribución angular ahora es verdaderamente φ (ángulo polar)
   - Correlación curvatura-densidad será más natural
   - Cuadrantes [0°, 90°, 180°, 270°] ahora son regiones polares reales

## Matemática Clave

### Parametrización

**Anterior (ángulo excéntrico θ):**
```
x = a cos(θ)
y = b sin(θ)
g_θθ = a²sin²(θ) + b²cos²(θ)
```

**Nueva (ángulo polar φ):**
```
r(φ) = ab/√(a²sin²φ + b²cos²φ)
x = r(φ)cos(φ)
y = r(φ)sin(φ)
g_φφ = r² + (dr/dφ)²
```

### Curvatura

En coordenadas polares:
```
κ(φ) = |r² + 2(dr/dφ)² - r(d²r/dφ²)| / (r² + (dr/dφ)²)^(3/2)
```

Para elipse (a > b):
- **κ máxima en φ=0°, 180°** (extremos semieje mayor): κ ≈ a/b²
- **κ mínima en φ=90°, 270°** (extremos semieje menor): κ ≈ b/a²

Esto invierte la interpretación anterior.

### Símbolos de Christoffel

```
Γ^φ_φφ = (∂_φ g_φφ)/(2 g_φφ)
```

Ya implementado y verificado.

## Impacto en Resultados Anteriores

### Análisis de Curvatura (60s)

Los resultados anteriores usando θ mostraron:
- Correlación densidad-curvatura: **-0.34** (final)
- Interpretación: partículas evitan regiones de alta curvatura

**Con φ (polar verdadero):**
- Los "cuadrantes" [0°-90°] ahora son regiones polares reales
- La curvatura κ(φ) está correctamente asociada al ángulo polar
- El análisis será más interpretable físicamente

### Conservación

- Energía E siempre se conserva (no depende de la parametrización)
- **Momento conjugado cambia**:
  - Anterior: P_θ = ∂L/∂θ̇ = m g_θθ θ̇
  - Nueva: P_φ = ∂L/∂φ̇ = m g_φφ φ̇
  - ¿Se conserva P_φ? **Usuario debe confirmar**

## Próximos Pasos

1. **Esperar definición de cantidad conservada** (usuario)
2. Actualizar `Particle` struct
3. Actualizar integrador
4. Actualizar colisiones con transporte paralelo en φ
5. Re-ejecutar simulaciones y comparar resultados
6. Validar que conservación es correcta

## Archivos Nuevos Creados

- `src/geometry/metrics_polar.jl` - Métrica en coordenadas polares
- `src/geometry/christoffel_polar.jl` - Símbolos de Christoffel para φ
- `test_polar_geometry.jl` - Tests de verificación (todos pasando)
- `MIGRACION_POLAR.md` - Este documento

## Notas Técnicas

### Ventajas de Coordenadas Polares

1. **Interpretación física clara**: φ es el ángulo polar real
2. **Análisis de curvatura natural**: κ(φ) se asocia directamente al ángulo
3. **Distribuciones angulares**: Los histogramas de φ son polares verdaderos
4. **Generalización a 3D**: Más natural para coordenadas esféricas (φ, θ)

### Desafíos

1. **Métrica más compleja**: g_φφ = r² + (dr/dφ)² vs simple g_θθ = a²sin²θ + b²cos²θ
2. **Conversión θ↔φ**: No hay fórmula cerrada (Newton-Raphson necesario)
3. **Código existente**: Requiere migración de toda la base de código

### Decisión de Diseño

- Mantener ambas parametrizaciones en el código
- Usar polar (φ) como default para nuevas simulaciones
- Permitir conversión desde resultados anteriores (θ)
