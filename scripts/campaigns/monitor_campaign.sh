#!/bin/bash
# Monitor Full Eccentricity Scan Campaign (180 runs)

CAMPAIGN_DIR="results/campaign_eccentricity_scan_20251116_014451"

echo "========================================"
echo "CAMPAÑA COMPLETA: Eccentricity Scan"
echo "========================================"
echo ""

# Count HDF5 files
N_H5=$(ls ${CAMPAIGN_DIR}/*.h5 2>/dev/null | wc -l)
echo "✅ HDF5 archivos completados: ${N_H5} / 180"

# Count running processes
N_PROC=$(ps aux | grep "run_single_eccentricity" | grep -v grep | wc -l)
echo "🔄 Simulaciones corriendo: ${N_PROC}"

# Calculate progress
if [ ${N_H5} -gt 0 ]; then
    PROG=$(awk "BEGIN {printf \"%.1f\", ${N_H5} * 100 / 180}")
else
    PROG=0
fi

echo ""
echo "Progreso: ${PROG}%"
echo ""

# Show last completed runs from joblog if it exists
if [ -f "${CAMPAIGN_DIR}/joblog.txt" ]; then
    N_COMPLETED=$(tail -n +2 "${CAMPAIGN_DIR}/joblog.txt" | grep -c "^[0-9]")
    echo "Jobs completados según joblog: ${N_COMPLETED}"

    if [ ${N_COMPLETED} -gt 0 ]; then
        echo ""
        echo "--- Últimos 5 runs completados ---"
        tail -n +2 "${CAMPAIGN_DIR}/joblog.txt" | tail -5 | while read line; do
            exitval=$(echo $line | awk '{print $7}')
            seq=$(echo $line | awk '{print $1}')
            runtime=$(echo $line | awk '{print $4}')
            if [ "$exitval" == "0" ]; then
                echo "  ✅ Run $seq - SUCCESS (${runtime}s)"
            elif [ "$exitval" != "Exitval" ] && [ "$exitval" != "" ]; then
                echo "  ❌ Run $seq - FAILED (exit code: $exitval)"
            fi
        done
    fi
fi

echo ""
echo "Para monitorear en tiempo real:"
echo "  watch -n 30 './monitor_campaign.sh'"
echo ""
echo "========================================"
