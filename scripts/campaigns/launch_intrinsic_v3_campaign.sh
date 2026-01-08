#!/bin/bash
# launch_intrinsic_v3_campaign.sh
# Lanza campaña intrinsic v3 con GNU parallel

set -e

MATRIX_FILE="parameter_matrix_intrinsic_v3.csv"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CAMPAIGN_DIR="results/intrinsic_v3_campaign_${TIMESTAMP}"

# Crear directorio
mkdir -p "$CAMPAIGN_DIR"

# Info de campaña
cat > "$CAMPAIGN_DIR/campaign_info.txt" << EOF
Campaña Intrinsic v3 (CORREGIDA)
================================
Fecha: $(date)
Directorio: $CAMPAIGN_DIR

CORRECCIÓN: N reducidos para garantizar colocación física
    N_max_ref = 100 → N_max práctico ≈ 85
    N = [30, 40, 50, 60] (todas < 85)

Radio = Perímetro / (2 × N_max_ref)
    Esto garantiza: N partículas = N% cobertura

Parámetros:
    e = [0.5, 0.7, 0.8, 0.9]
    N = [30, 40, 50, 60] (= cobertura %)
    Seeds = 10 por condición
    Total runs = 160

Configuración:
    max_time = 100.0
    dt_max = 1e-5
    dt_min = 1e-10
    save_interval = 0.5
    intrinsic collision detection = true
EOF

# Generar comandos
echo "Generando comandos..."
tail -n +2 "$MATRIX_FILE" | while IFS=, read -r run_id N e a seed max_time dt_max dt_min save_interval N_max_ref; do
    echo "julia --project=. run_single_intrinsic_campaign_v2.jl $run_id $N $e $a $seed $max_time $dt_max $dt_min $save_interval $N_max_ref \"$CAMPAIGN_DIR\""
done > "$CAMPAIGN_DIR/commands.txt"

echo "Comandos guardados en: $CAMPAIGN_DIR/commands.txt"
echo "Total comandos: $(wc -l < "$CAMPAIGN_DIR/commands.txt")"

# Lanzar con GNU parallel
echo ""
echo "Lanzando campaña con GNU parallel..."
echo "Directorio: $CAMPAIGN_DIR"
echo ""

# Usar todos los cores disponibles
N_JOBS=$(nproc)
echo "Usando $N_JOBS jobs en paralelo"

parallel --jobs "$N_JOBS" \
         --joblog "$CAMPAIGN_DIR/joblog.txt" \
         --progress \
         < "$CAMPAIGN_DIR/commands.txt"

echo ""
echo "Campaña completada!"
echo "Resultados en: $CAMPAIGN_DIR"
