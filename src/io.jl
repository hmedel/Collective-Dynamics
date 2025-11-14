"""
    io.jl

Sistema de entrada/salida para simulaciones.

Funciones principales:
- `read_config(filename)`: Leer configuración desde TOML
- `read_particles_csv(filename, a, b)`: Leer partículas desde CSV
- `save_simulation_results(data, config, output_dir)`: Guardar resultados

Permite ejecutar simulaciones sin modificar código, solo archivos de configuración.
"""

using TOML
using Dates
using DelimitedFiles
using Printf

# ============================================================================
# LECTURA DE CONFIGURACIÓN
# ============================================================================

"""
    read_config(filename::String) -> Dict

Lee archivo de configuración TOML y retorna diccionario con parámetros.

# Ejemplo
```julia
config = read_config("config/simulation_example.toml")
```
"""
function read_config(filename::String)
    if !isfile(filename)
        error("Archivo de configuración no encontrado: $filename")
    end

    config = TOML.parsefile(filename)

    # Validar campos requeridos
    required_sections = ["geometry", "simulation", "particles", "output"]
    for section in required_sections
        if !haskey(config, section)
            error("Falta sección requerida en configuración: [$section]")
        end
    end

    return config
end

"""
    validate_config(config::Dict) -> Nothing

Valida que la configuración tenga valores razonables.
Lanza error si hay problemas.
"""
function validate_config(config::Dict)
    # Geometría
    a = config["geometry"]["a"]
    b = config["geometry"]["b"]

    if a <= 0 || b <= 0
        error("Semi-ejes deben ser positivos: a=$a, b=$b")
    end

    if b > a
        @warn "Convencionalmente a ≥ b. Tienes b > a."
    end

    # Simulación
    method = config["simulation"]["method"]
    if !(method in ["adaptive", "fixed"])
        error("Método de simulación debe ser 'adaptive' o 'fixed', no '$method'")
    end

    max_time = config["simulation"]["max_time"]
    if max_time <= 0
        error("max_time debe ser positivo: $max_time")
    end

    # Partículas
    # Compatibilidad: from_file es opcional (configs antiguos pueden no tenerlo)
    has_random = haskey(config["particles"], "random") && config["particles"]["random"]["enabled"]
    has_from_file = haskey(config["particles"], "from_file") && config["particles"]["from_file"]["enabled"]

    if has_random && has_from_file
        error("No puedes habilitar 'random' y 'from_file' simultáneamente")
    end

    if !has_random && !has_from_file
        error("Debes habilitar 'random' o 'from_file' en [particles]")
    end

    println("✅ Configuración válida")
end

# ============================================================================
# LECTURA DE PARTÍCULAS
# ============================================================================

"""
    read_particles_csv(filename::String, a::T, b::T) -> Vector{Particle{T}}

Lee partículas desde archivo CSV y crea vector de Particle.

# Formato del CSV
```
id,mass,radius,theta,theta_dot
1,1.0,0.05,0.0,0.5
2,1.0,0.05,1.57,0.8
...
```

# Argumentos
- `filename`: Ruta al archivo CSV
- `a, b`: Semi-ejes de la elipse (para calcular velocidades)
"""
function read_particles_csv(
    filename::String,
    a::T,
    b::T
) where {T <: AbstractFloat}

    if !isfile(filename)
        error("Archivo de partículas no encontrado: $filename")
    end

    # Leer CSV
    data, header = readdlm(filename, ',', Float64, '\n'; header=true,
                           comments=true, comment_char='#')

    # Verificar columnas
    expected_cols = ["id", "mass", "radius", "theta", "theta_dot"]
    header_str = strip.(String.(header[:]))

    for col in expected_cols
        if !(col in header_str)
            error("Falta columna '$col' en $filename")
        end
    end

    # Crear partículas
    n = size(data, 1)
    particles = Vector{Particle{T}}(undef, n)

    for i in 1:n
        id = Int(data[i, 1])
        mass = T(data[i, 2])
        radius = T(data[i, 3])
        θ = T(data[i, 4])
        θ_dot = T(data[i, 5])

        particles[i] = initialize_particle(id, mass, radius, θ, θ_dot, a, b)
    end

    println("📥 Cargadas $n partículas desde $filename")
    return particles
