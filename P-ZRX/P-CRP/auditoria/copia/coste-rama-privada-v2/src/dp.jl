# dp.jl — DP de la carrera corta con contabilidad de masa explícita (encargo D2).
#
# Reglas de la corrección obligatoria, todas implementadas aquí:
#  - una única unidad: el estado es `z = g·D`, entero en la retícula; `d` entra en
#    unidades de trabajo y se convierte una sola vez (`z0 = g*d`);
#  - el déficit no se trunca a un corte fijo llamado "desviaciones": el soporte es
#    adaptativo y la cola omitida se publica como fuga, nunca se renormaliza;
#  - se separa masa del kernel (interior), masa absorbida por éxito y fuga por frontera;
#  - se propaga una cota acumulada: [p_exito, p_exito + fuga_total] acota la probabilidad
#    verdadera en todo el horizonte; la cola por paso no acredita el error final;
#  - `error total ≤ 10⁻¹²` solo se exige cuando la probabilidad está por encima de la
#    cota numérica; si está por debajo, se publica únicamente una cota.

struct ResultadoDP{T<:Real}
    p_exito_lower::T      # masa absorbida por éxito dentro del soporte (cota inferior)
    p_exito_upper::T      # p_exito_lower + fuga acumulada (cota superior válida)
    masa_kernel::T        # masa interior al final del horizonte
    masa_exito::T         # == p_exito_lower
    masa_fuga::T          # masa que salió del soporte y no se contó como éxito
    conservacion::T       # masa_kernel + masa_exito + masa_fuga − 1 (diagnóstico)
    horizonte::Int
    lo::Int
    hi::Int
    retícula::String       # descripción de la unidad del estado
end

"""
DP de un evento por paso sobre enteros. En cada paso, con prob `p` el estado salta `dh`
(honesto) y con prob `q` salta `da` (adversario). `exito(z)` decide la absorción.
El estado `z0` se evalúa en `n=0`; el soporte interior es `[lo,hi]`.
"""
function dp_acotada(::Type{Tnum}, z0::Integer, dh::Integer, da::Integer,
                    p::Real, q::Real, Thorizonte::Integer, lo::Integer, hi::Integer;
                    exito::Function) where {Tnum<:Real}
    lo <= z0 <= hi || throw(ArgumentError("z0=$z0 fuera de [$lo,$hi]"))
    ancho = Int(hi - lo + 1)
    interior = Vector{Tnum}(undef, ancho)
    fill!(interior, zero(Tnum))
    exito0 = exito(z0)
    p_ex = zero(Tnum)
    fuga = zero(Tnum)
    if exito0
        p_ex += one(Tnum)
    else
        interior[Int(z0 - lo + 1)] = one(Tnum)
    end
    interior_nuevo = Vector{Tnum}(undef, ancho)
    for _ in 1:Thorizonte
        fill!(interior_nuevo, zero(Tnum))
        for idx in 1:ancho
            m = interior[idx]
            m == 0 && continue
            z = lo + idx - 1
            for (dz, pr) in ((dh, Tnum(p)), (da, Tnum(q)))
                zn = z + dz
                if exito(zn)
                    p_ex += m * pr
                elseif zn < lo || zn > hi
                    fuga += m * pr
                else
                    interior_nuevo[Int(zn - lo + 1)] += m * pr
                end
            end
        end
        copyto!(interior, interior_nuevo)
    end
    masa_kernel = sum(interior)
    conserv = masa_kernel + p_ex + fuga - one(Tnum)
    return ResultadoDP{Tnum}(p_ex, p_ex + fuga, masa_kernel, p_ex, fuga, conserv,
                             Int(Thorizonte), Int(lo), Int(hi),
                             "z = g·D, paso honesto +$(dh), adversario $(da)")
end

