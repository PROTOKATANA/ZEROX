# GDR-v0.1 — referencia: oráculo claro que recalcula todo desde cero.
# Conjuntos explícitos (Set{Int}) y blue_work en BigInt. El k-cluster se comprueba
# directamente contra la DEFINICIÓN: |anticone(x) ∩ B′| ≤ k para todo x ∈ B′.
# No comparte el algoritmo incremental de protocol.rs: la equivalencia entre ambos
# es lo que los tests de validación acreditan empíricamente.

mutable struct GDRef
    sp::Int
    ms_ordenado::Vector{Int}    # mergeset completo en orden de coloreado (sin el sp)
    blues::Vector{Int}          # [sp, ...] en orden de coloreado
    reds::Vector{Int}           # en orden de coloreado
    tipos::Dict{Int,UInt8}      # bloque → 0x01 rojo_k, 0x02 rojo_U3
    blue_idents::Set{UInt64}
    blue_score::UInt64
    bw::BigInt
    blueset::Set{Int}           # azules de past(B) ∪ {B} (blue set completo)
    tam::Dict{Int,Int}          # tam[x] = |anticone(x) ∩ blueset(B)|, ∀x ∈ blueset(B)
end

mutable struct EstadoReferencia
    params::Params
    n::Int
    ids::Vector{ID32}
    padres::Vector{Vector{Int}}
    slots::Vector{UInt64}
    sds::Vector{UInt64}
    srs::Vector{UInt64}
    idents::Vector{UInt64}
    anc::Vector{Set{Int}}       # ancestros ESTRICTOS
    gd::Vector{GDRef}
    motivo::Vector{Symbol}      # por bloque: :ok o motivo de rechazo
end

bw_de(est::EstadoReferencia, i::Int) = est.gd[i].bw

function EstadoReferencia(params::Params, id_genesis::String;
                          slot_g::UInt64=UInt64(0), sr_g::UInt64=UInt64(0),
                          ident_g::UInt64=UInt64(0))
    gd = GDRef(0, Int[], [1], Int[], Dict{Int,UInt8}(),
               ident_g == 0 ? Set{UInt64}() : Set{UInt64}([ident_g]), UInt64(0), big(0),
               Set{Int}([1]), Dict{Int,Int}(1 => 0))
    return EstadoReferencia(params, 1, [hash_de_id(id_genesis)], [Int[]],
                            UInt64[slot_g], UInt64[0], UInt64[sr_g], UInt64[ident_g],
                            [Set{Int}()], [gd], [:ok])
end

es_ancestro_ref(est::EstadoReferencia, a::Int, b::Int) = a == b || a in est.anc[b]

# ---------------------------------------------------------------------------
# Corrección 1, tarea 3.2(c) — independencia de direcciones. El oráculo NO llama a
# cmp_orden/cmp_python/cmp_kaspa/menor_merge/mejor_sp/seleccionar_sp/orden_aplicacion
# de modelo.jl: hasta ahora ambos (oráculo y kernel) compartían esas funciones, así
# que la equivalencia oráculo=kernel nunca podía detectar un error de DIRECCIÓN (los
# dos habrían estado de acuerdo... y de acuerdo en lo mismo incorrecto). Cada modo
# tiene aquí su propia clave, escrita desde cero a partir del texto de la sección 2.
# ---------------------------------------------------------------------------
"Clave del orden del mergeset (usos b y c), independiente del kernel."
function clave_merge_ref(est::EstadoReferencia, merge_mode::MergeMode, x::Int)
    bw = BigInt(bw_de(est, x)); sd = BigInt(est.sds[x]); id = collect(est.ids[x])
    merge_mode == MERGE_SPEC   && return (bw, sd, id)
    merge_mode == MERGE_PYTHON && return (bw, -sd, id)
    return (bw, id)   # MERGE_KASPA
end

"Orden ascendente del mergeset por la clave independiente del modo (usos b y c)."
orden_merge_ref(est::EstadoReferencia, params::Params, cand::Vector{Int}) =
    sort(cand; by=x -> clave_merge_ref(est, params.merge_mode, x))

