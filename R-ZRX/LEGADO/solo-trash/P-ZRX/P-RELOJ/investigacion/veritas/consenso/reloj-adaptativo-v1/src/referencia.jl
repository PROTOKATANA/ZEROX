# referencia.jl — oráculos exactos y transparentes para los tres modelos.
#
# Regla de `veritas/LINEO.md` §5.3: la vía rápida no puede falsificar una conclusión matemática.
# Aquí van las rutas EXACTAS (`Rational{BigInt}` y aritmética entera) y el oráculo por
# fuerza bruta del sesgo de mediana. Todo lo de este archivo es pequeño y lento a propósito.

module Referencia



using ..Modelos: Adaptador, en_dominio_pot04, N_MAX_TIPO

const BigRat = Rational{BigInt}

# ================================================================ R1 · frontera exacta
#
# `(ADM)`: N·tv ≤ ε·N·tp con N > 0. Se reduce a `tv/(K·tp) ≤ ε`. Exacto.

"""
    admisible_exacto(tp, tv, K, ε) -> Bool

`(ADM)` con `Rational{BigInt}`. No hay flotante en la decisión.
"""
admisible_exacto(tp::BigRat, tv::BigRat, K::Integer, ε::BigRat) =
    tv / (K * tp) <= ε

"`N_max` exacto: `ε·τ/tv`, sin redondear. Devuelve el racional tal cual, no un flotante."
N_max_exacto(ε::BigRat, τ::BigRat, tv::BigRat) = ε * τ / tv

# ================================================================ R2 · mediana adversarial
#
# El sesgo de la mediana de una ventana de `W` timestamps con `C` posiciones controladas.
# Ventana de `W = 2m+1`; la mediana es la posición `m+1` en orden ascendente.
#
# PROPOSICIÓN (se demuestra en el INFORME). Sea una ventana de `W = 2m+1` timestamps con
# monotonía estricta, `C` posiciones controladas por el adversario y `W − C` honestas. Entonces:
#   (i)  si `C ≥ m+1`, el adversario fija la mediana y su sesgo máximo hacia abajo es `−δ`
#        (puede poner su mediana en el mínimo permitido por la monotonía, `δ` por debajo de la
#        escala honesta);
#   (ii) si `C ≤ m`, la mediana es una posición honesta; el sesgo máximo hacia abajo es `0`
#        (el adversario sólo puede subir los valores, nunca bajarlos por debajo de la escala
#        honesta, porque la monotonía y el `C` insuficiente le dejan el valor mediano en manos
#        honestas).
# La fuerza bruta de abajo es el ORÁCULO independiente de esta proposición.

"""
    sesgo_mediana_dp(W, C, δ, φ; escala = 1.0) -> (abajo, arriba)

ORÁCULO del sesgo máximo de la MEDIANA de una ventana de `W` timestamps, con `C` posiciones en
manos del adversario. Es independiente de la cota cerrada de `Modelos.sesgo_mediana_adversario`.

MODELO. Los `W − C` bloques honestos llevan timestamps sobre una escala creciente de `escala`
segundos por bloque honesto. El adversario coloca sus `C` bloques donde quiere; cada uno puede
subir hasta `φ` o bajar hasta `δ` respecto del valor anterior, y **la monotonía obliga a que
ningún valor baje del último valor honesto visto hasta esa posición** (`C-TS-01` no admite
retrocesos). El estado es `(mínimo alcanzable, máximo alcanzable, posiciones usadas)`: como los
valores extremos son monótonos, la frontera de Pareto del conjunto alcanzable la forman esos dos,
y el valor en la posición mediana es alcanzable si cae en `[mín, máx]`.

Devuelve el mínimo y el máximo valor alcanzable de la MEDIANA.
"""
function sesgo_mediana_dp(W::Integer, C::Integer, δ::Real, φ::Real; escala::Real = 1.0)
    (W >= 1 && 0 <= C <= W) || throw(ArgumentError("0 ≤ C ≤ W"))
    (δ >= 0 && φ >= 0) || throw(ArgumentError("δ, φ ≥ 0"))
    escala > 0 || throw(ArgumentError("escala > 0"))
    hvals = [Float64(j - 1) * Float64(escala) for j in 1:max(W - C, 1)]
    md = W ÷ 2 + 1

    # Estado: (mínimo en la última posición, máximo en la última posición, usadas, valor_mediana).
    # El valor de la mediana se arrastra como su propio intervalo (minmed, maxmed).
    estados = Set{Tuple{Float64,Float64,Int,Float64,Float64}}()
    v1 = hvals[1]
    push!(estados, (v1, v1, 0, md == 1 ? v1 : NaN, md == 1 ? v1 : NaN))
    if C >= 1
        push!(estados, (v1, v1, 1, md == 1 ? v1 : NaN, md == 1 ? v1 : NaN))
    end
    for k in 2:W
        nuevos = Set{Tuple{Float64,Float64,Int,Float64,Float64}}()
        for (lo, hi, c, mlo, mhi) in estados
            # (a) la posición k es honesta: el valor es h(usados_h + 1) y no puede bajar del
            # último valor emitido (monotonía), pero puede superarlo.
            uh = k - 1 - c
            if uh < length(hvals)
                v = max(hvals[uh + 1], lo)
                nlo = mlo; nhi = mhi
                if k == md
                    nlo = isnan(mlo) ? v : min(mlo, v)
                    nhi = isnan(mhi) ? v : max(mhi, v)
                end
                push!(nuevos, (v, v, c, nlo, nhi))
            end
            # (b) la posición k es del adversario: su valor está en [lo, hi] y se mueve hasta
            # δ por debajo o φ por encima, pero NUNCA por debajo del suelo honesto ya alcanzado
            # (si el bloque del adversario quedara por detrás del tiempo real, el timestamp
            # dejaría de ser una medición del reloj y la ventana no daría duración).
            if c + 1 <= C
                for v in (max(lo - δ, hi - δ), max(hi + φ, lo - δ))
                    nlo = mlo; nhi = mhi
                    if k == md
                        nlo = isnan(mlo) ? v : min(mlo, v)
                        nhi = isnan(mhi) ? v : max(mhi, v)
                    end
                    push!(nuevos, (v, v, c + 1, nlo, nhi))
                end
            end
        end
        estados = nuevos
        isempty(estados) && break
    end
    abajo = 0.0; arriba = 0.0
    for (_, _, c, mlo, mhi) in estados
        c == C || continue
        isnan(mlo) && continue
        mlo < abajo && (abajo = mlo)
        mhi > arriba && (arriba = mhi)
    end
    return (abajo, arriba)
