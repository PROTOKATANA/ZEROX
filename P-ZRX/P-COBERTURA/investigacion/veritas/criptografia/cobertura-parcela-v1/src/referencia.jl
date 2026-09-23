# referencia.jl — oráculo exacto, encierre riguroso y frontera combinatoria.
#
# REGLA (LINEO §5.3): la vía rápida no puede falsificar una conclusión. Aquí vive
# la referencia exacta (`Rational{BigInt}`), el encierre con redondeo dirigido
# (`BigFloat`) y la frontera que es pura combinatoria (sin aproximación alguna).

# ── 1 · La frontera es EXACTA y no necesita cálculo ──────────────────────────
"""
Frontera combinatoria. `X` = nº de unidades NO almacenadas entre las `k` abiertas,
`X ~ Hipergeométrica(N, M, k)` (sin reemplazo; `M` = unidades que el tramposo omite).

    P(X > B) = 0   ⟺   M ≤ B   ó   k ≤ B

Demostración (dos líneas, sin aproximación):
  (⇐) si `M ≤ B`, entonces `X ≤ M ≤ B` siempre; si `k ≤ B`, entonces `X ≤ k ≤ B`.
  (⇒) si `M > B` y `k > B`, el suceso «las `k` abiertas incluyen `B+1` de las `M`
      omitidas» tiene probabilidad positiva (basta que `N−M ≥ k−B−1`, que se cumple
      porque `N−M = N−M` y `k ≤ N`), luego `P(X > B) > 0`.

Consecuencia: el **almacenamiento forzado** `1 − B/N` (fracción que el tramposo debe
conservar para que NINGUNA auditoría de `k` aperturas lo detecte) es

    almacenamiento_forzado = max(0, 1 − B/N)   si k > B
    almacenamiento_forzado = 0                 si k ≤ B   (no hace falta almacenar)

`[demostrado]`. Es independiente de `k` en el régimen `k > B`. Etiqueta: teorema
elemental; el instrumento sólo lo COMPRUEBA contra la fórmula exacta en `referencia`.
"""
frontera_exacta(N::Integer, k::Integer, B::Integer) =
    (k <= B) ? (0, 0) : (max(0, N - B), N)

"""
`almacenamiento_forzado` exacto como `Rational{BigInt}`: `1 − B/N` si `k > B`, y `0`
si `k ≤ B`.
"""
function almacenamiento_forzado_exacta(N::Integer, k::Integer, B::Integer)::Rational{BigInt}
    (N >= 1) || throw(ArgumentError("N >= 1"))
    (k <= B) && return zero(Rational{BigInt})
    return max(zero(Rational{BigInt}), 1 - Rational{BigInt}(B, N))
end

# ── 2 · Cola hipergeométrica EXACTA ──────────────────────────────────────────
"""
`P(X > B)`, `X ~ Hipergeométrica(N, M, k)`, exacto en `Rational{BigInt}`.

    P(X = j) = C(M,j)·C(N−M,k−j) / C(N,k)

Complejidad `O(min(k,M))` operaciones con enteros grandes. Sólo se usa en
instancias pequeñas: la referencia contra la que se valida todo lo demás.
"""
function cola_hiper_exacta(N::Integer, M::Integer, k::Integer, B::Integer)::Rational{BigInt}
    (N >= 1) || throw(ArgumentError("N >= 1"))
    (0 <= M <= N) || throw(ArgumentError("M=$M fuera de [0,$N]"))
    (0 <= k <= N) || throw(ArgumentError("k=$k fuera de [0,$N]"))
    den = binomial(BigInt(N), k)
    iszero(den) && return zero(Rational{BigInt})
    num = BigInt(0)
    jmax = min(k, M)
    for j in (B + 1):jmax
        num += binomial(BigInt(M), j) * binomial(BigInt(N - M), k - j)
    end
    return num // den
end

"""
`P(X > B)`, `X ~ Binomial(k, p)` con `p = M/N` (muestreo CON reemplazo), exacto.
Sirve para acotar cuánto se separa el modelo con reemplazo del sin reemplazo.
"""
function cola_binomial_exacta(k::Integer, p::Rational, B::Integer)::Rational{BigInt}
    (0 <= p <= 1) || throw(ArgumentError("p fuera de [0,1]"))
    pp = Rational{BigInt}(p)
    q = 1 - pp
    acc = zero(Rational{BigInt})
    for j in (B + 1):k
        acc += binomial(BigInt(k), j) * pp^j * q^(k - j)
    end
    return acc
