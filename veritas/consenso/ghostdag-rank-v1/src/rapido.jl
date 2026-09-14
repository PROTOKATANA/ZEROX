# GDR-v0.1 — rapido: kernel incremental con la semántica de rusty-kaspa protocol.rs.
# check_blue_candidate / check_blue_candidate_with_chain_block / blue_anticone_size
# (protocol.rs:168-283) con el paseo por la cadena del sp y el mapa incremental de
# tamaños de anticono azul. blue_work en BW256 (dominio declarado [0, 2^256-1]).

mutable struct GDKernel
    sp::Int
    ms_ordenado::Vector{Int}    # mergeset completo en orden de coloreado (sin el sp)
    ms_blues::Vector{Int}       # [sp, ...] en orden de coloreado
    ms_reds::Vector{Int}        # en orden de coloreado
    tipos::Dict{Int,UInt8}      # bloque → 0x01 rojo_k, 0x02 rojo_U3
    bas::Dict{Int,UInt32}       # blues_anticone_sizes (protocol.rs:229-244)
    blue_idents::Set{UInt64}
    blue_score::UInt64
    bw::BW256
end

mutable struct EstadoRapido
    params::Params
    n::Int
    ids::Vector{ID32}
    padres::Vector{Vector{Int}}
    slots::Vector{UInt64}
    sds::Vector{UInt64}
    srs::Vector{UInt64}
    idents::Vector{UInt64}
    anc::Vector{BitSet}         # ancestros ESTRICTOS
    gd::Vector{GDKernel}
    motivo::Vector{Symbol}
end

bw_de(est::EstadoRapido, i::Int) = est.gd[i].bw

function EstadoRapido(params::Params, id_genesis::String;
                      slot_g::UInt64=UInt64(0), sr_g::UInt64=UInt64(0), ident_g::UInt64=UInt64(0))
    gd = GDKernel(0, Int[], [1], Int[], Dict{Int,UInt8}(), Dict{Int,UInt32}(1 => UInt32(0)),
                  ident_g == 0 ? Set{UInt64}() : Set{UInt64}([ident_g]), UInt64(0), BW256_CERO)
    return EstadoRapido(params, 1, [hash_de_id(id_genesis)], [Int[]],
                        UInt64[slot_g], UInt64[0], UInt64[sr_g], UInt64[ident_g],
                        [BitSet()], [gd], [:ok])
end

es_ancestro_rapido(est::EstadoRapido, a::Int, b::Int) = a == b || a in est.anc[b]

function mergeset_rapido(est::EstadoRapido, sp::Int, padres::Vector{Int})
    # past(B) \ (past(sp) ∪ {sp}), exacto también con padres no-punta.
    ms = BitSet()
    cola = Int[]
    for p in padres
        p == sp && continue
        es_ancestro_rapido(est, p, sp) && continue
        push!(ms, p)
        push!(cola, p)
    end
    while !isempty(cola)
        cur = popfirst!(cola)
        for p in est.padres[cur]
            p in ms && continue
            es_ancestro_rapido(est, p, sp) && continue
            push!(ms, p)
            push!(cola, p)
        end
    end
    return collect(ms)
end

# --- protocol.rs:230-244 ---------------------------------------------------
function tam_anticono_azul(est::EstadoRapido, nd::GDKernel, bloque::Int)::UInt32
    cur = nd
    while true
        haskey(cur.bas, bloque) && return cur.bas[bloque]
        sp = cur.sp
        sp == 0 && error("$bloque no está en el blue set del contexto")
        cur = est.gd[sp]
    end
end

# --- protocol.rs:168-225 ----------------------------------------------------
# `cadena == 0` representa el bloque nuevo (hash None en protocol.rs:259).
function revisar_con_bloque_cadena(est::EstadoRapido, nd::GDKernel, cadena::Int,
                                   cand::Int, cand_sizes::Dict{Int,UInt32},
                                   cand_size::UInt32, k::UInt32)
    if cadena != 0 && es_ancestro_rapido(est, cadena, cand)
        return (:azul, cand_size)
    end
    datos = cadena == 0 ? nd : est.gd[cadena]
    for peer in datos.ms_blues
        es_ancestro_rapido(est, peer, cand) && continue
        pbas = tam_anticono_azul(est, nd, peer)
        cand_sizes[peer] = pbas
        cand_size += UInt32(1)
        if cand_size > k
            return (:rojo, cand_size)
        end
        if pbas == k
            return (:rojo, cand_size)
        end
    end
    return (:pendiente, cand_size)
