# Fixtures deterministas (sin RNG), helpers de verificación y CLI de semilla.
# Los vectores usan la misma configuración de unidades que ARM-v0.1 donde corresponde.

function test_controller(; rounding::RCE.RoundMode=RCE.RoundFloor)
    # Valores elegidos del vector ARM, unidades abstractas de rango/adjudicaciones.
    return RCE.ControllerConfig(100, 10, 1, 1, 1, 2, 2, 1, 1, 1000, 1, rounding)
end

# Rama A (objetivo): H700 con bloques 1..5 y la copia RedK 6 del billete 1 (piece_offset
# distinto), y H701 con el bloque 10 que gasta una salida creada en H700.
# Rama B (respaldo, independiente): H800 bloques 20..24 y H801 bloque 25.
# Génesis: UTXOs 101..110 con importe 1000. Ambos nodos reciben el mismo conjunto de
# entregas en distinto orden; Ana retiene el cuerpo de la copia 6, Bruno el del ganador 1.
function fixture_convergencia(; policy::DCM.Policy=DCM.P0,
                              rounding::RCE.RoundMode=RCE.RoundFloor)
    blocks = [DCM.BlockSpec(UInt64(i), UInt64(i), UInt64(700), UInt64(i), DCM.Blue, UInt64[])
              for i in 1:5]
    push!(blocks, DCM.BlockSpec(UInt64(6), UInt64(1), UInt64(700), UInt64(6), DCM.RedK, UInt64[]))
    push!(blocks, DCM.BlockSpec(UInt64(10), UInt64(10), UInt64(701), UInt64(10), DCM.Blue, UInt64[]))
    for i in 20:24
        push!(blocks, DCM.BlockSpec(UInt64(i), UInt64(i), UInt64(800), UInt64(i - 19),
                                    DCM.Blue, UInt64[]))
    end
    push!(blocks, DCM.BlockSpec(UInt64(25), UInt64(25), UInt64(801), UInt64(6), DCM.Blue, UInt64[]))
    histories = [DCM.HistorySpec(UInt64(700), UInt64(0), UInt64(700), UInt64[1,2,3,4,5,6]),
                 DCM.HistorySpec(UInt64(701), UInt64(700), UInt64(701), UInt64[10]),
                 DCM.HistorySpec(UInt64(800), UInt64(0), UInt64(800), UInt64[20,21,22,23,24]),
                 DCM.HistorySpec(UInt64(801), UInt64(800), UInt64(801), UInt64[25])]
    txs = Dict{UInt64,TxSpec}()
    for i in 1:5
        txs[UInt64(i)] = TxSpec(0, 0, [UInt64(100 + i)], [UTXOSpec(UInt64(1000 + i), 500)])
    end
    txs[UInt64(6)] = TxSpec(1, 0, [UInt64(101)], [UTXOSpec(UInt64(1006), 500)])
    txs[UInt64(10)] = TxSpec(0, 0, [UInt64(1001)], [UTXOSpec(UInt64(1010), 500)])
    for i in 20:24
        txs[UInt64(i)] = TxSpec(0, 0, [UInt64(106 + i - 20)], [UTXOSpec(UInt64(1020 + i - 20), 500)])
    end
    txs[UInt64(25)] = TxSpec(0, 0, [UInt64(1020)], [UTXOSpec(UInt64(1025), 500)])
    genesis = [UTXOSpec(UInt64(100 + i), 1000) for i in 1:10]
    truth = Dict((h.id, b.id) => true for h in histories for b in blocks if b.id in h.blocks)
    modelo = EconModel(DCM.Catalog(blocks, histories; context_truth=truth), txs, genesis,
        [CloseFrame(700, 0, 10), CloseFrame(701, 1, 20),
         CloseFrame(800, 0, 10), CloseFrame(801, 1, 20)],
        10, 0, test_controller(; rounding); policy)
    return (modelo=modelo, ana_segs=eventos_ana(), bruno_segs=eventos_bruno(),
            objetivo=UInt64(701), respaldo=UInt64(801))
end

