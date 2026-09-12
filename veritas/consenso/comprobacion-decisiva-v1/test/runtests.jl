using Test
using ComprobacionDecisiva

const U = UInt64
const SEED = parse_seed(ARGS)

@testset "convergencia de dos nodos con distinto orden y cuerpos retenidos" begin
    for policy in (DCM.P0, DCM.P1), rounding in (RCE.RoundFloor, RCE.RoundNearestEven)
        fixture = fixture_convergencia(; policy, rounding)
        modelo = fixture.modelo
        cola_ana = reduce(vcat, fixture.ana_segs)
        cola_bruno = reduce(vcat, fixture.bruno_segs)
        @test cola_ana == cola_ana && length(cola_ana) == length(cola_bruno)
        @test sort(cola_ana; by=e -> (Int(e.kind), e.hid, e.bid)) ==
              sort(cola_bruno; by=e -> (Int(e.kind), e.hid, e.bid))
        for NodeF in (ReferenceNode, FastNode)
            ana = NodeF(modelo, "Ana", cola_ana, fixture.objetivo, fixture.respaldo)
            bruno = NodeF(modelo, "Bruno", cola_bruno, fixture.objetivo, fixture.respaldo)
            # Ana: la rama independiente completa llega primero → progreso sobre B.
            procesar_eventos!(ana, length(fixture.ana_segs[1]))
            @test ana.estado.dcm.public.current == fixture.respaldo
            @test length(ana.estado.controller.seals) == 2
            @test proyeccion_nodo(ana).economia.total_paid == 3000
            procesar_eventos!(ana, length(fixture.ana_segs[2]))
            @test ana.estado.dcm.public.current == fixture.objetivo
            antes_copia = proyeccion_nodo(ana)
            procesar_eventos!(ana, length(fixture.ana_segs[3]))
            @test proyeccion_nodo(ana) == antes_copia
            # Bruno: objetivo Pending por cuerpo retenido, sin publicar nada.
            procesar_eventos!(bruno, length(fixture.bruno_segs[1]))
            @test bruno.estado.dcm.public.current == 0
            @test isempty(bruno.estado.controller.seals)
            sin_cuerpo = proyeccion_nodo(bruno)
            @test replay!(bruno, fixture.objetivo) === DCM.Pending
            @test bruno.pending == U(700)
            publica(x) = (dcm=x.dcm, controller=x.controller, economia=x.economia)
            @test publica(proyeccion_nodo(bruno)) == publica(sin_cuerpo)
            # La rama independiente completa progresa mientras el objetivo espera.
            procesar_eventos!(bruno, length(fixture.bruno_segs[2]))
            @test bruno.estado.dcm.public.current == fixture.respaldo
            @test length(bruno.estado.controller.seals) == 2
            # El cuerpo tardío reproduce la historia retenida: no queda inerte.
            procesar_eventos!(bruno, length(fixture.bruno_segs[3]))
            @test bruno.estado.dcm.public.current == fixture.objetivo
            # Convergencia exacta de publicación conjunta.
            @test proyeccion_nodo(ana) == proyeccion_nodo(bruno)
            proj = proyeccion_nodo(bruno).economia
            @test proj.payments == [(U(700), U(1), U(1001), U(500)),
                                    (U(700), U(2), U(1002), U(500)),
                                    (U(700), U(3), U(1003), U(500)),
                                    (U(700), U(4), U(1004), U(500)),
                                    (U(700), U(5), U(1005), U(500)),
                                    (U(701), U(10), U(1010), U(500))]
            @test proj.consumptions == [(U(700), U(1), U(101), U(1000)),
                                        (U(700), U(2), U(102), U(1000)),
                                        (U(700), U(3), U(103), U(1000)),
                                        (U(700), U(4), U(104), U(1000)),
                                        (U(700), U(5), U(105), U(1000)),
                                        (U(701), U(10), U(1001), U(500))]
            @test proj.available == [(U(106), U(1000)), (U(107), U(1000)),
                                     (U(108), U(1000)), (U(109), U(1000)),
                                     (U(110), U(1000)), (U(1002), U(500)),
                                     (U(1003), U(500)), (U(1004), U(500)),
                                     (U(1005), U(500)), (U(1010), U(500))]
            @test proj.total_paid == 3000 && proj.total_consumed == 5500
            # Retarget exacto: mismo rango observado, mismas propuestas y agenda.
            cp = controller_projection(bruno.estado.controller)
            @test cp.proposals == [(U(700), U(0), U(20), U(200)),
                                   (U(701), U(1), U(30), U(400))]
            @test cp.activations == cp.proposals[1:1]
            @test cp.agenda == cp.proposals[2:2]
            @test cp.active_range == 200
            @test cp.seals[1].observed == 5 && cp.seals[2].observed == 1
            @test range_at(bruno.estado.controller, U(29)) == 200
            @test range_at(bruno.estado.controller, U(30)) == 400
        end
    end
