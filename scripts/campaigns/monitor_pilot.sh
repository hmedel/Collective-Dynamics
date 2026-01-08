#!/bin/bash
# Monitor Eccentricity Scan Pilot Campaign

CAMPAIGN_DIR="results/campaign_eccentricity_scan_20251116_002247"

echo "========================================"
echo "PILOTO: Eccentricity Scan Status"
echo "========================================"
echo ""

# Count HDF5 files
N_H5=$(ls ${CAMPAIGN_DIR}/*.h5 2>/dev/null | wc -l)
echo "✅ HDF5 archivos completados: ${N_H5} / 9"

# Count running processes
N_PROC=$(ps aux | grep "run_single_eccentricity" | grep -v grep | wc -l)
echo "🔄 Simulaciones corriendo: ${N_PROC}"

echo ""
echo "Progreso: $(echo "scale=1; ${N_H5} * 100 / 9" | bc 2>/dev/null || echo "0")%"
echo ""

# Show last completed run from joblog if it exists
if [ -f "${CAMPAIGN_DIR}/joblog.txt" ]; then
    echo "--- Últimos 3 runs completados ---"
    tail -n +2 "${CAMPAIGN_DIR}/joblog.txt" | tail -3 | while read line; do
        exitval=$(echo $line | awk '{print $7}')
        seq=$(echo $line | awk '{print $1}')
        if [ "$exitval" == "0" ]; then
            echo "  ✅ Run $seq - SUCCESS"
        elif [ "$exitval" != "Exitval" ]; then
            echo "  ❌ Run $seq - FAILED (exit code: $exitval)"
        fi
    done
fi

echo ""
echo "Para monitorear en tiempo real:"
echo "  watch -n 10 './monitor_pilot.sh'"
echo ""
echo "========================================"