function eventos_ana()
    ev = DeliveryEvent[]
    for bid in 20:25
        push!(ev, DeliveryEvent(DelHeader, 0, UInt64(bid)))
    end
    for bid in 20:25
        push!(ev, DeliveryEvent(DelBody, 0, UInt64(bid)))
    end
    for bid in 20:24
        push!(ev, DeliveryEvent(DelContext, 800, UInt64(bid)))
    end
    push!(ev, DeliveryEvent(DelContext, 801, UInt64(25)))
    for bid in (1,2,3,4,5,6,10)
        push!(ev, DeliveryEvent(DelHeader, 0, UInt64(bid)))
    end
    for bid in (1,2,3,4,5,10)
        push!(ev, DeliveryEvent(DelBody, 0, UInt64(bid)))
    end
    for bid in 1:6
        push!(ev, DeliveryEvent(DelContext, 700, UInt64(bid)))
    end
    push!(ev, DeliveryEvent(DelContext, 701, UInt64(10)))
    push!(ev, DeliveryEvent(DelBody, 0, UInt64(6)))
    return [ev[1:18], ev[19:38], ev[39:39]]
end

function eventos_bruno()
    ev = DeliveryEvent[]
    for bid in (1,2,3,4,5,6,10)
        push!(ev, DeliveryEvent(DelHeader, 0, UInt64(bid)))
    end
    for bid in (2,3,4,5,6,10)
        push!(ev, DeliveryEvent(DelBody, 0, UInt64(bid)))
    end
    for bid in 1:6
        push!(ev, DeliveryEvent(DelContext, 700, UInt64(bid)))
    end
    push!(ev, DeliveryEvent(DelContext, 701, UInt64(10)))
    for bid in 20:25
        push!(ev, DeliveryEvent(DelHeader, 0, UInt64(bid)))
    end
    for bid in 20:25
        push!(ev, DeliveryEvent(DelBody, 0, UInt64(bid)))
    end
    for bid in 20:24
        push!(ev, DeliveryEvent(DelContext, 800, UInt64(bid)))
    end
    push!(ev, DeliveryEvent(DelContext, 801, UInt64(25)))
    push!(ev, DeliveryEvent(DelBody, 0, UInt64(1)))
    return [ev[1:20], ev[21:38], ev[39:39]]
end

# Doble gasto entre ventanas: el bloque 10 consume la UTXO 101, ya gastada por el
# bloque 1 de la ventana anterior.
function fixture_doble_gasto(; policy::DCM.Policy=DCM.P0,
                             rounding::RCE.RoundMode=RCE.RoundFloor)
    base = fixture_convergencia(; policy, rounding)
    txs = copy(base.modelo.txs)
    txs[UInt64(10)] = TxSpec(0, 0, [UInt64(101)], [UTXOSpec(UInt64(1010), 500)])
    modelo = EconModel(base.modelo.catalog, txs, base.modelo.genesis,
                       collect(values(base.modelo.frames)), 10, 0,
                       base.modelo.controller; policy)
    return (modelo=modelo, ana_segs=base.ana_segs, bruno_segs=base.bruno_segs,
            objetivo=UInt64(701), respaldo=UInt64(801))
end

# Doble gasto dentro de la misma ventana: los bloques 1 y 2 consumen la misma UTXO.
function fixture_doble_gasto_ventana(; policy::DCM.Policy=DCM.P0,
                                     rounding::RCE.RoundMode=RCE.RoundFloor)
    blocks = [DCM.BlockSpec(UInt64(i), UInt64(i), UInt64(700), UInt64(i), DCM.Blue, UInt64[])
              for i in 1:5]
    histories = [DCM.HistorySpec(UInt64(700), UInt64(0), UInt64(700), UInt64[1,2,3,4,5])]
    txs = Dict{UInt64,TxSpec}(UInt64(i) =>
        TxSpec(0, 0, [UInt64(100 + i)], [UTXOSpec(UInt64(1000 + i), 500)]) for i in 1:5)
    txs[UInt64(2)] = TxSpec(0, 0, [UInt64(101)], [UTXOSpec(UInt64(1002), 500)])
    genesis = [UTXOSpec(UInt64(100 + i), 1000) for i in 1:5]
    truth = Dict((UInt64(700), UInt64(i)) => true for i in 1:5)
    modelo = EconModel(DCM.Catalog(blocks, histories; context_truth=truth), txs, genesis,
                       [CloseFrame(700, 0, 10)], 10, 0, test_controller(; rounding); policy)
    cola = DeliveryEvent[]
    for bid in 1:5
        push!(cola, DeliveryEvent(DelHeader, 0, UInt64(bid)))
        push!(cola, DeliveryEvent(DelBody, 0, UInt64(bid)))
        push!(cola, DeliveryEvent(DelContext, 700, UInt64(bid)))
    end
    return (modelo=modelo, cola=cola, objetivo=UInt64(700), respaldo=UInt64(700))
