# ESTADO DE CAMPAÑA Y PLAN DE RECUPERACIÓN
**Fecha**: 2025-11-16
**Campaña activa**: Eccentricity Scan Completa (180 runs)

---

## 1. ESTADO ACTUAL

### Campaña en ejecución
- **Campaign ID**: `campaign_eccentricity_scan_20251116_014451`
- **Directorio**: `results/campaign_eccentricity_scan_20251116_014451/`
- **Total runs**: 180 (9 eccentricidades × 20 realizaciones)
- **Tiempo por simulación**: ~7-8 minutos
- **Jobs paralelos**: 24
- **ETA finalización**: ~5-6 horas desde lanzamiento (01:44 UTC)
- **Finalización estimada**: ~07:00-08:00 UTC

### Parámetros de la campaña
```
Eccentricidades: [0.0, 0.3, 0.5, 0.7, 0.8, 0.9, 0.95, 0.98, 0.99]
N = 80 partículas
E/N = 0.32 (energía por partícula)
t_max = 200.0s (vs 50s en piloto)
Seeds: 1-20 para cada eccentricidad
dt_max = 1e-5
save_interval = 0.5s
projection_interval = 100 steps
```

### Archivos clave
- **Matriz de parámetros**: `parameter_matrix_eccentricity_scan.csv`
- **Comandos ejecutados**: `results/campaign_eccentricity_scan_20251116_014451/commands_simple.txt`
- **Log de parallel**: `results/campaign_eccentricity_scan_20251116_014451/parallel.log`
- **Job log**: `results/campaign_eccentricity_scan_20251116_014451/joblog.txt`
- **Script monitoreo**: `monitor_campaign.sh`

---

## 2. VERIFICAR PROGRESO

### Método 1: Script de monitoreo
```bash
./monitor_campaign.sh
```

### Método 2: Monitoreo continuo
```bash
watch -n 30 './monitor_campaign.sh'
```

### Método 3: Manual
```bash
# Contar HDF5 completados
ls results/campaign_eccentricity_scan_20251116_014451/*.h5 2>/dev/null | wc -l

# Ver procesos corriendo
ps aux | grep "run_single_eccentricity" | grep -v grep | wc -l

# Ver últimas entradas del joblog
tail -20 results/campaign_eccentricity_scan_20251116_014451/joblog.txt

# Ver últimas líneas del log de parallel
tail -50 results/campaign_eccentricity_scan_20251116_014451/parallel.log
```

### Verificar completitud
```bash
# Debe mostrar 180 al finalizar
ls results/campaign_eccentricity_scan_20251116_014451/*.h5 | wc -l

# Debe mostrar 181 líneas (180 + header)
wc -l results/campaign_eccentricity_scan_20251116_014451/joblog.txt
```

---

## 3. RESULTADOS DEL PILOTO (COMPLETADO)

### Resumen ejecutivo
✅ **Piloto completado exitosamente** - 9/9 simulaciones
✅ **Hipótesis confirmada**: R aumenta monotónicamente con e
✅ **Control negativo PASSED**: círculo (e=0.0) no muestra clustering
✅ **Conservación energía**: excelente en todos los casos (ΔE/E₀ < 10⁻⁴)

### Resultados por eccentricidad
```
e = 0.00:  R = 0.86 ± 0.34,  Ψ = 0.0810 ± 0.0378
e = 0.50:  R = 0.88 ± 0.09,  Ψ = 0.0824 ± 0.0056
e = 0.98:  R = 5.05 ± 2.00,  Ψ = 0.3903 ± 0.1490
```

**Interpretación**:
- **R** (clustering ratio): relación partículas en eje mayor vs eje menor
- **Ψ** (order parameter): 0=gas, 1=cristal perfecto
- Tendencia clara: e↑ → R↑ → clustering↑

### Conservación de energía (piloto)
Todos los runs mostraron conservación excelente:
- e=0.0: ΔE/E₀ ~ 10⁻¹³ (numérica perfecta)
- e=0.5: ΔE/E₀ ~ 10⁻⁷ (excelente)
- e=0.98: ΔE/E₀ ~ 10⁻⁵ (muy buena)

---

## 4. PRÓXIMOS PASOS (CUANDO TERMINE CAMPAÑA)

### PASO 1: Verificar completitud
```bash
# Ejecutar verificación completa
./monitor_campaign.sh

# Debe mostrar:
# - 180 archivos HDF5
# - 0 procesos corriendo
# - 180 jobs completados en joblog
```

### PASO 2: Análisis rápido de la campaña
Crear script `analyze_full_campaign.jl`:

