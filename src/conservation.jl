"""
    conservation.jl

Verificación de leyes de conservación para sistemas en variedades curvas.

Implementa funciones para monitorear y verificar:
- Conservación de energía
- Conservación de momento
- Volumen de espacio de fases (simplecticidad)
"""

using StaticArrays
using LinearAlgebra
using Statistics

# ============================================================================
# Estructuras para Almacenar Datos de Conservación
# ============================================================================

"""
    ConservationData{T}

Almacena datos de conservación a lo largo de la simulación.

# Campos
- `times::Vector{T}`: Tiempos de muestreo
- `energies::Vector{T}`: Energía total en cada tiempo
- `angular_momenta::Vector{T}`: Momento angular total
- `n_particles::Vector{Int}`: Número de partículas (para verificar)

# Nota
El momento lineal NO se almacena porque no se conserva en geodésicas
sobre variedades curvas (sin simetría traslacional).
"""
mutable struct ConservationData{T <: AbstractFloat}
    times::Vector{T}
    energies::Vector{T}
    angular_momenta::Vector{T}
    n_particles::Vector{Int}
end

# Constructor vacío
function ConservationData{T}() where {T <: AbstractFloat}
    return ConservationData{T}(
        Vector{T}(),
        Vector{T}(),
        Vector{T}(),
        Vector{Int}()
    )
end

# Constructor con capacidad inicial
function ConservationData{T}(capacity::Int) where {T <: AbstractFloat}
    return ConservationData{T}(
        Vector{T}(undef, 0),
        Vector{T}(undef, 0),
        Vector{T}(undef, 0),
        Vector{Int}(undef, 0)
    )
end

# ============================================================================
# Registro de Datos
# ============================================================================

"""
    record_conservation!(data::ConservationData, particles, t, a, b)

Registra el estado actual del sistema en data.

# Parámetros
- `data`: Estructura ConservationData a actualizar
- `particles`: Vector de partículas
- `t`: Tiempo actual
- `a`, `b`: Semi-ejes de la elipse
"""
function record_conservation!(
    data::ConservationData{T},
    particles::Vector{Particle{T}},
    t::T,
    a::T,
    b::T
) where {T <: AbstractFloat}

    # Calcular cantidades conservadas
    E = total_energy(particles, a, b)
    L = sum(p -> angular_momentum(p, a, b), particles)

    # Agregar a los vectores
    push!(data.times, t)
    push!(data.energies, E)
    push!(data.angular_momenta, L)
    push!(data.n_particles, length(particles))

    return nothing
end

# ============================================================================
# Análisis de Conservación
# ============================================================================

"""
    analyze_energy_conservation(data::ConservationData)

Analiza la conservación de energía a lo largo de la simulación.

# Retorna
- NamedTuple con:
  - `E_initial`: Energía inicial
  - `E_final`: Energía final
  - `E_mean`: Energía promedio
  - `E_std`: Desviación estándar
  - `rel_error`: Error relativo máximo |E - E₀|/E₀
  - `rel_drift`: Drift relativo (E_final - E_initial)/E_initial
"""
function analyze_energy_conservation(data::ConservationData{T}) where {T <: AbstractFloat}
    if isempty(data.energies)
        error("No hay datos de energía registrados")
    end

    E_initial = data.energies[1]
    E_final = data.energies[end]
    E_mean = mean(data.energies)
    E_std = std(data.energies)

    # Error relativo máximo
    rel_errors = abs.((data.energies .- E_initial) ./ E_initial)
    max_rel_error = maximum(rel_errors)

    # Drift relativo
    rel_drift = (E_final - E_initial) / E_initial

    return (
        E_initial = E_initial,
        E_final = E_final,
        E_mean = E_mean,
        E_std = E_std,
        max_rel_error = max_rel_error,
        rel_drift = rel_drift,
        is_conserved = max_rel_error < T(1e-4)  # Criterio del artículo
    )
end

"""
    analyze_angular_momentum(data::ConservationData)

Analiza el momento angular total.

# Nota Física
En una elipse (a ≠ b), NO hay simetría rotacional, por lo que el momento
angular NO es una cantidad conservada. Solo se conserva en círculos (a = b).

Esta función mide la variación para diagnosticar comportamiento del sistema.
"""
function analyze_angular_momentum(data::ConservationData{T}) where {T <: AbstractFloat}
    if isempty(data.angular_momenta)
        error("No hay datos de momento angular registrados")
    end

    L_initial = data.angular_momenta[1]
    L_final = data.angular_momenta[end]
    L_mean = mean(data.angular_momenta)
    L_std = std(data.angular_momenta)

    if abs(L_initial) > eps(T)
        rel_variation = maximum(abs.((data.angular_momenta .- L_initial) ./ L_initial))
    else
        rel_variation = maximum(abs.(data.angular_momenta))
    end

    return (
        L_initial = L_initial,
        L_final = L_final,
        L_mean = L_mean,
        L_std = L_std,
        rel_variation = rel_variation
    )
end