"""
Soporte adaptativo: duplica la semianchura hasta que la fuga quede por debajo de `tol`
o se alcance `max_ancho`. Nunca renormaliza; devuelve la última corrida con su fuga.
`direccion` ∈ {:arriba,:abajo,:ambas} indica por dónde expandir.
"""
function dp_adaptativa(::Type{Tnum}, z0::Integer, dh::Integer, da::Integer,
                       p::Real, q::Real, Thorizonte::Integer;
                       exito::Function, tol::Real=1e-14, max_ancho::Integer=2_000_001,
                       direccion::Symbol=:ambas,
                       lo_inicial::Union{Nothing,Integer}=nothing) where {Tnum<:Real}
    ancho = 64
    lo = lo_inicial === nothing ? Int(z0) - ancho : Int(lo_inicial)
    hi = Int(z0) + ancho
    lo <= z0 <= hi || throw(ArgumentError("lo_inicial=$lo deja fuera z0=$z0"))
    dir_lo = direccion == :arriba ? 0 : (direccion == :abajo ? 1 : 1)
    dir_hi = direccion == :abajo ? 0 : (direccion == :arriba ? 1 : 1)
    local r
    while true
        r = dp_acotada(Tnum, z0, dh, da, p, q, Thorizonte, lo, hi; exito=exito)
        if r.masa_fuga <= Tnum(tol)
            return r
        end
        proximo = (Int(hi - lo + 1)) * 2
        if proximo > max_ancho
            return r
        end
        extra = (proximo - (hi - lo + 1)) ÷ 2
        dir_lo == 1 && (lo -= extra)
        dir_hi == 1 && (hi += extra)
        lo = min(lo, Int(z0) - 1)
        hi = max(hi, Int(z0) + 1)
    end
end

"P(superar estrictamente) con soporte adaptativo, pasos ±1 en la retícula."
function prob_superar_dp(::Type{Tnum}, z0::Integer, p::Real, q::Real, Thorizonte::Integer;
                         tol::Real=1e-14, max_ancho::Integer=2_000_001) where {Tnum<:Real}
    # la frontera de superación es z ≤ −1: el soporte inferior se fija en −1 para
    # que la absorción sea alcanzable incluso con z0 grande (corrige revisión F3).
    return dp_adaptativa(Tnum, z0, 1, -1, p, q, Thorizonte; exito=z -> z <= -1,
                         tol=tol, max_ancho=max_ancho, direccion=:arriba,
                         lo_inicial=-1)
end

"P(empatar) con soporte adaptativo, pasos ±1 en la retícula."
function prob_empate_dp(::Type{Tnum}, z0::Integer, p::Real, q::Real, Thorizonte::Integer;
                        tol::Real=1e-14, max_ancho::Integer=2_000_001) where {Tnum<:Real}
    return dp_adaptativa(Tnum, z0, 1, -1, p, q, Thorizonte; exito=z -> z == 0,
                         tol=tol, max_ancho=max_ancho, direccion=:ambas)
end

"""
Inversión monótona `α_prob = inf{α : f(α) ≥ p0}`. Comprueba monotonicidad en una
rejilla; si no es monótona (o hay varias raíces), devuelve `nothing` y lo declara
indefinido, sin elegir una raíz (encargo §1).
Devuelve `(α_inf, α_sup, intervalo)` con un intervalo que acota el cruce.
"""
function invertir_monotona(f::Function, p0::Real; lo::Real=0.0, hi::Real=0.5, pasos::Int=200,
                           tol::Real=1e-7)
    xs = range(lo, hi; length=pasos)
    ys = [f(x) for x in xs]
    diffs = diff(ys)
    if any(d -> d < -1e-12, diffs)
        return nothing
    end
    if ys[1] >= p0
        return (lo, lo, (lo, lo))
    end
    if ys[end] < p0
        return (hi, hi, (hi, hi))
    end
    a, b = lo, hi
    for _ in 1:80
        m = (a + b) / 2
        if f(m) >= p0
            b = m
        else
            a = m
        end
        (b - a) <= tol && break
    end
    return (a, b, (a, b))
end
