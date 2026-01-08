#!/bin/bash
# Quick check if campaign is complete

CAMPAIGN_DIR="results/campaign_eccentricity_scan_20251116_014451"

echo "========================================"
echo "  VERIFICACIÓN RÁPIDA DE COMPLETITUD"
echo "========================================"
echo

# Count HDF5 files
n_files=$(ls $CAMPAIGN_DIR/*.h5 2>/dev/null | wc -l)

echo "Runs completados: $n_files / 180"
echo

# Check by eccentricity
for e in 0.000 0.300 0.500 0.700 0.800 0.900 0.950 0.980 0.990; do
    n_e=$(ls $CAMPAIGN_DIR/*e${e}*.h5 2>/dev/null | wc -l)
    if [ $n_e -eq 20 ]; then
        status="✓"
    else
        status="($n_e/20)"
    fi
    echo "  e=$e: $status"
done

echo
echo "----------------------------------------"

if [ $n_files -eq 180 ]; then
    echo "✅ CAMPAÑA COMPLETA!"
    echo
    echo "Ejecutar ahora:"
    echo "  julia --project=. analyze_full_campaign_final.jl"
    echo "  julia --project=. plot_campaign_final.jl"
else
    missing=$((180 - n_files))
    echo "⏳ Pendiente: $missing runs"

    # Check active processes
    n_procs=$(ps aux | grep -c "[r]un_single_eccentricity")
    echo "   Procesos activos: $n_procs"

    if [ $n_procs -gt 0 ]; then
        echo "   Status: EJECUTANDO"
    else
        echo "   ⚠️  WARNING: No hay procesos corriendo"
    fi
fi

echo "========================================"
