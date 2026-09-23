# =============================================================================
# referencia.jl — oráculos independientes (pequeños, transparentes, exactos)
# -----------------------------------------------------------------------------
# Nada de aquí se usa para publicar una cifra: se usa para **refutar** a
# `rapido.jl`/`modelo.jl`. Cada vía es independiente de la que valida:
#   · Φ de la Pareto: suma de Riemann por tramos (monotonía) contra la primitiva
#     cerrada de `modelo.jl`.
#   · Reclutamiento: fuerza bruta y DP exacta contra el avaricioso (que **no** es
#     óptimo cuando hay coste fijo por granja; el contraejemplo está en los tests).
#   · Dicotomía: barrido exhaustivo con `Rational{BigInt}`.
# =============================================================================

# -----------------------------------------------------------------------------
# R1 · Φ de la Pareto truncada por suma de Riemann (independiente de la primitiva)
# -----------------------------------------------------------------------------
"""
    Phi_pareto_riemann(d, x; K=200_000) -> (lo, hi, ancho)

Cota inferior y superior de `Φ(x)` por sumas de Riemann de la función monótona
`f ↦ f^{−a}` sobre una rejilla **geométrica** de `[x, fmax]`. Como el integrando es
decreciente, la suma por la izquierda sobreestima la integral y la de la derecha
la subestima: `lo ≤ Φ(x) ≤ hi` **sin aproximación de la primitiva**. Devuelve
también el ancho del intervalo, que es la tolerancia declarada del certificado.
"""
function Phi_pareto_riemann(d::ParetoTruncado{T}, x::T; K::Integer = 200_000) where {T<:Real}
    x ≤ d.fmin && return (one(T), one(T), zero(T))
    x ≥ d.fmax && return (zero(T), zero(T), zero(T))
    K ≥ 2 || throw(ArgumentError("K ≥ 2"))
    # Numerador: ∫_x^fmax f^{-a} df con rejilla geométrica; denominador: ∫_fmin^fmax.
    num_lo, num_hi = riemann_f_minus_a(x, d.fmax, d.a, K)
    den_lo, den_hi = riemann_f_minus_a(d.fmin, d.fmax, d.a, K)
    # Φ = num/den, decreciente en num y creciente en den ⇒ cotas cruzadas.
    lo = num_lo / den_hi
    hi = num_hi / den_lo
    return (lo, hi, hi - lo)
end

"""Sumas de Riemann inferior/superior de `∫_a^b f^{−α} df`, rejilla geométrica."""
function riemann_f_minus_a(a::T, b::T, α::T, K::Integer) where {T<:Real}
    lg = log(b / a) / K
    lo = zero(T)
    hi = zero(T)
    x_prev = a
    @inbounds for k in 1:K
        x_next = a * exp(lg * k)
        h = x_next - x_prev
        # decreciente: extremo derecho subestima, izquierdo sobreestima
        lo += h * x_next^(-α)
        hi += h * x_prev^(-α)
        x_prev = x_next
    end
    return (lo, hi)
end

"""
    certificar_cruce(lo, hi, umbral; sentido=:menor) -> Symbol

Regla de LINEO §5.3: si el intervalo `[lo,hi]` contiene el umbral, el resultado es
**inconcluso**; si cae entero de un lado, queda certificado. Nada se redondea a
favor de la hipótesis.
"""
function certificar_cruce(lo::T, hi::T, umbral::T; sentido::Symbol = :menor) where {T<:Real}
    if sentido === :menor
        hi ≤ umbral && return :certificado_menor
        lo > umbral && return :certificado_mayor
    elseif sentido === :mayor
        lo ≥ umbral && return :certificado_mayor
        hi < umbral && return :certificado_menor
    else
        throw(ArgumentError("sentido debe ser :menor o :mayor"))
    end
    return :inconcluso
end

# -----------------------------------------------------------------------------
# R2 · Reclutamiento de β_d: avaricioso, fuerza bruta y exacto
# -----------------------------------------------------------------------------
"""
    soborno_granja(f, τ, c_b, κq, Lp, λ, I, Pwin, Th; n_extra=1)

Soborno que el atacante debe pagar a una granja de tamaño `f` para que cofarmée,
una vez descontada la ganancia que la granja obtiene por sí sola. El granjero
elige la evasión más barata (`min(κq·Lp, n_extra·τ + c_b·f)`), así que el atacante
sólo compensa la diferencia:

    b(f) = max(0, min(κqLp, n_extra·τ + c_b·f) − f·λIPTh)
"""
function soborno_granja(f::T, τ::T, c_b::T, κq::T, Lp::T, λ::T, I::T, Pwin::T, Th::T;
                        n_extra::Integer = 1) where {T<:Real}
    G = ganancia_cofarmacion(f, λ, I, Pwin, Th)
    c_ev = min(κq * Lp, T(n_extra) * τ + c_b * f)
    return max(zero(T), c_ev - G)
end

"""
    CosteReclutamiento{T}

Resultado de juntar al menos `β` de espacio por una vía: coste total, espacio
conseguido y número de granjas usadas.
"""
struct CosteReclutamiento{T<:Real}
    factible::Bool
    coste::T
    espacio::T
    n::Int
end

"""Instancia factible con `coste`/`espacio`/`n`."""
CosteReclutamiento{T}(coste::T, espacio::T, n::Integer) where {T<:Real} =
    CosteReclutamiento{T}(true, coste, espacio, Int(n))
"""Instancia imposible (ningún subconjunto alcanza `β`); no usa `Inf` si `T` es racional."""
CosteReclutamiento{T}() where {T<:Real} = CosteReclutamiento{T}(false, zero(T), zero(T), 0)

