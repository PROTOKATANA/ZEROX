using Test
using VentanaRetargetCausal

const ROOT = normpath(joinpath(@__DIR__, ".."))
const FIXTURES = joinpath(ROOT, "fixtures", "CASOS.txt")

@testset "fixtures compartidos" begin
    ref = execute_fixtures(FIXTURES; engine=apply_reference)
    fast = execute_fixtures(FIXTURES; engine=apply_fast)
    @test ref == fast
    @test ref.cases == 7
    @test ref.assertions > 50
end

@testset "contrato de ventanas" begin
    @test_throws ArgumentError WindowSpec(0, 0, 0)
    @test_throws ArgumentError WindowSpec(1, 4, 0)
    @test_throws OverflowError WindowSpec(0, typemax(UInt64), 1)

    spec = WindowSpec(0, 4, 2)
    lg = Scenario(P0, LGRule(), spec)
    at_cutoff = Batch(1, 0, 6, [Candidate(1, 1, 3, 0, Blue, Complete, 1, 0)])
    result = apply_fast(State(), at_cutoff, lg)
    @test result.code === Applied
    @test isempty(result.state.journal) # LG usa incorporation < cutoff.

    state = State()
    state.context_id = 1
    state.context_slot = 6
    @test_throws ArgumentError close_window!(state, spec, 0, 7)
    @test_throws ArgumentError close_window!(state, spec, 1, 6)
    @test causal_sufficient(Scenario(P0, L0Rule(2), spec))
    @test !causal_sufficient(Scenario(P0, L0Rule(3), spec))
    @test causal_sufficient(Scenario(P0, LGRule(), spec))
end

@testset "selección, identidad y journal" begin
    spec = WindowSpec(0, 8, 2)
    blocks = [
        Candidate(10, 90, 2, 0, RedK, Complete, 0, 0),
        Candidate(11, 90, 2, 1, Blue, Complete, 5, 3),
        Candidate(12, 91, 2, 2, RedU3, Complete, 8, 1),
    ]
    batch = Batch(1, 0, 5, blocks)
    p0 = apply_fast(State(), batch, Scenario(P0, LGRule(), spec))
    p1 = apply_fast(State(), batch, Scenario(P1, LGRule(), spec))
    @test p0.winners == [10]
    @test p1.winners == [11]
    @test counted_ids(p0.state, 0) == payable_ids(p0.state, 0) == [EventId(1, 10)]
    @test p0.state.journal[1].subsidy == 0 # cero también consume y cuenta

    mismatch = Batch(1, 0, 3, [
        Candidate(20, 100, 1, 0, Blue, Complete, 1, 0),
        Candidate(21, 100, 2, 1, Blue, Complete, 1, 0),
    ])
    bad = apply_fast(State(), mismatch, Scenario(P0, LGRule(), spec))
    @test bad.code === Invalid
    @test bad.reason === :ticket_slot_mismatch
end

@testset "pending, sellado y undo" begin
    spec = WindowSpec(0, 4, 0)
    scenario = Scenario(P0, L0Rule(4), spec)
    state = State()
    first = apply_fast(state, Batch(1, 0, 4, Candidate[]), scenario)
    @test first.code === Applied
    pending_batch = Batch(2, 1, 4,
        [Candidate(30, 300, 1, 0, Blue, PendingData, 1, 0)])
    pending = apply_fast(first.state, pending_batch, scenario)
    @test pending.code === Pending
    query = close_window!(first.state, spec, 0, 4; pending_batches=[pending_batch])
    @test query.code === ControllerPending
    @test !haskey(first.state.sealed_windows, 0)

    ready = close_window!(first.state, spec, 0, 4)
    @test ready.code === Ready
    late = Batch(2, 1, 4, [Candidate(31, 301, 0, 0, Blue, Complete, 1, 0)])
    applied = apply_fast(first.state, late, scenario)
    @test applied.code === Applied
    @test applied.winners == [31]
    @test counted_ids(applied.state, 0) == EventId[]
    @test payable_ids(applied.state, 0) == [EventId(2, 31)]
    @test 31 in applied.state.seen_blocks

    undo!(applied.state, applied.undo_state)
    @test applied.state.context_id == 1
    @test haskey(applied.state.sealed_windows, 0) # el sello precedía a contexto 2
    @test_throws ArgumentError undo!(applied.state, applied.undo_state)
end

@testset "equivalencia referencia/kernel" begin
    spec = WindowSpec(0, 16, 3)
    for selection in (P0, P1), late in (L0Rule(5), LGRule()), n in 0:24
        blocks = Candidate[]
        for i in 1:n
            ticket = UInt64(1 + (i % 7))
            slot = UInt64(ticket % 5)
            color = i % 5 == 0 ? RedU3 : i % 2 == 0 ? Blue : RedK
            push!(blocks, Candidate(UInt64(i), ticket, slot, UInt64(i), color,
                                    Complete, UInt64(i % 3), UInt64(i % 2)))
        end
        batch = Batch(1, 0, 8, blocks)
        @test validate_equivalence(State(), batch, Scenario(selection, late, spec))
    end
end
