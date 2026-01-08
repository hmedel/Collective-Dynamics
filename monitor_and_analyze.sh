#!/bin/bash
# Monitor campaign and analyze when complete

CAMPAIGN_DIR="results/long_time_EN_scan_20260108_084402"

while true; do
    COMPLETED=$(find "$CAMPAIGN_DIR" -name "summary.json" 2>/dev/null | wc -l)
    ACTIVE=$(ps aux | grep run_single_EN_scan_long | grep -v grep | wc -l)
    
    echo "[$(date +%H:%M:%S)] Completed: $COMPLETED/75, Active: $ACTIVE"
    
    if [ $ACTIVE -eq 0 ] && [ $COMPLETED -ge 75 ]; then
        echo "Campaign complete! Running analysis..."
        
        # Batch analyze all runs
        for h5 in "$CAMPAIGN_DIR"/*/trajectories.h5; do
            dir=$(dirname "$h5")
            if [ ! -d "$dir/clustering_analysis" ]; then
                julia --project=. scripts/analysis/analyze_clustering_proper.jl "$h5" > /dev/null 2>&1
            fi
        done
        
        # Run cluster formation analysis
        julia --project=. scripts/analysis/analyze_cluster_formation_time.jl "$CAMPAIGN_DIR"
        
        echo "Analysis complete!"
        break
    fi
    
    sleep 60
done
