"""
projection_methods.jl

Métodos de proyección para garantizar conservación exacta de cantidades.

Los métodos de proyección corrigen pequeñas desviaciones numéricas en
cantidades conservadas (energía, momento) proyectando el estado sobre
la variedad de conservación.

Referencias:
- Hairer, Lubich, Wanner (2006) "Geometric Numerical Integration"
- Leimkuhler, Reich (2004) "Simulating Hamiltonian Dynamics"
"""

"""
    project_energy!(particles, E_target, a, b; tolerance=1e-12, max_iter=10)

Proyecta el estado de las partículas sobre la superficie de energía constante.

Escala las velocidades angulares para restaurar la energía total a `E_target`.

# Parámetros
- `particles`: Vector de partículas (modificado in-place)
- `E_target`: Energía objetivo (típicamente E₀ del estado inicial)
- `a`, `b`: Semi-ejes de la elipse
- `tolerance`: Tolerancia para convergencia
- `max_iter`: Número máximo de iteraciones Newton

# Algoritmo
1. Calcular energía actual E
2. Si |E - E_target| < tolerance → retornar
3. Calcular factor de escala: λ = sqrt(E_target / E)
4. Escalar velocidades: θ̇ → λ * θ̇
5. Actualizar partículas

# Nota
Este método **no es exactamente físico** (forzamos conservación),
pero es útil para:
- Compensar errores numéricos acumulados
- Garantizar estabilidad en simulaciones largas
- Validar que errores son puramente numéricos (no algorítmicos)

# Ejemplo
```julia
E0 = total_energy(particles, a, b)

# Cada 100 pasos, proyectar sobre energía inicial
if step % 100 == 0
    project_energy!(particles, E0, a, b)
end
```
"""
function project_energy!(
    particles::Vector{Particle{T}},
    E_target::T,
    a::T,
    b::T;
    tolerance::T = T(1e-12),
    max_iter::Int = 10
) where {T <: AbstractFloat}

    # Calcular energía actual
    E_current = zero(T)
    @inbounds for p in particles
        E_current += kinetic_energy_angular(p.φ, p.φ_dot, p.mass, a, b)
    end

    # Verificar si ya estamos dentro de tolerancia
    ΔE = abs(E_current - E_target)
    if ΔE < tolerance
        return (converged=true, iterations=0, final_error=ΔE)
    end

    # Calcular factor de escala para velocidades
    # E ∝ θ̇² → para escalar E: θ̇ → λ θ̇ donde λ = sqrt(E_target / E_current)
    λ = sqrt(E_target / E_current)

    # Escalar velocidades angulares
    @inbounds for i in 1:length(particles)
        p = particles[i]
        φ_dot_new = λ * p.φ_dot
        particles[i] = update_particle(p, p.φ, φ_dot_new, a, b)
    end

    # Verificar convergencia
    E_final = zero(T)
    @inbounds for p in particles
        E_final += kinetic_energy_angular(p.φ, p.φ_dot, p.mass, a, b)
    end

    ΔE_final = abs(E_final - E_target)
    converged = ΔE_final < tolerance

    return (converged=converged, iterations=1, final_error=ΔE_final)
end


