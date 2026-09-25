# rapido.jl — simuladores Monte Carlo (T02).
#
# Todos los núcleos son funciones puras sobre un RNG por réplica (LINEO §7):
# ninguna mutación compartida; las réplicas se reparten con `Threads.@threads`
# escribiendo posiciones disjuntas y la reducción se hace en orden de réplica.

module Rapido

using Random
using Distributions
using ..Modelo
using ..Referencia

# ===========================================================================
# E1 · control de Nakamoto
#
# El artículo fija el tiempo que el honesto tarda en minar z bloques en su
# *valor medio* z/p y modela los bloques del adversario en ese intervalo como
# Poisson(λ = z·q/p).  Por eso X se muestrea Poisson(λ) (no la binomial negativa
# del proceso embebido).  A partir de ahí, la captura desde el déficit z−X es la
# ruina del jugador con probabilidad (q/p)^{z−X}.
const CAP_E1 = 500

# Muestreo de Poisson por el método de Knuth (λ moderado en esta rejilla).
@inline function rand_poisson!(rng::AbstractRNG, λ::Float64)
    L = exp(-λ)
    k = 0
    prod = rand(rng)
    @inbounds while prod > L
        k += 1
        prod *= rand(rng)
    end
    return k
end

@inline function e1_replica!(rng::AbstractRNG, z::Int, h::Float64)
    z == 0 && return true
    p = 1 - h
    h >= p && return true
    x = rand_poisson!(rng, z * h / p)
    x >= z && return true
    d = z - x
    @inbounds while d > 0
        if rand(rng) < h
            d -= 1
        else
            d += 1
        end
        d > CAP_E1 && return false
    end
    return true
end

function correr_e1!(exito::Vector{Bool}, pt::PuntoE1, nrep::Int, master::UInt64)
    Threads.@threads for rep in 1:nrep
        rng = rng_replica(master, 1, pt.id, rep)
        exito[rep] = e1_replica!(rng, pt.z, pt.h)
    end
    return count(exito)
end

# ===========================================================================
# E2 · terminal alternativo privado + espacio
# ===========================================================================
# Éxito (>=) y estricto (>) para nodo nuevo y nodo en línea; instante de éxito
# en slots desde t_H y bloques PoW privados minados.
const DCAP_E2 = 300

# Estado honesto tras m slots PoST: (nº de bloques, slot del último bloque).
# O(1) por geométrica: P(nº fallos finales = t) = (1-α)^t α.
@inline function estado_honesto!(rng::AbstractRNG, m::Int, α::Float64)
    m <= 0 && return (0, 0)
    l1 = log1p(-α)
    u = rand(rng)
    if u <= exp(m * l1)             # ningún bloque en los m slots
        return (0, 0)
    end
    T = floor(Int, log(u) / l1)     # fallos finales; T < m
    dlast = m - T
    wh = 1 + (dlast > 1 ? rand(rng, Binomial(dlast - 1, α)) : 0)
    return (wh, dlast)
end

@inline function e2_replica!(rng::AbstractRNG, h::Float64, a::Float64, k::Int,
                             r::Float64, p::Float64, Fs::Float64, M::Int)
    th = gamma_erlang!(rng, k, 1 - h)
    horizonT = th + M * r

    # Bloques PoW privados hasta k o hasta el horizonte.
    ta = 0.0
    na = 0
    @inbounds while na < k
        ta += -log(rand(rng)) / h
        ta > horizonT && return (false, false, false, false, NaN, na)
        na += 1
    end

    α = (1 - a) * p
    β = a * p
    ge = false; ge_on = false; gt = false; gt_on = false
    slots_ge = NaN

    if ta <= th
        # En t_A no existe aún bloque PoST honesto: empate; gana el adversario (>=).
        ge = true
        ge_on = (0.0 < Fs)
        slots_ge = 0.0                    # el éxito precede a t_H: 0 slots desde t_H
        WH = 0; WA = 0; D = 0; dlast = 0
        jH = 1
        tHn = th + r
        tAn = ta + r
    else
        m = floor(Int, (ta - th) / r)
        m >= M && return (false, false, false, false, NaN, k)   # horizonte agotado
        WH0, dl0 = estado_honesto!(rng, m, α)
        WH = WH0; dlast = dl0; WA = 0; D = WH
        if WH == 0
            ge = true; ge_on = (0.0 < Fs); slots_ge = (ta - th) / r
        end
        jH = m + 1
        tHn = th + jH * r
        tAn = ta + r
    end

    if a < 0.5 && D > DCAP_E2
        return (ge, ge_on, false, false, slots_ge, k)
    end

    @inbounds while true
        tnext = min(tHn, tAn)
        tnext > horizonT && break
        if tHn <= tAn
            if rand(rng) < α
                WH += 1; D += 1; dlast = jH
            end
            jH += 1
            tHn = th + jH * r
        else
            if rand(rng) < β
                WA += 1; D -= 1
            end
            if !ge && WA >= WH
                ge = true; ge_on = (dlast < Fs); slots_ge = (tnext - th) / r
            end
            if !gt && WA > WH
                gt = true; gt_on = (dlast < Fs)
                break
            end
            tAn += r
        end
        if a < 0.5 && D > DCAP_E2
            break
        end
    end
    return (ge, ge_on, gt, gt_on, slots_ge, k)
