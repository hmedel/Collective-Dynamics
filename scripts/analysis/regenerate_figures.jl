#!/usr/bin/env julia
#
# regenerate_figures.jl - Figuras con interpretación correcta de κ_FS
#

using HDF5, Statistics, Printf
using Plots
gr()

println("="^70)
println("REGENERANDO FIGURAS CON INTERPRETACIÓN CORRECTA")
println("="^70)

include("src/geometry/metrics_polar.jl")

campaign_dir = "results/intrinsic_campaign_20251121_002941"
output_dir = joinpath(campaign_dir, "figures_corrected")
mkpath(output_dir)

colors = [:blue, :green, :orange, :red, :purple, :brown]
e_values = [0.0, 0.3, 0.5, 0.7, 0.8, 0.9]

#=============================================================================
FIGURA 1: Evolución temporal de φ_std
=============================================================================#
println("\n[1/6] φ_std vs tiempo...")

fig1 = plot(title="Evolución del Clustering: φ_std vs Tiempo",
            xlabel="Tiempo", ylabel="φ_std (rad)",
            legend=:topright, size=(800, 500), dpi=150)

for (idx, e) in enumerate(e_values)
    e_str = @sprintf("e%.2f", e)
    pattern = Regex("^$(e_str)_N080")

    run_dirs = filter(readdir(campaign_dir, join=true)) do path
        isdir(path) && occursin(pattern, basename(path))
    end

    if isempty(run_dirs) continue end

    all_phi_std = []
    for run_dir in run_dirs[1:min(10, length(run_dirs))]
        h5_file = joinpath(run_dir, "trajectories.h5")
        if !isfile(h5_file) continue end

        h5open(h5_file, "r") do f
            phi = read(f["trajectories/phi"])
            phi_std_t = [std(phi[t, :]) for t in 1:size(phi, 1)]
            push!(all_phi_std, phi_std_t)
        end
    end

    if isempty(all_phi_std) continue end

    min_len = minimum(length.(all_phi_std))
    phi_std_mean = [mean([ps[t] for ps in all_phi_std]) for t in 1:min_len]
    phi_std_err = [std([ps[t] for ps in all_phi_std])/sqrt(length(all_phi_std)) for t in 1:min_len]

    t_vals = range(0, 100, length=min_len)
    plot!(fig1, t_vals, phi_std_mean, ribbon=phi_std_err,
          label=@sprintf("e=%.1f", e), color=colors[idx], linewidth=2)
end

hline!(fig1, [π/sqrt(3)], linestyle=:dash, color=:gray, label="Uniforme", linewidth=1)
savefig(fig1, joinpath(output_dir, "fig1_phi_std_evolution.png"))
println("  ✅ fig1_phi_std_evolution.png")

#=============================================================================
FIGURA 2: Correlación κ_FS - densidad
=============================================================================#
println("\n[2/6] Correlación κ_FS-densidad...")

fig2 = plot(title="Correlación Curvatura Frenet-Serret - Densidad",
            xlabel="Tiempo", ylabel="cor(ρ, κ_FS)",
            legend=:bottomright, size=(800, 500), dpi=150)

for (idx, e) in enumerate([0.5, 0.7, 0.8, 0.9])
    e_str = @sprintf("e%.2f", e)
    a = 2.0
    b = a * sqrt(1 - e^2)
    pattern = Regex("^$(e_str)_N080")

    run_dirs = filter(readdir(campaign_dir, join=true)) do path
        isdir(path) && occursin(pattern, basename(path))
    end

    if isempty(run_dirs) continue end

    all_corr = []
    for run_dir in run_dirs[1:min(10, length(run_dirs))]
        h5_file = joinpath(run_dir, "trajectories.h5")
        if !isfile(h5_file) continue end

        h5open(h5_file, "r") do f
            phi = read(f["trajectories/phi"])
            n_time = size(phi, 1)

            corr_t = Float64[]
            for t in 1:n_time
                phi_t = phi[t, :]
                n_bins = 20
                bin_edges = range(0, 2π, length=n_bins+1)
                bin_counts = zeros(n_bins)
                bin_κ = zeros(n_bins)
                for i in 1:n_bins
                    mask = (phi_t .>= bin_edges[i]) .& (phi_t .< bin_edges[i+1])
                    bin_counts[i] = sum(mask)
                    φ_mid = (bin_edges[i] + bin_edges[i+1]) / 2
                    bin_κ[i] = curvature_ellipse_polar(φ_mid, a, b)
                end
                push!(corr_t, cor(bin_counts, bin_κ))
            end
            push!(all_corr, corr_t)
        end
    end

    if isempty(all_corr) continue end

    min_len = minimum(length.(all_corr))
    corr_mean = [mean([c[t] for c in all_corr]) for t in 1:min_len]
    t_vals = range(0, 100, length=min_len)
    plot!(fig2, t_vals, corr_mean, label=@sprintf("e=%.1f", e),
          color=colors[idx+2], linewidth=2)
