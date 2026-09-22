# eventos.jl — separa los tres objetos (encargo v0.3, punto 1):
#   P_terminal(T)      : masa en D(T)<0 al cierre EXACTO del horizonte
#   P_first_passage(T) : probabilidad de visitar D<0 alguna vez hasta T
#   P_eventual         : límite T→∞
#
# `α_prob` se recalcula por evento y con cobertura SIMULTÁNEA. Una celda 0/n no es
# una frontera: se publica como cota unilateral.

struct ResultadoEventos{T<:Real}
    p_terminal::T
    p_terminal_cota::Tuple{T,T}
    p_paso::T
    p_paso_cota::Tuple{T,T}
    p_eventual::T
    masa_fuga_terminal::T
    conservacion_terminal::T
    horizonte::Int
    z0::Int
end

"P_eventual exacta para el paseo ±1 con `q<p`; `1` si `q≥p`."
function prob_eventual_pm1(z0::Integer, p::Real, q::Real)
    z0 >= 0 || throw(ArgumentError("z0≥0"))
    q >= p && return 1.0
    return Float64((q / p)^(z0 + 1))
end

"""
Calcula los tres objetos para pasos ±1 con déficit `z0` en la retícula.
`p` = honesto (+1), `q` = adversario (−1).
"""
function resultado_eventos(::Type{T}, z0::Integer, p::Real, q::Real, Thorizonte::Integer;
                           tol::Real=1e-14) where {T<:Real}
    # primera pasada: absorción en z≤−1
    r_fp = dp_adaptativa(T, z0, 1, -1, p, q, Thorizonte; exito=z -> z <= -1,
                         tol=tol, direccion=:arriba, lo_inicial=-1)
    # terminal: sin absorción, masa en z≤−1 al final
    pterm, fuga, _vec, _lo, _hi = dp_terminal(T, z0, p, q, Thorizonte; tol=tol)
    pev = prob_eventual_pm1(z0, p, q)
    return ResultadoEventos{T}(pterm, (pterm, pterm + fuga),
                               r_fp.p_exito_lower, (r_fp.p_exito_lower, r_fp.p_exito_upper),
                               T(pev), T(fuga), T(_vec === nothing ? zero(T) :
                               sum(_vec) + fuga - one(T)),
                               Int(Thorizonte), Int(z0))
end

"Intervalo de Clopper–Pearson para `k` éxitos en `n` con nivel `1−gamma`."
function cp_intervalo(k::Integer, n::Integer, gamma::Real)
    n <= 0 && return (0.0, 1.0)
    k <= 0 && return (0.0, 1 - (gamma / 2)^(1 / n))
    k >= n && return ((gamma / 2)^(1 / n), 1.0)
    lo = quantile(Beta(k, n - k + 1), gamma / 2)
    hi = quantile(Beta(k + 1, n - k), 1 - gamma / 2)
    return (lo, hi)
end

"""
`α_prob` con cobertura SIMULTÁNEA sobre `m` celdas (Bonferroni: `gamma/m` por celda).
Entrada: `alphas`, `exitos`, `n`. Devuelve un `NamedTuple`:
- `tipo = :cruce`: intervalo `(a,b)` con la frontera entre celdas confiadamente a
  ambos lados;
- `tipo = :solo_cota_superior`: ninguna celda supera `p0`; `a = Inf`, `b =` cota;
- `tipo = :indefinida`: celdas no monótonas o insuficientes.
Una celda `0/n` NUNCA se llama frontera.
"""
function alpha_prob_simultaneo(alphas::Vector{<:Real}, exitos::Vector{<:Integer},
                               n::Integer, p0::Real; gamma_total::Real=0.05)
    length(alphas) == length(exitos) || throw(ArgumentError("longitudes distintas"))
    m = length(alphas)
    m == 0 && return (tipo=:indefinida, a=NaN, b=NaN, celdas=0)
    a_low = -Inf    # mayor α confiadamente POR DEBAJO de p0
    b_high = Inf    # menor α confiadamente POR ENCIMA de p0
    for i in eachindex(alphas)
        lo, hi = cp_intervalo(exitos[i], n, gamma_total / m)
        hi < p0 && (a_low = max(a_low, alphas[i]))
        lo >= p0 && (b_high = min(b_high, alphas[i]))
    end
    if a_low == -Inf && b_high == Inf
        return (tipo=:indefinida, a=NaN, b=NaN, celdas=m)          # ninguna celda decide
    elseif b_high == Inf
        return (tipo=:solo_inferior, a=a_low, b=Inf, celdas=m)     # α_prob > a_low
    elseif a_low == -Inf
        return (tipo=:solo_superior, a=-Inf, b=b_high, celdas=m)   # α_prob < b_high
    else
        return (tipo=(a_low < b_high ? :cruce : :indefinida), a=a_low, b=b_high, celdas=m)
    end
end

"""
`α_prob` determinista (DP/exacto) por uno de los tres eventos. `evento ∈
{:terminal,:paso,:eventual}`. Comprueba monotonicidad y devuelve el intervalo.
"""
function alpha_prob_determinista(z0::Integer, p0::Real; evento::Symbol=:paso,
                                 Zg::Integer=1, Tol=1_000, lo::Real=0.0, hi::Real=0.5,
                                 pasos::Integer=120)
    f = a -> begin
        r = resultado_eventos(Float64, z0, 1 - a, a, Tol)
        evento == :terminal && return r.p_terminal
        evento == :paso && return r.p_paso
        return r.p_eventual
    end
    inv = invertir_monotona(f, p0; lo=lo, hi=hi, pasos=Int(pasos))
    return inv === nothing ? (:indefinida, NaN, NaN) : (:cruce, inv[1], inv[2])
end