end

struct ResE2
    n::Int
    ge_nuevo::Int
    ge_online::Int
    gt_nuevo::Int
    gt_online::Int
    pow_medio::Float64
    slots_ge::Vector{Float64}
    slots_gt::Vector{Float64}
end

function correr_e2(pt::PuntoE2, nrep::Int, master::UInt64)
    gn = zeros(Int, nrep); go = zeros(Int, nrep)
    tn = zeros(Int, nrep); to = zeros(Int, nrep)
    pw = zeros(Int, nrep)
    sl = fill(NaN, nrep); st = fill(NaN, nrep)
    M = horizonte(pt.Fs)
    Threads.@threads for rep in 1:nrep
        rng = rng_replica(master, 2, pt.id, rep)
        gn[rep], go[rep], tn[rep], to[rep], sl[rep], pw[rep] =
            e2_replica!(rng, pt.h, pt.a, pt.k, pt.r, pt.p, pt.Fs, M)
        if tn[rep] != 0
            st[rep] = sl[rep]
        end
    end
    return ResE2(nrep, sum(gn), sum(go), sum(tn), sum(to),
                 sum(pw) / nrep,
                 filter(!isnan, sl), filter(!isnan, st))
end

# ===========================================================================
# E3 · rama PoW tardía más pesada (efecto hash aislado)
# ===========================================================================
# FC-1: partición entre nodos viejos (no cambian si d >= F_slots) y nuevos (sí).
# FC-3: gana solo mientras W_H = 0.
@inline function e3_replica!(rng::AbstractRNG, h::Float64, a::Float64, k::Int,
                             delta::Float64, r::Float64, p::Float64, Fs::Float64)
    rate = h / (1 + delta)
    ta = gamma_erlang!(rng, k, rate)
    n = floor(Int, ta / r)
    α = (1 - a) * p
    part = false
    if !isinf(Fs) && n >= Fs
        cnt = rand(rng, Binomial(n - Int(Fs) + 1, α))
        part = cnt > 0
    end
    fc3 = true
    if n > 0
        fc3 = rand(rng, Binomial(n, α)) == 0
    end
    return (part, fc3, ta)
end

struct ResE3
    n::Int
    fc1_part::Int      # en línea NO cambia y nuevo SÍ
    fc3::Int
    ta_medio::Float64
end

function correr_e3(pt::PuntoE3, nrep::Int, master::UInt64)
    part = zeros(Int, nrep); f3 = zeros(Int, nrep); ta = zeros(Float64, nrep)
    Threads.@threads for rep in 1:nrep
        rng = rng_replica(master, 3, pt.id, rep)
        part[rep], f3[rep], ta[rep] =
            e3_replica!(rng, pt.h, pt.a, pt.k, pt.delta, pt.r, pt.p, pt.Fs)
    end
    return ResE3(nrep, sum(part), sum(f3), sum(ta) / nrep)
end

# ===========================================================================
# E4 · censura de depósitos
# ===========================================================================
const HORIZONTE_E4 = 10_000.0   # T_pow

@inline function e4_replica!(rng::AbstractRNG, h::Float64, Mdep::Int, horizonteT::Float64)
    t = 0.0
    sel = 0
    adv_sel = 0
    dep_b = 0
    priv = 0
    @inbounds while t < horizonteT
        if dep_b == 0
            t += -log(rand(rng)) / (1 - h)
            t >= horizonteT && break
            sel += 1
            dep_b = sel
            priv = sel - 1
        else
            dth = -log(rand(rng)) / (1 - h)
            dta = -log(rand(rng)) / h
            if dth < dta
                t += dth
                t >= horizonteT && break
                sel += 1
                if sel >= dep_b + Mdep
                    return (true, t, adv_sel / sel)
                end
            else
                t += dta
                t >= horizonteT && break
                priv += 1
                if priv > sel
                    adv_sel += priv - (dep_b - 1)
                    sel = priv
                    dep_b = 0
                end
            end
        end
    end
    return (false, horizonteT, sel == 0 ? 0.0 : adv_sel / sel)
end

struct ResE4
    n::Int
    cortes::Int
    t_corte::Vector{Float64}
    frac_adv::Vector{Float64}
end

function correr_e4(pt::PuntoE4, nrep::Int, master::UInt64)
    cort = zeros(Bool, nrep)
    tc = fill(NaN, nrep)
    fr = fill(NaN, nrep)
    Threads.@threads for rep in 1:nrep
        rng = rng_replica(master, 4, pt.id, rep)
        c, t, f = e4_replica!(rng, pt.h, pt.Mdep, HORIZONTE_E4)
        cort[rep] = c
        if c
            tc[rep] = t
            fr[rep] = f
        end
    end
    return ResE4(nrep, count(cort), filter(!isnan, tc), filter(!isnan, fr))
end

export e1_replica!, correr_e1!, e2_replica!, correr_e2, ResE2,
    e3_replica!, correr_e3, ResE3, e4_replica!, correr_e4, ResE4,
    CAP_E1, DCAP_E2, HORIZONTE_E4

end # module
