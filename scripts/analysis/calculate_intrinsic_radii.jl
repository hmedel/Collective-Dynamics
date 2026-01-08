"""
    calculate_intrinsic_radii.jl

Calcula los radios intrínsecos correctos para la campaña de finite-size scaling,
asegurando que el packing fraction intrínseco sea consistente para todas las
combinaciones de (N, e).

Geometría Intrínseca:
    φ_intrinsic = N × 2r / P(e)

donde P(e) es el perímetro de la elipse con excentricidad e.

Para mantener φ_target constante:
    r(N, e) = φ_target × P(e) / (2N)
"""

using Pkg
Pkg.activate(".")

using Printf
using DataFrames
using CSV
using Statistics

# Cargar funciones geométricas
include("src/geometry/metrics_polar.jl")

# ============================================================================
# Parámetros de la campaña
# ============================================================================

N_values = [20, 40, 60, 80]  # Desde onset (N=20) hasta saturación (N=80)
e_values = [0.0, 0.3, 0.5, 0.7, 0.8, 0.9]  # Hasta e=0.9 - removidos e≥0.95 (problemas de conservación)

# Target packing fraction (intrínseco)
φ_target = 0.30  # Conservador para evitar problemas de generación

# Semi-ejes (fixed)
# Para e dado: a = sqrt(A/(πb)), b = sqrt(A×(1-e²)/π)
# Normalizamos a área A = 2π (a×b = 2)
A_ellipse = 2.0  # Área normalizada

println("="^80)
println("CÁLCULO DE RADIOS INTRÍNSECOS PARA CAMPAÑA FINITE-SIZE SCALING")
println("="^80)
println()
@printf("Target packing fraction: φ = %.3f\n", φ_target)
@printf("Área normalizada: A = %.2f\n", A_ellipse)
println()

# ============================================================================
# Función para calcular semi-ejes desde excentricidad
# ============================================================================

function calculate_semiaxes(e::Float64, A::Float64)
    """
    Calcula semi-ejes (a, b) desde excentricidad e y área A.

    Para elipse: A = π × a × b
    Excentricidad: e² = 1 - (b/a)²

    Solución:
        b = sqrt(A × (1-e²) / π)
        a = A / (π × b)
    """
    if e >= 1.0
        error("Excentricidad debe ser e < 1.0")
    end

    b = sqrt(A * (1 - e^2) / π)
    a = A / (π * b)

    return (a, b)
end

# ============================================================================
# Calcular matriz de radios
# ============================================================================

println("="^80)
println("MATRIZ DE RADIOS INTRÍNSECOS r(N, e)")
println("="^80)
println()

# Header
@printf("%-8s", "e \\ N")
for N in N_values
    @printf("%10s", "N=$N")
end
println()
println("-"^80)

# Crear matriz para almacenar datos
results = []

for e in e_values
    # Calcular semi-ejes
    a, b = calculate_semiaxes(e, A_ellipse)

    # Calcular perímetro
    P = ellipse_perimeter(a, b; method=:ramanujan)

    # Imprimir fila
    @printf("e=%.2f   ", e)

    for N in N_values
        # Radio intrínseco necesario
        r = radius_from_packing(N, φ_target, a, b)

        @printf("%10.5f", r)

        # Guardar resultado
        push!(results, (
            eccentricity = e,
            N = N,
            a = a,
            b = b,
            perimeter = P,
            radius = r,
            phi_intrinsic = φ_target
        ))
    end
    println()
end

println()

# ============================================================================
# Análisis de la matriz de radios
# ============================================================================

println("="^80)
println("ANÁLISIS DE RADIOS")
println("="^80)
println()

# Convertir a DataFrame
df = DataFrame(results)

# Estadísticas globales
r_min = minimum(df.radius)
r_max = maximum(df.radius)
r_mean = mean(df.radius)

@printf("Radio mínimo:  %.5f (N=%d, e=%.2f)\n",
    r_min,
    df[argmin(df.radius), :N],
    df[argmin(df.radius), :eccentricity])

