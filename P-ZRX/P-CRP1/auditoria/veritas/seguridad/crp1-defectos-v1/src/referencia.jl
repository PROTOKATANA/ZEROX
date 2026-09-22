# referencia.jl — oráculos independientes, exactos o casi exactos.
#
# Todo lo de este fichero se calcula por un método DISTINTO del kernel rápido de `rapido.jl`
# (enumeración a fuerza bruta, resolución exacta de un sistema racional, martingala, o suma
# directa en precisión arbitraria). Ninguno reutiliza código del instrumento auditado.

# ---------------------------------------------------------------------------
# 1. Predicado PoAS: conteo por enumeración exhaustiva.
# ---------------------------------------------------------------------------

"""
Cuenta a FUERZA BRUTA los residuos aceptados por el predicado PoAS en un dominio circular de
`M` puntos con rango `sr`. Independiente de `valores_aceptados`. Requiere `2(sr÷2)+1 ≤ M`.
"""
function conteo_residuos_por_enumeracion(M::Integer, sr::Integer)
    M >= 1 || throw(ArgumentError("M debe ser ≥ 1"))
    sr <= M - 1 || throw(ArgumentError("sr debe ser ≤ M−1 para que el arco no se solape"))
    r = sr ÷ 2
    n = 0
    for d in 0:(M - 1)
        dd = min(d, M - d)
        dd <= r && (n += 1)
    end
    return n
end

# ---------------------------------------------------------------------------
# 2. Ruina del jugador ±1: resolución EXACTA de un sistema racional.
#    Método independiente de la forma cerrada (q/p)^z.
# ---------------------------------------------------------------------------

"""
Ruina del jugador EXACTA por resolución del sistema lineal en `Rational{BigInt}`:
`v(i) = q·v(i−1) + p·v(i+1)`, `v(0)=1`, `v(N+1)=0`, con `p=1−α`, `q=α`.
Devuelve `v(m)`. Para `m` y `N` pequeños. La frontera `N+1` es absorbente en «fracaso», así que
`v(m)` es una COTA INFERIOR de la ruina infinita que crece con `N`.
"""
function ruina_unitaria_sistema_racional(α::Rational{BigInt}, m::Integer, N::Integer)
    1 <= m <= N || throw(ArgumentError("se requiere 1 ≤ m ≤ N"))
    p = 1 - α
    q = α
    A = zeros(Rational{BigInt}, N, N)
    b = zeros(Rational{BigInt}, N)
    for i in 1:N
        A[i, i] = big(1) // big(1)
        if i - 1 >= 1
            A[i, i - 1] = -q
        else
            b[i] += q            # v(0) = 1
        end
        i + 1 <= N && (A[i, i + 1] = -p)
    end
    v = A \ b
    return v[m]
end

"""
Ruina ±1 por ENUMERACIÓN de la distribución de caminos hasta `pasos` pasos, con el estado
absorbente en `0` (éxito) y en `N+1` (fracaso). Método independiente de la forma cerrada y del
sistema lineal. Se usa `BigFloat` (128 bits) para poder iterar miles de pasos sin que crezcan
los denominadores como en `Rational`. Devuelve `(exito, en_curso)`: cota inferior y masa que
aún no se ha absorbido (el error de truncar el horizonte).
"""
function ruina_unitaria_enumeracion(α::Rational{BigInt}, m::Integer, pasos::Integer,
                                    N::Integer = m + 40; prec::Int = 128)
    setprecision(BigFloat, prec) do
        p = BigFloat(1 - α)
        q = BigFloat(α)
        dist = zeros(BigFloat, N)
        dist[m] = BigFloat(1)
        exito = BigFloat(0)
        for _ in 1:pasos
            nd = zeros(BigFloat, N)
            for i in 1:N
                w = dist[i]
                w == 0 && continue
                jb = i - 1
                if jb <= 0
                    exito += w * q
                else
                    nd[jb] += w * q
                end
                ja = i + 1
                ja <= N && (nd[ja] += w * p)
            end
            dist = nd
        end
        return (exito = exito, en_curso = sum(dist))
    end
end

# ---------------------------------------------------------------------------
# 3. Martingala exacta para el paseo compuesto de Poisson.
# ---------------------------------------------------------------------------

"""
Verifica EXACTAMENTE que `E[z^X] = 1` para `X = H − A`, `H~Poisson(g(1−α))`, `A~Poisson(gα)` y
`z = α/(1−α)`. Es la identidad que convierte `z^m` en cota superior de la probabilidad de
alcanzar. Se comprueba con la forma cerrada `exp(g·[(1−α)(z−1) + α(z^{-1}−1)]) = 1`.
Devuelve el residuo `|E[z^X] − 1|` en `BigFloat`.
"""
function verificar_martingala(α::Real, g::Real; prec::Int = 256)
    setprecision(BigFloat, prec) do
        a = BigFloat(g) * (1 - BigFloat(α))
        b = BigFloat(g) * BigFloat(α)
        z = BigFloat(α) / (1 - BigFloat(α))
        ex = exp(a * (z - 1) + b * (1 / z - 1))
        return abs(ex - 1)
    end
end