"""
Clave histórica de selección de `sp` (:spec/:python/:kaspa): el padre seleccionado
es el MÁXIMO de la misma tupla que ordena el mergeset (así leía Kaspa/el prototipo
Python, antes de la regla C). No se reutiliza `clave_merge_ref` con `merge_mode`:
se lee directamente `sp_mode`, para no acoplar sp y mergeset si algún día difieren.
"""
function clave_sp_hist_ref(est::EstadoReferencia, sp_mode::SpMode, x::Int)
    bw = BigInt(bw_de(est, x)); sd = BigInt(est.sds[x]); id = collect(est.ids[x])
    sp_mode == SP_SPEC   && return (bw, sd, id)
    sp_mode == SP_PYTHON && return (bw, -sd, id)
    return (bw, id)   # SP_KASPA
end

"""
Padre seleccionado, independiente del kernel. Regla C (SP_ZEROX, uso a): mayor
blue_work; en empate, MENOR sd; en empate, MENOR id — clave `(-bw, sd, id)`
ascendente, se toma el mínimo (dirección mixta, ver sección 2 del encargo). Modos
históricos: máximo de `clave_sp_hist_ref` (mismo orden que el mergeset).
"""
function seleccionar_sp_ref(est::EstadoReferencia, params::Params, padres::Vector{Int})
    if params.sp_mode == SP_ZEROX
        claves = [(-(BigInt(bw_de(est, p))), BigInt(est.sds[p]), collect(est.ids[p]))
                  for p in padres]
        return padres[argmin(claves)]
    else
        claves = [clave_sp_hist_ref(est, params.sp_mode, p) for p in padres]
        return padres[argmax(claves)]
    end
end

"Punta virtual independiente: mismo criterio que seleccionar_sp_ref sobre las puntas."
virtual_sp_ref(est::EstadoReferencia, params::Params) =
    seleccionar_sp_ref(est, params, tips(est))

"""
Orden de aplicación independiente (R-FIN-8′(4)): idéntica estructura a
`orden_aplicacion` de modelo.jl (cadena ++ mergeset re-ordenado, saltando rojo_U3)
pero re-ordenando con `orden_merge_ref`, no con `menor_merge` del kernel.
"""
function orden_aplicacion_ref(est::EstadoReferencia, params::Params, tip::Int)
    ch = cadena_seleccionada(est, tip)
    orden = Int[ch[1]]
    for c in ch[2:end]
        ms = [x for x in ms_blues_de(est, c) if x != sp_de(est, c)]
        append!(ms, ms_reds_de(est, c))
        apl = [x for x in ms if !es_rojo_u3(est, c, x)]
        append!(orden, orden_merge_ref(est, params, apl))
        push!(orden, c)
    end
    return orden
end

function mergeset_ref(est::EstadoReferencia, sp::Int, padres::Vector{Int})
    # past(B) \ (past(sp) ∪ {sp}), exacto también con padres no-punta.
    ms = Set{Int}()
    cola = Int[]
    for p in padres
        p == sp && continue
        es_ancestro_ref(est, p, sp) && continue
        push!(ms, p)
        push!(cola, p)
    end
    while !isempty(cola)
        cur = popfirst!(cola)
        for p in est.padres[cur]
            p in ms && continue
            es_ancestro_ref(est, p, sp) && continue
            push!(ms, p)
            push!(cola, p)
        end
    end
    return ms
end

contar_anticone(est::EstadoReferencia, c::Int, S) =
    count(x -> !es_ancestro_ref(est, x, c) && !es_ancestro_ref(est, c, x), S)

