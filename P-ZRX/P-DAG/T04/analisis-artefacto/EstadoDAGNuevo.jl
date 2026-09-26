# T04 — Oráculo de referencia del estado en el DAG PoST.
#
# Implementa `P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md` (ED-1…ED-6, IE-1…IE-6) sobre:
#   * la fase PoW del oráculo T01 (`P-ZRX/P-TRANSICION/T01/src/Transicion.jl`,
#     dependencia de SOLO LECTURA vía `include`, declarada en METODO.md);
#   * el oráculo GHOSTDAG antiguo GDR-v0.2 (`src/modelo.jl` + `src/referencia.jl`,
#     copias literales) con la raíz interpretada como el terminal `T` (D-P07).
#
# Oráculo claro, sin optimización (LINEO §2); tipos concretos, sin `Any` en el
# núcleo, sin `@fastmath`/`@simd`/`@inbounds`. Un hilo.
module EstadoDAGNuevo

using Random
using SHA
using Printf
using StableRNGs

# T01 actual (F-18) instrumentado SOLO para este análisis de T04-D.
const RUTA_T01 = joinpath(@__DIR__, "t01_nuevo", "Transicion.jl")

include("GDR.jl")                 # module GDR (modelo.jl + referencia.jl)
include(RUTA_T01)                 # module Transicion (T01)

using .GDR
using .Transicion

export ParamsDAG, BloquePost, Admision, MOTIVOS
export procesar_uno!, resolver!, admite_todo, marcar_invalido!
export aplicar_bloque_fusion!, aplicar_fusion_con_undo
export estado_past, estado_post, tips_validas, estado_virtual, cadena_virtual,
       orden_aplicacion_virtual, descartes_virtual, aplicar_historia, u3_virtual, mejor_punta
export representacion_canonica, hash_canonico, invariante_I1, invariante_I1b
export id_T, k_de, params_T
export generar_pow_terminal, generar_dag_aleatorio, generar_cadena_post,
       sr_peso, bl_desde_post
export PARAMS_DAG_BASE, PUNTOS_T04

# ---------------------------------------------------------------------------
# Parámetros
# ---------------------------------------------------------------------------

"""
`ParamsDAG` = reglas por bloque de T01 (§3 de la orden) + `k` del k-cluster
GHOSTDAG. El resto de la rejilla de T01 se fija en `PUNTOS_T04`.
"""
struct ParamsDAG
    P::Transicion.Params
    k::UInt32
end

ParamsDAG(P::Transicion.Params, k::Integer) = ParamsDAG(P, UInt32(k))
params_T(pd::ParamsDAG) = pd.P
k_de(pd::ParamsDAG) = pd.k

# ---------------------------------------------------------------------------
# Bloque PoST del DAG
# ---------------------------------------------------------------------------

"""
Bloque PoST del DAG. `id` es el hash entero (como en T01); `padres` son ids de
bloques PoST o del terminal `T`; `sr` es el rango de espacio (peso GHOSTDAG);
`peso` es el peso PoST de T01 (`peso_sufijo`, solo para IE-5); `txs` son las
transacciones del contrato de transición.
"""
struct BloquePost
    id::Int
    padres::Vector{Int}
    slot::Int
    sr::UInt64
    sd::UInt64
    ident::UInt64
    productor::Int
    peso::Int
    txs::Vector{Transicion.Tx}
end

function BloquePost(; id, padres::Vector{Int}, slot::Integer,
                    sr::Integer = typemax(UInt64), sd::Integer = 0,
                    ident::Integer = 0, productor::Integer = 1,
                    peso::Integer = 1, txs::Vector{Transicion.Tx} = Transicion.Tx[])
    return BloquePost(Int(id), padres, Int(slot), UInt64(sr), UInt64(sd),
                      UInt64(ident), Int(productor), Int(peso), txs)
end

# ---------------------------------------------------------------------------
# Admisión
# ---------------------------------------------------------------------------

