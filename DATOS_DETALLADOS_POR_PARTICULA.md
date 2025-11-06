# Datos Detallados por Partícula - Guía Completa

**Actualización:** 2025-11-06
**Nueva característica:** Información completa por partícula en cada iteración

---

## 🎯 ¿Qué Datos Están Disponibles?

El sistema ahora guarda **información completa** de cada partícula en cada paso de tiempo:

✅ **Posiciones** (θ, x, y)
✅ **Velocidades** (θ_dot, vx, vy)
✅ **Energía individual** de cada partícula
✅ **Información de colisiones** por paso

---

## 📊 Archivos de Salida

Después de ejecutar una simulación, encontrarás estos archivos en `results/simulation_YYYYMMDD_HHMMSS/`:

### 1. `trajectories.csv` ⭐ PRINCIPAL

**Contiene:** Toda la información de cada partícula en cada paso guardado

**Columnas:**
```csv
time,particle_id,theta,theta_dot,x,y,vx,vy,energy
```

| Columna | Descripción | Unidades |
|---------|-------------|----------|
| `time` | Tiempo de simulación | segundos |
| `particle_id` | ID único de la partícula | entero |
| `theta` | Posición angular en la elipse | radianes (0 a 2π) |
| `theta_dot` | Velocidad angular | rad/s |
| `x` | Posición cartesiana X | unidades de longitud |
| `y` | Posición cartesiana Y | unidades de longitud |
| `vx` | Velocidad cartesiana X | unidades/s |
| `vy` | Velocidad cartesiana Y | unidades/s |
| `energy` | Energía cinética individual | unidades de energía |

**Ejemplo:**
```csv
time,particle_id,theta,theta_dot,x,y,vx,vy,energy
0.0000000000,1,0.0000000000,0.5000000000,2.0000000000,0.0000000000,0.0000000000,0.5000000000,1.250000e-01
0.0000000000,2,1.5700000000,0.8000000000,0.0050000000,1.0000000000,-0.8000000000,0.0040000000,3.200000e-01
0.0100000000,1,0.0050000000,0.5010000000,1.9999500000,0.0050000000,0.0000100000,0.5010000000,1.252501e-01
```

---

### 2. `collisions_per_step.csv` ⭐ COLISIONES

**Contiene:** Información de colisiones en cada paso de tiempo

**Columnas:**
```csv
step,time,n_collisions,conserved_fraction,had_collision
```

| Columna | Descripción | Valores |
|---------|-------------|---------|
| `step` | Número de paso | 1, 2, 3, ... |
| `time` | Tiempo de simulación | segundos |
| `n_collisions` | Número de colisiones en ese paso | 0, 1, 2, ... |
| `conserved_fraction` | Fracción de colisiones que conservaron energía | 0.0 a 1.0 |
| `had_collision` | Indicador booleano | 0=no, 1=sí |

**Ejemplo:**
```csv
step,time,n_collisions,conserved_fraction,had_collision
1,0.0000000000,0,1.000000,0
2,0.0000100000,0,1.000000,0
3,0.0000200000,1,1.000000,1
4,0.0000300000,0,1.000000,0
5,0.0000400000,2,1.000000,1
```

**Interpretación:**
- Paso 1-2: Sin colisiones
- Paso 3: 1 colisión, conservó energía perfectamente
- Paso 4: Sin colisiones
- Paso 5: 2 colisiones, ambas conservaron energía

---

### 3. `conservation.csv`

**Contiene:** Energía total y momento total del sistema en cada paso

**Columnas:**
```csv
time,total_energy,total_momentum
```

**Uso:** Verificar conservación global del sistema

---

### 4. `particles_initial.csv` y `particles_final.csv`

**Contiene:** Estado completo al inicio y al final

**Columnas:**
```csv
id,mass,radius,theta,theta_dot,x,y,vx,vy
```

**Uso:** Comparar estado inicial vs final, calcular deriva

---

