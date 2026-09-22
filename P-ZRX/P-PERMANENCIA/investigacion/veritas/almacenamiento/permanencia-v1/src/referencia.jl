# referencia.jl — oráculo exacto y cotas rigurosas para las colas de Poisson y binomial.
#
# El encargo exige referencia exacta (`Rational{BigInt}`) para lotes pequeños ANTES de
# cualquier aproximación normal. Aquí:
#
#   1. `poisson_cdf_intervalo` da un INTERVALO [lo, hi] que contiene la cola exacta, con
#      redondeo dirigido de MPFR (BigFloat) y suma exacta del término polinómico.
#   2. `suma_poisson_exacta` da ese término polinómico Σ λ^j/j! de forma EXACTA en
#      `Rational{BigInt}`; es el oráculo contra el que se valida el intervalo.
#   3. `binomial_cdf_exacta` da la cola binomial exacta en `Rational{BigInt}` para lotes
#      pequeños; es el oráculo de la hipótesis Poisson.
#   4. `umbral_rechazo` busca el umbral de rechazo con la cota SUPERIOR (conservadora para
#      el falso fallo); `potencia_inferior` usa la cota SUPERIOR de la cola (conservadora
#      para la potencia, es decir, NUNCA se atribuye al esquema más potencia de la que tiene).

# ---------------------------------------------------------------------------
# 1 · Término polinómico exacto
# ---------------------------------------------------------------------------

"""
`Σ_{j=0}^{k} λ^j / j!` exacto como `Rational{BigInt}`. `λ = λn/λd`.
Sin reducción por paso (se reduce una vez al final): para k de miles es rápido y mantiene
el oráculo independiente del kernel.
"""
function suma_poisson_exacta(λn::Integer, λd::Integer, k::Integer)
    λn == 0 && return Rational{BigInt}(1)
    k < 0 && return Rational{BigInt}(0)
    num = BigInt(0)
    den = BigInt(1)
    tnum = BigInt(1)
    tden = BigInt(1)
    for j in 0:k
        num = num * tden + tnum * den
        den = den * tden
        tnum *= λn
        tden *= λd * (j + 1)
    end
    g = gcd(num, den)
    return Rational{BigInt}(num ÷ g, den ÷ g)
end

# ---------------------------------------------------------------------------
# 2 · Cola de Poisson con intervalo riguroso
# ---------------------------------------------------------------------------

function _limites_lambda(λn::BigInt, λd::BigInt)
    lo = setrounding(BigFloat, RoundDown) do
        BigFloat(λn) / BigFloat(λd)
    end
    hi = setrounding(BigFloat, RoundUp) do
        BigFloat(λn) / BigFloat(λd)
    end
    return (lo, hi)
end

# Operaciones con redondeo dirigido en funciones propias: evita capturar variables mutables
# dentro de un `do`, que las convierte en `Core.Box` y hace que JET vea `Any`. LINEO §3.1.
_add_rd(a::BigFloat, b::BigFloat) = setrounding(BigFloat, RoundDown) do
    a + b
end
_add_ru(a::BigFloat, b::BigFloat) = setrounding(BigFloat, RoundUp) do
    a + b
end
_mul_rd(a::BigFloat, b::BigFloat) = setrounding(BigFloat, RoundDown) do
    a * b
end
_mul_ru(a::BigFloat, b::BigFloat) = setrounding(BigFloat, RoundUp) do
    a * b
end
_div_rd(a::BigFloat, b::BigFloat) = setrounding(BigFloat, RoundDown) do
    a / b
end
_div_ru(a::BigFloat, b::BigFloat) = setrounding(BigFloat, RoundUp) do
    a / b
end
_exp_neg_rd(a::BigFloat) = setrounding(BigFloat, RoundDown) do
    exp(-a)
end
_exp_neg_ru(a::BigFloat) = setrounding(BigFloat, RoundUp) do
    exp(-a)
end
_le(a::BigFloat, b::BigFloat) = a <= b

