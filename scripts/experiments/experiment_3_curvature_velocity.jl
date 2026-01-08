#!/usr/bin/env julia
"""
experiment_3_curvature_velocity.jl

EXPERIMENTO 3: Testing the "Traffic Jam" Hypothesis

Hypothesis: High curvature regions → particles slow down → density accumulation
           (Like traffic jams on curvy roads)

Strategy:
1. Track velocity vs local curvature over time
2. Track density vs curvature evolution (not just final state)
3. Measure time delay between curvature and density buildup
"""

using Pkg
Pkg.activate(".")

include("src/simulation_polar.jl")
include("src/geometry/metrics_polar.jl")

using Printf
using Random
using Statistics
using DelimitedFiles

println("=" ^ 70)
println("EXPERIMENTO 3: Curvature-Velocity Coupling (Traffic Jam Test)")
println("=" ^ 70)
println()

# ============================================================================
# Configuration
# ============================================================================

a, b = 2.0, 1.0
N = 40
mass = 1.0
radius = 0.05
max_time = 50.0
dt_max = 1e-5
dt_min = 1e-10
save_interval = 0.5  # Save every 0.5s for detailed tracking

println("PARÁMETROS:")
println("  N partículas:    $N")
println("  Tiempo total:    $max_time s")
println("  Save interval:   $save_interval s")
println("  Semi-ejes:       a=$a, b=$b")
println("  Eccentricidad:   e=$(sqrt(1 - (b/a)^2))")
println()

# Calculate curvature profile
println("PERFIL DE CURVATURA:")
φ_range = range(0, 2π, length=100)
κ_values = [curvature_ellipse_polar(φ, a, b) for φ in φ_range]
κ_max = maximum(κ_values)
κ_min = minimum(κ_values)
println("  κ_max = ", @sprintf("%.4f", κ_max), " at φ ≈ 0, π (semi-major axis)")
println("  κ_min = ", @sprintf("%.4f", κ_min), " at φ ≈ π/2, 3π/2 (semi-minor axis)")
println("  κ_max/κ_min = ", @sprintf("%.2f", κ_max/κ_min))
println()

# ============================================================================
# Create particles (same seed as Exp 1 & 2)
# ============================================================================

println("Creando partículas (seed=42)...")
Random.seed!(42)

particles = ParticlePolar{Float64}[]
for i in 1:N
    φ = rand() * 2π
    φ_dot = (rand() - 0.5) * 2.0
    push!(particles, ParticlePolar(i, mass, radius, φ, φ_dot, a, b))
end

E_initial = sum(kinetic_energy(p, a, b) for p in particles)
println("  Energía inicial: ", @sprintf("%.10f", E_initial))
println()

# ============================================================================
# Run simulation
# ============================================================================

println("=" ^ 70)
println("EJECUTANDO SIMULACIÓN")
println("=" ^ 70)
println()

t_start = time()

data = simulate_ellipse_polar_adaptive(
    particles, a, b;
    max_time = max_time,
    dt_max = dt_max,
    dt_min = dt_min,
    save_interval = save_interval,
    collision_method = :parallel_transport,
    use_projection = true,
    projection_interval = 100,
    projection_tolerance = 1e-12,
    verbose = true
)

t_elapsed = time() - t_start

println()
println("Simulación completada en: ", @sprintf("%.2f s", t_elapsed))
println()

# ============================================================================
# ANALYSIS: Velocity vs Curvature Correlation Over Time
# ============================================================================

println("=" ^ 70)
println("ANÁLISIS: VELOCIDAD vs CURVATURA")
println("=" ^ 70)
println()

output_dir = "results_experiment_3"
mkpath(output_dir)

n_snapshots = length(data.times)
n_bins = 16
bin_edges = range(0, 2π, length=n_bins+1)
bin_centers = [(bin_edges[i] + bin_edges[i+1])/2 for i in 1:n_bins]

# For each bin, calculate curvature
bin_curvatures = [curvature_ellipse_polar(φ, a, b) for φ in bin_centers]

# Time series: for each snapshot, calculate average velocity and density per bin
velocity_history = zeros(n_snapshots, n_bins)
density_history = zeros(n_snapshots, n_bins)

