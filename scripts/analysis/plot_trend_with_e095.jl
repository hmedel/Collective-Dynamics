#!/usr/bin/env julia
# Quick plot of R(e) trend including new e=0.95 data

using Printf

# Data from analyses (e, R_mean, R_std)
data = [
    (0.00, 1.01, 0.23),
    (0.30, 1.02, 0.16),
    (0.50, 1.18, 0.28),
    (0.70, 1.36, 0.38),
    (0.80, 1.36, 0.36),
    (0.90, 2.00, 0.57),
    (0.95, 2.51, 0.62),  # NEW!
]

println("="^70)
println("TENDENCIA R(e) INCLUYENDO e=0.95")
println("="^70)
println()

println("e      R       σ_R    Δ vs prev    Interpretación")
println("-"^70)

for i in 1:length(data)
    e, R, σ = data[i]

    delta_str = if i > 1
        delta = R - data[i-1][2]
        pct = (delta / data[i-1][2]) * 100
        @sprintf("%+.2f (%+.0f%%)", delta, pct)
    else
        "  (baseline)  "
    end

    interp = if R < 1.2
        "Gas uniforme"
    elseif R < 1.5
        "Clustering débil"
    elseif R < 2.2
        "Clustering moderado"
    elseif R < 3.0
        "Clustering FUERTE"
    else
        "Pre-cristal"
    end

    marker = (e == 0.95) ? " ←NEW" : ""

    @printf("%.2f  %4.2f ± %4.2f  %-15s  %-20s%s\n",
            e, R, σ, delta_str, interp, marker)
end

println()
println("="^70)
println()

# Acceleration analysis
println("ANÁLISIS DE ACELERACIÓN:")
println("-"^70)

increments = Float64[]
for i in 2:length(data)
    delta = data[i][2] - data[i-1][2]
    delta_e = data[i][1] - data[i-1][1]
    slope = delta / delta_e
    push!(increments, slope)

    regime = if data[i][1] <= 0.5
        "Inicial (e≤0.5)"
    elseif data[i][1] <= 0.8
        "Moderado (0.5<e≤0.8)"
    else
        "Alto (e>0.8)"
    end

    @printf("  %.2f→%.2f: dR/de = %.2f   [%s]\n",
            data[i-1][1], data[i][1], slope, regime)
end

println()
println("Observaciones:")
if increments[end] > 2 * increments[1]
    println("  ✅ Aceleración clara: dR/de aumenta con e")
    println("  → Comportamiento NO lineal detectado")
else
    println("  ⏸️  Crecimiento aproximadamente lineal")
end

println()
println("="^70)
println()

# Extrapolation to e=0.98, 0.99
println("EXTRAPOLACIÓN A e=0.98, 0.99:")
println("-"^70)

# Use last two points for linear extrapolation
e1, R1, _ = data[end-1]
e2, R2, _ = data[end]
slope = (R2 - R1) / (e2 - e1)

for e_pred in [0.98, 0.99]
    R_linear = R2 + slope * (e_pred - e2)
    @printf("  e=%.2f: R ~ %.1f (extrapolación lineal)\n", e_pred, R_linear)
end

println()
println("NOTA: Si tendencia se acelera (no lineal), valores reales")
println("      podrían ser MAYORES → R(0.98) ~ 4-6, R(0.99) ~ 5-8")
println()
println("="^70)
