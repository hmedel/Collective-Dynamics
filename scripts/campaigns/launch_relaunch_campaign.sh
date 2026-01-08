#!/bin/bash
# Launch relaunch campaign for failed intrinsic runs
# Uses adapted radius for N≥60 particles

CAMPAIGN_DIR="results/intrinsic_campaign_20251121_002941"
COMMANDS_FILE="relaunch_commands.txt"
JOBLOG="$CAMPAIGN_DIR/joblog_relaunch.txt"

echo "=============================================="
echo "INTRINSIC CAMPAIGN RELAUNCH"
echo "=============================================="
echo "Campaign directory: $CAMPAIGN_DIR"
echo "Commands file: $COMMANDS_FILE"
echo "Total runs to relaunch: $(wc -l < $COMMANDS_FILE)"
echo ""
echo "Radios adaptados:"
echo "  - N ≤ 40: 0.05 * b (original)"
echo "  - N = 60: 0.03 * b (reducido)"
echo "  - N ≥ 80: 0.025 * b (más reducido)"
echo ""
echo "Starting at: $(date)"
echo "=============================================="

# Run with GNU parallel
parallel --jobs 24 \
         --joblog "$JOBLOG" \
         --progress \
         --resume-failed \
         < "$COMMANDS_FILE"

echo ""
echo "=============================================="
echo "RELAUNCH COMPLETED"
echo "=============================================="
echo "Finished at: $(date)"
echo "Check results in: $CAMPAIGN_DIR"
echo "Joblog: $JOBLOG"
