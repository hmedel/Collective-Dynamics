#!/bin/bash
# Monitor campaign completion and auto-analyze

CAMPAIGN_DIR="results/campaign_eccentricity_scan_20251116_014451"
TARGET=180

echo "========================================"
echo "  ESPERANDO COMPLETITUD DE CAMPAÑA"
echo "========================================"
echo

while true; do
    # Count completed runs
    n_files=$(ls $CAMPAIGN_DIR/*.h5 2>/dev/null | wc -l)

    # Get timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] Progreso: $n_files / $TARGET"

    if [ $n_files -eq $TARGET ]; then
        echo
        echo "========================================"
        echo "  ✅ CAMPAÑA COMPLETA!"
        echo "========================================"
        echo

        # Verify by eccentricity
        ./check_completion.sh

        echo
        echo "Iniciando análisis automático..."
        echo

        # Run analysis
        echo "1. Análisis estadístico completo..."
        julia --project=. analyze_full_campaign_final.jl

        echo
        echo "2. Generación de plots..."
        julia --project=. plot_campaign_final.jl

        echo
        echo "========================================"
        echo "  ✅ ANÁLISIS COMPLETADO"
        echo "========================================"

        break
    fi

    # Count processes
    n_procs=$(ps aux | grep -c "[r]un_single_eccentricity")
    echo "    Procesos activos: $n_procs"

    # Check e=0.99 specifically
    n_e099=$(ls $CAMPAIGN_DIR/*e0.990*.h5 2>/dev/null | wc -l)
    echo "    e=0.99: $n_e099/20"

    echo

    # Wait before next check
    sleep 60
done
