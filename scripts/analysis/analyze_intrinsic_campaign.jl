using HDF5, Statistics, Printf, JSON

campaign_dir = "results/intrinsic_campaign_20251121_002941"

# Estructura para almacenar resultados
results = Dict{Tuple{Int,Float64}, Vector{Dict}}()

# Encontrar todos los directorios de runs
run_dirs = filter(isdir, [joinpath(campaign_dir, d) for d in readdir(campaign_dir)])
run_dirs = filter(d -> occursin(r"^e\d", basename(d)), run_dirs)

println("Procesando ", length(run_dirs), " runs...")

for (i, run_dir) in enumerate(run_dirs)
    h5_file = joinpath(run_dir, "trajectories.h5")
    json_file = joinpath(run_dir, "summary.json")
    
    if !isfile(h5_file) || !isfile(json_file)
        continue
    end
    
    try
        # Leer parámetros
        meta = JSON.parsefile(json_file)
        N = meta["N"]
        e = meta["eccentricity"]
        seed = meta["seed"]
        
        # Leer datos 
        h5open(h5_file, "r") do file
            # Datos en trajectories/
            phi = read(file, "trajectories/phi")  # (n_snapshots, n_particles)
            phidot = read(file, "trajectories/phidot")
            time = read(file, "trajectories/time")
            
            n_snapshots, n_particles = size(phi)
            
            # Métricas al final
            phi_final = phi[end, :]
            
            # Calcular parámetro de orden Kuramoto
            psi_final = abs(mean(exp.(im * phi_final)))
            
            # Calcular dispersión angular (R = circular std)
            mean_angle = angle(mean(exp.(im * phi_final)))
            deviations = [mod(p - mean_angle + π, 2π) - π for p in phi_final]
            R_final = sqrt(mean(deviations.^2))
            
            # Evolución temporal de Ψ
            psi_t = [abs(mean(exp.(im * phi[t, :]))) for t in 1:n_snapshots]
            
            # Tiempo de nucleación (cuando Ψ cruza 0.5)
            tau_nuc_idx = findfirst(x -> x > 0.5, psi_t)
            tau_nuc = tau_nuc_idx === nothing ? NaN : time[tau_nuc_idx]
            
            # Almacenar
            key = (N, e)
            if !haskey(results, key)
                results[key] = []
            end
            
            push!(results[key], Dict(
                "seed" => seed,
                "psi_final" => psi_final,
                "R_final" => R_final,
                "tau_nuc" => tau_nuc,
                "n_snapshots" => n_snapshots
            ))
        end
    catch err
        # Solo mostrar primeros errores
        if i <= 5
            println("Error en ", basename(run_dir), ": ", err)
        end
    end
    
    if i % 100 == 0
        print("\r  Procesados: ", i, "/", length(run_dirs))
    end
end

println("\n")

# Generar tabla de resultados
println("="^90)
println("CAMPAÑA INTRÍNSECA - MÉTRICAS DE CLUSTERING (720 runs, 30 seeds/condición)")
println("="^90)
println()

# Ordenar claves
keys_sorted = sort(collect(keys(results)), by=x->(x[1], x[2]))

println(@sprintf("%-5s %-5s %-5s │ %-10s %-8s │ %-10s %-8s │ %-10s %-8s │ %-6s",
    "N", "e", "n", "Ψ_final", "±σ", "R_final", "±σ", "τ_nuc", "±σ", "n_nuc"))
println("-"^90)

csv_lines = ["N,e,n_seeds,psi_mean,psi_std,R_mean,R_std,tau_nuc_mean,tau_nuc_std,n_nucleated"]

for key in keys_sorted
    N, e = key
    data = results[key]
    n_seeds = length(data)
    
    psi_vals = [d["psi_final"] for d in data]
    R_vals = [d["R_final"] for d in data]
    tau_vals = filter(!isnan, [d["tau_nuc"] for d in data])
    
    psi_mean = mean(psi_vals)
    psi_std = std(psi_vals)
    R_mean = mean(R_vals)
    R_std = std(R_vals)
    
    n_nucleated = length(tau_vals)
    if n_nucleated > 1
        tau_mean = mean(tau_vals)
        tau_std = std(tau_vals)
    else
        tau_mean = n_nucleated > 0 ? tau_vals[1] : NaN
        tau_std = NaN
    end
    
    println(@sprintf("%-5d %-5.1f %-5d │ %-10.4f %-8.4f │ %-10.4f %-8.4f │ %-10.2f %-8.2f │ %-6d",
        N, e, n_seeds, psi_mean, psi_std, R_mean, R_std, 
        isnan(tau_mean) ? 0.0 : tau_mean, 
        isnan(tau_std) ? 0.0 : tau_std, 
        n_nucleated))
    
    push!(csv_lines, "$N,$e,$n_seeds,$psi_mean,$psi_std,$R_mean,$R_std,$tau_mean,$tau_std,$n_nucleated")
end

# Guardar CSV
println("\n" * "="^90)
open("intrinsic_campaign_statistics.csv", "w") do io
    for line in csv_lines
        println(io, line)
    end
end
println("✅ Guardado: intrinsic_campaign_statistics.csv")
println("="^90)
