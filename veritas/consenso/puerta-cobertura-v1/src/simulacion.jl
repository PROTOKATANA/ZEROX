# Simulacion exacta del proceso de saltos, usada como oraculo independiente de las formulas
# cerradas y como unica via para las magnitudes de excursion (absorcion, instante del ultimo
# cambio de lider) que no tienen forma cerrada.
#
# No hay discretizacion del tiempo: los instantes de bloque son exponenciales exactos. El estado
# de peso se lleva en **enteros**: con `r = p/q`, `Dq = p·n₁ − q·n₂` es el peso en unidades de
# `w₂/q`, y su signo es exacto. Un acumulador Float64 se equivocaria de signo justo donde importa.

"""
    rng_replica(semilla, i) -> Philox4x{UInt64,10}

El generador de la réplica `i`. **Contracontador (Philox), no una semilla consecutiva.**

Medido en este instrumento: `StableRNG(semilla + i)` con `i` consecutivo produce flujos
**correlacionados entre réplicas** —las segundas salidas de semillas consecutivas forman una
progresión aritmética, y la autocorrelación lag-1 de la primera salida sobre 20 000 réplicas es
**−0,43**—, lo que sesga cualquier estimador Monte Carlo que promedie sobre réplicas. Con Philox
esa autocorrelación baja a **−0,0006**. Es lo que LINEO §5.1 pide literalmente: *«Random123.jl:
RNG contracontador/Philox para réplicas paralelas reproducibles. Preferido si cada réplica necesita
flujo independiente reproducible sin estado compartido»*.

La réplica entra como **clave**, no como contador inicial: claves distintas dan flujos
independientes por construcción, y el resultado sigue siendo reproducible bit a bit.
"""
rng_replica(semilla::UInt64, i::Integer) = Philox4x(UInt64, (semilla, UInt64(i)), 10)

"""
    Camino

Resumen de un camino simulado. Campos concretos e `isbits`: es el elemento de los vectores de
replicas, y no debe asignar dentro del bucle.

- `cambios`: numero de cambios de lider observados;
- `t_ultimo`: instante del ultimo cambio de lider dentro del horizonte (`0.0` si no hubo ninguno);
- `t_absorcion`: instante en que se completa la primera racha de signo constante de longitud `F`
  (`Inf` si no se completo dentro del horizonte: **censurado**, no «no ocurre»);
- `divergencia`: `true` si despues de esa racha hubo **otra** racha de longitud `F` con el signo
  contrario — dos nodos bloqueados en flujos distintos;
- `censurado`: `true` si el horizonte acabo sin que se completara ninguna racha de longitud `F`.
"""
struct Camino
    cambios::Int32
    t_ultimo::Float64
    t_absorcion::Float64
    divergencia::Bool
    censurado::Bool
end

"""
    recorrer(rng, f, T, F) -> Camino

Simula `D(u)` para `u ∈ [0,T]` y devuelve el `Camino`.

**Definicion de lider (H-EMPATE).** El flujo 1 lidera **si y solo si `D > 0`**; el empate `D = 0`
va al flujo 2. Es la misma convencion que usa `prob_cambio_posterior`, y por eso formula y
simulacion miden exactamente la misma cosa.

El empate es un **artefacto de la normalizacion**, no del protocolo: en ZEROX los pesos son
enteros de 128 bits derivados de dos `SR` distintos, asi que `n₁w₁ = n₂w₂` exacto tiene
probabilidad del orden de `2^{-128}`, y C-ORD-01 aun lo rompe por `solution_distance` y por id.
La sensibilidad a la convencion esta acotada por `P(D(t)=0)`, que el informe publica: es `O(1/√t)`
y tiende a cero.

**Definicion de absorcion.** La que causa la regla, no una barrera de `K` bloques: bajo adopcion
todo nodo honesto sigue al flujo de mayor `blue_work`, y por R-FIN-7 no reorganiza por debajo de
`F` segundos. Si el signo se mantiene durante `F`, todo nodo que adoptara al principio de esa
racha lleva `F` en ese flujo y ya no puede volver. La absorcion ocurre por tanto en
`inicio_de_la_racha + F`.
"""
function recorrer(rng::AbstractRNG, f::Flujos, T::Float64, F::Float64)
    Λ = f.λ₁ + f.λ₂
    Λ <= 0 && return Camino(Int32(0), 0.0, Inf, false, true)
    p1 = f.λ₁ / Λ
    p = Int64(numerator(f.r))
    q = Int64(denominator(f.r))

    t = 0.0
    Dq = Int64(0)
    signo = Int8(-1)             # D(0)=0 ≤ 0: el flujo 1 aun no lidera
    t_racha = 0.0                # inicio de la racha de signo actual
    cambios = Int32(0)
    t_ultimo = 0.0
    t_abs = Inf
    signo_abs = Int8(0)
    divergencia = false

    while true
        t -= log(rand(rng)) / Λ
        t > T && break
        Dq += rand(rng) < p1 ? p : -q
        nuevo = Dq > 0 ? Int8(1) : Int8(-1)
        if nuevo != signo
            largo = t - t_racha
            if largo >= F
                if isinf(t_abs)
                    t_abs = t_racha + F
                    signo_abs = signo
                elseif signo != signo_abs
                    divergencia = true
                end
            end
            cambios += Int32(1)
            t_ultimo = t
            signo = nuevo
            t_racha = t
        end
    end

    largo = T - t_racha
    if largo >= F
        if isinf(t_abs)
            t_abs = t_racha + F
            signo_abs = signo
        elseif signo != signo_abs
            divergencia = true
        end
    end
    return Camino(cambios, t_ultimo, t_abs, divergencia, isinf(t_abs))
