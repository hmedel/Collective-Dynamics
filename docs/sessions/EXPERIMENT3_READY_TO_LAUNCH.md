# Experimento 3: Condiciones Iniciales Uniformes - LISTO PARA LANZAR

**Fecha:** 2025-11-18
**Status:** ✅ TODO PREPARADO

---

## Resumen Ejecutivo

Basándonos en el análisis temporal que mostró:
- 48% de runs aún creciendo en t=200s
- Necesidad de t_max = 500s
- Divergencia desde t=0 (sugiere sensibilidad a ICs)

**Hemos preparado Experimento 3 con ICs UNIFORMES** para ver emergencia pura de clustering.

---

## Parámetros del Experimento

### Configuración
```
Eccentricidades: [0.7, 0.9]
Realizaciones:   20 por cada e
Total runs:      40
N partículas:    80
E/N:             0.32
t_max:           500s (2.5× campaña actual)
save_interval:   1.0s (análisis temporal fino)
```

### Condiciones Iniciales UNIFORMES

**Posiciones:**
- φ equiespaciados: φᵢ = 2πi/N, i=1...80
- Distribución perfectamente uniforme en [0, 2π]

**Velocidades:**
- Distribución térmica (Gaussiana)
- Energía total = N × E/N
- Seed diferente para cada realización
- ⇒ **SOLO las velocidades varían entre runs**

### Comparación con Campaña Actual

| Parámetro | Campaña Actual | Experimento 3 |
|-----------|----------------|---------------|
| ICs posiciones | Random | **Uniformes** |
| ICs velocidades | Térmicas | Térmicas (mismo) |
| t_max | 200s | **500s** |
| save_interval | 0.5s | **1.0s** |
| Objetivo | Tendencia R(e) | **Emergencia pura** |

---

## Preguntas Científicas

### 1. ¿Emerge clustering desde uniformidad?

**Hipótesis:** Sí, clustering es resultado de dinámica, no de ICs

**Verificación:**
- Si R(t=0) = 1.0 (uniforme)
- Y R(t=500s) > 1.5 (clustering)
- ⇒ Clustering emergente confirmado

### 2. ¿Misma evolución temporal con ICs uniformes?

**Comparación:**
- ICs random (campaña): divergencia desde t=0
- ICs uniformes (Exp 3): divergencia esperada en t > 0

**Análisis:**
- Graficar R(t) para ambos casos
- Identificar tiempo de divergencia
- Ver si estado final es el mismo

### 3. ¿Reduce bimodalidad?

**Hipótesis:** Bimodalidad en e=0.7, 0.8 es por ICs random

**Test:**
- Si ICs uniformes → distribución más estrecha de R_final
- ⇒ Bimodalidad era artefacto
- Si ICs uniformes → bimodalidad persiste
- ⇒ Bimodalidad es física (múltiples atractores)

### 4. ¿Coalescen clusters en t=500s?

**Objetivo principal:**
- Ver si N_clusters decrece con tiempo
- Determinar si t=500s es suficiente para equilibrio

---

## Archivos Preparados

### Scripts de Generación
```
✓ generate_uniform_ICs_campaign.jl    - Genera matriz de parámetros
✓ parameter_matrix_uniform_ICs_experiment.csv  - 40 runs configurados
```

### Script de Simulación
```
✓ run_uniform_ICs_experiment.jl       - Simulación con ICs uniformes
  - Genera φ equiespaciados
  - Velocidades térmicas con seed
  - Guarda flag "UNIFORM" en HDF5
```

### Script de Lanzamiento
```
✓ launch_uniform_ICs_experiment.sh    - Launcher con GNU parallel
  - 24 jobs paralelos
  - Background execution
  - Monitoreo automatizado
```

### Análisis (en progreso)
```
🏃 plot_phase_space_unwrapped.jl      - Espacio fase (φ, φ̇) unwrapped
  - Todas las trayectorias en un plot
  - Colormap por tiempo
  - Estados inicial vs final
```

---

## Estimación de Tiempo

### Con 24 Cores

```
Tiempo por run: ~19 minutos
Total runs:     40
Paralelo (24):  40 × 19 / 24 = ~30 minutos
```

### ETA
```
Inicio:      Cuando lances
Finalización: +30 minutos
```

**Muy rápido!** (vs 15-20 horas de otros experimentos)

---

## Cómo Lanzar

### Paso 1: Verificar que campaña actual no esté usando todos los cores

```bash
ps aux | grep "julia.*run_single" | wc -l
```

Si muestra 24 → **ESPERAR** a que termine (monitorear con `./monitor_relaunch.sh`)

### Paso 2: Lanzar Experimento 3

```bash
chmod +x launch_uniform_ICs_experiment.sh
./launch_uniform_ICs_experiment.sh
```

El script pedirá confirmación antes de lanzar.

### Paso 3: Monitorear

