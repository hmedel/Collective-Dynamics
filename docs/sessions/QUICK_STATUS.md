# ESTADO RÁPIDO - CAMPAÑA EN CURSO

**Fecha**: 2025-11-16 01:50 UTC  
**Status**: 🔄 CAMPAÑA EJECUTÁNDOSE

---

## TL;DR

```
✅ PILOTO: 9/9 completado - hipótesis CONFIRMADA
🔄 CAMPAÑA: 180 runs ejecutándose (ETA: ~6 horas)
📊 RESULTADOS: R aumenta con e (clustering confirmado)
```

## Verificación rápida

```bash
# Ver progreso
./monitor_campaign.sh

# O manual
ls results/campaign_eccentricity_scan_20251116_014451/*.h5 | wc -l
# Debe mostrar 180 cuando termine
```

## Cuando termine (180/180 completados)

```bash
# 1. Análisis rápido
julia --project=. analyze_full_campaign.jl

# 2. Verificar energía
julia --project=. verify_energy_conservation.jl

# 3. Generar plots
julia --project=. plot_campaign_results.jl
```

## Archivos importantes

- **Documento completo**: `CAMPAIGN_STATUS_RECOVERY.md`
- **Campaign dir**: `results/campaign_eccentricity_scan_20251116_014451/`
- **Monitor**: `./monitor_campaign.sh`
- **Parámetros**: `parameter_matrix_eccentricity_scan.csv`

## Resultados piloto (referencia)

| e    | R (clustering) | Ψ (order) | Interpretación |
|------|----------------|-----------|----------------|
| 0.00 | 0.86 ± 0.34   | 0.08 ± 0.04 | Sin clustering |
| 0.50 | 0.88 ± 0.09   | 0.08 ± 0.01 | Débil |
| 0.98 | 5.05 ± 2.00   | 0.39 ± 0.15 | **Fuerte** ✓ |

---

**Ver detalles completos en**: `CAMPAIGN_STATUS_RECOVERY.md`