end

"""
    replicas(f, T, F, n, semilla) -> Vector{Camino}

`n` caminos independientes con un RNG derivado de `(semilla, id_de_replica)` —nunca un RNG
compartido, nunca `threadid()` para repartir (LINEO §7)—, escritos cada uno en su posicion
exclusiva. La reduccion posterior recorre el vector en orden de id, asi que es determinista con
cualquier numero de hilos.
"""
function replicas(f::Flujos, T::Real, F::Real, n::Integer, semilla::UInt64)
    out = Vector{Camino}(undef, n)
    TT = float(T); FF = float(F)
    Threads.@threads for i in 1:n
        out[i] = recorrer(rng_replica(semilla, i), f, TT, FF)
    end
    return out
end

"""
    recorrer_realimentado(rng, f0, c, s₁0, λ, ρ, T, F) -> Camino

**La variante con realimentacion** que pide el encargo: los granjeros en exclusiva del flujo que
va perdiendo se cambian al que va ganando.

`s₁` deja de ser constante y relaja hacia el lider a tasa `ρ`: mientras el lider es el flujo 1,
`ds₁/dt = ρ(1−s₁)`; mientras es el 2, `ds₁/dt = −ρ·s₁`; sin lider no se mueve. Entre dos bloques
la solucion es exponencial y se aplica **exacta**, no por pasos.

Regimen con retarget convergido: las **tasas** de bloque no cambian (`λ₁=λ₂=λ`), lo que cambia es
el **peso** por bloque, `w_i ∝ W_i(t)`. Por eso aqui `D` se acumula en `Float64`: los saltos ya
no viven en una reticula. Es la unica parte del instrumento con esa limitacion y esta declarada.
"""
function recorrer_realimentado(rng::AbstractRNG, c::Float64, s₁0::Float64, λ::Float64,
                               ρ::Float64, T::Float64, F::Float64)
    Λ = 2 * λ
    t = 0.0
    s₁ = s₁0
    D = 0.0
    signo = Int8(-1)
    t_racha = 0.0
    cambios = Int32(0)
    t_ultimo = 0.0
    t_abs = Inf
    signo_abs = Int8(0)
    divergencia = false

    while true
        dt = -log(rand(rng)) / Λ
        t + dt > T && break
        t += dt
        if signo == 1
            s₁ = 1 - (1 - s₁) * exp(-ρ * dt)
        elseif signo == -1
            s₁ = s₁ * exp(-ρ * dt)
        end
        W₁ = c + (1 - c) * s₁
        W₂ = c + (1 - c) * (1 - s₁)
        D += rand(rng) < 0.5 ? W₁ : -W₂
        nuevo = D > 0 ? Int8(1) : Int8(-1)
        if nuevo != signo
            largo = t - t_racha
            if largo >= F
                if isinf(t_abs)
                    t_abs = t_racha + F
                    signo_abs = signo
                elseif signo != signo_abs
                    divergencia = true
                end
            end
            cambios += Int32(1)
            t_ultimo = t
            signo = nuevo
            t_racha = t
        end
    end
    largo = T - t_racha
    if largo >= F
        if isinf(t_abs)
            t_abs = t_racha + F
            signo_abs = signo
        elseif signo != signo_abs
            divergencia = true
        end
    end
    return Camino(cambios, t_ultimo, t_abs, divergencia, isinf(t_abs))
end

"""
    replicas_realimentadas(c, s₁, λ, ρ, T, F, n, semilla) -> Vector{Camino}
"""
function replicas_realimentadas(c::Real, s₁::Real, λ::Real, ρ::Real, T::Real, F::Real,
                                n::Integer, semilla::UInt64)
    out = Vector{Camino}(undef, n)
    cc = float(c); ss = float(s₁); ll = float(λ); rr = float(ρ)
    TT = float(T); FF = float(F)
    Threads.@threads for i in 1:n
        out[i] = recorrer_realimentado(rng_replica(semilla, i), cc, ss, ll, rr, TT, FF)
    end
    return out
end

"""
    clopper_pearson(k, n, α=0.05) -> (inf, sup)

Intervalo de confianza **exacto** para una proporcion binomial, por inversion de la binomial
(no la aproximacion normal, que a `k = 0` da el intervalo degenerado `[0,0]` y mentiria).
Se obtiene de los cuantiles Beta, calculados aqui por biseccion sobre la incompleta regularizada.
"""
function clopper_pearson(k::Integer, n::Integer, α::Float64=0.05)
    n == 0 && return (0.0, 1.0)
    inf = k == 0 ? 0.0 : cuantil_beta(α / 2, float(k), float(n - k + 1))
    sup = k == n ? 1.0 : cuantil_beta(1 - α / 2, float(k + 1), float(n - k))
    return (inf, sup)
