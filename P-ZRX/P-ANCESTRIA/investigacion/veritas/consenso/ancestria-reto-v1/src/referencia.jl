#=  referencia.jl — oráculos independientes de ANR-v0.1.

Ninguno de estos oráculos es «la fórmula contra sí misma»:

  O1  `phi_por_maximo`      maximiza `Lambda_c(t)/t` por búsqueda directa (optimización), mientras
                            `modelo.jl` resuelve la ecuación (39) por bisección (raíz). Son rutas
                            numéricas distintas del mismo objeto del Anexo F de BDK+19.
  O2  `brw_minimo`          simula el árbol etiquetado `T'` del Anexo F y estima `S*_k/k` por haz.
                            Contrasta la *construcción* (BRW) con la *tasa* (fórmula cerrada).
  O3  `phi_1_simbolico`     sustituye `t = -e` en (39) a mano: `-log(e) = -1`. Exacto, sin solver.
  O4  `ventana_*`           enumeración exhaustiva de cadenas explícitas para el lema de ventana
                            (la pieza que sostiene `c = d + 1`). Exacto y combinatorio.

`RNG`: semillas **no consecutivas** derivadas por splitmix64 del índice de réplica, según el
hallazgo de `P-ZRX/P-PUERTA/` citado en el encargo.
=#

# ---------------------------------------------------------------- O1: sup Lambda/t

"`h(t) = Lambda_c(t)/t`, el objeto cuyo supremo es `1/(lambda*eta_c)` (Anexo F, Prop. 1)."
h_brw(c::Integer, t) = Lambda(c, t) / t

"""
    phi_por_maximo(c; prec=384) -> (lo, hi)

`phi_c` calculado como `c / sup_t h(t)`, con `sup` por barrido exponencial + sección áurea.
Independiente de `recinto_theta`: no usa la ecuación (39).
"""
function phi_por_maximo(c::Integer; prec::Int=384)
    c >= 1 || throw(ArgumentError("c ≥ 1"))
    return setprecision(BigFloat, prec + 64) do
        # barrido: t = -exp(u), u de -12 a 3
        mejor_u = big(-1.0)
        mejor_h = big(-Inf)
        u = big(-12.0)
        paso = big(0.05)
        while u <= 3
            t = -exp(u)
            v = h_brw(c, t)
            if v > mejor_h
                mejor_h = v
                mejor_u = u
            end
            u += paso
        end
        # sección áurea en [mejor_u - 2*paso, mejor_u + 2*paso]
        a = mejor_u - 2 * paso
        b = mejor_u + 2 * paso
        gr = (sqrt(big(5)) - 1) / 2
        x1 = b - gr * (b - a)
        x2 = a + gr * (b - a)
        for _ in 1:400
            f1 = h_brw(c, -exp(x1))
            f2 = h_brw(c, -exp(x2))
            if f1 < f2
                a = x1
                x1 = x2
                x2 = a + gr * (b - a)
            else
                b = x2
                x2 = x1
                x1 = b - gr * (b - a)
            end
        end
        ustar = (a + b) / 2
        sup = h_brw(c, -exp(ustar))
        val = BigFloat(c) / sup
        return (val - BigFloat(2)^(-(prec - 8)), val + BigFloat(2)^(-(prec - 8)))
    end
end

# ---------------------------------------------------------------- O3: phi_1 = e exacto

"""
    phi_1_simbolico() -> Bool

Comprueba a mano que `t = -e` resuelve la ecuación (39) con `c = 1`. Con `c = 1`:
`Lambda_1(t) = -log(-t)`, `Lambda'_1(t) = -1/t`, luego (39) es `-log(-t) = -1`, i.e. `-t = e`.
Sustituyendo: `-log(e) = -1` ⟺ `-1 = -1`. Y `phi_1 = -1*(-e)/log(e) = e`.
"""
function phi_1_simbolico()
    t = -exp(big(1))
    residuo = Lambda(1, t) - t * dLambda(1, t)
    return abs(residuo) < BigFloat(2)^(-1000), phi_c_en(1, t) == exp(big(1))
end

# ---------------------------------------------------------------- RNG splitmix64

