# Certificacion con aritmetica de bolas (`Arblib`, LINEO §5.3). Todo numero de `L(t)`, de la raiz
# de Lundberg y de la tasa `I` que aparezca en `INFORME.md` sale de aqui: la version `Float64` es
# para barrer, esta es para publicar. Si una bola contiene el umbral, el resultado es
# **inconcluso** y se dice; no se redondea a favor de la hipotesis.

const PREC = 160

"""
    bola_cero_a(e; prec=PREC) -> Arb

La bola mas pequena que contiene el intervalo `[0, e]`. Es como se suma una cola truncada: no se
desprecia, se convierte en incertidumbre explicita.
"""
function bola_cero_a(e::Real; prec::Int=PREC)
    u = Arb(0; prec=prec)
    Arblib.union!(u, Arb(0; prec=prec), Arb(float(e); prec=prec))
    return u
end


"""
    cola_poisson_chernoff(m, μ; prec=PREC) -> Arb

Cota **elemental y rigurosa** de la cola de Poisson, por Chernoff:

    P(N ≥ m) ≤ exp(m − μ − m·log(m/μ))   para m > μ
    P(N ≤ m) ≤ exp(m − μ − m·log(m/μ))   para m < μ

Se usa en lugar de la gamma incompleta regularizada para acotar la masa fuera de la ventana.
Motivo medido: con `μ = 600` y `m = 2171` —el borde de una ventana de 64 sigmas—, la evaluacion
por intervalos de `hypgeom_gamma_lower` devuelve una bola de radio `10^{130}` (y tarda decenas de
segundos), y esa bola se propagaba entera al resultado. La cota de Chernoff es solo `exp`, `log` y
productos: estable, inmediata y sin cancelacion.
"""
function cola_poisson_chernoff(m::Integer, μ::Arb; prec::Int=PREC)
    m <= 0 && return Arb(1; prec=prec)
    mm = Arb(m; prec=prec)
    return exp(mm - μ - mm * log(mm / μ))
end

"""
    log_poisson_arb(μ, n; prec=PREC) -> Arb

`log P(Poisson(μ)=n) = n·log μ − μ − lgamma(n+1)`, con encierre.
"""
function log_poisson_arb(μ::Arb, n::Integer; prec::Int=PREC)
    lg = Arb(0; prec=prec)
    Arblib.lgamma!(lg, Arb(n + 1; prec=prec))
    return n * log(μ) - μ - lg
end

"""
    tabla_poisson_arb(μ, jmax; prec) -> (pmf, acum_le, acum_ge, cola_alta)

Tabula `P(Poisson(μ)=j)` para `j = 0..jmax` por la recurrencia `p(j) = p(j−1)·μ/j`, y de ahí las
dos acumuladas: `acum_le[k] = P(N ≤ k)` (suma hacia delante) y `acum_ge[m] = P(N ≥ m)` (suma hacia
**atrás**, más la cola de Chernoff por encima de `jmax` como bola).

**Por qué no se usa `hypgeom_gamma_*` para esto.** Medido: con `μ = 600` y `m = 844`,
`Arblib.hypgeom_gamma_lower` regularizada a 160 bits devuelve `[± 8,8·10^{111}]`, y con `m = 617`
la bola ya es tan ancha que arruinaba el resultado: `L(600)` salía con radio `0,24` en vez de
`10^{-26}`. Aquí todo son sumas de términos **positivos** —sin una sola resta— así que el encierre
no puede degradarse: es el patrón de dos velocidades de LINEO §5.3 aplicado a la cola.
"""
function tabla_poisson_arb(μ::Arb, jmax::Int; prec::Int=PREC)
    pmf = Vector{Arb}(undef, jmax + 1)
    pmf[1] = exp(-μ)
    @inbounds for j in 1:jmax
        pmf[j+1] = pmf[j] * μ / j
    end
    acum_le = Vector{Arb}(undef, jmax + 1)
    acc = Arb(0; prec=prec)
    @inbounds for j in 0:jmax
        acc += pmf[j+1]
        acum_le[j+1] = copy(acc)
    end
    cola = cola_poisson_chernoff(jmax + 1, μ; prec=prec)
    bola = bola_cero_a(Float64(Arblib.ubound(cola)); prec=prec)
    acum_ge = Vector{Arb}(undef, jmax + 2)
    acum_ge[jmax+2] = bola
    @inbounds for j in jmax:-1:0
        acum_ge[j+1] = acum_ge[j+2] + pmf[j+1]
    end
    return (pmf, acum_le, acum_ge, bola)
end