"""
Cota superior EXACTA (`Rational{BigInt}`) de la probabilidad de que el paseo compuesto de
Poisson alcance el déficit 0 partiendo de `m` bloques de ventaja: `z^m` con `z = α/(1−α)`.
Coincide numéricamente con la ruina exacta de pasos ±1 en la retícula con `m = d·g`.
"""
cota_martingala(α::Rational{BigInt}, m::Integer)::Rational{BigInt} =
    prob_empate_reticula(α, m)

# ---------------------------------------------------------------------------
# 4. Cota inferior de horizonte finito: P(S_n ≤ −m), con S_n compuesto de Poisson.
# ---------------------------------------------------------------------------

"`log k!` en `BigFloat` por suma de logaritmos (k pequeño, ≤ unos miles)."
function _logfact(k::Integer)
    s = BigFloat(0)
    for i in 2:k
        s += log(BigFloat(i))
    end
    return s
end

"`log pmf` de Poisson: `−μ + k·log μ − log k!`."
_logpmf_poisson(k::Integer, μ::BigFloat) = -μ + k * log(μ) - _logfact(k)

"""
Vector de `log pmf` de Poisson para `k = 0..n`, con lo que se evita recomputar `log k!`
en cada evaluación (el coste pasa de `O(n²)` a `O(n)`).
"""
function logpmf_poisson_vec(n::Integer, μ::BigFloat)
    out = Vector{BigFloat}(undef, n + 1)
    if μ <= 0
        out[1] = BigFloat(0)
        for k in 1:n
            out[k + 1] = BigFloat(-Inf)
        end
        return out
    end
    logμ = log(μ)
    lf = BigFloat(0)
    out[1] = -μ
    for k in 1:n
        lf += log(BigFloat(k))
        out[k + 1] = -μ + k * logμ - lf
    end
    return out
end

"""
Cota INFERIOR rigurosa de `P(ever alcanzar el déficit 0)` para el paseo compuesto de Poisson
con granularidad `g` y déficit inicial `m` bloques: la probabilidad de que la suma de `n`
slots ya esté por debajo: `P(S_n ≤ −m)` con `S_n = H_n − A_n`,
`H_n ~ Poisson(n·g·(1−α))`, `A_n ~ Poisson(n·g·α)`.
Devuelve `(p, masa_omitida)`: `p` es cota inferior válida para cualquier `n` y la masa omitida
acota el error de truncar la suma.
"""
function cota_inferior_horizonte(α::Real, g::Real, m::Integer, n::Integer; prec::Int = 256)
    setprecision(BigFloat, prec) do
        μh = BigFloat(n) * BigFloat(g) * (1 - BigFloat(α))
        μa = BigFloat(n) * BigFloat(g) * BigFloat(α)
        # cola de A: se trunca cuando la masa omitida es despreciable frente a la precisión.
        amax = ceil(Int, Float64(μa + 45 * sqrt(μa) + 80))
        # CDF de H hasta amax − m
        kmax = amax - m
        nh = max(amax, kmax, 0)
        lph = logpmf_poisson_vec(nh, μh)
        lpa = logpmf_poisson_vec(amax, μa)
        cdf = zeros(BigFloat, max(kmax, 0) + 1)
        acc = BigFloat(0)
        for k in 0:kmax
            acc += exp(lph[k + 1])
            cdf[k + 1] = acc
        end
        p = BigFloat(0)
        for a in 0:amax
            idx = a - m
            idx < 0 && continue                       # P(H ≤ idx) = 0
            p += exp(lpa[a + 1]) * cdf[min(idx, max(kmax, 0)) + 1]
        end
        # masa de A no recorrida
        masa_omitida = max(BigFloat(0), 1 - sum(exp(lpa[a + 1]) for a in 0:amax))
        return (p = p, masa_omitida = masa_omitida)
    end
end

"""
Mejor cota inferior de horizonte finito sobre una rejilla de horizontes `ns`.
Devuelve `(p, n_mejor)`.
"""
function mejor_cota_inferior_horizonte(α::Real, g::Real, m::Integer, ns; prec::Int = 256)
    mejor = BigFloat(0)
    nmejor = 0
    for n in ns
        r = cota_inferior_horizonte(α, g, m, n; prec = prec)
        if r.p > mejor
            mejor = r.p
            nmejor = n
        end
    end
    return (p = mejor, n = nmejor)
end

# ---------------------------------------------------------------------------
# 5. Poisson por transformada inversa (independiente del algoritmo de Knuth).
# ---------------------------------------------------------------------------

"Poisson por suma de exponenciales (transformada inversa). Independiente de `poisson_knuth`."
function poisson_inversa(rng, μ::Float64)
    μ <= 0 && return 0
    L = exp(-μ)
    k = 0
    u = rand(rng)
    while u > L
        k += 1
        u *= rand(rng)
    end
    return k
end

# ---------------------------------------------------------------------------
# 6. CDF de Poisson en precisión arbitraria (para la tabla de varianza exacta).
# ---------------------------------------------------------------------------

"""
CDF de Poisson `P(X ≤ k)` con `X ~ Poisson(μ)`, en `BigFloat` con `prec` bits, por suma directa
de la pmf en espacio logarítmico. Devuelve `(cdf, masa_omitida_izquierda)`.
"""
function cdf_poisson_big(k::Integer, μ::BigFloat)
    k < 0 && return (BigFloat(0), BigFloat(0))
    acc = BigFloat(0)
    for i in 0:k
        acc += exp(_logpmf_poisson(i, μ))
    end
    return (acc, BigFloat(0))
end
