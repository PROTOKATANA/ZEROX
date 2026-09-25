# modelo.jl — tipos, parámetros, rejilla y utilidades numéricas (T02).
#
# Convenciones comunes de CORRECCION-T02-A:
#  - Tiempo en unidades de T_pow. Bloques PoW: Poisson, honesto tasa (1-h), adversario h.
#  - Fase PoST de una rama arranca cuando existe su terminal; slot j>=1 en t_rama + j*r.
#    Honesto gana un bloque de peso 1 con prob (1-a)*p; adversario con prob a*p.
#  - Empates: la métrica principal usa >= (adversario gana el empate); además se reporta >.
#  - Horizonte: M slots contados desde t_H; si el adversario no ha ganado, abandona.
#
# Este módulo no usa Float64 para decidir reglas discretas más allá de las cotas
# probabilísticas del propio modelo analítico (LINEO §5.3).

module Modelo

using StableRNGs
using Random

# ---------------------------------------------------------------------------
# Rejilla de valores de prueba (ORDEN-T02 §3.6 + CORRECCION-T02-A)
# ---------------------------------------------------------------------------
const H_GRID     = (0.1, 0.25, 0.4, 0.5, 0.6, 0.9)
const A_GRID     = (0.1, 0.25, 0.4, 0.45, 0.5, 0.55)
const K_GRID     = (1, 3, 6, 12)
const Z_GRID     = (0, 1, 3, 6)
const R_GRID     = (1/60, 1/10, 1.0)
const P_GRID     = (0.5, 0.9)
const F_GRID     = (100.0, 1000.0, 10000.0, Inf)   # F_slots; Inf = sin cota
const DELTA_GRID = (0.01, 0.1)
const MDEP_GRID  = (1, 3, 6, 12)

# Horizonte M (en slots) según la corrección.
horizonte(Fs::Float64) = isinf(Fs) ? 100_000 : 10 * Int(Fs)

# ---------------------------------------------------------------------------
# Punto de la rejilla por escenario
# ---------------------------------------------------------------------------
struct PuntoE1
    id::Int
    h::Float64
    z::Int
end

struct PuntoE2
    id::Int
    h::Float64
    a::Float64
    k::Int
    r::Float64
    p::Float64
    Fs::Float64
end

struct PuntoE3
    id::Int
    h::Float64
    a::Float64
    k::Int
    delta::Float64
    r::Float64
    p::Float64
    Fs::Float64
end

struct PuntoE4
    id::Int
    h::Float64
    Mdep::Int
end

# ---------------------------------------------------------------------------
# RNG por (semilla maestra, escenario, punto, réplica) — LINEO §7
# ---------------------------------------------------------------------------
@inline function splitmix64(x::UInt64)
    x += 0x9e3779b97f4a7c15
    z = x
    z = (z ⊻ (z >> 30)) * 0xbf58476d1ce4e5b9
    z = (z ⊻ (z >> 27)) * 0x94d049bb133111eb
    return z ⊻ (z >> 31)
end

@inline function semilla_replica(master::UInt64, esc::Int, punto::Int, rep::Int)
    x = master ⊻ (UInt64(esc) * 0x9e3779b97f4a7c15) ⊻
        (UInt64(punto) * 0xc2b2ae3d27d4eb4f) ⊻
        (UInt64(rep) * 0x165667b19e3779f9)
    return splitmix64(x)
end

rng_replica(master::UInt64, esc::Int, punto::Int, rep::Int) =
    StableRNG(semilla_replica(master, esc, punto, rep))

# ---------------------------------------------------------------------------
# Intervalo de confianza de Wilson para una proporción (99,9 % por defecto).
# z_{0.9995} = 3.290527...  (dos colas al 99,9 %)
# ---------------------------------------------------------------------------
const Z999 = 3.2905270624683875

function wilson(k::Integer, n::Integer; z::Float64 = Z999)
    n == 0 && return (NaN, NaN, NaN)
    p̂ = k / n
    z2 = z * z
    denom = 1 + z2 / n
    centro = (p̂ + z2 / (2n)) / denom
    medio = (z / denom) * sqrt(p̂ * (1 - p̂) / n + z2 / (4n^2))
    return (p̂, max(0.0, centro - medio), min(1.0, centro + medio))
end

# ---------------------------------------------------------------------------
# Muestreo exacto de Gamma(forma entera k, tasa λ) como suma de k Exponenciales.
#   t = (Σ_{i=1..k} -log U_i) / λ,  U_i ~ U(0,1).
# ---------------------------------------------------------------------------
@inline function gamma_erlang!(rng::AbstractRNG, k::Int, λ::Float64)
    s = 0.0
    @inbounds for _ in 1:k
        s += -log(rand(rng))
    end
    return s / λ
end

# ---------------------------------------------------------------------------
# PMF de Poisson (estable por recurrencia) y CDF por cola finita.
# ---------------------------------------------------------------------------
function poisson_pmf(λ::Float64, kmax::Int)
    v = Vector{Float64}(undef, kmax + 1)
    v[1] = exp(-λ)
    @inbounds for k in 1:kmax
        v[k+1] = v[k] * λ / k
    end
    return v
end

export H_GRID, A_GRID, K_GRID, Z_GRID, R_GRID, P_GRID, F_GRID, DELTA_GRID, MDEP_GRID,
    horizonte, PuntoE1, PuntoE2, PuntoE3, PuntoE4,
    splitmix64, semilla_replica, rng_replica, Z999, wilson, gamma_erlang!, poisson_pmf

end # module

