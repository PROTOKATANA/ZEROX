# generadores_negativos.jl — T01-C: casos negativos de TRANSACCIÓN.
#
# ORDEN-T01-C §3.2. Solo construye bloques de rechazo sobre estados VÁLIDOS de
# T01; no cambia la semántica de `Transicion.jl`/`seleccion.jl`/`nodo.jl`. Cada
# caso lleva el error esperado escrito a mano (`esperado`) y lo confirma el
# oráculo en `exportar_negativos.jl` antes de escribirlo.
#
# Familias cubiertas (≥ 30 casos en el fichero, en PoW y PoST cuando aplica):
#   ErrSaldo, ErrDobleGasto, ErrRetiroPendiente, ErrAutorizacion, ErrInmaduro,
#   ErrEmision, ErrOperacionFase, ErrGarantia.

# ---------------------------------------------------------------------------
# Caso negativo
# ---------------------------------------------------------------------------

struct CasoNegativo
    nombre::String
    esperado::Err
    fase::String        # "PoW" | "PoST"
    familia::String     # agrupación de la orden
    bloques::Vector{Bloque}
end

# ---------------------------------------------------------------------------
# Utilidades sobre estados válidos
# ---------------------------------------------------------------------------

salida_neg(id::Integer, valor::Integer, dueño::Integer) =
    Salida(Int(id), UInt64(valor), Int(dueño), OrigenTx, -1, -1)

activo_de(E::Estado, k::Int) =
    haskey(E.garantias, k) ? E.garantias[k].activo : UInt64(0)

fase_bloque(B::Bloque) = B.familia == PoST ? FasePoST : FasePoW

# Punto (altura PoW o slot PoST) del bloque negativo que se construirá sobre Ep.
punto_bloque_neg(Ep::Estado, B::Bloque) =
    B.familia == PoW ? Ep.altura + 1 :
    (Ep.fase == FasePoW ? max(Ep.slot + 1, 1) : Ep.slot + 1)

gastable_punto(Ep::Estado, o::Salida, P::Params, fase::Fase, punto::Int) =
    gastable_en(o, fase, Ep.altura_terminal, Ep.s0, P, punto)

function gastables_punto(Ep::Estado, P::Params, fase::Fase, punto::Int)
    os = Salida[]
    for (_, o) in Ep.utxo
        gastable_punto(Ep, o, P, fase, punto) && push!(os, o)
    end
    return sort(os, by = o -> o.id)
end

function inmaduros_punto(Ep::Estado, P::Params, fase::Fase, punto::Int)
    os = Salida[]
    for (_, o) in Ep.utxo
        o.origen == OrigenCoinbasePow || continue
        gastable_punto(Ep, o, P, fase, punto) || push!(os, o)
    end
    return sort(os, by = o -> o.id)
end

function ids_gastados(pref::Vector{Bloque})
    s = Set{Int}()
    for b in pref, tx in b.txs, e in tx.entradas
        push!(s, e)
    end
    return s
end

# Estado del padre tras la promoción de pendientes en el punto del bloque
# (paso (b) de `aplicar_pow!`/`aplicar_post!`, antes de las transacciones).
function estado_promovido(Ep::Estado, P::Params, fase::Fase, punto::Int)
    E2 = clonar(Ep)
    promover!(E2, punto, fase == FasePoST)
    return E2
end

# Importe ya vencido (liberable) de la clave `g` en `slot`.
function vencido_de(E::Estado, g::Int, slot::Int, P::Params)
    haskey(E.garantias, g) || return UInt64(0)
    v = Int128(0)
    for r in E.garantias[g].en_retirada
        r.inicio_slot + P.R_slots <= slot && (v += Int128(r.importe))
    end
    return v
end

# Construye el bloque negativo sobre el padre `last(pref)` con estado `Ep`.
function bloque_neg(P::Params, pref::Vector{Bloque}, Ep::Estado, Bk::Bloque,
                    txs::Vector{Tx}; productor::Int = 1, peso::Int = 1)
    tip = last(pref).id
    if Bk.familia == PoW
        return gen_pow(id = tip + 1, padre = tip, altura = Ep.altura + 1,
                       txs = txs, trabajo = 1, pow_ok = true)
    else
        slot = Ep.fase == FasePoW ? max(Ep.slot + 1, 1) : Ep.slot + 1
        return gen_post(id = tip + 1, padre = tip, slot = slot,
                        productor = productor, peso = peso, sector = 0, txs = txs)
    end
