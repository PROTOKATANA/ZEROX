#= retencion-clave-v1 · src/referencia.jl
   ORÁCULO. Distribución del saldo confiscable por vías independientes del kernel.

   REPRESENTACIÓN EXACTA POR ESPACIOS EXPONENCIALES (la principal).
   Sea `N ~ Poisson(θ)` el número de bloques de la clave dentro de la ventana de retención
   (`θ = λ f T_v`) y sean `0 < a_(1) < … < a_(N) < T_v` sus antigüedades. Condicionado a `N = m`,
   las antigüedades son los estadísticos de orden de `m` uniformes en `[0,T_v)`. Con `a_(0)=0` y
   `a_(m+1)=T_v`, los huecos normalizados `G_k/T_v` siguen una `Dirichlet(1,…,1)`, que se representa
   de forma EXACTA como `G_k = E_k/Σ_j E_j` con `E_k ~ Exp(1)` independientes.

   Con retención lineal `v(a) = 1 − a/T_v`,
       B = ρ I Σ_{k=1..m} (1 − a_(k)/T_v) = ρ I Σ_{k=1..m} k·E_k / Σ_{j=1..m+1} E_j.
   De ahí los momentos exactos del modelo (integrales de la función de retención sobre el proceso
   de Poisson), que este instrumento usa como comprobación independiente:
       E[B]   = ρ I θ / 2                                                                (M3)
       Var[B] = ρ² I² θ / 3                                                              (M4)
       P(B=0) = e^{−θ}                                                                   (M5)
   Con liberación en escalón (`Vesting.ESCALON`), `v(a) = 1` dentro de la ventana y
   `E[B] = ρIθ`, `Var[B] = ρ²I²θ`, y `B = ρI·Σ_{k≤m} E_k / Σ_{j≤m+1} E_j`.

   REPRESENTACIÓN DISCRETA POR ENUMERACIÓN MULTINOMIAL (≤ ~10 bloques). Con `K` bins equiprobables,
   `B = (ρI/(2K))·Σ_j w'_j n_j`, `w'_j = 2K−2j+1`. Se enumeran las composiciones `(n_1..n_K)` de `N`
   bloques con peso `N!/(Π n_j!)·K^{−N}`. Sirve para comparar CDF completas contra la vía
   exponencial y contra el kernel.

   ARITMÉTICA RACIONAL (`dist_exacta_racional`): la misma enumeración en `Rational{BigInt}`, con el
   peso de Poisson fijado por un denominador `10^30` DECLARADO. Comprueba el ÁLGEBRA del reparto.
=#

module Referencia

using ..Modelo: Retencion, Vesting, LINEAL, ESCALON
using Random: randexp
using SpecialFunctions: erfc

export DistDiscreta, pesos_enteros, dist_enumerada, dist_exacta_racional,
       masa_en, cdf_dist, cola_dist, media_dist, varianza_dist, cuantil_dist,
       poisson_pmf, pmf_composiciones, peso_composicion, enumerar_saldos,
       masa_cero_exacta, masa_cero_aprox, cola_aproximada, cota_cola_inferior,
       cdf_m_bins, cdf_exacta,
       muestra_espaciado!, varianza_teorica, media_teorica

"""Distribución discreta sobre la rejilla `0 : paso : (length(masas)-1)·paso`."""
struct DistDiscreta
    paso::Float64
    masas::Vector{Float64}
end

"""Pesos ENTEROS `w'_j` de la representación discreta y el paso BASE `paso_grid` tal que
`B = ρ · paso_grid · Σ_j w'_j n_j`. `LINEAL`: `w'_j = 2K−2j+1`, `paso_grid = I/(2K)`.
`ESCALON`: `w'_j = 1`, `paso_grid = I/K`. **`ρ` NO entra en el paso**: con `ρ = 0` la rejilla
tendría `paso = 0` y la CDF se rompe (defecto O10 de `PROGRESO.md`); `ρ` se aplica al evaluar `B`."""
function pesos_enteros(K::Int, modo::Vesting, rho::Real, ingreso::Real)
    w = Vector{Int}(undef, K)
    if modo == LINEAL
        @inbounds for j in 1:K
            w[j] = 2K - 2j + 1
        end
        return (w, ingreso / (2K))
    else
        @inbounds for j in 1:K
            w[j] = 1
        end
        return (w, ingreso / K)
    end
