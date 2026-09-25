# referencia.jl — oráculo: fórmulas cerradas y simulador transparente (T02).
#
# Fuentes primarias:
#  - Nakamoto, *Bitcoin: A Peer-to-Peer Electronic Cash System*, §11 (tabla y fórmula).
#  - CORRECCION-T02-A para E1, E2, E3, E4.

module Referencia

using SpecialFunctions
using Distributions
using Random
using ..Modelo

# ===========================================================================
# E1 · control de Nakamoto (sin corte, sin k)
# ===========================================================================
# P(z) = 1 - Σ_{k=0}^{z} (λ^k e^{-λ}/k!)(1 - (q/p)^{z-k}),  λ = z·q/p, q=h, p=1-h.
# Para q >= p la captura es segura (Q_z = 1).  La fórmula de Nakamoto presupone q<p.
function e1_prob(z::Int, h::Float64)
    z < 0 && throw(ArgumentError("z debe ser >= 0"))
    z == 0 && return 1.0
    p = 1 - h
    h >= p && return 1.0
    λ = z * h / p
    r = h / p
    pm = poisson_pmf(λ, z)          # pm[k+1] = e^{-λ} λ^k / k!
    tail = 0.0
    @inbounds for k in 0:z
        tail += pm[k+1] * (1 - r^(z - k))
    end
    return 1 - tail
end

# Tabla publicada por Nakamoto §11.  Para q=0,1 el artículo tabula z=0…10;
# para q=0,3 tabula z=0,5,10,…,50 (no 1..4 ni 6..9).
const TABLA_NAKAMOTO = Tuple{Float64,Int,Float64}[
    (0.1, 0, 1.0000000), (0.1, 1, 0.2045873), (0.1, 2, 0.0509779),
    (0.1, 3, 0.0131722), (0.1, 4, 0.0034552), (0.1, 5, 0.0009137),
    (0.1, 6, 0.0002428), (0.1, 7, 0.0000647), (0.1, 8, 0.0000173),
    (0.1, 9, 0.0000046), (0.1, 10, 0.0000012),
    (0.3, 0, 1.0000000), (0.3, 5, 0.1773523), (0.3, 10, 0.0416605),
    (0.3, 15, 0.0101008), (0.3, 20, 0.0024804), (0.3, 25, 0.0006132),
    (0.3, 30, 0.0001522), (0.3, 35, 0.0000379), (0.3, 40, 0.0000095),
    (0.3, 45, 0.0000024), (0.3, 50, 0.0000006),
]

# ===========================================================================
# E2 · terminal alternativo privado + espacio
# ===========================================================================
# Probabilidad exacta de éxito de un nodo que sincroniza desde cero cuando NO
# hay horizonte (M = ∞) y a < 1/2.  Es el oráculo de validación del MC.
#
#   P = P(t_A <= t_H) + E[ γ^{floor((t_A - t_H)/r)} · 1{t_A > t_H} ],
#   γ = (1-α)/(1-β),  α = (1-a)p,  β = a p.
#
# La esperanza se calcula por cuadratura de Simpson sobre u = t_H y suma sobre
# las bandas m del retardo τ = t_A - t_H.
function e2_prob_sin_horizonte(h::Float64, a::Float64, k::Int, r::Float64, p::Float64)
    α = (1 - a) * p
    β = a * p
    # P(t_A <= t_H) para dos Gamma(k) independientes (carrera binomial negativa).
    pfirst = 0.0
    for i in k:(2k - 1)
        pfirst += binomial(2k - 1, i) * h^i * (1 - h)^(2k - 1 - i)
    end
    a >= 0.5 && return 1.0   # con a>=1/2 la absorción es segura
    γ = (1 - α) / (1 - β)

    dH = Gamma(k, (1 - h)^(-1))   # t_H ~ Gamma(forma k, escala 1/(1-h))
    dA = Gamma(k, h^(-1))         # t_A ~ Gamma(forma k, escala 1/h)

    # Rango de integración: hasta el cuantil 1-1e-14 de t_H.
    T = quantile(dH, 1 - 1e-14)
    T = min(T, 1e6)
    # Cuántas bandas m hacen falta: γ^m < 1e-15.
    mmax = γ <= 0 ? 0 : min(5000, ceil(Int, log(1e-15) / log(γ)))
    mmax = max(mmax, 1)

    integrand(u) = begin
        fh = pdf(dH, u)
        fh == 0 && return 0.0
        s = 0.0
        w = 1.0
        cprev = cdf(dA, u)           # F_A(u + 0)
        for m in 0:mmax
            cnext = cdf(dA, u + (m + 1) * r)
            s += w * (cnext - cprev)
            cprev = cnext
            w *= γ
            w < 1e-16 && break
        end
        return fh * s
    end

    n = 4000
    hstep = T / n
    acc = integrand(1e-12) + integrand(T)
    for i in 1:(n-1)
        u = i * hstep
        acc += (isodd(i) ? 4 : 2) * integrand(u)
    end
    E = acc * hstep / 3
    return pfirst + E