"""
    jmax_poisson(μ, tol; prec) -> Int

El corte `jmax` tal que la cota de Chernoff de `P(N ≥ jmax+1)` baja de `tol`. Crece por pasos de
media desviación hasta conseguirlo.
"""
function jmax_poisson(μ::Float64, tol::Float64; prec::Int=PREC)
    μ <= 0 && return 1
    σ = sqrt(μ)
    j = ceil(Int, μ + 8 * σ) + 8
    a = Arb(μ; prec=prec)
    for _ in 1:400
        Float64(Arblib.ubound(cola_poisson_chernoff(j + 1, a; prec=prec))) < tol && return j
        j += max(1, ceil(Int, σ / 2))
    end
    return j
end

"""
    suma_ventana_arb(μ₁, μ₂, r, cual; prec, objetivo) -> Arb

Núcleo común de `prob_no_positivo_arb` (`cual = :no_positivo`) y `prob_positivo_arb`
(`cual = :positivo`). Encierre riguroso: suma en bolas sobre la ventana de `n₁`, con las
probabilidades interiores leídas de la tabla acumulada de `tabla_poisson_arb`, y **toda** la masa
no sumada —la de fuera de la ventana— añadida como bola `[0, cota]`.

Todos los sumandos son positivos y todas las tablas se construyen sin restas, así que el encierre
que sale es tan estrecho como la precisión permita, no tan ancho como el peor intervalo intermedio.
"""
function suma_ventana_arb(μ₁::Arb, μ₂::Arb, r::Rational{Int64}, cual::Symbol; prec::Int=PREC,
                          objetivo::Float64=1e-24)
    m1 = Float64(Arblib.midpoint(μ₁))
    m2 = Float64(Arblib.midpoint(μ₂))
    if m1 <= 0
        return cual === :no_positivo ? Arb(1; prec=prec) : Arb(0; prec=prec)
    end
    lo, hi, _, _ = ventana_poisson(m1, objetivo)
    tol = objetivo / 1000
    j1 = max(hi, jmax_poisson(m1, tol; prec=prec))
    j2 = max(techo_racional(r, hi) + 1, jmax_poisson(m2, tol; prec=prec))
    p1, _, _, _ = tabla_poisson_arb(μ₁, j1; prec=prec)
    _, le2, ge2, _ = tabla_poisson_arb(μ₂, j2; prec=prec)

    s = Arb(0; prec=prec)
    for n1 in lo:hi
        w = p1[n1+1]
        m = techo_racional(r, n1)
        q = if cual === :no_positivo
            m <= 0 ? Arb(1; prec=prec) : (m > j2 ? ge2[j2+2] : ge2[m+1])
        else
            m <= 0 ? Arb(0; prec=prec) : (m - 1 > j2 ? Arb(1; prec=prec) : le2[m])
        end
        s += w * q
    end
    cola = (lo == 0 ? Arb(0; prec=prec) : cola_poisson_chernoff(lo - 1, μ₁; prec=prec)) +
           cola_poisson_chernoff(hi + 1, μ₁; prec=prec)
    return s + bola_cero_a(Float64(Arblib.ubound(cola)); prec=prec)
end

"""
    prob_no_positivo_arb(μ₁, μ₂, r; prec=PREC, objetivo=1e-24) -> Arb

`P(r·N₁ ≤ N₂)` con encierre riguroso. Ver `suma_ventana_arb`.
"""
prob_no_positivo_arb(μ₁::Arb, μ₂::Arb, r::Rational{Int64}; prec::Int=PREC,
                     objetivo::Float64=1e-24) =
    suma_ventana_arb(μ₁, μ₂, r, :no_positivo; prec=prec, objetivo=objetivo)

"""
    prob_positivo_arb(μ₁, μ₂, r; prec=PREC, objetivo=1e-24) -> Arb

`P(r·N₁ > N₂)` con el mismo encierre.
"""
prob_positivo_arb(μ₁::Arb, μ₂::Arb, r::Rational{Int64}; prec::Int=PREC,
                  objetivo::Float64=1e-24) =
    suma_ventana_arb(μ₁, μ₂, r, :positivo; prec=prec, objetivo=objetivo)

