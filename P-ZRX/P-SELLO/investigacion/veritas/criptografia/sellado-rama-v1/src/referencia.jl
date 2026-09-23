# referencia.jl — oráculos exactos y Monte Carlo independientes.
#
# Regla de la serie (LINEO y encargo §4): un test que compara una fórmula consigo
# misma no es un test. Aquí cada magnitud tiene DOS vías independientes:
#   α*      : forma cerrada  ↔  bisección exacta sobre g (no usa la forma cerrada)
#   LP      : regla de razón ↔  enumeración de vértices  ↔  rejilla racional
#   padres  : forma cerrada  ↔  simulación de eventos del modelo de punta
# y la verificación final es el residuo EXACTO (g(α*) = 0 en Rational{BigInt}).

using Random
using StableRNGs

# ---------------------------------------------------------------------------
# Aritmética exacta (Rational{BigInt})
# ---------------------------------------------------------------------------
const RB = Rational{BigInt}

ra(z::Integer) = RB(z)
ra(n::Integer, d::Integer) = RB(n, d)

alpha_estrella_exacta(η_h::RB, η_a::RB, β_d::RB, β_x::RB) =
    (η_h - η_a * β_d - (η_h + η_a) * β_x) // (η_h + η_a)

g_exacta(α::RB, η_h::RB, η_a::RB, β_d::RB, β_x::RB) =
    η_a * (α + β_d + β_x) - η_h * (1 - α - β_x)

"""
    biseccion_raiz(η_h, η_a, β_d, β_x; iter = 256)

Bracket racional de la raíz de `g` en `α ∈ [0,1]`, por bisección pura.
No usa `alpha_estrella_exacta`. Devuelve `(lo, hi)` con `g(lo) ≤ 0 ≤ g(hi)`.
"""
function biseccion_raiz(η_h::RB, η_a::RB, β_d::RB, β_x::RB; iter::Int = 256)
    (η_h > 0 && η_a > 0) || throw(ArgumentError("η > 0"))
    (β_d >= 0 && β_x >= 0) || throw(ArgumentError("β ≥ 0"))
    lo = RB(0)
    hi = RB(1)
    glo = g_exacta(lo, η_h, η_a, β_d, β_x)
    ghi = g_exacta(hi, η_h, η_a, β_d, β_x)
    glo <= 0 <= ghi || throw(ArgumentError("g no cambia de signo en [0,1]"))
    for _ in 1:iter
        med = (lo + hi) // 2
        gm = g_exacta(med, η_h, η_a, β_d, β_x)
        if gm < 0
            lo = med
        elseif gm > 0
            hi = med
        else
            return (med, med)
        end
    end
    return (lo, hi)
end

