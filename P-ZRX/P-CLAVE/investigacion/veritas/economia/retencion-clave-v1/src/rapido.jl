#= retencion-clave-v1 · src/rapido.jl
   KERNEL RÁPIDO. Muestreo vectorizado del saldo confiscable y cálculo determinista de las
   magnitudes agregadas del reclutamiento.

   OPERACIÓN DOMINANTE. (a) Muestrear el saldo de una clave: se sortea `N ~ Poisson(θ)` y después
   `N` posiciones uniformes; el saldo normalizado es `Σ_j w_j·conteos[j]` con `w_j = 1 − (j−½)/K`,
   que es exactamente la representación discreta de la referencia. (b) Sobre un vector de `n`
   claves, ordenar por soborno/espacio y acumular: `O(n log n)` tiempo, `O(n)` memoria.

   POR QUÉ ASÍ. (a) es un bucle tipado con `Vector{Int32}` de conteos: la memoria de trabajo es `K`
   enteros y no hay asignaciones por muestra. (b) evita materializar la matriz de claves: SoA
   (`Vector{Float64}` de fracciones y de sobornos) y una sola ordenación.

   RNG. Semilla por réplica NO consecutiva: `hash64(semilla_maestra, id)`, no `semilla_maestra + id`
   (hallazgo de `P-ZRX/P-PUERTA/`: `StableRNG` con semillas consecutivas sesga el Monte Carlo).
   Cada réplica escribe en su propia posición del vector de salida: sin carrera.
=#

module Rapido

using StableRNGs: StableRNG
using SpecialFunctions: erfc
using ..Modelo: Retencion, Vesting, LINEAL, ESCALON, Pareto, masa_prob

export hash64, rng_replica, ponderaciones, muestra_saldo!, muestra_saldos!, saldo_mc,
       cdf_saldo, cola_saldo_normal,
       fraccion_espacio_saldo_cero, fraccion_espacio_saldo_bajo_b, fraccion_claves_saldo_cero,
       vector_sobornos, reclutamiento_eligiendo, reclutamiento_azar, beta_minimo_gratis

# ------------------------------------------------------------------------ RNG

"""`hash64(a, b)`: mezcla determinista (SplitMix64) de dos enteros de 64 bits. Se usa para derivar
la semilla de cada réplica; NO se usa `a + b` porque las semillas consecutivas sesgan el MC."""
@inline function hash64(a::UInt64, b::UInt64)
    z = a + 0x9E3779B97F4A7C15 * b + 0x9E3779B97F4A7C15
    z = (z ⊻ (z >> 30)) * 0xBF58476D1CE4E5B9
    z = (z ⊻ (z >> 27)) * 0x94D049BB133111EB
    return z ⊻ (z >> 31)
end

"""RNG independiente y reproducible para la réplica `id`, derivado de `semilla_maestra` y `id`."""
@inline rng_replica(semilla_maestra::UInt64, id::Integer, etiqueta::UInt64 = UInt64(0)) =
    StableRNG(hash64(semilla_maestra ⊻ etiqueta, UInt64(id)))

"""Pesos de la representación discreta, NORMALIZADOS: `w_j = 1 − (j−½)/K` (lineal) o `1`
(escalón). El saldo es `ρ·I · Σ_j w_j·conteos[j]` — los mismos pesos que la vía de espacios
exponenciales de `referencia.jl`, donde `B = ρI·Σ k E_k/Σ E_j = (ρI/K)·Σ_j w_j n_j`. La
equivalencia se comprueba en `test/runtests.jl`."""
function ponderaciones(K::Int, modo::Vesting)
    w = Vector{Float64}(undef, K)
    @inbounds for j in 1:K
        w[j] = modo == LINEAL ? 1 - (j - 0.5) / K : 1.0
    end
    return w
end

# ---------------------------------------------------------------- muestreador MC