end

# Ventana vacía con HeldZero (enmienda Z0, 2026-09-12): N0=5 en sello 10 agenda 200@30;
# N1=0 en sello 20 y N2=0 en sello 40 no agendan nada (no-op). El rango queda en 200 en
# el slot 40: convergencia exacta con el helper Rust `FeedbackState::close`.
function fixture_heldzero(; rounding::RCE.RoundMode=RCE.RoundFloor)
    blocks = [DCM.BlockSpec(UInt64(i), UInt64(i), UInt64(70), UInt64(i), DCM.Blue, UInt64[])
              for i in 1:5]
    histories = [DCM.HistorySpec(UInt64(100), UInt64(0), UInt64(70), UInt64[1,2,3,4,5]),
                 DCM.HistorySpec(UInt64(200), UInt64(100), UInt64(80), UInt64[]),
                 DCM.HistorySpec(UInt64(300), UInt64(200), UInt64(90), UInt64[])]
    txs = Dict{UInt64,TxSpec}(UInt64(i) =>
        TxSpec(0, 0, [UInt64(200 + i)], [UTXOSpec(UInt64(1200 + i), 500)]) for i in 1:5)
    genesis = [UTXOSpec(UInt64(200 + i), 1000) for i in 1:5]
    truth = Dict((UInt64(100), UInt64(i)) => true for i in 1:5)
    cfg = RCE.ControllerConfig(100, 10, 1, 1, 1, 2, 2, 1, 1, 1000, 2, rounding)
    modelo = EconModel(DCM.Catalog(blocks, histories; context_truth=truth), txs, genesis,
        [CloseFrame(100, 0, 10), CloseFrame(200, 1, 20), CloseFrame(300, 2, 40)],
        10, 0, cfg)
    cola = DeliveryEvent[]
    for bid in 1:5
        push!(cola, DeliveryEvent(DelHeader, 0, UInt64(bid)))
        push!(cola, DeliveryEvent(DelBody, 0, UInt64(bid)))
        push!(cola, DeliveryEvent(DelContext, 100, UInt64(bid)))
    end
    return (modelo=modelo, cola=cola, objetivo=UInt64(300), respaldo=UInt64(100))
end

# Caso literal de la laguna de unicidad pagable del SPEC §7.2: dos copias RedK del
# billete 1 sin copia azul. El billete queda deducplicado a UN ganador (bloque 2,
# rank 2 < rank 3); el bloque 1 no cobra y no cuenta. P0 y P1 eligen igual.
function fixture_copias_rojas_sin_azul(; policy::DCM.Policy=DCM.P0,
                                       rounding::RCE.RoundMode=RCE.RoundFloor)
    blocks = [DCM.BlockSpec(UInt64(1), UInt64(1), UInt64(700), UInt64(3), DCM.RedK, UInt64[]),
              DCM.BlockSpec(UInt64(2), UInt64(1), UInt64(700), UInt64(2), DCM.RedK, UInt64[]),
              DCM.BlockSpec(UInt64(3), UInt64(3), UInt64(700), UInt64(1), DCM.Blue, UInt64[])]
    histories = [DCM.HistorySpec(UInt64(700), UInt64(0), UInt64(700), UInt64[1,2,3])]
    txs = Dict{UInt64,TxSpec}(
        UInt64(1) => TxSpec(0, 0, [UInt64(101)], [UTXOSpec(UInt64(1001), 500)]),
        UInt64(2) => TxSpec(1, 0, [UInt64(101)], [UTXOSpec(UInt64(1002), 500)]),
        UInt64(3) => TxSpec(0, 0, [UInt64(103)], [UTXOSpec(UInt64(1003), 500)]))
    genesis = [UTXOSpec(UInt64(100 + i), 1000) for i in 1:5]
    truth = Dict((UInt64(700), UInt64(i)) => true for i in 1:3)
    modelo = EconModel(DCM.Catalog(blocks, histories; context_truth=truth), txs, genesis,
                       [CloseFrame(700, 0, 10)], 10, 0, test_controller(; rounding); policy)
    cola = DeliveryEvent[]
    for bid in 1:3
        push!(cola, DeliveryEvent(DelHeader, 0, UInt64(bid)))
        push!(cola, DeliveryEvent(DelBody, 0, UInt64(bid)))
        push!(cola, DeliveryEvent(DelContext, 700, UInt64(bid)))
    end
    return (modelo=modelo, cola=cola, objetivo=UInt64(700), respaldo=UInt64(700))
