# rapido.jl — kernels tipoestables con salidas preasignadas.
# Sin globales dinámicos, sin Any, sin @fastmath. @inbounds con prueba de rango
# en el test; el barrido se ejecuta también con --check-bounds=yes en CI.

# ---------------------------------------------------------------------------
# Núcleo §2.2: presupuesto del honesto sobre una rejilla de Δ.
# ---------------------------------------------------------------------------
function kernel_presupuesto!(W::Vector{Float64}, tasa::Vector{Float64},
                             dmax::Vector{Float64}, padres::Vector{Float64},
                             deltas::Vector{Float64}, λ::Float64, τ::Float64,
                             r_maq::Float64; n_puntas::Float64 = NaN)
    n = length(deltas)
    (length(W) == n && length(tasa) == n && length(dmax) == n &&
     length(padres) == n) || throw(DimensionMismatch("salidas de tamaño $n"))
    @inbounds for i in 1:n
        Δ = deltas[i]
        p = presupuesto_honesto(λ, τ, Δ; n_puntas = n_puntas)
        W[i] = p.W_s
        tasa[i] = p.tasa_religadura
        dmax[i] = r_maq * p.W_s
        padres[i] = puntas_concurrentes(λ, Δ)
    end
    return nothing
end

# ---------------------------------------------------------------------------
# Núcleo de materialización: fracción de un objeto de S piezas que cabe en W.
# ---------------------------------------------------------------------------
function kernel_materializacion!(frac::Vector{Float64}, veces::Vector{Float64},
                                 W::Vector{Float64}, S_piezas::Float64,
                                 r_maq::Float64)
    n = length(W)
    @inbounds for i in 1:n
        frac[i] = r_maq * W[i] / S_piezas
        veces[i] = (S_piezas / r_maq) / W[i]
    end
    return nothing
end

# ---------------------------------------------------------------------------
# Núcleo F5: α* sobre una rejilla (β_d, β_x) con η dados.
# ---------------------------------------------------------------------------
function kernel_alfa!(α::Vector{Float64}, β_d::Vector{Float64},
                      β_x::Vector{Float64}, η_h::Float64, η_a::Float64)
    n = length(β_d)
    (length(α) == n && length(β_x) == n) || throw(DimensionMismatch("salidas"))
    den = η_h + η_a
    @inbounds for i in 1:n
        α[i] = (η_h - η_a * β_d[i] - den * β_x[i]) / den
    end
    return nothing
end

# ---------------------------------------------------------------------------
# Lema de circularidad (§2.1): dos bloques con el MISMO conjunto de padres
# tienen EXACTAMENTE la misma ancestría. Por tanto ninguna etiqueta derivada de
# la ancestría puede distinguir dos ramas que bifurcan en la punta.
# Se comprueba por enumeración explícita sobre DAGs pequeños.
# ---------------------------------------------------------------------------
"Ancestría (conjunto de ancestros propios, sin el propio bloque) de `b`."
function ancestria(padres::Vector{Vector{Int}}, b::Int)
    vista = falses(length(padres))
    pila = copy(padres[b])
    while !isempty(pila)
        x = pop!(pila)
        vista[x] && continue
        vista[x] = true
        for y in padres[x]
            vista[y] || push!(pila, y)
        end
    end
    return vista
end

"""
    pares_mismo_padre(padres)

Devuelve las parejas `(i,j)` con `padres[i] == padres[j]`, `i ≠ j`.
"""
function pares_mismo_padre(padres::Vector{Vector{Int}})
    pares = Tuple{Int,Int}[]
    n = length(padres)
    for i in 1:n, j in (i + 1):n
        if padres[i] == padres[j]
            push!(pares, (i, j))
        end
    end
    return pares
end
