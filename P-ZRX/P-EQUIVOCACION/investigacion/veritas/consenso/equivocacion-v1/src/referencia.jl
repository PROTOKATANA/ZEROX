# =============================================================================
# referencia.jl — oráculo pequeño, transparente y lento
#
# Independencia de método respecto de `rapido.jl` / `modelo.jl`:
#   R1. El pasado se recalcula por DFS en cada consulta; no usa la caché `Dag.pasado`.
#   R2. El orden de proceso se recalcula por DFS postorden; no usa el orden de ids.
#   R3. El coloreo se reimplementa con `Vector{Int}` y anticonos explícitos, sin bitsets.
#   R4. El ancla se calcula con la formulación ALTERNATIVA de R-FIN-1 («menor `blue_work`
#       entre los bloques de la cadena con `slot >= T_j`»), no con «el primer cruce».
#       La equivalencia de las dos formulaciones se apoya en (F1) `slot` no decreciente y
#       (F2) `blue_work` estrictamente creciente a lo largo de la cadena seleccionada,
#       citadas en `veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md:641-655`. Aquí se
#       COMPRUEBA en vez de suponerse: si las dos formulaciones discrepan, se reporta.
#   R5. El flujo se recalcula entero para cada slot, sin prefijos ni caché.
# =============================================================================

"R1: pasado estricto por DFS (máscara sobre todos los bloques del DAG)."
function pasado_ref(d::Dag, b::Int)
    n = nbloques(d)
    vistos = falses(n)
    pila = copy(d.bloques[b].padres)
    while !isempty(pila)
        x = pop!(pila)
        vistos[x] && continue
        vistos[x] = true
        for p in d.bloques[x].padres
            vistos[p] || push!(pila, p)
        end
    end
    return vistos
end

"R2: orden topológico por DFS postorden restringido a `V`."
function orden_topo_ref(d::Dag, V::Vector{Int})
    conjunto = falses(nbloques(d)); conjunto[V] .= true
    visto = falses(nbloques(d))
    orden = Int[]
    function visita(x)
        visto[x] && return
        visto[x] = true
        for p in d.bloques[x].padres
            conjunto[p] && visita(p)
        end
        push!(orden, x)
    end
    for x in V
        visita(x)
    end
    return orden
end

"Anticono de `x` dentro del contexto `ctx`: bloques INCOMPARABLES con `x`."
function anticono_ref(d::Dag, x::Int, ctx::Vector{Int}, pas::Dict{Int,BitVector})
    out = Int[]
    for y in ctx
        (y != x && !pas[x][y] && !pas[y][x]) && push!(out, y)
    end
    return out
end

"""
    ghostdag_ref(d, V, k)

GHOSTDAG restringido a `V`: devuelve `(sp, azules, aporte, bsc, bwr)`, todos `Dict`.
"""
function ghostdag_ref(d::Dag, V::Vector{Int}, k::Int)
    pas = Dict(x => pasado_ref(d, x) for x in V)
    orden = orden_topo_ref(d, V)
    enV = falses(nbloques(d)); enV[V] .= true
    sp = Dict{Int,Int}(); azules = Dict{Int,Vector{Int}}(); aporte = Dict{Int,Vector{Int}}()
    bsc = Dict{Int,Int}(); bwr = Dict{Int,BigInt}()
    for b in orden
        padv = [p for p in d.bloques[b].padres if enV[p]]
        if isempty(padv)
            sp[b] = 0; azules[b] = [b]; aporte[b] = [b]
            bsc[b] = 1; bwr[b] = peso_bloque(d.bloques[b].sr)
            continue
        end
        mejor = 0
        for p in padv
            if mejor == 0 || (bwr[p], -d.bloques[p].dist, -p) > (bwr[mejor], -d.bloques[mejor].dist, -mejor)
                mejor = p
            end
        end
        sp[b] = mejor
        ms = Int[]
        for x in V
            (x != b && pas[b][x]) || continue
            (x == mejor || pas[mejor][x]) && continue
            push!(ms, x)
        end
        sort!(ms; by = x -> (bwr[x], d.bloques[x].dist, x))
        ctx = copy(azules[mejor]); push!(ctx, mejor)
        ap = [mejor]
        for x in ms
            # U3'' (C-GD-07): identidad ya azul en el contexto acumulado
            if any(y -> d.bloques[y].billete == d.bloques[x].billete, ctx)
                continue                       # rojo_U3: no entra en el contexto ni en el aporte
            end
            anti = anticono_ref(d, x, ctx, pas)
            rojo = length(anti) > k
            if !rojo
                for y in anti
                    # todo `y ∈ anti` es azul: `anti ⊆ ctx` y `ctx` ES el conjunto azul acumulado
                    if length(anticono_ref(d, y, ctx, pas)) + 1 >= k
                        rojo = true; break
                    end
                end
            end
            if !rojo
                push!(ctx, x); push!(ap, x)
            end
        end
        azules[b] = sort(unique(ctx)); aporte[b] = sort(unique(ap))
        bsc[b] = bsc[mejor] + length(aporte[b])
        bwr[b] = bwr[mejor] + sum(peso_bloque(d.bloques[x].sr) for x in aporte[b])
    end
    return sp, azules, aporte, bsc, bwr
end

"R4: ancla por la formulación alternativa de R-FIN-1 (menor `blue_work` entre los cruces)."
function ancla_ref(d::Dag, b::Int, T::Int, L::Int, k::Int)
    pas_b = pasado_ref(d, b)
    V = [x for x in 1:nbloques(d) if (x == b || pas_b[x]) && d.bloques[x].slot < T + L]
    sp, _, _, _, bwr = ghostdag_ref(d, V, k)
    enV = falses(nbloques(d)); enV[V] .= true
    puntas = [x for x in V if !any(y -> y != x && enV[y] && x in d.bloques[y].padres, V)]
    tip = 0
    for t in puntas
        if tip == 0 || (bwr[t], -d.bloques[t].dist, -t) > (bwr[tip], -d.bloques[tip].dist, -tip)
            tip = t
        end
    end
    cad = Int[]; x = tip
    while x != 0
        push!(cad, x); x = sp[x]
    end
    cadena = reverse(cad)                      # del génesis de V a la punta
    cruces = [y for y in cadena if d.bloques[y].slot >= T]
    isempty(cruces) && return 0, cadena
    return cruces[argmin([bwr[y] for y in cruces])], cadena
end

"R5: inyecciones y flujo recalculados por completo para cada slot."
function flujo_ref(d::Dag, b::Int, s::Int, I_slots::Int, L::Int, jmax::Int, k::Int)
    out = Tuple{Int,Tuple{Int,Int},Int}[]
    for j in 1:jmax
        T = j * I_slots
        a, _ = ancla_ref(d, b, T, L, k)
        a == 0 && continue
        t = d.bloques[a].slot + L
        t <= s || continue
        push!(out, (j, (d.bloques[a].chunk, d.bloques[a].slot), t))
    end
    return out
end
