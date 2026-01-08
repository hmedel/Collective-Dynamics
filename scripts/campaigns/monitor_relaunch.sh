#!/bin/bash
# Monitor relaunch campaign progress

CAMPAIGN_DIR="results/intrinsic_campaign_20251121_002941"
JOBLOG="$CAMPAIGN_DIR/joblog_relaunch.txt"

echo "=============================================="
echo "RELAUNCH CAMPAIGN STATUS"
echo "=============================================="
echo "Time: $(date)"
echo ""

# Count completed runs from joblog
if [ -f "$JOBLOG" ]; then
    TOTAL_RUNS=$(wc -l < "$JOBLOG")
    HEADER=1
    COMPLETED=$((TOTAL_RUNS - HEADER))

    # Count by exit code
    SUCCESSFUL=$(awk -F'\t' 'NR>1 && $7==0 {count++} END {print count+0}' "$JOBLOG")
    FAILED=$(awk -F'\t' 'NR>1 && $7!=0 {count++} END {print count+0}' "$JOBLOG")

    echo "Progress: $COMPLETED / 338 runs completed"
    echo "  ✓ Successful: $SUCCESSFUL"
    echo "  ✗ Failed: $FAILED"
else
    echo "Joblog not found yet (campaign may be starting)"
fi

echo ""

# Count H5 files created (new ones since relaunch)
NEW_H5=$(find "$CAMPAIGN_DIR" -name "trajectories.h5" -newer relaunch_commands.txt 2>/dev/null | wc -l)
TOTAL_H5=$(find "$CAMPAIGN_DIR" -name "trajectories.h5" 2>/dev/null | wc -l)
echo "HDF5 files: $TOTAL_H5 total ($NEW_H5 new)"

echo ""

# Running processes
JULIA_PROCS=$(pgrep -c julia 2>/dev/null || echo "0")
echo "Running Julia processes: $JULIA_PROCS"

echo ""
echo "=============================================="

# Show latest completed runs
if [ -f "$JOBLOG" ]; then
    echo "Latest completed runs:"
    tail -3 "$JOBLOG" | awk -F'\t' 'NR>0 {split($9, cmd, " "); printf "  Run %s: N=%s e=%s (exit %s, %.0fs)\n", cmd[4], cmd[5], cmd[6], $7, $4}'
fi

echo ""
echo "For continuous monitoring: watch -n 30 ./monitor_relaunch.sh"
