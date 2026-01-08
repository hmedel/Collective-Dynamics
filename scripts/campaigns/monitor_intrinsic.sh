#!/bin/bash
# Monitor intrinsic campaign progress
CAMPAIGN_DIR="results/intrinsic_campaign_20251121_002941"

echo "=== Intrinsic Campaign Monitor ==="
echo "Timestamp: $(date)"
echo ""

# Check if parallel is running
if pgrep -f "parallel.*intrinsic" > /dev/null; then
    echo "Status: RUNNING"
else
    echo "Status: NOT RUNNING (finished or stopped)"
fi
echo ""

# Count HDF5 files
HDF5_COUNT=$(find "$CAMPAIGN_DIR" -name "*.h5" 2>/dev/null | wc -l)
echo "HDF5 files generated: $HDF5_COUNT / 720"
echo "Progress: $(echo "scale=1; $HDF5_COUNT * 100 / 720" | bc)%"
echo ""

# Joblog stats
if [ -f "$CAMPAIGN_DIR/joblog.txt" ]; then
    COMPLETED=$(tail -n +2 "$CAMPAIGN_DIR/joblog.txt" | wc -l)
    SUCCESS=$(tail -n +2 "$CAMPAIGN_DIR/joblog.txt" | awk '$7==0' | wc -l)
    FAILED=$(tail -n +2 "$CAMPAIGN_DIR/joblog.txt" | awk '$7!=0' | wc -l)
    echo "Jobs completed: $COMPLETED / 720"
    echo "  - Successful: $SUCCESS"
    echo "  - Failed: $FAILED"

    if [ "$COMPLETED" -gt 0 ]; then
        echo ""
        echo "Last 3 completed:"
        tail -3 "$CAMPAIGN_DIR/joblog.txt" | awk '{print "  Run", NR, "- Exit:", $7, "- Runtime:", $4"s"}'
    fi
fi