end

# Único vector que distingue P0 de P1: copias del billete 1 con colores distintos.
# P0 elige por (rank, id) → bloque 8 RedK (rank 2 < 5); P1 elige azul primero →
# bloque 7 Blue pese a su rank 5. Es la evidencia de que la decisión de Katana
# (azul primero) es material.
function fixture_desempate_color(; policy::DCM.Policy=DCM.P0,
                                 rounding::RCE.RoundMode=RCE.RoundFloor)
    blocks = [DCM.BlockSpec(UInt64(7), UInt64(1), UInt64(700), UInt64(5), DCM.Blue, UInt64[]),
              DCM.BlockSpec(UInt64(8), UInt64(1), UInt64(700), UInt64(2), DCM.RedK, UInt64[])]
    histories = [DCM.HistorySpec(UInt64(700), UInt64(0), UInt64(700), UInt64[7,8])]
    txs = Dict{UInt64,TxSpec}(
        UInt64(7) => TxSpec(0, 0, [UInt64(101)], [UTXOSpec(UInt64(1007), 700)]),
        UInt64(8) => TxSpec(1, 0, [UInt64(101)], [UTXOSpec(UInt64(1008), 800)]))
    genesis = [UTXOSpec(UInt64(100 + i), 1000) for i in 1:3]
    truth = Dict((UInt64(700), UInt64(bid)) => true for bid in (7, 8))
    modelo = EconModel(DCM.Catalog(blocks, histories; context_truth=truth), txs, genesis,
                       [CloseFrame(700, 0, 10)], 10, 0, test_controller(; rounding); policy)
    cola = DeliveryEvent[]
    for bid in (7, 8)
        push!(cola, DeliveryEvent(DelHeader, 0, UInt64(bid)))
        push!(cola, DeliveryEvent(DelBody, 0, UInt64(bid)))
        push!(cola, DeliveryEvent(DelContext, 700, UInt64(bid)))
    end
    return (modelo=modelo, cola=cola, objetivo=UInt64(700), respaldo=UInt64(700))
end

