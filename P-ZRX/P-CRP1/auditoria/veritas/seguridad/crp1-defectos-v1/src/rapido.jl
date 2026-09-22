# rapido.jl — kernels validados contra los oráculos de `referencia.jl`.
#
# Elección de estructuras (LINEO §4):
#  * La DP de alcance es una recurrencia lineal de orden infinito sobre un estado entero (déficit
#    en bloques). Se resuelve por iteración de valor con la transición como matriz-vector densa de
#    banda (BLAS) y frontera explícita, en vez de truncar la pmf a un corte fijo.
#  * La tabla de varianza es una suma doble sobre dos Poisson independientes; se evalúa
#    directamente en `BigFloat` (256 bits) con pesos ENTEROS exactos, sin Monte Carlo.

# ---------------------------------------------------------------------------
# pmf de Poisson con log-factoriales acumulados (evita O(k) por evaluación)
# ---------------------------------------------------------------------------

"Vector de `log k!` para `k = 0..n`, acumulado."
function logfact_acum(n::Integer)
    v = zeros(Float64, n + 1)
    for k in 1:n
        v[k + 1] = v[k] + log(Float64(k))
    end
    return v
end

"pmf de Poisson `k ↦ e^{−μ}μ^k/k!` para `k = 0..n` (Float64), con `μ` fijo."
function pmf_poisson_vec(n::Integer, μ::Float64)
    lf = logfact_acum(n)
    out = Vector{Float64}(undef, n + 1)
    if μ <= 0
        out .= 0.0
        out[1] = 1.0
        return out
    end
    logμ = log(μ)
    for k in 0:n
        out[k + 1] = exp(-μ + k * logμ - lf[k + 1])
    end
    return out
end

"pmf de Poisson puntual en `Float64`."
pmf_poisson_f64(k::Integer, μ::Float64) = μ <= 0 ? (k == 0 ? 1.0 : 0.0) :
    exp(-μ + k * log(μ) - sum(log(Float64(i)) for i in 2:k))

"Mezcla de semillas (splitmix64) para derivar semillas NO consecutivas por réplica."
function splitmix64(x::UInt64)
    z = x + 0x9E3779B97F4A7C15
    z = (z ⊻ (z >> 30)) * 0xBF58476D1CE4E5B9
    z = (z ⊻ (z >> 27)) * 0x94D049BB133111EB
    return z ⊻ (z >> 31)
end

# ---------------------------------------------------------------------------
# DP de alcance con masa conservada y soporte adaptativo
# ---------------------------------------------------------------------------

"""
Soporte adaptativo de `X = H − A` (`H~Poisson(g(1−α))`, `A~Poisson(gα)`): colas de `margen`
desviaciones típicas más una constante. Devuelve la masa retenida para no confundirla con 1
(regla de D2: publicar la masa cruda antes de cualquier renormalización).
"""
function soporte_incremento(α::Real, g::Real; margen::Real = 40.0)
    μh = g * (1 - α)
    μa = g * α
    hmax = ceil(Int, μh + margen * sqrt(μh) + 80)
    amax = ceil(Int, μa + margen * sqrt(μa) + 80)
    ph = pmf_poisson_vec(hmax, μh)
    pa = pmf_poisson_vec(amax, μa)
    xmin = -amax
    xmax = hmax
    q = zeros(Float64, xmax - xmin + 1)
    for h in 0:hmax
        phh = ph[h + 1]
        phh == 0.0 && continue
        for a in 0:amax
            q[(h - a) - xmin + 1] += phh * pa[a + 1]
        end
    end
    return (xmin = xmin, xmax = xmax, q = q, masa = sum(q),
            masa_ph = sum(ph), masa_pa = sum(pa), hmax = hmax, amax = amax)
end

