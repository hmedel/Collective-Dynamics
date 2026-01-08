#!/bin/bash
#
# launch_long_time_EN_scan.sh
#
# Launch long-time E/N scan campaign (t_max=500s)
# Follow-up to initial E/N scan to better capture clustering dynamics
#

set -e

MATRIX_FILE="config/matrices/parameter_matrix_long_time_EN_scan.csv"
N_JOBS="${1:-24}"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CAMPAIGN_DIR="results/long_time_EN_scan_${TIMESTAMP}"

mkdir -p "$CAMPAIGN_DIR"
cp "$MATRIX_FILE" "$CAMPAIGN_DIR/parameter_matrix.csv"

TOTAL_RUNS=$(tail -n +2 "$MATRIX_FILE" | wc -l)

echo "========================================================================"
echo "LONG-TIME E/N SCAN CAMPAIGN"
echo "========================================================================"
echo ""
echo "Purpose: Better capture clustering dynamics with 5x longer simulation"
echo ""
echo "Configuration:"
echo "  Matrix file:    $MATRIX_FILE"
echo "  Campaign dir:   $CAMPAIGN_DIR"
echo "  Total runs:     $TOTAL_RUNS"
echo "  Parallel jobs:  $N_JOBS"
echo "  t_max:          500s (vs 100s in initial scan)"
echo ""
echo "Starting campaign at $(date)"
echo ""

cat > "$CAMPAIGN_DIR/campaign_info.txt" << EOF
Long-Time E/N Scan Campaign
============================
Started: $(date)
Matrix file: $MATRIX_FILE
Total runs: $TOTAL_RUNS
Parallel jobs: $N_JOBS

Purpose: Follow-up to initial E/N scan
- Initial scan showed max 10% clustering with t_max=100s
- This experiment uses t_max=500s to allow more time for clustering
- Focus on transition region: E/N = 0.1 to 1.6
- Eccentricities: 0.5, 0.8, 0.9
EOF

# Generate commands
COMMANDS_FILE="$CAMPAIGN_DIR/commands.txt"
echo "Generating commands..."

# CSV columns: run_id,E_per_N,eccentricity,a,b,ecc_label,N,phi,radius,v_max,t_max,seed,...
tail -n +2 "$MATRIX_FILE" | while IFS=',' read -r run_id E_per_N e a b ecc_label N phi radius v_max t_max seed rest; do
    echo "julia --project=. scripts/analysis/run_single_EN_scan_long.jl $run_id $N $e $E_per_N $t_max $seed $CAMPAIGN_DIR"
done > "$COMMANDS_FILE"

echo "Generated $(wc -l < "$COMMANDS_FILE") commands"
echo ""

# Check for parallel
if ! command -v parallel &> /dev/null; then
    echo "ERROR: GNU parallel not found. Install with: sudo apt install parallel"
    exit 1
fi

echo "Launching with GNU parallel ($N_JOBS jobs)..."
parallel --progress --jobs "$N_JOBS" < "$COMMANDS_FILE"

echo ""
echo "========================================================================"
echo "CAMPAIGN COMPLETE"
echo "========================================================================"
echo "Finished at $(date)"
echo "Results in: $CAMPAIGN_DIR"
echo ""

echo "Completed: $(date)" >> "$CAMPAIGN_DIR/campaign_info.txt"