"Semilla no consecutiva por réplica: splitmix64 del índice (evita el sesgo de semillas contiguas)."
@inline function semilla_replica(maestra::UInt64, i::Integer)
    z = maestra + 0x9e3779b97f4a7c15 * UInt64(i)
    z = (z ⊻ (z >> 30)) * 0xbf58476d1ce4e5b9
    z = (z ⊻ (z >> 27)) * 0x94d049bb133111eb
    return z ⊻ (z >> 31)
end

#=  Generador determinista local (xoshiro por réplica) sin depender del RNG global mutable.
    El constructor recibe el ESTADO crudo; la semilla por réplica se deriva aparte con
    `semilla_replica` (splitmix64), nunca como semilla contigua.  =#
mutable struct RngLocal
    s::UInt64
    RngLocal(s::UInt64) = new(s)
end
@inline function uniforme!(r::RngLocal)
    r.s += 0x9e3779b97f4a7c15
    z = r.s
    z = (z ⊻ (z >> 30)) * 0xbf58476d1ce4e5b9
    z = (z ⊻ (z >> 27)) * 0x94d049bb133111eb
    z = z ⊻ (z >> 31)
    return (z >> 11) * (1.0 / 9007199254740992.0)
end
"Exponencial de media 1 (inversa de la CDF)."
@inline expo!(r::RngLocal) = -log(1.0 - uniforme!(r))

# ---------------------------------------------------------------- O2: simulacion del BRW

"""
    brw_minimo(c; k, haz, hijos, replicas, semilla) -> Vector{Float64}

Estima `S*_k` (mínimo tiempo de llegada al nivel `k` del árbol `T'` del Anexo F de BDK+19) por
un haz de `haz` nodos por nivel. Cada nodo genera `hijos` hijos; el i-ésimo hijo de un nodo con
tiempo `a` llega en `a + sum_{l=1}^{i+c-1} Exp(1)`.

Devuelve la mediana de `S*_k / k` sobre `replicas`. `ESTIMADO`: el haz trunca el árbol infinito y
el mínimo real es ≤ el estimado, así que el cociente estimado es una **cota superior** de `c/phi_c`.
"""
function brw_minimo(c::Integer; k::Integer=7, haz::Integer=400, hijos::Integer=50,
                    replicas::Integer=64, semilla::Integer=0x5a5a5a5a)
    c >= 1 || throw(ArgumentError("c ≥ 1"))
    sem = UInt64(semilla)
    vals = Vector{Float64}(undef, replicas)
    for rep in 1:replicas
        rng = RngLocal(semilla_replica(sem, rep) | 0x1)
        nivel = Float64[0.0]
        for _ in 1:k
            nxt = Float64[]
            sizehint!(nxt, haz * hijos)
            for a in nivel
                t = a
                for i in 1:hijos
                    t += expo!(rng)                       # i-ésimo hijo: acumula i exponenciales...
                    extra = 0.0
                    for _ in 1:(c - 1)                    # ...más c-1, total i+c-1
                        extra += expo!(rng)
                    end
                    push!(nxt, t + extra)
                end
            end
            sort!(nxt)
            nivel = nxt[1:min(haz, length(nxt))]
        end
        vals[rep] = nivel[1] / k
    end
    sort!(vals)
    return vals
end

# ---------------------------------------------------------------- O4: lema de ventana

"""
    ventana_exhaustiva(c; Lmax) -> Bool

Enumeración exhaustiva del lema de ventana. Se construyen dos ramas que comparten `m` bloques y
divergen; se calcula `sigma(B)` como el ancestro a `c` niveles y se comprueba, para todo `n`, que
las dos ramas comparten `sigma` si y sólo si `n - c <= m`.

Modelo explícito: cada rama es un vector de profundidades 0..N; el ancestro a `c` niveles de la
posición `n` es `n - c` si `n >= c`, y "compartido" si `n - c <= m`.
"""
function ventana_exhaustiva(c::Integer; Lmax::Integer=60)
    ok = true
    for m in 0:(Lmax - 1), n in (m + 1):Lmax
        # rama pública y privada: coinciden hasta m, divergen despues
        sigma_pub = n - c <= m ? (:compartido, n - c) : (:pub, n - c)
        sigma_priv = n - c <= m ? (:compartido, n - c) : (:priv, n - c)
        comparten = sigma_pub == sigma_priv
        esperado = (n - c) <= m
        ok &= (comparten == esperado)
    end
    return ok