"""
Estado de admisión del DAG. `gdr` es el `EstadoReferencia` de GDR-v0.2 con la
raíz `1` = terminal `T`; `past[b]` = `Estado(past(b))`; `post[b]` =
`Estado(past(b) ∪ {b})`; `validos`/`motivos` por id.
"""
mutable struct Admision
    pd::ParamsDAG
    gparams::GDR.Params
    pow_bloques::Vector{Transicion.Bloque}
    _id_T::Int
    estado_T::Transicion.Estado
    por_id::Dict{Int,BloquePost}
    validos::Dict{Int,Bool}
    motivos::Dict{Int,Symbol}
    past::Dict{Int,Transicion.Estado}
    post::Dict{Int,Transicion.Estado}
    descartes::Dict{Int,Vector{Tuple{Int,Transicion.Err}}}
    gidx::Dict{Int,Int}          # id de bloque -> índice GDR (1 = T)
    id_g::Vector{Int}            # índice GDR -> id de bloque (id_g[1] = T)
    gdr::GDR.EstadoReferencia
    procesados::Set{Int}
    orden::Vector{Int}           # ids PoST en el orden en que se procesaron
end

id_T(A::Admision) = A._id_T

function Admision(pd::ParamsDAG, pow_bloques::Vector{Transicion.Bloque}, id_terminal::Integer)
    P = pd.P
    gparams = GDR.Params(k = pd.k, max_parents = 3, mergeset_limit = 180,
                         s_max = typemax(UInt64), u2 = true,
                         u3_mode = GDR.U3_DYNAMIC, sp_mode = GDR.SP_ZEROX,
                         merge_mode = GDR.MERGE_SPEC)
    idt = Int(id_terminal)
    gdr = GDR.EstadoReferencia(gparams, "T";
                               slot_g = UInt64(0), sr_g = UInt64(0), ident_g = UInt64(0))
    S = Transicion.estado_inicial(P)
    for B in pow_bloques
        r = Transicion.aplicar!(S, B, P)
        r isa Transicion.Err && error("PoW inválido al construir Admision: $(r)")
    end
    return Admision(pd, gparams, pow_bloques, idt, S, Dict{Int,BloquePost}(),
                    Dict{Int,Bool}(), Dict{Int,Symbol}(), Dict{Int,Transicion.Estado}(),
                    Dict{Int,Transicion.Estado}(),
                    Dict{Int,Vector{Tuple{Int,Transicion.Err}}}(),
                    Dict(idt => 1), [idt], gdr, Set{Int}([idt]), Int[])
end

"Texto GDR de un id dado el terminal `idt`."
texto_id(i::Integer, idt::Integer) = i == idt ? "T" : string("B", i)

# ---------------------------------------------------------------------------
# Comprobaciones de forma / padres
# ---------------------------------------------------------------------------

"""
Marca `b` como inválido con motivo `m` (símbolo). No altera el estado GHOSTDAG
(si el bloque ya fue añadido a GDR, queda ahí pero nunca es ancestro de un
bloque válido: los hijos comprueban `validos`).
"""
function marcar_invalido!(A::Admision, b::BloquePost, m::Symbol)
    A.por_id[b.id] = b
    A.validos[b.id] = false
    A.motivos[b.id] = m
    push!(A.procesados, b.id)
    return m
end

mapear_motivo_gdr(m::Symbol) =
    m === :slot_no_monotono ? :ErrSlot :
    m === :salto_mayor_smax ? :ErrSlot :
    m === :toomanyparents   ? :ErrSinPadre :
    m === :mergesettoobig   ? :ErrMergeset :
    m === :u2               ? :ErrU2 :
    :ErrSinPadre

