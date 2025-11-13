# Guía: Ejecutar Simulaciones en Background

Esta guía explica cómo ejecutar simulaciones largas que continúen corriendo incluso después de cerrar la sesión SSH.

---

## TL;DR - Lo Más Simple

```bash
# Ejecutar en background
nohup julia --project=. run_simulation.jl config/ultra_precision.toml > simulation.log 2>&1 &

# Guardar el PID (opcional)
echo $! > simulation.pid

# Ver progreso
tail -f simulation.log

# Cerrar SSH sin problemas
exit
```

**¡Eso es todo!** La simulación continuará corriendo.

---

## Método Recomendado (nohup)

### Paso 1: Ejecutar en Background

```bash
nohup julia --project=. run_simulation.jl config/ultra_precision.toml > mi_simulacion.log 2>&1 &
```

**Explicación:**
- `nohup` → El proceso ignora la señal de desconexión (SIGHUP)
- `> mi_simulacion.log` → Guarda la salida en un archivo
- `2>&1` → También guarda los errores en el mismo archivo
- `&` → Ejecuta en background

El comando te mostrará algo como:
```
[1] 12345
```

Ese número (`12345`) es el **PID** del proceso.

### Paso 2: Guardar el PID (Opcional pero Útil)

```bash
echo $! > mi_simulacion.pid
```

La variable `$!` contiene el PID del último proceso en background.

### Paso 3: Verificar que Está Corriendo

```bash
# Ver el proceso
ps -p $(cat mi_simulacion.pid)

# O buscar todos los procesos de Julia
ps aux | grep julia
```

Si ves una línea con tu proceso, está corriendo correctamente.

### Paso 4: Monitorear el Progreso

```bash
# Ver en tiempo real (Ctrl+C para salir)
tail -f mi_simulacion.log

# Ver últimas 50 líneas
tail -n 50 mi_simulacion.log

# Buscar errores
grep -i error mi_simulacion.log
```

### Paso 5: Cerrar SSH Tranquilamente

```bash
exit
```

La simulación seguirá corriendo en el servidor.

### Para Detener la Simulación (si es necesario)

```bash
# Detención normal
kill $(cat mi_simulacion.pid)

# Si no responde (último recurso)
kill -9 $(cat mi_simulacion.pid)
```

---

## Organizando Múltiples Simulaciones

Si ejecutas varias simulaciones, usa nombres descriptivos con timestamps:

```bash
# Crear directorio de logs
mkdir -p logs

# Ejecutar con nombre descriptivo
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
nohup julia --project=. run_simulation.jl config/ultra_precision.toml \
  > logs/ultra_${TIMESTAMP}.log 2>&1 &
echo $! > logs/ultra_${TIMESTAMP}.pid

# Ejecutar otra
nohup julia --project=. run_simulation.jl config/alta_precision.toml \
  > logs/alta_${TIMESTAMP}.log 2>&1 &
echo $! > logs/alta_${TIMESTAMP}.pid
```

Ver todas las simulaciones:
```bash
# Listar procesos de Julia
ps aux | grep julia

# Ver logs recientes
ls -lht logs/
```

---

## Scripts Helper (Opcional)

Si ejecutas simulaciones frecuentemente, puedes usar los scripts incluidos que automatizan lo anterior:

### run_simulation_bg.sh

```bash
# Ejecuta la simulación y crea logs automáticamente
./run_simulation_bg.sh config/ultra_precision.toml

# Con descripción
./run_simulation_bg.sh config/alta_precision.toml "Test conservación"
```

Esto hace automáticamente:
- Crea `logs/simulation_TIMESTAMP.log`
- Guarda el PID en `logs/simulation_TIMESTAMP.pid`
- Te muestra comandos útiles

### check_simulation.sh

```bash
# Ver todas las simulaciones
./check_simulation.sh

# Verificar simulación específica
./check_simulation.sh 12345
```

