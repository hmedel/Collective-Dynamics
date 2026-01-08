#!/bin/bash
#
# Launch E/N Temperature Scan Campaign
#
# Critical experiment to establish temperature-dependent phase behavior.
# Runs 210 simulations (7 E/N values × 3 eccentricities × 10 seeds).
#
# Usage:
#   ./launch_EN_scan.sh parameter_matrix_EN_scan.csv --mode parallel --jobs 24
#   ./launch_EN_scan.sh parameter_matrix_EN_scan.csv --mode sequential  # debug

set -e  # Exit on error

# ========================================
# Configuration
# ========================================

PARAM_FILE=${1:-parameter_matrix_EN_scan.csv}
MODE=${2:---mode}
EXEC_MODE=${3:-parallel}  # parallel or sequential
N_JOBS=${5:-24}           # Parallel jobs (max CPU cores)
N_THREADS=1               # Threads per job (use 1 to maximize parallel jobs)

PROJECT_DIR=$(pwd)
RUN_SCRIPT="$PROJECT_DIR/run_single_experiment.jl"
OUTPUT_BASE="$PROJECT_DIR/results/campaign_EN_scan_$(date +%Y%m%d_%H%M%S)"

# Simulation parameters (E/N scan specific)
T_MAX=100.0               # 100 seconds for good statistics
USE_PARALLEL="--use_parallel"  # Enable parallel collision detection

# ========================================
# Validate Inputs
# ========================================

if [ ! -f "$PARAM_FILE" ]; then
    echo "Error: Parameter file not found: $PARAM_FILE"
    echo "Generate one with: julia generate_EN_scan_matrix.jl"
    exit 1
fi

if [ ! -f "$RUN_SCRIPT" ]; then
    echo "Error: Run script not found: $RUN_SCRIPT"
    exit 1
fi

# Count total runs
N_RUNS=$(tail -n +2 "$PARAM_FILE" | wc -l)

echo "========================================================================"
echo "E/N Temperature Scan Campaign"
echo "========================================================================"
echo "Purpose:      Determine critical temperature T_c and phase diagram"
echo "Parameter file: $PARAM_FILE"
echo "Total runs:     $N_RUNS"
echo "Execution mode: $EXEC_MODE"
echo "Parallel jobs:  $N_JOBS"
echo "Threads/job:    $N_THREADS"
echo "Simulation time: $T_MAX seconds"
echo "Output base:    $OUTPUT_BASE"
echo "========================================================================"
echo

# Create output directory
mkdir -p "$OUTPUT_BASE/logs"

# Copy parameter matrix to output for reference
cp "$PARAM_FILE" "$OUTPUT_BASE/parameter_matrix.csv"

# ========================================
# GNU Parallel Mode (Recommended)
# ========================================

if [ "$EXEC_MODE" == "parallel" ]; then
    echo "Running with GNU Parallel (max $N_JOBS jobs)..."

    # Check if GNU parallel is available
    if ! command -v parallel &> /dev/null; then
        echo "Error: GNU parallel not found. Install with: sudo apt install parallel"
        exit 1
    fi

    # Extract run IDs from parameter file
    RUN_IDS=$(tail -n +2 "$PARAM_FILE" | awk -F',' '{print $1}')

    # Create command list
    CMD_FILE="$OUTPUT_BASE/commands.txt"
    rm -f "$CMD_FILE"

    for RUN_ID in $RUN_IDS; do
        echo "julia --project=$PROJECT_DIR --threads=$N_THREADS $RUN_SCRIPT --param_file $PARAM_FILE --run_id $RUN_ID --output_dir $OUTPUT_BASE --t_max $T_MAX $USE_PARALLEL" >> "$CMD_FILE"
    done

    echo "Created command file: $CMD_FILE ($N_RUNS commands)"
    echo "Starting execution at $(date)..."
    echo

    # Estimate time
    TIME_PER_RUN_MIN=6.0  # 6 minutes per run for N=40, t_max=100s
    TOTAL_TIME_MIN=$(echo "$N_RUNS * $TIME_PER_RUN_MIN" | bc)
    PARALLEL_TIME_MIN=$(echo "$TOTAL_TIME_MIN / $N_JOBS" | bc)
    PARALLEL_TIME_HR=$(echo "scale=1; $PARALLEL_TIME_MIN / 60" | bc)

    echo "⏱️  Estimated completion time: ~${PARALLEL_TIME_HR} hours"
    echo

    # Run with GNU parallel
    # --jobs: number of parallel jobs
    # --progress: show progress bar
    # --joblog: save job execution log
    # --resume: can resume if interrupted
    parallel --jobs "$N_JOBS" \
             --progress \
             --joblog "$OUTPUT_BASE/joblog.txt" \
             --resume \
             < "$CMD_FILE"

    EXIT_CODE=$?

    echo
    echo "========================================================================"
    if [ $EXIT_CODE -eq 0 ]; then
        echo "✅ All jobs completed successfully!"
    else
        echo "⚠️  Some jobs may have failed (exit code: $EXIT_CODE)"
        echo "   Check: $OUTPUT_BASE/joblog.txt"
    fi
    echo "========================================================================"
    echo "Completion time: $(date)"
    echo "Job log: $OUTPUT_BASE/joblog.txt"
    echo

