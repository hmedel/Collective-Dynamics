#!/bin/bash
# Launch finite-size scaling campaign
# Uses GNU parallel for efficient multi-core execution

set -e

echo "================================================================================"
echo "FINITE-SIZE SCALING CAMPAIGN LAUNCHER"
echo "================================================================================"
echo ""

# Configuration
MATRIX_FILE="parameter_matrix_finite_size_scaling.csv"
CAMPAIGN_DIR="results/campaign_finite_size_scaling_$(date +%Y%m%d_%H%M%S)"
N_CORES=24
LOG_FILE="$CAMPAIGN_DIR/campaign.log"

# Check if matrix exists
if [ ! -f "$MATRIX_FILE" ]; then
    echo "❌ ERROR: Parameter matrix not found: $MATRIX_FILE"
    echo "   Run: julia --project=. generate_finite_size_scaling_matrix.jl"
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
echo "Total runs: $TOTAL_RUNS"
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

# Construct use_parallel flag
if [ "$use_parallel" == "true" ] || [ "$use_parallel" == "True" ]; then
    PARALLEL_FLAG="--use_parallel"
else
    PARALLEL_FLAG=""
fi

# Run simulation
# Note: script auto-determines save_interval based on t_max
julia --project=. -t $JULIA_NUM_THREADS run_single_experiment.jl \
    --N $N \
    -e $e \
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
echo "LAUNCHING CAMPAIGN"
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
             --colsep ',' \
             "$RUN_SCRIPT" {%} "$CAMPAIGN_DIR"

EXIT_CODE=$?

echo ""
echo "================================================================================"
echo "CAMPAIGN COMPLETED"
echo "================================================================================"
echo ""
echo "End time: $(date)"
echo "Exit code: $EXIT_CODE"
echo ""

# Summary
COMPLETED=$(find "$CAMPAIGN_DIR" -name "*.h5" | wc -l)
echo "Runs completed: $COMPLETED / $TOTAL_RUNS"

if [ $COMPLETED -eq $TOTAL_RUNS ]; then
    echo "✅ All runs completed successfully!"
else
    FAILED=$((TOTAL_RUNS - COMPLETED))
    echo "⚠️  $FAILED runs failed or incomplete"
    echo ""
    echo "To relaunch failed runs:"
    echo "  ./launch_finite_size_scaling.sh"
    echo "  (GNU parallel will resume from joblog)"
fi

echo ""
echo "Results directory: $CAMPAIGN_DIR"
echo ""
echo "Next steps:"
echo "  1. Verify: ls $CAMPAIGN_DIR/*.h5 | wc -l"
echo "  2. Analyze temporal dynamics: julia --project=. analyze_temporal_dynamics.jl"
echo "  3. Finite-size scaling: julia --project=. analyze_finite_size_scaling.jl"

exit $EXIT_CODE
