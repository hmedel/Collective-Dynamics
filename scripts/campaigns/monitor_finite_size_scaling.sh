#!/bin/bash
# Monitor progress of finite-size scaling campaign

# Find most recent campaign directory
CAMPAIGN_DIR=$(ls -dt results/campaign_finite_size_scaling_* 2>/dev/null | head -1)

if [ -z "$CAMPAIGN_DIR" ]; then
    echo "No campaign directory found"
    exit 1
fi

echo "================================================================================"
echo "FINITE-SIZE SCALING CAMPAIGN MONITOR"
echo "================================================================================"
echo ""
echo "Campaign: $CAMPAIGN_DIR"
echo "Time: $(date)"
echo ""

# Total runs expected
TOTAL=450

# Count completed
COMPLETED=$(find "$CAMPAIGN_DIR" -name "*.h5" -type f 2>/dev/null | wc -l)
PERCENT=$(awk "BEGIN {printf \"%.1f\", ($COMPLETED/$TOTAL)*100}")

echo "Progress: $COMPLETED / $TOTAL ($PERCENT%)"
echo ""

# Progress bar
BAR_LEN=50
FILLED=$(awk "BEGIN {printf \"%.0f\", ($COMPLETED/$TOTAL)*$BAR_LEN}")
printf "["
for i in $(seq 1 $FILLED); do printf "="; done
for i in $(seq $((FILLED+1)) $BAR_LEN); do printf " "; done
printf "]\n"
echo ""

# Breakdown by N
echo "By particle number (N):"
for N in 40 60 80 100 120; do
    COUNT=$(find "$CAMPAIGN_DIR" -name "*_N${N}_*" -type f 2>/dev/null | wc -l)
    EXPECTED=90  # 9 e × 10 realizations
    printf "  N = %3d: %2d / %2d\n" $N $COUNT $EXPECTED
done
echo ""

# Breakdown by e
echo "By eccentricity (e):"
for e in 0.0 0.3 0.5 0.7 0.8 0.9 0.95 0.98 0.99; do
    # Format e for filename matching
    e_str=$(printf "%.1f" $e | sed 's/\.//g' | sed 's/^0*//')
    if [ "$e" == "0.0" ]; then e_str="0.0"; fi
    COUNT=$(find "$CAMPAIGN_DIR" -name "*_e${e}*" -type f 2>/dev/null | wc -l)
    EXPECTED=50  # 5 N × 10 realizations
    printf "  e = %.2f: %2d / %2d\n" $e $COUNT $EXPECTED
done
echo ""

# Estimate time remaining
if [ -f "$CAMPAIGN_DIR/joblog.txt" ]; then
    echo "Job log analysis:"

    # Count running jobs
    RUNNING=$(ps aux | grep -c "[r]un_single_experiment.jl" || echo 0)
    echo "  Currently running: $RUNNING processes"

    # Failures
    FAILED=$(tail -n +2 "$CAMPAIGN_DIR/joblog.txt" | awk '$7 != 0 && $7 != "" {count++} END {print count+0}')
    echo "  Failed jobs: $FAILED"

    echo ""
fi

# Recent completions
echo "Last 5 completed runs:"
find "$CAMPAIGN_DIR" -name "*.h5" -type f -printf "%T@ %p\n" 2>/dev/null | \
    sort -rn | head -5 | while read -r timestamp file; do
    basename "$file"
done

echo ""
echo "================================================================================"

# Auto-refresh if requested
if [ "$1" == "--watch" ]; then
    sleep 10
    clear
    exec "$0" --watch
fi