# ---------------------------------------------------------------------------
# F5 · ¿a quién prefiere el atacante por unidad de coste?
#   β_d baja α* en 1/2 por unidad de espacio; β_x lo baja en 1.
#   Daño por unidad de coste: (1/2)/c_d  frente a  1/c_x.
#   β_x se prefiere si  (1/2)/c_d < 1/c_x  ⇔  c_d > c_x/2.
# Es una comparación aritmética de dos racionales, no un LP con solución única
# (con presupuesto y espacio ilimitados el LP es un cono: lo que decide es la
#  dirección de máximo daño por coste, que es esta comparación).
# ---------------------------------------------------------------------------
"Daño sobre α* por unidad de coste de cada mecanismo."
function dano_por_coste(c_d::RB, c_x::RB)
    (c_d > 0 && c_x > 0) || throw(ArgumentError("c > 0"))
    return (bd = (RB(1) // 2) // c_d, bx = RB(1) // c_x)
end

"Cuántas veces es mejor β_x que β_d por unidad de coste ( > 1 ⇒ se prefiere β_x )."
ventaja_bx_sobre_bd(c_d::RB, c_x::RB) = (2 * c_d) // c_x

struct ResumenUmbral
    n::Int
    n_coincide::Int
end

"Contrasta la regla `c_d > c_x/2` con la comparación directa de daños por coste."
function validar_umbral(razones::Vector{RB}, c_x::RB)
    n = 0; ok = 0
    for φ in razones
        c_d = φ * c_x
        d = dano_por_coste(c_d, c_x)
        prefiere_bx = d.bx > d.bd
        esperado = c_d > c_x // 2
        prefiere_bx == esperado && (ok += 1)
        # coherencia con la ventaja marginal
        (ventaja_bx_sobre_bd(c_d, c_x) > 1) == prefiere_bx || error("ventaja incoherente")
        n += 1
    end
    return ResumenUmbral(n, ok)
end

# ---------------------------------------------------------------------------
# Semillas no consecutivas (encargo §4)
# ---------------------------------------------------------------------------
@inline function splitmix64(x::UInt64)
    x += 0x9E3779B97F4A7C15
    x = (x ⊻ (x >> 30)) * 0xBF58476D1CE4E5B9
    x = (x ⊻ (x >> 27)) * 0x94D049BB133111EB
    return x ⊻ (x >> 31)
end

"Semilla de la réplica `r` derivada de la maestra. No consecutivas por construcción."
semilla_replica(maestra::UInt64, r::Integer) =
    splitmix64(maestra ⊻ (UInt64(r) * 0xD1B54A32D192ED03))

# ---------------------------------------------------------------------------
# Monte Carlo del modelo de punta (H-RECEP)
#
# Cada bloque se crea en un tiempo Poisson(λ) y se recibe en el nodo de
# referencia tras un retardo exponencial de media Δ. Un bloque referencia las
# puntas visibles en su creación; la referencia se hace efectiva al recibirse.
# Devuelve `(padres_medios, puntas_medias_en_creacion, replicas)`.
# ---------------------------------------------------------------------------
function mc_puntas_una(λ::Float64, Δmedia::Float64, H::Float64, rng::AbstractRNG)
    t = Float64[]
    tt = 0.0
    while true
        tt += -log(rand(rng)) / λ
        tt > H && break
        push!(t, tt)
    end
    M = length(t)
    M == 0 && return (0.0, 0.0, 0)
    r = t .+ (-Δmedia .* log.(rand(rng, M)))   # recepción = creación + Exp(Δmedia)

    orden = sortperm(vcat(t, r))               # 1..M creación, M+1..2M recepción
    es_creacion = falses(2M)
    idx_bloque = Vector{Int}(undef, 2M)
    for i in 1:M
        es_creacion[i] = true
        idx_bloque[i] = i
        es_creacion[M + i] = false
        idx_bloque[M + i] = i
    end
    # ordenar por tiempo respetando el orden de inserción como desempate
    eventos = sort!(collect(1:2M); by = e -> (e <= M ? t[e] : r[e - M], e))

    es_punta = falses(M)
    padres_de = Vector{Vector{Int}}(undef, M)
    puntas = Int[]
    suma_padres = 0
    suma_puntas = 0
    for e in eventos
        i = idx_bloque[e]
        if es_creacion[e]
            n = count(j -> es_punta[j], puntas)
            # compactar si hace falta
            if length(puntas) > 2 * (suma_padres + M) + 16
                filter!(j -> es_punta[j], puntas)
            end
            p = Int[]
            for j in puntas
                es_punta[j] && push!(p, j)
            end
            padres_de[i] = p
            suma_padres += length(p)
            suma_puntas += length(p)
        else
            for q in padres_de[i]
                es_punta[q] = false
            end
            es_punta[i] = true
            push!(puntas, i)
        end
    end
    return (suma_padres / M, suma_puntas / M, M)
end

function mc_puntas(λ::Float64, Δmedia::Float64, H::Float64, replicas::Int,
                   maestra::UInt64)
    padres = Vector{Float64}(undef, replicas)
    puntas = Vector{Float64}(undef, replicas)
    Threads.@threads for r in 1:replicas
        rng = StableRNG(semilla_replica(maestra, r) % UInt64)
        pm, pp, _ = mc_puntas_una(λ, Δmedia, H, rng)
        padres[r] = pm
        puntas[r] = pp
    end
    return (padres, puntas)
end

"""
    mc_puntas_r123(λ, Δmedia, H, replicas, maestra)

Segunda vía de Monte Carlo, con RNG contracontador `Philox4x` (Random123) y
contador por réplica. Independiente del generador de `mc_puntas`.
"""
function mc_puntas_r123(λ::Float64, Δmedia::Float64, H::Float64, replicas::Int,
                        maestra::UInt64)
    padres = Vector{Float64}(undef, replicas)
    puntas = Vector{Float64}(undef, replicas)
    Threads.@threads for r in 1:replicas
        s1 = semilla_replica(maestra, r)
        s2 = splitmix64(s1)
        rng = Philox4x((s1, s2))
        pm, pp, _ = mc_puntas_una(λ, Δmedia, H, rng)
        padres[r] = pm
        puntas[r] = pp
    end
    return (padres, puntas)
end
