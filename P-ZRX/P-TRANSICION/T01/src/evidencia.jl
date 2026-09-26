# SL-3 · Generadores de historias con `EvidenceTx` (T01).
#
# Construye historias PoST válidas sobre el terminal con garantía de la clave 1
# y les inyecta `EvidenceTx` de los seis tipos exigidos por la orden §2.5:
# aplicada, duplicada, fuera de plazo, `cbid` ajeno, contra clave sin saldo y
# deshecha (por undo exacto). Además el caso dirigido de la carrera de RAT-3 y
# el de autodenuncia. Todo es determinista con `StableRNG`.

# Prefijo PoST válido: PoW hasta el terminal + `n_post` bloques PoST del
# productor 1. Devuelve `(bloques, estados)`.
function _prefijo_ev(rng::AbstractRNG, P::Params; n_post::Int = 2)
    t = construir_poW(rng, P; hasta = 10, depositar = true, transferir = false)
    bloques, estados = t[1], t[2]
    E = estados[end]
    E.terminal == -1 && return bloques, estados
    parent = bloques[end].id
    slot = 0
    for _ in 1:n_post
        slot += 1
        B = gen_post(id = parent + 1, padre = parent, slot = slot, productor = 1,
                     peso = 1, txs = [tx_coinbase_post(3)])
        r = aplicar(E, B, P)
        r isa Err && break
        E = r
        push!(bloques, B)
        push!(estados, E)
        parent = B.id
    end
    return bloques, estados
end

# Bloque PoST con la evidencia `ev` (más la coinbase PoST). Devuelve
# `(bloque, resultado)`; el resultado puede ser `Err` (el bloque queda en la
# historia para que el vector registre su `RES`).
function _bloque_con_ev(P::Params, E::Estado, parent::Int, slot::Int, ev::Evidencia;
                        productor::Int = 1, extra::Vector{Tx} = Tx[])
    txs = Tx[tx_coinbase_post(3)]
    append!(txs, extra)
    push!(txs, tx_evidencia(ev))
    B = gen_post(id = parent + 1, padre = parent, slot = slot, productor = productor,
                 peso = 1, txs = txs)
    return B, aplicar(E, B, P)
end

# Caso de cobertura `tipo ∈ (:aplicada,:duplicada,:tardia,:cbid,:sin_saldo,
# :con_entradas,:orden,:orden_igual,:ambos)` para el índice `idx` (varía
# `pre_hash`, clave y rama base). SL-4c-O: `:cbid` y `:orden` son defectos de
# **forma**; `:ambos` lleva los dos y debe devolver `EvidenciaCbidAjeno`
# (precedencia). SL-4c-O-B añade `:orden_igual` (`H1 = H2`), el otro tipo de
# orden no canónico, además del descendente `:orden`. SL-4c-O-C: `:con_entradas`
# también es **forma** (`EvidenciaConEntradasOSalidas`) y precede a `cbid`/orden.
function _caso_evidencia(P::Params, tipo::Symbol, idx::Int)
    rng = StableRNG(0x5100 + UInt64(idx) * 17 + UInt64(hash(tipo) & 0xffff))
    bloques, estados = _prefijo_ev(rng, P; n_post = 1 + (idx % 3))
    E = estados[end]
    parent = bloques[end].id
    ph1 = UInt64(1000 + 2 * idx)
    ph2 = UInt64(1001 + 2 * idx)
    s = E.slot + 1
    key = 1
    cbid = P.cbid
    sf = s
    if tipo == :tardia
        s = max(s, P.Plazo_slots)
        sf = s - P.Plazo_slots            # ventana cerrada al aplicar
    elseif tipo == :cbid
        cbid = P.cbid + 1
    elseif tipo == :orden
        ph1, ph2 = ph2, ph1               # no canónico (descendente)
    elseif tipo == :orden_igual
        ph2 = ph1                         # no canónico por igualdad (H1 = H2)
    elseif tipo == :ambos
        cbid = P.cbid + 1
        ph1, ph2 = ph2, ph1               # cbid ajeno + orden no canónico
    elseif tipo == :sin_saldo
        key = 99
    end
    ev = evidencia(cbid, key, 0, 0, 0, sf, ph1, ph2)
    B1, r1 = _bloque_con_ev(P, E, parent, s, ev)
    if tipo == :duplicada
        push!(bloques, B1)
        if !(r1 isa Err)
            B2, r2 = _bloque_con_ev(P, r1, B1.id, s + 1, ev)
            push!(bloques, B2)
            return (string("ev-", tipo), bloques)
        end
        return (string("ev-", tipo), bloques)
    elseif tipo == :con_entradas
        # EV-04 (SL-4c-O-C): EvidenceTx con salidas monetarias ⇒ forma
        # `ErrForma(EvidenciaConEntradasOSalidas)`, la primera de la precedencia.
        txs = Tx[tx_coinbase_post(3),
                 Tx(TxEvidencia, [Salida(900777, UInt64(1), key, OrigenTx, -1, -1)],
                    Int[], 0, key, UInt64(0), 0, UInt64(0), ev)]
        B = gen_post(id = parent + 1, padre = parent, slot = s, productor = 1,
                     peso = 1, txs = txs)
        push!(bloques, B)
        return (string("ev-", tipo), bloques)
    end
    push!(bloques, B1)
    return (string("ev-", tipo), bloques)
