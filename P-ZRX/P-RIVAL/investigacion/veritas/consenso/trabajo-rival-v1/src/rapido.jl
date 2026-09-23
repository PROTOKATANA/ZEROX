# src/rapido.jl — kernels tipoestables (Float64) para rejillas y benchmarks, y
# el modelo de coste.  NINGUNA frontera se decide con Float64: ver src/modelo.jl.

# ---------------------------------------------------------------------------
# Kernels de rejilla (tipoestables, sin asignaciones, sin globals dinámicos)
# ---------------------------------------------------------------------------
@inline function alpha_aditivo_f64(β_d::Float64, β_x::Float64, θ::Float64, ρ::Float64)
    θ == 1.0 && return NaN
    (1.0 - β_d - 2.0 * β_x - θ * (ρ - 1.0) / (1.0 - θ)) / 2.0
end

@inline function g_aditivo_f64(α::Float64, β_d::Float64, β_x::Float64, θ::Float64, ρ::Float64)
    (1.0 - θ) * (2.0 * α + β_d + 2.0 * β_x - 1.0) + θ * (ρ - 1.0)
end

@inline ventaja_marginal_f64(θ::Float64, c::Float64) = 1.0 - θ + θ * c

# Rejilla de α* sobre un vector de β_d; escribe en destino preasignado.
function rejilla_alpha!(dest::Vector{Float64}, β_d::Vector{Float64},
                        β_x::Float64, θ::Float64, ρ::Float64)
    @inbounds for i in eachindex(β_d, dest)
        dest[i] = alpha_aditivo_f64(β_d[i], β_x, θ, ρ)
    end
    return dest
end

# ---------------------------------------------------------------------------
# Umbral de cierre MARGINAL (seguridad): θ tal que ∂(ventaja)/∂β_d ≤ 0.
#   ventaja_marginal(θ,c) = 1 + θ(c−1) ≥ 0 para todo θ∈[0,1) y c ≥ 0.
#   ⇒ no existe θ < 1 que la anule; sólo c = 0 y θ = 1 dan exactamente 0.
# Devuelve `missing` cuando no existe en [0,1).
# ---------------------------------------------------------------------------
function theta_estrella_marginal(c::R)
    m(θ) = ventaja_marginal_aditiva(θ, c)
    m(R(0)) > 0 || return R(0)
    m(R(1)) > 0 && return missing        # nunca ≤ 0 en [0,1)
    # único caso: c = 0 y θ = 1
    return R(1)
end

# ---------------------------------------------------------------------------
# Cierre ECONÓMICO (el granjero no gana con duplicar): distinto del de seguridad.
#   ganancia_neta(θ) = (1−θ) − c·(p_v − θ)   con p_v = precio del trabajo / valor del peso
#   cierra ⟺ ganancia_neta ≤ 0.
# ---------------------------------------------------------------------------
function cierra_economico(θ::R, c::R, p_v::R)
    return (1 - θ) - c * (p_v - θ) <= 0
end
function theta_estrella_economico(c::R, p_v::R)
    # (1−θ) ≤ c(p_v−θ)  ⟺  θ(c−1) ≤ c·p_v − 1 =: rhs
    # Devuelve el MÍNIMO θ∈[0,1] a partir del cual cierra, o `missing` si no cierra en [0,1).
    rhs = c * p_v - 1
    if c == 1
        return rhs >= 0 ? R(0) : missing          # cierra para todo θ si p_v ≥ 1
    elseif c > 1
        t = rhs / (c - 1)                          # cierra para θ ≤ t
        t < 0 && return missing                    # no cierra para ningún θ ≥ 0
        return R(0)                                # cierra en [0, min(t,1)] ⇒ desde 0
    else
        t = rhs / (c - 1)                          # cierra para θ ≥ t (denominador negativo)
        t <= 0 && return R(0)
        t > 1 && return missing
        return t
    end
end

# ---------------------------------------------------------------------------
# Modelo de coste (F5).  Todas las entradas son símbolos con unidad declarada.
#
#   N        espacio de la red, en GiB
#   C        piezas por GiB (≙ peso de espacio por bloque ≈ N·C, C-GD-01)
#   λ        bloques por segundo (nominal 1)
#   θ        fracción de peso del trabajo rival
#   e_hash   julios por hash (estimado; el repo mide blake3, no julios)
#   t_plot   segundos de ploteo por GiB (medido: 83,608 s/GiB CPU 32 hilos)
#   P_plot   vatios de la CPU durante el ploteo (supuesto)
#   T_vida   vida del plot en segundos (supuesto)
# ---------------------------------------------------------------------------
hashes_por_bloque(θ::Float64, N::Float64, C::Float64) = θ / (1.0 - θ) * N * C
tasa_hash_red(θ::Float64, N::Float64, C::Float64, λ::Float64) = λ * hashes_por_bloque(θ, N, C)
vatios_pow(θ::Float64, N::Float64, C::Float64, λ::Float64, e_hash::Float64) =
    tasa_hash_red(θ, N, C, λ) * e_hash
vatios_espacio(N::Float64, t_plot::Float64, P_plot::Float64, T_vida::Float64) =
    N * t_plot * P_plot / T_vida
coste_relativo(θ::Float64, N::Float64, C::Float64, λ::Float64, e_hash::Float64,
               t_plot::Float64, P_plot::Float64, T_vida::Float64) =
    vatios_pow(θ, N, C, λ, e_hash) / vatios_espacio(N, t_plot, P_plot, T_vida)
nucleos_necesarios(tasa::Float64, h_por_nucleo::Float64) = tasa / h_por_nucleo