end

"""Varianza y media teóricas del modelo, para comprobar el oráculo."""
function media_teorica(lam::Real, f::Real, ret::Retencion, ingreso::Real;
                       modo::Vesting = LINEAL)
    θ = lam * f * ret.Tv
    return modo == LINEAL ? ret.rho * ingreso * θ / 2 : ret.rho * ingreso * θ
end

function varianza_teorica(lam::Real, f::Real, ret::Retencion, ingreso::Real;
                          modo::Vesting = LINEAL)
    θ = lam * f * ret.Tv
    return modo == LINEAL ? ret.rho^2 * ingreso^2 * θ / 3 : ret.rho^2 * ingreso^2 * θ
end

# ----------------------------------------------------------------- utilidades

masa_en(d::DistDiscreta, x::Real) = begin
    i = round(Int, x / d.paso)
    (i < 0 || i > length(d.masas) - 1) ? 0.0 : d.masas[i+1]
end

"""`P(B ≤ x)`."""
function cdf_dist(d::DistDiscreta, x::Real)
    i = floor(Int, x / d.paso + 1e-9)
    i < 0 && return 0.0
    i = min(i, length(d.masas) - 1)
    s = 0.0
    @inbounds for j in 0:i
        s += d.masas[j+1]
    end
    return s
end

cola_dist(d::DistDiscreta, x::Real) = max(0.0, sum(d.masas) - cdf_dist(d, x))

function media_dist(d::DistDiscreta)
    s = 0.0
    @inbounds for i in eachindex(d.masas)
        s += (i - 1) * d.paso * d.masas[i]
    end
    return s
end

function varianza_dist(d::DistDiscreta)
    m = media_dist(d)
    s = 0.0
    @inbounds for i in eachindex(d.masas)
        s += ((i - 1) * d.paso - m)^2 * d.masas[i]
    end
    return s
end

function cuantil_dist(d::DistDiscreta, q::Real)
    acc = 0.0
    @inbounds for i in eachindex(d.masas)
        acc += d.masas[i]
        acc >= q && return (i - 1) * d.paso
    end
    return (length(d.masas) - 1) * d.paso
end

function poisson_pmf(θ::Real, n::Integer)
    θ <= 0 && return n == 0 ? 1.0 : 0.0
    l = -θ + n * log(θ)
    for i in 1:n
        l -= log(i)
    end
    return exp(l)
end

"""Composiciones de `N` en `K` cajas no negativas (recursivo, orden lexicográfico)."""
function pmf_composiciones(N::Int, K::Int)
    out = Vector{Vector{Int}}()
    K == 1 && (push!(out, Int[N]); return out)
    for i in 0:N
        for resto in pmf_composiciones(N - i, K - 1)
            push!(out, vcat(i, resto))
        end
    end
    return out
end

"""Peso multinomial de la composición `comp` de `N` bloques en `K` bins: `N!/(Π n_j!)·K^{−N}`."""
function peso_composicion(comp::Vector{Int}, N::Int, K::Int)
    w = 1.0
    resto = N
    for c in comp                       # Π_j C(resto_j, c_j) = N!/(Π n_j!)
        for i in 1:c
            w *= resto / i
            resto -= 1
        end
    end
    return w / Float64(K)^N
end

