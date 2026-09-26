# T04 — propiedades IE-1…IE-6 sobre historias DAG aleatorias.

"""
IE-1 (conservación), IE-2 (cada bloque no-`rojo_U3` aplicado una vez) e IE-4 (undo
exacto) sobre `Estado(past(B))`, `Estado(past(B)∪{B})` y el virtual. Devuelve la
lista de fallos.
"""
function verificar_ie1_ie2_ie4(A::Admision)
    fallos = String[]
    S, _, _ = estado_virtual(A)
    invariante_I1(S) || push!(fallos, "IE-1 virtual")
    invariante_I1b(S) || push!(fallos, "IE-1b virtual")
    ord = orden_aplicacion_virtual(A)
    validos = Set(id for (id, v) in A.validos if v)
    u3 = u3_virtual(A)
    if length(ord) != length(unique(ord))
        push!(fallos, "IE-2 duplicado")
    end
    if Set(ord) != setdiff(validos, u3)
        push!(fallos, "IE-2 cobertura")
    end
    for id in setdiff(validos, u3)
        invariante_I1(A.past[id]) || push!(fallos, "IE-1 past $id")
        invariante_I1(A.post[id]) || push!(fallos, "IE-1 post $id")
        E = A.past[id]
        b = A.por_id[id]
        S2, undo = aplicar_fusion_con_undo(A, E, b, b.slot)
        hash_canonico(undo) == hash_canonico(E) || push!(fallos, "IE-4 undo $id")
        hash_canonico(S2) == hash_canonico(A.post[id]) || push!(fallos, "IE-4 post $id")
    end
    S3, _, _ = aplicar_historia(A)
    hash_canonico(S3) == hash_canonico(S) || push!(fallos, "historia != virtual")
    return fallos
end

"""
IE-3 (determinismo del orden de llegada): reprocesa el mismo conjunto con uno o
varios órdenes de entrega y compara estados por id. `ordenes` es una lista de
vectores de índices (o `nothing` para generar `intentos` permutaciones aleatorias).
"""
function verificar_ie3(A::Admision, bloques::Vector{BloquePost}; ordenes = nothing,
                       intentos::Int = 200, semilla::UInt64 = UInt64(0x13))
    fallos = String[]
    ref_past = Dict(id => hash_canonico(A.past[id]) for id in keys(A.validos) if A.validos[id])
    ref_post = Dict(id => hash_canonico(A.post[id]) for id in keys(A.validos) if A.validos[id])
    ref_val = copy(A.validos)
    lista = if ordenes === nothing
        rng = StableRNG(semilla)
        [randperm(rng, length(bloques)) for _ in 1:intentos]
    else
        ordenes
    end
    for perm in lista
        A2 = Admision(A.pd, A.pow_bloques, A._id_T)
        resolver!(A2, bloques; llegada = perm)
        for id in union(keys(ref_val), keys(A2.validos))
            get(ref_val, id, false) == get(A2.validos, id, false) ||
                (push!(fallos, "IE-3 validez $id"); continue)
            if get(ref_val, id, false)
                ref_past[id] == hash_canonico(A2.past[id]) || push!(fallos, "IE-3 past $id")
                ref_post[id] == hash_canonico(A2.post[id]) || push!(fallos, "IE-3 post $id")
            end
        end
        isempty(fallos) || return fallos
    end
    return fallos
end

"IE-5: en historias sin fusiones (k=0) `Estado` coincide con T01."
function verificar_ie5(A::Admision, bps::Vector{BloquePost}, Efin::Transicion.Estado)
    fallos = String[]
    for b in bps
        get(A.validos, b.id, false) ||
            (push!(fallos, "IE-5 bloque $(b.id) inválido: $(get(A.motivos, b.id, :?))"); continue)
    end
    isempty(fallos) || return fallos
    hash_canonico(A.post[bps[end].id]) == hash_canonico(Efin) || push!(fallos, "IE-5 estado")
    return fallos
end

"""
IE-6 (complementariedad): el GHOSTDAG (blue_work, `sp`, mergeset, colores) y la
cadena seleccionada no dependen de los saldos de garantía. Se compara la historia
con sus transacciones frente a la misma estructura con solo coinbase.
"""
function verificar_ie6(A::Admision)
    fallos = String[]
    P = A.pd.P
    bloques_sin = BloquePost[]
    for b in values(A.por_id)
        txs = Transicion.Tx[Transicion.tx_coinbase_post(Transicion.subsidio_post(b.slot, P))]
        push!(bloques_sin, BloquePost(id = b.id, padres = b.padres, slot = b.slot,
                                      sr = b.sr, sd = b.sd, ident = b.ident,
                                      productor = b.productor, peso = b.peso, txs = txs))
    end
    A2 = Admision(A.pd, A.pow_bloques, A._id_T)
    # Orden de llegada sencillo: tal como se procesaron en A.
    resolver!(A2, bloques_sin; llegada = collect(1:length(bloques_sin)))
    for (id, val) in A.validos
        (val && get(A2.validos, id, false)) || continue
        g1 = A.gdr.gd[A.gidx[id]]
        g2 = A2.gdr.gd[A2.gidx[id]]
        sp1 = A.id_g[g1.sp]; sp2 = A2.id_g[g2.sp]
        ms1 = [A.id_g[x] for x in g1.ms_ordenado]
        ms2 = [A2.id_g[x] for x in g2.ms_ordenado]
        bl1 = [A.id_g[x] for x in g1.blues]
        bl2 = [A2.id_g[x] for x in g2.blues]
        rd1 = [A.id_g[x] for x in g1.reds]
        rd2 = [A2.id_g[x] for x in g2.reds]
        tp1 = sort!([(A.id_g[k], v) for (k, v) in g1.tipos])
        tp2 = sort!([(A2.id_g[k], v) for (k, v) in g2.tipos])
        (sp1 == sp2 && ms1 == ms2 && bl1 == bl2 && rd1 == rd2 &&
         tp1 == tp2 && g1.bw == g2.bw && g1.blue_score == g2.blue_score) ||
            push!(fallos, "IE-6 GHOSTDAG $id")
    end
    if Set(cadena_virtual(A)) == Set(cadena_virtual(A2))
        cadena_virtual(A) == cadena_virtual(A2) || push!(fallos, "IE-6 cadena orden")
    end
    return fallos
end
