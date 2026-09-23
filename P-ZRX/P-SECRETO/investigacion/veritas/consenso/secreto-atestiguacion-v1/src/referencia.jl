# referencia.jl — oráculos independientes (enumeración exhaustiva, aritmética de bolas,
# convolución numérica) para contrastar las fórmulas del modelo.
# Ningún test compara una fórmula consigo misma (PROMPT §6).

using Arblib
using SpecialFunctions

const RB = Rational{BigInt}

# ---------------------------------------------------------------------------
# Oráculo A: enumeración de sorteos sobre un universo finito de N nodos.
# ---------------------------------------------------------------------------

"""Enumerar las N^k secuencias de plazas con su peso (con reemplazo).
Devuelve Vector{Tuple{Vector{Int}, RB}}; N y k pequeños (N ≤ 8, k ≤ 4)."""
function enumerar_sorteos(w::Vector{RB}, k::Int)::Vector{Tuple{Vector{Int}, RB}}
    N = length(w)
    suma = sum(w)
    abs(suma - RB(1)) < RB(1, 10)^12 || throw(ArgumentError("pesos deben sumar 1"))
    out = Tuple{Vector{Int}, RB}[]
    idx = zeros(Int, k)
    function rec(prof::Int, peso::RB)
        if prof == k
            push!(out, (copy(idx), peso))
            return
        end
        for j in 1:N
            idx[prof+1] = j
            rec(prof + 1, peso * w[j])
        end
    end
    rec(0, RB(1))
    return out
end

"""P(los k sorteados son todos del atacante) por enumeración, universo finito."""
function captura_enumerada(w::Vector{RB}, k::Int, atacante::Vector{Int})::RB
    s = RB(0)
    for (sec, peso) in enumerar_sorteos(w, k)
        if all(j -> j in atacante, sec)
            s += peso
        end
    end
    return s
end

"""P(las k plazas caen en nodos que responden) por enumeración con banderas de
respuesta deterministas (responde[j] ∈ {0,1})."""
function produce_enumerada(w::Vector{RB}, k::Int, responde::Vector{Int})::RB
    s = RB(0)
    for (sec, peso) in enumerar_sorteos(w, k)
        if all(j -> responde[j] == 1, sec)
            s += peso
        end
    end
    return s
end

"""P(las k plazas caen en nodos que responden) con respuesta ALEATORIA por nodo
honesto (prob. p; el atacante nunca responde): se enumeran las 2^(N−m) configuraciones
de respuesta de los honestos con sus pesos. Ruta independiente para fraccion_produce
con p < 1."""
function produce_enumerada_p(w::Vector{RB}, k::Int, p::RB, atacante::Vector{Int})::RB
    N = length(w)
    honestos = [j for j in 1:N if !(j in atacante)]
    s = RB(0)
    for flags in 0:(2^length(honestos) - 1)
        responde = zeros(Int, N)
        peso_flags = RB(1)
        for (pos, j) in enumerate(honestos)
            r = ((flags >> (pos - 1)) & 1) == 1 ? 1 : 0
            responde[j] = r
            peso_flags *= r == 1 ? p : (RB(1) - p)
        end
        for (sec, peso) in enumerar_sorteos(w, k)
            if all(j -> responde[j] == 1, sec)
                s += peso * peso_flags
            end
        end
    end
    return s
end

"""P(paro total en partición) por enumeración, INCLUIDO el sorteo del productor:
el productor cae en el nodo j con prob. w[j] (independiente de las plazas, S4).
Un lado produce si productor y las k plazas están todos en ese lado."""
function particion_enumerada(w::Vector{RB}, k::Int, lado::Vector{Int})::RB
    s = RB(0)
    for (prod, wprod) in enumerate(w)
        for (sec, peso) in enumerar_sorteos(w, k)
            producen_A = lado[prod] == 1 && all(j -> lado[j] == 1, sec)
            producen_B = lado[prod] == 2 && all(j -> lado[j] == 2, sec)
            if !producen_A && !producen_B
                s += wprod * peso
            end
        end
    end
    return s
end

"""P(cadena de d bloques capturada) por enumeración: en cada slot hay un RETO
(independiente: el atacante gana con prob. α) y k plazas; el bloque cuenta si
gana el reto y las k plazas son suyas. Universo pequeño: N=2, d ≤ 3, k ≤ 2.
Mecánica genuinamente distinta de la forma cerrada α^((k+1)d)."""
function captura_cadena_enumerada(α::RB, k::Int, d::Int)::RB
    N = 2
    w = [α, RB(1) - α]
    atacante = [1]
    s = RB(0)
    # por slot: enumerar (reto gana atacante: prob α) × (k plazas)
    sorteos = enumerar_sorteos(w, k)
    p_bloque = RB(0)
    for (sec, peso) in sorteos
        if all(j -> j in atacante, sec)
            p_bloque += peso
        end
    end
    # P(bloque atacante por slot) = α · p_bloque  (independencia S4)
    p_slot = α * p_bloque
    return p_slot^d
end

# ---------------------------------------------------------------------------
# Oráculo B: lognormal del enlace (DMS-v0.1: mediana 80 ms, p99 500 ms, por enlace
# no dirigido; veritas/finalidad/delta-medido-v1/INFORME.md:44) y el umbral de
# cabida de la ronda. Los valores que tocan el veredicto se certifican con Arblib.
# ---------------------------------------------------------------------------

