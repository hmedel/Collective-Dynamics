#!/bin/bash
# Monitor relaunch campaign progress

CAMPAIGN_DIR="results/extended_campaign_20251123_161354"

echo "========================================"
echo "RELAUNCH CAMPAIGN STATUS"
echo "========================================"
echo "Date: $(date)"
echo

# Check if process is running
if [ -f "$CAMPAIGN_DIR/bgpid_relaunch.txt" ]; then
    BGPID=$(cat "$CAMPAIGN_DIR/bgpid_relaunch.txt")
    if ps -p $BGPID > /dev/null 2>&1; then
        echo "Status: RUNNING (PID $BGPID)"
    else
        echo "Status: FINISHED or STOPPED"
    fi
else
    echo "Status: No PID file found"
fi
echo

# Count completed runs
TOTAL_RUNS=90
COMPLETED=$(find "$CAMPAIGN_DIR" -name "summary.json" | wc -l)
echo "Completed: $COMPLETED / $TOTAL_RUNS"

# Count by condition
echo
echo "By condition:"
for e in 0.70 0.80 0.90; do
    for N in 040 060 080; do
        pattern="e${e}_N${N}_seed*"
        total=$(ls -d "$CAMPAIGN_DIR"/$pattern 2>/dev/null | wc -l)
        completed=$(find "$CAMPAIGN_DIR" -path "*e${e}_N${N}_seed*/summary.json" 2>/dev/null | wc -l)
        if [ $total -gt 0 ]; then
            if [ $completed -eq $total ]; then
                status="✓"
            elif [ $completed -gt 0 ]; then
                status="⚠"
            else
                status="✗"
            fi
            echo "  e=$e N=$N: $completed/$total $status"
        fi
    done
done

# Show joblog tail if exists
if [ -f "$CAMPAIGN_DIR/joblog_relaunch.txt" ]; then
    echo
    echo "Recent jobs (joblog_relaunch.txt):"
    tail -5 "$CAMPAIGN_DIR/joblog_relaunch.txt" | awk '{print "  "$0}'
fi

# Show recent output
if [ -f "$CAMPAIGN_DIR/relaunch_output.log" ]; then
    echo
    echo "Recent output:"
    tail -3 "$CAMPAIGN_DIR/relaunch_output.log" | awk '{print "  "$0}'
fi

echo
echo "========================================"
