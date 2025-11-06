# Sistema de Entrada/Salida Basado en Archivos

**Fecha:** 2025-11-06
**Versión:** 1.0

---

## 🎯 Objetivo

Ejecutar simulaciones **sin modificar código**, usando solo archivos de configuración. Todos los resultados se guardan automáticamente en un directorio organizado.

---

## 🚀 Inicio Rápido

### 1. Ejecutar Simulación

```bash
julia --project=. run_simulation.jl config/simulation_example.toml
```

¡Eso es todo! El script:
- Lee la configuración
- Crea/carga partículas
- Ejecuta la simulación
- Guarda todos los resultados

### 2. Ver Resultados

```bash
cat results/simulation_20250106_143022/summary.txt
```

---

## 📁 Estructura de Archivos

```
Collective-Dynamics/
├── config/                         # Configuraciones
│   ├── simulation_example.toml    # Ejemplo con método adaptativo
│   ├── simulation_fixed_dt.toml   # Ejemplo con dt fijo
│   └── particles_custom.csv       # Partículas personalizadas
│
├── run_simulation.jl              # Script principal ⭐
│
├── results/                        # Resultados (auto-creado)
│   └── simulation_YYYYMMDD_HHMMSS/
│       ├── config_used.toml       # Configuración usada
│       ├── config_parsed.toml     # Config parseada
│       ├── particles_initial.csv  # Estado inicial
│       ├── particles_final.csv    # Estado final
│       ├── trajectories.csv       # Trayectorias completas
│       ├── conservation.csv       # Energía y momento vs tiempo
│       └── summary.txt            # Resumen legible
│
└── src/
    └── io.jl                      # Módulo de I/O (interno)
```

---

## 📝 Formato del Archivo de Configuración (TOML)

### Estructura Completa

```toml
[geometry]
a = 2.0  # Semi-eje mayor
b = 1.0  # Semi-eje menor

[simulation]
method = "adaptive"              # "adaptive" o "fixed"
max_time = 1.0
save_interval = 0.01
dt_max = 1.0e-5                  # Solo adaptativo
dt_min = 1.0e-10                 # Solo adaptativo
dt_fixed = 1.0e-5                # Solo fixed
collision_method = "parallel_transport"
tolerance = 1.0e-6
verbose = true

[particles.random]
enabled = true                   # Generar aleatorias
n_particles = 10
mass = 1.0
radius = 0.1
theta_dot_min = -1.0
theta_dot_max = 1.0
seed = 1234                      # Opcional

[particles.from_file]
enabled = false                  # O desde archivo
filename = "config/particles_custom.csv"

[output]
base_dir = "results"
use_timestamp = true             # Crea dir con fecha/hora
custom_name = "my_simulation"    # Si use_timestamp = false
save_csv = true
save_jld2 = false                # Formato binario Julia
save_summary = true
save_trajectories = true
save_conservation = true
save_initial_final = true
save_collision_events = false
copy_config = true

[analysis]
compute_energy_stats = true
compute_collision_stats = true
compute_phase_space = false
generate_plots = false           # Futuro

[resources]
n_threads = 1                    # Futuro
use_gpu = false                  # Futuro
```

---

## 🔧 Opciones Detalladas

### Geometría

| Parámetro | Tipo | Descripción |
|-----------|------|-------------|
| `a` | Float | Semi-eje mayor de la elipse (> 0) |
| `b` | Float | Semi-eje menor de la elipse (> 0) |

**Convención:** Usualmente `a ≥ b`

---

### Simulación

#### Método Adaptativo (`method = "adaptive"`)

**Ventajas:**
- Detección exacta de colisiones
- Mejor conservación de energía
- Ajuste automático de dt

**Recomendado para:** n < 50 partículas

**Parámetros:**
```toml
[simulation]
method = "adaptive"
dt_max = 1.0e-5      # Paso máximo permitido
dt_min = 1.0e-10     # Paso mínimo (evita stuck)
```

#### Método de dt Fijo (`method = "fixed"`)

**Ventajas:**
- Más rápido
- Predecible
- Mejor para sistemas densos

**Recomendado para:** n > 100 partículas

**Parámetros:**
```toml
[simulation]
method = "fixed"
dt_fixed = 1.0e-5    # Paso de tiempo constante
```

#### Métodos de Colisión

| Método | Descripción | Conservación |
|--------|-------------|--------------|
| `"simple"` | Intercambio simple | Buena |
| `"parallel_transport"` | Transporte paralelo con RK4 | **Excelente** ⭐ |
| `"geodesic"` | Basado en geodésicas | Muy buena |

**Recomendado:** `"parallel_transport"` (conservación < 1e-6)

---

### Partículas

#### Opción 1: Generación Aleatoria

```toml
[particles.random]
enabled = true
n_particles = 10
mass = 1.0
radius = 0.1           # Fracción del semi-eje menor
theta_dot_min = -1.0   # Velocidad angular mínima
theta_dot_max = 1.0    # Velocidad angular máxima
seed = 1234            # Para reproducibilidad
```

**Rango de velocidades recomendado:** `[-1.0, 1.0]` rad/s

