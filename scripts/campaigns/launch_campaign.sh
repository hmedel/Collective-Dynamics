#!/bin/bash
#
# Launch Experimental Campaign
#
# Submits all simulations from parameter matrix in parallel.
# Supports both SLURM (cluster) and GNU Parallel (local workstation).
#
# Usage:
#   ./launch_campaign.sh parameter_matrix_minimal.csv --mode slurm
#   ./launch_campaign.sh parameter_matrix_minimal.csv --mode parallel --jobs 24

set -e  # Exit on error

# ========================================
# Configuration
# ========================================

PARAM_FILE=${1:-parameter_matrix_minimal.csv}
MODE=${2:---mode}
EXEC_MODE=${3:-parallel}  # slurm or parallel
N_JOBS=${5:-24}

PROJECT_DIR=$(pwd)
RUN_SCRIPT="$PROJECT_DIR/run_single_experiment.jl"
OUTPUT_BASE="$PROJECT_DIR/results/campaign_$(date +%Y%m%d_%H%M%S)"

# ========================================
# Validate Inputs
# ========================================

if [ ! -f "$PARAM_FILE" ]; then
    echo "Error: Parameter file not found: $PARAM_FILE"
    echo "Generate one with: julia generate_parameter_matrix.jl minimal"
    exit 1
fi

if [ ! -f "$RUN_SCRIPT" ]; then
    echo "Error: Run script not found: $RUN_SCRIPT"
    exit 1
fi

# Count total runs
N_RUNS=$(tail -n +2 "$PARAM_FILE" | wc -l)

echo "========================================================================"
echo "Launching Experimental Campaign"
echo "========================================================================"
echo "Parameter file: $PARAM_FILE"
echo "Total runs:     $N_RUNS"
echo "Execution mode: $EXEC_MODE"
echo "Output base:    $OUTPUT_BASE"
echo "========================================================================"
echo

# Create output directory
mkdir -p "$OUTPUT_BASE/logs"

# ========================================
# SLURM Mode (Cluster)
# ========================================

if [ "$EXEC_MODE" == "slurm" ]; then
    echo "Submitting jobs to SLURM..."

    # Create SLURM array job script
    SLURM_SCRIPT="$OUTPUT_BASE/submit_array.sh"

    cat > "$SLURM_SCRIPT" <<EOF
#!/bin/bash
#SBATCH --job-name=collective_dynamics
#SBATCH --array=1-${N_RUNS}
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=24
#SBATCH --mem=8G
#SBATCH --time=02:00:00
#SBATCH --output=${OUTPUT_BASE}/logs/run_%a_%j.out
#SBATCH --error=${OUTPUT_BASE}/logs/run_%a_%j.err

# Load modules (adjust for your cluster)
# module load julia/1.10.0

# Run simulation
julia --project=$PROJECT_DIR --threads=24 $RUN_SCRIPT \\
    --param_file $PARAM_FILE \\
    --run_id \${SLURM_ARRAY_TASK_ID} \\
    --output_dir $OUTPUT_BASE \\
    --t_max 50.0 \\
    --use_parallel
EOF

    chmod +x "$SLURM_SCRIPT"

    # Submit
    JOB_ID=$(sbatch "$SLURM_SCRIPT" | awk '{print $4}')

    echo "Submitted SLURM array job: $JOB_ID"
    echo "Monitor with: squeue -u $USER"
    echo "Cancel with: scancel $JOB_ID"

# ========================================
# GNU Parallel Mode (Local Workstation)
# ========================================

elif [ "$EXEC_MODE" == "parallel" ]; then
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
        echo "julia --project=$PROJECT_DIR --threads=24 $RUN_SCRIPT --param_file $PARAM_FILE --run_id $RUN_ID --output_dir $OUTPUT_BASE --t_max 50.0 --use_parallel" >> "$CMD_FILE"
    done

    echo "Created command file: $CMD_FILE ($N_RUNS commands)"
    echo "Starting execution..."

    # Run with GNU parallel
    parallel --jobs "$N_JOBS" --progress --joblog "$OUTPUT_BASE/joblog.txt" < "$CMD_FILE"

    echo "All jobs completed!"
    echo "Job log: $OUTPUT_BASE/joblog.txt"

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
        echo "[$COUNT/$N_RUNS] Running ID=$RUN_ID..."

        julia --project="$PROJECT_DIR" --threads=24 "$RUN_SCRIPT" \
            --param_file "$PARAM_FILE" \
            --run_id "$RUN_ID" \
            --output_dir "$OUTPUT_BASE" \
            --t_max 50.0 \
            --use_parallel \
            2>&1 | tee "$OUTPUT_BASE/logs/run_${RUN_ID}.log"
    done

    echo "All runs completed!"

else
    echo "Error: Unknown execution mode: $EXEC_MODE"
    echo "Use: slurm, parallel, or sequential"
    exit 1
fi

# ========================================
# Post-Launch Information
# ========================================

echo
echo "========================================================================"
echo "Campaign Launched!"
echo "========================================================================"
echo "Output directory: $OUTPUT_BASE"
echo
echo "Monitor progress:"
if [ "$EXEC_MODE" == "slurm" ]; then
    echo "  squeue -u $USER"
    echo "  tail -f $OUTPUT_BASE/logs/run_*.out"
elif [ "$EXEC_MODE" == "parallel" ]; then
    echo "  tail -f $OUTPUT_BASE/joblog.txt"
fi
echo
echo "Analyze ensemble (after completion):"
echo "  julia analyze_ensemble.jl $OUTPUT_BASE/e0.866_N040_phi0.06_E0.32"
echo
echo "Generate phase diagrams:"
echo "  julia create_phase_diagrams.jl $OUTPUT_BASE"
echo "========================================================================"
