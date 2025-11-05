# ⚡ Quick Start - CollectiveDynamics.jl

Instrucciones mínimas para empezar en **5 minutos**.

---

## 🚀 Comandos Esenciales

### **1. Clonar y Preparar**

```bash
# Clonar repositorio
git clone https://github.com/hmedel/Collective-Dynamics.git
cd Collective-Dynamics

# Cambiar a la rama de desarrollo
git checkout claude/incomplete-task-recovery-011CUq95bFhkWKMNKHXgZaVN

# Instalar dependencias (toma ~5 minutos)
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

### **2. Verificar Instalación**

```bash
# Ejecutar verificación automática
julia --project=. verify_installation.jl
```

**Salida esperada:**
```
✅ TODAS LAS VERIFICACIONES PASARON
CollectiveDynamics.jl está correctamente instalado
```

### **3. Ejecutar Tests**

```bash
julia --project=. test/runtests.jl
```

### **4. Ejecutar Simulación**

```bash
julia --project=. examples/ellipse_simulation.jl
```

---

## 📝 Ejemplo Mínimo Interactivo

```bash
julia --project=.
```

```julia
using CollectiveDynamics

# Generar 10 partículas en una elipse
particles = generate_random_particles(10, 1.0, 0.05, 2.0, 1.0)

# Simular 1000 pasos
data = simulate_ellipse(particles, 2.0, 1.0; n_steps=1000, dt=1e-6)

# Analizar conservación
print_conservation_summary(data.conservation)
```

---

## 🆘 Problemas?

Ver **[INSTALL.md](INSTALL.md)** para instrucciones detalladas.

---

## ✅ Checklist Rápido

```bash
# Todo en uno:
git clone https://github.com/hmedel/Collective-Dynamics.git && \
cd Collective-Dynamics && \
git checkout claude/incomplete-task-recovery-011CUq95bFhkWKMNKHXgZaVN && \
julia --project=. -e 'using Pkg; Pkg.instantiate()' && \
julia --project=. verify_installation.jl
```

Si el último comando muestra ✅, **¡estás listo!**