end

"Casos de cobertura de evidencia (≥ `n` por tipo) para el punto `P`."
function casos_evidencia_cobertura(P::Params; n::Int = 40)
    out = Tuple{String,Vector{Bloque}}[]
    for idx in 1:n
        for tipo in (:aplicada, :duplicada, :tardia, :cbid, :sin_saldo,
                     :con_entradas, :orden, :orden_igual, :ambos)
            nombre, bl = _caso_evidencia(P, tipo, idx)
            push!(out, (nombre, bl))
        end
    end
    return out
end

# SL-4c-O-B: dos `EvidenceTx` en un mismo bloque (T01 solo tiene modo estricto:
# el bloque es inválido). La primera transacción defectuosa manda, así que el
# defecto de la **primera** evidencia fija el motivo. `primer ∈ (:orden, :cbid)`.
# Devuelve `(bloques, esperado)` o `nothing` si el prefijo no alcanza terminal.
function caso_dos_evidencias(P::Params, primer::Symbol)
    rng = StableRNG(0x5c00 + UInt64(primer == :orden ? 1 : 2))
    bloques, estados = _prefijo_ev(rng, P; n_post = 1)
    E = estados[end]
    E.terminal == -1 && return nothing
    parent = bloques[end].id
    s = E.slot + 1
    ok1, ok2 = UInt64(6001), UInt64(6002)          # canónico (ascendente)
    mal1, mal2 = UInt64(7002), UInt64(7001)        # no canónico (descendente)
    if primer == :orden
        e1 = evidencia(P.cbid, 1, 0, 0, 0, s, mal1, mal2)
        e2 = evidencia(P.cbid + 1, 1, 0, 0, 0, s, ok1, ok2)
        esperado = ErrForma(OrdenCanonicoInvalido)
    elseif primer == :cbid
        e1 = evidencia(P.cbid + 1, 1, 0, 0, 0, s, ok1, ok2)
        e2 = evidencia(P.cbid, 1, 0, 0, 0, s, mal1, mal2)
        esperado = ErrForma(EvidenciaCbidAjeno)
    else
        error("primer debe ser :orden o :cbid, no $primer")
    end
    B = gen_post(id = parent + 1, padre = parent, slot = s, productor = 1,
                 peso = 1,
                 txs = [tx_coinbase_post(3), tx_evidencia(e1), tx_evidencia(e2)])
    return (vcat(bloques, [B]), esperado)
end

"Los dos casos dirigidos de dos evidencias (orden→cbid y cbid→orden) en `P`."
function casos_evidencia_dirigidos(P::Params)
    out = Tuple{String,Vector{Bloque}}[]
    c1 = caso_dos_evidencias(P, :orden)
    c1 === nothing || push!(out, ("ev-dir-orden-cbid", c1[1]))
    c2 = caso_dos_evidencias(P, :cbid)
    c2 === nothing || push!(out, ("ev-dir-cbid-orden", c2[1]))
    return out
