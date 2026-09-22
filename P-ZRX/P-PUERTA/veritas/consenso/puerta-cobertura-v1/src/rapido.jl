# Kernel rapido en Float64 para `L(t)` = P(el signo del lider vuelva a cambiar despues de `t`)
# y para `t(ε)`. Cada suma es de terminos **positivos** y su truncacion esta acotada por colas
# exactas de Poisson: no hay ningun recorte, y el valor verdadero siempre queda encerrado.

"""
    techo_racional(r, n) -> Int

`ceil(r·n)` exacto para `r::Rational{Int64}` y `n` entero, en `Int128` para que el producto no
desborde con `n` del orden de `10^8`.
"""
function techo_racional(r::Rational{Int64}, n::Integer)
    p = Int128(numerator(r)) * Int128(n)
    q = Int128(denominator(r))
    return Int(cld(p, q))
end

"""
    techo_desplazado(r, n, b) -> Int

`⌈r·n − b⌉` exacto para `r`, `b` racionales y `n` entero, en `Int128` para que el producto no
desborde. Es el indice de Poisson que separa `D ≤ b` de `D > b`, y se calcula en aritmetica
racional porque con `r` cerca de 1 y `n ~ 10^7` un `ceil` en `Float64` se equivoca de entero.
"""
function techo_desplazado(r::Rational{Int64}, n::Integer, b::Rational{Int64})
    dr = Int128(denominator(r)); db = Int128(denominator(b))
    num = Int128(numerator(r)) * Int128(n) * db - Int128(numerator(b)) * dr
    return Int(cld(num, dr * db))
end

"""
    ventana_poisson(μ, objetivo; k_max=64.0) -> (lo, hi, cola_baja, cola_alta)

Ventana `[lo,hi]` de `n` tal que la masa de `Poisson(μ)` fuera de ella no supera `objetivo`.
Las dos colas se calculan con la gamma incompleta regularizada (exactas, no acotadas a ojo):

    cola_baja = P(N ≤ lo−1) = Q_gamma(lo, μ)
    cola_alta = P(N ≥ hi+1) = P_gamma(hi+1, μ)

Si no se alcanza `objetivo` con `k_max` desviaciones, devuelve la ventana mas ancha probada y su
cola real, que el llamante propaga como error: nunca se silencia.
"""
function ventana_poisson(μ::Float64, objetivo::Float64; k_max::Float64=64.0)
    μ <= 0 && return (0, 0, 0.0, 0.0)
    σ = sqrt(μ)
    k = 8.0
    lo = 0; hi = 0; cb = 0.0; ca = 0.0
    while true
        lo = max(0, floor(Int, μ - k * σ))
        hi = max(1, ceil(Int, μ + k * σ))
        cb = lo == 0 ? 0.0 : gamma_inc(float(lo), μ)[2]
        ca = gamma_inc(float(hi) + 1, μ)[1]
        (cb + ca <= objetivo || k >= k_max) && break
        k *= 1.5
    end
    return (lo, hi, cb, ca)
end

"""
    log_poisson(μ, n) -> Float64

`log P(Poisson(μ) = n)` en espacio logaritmico: con `μ ~ 10^7` el calculo directo se desborda.
"""
log_poisson(μ::Float64, n::Integer) = n * log(μ) - μ - loggamma(float(n) + 1)

"""
    prob_le(μ₁, μ₂, r, b; objetivo) -> (valor, cota)

`P(r·N₁ − N₂ ≤ b)` con `N₁ ~ Poisson(μ₁)`, `N₂ ~ Poisson(μ₂)` independientes y `b` racional.

`D ≤ b` equivale a `n₂ ≥ ⌈r·n₁ − b⌉`, asi que la suma es sobre `n₁` de
`P(N₁=n₁)·P(N₂ ≥ ⌈r·n₁ − b⌉)`. Todos los sumandos son positivos, luego el valor verdadero esta en
`[valor, valor + cota]`, donde `cota` es la masa de Poisson(μ₁) excluida por la ventana.

Generaliza `prob_no_positivo` (que es el caso `b = 0`) y es lo que hace falta para las
probabilidades de **banda** del congelamiento: `P(a < D ≤ b) = prob_le(b) − prob_le(a)`.
"""
function prob_le(μ₁::Float64, μ₂::Float64, r::Rational{Int64}, b::Rational{Int64};
                 objetivo::Float64=1e-18)
    if μ₁ <= 0
        m = techo_desplazado(r, 0, b)
        q = m <= 0 ? 1.0 : (μ₂ <= 0 ? 0.0 : gamma_inc(float(m), μ₂)[1])
        return (q, 0.0)
    end
    lo, hi, cb, ca = ventana_poisson(μ₁, objetivo)
    lμ = log(μ₁)
    s = 0.0
    @inbounds for n1 in lo:hi           # `lo:hi` son Int por construccion de ventana_poisson
        lp = n1 * lμ - μ₁ - loggamma(float(n1) + 1)
        lp < -745.0 && continue
        m = techo_desplazado(r, n1, b)
        q = m <= 0 ? 1.0 : (μ₂ <= 0 ? 0.0 : gamma_inc(float(m), μ₂)[1])
        q == 0.0 && continue
        s += exp(lp) * q
    end
    return (s, cb + ca)