end

"""
    cuantil_beta(p, a, b) -> Float64

Cuantil `x` con `I_x(a,b) = p`, por biseccion sobre la beta incompleta regularizada calculada a
partir de `beta_inc` de `SpecialFunctions`.
"""
function cuantil_beta(p::Float64, a::Float64, b::Float64)
    lo, hi = 0.0, 1.0
    for _ in 1:200
        mid = 0.5 * (lo + hi)
        (mid <= lo || mid >= hi) && break
        beta_inc(a, b, mid)[1] < p ? (lo = mid) : (hi = mid)
    end
    return 0.5 * (lo + hi)
end

"""
    mc_congelamiento(f, F, τ, n, semilla; α=0.05) -> (p̂, inf, sup)

Oráculo de Monte Carlo de `prob_congelamiento_divergente`, **independiente de toda la teoría**:
simula `D` hasta `F` y cuenta en qué fracción de réplicas el signo en `F−τ` difiere del signo en
`F`. Es exactamente «dos nodos, uno con `τ` segundos de retraso, se congelan en flujos distintos».

El estado sigue en enteros (`Dq = p·n₁ − q·n₂`): el signo es lo que se mide y un acumulador
flotante se equivocaría justo en el cruce. El intervalo es Clopper–Pearson exacto.
"""
function mc_congelamiento(f::Flujos, F::Real, τ::Real, n::Integer, semilla::UInt64;
                          α::Float64=0.05)
    g = canonico(f)
    Λ = g.λ₁ + g.λ₂
    p1 = g.λ₁ / Λ
    p = Int64(numerator(g.r)); q = Int64(denominator(g.r))
    FF = float(F); ss = FF - float(τ)
    hits = Vector{Bool}(undef, n)
    Threads.@threads for i in 1:n
        rng = rng_replica(semilla, i)
        t = 0.0
        Dq = Int64(0)
        signo_s = Int8(-1)
        visto = false
        while true
            t -= log(rand(rng)) / Λ
            if !visto && t > ss
                signo_s = Dq > 0 ? Int8(1) : Int8(-1)   # D(ss): no hubo evento en (último, t)
                visto = true
            end
            t > FF && break
            Dq += rand(rng) < p1 ? p : -q
        end
        visto || (signo_s = Dq > 0 ? Int8(1) : Int8(-1))
        hits[i] = signo_s != (Dq > 0 ? Int8(1) : Int8(-1))
    end
    k = count(hits)
    lo, hi = clopper_pearson(k, n, α)
    return (k / n, lo, hi)
end

"""
    mc_congelamiento_realimentado(c, s₁, λ, ρ, F, τ, n, semilla; α=0.05) -> (p̂, inf, sup)

La misma medida que `mc_congelamiento` —el signo en `F−τ` frente al signo en `F`— pero con la
variante de **realimentación**: los granjeros en exclusiva del flujo que va perdiendo se cambian a
tasa `ρ`, así que `W₁` y `W₂` evolucionan y la deriva crece con el tiempo.

Responde a «cuánto acelera» bajo la regla corregida: no acelera una absorción —que ahora ocurre a
la fuerza en `t_j + F`—, sino que **aleja `D` de cero antes de que llegue ese instante**, que es lo
único que reduce la probabilidad de congelarse partido.
"""
function mc_congelamiento_realimentado(c::Real, s₁0::Real, λ::Real, ρ::Real, F::Real, τ::Real,
                                       n::Integer, semilla::UInt64; α::Float64=0.05)
    cc = float(c); ll = float(λ); rr = float(ρ)
    Λ = 2 * ll
    FF = float(F); ss = FF - float(τ)
    hits = Vector{Bool}(undef, n)
    Threads.@threads for i in 1:n
        rng = rng_replica(semilla, i)
        t = 0.0
        s₁ = float(s₁0)
        D = 0.0
        signo = Int8(-1)
        sg = Int8(-1)
        visto = false
        while true
            dt = -log(rand(rng)) / Λ
            if !visto && t + dt > ss
                sg = D > 0 ? Int8(1) : Int8(-1)
                visto = true
            end
            t + dt > FF && break
            t += dt
            if signo == 1
                s₁ = 1 - (1 - s₁) * exp(-rr * dt)
            else
                s₁ = s₁ * exp(-rr * dt)
            end
            W₁ = cc + (1 - cc) * s₁
            W₂ = cc + (1 - cc) * (1 - s₁)
            D += rand(rng) < 0.5 ? W₁ : -W₂
            signo = D > 0 ? Int8(1) : Int8(-1)
        end
        visto || (sg = D > 0 ? Int8(1) : Int8(-1))
        hits[i] = sg != (D > 0 ? Int8(1) : Int8(-1))
    end
    k = count(hits)
    lo, hi = clopper_pearson(k, n, α)
    return (k / n, lo, hi)
end