"""
Comprueba la forma/padres de `b` **sin** tocar GDR. Devuelve `nothing` si pasa, o
el símbolo de error de bloque.
"""
function chequear_forma(A::Admision, b::BloquePost)
    isempty(b.padres) && return :ErrSinPadre
    length(unique(b.padres)) != length(b.padres) && return :ErrSinPadre
    if A._id_T in b.padres && length(b.padres) != 1
        return :ErrSinPadre
    end
    for p in b.padres
        if p != A._id_T && !haskey(A.por_id, p)
            return :ErrSinPadre
        end
        if p != A._id_T && !get(A.validos, p, false)
            return :ErrSinPadre
        end
    end
    b.slot >= 1 || return :ErrSlot
    # coinbase: a lo sumo una, y si está, primera y de tipo PoST (R-6/F-09)
    ncb = 0
    icb = 0
    for (i, tx) in enumerate(b.txs)
        if tx.tipo == Transicion.TxCoinbase || tx.tipo == Transicion.TxCoinbasePost
            ncb += 1
            icb = i
        end
    end
    ncb > 1 && return :ErrEmision
    if ncb == 1
        icb == 1 || return :ErrEmision
        txcb = b.txs[1]
        txcb.tipo == Transicion.TxCoinbasePost || return :ErrEmision
        txcb.importe == 0 && return :ErrSaldo   # R-8
    end
    return nothing
end

# ---------------------------------------------------------------------------
# Aplicación en modo fusión
# ---------------------------------------------------------------------------

bloque_sintetico(b::BloquePost, punto::Int) =
    Transicion.Bloque(id = b.id, familia = Transicion.PoST, padre = -1,
                      slot = punto, productor = b.productor, peso = max(b.peso, 1),
                      sector = 0, txs = b.txs)

"""
Aplica **en modo fusión** la coinbase y las transacciones de `b` sobre `S` en el
punto de aplicación `punto` (§3 del contrato):
  * las transacciones que no validan se **descartan** (no invalidan el bloque);
  * la coinbase PoST acredita `mín(declarado, subsidio_post(slot(b)) + tarifas
    aceptadas)`; el resto no existe;
  * la madurez del crédito y el inicio de retiro/liberación usan `punto`;
  * el importe del subsidio usa `slot(b)` (AMBIGUEDAD-1);
  * `rojo_U3` no llega aquí (se salta antes).
Devuelve `(S, descartes)` con `descartes::Vector{Tuple{Int,Transicion.Err}}`.
"""
function aplicar_bloque_fusion!(A::Admision, S::Transicion.Estado, b::BloquePost, punto::Int)
    P = A.pd.P
    desc = Tuple{Int,Transicion.Err}[]
    if S.fase == Transicion.FasePoW
        S.fase = Transicion.FasePoST
        S.s0 = 0
    end
    Transicion.promover!(S, punto, true)

    ncb = 0
    icb = 0
    for (i, tx) in enumerate(b.txs)
        if tx.tipo == Transicion.TxCoinbase || tx.tipo == Transicion.TxCoinbasePost
            ncb += 1
            icb = i
        end
    end
    declared = ncb == 1 ? b.txs[icb].importe : UInt64(0)
    tarifas = Int128(0)
    for (i, tx) in enumerate(b.txs)
        i == icb && continue
        if tx.tipo == Transicion.TxTransferencia
            if isempty(tx.entradas)          # R-9
                push!(desc, (i, Transicion.ErrEmision)); continue
            end
            if isempty(tx.salidas)           # R-9
                push!(desc, (i, Transicion.ErrSaldo)); continue
            end
            ve = Int128(0)
            falta = false
            for id in tx.entradas
                o = get(S.utxo, id, nothing)
                if o === nothing
                    falta = true; break
                end
                ve += Int128(o.valor)
            end
            if falta
                push!(desc, (i, Transicion.ErrDobleGasto)); continue
            end
            vs = Int128(0)
            for s in tx.salidas
                vs += Int128(s.valor)
            end
            if vs > ve                      # R-3
                push!(desc, (i, Transicion.ErrSaldo)); continue
            end
            S2 = Transicion.clonar(S)
            r = Transicion.aplicar_transferencia!(S2, P, punto, tx)
            if r isa Transicion.Err
                push!(desc, (i, r))
            else
                tarifas += ve - vs
                S = S2
            end
        else
            S2 = Transicion.clonar(S)
            r = Transicion.aplicar_tx!(S2, bloque_sintetico(b, punto), P, punto, tx)
            if r isa Transicion.Err
                push!(desc, (i, r))
            else
                S = S2
            end
        end
    end
    sub = Int128(Transicion.subsidio_post(b.slot, P))
    if ncb == 1
        credito = UInt64(min(Int128(declared), sub + tarifas))
        g = Transicion.obtener_garantia!(S, b.productor)
        madura = punto + P.M_rec_slots
        if madura <= punto
            r = Transicion.add_activo!(g, credito)
            r isa Transicion.Err && push!(desc, (icb, r))
        else
            push!(g.creditos, Transicion.Pendiente(credito, -1, madura))
        end
        S.emitido += Int128(credito) - tarifas
    else
        S.emitido += -tarifas
    end
    S.subsidio_acum += sub
    S.slot = punto
    S.bloque_raiz = b.id
    return S, desc
