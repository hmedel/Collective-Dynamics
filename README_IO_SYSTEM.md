# Sistema de Entrada/Salida - Guía Rápida

**¡NUEVO!** Ahora puedes ejecutar simulaciones sin tocar código, solo modificando archivos de configuración.

---

## 🚀 Uso Básico en 3 Pasos

###  1. Crea/modifica archivo de configuración

```bash
# Usar ejemplo incluido
cp config/simulation_example.toml config/my_simulation.toml

# Editar con tu editor favorito
nano config/my_simulation.toml
```

### 2. Ejecuta la simulación

```bash
julia --project=. run_simulation.jl config/my_simulation.toml
```

### 3. Revisa los resultados

```bash
cat results/simulation_*/summary.txt
```

---

## 📁 Ejemplos Incluidos

### Ejemplo 1: Método Adaptativo (Recomendado)
```bash
julia --project=. run_simulation.jl config/simulation_example.toml
```

**Características:**
- 10 partículas aleatorias
- Método adaptativo (alta precisión)
- Guarda trayectorias completas
- Tiempo: ~2 segundos

### Ejemplo 2: Método de dt Fijo (Rápido)
```bash
julia --project=. run_simulation.jl config/simulation_fixed_dt.toml
```

**Características:**
- 5 partículas desde CSV
- Método de dt fijo (más rápido)
- Salida mínima (ahorra espacio)
- Tiempo: ~1 segundo

---

## 📝 Archivo de Configuración (TOML)

Estructura básica:

```toml
[geometry]
a = 2.0  # Semi-eje mayor
b = 1.0  # Semi-eje menor

[simulation]
method = "adaptive"        # "adaptive" o "fixed"
max_time = 1.0
save_interval = 0.01
collision_method = "parallel_transport"

[particles.random]
enabled = true
n_particles = 10
theta_dot_min = -1.0
theta_dot_max = 1.0

[output]
base_dir = "results"
use_timestamp = true       # Crea dir con fecha/hora
save_trajectories = true
```

**Ver:** `config/simulation_example.toml` para todas las opciones

---

## 📊 Resultados Generados

Directorio automático: `results/simulation_YYYYMMDD_HHMMSS/`

**Archivos:**
- `summary.txt` - Resumen legible ⭐
- `particles_initial.csv` - Estado inicial
- `particles_final.csv` - Estado final
- `trajectories.csv` - Trayectorias completas
- `conservation.csv` - Energía/momento vs tiempo
- `config_used.toml` - Configuración usada

---

## 🎯 Casos de Uso

### Testing Rápido (5 partículas, 0.01s)
```toml
[simulation]
max_time = 0.01
[particles.random]
n_particles = 5
```

### Alta Precisión (dt muy pequeño)
```toml
[simulation]
method = "adaptive"
dt_max = 1.0e-6
```

### Muchas Partículas (usar dt fijo)
```toml
[simulation]
method = "fixed"
dt_fixed = 1.0e-5
[particles.random]
n_particles = 100
```

### Partículas Personalizadas
```toml
[particles.from_file]
enabled = true
filename = "config/my_particles.csv"
```

Formato CSV:
```csv
id,mass,radius,theta,theta_dot
1,1.0,0.05,0.0,0.5
2,1.0,0.05,1.57,0.8
```

---

## ⚙️ Parámetros Importantes

### Velocidades (CRÍTICO)
```toml
theta_dot_min = -1.0   # ✅ Realista
theta_dot_max = 1.0    # ✅ Realista
```

⚠️ **NO usar valores > 100:** Causa 99% pérdida de energía

### Método de Simulación

| Método | Cuándo Usar | Velocidad | Precisión |
|--------|-------------|-----------|-----------|
| `"adaptive"` | n < 50 partículas | Media | Excelente |
| `"fixed"` | n > 100 partículas | Rápida | Buena |

### Método de Colisión

| Método | Conservación | Velocidad |
|--------|--------------|-----------|
| `"simple"` | Buena | Rápida |
| `"parallel_transport"` | **Excelente** ⭐ | Media |
| `"geodesic"` | Muy buena | Lenta |

**Recomendado:** `"parallel_transport"` (error < 1e-6)

---

## 📚 Documentación Completa

**Para usuarios:** `SISTEMA_IO_DOCUMENTACION.md` (~100 páginas)

Incluye:
- Todas las opciones del TOML
- Formatos de archivos de salida
- Análisis de resultados (Julia/Python/R)
- Troubleshooting completo
- Casos de uso avanzados

---

## 🐛 Troubleshooting Rápido

### "Archivo no encontrado"
```bash
# Asegúrate de estar en el directorio correcto
cd /path/to/Collective-Dynamics
julia --project=. run_simulation.jl config/simulation_example.toml
```

### "99% pérdida de energía"
```toml
# Reducir velocidades en config
theta_dot_max = 1.0    # Era 100.0
```

### "1M steps warning"
```toml
# Aumentar dt_min o usar método fixed
dt_min = 1.0e-9        # Era 1.0e-10
```

---

## 🎉 Ventajas del Sistema I/O

✅ **Sin modificar código** - Solo edita archivos TOML
✅ **Resultados organizados** - Directorio con timestamp
✅ **Reproducible** - Configuración guardada con resultados
✅ **Múltiples formatos** - CSV, texto, futuro: JLD2
✅ **Análisis fácil** - Compatible con Julia/Python/R
✅ **Batch processing** - Ejecuta múltiples configs con script bash

---

## 💡 Próximos Pasos

1. **Prueba el ejemplo:**
   ```bash
   julia --project=. run_simulation.jl config/simulation_example.toml
   ```

2. **Revisa el resumen:**
   ```bash
   cat results/simulation_*/summary.txt
   ```

3. **Modifica config para tu caso:**
   ```bash
   nano config/my_simulation.toml
   ```

4. **Experimenta con parámetros**

5. **Visualiza resultados** (Python/Julia/R)

---

## 📂 Archivos del Sistema

```
run_simulation.jl                  # Script principal ⭐
config/simulation_example.toml     # Ejemplo adaptativo
config/simulation_fixed_dt.toml    # Ejemplo dt fijo
config/particles_custom.csv        # Partículas personalizadas
src/io.jl                          # Módulo I/O (interno)
SISTEMA_IO_DOCUMENTACION.md        # Doc completa
README_IO_SYSTEM.md                # Esta guía
```

---

**Fecha:** 2025-11-06
**Estado:** ✅ LISTO PARA USO
**Documentación:** `SISTEMA_IO_DOCUMENTACION.md`