end

@testset "peso azul deduplicado y control negativo de multiplicación" begin
    for policy in (DCM.P0, DCM.P1)
        fixture = fixture_convergencia(; policy)
        modelo = fixture.modelo
        @test peso_dedup(modelo, U(700), Set{UInt64}()) == 5
        @test peso_naive(modelo, U(700), Set{UInt64}()) == 6
        control = control_peso_naive(modelo, U(700))
        @test control.dedup == 5 && control.naive == 6
        @test control.naive_detected
        @test control.rango_dedup == 200
        @test control.rango_naive == 166
        # El estado aplicado usa la versión deduplicada, nunca la multiplicada.
        ana = FastNode(modelo, "Ana", reduce(vcat, fixture.ana_segs),
                       fixture.objetivo, fixture.respaldo)
        procesar_eventos!(ana, length(reduce(vcat, fixture.ana_segs)))
        @test ana.estado.controller.seals[1].observed == 5
        @test proyeccion_nodo(ana).economia.payments ==
              vcat([(U(700), U(i), U(1000 + i), U(500)) for i in 1:5],
                   [(U(701), U(10), U(1010), U(500))])
        @test !((U(700), U(6), U(1006), U(500)) in
                proyeccion_nodo(ana).economia.payments)
    end
end

@testset "unicidad pagable: copias rojas, desempate de color y copia en fusión posterior" begin
    ejecutar(fixture, NodeF) = begin
        nodo = NodeF(fixture.modelo, "unicidad", fixture.cola,
                     fixture.objetivo, fixture.respaldo)
        procesar_eventos!(nodo, length(fixture.cola))
        @test nodo.estado.dcm.public.current == fixture.objetivo
        nodo
    end
    # Vector 1: caso literal de la laguna de §7.2. Dos copias RedK del billete 1 sin
    # copia azul: el billete queda deducplicado a UN ganador (bloque 2, rank 2 < rank 3);
    # el bloque 1 no cobra y no cuenta. Idéntico en P0/P1 y en Reference/Fast.
    for policy in (DCM.P0, DCM.P1)
        fixture = fixture_copias_rojas_sin_azul(; policy)
        proyecciones = Any[]
        for NodeF in (ReferenceNode, FastNode)
            nodo = ejecutar(fixture, NodeF)
            proj = proyeccion_nodo(nodo)
            cp = controller_projection(nodo.estado.controller)
            @test cp.seals[1].observed == 2
            @test [(e.history, e.block) for e in nodo.estado.dcm.public.counted[U(700)]] ==
                  [(U(700), U(3)), (U(700), U(2))]
            @test proj.economia.payments == [(U(700), U(3), U(1003), U(500)),
                                             (U(700), U(2), U(1002), U(500))]
            @test proj.economia.total_paid == 1000
            @test cp.proposals == [(U(700), U(0), U(20), U(200))]
            @test proj.economia.consumptions == [(U(700), U(3), U(103), U(1000)),
                                                (U(700), U(2), U(101), U(1000))]
            @test proj.economia.available == [(U(102), U(1000)), (U(104), U(1000)),
                                              (U(105), U(1000)), (U(1002), U(500)),
                                              (U(1003), U(500))]
            @test proj.economia.total_consumed == 2000
            @test !((U(700), U(1), U(1001), U(500)) in proj.economia.payments)
            @test nodo.estado.dcm.public.consumed == Set([U(1), U(3)])
            # Orden de entrega invertido: misma proyección pública exacta.
            invertida = reverse(copy(fixture.cola))
            nodo_inv = NodeF(fixture.modelo, "unicidad-inv", invertida,
                             fixture.objetivo, fixture.respaldo)
            procesar_eventos!(nodo_inv, length(invertida))
            @test proyeccion_nodo(nodo_inv) == proj
            push!(proyecciones, proj)
        end
        @test proyecciones[1] == proyecciones[2]
    end
    # Vector 2: el único vector que distingue P0 de P1. P0 elige por (rank, id) → bloque 8;
    # P1 elige azul primero → bloque 7 pese a su rank 5. La decisión de Katana es material.
    pagos_p0 = Any[]
    pagos_p1 = Any[]
    for NodeF in (ReferenceNode, FastNode)
        proj_p0 = proyeccion_nodo(ejecutar(fixture_desempate_color(; policy=DCM.P0),
                                           NodeF)).economia
        proj_p1 = proyeccion_nodo(ejecutar(fixture_desempate_color(; policy=DCM.P1),
                                           NodeF)).economia
        @test proj_p0.payments == [(U(700), U(8), U(1008), U(800))]
        @test proj_p0.total_paid == 800
        @test proj_p1.payments == [(U(700), U(7), U(1007), U(700))]
        @test proj_p1.total_paid == 700
        @test proj_p1.payments[1][2] == U(7)
        @test proj_p0.payments != proj_p1.payments
        push!(pagos_p0, proj_p0.payments)
        push!(pagos_p1, proj_p1.payments)
    end
    @test all(p -> p == pagos_p0[1], pagos_p0)
    @test all(p -> p == pagos_p1[1], pagos_p1)
    # Vector 3: copia del billete 1 fusionada en la ventana posterior. Inerte por DOS
    # guardas independientes — billete ya en `consumed` y ventana de origen (700) fuera
    # de la historia H701 —: no cobra (pagado total 1000, 2 pagos) y no infla el retarget.
    for policy in (DCM.P0, DCM.P1), NodeF in (ReferenceNode, FastNode)
        fixture = fixture_copia_en_fusion_posterior(; policy)
        nodo = ejecutar(fixture, NodeF)
        cp = controller_projection(nodo.estado.controller)
        proj = proyeccion_nodo(nodo).economia
        @test length(proj.payments) == 2
        @test proj.payments == [(U(700), U(1), U(1001), U(500)),
                                (U(701), U(10), U(1010), U(500))]
        @test proj.total_paid == 1000
        @test !((U(701), U(9), U(1009), U(999)) in proj.payments)
        @test [s.observed for s in cp.seals] == [1, 1]
    end
    # Hallazgo documentado: las dos guardas no se pueden aislar en vectores distintos
    # porque DCM.Catalog rechaza con ArgumentError("ticket changes origin window")
    # cualquier copia que declare otra ventana de origen para el mismo billete. Se
    # fija al mensaje concreto: el ArgumentError esperado es exactamente ese.
    @test_throws "ticket changes origin window" DCM.Catalog([
        DCM.BlockSpec(U(1), U(1), U(700), U(1), DCM.Blue, UInt64[]),
        DCM.BlockSpec(U(9), U(1), U(701), U(9), DCM.RedK, UInt64[]),
        DCM.BlockSpec(U(10), U(10), U(701), U(10), DCM.Blue, UInt64[])],
        [DCM.HistorySpec(U(700), U(0), U(700), U[1]),
         DCM.HistorySpec(U(701), U(700), U(701), U[9, 10])])