end

# ===========================================================================
# E3 · rama PoW tardía con más trabajo por bloque (abstracción de dificultad)
# ===========================================================================
const E3_BASE = (h = 0.3, a = 0.4, k = 6, delta = 0.1, r = 1/10, p = 0.9, Fs = 1000.0)

function e3_distribucion_tA(h::Float64, k::Int, delta::Float64, r::Float64; nmax::Int = 0)
    rate = h / (1 + delta)
    dA = Gamma(k, 1 / rate)          # t_A ~ Gamma(forma k, escala (1+δ)/h)
    # Techo: cuantil 1-1e-14, o el punto donde (1-α)^n es despreciable.
    T = quantile(dA, 1 - 1e-14)
    N = max(ceil(Int, T / r), nmax, 64)
    return dA, N
end

# FC-1: el adversario publica su terminal con más trabajo.  El nodo nuevo
# cambia siempre; el nodo en línea solo si d < F_slots (d = slot del último
# bloque PoST honesto; 0 si no hay ninguno).  Se reporta la partición:
#   P(en línea NO cambia y nuevo SÍ) = P(d >= F_slots).
function e3_prob_fc1(h::Float64, a::Float64, k::Int, delta::Float64, r::Float64,
                     p::Float64, Fs::Float64)
    (isinf(Fs)) && return 0.0     # d < ∞ siempre ⇒ el nodo en línea cambia
    α = (1 - a) * p
    dA, N = e3_distribucion_tA(h, k, delta, r)
    acc = 0.0
    prev = 0.0
    # Cola de la Gamma.
    survive = 1.0
    for n in 0:N
        c = cdf(dA, (n + 1) * r)
        pn = c - prev
        prev = c
        pn <= 0 && continue
        # P(band = n) = pn
        prob = 1 - (1 - α)^(max(0, n - Int(Fs) + 1))
        acc += pn * prob
    end
    return acc
end

# FC-3: W_A = 0 (E3 no produce PoST) y gana solo mientras W_H = 0, es decir,
# el adversario publica antes de que exista ningún bloque PoST honesto.
function e3_prob_fc3(h::Float64, a::Float64, k::Int, delta::Float64, r::Float64,
                     p::Float64)
    α = (1 - a) * p
    dA, N = e3_distribucion_tA(h, k, delta, r)
    acc = 0.0
    prev = 0.0
    for n in 0:N
        c = cdf(dA, (n + 1) * r)
        pn = c - prev
        prev = c
        pn <= 0 && continue
        acc += pn * (1 - α)^n
    end
    return acc
end

# Ambas métricas de E3 en un solo recorrido (evita duplicar la suma).
function e3_probabilidades(h::Float64, a::Float64, k::Int, delta::Float64,
                           r::Float64, p::Float64, Fs::Float64)
    α = (1 - a) * p
    dA, N = e3_distribucion_tA(h, k, delta, r)
    fc1 = 0.0
    fc3 = 0.0
    prev = 0.0
    Finf = isinf(Fs)
    Fsi = Finf ? 0 : Int(Fs)
    for n in 0:N
        c = cdf(dA, (n + 1) * r)
        pn = c - prev
        prev = c
        pn <= 0 && continue
        fc3 += pn * (1 - α)^n
        if !Finf
            fc1 += pn * (1 - (1 - α)^(max(0, n - Fsi + 1)))
        end
    end
    return (fc1, fc3)
end

# ===========================================================================
# Simulador transparente (referencia) — E4 · censura de depósitos
# ===========================================================================
# Modelo de CORRECCION-T02-A: un depósito pendiente en mempool; todo bloque
# honesto lo incluye; el adversario nunca.  El adversario persigue un depósito
# a la vez desde el padre del bloque que lo incluye y publica cuando su rama
# privada es estrictamente más larga.  El corte ocurre cuando la cadena
# seleccionada alcanza b + M_dep con el depósito dentro.
#
# Devuelve (corte::Bool, t_corte, fraccion_adversaria).
function e4_replica_ref!(rng::AbstractRNG, h::Float64, Mdep::Int, horizonteT::Float64)
    t = 0.0
    sel = 0             # altura de la cadena seleccionada
    adv_sel = 0         # bloques del adversario en la cadena seleccionada
    dep_b = 0           # altura del depósito incluido (0 = ninguno activo)
    priv = 0            # altura de la rama privada durante el intento

    while t < horizonteT
        if dep_b == 0
            # Espera al próximo bloque honesto que incluya el depósito.
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
                    return (true, t, sel == 0 ? 0.0 : adv_sel / sel)
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

export e1_prob, TABLA_NAKAMOTO, e2_prob_sin_horizonte,
    e3_distribucion_tA, e3_prob_fc1, e3_prob_fc3, e3_probabilidades, E3_BASE,
    e4_replica_ref!

end # module