end

"Undo por copia íntegra (como T01): devuelve `(E2, E)` con `E2` el estado tras fusionar `b`."
function aplicar_fusion_con_undo(A::Admision, E::Transicion.Estado, b::BloquePost, punto::Int)
    E2 = Transicion.clonar(E)
    S, _ = aplicar_bloque_fusion!(A, E2, b, punto)
    S.peso_sufijo += b.peso
    return (S, E)
end

# ---------------------------------------------------------------------------
# Estado del pasado (ED-2) e incorporación de un bloque
# ---------------------------------------------------------------------------

"""
`Estado(past(b))` para el bloque ya coloreado por GDR en el índice `gi`:
parte de `post[sp(b)]` (o `Estado(T)` si `sp(b)=T`) y aplica en orden C-GD-05 los
bloques de `mergeset(b) \\ {sp(b)}` que no son `rojo_U3`, todos en fusión con punto
`slot(b)`. `b` **no** se aplica. Devuelve `(estado, error_o_nothing)`.
"""
function estado_past!(A::Admision, b::BloquePost, gi::Int)
    gd = A.gdr.gd[gi]
    sp_g = gd.sp
    if sp_g == 1
        base = Transicion.clonar(A.estado_T)
    else
        sp_id = A.id_g[sp_g]
        base = Transicion.clonar(A.post[sp_id])
    end
    for xg in gd.ms_ordenado
        x_id = A.id_g[xg]
        xb = A.por_id[x_id]
        get(gd.tipos, xg, 0x00) == 0x02 && continue     # rojo_U3 inerte
        if b.slot - xb.slot > A.pd.P.F_slots            # merge_depth (AMBIGUEDAD-5)
            return base, :ErrMergeDepth
        end
        base, _ = aplicar_bloque_fusion!(A, base, xb, b.slot)
    end
    return base, nothing
end