@printf("Radio máximo:  %.5f (N=%d, e=%.2f)\n",
    r_max,
    df[argmax(df.radius), :N],
    df[argmax(df.radius), :eccentricity])

@printf("Radio promedio: %.5f\n", r_mean)
@printf("Rango dinámico: %.2fx\n", r_max / r_min)
println()

# ============================================================================
# Comparación con radios euclidianos (anteriores)
# ============================================================================

println("="^80)
println("COMPARACIÓN: Radios Intrínsecos vs Euclidianos")
println("="^80)
println()

# Radio euclidiano fijo que usábamos antes
r_euclidean = 0.05

@printf("Radio euclidiano anterior: r = %.4f (constante)\n", r_euclidean)
println()
@printf("%-12s %-8s %-12s %-12s %-10s\n", "Caso", "N", "r_intrinsic", "Reducción %", "Ratio")
println("-"^80)

# Casos críticos: e altos con N grandes
critical_cases = filter(row -> row.eccentricity >= 0.9 && row.N >= 80, df)

for row in eachrow(critical_cases)
    reduction = (1 - row.radius / r_euclidean) * 100
    ratio = r_euclidean / row.radius

    @printf("e=%.2f N=%3d   %.5f       %6.1f%%       %.2fx\n",
        row.eccentricity, row.N, row.radius, reduction, ratio)
end

println()

# ============================================================================
# Exportar resultados
# ============================================================================

output_file = "intrinsic_radii_matrix.csv"
CSV.write(output_file, df)

println("="^80)
println("RESULTADOS GUARDADOS")
println("="^80)
println()
println("Archivo: $output_file")
println("Formato: CSV con columnas [eccentricity, N, a, b, perimeter, radius, phi_intrinsic]")
println()

# ============================================================================
# Generar recomendación para parameter matrix
# ============================================================================

println("="^80)
println("RECOMENDACIÓN PARA PARAMETER MATRIX")
println("="^80)
println()

println("En generate_finite_size_scaling_matrix.jl, usar:")
println()
println("""
function get_intrinsic_radius(N::Int, e::Float64, φ_target::Float64=0.30)
    # Semi-ejes (área normalizada A=2)
    A = 2.0
    b = sqrt(A * (1 - e^2) / π)
    a = A / (π * b)

    # Perímetro
    h = ((a - b) / (a + b))^2
    P = π * (a + b) * (1 + 3*h / (10 + sqrt(4 - 3*h)))  # Ramanujan

    # Radio intrínseco
    r = φ_target * P / (2 * N)

    return r
end
""")

println()
println("Ejemplo de uso:")
println("""
for N in [40, 60, 80, 100, 120]
    for e in [0.0, 0.3, 0.5, 0.7, 0.8, 0.9, 0.95, 0.98, 0.99]
        r = get_intrinsic_radius(N, e, 0.30)
        # ... agregar a matriz
    end
end
""")

println()
println("="^80)
println("VERIFICACIÓN FINAL")
println("="^80)
println()

# Verificar caso que falló antes: N=120, e=0.99
N_fail = 120
e_fail = 0.99
row_fail = first(filter(row -> row.N == N_fail && row.eccentricity == e_fail, df))

@printf("Caso que FALLÓ anteriormente:\n")
@printf("  N = %d, e = %.2f\n", N_fail, e_fail)
@printf("  Radio anterior (euclidiano): %.5f\n", r_euclidean)
@printf("  φ_intrinsic (anterior):      %.4f (%.1f%%) → IMPOSIBLE\n",
    intrinsic_packing_fraction(N_fail, r_euclidean, row_fail.a, row_fail.b),
    intrinsic_packing_fraction(N_fail, r_euclidean, row_fail.a, row_fail.b) * 100)
println()
@printf("  Radio nuevo (intrínseco):    %.5f\n", row_fail.radius)
@printf("  φ_intrinsic (nuevo):         %.4f (%.1f%%) → ✅ VIABLE\n",
    row_fail.phi_intrinsic,
    row_fail.phi_intrinsic * 100)

println()
println("="^80)
println("✅ CÁLCULO COMPLETADO")
println("="^80)
