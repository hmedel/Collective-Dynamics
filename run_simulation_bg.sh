#!/bin/bash
#
# run_simulation_bg.sh
#
# Ejecuta una simulación en background usando nohup.
# La simulación continuará ejecutándose incluso si cierras la sesión SSH.
#
# Uso:
#   ./run_simulation_bg.sh config/ultra_precision.toml
#   ./run_simulation_bg.sh config/alta_precision.toml "Mi simulación especial"
#
# Para ver el progreso en tiempo real:
#   tail -f logs/simulation_XXXXXX.log
#
# Para detener la simulación:
#   kill <PID>  (el PID se muestra al iniciar)
#

set -e  # Exit on error

# Verificar argumentos
if [ "$#" -lt 1 ]; then
    echo "❌ Error: Proporciona el archivo de configuración"
    echo ""
    echo "Uso:"
    echo "  ./run_simulation_bg.sh config/ultra_precision.toml"
    echo "  ./run_simulation_bg.sh config/alta_precision.toml \"Descripción opcional\""
    echo ""
    exit 1
fi

CONFIG_FILE="$1"
DESCRIPTION="${2:-Simulación en background}"

# Verificar que el archivo de configuración existe
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Error: No se encontró el archivo de configuración: $CONFIG_FILE"
    exit 1
fi

# Crear directorio de logs si no existe
mkdir -p logs

# Generar nombre de archivo de log con timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOGFILE="logs/simulation_${TIMESTAMP}.log"
PIDFILE="logs/simulation_${TIMESTAMP}.pid"

# Banner
echo "================================================================================"
echo "EJECUTANDO SIMULACIÓN EN BACKGROUND"
echo "================================================================================"
echo ""
echo "Configuración: $CONFIG_FILE"
echo "Descripción:   $DESCRIPTION"
echo "Log file:      $LOGFILE"
echo "PID file:      $PIDFILE"
echo ""

# Escribir información en el log
{
    echo "================================================================================"
    echo "SIMULACIÓN INICIADA: $(date)"
    echo "================================================================================"
    echo "Configuración: $CONFIG_FILE"
    echo "Descripción:   $DESCRIPTION"
    echo "Host:          $(hostname)"
    echo "Usuario:       $(whoami)"
    echo "================================================================================"
    echo ""
} > "$LOGFILE"

# Ejecutar Julia con nohup
nohup julia --project=. run_simulation.jl "$CONFIG_FILE" >> "$LOGFILE" 2>&1 &

# Obtener PID
PID=$!

# Guardar PID en archivo
echo "$PID" > "$PIDFILE"

# Esperar un momento para verificar que el proceso arrancó correctamente
sleep 2

# Verificar que el proceso sigue corriendo
if ps -p $PID > /dev/null 2>&1; then
    echo "✅ Simulación iniciada correctamente"
    echo ""
    echo "📊 INFORMACIÓN DEL PROCESO:"
    echo "   PID:        $PID"
    echo "   Config:     $CONFIG_FILE"
    echo "   Log:        $LOGFILE"
    echo ""
    echo "📋 COMANDOS ÚTILES:"
    echo ""
    echo "   Ver progreso en tiempo real:"
    echo "     tail -f $LOGFILE"
    echo ""
    echo "   Ver últimas 50 líneas:"
    echo "     tail -n 50 $LOGFILE"
    echo ""
    echo "   Buscar errores:"
    echo "     grep -i error $LOGFILE"
    echo ""
    echo "   Verificar si sigue corriendo:"
    echo "     ps -p $PID"
    echo "     ./check_simulation.sh $PID"
    echo ""
    echo "   Detener la simulación:"
    echo "     kill $PID"
    echo ""
    echo "   Detener forzadamente (último recurso):"
    echo "     kill -9 $PID"
    echo ""
    echo "================================================================================"
    echo ""
    echo "💡 NOTA: Puedes cerrar esta sesión SSH de forma segura."
    echo "         La simulación continuará ejecutándose en background."
    echo ""
    echo "================================================================================"
else
    echo "❌ Error: El proceso no se inició correctamente"
    echo "   Revisa el log para más detalles: $LOGFILE"
    cat "$LOGFILE"
    exit 1
fi