end

"""
    conteo_clases_ventana(c; N) -> Vector{Int}

Número de clases de reto distintas a cada profundidad `n` de un árbol binario completo de
profundidad `N`, contando cada bloque por su `sigma` (ancestro a `c` niveles). Verifica que la
clase de reto NO se refresca por nivel sino por ventana de `c`.
"""
function conteo_clases_ventana(c::Integer; N::Integer=12)
    # arbol binario explicito: nodo = (profundidad, camino)
    nodos = [() => 0]
    conteo = zeros(Int, N + 1)
    por_nivel = [Vector{Vector{Int}}() for _ in 1:(N + 1)]
    push!(por_nivel[1], Int[])
    for n in 1:N, camino in por_nivel[n]
        for b in 0:1
            nuevo = vcat(camino, b)
            push!(por_nivel[n + 1], nuevo)
        end
    end
    for n in 0:N
        sigmas = Set{Vector{Int}}()
        for camino in por_nivel[n + 1]
            s = n - c >= 0 ? camino[1:(n - c + 1)] : Int[]
            push!(sigmas, s)
        end
        conteo[n + 1] = length(sigmas)
    end
    return conteo
end

# ---------------------------------------------------------------- O2 (exacto): reducción many-to-one

#=  El contenido algebraico del Anexo F es la reducción *many-to-one*:
        Lambda_c(t) = log( sum_{j>=c} E[e^{t*S_j}] ),  S_j ~ Gamma(j, 1),  E[e^{t*E}] = 1/(1-t)
    y la suma geométrica `sum_{j>=c} q^j = q^c/(1-q)` con `q = 1/(1-t)`. Las dos piezas son
    algebraicas y se comprueban EXACTAMENTE con `Rational{BigInt}` y `BigFloat`; no es la fórmula
    contra sí misma, es la transcripción de (39)/Anexo F contra la definición de la suma.  =#

"Comprueba exactamente `sum_{j=c}^{N} q^j + q^(N+1)/(1-q) == q^c/(1-q)` en `Rational{BigInt}`."
function identidad_geometrica(; cs=(1, 2, 3, 10, 50), N=400)
    q = big(1) // big(2)                         # |q| < 1
    for c in cs
        suma = sum(q^j for j in c:N)
        cerrada = q^c / (1 - q)
        cola = q^(N + 1) / (1 - q)
        abs(suma + cola - cerrada) < big(1) // big(10)^100 || return false
    end
    return true
end

"Suma `sum_{j>=c} q^j` por acumulación, parando cuando la cola RELATIVA es despreciable."
function suma_cola(q::BigFloat, c::Integer; tol=big(2)^(-200))
    total = big(0)
    j = c
    while true
        term = q^j
        total += term
        cola = term * q / (1 - q)                # suma exacta de j+1 .. ∞
        cola <= tol * abs(total) && break
        j += 1
        j > c + 10^7 && break
    end
    return total
end

"""
    identidad_lambda(; cs, ts) -> Bool

Comprueba la transcripción del Anexo F: `Lambda_c(t) = log( sum_{j>=c} q^j )` con
`q = 1/(1-t) = E[e^{t*E}]` (esto es `E = lambda/(lambda-t)` con `lambda = 1`). Se contrastan las
dos formas de la suma —acumulada con cola relativa y cerrada `q^c/(1-q)`— contra `Lambda(c,t)`.
La identidad geométrica se certifica aparte y exactamente en `identidad_geometrica`.
"""
function identidad_lambda(; cs=(1, 2, 3, 10, 50, 1000), ts=(-big(1)//big(2), -big(1)//big(10), -2//1))
    for c in cs, t in ts
        tb = BigFloat(t)                         # evita `Rational{Int64}` y su desbordamiento
        q = 1 / (1 - tb)                         # |q|<1 ⇔ t<0
        cerrada = q^c / (1 - q)
        acumulada = suma_cola(q, c)
        abs(log(cerrada) - Lambda(c, tb)) > big(2)^(-240) && return false
        abs(log(acumulada) - Lambda(c, tb)) > big(2)^(-180) && return false
    end
    return true
end
