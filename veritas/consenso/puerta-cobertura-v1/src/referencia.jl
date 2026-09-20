# Oraculos: lentos, transparentes y —donde se puede— exactos. El kernel rapido se valida contra
# ellos, nunca al reves (LINEO §2, orden 1).

"""
    prob_no_positivo_ref(μ₁, μ₂, r; nmax, bits=256) -> (valor, cota)

Oraculo de `prob_no_positivo`: doble suma directa en `BigFloat` sobre `n₁ = 0..nmax` y
`n₂ = 0..n₂max`, sin ninguna gamma incompleta. Lento a proposito: es la definicion escrita tal
cual. La cota es la masa de Poisson que queda fuera de los dos rangos.
"""
function prob_no_positivo_ref(μ₁::Real, μ₂::Real, r::Rational{Int64}; nmax::Int=400,
                              bits::Int=256)
    setprecision(BigFloat, bits) do
        m1 = BigFloat(μ₁); m2 = BigFloat(μ₂)
        p1 = [exp(-m1)]; for n in 1:nmax; push!(p1, p1[end] * m1 / n); end
        n2max = nmax + techo_racional(r, nmax) + 1
        p2 = [exp(-m2)]; for n in 1:n2max; push!(p2, p2[end] * m2 / n); end
        s = BigFloat(0)
        for n1 in 0:nmax
            m = techo_racional(r, n1)
            m > n2max && continue
            acc = BigFloat(0)
            for n2 in max(m, 0):n2max
                acc += p2[n2+1]
            end
            s += p1[n1+1] * acc
        end
        cota = (1 - sum(p1)) + (1 - sum(p2))
        return (Float64(s), Float64(max(cota, 0)))
    end
end

"""
    pmf_poisson_bf(μ, nmax) -> Vector{BigFloat}

`P(Poisson(μ)=n)` para `n = 0..nmax`, por la recurrencia `p(n) = p(n−1)·μ/n` en `BigFloat`: sin
`exp`/`lgamma` por termino, que es lo que hacia inutilizable la version anterior.
"""
function pmf_poisson_bf(μ::BigFloat, nmax::Int)
    p = Vector{BigFloat}(undef, nmax + 1)
    p[1] = exp(-μ)
    @inbounds for n in 1:nmax
        p[n+1] = p[n] * μ / n
    end
    return p
end

"""
    nmax_poisson(μ; k=14.0) -> Int

Corte `nmax` para las sumas del oraculo: `μ + k·√μ + 20`, redondeado. La masa que queda fuera se
devuelve siempre como cota, nunca se ignora.
"""
nmax_poisson(μ::Real; k::Float64=14.0) = max(20, ceil(Int, float(μ) + k * sqrt(float(μ)) + 20))

"""
    skellam_pmf_ref(μ₁, μ₂, d; nmax, bits=256) -> Float64

`P(N₁ − N₂ = d)` por suma directa `Σ_n P(N₁=n+d)·P(N₂=n)` en `BigFloat`. Oraculo del caso
transitorio, donde `r = 1` y la diferencia de peso **es** un Skellam.
"""
function skellam_pmf_ref(μ₁::Real, μ₂::Real, d::Integer; nmax::Int=0, bits::Int=256)
    nm = nmax > 0 ? nmax : max(nmax_poisson(μ₁), nmax_poisson(μ₂))
    setprecision(BigFloat, bits) do
        p1 = pmf_poisson_bf(BigFloat(μ₁), nm + abs(d))
        p2 = pmf_poisson_bf(BigFloat(μ₂), nm)
        s = BigFloat(0)
        for n in max(0, -d):nm
            idx = n + d
            (0 <= idx <= nm + abs(d)) || continue
            s += p1[idx+1] * p2[n+1]
        end
        return Float64(s)
    end
end

