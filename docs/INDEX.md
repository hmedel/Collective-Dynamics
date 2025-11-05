# 📚 Índice de Documentación - CollectiveDynamics.jl

Documentación completa del framework de dinámica colectiva en variedades curvas.

---

## 🚀 Inicio Rápido

| Documento | Descripción | Tiempo de lectura |
|-----------|-------------|-------------------|
| [QUICKSTART.md](../QUICKSTART.md) | Comandos esenciales para empezar en 5 minutos | 5 min |
| [README.md](../README.md) | Introducción general y ejemplos básicos | 10 min |

---

## 📖 Guías de Usuario

| Documento | Descripción | Audiencia |
|-----------|-------------|-----------|
| [INSTALL.md](../INSTALL.md) | Guía completa de instalación paso a paso | Todos |
| [QUICKSTART.md](../QUICKSTART.md) | Inicio rápido | Usuarios nuevos |
| [README.md](../README.md) | Documentación principal con ejemplos | Todos |

---

## 🔬 Documentación Técnica

### Componentes Principales

| Documento | Contenido | Audiencia |
|-----------|-----------|-----------|
| [GEOMETRY_TECHNICAL.md](GEOMETRY_TECHNICAL.md) | **Geometría Diferencial Completa** | Desarrolladores, Investigadores |
| | • Métricas de Riemann | |
| | • Símbolos de Christoffel (3 métodos) | |
| | • Transporte Paralelo | |
| | • Derivaciones matemáticas completas | |
| | • Validación numérica | |

| [INTEGRATOR_TECHNICAL.md](INTEGRATOR_TECHNICAL.md) | **Integrador Forest-Ruth** | Desarrolladores, Investigadores |
| | • Teoría de integradores simplécticos | |
| | • Método Forest-Ruth orden 4 | |
| | • Implementación optimizada | |
| | • Propiedades simplécticas | |
| | • Benchmarks y comparaciones | |

| [COMPLETE_TECHNICAL_DOCUMENTATION.md](COMPLETE_TECHNICAL_DOCUMENTATION.md) | **Documentación Completa del Sistema** | Desarrolladores |
| | • Sistema de partículas | |
| | • Colisiones en variedades curvas | |
| | • Conservación y análisis | |
| | • Arquitectura del sistema | |
| | • Guía de desarrollo | |
| | • API Reference completa | |

---

## 📊 Análisis y Comparaciones

| Documento | Contenido | Audiencia |
|-----------|-----------|-----------|
| [ANALYSIS.md](../ANALYSIS.md) | Comparación código original vs optimizado | Todos |
| | • Discrepancias identificadas | |
| | • Problemas de performance | |
| | • Optimizaciones implementadas | |
| | • Ganancia de speedup (~2000x) | |

---

## 🛠️ Para Desarrolladores

### Guías de Desarrollo