⚠️ **NO usar valores > 100:** Causa inestabilidad numérica

#### Opción 2: Desde Archivo CSV

```toml
[particles.from_file]
enabled = true
filename = "config/particles_custom.csv"
```

**Formato del CSV:**
```csv
# Comentarios con #
id,mass,radius,theta,theta_dot
1,1.0,0.05,0.0,0.5
2,1.0,0.05,1.57,0.8
...
```

**Columnas:**
- `id`: Identificador único (entero)
- `mass`: Masa de la partícula
- `radius`: Radio de la partícula
- `theta`: Posición angular inicial (0 a 2π radianes)
- `theta_dot`: Velocidad angular inicial (rad/s)

---

### Salida

#### Directorio de Resultados

```toml
[output]
base_dir = "results"
use_timestamp = true   # Crea: results/simulation_20250106_143022/
custom_name = "test1"  # Si false: results/test1/
```

#### Archivos a Guardar

| Opción | Archivo Generado | Tamaño | Descripción |
|--------|------------------|--------|-------------|
| `save_initial_final` | `particles_initial.csv`<br>`particles_final.csv` | Pequeño | Solo estados extremos |
| `save_trajectories` | `trajectories.csv` | **Grande** | Todas las posiciones guardadas |
| `save_conservation` | `conservation.csv` | Mediano | Energía/momento vs tiempo |
| `save_summary` | `summary.txt` | Pequeño | Resumen legible |

**Recomendación para simulaciones grandes:**
```toml
save_trajectories = false       # Ahorra mucho espacio
save_initial_final = true
save_conservation = true
save_summary = true
```

---

## 📊 Formato de Archivos de Salida

### 1. `particles_initial.csv` y `particles_final.csv`

```csv
id,mass,radius,theta,theta_dot,x,y,vx,vy
1,1.0,0.05,0.0,0.5,2.0,0.0,0.0,0.5
2,1.0,0.05,1.57,0.8,0.0,1.0,-0.8,0.0
...
```

**Uso:** Comparar estados inicial/final, verificar deriva

### 2. `trajectories.csv`

```csv
time,particle_id,theta,theta_dot,x,y,vx,vy
0.0,1,0.0,0.5,2.0,0.0,0.0,0.5
0.0,2,1.57,0.8,0.0,1.0,-0.8,0.0
0.01,1,0.005,0.501,1.999,0.005,0.0,0.501
...
```

**Uso:** Visualización, análisis detallado

⚠️ **Advertencia:** Puede ser muy grande (GB para simulaciones largas)

### 3. `conservation.csv`

```csv
time,total_energy,total_momentum
0.0,4.50392782,0.0
0.01,4.50392780,1.2e-15
0.02,4.50392781,-3.4e-16
...
```

**Uso:** Verificar conservación, detectar problemas numéricos

### 4. `summary.txt`

```
======================================================================
RESUMEN DE SIMULACIÓN
======================================================================

Fecha: 2025-01-06 14:30:22

CONFIGURACIÓN:
  Geometría: a = 2.0, b = 1.0
  Método: adaptive
  Tiempo simulado: 1.0 unidades
  Partículas: 10

RESULTADOS:
  Pasos de tiempo: 1001
  Colisiones totales: 0

CONSERVACIÓN DE ENERGÍA:
  Energía inicial:  4.5039278174
  Energía final:    4.5039277558
  Error máximo:     1.368739e-08
  Drift relativo:   -1.368739e-08

  ✅ EXCELENTE: Error < 1e-6
```

**Uso:** Revisión rápida de resultados

---

## 💡 Casos de Uso

### Caso 1: Simulación Rápida para Testing

```toml
[simulation]
method = "adaptive"
max_time = 0.01          # Muy corto
save_interval = 0.001

[particles.random]
n_particles = 5          # Pocas partículas

[output]
save_trajectories = false  # Solo resumen
save_initial_final = true
```

**Tiempo:** ~1 segundo

---

### Caso 2: Simulación de Alta Precisión

```toml
[simulation]
method = "adaptive"
max_time = 10.0
dt_max = 1.0e-6          # Paso muy pequeño
save_interval = 0.1

[particles.random]
n_particles = 10

[output]
save_trajectories = true   # Todo guardado
save_conservation = true
```

**Tiempo:** ~10 minutos
**Espacio:** ~100 MB

---

### Caso 3: Muchas Partículas (Rápido)

```toml
[simulation]
method = "fixed"           # Más rápido que adaptive
dt_fixed = 1.0e-5
max_time = 1.0

[particles.random]
n_particles = 100

[output]
save_trajectories = false  # Ahorrar espacio
save_initial_final = true
```

**Tiempo:** ~30 segundos
**Espacio:** ~1 MB

---

### Caso 4: Partículas Personalizadas

Archivo `config/my_particles.csv`:
```csv
id,mass,radius,theta,theta_dot
1,1.0,0.05,0.0,1.0
2,2.0,0.08,3.14,-0.5
3,0.5,0.03,1.57,2.0
```

Configuración:
```toml
[particles.random]
enabled = false

[particles.from_file]
enabled = true
filename = "config/my_particles.csv"
```

