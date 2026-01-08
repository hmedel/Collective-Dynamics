"""
    generate_final_campaign_matrix.jl

Genera la matriz de parámetros final para la campaña de finite-size scaling
con geometría intrínseca corregida y energy projection activado.

Configuración Final (post-optimización):
- N = [20, 40, 60, 80]  (onset → saturación)
- e = [0.0, 0.3, 0.5, 0.7, 0.8, 0.9]  (removidos e≥0.95)
- Seeds = 1:10
- Total: 4 × 6 × 10 = 240 runs

Parámetros de simulación:
- t_max = 120.0s (2× tiempo de relajación)
- dt_max = adaptativo según e (5e-5 para e≥0.8, 1e-4 para e<0.8)
- save_interval = 0.5s
- use_projection = true (projection_interval adaptativo)
- Tamaño de partícula: FIJO (100 partículas cubrirían la curva completamente)
"""

using Pkg
Pkg.activate(".")

using CSV
using DataFrames
using Printf
using Statistics

# Cargar funciones de geometría para calcular radios
include("src/geometry/metrics_polar.jl")

println("="^80)
println("GENERACIÓN DE MATRIZ DE PARÁMETROS - CAMPAÑA FINAL")
println("="^80)
println()

# ============================================================================
# Parámetros de la campaña
# ============================================================================

N_values = [20, 40, 60, 80]
e_values = [0.0, 0.3, 0.5, 0.7, 0.8, 0.9]
seeds = 1:10

# Tamaño de partícula FIJO
max_particles = 150  # Número de partículas que cubrirían completamente la curva

A_ellipse = 2.0  # Área normalizada

# Parámetros de simulación
t_max = 120.0
save_interval = 0.5
use_projection = true
projection_tolerance = 1e-12

# dt_max y projection_interval son adaptativos (se configuran en run_single_final_campaign.jl)

println("Parámetros del Grid:")
@printf("  N:              %s\n", join(N_values, ", "))
@printf("  e:              %s\n", join([@sprintf("%.2f", e) for e in e_values], ", "))
@printf("  Seeds:          1:%d\n", maximum(seeds))
@printf("  Total runs:     %d × %d × %d = %d\n",
    length(N_values), length(e_values), length(seeds),
    length(N_values) * length(e_values) * length(seeds))
println()

println("Parámetros de Simulación:")
@printf("  t_max:                 %.1f s\n", t_max)
@printf("  dt_max:                adaptativo (5e-5 para e≥0.8, 1e-4 para e<0.8)\n")
@printf("  save_interval:         %.1f s\n", save_interval)
@printf("  use_projection:        %s\n", use_projection)
@printf("  projection_interval:   adaptativo (5 para e≥0.8, 10 para 0.5≤e<0.8, 20 para e<0.5)\n")
@printf("  max_particles:         %d (tamaño de partícula FIJO)\n", max_particles)
println()

# ============================================================================
# Función auxiliar: calcular semi-ejes desde excentricidad
# ============================================================================

function calculate_semiaxes(e::Float64, A::Float64)
    if e >= 1.0
        error("Excentricidad debe ser e < 1.0")
    end
    b = sqrt(A * (1 - e^2) / π)
    a = A / (π * b)
    return (a, b)
end

# ============================================================================
# Generar matriz de parámetros
# ============================================================================

println("Generando matriz de parámetros...")
println()

results = []

# Generate all parameter combinations
for (idx, (N, e, seed)) in enumerate(Iterators.product(N_values, e_values, seeds))
    # Calcular semi-ejes
    a, b = calculate_semiaxes(e, A_ellipse)

    # Radio FIJO (independiente de N)
    # Tamaño tal que max_particles partículas cubrirían completamente la curva
    r = radius_from_max_particles(a, b; max_particles=max_particles)

    # Perímetro
    P = ellipse_perimeter(a, b; method=:ramanujan)

    # Packing fraction intrínseco (depende de N con radio fijo)
    φ_intrinsic = intrinsic_packing_fraction(N, r, a, b)

    push!(results, (
        run_id = idx,
        N = N,
        eccentricity = e,
        seed = seed,
        a = a,
        b = b,
        radius = r,
        perimeter = P,
        phi_intrinsic = φ_intrinsic,
        t_max = t_max,
        save_interval = save_interval,
        use_projection = use_projection,
        mass = 1.0,
        max_speed = 1.0
    ))
end

df = DataFrame(results)

println("Matriz generada: $(nrow(df)) runs")
println()

# ============================================================================
# Estadísticas de la matriz
# ============================================================================

println("="^80)
println("ESTADÍSTICAS DE LA MATRIZ")
println("="^80)
println()

