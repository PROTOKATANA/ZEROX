# referencia.jl — oráculos exactos y claros para el paseo de trabajo.
#
# Proceso: D_n = d + W_pub(n) − W_priv(n), D_0 = d ≥ 0. Cada evento es un bloque
# (honesto `+1` con prob `p=1−α`; adversario `−1` con prob `q=α`) en el baseline
# simétrico. "Empatar" = visitar D=0; "superar estrictamente" = visitar D<0.
#
# Referencias exactas (encargo D3), para q<p:
#   P(empate eventual)   = (q/p)^d
#   P(superar eventual)  = (q/p)^(d+1)
# Para q≥p ambas probabilidades eventuales son 1.

"""
Probabilidad eventual de alcanzar el empate `D=0` partiendo de `d`.
`p` = prob. de paso +1 (honesto), `q` = prob. de paso −1 (adversario).
Exacta como `Rational{BigInt}`.
"""
function prob_empate_eventual(d::Integer, p::Rational, q::Rational)
    d >= 0 || throw(ArgumentError("d debe ser ≥ 0"))
    (p > 0 && q > 0) || throw(ArgumentError("p,q deben ser > 0"))
    abs(p + q - 1) == 0 || throw(ArgumentError("p+q debe ser 1"))
    d == 0 && return 1//1
    q >= p && return 1//1
    return (q // p)^d
end

"""
Probabilidad eventual de superar estrictamente (`D<0`) partiendo de `d`.
"""
function prob_superar_eventual(d::Integer, p::Rational, q::Rational)
    d >= 0 || throw(ArgumentError("d debe ser ≥ 0"))
    abs(p + q - 1) == 0 || throw(ArgumentError("p+q debe ser 1"))
    q >= p && return 1//1
    return (q // p)^(d + 1)
end

"""
DP exacta sobre enteros para una distribución de saltos finitos.
`saltos` es un vector de `(Δ::Integer, prob::Rational{BigInt})`.
`exito(z)` decide la absorción por éxito. Devuelve `(p_exito, dist_final)`.
El estado inicial cuenta en `n=0` según `exito`.
"""
function dp_exacta_racional(z0::Integer, saltos::Vector{Tuple{Integer,Rational{BigInt}}},
                            T::Integer; exito::Function)
    p_ex = 0//1
    dist = Dict{Int,Rational{BigInt}}()
    if exito(z0)
        p_ex += 1//1
    else
        dist[Int(z0)] = 1//1
    end
    for _ in 1:T
        nd = Dict{Int,Rational{BigInt}}()
        for (z, m) in dist
            for (dz, pr) in saltos
                zn = z + Int(dz)
                if exito(zn)
                    p_ex += m * pr
                else
                    nd[zn] = get(nd, zn, 0//1) + m * pr
                end
            end
        end
        dist = nd
    end
    return p_ex, dist
end

"Saltos ±1 del baseline con `p=1−α`, `q=α`."
function saltos_baseline(p::Rational, q::Rational)
    pb = BigInt(numerator(p)) // BigInt(denominator(p))
    qb = BigInt(numerator(q)) // BigInt(denominator(q))
    return Tuple{Integer,Rational{BigInt}}[(1, pb), (-1, qb)]
end

"P(empatar alguna vez hasta T) exacta para pasos ±1."
function prob_empate_finita(d::Integer, p::Rational, q::Rational, T::Integer)
    p_ex, _ = dp_exacta_racional(d, saltos_baseline(p, q), T; exito=z -> z == 0)
    return p_ex
end

"P(superar estrictamente alguna vez hasta T) exacta para pasos ±1."
function prob_superar_finita(d::Integer, p::Rational, q::Rational, T::Integer)
    p_ex, _ = dp_exacta_racional(d, saltos_baseline(p, q), T; exito=z -> z <= -1)
    return p_ex
end

"P(superar estrictamente antes de un deadline T) — mismo objeto que `prob_superar_finita`."
prob_superar_antes(d, p::Rational, q::Rational, deadline::Integer) =
    prob_superar_finita(d, p, q, deadline)

"""
Regresión textual/numérica del encargo D3: `1/(1+ε^(−1/d))` converge a `1/2`
**desde abajo**, nunca a `1/2⁺`. Devuelve `(valor, valor−1/2)` en `BigFloat`.
"""
function corrimiento_alpha_prob(d::Integer, epsilon)
    d > 0 || throw(ArgumentError("d>0"))
    e = BigFloat(epsilon)
    0 < e < 1 || throw(ArgumentError("0<ε<1"))
    val = 1 / (1 + e^(-BigFloat(1) / d))
    return val, val - BigFloat(1) / 2
end
