#!/bin/bash
# Launch TEST campaign (5 runs) for finite-size scaling validation
# Uses GNU parallel for efficient multi-core execution

set -e

echo "================================================================================"
echo "TEST CAMPAIGN LAUNCHER (5 runs)"
echo "================================================================================"
echo ""

# Configuration
MATRIX_FILE="parameter_matrix_test.csv"
CAMPAIGN_DIR="results/test_campaign_$(date +%Y%m%d_%H%M%S)"
N_CORES=5  # Use 5 cores for 5 runs (1 per run)
LOG_FILE="$CAMPAIGN_DIR/campaign.log"

# Check if matrix exists
if [ ! -f "$MATRIX_FILE" ]; then
    echo "❌ ERROR: Parameter matrix not found: $MATRIX_FILE"
    exit 1
fi

# Create campaign directory
mkdir -p "$CAMPAIGN_DIR"
echo "Campaign directory: $CAMPAIGN_DIR"
echo ""

# Copy matrix to campaign dir
cp "$MATRIX_FILE" "$CAMPAIGN_DIR/"

# Count total runs
TOTAL_RUNS=$(tail -n +2 "$MATRIX_FILE" | wc -l)
echo "Total test runs: $TOTAL_RUNS"
echo "Cores: $N_CORES"
echo ""

# Create run script
RUN_SCRIPT="$CAMPAIGN_DIR/run_single.sh"
cat > "$RUN_SCRIPT" << 'EOF'
#!/bin/bash
# Single run executor

# Parse CSV line
IFS=',' read -r run_id N e a b E_per_N radius seed t_max save_interval method collision_method use_parallel <<< "$1"

# Output filename
FILENAME="run_$(printf "%04d" $run_id)_N${N}_e${e}_seed${seed}.h5"
OUTPUT="$2/$FILENAME"

# Skip if already exists
if [ -f "$OUTPUT" ]; then
    echo "⏭️  Run $run_id already exists, skipping"
    exit 0
fi

# Calculate packing fraction: phi = N * radius^2 / (a * b)
phi=$(awk -v n=$N -v r=$radius -v a=$a -v b=$b 'BEGIN {printf "%.6f", n * r * r / (a * b)}')

# Construct use_parallel flag
if [ "$use_parallel" == "true" ] || [ "$use_parallel" == "True" ]; then
    PARALLEL_FLAG="--use_parallel"
else
    PARALLEL_FLAG=""
fi

echo "🚀 Starting run $run_id: N=$N, e=$e, phi=$phi, seed=$seed"

# Run simulation
julia --project=. -t $JULIA_NUM_THREADS run_single_experiment.jl \
    --eccentricity $e \
    --N $N \
    --phi $phi \
    --E_per_N $E_per_N \
    --seed $seed \
    --t_max $t_max \
    $PARALLEL_FLAG \
    --output_dir "$2" \
    2>&1 > "$OUTPUT.log"

# Check if output file was created
if [ -f "$OUTPUT" ]; then
    echo "✅ Run $run_id completed: $FILENAME"
    rm -f "$OUTPUT.log"  # Remove log on success
    exit 0
else
    echo "❌ Run $run_id FAILED - no output file created"
    cat "$OUTPUT.log"
    exit 1
fi
EOF

chmod +x "$RUN_SCRIPT"

# Export variables for parallel
export CAMPAIGN_DIR
export RUN_SCRIPT
export JULIA_NUM_THREADS=1  # Each job uses 1 thread for Julia

# Launch with GNU parallel
echo "================================================================================"
echo "LAUNCHING TEST CAMPAIGN"
echo "================================================================================"
echo ""
echo "Start time: $(date)"
echo ""

# Skip header, pass to parallel
tail -n +2 "$MATRIX_FILE" | \
    parallel --bar \
             --jobs $N_CORES \
             --joblog "$CAMPAIGN_DIR/joblog.txt" \
             --resume-failed \
             "$RUN_SCRIPT" {} "$CAMPAIGN_DIR"

EXIT_CODE=$?

echo ""
echo "================================================================================"
echo "TEST CAMPAIGN COMPLETED"
echo "================================================================================"
echo ""
echo "End time: $(date)"
echo "Exit code: $EXIT_CODE"
echo ""

# Summary
COMPLETED=$(find "$CAMPAIGN_DIR" -name "*.h5" | wc -l)
echo "Runs completed: $COMPLETED / $TOTAL_RUNS"

if [ $COMPLETED -eq $TOTAL_RUNS ]; then
    echo "✅ All test runs completed successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Verify results: julia --project=. verify_test_campaign.jl"
    echo "  2. If validation passes, launch full campaign: ./launch_finite_size_scaling.sh"
else
    FAILED=$((TOTAL_RUNS - COMPLETED))
    echo "⚠️  $FAILED runs failed or incomplete"
fi

echo ""
echo "Results directory: $CAMPAIGN_DIR"

exit $EXIT_CODE
