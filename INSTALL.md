# 🚀 Guía de Instalación y Ejecución - CollectiveDynamics.jl

Esta guía te llevará desde cero hasta ejecutar las simulaciones completas.

---

## 📋 Requisitos Previos

### 1. **Instalar Julia** (si no la tienes)

#### **Linux / macOS:**
```bash
# Descargar Julia 1.9+ desde el sitio oficial
curl -fsSL https://install.julialang.org | sh

# O usar el instalador oficial:
# https://julialang.org/downloads/
```

#### **Windows:**
Descarga el instalador desde: https://julialang.org/downloads/

#### **Verificar instalación:**
```bash
julia --version
# Debe mostrar: julia version 1.9.x o superior
```

### 2. **Instalar Git** (si no lo tienes)
```bash
# Linux (Ubuntu/Debian)
sudo apt-get install git

# macOS (con Homebrew)
brew install git

# Windows
# Descarga desde: https://git-scm.com/download/win
```

---

## 📥 Paso 1: Clonar el Repositorio

Abre una terminal y ejecuta:

```bash
# Clonar el repositorio
git clone https://github.com/hmedel/Collective-Dynamics.git

# Entrar al directorio
cd Collective-Dynamics

# Cambiar a la rama de desarrollo
git checkout claude/incomplete-task-recovery-011CUq95bFhkWKMNKHXgZaVN
```

**Verificar que estés en la rama correcta:**
```bash
git branch
# Debe mostrar: * claude/incomplete-task-recovery-011CUq95bFhkWKMNKHXgZaVN
```

---

## 📦 Paso 2: Instalar Dependencias de Julia

### **Opción A: Instalación Automática (Recomendada)**

```bash
# Desde la terminal, en el directorio Collective-Dynamics/
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

Esto instalará automáticamente todas las dependencias listadas en `Project.toml`:
- StaticArrays
- ForwardDiff
- Elliptic
- DataFrames
- CSV
- GLMakie (para visualización futura)
- CUDA (para GPU, opcional)

**Tiempo estimado:** 5-10 minutos (primera vez)

### **Opción B: Instalación Manual (si la Opción A falla)**

```bash
# Abrir Julia en modo proyecto
julia --project=.
```

Dentro del REPL de Julia:
```julia
using Pkg

# Instalar dependencias principales
Pkg.add("StaticArrays")
Pkg.add("ForwardDiff")
Pkg.add("Elliptic")
Pkg.add("DataFrames")
Pkg.add("CSV")
Pkg.add("GLMakie")

# Precompilar todo
Pkg.precompile()

# Salir
exit()
```

---

## ✅ Paso 3: Verificar Instalación con Tests

### **Ejecutar Tests Unitarios:**

```bash
# Opción 1: Desde la terminal
julia --project=. test/runtests.jl
```

**O:**

```bash
# Opción 2: Desde el REPL de Julia
julia --project=.
```

Dentro del REPL:
```julia
using Pkg
Pkg.test()
```

**Salida esperada:**
```
Test Summary:                | Pass  Total
CollectiveDynamics.jl        |   XX     XX
  Métrica de Elipse          |    X      X
  Símbolos de Christoffel    |    X      X
  Transporte Paralelo        |    X      X
  Integrador Forest-Ruth     |    X      X
  Struct Particle            |    X      X
  Generar Partículas Aleatorias |  X    X
  Detección de Colisiones    |    X      X
  Conservación en Colisiones |    X      X
  ConservationData           |    X      X
  Simulación Corta           |    X      X

✅ Todos los tests pasaron exitosamente!
```

**Si todos los tests pasan:** ✅ La instalación está completa.

**Si hay errores:**
- Verifica que Julia sea versión 1.9+
- Revisa que todas las dependencias se instalaron
- Abre un issue en GitHub con el error

---

## 🎮 Paso 4: Ejecutar Ejemplo de Simulación

### **Ejecutar el ejemplo completo:**

```bash
# Desde la terminal
julia --project=. examples/ellipse_simulation.jl
```

**Salida esperada (simplificada):**

```
╔════════════════════════════════════════════════════════════════════╗
║        Simulación de Dinámica Colectiva en Elipse                 ║
╚════════════════════════════════════════════════════════════════════╝

📋 PARÁMETROS:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Elipse (a, b):        (2.00, 1.00)
  Partículas:           40
  Pasos de tiempo:      100000
  dt:                   1.00e-08
  Método colisión:      parallel_transport

🚀 Iniciando simulación...

Progreso: 10.0% | Colisiones: 5 | t = 0.000010
Progreso: 20.0% | Colisiones: 3 | t = 0.000020
...
Progreso: 100.0% | Colisiones: 2 | t = 0.000100

📊 ANÁLISIS DE CONSERVACIÓN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 ENERGÍA:
  Inicial:           1.234567e+08
  Final:             1.234566e+08
  Error relativo max: 8.23e-05
  ✅ Conservada:      SÍ

💾 Guardando resultados...
✅ Resultados guardados en: ellipse_simulation_results.csv