"""
    prob_cambio_posterior_ref(f, t; nmax, bits=256) -> (valor, cota)

Oraculo de `prob_cambio_posterior` **solo para `r = 1`** (el caso transitorio), por la via directa
y **sin** inclinacion exponencial:

    L(t) = Σ_{n₁,n₂} P(N₁=n₁)·P(N₂=n₂)·[ d ≤ 0 ? 1 : (λ₂/λ₁)^d ],   d = n₁ − n₂

usando el resultado clasico exacto de ruina de Skellam `P(bajar a ≤0 desde d) = (λ₂/λ₁)^d`, que
vale por ser el paseo sin salto hacia abajo. Que este oraculo y el kernel coincidan comprueba a la
vez la identidad de inclinacion exponencial y la suma por ventana del kernel.

La cota devuelta es la masa de Poisson que los dos cortes dejan fuera.
"""
function prob_cambio_posterior_ref(f::Flujos, t::Real; nmax::Int=0, bits::Int=256)
    g = canonico(f)
    g.r == 1 || throw(ArgumentError("el oraculo directo solo cubre r = 1 (transitorio)"))
    μ1f = g.λ₁ * float(t); μ2f = g.λ₂ * float(t)
    nm = nmax > 0 ? nmax : max(nmax_poisson(μ1f), nmax_poisson(μ2f))
    setprecision(BigFloat, bits) do
        p1 = pmf_poisson_bf(BigFloat(μ1f), nm)
        p2 = pmf_poisson_bf(BigFloat(μ2f), nm)
        ρ = BigFloat(g.λ₂) / BigFloat(g.λ₁)
        pw = Vector{BigFloat}(undef, nm + 1)
        pw[1] = BigFloat(1)
        for d in 1:nm
            pw[d+1] = pw[d] * ρ
        end
        s = BigFloat(0)
        @inbounds for n1 in 0:nm
            a = p1[n1+1]
            a == 0 && continue
            acc = BigFloat(0)
            for n2 in 0:nm
                d = n1 - n2
                acc += p2[n2+1] * (d <= 0 ? BigFloat(1) : pw[d+1])
            end
            s += a * acc
        end
        cota = max(1 - sum(p1), BigFloat(0)) + max(1 - sum(p2), BigFloat(0))
        return (Float64(s), Float64(cota))
    end
end

"""
    mc_cambio_posterior(f, t, T, n, semilla; α=0.05) -> (p̂, inf, sup)

Oraculo de Monte Carlo, **independiente de toda la teoria**: simula el proceso hasta `T` y cuenta
en que fraccion de replicas hay al menos un cambio de lider despues de `t`.

Es una **cota inferior** de `L(t)` (horizonte finito), no una estimacion insesgada de ella: con
`T → ∞` sube hasta `L(t)`. El intervalo es Clopper–Pearson exacto.
"""
function mc_cambio_posterior(f::Flujos, t::Real, T::Real, n::Integer, semilla::UInt64;
                             α::Float64=0.05)
    TT = float(T); tt = float(t)
    hits = Vector{Bool}(undef, n)
    Threads.@threads for i in 1:n
        cam = recorrer(rng_replica(semilla, i), f, TT, TT + 1.0)
        hits[i] = cam.t_ultimo > tt
    end
    k = count(hits)
    lo, hi = clopper_pearson(k, n, α)
    return (k / n, lo, hi)
end

"""
    mc_ruina(f, d, T, n, semilla; α=0.05) -> (p̂, inf, sup)

Oraculo de `prob_ruina`: fraccion de replicas en las que `D`, partiendo de `d` unidades de `w₂`,
baja a `≤ 0` antes de `T`. Cota inferior del valor con horizonte infinito.
"""
function mc_ruina(f::Flujos, d::Real, T::Real, n::Integer, semilla::UInt64; α::Float64=0.05)
    Λ = f.λ₁ + f.λ₂
    p1 = f.λ₁ / Λ
    p = Int64(numerator(f.r)); q = Int64(denominator(f.r))
    d0 = round(Int64, float(d) * q)
    TT = float(T)
    hits = Vector{Bool}(undef, n)
    Threads.@threads for i in 1:n
        rng = rng_replica(semilla, i)
        x = d0; u = 0.0; ok = false
        while true
            u -= log(rand(rng)) / Λ
            u > TT && break
            x += rand(rng) < p1 ? p : -q
            if x <= 0
                ok = true
                break
            end
        end
        hits[i] = ok
    end
    k = count(hits)
    lo, hi = clopper_pearson(k, n, α)
    return (k / n, lo, hi)
end

"""
    arcoseno_discreta(n) -> Vector{Rational{BigInt}}

Ley **exacta** del instante del ultimo paso por cero de un paseo aleatorio simetrico simple de
`2n` pasos: `P(ultimo cero en el paso 2k) = u_{2k}·u_{2n−2k}` con `u_{2m} = C(2m,m)/4^m`
(ley del arcoseno discreta). En `Rational{BigInt}`: exacta, sin coma flotante.

Es la referencia del punto 4 del encargo en el caso de deriva nula (`c = 1` o `s₁ = s₂`), que es
el unico regimen en el que la magnitud historica de la ronda 3 es comparable.
"""
function arcoseno_discreta(n::Integer)
    u = Vector{Rational{BigInt}}(undef, n + 1)
    for m in 0:n
        u[m+1] = binomial(BigInt(2m), BigInt(m)) // (BigInt(4)^m)
    end
    return [u[k+1] * u[n-k+1] for k in 0:n]
end

"""
    arcoseno_continua(x) -> Float64

`P(ultimo cruce ≤ x·T) = (2/π)·arcsin(√x)`, el limite continuo de `arcoseno_discreta`. Su media
es `T/2` y su densidad tiene forma de U: acumula masa en los **dos** extremos.
"""
function arcoseno_continua(x::Real)
    xx = float(x)
    xx <= 0 && return 0.0
    xx >= 1 && return 1.0          # el ultimo cruce no puede caer fuera del horizonte
    return 2 / π * asin(sqrt(xx))