"""Muestrea el saldo confiscable de UNA clave. Escribe en `conteos` (buffer de longitud `K` que se
reutiliza) y devuelve `(saldo_normalizado, N)`: `Σ_j w_j·conteos[j]`, SIN multiplicar por la
escala. El llamante multiplica por `ρ·I/K`."""
function muestra_saldo!(rng, conteos::Vector{Int32}, w::Vector{Float64}, θ::Float64)
    K = length(conteos)
    @inbounds for j in 1:K
        conteos[j] = 0
    end
    N = 0
    if θ > 0
        if θ < 30
            L = exp(-θ)
            p = 1.0
            n = 0
            while true
                n += 1
                p *= rand(rng)
                p <= L && break
                n > 100_000 && break
            end
            N = n - 1
        else
            N = max(0, round(Int, θ + sqrt(θ) * randn(rng)))
        end
    end
    s = 0.0
    @inbounds for _ in 1:N
        j = rand(rng, 1:K)
        conteos[j] += Int32(1)
        s += w[j]
    end
    return (s, N)
end

"""Muestrea `R` réplicas del saldo de una clave y las escribe en `dest[1:R]` (una posición por
réplica, escritura disjunta). Serial. Devuelve `dest` en u.e. (`× ρ·I/K`)."""
function muestra_saldos!(dest::Vector{Float64}, semilla_maestra::UInt64, R::Int,
                         lam::Real, f::Real, ret::Retencion, ingreso::Real;
                         K::Int = 32, modo::Vesting = LINEAL, etiqueta::UInt64 = UInt64(0))
    @assert length(dest) >= R "dest demasiado corto"
    θ = lam * f * ret.Tv
    w = ponderaciones(K, modo)
    escala = ret.rho * ingreso / K
    conteos = Vector{Int32}(undef, K)
    @inbounds for r in 1:R
        rng = rng_replica(semilla_maestra, r, etiqueta)
        s, _ = muestra_saldo!(rng, conteos, w, θ)
        dest[r] = s * escala
    end
    return dest
end

"""Muestreo con hilos. Cada réplica escribe en su propia posición y usa su propio RNG, así que el
resultado es **idéntico** al serial (lo comprueba `test/runtests.jl`). Devuelve `Vector{Float64}`."""
function saldo_mc(semilla_maestra::UInt64, R::Int, lam::Real, f::Real, ret::Retencion,
                  ingreso::Real; K::Int = 32, modo::Vesting = LINEAL, hilos::Bool = true,
                  etiqueta::UInt64 = UInt64(0))
    dest = Vector{Float64}(undef, R)
    if hilos && R >= 4096
        Threads.@threads for r in 1:R
            w = ponderaciones(K, modo)
            conteos = Vector{Int32}(undef, K)
            rng = rng_replica(semilla_maestra, r, etiqueta)
            s, _ = muestra_saldo!(rng, conteos, w, lam * f * ret.Tv)
            dest[r] = s * ret.rho * ingreso
        end
    else
        w = ponderaciones(K, modo)
        conteos = Vector{Int32}(undef, K)
        @inbounds for r in 1:R
            rng = rng_replica(semilla_maestra, r, etiqueta)
            s, _ = muestra_saldo!(rng, conteos, w, lam * f * ret.Tv)
            dest[r] = s * ret.rho * ingreso
        end
    end
    return dest
end

"""CDF empírica en `x`: `(P(B ≤ x), error_estándar)`."""
function cdf_saldo(muestras::AbstractVector{<:Real}, x::Real)
    n = length(muestras)
    k = 0
    @inbounds for v in muestras
        v <= x && (k += 1)
    end
    p = k / n
    return (p, sqrt(max(p * (1 - p), 1e-300) / n))
end

"""Cola normal de contraste `Φ((x−μ)/σ)` con `μ = E[B]` y `σ² = Var[B]` EXACTOS del modelo.
Para medir el error de la normal; no decide ninguna cifra."""
function cola_saldo_normal(lam::Real, f::Real, ret::Retencion, ingreso::Real, x::Real;
                           modo::Vesting = LINEAL)
    θ = lam * f * ret.Tv
    γ = modo == LINEAL ? 0.5 : 1.0
    μ = ret.rho * ingreso * γ * θ
    σ2 = ret.rho^2 * ingreso^2 * (modo == LINEAL ? θ / 3 : θ)
    σ2 <= 0 && return (x >= μ ? 1.0 : 0.0)
    z = (x - μ) / sqrt(σ2)
    return 0.5 * erfc(-z / sqrt(2))
end

# ---------------------------------------------- agregados exactos sobre el espacio