## 📈 Ejemplos de Análisis

### Ejemplo 1: Energía Individual por Partícula (Python)

```python
import pandas as pd
import matplotlib.pyplot as plt

# Leer datos
df = pd.read_csv("results/simulation_*/trajectories.csv")

# Graficar energía de cada partícula
fig, ax = plt.subplots(figsize=(12, 6))

for particle_id in df['particle_id'].unique():
    data = df[df['particle_id'] == particle_id]
    ax.plot(data['time'], data['energy'],
            label=f'Partícula {particle_id}')

ax.set_xlabel('Tiempo (s)')
ax.set_ylabel('Energía (J)')
ax.set_title('Energía Individual por Partícula')
ax.legend()
ax.grid(True)
plt.show()
```

---

### Ejemplo 2: Velocidades Angulares (Python)

```python
import pandas as pd
import matplotlib.pyplot as plt

df = pd.read_csv("results/simulation_*/trajectories.csv")

# Graficar velocidades angulares
fig, ax = plt.subplots(figsize=(12, 6))

for particle_id in df['particle_id'].unique():
    data = df[df['particle_id'] == particle_id]
    ax.plot(data['time'], data['theta_dot'],
            label=f'Partícula {particle_id}', alpha=0.7)

ax.set_xlabel('Tiempo (s)')
ax.set_ylabel('Velocidad Angular (rad/s)')
ax.set_title('Velocidades Angulares por Partícula')
ax.legend()
ax.grid(True)
plt.show()
```

---

### Ejemplo 3: Detectar Colisiones (Python)

```python
import pandas as pd

# Leer datos de colisiones
df_coll = pd.read_csv("results/simulation_*/collisions_per_step.csv")

# Filtrar solo pasos con colisiones
collisions = df_coll[df_coll['had_collision'] == 1]

print(f"Total de pasos con colisiones: {len(collisions)}")
print(f"Total de colisiones individuales: {collisions['n_collisions'].sum()}")
print(f"Conservación promedio: {collisions['conserved_fraction'].mean():.6f}")

# Ver momentos específicos de colisión
print("\nPrimeras 10 colisiones:")
print(collisions.head(10))
```

---

### Ejemplo 4: Trayectorias en el Espacio (Python)

```python
import pandas as pd
import matplotlib.pyplot as plt

df = pd.read_csv("results/simulation_*/trajectories.csv")

# Graficar trayectorias en el plano XY
fig, ax = plt.subplots(figsize=(10, 8))

for particle_id in df['particle_id'].unique():
    data = df[df['particle_id'] == particle_id]
    ax.plot(data['x'], data['y'],
            label=f'Partícula {particle_id}',
            alpha=0.6)

ax.set_xlabel('X')
ax.set_ylabel('Y')
ax.set_title('Trayectorias en el Espacio')
ax.axis('equal')
ax.legend()
ax.grid(True)
plt.show()
```

---

### Ejemplo 5: Estadísticas de Colisiones (Julia)

```julia
using DelimitedFiles, Statistics

# Leer datos
data = readdlm("results/simulation_*/collisions_per_step.csv",
               ',', header=true)

collisions = data[1]

# Filtrar pasos con colisiones
steps_with_coll = collisions[:, 5] .== 1
n_steps_with_coll = sum(steps_with_coll)

println("Estadísticas de Colisiones:")
println("  Pasos con colisiones: $n_steps_with_coll")
println("  Colisiones totales: ", sum(collisions[:, 3]))
println("  Conservación media: ", mean(collisions[steps_with_coll, 4]))

# Histograma de colisiones por paso
using Plots
histogram(collisions[steps_with_coll, 3],
          xlabel="Colisiones por paso",
          ylabel="Frecuencia",
          title="Distribución de Colisiones")
```

---

### Ejemplo 6: Análisis de Energía Antes/Después Colisión (Python)