"""
Intervalo [lo, hi] que contiene `P(X ≤ k)` para `X ~ Poisson(λn/λd)`.
Rigor: redondeo dirigido en cada operación y `exp` de MPFR; `λlo ≤ λ ≤ λhi`; los términos
`λ^j/j!` se acotan por inducción hacia abajo y hacia arriba. `exp(-λ) ∈ [exp(-λhi), exp(-λlo)]`
porque `exp` es decreciente.
"""
function poisson_cdf_intervalo(λn::Integer, λd::Integer, k::Integer; prec::Int = 256)
    return setprecision(BigFloat, prec) do
        λn == 0 && return (BigFloat(k >= 0 ? 1 : 0), BigFloat(k >= 0 ? 1 : 0))
        k < 0 && return (zero(BigFloat), zero(BigFloat))
        λlo, λhi = _limites_lambda(BigInt(λn), BigInt(λd))
        elo = _exp_neg_rd(λhi)
        ehi = _exp_neg_ru(λlo)
        slo = one(BigFloat)
        shi = one(BigFloat)
        tlo = one(BigFloat)
        thi = one(BigFloat)
        for j in 1:k
            d = BigFloat(j)
            tlo = _div_rd(_mul_rd(tlo, λlo), d)
            thi = _div_ru(_mul_ru(thi, λhi), d)
            slo = _add_rd(slo, tlo)
            shi = _add_ru(shi, thi)
        end
        lo = _mul_rd(slo, elo)
        hi = _mul_ru(shi, ehi)
        return (lo, hi)
    end
end

"""Cota superior de `P(X ≤ k)`; conservadora para el falso fallo (el test rechaza si `X ≤ K`)."""
cdf_superior(λn::Integer, λd::Integer, k::Integer; prec::Int = 256) =
    poisson_cdf_intervalo(λn, λd, k; prec = prec)[2]

"""Cota inferior de `P(X ≤ k)`; conservadora para la POTENCIA de detectar una media menor."""
cdf_inferior(λn::Integer, λd::Integer, k::Integer; prec::Int = 256) =
    poisson_cdf_intervalo(λn, λd, k; prec = prec)[1]

# ---------------------------------------------------------------------------
# 3 · Cola binomial exacta (oráculo de lotes pequeños)
# ---------------------------------------------------------------------------

"""
`P(X ≤ k)` para `X ~ Binomial(n, a/b)` EXACTA en `Rational{BigInt}`.
Se usa solo como oráculo en lotes pequeños (n ≤ unos miles) y para validar la Poisson.
"""
function binomial_cdf_exacta(n::Integer, a::Integer, b::Integer, k::Integer)
    (a < 0 || a > b || b <= 0) && throw(ArgumentError("probabilidad a/b fuera de [0,1]"))
    k < 0 && return Rational{BigInt}(0)
    k >= n && return Rational{BigInt}(1)
    a == 0 && return Rational{BigInt}(1)      # nunca hay éxito
    a == b && return Rational{BigInt}(0)      # siempre hay éxito (y k < n)
    acc = Rational{BigInt}(0)
    # término j: C(n,j) a^j (b-a)^(n-j) / b^n, por recurrencia exacta (siempre BigInt)
    num = BigInt(b - a)^n
    den = BigInt(b)^n
    for j in 0:k
        acc += Rational{BigInt}(num, den)
        # pasar de j a j+1
        num = num * (n - j) * a
        den = den * (j + 1) * (b - a)
    end
    return acc
end

"""`P(X > k)` binomial exacta."""
binomial_supervivencia_exacta(n::Integer, a::Integer, b::Integer, k::Integer) =
    1 - binomial_cdf_exacta(n, a, b, k)

# ---------------------------------------------------------------------------
# 4 · Umbral de rechazo y potencia (cotas conservadoras)
# ---------------------------------------------------------------------------

"""
Mayor `K` con `P(Poisson(λ) ≤ K) ≤ β` usando la cota SUPERIOR de la cola.
Devuelve `-1` si ni `K = 0` cumple: entonces el test no puede rechazar sin superar `β`
(es el caso de `λ` demasiado pequeño y se declara, no se aproxima).
`λ = λn/λd`. `kmax` acota la búsqueda; si se alcanza, se devuelve `(K, false)`.
"""
function umbral_rechazo(λn::Integer, λd::Integer, beta::Real; prec::Int = 256, kmax::Int = 1_000_000)
    β = BigFloat(beta)
    return setprecision(BigFloat, prec) do
        λn == 0 && return (β >= 1 ? 0 : -1, true)
        λlo, λhi = _limites_lambda(BigInt(λn), BigInt(λd))
        elo = _exp_neg_rd(λhi)
        ehi = _exp_neg_ru(λlo)
        slo = one(BigFloat)
        shi = one(BigFloat)
        tlo = one(BigFloat)
        thi = one(BigFloat)
        c0 = _mul_ru(shi, ehi)
        _le(c0, β) || return (-1, true)
        K = 0
        for j in 1:kmax
            d = BigFloat(j)
            tlo = _div_rd(_mul_rd(tlo, λlo), d)
            thi = _div_ru(_mul_ru(thi, λhi), d)
            slo = _add_rd(slo, tlo)
            shi = _add_ru(shi, thi)
            hi = _mul_ru(shi, ehi)
            if _le(hi, β)
                K = j
            else
                return (K, true)
            end
        end
        return (K, false)
    end
end