end

@testset "unicidad pagable: reorg libera el billete en la rama que prevalece" begin
    # El mismo billete 1 gana en dos ramas competidoras (bloque 1 en H700, bloque 20 en
    # H800 con window=700 por restricción del catálogo). Al reorg a H800, el billete se
    # libera y lo consume el bloque 20: nunca se paga dos veces ni se conserva nada de
    # la rama abandonada.
    for policy in (DCM.P0, DCM.P1), NodeF in (ReferenceNode, FastNode)
        fixture = fixture_reorg_libera_billete(; policy)
        nodo = NodeF(fixture.modelo, "reorg", fixture.cola,
                     fixture.objetivo, fixture.respaldo)
        procesar_eventos!(nodo, length(fixture.cola))
        @test nodo.estado.dcm.public.current == fixture.objetivo
        rama_a = proyeccion_nodo(nodo).economia
        @test rama_a.payments == [(U(700), U(1), U(1001), U(500))]
        @test rama_a.total_paid == 500
        @test rama_a.total_consumed == 1000
        @test rama_a.consumptions == [(U(700), U(1), U(101), U(1000))]
        @test replay!(nodo, U(800)) === DCM.Applied
        @test nodo.estado.dcm.public.current == U(800)
        proj = proyeccion_nodo(nodo)
        cp = controller_projection(nodo.estado.controller)
        @test proj.economia.payments == [(U(800), U(20), U(1020), U(777))]
        @test proj.economia.total_paid == 777
        @test proj.economia.total_consumed == 1000
        @test proj.economia.consumptions == [(U(800), U(20), U(102), U(1000))]
        @test proj.economia.available == [(U(101), U(1000)), (U(103), U(1000)),
                                          (U(104), U(1000)), (U(105), U(1000)),
                                          (U(1020), U(777))]
        @test nodo.estado.dcm.public.consumed == Set([U(1)])
        @test [s.observed for s in cp.seals] == [1]
        @test cp.proposals == [(U(800), U(0), U(20), U(200))]
        # El billete 1 NO queda pagado dos veces: la rama abandonada no paga.
        @test !((U(700), U(1), U(1001), U(500)) in proj.economia.payments)
        # La proyección pública tras el reorg no conserva nada de la rama A.
        @test proj.dcm.public.journal == [(U(800), U(20))]
        @test proj.dcm.public.counted == [(U(700), [(U(800), U(20))])]
        @test proj.dcm.public.applied_blocks == [U(20)]
    end
