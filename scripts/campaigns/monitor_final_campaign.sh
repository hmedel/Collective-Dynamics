#!/bin/bash
#
# monitor_final_campaign.sh
#
# Quick status check for the final campaign
#

CAMPAIGN_DIR="results/final_campaign_20251120_202723"

if [ ! -d "$CAMPAIGN_DIR" ]; then
    echo "❌ Campaign directory not found: $CAMPAIGN_DIR"
    exit 1
fi

echo "========================================================================"
echo "FINAL CAMPAIGN STATUS"
echo "========================================================================"
echo "Campaign: $CAMPAIGN_DIR"
echo "Started:  $(date -r "$CAMPAIGN_DIR" '+%Y-%m-%d %H:%M:%S')"
echo

# Count completed runs
COMPLETED=$(find "$CAMPAIGN_DIR" -name "trajectories.h5" | wc -l)
TOTAL=240

echo "Progress: $COMPLETED / $TOTAL simulations completed ($(echo "scale=1; $COMPLETED*100/$TOTAL" | bc)%)"
echo

# Count running processes
RUNNING=$(ps aux | grep "[j]ulia.*run_single_final_campaign" | wc -l)
echo "Running processes: $RUNNING"
echo

# Estimated time remaining (based on average)
if [ -f "$CAMPAIGN_DIR/joblog.txt" ] && [ $COMPLETED -gt 0 ]; then
    # Calculate average time per job from joblog (column 4)
    AVG_TIME=$(tail -n +2 "$CAMPAIGN_DIR/joblog.txt" | awk -F'\t' '{sum+=$4; count++} END {if(count>0) print sum/count; else print 0}')

    if [ ! -z "$AVG_TIME" ] && (( $(echo "$AVG_TIME > 0" | bc -l) )); then
        REMAINING=$((TOTAL - COMPLETED))
        # With 24 parallel jobs
        TIME_LEFT=$(echo "scale=1; $REMAINING * $AVG_TIME / 24" | bc)
        TIME_MIN=$(echo "scale=0; $TIME_LEFT / 60" | bc)

        echo "Average time/job: ${AVG_TIME}s"
        echo "Estimated time remaining: ~${TIME_MIN} minutes"
        echo
    fi
fi

# Recent completions
echo "Recent completions (last 5):"
find "$CAMPAIGN_DIR" -name "trajectories.h5" -printf '%T@ %p\n' | \
    sort -rn | head -5 | \
    while read timestamp path; do
        dir=$(dirname "$path")
        run_name=$(basename "$dir")
        date_str=$(date -d "@$timestamp" '+%H:%M:%S')
        echo "  [$date_str] $run_name"
    done
echo

# Check for errors
ERROR_COUNT=$(grep -r "ERROR" "$CAMPAIGN_DIR"/*/run.log 2>/dev/null | wc -l)
if [ $ERROR_COUNT -gt 0 ]; then
    echo "⚠️  Found $ERROR_COUNT errors in logs"
    echo
fi

# Disk usage
DISK_USAGE=$(du -sh "$CAMPAIGN_DIR" | cut -f1)
echo "Disk usage: $DISK_USAGE"
echo

echo "========================================================================"
echo "To monitor in real-time, run:"
echo "  watch -n 10 ./monitor_final_campaign.sh"
echo "========================================================================"