# Copia del billete 1 (bloque 9) fusionada en la ventana posterior a la del ganador
# (bloque 1). Respalda la cláusula «incluso en fusiones distintas»: la copia es
# inerte por DOS guardas independientes — el billete ya está en `consumed` y su
# ventana de origen (700) no es la ventana de la historia H701 — que no se pueden
# aislar porque DCM.Catalog rechaza copias con otra ventana de origen declarada.
function fixture_copia_en_fusion_posterior(; policy::DCM.Policy=DCM.P0,
                                           rounding::RCE.RoundMode=RCE.RoundFloor)
    blocks = [DCM.BlockSpec(UInt64(1), UInt64(1), UInt64(700), UInt64(1), DCM.Blue, UInt64[]),
              DCM.BlockSpec(UInt64(9), UInt64(1), UInt64(700), UInt64(9), DCM.RedK, UInt64[]),
              DCM.BlockSpec(UInt64(10), UInt64(10), UInt64(701), UInt64(10), DCM.Blue, UInt64[])]
    histories = [DCM.HistorySpec(UInt64(700), UInt64(0), UInt64(700), UInt64[1]),
                 DCM.HistorySpec(UInt64(701), UInt64(700), UInt64(701), UInt64[9,10])]
    txs = Dict{UInt64,TxSpec}(
        UInt64(1) => TxSpec(0, 0, [UInt64(101)], [UTXOSpec(UInt64(1001), 500)]),
        UInt64(9) => TxSpec(1, 0, [UInt64(102)], [UTXOSpec(UInt64(1009), 999)]),
        UInt64(10) => TxSpec(0, 0, [UInt64(103)], [UTXOSpec(UInt64(1010), 500)]))
    genesis = [UTXOSpec(UInt64(100 + i), 1000) for i in 1:5]
    truth = Dict((h.id, b.id) => true for h in histories for b in blocks if b.id in h.blocks)
    modelo = EconModel(DCM.Catalog(blocks, histories; context_truth=truth), txs, genesis,
        [CloseFrame(700, 0, 10), CloseFrame(701, 1, 20)], 10, 0,
        test_controller(; rounding); policy)
    cola = DeliveryEvent[]
    for (hid, bids) in ((UInt64(700), UInt64[1]), (UInt64(701), UInt64[9,10]))
        for bid in bids
            push!(cola, DeliveryEvent(DelHeader, 0, bid))
            push!(cola, DeliveryEvent(DelBody, 0, bid))
            push!(cola, DeliveryEvent(DelContext, hid, bid))
        end
    end
    return (modelo=modelo, cola=cola, objetivo=UInt64(701), respaldo=UInt64(700))
end

# Reorg entre dos ramas competidoras que usan el MISMO billete: el bloque 1 (rama A)
# y el bloque 20 (rama B) comparten billete 1 y ventana de origen 700. Restricción del
# modelo: DCM.Catalog exige una única ventana de origen por billete, y
# objective_winners exige origin_window == h.window; por eso la historia 800 declara
# window=700. Al abandonar la rama A, el billete 1 se libera y lo consume el bloque 20
# en la rama que prevalece: nunca se paga dos veces, ni siquiera a través de un reorg.
function fixture_reorg_libera_billete(; policy::DCM.Policy=DCM.P0,
                                      rounding::RCE.RoundMode=RCE.RoundFloor)
    blocks = [DCM.BlockSpec(UInt64(1), UInt64(1), UInt64(700), UInt64(1), DCM.Blue, UInt64[]),
              DCM.BlockSpec(UInt64(20), UInt64(1), UInt64(700), UInt64(2), DCM.Blue, UInt64[])]
    histories = [DCM.HistorySpec(UInt64(700), UInt64(0), UInt64(700), UInt64[1]),
                 DCM.HistorySpec(UInt64(800), UInt64(0), UInt64(700), UInt64[20])]
    txs = Dict{UInt64,TxSpec}(
        UInt64(1) => TxSpec(0, 0, [UInt64(101)], [UTXOSpec(UInt64(1001), 500)]),
        UInt64(20) => TxSpec(1, 0, [UInt64(102)], [UTXOSpec(UInt64(1020), 777)]))
    genesis = [UTXOSpec(UInt64(100 + i), 1000) for i in 1:5]
    truth = Dict((UInt64(700), UInt64(1)) => true, (UInt64(800), UInt64(20)) => true)
    modelo = EconModel(DCM.Catalog(blocks, histories; context_truth=truth), txs, genesis,
        [CloseFrame(700, 0, 10), CloseFrame(800, 0, 10)], 10, 0,
        test_controller(; rounding); policy)
    cola = DeliveryEvent[]
    for (hid, bid) in ((UInt64(700), UInt64(1)), (UInt64(800), UInt64(20)))
        push!(cola, DeliveryEvent(DelHeader, 0, bid))
        push!(cola, DeliveryEvent(DelBody, 0, bid))
        push!(cola, DeliveryEvent(DelContext, hid, bid))
    end
    return (modelo=modelo, cola=cola, objetivo=UInt64(700), respaldo=UInt64(700))
end