end

# --- protocol.rs:247-283 ----------------------------------------------------
# Devuelve (azul::Bool, cand_size, cand_sizes).
function check_azul(est::EstadoRapido, nd::GDKernel, cand::Int, k::UInt32)
    if length(nd.ms_blues) == k + 1
        return (false, UInt32(0), Dict{Int,UInt32}())
    end
    cand_sizes = Dict{Int,UInt32}()
    cand_size = UInt32(0)
    cadena = 0
    while true
        estado, cand_size = revisar_con_bloque_cadena(est, nd, cadena, cand,
                                                      cand_sizes, cand_size, k)
        estado == :azul && return (true, cand_size, cand_sizes)
        estado == :rojo && return (false, UInt32(0), cand_sizes)
        datos = cadena == 0 ? nd : est.gd[cadena]
        siguiente = datos.sp
        siguiente == 0 && error("génesis alcanzado sin resolver el candidato $cand")
        cadena = siguiente
    end
end

function anadir!(est::EstadoRapido, params::Params, id::String, padres::Vector{Int},
                 slot::UInt64, sd::UInt64, sr::UInt64, ident::UInt64)
    motivo = validar_estructura(est, params, padres, slot, ident)
    motivo == :ok || (push!(est.motivo, motivo); return false)

    anc = BitSet()
    for p in padres
        push!(anc, p)
        union!(anc, est.anc[p])
    end
    sp = seleccionar_sp(est, params, padres)
    if est.slots[sp] > slot
        push!(est.motivo, :slot_no_monotono)
        return false
    end
    if slot - est.slots[sp] > params.s_max
        push!(est.motivo, :salto_mayor_smax)
        return false
    end

    ms = mergeset_rapido(est, sp, padres)
    if length(ms) + 1 > params.mergeset_limit
        push!(est.motivo, :mergesettoobig)
        return false
    end
    ordenado = sort!(ms; lt=(a, b) -> menor_merge(est, params, a, b))

    nd = GDKernel(sp, copy(ordenado), [sp], Int[], Dict{Int,UInt8}(),
                  Dict{Int,UInt32}(sp => UInt32(0)), Set{UInt64}(),
                  UInt64(0), BW256_CERO)
    sp_bi = est.gd[sp].blue_idents
    vistos = Set{UInt64}()
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
            push!(nd.ms_reds, cand)
            nd.tipos[cand] = 0x02
            continue
        end
        azul, tam, cand_sizes = check_azul(est, nd, cand, params.k)
        if azul
            push!(nd.ms_blues, cand)
            nd.bas[cand] = tam
            for (h, s) in cand_sizes
                nd.bas[h] = s + UInt32(1)
            end
            cid != 0 && push!(vistos, cid)
        else
            push!(nd.ms_reds, cand)
            nd.tipos[cand] = 0x01
        end
    end

    nd.blue_score = est.gd[sp].blue_score + UInt64(length(nd.ms_blues))
    bw = est.gd[sp].bw
    for x in nd.ms_blues
        bw += peso(est.srs[x])
    end
    nd.bw = bw
    nd.blue_idents = copy(sp_bi)
    for x in nd.ms_blues
        cid = est.idents[x]
        cid != 0 && push!(nd.blue_idents, cid)
    end
    ident != 0 && push!(nd.blue_idents, ident)

    push!(est.ids, hash_de_id(id))
    push!(est.padres, padres)
    push!(est.slots, slot)
    push!(est.sds, sd)
    push!(est.srs, sr)
    push!(est.idents, ident)
    push!(est.anc, anc)
    push!(est.gd, nd)
    push!(est.motivo, :ok)
    est.n += 1
    return true
end