"""Saldos (índices enteros) y probabilidades por enumeración multinomial explícita."""
function enumerar_saldos(θ::Real, K::Int, N_max::Int, w::Vector{Int})
    acc = Dict{Int,Float64}()
    for N in 0:N_max
        pN = poisson_pmf(θ, N)
        pN == 0 && continue
        for comp in pmf_composiciones(N, K)
            idx = 0
            @inbounds for j in 1:K
                idx += w[j] * comp[j]
            end
            acc[idx] = get(acc, idx, 0.0) + pN * peso_composicion(comp, N, K)
        end
    end
    idxs = sort!(collect(keys(acc)))
    return (idxs, [acc[i] for i in idxs])
end

"""Distribución del saldo por enumeración multinomial explícita. El coste es el número de
composiciones, `C(N+K−1, K−1)`: crece muy rápido, así que se usa sólo con `N_max` de una decena y
`K` pequeño (es el oráculo lento, no el kernel)."""
function dist_enumerada(lam::Real, f::Real, ret::Retencion, ingreso::Real;
                        K::Int = 8, N_max::Int = 10, modo::Vesting = LINEAL)
    w, paso_grid = pesos_enteros(K, modo, ret.rho, ingreso)
    paso = ret.rho * paso_grid
    θ = lam * f * ret.Tv
    # Con ρ = 0 no hay nada retenido: B ≡ 0 y la distribución es la delta en 0. Sin este corte la
    # rejilla degenera (paso = 0) y reparte la masa por índices sin sentido (defecto O12).
    (θ <= 0 || ret.rho <= 0) && return DistDiscreta(paso, [1.0])
    idxs, ps = enumerar_saldos(θ, K, N_max, w)
    masas = zeros(Float64, maximum(idxs) + 1)
    for (i, p) in zip(idxs, ps)
        masas[i+1] += p
    end
    return DistDiscreta(paso, masas)
end

