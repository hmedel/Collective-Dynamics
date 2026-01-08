#!/bin/bash
# Launch relaunch campaign for failed runs with higher max_steps (50M)

CAMPAIGN_DIR="results/extended_campaign_20251123_161354"
COMMANDS_FILE="relaunch_commands.txt"

echo "========================================"
echo "RELAUNCH CAMPAIGN"
echo "========================================"
echo "Date:         $(date)"
echo "Commands:     $(wc -l < $COMMANDS_FILE)"
echo "Campaign dir: $CAMPAIGN_DIR"
echo "max_steps:    50_000_000 (5x original)"
echo "========================================"
echo

if [ ! -f "$COMMANDS_FILE" ]; then
    echo "ERROR: Commands file not found: $COMMANDS_FILE"
    echo "Run: julia --project=. generate_relaunch_commands.jl"
    exit 1
fi

# Use GNU parallel with 20 jobs (leave some cores free)
# Each job is compute-intensive, so moderate parallelism
N_JOBS=20

echo "Starting relaunch with $N_JOBS parallel jobs..."
echo "Log: $CAMPAIGN_DIR/joblog_relaunch.txt"
echo

nohup parallel --jobs $N_JOBS \
    --joblog "$CAMPAIGN_DIR/joblog_relaunch.txt" \
    --progress \
    < "$COMMANDS_FILE" \
    > "$CAMPAIGN_DIR/relaunch_output.log" 2>&1 &

BGPID=$!
echo "Background PID: $BGPID"
echo "Saved to: $CAMPAIGN_DIR/bgpid_relaunch.txt"
echo $BGPID > "$CAMPAIGN_DIR/bgpid_relaunch.txt"

echo
echo "To monitor progress:"
echo "  tail -f $CAMPAIGN_DIR/relaunch_output.log"
echo "  tail -f $CAMPAIGN_DIR/joblog_relaunch.txt"
echo
echo "Or run: ./monitor_relaunch_campaign.sh"