```bash
# Ver progreso
watch -n 30 'ls results/experiment_uniform_ICs_*/\*.h5 2>/dev/null | wc -l'

# Ver log
tail -f results/experiment_uniform_ICs_*/parallel.log

# Ver joblog
tail results/experiment_uniform_ICs_*/joblog.txt
```

---

## Análisis Post-Simulación

### Inmediato (cuando termine)

```bash
# 1. Comparar R(t) uniform vs random ICs
julia --project=. compare_uniform_vs_random.jl  # (crear este script)

# 2. Análisis temporal detallado
julia --project=. analyze_temporal_evolution.jl  # (ya existe)

# 3. Espacio fase
julia --project=. plot_phase_space_unwrapped.jl  # (en ejecución)
```

### Comparaciones Clave

**Plot 1: R(t) Uniform vs Random**
- Mismo e, diferentes ICs
- Ver si convergen o divergen

**Plot 2: Distribución R_final**
- Histogramas lado a lado
- Test de bimodalidad

**Plot 3: Espacio Fase**
- Trayectorias desde uniformidad
- Ver formación de clusters

---

## Resultados Esperados

### Escenario A: Emergencia Limpia

```
t=0:    R = 1.0  (uniforme)
t=50s:  R ≈ 1.2  (clustering débil)
t=200s: R ≈ 1.5  (clustering moderado)
t=500s: R ≈ 2.0  (clustering fuerte, saturado)
```

**Interpretación:** Clustering emerge de dinámica pura

### Escenario B: No Equilibra

```
t=0:    R = 1.0
t=500s: R ≈ 1.3  (aún creciendo)
```

**Interpretación:** Necesita t_max >> 500s

### Escenario C: Múltiples Atractores

```
Algunos runs: R → 2.5
Otros runs:   R → 1.2
```

**Interpretación:** Bimodalidad persiste, múltiples estados finales

---

## Próximos Pasos (Después de Exp 3)

### Si Exp 3 muestra equilibración en 500s:

✅ **Lanzar Opción C** (estadística alta)
- 50-100 realizaciones
- e = [0.7, 0.9]
- t_max = 500s
- Caracterizar distribución completa

### Si Exp 3 NO equilibra en 500s:

✅ **Lanzar runs más largos**
- 10 runs × 1000s
- Ver si satura eventualmente
- Determinar τ_eq empíricamente

### Análisis Científico Final:

1. **Mecanismo de clustering:**
   - ¿Nucleación temprana o coalescencia lenta?
   - ¿Depende de ICs?

2. **Coexistencia de fases:**
   - ¿Bimodalidad real o artefacto?
   - ¿Transición de primer orden?

3. **Publicación:**
   - Figuras de emergencia temporal
   - Comparación ICs uniform vs random
   - Caracterización completa

---

## Estado de Otros Procesos

### Campaña Original (e=0.95, 0.98, 0.99)

```
Status:   🏃 60 runs ejecutándose
Progress: Verificar con ./monitor_relaunch.sh
ETA:      ~15-20 horas desde 18:11 UTC
```

**No interferirá** con Exp 3 si esperas a que termine.

### Análisis de Espacio Fase

```
Status:   🏃 Generando plots
Output:   phase_space_unwrapped_e*.png
          phase_space_multiple_runs_e*.png
ETA:      ~5-10 minutos (CairoMakie compilando)
```

---

## Decisión Recomendada

### Opción A: Lanzar Ahora (si campaña terminó)

```bash
# Verificar primero
ps aux | grep "julia.*run_single" | wc -l

# Si da 0, lanzar
./launch_uniform_ICs_experiment.sh
```

**Ventaja:** Resultados en 30 minutos

### Opción B: Esperar campaña + análisis

```bash
# Esperar a que campaña termine
# Analizar resultados de e=0.95, 0.98, 0.99
# LUEGO lanzar Exp 3 informadamente
```

**Ventaja:** Ver e=0.98 primero (esperamos R≈5)

---

## Archivos de Salida

### Directorio
```
results/experiment_uniform_ICs_YYYYMMDD_HHMMSS/
├── parameter_matrix_uniform_ICs_experiment.csv
├── run_uniform_ICs_experiment.jl
├── commands.txt
├── joblog.txt
├── parallel.log
└── run_*_e*_N80_E*_seed*_UNIFORM.h5  (40 archivos)
```

### Formato HDF5

**Metadata especial:**
```
attributes["initial_conditions"] = "UNIFORM"  # FLAG
```

Permite identificar fácilmente ICs uniformes vs random.

---

## Conclusión

**TODO LISTO PARA LANZAR** ✅

- Scripts verificados
- Matriz generada (40 runs)
- Tiempo estimado: 30 minutos
- Objetivos científicos claros

**Acción sugerida:**
1. Verificar estado de campaña actual
2. Esperar análisis de espacio fase (5 min)
3. Revisar plots generados
4. Lanzar Exp 3

---

**Autor:** Claude Code (claude-sonnet-4-5)
**Fecha:** 2025-11-18 19:12 UTC
**Status:** 🎯 READY TO LAUNCH
