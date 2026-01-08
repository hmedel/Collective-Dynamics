#!/bin/bash
#
# launch_extended_campaign.sh
#
# Launch extended time campaign (t_max=500) using GNU parallel
#

set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CAMPAIGN_DIR="results/extended_campaign_${TIMESTAMP}"
MATRIX_FILE="parameter_matrix_extended_campaign.csv"
COMMANDS_FILE="${CAMPAIGN_DIR}/commands.txt"
JOBLOG_FILE="${CAMPAIGN_DIR}/joblog.txt"
N_CORES=24

echo "============================================================"
echo "EXTENDED TIME CAMPAIGN LAUNCHER"
echo "============================================================"
echo ""
echo "Campaign directory: $CAMPAIGN_DIR"
echo "Parameter matrix:   $MATRIX_FILE"
echo "Parallel cores:     $N_CORES"
echo ""

# Create campaign directory
mkdir -p "$CAMPAIGN_DIR"

# Copy parameter matrix
cp "$MATRIX_FILE" "$CAMPAIGN_DIR/"

# Generate commands from CSV
echo "Generating commands..."
tail -n +2 "$MATRIX_FILE" | while IFS=',' read -r run_id N e a b seed max_time dt_max dt_min save_interval; do
    echo "julia --project=. run_single_intrinsic_campaign.jl $run_id $N $e $a $b $seed $max_time $dt_max $dt_min $save_interval \"$CAMPAIGN_DIR\""
done > "$COMMANDS_FILE"

N_RUNS=$(wc -l < "$COMMANDS_FILE")
echo "Generated $N_RUNS commands"
echo ""

# Estimate runtime
echo "Estimated runtime: ~4 hours (with $N_CORES cores)"
echo ""

# Confirm launch
echo "Ready to launch campaign."
echo "Commands file: $COMMANDS_FILE"
echo ""

# Launch with GNU parallel
echo "Launching with GNU parallel..."
echo ""

parallel --joblog "$JOBLOG_FILE" \
         --jobs "$N_CORES" \
         --progress \
         --eta \
         --resume-failed \
         < "$COMMANDS_FILE" \
         > "${CAMPAIGN_DIR}/parallel_output.log" 2>&1 &

PARALLEL_PID=$!
echo "GNU parallel started with PID: $PARALLEL_PID"
echo ""

# Save campaign info
cat > "${CAMPAIGN_DIR}/campaign_info.txt" << EOF
Extended Time Campaign
======================
Started: $(date)
Campaign ID: extended_campaign_${TIMESTAMP}
Total runs: $N_RUNS
Parallel cores: $N_CORES
PID: $PARALLEL_PID

Parameters:
- N values: 40, 60, 80
- e values: 0.7, 0.8, 0.9
- Seeds: 10 per condition
- max_time: 500
- save_interval: 2.5

Monitor with:
  tail -f ${CAMPAIGN_DIR}/parallel_output.log
  watch "wc -l ${JOBLOG_FILE}"
EOF

echo "Campaign info saved to: ${CAMPAIGN_DIR}/campaign_info.txt"
echo ""
echo "Monitor progress with:"
echo "  tail -100 ${CAMPAIGN_DIR}/parallel_output.log"
echo "  wc -l ${JOBLOG_FILE}"
echo ""
echo "============================================================"
echo "CAMPAIGN LAUNCHED"
echo "============================================================"