"""
Procesa un bloque PoST `b` (sus padres ya deben estar procesados o ser `T`).
Devuelve `:OK` o el símbolo de error de bloque. Registra `b` en `A.por_id`.
"""
function procesar_uno!(A::Admision, b::BloquePost)
    A.por_id[b.id] = b
    m = chequear_forma(A, b)
    m !== nothing && return marcar_invalido!(A, b, m)

    padres_g = Int[]
    for p in b.padres
        push!(padres_g, p == A._id_T ? 1 : A.gidx[p])
    end
    gi = A.gdr.n + 1
    ok = GDR.anadir!(A.gdr, A.gparams, texto_id(b.id, A._id_T), padres_g,
                     UInt64(b.slot), b.sd, b.sr, b.ident)
    if !ok
        return marcar_invalido!(A, b, mapear_motivo_gdr(A.gdr.motivo[end]))
    end
    A.gidx[b.id] = gi
    push!(A.id_g, b.id)

    base, err = estado_past!(A, b, gi)
    if err !== nothing
        A.validos[b.id] = false
        A.motivos[b.id] = err
        push!(A.procesados, b.id)
        return err
    end

    # garantía del productor sobre Estado(past(b)) promovido en slot(b) (TRN-07)
    Sg = Transicion.clonar(base)
    if Sg.fase == Transicion.FasePoW
        Sg.fase = Transicion.FasePoST
        Sg.s0 = 0
    end
    Transicion.promover!(Sg, b.slot, true)
    g = get(Sg.garantias, b.productor, nothing)
    activo = g === nothing ? UInt64(0) : g.activo
    if activo < UInt64(A.pd.P.q)
        A.validos[b.id] = false
        A.motivos[b.id] = :ErrGarantia
        push!(A.procesados, b.id)
        return :ErrGarantia
    end

    A.past[b.id] = base
    S, desc = aplicar_bloque_fusion!(A, Transicion.clonar(base), b, b.slot)
    S.peso_sufijo += b.peso
    A.post[b.id] = S
    A.descartes[b.id] = desc
    A.validos[b.id] = true
    push!(A.procesados, b.id)
    push!(A.orden, b.id)
    return :OK
end

# ---------------------------------------------------------------------------
# Resolución de un conjunto de bloques en orden de llegada arbitrario
# ---------------------------------------------------------------------------

"¿Están listos los padres de `b` (o son desconocidos ⇒ se puede rechazar ya)?"
function padres_listos(A::Admision, b::BloquePost)
    for p in b.padres
        p == A._id_T && continue
        if !haskey(A.por_id, p)
            return true     # padre desconocido: se rechaza ya como ErrSinPadre
        end
        p in A.procesados || return false
    end
    return true
end

"""
Procesa `bloques` en el orden de llegada `llegada` (permutación de índices de
`bloques`), respetando que un bloque solo se procesa cuando sus padres están
procesados; los no listos se reintentan después. Devuelve `A`.
"""
function resolver!(A::Admision, bloques::Vector{BloquePost}; llegada::Vector{Int} = collect(1:length(bloques)))
    for b in bloques
        haskey(A.por_id, b.id) || (A.por_id[b.id] = b)
    end
    pendientes = collect(llegada)
    while !isempty(pendientes)
        quedan = Int[]
        progreso = false
        for j in pendientes
            b = bloques[j]
            b.id in A.procesados && continue
            if padres_listos(A, b)
                procesar_uno!(A, b)
                progreso = true
            else
                push!(quedan, j)
            end
        end
        pendientes = quedan
        progreso || error("DAG no resoluble (ciclo o padre ausente no rechazable)")
    end
    return A
end

"Resuelve todos los bloques en su orden natural."
admite_todo(A::Admision, bloques::Vector{BloquePost}) = resolver!(A, bloques)

# ---------------------------------------------------------------------------
# Puntas, cadena seleccionada y estado virtual (ED-3)
# ---------------------------------------------------------------------------

"Bloques PoST válidos sin hijo válido (puntas del DAG admitido)."
function tips_validas(A::Admision)
    con_hijo = Set{Int}()
    for (id, b) in A.por_id
        get(A.validos, id, false) || continue
        for p in b.padres
            p == A._id_T && continue
            get(A.validos, p, false) && push!(con_hijo, p)
        end
    end
    return [id for (id, b) in A.por_id
            if get(A.validos, id, false) && !(id in con_hijo)]
end

"Mejor punta por la regla C (mayor blue_work; menor sd; menor id)."
function mejor_punta(A::Admision, tips::Vector{Int})
    isempty(tips) && return A._id_T
    gtips = [A.gidx[t] for t in tips]
    return A.id_g[GDR.seleccionar_sp_ref(A.gdr, A.gparams, gtips)]
end

"Camina `sp` desde `spg` hasta la raíz (índices GDR, incluye 1=T). No usa `validacion.jl`."
function cadena_gdr(gdr::GDR.EstadoReferencia, spg::Int)
    ch = Int[]
    cur = spg
    while cur != 0
        push!(ch, cur)
        cur = gdr.gd[cur].sp
    end
    reverse!(ch)
    return ch
