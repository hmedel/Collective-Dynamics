using JSON, Statistics, Printf

function get_collision_stats(campaign_dir)
    results = Dict{Tuple{Int,Float64}, Vector{Int}}()
    
    for d in readdir(campaign_dir)
        json_file = joinpath(campaign_dir, d, "summary.json")
        if !isfile(json_file)
            continue
        end
        try
            meta = JSON.parsefile(json_file)
            N = meta["N"]
            e = meta["eccentricity"]
            collisions = meta["total_collisions"]
            
            key = (N, e)
            if !haskey(results, key)
                results[key] = Int[]
            end
            push!(results[key], collisions)
        catch
        end
    end
    return results
end

euc_stats = get_collision_stats("results/final_campaign_20251120_202723")
intr_stats = get_collision_stats("results/intrinsic_campaign_20251121_002941")

println("="^80)
println("COMPARACIÓN DE TASAS DE COLISIÓN")
println("="^80)
println()
println(@sprintf("%-5s %-5s │ %-15s │ %-15s │ %-10s",
    "N", "e", "Colisiones(Euc)", "Colisiones(Int)", "Ratio"))
println("-"^80)

keys = sort(collect(keys(euc_stats)), by=x->(x[1], x[2]))

for key in keys
    N, e = key
    
    if !haskey(intr_stats, key)
        continue
    end
    
    euc_mean = mean(euc_stats[key])
    intr_mean = mean(intr_stats[key])
    ratio = intr_mean / euc_mean
    
    println(@sprintf("%-5d %-5.1f │ %15.0f │ %15.0f │ %.2fx",
        N, e, euc_mean, intr_mean, ratio))
end

println("-"^80)

# Promedios globales
all_euc = vcat(values(euc_stats)...)
all_intr = vcat(values(intr_stats)...)

println(@sprintf("PROMEDIO  │ %15.0f │ %15.0f │ %.2fx",
    mean(all_euc), mean(all_intr), mean(all_intr)/mean(all_euc)))
println("="^80)
