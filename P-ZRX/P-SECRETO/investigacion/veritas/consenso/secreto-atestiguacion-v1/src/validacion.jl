# validacion.jl — equivalencia kernel rápido ↔ oráculo, bordes e invariantes
# Rutas independientes: enumeración exhaustiva (mecánica distinta), bolas de Arb,
# convolución numérica y Monte Carlo con RNG no consecutivo. La tabla de rutas
# independientes / no independientes se publica en el INFORME del instrumento.

using Random
using Random123

const RB = Rational{BigInt}

"""Contraste de captura_reemplazo contra enumeración, universo de N nodos,
atacante = primeros m nodos re-ponderados a fracción α exacta."""
function validar_captura(N::Int, kmax::Int; αs = [RB(1, 10), RB(1, 3), RB(1, 2)])::Bool
    for k in 1:kmax, α in αs
        m = max(1, round(Int, α * N))
        m ≤ N || continue
        w = fill((RB(1) - α) // (N - m), N)
        for j in 1:m
            w[j] = α // m
        end
        sum(w) == RB(1) || error("pesos mal normalizados")
        orac = captura_enumerada(w, k, collect(1:m))
        mod = captura_reemplazo(α, k)
        orac == mod || return false
    end
    return true
end

"""Enumeración sin reemplazo de nodos: secuencias de k nodos distintos,
peso condicional exacto (mecánica independiente de la forma de producto)."""
function captura_sin_reemplazo_enumerada(w::Vector{RB}, k::Int, atacante::Vector{Int})::RB
    N = length(w)
    s = RB(0)
    total = RB(0)
    idx = zeros(Int, k)
    function rec(prof::Int, peso::RB)
        if prof == k
            total += peso
            if all(j -> j in atacante, idx)
                s += peso
            end
            return
        end
        for j in 1:N
            j in idx[1:prof] && continue
            idx[prof+1] = j
            rec(prof + 1, peso * w[j])
        end
    end
    rec(0, RB(1))
    return s // total
end

"""Contraste de captura_sin_reemplazo contra enumeración SIN reemplazo de nodos."""
function validar_sin_reemplazo(N::Int, kmax::Int)::Bool
    for k in 1:kmax
        for m in max(1, k):N
            w = fill(RB(1) // N, N)
            orac = captura_sin_reemplazo_enumerada(w, k, collect(1:m))
            α = RB(m) // N
            mod = captura_sin_reemplazo(α, m, k)
            orac == mod || return false
        end
    end
    return true
end

"""Contraste del modelo de NODOS (disponibilidad correlacionada por nodo) contra
enumeración: los honestos responden con prob. p (enumeración de las 2^h configs)."""
function validar_produce(N::Int, kmax::Int; αs = [RB(1, 10), RB(1, 3)], ps = [RB(1), RB(9, 10), RB(1, 2)])::Bool
    for k in 1:kmax, α in αs, p in ps
        m = max(1, round(Int, α * N))
        m < N || continue
        w = fill((RB(1) - α) // (N - m), N)
        for j in 1:m
            w[j] = α // m
        end
        orac = produce_enumerada_p(w, k, p, collect(1:m))
        mod = fraccion_produce_nodos(α, p, k, N - m)
        orac == mod || return false
        # convergencia al continuo: fraccion_produce_nodos → fraccion_produce con h creciente
        h1 = fraccion_produce_nodos(α, p, k, 10)
        h2 = fraccion_produce_nodos(α, p, k, 40)
        lim = fraccion_produce(α, p, k)
        abs(h1 - lim) ≥ abs(h2 - lim) || return false
    end
    return true
end

"""Contraste de paro_particion (con sorteo del productor) contra enumeración."""
function validar_particion(N::Int, kmax::Int; xs = [RB(1, 10), RB(1, 3), RB(1, 2)])::Bool
    for k in 1:kmax, x in xs
        n1 = max(1, round(Int, x * N))
        n1 < N || continue
        w = fill(RB(1) // N, N)
        lado = [j ≤ n1 ? 1 : 2 for j in 1:N]
        orac = particion_enumerada(w, k, lado)
        x_ef = RB(n1) // N
        mod = paro_particion(x_ef, k)
        orac == mod || return false
    end
    return true
end

"""Contraste de captura_cadena (con factor del reto) contra enumeración por slot
(mecánica distinta: enumerar reto × sorteos en cada slot, N=2, d ≤ 3, k ≤ 2)."""
function validar_cadena()::Bool
    for k in 1:2, d in 1:3, α in [RB(1, 3), RB(1, 2), RB(2, 5)]
        orac = captura_cadena_enumerada(α, k, d)
        mod = captura_cadena(α, k, d)
        orac == mod || return false
    end
    return true
end

"""Contraste de p_no_fuga_exacta contra enumeración por plaza (3 resultados por
plaza: atacante / honesto-silencioso / honesto-filtrador), d ≤ 2, k ≤ 2."""
function validar_fuga()::Bool
    for k in 1:2, d in 1:2, α in [RB(1, 3), RB(1, 2)], p_sil in [RB(1, 2), RB(1, 10)]
        # enumerar las 3^(k·d) secuencias de resultados por plaza
        s = RB(0)
        total = k * d
        function rec(prof::Int, peso::RB)
            if prof == total
                s += peso
                return
            end
            rec(prof + 1, peso * α)                          # plaza del atacante
            rec(prof + 1, peso * (RB(1) - α) * p_sil)        # honesto silencioso
            # honesto filtrador: no cuenta para "ninguna fuga"
        end
        rec(0, RB(1))
        orac = s
        mod = p_no_fuga_exacta(α, p_sil, k, d)
        orac == mod || return false
    end
    return true
end

"""Contraste de la superficie α*: g(α*) = 0 exacto y signo estricto a los dos lados
en un entorno racional. También: β_x baja el umbral el doble que β_d."""
function validar_superficie()::Bool
    ε = RB(1, 10)^9
    for β_d in [RB(0), RB(1, 10), RB(1, 4)], β_x in [RB(0), RB(1, 20), RB(1, 10)]
        η_h, η_a = RB(1), RB(1)
        α = alpha_estrella(β_d, β_x, η_h, η_a)
        deriva(α, β_d, β_x, η_h, η_a) == RB(0) || return false
        deriva(α - ε, β_d, β_x, η_h, η_a) < RB(0) || return false
        deriva(α + ε, β_d, β_x, η_h, η_a) > RB(0) || return false
        alpha_estrella_uno(β_d, β_x) == alpha_estrella(β_d, β_x, RB(1), RB(1)) || return false
        d_d = alpha_estrella_uno(β_d + ε, β_x) - alpha_estrella_uno(β_d, β_x)
        d_x = alpha_estrella_uno(β_d, β_x + ε) - alpha_estrella_uno(β_d, β_x)
        d_x == 2 * d_d || return false
    end
    return true
end

"""Monte Carlo del máximo de k enlaces (valida la maquinaria RNG/plomería del modelo
multihop; la validez de la lognormal como modelo del enlace es S7, entrada externa)."""
function mc_max_enlace(k::Int, n::Int, semilla::UInt64)::Vector{Float64}
    μ, σ = parametros_enlace()
    maxs = Vector{Float64}(undef, n)
    for i in 1:n
        rng = Philox4x((splitmix64(semilla, 2i - 1), splitmix64(semilla, 2i)))
        mx = 0.0
        for _ in 1:k
            u = (rand(rng, UInt64) >> 11) / (Float64(typemax(UInt64) >> 11) + 1.0)
            u = min(u, 1.0 - eps(Float64))
            mx = max(mx, exp(μ + σ * sqrt(2.0) * erfcinv(2.0 * (1.0 - u))))
        end
        maxs[i] = mx
    end
    return maxs
end

"""IC de Wilson para una proporción (cerrado; usado solo para márgenes de Monte Carlo)."""
function ic_wilson(k_exitos::Int, n::Int, z::Float64 = 2.575829)::Tuple{Float64,Float64}
    p = k_exitos / n
    den = 1.0 + z^2 / n
    c = p + z^2 / (2 * n)
    m = z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2))
    return ((c - m) / den, (c + m) / den)
end
