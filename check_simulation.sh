#!/bin/bash
#
# check_simulation.sh
#
# Verifica el estado de una o todas las simulaciones en ejecución.
#
# Uso:
#   ./check_simulation.sh           # Muestra todas las simulaciones
#   ./check_simulation.sh 12345     # Verifica simulación con PID 12345
#   ./check_simulation.sh logs/simulation_20251113_120000.pid  # Desde archivo PID
#

# Colores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para mostrar información de un proceso
show_process_info() {
    local pid=$1

    if ps -p "$pid" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Proceso corriendo${NC}"
        echo ""

        # Información básica del proceso
        echo "📊 INFORMACIÓN DEL PROCESO:"
        ps -p "$pid" -o pid,user,%cpu,%mem,etime,cmd --no-headers | \
            awk '{printf "   PID:         %s\n   Usuario:     %s\n   CPU:         %s%%\n   Memoria:     %s%%\n   Tiempo:      %s\n   Comando:     ", $1, $2, $3, $4, $5; for(i=6;i<=NF;i++) printf "%s ", $i; printf "\n"}'
        echo ""

        # Buscar archivo de log correspondiente
        if [ -d "logs" ]; then
            echo "📋 ARCHIVOS DE LOG:"
            # Buscar por PID en archivos .pid
            for pidfile in logs/*.pid; do
                if [ -f "$pidfile" ]; then
                    file_pid=$(cat "$pidfile" 2>/dev/null)
                    if [ "$file_pid" = "$pid" ]; then
                        logfile="${pidfile%.pid}.log"
                        if [ -f "$logfile" ]; then
                            echo "   Log file:    $logfile"

                            # Mostrar tamaño del log
                            logsize=$(du -h "$logfile" | cut -f1)
                            echo "   Tamaño:      $logsize"

                            # Mostrar última actividad
                            echo ""
                            echo "   Últimas 10 líneas:"
                            tail -n 10 "$logfile" | sed 's/^/      /'
                            echo ""

                            echo "   Para ver progreso en tiempo real:"
                            echo "      tail -f $logfile"
                        fi
                    fi
                fi
            done
        fi

    else
        echo -e "${RED}❌ Proceso NO está corriendo${NC}"
        echo ""

        # Buscar en logs si terminó
        if [ -d "logs" ]; then
            for pidfile in logs/*.pid; do
                if [ -f "$pidfile" ]; then
                    file_pid=$(cat "$pidfile" 2>/dev/null)
                    if [ "$file_pid" = "$pid" ]; then
                        logfile="${pidfile%.pid}.log"
                        if [ -f "$logfile" ]; then
                            echo "📋 Log encontrado: $logfile"
                            echo ""

                            # Verificar si terminó exitosamente
                            if grep -q "Simulación completada" "$logfile" 2>/dev/null; then
                                echo -e "${GREEN}✅ La simulación terminó exitosamente${NC}"
                            elif grep -q -i "error" "$logfile" 2>/dev/null; then
                                echo -e "${RED}❌ La simulación terminó con errores${NC}"
                                echo ""
                                echo "Últimos errores encontrados:"
                                grep -i "error" "$logfile" | tail -n 5 | sed 's/^/   /'
                            else
                                echo -e "${YELLOW}⚠️  Estado desconocido (proceso interrumpido?)${NC}"
                            fi

                            echo ""
                            echo "Últimas 15 líneas del log:"
                            tail -n 15 "$logfile" | sed 's/^/   /'
                        fi
                    fi
                fi
            done
        fi
    fi
}

# Banner
echo "================================================================================"
echo "VERIFICADOR DE SIMULACIONES"
echo "================================================================================"
echo ""

# Si se proporciona un argumento
if [ "$#" -eq 1 ]; then
    ARG="$1"

    # Verificar si es un archivo .pid
    if [ -f "$ARG" ] && [[ "$ARG" == *.pid ]]; then
        PID=$(cat "$ARG")
        echo "Verificando simulación desde archivo: $ARG"
        echo "PID: $PID"
        echo ""
        show_process_info "$PID"
    # Verificar si es un número (PID directo)
    elif [[ "$ARG" =~ ^[0-9]+$ ]]; then
        echo "Verificando simulación con PID: $ARG"
        echo ""
        show_process_info "$ARG"
    else
        echo -e "${RED}❌ Error: Argumento inválido${NC}"
        echo "Debe ser un PID (número) o un archivo .pid"
        exit 1
    fi
else
    # Mostrar todas las simulaciones
    echo "Buscando todas las simulaciones en ejecución..."
    echo ""

    # Buscar procesos de Julia ejecutando run_simulation.jl
    PIDS=$(ps aux | grep "[j]ulia.*run_simulation.jl" | awk '{print $2}')

    if [ -z "$PIDS" ]; then
        echo -e "${YELLOW}⚠️  No se encontraron simulaciones en ejecución${NC}"
        echo ""

        # Mostrar simulaciones recientes de los logs
        if [ -d "logs" ] && [ "$(ls -A logs/*.pid 2>/dev/null)" ]; then
            echo "📋 Simulaciones recientes (últimas 5):"
            echo ""

            ls -t logs/*.pid 2>/dev/null | head -n 5 | while read pidfile; do
                pid=$(cat "$pidfile" 2>/dev/null)
                logfile="${pidfile%.pid}.log"
                timestamp=$(basename "$pidfile" | sed 's/simulation_\(.*\)\.pid/\1/')

                if ps -p "$pid" > /dev/null 2>&1; then
                    status="${GREEN}✅ Corriendo${NC}"
                else
                    if [ -f "$logfile" ] && grep -q "Simulación completada" "$logfile" 2>/dev/null; then
                        status="${GREEN}✅ Completada${NC}"
                    else
                        status="${RED}❌ Detenida${NC}"
                    fi
                fi

                echo -e "   [$timestamp] PID: $pid - $status"
                echo "      Log: $logfile"
                echo ""
            done
        fi
    else
        echo -e "${GREEN}Se encontraron $(echo "$PIDS" | wc -w) simulación(es) en ejecución:${NC}"
        echo ""

        for pid in $PIDS; do
            echo "-------------------------------------------------------------------------------"
            show_process_info "$pid"
            echo "-------------------------------------------------------------------------------"
            echo ""
        done
    fi
fi

echo "================================================================================"
