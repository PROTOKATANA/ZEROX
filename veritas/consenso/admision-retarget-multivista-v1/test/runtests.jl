using Test
using AdmisionRetargetMultivista

const ARM = AdmisionRetargetMultivista
const U = UInt64
const SEED = parse_seed(ARGS)

@testset "ARM vector manual y control negativo" begin
    result = validate_manual(SEED)
    @test result.observed == 5
    @test result.negative_detected && result.causal_convergence
    @test result.naive_early_range == 200 && result.naive_late_range == 100
    @test result.causal_range_at_21 == 200
    model = manual_model()
    ref = deliver_all!(ReferenceView(model))
    fast = deliver_all!(FastView(model))
    @test replay!(ref, U(100)) === DCM.Applied
    @test replay!(fast, U(100)) === DCM.Applied
    @test projection(ref) == projection(fast)
    cp = controller_projection(fast.state.controller)
    @test cp.active_range == 100 && cp.causal_slot == 10
    @test cp.proposals == [(U(100), U(0), U(20), U(200))]
    @test cp.agenda == cp.proposals && isempty(cp.activations)
    @test cp.seals[1].observed == 5
    @test cp.seals[1].events == [(U(100), U(i)) for i in 1:5]
    @test cp.seals[1].input_range == 100 && cp.seals[1].output_range == 200
    @test cp.seals[1].code === RCE.StepScheduled
    before = projection(fast)
    @test range_at(fast.state.controller, U(19)) == 100
    @test range_at(fast.state.controller, U(20)) == 200
    @test range_at(fast.state.controller, U(21)) == 200
    @test projection(fast) == before
end

@testset "recepciones antes/en/después y órdenes comunes" begin
    # Slots elegidos del fixture, no reloj/latencia de una red simulada.
    # La evidencia se entrega al observador en cada recepción etiquetada; replay
    # usa siempre el CloseFrame objetivo y nunca esta etiqueta local.
    for policy in (DCM.P0, DCM.P1), rounding in (RCE.RoundFloor, RCE.RoundNearestEven)
        model = manual_model(; policy, rounding)
        baseline = deliver_all!(ReferenceView(model, "baseline"))
        @test replay!(baseline, U(100)) === DCM.Applied
        for reception_slot in U[9,10,19,20,21]
            delayed = FastView(model, "receipt_$reception_slot")
            for bid in U[6,5,4,3,2,1]
                @test deliver_header!(delayed, bid)
            end
            @test replay!(delayed, U(100)) === DCM.Pending
            @test isempty(delayed.state.controller.seals)
            for bid in U[5,3,1,4,2] # cuerpo de la copia perdedora 6 ausente
                @test deliver_body!(delayed, bid, true)
                @test deliver_context!(delayed, U(100), bid, true)
            end
            @test replay!(delayed, U(100)) === DCM.Applied
            @test projection(delayed) == projection(baseline)
            @test range_at(delayed.state.controller, U(21)) == 200
            negative = negative_local_control(model, model.frames[U(100)],
                delayed.state.dcm.public.counted[U(700)], reception_slot, U(21))
            @test negative.local_seal_slot == max(U(10), reception_slot)
            @test negative.code === (reception_slot < 20 ? RCE.StepScheduled : RCE.StepMissedUpdate)
            @test negative.active_range == (reception_slot < 20 ? 200 : 100)
        end
    end
end

@testset "ganador requerido, alternativa completa y reunión" begin
    model = manual_model()
    for View in (ReferenceView, FastView)
        ana = deliver_all!(View(model, "Ana"); missing_bodies=Set(U[6]))
        bruno = deliver_all!(View(model, "Bruno"); missing_bodies=Set(U[1]))
        @test replay!(ana, U(100)) === DCM.Applied
        before = public_projection(bruno)
        @test replay!(bruno, U(100)) === DCM.Pending
        @test public_projection(bruno) == before
        @test bruno.pending == 100
        @test replay!(bruno, U(200)) === DCM.Applied
        @test bruno.state.controller.seals[1].observed == 5
        @test controller_projection(bruno.state.controller).proposals[1][1] == 200
        @test deliver_body!(bruno, U(1), true)
        @test replay!(bruno, U(100)) === DCM.Applied
        @test projection(ana) == projection(bruno)
    end
end