end

hline!(fig2, [0], linestyle=:dash, color=:gray, label="", linewidth=1)
savefig(fig2, joinpath(output_dir, "fig2_curvature_correlation.png"))
println("  ✅ fig2_curvature_correlation.png")

#=============================================================================
FIGURA 3: Distribución espacial
=============================================================================#
println("\n[3/6] Distribución espacial...")

run_dir = joinpath(campaign_dir, "e0.90_N080_seed01")
h5_file = joinpath(run_dir, "trajectories.h5")

h5open(h5_file, "r") do f
    phi = read(f["trajectories/phi"])
    phidot = read(f["trajectories/phidot"])
    n_time, N = size(phi)
    a, b = 2.0, 2.0 * sqrt(1 - 0.9^2)

    fig3 = plot(layout=(1, 3), size=(1200, 400), dpi=150)

    for (subplot_idx, t_idx) in enumerate([1, n_time÷2, n_time])
        phi_t = phi[t_idx, :]
        phidot_t = abs.(phidot[t_idx, :])
        t_val = (t_idx - 1) / (n_time - 1) * 100

        θ_ellipse = range(0, 2π, length=200)
        r_ellipse = [radial_ellipse(θ, a, b) for θ in θ_ellipse]
        x_ellipse = r_ellipse .* cos.(θ_ellipse)
        y_ellipse = r_ellipse .* sin.(θ_ellipse)

        plot!(fig3[subplot_idx], x_ellipse, y_ellipse,
              color=:lightgray, linewidth=2, label="", aspect_ratio=:equal)

        r_particles = [radial_ellipse(φ, a, b) for φ in phi_t]
        x_particles = r_particles .* cos.(phi_t)
        y_particles = r_particles .* sin.(phi_t)

        scatter!(fig3[subplot_idx], x_particles, y_particles,
                markersize=4, markerstrokewidth=0,
                marker_z=phidot_t, color=:viridis,
                colorbar=(subplot_idx==3), clims=(0, 1.2),
                label="", title=@sprintf("t = %.0f", t_val))

        xlims!(fig3[subplot_idx], -2.5, 2.5)
        ylims!(fig3[subplot_idx], -1.2, 1.2)
    end

    plot!(fig3, plot_title="Partículas (e=0.9, N=80) - Color: |φ̇|")
    savefig(fig3, joinpath(output_dir, "fig3_spatial_distribution.png"))
    println("  ✅ fig3_spatial_distribution.png")
end

#=============================================================================
FIGURA 4: Relación φ̇ vs κ_FS y g_φφ
=============================================================================#
println("\n[4/6] Relación φ̇ vs κ_FS...")

phi_all = Float64[]
phidot_all = Float64[]

run_dirs = filter(readdir(campaign_dir, join=true)) do path
    isdir(path) && occursin(r"^e0\.90_N080", basename(path))
end

for run_dir in run_dirs[1:min(15, length(run_dirs))]
    h5_file = joinpath(run_dir, "trajectories.h5")
    if !isfile(h5_file) continue end

    h5open(h5_file, "r") do f
        phi = read(f["trajectories/phi"])
        phidot = read(f["trajectories/phidot"])
        append!(phi_all, phi[end, :])
        append!(phidot_all, phidot[end, :])
    end
end

a, b = 2.0, 2.0 * sqrt(1 - 0.9^2)
κ_all = [curvature_ellipse_polar(φ, a, b) for φ in phi_all]
g_all = [metric_ellipse_polar(φ, a, b) for φ in phi_all]

fig4 = plot(layout=(1, 2), size=(1000, 400), dpi=150)

scatter!(fig4[1], κ_all, abs.(phidot_all),
        markersize=3, alpha=0.5, label="",
        xlabel="κ_FS", ylabel="|φ̇|",
        title="Velocidad vs Curvatura F-S")

scatter!(fig4[2], g_all, abs.(phidot_all),
        markersize=3, alpha=0.5, label="",
        xlabel="g_φφ", ylabel="|φ̇|",
        title="Velocidad vs Métrica")