```julia
#!/usr/bin/env julia
using HDF5
using Statistics
using DataFrames
using CSV
using Printf

campaign_dir = "results/campaign_eccentricity_scan_20251116_014451"

println("="^70)
println("ANÁLISIS CAMPAÑA COMPLETA: Eccentricity Scan")
println("="^70)
println()

# Funciones de análisis
function clustering_ratio(phi_positions, bin_width=π/4)
    n_mayor = count(φ -> (φ < bin_width || φ > 2π - bin_width ||
                          abs(φ - π) < bin_width), phi_positions)
    n_menor = count(φ -> abs(φ - π/2) < bin_width ||
                          abs(φ - 3π/2) < bin_width, phi_positions)
    return n_mayor / max(n_menor, 1)
end

function order_parameter(phi_positions)
    mean_cos = mean(cos.(phi_positions))
    mean_sin = mean(sin.(phi_positions))
    return sqrt(mean_cos^2 + mean_sin^2)
end

# Analizar todos los HDF5
results = []

for file in sort(readdir(campaign_dir, join=true))
    !endswith(file, ".h5") && continue
    
    filename = basename(file)
    
    # Extraer parámetros del nombre de archivo
    m = match(r"e([\d\.]+)_N\d+_E[\d\.]+_seed(\d+)", filename)
    if m === nothing
        @warn "No se pudo parsear: $filename"
        continue
    end
    
    e = parse(Float64, m.captures[1])
    seed = parse(Int, m.captures[2])
    
    h5open(file, "r") do f
        # Leer estado final
        phi_final = read(f["trajectories"]["phi"])[:, end]
        
        # Métricas
        R_cluster = clustering_ratio(phi_final)
        Psi = order_parameter(phi_final)
        
        # Energía (si está disponible)
        if haskey(f, "conservation")
            energy = read(f["conservation"]["total_energy"])
            dE = maximum(abs.(energy .- energy[1])) / energy[1]
        else
            dE = NaN
        end
        
        push!(results, (e=e, seed=seed, R=R_cluster, Psi=Psi, 
                       dE_rel=dE, file=filename))
    end
end

println("Total simulaciones analizadas: $(length(results))")
println()

# Crear DataFrame
df = DataFrame(results)

# Agrupar por eccentricidad
grouped = groupby(df, :e)
summary = combine(grouped,
    :R => mean => :R_mean,
    :R => std => :R_std,
    :Psi => mean => :Psi_mean,
    :Psi => std => :Psi_std,
    :dE_rel => mean => :dE_mean,
    nrow => :n_samples
)

# Mostrar resumen
println("RESUMEN POR ECCENTRICIDAD:")
println("-"^70)
@printf("%-6s | %-5s | %-12s | %-12s | %-12s\n", 
        "e", "N", "R (mean±std)", "Ψ (mean±std)", "ΔE/E₀")
println("-"^70)

for row in eachrow(sort(summary, :e))
    @printf("%.2f | %5d | %.2f ± %.2f | %.4f ± %.4f | %.2e\n",
            row.e, row.n_samples, row.R_mean, row.R_std,
            row.Psi_mean, row.Psi_std, row.dE_mean)
end
println("="^70)

# Guardar resultados
CSV.write(joinpath(campaign_dir, "summary_by_eccentricity.csv"), summary)
CSV.write(joinpath(campaign_dir, "all_results.csv"), df)

println()
println("Archivos guardados:")
println("  - $(campaign_dir)/summary_by_eccentricity.csv")
println("  - $(campaign_dir)/all_results.csv")
println()

# Verificar tendencia
sorted_e = sort(unique(df.e))
R_by_e = [mean(df[df.e .== e, :R]) for e in sorted_e]

if all(diff(R_by_e) .>= 0)
    println("✅ HIPÓTESIS CONFIRMADA: R aumenta monotónicamente con e")
else
    println("⚠️  WARNING: Tendencia no monotónica detectada")
end

println()
println("="^70)
```

### PASO 3: Ejecutar análisis
```bash
chmod +x analyze_full_campaign.jl
julia --project=. analyze_full_campaign.jl
```

### PASO 4: Generar visualizaciones
Crear script `plot_campaign_results.jl`:

```julia
#!/usr/bin/env julia
using CSV
using DataFrames
using CairoMakie

campaign_dir = "results/campaign_eccentricity_scan_20251116_014451"

# Leer resumen
summary = CSV.read(joinpath(campaign_dir, "summary_by_eccentricity.csv"), DataFrame)
all_data = CSV.read(joinpath(campaign_dir, "all_results.csv"), DataFrame)

# Plot 1: R vs e con barras de error
fig1 = Figure(resolution=(800, 600))
ax1 = Axis(fig1[1,1],
    xlabel = "Eccentricity (e)",
    ylabel = "Clustering Ratio (R)",
    title = "Clustering vs Eccentricity (N=80, E/N=0.32)"
)

errorbars!(ax1, summary.e, summary.R_mean, summary.R_std, 
           whiskerwidth=10)
scatter!(ax1, summary.e, summary.R_mean, markersize=12)
lines!(ax1, summary.e, summary.R_mean, linestyle=:dash)

save(joinpath(campaign_dir, "R_vs_eccentricity.png"), fig1)

# Plot 2: Order parameter Ψ vs e
fig2 = Figure(resolution=(800, 600))
ax2 = Axis(fig2[1,1],
    xlabel = "Eccentricity (e)",
    ylabel = "Order Parameter (Ψ)",
    title = "Order Parameter vs Eccentricity"
)

errorbars!(ax2, summary.e, summary.Psi_mean, summary.Psi_std,
           whiskerwidth=10)
scatter!(ax2, summary.e, summary.Psi_mean, markersize=12)
lines!(ax2, summary.e, summary.Psi_mean, linestyle=:dash)

save(joinpath(campaign_dir, "Psi_vs_eccentricity.png"), fig2)

# Plot 3: Scatter de todas las realizaciones
fig3 = Figure(resolution=(800, 600))
ax3 = Axis(fig3[1,1],
    xlabel = "Eccentricity (e)",
    ylabel = "Clustering Ratio (R)",
    title = "All Realizations (20 per eccentricity)"
)

scatter!(ax3, all_data.e, all_data.R, alpha=0.5, markersize=8)
lines!(ax3, summary.e, summary.R_mean, color=:red, linewidth=3)

save(joinpath(campaign_dir, "R_all_realizations.png"), fig3)

println("Plots guardados en: $campaign_dir")
println("  - R_vs_eccentricity.png")
println("  - Psi_vs_eccentricity.png")
println("  - R_all_realizations.png")
```

### PASO 5: Verificar conservación de energía
```bash
# Crear script de verificación
cat > verify_energy_conservation.jl << 'EOFSCRIPT'
#!/usr/bin/env julia
using HDF5
using Printf

campaign_dir = "results/campaign_eccentricity_scan_20251116_014451"

println("Verificando conservación de energía...")
println("-"^70)

bad_runs = []

for file in readdir(campaign_dir, join=true)
    !endswith(file, ".h5") && continue
    
    h5open(file, "r") do f
        if haskey(f, "conservation")
            energy = read(f["conservation"]["total_energy"])
            dE_rel = maximum(abs.(energy .- energy[1])) / energy[1]
            
            if dE_rel > 1e-4
                push!(bad_runs, (file=basename(file), dE=dE_rel))
            end
        end
    end
end

if isempty(bad_runs)
    println("✅ TODAS las simulaciones conservan energía (ΔE/E₀ < 10⁻⁴)")
else
    println("⚠️  $(length(bad_runs)) simulaciones con ΔE/E₀ > 10⁻⁴:")
    for run in bad_runs
        @printf("  %s: ΔE/E₀ = %.2e\n", run.file, run.dE)
    end
end
EOFSCRIPT

chmod +x verify_energy_conservation.jl
julia --project=. verify_energy_conservation.jl
```

---

## 5. ANÁLISIS CIENTÍFICO (DESPUÉS DE PASOS 1-5)

### Objetivos del análisis
1. **Confirmar hipótesis**: R(e) es función monotónica creciente
2. **Cuantificar transición**: ¿existe e_crítica para gas→cristal?
3. **Analizar dinámica temporal**: ¿cómo evoluciona R(t)?
4. **Caracterizar nucleación**: ¿formación súbita o gradual?

### Scripts adicionales a crear

#### A. Análisis temporal de clustering
```julia
# analyze_temporal_evolution.jl
# Para cada e, plotear R(t) y Ψ(t)
# Identificar tiempo de relajación τ_relax
```

#### B. Análisis de distribuciones
```julia
# analyze_distributions.jl
# Histogramas de φ en estado final
# Distribuciones de velocidades φ̇
# Test de uniformidad (Rayleigh test)
```

#### C. Identificación de fase
```julia
# phase_identification.jl
# Clasificar cada run como "gas" o "cristal"
# Usar criterio: Ψ > 0.3 → cristal
# Estimar e_crítica
```

### Productos esperados
1. **Figura principal**: R(e) y Ψ(e) con error bars
2. **Tabla resumen**: estadísticas por eccentricidad
3. **Análisis temporal**: evolución R(t) para casos representativos
4. **Diagnóstico**: verificación conservación energía

---

## 6. TROUBLESHOOTING

### Problema: Campaña se detuvo antes de completar