```python
import pandas as pd

df_traj = pd.read_csv("results/simulation_*/trajectories.csv")
df_coll = pd.read_csv("results/simulation_*/collisions_per_step.csv")

# Obtener tiempos de colisión
collision_times = df_coll[df_coll['had_collision'] == 1]['time'].values

# Para cada colisión, analizar energías
for i, t_coll in enumerate(collision_times[:10]):  # Primeras 10
    # Frame antes y después
    before = df_traj[df_traj['time'] < t_coll].groupby('time').last()
    after = df_traj[df_traj['time'] > t_coll].groupby('time').first()

    if len(before) > 0 and len(after) > 0:
        E_before = before['energy'].sum()
        E_after = after['energy'].sum()

        print(f"Colisión {i+1} en t={t_coll:.6f}:")
        print(f"  E antes:   {E_before:.6e}")
        print(f"  E después: {E_after:.6e}")
        print(f"  ΔE/E:      {abs(E_after-E_before)/E_before:.6e}")
        print()
```

---

## 🔍 Preguntas Frecuentes

### ¿Cómo sé cuándo colisionó cada partícula?

Usa `collisions_per_step.csv` para saber EN QUÉ PASOS hubo colisiones.
Luego busca esos tiempos en `trajectories.csv` para ver el estado de las partículas.

```python
# Obtener tiempos de colisión
df_coll = pd.read_csv("collisions_per_step.csv")
collision_times = df_coll[df_coll['had_collision'] == 1]['time']

# Para cada tiempo, ver estado de partículas
df_traj = pd.read_csv("trajectories.csv")
for t in collision_times:
    estado = df_traj[df_traj['time'] == t]
    print(f"En t={t}:")
    print(estado[['particle_id', 'theta', 'theta_dot', 'energy']])
```

### ¿Cómo calculo la energía total del sistema?

```python
df = pd.read_csv("trajectories.csv")
energy_total_by_time = df.groupby('time')['energy'].sum()
```

O usa directamente `conservation.csv` que tiene `total_energy`.

### ¿Puedo saber CUÁLES partículas colisionaron?

Actualmente el sistema guarda el NÚMERO de colisiones por paso, no el detalle de qué pares colisionaron.

Para inferirlo, busca partículas cuyas velocidades cambian abruptamente:

```python
df = pd.read_csv("trajectories.csv")

for pid in df['particle_id'].unique():
    data = df[df['particle_id'] == pid]
    # Calcular cambios en velocidad
    dv = data['theta_dot'].diff().abs()
    # Picos grandes indican colisiones
    likely_collisions = data[dv > threshold]['time']
    print(f"Partícula {pid} colisionó cerca de: {likely_collisions.values}")
```

### ¿Cuánto espacio ocupan estos archivos?

Depende de la simulación:

- **10 partículas, 1000 pasos guardados:** ~1 MB
- **50 partículas, 10000 pasos:** ~50 MB
- **100 partículas, 100000 pasos:** ~1 GB

**Recomendación:** Ajusta `save_interval` en la configuración:
```toml
save_interval = 0.1  # Guardar cada 0.1s (menos frames)
```

---

## ⚙️ Configuración

Para activar/desactivar estos datos, modifica tu archivo TOML:

```toml
[output]
save_trajectories = true        # ✅ Activa para datos completos
save_collision_events = true    # ✅ Activa para info de colisiones
```

**Para ahorrar espacio (simulaciones largas):**
```toml
[simulation]
save_interval = 0.1             # Guardar menos frames

[output]
save_trajectories = false       # Solo inicial/final
save_collision_events = true    # Colisiones siempre útiles
```

---

## 📚 Resumen de Capacidades