end

"""`T` mínimo de auditorías independientes para que la detección acumulada ≥ `1−β`. Exacto."""
function T_para_beta_exacta(p::Rational, beta::Rational)::Int
    (0 < beta < 1) || throw(ArgumentError("beta en (0,1)"))
    pp = Rational{BigInt}(p)
    bb = Rational{BigInt}(beta)
    iszero(pp) && return typemax(Int)
    pp == 1 && return 1
    T = 0
    acum = zero(Rational{BigInt})          # 1 − (1−p)^T
    while 1 - acum > bb
        T += 1
        acum = 1 - (1 - pp)^T
        T > 10^7 && return typemax(Int)    # salvaguarda; nunca se alcanza con p>0
    end
    return T
end

"""Detección acumulada en `T` auditorías independientes: `1 − (1−p)^T`. Exacto."""
deteccion_acumulada_exacta(p::Rational, T::Integer) = 1 - (1 - Rational{BigInt}(p))^T

# ── 3 · Encierre riguroso con redondeo dirigido (N grande) ───────────────────
# P(X=j) por la recursión de razones, partiendo del extremo inferior del soporte
# j0 = max(0, k−(N−M)). Todos los factores son cocientes de enteros positivos y
# toda operación es monótona, así que redondear hacia abajo da una cota INFERIOR
# y redondear hacia arriba una cota SUPERIOR. No hay aproximación sin cota.
function _cola_hiper_redondeada(N::Integer, M::Integer, k::Integer, B::Integer)
    jmax = min(k, M)
    B >= jmax && return BigFloat(0)
    j0 = max(0, k - (N - M))
    # P(X = j0) con TODOS los factores positivos (véase demostración en el INFORME):
    #   P = [∏(M−i)] · [∏(N−M−i)] · [∏(k−j0+i)/i] / [∏(N−i)]
    # El producto de la derecha es C(k,j0) factorizado, para no perder exactitud
    # convirtiendo un entero grande. Con j0=0 se reduce a ∏(N−M−i)/(N−i).
    p = BigFloat(1)
    for i in 0:(j0 - 1)
        p = p * BigFloat(M - i)
    end
    for i in 0:(k - j0 - 1)
        p = p * BigFloat(N - M - i)
    end
    for i in 1:j0
        p = p * (BigFloat(k - j0 + i) / BigFloat(i))
    end
    for i in 0:(k - 1)
        p = p / BigFloat(N - i)
    end
    total = BigFloat(0)
    for j in j0:jmax
        j > B && (total = total + p)
        if j < jmax
            p = p * (BigFloat(M - j) / BigFloat(j + 1)) *
                (BigFloat(k - j) / BigFloat(N - M - k + j + 1))
        end
    end
    return total
end

"""
Encierre `[lo, hi]` de `P(X > B)` con redondeo dirigido a `bits` de precisión.
Válido para `N` grande y `k` moderado. Complejidad `O(k)` operaciones `BigFloat`.
`[demostrado]` (cada operación es monótona en los factores positivos).
"""
function cola_hiper_intervalo(N::Integer, M::Integer, k::Integer, B::Integer; bits::Int = 256)
    (N >= 1) || throw(ArgumentError("N >= 1"))
    (0 <= M <= N) || throw(ArgumentError("M=$M fuera de [0,$N]"))
    (0 <= k <= N) || throw(ArgumentError("k=$k fuera de [0,$N]"))
    return setprecision(BigFloat, bits) do
        lo = setrounding(BigFloat, RoundDown) do
            _cola_hiper_redondeada(N, M, k, B)
        end
        hi = setrounding(BigFloat, RoundUp) do
            _cola_hiper_redondeada(N, M, k, B)
        end
        (lo, hi)
    end
end