end

@testset "doble gasto invalida sin publicar" begin
    for NodeF in (ReferenceNode, FastNode)
        fixture = fixture_doble_gasto()
        cola = reduce(vcat, fixture.ana_segs)
        nodo = NodeF(fixture.modelo, "ds", cola, fixture.objetivo, fixture.respaldo)
        procesar_eventos!(nodo, length(cola))
        @test nodo.estado.dcm.public.current == fixture.respaldo
        before = proyeccion_nodo(nodo)
        @test replay!(nodo, fixture.objetivo) === DCM.Invalid
        @test nodo.pending == 0
        @test proyeccion_nodo(nodo) == before
        fixture2 = fixture_doble_gasto_ventana()
        nodo2 = NodeF(fixture2.modelo, "dsv", fixture2.cola,
                      fixture2.objetivo, fixture2.respaldo)
        procesar_eventos!(nodo2, length(fixture2.cola))
        before2 = proyeccion_nodo(nodo2)
        @test replay!(nodo2, fixture2.objetivo) === DCM.Invalid
        @test proyeccion_nodo(nodo2) == before2
    end
end

@testset "reloj local: control negativo heredado de ARM" begin
    resultado = verificar_reloj()
    @test resultado.events_equal
    @test resultado.early_active == 200
    @test resultado.late_active == 100
    @test resultado.causal_range_at_21 == 200
end