@testset "reorg reconstruye fuentes agenda activaciones y prefijos" begin
    fixture = branch_model(2)
    ref = deliver_all!(ReferenceView(fixture.model))
    fast = deliver_all!(FastView(fixture.model))
    for target in U[fixture.target_a, fixture.target_b, 900, 0, fixture.target_a]
        @test replay!(ref, target) === DCM.Applied
        @test replay!(fast, target) === DCM.Applied
        @test projection(ref) == projection(fast)
        cp = controller_projection(fast.state.controller)
        if target == fixture.target_a || target == fixture.target_b
            first_h = target == fixture.target_a ? U(11001) : U(12001)
            @test cp.proposals == [(U(900),U(0),U(20),U(200)),
                                   (first_h,U(1),U(30),U(400)),
                                   (target,U(2),U(40),U(800))]
            @test cp.activations == cp.proposals[1:2]
            @test cp.agenda == cp.proposals[3:3]
            @test cp.active_range == 400
            @test range_at(fast.state.controller, U(19)) == 100
            @test range_at(fast.state.controller, U(20)) == 200
            @test range_at(fast.state.controller, U(29)) == 200
            @test range_at(fast.state.controller, U(30)) == 400
            @test range_at(fast.state.controller, U(40)) == 800
        elseif target == 900
            @test cp.active_range == 100 && isempty(cp.activations)
            @test cp.agenda == [(U(900),U(0),U(20),U(200))]
        else
            @test cp.active_range == 100
            @test isempty(cp.seals) && isempty(cp.proposals) && isempty(cp.activations)
            @test isempty(fast.state.dcm.undo)
        end
    end
end

@testset "Pending e Invalid de dos etapas no publican parcialmente" begin
    original = branch_model(2)
    cat = original.model.catalog
    truth = copy(cat.context_truth)
    truth[(U(12002),U(2002))] = false
    catalog = DCM.Catalog(collect(values(cat.blocks)), collect(values(cat.histories)); context_truth=truth)
    model = ArmModel(catalog, collect(values(original.model.frames)), 10, 0, original.model.controller)
    for View in (ReferenceView, FastView)
        view = deliver_all!(View(model); missing_bodies=Set(U[2002]),
                           missing_contexts=Set([(U(12002),U(2002))]))
        @test replay!(view, original.target_a) === DCM.Applied
        before = public_projection(view)
        @test replay!(view, original.target_b) === DCM.Pending
        @test public_projection(view) == before
        @test view.pending == 12002
        @test deliver_body!(view, U(2002), true)
        @test deliver_context!(view, U(12002), U(2002), false)
        @test replay!(view, original.target_b) === DCM.Invalid
        @test public_projection(view) == before
        @test view.pending == 0
    end
end

@testset "cierre objetivamente tardío y cero real distinto de Pending" begin
    for View in (ReferenceView, FastView)
        late = deliver_all!(View(manual_model(; causal_seal=U(21))))
        @test replay!(late, U(100)) === DCM.Applied
        @test late.state.controller.seals[1].code === RCE.StepMissedUpdate
        @test isempty(late.state.controller.proposals)
        @test range_at(late.state.controller, U(100)) == 100
        empty_catalog = DCM.Catalog(DCM.BlockSpec[], [DCM.HistorySpec(U(700),U(0),U(999),U[])])
        empty_model = ArmModel(empty_catalog, [CloseFrame(700,0,10)], 10, 0, ARM.test_controller())
        empty_view = View(empty_model)
        @test replay!(empty_view, U(700)) === DCM.Applied
        @test empty_view.state.controller.seals[1].observed == 0
        @test empty_view.state.controller.seals[1].code === RCE.StepHeldZero
        # Enmienda Z0 (2026-09-12): HeldZero no agenda; la activación registrada es 0.
        @test isempty(empty_view.state.controller.proposals)
        @test empty_view.state.controller.seals[1].activation_slot == 0
        pending_view = View(manual_model())
        @test replay!(pending_view, U(100)) === DCM.Pending
        @test isempty(pending_view.state.controller.seals)
        @test isempty(pending_view.state.dcm.public.counted)
    end
end

