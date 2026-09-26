#= SL-2 · referencia.jl
   ORÁCULOS exactos y lentos, vías INDEPENDIENTES del kernel `rapido.jl`:
     · primera pasada por enumeración exhaustiva en `Rational{BigInt}` (T ≤ 20);
     · primera pasada por DP absorbente en `Rational{BigInt}`;
     · intervalo de Wilson;
     · masas de la Pareto truncada por integración exacta de la CDF.
   Reutiliza la convención de DS-3: `q_adv` es la tasa del ADVERSARIO por paso, el honesto `1−q_adv`.
=#

"Primera pasada por enumeración recursiva de las `2^T` trayectorias. `q_adv` = tasa del adversario."
function enumerar_exhaustivo(q_adv::Rational{BigInt}, d::Integer, T::Integer)
    T <= 20 || throw(ArgumentError("enumeración exhaustiva sólo para T ≤ 20"))
    p_hon = 1 - q_adv
    term = zero(Rational{BigInt})
    paso = zero(Rational{BigInt})
    function rec!(z::Int, t::Int, pr::Rational{BigInt}, tocado::Bool)
        if z == -1 && !tocado
            paso += pr
            t == T && (term += pr)
            tocado = true
        end
        t == T && return
        rec!(z - 1, t + 1, pr * q_adv, tocado)
        rec!(z + 1, t + 1, pr * p_hon, tocado)
        return
    end
    rec!(d, 0, one(Rational{BigInt}), false)
    return (terminal = term, paso = paso)
end

"""
    primera_absorbente_exacta(q_adv, d, T)

DP absorbente en `Rational{BigInt}` sobre la POSICIÓN, con `−1` absorbente. O(T·(d+T)), exacta.
Vía independiente del DP `(mínimo, posición)` de `rapido.jl`.
"""
function primera_absorbente_exacta(q_adv::Rational{BigInt}, d::Integer, T::Integer)
    d >= 0 || throw(ArgumentError("d ≥ 0"))
    p_hon = 1 - q_adv
    zmax = d + T + 2
    u = zeros(Rational{BigInt}, zmax + 2)
    u[d + 1] = one(Rational{BigInt})
    a = zero(Rational{BigInt})
    un = similar(u)
    for _ in 1:T
        fill!(un, zero(Rational{BigInt}))
        for z in 0:zmax
            v = u[z + 1]
            iszero(v) && continue
            if z - 1 == -1
                a += v * q_adv
            else
                un[z - 1 + 1] += v * q_adv
            end
            un[z + 1 + 1] += v * p_hon
        end
        u, un = un, u
    end
    return a
end

"Forma cerrada exacta del horizonte largo: `(q/p)^(d+1)` si `q < p`, si no `1`."
function eventual_exacto(q_adv::Rational{BigInt}, d::Integer)
    p_hon = 1 - q_adv
    q_adv < p_hon || return one(Rational{BigInt})
    return (q_adv / p_hon)^(d + 1)
end

"Intervalo de Wilson al 95 % para `k` éxitos de `n` (P-PRESTAMO `referencia.jl`, DS-3)."
function wilson(k::Integer, n::Integer)
    n == 0 && return (0.0, 1.0)
    z = 1.959963984540054
    ph = k / n
    den = 1 + z^2 / n
    centro = (ph + z^2 / (2n)) / den
    medio = z * sqrt(ph * (1 - ph) / n + z^2 / (4n^2)) / den
    return (max(0.0, centro - medio), min(1.0, centro + medio))
end

"""
    B_par_exacta(f_min, alpha, x; F_max = Inf, N = 400_000)

Fracción de espacio `∫_{fmin}^{min(x,Fmax)} f p(f) df / ∫_{fmin}^{Fmax} f p(f) df` para
`p(f) ∝ f^{−alpha}`, por **cuadratura numérica** en `t = ln f` (vía independiente de `masa_prob`).
Con `F_max = Inf` exige `alpha > 2` (igual que la rama no truncada de DS-3).
"""
function B_par_exacta(f_min::Float64, alpha::Float64, x::Float64;
                      F_max::Float64 = Inf, N::Integer = 400_000)
    x <= f_min && return 0.0
    isinf(F_max) && alpha <= 2 && throw(ArgumentError("Pareto no truncada con α ≤ 2"))
    tmin = log(f_min)
    # ∫_{a}^{b} exp((2-alpha) t) dt por trapecio; la cola es despreciable a 200 unidades de log
    function integral(a::Float64, b::Float64)
        b <= a && return 0.0
        n = max(2, round(Int, N * (b - a) / max(b - a, 1.0)))
        h = (b - a) / n
        s = 0.0
        for i in 0:n
            t = a + i * h
            w = (i == 0 || i == n) ? 0.5 : 1.0
            s += w * exp((2 - alpha) * t)
        end
        return s * h
    end
    tmax = isinf(F_max) ? tmin + 200.0 : log(F_max)
    den = integral(tmin, tmax)
    den <= 0 && return 1.0
    xc = isinf(F_max) ? x : min(x, F_max)
    num = integral(tmin, log(xc))
    return num / den
end