| Información | Archivo | Disponible |
|-------------|---------|------------|
| **Posición angular (θ)** | trajectories.csv | ✅ Por partícula, cada paso |
| **Velocidad angular (θ_dot)** | trajectories.csv | ✅ Por partícula, cada paso |
| **Posición cartesiana (x,y)** | trajectories.csv | ✅ Por partícula, cada paso |
| **Velocidad cartesiana (vx,vy)** | trajectories.csv | ✅ Por partícula, cada paso |
| **Energía individual** | trajectories.csv | ✅ Por partícula, cada paso |
| **Energía total** | conservation.csv | ✅ Cada paso |
| **¿Hubo colisión?** | collisions_per_step.csv | ✅ Cada paso |
| **Cuántas colisiones** | collisions_per_step.csv | ✅ Cada paso |
| **¿Conservó energía?** | collisions_per_step.csv | ✅ Cada paso |
| **Qué partículas colisionaron** | - | ❌ No directamente |

---

## 💡 Ejemplo Completo: Analizar Simulación

```python
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

# 1. Cargar todos los datos
df_traj = pd.read_csv("results/simulation_*/trajectories.csv")
df_coll = pd.read_csv("results/simulation_*/collisions_per_step.csv")
df_cons = pd.read_csv("results/simulation_*/conservation.csv")

# 2. Información básica
print("="*60)
print("ANÁLISIS DE SIMULACIÓN")
print("="*60)
print(f"Partículas: {df_traj['particle_id'].nunique()}")
print(f"Tiempo total: {df_traj['time'].max():.3f} s")
print(f"Pasos guardados: {len(df_traj['time'].unique())}")
print(f"Colisiones totales: {df_coll['n_collisions'].sum()}")
print()

# 3. Conservación de energía
E_initial = df_cons['total_energy'].iloc[0]
E_final = df_cons['total_energy'].iloc[-1]
error = abs(E_final - E_initial) / E_initial
print(f"Energía inicial: {E_initial:.6e}")
print(f"Energía final: {E_final:.6e}")
print(f"Error relativo: {error:.6e}")
print()

# 4. Graficar
fig, axes = plt.subplots(2, 2, figsize=(15, 12))

# Energías individuales
ax = axes[0, 0]
for pid in df_traj['particle_id'].unique():
    data = df_traj[df_traj['particle_id'] == pid]
    ax.plot(data['time'], data['energy'], label=f'P{pid}', alpha=0.7)
ax.set_xlabel('Tiempo (s)')
ax.set_ylabel('Energía')
ax.set_title('Energía por Partícula')
ax.legend()
ax.grid(True)

# Velocidades angulares
ax = axes[0, 1]
for pid in df_traj['particle_id'].unique():
    data = df_traj[df_traj['particle_id'] == pid]
    ax.plot(data['time'], data['theta_dot'], label=f'P{pid}', alpha=0.7)
ax.set_xlabel('Tiempo (s)')
ax.set_ylabel('θ_dot (rad/s)')
ax.set_title('Velocidades Angulares')
ax.legend()
ax.grid(True)

# Trayectorias
ax = axes[1, 0]
for pid in df_traj['particle_id'].unique():
    data = df_traj[df_traj['particle_id'] == pid]
    ax.plot(data['x'], data['y'], label=f'P{pid}', alpha=0.6)
ax.set_xlabel('X')
ax.set_ylabel('Y')
ax.set_title('Trayectorias')
ax.axis('equal')
ax.legend()
ax.grid(True)

# Colisiones
ax = axes[1, 1]
coll_steps = df_coll[df_coll['had_collision'] == 1]
ax.scatter(coll_steps['time'], coll_steps['n_collisions'],
           alpha=0.6, s=50, color='red')
ax.set_xlabel('Tiempo (s)')
ax.set_ylabel('Número de Colisiones')
ax.set_title('Eventos de Colisión')
ax.grid(True)

plt.tight_layout()
plt.savefig('analisis_completo.png', dpi=150)
print("✅ Gráficas guardadas en 'analisis_completo.png'")
```

---

**Actualización:** 2025-11-06
**Estado:** ✅ COMPLETO Y FUNCIONANDO
**Documentación adicional:** Ver `SISTEMA_IO_DOCUMENTACION.md`
