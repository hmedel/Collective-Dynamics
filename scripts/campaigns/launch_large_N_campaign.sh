#!/bin/bash
#
# launch_large_N_campaign.sh
#
# Lanza campaña con N grande para observar clustering con detección intrínseca.
# 60 runs: e=[0.8, 0.9], N=[80-150], 10 seeds cada uno
#

set -e

# Crear directorio de resultados con timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CAMPAIGN_DIR="results/large_N_campaign_${TIMESTAMP}"
mkdir -p "$CAMPAIGN_DIR"

echo "========================================"
echo "CAMPAÑA N GRANDE - INTRINSIC"
echo "========================================"
echo "Timestamp: $TIMESTAMP"
echo "Directorio: $CAMPAIGN_DIR"
echo ""

# Copiar matriz de parámetros
cp parameter_matrix_large_N_campaign.csv "$CAMPAIGN_DIR/"

# Generar archivo de comandos
COMMANDS_FILE="$CAMPAIGN_DIR/commands.txt"
echo "Generando comandos..."

tail -n +2 parameter_matrix_large_N_campaign.csv | while IFS=',' read -r run_id N e a b seed max_time dt_max dt_min save_interval; do
    echo "julia --project=. run_single_intrinsic_campaign.jl $run_id $N $e $a $b $seed $max_time $dt_max $dt_min $save_interval \"$CAMPAIGN_DIR\""
done > "$COMMANDS_FILE"

N_RUNS=$(wc -l < "$COMMANDS_FILE")
echo "Total comandos generados: $N_RUNS"
echo ""

# Info de campaña
cat > "$CAMPAIGN_DIR/campaign_info.txt" << EOF
Campaña N Grande - Intrínsica
=============================
Fecha: $(date)
Directorio: $CAMPAIGN_DIR

Parámetros:
- e = [0.8, 0.9]
- N = [80, 100, 120] para e=0.8
- N = [100, 120, 150] para e=0.9
- Seeds = 10 por condición
- Total runs = $N_RUNS

Configuración de simulación:
- max_time = 100.0
- dt_max = 1e-5
- dt_min = 1e-10
- save_interval = 0.5
- collision_method = parallel_transport
- intrinsic = true (arc-length collision detection)
EOF

# Detectar número de cores disponibles
N_CORES=$(nproc)
# Usar máximo 24 cores para dejar recursos al sistema
N_JOBS=$((N_CORES > 24 ? 24 : N_CORES - 2))
echo "Cores disponibles: $N_CORES"
echo "Jobs en paralelo: $N_JOBS"
echo ""

# Lanzar con GNU parallel
echo "Lanzando campaña con GNU parallel..."
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