@testset "HeldZero no-op: ventana vacía no agenda y no revierte el rango" begin
    # Enmienda Z0 (2026-09-12). Fixture elegido ARM: W10, G0, delay2, N0=5 en sello10
    # y N1=0 en sello20; la cohorte 2 (sello40) también es vacía. RCE agenda 200@30;
    # HeldZero ya no agenda 100@40 ni 100@50, así que el rango no vuelve a caer a 100.
    blocks = [DCM.BlockSpec(U(i),U(i),U(70),U(i),DCM.Blue,U[]) for i in 1:5]
    histories = [DCM.HistorySpec(U(100),U(0),U(70),U[1,2,3,4,5]),
                 DCM.HistorySpec(U(200),U(100),U(80),U[]),
                 DCM.HistorySpec(U(300),U(200),U(90),U[])]
    truth = Dict((U(100),b.id) => true for b in blocks)
    cfg = RCE.ControllerConfig(100,10,1,1,1,2,2,1,1,1000,2,RCE.RoundFloor)
    model = ArmModel(DCM.Catalog(blocks,histories;context_truth=truth),
                     [CloseFrame(100,0,10),CloseFrame(200,1,20),CloseFrame(300,2,40)],10,0,cfg)
    ref = deliver_all!(ReferenceView(model))
    fast = deliver_all!(FastView(model))
    for view in (ref,fast)
        @test replay!(view,U(200)) === DCM.Applied
        cp = controller_projection(view.state.controller)
        @test cp.active_range == 100
        @test cp.proposals == [(U(100),U(0),U(30),U(200))]
        @test cp.seals[2].code === RCE.StepHeldZero
        @test cp.seals[2].activation_slot == 0
        @test range_at(view.state.controller,U(30)) == 200
        @test range_at(view.state.controller,U(39)) == 200
        @test range_at(view.state.controller,U(40)) == 200
        @test replay!(view,U(300)) === DCM.Applied
        after = controller_projection(view.state.controller)
        @test after.active_range == 200
        @test after.activations == after.proposals
        @test isempty(after.agenda)
        @test range_at(view.state.controller,U(35)) == 200
    end
    @test projection(ref) == projection(fast)
end

@testset "descriptor dominio fronteras y overflow rechazan sin publicar" begin
    original = branch_model(1)
    model = original.model
    @test_throws ArgumentError ArmModel(model.catalog, collect(values(model.frames)), 0, 0, model.controller)
    @test_throws ArgumentError ArmModel(model.catalog, CloseFrame[], 10, 0, model.controller)
    @test_throws ArgumentError ArmModel(model.catalog, [CloseFrame(999,0,10)], 10, 0, model.controller)
    @test_throws ArgumentError ArmModel(model.catalog, [collect(values(model.frames)); CloseFrame(900,0,10)],
                                        10, 0, model.controller)
    for (cohort, seal) in ((U(0),U(20)), (U(2),U(30)), (U(1),U(9)), (U(1),U(19)))
        frames = [h == original.target_b ? CloseFrame(h,cohort,seal) : frame for (h,frame) in model.frames]
        bad = ArmModel(model.catalog, frames, 10, 0, model.controller)
        for View in (ReferenceView, FastView)
            view = deliver_all!(View(bad))
            @test replay!(view, original.target_a) === DCM.Applied
            before = public_projection(view)
            @test replay!(view, original.target_b) === DCM.Invalid
            @test public_projection(view) == before
        end
    end
    one_catalog = DCM.Catalog(DCM.BlockSpec[], [DCM.HistorySpec(U(1),U(0),U(1),U[])])
    for (width,grace) in ((typemax(U),U(0)), (typemax(U),U(1)))
        bad = ArmModel(one_catalog, [CloseFrame(1,0,typemax(U))], width, grace, model.controller)
        for View in (ReferenceView, FastView)
            view = View(bad)
            before = public_projection(view)
            @test replay!(view, U(1)) === DCM.Invalid
            @test public_projection(view) == before
        end
    end
    @test_throws OverflowError ARM.cutoff(model, CloseFrame(U(900),typemax(U),typemax(U)))
    for View in (ReferenceView, FastView)
        view = deliver_all!(View(model))
        @test replay!(view, original.target_a) === DCM.Applied
        before = public_projection(view)
        @test replay!(view, U(999999)) === DCM.Invalid
        @test public_projection(view) == before
    end
end

@testset "semilla obligatoria sin RNG implícito" begin
    @test parse_seed(["--seed", "20260911"]) == U(20260911)
    @test parse_seed(["--seed", "0"]) == U(0)
    @test_throws ArgumentError parse_seed(String[])
    @test_throws ArgumentError parse_seed(["--seed", "-1"])
    @test_throws ArgumentError parse_seed(["--seed", "+1"])
    @test_throws ArgumentError parse_seed(["--seed", "1", "EXTRA"])
end

println("model=ARM-v0.1 seed=$SEED rng=none acceptance=exact_composition")
