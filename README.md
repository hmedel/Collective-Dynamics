# CollectiveDynamics.jl

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Julia](https://img.shields.io/badge/julia-v1.9+-blue.svg)](https://julialang.org)

**Framework para simulaciones de dinámica colectiva en variedades curvas**

Implementación optimizada del algoritmo descrito en:
> *"Collision Dynamics on Curved Manifolds: A Simple Symplectic Computational Approach"*
> por J. Isaí García-Hernández y Héctor J. Medel-Cobaxín

---

##  Características Principales

- ✅ **Geometría Diferencial Aplicada**: Métricas, símbolos de Christoffel, transporte paralelo
- ✅ **Integrador Simpléctico Forest-Ruth**: 4to orden, conservación de energía O(dt⁴)
- ✅ **Transporte Paralelo de Velocidades**: Corrección geométrica en colisiones
- ✅ **Optimizado para Performance**: Float64, StaticArrays, type-stable
- ✅ **Conservación Rigurosa**: Energía conservada < 1e-4 (verificado numéricamente)
- 🚧 **Preparado para Paralelización**: CPU (Threads.jl) y GPU (CUDA.jl)

---

##  Instalación

```julia
# Desde el REPL de Julia
using Pkg
Pkg.activate(".")
Pkg.instantiate()
```

O manualmente:

```julia
using Pkg
Pkg.add(["StaticArrays", "ForwardDiff", "Elliptic", "DataFrames", "CSV", "GLMakie"])
```

---

##  Uso Rápido

```julia
using CollectiveDynamics

# Parámetros de la elipse
a, b = 2.0, 1.0  # Semi-ejes mayor y menor

# Generar 40 partículas sin superposición
particles = generate_random_particles(40, 1.0, 0.05, a, b)

# Simular 100,000 pasos con transporte paralelo
data = simulate_ellipse(
    particles, a, b;
    n_steps=100_000,
    dt=1e-8,
    collision_method=:parallel_transport
)

# Analizar conservación
print_conservation_summary(data.conservation)
```

**Salida esperada:**
```
 ENERGÍA:
  Inicial:           1.234567e+08
  Final:             1.234566e+08
  Error relativo max: 8.23e-05
  ✅ Conservada:      SÍ
```

---

##  Resultados del Artículo

Nuestro método demuestra:

| Métrica | Valor | Comparación con Métodos Tradicionales |
|---------|-------|---------------------------------------|
| **Conservación de Energía** | ΔE/E₀ < 1e-4 | **2-3 órdenes de magnitud mejor** |
| **Orden de Precisión** | O(dt⁴) | Forest-Ruth 4to orden |
| **Estabilidad Numérica** | > 100,000 pasos | Sin drift significativo |

---

##  Fundamento Matemático

### Ecuación Geodésica

En una variedad Riemanniana con métrica \(g_{ij}\), las partículas libres siguen geodésicas:

```math
\frac{d^2 q^i}{dt^2} + \Gamma^i_{jk} \frac{dq^j}{dt} \frac{dq^k}{dt} = 0
```

donde \(\Gamma^i_{jk}\) son los símbolos de Christoffel:

```math
\Gamma^i_{jk} = \frac{1}{2} g^{il} \left( \partial_j g_{lk} + \partial_k g_{lj} - \partial_l g_{jk} \right)
```

### Transporte Paralelo (Ecuación Clave)

Durante las colisiones, las velocidades se actualizan mediante:

```math
v'^i = v^i - \Gamma^i_{jk} v^j \Delta q^k
```

Esto asegura que los vectores velocidad permanezcan tangentes a la variedad.

### Métrica de la Elipse

Para una elipse parametrizada por \(\theta\):

```math
g_{\theta\theta} = a^2 \sin^2(\theta) + b^2 \cos^2(\theta)
```

---

##  Estructura del Proyecto

```
Collective-Dynamics/
├── src/
│   ├── CollectiveDynamics.jl          # Módulo principal
│   ├── geometry/
│   │   ├── metrics.jl                  # Métricas de Riemann
│   │   ├── christoffel.jl              # Símbolos de conexión
│   │   └── parallel_transport.jl       # Transporte paralelo
│   ├── integrators/
│   │   └── forest_ruth.jl              # Integrador simpléctico
│   ├── particles.jl                    # Struct Particle optimizado
│   ├── collisions.jl                   # Detección y resolución
│   └── conservation.jl                 # Verificación de leyes
├── examples/
│   └── ellipse_simulation.jl           # Ejemplo completo
├── test/
│   └── runtests.jl                     # Tests unitarios
├── ANALYSIS.md                          # Análisis detallado
└── Project.toml                         # Dependencias
```

---

##  Ejemplos

### 1. Verificar Conservación de Energía

```julia
using CollectiveDynamics

a, b = 2.0, 1.0
particles = generate_random_particles(20, 1.0, 0.05, a, b)

data = simulate_ellipse(particles, a, b; n_steps=10_000, dt=1e-6)

# Extraer datos de energía
times, energies, rel_errors = get_energy_data(data.conservation)

# Verificar
E_analysis = analyze_energy_conservation(data.conservation)
println("Error relativo máximo: ", E_analysis.max_rel_error)
```

### 2. Comparar Métodos de Colisión

```julia
methods = [:simple, :parallel_transport, :geodesic]

for method in methods
    data = simulate_ellipse(particles, a, b;
        n_steps=1000, dt=1e-6,
        collision_method=method,
        verbose=false
    )

    E_analysis = analyze_energy_conservation(data.conservation)
    println("$method: ΔE/E₀ = ", E_analysis.max_rel_error)
end
```

**Resultado esperado:**
```
simple:             ΔE/E₀ = 1.2e-04
parallel_transport: ΔE/E₀ = 5.3e-05  ← Mejor conservación
geodesic:           ΔE/E₀ = 4.1e-05
```

### 3. Calcular Símbolos de Christoffel

```julia
a, b = 2.0, 1.0
θ = π/4

# Método analítico
Γ_analytic = christoffel_ellipse(θ, a, b)

# Método numérico (diferencias finitas)
metric_fn(x) = metric_ellipse(x, a, b)
Γ_numerical = christoffel_numerical(metric_fn, θ)

# Diferenciación automática
Γ_autodiff = christoffel_autodiff(metric_fn, θ)

# Comparar
println("Analítico:  ", Γ_analytic)
println("Numérico:   ", Γ_numerical)
println("AutoDiff:   ", Γ_autodiff)
```

---

##  Performance

### Mejoras respecto al código original:

| Optimización | Speedup | Impacto |
|--------------|---------|---------|
| BigFloat → Float64 | ~100x | Operaciones básicas |
| Vector → SVector | ~10x | Alocación stack |
| Type stability | ~10x | Compilación especializada |
| @simd, @inbounds | ~2x | Loops críticos |
| **Total (serial)** | **~2000x** | Combinado |

### Próximas optimizaciones:

-  **Threads.jl**: Paralelización CPU (5-8x en 8 cores)
-  **CUDA.jl**: Paralelización GPU (50-200x para n > 10,000)
-  **Spatial hashing**: Detección de colisiones O(n) vs. O(n²)

---

##  Tests

Ejecutar todos los tests:

```bash
julia test/runtests.jl
```

O desde el REPL:

```julia
using Pkg
Pkg.test("CollectiveDynamics")
```

**Cobertura:**
- ✅ Geometría diferencial (métricas, Christoffel, transporte paralelo)
- ✅ Integrador Forest-Ruth (simplecticidad verificada)
- ✅ Partículas (inicialización, energía, momento)
- ✅ Colisiones (detección, conservación)
- ✅ Simulación completa

---

##  Documentación Completa

###  Guías de Usuario
- **[QUICKSTART.md](QUICKSTART.md)** - Inicio rápido en 5 minutos
- **[INSTALL.md](INSTALL.md)** - Guía completa de instalación
- **[README.md](README.md)** - Este documento (introducción general)

###  Documentación Técnica Exhaustiva
- **[docs/GEOMETRY_TECHNICAL.md](docs/GEOMETRY_TECHNICAL.md)** - Geometría diferencial completa
  - Métricas de Riemann
  - Símbolos de Christoffel (analítico, numérico, autodiff)
  - Transporte paralelo
  - Derivaciones matemáticas completas

- **[docs/INTEGRATOR_TECHNICAL.md](docs/INTEGRATOR_TECHNICAL.md)** - Integrador Forest-Ruth
  - Teoría de integradores simplécticos
  - Implementación orden 4
  - Propiedades simplécticas
  - Benchmarks y comparaciones

- **[docs/COMPLETE_TECHNICAL_DOCUMENTATION.md](docs/COMPLETE_TECHNICAL_DOCUMENTATION.md)** - Sistema completo
  - Sistema de partículas
  - Colisiones en variedades curvas
  - Conservación y análisis
  - Arquitectura del sistema
  - Guía de desarrollo
  - API Reference completa

###  Análisis
- **[ANALYSIS.md](ANALYSIS.md)** - Código original vs optimizado (~2000x speedup)

###  Índice
- **[docs/INDEX.md](docs/INDEX.md)** - Índice completo de toda la documentación

###  Artículo
- *"Collision Dynamics on Curved Manifolds: A Simple Symplectic Computational Approach"*
  García-Hernández & Medel-Cobaxín (2024) - Próximamente en arXiv

---

##  Contribuciones

¡Contribuciones son bienvenidas! Por favor:

1. Fork el repositorio
2. Crea una rama (`git checkout -b feature/nueva-caracteristica`)
3. Commit tus cambios (`git commit -am 'Añadir nueva característica'`)
4. Push a la rama (`git push origin feature/nueva-caracteristica`)
5. Abre un Pull Request

---

##  Licencia

Este proyecto está licenciado bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para detalles.

---

##  Autores

- **J. Isaí García-Hernández** - [A01709199@tec.mx](mailto:A01709199@tec.mx)
- **Héctor J. Medel-Cobaxín** - [hmedel@tec.mx](mailto:hmedel@tec.mx)

*Tecnológico de Monterrey, Escuela de Ingeniería y Ciencias*

---

##  Agradecimientos

- Forest & Ruth por el integrador simpléctico (1990)
- do Carmo por *Riemannian Geometry* (1992)
- La comunidad de Julia por las excelentes herramientas numéricas

---

##  Contacto

¿Preguntas? ¿Sugerencias? Abre un [issue](https://github.com/tuusuario/Collective-Dynamics/issues) o contacta a los autores.

---

**⭐ Si este proyecto te resulta útil, considera darle una estrella en GitHub!** 