end

# ============================================================================
# CREACIÓN DE PARTÍCULAS DESDE CONFIG
# ============================================================================

"""
    create_particles_from_config(config::Dict, a::T, b::T) -> Vector{Particle{T}}

Crea partículas según configuración (random o desde archivo).
"""
function create_particles_from_config(
    config::Dict,
    a::T,
    b::T
) where {T <: AbstractFloat}

    particles_config = config["particles"]

    if particles_config["random"]["enabled"]
        # Generación aleatoria
        random_cfg = particles_config["random"]

        n = random_cfg["n_particles"]
        mass = T(random_cfg["mass"])
        radius_frac = T(random_cfg["radius"])
        θ_dot_min = T(random_cfg["theta_dot_min"])
        θ_dot_max = T(random_cfg["theta_dot_max"])

        # RNG con semilla si se especificó
        rng = Random.GLOBAL_RNG
        if haskey(random_cfg, "seed")
            rng = Random.MersenneTwister(random_cfg["seed"])
        end

        println("🎲 Generando $n partículas aleatorias...")
        particles = generate_random_particles(
            n, mass, radius_frac, a, b;
            θ_dot_range = (θ_dot_min, θ_dot_max),
            rng = rng
        )

    elseif haskey(particles_config, "from_file") && particles_config["from_file"]["enabled"]
        # Desde archivo
        filename = particles_config["from_file"]["filename"]
        particles = read_particles_csv(filename, a, b)

    else
        error("No hay método habilitado para crear partículas")
    end

    return particles
end

# ============================================================================
# GUARDADO DE RESULTADOS
# ============================================================================

"""
    create_output_directory(config::Dict) -> String

Crea directorio de salida según configuración y retorna su path.
"""
function create_output_directory(config::Dict)
    output_cfg = config["output"]
    base_dir = output_cfg["base_dir"]

    # Crear directorio base si no existe
    if !isdir(base_dir)
        mkpath(base_dir)
    end

    # Determinar nombre del subdirectorio
    if output_cfg["use_timestamp"]
        timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
        dir_name = "simulation_$timestamp"
    else
        dir_name = output_cfg["custom_name"]
    end

    output_dir = joinpath(base_dir, dir_name)
    mkpath(output_dir)

    println("📁 Directorio de salida: $output_dir")
    return output_dir
end

"""
    save_config_copy(config::Dict, config_file::String, output_dir::String)

Guarda copia del archivo de configuración usado en el directorio de resultados.
"""
function save_config_copy(config::Dict, config_file::String, output_dir::String)
    # Copiar archivo original
    if isfile(config_file)
        dest = joinpath(output_dir, "config_used.toml")
        cp(config_file, dest; force=true)
    end

    # También guardar el diccionario parseado (puede ser útil)
    open(joinpath(output_dir, "config_parsed.toml"), "w") do io
        TOML.print(io, config)
    end
end

"""
    save_particles_csv(particles::Vector{Particle{T}}, filename::String)

Guarda partículas en formato CSV.
"""
function save_particles_csv(
    particles::Vector{Particle{T}},
    filename::String
) where {T <: AbstractFloat}

    open(filename, "w") do io
        # Header
        println(io, "id,mass,radius,theta,theta_dot,x,y,vx,vy")

        # Datos
        for p in particles
            @printf(io, "%d,%.10f,%.10f,%.10f,%.10f,%.10f,%.10f,%.10f,%.10f\n",
                    p.id, p.mass, p.radius, p.θ, p.θ_dot,
                    p.pos[1], p.pos[2], p.vel[1], p.vel[2])
        end
    end
end

