#= DS-3 · referencia.jl
   ORÁCULOS exactos y lentos. Vías INDEPENDIENTES del kernel `rapido.jl`:
     · primera pasada por enumeración exhaustiva en `Rational{BigInt}` (T ≤ 20);
     · primera pasada por DP absorbente en `Rational{BigInt}` (d, T pequeños);
     · cola hipergeométrica exacta (cobertura);
     · almacenamiento forzado exacto;
     · muestreador exacto del saldo por espacios exponenciales (retención).

   Convención ÚNICA de este proyecto: `q_adv` es la tasa del ADVERSARIO por paso
   (`q` de BASELINE.md); el honesto tiene `1 − q_adv`. Se evita el nombre histórico
   ambiguo de P-PRESTAMO para que ninguna firma engañe.
=#

"Primera pasada por enumeración recursiva de las `2^T` trayectorias. `q_adv` = tasa del adversario."
function enumerar_exhaustivo(q_adv::Rational{BigInt}, d::Integer, T::Integer)
    T <= 20 || throw(ArgumentError("enumeración exhaustiva sólo para T ≤ 20"))
    p_hon = 1 - q_adv
    term = zero(Rational{BigInt})
    paso = zero(Rational{BigInt})
    function rec!(z::Int, t::Int, pr::Rational{BigInt}, tocado::Bool)
        if z == -1 && !tocado
            paso += pr
            t == T && (term += pr)
            tocado = true
        end
        t == T && return
        rec!(z - 1, t + 1, pr * q_adv, tocado)   # paso del adversario: baja
        rec!(z + 1, t + 1, pr * p_hon, tocado)   # paso del honesto: sube
        return
    end
    rec!(d, 0, one(Rational{BigInt}), false)
    return (terminal = term, paso = paso)
end

"""
    primera_absorbente_exacta(q_adv, d, T)

DP absorbente en `Rational{BigInt}` sobre la POSICIÓN, con `−1` absorbente. Es O(T·(d+T))
y exacta: la masa absorbida es `P(∃ t ≤ T : Z_t = −1)`. Vía independiente del DP de
`(mínimo, posición)` de `rapido.jl`; ambas se comprueban iguales en el dominio del oráculo.
"""
function primera_absorbente_exacta(q_adv::Rational{BigInt}, d::Integer, T::Integer)
    d >= 0 || throw(ArgumentError("d ≥ 0"))
    p_hon = 1 - q_adv
    zmax = d + T + 2
    u = zeros(Rational{BigInt}, zmax + 2)      # u[i+1] ↔ posición i (i = 0..zmax+1)
    u[d + 1] = one(Rational{BigInt})
    a = zero(Rational{BigInt})
    un = similar(u)
    for _ in 1:T
        fill!(un, zero(Rational{BigInt}))
        for z in 0:zmax
            v = u[z + 1]
            iszero(v) && continue
            # paso adversario z-1
            if z - 1 == -1
                a += v * q_adv
            else
                un[z - 1 + 1] += v * q_adv
            end
            # paso honesto z+1
            un[z + 1 + 1] += v * p_hon
        end
        u, un = un, u
    end
    return a
end

"Forma cerrada exacta del horizonte largo: `(q/p)^(d+1)` si `q < p`, si no `1`."
function eventual_exacto(q_adv::Rational{BigInt}, d::Integer)
    p_hon = 1 - q_adv
    q_adv < p_hon || return one(Rational{BigInt})
    return (q_adv / p_hon)^(d + 1)
end

# ─────────────────────────────────────────── cobertura exacta (MODELO §2.8)

"`1 − B/N` si `k > B`; `0` si `k ≤ B`, exacto en `Rational{BigInt}`."
function almacenamiento_forzado_exacta(N::Integer, k::Integer, B::Integer)::Rational{BigInt}
    N >= 1 || throw(ArgumentError("N ≥ 1"))
    k <= B && return zero(Rational{BigInt})
    return max(zero(Rational{BigInt}), 1 - Rational{BigInt}(B, N))
end

"`P(X > B)`, `X ~ Hipergeométrica(N, M, k)`, exacto en `Rational{BigInt}`."
function cola_hiper_exacta(N::Integer, M::Integer, k::Integer, B::Integer)::Rational{BigInt}
    N >= 1 || throw(ArgumentError("N ≥ 1"))
    (0 <= M <= N) || throw(ArgumentError("M=$M fuera de [0,$N]"))
    (0 <= k <= N) || throw(ArgumentError("k=$k fuera de [0,$N]"))
    den = binomial(BigInt(N), k)
    iszero(den) && return zero(Rational{BigInt})
    num = BigInt(0)
    jmax = min(k, M)
    for j in (B + 1):jmax
        num += binomial(BigInt(M), j) * binomial(BigInt(N - M), k - j)
    end
    return num // den
end

# ─────────────────────────────────────────── retención: oráculo exponencial

"""
    muestra_saldo_espaciado!(rng, θ, coef; modo = :lineal)

Muestreador EXACTO del saldo confiscable por espacios exponenciales (P-CLAVE `referencia.jl`).
Con `N ~ Poisson(θ)` bloques en la ventana, las antigüedades dan
`B = coef · Σ_{k=1..m} k·E_k / Σ_{j=1..m+1} E_j` con `E_k ~ Exp(1)`.
Devuelve `(saldo, m)`.
"""
function muestra_saldo_espaciado!(rng, θ::Float64, coef::Float64; modo::Symbol = :lineal)
    m = 0
    if θ > 0
        if θ < 30
            L = exp(-θ)
            p = 1.0
            n = 0
            while true
                n += 1
                p *= rand(rng)
                p <= L && break
                n > 1_000_000 && break
            end
            m = n - 1
        else
            m = max(0, round(Int, θ + sqrt(θ) * randn(rng)))
        end
    end
    m = min(m, 100_000)
    E = Vector{Float64}(undef, m + 1)
    se = 0.0
    @inbounds for j in 1:(m + 1)
        E[j] = randexp(rng)
        se += E[j]
    end
    s = 0.0
    if modo === :lineal
        @inbounds for k in 1:m
            s += k * E[k]
        end
    else
        @inbounds for k in 1:m
            s += E[k]
        end
    end
    return (coef * s / se, m)
end