"""
Potencia MÍNIMA garantizada contra una alternativa de media `λc` con el umbral `K`.
El test **rechaza si `X ≤ K`** (menos parciales de las esperadas), así que la potencia es
`P(X_alternativa ≤ K)` y se usa la cota INFERIOR de la cola: nunca sobreestima la potencia.
"""
function potencia_garantizada(λn::Integer, λd::Integer, K::Integer; prec::Int = 256)
    return setprecision(BigFloat, prec) do
        lo, _ = poisson_cdf_intervalo(λn, λd, K; prec = prec)
        return lo
    end
end

"""Falso fallo MÁXIMO de un honesto con media `λa` y umbral `K` (cota superior)."""
function falso_fallo_maximo(λn::Integer, λd::Integer, K::Integer; prec::Int = 256)
    hi = cdf_superior(λn, λd, K; prec = prec)
    return min(one(hi), hi)
end

# ---------------------------------------------------------------------------
# 5 · Periodos hasta detectar (búsqueda exacta sobre T)
# ---------------------------------------------------------------------------

"""
Mínimo `T` (periodos) tal que, rechazando cuando el acumulado es `≤ K_T` con
`K_T = umbral(λ·T, β)`, la potencia garantizada contra `Poisson(s·λ·T)` es `≥ 1-γ`.
`λ = λn/λd` por periodo. Devuelve `(T, K_T, potencia_garantizada)`; `T = 0` significa que
ni con un periodo se cumple, `T = Tmax+1` que no se alcanza dentro del presupuesto.
"""
function _potencia_y_umbral(λn::Integer, λd::Integer, T::Integer, s_num::Integer, s_den::Integer,
        beta::Real; prec::Int)
    Kn = BigInt(λn) * T
    Kd = BigInt(λd)
    # cota holgada del umbral: media + 50 desviaciones + 100
    med = Float64(Kn) / Float64(Kd)
    med > 2e6 && return (-1, BigFloat(0), false)   # fuera del presupuesto de la búsqueda
    kmax = Int(ceil(med + 50 * sqrt(med) + 100)) + 10
    K, ok = umbral_rechazo(Kn, Kd, beta; prec = prec, kmax = kmax)
    (K < 0 || !ok) && return (K, BigFloat(0), ok)
    pot = potencia_garantizada(Kn * s_num, Kd * s_den, K; prec = prec)
    return (K, pot, true)
end

"""
Mínimo `T` (periodos) tal que, rechazando cuando el acumulado es `≤ K_T` con
`K_T = umbral(λ·T, β)`, la potencia garantizada contra `Poisson(s·λ·T)` es `≥ 1-γ`.
`λ = λn/λd` por periodo. Búsqueda por duplicación y después bisección: la potencia
garantizada es no decreciente en `T` (se comprueba como invariante en `validacion.jl`).
Devuelve `(T, K_T, potencia_garantizada)`; `T = Tmax+1` significa que no se alcanza.
"""
function periodos_deteccion(
    λn::Integer,
    λd::Integer,
    s_num::Integer,
    s_den::Integer,
    beta::Real,
    gamma::Real;
    prec::Int = 256,
    Tmax::Int = 200_000,
)
    objetivo = 1 - BigFloat(gamma)
    s_num >= s_den && return (Tmax + 1, -1, BigFloat(0))   # s ≥ 1: no hay nada que detectar
    alto = 0
    T = 1
    while T <= Tmax
        _, pot, ok = _potencia_y_umbral(λn, λd, T, s_num, s_den, beta; prec = prec)
        if ok && pot >= objetivo
            alto = T
            break
        end
        T *= 2
    end
    alto == 0 && return (Tmax + 1, -1, BigFloat(0))
    bajo = max(1, alto ÷ 2)
    mejor = alto
    while bajo < alto
        medio = (bajo + alto) ÷ 2
        _, pot, ok = _potencia_y_umbral(λn, λd, medio, s_num, s_den, beta; prec = prec)
        if ok && pot >= objetivo
            alto = medio
            mejor = medio
        else
            bajo = medio + 1
        end
    end
    K, pot, _ = _potencia_y_umbral(λn, λd, mejor, s_num, s_den, beta; prec = prec)
    return (mejor, K, pot)
end

"""Aproximación cerrada de muestras para λ grande (solo para arrancar la búsqueda)."""
function periodos_deteccion_aprox(λ::Real, s::Real, beta::Real, gamma::Real)
    zβ = 3.0902323061678132   # Φ⁻¹(1-β) a β=1e-3; solo orientativa, no se publica
    zγ = 2.3263478740408408   # Φ⁻¹(1-γ) a γ=1e-2
    return ((zβ + zγ * sqrt(s)) / ((1 - s) * sqrt(λ)))^2
end