end

"Rejilla reducida de evidencia (SL-3): `f ∈ {1/2,1}`, ventanas en slots."
function puntos_evidencia()
    out = Params[]
    for (f_num, f_den) in ((1, 2), (1, 1)), Plazo in (1, 2, 3), Mm in (0, 1)
        R = Plazo + Mm + 1
        push!(out, Params(H_dep = 1, M_cb = 1, M_dep = 0, H_corte_min = 2,
                          W_min = 1, S_min = 1, K_min = 1, q = 1,
                          M_res_slots = 1, M_dep_slots = 1, M_rec_slots = 1,
                          R_slots = R, F_slots = typemax(Int), sec = SEC0,
                          corte = CUT_HWPhi, seleccion = FC3, f_num = f_num,
                          f_den = f_den, Plazo_slots = Plazo,
                          M_margen_slots = Mm, cbid = 7, evp = true))
    end
    return out
end

"""
Carrera de RAT-3: retiro parcial en `t0`, producción continuada, doble firma en
`sf = t0 + R_slots − Plazo_slots` aplicada en `sf+1`, y liberación intentada en
`t0 + R_slots`. La condición (i) de EV-24 ya no bloquea (el incidente se poda al
abrirse la ventana), pero (ii) sí. Devuelve `(bloques, indice_ev, indice_lib)` o
`nothing` si el punto no cumple las precondiciones.
"""
function caso_rat3_carrera(P::Params)
    (P.Plazo_slots >= 2 && P.R_slots >= P.Plazo_slots) || return nothing
    rng = StableRNG(0x9a3)
    bloques, estados = _prefijo_ev(rng, P; n_post = 1)
    E = estados[end]
    g = get(E.garantias, 1, nothing)
    (g === nothing || g.activo < UInt64(P.q) + 1) && return nothing
    parent = bloques[end].id
    t0 = E.slot + 1
    # B0: retiro parcial.
    B0 = gen_post(id = parent + 1, padre = parent, slot = t0, productor = 1,
                  peso = 1,
                  txs = [tx_coinbase_post(3),
                         tx_retiro(1, 1, 1; nonce = nonce_de(E, 1))])
    E0 = aplicar(E, B0, P)
    E0 isa Err && return nothing
    push!(bloques, B0)
    # B1: producción continuada con la doble firma.
    sf = t0 + P.R_slots - P.Plazo_slots
    sa = sf + 1
    ev = evidencia(P.cbid, 1, 0, 0, 0, sf, UInt64(7001), UInt64(7002))
    B1, r1 = _bloque_con_ev(P, E0, B0.id, sa, ev)
    r1 isa Err && return nothing
    push!(bloques, B1)
    idx_ev = length(bloques)
    # B2: liberación (rechazada por EV-24(ii)).
    tr = t0 + P.R_slots
    B2 = gen_post(id = B1.id + 1, padre = B1.id, slot = tr, productor = 1, peso = 1,
                  txs = [tx_coinbase_post(3),
                         tx_liberacion(1, 1, 1; nonce = nonce_de(r1, 1))])
    push!(bloques, B2)
    idx_lib = length(bloques)
    return (bloques, idx_ev, idx_lib)
end

"Historia de autodenuncia: el productor del bloque que aplica es el infractor."
function caso_autodenuncia(P::Params; idx::Int = 1)
    rng = StableRNG(0x9b00 + UInt64(idx))
    bloques, estados = _prefijo_ev(rng, P; n_post = 1)
    E = estados[end]
    parent = bloques[end].id
    s = E.slot + 1
    ev = evidencia(P.cbid, 1, 0, 0, 0, s, UInt64(8001 + idx), UInt64(9001 + idx))
    B, r = _bloque_con_ev(P, E, parent, s, ev; productor = 1)
    push!(bloques, B)
    return (bloques, r)
end
