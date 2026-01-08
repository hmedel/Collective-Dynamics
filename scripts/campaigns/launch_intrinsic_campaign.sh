#!/bin/bash

# Launch script for INTRINSIC DISTANCE campaign
# 720 runs: 4 N × 6 e × 30 seeds
# Uses corrected collision detection with arc-length

set -e

echo "======================================================================"
echo "LAUNCHING INTRINSIC DISTANCE CAMPAIGN"
echo "======================================================================"
echo ""
echo "This campaign corrects the collision detection to use INTRINSIC"
echo "distances (arc-length along the ellipse) instead of Euclidean."
echo ""
echo "Configuration:"
echo "  - Total runs: 720"
echo "  - Seeds per condition: 30 (improved statistics)"
echo "  - Collision method: INTRINSIC (arc-length)"
echo "  - Parallel cores: $(nproc)"
echo ""
read -p "Press ENTER to start or Ctrl+C to cancel..."
echo ""

# Crear directorio de resultados
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CAMPAIGN_DIR="results/intrinsic_campaign_${TIMESTAMP}"
mkdir -p "$CAMPAIGN_DIR"

echo "Campaign directory: $CAMPAIGN_DIR"
echo ""

# Copiar matriz de parámetros
cp parameter_matrix_intrinsic_campaign.csv "$CAMPAIGN_DIR/"

# NO copiar script - ejecutarlo desde el directorio principal

# Crear archivo de comandos para GNU parallel
COMMANDS_FILE="$CAMPAIGN_DIR/commands.txt"
echo "Generating commands file..."

while IFS=, read -r run_id N e a b seed max_time dt_max dt_min save_interval
do
    # Skip header
    if [ "$run_id" = "run_id" ]; then
        continue
    fi

    # Formato: julia --project=. run_single_intrinsic_campaign.jl <parametros>
    # Ejecutar desde el directorio del proyecto (no desde results/)
    echo "julia --project=. run_single_intrinsic_campaign.jl $run_id $N $e $a $b $seed $max_time $dt_max $dt_min $save_interval \"$CAMPAIGN_DIR\"" >> "$COMMANDS_FILE"
done < parameter_matrix_intrinsic_campaign.csv

TOTAL_RUNS=$(wc -l < "$COMMANDS_FILE")
echo "✅ Commands file created: $TOTAL_RUNS runs"
echo ""

# Lanzar con GNU parallel
echo "======================================================================"
echo "STARTING PARALLEL EXECUTION"
echo "======================================================================"
echo ""
echo "Using GNU parallel with $(nproc) cores"
echo "Logging to: $CAMPAIGN_DIR/joblog.txt"
echo ""

# Ejecutar con GNU parallel
parallel --jobs $(nproc) \
         --joblog "$CAMPAIGN_DIR/joblog.txt" \
         --resume \
         --progress \
         < "$COMMANDS_FILE"

echo ""
echo "======================================================================"
echo "CAMPAIGN COMPLETED"
echo "======================================================================"
echo ""

# Estadísticas de finalización
COMPLETED=$(grep -c "^[0-9]" "$CAMPAIGN_DIR/joblog.txt" || echo "0")
echo "Completed runs: $COMPLETED / $TOTAL_RUNS"
echo ""

# Crear archivo de resumen
SUMMARY_FILE="$CAMPAIGN_DIR/campaign_summary.txt"
cat > "$SUMMARY_FILE" << EOF
INTRINSIC DISTANCE CAMPAIGN SUMMARY
====================================================================

Campaign ID: intrinsic_campaign_${TIMESTAMP}
Launch time: $(date)
Total runs:  $TOTAL_RUNS
Completed:   $COMPLETED

PARAMETERS:
-----------
N values:      [20, 40, 60, 80]
e values:      [0.0, 0.3, 0.5, 0.7, 0.8, 0.9]
Seeds:         30 per condition
Total:         720 runs

PHYSICS:
--------
Semi-major axis (a):  2.0
Collision detection:  INTRINSIC (arc-length)
Collision method:     Parallel transport
Integration:          Forest-Ruth 4th order
Max time:             100.0
dt_max:               1e-5
dt_min:               1e-10
Save interval:        0.5

IMPROVEMENTS vs PREVIOUS CAMPAIGN:
-----------------------------------
✅ Collision detection: Euclidean → Intrinsic (arc-length)
✅ Seeds:               10 → 30 (3x better statistics)
✅ Total runs:          240 → 720

This corrected campaign ensures proper geometric treatment of collisions
on curved manifolds, critical for curvature-driven clustering studies.

====================================================================
EOF

echo "✅ Summary saved to: $SUMMARY_FILE"
cat "$SUMMARY_FILE"

echo ""
echo "======================================================================"
echo "Next steps:"
echo "  1. Check results: ls -lh $CAMPAIGN_DIR/"
echo "  2. Analyze data:  julia --project=. analyze_intrinsic_campaign.jl"
echo "======================================================================"