"""
    save_trajectories_csv(data::SimulationData{T}, filename::String, a::T, b::T)

Guarda trayectorias completas en CSV con energía individual por partícula.

# Columnas
- time: Tiempo de la simulación
- particle_id: ID de la partícula
- theta: Posición angular (radianes)
- theta_dot: Velocidad angular (rad/s)
- x, y: Posición cartesiana
- vx, vy: Velocidad cartesiana
- energy: Energía cinética individual de la partícula
"""
function save_trajectories_csv(
    data::SimulationData{T},
    filename::String,
    a::T,
    b::T
) where {T <: AbstractFloat}

    open(filename, "w") do io
        # Header con energía
        println(io, "time,particle_id,theta,theta_dot,x,y,vx,vy,energy")

        # Datos
        for (idx, t) in enumerate(data.times)
            particles = data.particles[idx]
            for p in particles
                # Calcular energía individual
                E_particle = kinetic_energy_angular(p.θ_dot, p.θ, a, b, p.mass)

                @printf(io, "%.10f,%d,%.10f,%.10f,%.10f,%.10f,%.10f,%.10f,%.10e\n",
                        t, p.id, p.θ, p.θ_dot, p.pos[1], p.pos[2], p.vel[1], p.vel[2], E_particle)
            end
        end
    end
end

"""
    save_conservation_csv(data::SimulationData{T}, filename::String)

Guarda datos de conservación en CSV.
"""
function save_conservation_csv(
    data::SimulationData{T},
    filename::String
) where {T <: AbstractFloat}

    cons = data.conservation

    open(filename, "w") do io
        println(io, "time,total_energy,conjugate_momentum")

        for i in 1:length(cons.times)
            @printf(io, "%.10f,%.15e,%.15e\n",
                    cons.times[i], cons.energies[i],
                    cons.conjugate_momenta[i])
        end
    end
end

"""
    save_collisions_per_step_csv(data::SimulationData{T}, filename::String)

Guarda información de colisiones por paso de tiempo.

# Columnas
- step: Número de paso
- time: Tiempo de simulación
- n_collisions: Número de colisiones en ese paso
- conserved_fraction: Fracción de colisiones que conservaron energía
- had_collision: 1 si hubo colisiones, 0 si no
"""
function save_collisions_per_step_csv(
    data::SimulationData{T},
    filename::String
) where {T <: AbstractFloat}

    open(filename, "w") do io
        println(io, "step,time,n_collisions,conserved_fraction,had_collision")

        for i in 1:length(data.times)
            n_coll = data.n_collisions[i]
            cons_frac = data.conserved_fractions[i]
            had_coll = n_coll > 0 ? 1 : 0

            @printf(io, "%d,%.10f,%d,%.6f,%d\n",
                    i, data.times[i], n_coll, cons_frac, had_coll)
        end
    end
end

"""
    save_summary_txt(data::SimulationData{T}, config::Dict, filename::String)

Guarda resumen de la simulación en texto plano.
"""
function save_summary_txt(
    data::SimulationData{T},
    config::Dict,
    filename::String
) where {T <: AbstractFloat}

    open(filename, "w") do io
        println(io, "="^70)
        println(io, "RESUMEN DE SIMULACIÓN")
        println(io, "="^70)
        println(io)

        println(io, "Fecha: ", Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))
        println(io)

        # Configuración
        println(io, "CONFIGURACIÓN:")
        println(io, "  Geometría: a = ", config["geometry"]["a"],
                ", b = ", config["geometry"]["b"])
        println(io, "  Método: ", config["simulation"]["method"])
        println(io, "  Tiempo simulado: ", data.times[end], " unidades")
        println(io, "  Partículas: ", length(data.particles[1]))
        println(io)

        # Resultados
        println(io, "RESULTADOS:")
        println(io, "  Pasos de tiempo: ", length(data.times))
        println(io, "  Colisiones totales: ", sum(data.n_collisions))
        println(io)

        # Conservación
        E_analysis = analyze_energy_conservation(data.conservation)
        println(io, "CONSERVACIÓN DE ENERGÍA:")
        @printf(io, "  Energía inicial:  %.10e\n", E_analysis.E_initial)
        @printf(io, "  Energía final:    %.10e\n", E_analysis.E_final)
        @printf(io, "  Error máximo:     %.6e\n", E_analysis.max_rel_error)
        @printf(io, "  Drift relativo:   %.6e\n", E_analysis.rel_drift)
        println(io)

        if E_analysis.max_rel_error < 1e-6
            println(io, "  ✅ EXCELENTE: Error < 1e-6")
        elseif E_analysis.max_rel_error < 1e-4
            println(io, "  ✅ BUENO: Error < 1e-4")
        elseif E_analysis.max_rel_error < 1e-2
            println(io, "  ⚠️  ACEPTABLE: Error < 1e-2")
        else
            println(io, "  ❌ ALTO: Error > 1e-2")
        end
        println(io)

        # Estadísticas de dt (si es adaptativo)
        if haskey(data.parameters, :dt_history)
            dt_hist = data.parameters[:dt_history]
            println(io, "ESTADÍSTICAS DE PASO DE TIEMPO (ADAPTATIVO):")
            @printf(io, "  dt promedio:     %.6e\n", mean(dt_hist))
            @printf(io, "  dt mínimo:       %.6e\n", minimum(dt_hist))
            @printf(io, "  dt máximo:       %.6e\n", maximum(dt_hist))
            @printf(io, "  Valores únicos:  %d\n", length(unique(dt_hist)))
            println(io)
        end

        println(io, "="^70)
    end