println("Calculando velocidad y densidad por bin temporal...")
for (snap_idx, snapshot) in enumerate(data.particles_history)
    # Initialize bins
    bin_velocities = [Float64[] for _ in 1:n_bins]
    bin_counts = zeros(Int, n_bins)

    # Bin particles
    for p in snapshot
        φ_norm = mod(p.φ, 2π)
        bin_idx = searchsortedfirst(bin_edges, φ_norm)
        bin_idx = min(bin_idx, n_bins)

        if bin_idx >= 1 && bin_idx <= n_bins
            # Get metric at this location
            g_φφ = metric_ellipse_polar(p.φ, a, b)
            # Physical velocity (not φ̇, but actual speed)
            v_phys = abs(p.φ_dot) * sqrt(g_φφ)

            push!(bin_velocities[bin_idx], v_phys)
            bin_counts[bin_idx] += 1
        end
    end

    # Calculate averages per bin
    for bin in 1:n_bins
        if !isempty(bin_velocities[bin])
            velocity_history[snap_idx, bin] = mean(bin_velocities[bin])
        else
            velocity_history[snap_idx, bin] = NaN
        end
        density_history[snap_idx, bin] = bin_counts[bin]
    end
end

println("  ✓ Velocidades y densidades calculadas")
println()

# ============================================================================
# Analysis 1: Time-averaged correlations
# ============================================================================

println("ANÁLISIS 1: Correlaciones Temporales")
println("-" ^ 70)

# Early time (first 20% of snapshots)
early_idx = 1:div(n_snapshots, 5)
late_idx = div(4*n_snapshots, 5):n_snapshots

# Average over early and late periods
velocity_early = vec(mean(velocity_history[early_idx, :], dims=1))
density_early = vec(mean(density_history[early_idx, :], dims=1))

velocity_late = vec(mean(velocity_history[late_idx, :], dims=1))
density_late = vec(mean(density_history[late_idx, :], dims=1))

# Correlations with curvature
# Remove NaN values
valid_early = .!isnan.(velocity_early)
valid_late = .!isnan.(velocity_late)

if sum(valid_early) > 2
    corr_v_κ_early = cor(velocity_early[valid_early], bin_curvatures[valid_early])
    corr_ρ_κ_early = cor(density_early[valid_early], bin_curvatures[valid_early])
else
    corr_v_κ_early = NaN
    corr_ρ_κ_early = NaN
end

if sum(valid_late) > 2
    corr_v_κ_late = cor(velocity_late[valid_late], bin_curvatures[valid_late])
    corr_ρ_κ_late = cor(density_late[valid_late], bin_curvatures[valid_late])
else
    corr_v_κ_late = NaN
    corr_ρ_κ_late = NaN
end

println()
println("Tiempo TEMPRANO (t < $(data.times[early_idx[end]]) s):")
println("  Correlación v(φ) vs κ(φ):  ", @sprintf("%.4f", corr_v_κ_early))
println("  Correlación ρ(φ) vs κ(φ):  ", @sprintf("%.4f", corr_ρ_κ_early))

println()
println("Tiempo TARDÍO (t > $(data.times[late_idx[1]]) s):")
println("  Correlación v(φ) vs κ(φ):  ", @sprintf("%.4f", corr_v_κ_late))
println("  Correlación ρ(φ) vs κ(φ):  ", @sprintf("%.4f", corr_ρ_κ_late))

println()
println("INTERPRETACIÓN:")
if !isnan(corr_v_κ_early) && corr_v_κ_early < -0.3
    println("  ✅ Hipótesis APOYADA: Velocidad negatively correlated con curvatura")
    println("     → Partículas se FRENAN en regiones de alta curvatura (traffic jam!)")
elseif !isnan(corr_v_κ_early) && abs(corr_v_κ_early) < 0.2
    println("  ⚠️  Correlación débil: Curvatura no afecta fuertemente la velocidad")
else
    println("  ❓ Correlación positiva o no concluyente")
end

println()

# ============================================================================
# Analysis 2: Density buildup dynamics
# ============================================================================

println("ANÁLISIS 2: Dinámica de Acumulación de Densidad")
println("-" ^ 70)

# Find bin with highest curvature
max_κ_bin = argmax(bin_curvatures)
min_κ_bin = argmin(bin_curvatures)

println()
println("Bin con MÁXIMA curvatura (bin $max_κ_bin, φ=$(bin_centers[max_κ_bin])):")
println("  κ = ", @sprintf("%.4f", bin_curvatures[max_κ_bin]))

# Density evolution in this bin
ρ_high_κ = density_history[:, max_κ_bin]
ρ_mean_initial = mean(ρ_high_κ[1:10])
ρ_mean_final = mean(ρ_high_κ[end-10:end])

println("  Densidad inicial: ", @sprintf("%.2f", ρ_mean_initial))
println("  Densidad final:   ", @sprintf("%.2f", ρ_mean_final))
println("  Ratio:            ", @sprintf("%.3f", ρ_mean_final / ρ_mean_initial))

println()
println("Bin con MÍNIMA curvatura (bin $min_κ_bin, φ=$(bin_centers[min_κ_bin])):")
println("  κ = ", @sprintf("%.4f", bin_curvatures[min_κ_bin]))