"""
DP de alcance con MASA CONSERVADA e iteración de valor `v ← M·v + rhs` sobre los estados
`1..N` (déficit en BLOQUES):
`M[i,j] = P(X = j−i)`, `rhs[i] = P(X ≤ umbral−i)` (salto directo a la absorción), y
`e[i] = P(X > N−i)` (salto fuera de la ventana).

`absorbe_estricto=false` absorbe en déficit `≤ 0` (EMPATE); `true` en `≤ −1` (SUPERAR).
`frontera=:cero` no cuenta los saltos fuera de la ventana (COTA INFERIOR por truncación);
`frontera=:uno` los cuenta como éxito (COTA SUPERIOR).
"""
function dp_ruina_conservada(α::Real, g::Real, m::Integer;
                             N::Union{Nothing,Int} = nothing, margen_ventana::Int = 400,
                             absorbe_estricto::Bool = false, frontera::Symbol = :cero,
                             maxit::Int = 100_000, rtol::Float64 = 1e-14,
                             margen_cola::Real = 40.0, verbose::Bool = false)
    Nv = N === nothing ? m + margen_ventana : N
    Nv > m || throw(ArgumentError("la ventana N debe superar el déficit m"))
    sop = soporte_incremento(α, g; margen = margen_cola)
    xmin, xmax, q = sop.xmin, sop.xmax, sop.q
    ls = length(q)
    # Indexación: el estado `k = 1..Nv` representa el déficit `d = k + despl`.
    #   EMPATE  (absorbe en d ≤ 0): despl = 0  ⇒ estados 1..Nv, objetivo k = m
    #   ESTRICTO(absorbe en d ≤ −1): despl = −1 ⇒ estados 0..Nv−1, objetivo k = m+1
    # En AMBOS casos la absorción ocurre cuando `k + x ≤ 0`, así que la frontera inferior es
    # idéntica y sólo cambia el índice del objetivo. Así el estado vivo «déficit 0» no se pierde.
    despl = absorbe_estricto ? -1 : 0
    M = zeros(Float64, Nv, Nv)
    b = zeros(Float64, Nv)
    e = zeros(Float64, Nv)
    for idx in 1:ls
        x = xmin + idx - 1
        w = q[idx]
        w == 0.0 && continue
        if x < 0
            ax = -x
            for k in 1:min(Nv, ax)
                b[k] += w                    # k + x ≤ 0 → absorción
            end
            for k in (ax + 1):Nv
                M[k, k - ax] += w
            end
        elseif x == 0
            for k in 1:Nv
                M[k, k] += w
            end
        else
            for k in 1:(Nv - x)
                M[k, k + x] += w
            end
            for k in max(1, Nv - x + 1):Nv
                e[k] += w                    # k + x > Nv → fuera de ventana
            end
        end
    end
    kobj = m - despl
    rhs = frontera === :uno ? b .+ e : b
    v = zeros(Float64, Nv)
    resid = Inf
    iter = 0
    for it in 1:maxit
        vn = M * v .+ rhs
        # residuo relativo, ignorando componentes despreciables frente al objetivo
        d = 0.0
        for i in 1:Nv
            den = max(vn[i], 1e-300)
            d = max(d, abs(vn[i] - v[i]) / den)
        end
        v = vn
        resid = d
        iter = it
        if d < rtol
            break
        end
    end
    verbose && @printf("    DP g=%.4g N=%d iter=%d resid=%.3e masa=%.15f\n", g, Nv, iter, resid, sop.masa)
    return (p = v[kobj], N = Nv, masa_incremento = sop.masa, iter = iter,
            residuo_rel = resid, v = v, xmin = xmin, xmax = xmax)
end

"""
Estimación del alcance del paseo COMPUESTO de Poisson, refinando la ventana hasta estabilizar.
Devuelve `(p, N, residuo_rel, masa_incremento, p_ventanas)`.
"""
function alcance_compuesto(α::Real, g::Real, m::Integer;
                           ventanas = (m + 200, m + 600, m + 1800),
                           absorbe_estricto::Bool = false, rtol::Float64 = 1e-13,
                           maxit::Int = 100_000)
    ps = Float64[]
    ultimo = nothing
    for Nv in ventanas
        ultimo = dp_ruina_conservada(α, g, m; N = Nv, absorbe_estricto = absorbe_estricto,
                                     frontera = :cero, rtol = rtol, maxit = maxit)
        push!(ps, ultimo.p)
    end
    return (p = ultimo.p, N = ultimo.N, residuo_rel = ultimo.residuo_rel,
            masa_incremento = ultimo.masa_incremento, p_ventanas = ps, ventanas = ventanas)
end