| Sección | Ubicación | Contenido |
|---------|-----------|-----------|
| **Setup** | [COMPLETE_TECHNICAL_DOCUMENTATION.md](COMPLETE_TECHNICAL_DOCUMENTATION.md#guía-de-desarrollo) | Configurar entorno de desarrollo |
| **Workflow** | Mismo | Desarrollo iterativo con tests |
| **Añadir geometría** | Mismo | Cómo extender a otras geometrías |
| **Optimización** | Mismo | Herramientas y checklist |

### API Reference

| Módulo | Ubicación | Funciones |
|--------|-----------|-----------|
| **Geometry** | [COMPLETE_TECHNICAL_DOCUMENTATION.md](COMPLETE_TECHNICAL_DOCUMENTATION.md#api-reference-completa) | metrics, christoffel, parallel_transport |
| **Integrators** | Mismo | forest_ruth, verify_symplecticity |
| **Particles** | Mismo | Particle, generate_random_particles, energías |
| **Collisions** | Mismo | check_collision, resolve_collision_* |
| **Conservation** | Mismo | ConservationData, análisis |
| **Simulation** | Mismo | simulate_ellipse |

---

## 📝 Ejemplos de Código

| Ejemplo | Archivo | Descripción |
|---------|---------|-------------|
| **Simulación completa** | [examples/ellipse_simulation.jl](../examples/ellipse_simulation.jl) | 40 partículas, 100k pasos, análisis completo |
| **Tests unitarios** | [test/runtests.jl](../test/runtests.jl) | Suite completa de tests |
| **Verificación** | [verify_installation.jl](../verify_installation.jl) | Script de verificación automática |

---

## 🔍 Búsqueda por Tópico

### Matemáticas

| Tópico | Documento | Sección |
|--------|-----------|---------|
| **Ecuación geodésica** | [GEOMETRY_TECHNICAL.md](GEOMETRY_TECHNICAL.md) | § Símbolos de Christoffel |
| **Transporte paralelo** | [GEOMETRY_TECHNICAL.md](GEOMETRY_TECHNICAL.md) | § Transporte Paralelo |
| **Métrica de elipse** | [GEOMETRY_TECHNICAL.md](GEOMETRY_TECHNICAL.md) | § Métricas de Riemann |
| **Christoffel** | [GEOMETRY_TECHNICAL.md](GEOMETRY_TECHNICAL.md) | § Símbolos de Christoffel |
| **Simplecticidad** | [INTEGRATOR_TECHNICAL.md](INTEGRATOR_TECHNICAL.md) | § Propiedades Simplécticas |

### Implementación

| Tópico | Documento | Sección |
|--------|-----------|---------|
| **Struct Particle** | [COMPLETE_TECHNICAL_DOCUMENTATION.md](COMPLETE_TECHNICAL_DOCUMENTATION.md) | § Sistema de Partículas |
| **Colisiones** | [COMPLETE_TECHNICAL_DOCUMENTATION.md](COMPLETE_TECHNICAL_DOCUMENTATION.md) | § Colisiones |
| **Forest-Ruth** | [INTEGRATOR_TECHNICAL.md](INTEGRATOR_TECHNICAL.md) | § Implementación |
| **Conservación** | [COMPLETE_TECHNICAL_DOCUMENTATION.md](COMPLETE_TECHNICAL_DOCUMENTATION.md) | § Conservación |

### Performance

| Tópico | Documento | Sección |
|--------|-----------|---------|
| **Optimizaciones** | [ANALYSIS.md](../ANALYSIS.md) | § Optimizaciones Propuestas |
| **Benchmarks** | [INTEGRATOR_TECHNICAL.md](INTEGRATOR_TECHNICAL.md) | § Validación y Benchmarks |
| **Type stability** | [ANALYSIS.md](../ANALYSIS.md) | § Type Instability |
| **StaticArrays** | [ANALYSIS.md](../ANALYSIS.md) | § NO Usa StaticArrays |

---

## 📚 Orden de Lectura Recomendado

### Para Usuarios (Sin experiencia técnica)

1. [QUICKSTART.md](../QUICKSTART.md) - 5 minutos
2. [README.md](../README.md) - 10 minutos
3. [INSTALL.md](../INSTALL.md) - Si hay problemas
4. Ejecutar [examples/ellipse_simulation.jl](../examples/ellipse_simulation.jl)

### Para Investigadores

1. [README.md](../README.md) - Contexto general
2. [GEOMETRY_TECHNICAL.md](GEOMETRY_TECHNICAL.md) - Fundamentos matemáticos
3. [INTEGRATOR_TECHNICAL.md](INTEGRATOR_TECHNICAL.md) - Método numérico
4. [COMPLETE_TECHNICAL_DOCUMENTATION.md](COMPLETE_TECHNICAL_DOCUMENTATION.md) - Implementación completa
5. [ANALYSIS.md](../ANALYSIS.md) - Comparaciones y resultados

### Para Desarrolladores

1. [INSTALL.md](../INSTALL.md) - Setup
2. [COMPLETE_TECHNICAL_DOCUMENTATION.md](COMPLETE_TECHNICAL_DOCUMENTATION.md) § Guía de Desarrollo
3. [COMPLETE_TECHNICAL_DOCUMENTATION.md](COMPLETE_TECHNICAL_DOCUMENTATION.md) § API Reference
4. [GEOMETRY_TECHNICAL.md](GEOMETRY_TECHNICAL.md) - Detalles de geometría
5. [INTEGRATOR_TECHNICAL.md](INTEGRATOR_TECHNICAL.md) - Detalles de integrador
6. Código fuente en `src/`

---

## 🔗 Referencias Externas

### Artículos Citados

1. **García-Hernández & Medel-Cobaxín** (2024). "Collision Dynamics on Curved Manifolds: A Simple Symplectic Computational Approach"

2. **Forest, E., & Ruth, R. D.** (1990). "Fourth-order symplectic integration". *Physica D*, 43(1), 105-117.

3. **do Carmo, M. P.** (1992). *Riemannian Geometry*. Birkhäuser.

4. **Lee, J. M.** (2018). *Introduction to Riemannian Manifolds*. Springer.

### Herramientas Utilizadas

- **Julia:** https://julialang.org/
- **StaticArrays.jl:** https://github.com/JuliaArrays/StaticArrays.jl
- **ForwardDiff.jl:** https://github.com/JuliaDiff/ForwardDiff.jl
- **Elliptic.jl:** https://github.com/nolta/Elliptic.jl

---

## 📞 Soporte y Contacto

### Documentación

- **Issues:** https://github.com/hmedel/Collective-Dynamics/issues
- **Docs online:** *(próximamente)*

### Contacto Directo

- **Email:** hmedel@tec.mx
- **Institución:** Tecnológico de Monterrey

---

## 🔄 Actualizaciones

| Versión | Fecha | Cambios |
|---------|-------|---------|
| 0.1.0 | 2024 | Implementación inicial completa |
| | | • Framework de geometría diferencial |
| | | • Integrador Forest-Ruth 4to orden |
| | | • 3 métodos de resolución de colisiones |
| | | • Documentación exhaustiva |

---

## ✅ Checklist de Documentación

### Para Usuarios

- [x] Guía de instalación
- [x] Quick start
- [x] Ejemplos ejecutables
- [x] Troubleshooting

### Para Investigadores

- [x] Fundamentos matemáticos
- [x] Derivaciones completas
- [x] Validación numérica
- [x] Comparación con artículo

### Para Desarrolladores

- [x] API Reference
- [x] Guía de desarrollo
- [x] Convenciones de código
- [x] Arquitectura del sistema
- [x] Tests y benchmarks

---

**Nota:** Todos los documentos están en formato Markdown y se pueden leer en cualquier editor de texto o navegador web.

**Última actualización:** 2024
**Autores:** J. Isaí García-Hernández, Héctor J. Medel-Cobaxín