# ── 4 · Cota de acoplamiento hipergeométrica ↔ binomial ──────────────────────
"""
Cota superior RIGUROSA de la distancia de variación total entre el muestreo SIN
reemplazo (`Hipergeométrica(N,M,k)`) y CON reemplazo (`Binomial(k, M/N)`):

    d_TV ≤ 1 − ∏_{i=1}^{k−1}(1 − i/N) ≤ k(k−1)/(2N)

Demostración: acoplar la secuencia con reemplazo con la muestra sin reemplazo
acondicionada a que las `k` extracciones sean distintas. Condicionado a que no haya
repetidos, ambas leyes coinciden; la probabilidad de repetición es
`1 − ∏(1−i/N) ≤ k(k−1)/(2N)` (unión de los pares). `[demostrado]`.

Para `N = 10⁶` y `k = 10³` vale `≈ 0,5`: es una cota de acoplamiento, no una cota
útil en ese régimen; se declara como tal y se comprueba numéricamente contra la
distancia exacta en el dominio pequeño.
"""
cota_tv_hiper_binomial(N::Integer, k::Integer) =
    (N <= 0 || k <= 1) ? 0.0 : Float64(k) * (Float64(k) - 1) / (2 * Float64(N))

"""Distancia de variación total EXACTA entre hipergeométrica y binomial (dominio pequeño)."""
function tv_hiper_binomial_exacta(N::Integer, M::Integer, k::Integer)::Rational{BigInt}
    den = binomial(BigInt(N), k)
    p = Rational{BigInt}(M, N)
    acc = zero(Rational{BigInt})
    for j in 0:min(k, M)
        ph = binomial(BigInt(M), j) * binomial(BigInt(N - M), k - j) // den
        pb = binomial(BigInt(k), j) * p^j * (1 - p)^(k - j)
        acc += abs(ph - pb)
    end
    return acc // 2
end

# ── 5 · Intervalo de Clopper–Pearson exacto (para el Monte Carlo) ────────────
"""`P(X ≤ j)`, `X ~ Binomial(n,p)`, con coeficientes binomiales precalculados."""
function cdf_binomial_big(j::Integer, coefs::Vector{BigFloat}, n::Integer, p::BigFloat)
    (j < 0) && return BigFloat(0)
    (j >= n) && return BigFloat(1)
    q = 1 - p
    s = BigFloat(0)
    for i in 0:j
        @inbounds s += coefs[i + 1] * p^i * q^(n - i)
    end
    return s
end

"""Resuelve `cdf_binomial(j, n, p) = objetivo` por bisección. La CDF es DECRECIENTE
en `p` (con `p` pequeño, `X` es pequeño y `P(X ≤ j)` grande), de ahí el sentido."""
function _biseccion_cdf(j::Integer, coefs::Vector{BigFloat}, n::Integer, objetivo::BigFloat)
    lo = BigFloat(0); hi = BigFloat(1)
    for _ in 1:120
        med = (lo + hi) / 2
        if cdf_binomial_big(j, coefs, n, med) > objetivo
            lo = med
        else
            hi = med
        end
    end
    return (lo + hi) / 2
end

"""
Intervalo de Clopper–Pearson EXACTO para `x/n` éxitos. Extremos por la forma
unilateral de la beta:

    lo  tal que  P(X ≥ x | lo, n) = α/2   ⟺   P(X ≤ x−1 | lo, n) = 1 − α/2
    hi  tal que  P(X ≤ x | hi, n) = α/2

`lo = 0` si `x = 0` y `hi = 1` si `x = n`. Nunca degenerado, nunca ±1σ.
Complejidad `O(iteraciones · n)`; los coeficientes binomiales se calculan UNA vez.
"""
function clopper_pearson(x::Integer, n::Integer; alfa::Real = 0.05)
    (0 <= x <= n) || throw(ArgumentError("x fuera de [0,n]"))
    (n >= 1) || throw(ArgumentError("n >= 1"))
    return setprecision(BigFloat, 256) do
        coefs = Vector{BigFloat}(undef, n + 1)
        for i in 0:n
            coefs[i + 1] = BigFloat(binomial(BigInt(n), i))
        end
        unomenos = 1 - BigFloat(alfa) / 2
        medio = BigFloat(alfa) / 2
        lo = (x == 0) ? BigFloat(0) : _biseccion_cdf(x - 1, coefs, n, unomenos)
        hi = (x == n) ? BigFloat(1) : _biseccion_cdf(x, coefs, n, medio)
        (Float64(lo), Float64(hi))
    end
end