"""
Definición directa del k-cluster sobre el BLUE SET COMPLETO de past(B):
al añadir `cand`, contexto ∪ {cand} debe seguir siendo un k-cluster, es decir
(i) |anticone(cand) ∩ contexto| ≤ k y
(ii) ∀b ∈ contexto ∩ anticone(cand): |anticone(b) ∩ contexto| + 1 ≤ k.
`tam[x] = |anticone(x) ∩ contexto|` se mantiene incrementalmente; su semántica es la
definición, no el algoritmo de protocol.rs (esa equivalencia la acreditan los tests).
"""
function k_cluster_vale(est::EstadoReferencia, contexto::Set{Int}, tam::Dict{Int,Int},
                        cand::Int, k::UInt32)
    anticono = [b for b in contexto
                if !es_ancestro_ref(est, b, cand) && !es_ancestro_ref(est, cand, b)]
    length(anticono) <= k || return (false, anticono)
    for b in anticono
        tam[b] + 1 <= k || return (false, anticono)
    end
    return (true, anticono)
end

function anadir!(est::EstadoReferencia, params::Params, id::String, padres::Vector{Int},
                 slot::UInt64, sd::UInt64, sr::UInt64, ident::UInt64)
    motivo = validar_estructura(est, params, padres, slot, ident)
    motivo == :ok || (push!(est.motivo, motivo); return false)

    anc = Set{Int}()
    for p in padres
        push!(anc, p)
        union!(anc, est.anc[p])
    end
    sp = seleccionar_sp_ref(est, params, padres)
    if est.slots[sp] > slot
        push!(est.motivo, :slot_no_monotono)
        return false
    end
    if slot - est.slots[sp] > params.s_max
        push!(est.motivo, :salto_mayor_smax)
        return false
    end

    ms = mergeset_ref(est, sp, padres)
    if length(ms) + 1 > params.mergeset_limit
        push!(est.motivo, :mergesettoobig)
        return false
    end
    ordenado = orden_merge_ref(est, params, collect(ms))

    sp_bi = est.gd[sp].blue_idents
    vistos = Set{UInt64}()
    contexto = copy(est.gd[sp].blueset)      # blue set completo de past(B)
    tam = copy(est.gd[sp].tam)
    blues = Int[sp]
    reds = Int[]
    tipos = Dict{Int,UInt8}()
    for cand in ordenado
        cid = est.idents[cand]
        filtrado = false
        if params.u3_mode != U3_OFF && cid != 0
            filtrado = cid in sp_bi
            if params.u3_mode == U3_DYNAMIC && !filtrado && cid in vistos
                filtrado = true
            end
        end
        if filtrado
            push!(reds, cand)
            tipos[cand] = 0x02
            continue
        end
        valido, anticono = k_cluster_vale(est, contexto, tam, cand, params.k)
        if valido
            for b in anticono
                tam[b] += 1
            end
            tam[cand] = length(anticono)
            push!(contexto, cand)
            push!(blues, cand)
            cid != 0 && push!(vistos, cid)
        else
            push!(reds, cand)
            tipos[cand] = 0x01
        end
    end

    blue_score = est.gd[sp].blue_score + UInt64(length(blues))
    bw = est.gd[sp].bw
    for x in blues
        bw += peso_big(est.srs[x])
    end
    blue_idents = copy(sp_bi)
    for x in blues
        cid = est.idents[x]
        cid != 0 && push!(blue_idents, cid)
    end
    ident != 0 && push!(blue_idents, ident)

    n_idx = est.n + 1
    blueset_final = copy(contexto)
    push!(blueset_final, n_idx)
    tam_final = tam
    # anticone(B) ∩ blueset(B) = ∅: todo azul de blueset(B) \ {B} es ancestro estricto de B
    tam_final[n_idx] = 0

    push!(est.ids, hash_de_id(id))
    push!(est.padres, padres)
    push!(est.slots, slot)
    push!(est.sds, sd)
    push!(est.srs, sr)
    push!(est.idents, ident)
    push!(est.anc, anc)
    push!(est.gd, GDRef(sp, ordenado, blues, reds, tipos, blue_idents, blue_score, bw,
                        blueset_final, tam_final))
    push!(est.motivo, :ok)
    est.n += 1
    return true
end
