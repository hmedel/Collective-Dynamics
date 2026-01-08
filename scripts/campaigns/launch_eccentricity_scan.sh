#!/bin/bash
# Launch eccentricity scan campaign with GNU parallel

set -e

PARAM_FILE=${1:-parameter_matrix_eccentricity_scan.csv}
N_JOBS=${2:-24}

if [ ! -f "$PARAM_FILE" ]; then
    echo "ERROR: Parameter file not found: $PARAM_FILE"
    echo "Run first: julia --project=. generate_eccentricity_scan.jl"
    exit 1
fi

echo "========================================================================"
echo "ECCENTRICITY SCAN CAMPAIGN LAUNCHER"
echo "========================================================================"
echo ""
echo "Parameter file: $PARAM_FILE"
echo "Parallel jobs: $N_JOBS"
echo ""

# Count runs
N_RUNS=$(tail -n +2 "$PARAM_FILE" | wc -l)
echo "Total runs: $N_RUNS"
echo ""

# Create output directory with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CAMPAIGN_DIR="results/campaign_eccentricity_scan_${TIMESTAMP}"
mkdir -p "$CAMPAIGN_DIR"

echo "Campaign directory: $CAMPAIGN_DIR"
echo ""

# Copy parameter file to campaign directory
cp "$PARAM_FILE" "$CAMPAIGN_DIR/parameters.csv"

# Generate command list
COMMANDS_FILE="$CAMPAIGN_DIR/commands.txt"
echo "Generating command list..."

# Read CSV and generate commands (skip header)
tail -n +2 "$PARAM_FILE" | while IFS=',' read -r run_id e a b N E_per_N seed t_max dt_max save_interval use_projection projection_interval; do
    # Remove any quotes or whitespace
    run_id=$(echo "$run_id" | tr -d ' "')
    e=$(echo "$e" | tr -d ' "')
    a=$(echo "$a" | tr -d ' "')
    b=$(echo "$b" | tr -d ' "')
    N=$(echo "$N" | tr -d ' "')
    E_per_N=$(echo "$E_per_N" | tr -d ' "')
    seed=$(echo "$seed" | tr -d ' "')
    t_max=$(echo "$t_max" | tr -d ' "')
    dt_max=$(echo "$dt_max" | tr -d ' "')
    save_interval=$(echo "$save_interval" | tr -d ' "')
    use_projection=$(echo "$use_projection" | tr -d ' "')
    projection_interval=$(echo "$projection_interval" | tr -d ' "')

    # Build command
    CMD="julia --project=. --threads=1 run_single_eccentricity_experiment.jl"
    CMD="$CMD --run-id $run_id"
    CMD="$CMD --eccentricity $e"
    CMD="$CMD --a $a"
    CMD="$CMD --b $b"
    CMD="$CMD --N $N"
    CMD="$CMD --E-per-N $E_per_N"
    CMD="$CMD --seed $seed"
    CMD="$CMD --t-max $t_max"
    CMD="$CMD --dt-max $dt_max"
    CMD="$CMD --save-interval $save_interval"
    CMD="$CMD --projection-interval $projection_interval"
    CMD="$CMD --output-dir $CAMPAIGN_DIR"

    # Add --use-projection flag if true
    if [ "$use_projection" = "true" ] || [ "$use_projection" = "True" ] || [ "$use_projection" = "1" ]; then
        CMD="$CMD --use-projection"
    fi

    # Redirect output
    LOG_FILE="$CAMPAIGN_DIR/run_${run_id}.log"
    CMD="$CMD > $LOG_FILE 2>&1"

    echo "$CMD"
done > "$COMMANDS_FILE"

echo "Commands generated: $COMMANDS_FILE"
echo ""

# Show summary
echo "========================================================================"
echo "CAMPAIGN SUMMARY"
echo "========================================================================"
head -5 "$COMMANDS_FILE" | sed 's/^/  /'
echo "  ..."
echo ""
echo "Total commands: $(wc -l < $COMMANDS_FILE)"
echo ""

# Estimate time
echo "Estimated time:"
echo "  ~45 min per run (sequential)"
TOTAL_HOURS=$(echo "scale=1; $N_RUNS * 0.75" | bc)
PARALLEL_HOURS=$(echo "scale=1; $TOTAL_HOURS / $N_JOBS" | bc)
echo "  Total sequential: $TOTAL_HOURS hours"
echo "  With $N_JOBS parallel jobs: $PARALLEL_HOURS hours"
echo ""

# Ask for confirmation
read -p "Launch campaign? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Campaign cancelled."
    exit 0
fi

echo ""
echo "========================================================================"
echo "LAUNCHING CAMPAIGN"
echo "========================================================================"
echo ""

# Launch with GNU parallel
cd "$CAMPAIGN_DIR"
nohup parallel --jobs "$N_JOBS" --progress --joblog joblog.txt < commands.txt > parallel_output.log 2>&1 &
PARALLEL_PID=$!

cd - > /dev/null

echo "Campaign launched in background!"
echo ""
echo "PID: $PARALLEL_PID"
echo "Campaign dir: $CAMPAIGN_DIR"
echo ""
echo "Monitor with:"
echo "  tail -f $CAMPAIGN_DIR/parallel_output.log"
echo "  tail -f $CAMPAIGN_DIR/joblog.txt"
echo ""
echo "Check progress:"
echo "  ls $CAMPAIGN_DIR/*.h5 | wc -l"
echo ""
echo "========================================================================"
