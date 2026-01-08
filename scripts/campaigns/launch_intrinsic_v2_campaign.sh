#!/bin/bash
#
# launch_intrinsic_v2_campaign.sh
#
# Campaña v2: Radio basado en perímetro (no en b)
# N partículas = N% de cobertura (independiente de e)
#
# 160 runs: e=[0.5,0.7,0.8,0.9], N=[50,60,70,80], 10 seeds
#

set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CAMPAIGN_DIR="results/intrinsic_v2_campaign_${TIMESTAMP}"
mkdir -p "$CAMPAIGN_DIR"

echo "========================================"
echo "CAMPAÑA INTRINSIC v2"
echo "Radio = Perímetro / (2 × N_max_ref)"
echo "========================================"
echo "Timestamp: $TIMESTAMP"
echo "Directorio: $CAMPAIGN_DIR"
echo ""

# Copiar matriz
cp parameter_matrix_intrinsic_v2.csv "$CAMPAIGN_DIR/"

# Generar comandos
COMMANDS_FILE="$CAMPAIGN_DIR/commands.txt"
echo "Generando comandos..."

tail -n +2 parameter_matrix_intrinsic_v2.csv | while IFS=',' read -r run_id N e a seed max_time dt_max dt_min save_interval N_max_ref; do
    echo "julia --project=. run_single_intrinsic_campaign_v2.jl $run_id $N $e $a $seed $max_time $dt_max $dt_min $save_interval $N_max_ref \"$CAMPAIGN_DIR\""
done > "$COMMANDS_FILE"

N_RUNS=$(wc -l < "$COMMANDS_FILE")
echo "Total comandos: $N_RUNS"
echo ""

# Info
cat > "$CAMPAIGN_DIR/campaign_info.txt" << EOF
Campaña Intrinsic v2
====================
Fecha: $(date)
Directorio: $CAMPAIGN_DIR

CAMBIO CLAVE: Radio basado en perímetro
    radius = Perímetro / (2 × N_max_ref)
    N_max_ref = 100

    Esto garantiza: N partículas = N% cobertura (independiente de e)

Parámetros:
    e = [0.5, 0.7, 0.8, 0.9]
    N = [50, 60, 70, 80] (= cobertura %)
    Seeds = 10 por condición
    Total runs = $N_RUNS

Configuración:
    max_time = 100.0
    dt_max = 1e-5
    dt_min = 1e-10
    save_interval = 0.5
    intrinsic collision detection = true
EOF

# Cores
N_CORES=$(nproc)
N_JOBS=$((N_CORES > 24 ? 24 : N_CORES - 2))
echo "Cores disponibles: $N_CORES"
echo "Jobs en paralelo: $N_JOBS"
echo ""

# Lanzar
echo "Lanzando campaña..."
echo "Log: $CAMPAIGN_DIR/joblog.txt"
echo ""

parallel --jobs $N_JOBS \
         --joblog "$CAMPAIGN_DIR/joblog.txt" \
         --progress \
         --resume-failed \
         < "$COMMANDS_FILE"

echo ""
echo "========================================"
echo "CAMPAÑA COMPLETADA"
echo "========================================"
echo "Resultados en: $CAMPAIGN_DIR"
