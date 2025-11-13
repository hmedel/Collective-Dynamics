# Guía: Ejecutar Simulaciones en Background

Esta guía explica cómo ejecutar simulaciones largas en background de manera que continúen ejecutándose incluso después de cerrar la sesión SSH.

## 📋 Tabla de Contenidos

1. [Método 1: Script Wrapper (Recomendado)](#método-1-script-wrapper-recomendado)
2. [Método 2: nohup Manual](#método-2-nohup-manual)
3. [Método 3: screen](#método-3-screen)
4. [Método 4: tmux](#método-4-tmux)
5. [Monitoreo de Simulaciones](#monitoreo-de-simulaciones)
6. [Gestión de Procesos](#gestión-de-procesos)
7. [Tips y Mejores Prácticas](#tips-y-mejores-prácticas)

---

## Método 1: Script Wrapper (Recomendado)

El método más simple es usar el script `run_simulation_bg.sh` que automatiza todo el proceso.

### Uso Básico

```bash
# Ejecutar simulación en background
./run_simulation_bg.sh config/ultra_precision.toml

# Con descripción opcional
./run_simulation_bg.sh config/alta_precision.toml "Prueba conservación energía"
```

### Lo que hace el script

1. Ejecuta Julia con `nohup` en background
2. Redirige toda la salida a un archivo de log en `logs/`
3. Guarda el PID (Process ID) en un archivo `.pid`
4. Te muestra información para monitorear el progreso
5. Permite cerrar la sesión SSH sin interrumpir la simulación

### Ejemplo de Uso

```bash
$ ./run_simulation_bg.sh config/ultra_precision.toml

================================================================================
EJECUTANDO SIMULACIÓN EN BACKGROUND
================================================================================

Configuración: config/ultra_precision.toml
Descripción:   Simulación en background
Log file:      logs/simulation_20251113_143022.log
PID file:      logs/simulation_20251113_143022.pid

✅ Simulación iniciada correctamente

📊 INFORMACIÓN DEL PROCESO:
   PID:        12345
   Config:     config/ultra_precision.toml
   Log:        logs/simulation_20251113_143022.log

📋 COMANDOS ÚTILES:

   Ver progreso en tiempo real:
     tail -f logs/simulation_20251113_143022.log

   Verificar si sigue corriendo:
     ./check_simulation.sh 12345

   Detener la simulación:
     kill 12345
```

### Verificar Estado

```bash
# Ver todas las simulaciones en ejecución
./check_simulation.sh

# Verificar simulación específica por PID
./check_simulation.sh 12345

# Verificar desde archivo PID
./check_simulation.sh logs/simulation_20251113_143022.pid
```

---

## Método 2: nohup Manual

Si prefieres control manual, usa `nohup` directamente.

### Paso 1: Crear directorio de logs

```bash
mkdir -p logs
```

### Paso 2: Ejecutar con nohup

```bash
nohup julia --project=. run_simulation.jl config/ultra_precision.toml > logs/mi_simulacion.log 2>&1 &
```

Explicación:
- `nohup`: Hace que el proceso ignore la señal SIGHUP (cuando cierras la sesión)
- `> logs/mi_simulacion.log`: Redirige stdout al log
- `2>&1`: Redirige stderr también al log
- `&`: Ejecuta en background

### Paso 3: Guardar el PID

```bash
echo $! > logs/mi_simulacion.pid
```

La variable `$!` contiene el PID del último proceso en background.

### Paso 4: Monitorear

```bash
# Ver progreso en tiempo real
tail -f logs/mi_simulacion.log

# Ver últimas 50 líneas
tail -n 50 logs/mi_simulacion.log

# Buscar errores
grep -i error logs/mi_simulacion.log
```

### Paso 5: Verificar si sigue corriendo

```bash
PID=$(cat logs/mi_simulacion.pid)
ps -p $PID
```

Si el proceso está corriendo, verás algo como:
```
  PID TTY          TIME CMD
12345 ?        00:45:32 julia
```

---

## Método 3: screen

`screen` permite crear sesiones de terminal que persisten al cerrar SSH.

### Instalación (si no está instalado)

```bash
sudo apt-get install screen
```

### Uso

```bash
# Crear nueva sesión llamada "sim"
screen -S sim

# Dentro de screen, ejecutar la simulación
julia --project=. run_simulation.jl config/ultra_precision.toml

# Desconectar de screen (la simulación sigue corriendo)
# Presiona: Ctrl+A, luego D

# Listar sesiones de screen
screen -ls

# Reconectar a la sesión
screen -r sim

# Terminar screen (desde dentro de la sesión)
exit
```

### Ventajas

- Puedes reconectarte y ver el output en tiempo real
- Puedes tener múltiples ventanas/sesiones
- Control interactivo completo

### Desventajas

- Requiere instalar screen
- No guarda logs automáticamente (a menos que lo hagas manualmente)

---

## Método 4: tmux

`tmux` es similar a screen pero más moderno y con más características.

### Instalación (si no está instalado)

```bash
sudo apt-get install tmux
```

### Uso Básico

```bash
# Crear nueva sesión llamada "sim"
tmux new -s sim

# Dentro de tmux, ejecutar la simulación
julia --project=. run_simulation.jl config/ultra_precision.toml

# Desconectar de tmux (la simulación sigue corriendo)
# Presiona: Ctrl+B, luego D

# Listar sesiones
tmux ls

# Reconectar a la sesión
tmux attach -t sim

# Terminar tmux (desde dentro)
exit
```

### Comandos Útiles de tmux

| Comando | Acción |
|---------|--------|
| `Ctrl+B %` | Dividir panel verticalmente |
| `Ctrl+B "` | Dividir panel horizontalmente |
| `Ctrl+B →` | Moverse al panel derecho |
| `Ctrl+B ←` | Moverse al panel izquierdo |
| `Ctrl+B C` | Crear nueva ventana |
| `Ctrl+B N` | Siguiente ventana |
| `Ctrl+B D` | Desconectar (detach) |

### Ejemplo: Simulación + Monitoreo

```bash
# Crear sesión
tmux new -s sim

# Dividir pantalla horizontalmente
# Presiona: Ctrl+B "

# Panel superior: ejecutar simulación
julia --project=. run_simulation.jl config/ultra_precision.toml

# Mover al panel inferior
# Presiona: Ctrl+B ↓

# Panel inferior: monitorear resultados
watch -n 5 'ls -lh results/ | tail -n 10'

# Desconectar
# Presiona: Ctrl+B D
```

---

## Monitoreo de Simulaciones

### Script de Verificación

```bash
# Ver todas las simulaciones
./check_simulation.sh

# Ver simulación específica
./check_simulation.sh 12345
```

### Comandos Útiles

#### Ver procesos de Julia

```bash
ps aux | grep julia
```

#### Ver uso de CPU/Memoria

```bash
# Usando top
top -p 12345

# Usando htop (más amigable)
htop -p 12345
```

#### Monitoreo continuo del log

```bash
# Ver últimas líneas continuamente
tail -f logs/simulation_20251113_143022.log

# Filtrar solo líneas importantes
tail -f logs/simulation_20251113_143022.log | grep -E "Paso|completada|Error"
```

#### Ver estadísticas de IO

```bash
iostat -x 2
```

---

## Gestión de Procesos

### Detener una Simulación

```bash
# Detención normal (permite cleanup)
kill 12345

# Si no responde después de 30 segundos, forzar
kill -9 12345
```

### Pausar y Reanudar (solo con screen/tmux)

```bash
# Dentro de screen/tmux, pausar con Ctrl+Z

# Reanudar
fg
```

### Limitar Recursos

Si quieres limitar el uso de CPU:

```bash
# Usar nice (ejecuta con menor prioridad)
nice -n 10 julia --project=. run_simulation.jl config/ultra_precision.toml

# Con nohup
nohup nice -n 10 julia --project=. run_simulation.jl config/ultra_precision.toml > logs/sim.log 2>&1 &
```

Valores de nice:
- `-20` = máxima prioridad (requiere root)
- `0` = prioridad normal
- `19` = mínima prioridad

---

## Tips y Mejores Prácticas

### 1. Siempre Redirigir la Salida

```bash
# ✅ BIEN - salida guardada
nohup julia --project=. run_simulation.jl config.toml > logs/sim.log 2>&1 &

# ❌ MAL - salida se pierde
nohup julia --project=. run_simulation.jl config.toml &
```

### 2. Guardar el PID

```bash
# Guardar inmediatamente después de iniciar
nohup julia --project=. run_simulation.jl config.toml > logs/sim.log 2>&1 &
echo $! > logs/sim.pid
```

### 3. Usar Nombres Descriptivos

```bash
# ✅ BIEN
logs/ultra_precision_20251113.log

# ❌ MAL
logs/output.log
```

### 4. Verificar Antes de Cerrar SSH

```bash
# Verificar que el proceso está corriendo
ps -p $(cat logs/sim.pid)

# Verificar que el log está creciendo
ls -lh logs/sim.log
sleep 10
ls -lh logs/sim.log  # Debe tener mayor tamaño
```

### 5. Monitoreo Periódico

Crea un cronjob para verificar simulaciones:

```bash
# Editar crontab
crontab -e

# Agregar línea para verificar cada hora
0 * * * * /path/to/check_simulation.sh > /path/to/simulation_status.txt
```

### 6. Limpiar Logs Antiguos

```bash
# Eliminar logs de más de 30 días
find logs/ -name "*.log" -mtime +30 -delete
find logs/ -name "*.pid" -mtime +30 -delete
```

### 7. Notificaciones por Email

Puedes configurar notificaciones cuando termine una simulación:

```bash
# Al final de run_simulation.jl o en un wrapper
julia --project=. run_simulation.jl config.toml && \
  echo "Simulación completada" | mail -s "Simulación terminada" tu@email.com
```

---

## Comparación de Métodos

| Método | Facilidad | Flexibilidad | Requiere Instalación | Logs Automáticos | Reconexión Interactiva |
|--------|-----------|--------------|---------------------|------------------|------------------------|
| **Script wrapper** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ❌ No | ✅ Sí | ❌ No |
| **nohup manual** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ❌ No | ⚠️ Manual | ❌ No |
| **screen** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⚠️ A veces | ⚠️ Manual | ✅ Sí |
| **tmux** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⚠️ A veces | ⚠️ Manual | ✅ Sí |

### Recomendaciones

- **Para simulaciones largas desatendidas**: Script wrapper o nohup manual
- **Para desarrollo/debugging**: tmux o screen
- **Para múltiples simulaciones simultáneas**: tmux con múltiples paneles
- **Para máxima simplicidad**: Script wrapper

---

## Solución de Problemas

### Problema: El proceso se detuvo al cerrar SSH

**Causa**: No usaste `nohup` o screen/tmux

**Solución**: Siempre usa uno de los métodos descritos arriba.

### Problema: No puedo encontrar el PID

**Solución**:
```bash
# Buscar procesos de Julia
ps aux | grep "julia.*run_simulation"

# Usar check_simulation.sh
./check_simulation.sh
```

### Problema: El log no se actualiza

**Posibles causas**:
1. El proceso se detuvo (verificar con `ps`)
2. Julia está bufferizando el output

**Solución para buffering**:
```bash
# Ejecutar Julia sin buffering
nohup julia --project=. -e 'ENV["JULIA_DEBUG"]="all"' run_simulation.jl config.toml > logs/sim.log 2>&1 &
```

### Problema: No tengo suficiente espacio en disco

**Solución**:
```bash
# Verificar espacio
df -h

# Comprimir logs antiguos
gzip logs/*.log

# Eliminar resultados intermedios si es seguro
```

---

## Ejemplos Completos

### Ejemplo 1: Simulación Simple

```bash
# Ejecutar
./run_simulation_bg.sh config/ultra_precision.toml

# Ver progreso
tail -f logs/simulation_*.log

# Cerrar SSH (Ctrl+D o exit)

# Más tarde, reconectar y verificar
ssh usuario@servidor
cd Collective-Dynamics
./check_simulation.sh
```

### Ejemplo 2: Múltiples Simulaciones

```bash
# Ejecutar 3 simulaciones diferentes
./run_simulation_bg.sh config/config1.toml "Simulación 1"
./run_simulation_bg.sh config/config2.toml "Simulación 2"
./run_simulation_bg.sh config/config3.toml "Simulación 3"

# Verificar todas
./check_simulation.sh
```

### Ejemplo 3: Con tmux (para monitoreo interactivo)

```bash
# Crear sesión
tmux new -s monitoring

# Dividir en 4 paneles (Ctrl+B ", luego Ctrl+B %)
# Panel 1: Simulación principal
julia --project=. run_simulation.jl config/ultra_precision.toml

# Panel 2: Monitoreo del log
tail -f results/simulation_*/conservation.log

# Panel 3: Uso de recursos
htop

# Panel 4: Espacio en disco
watch -n 60 'df -h | grep -E "Filesystem|/home"'

# Desconectar: Ctrl+B D
# Reconectar: tmux attach -t monitoring
```

---

## Recursos Adicionales

- [Documentación de nohup](https://man7.org/linux/man-pages/man1/nohup.1.html)
- [Guía de screen](https://www.gnu.org/software/screen/manual/screen.html)
- [Guía de tmux](https://github.com/tmux/tmux/wiki)
- [Señales de Linux](https://man7.org/linux/man-pages/man7/signal.7.html)

---

**Última actualización**: 2025-11-13