"""Coste avaricioso: ordena por coste por unidad de espacio y acumula."""
function reclutamiento_avaricioso(f::AbstractVector{T}, sobornos::AbstractVector{T},
                                  β::T) where {T<:Real}
    length(f) == length(sobornos) || throw(ArgumentError("longitudes distintas"))
    orden = sortperm(sobornos ./ f)
    coste = zero(T)
    espacio = zero(T)
    n = 0
    @inbounds for i in orden
        espacio ≥ β && break
        coste += sobornos[i]
        espacio += f[i]
        n += 1
    end
    return CosteReclutamiento{T}(coste, espacio, n)
end

"""
    reclutamiento_bruto(f, sobornos, β) -> CosteReclutamiento

Fuerza bruta sobre los `2^n` subconjuntos. Sólo para `n ≤ 20`. Es la verdad de
referencia del problema de selección.
"""
function reclutamiento_bruto(f::AbstractVector{T}, sobornos::AbstractVector{T},
                             β::T) where {T<:Real}
    n = length(f)
    n ≤ 20 || throw(ArgumentError("fuerza bruta sólo para n ≤ 20"))
    mejor = nothing
    @inbounds for mask in 0:(2^n - 1)
        espacio = zero(T)
        coste = zero(T)
        k = 0
        for i in 1:n
            if (mask >> (i - 1)) & 1 == 1
                espacio += f[i]
                coste += sobornos[i]
                k += 1
            end
        end
        espacio ≥ β || continue
        if mejor === nothing || coste < mejor[1]
            mejor = (coste, espacio, k)
        end
    end
    mejor === nothing && return CosteReclutamiento{T}()
    return CosteReclutamiento{T}(mejor[1], mejor[2], mejor[3])
end

"""
    reclutamiento_dos_niveles(θ, f_grande, K, τ, c_b, κq, Lp, λ, I, Pwin, Th, β)
        -> CosteReclutamiento

Solución **exacta** del problema de selección para la familia de dos niveles
(una granja grande + `K` pequeñas idénticas): enumera si se toma la grande y
cuántas pequeñas. No es un avaricioso: es la enumeración completa del par
`(toma_grande, k_pequeñas)`, `O(2K)`.
"""
function reclutamiento_dos_niveles(θ::T, f_grande::T, K::Integer, τ::T, c_b::T, κq::T,
                                   Lp::T, λ::T, I::T, Pwin::T, Th::T, β::T) where {T<:Real}
    f_peq = (one(T) - θ) / T(K)
    b_grande = soborno_granja(f_grande, τ, c_b, κq, Lp, λ, I, Pwin, Th)
    b_peq = soborno_granja(f_peq, τ, c_b, κq, Lp, λ, I, Pwin, Th)
    mejor = nothing
    for k in 0:K
        for toma in (false, true)
            espacio = T(k) * f_peq + (toma ? f_grande : zero(T))
            espacio ≥ β || continue
            coste = T(k) * b_peq + (toma ? b_grande : zero(T))
            if mejor === nothing || coste < mejor[1]
                mejor = (coste, espacio, k + (toma ? 1 : 0))
            end
        end
    end
    mejor === nothing && return CosteReclutamiento{T}()
    return CosteReclutamiento{T}(mejor[1], mejor[2], mejor[3])
end

# -----------------------------------------------------------------------------
# R3 · Barrido exhaustivo de la dicotomía (exacto, Rational{BigInt})
# -----------------------------------------------------------------------------
"""
    auditar_dicotomia(horarios, fracciones, Ns) -> Vector{NamedTuple}

Para cada horario y cada par `(f, N)` comprueba, con aritmética exacta, las dos
propiedades y su equivalencia:

  · `parte_mas_caro  = N·φ(f/N) > φ(f)`
  · `regresiva       = φ(f)/f > φ(f·N)/ (f·N)`  (la pequeña paga más por byte)
  · `concava         = φ(f) > (φ(f−δ)+φ(f+δ))/2` en una rejilla fina

Devuelve una fila por `(horario, f, N)`. La equivalencia se afirma en los tests,
no aquí.
"""
function auditar_dicotomia(horarios::Vector{<:Horario}, fracciones::Vector{Rational{BigInt}},
                           Ns::Vector{Int})
    filas = NamedTuple[]
    for h in horarios
        for f in fracciones
            for N in Ns
                f > 0 || continue
                parte = particion_mas_cara(h, f, N)
                reg = regresiva(h, f, f * N)
                push!(filas, (horario = string(typeof(h)), f = f, N = N,
                              parte_mas_caro = parte, regresiva = reg))
            end
        end
    end
    return filas
end

"""
    auditar_dicotomia_concava(horarios, fracciones) -> Vector{NamedTuple}

Comprueba, en una rejilla exacta y con expresiones **distintas** de las de
`auditar_dicotomia`, la concavidad en el punto medio y la subaditividad. Sirve
para separar «cóncava» (suficiente) de «subaditiva» (equivalente a la
regresividad): la tasa fija es cóncava y subaditiva; la lineal es cóncava y **no**
subaditiva estricta; la escalera con tope no es ni una cosa ni la otra en los
saltos.
"""
function auditar_dicotomia_concava(horarios::Vector{<:Horario},
                                   fracciones::Vector{Rational{BigInt}})
    filas = NamedTuple[]
    for h in horarios
        for i in 1:(length(fracciones) - 1)
            a = fracciones[i]
            b = fracciones[i + 1]
            push!(filas, (horario = string(typeof(h)), f1 = a, f2 = b,
                          concava = concava_en(h, a, b),
                          estricta = estrictamente_concava_en(h, a, b),
                          subaditiva = subaditiva_en(h, a, b),
                          subaditiva_estricta = subaditiva_estricta_en(h, a, b),
                          carga_decrece = carga_decreciente(h, a, b)))
        end
    end
    return filas
end
