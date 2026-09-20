# El proceso de la diferencia de peso entre dos flujos, y las dos cantidades que el encargo pide
# como funciones de (c, s1, lambda, F).
#
# D(t) = w1·N1(t) − w2·N2(t), con N_i procesos de Poisson independientes de tasa λ_i (bloques
# AZULES por unidad de tiempo del flujo i). Se mide D en unidades de w2, de modo que el proceso
# sube en saltos de `r = w1/w2` y **baja en saltos de exactamente 1**.

"""
    fraccion_azul(ν, Δ, k) -> Float64

Fraccion de bloques honestos que GHOSTDAG colorea de azul, bajo el modelo declarado **H-BETA**
(ver `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`): en un DAG honesto de Poisson con tasa `ν` y
retardo de propagacion `Δ`, el anticono de un bloque se aproxima por `Poisson(2νΔ)`, y un bloque
es azul si su anticono no supera `k`:

    β(ν,Δ,k) = P(Poisson(2νΔ) ≤ k)

**No es un teorema de GHOSTDAG.** Es un modelo, y todo resultado que dependa de el se entrega
como dependencia de la razon `β₁/β₂`, nunca con `β` fijada a un numero.
"""
function fraccion_azul(ν::Real, Δ::Real, k::Integer)
    μ = 2 * float(ν) * float(Δ)
    μ <= 0 && return 1.0
    return gamma_inc(float(k) + 1, μ)[2]
end

"""
    espacio_cubridor(c, s₁) -> (W₁, W₂)

El espacio que cubre cada flujo cuando una fraccion `c` del espacio total cubre **los dos** y
`1−c` se reparte en exclusiva `s₁ / (1−s₁)`:

    W_i = c + (1−c)·s_i

El espacio total normalizado a 1 antes de la particion; despues, `W₁+W₂ = 1+c ≥ 1`, porque el
mismo sector se audita contra los dos retos (no se divide el espacio: ese es el error que
`research/dag-poas-ancla-de-finalidad-metaauditoria.md:130-145` documenta).
"""
function espacio_cubridor(c::Rational, s₁::Rational)
    0 <= c <= 1 || throw(ArgumentError("c debe estar en [0,1]"))
    0 <= s₁ <= 1 || throw(ArgumentError("s₁ debe estar en [0,1]"))
    return (c + (1 - c) * s₁, c + (1 - c) * (1 - s₁))
end

"""
    Flujos

Dos flujos en competencia, reducidos a los tres numeros de los que depende toda la dinamica:

- `λ₁`, `λ₂`: tasa de bloques **azules** por unidad de tiempo en cada flujo (solo los azules
  suman a `blue_work`, `SPEC.md:1710`);
- `r = w₁/w₂`: la razon de pesos por bloque, exacta como `Rational`.

`D(t)/w₂` sube `r` a tasa `λ₁` y baja `1` a tasa `λ₂`. Que los saltos de bajada sean todos de
tamano **exactamente 1** es lo que hace que el proceso sea *sin salto hacia abajo* y que la
probabilidad de ruina tenga forma cerrada exacta (ver `prob_ruina`).
"""
struct Flujos
    λ₁::Float64
    λ₂::Float64
    r::Rational{Int64}
end

"""
    deriva(f) -> Float64

`λ₁·r − λ₂`, en unidades de `w₂` por unidad de tiempo. Es la deriva del encargo: con
`w_i ∝ W_i` y `λ₁=λ₂=λ` sale `λ(W₁−W₂)/W₂ = λ(1−c)(s₁−s₂)/W₂`.
"""
deriva(f::Flujos) = f.λ₁ * float(f.r) - f.λ₂