end

"""
    media_arcoseno_discreta(n) -> Rational{BigInt}

`E[ultimo cero]/(2n)` bajo `arcoseno_discreta(n)`, exacta. Converge a `1/2`.
"""
function media_arcoseno_discreta(n::Integer)
    p = arcoseno_discreta(n)
    return sum((BigInt(k) // BigInt(n)) * p[k+1] for k in 0:n)
end

"""
    cola_arcoseno(x) -> Float64

`P(último cruce > x·T) = 1 − (2/π)·arcsin(√x)` bajo la ley del arcoseno. Es **la** magnitud del
punto 4 del encargo: «hay un cambio de líder **después** de `x·T`», no «hay al menos un cambio»,
que con centenares de eventos vale ≈1 trivialmente.
"""
cola_arcoseno(x::Real) = 1 - arcoseno_continua(x)

"""
    horizonte_implicito_cola(p, t) -> Float64

El horizonte `T` que hace que la ley del arcoseno dé exactamente `P(último cruce > t) = p`.
Invierte `cola_arcoseno`:

    T = t / sin²( (1−p)·π/2 )

Sirve para leer un dato histórico que publicó la probabilidad **sin publicar el horizonte**: dice
qué horizonte habría que haber usado para obtenerlo bajo un paseo sin deriva.
"""
horizonte_implicito_cola(p::Real, t::Real) = float(t) / sin((1 - float(p)) * π / 2)^2

"""
    horizonte_implicito_media(m) -> Float64

El horizonte `T` que hace que la media del instante del último cruce valga `m` bajo la ley del
arcoseno: `E[L] = T/2`, luego `T = 2m`. La media de la ley del arcoseno es `T/2` **exactamente**
para todo `T` (lo comprueba `media_arcoseno_discreta`), así que un dato histórico con
`E[L]/T ≈ 0,99` no puede provenir de un paseo libre sin deriva.
"""
horizonte_implicito_media(m::Real) = 2 * float(m)

"""
    congelamiento_ref(f, F, τ; bits=256) -> Float64

Oráculo de `prob_congelamiento_divergente`: enumera **toda** la ley conjunta en `BigFloat`. Primero
tabula la ley de `D(F−τ)` sobre la retícula recorriendo los pares `(n₁,n₂)`, y luego recorre los
pares `(m₁,m₂)` del incremento comparando el signo antes y después. Es la definición escrita tal
cual, sin bandas ni inclinaciones; sólo sirve para `F` pequeño porque es `O(n²)` en `BigFloat`.
"""
function congelamiento_ref(f::Flujos, F::Real, τ::Real; bits::Int=256)
    g = canonico(f)
    s = float(F) - float(τ)
    s <= 0 && throw(ArgumentError("τ debe ser menor que F"))
    setprecision(BigFloat, bits) do
        m1 = BigFloat(g.λ₁ * s); m2 = BigFloat(g.λ₂ * s)
        v1 = BigFloat(g.λ₁ * float(τ)); v2 = BigFloat(g.λ₂ * float(τ))
        N = max(nmax_poisson(Float64(m1)), nmax_poisson(Float64(m2)))
        M = max(nmax_poisson(Float64(v1)), nmax_poisson(Float64(v2)))
        p1 = pmf_poisson_bf(m1, N); p2 = pmf_poisson_bf(m2, N)
        q1 = pmf_poisson_bf(v1, M); q2 = pmf_poisson_bf(v2, M)
        pn = numerator(g.r); qd = denominator(g.r)
        ley = Dict{Int,BigFloat}()
        for a in 0:N, b in 0:N
            d = pn * a - qd * b
            ley[d] = get(ley, d, BigFloat(0)) + p1[a+1] * p2[b+1]
        end
        tot = BigFloat(0)
        for a in 0:M, b in 0:M
            e = pn * a - qd * b
            e == 0 && continue
            w = q1[a+1] * q2[b+1]
            acc = BigFloat(0)
            for (d, pd) in ley
                ((d > 0) != ((d + e) > 0)) && (acc += pd)
            end
            tot += w * acc
        end
        return Float64(tot)
    end
end

"""
    autocorrelacion_replicas(semilla, n) -> Float64

Autocorrelación lag-1 de la **primera salida** de los generadores de `n` réplicas consecutivas. Es
el test de regresión del defecto D4: con `StableRNG(semilla + i)` vale `≈ −0,43` y sesga cualquier
estimador que promedie sobre réplicas; con `rng_replica` (Philox contracontador) vale `≈ −0,001`.
"""
function autocorrelacion_replicas(semilla::UInt64, n::Integer)
    a = [rand(rng_replica(semilla, i)) for i in 1:n]
    m = sum(a) / n
    num = sum((a[i] - m) * (a[i+1] - m) for i in 1:n-1)
    den = sum((x - m)^2 for x in a)
    return den == 0 ? 0.0 : num / den
end