"""
Tabla corregida de granularidad (D2) para `α` (racional) y `d` en u.t., con `g` bloques por
u.t. El déficit en la retícula es `z = d·g`, NO `d`. Devuelve por cada `g`: `z`, la ruina exacta
`(q/p)^z` en `Rational{BigInt}` (que además es cota de martingala rigurosa del paseo compuesto),
y la estimación del paseo compuesto por DP de masa conservada.
"""
function tabla_granularidad(α::Rational{BigInt}, d::Integer, gs; con_compuesto::Bool = true,
                            ventanas_extra = (200, 600, 1800))
    filas = NamedTuple[]
    for g in gs
        z = d * g
        exacto = prob_empate_reticula(α, z)
        fila = (g = g, z = z, exacto = exacto,
                log10_exacto = Float64(log10(BigFloat(exacto))))
        if con_compuesto
            c = alcance_compuesto(Float64(α), Float64(g), z;
                                  ventanas = Tuple(z .+ collect(ventanas_extra)))
            fila = merge(fila, (compuesto = c.p, compuesto_N = c.N,
                                compuesto_masa = c.masa_incremento,
                                compuesto_ventanas = c.p_ventanas))
        end
        push!(filas, fila)
    end
    return filas
end

# ---------------------------------------------------------------------------
# Compra de varianza (D5): convolución exacta de dos Poisson compuestos
# ---------------------------------------------------------------------------

"""
Tabla de compra de varianza SIN Monte Carlo: convolución exacta de los dos procesos de Poisson
compuestos. Trabajo honesto `A_h·w(sr0)` con `A_h ~ Poisson(μ_h)`; trabajo adversario
`A_a·w(sr_a)` con `A_a ~ Poisson(μ_a)`. La comparación usa los pesos ENTEROS exactos, así que
los empates se contabilizan sin error de redondeo.

Devuelve por `K`: `p_mayor`, `p_mayor_igual`, `p_igual`, medias de trabajo y la masa de Poisson
omitida al truncar las colas.
"""
function varianza_exacta(p::ParametrosVarianza; prec::Int = 256, margen::Real = 45.0)
    setprecision(BigFloat, prec) do
        filas = NamedTuple[]
        for K in p.factores
            m = medias_varianza(p, K)
            W = BigInt(m.wa)
            W0 = BigInt(m.wh)
            μa = BigFloat(m.μa)
            μh = BigFloat(m.μh)
            bmax = ceil(Int, Float64(μa + margen * sqrt(μa) + 80))
            amax = max(0, Int(fld(bmax * W - 1, W0)))
            lph = logpmf_poisson_vec(amax, μh)
            lpa = logpmf_poisson_vec(bmax, μa)
            cdf = Vector{BigFloat}(undef, amax + 1)
            acc = BigFloat(0)
            for a in 0:amax
                acc += exp(lph[a + 1])
                cdf[a + 1] = acc
            end
            p_mayor = BigFloat(0)
            p_mayor_igual = BigFloat(0)
            p_igual = BigFloat(0)
            masa_b = BigFloat(0)
            for b in 0:bmax
                pb = exp(lpa[b + 1])
                masa_b += pb
                thr = Int(fld(b * W - 1, W0))       # max A con A·W0 < b·W
                thr >= 0 && (p_mayor += pb * cdf[min(thr, amax) + 1])
                thr2 = Int(fld(b * W, W0))          # max A con A·W0 ≤ b·W
                thr2 >= 0 && (p_mayor_igual += pb * cdf[min(thr2, amax) + 1])
                if b * W % W0 == 0
                    Aeq = Int(b * W ÷ W0)
                    Aeq <= amax && (p_igual += pb * exp(lph[Aeq + 1]))
                end
            end
            push!(filas, (K = K, sra = m.sra,
                          μh = Float64(μh), μa = Float64(μa),
                          E_hon = Float64(μh),
                          E_adv = Float64(μa) * Float64(W) / Float64(W0),
                          p_mayor = Float64(p_mayor),
                          p_mayor_igual = Float64(p_mayor_igual),
                          p_igual = Float64(p_igual),
                          masa_b_truncada = Float64(1 - masa_b),
                          amax_trunc = amax, bmax_trunc = bmax))
        end
        return filas
    end
end

# ---------------------------------------------------------------------------
# Monte Carlo bien hecho
# ---------------------------------------------------------------------------

"Cuantil normal estándar por bisección sobre `Phi` (Abramowitz–Stegun 26.2.17, error < 7.5e-8)."
function quantil_normal(p::Real)
    lo, hi = -10.0, 10.0
    for _ in 1:200
        mid = (lo + hi) / 2
        if Phi(mid) < p
            lo = mid
        else
            hi = mid
        end
    end
    return (lo + hi) / 2