"""
    canonico(f) -> Flujos

Devuelve el mismo par de flujos con los papeles intercambiados si hace falta, de modo que la
deriva sea `≥ 0`. El suceso «el signo del lider cambia» es invariante bajo el intercambio
(`D → −D` deja fijo el conjunto de cruces de cero), asi que ninguna cantidad publicada cambia.
"""
function canonico(f::Flujos)
    deriva(f) >= 0 && return f
    return Flujos(f.λ₂, f.λ₁, 1 // f.r)
end

"""
    flujos_regimen(c, s₁, λ) -> Flujos

Los dos flujos **con el retarget de cada uno ya convergido** (R-FIN-13′, `SPEC.md:1289-1291`).

Cada flujo reajusta su `SR` sobre su propio conjunto pagable, asi que los dos acaban emitiendo a
la **misma** tasa `λ`; lo que difiere es el **peso por bloque**, que vale `w_i = 2^128/(SR_i+1)`
con `SR_i+1 ∝ 1/W_i`, es decir `w_i ∝ W_i`. De ahi `r = W₁/W₂`.

Esta es la razon por la que la fraccion azul no interviene aqui: el retarget fija la misma tasa
en los dos flujos, luego `β₁ = β₂` y la razon `β₁/β₂` vale 1 (ver `MODELO.md` §2).
"""
function flujos_regimen(c::Rational, s₁::Rational, λ::Real)
    W₁, W₂ = espacio_cubridor(c, s₁)
    return canonico(Flujos(float(λ), float(λ), Rational{Int64}(W₁ // W₂)))
end

"""
    flujos_transitorio(c, s₁, ν₀, Δ, k) -> Flujos

Los dos flujos **antes de que el retarget converja**: los dos heredan el `SR` del ultimo bloque
comun, luego `w₁ = w₂` y `r = 1`, y lo que difiere son las tasas:

    ν_i = W_i·ν₀            (tasa de bloques total del flujo i)
    λ_i = β(ν_i,Δ,k)·ν_i    (tasa de bloques azules)

Aqui `β` **si** interviene, y con signo: el flujo minoritario produce mas despacio, tiene menos
anticono y una `β` mayor, luego el transitorio **favorece al minoritario**. Es un Skellam
verdadero (saltos `±1`), a diferencia del regimen.
"""
function flujos_transitorio(c::Rational, s₁::Rational, ν₀::Real, Δ::Real, k::Integer)
    W₁, W₂ = espacio_cubridor(c, s₁)
    ν₁ = float(W₁) * float(ν₀)
    ν₂ = float(W₂) * float(ν₀)
    λ₁ = fraccion_azul(ν₁, Δ, k) * ν₁
    λ₂ = fraccion_azul(ν₂, Δ, k) * ν₂
    return canonico(Flujos(λ₁, λ₂, 1 // 1))
end

"""
    lundberg(f; tol=1e-14, iter_max=200) -> Float64

La unica raiz `R > 0` de

    g(R) = λ₁·(e^{−R·r} − 1) + λ₂·(e^{R} − 1) = 0

que existe si y solo si la deriva `λ₁r − λ₂` es estrictamente positiva (`g(0)=0`, `g′(0) = −(λ₁r−λ₂)`,
`g` convexa y `g(R) → ∞`). Devuelve `0.0` cuando la deriva es `≤ 0`, que es el caso recurrente:
ahi el lider cambia con probabilidad 1 y no hay exponente que calcular.

Biseccion sobre un corchete obtenido doblando; el resultado se certifica aparte con `Arblib`
(`src/certificado.jl`).
"""
function lundberg(f::Flujos; tol::Float64=1e-14, iter_max::Int=200)
    deriva(f) <= 0 && return 0.0
    rr = float(f.r)
    g(R) = f.λ₁ * expm1(-R * rr) + f.λ₂ * expm1(R)
    hi = 1.0
    n = 0
    while g(hi) <= 0
        hi *= 2
        n += 1
        n > 200 && error("lundberg: no se encontro corchete superior")
    end
    lo = 0.0
    for _ in 1:iter_max
        mid = 0.5 * (lo + hi)
        (mid <= lo || mid >= hi) && break
        if g(mid) > 0
            hi = mid
        else
            lo = mid
        end
        hi - lo <= tol * max(hi, 1.0) && break
    end
    return 0.5 * (lo + hi)
end

"""
    prob_ruina(f, d) -> (cota_inf, cota_sup)

**Encierre riguroso** de `P(D(u) ≤ 0 para algun u > 0, partiendo de D(0) = d > 0)`, en unidades
de `w₂`. Devuelve un intervalo que **contiene** el valor verdadero; no devuelve un numero solo
para poder presentarlo como exacto cuando no lo es.

`M_u = e^{−R·D(u)}` es martingala por definicion de `R` (el exponente de Levy del proceso se
anula en `−R`). El proceso baja en saltos de tamano exactamente 1, luego al cruzar el cero acaba
en `D(τ) ∈ (−1, 0]` y `M_τ ∈ [1, e^{R})`. El teorema de parada opcional da

    e^{−R·d} = E[M_τ·1(τ<∞)]   ⟹   e^{−R(d+1)} ≤ P(τ<∞) ≤ e^{−R·d}

**El encierre colapsa a un punto —resultado exacto— cuando `r` es un entero positivo**, porque
entonces `D` vive en la reticula entera, el salto de bajada aterriza exactamente en `0` y
`M_τ = 1`. Ese es el caso del transitorio (`r = 1`), donde se recupera el clasico
`P = (λ₂/λ₁)^d` de Skellam.

Con deriva `≤ 0` (`R = 0`) devuelve `(1, 1)`: el proceso es recurrente o adverso y cruza con
probabilidad 1.
"""
function prob_ruina(f::Flujos, d::Real)
    d <= 0 && return (1.0, 1.0)
    R = lundberg(f)
    R == 0 && return (1.0, 1.0)
    sup = exp(-R * float(d))
    exacto = denominator(f.r) == 1 && numerator(f.r) >= 1
    inf = exacto ? sup : exp(-R * (float(d) + 1))
    return (inf, sup)
end
