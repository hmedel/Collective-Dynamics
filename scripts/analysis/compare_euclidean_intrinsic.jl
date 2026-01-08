using HDF5, Statistics, Printf, JSON

# Analizar campaña Euclideana para comparación
euclidean_dir = "results/final_campaign_20251120_202723"

results_euc = Dict{Tuple{Int,Float64}, Vector{Dict}}()

run_dirs = filter(isdir, [joinpath(euclidean_dir, d) for d in readdir(euclidean_dir)])
run_dirs = filter(d -> occursin(r"^e\d", basename(d)), run_dirs)

println("Procesando campaña Euclideana (", length(run_dirs), " runs)...")

for run_dir in run_dirs
    h5_file = joinpath(run_dir, "trajectories.h5")
    json_file = joinpath(run_dir, "summary.json")
    
    if !isfile(h5_file) || !isfile(json_file)
        continue
    end
    
    try
        meta = JSON.parsefile(json_file)
        N = meta["N"]
        e = meta["eccentricity"]
        seed = meta["seed"]
        
        h5open(h5_file, "r") do file
            phi = read(file, "trajectories/phi")
            time = read(file, "trajectories/time")
            
            n_snapshots, n_particles = size(phi)
            phi_final = phi[end, :]
            
            psi_final = abs(mean(exp.(im * phi_final)))
            
            mean_angle = angle(mean(exp.(im * phi_final)))
            deviations = [mod(p - mean_angle + π, 2π) - π for p in phi_final]
            R_final = sqrt(mean(deviations.^2))
            
            psi_t = [abs(mean(exp.(im * phi[t, :]))) for t in 1:n_snapshots]
            tau_nuc_idx = findfirst(x -> x > 0.5, psi_t)
            tau_nuc = tau_nuc_idx === nothing ? NaN : time[tau_nuc_idx]
            
            key = (N, e)
            if !haskey(results_euc, key)
                results_euc[key] = []
            end
            
            push!(results_euc[key], Dict(
                "psi_final" => psi_final,
                "R_final" => R_final,
                "tau_nuc" => tau_nuc
            ))
        end
    catch err
    end
end

# Leer resultados intrínsecos del CSV
using DelimitedFiles
intrinsic_data = readdlm("intrinsic_campaign_statistics.csv", ',', skipstart=1)

println("\n" * "="^100)
println("COMPARACIÓN: EUCLIDEANO vs INTRÍNSECO")
println("="^100)
println()
println(@sprintf("%-5s %-5s │ %-22s │ %-22s │ %-8s",
    "N", "e", "Ψ_final (Eucl → Intr)", "Nucleaciones", "Δ%"))
println("-"^100)

keys_sorted = sort(collect(keys(results_euc)), by=x->(x[1], x[2]))

for key in keys_sorted
    N, e = key
    data_euc = results_euc[key]
    
    # Buscar datos intrínsecos
    idx = findfirst(row -> row[1] == N && row[2] == e, eachrow(intrinsic_data))
    if idx === nothing
        continue
    end
    
    intr_row = intrinsic_data[idx, :]
    
    psi_euc = mean([d["psi_final"] for d in data_euc])
    psi_intr = intr_row[4]  # psi_mean
    
    n_nuc_euc = count(!isnan, [d["tau_nuc"] for d in data_euc])
    n_nuc_intr = Int(intr_row[10])  # n_nucleated
    
    n_euc = length(data_euc)
    n_intr = Int(intr_row[3])
    
    delta_psi = (psi_intr - psi_euc) / psi_euc * 100
    
    println(@sprintf("%-5d %-5.1f │ %.3f → %.3f (%+.0f%%)   │ %d/%d → %d/%d         │ %s",
        N, e, psi_euc, psi_intr, delta_psi,
        n_nuc_euc, n_euc, n_nuc_intr, n_intr,
        delta_psi < -20 ? "⬇️" : (delta_psi > 20 ? "⬆️" : "≈")))
end

println("\n" * "="^100)
println("CONCLUSIÓN:")
println("="^100)