end

# ---------------------------------------------------------------------------
# Recetas sobre un bloque base (su padre ya es un estado válido)
# ---------------------------------------------------------------------------

function casos_bloque(P::Params, pref::Vector{Bloque}, Ep::Estado, Bk::Bloque)
    casos = CasoNegativo[]
    es_pow = Bk.familia == PoW
    fase = es_pow ? "PoW" : "PoST"
    pt = punto_bloque_neg(Ep, Bk)
    faseA = fase_bloque(Bk)
    sp = gastables_punto(Ep, P, faseA, pt)
    inm = inmaduros_punto(Ep, P, faseA, pt)
    # Estado con la promoción ya aplicada: es el que ven las transacciones.
    Ef = estado_promovido(Ep, P, faseA, pt)
    gkeys = sort(collect(keys(Ef.garantias)))
    gastados = sort(collect(ids_gastados(pref)))
    oid = Ref(900000 + 37 * last(pref).id)
    nuevo() = (oid[] += 1; oid[])
    cb() = es_pow ? tx_coinbase([salida_neg(nuevo(), 10, 1)]) : tx_coinbase_post(3)
    prod_ok = activo_de(Ef, 1) >= UInt64(P.q)

    agrega(nombre, familia, esperado, txs; productor = 1, peso = 1) = begin
        B = bloque_neg(P, pref, Ep, Bk, txs; productor = productor, peso = peso)
        push!(casos, CasoNegativo(nombre, esperado, fase, familia,
                                  vcat(pref, [B])))
    end

    # Si un bloque PoST no tiene productor válido, el oráculo daría ErrGarantia
    # antes de tocar las transacciones: esas recetas no aplican.
    aplica_tx = es_pow || prod_ok

    # ===== ErrEmision (R-6, R-7, R-9) ==================================
    if es_pow
        # R-7: coinbase PoW sin salidas.
        agrega("neg-emision-r7-coinbase-vacia", "Emision", ErrEmision,
               [tx_coinbase(Salida[])])
    end
    if aplica_tx
        # R-6: la única coinbase no ocupa la primera posición.
        prim = isempty(sp) ?
               tx_transferencia(Int[], [salida_neg(nuevo(), 1, 1)], 1) :
               tx_transferencia([sp[1].id],
                                [salida_neg(nuevo(), 1, sp[1].dueño)],
                                sp[1].dueño)
        cbx = es_pow ? tx_coinbase([salida_neg(nuevo(), 10, 1)]) :
                       tx_coinbase_post(3)
        agrega("neg-emision-r6-coinbase-no-primera", "Emision", ErrEmision,
               [prim, cbx])
        # R-9: transferencia sin entradas.
        agrega("neg-emision-r9-transfer-sin-entradas", "Emision", ErrEmision,
               [cb(), tx_transferencia(Int[], [salida_neg(nuevo(), 1, 1)], 1)])
    end
    if !aplica_tx
        return casos
    end

    # ===== ErrSaldo =====================================================
    for o in Iterators.take(sp, 2)
        # Transferencia que crea valor (Σ salidas > Σ entradas).
        agrega("neg-saldo-transfer-crea-valor", "Saldo", ErrSaldo,
               [cb(), tx_transferencia([o.id],
                        [salida_neg(nuevo(), Int(o.valor) + 1, o.dueño)],
                        o.dueño)])
        # Transferencia con entradas y sin salidas (R-9).
        agrega("neg-saldo-transfer-sin-salidas", "Saldo", ErrSaldo,
               [cb(), tx_transferencia([o.id], Salida[], o.dueño)])
    end
    # Depósito que no cuadra (Σ entradas ≠ importe).
    if !es_pow || pt >= P.H_dep
        for o in Iterators.take(sp, 2)
            agrega("neg-saldo-deposito-descuadra", "Saldo", ErrSaldo,
                   [cb(), tx_deposito([o.id], o.dueño, Int(o.valor) + 1,
                                      o.dueño)])
        end
    end
    # Retiro mayor que el activo.
    for g in Iterators.take(gkeys, 2)
        agrega("neg-saldo-retiro-mayor-activo", "Saldo", ErrSaldo,
               [cb(), tx_retiro(g, Int(activo_de(Ef, g)) + 1, g)])
    end
    # Liberación mayor que lo vencido (solo PoST).
    if !es_pow
        for g in Iterators.take(gkeys, 2)
            v = Int(vencido_de(Ef, g, pt, P))
            agrega("neg-saldo-liberacion-mayor-vencido", "Saldo", ErrSaldo,
                   [cb(), tx_liberacion(g, v + 1, g)])
        end
        # R-8: importe 0 en CoinbasePost / Liberacion.
        agrega("neg-saldo-r8-coinbasepost-cero", "Saldo", ErrSaldo,
               [tx_coinbase_post(0)])
        agrega("neg-saldo-r8-liberacion-cero", "Saldo", ErrSaldo,
               [cb(), tx_liberacion(1, 0, 1)])
        # Liberación antes de R_slots: retiro en el mismo bloque y liberación.
        for g in Iterators.take(gkeys, 2)
            if isempty(Ef.garantias[g].en_retirada) &&
               activo_de(Ef, g) >= UInt64(2)
                agrega("neg-saldo-liberacion-antes-R", "Saldo", ErrSaldo,
                       [cb(), tx_retiro(g, 1, g), tx_liberacion(g, 1, g)])
            end
        end
    end
    # R-8: importe 0 en Deposito y Retiro.
    agrega("neg-saldo-r8-deposito-cero", "Saldo", ErrSaldo,
           [cb(), tx_deposito(Int[], 1, 0, 1)])
    agrega("neg-saldo-r8-retiro-cero", "Saldo", ErrSaldo,
           [cb(), tx_retiro(1, 0, 1)])

    # ===== ErrDobleGasto ===============================================
    for o in Iterators.take(sp, 2)
        # Misma entrada dos veces en una transacción.
        agrega("neg-doblegasto-entrada-duplicada-tx", "DobleGasto",
               ErrDobleGasto,
               [cb(), tx_transferencia([o.id, o.id],
                        [salida_neg(nuevo(), Int(o.valor), o.dueño)],
                        o.dueño)])
        # Misma entrada en dos transacciones del mismo bloque.
        agrega("neg-doblegasto-entrada-dos-txs", "DobleGasto", ErrDobleGasto,
               [cb(),
                tx_transferencia([o.id], [salida_neg(nuevo(), 1, o.dueño)],
                                 o.dueño),
                tx_transferencia([o.id], [salida_neg(nuevo(), 1, o.dueño)],
                                 o.dueño)])
    end
    # Gasto de una salida ya gastada.
    for id in Iterators.take(gastados, 2)
        haskey(Ep.utxo, id) && continue
        agrega("neg-doblegasto-salida-ya-gastada", "DobleGasto", ErrDobleGasto,
               [cb(), tx_transferencia([id], [salida_neg(nuevo(), 1, 1)], 1)])
        if !es_pow || pt >= P.H_dep
            agrega("neg-doblegasto-deposito-salida-gastada", "DobleGasto",
                   ErrDobleGasto, [cb(), tx_deposito([id], 1, 1, 1)])
        end
    end

    # ===== ErrRetiroPendiente ==========================================
    for g in Iterators.take(gkeys, 3)
        if !isempty(Ef.garantias[g].en_retirada) &&
           activo_de(Ef, g) >= UInt64(1)
            agrega("neg-retiropendiente-segunda", "RetiroPendiente",
                   ErrRetiroPendiente, [cb(), tx_retiro(g, 1, g)])
        end
        if isempty(Ef.garantias[g].en_retirada) &&
           activo_de(Ef, g) >= UInt64(2)
            agrega("neg-retiropendiente-dos-en-bloque", "RetiroPendiente",
                   ErrRetiroPendiente,
                   [cb(), tx_retiro(g, 1, g), tx_retiro(g, 1, g)])
        end
    end

    # ===== ErrAutorizacion =============================================
    for o in Iterators.take(sp, 2)
        f2 = o.dueño == 1 ? 2 : 1
        agrega("neg-autorizacion-transfer", "Autorizacion", ErrAutorizacion,
               [cb(), tx_transferencia([o.id],
                        [salida_neg(nuevo(), Int(o.valor), o.dueño)], f2)])
    end
    agrega("neg-autorizacion-deposito", "Autorizacion", ErrAutorizacion,
           [cb(), tx_deposito(Int[], 1, 1, 2)])
    agrega("neg-autorizacion-retiro", "Autorizacion", ErrAutorizacion,
           [cb(), tx_retiro(1, 1, 2)])
    if !es_pow
        agrega("neg-autorizacion-liberacion", "Autorizacion", ErrAutorizacion,
               [cb(), tx_liberacion(1, 1, 2)])
    end

    # ===== ErrInmaduro =================================================
    if es_pow
        # Gasto de la coinbase creada en el propio bloque.
        cbid = nuevo()
        agrega("neg-inmaduro-coinbase-mismo-bloque", "Inmaduro", ErrInmaduro,
               [tx_coinbase([salida_neg(cbid, 10, 1)]),
                tx_transferencia([cbid], [salida_neg(nuevo(), 9, 1)], 1)])
        # Gasto de una coinbase inmadura del estado padre.
        for o in Iterators.take(inm, 2)
            agrega("neg-inmaduro-coinbase-inmadura-prev", "Inmaduro",
                   ErrInmaduro,
                   [cb(), tx_transferencia([o.id],
                            [salida_neg(nuevo(), 1, o.dueño)], o.dueño)])
        end
        # Depósito de la coinbase creada en el propio bloque.
        if pt >= P.H_dep
            cbid2 = nuevo()
            agrega("neg-inmaduro-deposito-mismo-bloque", "Inmaduro",
                   ErrInmaduro,
                   [tx_coinbase([salida_neg(cbid2, 10, 1)]),
                    tx_deposito([cbid2], 1, 10, 1)])
        end
    else
        # Cruce del corte: gasto antes de s_0 + M_res_slots (madurez residual).
        for o in Iterators.take(inm, 2)
            agrega("neg-inmaduro-cruce-corte", "Inmaduro", ErrInmaduro,
                   [cb(), tx_transferencia([o.id],
                            [salida_neg(nuevo(), 1, o.dueño)], o.dueño)])
        end
    end

    # ===== ErrOperacionFase (solo PoW: liberación y evidencia) =========
    if es_pow
        agrega("neg-operacionfase-liberacion", "OperacionFase",
               ErrOperacionFase, [cb(), tx_liberacion(1, 1, 1)])
        agrega("neg-operacionfase-evidencia", "OperacionFase",
               ErrOperacionFase, [cb(), tx_evidencia(1)])
        agrega("neg-operacionfase-liberacion-sola", "OperacionFase",
               ErrOperacionFase, [tx_liberacion(1, 1, 1)])
        agrega("neg-operacionfase-evidencia-sola", "OperacionFase",
               ErrOperacionFase, [tx_evidencia(1)])
    end

    return casos