end

"CDF normal estándar por la aproximación racional de Abramowitz–Stegun 26.2.17."
function Phi(x::Float64)
    if x < 0
        return 1 - Phi(-x)
    end
    t = 1 / (1 + 0.2316419 * x)
    d = 0.3989422804014327 * exp(-x^2 / 2)
    poly = t * (0.319381530 + t * (-0.356563782 + t * (1.781477937 + t * (-1.821255978 + t * 1.330274429))))
    return 1 - d * poly
end

"Intervalo de Wilson `1−δ` para una proporción."
function ic_wilson(k::Integer, n::Integer, δ::Real = 0.001)
    z = quantil_normal(1 - δ / 2)
    ph = k / n
    den = 1 + z^2 / n
    cen = (ph + z^2 / (2n)) / den
    rad = z / den * sqrt(ph * (1 - ph) / n + z^2 / (4n^2))
    return (lo = max(0.0, cen - rad), hi = min(1.0, cen + rad))
end

"Intervalo de Hoeffding `1−δ`, válido sin supuestos de normalidad."
function ic_hoeffding(k::Integer, n::Integer, δ::Real = 0.001)
    r = sqrt(log(2 / δ) / (2n))
    return (lo = max(0.0, k / n - r), hi = min(1.0, k / n + r))
end

"""
MC de la tabla de varianza con el MISMO proceso que CRP-v0.1 (`simular_rama_rapido`, Poisson por
slot) pero con RNG por réplica y semillas NO consecutivas.
`modo=:hashed` deriva `splitmix64(semilla ⊻ r·φ)`; `modo=:consecutivas` reproduce el esquema del
instrumento (`semilla + 0x9E3779B9·ik + r`).
"""
function mc_varianza(p::ParametrosVarianza; n_rep::Int = 4000,
                     semilla::UInt64 = UInt64(0x5A71A), modo::Symbol = :hashed,
                     δ::Real = 0.001)
    filas = NamedTuple[]
    for (ik, K) in enumerate(p.factores)
        sra = sr_adversario(p.sr0, K)
        W = peso_exacto(sra)
        W0 = peso_exacto(p.sr0)
        μh = (1 - p.α)
        μa = p.α * Float64(sra) / Float64(p.sr0)
        gana = zeros(Int, n_rep)
        suma_a = zeros(Float64, n_rep)
        Threads.@threads for r in 1:n_rep
            sd = modo === :hashed ?
                 splitmix64(semilla ⊻ (UInt64(r) * 0x9E3779B97F4A7C15)) :
                 semilla + UInt64(0x9E3779B9) * UInt64(ik) + UInt64(r)
            rng = StableRNG(sd)
            bh = 0
            ba = 0
            for _ in 1:p.T
                bh += poisson_inversa(rng, μh)
                ba += poisson_inversa(rng, μa)
            end
            gana[r] = (BigInt(ba) * W > BigInt(bh) * W0) ? 1 : 0
            suma_a[r] = Float64(BigInt(ba) * W / W0)
        end
        k = sum(gana)
        push!(filas, (K = K, n_rep = n_rep, k = k, p = k / n_rep,
                      wilson = ic_wilson(k, n_rep, δ),
                      hoeffding = ic_hoeffding(k, n_rep, δ),
                      E_adv = sum(suma_a) / n_rep, modo = modo))
    end
    return filas
end

"""
Autocorrelación lag-1 de la PRIMERA salida de `n` generadores con semillas `semilla + i`.
Es el test de regresión del sesgo que `P-ZRX/P-PUERTA/` encontró
(`veritas/consenso/puerta-cobertura-v1/src/referencia.jl:291-292`: «≈ −0,43»).
"""
function autocorrelacion_lag1_consecutivas(n::Int = 20_000; semilla::UInt64 = UInt64(0x1234))
    xs = Vector{Float64}(undef, n)
    for i in 1:n
        xs[i] = rand(StableRNG(semilla + UInt64(i)))
    end
    μ = sum(xs) / n
    num = 0.0
    den = 0.0
    for i in 1:(n - 1)
        num += (xs[i] - μ) * (xs[i + 1] - μ)
    end
    for i in 1:n
        den += (xs[i] - μ)^2
    end
    return num / den
end