╔════════════════════════════════════════════════════════════════════╗
║                    SIMULACIÓN COMPLETADA                           ║
╚════════════════════════════════════════════════════════════════════╝
```

**Archivo generado:** `ellipse_simulation_results.csv` con datos de conservación.

---

## 🧪 Paso 5: Experimentar Interactivamente

### **Abrir REPL de Julia en modo proyecto:**

```bash
julia --project=.
```

### **Ejemplo interactivo básico:**

```julia
# Cargar el módulo
using CollectiveDynamics

# Verificar versión
version_info()

# Parámetros de la elipse
a, b = 2.0, 1.0

# Generar 10 partículas
particles = generate_random_particles(10, 1.0, 0.05, a, b)

# Ver primera partícula
println(particles[1])

# Simular (versión corta para probar)
data = simulate_ellipse(
    particles, a, b;
    n_steps=1000,
    dt=1e-6,
    collision_method=:parallel_transport,
    verbose=true
)

# Analizar conservación
print_conservation_summary(data.conservation)
```

### **Probar funciones geométricas:**

```julia
using CollectiveDynamics

a, b = 2.0, 1.0
θ = π/4

# Métrica
g = metric_ellipse(θ, a, b)
println("Métrica g_θθ = ", g)

# Símbolos de Christoffel
Γ = christoffel_ellipse(θ, a, b)
println("Christoffel Γ^θ_θθ = ", Γ)

# Comparar métodos
comparison = compare_christoffel_methods(θ, a, b)
println(comparison)

# Transporte paralelo
v = 1.0
Δθ = 0.01
v_transported = parallel_transport_velocity(v, Δθ, θ, a, b)
println("Velocidad transportada: ", v_transported)
```

---

## 🐛 Solución de Problemas Comunes

### **Error: "Package not found"**

```bash
# Reinstalar dependencias
julia --project=. -e 'using Pkg; Pkg.resolve(); Pkg.instantiate()'
```

### **Error: "LoadError: UndefVarError"**

Asegúrate de estar en el directorio correcto y usar `--project=.`:
```bash
cd Collective-Dynamics
julia --project=.
```

### **Error: "MethodError" o problemas de tipos**

Verifica la versión de Julia:
```bash
julia --version
# Debe ser 1.9.0 o superior
```

### **Tests fallan por timeout**

Algunos tests pueden tardar. Si quieres tests más rápidos, edita `test/runtests.jl`:
```julia
# Cambiar:
n_steps=100  # En vez de 1000
```

### **Error con Elliptic.jl**

Si hay problemas con el paquete Elliptic:
```julia
using Pkg
Pkg.add(url="https://github.com/nolta/Elliptic.jl")
Pkg.build("Elliptic")
```

---

## 📊 Paso 6: Ver Resultados

Los resultados se guardan en `ellipse_simulation_results.csv`. Puedes visualizarlos con:

### **Python (Pandas + Matplotlib):**
```python
import pandas as pd
import matplotlib.pyplot as plt

df = pd.read_csv('ellipse_simulation_results.csv')

plt.figure(figsize=(10, 4))
plt.plot(df['time'], df['energy'])
plt.xlabel('Tiempo')
plt.ylabel('Energía Total')
plt.title('Conservación de Energía')
plt.show()
```

### **Julia (Plots.jl):**
```julia
using CSV, DataFrames, Plots

df = CSV.read("ellipse_simulation_results.csv", DataFrame)

plot(df.time, df.energy,
     xlabel="Tiempo",
     ylabel="Energía Total",
     title="Conservación de Energía",
     legend=false)
```

### **Excel / Google Sheets:**
Simplemente abre el archivo CSV.

---

## 🎯 Resumen de Comandos (TL;DR)

```bash
# 1. Clonar repo
git clone https://github.com/hmedel/Collective-Dynamics.git
cd Collective-Dynamics
git checkout claude/incomplete-task-recovery-011CUq95bFhkWKMNKHXgZaVN

# 2. Instalar dependencias
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# 3. Ejecutar tests
julia --project=. test/runtests.jl

# 4. Ejecutar ejemplo
julia --project=. examples/ellipse_simulation.jl

# 5. Modo interactivo
julia --project=.
```

---

## 📞 Ayuda Adicional

- **GitHub Issues:** https://github.com/hmedel/Collective-Dynamics/issues
- **Documentación Julia:** https://docs.julialang.org/
- **Contacto:** hmedel@tec.mx

---

## ✅ Checklist de Verificación

- [ ] Julia 1.9+ instalado
- [ ] Repositorio clonado
- [ ] Rama correcta (`claude/incomplete-task-recovery-011CUq95bFhkWKMNKHXgZaVN`)
- [ ] Dependencias instaladas (`Pkg.instantiate()`)
- [ ] Tests pasan (`test/runtests.jl`)
- [ ] Ejemplo ejecuta (`examples/ellipse_simulation.jl`)
- [ ] Resultados CSV generados

**Si todos los puntos están ✅, la instalación es exitosa!**

---

**¿Problemas?** Abre un issue con:
1. Tu versión de Julia (`julia --version`)
2. Sistema operativo
3. Mensaje de error completo
4. Qué comando ejecutaste