end

# ---------------------------------------------------------------------------
# ErrGarantia: productores sin garantía activa (claves frescas) y
# «depósito pendiente usado para producir» (bloques previos válidos).
# ---------------------------------------------------------------------------

function casos_garantia_insuficiente(P::Params, pref::Vector{Bloque},
                                     Ep::Estado, Bk::Bloque)
    Bk.familia == PoST || return CasoNegativo[]
    out = CasoNegativo[]
    for K in (3, 4, 5, 7, 9999)
        # Clave sin garantía alguna: no puede promover nada en el bloque.
        (activo_de(Ep, K) == 0 && !haskey(Ep.garantias, K)) || continue
        B = bloque_neg(P, pref, Ep, Bk, [tx_coinbase_post(3)]; productor = K)
        push!(out, CasoNegativo("neg-garantia-sin-activo", ErrGarantia,
                                "PoST", "Garantia", vcat(pref, [B])))
    end
    return out
end

function casos_garantia_pendiente(P::Params, pref0::Vector{Bloque},
                                  Ep0::Estado, Bk0::Bloque)
    Bk0.familia == PoST || return CasoNegativo[]
    # El depósito debe seguir pendiente en el bloque negativo: si madura en el
    # acto (M_dep_slots <= 1) no hay «pendiente usado para producir».
    P.M_dep_slots >= 2 || return CasoNegativo[]
    # Clave K sin garantía (ni activa ni pendiente) en el estado del padre.
    K = 0
    for cand in (2, 3, 4, 5, 7, 9999)
        if activo_de(Ep0, cand) == 0 && !haskey(Ep0.garantias, cand) &&
           activo_de(Ep0, cand) < UInt64(P.q)
            K = cand
            break
        end
    end
    K == 0 && return CasoNegativo[]
    # Necesita una salida gastable de la clave 1 con valor >= 2.
    pto0 = punto_bloque_neg(Ep0, Bk0)
    cand = [o for o in gastables_punto(Ep0, P, fase_bloque(Bk0), pto0)
            if o.dueño == 1 && o.valor >= 2]
    isempty(cand) && return CasoNegativo[]
    o1 = cand[1]
    tip0 = last(pref0).id
    slot0 = pto0
    k1 = 930000 + 37 * tip0
    # V0: transferencia válida de 1 brek a K.
    V0 = gen_post(id = tip0 + 1, padre = tip0, slot = slot0, productor = 1,
                  peso = 1, sector = 0,
                  txs = [tx_coinbase_post(3),
                         tx_transferencia([o1.id], [salida_neg(k1, 1, K)],
                                          o1.dueño)])
    E0 = aplicar(Ep0, V0, P)
    E0 isa Err && return CasoNegativo[]
    # V1: K deposita su salida ⇒ garantía pendiente (madura en s + M_dep_slots).
    V1 = gen_post(id = V0.id + 1, padre = V0.id, slot = slot0 + 1,
                  productor = 1, peso = 1, sector = 0,
                  txs = [tx_coinbase_post(3), tx_deposito([k1], K, 1, K)])
    E1 = aplicar(E0, V1, P)
    E1 isa Err && return CasoNegativo[]
    # B: K produce con solo el pendiente ⇒ ErrGarantia.
    B = gen_post(id = V1.id + 1, padre = V1.id, slot = slot0 + 2, productor = K,
                 peso = 1, sector = 0, txs = [tx_coinbase_post(3)])
    return [CasoNegativo("neg-garantia-deposito-pendiente", ErrGarantia,
                         "PoST", "Garantia", vcat(pref0, [V0, V1, B]))]