end
cadena_gdr(A::Admision, spg::Int) = cadena_gdr(A.gdr, spg)

"Cadena seleccionada (ids de PoST, empezando por el primer bloque PoST) desde la virtual."
function cadena_virtual(A::Admision)
    tips = tips_validas(A)
    isempty(tips) && return Int[]
    sp_id = mejor_punta(A, tips)
    ch = cadena_gdr(A, A.gidx[sp_id])
    return [A.id_g[g] for g in ch if g != 1]
end

"Puntas no seleccionadas, en orden C-GD-05."
function otras_puntas(A::Admision, tips::Vector{Int}, sp_id::Int)
    otros = [t for t in tips if t != sp_id]
    sort!(otros; lt = (a, b) -> GDR.cmp_orden(A.gdr, A.gidx[a], A.gidx[b]) < 0)
    return otros
end

"""
Bloque virtual V: se clona el estado GDR y se añade V con todos los padres = puntas
para que GDR coloree su mergeset completo (ED-2/ED-3). Devuelve `(gdr2, gV, tips)`
o `(nothing, 0, tips)` si no hay puntas.
"""
function _virtual_gdr(A::Admision)
    tips = tips_validas(A)
    isempty(tips) && return (nothing, 0, tips)
    gtips = [A.gidx[t] for t in tips]
    gdr2 = deepcopy(A.gdr)
    punto = maximum(A.por_id[t].slot for t in tips)
    # V puede tener más padres que `max_parents`; no es un bloque real.
    gp = GDR.Params(k = A.gparams.k, max_parents = typemax(UInt32),
                    mergeset_limit = typemax(UInt32), s_max = typemax(UInt64),
                    u2 = false, u3_mode = A.gparams.u3_mode,
                    sp_mode = A.gparams.sp_mode, merge_mode = A.gparams.merge_mode)
    ok = GDR.anadir!(gdr2, gp, "V", gtips, UInt64(punto), UInt64(0), UInt64(0), UInt64(0))
    ok || error("no se pudo añadir el bloque virtual: $(gdr2.motivo[end])")
    return (gdr2, gdr2.n, tips)
end

"`slot(V)` = max slot(puntas) (AMBIGUEDAD-6)."
slot_virtual(A::Admision, tips::Vector{Int}) = maximum(A.por_id[t].slot for t in tips)

"""
`Estado(past(V))` (ED-3): V tiene por padres las puntas válidas. Su mergeset
completo (no solo las puntas) se aplica en orden C-GD-05, saltando `rojo_U3`, con
punto `slot(V) = max slot(puntas)` (AMBIGUEDAD-6). Devuelve `(estado, aplicados,
descartes)`.
"""
function estado_virtual(A::Admision)
    gdr2, gV, tips = _virtual_gdr(A)
    gdr2 === nothing && return (Transicion.clonar(A.estado_T), Int[],
                                Tuple{Int,Int,Transicion.Err}[])
    sp_g = gdr2.gd[gV].sp
    punto = slot_virtual(A, tips)
    S = sp_g == 1 ? Transicion.clonar(A.estado_T) :
                    Transicion.clonar(A.post[A.id_g[sp_g]])
    aplicados = Int[]
    desc = Tuple{Int,Int,Transicion.Err}[]
    for xg in gdr2.gd[gV].ms_ordenado
        get(gdr2.gd[gV].tipos, xg, 0x00) == 0x02 && continue
        x_id = A.id_g[xg]
        xb = A.por_id[x_id]
        S, d = aplicar_bloque_fusion!(A, S, xb, punto)
        push!(aplicados, x_id)
        for (i, e) in d
            push!(desc, (x_id, i, e))
        end
    end
    return (S, aplicados, desc)
end