ρ_low_κ = density_history[:, min_κ_bin]
ρ_mean_initial_low = mean(ρ_low_κ[1:10])
ρ_mean_final_low = mean(ρ_low_κ[end-10:end])

println("  Densidad inicial: ", @sprintf("%.2f", ρ_mean_initial_low))
println("  Densidad final:   ", @sprintf("%.2f", ρ_mean_final_low))
println("  Ratio:            ", @sprintf("%.3f", ρ_mean_final_low / ρ_mean_initial_low))

println()
if (ρ_mean_final / ρ_mean_initial) > (ρ_mean_final_low / ρ_mean_initial_low) * 1.5
    println("  ✅ Densidad aumenta MÁS en zona de alta curvatura (traffic jam effect!)")
elseif (ρ_mean_final / ρ_mean_initial) < (ρ_mean_final_low / ρ_mean_initial_low) * 0.67
    println("  ⚠️  Densidad aumenta MENOS en zona de alta curvatura")
else
    println("  ⚠️  Acumulación similar en ambas zonas")
end

println()

# ============================================================================
# Save detailed data
# ============================================================================

println("=" ^ 70)
println("GUARDANDO DATOS")
println("=" ^ 70)
println()

# Save curvature profile
curv_data = hcat(bin_centers, bin_curvatures)
writedlm(joinpath(output_dir, "curvature_profile.csv"), curv_data, ',')
println("  ✓ curvature_profile.csv")

# Save velocity history (time x bins)
header_v = ["time" string.(1:n_bins)...]
velocity_data = hcat(data.times, velocity_history)
writedlm(joinpath(output_dir, "velocity_vs_phi_history.csv"),
         vcat(reshape(header_v, 1, :), velocity_data), ',')
println("  ✓ velocity_vs_phi_history.csv")

# Save density history
header_ρ = ["time" string.(1:n_bins)...]
density_data = hcat(data.times, density_history)
writedlm(joinpath(output_dir, "density_vs_phi_history.csv"),
         vcat(reshape(header_ρ, 1, :), density_data), ',')
println("  ✓ density_vs_phi_history.csv")

# Summary
open(joinpath(output_dir, "traffic_jam_analysis.txt"), "w") do io
    println(io, "Traffic Jam Hypothesis Analysis")
    println(io, "=" ^ 70)
    println(io)
    println(io, "Parámetros:")
    println(io, "  a/b = $(a/b)")
    println(io, "  Eccentricity = $(sqrt(1 - (b/a)^2))")
    println(io, "  N = $N")
    println(io, "  Time = $max_time s")
    println(io)
    println(io, "Curvatura:")
    println(io, "  κ_max = ", @sprintf("%.4f", κ_max))
    println(io, "  κ_min = ", @sprintf("%.4f", κ_min))
    println(io, "  κ_max/κ_min = ", @sprintf("%.2f", κ_max/κ_min))
    println(io)
    println(io, "Correlaciones (tiempo temprano):")
    println(io, "  v(φ) vs κ(φ):  ", @sprintf("%.4f", corr_v_κ_early))
    println(io, "  ρ(φ) vs κ(φ):  ", @sprintf("%.4f", corr_ρ_κ_early))
    println(io)
    println(io, "Correlaciones (tiempo tardío):")
    println(io, "  v(φ) vs κ(φ):  ", @sprintf("%.4f", corr_v_κ_late))
    println(io, "  ρ(φ) vs κ(φ):  ", @sprintf("%.4f", corr_ρ_κ_late))
    println(io)
    println(io, "Acumulación de densidad:")
    println(io, "  Zona alta κ: ratio = ", @sprintf("%.3f", ρ_mean_final / ρ_mean_initial))
    println(io, "  Zona baja κ: ratio = ", @sprintf("%.3f", ρ_mean_final_low / ρ_mean_initial_low))
    println(io)

    if !isnan(corr_v_κ_early) && corr_v_κ_early < -0.3
        println(io, "CONCLUSIÓN: ✅ Hipótesis del traffic jam APOYADA")
        println(io, "  - Velocidad anti-correlacionada con curvatura")
        println(io, "  - Alta curvatura → frenado → acumulación de densidad")
    else
        println(io, "CONCLUSIÓN: ⚠️  Evidencia mixta o hipótesis no apoyada")
    end
end
println("  ✓ traffic_jam_analysis.txt")

println()
println("=" ^ 70)
println("✅ EXPERIMENTO 3 COMPLETADO")
println("=" ^ 70)
println()

println("Resultados guardados en: $output_dir/")
println()
println("Próximo paso:")
println("  → Experimento 4: Variar eccentricidad (a/b = 1, 2, 3, 5)")
println("    Si hipótesis correcta: mayor a/b → clustering más fuerte")
println()
