# CRP-v0.1 — referencia: oráculo exacto y transparen­te para casos pequeños.
# Independiente del kernel de `rapido.jl` en método y en orden de operaciones. Aritmética
# exacta (BigInt/Rational) donde el veredicto es discreto.

# ---------------------------------------------------------------------------
# 1. Invariancia sr↔peso (el corazón del §3.2). Exacta.
#    La identidad asintótica es (sr/sr0)·(w(sr)/w(sr0)) → 1. Se acota el error de los
#    suelos, sin aproximar.
# ---------------------------------------------------------------------------
struct CotaInvariancia
    sr::BigInt
    razon::Rational{BigInt}   # (sr/sr0)·(w(sr)/w(sr0))
    error_rel::BigFloat
end

"Tabla exacta de la razón (sr/sr0)·(peso(sr)/peso(sr0)) para varios `sr`."
function cota_invariancia(sr0::Integer; srs=nothing)
    if srs === nothing
        srs = [sr0 >> 4, sr0 >> 2, sr0 >> 1, sr0, sr0 << 1, sr0 << 2, sr0 << 4]
    end
    out = CotaInvariancia[]
    for sr in srs
        sr = BigInt(sr)
        razon = (sr // BigInt(sr0)) * (peso_exacto(sr) // peso_exacto(sr0))
        push!(out, CotaInvariancia(sr, razon, abs(BigFloat(razon) - 1)))
    end
    return out
end

# ---------------------------------------------------------------------------
# 2. Contabilidad exacta del trabajo por slot para una rama (s, sr).
#    E[trabajo/slot] = λ(s,sr)·w(sr)/w(sr0) con λ exacta como racional.
#    (Se usa la λ esperada, que es lineal; no se redondea a entero.)
# ---------------------------------------------------------------------------
function trabajo_esperado_exacto(s::Rational{BigInt}, sr::Integer, sr0::Integer,
                                 lambda0::Rational{BigInt}=big(1)//big(1))
    λ = s * lambda0 * BigInt(sr) // BigInt(sr0)
    return λ * peso_exacto(sr) // peso_exacto(sr0)
end

# ---------------------------------------------------------------------------
# 3. Ruina del jugador exacta para pasos ±1 (PoW lineal). Sin recursión infinita:
#    p(d) = (q/p)^d para q<p, 1 para q≥p. Y su complementaria.
# ---------------------------------------------------------------------------
"Probabilidad exacta (Rational) de alcanzar desde `d` con pasos ±1, adversario `α`."
function ruina_exacta(α::Rational{BigInt}, d::Integer)
    p = 1 - α
    q = α
    q >= p && return 1//1
    return (q // p)^d
end

# ---------------------------------------------------------------------------
# 4. Oráculo por Monte Carlo LENTO y distinto: Poisson por suma de tiempos
#    exponenciales (método de la transformada inversa), no por el algoritmo de Knuth.
#    Sirve de referencia independiente para `simular_rama_rapido`.
# ---------------------------------------------------------------------------
function poisson_exponencial(rng, mu::Float64)
    mu <= 0 && return 0
    L = exp(-mu)
    k = 0
    pr = rand(rng)
    while pr > L
        k += 1
        pr *= rand(rng)
    end
    return k
end

"""
Referencia lenta del proceso de trabajo de una rama. Devuelve el trabajo total (unidades
de w(sr0)) tras `n_slots` y el número de bloques. `mode` sólo afecta a la doc: aquí el
trabajo se acumula de la forma declarada en el modelo.
"""
function simular_rama_referencia(rng, s::Real, p::Parametros; n_slots::Int=100,
                                 sr::Integer=p.sr0)
    total = 0.0
    bloques = 0
    mu = tasa_esperada(s, sr, p)
    wrel = Float64(peso_relativo(sr, p.sr0))
    for _ in 1:n_slots
        k = poisson_exponencial(rng, mu)
        bloques += k
        total += k * wrel
    end
    return (trabajo=total, bloques=bloques)
end

# ---------------------------------------------------------------------------
# 5. Umbral medio: con las dos ramas repartiéndose el trabajo, el adversario supera
#    estrictamente si su fracción de trabajo es mayor que la honesta. Exacto.
# ---------------------------------------------------------------------------
"Trabajo medio por slot de cada rama en el modo dado; devuelve (honesto, adversario, razón)."
function umbral_medio(α::Real; publica::Bool, sirv_alpha::Real=1.0)
    # `publica=false` ⇒ el adversario retiene: la honesta sólo acumula (1−α).
    # `publica=true`  ⇒ el adversario publica: la honesta acumula todo el espacio (1).
    h = publica ? 1.0 : (1.0 - α)
    a = α * sirv_alpha
    return (honesto=h, adversario=a, razon=h == 0 ? Inf : a / h)
end

"α mínimo medio (razón=1) para el modo dado. Retención → 1/2; publicación → 1/sirv."
function α_estrella_medio(; publica::Bool=false, sirv_alpha::Real=1.0)
    # retención: α·sirv = 1−α  →  α = 1/(1+sirv)
    # publicación: α·sirv = 1  →  α = 1/sirv (la honesta acumula el espacio completo)
    publica && return 1.0 / sirv_alpha
    return 1.0 / (1.0 + sirv_alpha)
end

# ---------------------------------------------------------------------------
# 6. Curva corta con granularidad: ruina compuesta por saltos de Poisson.
#    Independiente de la aproximación de difusión. DP con truncamiento, Float64.
# ---------------------------------------------------------------------------
function pmf_poisson(k::Int, mu::Float64)
    mu < 0 && throw(ArgumentError("mu negativo"))
    mu == 0 && return k == 0 ? 1.0 : 0.0
    p = exp(-mu)
    for i in 1:k
        p *= mu / i
    end
    return p
end

"""
Distribución del cambio neto por slot: H−A, con H~Poisson(g(1−α)), A~Poisson(gα).
Truncada en `±corte` desviaciones. Devuelve el vector de probabilidades indexado por
`net+corte+1`.
"""
function pmf_cambio_neto(α::Real, g::Real; corte::Int=40)
    mh = g * (1 - α)
    ma = g * α
    q = zeros(Float64, 2 * corte + 1)
    ph = [pmf_poisson(k, mh) for k in 0:corte]
    pa = [pmf_poisson(k, ma) for k in 0:corte]
    for h in 0:corte, a in 0:corte
        net = h - a
        abs(net) > corte && continue
        q[net + corte + 1] += ph[h + 1] * pa[a + 1]
    end
    return q
end

"""
Probabilidad de que el adversario alcance alguna vez una ventaja inicial de `d` unidades
de trabajo (el adversario va por detrás). DP de valor iterado sobre el déficit (entero).
`g` = bloques por unidad de trabajo. Devuelve `p` para déficits 1..`nmax`.
"""
function prob_alcance_dp(α::Real, g::Real, nmax::Int; d::Integer=nothing, maxit::Int=10_000,
                         tol::Float64=1e-12)
    q = pmf_cambio_neto(α, g; corte=min(nmax, 60))
    corte = (length(q) - 1) ÷ 2
    p = zeros(Float64, nmax + 1)
    p[1] = 1.0                      # déficit ≤ 0: ya alcanzó
    for _ in 1:maxit
        pmax = 0.0
        for dd in 1:nmax
            acc = 0.0
            for (idx, prob) in enumerate(q)
                prob == 0 && continue
                net = idx - corte - 1
                nuevo = dd + net
                nuevo <= 0 && (acc += prob; continue)
                nuevo > nmax && continue         # escape a +∞ (p=0 en la frontera)
                acc += prob * p[nuevo + 1]
            end
            pmax = max(pmax, abs(acc - p[dd + 1]))
            p[dd + 1] = acc
        end
        pmax < tol && break
    end
    return d === nothing ? p[2:end] : p[d + 1]
end