@testset "ventana vacía con HeldZero: convergencia Julia–Rust tras la enmienda Z0" begin
    # Enmienda Z0 (2026-09-12). Antes: Julia agendaba 100@40 y 100@50 (HeldZero),
    # el helper Rust no, y el rango en el slot 40 era 100 en Julia y 200 en Rust.
    # Ahora ambas implementaciones no agendan y el rango en 40 es 200 en las dos.
    for NodeF in (ReferenceNode, FastNode)
        resultado = verificar_heldzero(NodeF)
        @test resultado.applied && resultado.observed_zero && resultado.heldzero
        @test resultado.activation_zero
        @test resultado.proposals == [(U(100), U(0), U(30), U(200))]
        @test resultado.activations == resultado.proposals
        @test resultado.range_at_39 == 200
        @test resultado.range_at_40 == 200
        @test resultado.range_at_35 == 200
    end
end

@testset "referencia y kernel coinciden en todos los vectores" begin
    f1 = fixture_convergencia()
    f2 = fixture_doble_gasto()
    f3 = fixture_heldzero()
    f4 = fixture_doble_gasto_ventana()
    for (fixture, cola) in ((f1, reduce(vcat, f1.ana_segs)),
                            (f2, reduce(vcat, f2.ana_segs)),
                            (f3, f3.cola), (f4, f4.cola))
        ref = ReferenceNode(fixture.modelo, "ref", cola, fixture.objetivo, fixture.respaldo)
        fast = FastNode(fixture.modelo, "fast", cola, fixture.objetivo, fixture.respaldo)
        procesar_eventos!(ref, length(cola))
        procesar_eventos!(fast, length(cola))
        @test proyeccion_nodo(ref) == proyeccion_nodo(fast)
        @test replay!(ref, fixture.objetivo) == replay!(fast, fixture.objetivo)
        @test proyeccion_nodo(ref) == proyeccion_nodo(fast)
    end
end

@testset "descriptor, dominio y fallos sin publicar" begin
    fixture = fixture_convergencia()
    modelo = fixture.modelo
    @test_throws ArgumentError EconModel(modelo.catalog, modelo.txs, modelo.genesis,
                                         CloseFrame[], 10, 0, modelo.controller)
    @test_throws ArgumentError EconModel(modelo.catalog, modelo.txs, modelo.genesis,
                                         [CloseFrame(999, 0, 10)], 10, 0, modelo.controller)
    @test_throws ArgumentError EconModel(modelo.catalog, modelo.txs, modelo.genesis,
                                         collect(values(modelo.frames)), 0, 0,
                                         modelo.controller)
    malas_txs = copy(modelo.txs)
    malas_txs[UInt64(1)] = TxSpec(0, 0, [UInt64(101), UInt64(101)],
                                  [UTXOSpec(UInt64(1001), 500)])
    @test_throws ArgumentError EconModel(modelo.catalog, malas_txs, modelo.genesis,
                                         collect(values(modelo.frames)), 10, 0,
                                         modelo.controller)
    for NodeF in (ReferenceNode, FastNode)
        nodo = NodeF(modelo, "x", DeliveryEvent[], fixture.objetivo, fixture.respaldo)
        before = proyeccion_nodo(nodo)
        @test replay!(nodo, U(999999)) === DCM.Invalid
        @test proyeccion_nodo(nodo) == before
    end
end

@testset "semilla obligatoria sin RNG implícito" begin
    @test parse_seed(["--seed", "20260912"]) == U(20260912)
    @test parse_seed(["--seed", "0"]) == U(0)
    @test_throws ArgumentError parse_seed(String[])
    @test_throws ArgumentError parse_seed(["--seed", "-1"])
    @test_throws ArgumentError parse_seed(["--seed", "+1"])
    @test_throws ArgumentError parse_seed(["--seed", "1", "EXTRA"])
end

println("model=comprobacion-decisiva-v1 seed=$SEED rng=none acceptance=exact_economic_convergence")
