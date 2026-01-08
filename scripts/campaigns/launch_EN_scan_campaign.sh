#!/bin/bash
#
# launch_EN_scan_campaign.sh
#
# Launch E/N (temperature) scan campaign using GNU parallel
#
# Usage:
#   ./launch_EN_scan_campaign.sh [matrix_file] [n_jobs]
#
# Arguments:
#   matrix_file - CSV file with parameters (default: config/matrices/parameter_matrix_EN_scan.csv)
#   n_jobs      - Number of parallel jobs (default: 24)
#

set -e

# Default parameters
MATRIX_FILE="${1:-config/matrices/parameter_matrix_EN_scan.csv}"
N_JOBS="${2:-24}"

# Timestamp for campaign
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CAMPAIGN_DIR="results/EN_scan_campaign_${TIMESTAMP}"

# Create campaign directory
mkdir -p "$CAMPAIGN_DIR"

# Copy matrix file for reference
cp "$MATRIX_FILE" "$CAMPAIGN_DIR/parameter_matrix.csv"

# Count total runs
TOTAL_RUNS=$(tail -n +2 "$MATRIX_FILE" | wc -l)

echo "========================================================================"
echo "E/N SCAN CAMPAIGN LAUNCHER"
echo "========================================================================"
echo ""
echo "Configuration:"
echo "  Matrix file:    $MATRIX_FILE"
echo "  Campaign dir:   $CAMPAIGN_DIR"
echo "  Total runs:     $TOTAL_RUNS"
echo "  Parallel jobs:  $N_JOBS"
echo ""
echo "Starting campaign at $(date)"
echo ""

# Save campaign info
cat > "$CAMPAIGN_DIR/campaign_info.txt" << EOF
E/N Scan Campaign
==================
Started: $(date)
Matrix file: $MATRIX_FILE
Total runs: $TOTAL_RUNS
Parallel jobs: $N_JOBS

Purpose: Establish temperature-dependent phase behavior
Varying: E/N (effective temperature)
Fixed: N=40, φ=0.06
EOF

# Generate commands file
COMMANDS_FILE="$CAMPAIGN_DIR/commands.txt"
echo "Generating commands..."

# CSV columns: run_id,E_per_N,eccentricity,a_b_ratio,ecc_label,N,phi,radius,v_max,seed,...
tail -n +2 "$MATRIX_FILE" | while IFS=',' read -r run_id E_per_N eccentricity a_b_ratio ecc_label N phi radius v_max seed rest; do
    # Arguments: run_id N e E_per_N seed campaign_dir
    echo "julia --project=. scripts/analysis/run_single_EN_scan.jl $run_id $N $eccentricity $E_per_N $seed $CAMPAIGN_DIR"
done > "$COMMANDS_FILE"

echo "Generated $(wc -l < "$COMMANDS_FILE") commands"
echo ""

# Launch with GNU parallel
echo "Launching with GNU parallel ($N_JOBS jobs)..."
echo ""

# Check if parallel is available
if ! command -v parallel &> /dev/null; then
    echo "ERROR: GNU parallel not found. Install with: sudo apt install parallel"
    echo ""
    echo "Alternative: Run sequentially with:"
    echo "  while read cmd; do \$cmd; done < $COMMANDS_FILE"
    exit 1
fi

# Run with progress bar
parallel --progress --jobs "$N_JOBS" < "$COMMANDS_FILE"

# Campaign complete
echo ""
echo "========================================================================"
echo "CAMPAIGN COMPLETE"
echo "========================================================================"
echo "Finished at $(date)"
echo "Results in: $CAMPAIGN_DIR"
echo ""
echo "Next steps:"
echo "  1. Check results: ls $CAMPAIGN_DIR/"
echo "  2. Analyze: julia --project=. scripts/analysis/analyze_EN_scan.jl $CAMPAIGN_DIR"
echo "========================================================================"

# Save completion info
echo "Completed: $(date)" >> "$CAMPAIGN_DIR/campaign_info.txt"