end

# ================================================================ R3 · adaptador exacto
#
# La MISMA ley de control que `Modelos.simular!`, pero con `Rational{BigInt}` en N, de modo que
# el redondeo al múltiplo de 16 y la comparación con los límites son exactos. Sirve para validar
# que la versión Float64 de `simular!` no cambia el signo de ningún ajuste.

"""
    simular_exacto(hw, p) -> Vector{BigInt}

Adaptador con aritmética exacta. `hw` en `Rational{BigInt}` (segundos por bloque). La ley es
idéntica a `Modelos.simular!`: el objetivo es `τ = N_objetivo · t_bloque`, y `t_bloque` entra
TAMBIÉN en exacto, de modo que las dos rutas no se separan por redondear el objetivo de dos
formas distintas. Con hardware y `N` enteros, las dos trazas coinciden bit a bit.
"""
function simular_exacto(hw::Vector{BigRat}, p::Adaptador)
    T = length(hw)
    N = BigInt(p.N_inicial)
    Nmin = BigInt(p.N_min)
    Nmax = BigInt(p.N_max)
    τobj = BigInt(p.N_objetivo) * BigRat(p.t_bloque)     # exacto, del MISMO Float64 que el lazo
    g = BigRat(p.ganancia)
    traza = Vector{BigInt}(undef, T)
    traza[1] = N
    for s in 2:T
        idx = max(s - p.retardo, 1)
        τobs = BigRat(traza[idx]) * hw[idx]
        e = τobj / τobs - 1
        prop = N * (1 + g * e)
        # División entera hacia abajo: es la semántica de `floor(Int64, x)` del kernel rápido.
        ip = numerator(prop) ÷ denominator(prop)
        ip = (ip ÷ 16) * 16
        ip = clamp(ip, Nmin, Nmax)
        if ip == N || abs(ip - N) < p.paso_minimo
            # sin cambio
        elseif ip < N && p.trinquete
            # sin cambio
        elseif ip < N && p.caducidad > 0 && (s - idx) > p.caducidad
            # sin cambio
        else
            N = ip
        end
        traza[s] = N
    end
    return traza
end

# ================================================================ R4 · dominio de C-POT-04
#
# Enumeración completa de los valores de N que NO pertenecen al dominio, junto a los que sí.
# Es pequeño a propósito: el dominio es un predicado, no un rango que haya que recorrer.

"""
    casos_dominio() -> Vector{Tuple{UInt64,Bool}}

Pares `(N, en_dominio)` para los casos de borde de `C-POT-04`: 0, 1, 15, 16, 17, u32::MAX−1,
u32::MAX, u32::MAX+1 y el mayor múltiplo de 16 que cabe. La etiqueta es la que el oráculo exige.
"""
function casos_dominio()
    return [(UInt64(0), false),
            (UInt64(1), false),
            (UInt64(15), false),
            (UInt64(16), true),
            (UInt64(17), false),
            (UInt64(4_294_967_295), false),          # u32::MAX, no múltiplo de 16
            (UInt64(4_294_967_296), false),          # fuera de u32
            (UInt64(4_294_967_280), true),           # mayor múltiplo de 16 que cabe
            (UInt64(4_294_967_264), true),
            (N_MAX_TIPO, true)]
end

"Comprueba los casos de borde con el predicado del modelo. Devuelve `true` si TODOS coinciden."
function dominio_concuerda()
    for (n, esperado) in casos_dominio()
        obtenido = en_dominio_pot04(n)
        obtenido == esperado || return false
    end
    return true
end

end # module