"""Igual que `dist_enumerada` con `Rational{BigInt}`. Devuelve `(idxs, probs, paso_racional)`.
El peso de Poisson se fija con denominador `10^30` DECLARADO."""
function dist_exacta_racional(rho::Rational{BigInt}, ingreso::Rational{BigInt},
                              θ_aprox::Float64, K::Int, N_max::Int; modo::Vesting = LINEAL)
    den = big(10)^30
    w = Vector{Int}(undef, K)
    for j in 1:K
        w[j] = modo == LINEAL ? 2K - 2j + 1 : 1
    end
    acc = Dict{Int,Rational{BigInt}}()
    for N in 0:N_max
        pN = Rational{BigInt}(round(BigInt, poisson_pmf(θ_aprox, N) * Float64(den)), den)
        pN == 0 && continue
        for comp in pmf_composiciones(N, K)
            idx = sum(w[j] * comp[j] for j in 1:K)
            wm = factorial(big(N))
            for c in comp
                wm = wm ÷ factorial(big(c))
            end
            acc[idx] = get(acc, idx, big(0)//big(1)) + pN * wm // big(K)^N
        end
    end
    idxs = sort!(collect(keys(acc)))
    paso = modo == LINEAL ? rho * ingreso // big(2K) : rho * ingreso // big(K)
    return (idxs, [acc[i] for i in idxs], paso)
end

# --------------------------------------------------------------- colas y cotas

"""`P(B = 0) = e^{−θ}`, exacta en el modelo (basta `N = 0`)."""
masa_cero_exacta(lam::Real, f::Real, ret::Retencion) = exp(-lam * f * ret.Tv)

"""Aproximación normal de `P(B = 0)`: `Φ(−μ/σ)` con `μ = E[B]`, `σ² = Var[B]` EXACTOS del modelo
(γ = 1/2 lineal, γ = 1 escalón). Se publica para MEDIR su error; no decide ninguna cifra.

OJO: usar la desviación típica del NÚMERO de bloques (`√θ`) en vez de la del SALDO (`√(γθ)`) es un
defecto real que se cometió en `rapido.jl` y que este instrumento corrige (PROGRESO.md O9)."""
function masa_cero_aprox(lam::Real, f::Real, ret::Retencion, ingreso::Real;
                         modo::Vesting = LINEAL)
    θ = lam * f * ret.Tv
    γ = modo == LINEAL ? 0.5 : 1.0
    μ = ret.rho * ingreso * γ * θ
    σ2 = ret.rho^2 * ingreso^2 * (modo == LINEAL ? θ / 3 : θ)
    σ2 <= 0 && return 1.0
    return 0.5 * erfc(μ / sqrt(2 * σ2))
end

"""Cola por el método de los momentos sobre `K` bins. Devuelve `(valor, media, varianza)`.
APROXIMACIÓN: sirve para declarar el error, no para decidir."""
function cola_aproximada(lam::Real, f::Real, ret::Retencion, ingreso::Real, x::Real;
                         K::Int = 16, modo::Vesting = LINEAL)
    w, paso = pesos_enteros(K, modo, ret.rho, ingreso)
    θ = lam * f * ret.Tv
    # S = Σ w'_j n_j ~ Poisson compuesto: E = θ·Σw'/K, Var = θ·Σ(w'^2)/K
    mS = θ * sum(w) / K
    vS = θ * sum(abs2, w) / K
    vS <= 0 && return (x >= paso * mS ? 1.0 : 0.0, paso * mS, 0.0)
    z = (x / paso - mS) / sqrt(vS)
    return (0.5 * erfc(-z / sqrt(2)), paso * mS, paso^2 * vS)
end

# ------------------------- CDF por recursión EXACTA sobre la rejilla de K bins

"""CDF del saldo para un número FIJO `m` de bloques en la ventana, por DP EXACTA sobre la rejilla
de pesos enteros.

FORMULACIÓN. Estado `estado[s+1, i+1]` = `P(S_j = s, Σ_{l<j} w'_l n_l = i)`, donde `S_j` es el número
de bloques que aún NO se han repartido al empezar el bin `j` (`S_1 = m`). En el bin `j` caen `k` de
esos `s` bloques; los `s−k` restantes siguen vivos para los bins `j+1..K`:

    nuevo[(s−k)+1, i + k·w'_j] += estado[s+1, i] · P(n_j = k | S_j = s)

con `P(n_j = k | S_j = s) = C(s,k)·p^k·(1−p)^{s−k}` y `p = 1/(K−j+1)` (probabilidad de que un bloque
de los que quedan caiga justo en el bin `j`). Es la descomposición secuencial del multinomial
(Agresti) leída como reparto del remanente. Massa total conservada en cada bin — se comprueba en
los tests.

**Sin aproximación**: la única truncación es la rejilla, que es exacta porque los pesos `w'_j` son
enteros. Coste `O(K·m²·maxidx)`, memoria `O(m·maxidx)`.

Los tres defectos de las versiones anteriores están en `PROGRESO.md` O2 y O3: convolución que perdía
la masa de `N = 0`; `nuevo[fila, :]` que en Julia COPIA en vez de ser una vista; y el índice de fila
`S` mal puesto, que dejaba la masa en una fila que el bin siguiente ya no leía."""
function cdf_m_bins(m::Int, K::Int, w::Vector{Int}, xmax::Real, paso_grid::Float64,
                     rho::Real = 1.0)
    maxidx = m * sum(w)
    # C(s,k) por recurrencia entera (la recurrencia de la binomial en k NO sirve entre bins
    # distintos porque p cambia con j: defecto O4 de PROGRESO.md)
    C = Vector{Vector{Float64}}(undef, m + 1)
    for s in 0:m
        v = Vector{Float64}(undef, s + 1)
        v[1] = 1.0
        for k in 1:s
            v[k+1] = v[k] * (s - k + 1) / k
        end
        C[s+1] = v
    end
    estado = zeros(Float64, m + 1, maxidx + 1)
    estado[m+1, 1] = 1.0                     # S_1 = m
    for j in 1:K
        idxj = w[j]
        p = 1 / (K - j + 1)                  # P(un bloque del remanente cae en el bin j)
        nuevo = zeros(Float64, m + 1, maxidx + 1)
        for s in 0:m
            fila_s = @view estado[s+1, :]
            any(!iszero, fila_s) || continue
            for k in 0:s                     # k = n_j; el remanente pasa a s − k
                wbin = C[s+1][k+1] * p^k * (1 - p)^(s - k)
                wbin == 0 && continue
                des = k * idxj
                @inbounds for i in 0:(maxidx-des)
                    e = fila_s[i+1]
                    e == 0 && continue
                    nuevo[s-k+1, i+1+des] += e * wbin
                end
            end
        end
        estado = nuevo
    end
    paso = rho * paso_grid
    imax = paso > 0 ? min(maxidx, floor(Int, xmax / paso + 1e-9)) : -1
    s = 0.0
    # tras el último bin S_{K+1} = 0: TODA la masa está en la fila 1 (defecto O5 de PROGRESO.md)
    @inbounds for i in 0:imax
        s += estado[1, i+1]
    end
    return clamp(s, 0.0, 1.0)
end

"""CDF `P(B ≤ x)` por mezcla EXACTA sobre `m` (número de bloques en la ventana), sin Monte Carlo:

    P(B ≤ x) = Σ_{m≥0} Poisson(θ)(m) · P(B ≤ x | m)

y `P(B ≤ x | m)` se calcula con `cdf_m_bins` (exacto en la rejilla entera). Se corta en `M_corte`
cuando `Poisson(θ)(m) < 1e-18` o cuando el mínimo alcanzable de `B` con `m` bloques supera `x`
(entonces `P(B ≤ x | m') = 0` para todo `m' ≥ m`, y el corte es EXACTO, no aproximado).

Devuelve `(cdf, m_corte, exacto::Bool)`."""
function cdf_exacta(lam::Real, f::Real, ret::Retencion, ingreso::Real, x::Real;
                    K::Int = 32, M_max::Int = 4096, modo::Vesting = LINEAL)
    θ = lam * f * ret.Tv
    (θ <= 0 || ret.rho <= 0) && return (1.0, 0, true)   # B ≡ 0 ⇔ P(B ≤ x) = 1 para x ≥ 0
    w, paso_grid = pesos_enteros(K, modo, ret.rho, ingreso)
    paso = ret.rho * paso_grid
    total = exp(-θ)                    # m = 0 ⇒ B = 0 ≤ x
    MC = 0
    for m in 1:M_max
        pm = poisson_pmf(θ, m)
        if pm < 1e-18
            return (clamp(total, 0.0, 1.0), m - 1, true)
        end
        # mínimo alcanzable con m bloques: todos en el bin de menor peso
        minB = paso * m * minimum(w)
        if minB > x
            return (clamp(total, 0.0, 1.0), m - 1, true)
        end
        total += pm * cdf_m_bins(m, K, w, x, paso_grid, ret.rho)
        MC = m
    end
    return (clamp(total, 0.0, 1.0), MC, false)
end

"""Cota inferior EXACTA y rigurosa: `P(B ≤ x) ≥ P(N = 0) = e^{−θ}` para todo `x ≥ 0`."""
cota_cola_inferior(lam::Real, f::Real, ret::Retencion) = exp(-lam * f * ret.Tv)

# ------------------------------------------------- oráculo por espacios exponenciales

"""Muestreador EXACTO por espacios exponenciales. Dado `m`, sortea `m+1` variables `Exp(1)` y
devuelve `(saldo, m)`. Es la vía independiente contra la que se comprueba el kernel."""
function muestra_espaciado!(rng, θ::Float64, coef::Float64; modo::Vesting = LINEAL,
                            M_max::Int = 1_000_000)
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
                n > M_max && break
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
    if modo == LINEAL
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

end # module Referencia
