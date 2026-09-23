# validacion.jl — equivalencia, invariantes y bordes.
# Cada comprobación contrasta DOS vías independientes; ninguna compara una
# fórmula consigo misma.

# ---------------------------------------------------------------------------
# α*: forma cerrada vs bisección exacta vs residuo exacto
# ---------------------------------------------------------------------------
struct ResumenAlfa
    n::Int
    n_residuo_cero::Int
    n_en_bracket::Int
    max_ancho::RB
end

function validar_alfa(η_h::RB, η_a::RB, βds::Vector{RB}, βxs::Vector{RB};
                      iter::Int = 256)
    n = 0
    nr = 0
    nb = 0
    maxancho = RB(0)
    for β_d in βds, β_x in βxs
        (β_d >= 0 && β_x >= 0 && β_d + β_x <= 1) || continue
        α = alpha_estrella_exacta(η_h, η_a, β_d, β_x)
        (0 <= α <= 1) || continue
        n += 1
        g_exacta(α, η_h, η_a, β_d, β_x) == 0 && (nr += 1)
        lo, hi = biseccion_raiz(η_h, η_a, β_d, β_x; iter = iter)
        lo <= α <= hi && (nb += 1)
        w = hi - lo
        w > maxancho && (maxancho = w)
        # orientación del signo a los dos lados (via independiente):
        # g es estrictamente creciente en α (pendiente η_h+η_a > 0)
        if α - RB(1, 10)^6 >= 0
            g_exacta(α - RB(1, 10)^6, η_h, η_a, β_d, β_x) < 0 ||
                throw(ErrorException("g no es < 0 a la izquierda de α*"))
        end
        g_exacta(α + RB(1, 10)^6, η_h, η_a, β_d, β_x) > 0 ||
            throw(ErrorException("g no es > 0 a la derecha de α*"))
    end
    return ResumenAlfa(n, nr, nb, maxancho)
end

# ---------------------------------------------------------------------------
# F5 · gap de sustitución: α*(β_d=s) − α*(β_x=s) = s/2, con g = 0 en ambos
# ---------------------------------------------------------------------------
struct ResumenGap
    n::Int
    n_residuo_cero::Int
    n_gap_exacto::Int
end

function validar_gap(η_h::RB, η_a::RB, ss::Vector{RB})
    n = 0; nr = 0; ng = 0
    for s in ss
        (0 <= s <= 1) || continue
        a_bd = alpha_estrella_exacta(η_h, η_a, s, RB(0))
        a_bx = alpha_estrella_exacta(η_h, η_a, RB(0), s)
        n += 1
        (g_exacta(a_bd, η_h, η_a, s, RB(0)) == 0 &&
         g_exacta(a_bx, η_h, η_a, RB(0), s) == 0) && (nr += 1)
        (a_bd - a_bx == s // 2) && (ng += 1)
    end
    return ResumenGap(n, nr, ng)
end

# ---------------------------------------------------------------------------
# Lema de circularidad: mismo conjunto de padres ⇒ misma ancestría
# ---------------------------------------------------------------------------
struct ResumenAncestria
    n_dags::Int
    n_pares::Int
    n_iguales::Int
end

function validar_ancestria(maestra::UInt64, n_dags::Int, n_max::Int)
    rng = StableRNG(maestra % UInt64)
    total_pares = 0
    iguales = 0
    for _ in 1:n_dags
        n = 2 + rand(rng, 1:(n_max - 2))
        pad = [Int[] for _ in 1:n]
        for i in 2:n
            # padres = subconjunto de 1..i-1 (no vacío en general)
            for j in 1:(i - 1)
                rand(rng) < 0.35 && push!(pad[i], j)
            end
        end
        pares = pares_mismo_padre(pad)
        for (i, j) in pares
            total_pares += 1
            ancestria(pad, i) == ancestria(pad, j) && (iguales += 1)
        end
    end
    return ResumenAncestria(n_dags, total_pares, iguales)
end

# ---------------------------------------------------------------------------
# Monotonía de α* (invariante del modelo contable)
# ---------------------------------------------------------------------------
function validar_monotonia(η_h::RB, η_a::RB, βds::Vector{RB}, βxs::Vector{RB})
    for β_d in βds, β_x in βxs
        β_d + β_x <= 1 || continue
        α = alpha_estrella_exacta(η_h, η_a, β_d, β_x)
        β_d + RB(1, 100) + β_x <= 1 && begin
            α2 = alpha_estrella_exacta(η_h, η_a, β_d + RB(1, 100), β_x)
            α2 < α || throw(ErrorException("α* no decrece en β_d"))
        end
        β_d + β_x + RB(1, 100) <= 1 && begin
            α3 = alpha_estrella_exacta(η_h, η_a, β_d, β_x + RB(1, 100))
            α3 < α || throw(ErrorException("α* no decrece en β_x"))
        end
    end
    return true
end