"Bloques `rojo_U3` inertes en la historia seleccionada (ni coinbase ni transacciones)."
function u3_virtual(A::Admision)
    gdr2, gV, tips = _virtual_gdr(A)
    gdr2 === nothing && return Set{Int}()
    s = Set{Int}()
    for g in cadena_gdr(gdr2, gdr2.gd[gV].sp)
        g == 1 && continue
        gd = gdr2.gd[g]
        for xg in gd.ms_ordenado
            get(gd.tipos, xg, 0x00) == 0x02 && push!(s, A.id_g[xg])
        end
    end
    for xg in gdr2.gd[gV].ms_ordenado
        get(gdr2.gd[gV].tipos, xg, 0x00) == 0x02 && push!(s, A.id_g[xg])
    end
    return s
end

"Descartes de la aplicación virtual (por bloque aplicado)."
descartes_virtual(A::Admision) = estado_virtual(A)[3]

"""
Recomputa desde `Estado(T)` la historia seleccionada completa (R-FIN-8′(4)):
por cada bloque de cadena `C`, su mergeset (sin `rojo_U3`) a `slot(C)`, luego `C`;
al final el mergeset de `V` a `slot(V)`. Devuelve `(estado, orden, descartes)`,
donde `descartes` es `(idBloque, índiceTx, Err)`. Es la fuente del exportador.
"""
function aplicar_historia(A::Admision)
    gdr2, gV, tips = _virtual_gdr(A)
    gdr2 === nothing && return (Transicion.clonar(A.estado_T), Int[],
                                Tuple{Int,Int,Transicion.Err}[])
    S = Transicion.clonar(A.estado_T)
    orden = Int[]
    desc = Tuple{Int,Int,Transicion.Err}[]
    for g in cadena_gdr(gdr2, gdr2.gd[gV].sp)
        g == 1 && continue
        C = A.por_id[A.id_g[g]]
        gd = gdr2.gd[g]
        for xg in gd.ms_ordenado
            get(gd.tipos, xg, 0x00) == 0x02 && continue
            X = A.por_id[A.id_g[xg]]
            S, d = aplicar_bloque_fusion!(A, S, X, C.slot)
            push!(orden, X.id)
            for (i, e) in d
                push!(desc, (X.id, i, e))
            end
        end
        S, d = aplicar_bloque_fusion!(A, S, C, C.slot)
        S.peso_sufijo += C.peso
        push!(orden, C.id)
        for (i, e) in d
            push!(desc, (C.id, i, e))
        end
    end
    punto = slot_virtual(A, tips)
    for xg in gdr2.gd[gV].ms_ordenado
        get(gdr2.gd[gV].tipos, xg, 0x00) == 0x02 && continue
        X = A.por_id[A.id_g[xg]]
        S, d = aplicar_bloque_fusion!(A, S, X, punto)
        push!(orden, X.id)
        for (i, e) in d
            push!(desc, (X.id, i, e))
        end
    end
    return (S, orden, desc)
end

"""
Orden de aplicación de la historia seleccionada (R-FIN-8′(4)): por cada bloque de
cadena `C`, su mergeset (sin `rojo_U3`) y luego `C`; al final el mergeset completo
de V. Sirve para IE-2 (cada bloque aplicado una sola vez).
"""
function orden_aplicacion_virtual(A::Admision)
    gdr2, gV, tips = _virtual_gdr(A)
    gdr2 === nothing && return Int[]
    orden = Int[]
    ch = cadena_gdr(gdr2, gdr2.gd[gV].sp)
    for g in ch
        g == 1 && continue
        gd = gdr2.gd[g]
        for xg in gd.ms_ordenado
            get(gd.tipos, xg, 0x00) == 0x02 && continue
            push!(orden, A.id_g[xg])
        end
        push!(orden, A.id_g[g])
    end
    for xg in gdr2.gd[gV].ms_ordenado
        get(gdr2.gd[gV].tipos, xg, 0x00) == 0x02 && continue
        push!(orden, A.id_g[xg])
    end
    return orden
end