# Ramas sintéticas para medir solo el coste del workload (bench), como ARM-v0.1.
function fixture_rama(depth::Int; policy::DCM.Policy=DCM.P0,
                      rounding::RCE.RoundMode=RCE.RoundFloor)
    depth > 0 || throw(ArgumentError("positive synthetic depth"))
    blocks = [DCM.BlockSpec(UInt64(1), UInt64(1), UInt64(700), UInt64(1), DCM.Blue, UInt64[])]
    histories = [DCM.HistorySpec(UInt64(900), UInt64(0), UInt64(700), UInt64[1])]
    frames = [CloseFrame(900, 0, 10)]
    txs = Dict{UInt64,TxSpec}(UInt64(1) =>
        TxSpec(0, 0, [UInt64(90001)], [UTXOSpec(UInt64(190001), 500)]))
    genesis_ids = UInt64[90001]
    for branch in 1:2, level in 1:depth
        base = branch == 1 ? 1_000 : 2_000
        bid = UInt64(base + level)
        hid = UInt64(10_000 + base + level)
        window = UInt64(30_000 + base + level)
        parent_bid = level == 1 ? UInt64(1) : UInt64(base + level - 1)
        parent_hid = level == 1 ? UInt64(900) : UInt64(10_000 + base + level - 1)
        push!(blocks, DCM.BlockSpec(bid, bid, window, UInt64(level + 1), DCM.Blue,
                                    UInt64[parent_bid]))
        push!(histories, DCM.HistorySpec(hid, parent_hid, window, UInt64[bid]))
        push!(frames, CloseFrame(hid, UInt64(level), UInt64(10 * (level + 1))))
        txs[bid] = TxSpec(0, 0, [UInt64(90000 + bid)], [UTXOSpec(UInt64(190000 + bid), 500)])
        push!(genesis_ids, UInt64(90000 + bid))
    end
    truth = Dict((h.id, b.id) => true for h in histories for b in blocks)
    modelo = EconModel(DCM.Catalog(blocks, histories; context_truth=truth), txs,
        [UTXOSpec(id, 1000) for id in genesis_ids], frames, 10, 0,
        test_controller(; rounding); policy)
    return (modelo=modelo, objetivo=UInt64(11_000 + depth),
            respaldo=UInt64(12_000 + depth))
end

function verificar_heldzero(NodeF=FastNode; rounding::RCE.RoundMode=RCE.RoundFloor)
    modelo, cola, objetivo, respaldo = fixture_heldzero(; rounding)
    nodo = NodeF(modelo, "heldzero", cola, objetivo, respaldo)
    procesar_eventos!(nodo, length(cola))
    replay!(nodo, objetivo) === DCM.Applied || error("heldzero replay")
    cp = controller_projection(nodo.estado.controller)
    # Enmienda Z0 (2026-09-12): HeldZero sella y registra la ventana vacía, pero no agenda.
    return (applied=true, observed_zero=cp.seals[2].observed == 0,
            heldzero=cp.seals[2].code === RCE.StepHeldZero,
            activation_zero=cp.seals[2].activation_slot == 0,
            proposals=cp.proposals, activations=cp.activations,
            range_at_39=range_at(nodo.estado.controller, UInt64(39)),
            range_at_40=range_at(nodo.estado.controller, UInt64(40)),
            range_at_35=range_at(nodo.estado.controller, UInt64(35)))
end

function verificar_doble_gasto(NodeF=FastNode)
    fixture = fixture_doble_gasto()
    cola = reduce(vcat, fixture.ana_segs)
    nodo = NodeF(fixture.modelo, "doble-gasto", cola, fixture.objetivo, fixture.respaldo)
    procesar_eventos!(nodo, length(cola))
    nodo.estado.dcm.public.current == fixture.respaldo ||
        error("respaldo no aplicado en el control de doble gasto")
    before = proyeccion_nodo(nodo)
    outcome = replay!(nodo, fixture.objetivo)
    return (outcome=outcome, unpublished=proyeccion_nodo(nodo) == before,
            pending=nodo.pending)
end

function verificar_doble_gasto_ventana(NodeF=FastNode)
    fixture = fixture_doble_gasto_ventana()
    nodo = NodeF(fixture.modelo, "doble-gasto-ventana", fixture.cola,
                 fixture.objetivo, fixture.respaldo)
    procesar_eventos!(nodo, length(fixture.cola))
    before = proyeccion_nodo(nodo)
    outcome = replay!(nodo, fixture.objetivo)
    return (outcome=outcome, unpublished=proyeccion_nodo(nodo) == before,
            pending=nodo.pending)
