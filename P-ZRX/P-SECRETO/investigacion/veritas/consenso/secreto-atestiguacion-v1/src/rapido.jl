# rapido.jl — kernels Float64/BigFloat tipoestables, sin asignaciones en el bucle caliente
# Toda decisión de veredicto se certifica aparte (referencia.jl, Arblib, convolución, MC).

using Random
using Random123
using SpecialFunctions

const MEDIANA_ENLACE_R = 0.080
const P99_ENLACE_R = 0.500
const Z99_R = 2.326347874040841

"""splitmix64 (semillas NO consecutivas por réplica: hallazgo P-ZRX/P-PUERTA §5, defecto 4)."""
function splitmix64(x::UInt64, round::Int)::UInt64
    z = x + UInt64(0x9E3779B97F4A7C15) * UInt64(round)
    z = (z ⊻ (z >> 30)) * UInt64(0xBF58476D1CE4E5B9)
    z = (z ⊻ (z >> 27)) * UInt64(0x94D049BB133111EB)
    return z ⊻ (z >> 31)
end

"""μ, σ de la lognormal del enlace (derivación exacta de mediana y p99)."""
function parametros_enlace_r()::Tuple{Float64,Float64}
    μ = log(MEDIANA_ENLACE_R)
    σ = (log(P99_ENLACE_R) - μ) / Z99_R
    return (μ, σ)
end

"""CDF lognormal del enlace en Float64."""
function cdf_enlace(t::Float64)::Float64
    μ, σ = parametros_enlace_r()
    return 0.5 * (1.0 + erf((log(t) - μ) / (σ * sqrt(2.0))))
end

"""P(cabe) multihop por convolución iterada (ruta numérica independiente del MC):
T_col = Σ de 2h enlaces lognormales iid (tramo de ida y de vuelta, h saltos cada uno)
+ t_sign; con k firmantes en paralelo, P(cabe) = F_suma(W − t_sign)^k."""
function p_cabe_multihop_conv(τ::Float64, Δ::Float64, k::Int, h::Int, t_sign::Float64)::Float64
    W = τ - Δ
    p1 = p_cabe_conv(W, 2 * h, t_sign)
    return p1^k
end

"""Monte Carlo del mismo evento (ruta independiente de la convolución).
RNG Philox4x por réplica con semillas NO consecutivas (splitmix64).
Devuelve (estimación, lo, hi) con IC de Wilson al 99 %."""
function mc_p_cabe(τ::Float64, Δ::Float64, k::Int, h::Int, t_sign::Float64,
                   n::Int, semilla::UInt64)::Tuple{Float64,Float64,Float64}
    μ, σ = parametros_enlace_r()
    W = τ - Δ
    exitos = 0
    for i in 1:n
        rng = Philox4x((splitmix64(semilla, 2i - 1), splitmix64(semilla, 2i)))
        cabe = true
        for _ in 1:k
            t = t_sign
            for _ in 1:(2h)
                u = (rand(rng, UInt64) >> 11) / (Float64(typemax(UInt64) >> 11) + 1.0)
                u = min(u, 1.0 - eps(Float64))   # u ∈ [0, 1); evita erfcinv(0) = +Inf
                t += exp(μ + σ * sqrt(2.0) * erfcinv(2.0 * (1.0 - u)))
            end
            t > W && (cabe = false; break)
        end
        cabe && (exitos += 1)
    end
    p = exitos / n
    z = 2.575829
    den = 1.0 + z^2 / n
    c = p + z^2 / (2n)
    m = z * sqrt(p * (1 - p) / n + z^2 / (4n^2))
    return (p, (c - m) / den, (c + m) / den)
end

"""log10 de P(ninguna fuga en la cadena de d bloques), evaluación BigFloat del
valor exacto (α + (1−α)·p_sil)^(k·d). Sin subdesbordamiento: se publica log10."""
function log10_p_no_fuga(α::Float64, p_sil::Float64, k::Int, d::Int)::BigFloat
    base = BigFloat(α) + (1 - BigFloat(α)) * BigFloat(p_sil)
    return BigFloat(k) * BigFloat(d) * log10(base)
end