end

"""
    save_simulation_results(
        data::SimulationData{T},
        config::Dict,
        config_file::String,
        output_dir::String,
        a::T,
        b::T
    )

Guarda todos los resultados de simulación según configuración.
"""
function save_simulation_results(
    data::SimulationData{T},
    config::Dict,
    config_file::String,
    output_dir::String,
    a::T,
    b::T
) where {T <: AbstractFloat}

    output_cfg = config["output"]

    println()
    println("="^70)
    println("💾 GUARDANDO RESULTADOS")
    println("="^70)

    # Copiar configuración
    if output_cfg["copy_config"]
        save_config_copy(config, config_file, output_dir)
        println("✅ Configuración guardada")
    end

    # Guardar en CSV
    if output_cfg["save_csv"]
        # Partículas iniciales y finales
        if output_cfg["save_initial_final"]
            save_particles_csv(
                data.particles[1],
                joinpath(output_dir, "particles_initial.csv")
            )
            save_particles_csv(
                data.particles[end],
                joinpath(output_dir, "particles_final.csv")
            )
            println("✅ Partículas inicial/final guardadas (CSV)")
        end

        # Trayectorias (ahora con energía individual)
        if output_cfg["save_trajectories"]
            save_trajectories_csv(
                data,
                joinpath(output_dir, "trajectories.csv"),
                a, b
            )
            println("✅ Trayectorias guardadas (CSV) - incluye energía por partícula")
        end

        # Conservación
        if output_cfg["save_conservation"]
            save_conservation_csv(
                data,
                joinpath(output_dir, "conservation.csv")
            )
            println("✅ Datos de conservación guardados (CSV)")
        end

        # Colisiones por paso
        if output_cfg["save_collision_events"]
            save_collisions_per_step_csv(
                data,
                joinpath(output_dir, "collisions_per_step.csv")
            )
            println("✅ Eventos de colisión por paso guardados (CSV)")
        end
    end

    # Guardar resumen
    if output_cfg["save_summary"]
        save_summary_txt(
            data,
            config,
            joinpath(output_dir, "summary.txt")
        )
        println("✅ Resumen guardado (TXT)")
    end

    # Guardar en JLD2 (formato Julia binario, más eficiente)
    if output_cfg["save_jld2"]
        # Esto se implementará si el usuario tiene JLD2 instalado
        @warn "Guardado en JLD2 no implementado aún. Instala JLD2.jl si lo necesitas."
    end

    println("="^70)
    println("✅ Todos los resultados guardados en: $output_dir")
    println("="^70)
end

# Exportar funciones públicas
export read_config, validate_config
export read_particles_csv, create_particles_from_config
export create_output_directory, save_simulation_results
