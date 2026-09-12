using Test
using RetargetCausalEndogeno

const ROOT = normpath(joinpath(@__DIR__, ".."))
const U = UInt64

function controller(; target=10, gain_num=1, gain_den=1, delay=1,
                    rounding=RoundNearestEven)
    ControllerConfig(300, target, gain_num, gain_den, 1, 2, 2, 1,
                     10, 900, delay, rounding)
end

function scenario(label, selection, late; target=10, admission=2)
    Scenario(label, U(240), U(20), U(3), U(admission), selection, late, U(1024),
             U(2), U(1), U(3), U(5), U(4), U(11), U(2), U(3), controller(target=target))
end

@testset "fixtures de controlador" begin
    result = execute_fixtures(joinpath(ROOT, "fixtures", "CONTROLADOR.txt"))
    @test result == (cases=10, assertions=20)
end

@testset "aritmética exacta" begin
    for mode in (RoundFloor, RoundNearestEven), current in U(1):U(80), observed in U(1):U(80)
        cfg = ControllerConfig(current, 23, 1, 2, 1, 4, 4, 1, 1, 1000, 2, mode)
        @test next_range_fast(current, observed, cfg) ==
              next_range_reference(current, observed, cfg)
    end
    @test_throws ArgumentError ControllerConfig(10, 1, 1, 2, 2, 1, 2, 1, 1, 100, 1, RoundFloor)
    @test_throws ArgumentError ControllerConfig(10, 1, 1, 2, 1, 2, 1, 2, 1, 100, 1, RoundFloor)
    @test_throws ArgumentError ControllerConfig(10, 1, 1, 2, 1, 2, 2, 1, 1,
                                                typemax(UInt64), 1, RoundFloor)
end

@testset "activación y Pending" begin
    cfg = controller()
    @test causal_step(300, nothing, 23, 23, 20, cfg) ==
          (StepPending, U(300), U(0), false)
    # Enmienda Z0 (2026-09-12): HeldZero es no-op; la activación pasa de 40 a 0 para
    # que ningún llamante pueda agendar la propuesta.
    @test causal_step(300, U(0), 23, 23, 20, cfg) ==
          (StepHeldZero, U(300), U(0), false)
    # Regresión del vector que motivó la enmienda (delay_windows=2, ventana vacía no Missed).
    cfg_delay2 = ControllerConfig(100, 10, 1, 1, 1, 2, 2, 1, 1, 1000, 2, RoundFloor)
    @test causal_step(100, U(0), 20, 20, 10, cfg_delay2) ==
          (StepHeldZero, U(100), U(0), false)
    @test causal_step(300, U(10), 23, 40, 20, cfg)[1] === StepMissedUpdate
    @test causal_step(300, U(10), 23, 39, 20, cfg)[1] === StepScheduled
    @test_throws ArgumentError causal_step(300, U(10), 23, 22, 20, cfg)
    @test_throws ArgumentError causal_step(300, nothing, 23, 22, 20, cfg)
    @test_throws ArgumentError causal_step(300, nothing, 23, 23, 0, cfg)
end

@testset "borde intr-slot de cuerpo" begin
    p = RetargetCausalEndogeno.Produced(U(1), U(1), U(0), U(0), U(3), U(5), true, true)
    batch = [p]
    @test RetargetCausalEndogeno.closure_has_unresolved(batch, U(5))
    @test RetargetCausalEndogeno.ref_closure_has_unresolved(batch, U(5))
    @test !RetargetCausalEndogeno.closure_has_unresolved(batch, U(6))
    @test !RetargetCausalEndogeno.ref_closure_has_unresolved(batch, U(6))
end

@testset "simulación endógena comparable" begin
    trace = generate_trace(U(20260911), U(240), U(2), U(1))
    variants = [scenario("P0-L0", P0, L0), scenario("P1-L0", P1, L0),
                scenario("P0-LG", P0, LG), scenario("P1-LG", P1, LG)]
    results = SimulationMetrics[]
    for s in variants
        @test validate_equivalence(trace, s)
        m = simulate_fast(trace, s)
        push!(results, m)
        @test m.reversal_after_acceptance.reason === :no_branch_model
        @test m.observer_disagreement.reason === :single_observer_model
        @test m.network_service_queue.reason === :scheduled_deliveries_not_service_queue
        @test m.payments_never_accepted <= m.payments_originated
    end
    @test any(m -> m.final_range != m.ranges_by_slot[1], results)
    @test any(m -> m.pending_slots > 0, results)

    low = scenario("target-low", P0, LG; target=4)
    high = scenario("target-high", P0, LG; target=16)
    low_result = simulate_fast(trace, low)
    high_result = simulate_fast(trace, high)
    @test low_result.ranges_by_slot != high_result.ranges_by_slot
    @test low_result.final_range != high_result.final_range
    common_blocks = intersect(Set(e.block_id for e in low_result.events),
                              Set(e.block_id for e in high_result.events))
    low_ticket = Dict(e.block_id => e.ticket_id for e in low_result.events)
    high_ticket = Dict(e.block_id => e.ticket_id for e in high_result.events)
    @test !isempty(common_blocks)
    @test all(id -> low_ticket[id] == high_ticket[id], common_blocks)
    @test stable_opportunity_ids(low, true, U(17)) ==
          stable_opportunity_ids(high, true, U(17))
end

@testset "traza contraderivada y actores vacíos" begin
    t = generate_trace(U(9), U(8), U(3), U(0))
    @test length(t.honest) == 24
    @test isempty(t.adversary)
    @test length(unique(op.draw for op in t.honest)) == length(t.honest)
    t2 = generate_trace(U(9), U(8), U(0), U(2))
    @test isempty(t2.honest)
    @test length(t2.adversary) == 16
end

@testset "retención de cuerpo adversaria DA0" begin
    cfg = controller()
    clear = Scenario("body-clear", U(80), U(10), U(2), U(2), P0, LG, U(1024),
        U(0), U(1), U(0), U(0), U(0), U(0), U(0), U(0), cfg)
    held = Scenario("body-held", U(80), U(10), U(2), U(2), P0, LG, U(1024),
        U(0), U(1), U(0), U(0), U(4), U(0), U(0), U(0), cfg)
    trace = generate_trace(U(123), U(80), U(0), U(1))
    @test validate_equivalence(trace, clear)
    @test validate_equivalence(trace, held)
    mc = simulate_fast(trace, clear)
    mh = simulate_fast(trace, held)
    @test mh.pending_slots > mc.pending_slots
    @test mh.max_no_event_progress > mc.max_no_event_progress
    @test mh.max_pending_headers > mc.max_pending_headers
end

@testset "exclusión y reinclusión observables" begin
    trace = generate_trace(U(77), U(240), U(2), U(1))
    strict = scenario("L0-estricto", P0, L0; admission=0)
    m = simulate_fast(trace, strict)
    @test m.honest_excluded > 0
    @test m.reincluded <= m.honest_excluded
    @test m.payments_never_accepted > 0
end