end

# ---------------------------------------------------------------------------
# Cadena base válida por punto y recolección de casos
# ---------------------------------------------------------------------------

function cadena_base(P::Params; seed::Int, max_post::Int = 3)
    retirar = 9 >= P.H_corte_min ? P.H_corte_min : -1
    tb = construir_poW(StableRNG(seed), P; hasta = 9, depositar = true,
                       transferir = false, retirar_en = retirar)
    bloques, estados = tb[1], tb[2]
    if estados[end].terminal != -1
        post = extender_post(StableRNG(seed + 1), P, bloques, estados, tb[3],
                             tb[4], tb[5]; max_post = max_post)
        bloques, estados = post[1], post[2]
    end
    return bloques, estados
end

function casos_negativos(P::Params; seeds::Vector{Int} = [707, 808, 909],
                         max_post::Int = 3)
    todos = CasoNegativo[]
    for seed in seeds
        bloques, estados = cadena_base(P; seed = seed, max_post = max_post)
        for k in 2:length(bloques)
            Ep = estados[k - 1]
            Bk = bloques[k]
            pref = bloques[1:k - 1]
            append!(todos, casos_bloque(P, pref, Ep, Bk))
            append!(todos, casos_garantia_insuficiente(P, pref, Ep, Bk))
            append!(todos, casos_garantia_pendiente(P, pref, Ep, Bk))
        end
    end
    return todos
end

# Puntos de la rejilla por defecto (SEC0, CUT_HWPhi, FC3): los tres de T01-B.
function puntos_negativos()
    puntos = [P for P in puntos_rejilla(rejilla = :reducida)
              if P.sec == SEC0 && P.corte == CUT_HWPhi && P.seleccion == FC3]
    N = length(puntos)
    return unique([1, div(1 + N, 2), N]), puntos
end