Muestra:
- Estado (corriendo/completada/error)
- Uso de CPU/memoria
- Últimas líneas del log

**Nota:** Estos scripts son conveniencia, no son necesarios. El método básico con `nohup` es suficiente.

---

## Métodos Alternativos

### screen (para sesiones interactivas)

Si quieres reconectarte y ver el output interactivo:

```bash
# Instalar si no está disponible
sudo apt-get install screen

# Crear sesión
screen -S sim

# Ejecutar simulación (sin nohup)
julia --project=. run_simulation.jl config/ultra_precision.toml

# Desconectar (simulación sigue corriendo)
# Presiona: Ctrl+A, luego D

# Cerrar SSH
exit

# Más tarde, reconectar
ssh usuario@servidor
screen -r sim

# Ver sesiones disponibles
screen -ls
```

### tmux (similar a screen, más moderno)

```bash
# Instalar si no está disponible
sudo apt-get install tmux

# Crear sesión
tmux new -s sim

# Ejecutar simulación
julia --project=. run_simulation.jl config/ultra_precision.toml

# Desconectar
# Presiona: Ctrl+B, luego D

# Reconectar
tmux attach -t sim

# Ver sesiones
tmux ls
```

**Ventajas de screen/tmux:**
- Puedes reconectarte y ver el output en tiempo real
- Puedes interactuar con el proceso (pausar con Ctrl+Z, etc.)
- Puedes dividir la pantalla en múltiples paneles

**Desventajas:**
- Requieren instalación
- Más complejos para uso básico

---

## Comandos Útiles

### Monitoreo de Recursos

```bash
# Ver uso de CPU/memoria de un proceso específico
top -p 12345

# Más amigable (si está instalado)
htop -p 12345

# Uso de disco
df -h

# IO del disco
iostat -x 2
```

### Verificar que el Log Está Creciendo

```bash
# Ver tamaño del log
ls -lh simulation.log

# Esperar 10 segundos
sleep 10

# Ver de nuevo (debe ser más grande)
ls -lh simulation.log
```

### Buscar en los Logs

```bash
# Buscar errores
grep -i error simulation.log

# Buscar líneas con "Paso"
grep "Paso" simulation.log

# Últimas 10 colisiones
grep "colisiones" simulation.log | tail -n 10

# Ver progreso de conservación
grep "Error relativo" simulation.log
```

---

## Ejemplos Prácticos

### Ejemplo 1: Simulación Simple

```bash
# Ejecutar
nohup julia --project=. run_simulation.jl config/ultra_precision.toml > ultra.log 2>&1 &
echo $! > ultra.pid

# Ver progreso un momento
tail -f ultra.log
# Presiona Ctrl+C cuando quieras salir

# Cerrar SSH
exit

# Horas/días después, reconectar
ssh usuario@servidor
cd Collective-Dynamics

# Verificar si sigue corriendo
ps -p $(cat ultra.pid)

# Ver últimas líneas
tail -n 50 ultra.log
```

### Ejemplo 2: Múltiples Simulaciones Simultáneas

```bash
# Crear directorio
mkdir -p logs

# Simulación 1
nohup julia --project=. run_simulation.jl config/config1.toml > logs/sim1.log 2>&1 &
echo $! > logs/sim1.pid

# Simulación 2
nohup julia --project=. run_simulation.jl config/config2.toml > logs/sim2.log 2>&1 &
echo $! > logs/sim2.pid

# Simulación 3
nohup julia --project=. run_simulation.jl config/config3.toml > logs/sim3.log 2>&1 &
echo $! > logs/sim3.pid

# Ver todas
ps aux | grep julia

# Monitorear todas en paralelo (requiere tmux)
tmux new-session \; \
  split-window -v \; \
  split-window -v \; \
  select-layout even-vertical \; \
  send-keys -t 0 'tail -f logs/sim1.log' C-m \; \
  send-keys -t 1 'tail -f logs/sim2.log' C-m \; \
  send-keys -t 2 'tail -f logs/sim3.log' C-m
```