---

## 🔬 Análisis de Resultados

### Usando Julia

```julia
using DelimitedFiles
using Plots

# Leer conservación
data = readdlm("results/simulation_20250106_143022/conservation.csv",
               ',', Float64, '\n'; header=true)

times = data[1][:, 1]
energies = data[1][:, 2]

# Graficar
plot(times, energies, label="Energy", xlabel="Time", ylabel="E")
```

### Usando Python

```python
import pandas as pd
import matplotlib.pyplot as plt

# Leer trayectorias
df = pd.read_csv("results/simulation_20250106_143022/trajectories.csv")

# Filtrar partícula 1
p1 = df[df['particle_id'] == 1]

# Graficar trayectoria
plt.plot(p1['x'], p1['y'])
plt.axis('equal')
plt.show()
```

### Usando R

```r
library(tidyverse)

# Leer datos
df <- read_csv("results/simulation_20250106_143022/conservation.csv")

# Graficar
ggplot(df, aes(x=time, y=total_energy)) +
  geom_line() +
  labs(title="Energy Conservation")
```

---

## ⚙️ Opciones Avanzadas

### Reproducibilidad

Usa semilla fija para resultados reproducibles:

```toml
[particles.random]
seed = 12345
```

Dos ejecuciones con la misma configuración y semilla darán resultados **idénticos**.

### Optimización de Espacio

Para simulaciones largas con muchas partículas:

```toml
[simulation]
save_interval = 0.1        # Guardar menos frames

[output]
save_trajectories = false  # No guardar trayectorias
save_initial_final = true  # Solo extremos
```

**Reducción:** Factor de 100x en espacio

### Múltiples Simulaciones

Script bash para ejecutar varias configuraciones:

```bash
#!/bin/bash
for config in config/experiment_*.toml; do
    echo "Ejecutando $config..."
    julia --project=. run_simulation.jl $config
done
```

---

## 🐛 Troubleshooting

### Error: "Archivo no encontrado"

```
❌ Error: Archivo no encontrado: config/mi_config.toml
```

**Solución:** Verifica la ruta relativa. Ejecuta desde el directorio raíz del proyecto.

```bash
cd /path/to/Collective-Dynamics
julia --project=. run_simulation.jl config/simulation_example.toml
```

---

### Error: "Falta columna en CSV"

```
❌ Error: Falta columna 'theta_dot' en config/particles.csv
```

**Solución:** Verifica que el CSV tenga todas las columnas requeridas:
```
id,mass,radius,theta,theta_dot
```

---

### Error: "99% pérdida de energía"

```
❌ ALTO: Error > 1e-2
Drift relativo: -9.913497e-01
```

**Causa:** Velocidades demasiado altas

**Solución:** Reduce `theta_dot_max`:
```toml
theta_dot_min = -1.0    # NO -100.0
theta_dot_max = 1.0     # NO +100.0
```

---

### Warning: "Alcanzado límite de pasos"

```
⚠️ Warning: Alcanzado límite de pasos (1M)
```

**Causa:** Partículas pegadas (método adaptativo)

**Soluciones:**
1. Aumentar `dt_min` a `1e-9`
2. Reducir `radius` de partículas
3. Usar método `"fixed"` en lugar de `"adaptive"`

---

## 📚 Ejemplos Incluidos

### 1. `config/simulation_example.toml`

- **Método:** Adaptativo
- **Partículas:** 10 aleatorias
- **Salida:** Completa (trayectorias + resumen)
- **Uso:** Ejemplo general, testing

### 2. `config/simulation_fixed_dt.toml`

- **Método:** dt fijo
- **Partículas:** Desde archivo CSV
- **Salida:** Mínima (solo inicial/final + resumen)
- **Uso:** Simulaciones rápidas, muchas partículas

### 3. `config/particles_custom.csv`

- 5 partículas predefinidas
- Posiciones uniformemente espaciadas
- Velocidades variadas
- **Uso:** Testing con configuración conocida

---

## 🎯 Resumen de Comandos

```bash
# Ejecutar simulación
julia --project=. run_simulation.jl config/simulation_example.toml

# Ver resumen
cat results/simulation_*/summary.txt

# Listar resultados
ls -lh results/simulation_*/

# Limpiar resultados antiguos
rm -rf results/simulation_2025*
```

---

## 🚀 Próximos Pasos

Después de ejecutar tu primera simulación:

1. **Inspecciona** `summary.txt` para verificar conservación
2. **Modifica** el archivo TOML para tu caso de uso
3. **Experimenta** con diferentes `n_particles`, `dt_max`, etc.
4. **Visualiza** resultados con scripts de análisis

---

## 📞 Soporte

**Problemas?**
1. Ver sección Troubleshooting arriba
2. Verificar que estás en el directorio correcto
3. Revisar `QUICK_REFERENCE_ADAPTIVE.md` para métricas esperadas

**Todo funcionando?** ✅ Empieza a experimentar!

---

**Última actualización:** 2025-11-06
**Versión del sistema:** 1.0
**Estado:** ✅ PRODUCCIÓN READY