"""
    project_momentum!(particles, P_target, a, b; tolerance=1e-12)

Proyecta el estado de las partículas sobre la superficie de momento conjugado constante.

Ajusta las velocidades para restaurar el momento conjugado total.

# Parámetros
- `particles`: Vector de partículas (modificado in-place)
- `P_target`: Momento conjugado objetivo (típicamente P₀ del estado inicial)
- `a`, `b`: Semi-ejes de la elipse
- `tolerance`: Tolerancia para convergencia

# Algoritmo
Para conservar momento: Σᵢ pᵢ = P_target, donde pᵢ = g_θθ(θᵢ) * θ̇ᵢ

Añadimos corrección uniforme a todas las velocidades:
θ̇ᵢ → θ̇ᵢ + δθ̇

donde δθ̇ se calcula para que Σᵢ g_θθ(θᵢ) * (θ̇ᵢ + δθ̇) = P_target
"""
function project_momentum!(
    particles::Vector{Particle{T}},
    P_target::T,
    a::T,
    b::T;
    tolerance::T = T(1e-12)
) where {T <: AbstractFloat}

    # Calcular momento actual
    P_current = zero(T)
    @inbounds for p in particles
        P_current += conjugate_momentum(p, a, b)
    end

    ΔP = P_target - P_current

    # Verificar si ya estamos dentro de tolerancia
    if abs(ΔP) < tolerance
        return (converged=true, final_error=abs(ΔP))
    end

    # Calcular suma de métricas
    sum_g = zero(T)
    @inbounds for p in particles
        g_θθ = metric_ellipse(p.φ, a, b)
        sum_g += g_θθ
    end

    # Corrección uniforme: δθ̇ = ΔP / Σ g_θθ
    δθ_dot = ΔP / sum_g

    # Aplicar corrección
    @inbounds for i in 1:length(particles)
        p = particles[i]
        φ_dot_new = p.φ_dot + δθ_dot
        particles[i] = update_particle(p, p.φ, φ_dot_new, a, b)
    end

    # Verificar convergencia
    P_final = zero(T)
    @inbounds for p in particles
        P_final += conjugate_momentum(p, a, b)
    end

    ΔP_final = abs(P_final - P_target)

    return (converged=ΔP_final < tolerance, final_error=ΔP_final)
end


"""
    project_both!(particles, E_target, P_target, a, b; tolerance=1e-12, max_iter=10)

Proyecta simultáneamente sobre energía y momento conjugado constantes.

Itera entre proyección de energía y momento hasta convergencia.

# Algoritmo
1. Proyectar energía
2. Proyectar momento
3. Repetir hasta que ambos estén dentro de tolerancia

# Nota
La convergencia está garantizada pero puede ser lenta si las
superficies de energía y momento no son aproximadamente ortogonales.
"""
function project_both!(
    particles::Vector{Particle{T}},
    E_target::T,
    P_target::T,
    a::T,
    b::T;
    tolerance::T = T(1e-12),
    max_iter::Int = 10
) where {T <: AbstractFloat}

    for iter in 1:max_iter
        # Proyectar energía
        result_E = project_energy!(particles, E_target, a, b; tolerance=tolerance, max_iter=1)

        # Proyectar momento
        result_P = project_momentum!(particles, P_target, a, b; tolerance=tolerance)

        # Verificar convergencia conjunta
        if result_E.converged && result_P.converged
            return (converged=true, iterations=iter,
                   energy_error=result_E.final_error,
                   momentum_error=result_P.final_error)
        end
    end

    # No convergió
    E_final = sum(kinetic_energy_angular(p.φ, p.φ_dot, p.mass, a, b) for p in particles)
    P_final = sum(conjugate_momentum(p, a, b) for p in particles)

    return (converged=false, iterations=max_iter,
           energy_error=abs(E_final - E_target),
           momentum_error=abs(P_final - P_target))
end


"""
    compute_conservation_errors(particles, E0, P0, a, b)

Calcula errores relativos en conservación de energía y momento.

# Retorna
- `ΔE_rel`: Error relativo de energía |E - E₀| / |E₀|
- `ΔP_rel`: Error relativo de momento |P - P₀| / |P₀|
"""
function compute_conservation_errors(
    particles::Vector{Particle{T}},
    E0::T,
    P0::T,
    a::T,
    b::T
) where {T <: AbstractFloat}

    E = sum(kinetic_energy_angular(p.φ, p.φ_dot, p.mass, a, b) for p in particles)
    P = sum(conjugate_momentum(p, a, b) for p in particles)

    ΔE_rel = abs(E - E0) / abs(E0)
    ΔP_rel = abs(P - P0) / abs(P0)

    return (ΔE_rel=ΔE_rel, ΔP_rel=ΔP_rel, E=E, P=P)
end