const MEDIANA_ENLACE = 0.080      # s, DMS-v0.1 (entrada congelada, etiquetada)
const P99_ENLACE = 0.500          # s, íd.
const Z99 = 2.326347874040841      # Φ⁻¹(0,99)

"""μ y σ de la lognormal del enlace, derivados de mediana y p99 (identidades exactas:
ln(mediana) = μ; ln(p99) = μ + z99·σ)."""
function parametros_enlace(med::Float64 = MEDIANA_ENLACE, p99::Float64 = P99_ENLACE)::Tuple{Float64,Float64}
    μ = log(med)
    σ = (log(p99) - μ) / Z99
    return (μ, σ)
end

"""CDF de la lognormal del enlace evaluada con bola de Arb (certificación).
Devuelve la bola Arb de Φ(z) con z = (ln t − μ)/(σ·√2); Φ = (1+erf(z))/2."""
function cdf_enlace_arb(t::Float64; prec::Int = 128)::Arb
    μ, σ = parametros_enlace()
    tt = Arb(t; prec = prec)
    mm = Arb(μ; prec = prec)
    ss = Arb(σ; prec = prec)
    z = (log(tt) - mm) / (ss * Arb(sqrt(2.0); prec = prec))
    return (Arb(1; prec = prec) + SpecialFunctions.erf(z)) / 2
end

"""CDF de la lognormal del enlace en Float64 (SpecialFunctions.erf), para las tablas."""
function cdf_enlace_f64(t::Float64)::Float64
    μ, σ = parametros_enlace()
    return 0.5 * (1.0 + SpecialFunctions.erf((log(t) - μ) / (σ * sqrt(2.0))))
end

"""Comprobación independiente de la constante z99: Φ(z99) = 0,99 con bola de Arb."""
function comprobar_z99(prec::Int = 128)::Arb
    z = Arb(Z99; prec = prec)
    return (Arb(1; prec = prec) + SpecialFunctions.erf(z / Arb(sqrt(2.0); prec = prec))) / 2
end

# ---------------------------------------------------------------------------
# Oráculo C: suma de m lognormales iid por convolución numérica iterada.
# Ruta independiente del Monte Carlo para la latencia multihop:
#   T_col = 2·h·l + t_sign, l ~ lognormal; P(cabe) = P(T_col ≤ W − t_sign).
# Convolución iterada: F_{n+1}(t) = ∫ F_n(t−x) f_1(x) dx, integración de Simpson
# sobre una rejilla; la cola se completa con la monotonía de la CDF.
# ---------------------------------------------------------------------------

function pdf_enlace(x::Float64)::Float64
    μ, σ = parametros_enlace()
    x ≤ 0.0 && return 0.0
    return exp(-(log(x) - μ)^2 / (2σ^2)) / (x * σ * sqrt(2π))
end

"""CDF de la suma de m enlaces lognormales iid por convolución iterada.
La primera capa usa la CDF exacta (erf certificada) en la rejilla; las capas
siguientes integran con Simpson compuesto (error O(dx⁴) por capa, propagado por
sup-norma). Ruta numérica independiente del Monte Carlo."""
function cdf_suma_enlaces(m::Int, t_max::Float64 = 6.0, npts::Int = 4000)::Tuple{Vector{Float64},Vector{Float64}}
    m ≥ 1 || throw(ArgumentError("m ≥ 1"))
    iseven(npts) || (npts += 1)          # Simpson compuesto exige nº par de intervalos
    dx = t_max / npts
    x = collect(range(0.0, t_max, length = npts + 1))   # rejilla con bordes 0..t_max
    f = pdf_enlace.(x)
    if m == 1
        return (x, cdf_enlace_f64.(x))
    end
    F = cdf_enlace_f64.(x)               # F_1 exacta (erf) en la rejilla
    w = ones(npts + 1)
    for j in 2:2:npts
        w[j] = 4.0
    end
    for j in 3:2:(npts - 1)
        w[j] = 2.0
    end
    for _ in 2:m
        Fn = similar(F)
        for i in 0:npts
            # F_n(t_i) = ∫₀^{t_i} F_{n−1}(t_i − x) f(x) dx por Simpson;
            # t_i − x_j = (i−j)·dx cae en la rejilla: índice i−j+1 ∈ [1, i+1] (en rango).
            s = 0.0
            @inbounds for j in 0:i
                s += F[i-j+1] * f[j+1] * w[j+1]
            end
            Fn[i+1] = s * dx / 3.0
        end
        F = Fn
    end
    return (x, F)   # F[k] = CDF en x[k]
end

"""P(T_col ≤ umbral) por convolución iterada, T_col = m enlaces + t_sign.
NOTA: cada llamada reconstruye la convolución; en las tablas (run.jl) la CDF se
precalcula UNA vez por m y se interpola (el coste se amortiza entre todas las celdas)."""
function p_cabe_conv(umbral::Float64, m::Int, t_sign::Float64, npts::Int = 4000)::Float64
    u = umbral - t_sign
    u ≤ 0.0 && return 0.0
    t_max = max(6.0, u + 0.5)
    x, F = cdf_suma_enlaces(m, t_max, npts)
    dx = t_max / npts
    idx = clamp(round(Int, u / dx) + 1, 1, length(F))
    return F[idx]
end