"""Fracción del ESPACIO TOTAL en claves con saldo confiscable «cero»: `M(f*)` con
`f* = ε/(λ·T_v)` (`θ = λ f T_v < ε`). `ε` es el umbral de saldo (u.e.) que se considera cero y se
declara en cada fila que use esta función. No necesita Monte Carlo."""
function fraccion_espacio_saldo_cero(dist::Pareto, lam::Real, ret::Retencion; ε::Real = 0.0)
    (lam <= 0 || ret.Tv <= 0) && return 1.0
    fstar = ε / (lam * ret.Tv)
    return masa_prob(dist, fstar)
end

"""Fracción del espacio en claves cuyo saldo confiscable MEDIO está por debajo de `b` (u.e.)."""
function fraccion_espacio_saldo_bajo_b(dist::Pareto, b::Real, lam::Real, ret::Retencion,
                                       ingreso::Real; modo::Vesting = LINEAL)
    coef = modo == LINEAL ? ret.rho * ingreso * lam * ret.Tv / 2 :
                            ret.rho * ingreso * lam * ret.Tv
    coef <= 0 && return 1.0
    return masa_prob(dist, b / coef)
end

"""Fracción en NÚMERO de claves con saldo cero (`P(f < f*)`), para no confundir las dos medidas."""
function fraccion_claves_saldo_cero(dist::Pareto, lam::Real, ret::Retencion; ε::Real = 0.0)
    (lam <= 0 || ret.Tv <= 0) && return 1.0
    fstar = ε / (lam * ret.Tv)
    fstar <= dist.f_min && return 0.0
    return max(0.0, 1 - (dist.f_min / fstar)^dist.alpha)
end

# ------------------------------------------- reclutamiento: elegir frente a azar

"""Soborno por clave: `min(B_i, b)` con `B_i = coef·f_i` el saldo medio y `0` si `θ_i < ε`.
`b` es el valor del ataque por reclutado (tope de lo que hace falta pagar). SoA."""
function vector_sobornos(fs::AbstractVector{<:Real}, lam::Real, ret::Retencion,
                         ingreso::Real, b::Real; ε::Real = 0.0, modo::Vesting = LINEAL)
    n = length(fs)
    out = Vector{Float64}(undef, n)
    coef = modo == LINEAL ? ret.rho * ingreso * lam * ret.Tv / 2 :
                            ret.rho * ingreso * lam * ret.Tv
    @inbounds for i in 1:n
        θi = lam * fs[i] * ret.Tv
        bi = θi < ε ? 0.0 : coef * fs[i]
        out[i] = min(bi, b)
    end
    return out
end

"""Reclutamiento ELEGIENDO por saldo: ordena por soborno/espacio y acumula hasta juntar `β`.
Devuelve `(coste, espacio, n_claves, suficiente)`."""
function reclutamiento_eligiendo(fs::AbstractVector{<:Real}, sobornos::AbstractVector{<:Real},
                                 β::Real; overhead::Real = 0.0)
    n = length(fs)
    ratios = Vector{Float64}(undef, n)
    @inbounds for i in 1:n
        ratios[i] = (sobornos[i] + overhead) / fs[i]
    end
    perm = sortperm(ratios)
    coste = 0.0
    espacio = 0.0
    k = 0
    @inbounds for i in perm
        espacio >= β && break
        coste += sobornos[i] + overhead
        espacio += fs[i]
        k += 1
    end
    return (coste = coste, espacio = espacio, n_claves = k, suficiente = espacio >= β)
end

"""Reclutamiento AL AZAR (contrafactual de F2): toma las claves en orden de índice sin mirar el
saldo. Devuelve `(coste, espacio, n_claves, suficiente)`."""
function reclutamiento_azar(fs::AbstractVector{<:Real}, sobornos::AbstractVector{<:Real},
                            β::Real; overhead::Real = 0.0)
    coste = 0.0
    espacio = 0.0
    k = 0
    @inbounds for i in eachindex(fs)
        espacio >= β && break
        coste += sobornos[i] + overhead
        espacio += fs[i]
        k += 1
    end
    return (coste = coste, espacio = espacio, n_claves = k, suficiente = espacio >= β)
end

"""Mayor `β` alcanzable a coste CERO: la fracción de espacio en claves de saldo cero."""
function beta_minimo_gratis(dist::Pareto, lam::Real, ret::Retencion; ε::Real = 0.0)
    return fraccion_espacio_saldo_cero(dist, lam, ret; ε = ε)
end

end # module Rapido