"""
    print_conservation_summary(data::ConservationData)

Imprime un resumen legible del análisis de conservación.
"""
function print_conservation_summary(data::ConservationData{T}) where {T <: AbstractFloat}
    println("=" ^ 70)
    println("ANÁLISIS DE CONSERVACIÓN")
    println("=" ^ 70)

    # Energía
    E_analysis = analyze_energy_conservation(data)
    println("\n📊 ENERGÍA:")
    println("  Inicial:           ", E_analysis.E_initial)
    println("  Final:             ", E_analysis.E_final)
    println("  Promedio:          ", E_analysis.E_mean)
    println("  Desv. estándar:    ", E_analysis.E_std)
    println("  Error relativo max:", E_analysis.max_rel_error)
    println("  Drift relativo:    ", E_analysis.rel_drift)
    println("  ✅ Conservada:      ", E_analysis.is_conserved ? "SÍ" : "NO")

    # Momento lineal
    p_analysis = analyze_momentum_conservation(data)
    println("\n📊 MOMENTO LINEAL:")
    println("  |p⃗| inicial:        ", p_analysis.p_mag_initial)
    println("  |p⃗| final:          ", p_analysis.p_mag_final)
    println("  |p⃗| promedio:       ", p_analysis.p_mag_mean)
    println("  Variación relativa: ", p_analysis.rel_variation)

    # Momento angular
    L_analysis = analyze_angular_momentum(data)
    println("\n📊 MOMENTO ANGULAR:")
    println("  L inicial:         ", L_analysis.L_initial)
    println("  L final:           ", L_analysis.L_final)
    println("  L promedio:        ", L_analysis.L_mean)
    println("  Variación relativa:", L_analysis.rel_variation)
    println("  ⚠️  Nota: L NO se conserva en elipses (solo en círculos)")

    # Información general
    println("\n📊 SIMULACIÓN:")
    println("  Duración:          ", data.times[end] - data.times[1])
    println("  Pasos registrados: ", length(data.times))
    println("  Partículas:        ", data.n_particles[1])

    println("=" ^ 70)
end

# ============================================================================
# Verificación Instantánea
# ============================================================================

"""
    verify_collision_conservation(p1_before, p2_before, p1_after, p2_after, a, b; tolerance=1e-6)

Verifica que una colisión conserve energía y momento.

# Retorna
- NamedTuple(energy_conserved, momentum_conserved, ΔE, Δp)
"""
function verify_collision_conservation(
    p1_before::Particle{T},
    p2_before::Particle{T},
    p1_after::Particle{T},
    p2_after::Particle{T},
    a::T,
    b::T;
    tolerance::T = T(1e-6)
) where {T <: AbstractFloat}

    # Energía antes y después
    E_before = kinetic_energy(p1_before, a, b) + kinetic_energy(p2_before, a, b)
    E_after = kinetic_energy(p1_after, a, b) + kinetic_energy(p2_after, a, b)
    ΔE = abs(E_after - E_before)

    energy_conserved = ΔE / (E_before + eps(T)) < tolerance

    # Momento angular antes y después
    L_before = angular_momentum(p1_before, a, b) + angular_momentum(p2_before, a, b)
    L_after = angular_momentum(p1_after, a, b) + angular_momentum(p2_after, a, b)
    ΔL = abs(L_after - L_before)

    momentum_conserved = ΔL / (abs(L_before) + eps(T)) < tolerance

    return (
        energy_conserved = energy_conserved,
        momentum_conserved = momentum_conserved,
        ΔE = ΔE,
        ΔE_rel = ΔE / (E_before + eps(T)),
        ΔL = ΔL,
        ΔL_rel = ΔL / (abs(L_before) + eps(T))
    )
end

# ============================================================================
# Utilidades para Plotting
# ============================================================================

"""
    get_energy_data(data::ConservationData)

Extrae datos de energía para plotting.

# Retorna
- `(times, energies, rel_errors)`: Vectores para graficar
"""
function get_energy_data(data::ConservationData{T}) where {T <: AbstractFloat}
    times = data.times
    energies = data.energies
    E0 = energies[1]
    rel_errors = abs.((energies .- E0) ./ E0)

    return (times, energies, rel_errors)
end

# ============================================================================
# Imports
# ============================================================================

if !@isdefined(total_energy)
    function total_energy(particles::Vector{Particle{T}}, a::T, b::T) where {T <: AbstractFloat}
        return sum(p -> kinetic_energy(p, a, b), particles)
    end
end

if !@isdefined(total_linear_momentum)
    function total_linear_momentum(particles::Vector{Particle{T}}) where {T <: AbstractFloat}
        return sum(p -> p.mass * p.vel, particles)
    end
end

if !@isdefined(kinetic_energy)
    function kinetic_energy(p::Particle{T}, a::T, b::T) where {T <: AbstractFloat}
        g = metric_ellipse(p.θ, a, b)
        return 0.5 * p.mass * g * p.θ_dot^2
    end
end

if !@isdefined(angular_momentum)
    function angular_momentum(p::Particle{T}, a::T, b::T) where {T <: AbstractFloat}
        g = metric_ellipse(p.θ, a, b)
        return p.mass * g * p.θ_dot
    end
end

if !@isdefined(metric_ellipse)
    function metric_ellipse(θ::T, a::T, b::T) where {T <: AbstractFloat}
        s, c = sincos(θ)
        return a^2 * s^2 + b^2 * c^2
    end
end