# Radios (FIJOS para cada e, varían solo con geometría)
r_unique = unique(df.radius)
println("Radios intrínsecos (FIJOS por eccentricity):")
@printf("  Valores únicos: %d (uno por cada e)\n", length(r_unique))
@printf("  Mínimo:   %.5f (e=%.2f)\n",
    minimum(r_unique),
    df[argmin(df.radius), :eccentricity])
@printf("  Máximo:   %.5f (e=%.2f)\n",
    maximum(r_unique),
    df[argmax(df.radius), :eccentricity])
@printf("  Rango:    %.2fx\n", maximum(r_unique) / minimum(r_unique))
println()

# Packing fractions (VARÍAN con N para radio fijo)
println("Packing fractions (VARÍAN con N, radio FIJO):")
@printf("  Mínimo:   %.4f (N=%d)\n", minimum(df.phi_intrinsic), df[argmin(df.phi_intrinsic), :N])
@printf("  Máximo:   %.4f (N=%d)\n", maximum(df.phi_intrinsic), df[argmax(df.phi_intrinsic), :N])
@printf("  max_particles = %d → φ_max ≈ %.2f para N=%d\n",
    max_particles, maximum(df.phi_intrinsic), df[argmax(df.phi_intrinsic), :N])
println()

# Runs por categoría
println("Distribución de runs:")
for N in N_values
    count = nrow(filter(row -> row.N == N, df))
    @printf("  N=%3d:  %3d runs\n", N, count)
end
println()

for e in e_values
    count = nrow(filter(row -> row.eccentricity == e, df))
    @printf("  e=%.2f:  %3d runs\n", e, count)
end
println()

# ============================================================================
# Exportar matriz
# ============================================================================

output_file = "parameter_matrix_final_campaign.csv"
CSV.write(output_file, df)

println("="^80)
println("MATRIZ GUARDADA")
println("="^80)
println()
println("Archivo: $output_file")
println("Formato: CSV")
println("Columnas:")
for col in names(df)
    println("  - $col")
end
println()

# ============================================================================
# Caso de prueba: verificar un run específico
# ============================================================================

println("="^80)
println("EJEMPLO DE RUN")
println("="^80)
println()

# Caso más crítico: N=80, e=0.9
example = first(filter(row -> row.N == 80 && row.eccentricity == 0.9 && row.seed == 1, df))

println("Run crítico: N=80, e=0.9, seed=1")
@printf("  run_id:              %d\n", example.run_id)
@printf("  Semi-ejes (a, b):    (%.4f, %.4f)\n", example.a, example.b)
@printf("  Radio FIJO:          %.5f (max_particles=%d)\n", example.radius, max_particles)
@printf("  Perímetro:           %.4f\n", example.perimeter)
@printf("  φ_intrinsic:         %.4f (alta densidad con N=80)\n", example.phi_intrinsic)
@printf("  use_projection:      %s\n", example.use_projection)
@printf("  dt_max:              5e-5 (adaptativo para e≥0.8)\n")
@printf("  projection_interval: 5 (adaptativo para e≥0.8)\n")
println()

# Estimación de colisiones
# Para N=80, e=0.9, r=0.014: ~1200 colisiones/s (estimado)
est_collisions = 1200 * t_max
@printf("  Colisiones estimadas: ~%d en %.0fs\n", est_collisions, t_max)
@printf("  Conservación esperada con projection: ΔE/E₀ < 2×10⁻⁵\n")
println()

# ============================================================================
# Resumen final
# ============================================================================

println("="^80)
println("RESUMEN DE CAMPAÑA")
println("="^80)
println()

@printf("Total de runs:         %d\n", nrow(df))
@printf("Tiempo por run:        ~5-10 min (estimado)\n")
@printf("Tiempo total (serial): ~%d hrs\n", div(nrow(df) * 7, 60))
@printf("Tiempo con 24 cores:   ~%d min\n", div(nrow(df) * 7, 24))
println()

snapshots_per_run = Int(t_max / save_interval) + 1
@printf("Snapshots por run:     %d\n", snapshots_per_run)
@printf("Tamaño por run:        ~5-6 MB\n")
@printf("Tamaño total (est):    ~%.1f GB\n", nrow(df) * 5.5 / 1024)
println()

println("Análisis post-campaña:")
println("  1. Clustering dynamics: R(t), Ψ(t), τ(N,e)")
println("  2. Finite-size scaling: R_∞(e), exponentes críticos")
println("  3. Phase diagrams: (N, e) space")
println("  4. Conservation verification: ΔE/E₀ < 2×10⁻⁵ para todos")
println()

println("="^80)
println("✅ MATRIZ LISTA PARA CAMPAÑA")
println("="^80)
println()
println("Próximo paso:")
println("  julia --project=. launch_final_campaign.jl")
println()
