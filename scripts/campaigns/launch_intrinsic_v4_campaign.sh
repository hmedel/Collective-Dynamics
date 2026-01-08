#!/bin/bash
# launch_intrinsic_v4_campaign.sh
# Lanza campaña v4 con partículas pequeñas (N_max_ref=200)

set -e

# Configuración
MATRIX_FILE="parameter_matrix_intrinsic_v4.csv"
CAMPAIGN_DIR="results/intrinsic_v4_campaign_$(date +%Y%m%d_%H%M%S)"
N_JOBS=20  # Paralelismo de GNU parallel

# Verificar matriz
if [ ! -f "$MATRIX_FILE" ]; then
    echo "ERROR: No existe $MATRIX_FILE"
    echo "Ejecuta: julia --project=. generate_intrinsic_v4_campaign_matrix.jl"
    exit 1
fi

# Crear directorio
mkdir -p "$CAMPAIGN_DIR"

# Info de campaña
cat > "$CAMPAIGN_DIR/campaign_info.txt" << EOF
Campaña Intrinsic v4 (PARTÍCULAS PEQUEÑAS)
==========================================
Fecha: $(date)
Directorio: $CAMPAIGN_DIR

CAMBIO CLAVE: N_max_ref = 200 (vs 100 en v3)
    Radio = Perímetro / (2 × 200)
    Las partículas son la MITAD de tamaño que en v3

Esto permite:
    - Mayor densidad de partículas
    - Explorar e = 0.95 (muy excéntrico)
    - N hasta 120 partículas

Parámetros:
    e = [0.8, 0.9, 0.95]
    N = [60, 80, 100, 120]
    Coberturas = [30%, 40%, 50%, 60%]
    Seeds = 5 por condición
    Total runs = 60

Configuración de simulación:
    max_time = 100.0
    dt_max = 1e-5
    dt_min = 1e-10
    save_interval = 0.5
EOF

echo "=========================================="
echo "CAMPAÑA INTRINSIC v4 - PARTÍCULAS PEQUEÑAS"
echo "=========================================="
echo "Directorio: $CAMPAIGN_DIR"
echo "Runs totales: $(tail -n +2 $MATRIX_FILE | wc -l)"
echo ""

# Generar comandos
COMMANDS_FILE="$CAMPAIGN_DIR/commands.txt"
tail -n +2 "$MATRIX_FILE" | while IFS=, read -r run_id N e a seed max_time dt_max dt_min save_interval N_max_ref; do
    echo "julia --project=. run_single_intrinsic_campaign_v2.jl $run_id $N $e $a $seed $max_time $dt_max $dt_min $save_interval $N_max_ref $CAMPAIGN_DIR"
done > "$COMMANDS_FILE"

echo "Comandos generados: $(wc -l < $COMMANDS_FILE)"
echo ""
echo "Lanzando con GNU parallel (jobs=$N_JOBS)..."
echo ""

# Ejecutar
parallel --jobs $N_JOBS --joblog "$CAMPAIGN_DIR/joblog.txt" --progress < "$COMMANDS_FILE"

echo ""
echo "=========================================="
echo "CAMPAÑA COMPLETADA"
echo "=========================================="
echo "Resultados en: $CAMPAIGN_DIR"