estado_past(A::Admision, id::Integer) = A.past[Int(id)]
estado_post(A::Admision, id::Integer) = A.post[Int(id)]

# ---------------------------------------------------------------------------
# Re-export de utilidades de representación de T01
# ---------------------------------------------------------------------------

representacion_canonica(E::Transicion.Estado) = Transicion.representacion_canonica(E)
hash_canonico(E::Transicion.Estado) = Transicion.hash_canonico(E)
invariante_I1(E::Transicion.Estado) = Transicion.invariante_I1(E)
invariante_I1b(E::Transicion.Estado) = Transicion.invariante_I1b(E)

# ---------------------------------------------------------------------------
# Rejilla T04 (subconjunto declarado de la rejilla reducida de T01)
# ---------------------------------------------------------------------------

"""
Subconjunto declarado de la rejilla de T01 (ORDEN-T04 §3.4): `SEC0`,
`CUT_HWPhi`, `FC3`, `M_rec_slots ≥ 1` (AMBIGUEDAD-7) y `F_slots ∈ {2, ∞}`.
Cinco puntos × `k ∈ {0,1,3}`.
"""
const PARAMS_DAG_BASE = [
    Transicion.Params(H_dep = 1, M_cb = 1, M_dep = 0, H_corte_min = 2, W_min = 1,
                      S_min = 1, K_min = 1, q = 1, M_res_slots = 1, M_dep_slots = 1,
                      M_rec_slots = 1, R_slots = 1, F_slots = 2, sec = Transicion.SEC0,
                      corte = Transicion.CUT_HWPhi, seleccion = Transicion.FC3),
    Transicion.Params(H_dep = 1, M_cb = 1, M_dep = 0, H_corte_min = 2, W_min = 1,
                      S_min = 1, K_min = 1, q = 1, M_res_slots = 1, M_dep_slots = 1,
                      M_rec_slots = 2, R_slots = 2, F_slots = typemax(Int),
                      sec = Transicion.SEC0, corte = Transicion.CUT_HWPhi,
                      seleccion = Transicion.FC3),
    Transicion.Params(H_dep = 1, M_cb = 2, M_dep = 1, H_corte_min = 3, W_min = 2,
                      S_min = 5, K_min = 1, q = 2, M_res_slots = 2, M_dep_slots = 1,
                      M_rec_slots = 1, R_slots = 1, F_slots = 2, sec = Transicion.SEC0,
                      corte = Transicion.CUT_HWPhi, seleccion = Transicion.FC3),
    Transicion.Params(H_dep = 2, M_cb = 1, M_dep = 0, H_corte_min = 3, W_min = 1,
                      S_min = 1, K_min = 1, q = 1, M_res_slots = 1, M_dep_slots = 2,
                      M_rec_slots = 1, R_slots = 3, F_slots = typemax(Int),
                      sec = Transicion.SEC0, corte = Transicion.CUT_HWPhi,
                      seleccion = Transicion.FC3),
    Transicion.Params(H_dep = 1, M_cb = 1, M_dep = 1, H_corte_min = 3, W_min = 3,
                      S_min = 2, K_min = 1, q = 1, M_res_slots = 1, M_dep_slots = 1,
                      M_rec_slots = 2, R_slots = 2, F_slots = 2, sec = Transicion.SEC0,
                      corte = Transicion.CUT_HWPhi, seleccion = Transicion.FC3),
]

"`(punto, k)` de la rejilla T04: 5 puntos × k ∈ {0,1,3}."
const PUNTOS_T04 = [(p, k) for p in 1:length(PARAMS_DAG_BASE) for k in (0, 1, 3)]

include("generadores.jl")
include("dirigidos.jl")
include("revalidacion_gdr.jl")
include("propiedades.jl")

export casos_dirigidos, utxo_gastable, base_dirigida
export revalidar_corpus, revalidar_kaspa, texto_id32, leer_json
export verificar_ie1_ie2_ie4, verificar_ie3, verificar_ie5, verificar_ie6

end # module EstadoDAG