### Ejemplo 3: Con Notificación al Terminar

```bash
# Ejecutar simulación y enviar email al terminar (requiere mail configurado)
nohup julia --project=. run_simulation.jl config/ultra_precision.toml > ultra.log 2>&1 && \
  echo "Simulación completada" | mail -s "Simulación OK" tu@email.com &

# O escribir un archivo de señal
nohup julia --project=. run_simulation.jl config/ultra_precision.toml > ultra.log 2>&1 && \
  touch SIMULACION_COMPLETADA &
```

---

## Solución de Problemas

### El proceso se detuvo al cerrar SSH

**Causa:** No usaste `nohup`

**Solución:** Siempre usa `nohup` o screen/tmux

### No puedo encontrar el PID

```bash
# Buscar todos los procesos de Julia
ps aux | grep "julia.*run_simulation"

# Encontrarás algo como:
# usuario  12345  98.5  2.3  ... julia --project=. run_simulation.jl config/...
```

El segundo número (`12345`) es el PID.

### El log no se actualiza

**Verificar si el proceso está corriendo:**
```bash
ps -p 12345
```

Si no aparece, el proceso se detuvo. Revisa el log para ver el error:
```bash
tail -n 100 simulation.log | grep -i error
```

### Me quedé sin espacio en disco

```bash
# Verificar espacio
df -h

# Encontrar archivos grandes
du -h results/ | sort -h | tail -n 20

# Comprimir logs antiguos
gzip logs/*.log

# Eliminar resultados antiguos (¡CUIDADO!)
rm -rf results/simulation_20240101_*
```

### Julia usa demasiada memoria

```bash
# Ver uso de memoria
ps aux | grep julia

# Si es necesario, limitar con ulimit (ejecutar ANTES de la simulación)
ulimit -v 16000000  # Limitar a ~16GB
nohup julia --project=. run_simulation.jl config.toml > sim.log 2>&1 &
```

---

## Mejores Prácticas

### ✅ DO

- **Siempre** usa `nohup` o screen/tmux
- **Siempre** redirige la salida a un archivo (`> simulation.log 2>&1`)
- **Guarda el PID** para facilitar el manejo del proceso
- **Verifica** que el proceso arrancó antes de cerrar SSH
- **Usa nombres descriptivos** para los logs
- **Monitorea** el espacio en disco si las simulaciones son largas

### ❌ DON'T

- No ejecutes sin `nohup` y esperes que siga corriendo
- No olvides el `2>&1` (perderás los errores)
- No olvides el `&` al final (bloqueará la terminal)
- No uses nombres genéricos como `output.log` si tienes múltiples simulaciones
- No llenes el disco (monitorea el espacio disponible)

---

## Comparación de Métodos

| Método | Simplicidad | Flexibilidad | Requiere Instalación | Reconexión Interactiva |
|--------|-------------|--------------|---------------------|------------------------|
| **nohup** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ❌ No | ❌ No |
| **Scripts helper** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ❌ No | ❌ No |
| **screen** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⚠️ A veces | ✅ Sí |
| **tmux** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⚠️ A veces | ✅ Sí |

**Recomendación:**
- Para la mayoría de casos: **nohup** (método simple)
- Para múltiples simulaciones frecuentes: **Scripts helper**
- Para desarrollo/debugging interactivo: **tmux** o **screen**

---

## Resumen de Comandos

```bash
# EJECUTAR EN BACKGROUND (lo esencial)
nohup julia --project=. run_simulation.jl config.toml > sim.log 2>&1 &
echo $! > sim.pid

# VERIFICAR ESTADO
ps -p $(cat sim.pid)

# MONITOREAR
tail -f sim.log

# DETENER
kill $(cat sim.pid)

# BUSCAR ERRORES
grep -i error sim.log

# VER USO DE RECURSOS
top -p $(cat sim.pid)
```

---

**Última actualización**: 2025-11-13