end

function verificar_reloj(NodeF=FastNode)
    fixture = fixture_convergencia()
    cola = reduce(vcat, fixture.ana_segs)
    nodo = NodeF(fixture.modelo, "reloj", cola, fixture.objetivo, fixture.respaldo)
    procesar_eventos!(nodo, length(cola))
    eventos = nodo.estado.dcm.public.counted[UInt64(700)]
    frame = fixture.modelo.frames[UInt64(700)]
    early = control_reloj_local(fixture.modelo, frame, eventos, UInt64(9), UInt64(21))
    late = control_reloj_local(fixture.modelo, frame, eventos, UInt64(21), UInt64(21))
    return (events_equal=early.events == late.events, early_active=early.active_range,
            late_active=late.active_range,
            causal_range_at_21=range_at(nodo.estado.controller, UInt64(21)))
end

function ejecutar_convergencia(seed::UInt64)
    fixture = fixture_convergencia()
    modelo = fixture.modelo
    ana = FastNode(modelo, "Ana", reduce(vcat, fixture.ana_segs),
                   fixture.objetivo, fixture.respaldo)
    bruno = FastNode(modelo, "Bruno", reduce(vcat, fixture.bruno_segs),
                     fixture.objetivo, fixture.respaldo)
    procesar_eventos!(ana, length(fixture.ana_segs[1]))
    progreso_ana = ana.estado.dcm.public.current == fixture.respaldo
    procesar_eventos!(ana, length(fixture.ana_segs[2]) + length(fixture.ana_segs[3]))
    procesar_eventos!(bruno, length(fixture.bruno_segs[1]))
    pendiente = bruno.estado.dcm.public.current == 0
    procesar_eventos!(bruno, length(fixture.bruno_segs[2]))
    progreso_bruno = bruno.estado.dcm.public.current == fixture.respaldo
    procesar_eventos!(bruno, length(fixture.bruno_segs[3]))
    reproducido = bruno.estado.dcm.public.current == fixture.objetivo
    convergido = ana.estado.dcm.public.current == fixture.objetivo && reproducido &&
                 proyeccion_nodo(ana) == proyeccion_nodo(bruno)
    retarget_igual = controller_projection(ana.estado.controller) ==
                     controller_projection(bruno.estado.controller)
    proj = proyeccion_nodo(ana).economia
    peso = control_peso_naive(modelo, UInt64(700))
    reloj = verificar_reloj()
    gasto = verificar_doble_gasto()
    ventana = verificar_doble_gasto_ventana()
    heldzero = verificar_heldzero()
    return (seed=seed, convergido=convergido, progreso_ana=progreso_ana,
            progreso_bruno=progreso_bruno, pendiente_reproducido=pendiente && reproducido,
            retarget_igual=retarget_igual, pagos=length(proj.payments),
            consumos=length(proj.consumptions), total_paid=proj.total_paid,
            total_consumed=proj.total_consumed, peso_dedup=peso.dedup,
            peso_naive=peso.naive, naive_detected=peso.naive_detected,
            doble_gasto=gasto.outcome === DCM.Invalid && gasto.unpublished,
            doble_gasto_ventana=ventana.outcome === DCM.Invalid && ventana.unpublished,
            reloj_detectado=reloj.events_equal && reloj.early_active == 200 &&
                            reloj.late_active == 100,
            # Enmienda Z0 (2026-09-12): convergencia Julia–Rust, no discrepancia documentada.
            heldzero_convergencia=heldzero.heldzero && heldzero.activation_zero &&
                                  heldzero.range_at_39 == 200 &&
                                  heldzero.range_at_40 == 200)
end

function parse_seed(args::Vector{String})
    length(args) == 2 && args[1] == "--seed" || throw(ArgumentError("usage: --seed DECIMAL_U64"))
    token = args[2]
    !isempty(token) && all(c -> '0' <= c <= '9', token) ||
        throw(ArgumentError("ASCII decimal seed required"))
    return parse(UInt64, token)
end