g_range = range(minimum(g_all), maximum(g_all), length=50)
c_fit = mean(abs.(phidot_all) .* sqrt.(g_all))
phidot_theory = c_fit ./ sqrt.(g_range)
plot!(fig4[2], g_range, phidot_theory, color=:red, linewidth=2, label="φ̇∝1/√g")

corr_val = cor(κ_all, abs.(phidot_all))
annotate!(fig4[1], 0.5, 1.0, text(@sprintf("cor = %.2f", corr_val), 10))

savefig(fig4, joinpath(output_dir, "fig4_velocity_vs_curvature.png"))
println("  ✅ fig4_velocity_vs_curvature.png")

#=============================================================================
FIGURA 5: Histogramas angulares
=============================================================================#
println("\n[5/6] Histogramas angulares...")

fig5 = plot(layout=(2, 2), size=(1000, 800), dpi=150)

for (subplot_idx, (e, N)) in enumerate([(0.5, 80), (0.7, 80), (0.9, 80), (0.9, 40)])
    e_str = @sprintf("e%.2f", e)
    N_str = @sprintf("N%03d", N)
    pattern = Regex("^$(e_str)_$(N_str)")

    run_dirs = filter(readdir(campaign_dir, join=true)) do path
        isdir(path) && occursin(pattern, basename(path))
    end

    if isempty(run_dirs) continue end

    phi_initial = Float64[]
    phi_final = Float64[]

    for run_dir in run_dirs[1:min(10, length(run_dirs))]
        h5_file = joinpath(run_dir, "trajectories.h5")
        if !isfile(h5_file) continue end

        h5open(h5_file, "r") do f
            phi = read(f["trajectories/phi"])
            append!(phi_initial, phi[1, :])
            append!(phi_final, phi[end, :])
        end
    end

    histogram!(fig5[subplot_idx], phi_initial, bins=30,
              normalize=:pdf, alpha=0.5, color=:blue, label="t=0")
    histogram!(fig5[subplot_idx], phi_final, bins=30,
              normalize=:pdf, alpha=0.5, color=:red, label="t=100",
              title=@sprintf("e=%.1f, N=%d", e, N),
              xlabel="φ (rad)", ylabel="Densidad")

    vline!(fig5[subplot_idx], [0, π, 2π], linestyle=:dash, color=:gray,
           label="", alpha=0.5)
end

plot!(fig5, plot_title="Distribución Angular: t=0 (azul) vs t=100 (rojo)")
savefig(fig5, joinpath(output_dir, "fig5_angular_distribution.png"))
println("  ✅ fig5_angular_distribution.png")

#=============================================================================
FIGURA 6: Diagrama de fase
=============================================================================#
println("\n[6/6] Diagrama de fase...")

N_values = [20, 40, 60, 80]
e_values_phase = [0.0, 0.3, 0.5, 0.7, 0.8, 0.9]
frac_high_κ = zeros(length(N_values), length(e_values_phase))

for (i, N) in enumerate(N_values)
    for (j, e) in enumerate(e_values_phase)
        e_str = @sprintf("e%.2f", e)
        N_str = @sprintf("N%03d", N)
        pattern = Regex("^$(e_str)_$(N_str)")

        run_dirs = filter(readdir(campaign_dir, join=true)) do path
            isdir(path) && occursin(pattern, basename(path))
        end

        if isempty(run_dirs)
            frac_high_κ[i, j] = NaN
            continue
        end

        fracs = Float64[]
        for run_dir in run_dirs[1:min(10, length(run_dirs))]
            h5_file = joinpath(run_dir, "trajectories.h5")
            if !isfile(h5_file) continue end

            h5open(h5_file, "r") do f
                phi = read(f["trajectories/phi"])
                phi_final = phi[end, :]
                n_high = sum(abs.(cos.(phi_final)) .> 0.7)
                push!(fracs, n_high / length(phi_final))
            end
        end

        frac_high_κ[i, j] = isempty(fracs) ? NaN : mean(fracs)
    end
end

fig6 = heatmap(string.(e_values_phase), string.(N_values), frac_high_κ,
               xlabel="Excentricidad (e)", ylabel="N partículas",
               title="Fracción en Alta κ_FS (φ≈0,π) al t=100",
               color=:YlOrRd, clims=(0.3, 0.7),
               size=(600, 400), dpi=150)

savefig(fig6, joinpath(output_dir, "fig6_phase_diagram.png"))
println("  ✅ fig6_phase_diagram.png")

println("\n" * "="^70)
println("✅ FIGURAS GUARDADAS EN: $output_dir")
println("="^70)