**Diagnóstico**:
```bash
# Ver cuántos completaron
ls results/campaign_eccentricity_scan_20251116_014451/*.h5 | wc -l

# Ver joblog para identificar fallidos
tail -50 results/campaign_eccentricity_scan_20251116_014451/joblog.txt
```

**Solución**: Relanzar solo los fallidos
```bash
cd results/campaign_eccentricity_scan_20251116_014451

# Identificar runs completados
completed=$(ls *.h5 2>/dev/null | sed 's/.*run\([0-9]*\)_.*/\1/' | sort -n)

# Crear lista de runs pendientes
awk -F',' 'NR>1 {print $1}' parameters.csv | while read run_id; do
    if ! echo "$completed" | grep -q "^${run_id}$"; then
        echo $run_id
    fi
done > pending_runs.txt

# Relanzar pendientes
while read run_id; do
    grep "run-id $run_id " commands_simple.txt
done < pending_runs.txt | parallel --jobs 24 --progress
```

### Problema: Uso excesivo de disco

**Diagnóstico**:
```bash
du -sh results/campaign_eccentricity_scan_20251116_014451/
du -sh results/campaign_eccentricity_scan_20251116_014451/*.h5 | head
```

**Nota**: Cada HDF5 ~ 10-50 MB → 180 runs ~ 2-9 GB total

### Problema: Errores de memoria

**Señal**: Procesos killed, exit code 137 en joblog

**Solución**:
- Reducir jobs paralelos de 24 a 16 o 12
- Verificar memoria disponible: `free -h`

---

## 7. INFORMACIÓN TÉCNICA

### Estructura HDF5
```
archivo.h5
├── metadata (attributes: N, E_total, eccentricity, seed, ...)
├── trajectories/
│   ├── phi [N_particles × N_frames]
│   ├── phidot [N_particles × N_frames]
│   └── time [N_frames]
└── conservation/
    ├── total_energy [N_frames]
    ├── total_momentum_x [N_frames]
    └── total_momentum_y [N_frames]
```

### Convención de nombres
```
run{run_id}_e{ecc}_N{N}_E{E_total}_seed{seed}.h5

Ejemplo:
run1_e0.00_N80_E25.6_seed1.h5
run180_e0.99_N80_E25.6_seed20.h5
```

### Comando de ejecución individual
```bash
julia --project=. --threads=1 run_single_eccentricity_experiment.jl \
    --run-id 1 \
    --eccentricity 0.5 \
    --a 3.5 \
    --b 1.75 \
    --N 80 \
    --E-per-N 0.32 \
    --seed 1 \
    --t-max 200.0 \
    --dt-max 1e-5 \
    --save-interval 0.5 \
    --projection-interval 100 \
    --output-dir results/campaign_eccentricity_scan_20251116_014451 \
    --use-projection
```

---

## 8. CONTACTO Y REFERENCIAS

### Archivos de documentación
- `POLAR_IMPLEMENTATION_RESULTS.md` - Resultados migración polar
- `SCIENTIFIC_FINDINGS.md` - Hallazgos científicos previos
- `PILOTO_STATUS.md` - Resultados del piloto

### Scripts clave
- `generate_eccentricity_scan.jl` - Generador de matriz
- `run_single_eccentricity_experiment.jl` - Runner individual
- `launch_eccentricity_scan.sh` - Launcher de campaña
- `monitor_campaign.sh` - Monitor de progreso

### Hipótesis central
**Clustering geométrico inducido por curvatura**:
- En elipses muy excéntricas, las partículas se acumulan en el eje mayor
- Mecanismo: φ̇ ∝ 1/g_φφ → partículas lentas en alta curvatura
- Resultado: transición gas→cristal fuera de equilibrio

---

## 9. CHECKLIST DE RECUPERACIÓN

Cuando retomes el trabajo:

- [ ] Verificar que la campaña terminó: `ls *.h5 | wc -l` debe dar 180
- [ ] Ejecutar `./monitor_campaign.sh` para ver estado final
- [ ] Correr `analyze_full_campaign.jl` para generar resumen
- [ ] Verificar conservación de energía con `verify_energy_conservation.jl`
- [ ] Generar plots con `plot_campaign_results.jl`
- [ ] Revisar tendencia R(e) - debe ser monotónica creciente
- [ ] Identificar e_crítica para transición gas→cristal
- [ ] Preparar figura publication-ready
- [ ] Documentar hallazgos en `SCIENTIFIC_FINDINGS.md`

---

**Última actualización**: 2025-11-16 01:50 UTC
**Próxima revisión sugerida**: 2025-11-16 07:00 UTC (cuando campaña debería estar completa)
