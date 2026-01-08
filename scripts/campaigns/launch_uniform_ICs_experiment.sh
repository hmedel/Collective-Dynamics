#!/bin/bash

# Script de lanzamiento para Experimento 3: ICs Uniformes
# 40 runs (e=0.7, 0.9 × 20 realizaciones)
# t_max = 500s, ICs uniformes

set -e

PARAM_FILE="parameter_matrix_uniform_ICs_experiment.csv"
OUTPUT_DIR="results/experiment_uniform_ICs_$(date +%Y%m%d_%H%M%S)"
SCRIPT="run_uniform_ICs_experiment.jl"

echo "========================================================================"
echo "  LANZAMIENTO EXPERIMENTO 3: Condiciones Iniciales Uniformes"
echo "========================================================================"
echo ""
echo "Parámetros:"
echo "  Matriz:      $PARAM_FILE"
echo "  Output:      $OUTPUT_DIR"
echo "  Script:      $SCRIPT"
echo ""

# Verificar archivos
if [ ! -f "$PARAM_FILE" ]; then
    echo "ERROR: No se encuentra $PARAM_FILE"
    echo "Ejecutar: julia --project=. generate_uniform_ICs_campaign.jl"
    exit 1
fi

if [ ! -f "$SCRIPT" ]; then
    echo "ERROR: No se encuentra $SCRIPT"
    exit 1
fi

# Crear directorio de salida
mkdir -p "$OUTPUT_DIR"

# Copiar configuración
cp "$PARAM_FILE" "$OUTPUT_DIR/"
cp "$SCRIPT" "$OUTPUT_DIR/"

echo "Directorio creado: $OUTPUT_DIR"
echo ""

# Generar comandos
echo "Generando comandos..."

COMMANDS_FILE="${OUTPUT_DIR}/commands.txt"

awk -F',' 'NR>1 {
    printf "julia --project=. --threads=1 %s ", script
    printf "--run-id %s --eccentricity %s --a %s --b %s ", $5, $7, $4, $1
    printf "--N %s --E-per-N %s --seed %s ", $6, $2, $13
    printf "--t-max %s --dt-max %s --save-interval %s ", $11, $12, $3
    printf "--projection-interval %s --output-dir %s ", $10, outdir
    if ($8 == "true") printf "--use-projection"
    printf "\n"
}' script="$SCRIPT" outdir="$OUTPUT_DIR" "$PARAM_FILE" > "$COMMANDS_FILE"

N_COMMANDS=$(wc -l < "$COMMANDS_FILE")

echo "  ✓ $N_COMMANDS comandos generados"
echo "  ✓ Guardados en: $COMMANDS_FILE"
echo ""

# Preguntar confirmación
echo "========================================================================"
echo "  RESUMEN"
echo "========================================================================"
echo ""
echo "Total runs:       $N_COMMANDS"
echo "Tiempo/run:       ~19 minutos (500s)"
echo "Tiempo total:     ~12.5 horas (secuencial)"
echo "Con 24 cores:     ~30 minutos"
echo ""
echo "Output:           $OUTPUT_DIR"
echo ""

read -p "¿Iniciar simulación? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelado"
    exit 0
fi

# Lanzar con GNU parallel
echo ""
echo "========================================================================"
echo "  LANZANDO SIMULACIÓN"
echo "========================================================================"
echo ""

JOBLOG="${OUTPUT_DIR}/joblog.txt"
PARALLEL_LOG="${OUTPUT_DIR}/parallel.log"

nohup parallel --jobs 24 --progress --joblog "$JOBLOG" < "$COMMANDS_FILE" > "$PARALLEL_LOG" 2>&1 &

PID=$!

echo "Simulación lanzada en background"
echo "  PID:            $PID"
echo "  Jobs paralelos: 24"
echo "  Job log:        $JOBLOG"
echo "  Parallel log:   $PARALLEL_LOG"
echo ""
echo "Monitoreo:"
echo "  watch -n 30 'ls $OUTPUT_DIR/*.h5 2>/dev/null | wc -l'"
echo "  tail -f $PARALLEL_LOG"
echo ""
echo "========================================================================"
