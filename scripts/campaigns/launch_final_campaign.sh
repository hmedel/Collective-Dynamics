#!/bin/bash
#
# launch_final_campaign.sh
#
# Lanza la campaña final de finite-size scaling con 240 runs
# usando GNU parallel para ejecución paralela en 24 cores.
#
# Configuración:
#   - N = [20, 40, 60, 80]
#   - e = [0.0, 0.3, 0.5, 0.7, 0.8, 0.9]
#   - Seeds = 1:10
#   - Total: 240 runs
#   - Geometría intrínseca + energy projection
#
# Tiempo estimado con 24 cores: ~70 minutos
#

set -e  # Exit on error

# ============================================================================
# Configuración
# ============================================================================

PARAMETER_FILE="parameter_matrix_final_campaign.csv"
CAMPAIGN_NAME="final_campaign_$(date +%Y%m%d_%H%M%S)"
CAMPAIGN_DIR="results/$CAMPAIGN_NAME"
RUN_SCRIPT="run_single_final_campaign.jl"

N_CORES=24  # Ajustar según CPU disponible

# ============================================================================
# Verificaciones previas
# ============================================================================

echo "========================================================================"
echo "CAMPAÑA FINAL - FINITE-SIZE SCALING"
echo "========================================================================"
echo

# Verificar que existe el archivo de parámetros
if [ ! -f "$PARAMETER_FILE" ]; then
    echo "❌ ERROR: No se encontró $PARAMETER_FILE"
    echo "   Ejecuta primero: julia --project=. generate_final_campaign_matrix.jl"
    exit 1
fi

# Verificar que existe el script de ejecución
if [ ! -f "$RUN_SCRIPT" ]; then
    echo "❌ ERROR: No se encontró $RUN_SCRIPT"
    exit 1
fi

# Verificar GNU parallel
if ! command -v parallel &> /dev/null; then
    echo "❌ ERROR: GNU parallel no está instalado"
    echo "   Instalar con: sudo pacman -S parallel (Arch)"
    exit 1
fi

# Verificar Julia
if ! command -v julia &> /dev/null; then
    echo "❌ ERROR: Julia no está instalado"
    exit 1
fi

echo "✅ Verificaciones completadas"
echo

# ============================================================================
# Crear directorio de campaña
# ============================================================================

mkdir -p "$CAMPAIGN_DIR"

echo "Directorio de campaña: $CAMPAIGN_DIR"
echo

# Copiar archivos de configuración
cp "$PARAMETER_FILE" "$CAMPAIGN_DIR/"
cp "$RUN_SCRIPT" "$CAMPAIGN_DIR/"

# ============================================================================
# Resumen de configuración
# ============================================================================

TOTAL_RUNS=$(tail -n +2 "$PARAMETER_FILE" | wc -l)

echo "Configuración de la Campaña:"
echo "  Matriz de parámetros: $PARAMETER_FILE"
echo "  Total de runs:        $TOTAL_RUNS"
echo "  Cores paralelos:      $N_CORES"
echo "  Geometría:            Intrínseca (arc-length)"
echo "  Energy projection:    Activado (interval=10)"
echo

# Confirmar con usuario
echo "⚠️  Esta campaña ejecutará $TOTAL_RUNS simulaciones"
echo "   Tiempo estimado: ~70 minutos con $N_CORES cores"
echo

read -p "¿Continuar? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Campaña cancelada por el usuario"
    exit 0
fi

# ============================================================================
# Log de inicio
# ============================================================================

LOG_FILE="$CAMPAIGN_DIR/campaign.log"

{
    echo "========================================================================"
    echo "CAMPAÑA INICIADA"
    echo "========================================================================"
    echo "Fecha inicio:     $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Directorio:       $CAMPAIGN_DIR"
    echo "Total runs:       $TOTAL_RUNS"
    echo "Cores:            $N_CORES"
    echo "========================================================================"
    echo
} | tee "$LOG_FILE"

# ============================================================================
# Lanzar con GNU parallel
# ============================================================================

echo "Lanzando simulaciones con GNU parallel..."
echo "Logs en tiempo real en: $CAMPAIGN_DIR/joblog.txt"
echo

START_TIME=$(date +%s)

# Extraer run_ids desde CSV (columna 1, saltando header)
tail -n +2 "$PARAMETER_FILE" | cut -d',' -f1 | \
parallel -j "$N_CORES" \
         --joblog "$CAMPAIGN_DIR/joblog.txt" \
         --progress \
         --eta \
         julia --project=. "$RUN_SCRIPT" {} "$CAMPAIGN_DIR"