end

"""
    prob_no_positivo(μ₁, μ₂, r; objetivo) -> (valor, cota)

`P(r·N₁ − N₂ ≤ 0)`. Es `prob_le` con `b = 0`.
"""
prob_no_positivo(μ₁::Float64, μ₂::Float64, r::Rational{Int64}; objetivo::Float64=1e-18) =
    prob_le(μ₁, μ₂, r, 0 // 1; objetivo=objetivo)

"""
    prob_positivo(μ₁, μ₂, r; objetivo) -> (valor, cota)

`P(r·N₁ − N₂ > 0)`. Suma de `P(N₁=n₁)·P(N₂ ≤ ⌈r·n₁⌉−1)`, con la misma politica de ventana y de
error: el valor verdadero esta en `[valor, valor + cota]`.
"""
function prob_positivo(μ₁::Float64, μ₂::Float64, r::Rational{Int64}; objetivo::Float64=1e-18)
    μ₁ <= 0 && return (0.0, 0.0)
    lo, hi, cb, ca = ventana_poisson(μ₁, objetivo)
    lμ = log(μ₁)
    s = 0.0
    @inbounds for n1 in lo:hi
        lp = n1 * lμ - μ₁ - loggamma(float(n1) + 1)
        lp < -745.0 && continue
        m = techo_racional(r, n1)
        m <= 0 && continue
        q = μ₂ <= 0 ? 1.0 : gamma_inc(float(m), μ₂)[2]
        q == 0.0 && continue
        s += exp(lp) * q
    end
    return (s, cb + ca)
end


"""
    objetivo_automatico(f, t) -> Float64

La masa de Poisson que se permite dejar fuera de la ventana, elegida **en funcion del tamano del
resultado** y no fijada a ojo.

Es lo que evita el defecto silencioso mas facil de cometer aqui: `L(t)` decae como `e^{−I·t}`, y
la contribucion dominante a `P(D(t) ≤ 0)` viene de un `n₁` muy por debajo de la media. Con una
ventana de `±10σ` alrededor de la media, esa region queda **fuera**, la suma devuelve un numero
pequeno que no es `L(t)` sino el residuo de los terminos que si entraron, y la cota de truncacion
—correcta— acaba siendo mil billones de veces mayor que el valor. El encierre seguia siendo
valido, pero inutil.

Se fija `objetivo = 10^{-4}·2e^{−I·t}`: un diezmilesimo de la cota de Chernoff del propio `L(t)`,
con suelo en `10^{-300}`. Asi la ventana se ensancha justo hasta donde vive el resultado.
"""
function objetivo_automatico(f::Flujos, t::Real)
    I = tasa_grandes_desvios(f)
    I <= 0 && return 1e-18
    cota = 2 * exp(-I * float(t))
    return max(1e-300, min(1e-12, 1e-4 * cota))
end

"""
    tasa_grandes_desvios(f) -> Float64

La tasa exponencial `I` con la que `L(t)` decae. Es `I = −min_{θ>0} g(θ)` con
`g(θ) = λ₁(e^{−θr}−1) + λ₂(e^{θ}−1)`, y tiene forma cerrada porque `g` es convexa con derivada
elemental:

    θ* = log(λ₁·r/λ₂)/(1+r)        I = λ₁ + λ₂ − λ₁e^{−θ*r} − λ₂e^{θ*}

El mismo `I` acota **los dos** sumandos de `L(t)`: el de `D(t) ≤ 0` por Chernoff directo, y el
del proceso inclinado porque su exponente cumple `ψ̃(θ) = ψ(θ−R)` y el minimo cae dentro de
`(−R, 0)`. De ahi `L(t) ≤ 2·e^{−I·t}` (ver `prob_cambio_posterior` y `tiempo_suficiente`).
"""
function tasa_grandes_desvios(f::Flujos)
    g = canonico(f)
    deriva(g) <= 0 && return 0.0
    rr = float(g.r)
    θ = log(g.λ₁ * rr / g.λ₂) / (1 + rr)
    return -(g.λ₁ * expm1(-θ * rr) + g.λ₂ * expm1(θ))
end

"""
    prob_cambio_posterior(f, t; objetivo) -> (inf, sup)

**El entregable 2 del encargo**: `L(t)` = probabilidad de que el signo del lider vuelva a cambiar
en algun instante posterior a `t`, con horizonte infinito. Devuelve un **encierre** `[inf, sup]`
que contiene el valor verdadero.

Descomposicion, exacta y sin recortes:

    L(t) = P(D(t) ≤ 0)·1  +  E[ h(D(t))·1(D(t) > 0) ]

porque con deriva positiva, desde `D ≤ 0` el signo vuelve a cambiar con probabilidad 1. Para el
segundo sumando se usa `h(d) ∈ [e^{−R(d+1)}, e^{−R d}]` (`prob_ruina`) y la identidad de
inclinacion exponencial

    E[e^{−R·D(t)}·1(D(t)>0)] = P(D̃(t) > 0),    λ̃₁ = λ₁e^{−R r},  λ̃₂ = λ₂e^{R}

que vale porque `E[e^{−R D(t)}] = e^{t·ψ(−R)} = 1` por definicion de `R`. Los dos sumandos son
«probabilidades del lado equivocado» y **decaen los dos**, asi que no hay ninguna resta de
numeros grandes: por eso no hace falta ningun `min(1.0, ·)`.

Con deriva nula (`R = 0`) los dos sumandos son `P(D≤0)` y `P(D>0)` y la funcion **calcula** 1;
no se devuelve 1 escrito a mano.
"""
function prob_cambio_posterior(f::Flujos, t::Real; objetivo::Float64=0.0)
    g = canonico(f)
    R = lundberg(g)
    objetivo = objetivo > 0 ? objetivo : objetivo_automatico(g, t)
    rr = float(g.r)
    tt = float(t)
    A, eA = prob_no_positivo(g.λ₁ * tt, g.λ₂ * tt, g.r; objetivo)
    B, eB = prob_positivo(g.λ₁ * tt * exp(-R * rr), g.λ₂ * tt * exp(R), g.r; objetivo)
    exacto = denominator(g.r) == 1
    inf = A + (exacto ? B : exp(-R) * B)
    sup = A + eA + B + eB
    return (inf, sup)
end

"""
    tiempo_suficiente(f, ε) -> Float64

El `t` a partir del cual la cota de Chernoff `2e^{−I t}` ya vale menos que `ε`: un tiempo
**suficiente** certificado, `log(2/ε)/I`. Con deriva nula devuelve `Inf`, que es el resultado
correcto: `L ≡ 1` y no existe tal `t`.
"""
function tiempo_suficiente(f::Flujos, ε::Real)
    I = tasa_grandes_desvios(f)
    I <= 0 && return Inf
    return log(2 / float(ε)) / I
end

"""
    tiempo_hasta(f, ε; objetivo, mu_max) -> (t_inf, t_sup)

**El segundo entregable del punto 2**: el instante a partir del cual `L(t) < ε`, como encierre.

`L(t)` decae como `C(t)·e^{−I·t}` con `C` de variacion lenta, asi que en vez de biseccionar —que
costaria ~160 evaluaciones y cada evaluacion recorre una ventana de `O(√(λt))` terminos— se
arranca del tiempo **suficiente** certificado `log(2/ε)/I` y se itera

    t ← t + log(L(t)/ε)/I

que es Newton sobre `log L` con la pendiente asintotica, y converge en unas pocas pasadas. Se hace
dos veces: sobre el **supremo** del encierre (da `t_sup`, que garantiza el umbral) y sobre el
**infimo** (da `t_inf`, por debajo del cual el umbral seguro que no se cumplia).

**Presupuesto.** Si la media de Poisson necesaria supera `mu_max`, la evaluacion exacta se sale
del presupuesto declarado y la funcion devuelve `(NaN, NaN)`: entonces lo unico publicable es
`tiempo_suficiente`, que es una cota **superior** certificada. No se sustituye por una
extrapolacion.
"""
function tiempo_hasta(f::Flujos, ε::Real; objetivo::Float64=0.0, mu_max::Float64=2.0e8,
                      iter::Int=14)
    g = canonico(f)
    I = tasa_grandes_desvios(g)
    I <= 0 && return (Inf, Inf)
    εf = float(ε)
    obj = objetivo > 0 ? objetivo : max(εf * 1e-4, 1e-300)
    t0 = log(2 / εf) / I
    Λ = g.λ₁ + g.λ₂
    Λ * t0 > mu_max && return (NaN, NaN)

    function newton(cual::Int)
        t = t0
        for _ in 1:iter
            v = prob_cambio_posterior(g, t; objetivo=obj)[cual]
            (v <= 0 || !isfinite(v)) && break
            tn = t + log(v / εf) / I
            tn <= 0 && (tn = t / 2)
            paso = abs(tn - t)
            t = tn
            paso <= 1e-7 * max(t, 1.0) && break
        end
        return max(t, 0.0)
    end
    t_sup = newton(2)
    t_inf = newton(1)
    return (min(t_inf, t_sup), max(t_inf, t_sup))
end

"""
    prob_empate(f, t; objetivo) -> (valor, cota)

`P(D(t) = 0)`: la masa que la convencion de empate (H-EMPATE) puede mover de un lado al otro. Es
**la cota de sensibilidad** de `L(t)` a esa convencion, y por eso se publica junto a `L`.

Con `r = p/q` en forma reducida, `D = 0` exige `q | n₁` y `n₂ = (p/q)·n₁`, asi que la suma recorre
solo los multiplos de `q`. Decae como `O(1/√t)`.
"""
function prob_empate(f::Flujos, t::Real; objetivo::Float64=0.0)
    g = canonico(f)
    objetivo = objetivo > 0 ? objetivo : objetivo_automatico(g, t)
    tt = float(t)
    μ₁ = g.λ₁ * tt; μ₂ = g.λ₂ * tt
    μ₁ <= 0 && return (μ₂ <= 0 ? 1.0 : exp(-μ₂), 0.0)
    q = denominator(g.r); pnum = numerator(g.r)
    lo, hi, cb, ca = ventana_poisson(μ₁, objetivo)
    lμ1 = log(μ₁)
    s = 0.0
    n1 = lo + mod(-lo, q)
    while n1 <= hi
        n2 = (n1 ÷ q) * pnum
        lp = n1 * lμ1 - μ₁ - loggamma(float(n1) + 1)
        lp2 = μ₂ <= 0 ? (n2 == 0 ? 0.0 : -Inf) : n2 * log(μ₂) - μ₂ - loggamma(float(n2) + 1)
        tot = lp + lp2
        tot > -745.0 && (s += exp(tot))
        n1 += q
    end
    return (s, cb + ca)
end

"""
    prob_banda(f, t, δ; objetivo) -> (valor, cota)

`P(|D(t)| ≤ δ)`, con `δ` en unidades de `w₂`. Es la **cota de banda** del congelamiento divergente:
dos nodos cuyas vistas de `D` difieren como mucho en `δ` solo pueden discrepar sobre quién lidera
si `D` está dentro de esa banda alrededor de cero.

Se calcula como `prob_le(δ) − prob_le(−δ)`, una resta de dos sumas de términos positivos; el error
que se devuelve es la suma de las dos cotas de truncación, no su diferencia.
"""
function prob_banda(f::Flujos, t::Real, δ::Real; objetivo::Float64=1e-18)
    g = canonico(f)
    tt = float(t)
    d = Rational{Int64}(rationalize(Int64, float(δ); tol=1e-9))
    μ₁ = g.λ₁ * tt; μ₂ = g.λ₂ * tt
    vhi, ehi = prob_le(μ₁, μ₂, g.r, d; objetivo=objetivo)
    vlo, elo = prob_le(μ₁, μ₂, g.r, -d; objetivo=objetivo)
    return (max(vhi - vlo, 0.0), ehi + elo)
end

"""
    delta_red(f, τ) -> Float64

El peso **en vuelo** durante un desfase de vista de `τ` segundos, en unidades de `w₂`:
`(λ₁·r + λ₂)·τ`. Es la escala natural de `δ` para `prob_banda`: lo que un nodo retrasado `τ`
todavía no ha visto.
"""
delta_red(f::Flujos, τ::Real) = (f.λ₁ * float(f.r) + f.λ₂) * float(τ)

"""
    prob_congelamiento_divergente(f, F, τ; objetivo) -> (valor, cota)

**La probabilidad de que la red se congele partida**, bajo la regla de R-FIN-7 leída por su letra:
la profundidad de la reorganización necesaria para cambiar de flujo es `t − t_j`, así que **todos
los nodos se congelan a la vez en `t_j + F`**, cada uno en el flujo que su propia vista diga que
lidera en ese instante.

Con vista común no hay divergencia posible: todos ven el mismo `D` y se congelan juntos. La única
grieta es el **desfase de vista**: si un nodo va `τ` segundos por detrás de otro, sus vistas son
`D(F−τ)` y `D(F)`, y se congelan en flujos distintos **si y solo si el líder cambió durante esos
últimos `τ` segundos**:

    P_div(F, τ) = P( sign D(F−τ) ≠ sign D(F) )

Se calcula condicionando por el **incremento** `ΔD` sobre la ventana `τ` —que tiene pocos eventos,
`Poisson(λτ)`— y usando probabilidades de banda para `D(F−τ)`:

    P_div = Σ_{e ≠ 0} P(ΔD = e) · P( D(F−τ) ∈ I_e ),   I_e = (0,−e] si e<0;  (−e,0] si e>0

En el límite de difusión sin deriva tiene forma cerrada —`arcsin(√(τ/F))/π`, ver
`congelamiento_arcoseno`— y decae como `√(τ/F)`: para dividirla por dos hay que **cuadruplicar `F`**.
"""
function prob_congelamiento_divergente(f::Flujos, F::Real, τ::Real; objetivo::Float64=1e-14)
    g = canonico(f)
    FF = float(F); tt = float(τ)
    tt <= 0 && return (0.0, 0.0)
    tt >= FF && throw(ArgumentError("el desfase de vista τ debe ser menor que F"))
    s = FF - tt
    μ₁ = g.λ₁ * s; μ₂ = g.λ₂ * s
    ν₁ = g.λ₁ * tt; ν₂ = g.λ₂ * tt
    _, M1, _, ca1 = ventana_poisson(ν₁, objetivo)
    _, M2, _, ca2 = ventana_poisson(ν₂, objetivo)
    cache = Dict{Rational{Int64},Tuple{Float64,Float64}}()
    leb(b::Rational{Int64}) = get!(() -> prob_le(μ₁, μ₂, g.r, b; objetivo=objetivo), cache, b)
    total = 0.0; err = 0.0
    for m1 in 0:M1
        lp1 = ν₁ <= 0 ? (m1 == 0 ? 0.0 : -Inf) : m1 * log(ν₁) - ν₁ - loggamma(float(m1) + 1)
        lp1 < -745.0 && continue
        for m2 in 0:M2
            lp2 = ν₂ <= 0 ? (m2 == 0 ? 0.0 : -Inf) : m2 * log(ν₂) - ν₂ - loggamma(float(m2) + 1)
            lp2 < -745.0 && continue
            e = g.r * m1 - m2
            e == 0 && continue
            w = exp(lp1 + lp2)
            a, b = e < 0 ? (zero(Rational{Int64}), -e) : (-e, zero(Rational{Int64}))
            va, ea = leb(a)
            vb, eb = leb(b)
            total += w * max(vb - va, 0.0)
            err += w * (ea + eb)
        end
    end
    return (total, err + ca1 + ca2)
end

"""
    congelamiento_arcoseno(F, τ) -> Float64

La forma cerrada de `prob_congelamiento_divergente` en el límite de difusión **sin deriva**:

    P_div = (1/π)·arcsin(√(τ/F))

`(D(F−τ), D(F))` es normal bivariante de correlación `ρ = √((F−τ)/F)`, y la probabilidad de que dos
normales con esa correlación caigan en cuadrantes opuestos es `1/2 − arcsin(ρ)/π`; con
`arcsin(√(1−x)) = π/2 − arcsin(√x)` queda `arcsin(√(τ/F))/π`.

**No confundir con `(2/π)·arcsin(√(τ/F))`**, que es `P(hay un cero en (F−τ, F))`: un paseo puede
cruzar el cero y volver al mismo lado, así que ese suceso es el **doble** de frecuente y sería la
magnitud equivocada. La primera versión de esta función usaba esa fórmula y sobrestimaba el
resultado por un factor 2 exacto; lo detectó el contraste contra `prob_congelamiento_divergente`.

Decae como `√(τ/F)`: para dividir la probabilidad por dos hay que **cuadruplicar `F`**.
"""
congelamiento_arcoseno(F::Real, τ::Real) = asin(sqrt(min(float(τ) / float(F), 1.0))) / π