# ========================================
# Sequential Mode (Debugging)
# ========================================

elif [ "$EXEC_MODE" == "sequential" ]; then
    echo "Running sequentially (for debugging)..."

    # Extract run IDs
    RUN_IDS=$(tail -n +2 "$PARAM_FILE" | awk -F',' '{print $1}')

    COUNT=0
    for RUN_ID in $RUN_IDS; do
        COUNT=$((COUNT + 1))
        echo "[$COUNT/$N_RUNS] Running ID=$RUN_ID at $(date)..."

        julia --project="$PROJECT_DIR" --threads="$N_THREADS" "$RUN_SCRIPT" \
            --param_file "$PARAM_FILE" \
            --run_id "$RUN_ID" \
            --output_dir "$OUTPUT_BASE" \
            --t_max "$T_MAX" \
            $USE_PARALLEL \
            2>&1 | tee "$OUTPUT_BASE/logs/run_${RUN_ID}.log"
    done

    echo "All runs completed!"

else
    echo "Error: Unknown execution mode: $EXEC_MODE"
    echo "Use: parallel or sequential"
    exit 1
fi

# ========================================
# Post-Launch Summary
# ========================================

# Count successful runs
if [ -f "$OUTPUT_BASE/joblog.txt" ]; then
    N_SUCCESS=$(tail -n +2 "$OUTPUT_BASE/joblog.txt" | awk '$7 == 0 {count++} END {print count}')
    N_FAILED=$(tail -n +2 "$OUTPUT_BASE/joblog.txt" | awk '$7 != 0 {count++} END {print count}')

    echo
    echo "Summary:"
    echo "  Successful: $N_SUCCESS / $N_RUNS"
    if [ "$N_FAILED" != "" ] && [ "$N_FAILED" -gt 0 ]; then
        echo "  Failed:     $N_FAILED"
        echo "  Review failed runs:"
        echo "    tail -n +2 $OUTPUT_BASE/joblog.txt | awk '\$7 != 0 {print \$1}'"
    fi
fi

echo
echo "========================================================================"
echo "Next Steps - Analysis"
echo "========================================================================"
echo
echo "1. Check completion status:"
echo "   tail $OUTPUT_BASE/joblog.txt"
echo
echo "2. Analyze individual ensemble:"
echo "   julia analyze_ensemble.jl $OUTPUT_BASE/e0.866_N40_phi0.06_E0.32"
echo
echo "3. Generate E/N phase diagram (after all runs complete):"
echo "   julia analyze_EN_scan.jl $OUTPUT_BASE"
echo
echo "4. Extract critical temperature T_c:"
echo "   julia extract_critical_temperature.jl $OUTPUT_BASE"
echo
echo "Output directory: $OUTPUT_BASE"
echo "========================================================================"