PARALLEL_EXIT=$?
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
ELAPSED_MIN=$((ELAPSED / 60))

# ============================================================================
# Análisis de resultados
# ============================================================================

echo
echo "========================================================================"
echo "CAMPAÑA COMPLETADA"
echo "========================================================================"

# Contar éxitos y fallos
SUCCESS_COUNT=$(grep -c "DONE:" "$CAMPAIGN_DIR"/*/run.log 2>/dev/null || echo 0)
ERROR_COUNT=$(grep -c "ERROR:" "$CAMPAIGN_DIR"/*/run.log 2>/dev/null || echo 0)

{
    echo
    echo "========================================================================"
    echo "RESUMEN FINAL"
    echo "========================================================================"
    echo "Fecha fin:        $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Tiempo total:     ${ELAPSED_MIN} minutos ($ELAPSED segundos)"
    echo "Runs exitosos:    $SUCCESS_COUNT / $TOTAL_RUNS"
    echo "Runs con error:   $ERROR_COUNT"
    echo
} | tee -a "$LOG_FILE"

# ============================================================================
# Verificar conservación de energía
# ============================================================================

echo "Verificando conservación de energía..." | tee -a "$LOG_FILE"
echo | tee -a "$LOG_FILE"

# Extraer ΔE/E₀ de todos los runs exitosos
CONSERVATION_FILE="$CAMPAIGN_DIR/conservation_summary.txt"

{
    echo "========================================================================"
    echo "CONSERVACIÓN DE ENERGÍA - RESUMEN"
    echo "========================================================================"
    echo
    printf "%-10s %-5s %-6s %-8s %-15s %-8s\n" "run_id" "N" "e" "seed" "ΔE/E₀" "status"
    echo "------------------------------------------------------------------------"
} > "$CONSERVATION_FILE"

# Leer conservación de cada summary.json
find "$CAMPAIGN_DIR" -name "summary.json" | while read json_file; do
    run_id=$(jq -r '.run_id' "$json_file")
    N=$(jq -r '.N' "$json_file")
    e=$(jq -r '.eccentricity' "$json_file")
    seed=$(jq -r '.seed' "$json_file")
    delta_E=$(jq -r '.ΔE_rel_max' "$json_file")

    # Clasificar conservación
    if (( $(echo "$delta_E < 1e-5" | bc -l) )); then
        status="✅ EXCELENTE"
    elif (( $(echo "$delta_E < 1e-4" | bc -l) )); then
        status="✅ BUENO"
    elif (( $(echo "$delta_E < 1e-3" | bc -l) )); then
        status="⚠️  ACEPTABLE"
    else
        status="❌ POBRE"
    fi

    printf "%-10s %-5s %-6.2f %-8s %-15.3e %s\n" \
           "$run_id" "$N" "$e" "$seed" "$delta_E" "$status"
done | sort -t',' -k1 -n >> "$CONSERVATION_FILE"

{
    echo
    echo "Conservación guardada en: $CONSERVATION_FILE"
    echo
} | tee -a "$LOG_FILE"

# ============================================================================
# Estadísticas de tamaño
# ============================================================================

TOTAL_SIZE=$(du -sh "$CAMPAIGN_DIR" | cut -f1)

{
    echo "========================================================================"
    echo "ALMACENAMIENTO"
    echo "========================================================================"
    echo "Tamaño total:     $TOTAL_SIZE"
    echo "Directorio:       $CAMPAIGN_DIR"
    echo
} | tee -a "$LOG_FILE"

# ============================================================================
# Próximos pasos
# ============================================================================

{
    echo "========================================================================"
    echo "PRÓXIMOS PASOS"
    echo "========================================================================"
    echo
    echo "1. Revisar conservación:"
    echo "   cat $CAMPAIGN_DIR/conservation_summary.txt"
    echo
    echo "2. Analizar datos:"
    echo "   julia --project=. analyze_final_campaign.jl $CAMPAIGN_DIR"
    echo
    echo "3. Generar plots:"
    echo "   - Clustering dynamics: R(t), Ψ(t)"
    echo "   - Finite-size scaling: R_∞(e)"
    echo "   - Phase diagrams: (N, e) space"
    echo
    echo "========================================================================"
} | tee -a "$LOG_FILE"

# Exit code de parallel
if [ $PARALLEL_EXIT -eq 0 ]; then
    echo "✅ CAMPAÑA EXITOSA" | tee -a "$LOG_FILE"
    exit 0
else
    echo "⚠️  CAMPAÑA COMPLETADA CON ERRORES (revisar logs)" | tee -a "$LOG_FILE"
    exit 1
fi