"""
    lundberg_arb(f; prec=PREC) -> Arb

Encierre certificado de la raiz de Lundberg `R`, por **biseccion en aritmetica de bolas**: en cada
paso se decide el signo de `g` en el punto medio con `Arblib.is_negative` / `is_positive`, de modo
que el corchete `[lo,hi]` **contiene** la raiz en todo momento por el teorema de Bolzano, y se
estrecha hasta el orden de `2^{-0,8·prec}`.

No basta con afinar `R` «lo suficiente»: `R` entra despues en `exp(±R)` multiplicando medias de
Poisson del orden de `10^2`, y la evaluacion por intervalos de la gamma incompleta **amplifica**
el radio del argumento varios miles de veces. Con un `R` de radio `10^{-13}` la bola de `L(t)`
salia con radio `10^{-8}`, inservible para hablar de `ε = 10^{-9}`. Con esta biseccion el radio de
`R` baja a `10^{-40}` y deja de ser el termino dominante.
"""
function lundberg_arb(f::Flujos; prec::Int=PREC)
    g = canonico(f)
    deriva(g) <= 0 && return Arb(0; prec=prec)
    rr = Arb(numerator(g.r); prec=prec) / Arb(denominator(g.r); prec=prec)
    l1 = Arb(g.λ₁; prec=prec); l2 = Arb(g.λ₂; prec=prec)
    gg(x) = l1 * (exp(-x * rr) - 1) + l2 * (exp(x) - 1)

    R0 = lundberg(g)
    lo = Arb(R0 / 2; prec=prec)
    for _ in 1:200
        Arblib.is_negative(gg(lo)) && break
        lo /= 2
    end
    Arblib.is_negative(gg(lo)) || error("lundberg_arb: no se pudo anclar el extremo inferior")
    hi = Arb(max(2 * R0, 1.0); prec=prec)
    for _ in 1:200
        Arblib.is_positive(gg(hi)) && break
        hi *= 2
    end
    Arblib.is_positive(gg(hi)) || error("lundberg_arb: no se pudo anclar el extremo superior")

    objetivo = Arb(2; prec=prec)^(-div(4 * prec, 5))
    for _ in 1:4 * prec
        (hi - lo) < objetivo && break
        mid = (lo + hi) / 2
        v = gg(mid)
        if Arblib.is_positive(v)
            hi = mid
        elseif Arblib.is_negative(v)
            lo = mid
        else
            break
        end
    end
    res = Arb(0; prec=prec)
    Arblib.union!(res, lo, hi)
    return res
end

"""
    prob_cambio_posterior_arb(f, t; prec=PREC, objetivo=1e-24) -> Arb

`L(t)` certificado: el mismo encierre que `prob_cambio_posterior`, con la raiz de Lundberg como
bola y las dos sumas de Poisson en aritmetica de bolas. La bola devuelta **contiene** `L(t)`.

Incluye el encierre de la ruina (`h(d) ∈ [e^{−R(d+1)}, e^{−Rd}]`, exacto si `r` es entero), de
modo que la anchura de la bola es la suma del error numerico y de la incertidumbre de exceso al
cruzar el cero. Las dos estan a la vista.
"""
function prob_cambio_posterior_arb(f::Flujos, t::Real; prec::Int=PREC,
                                   objetivo::Float64=0.0)
    g = canonico(f)
    objetivo = objetivo > 0 ? objetivo : min(1e-24, objetivo_automatico(g, t))
    R = lundberg_arb(g; prec=prec)
    rr = Arb(numerator(g.r); prec=prec) / Arb(denominator(g.r); prec=prec)
    tt = Arb(float(t); prec=prec)
    A = prob_no_positivo_arb(Arb(g.λ₁; prec=prec) * tt, Arb(g.λ₂; prec=prec) * tt, g.r;
                             prec=prec, objetivo=objetivo)
    B = prob_positivo_arb(Arb(g.λ₁; prec=prec) * tt * exp(-R * rr),
                          Arb(g.λ₂; prec=prec) * tt * exp(R), g.r; prec=prec, objetivo=objetivo)
    if denominator(g.r) == 1
        return A + B
    end
    factor = Arb(0; prec=prec)
    Arblib.union!(factor, exp(-R), Arb(1; prec=prec))
    return A + factor * B
end

"""
    tasa_grandes_desvios_arb(f; prec=PREC) -> Arb

`I` certificada, por la forma cerrada `θ* = log(λ₁r/λ₂)/(1+r)`, `I = λ₁+λ₂ − λ₁e^{−θ*r} − λ₂e^{θ*}`,
evaluada en bolas.
"""
function tasa_grandes_desvios_arb(f::Flujos; prec::Int=PREC)
    g = canonico(f)
    deriva(g) <= 0 && return Arb(0; prec=prec)
    rr = Arb(numerator(g.r); prec=prec) / Arb(denominator(g.r); prec=prec)
    l1 = Arb(g.λ₁; prec=prec); l2 = Arb(g.λ₂; prec=prec)
    θ = log(l1 * rr / l2) / (1 + rr)
    return l1 + l2 - l1 * exp(-θ * rr) - l2 * exp(θ)
end
