# DCM-v0.1: regresiones exactas, sin RNG ni tolerancias.
# Presupuesto de esta revisión: 1 hilo CPU, 4 GiB RAM, 512 MiB nuevos, 20 min.
# El oráculo pequeño enumera 2^(3^2)*3^3 = 13_824 entradas; usa alcanzabilidad
# de Floyd-Warshall O(3^3) por entrada, independiente del Kahn del instrumento.

const DCM = DisponibilidadCausalMultivista

function evidence_projection(view)
    return (headers=copy(view.headers), good=copy(view.good), rejected=copy(view.rejected),
            invalid=copy(view.invalid), context_good=deepcopy(view.context_good),
            context_invalid=deepcopy(view.context_invalid), state=projection(view))
end

@testset "parser fail-closed y EXPECT canónico" begin
    valid = """
    CASE minimo P0
    BLOCK 1 1 7 1 B -
    BLOCK 2 1 7 2 R -
    HISTORY 100 - 7 1,2
    BODY_TRUTH 1 COMPLETE
    BODY_TRUTH 2 COMPLETE
    CONTEXT_TRUTH 100 1 VALID
    VIEW V
    HEADER V 1
    HEADER V 2
    BODY V 1 COMPLETE
    CONTEXT V 100 1 VALID
    APPLY V 100 Applied
    EXPECT V 100 100:1 7=100:1 7=100:1 100:7:2 1 -
    END
    """
    @test execute_fixture(IOBuffer(valid)) == (cases=1, assertions=4)
    # Los mismos seis mutantes de control del arnés Rust.
    mutants = (
        replace(valid, "VIEW V\n" => "CASE anidado P0\nVIEW V\n"),
        "HEADER V 1\n" * valid,
        valid * "CASE sin_cierre P0\n",
        replace(valid, "VIEW V\n" => "VIEW V EXTRA\n"),
        replace(valid, "END\n" => "END EXTRA\n"),
        replace(valid, "HEADER V 1\n" => "BLOCK 3 3 7 3 B -\nHEADER V 1\n"),
        replace(valid, "CASE minimo P0\n" => ""),
        valid * "END\n",
        replace(valid, "VIEW V\n" => "VIEW V\nVIEW V\n"),
        replace(valid, "VIEW V\n" => "VIEW V\nUNKNOWN\n"),
        replace(valid, "VIEW V\n" => "VIEW V\nHISTORY 777 - 7 -\n"),
        replace(valid, "VIEW V\n" => "VIEW V\nBODY_TRUTH 777 COMPLETE\n"),
        replace(valid, "VIEW V\n" => "VIEW V\nCONTEXT_TRUTH 100 2 VALID\n"),
    )
    for mutant in mutants
        @test_throws ErrorException execute_fixture(IOBuffer(mutant))
    end
    for empty in ("", " \n# sólo comentario\n", "CASE vacio P0\nEND\n",
                  "CASE vacio P0\nVIEW Ana\nEND\n")
        @test_throws ErrorException execute_fixture(IOBuffer(empty))
    end
    @test_throws ErrorException execute_fixture(IOBuffer(
        replace(valid, "100:1" => "100:1:EXTRA")))
    @test_throws ErrorException execute_fixture(IOBuffer(
        replace(valid, "100:7:2" => "100:7:2:EXTRA")))
    for malformed in ("", "100", "100:", ":1", "100:1:", "100:1,", "100:1,100:1")
        @test_throws ErrorException DCM.parse_events(malformed)
    end
    for malformed in ("", "100:7", "100:7:", "100::2", ":7:2", "100:7:2,",
                      "100:7:2,100:7:2")
        @test_throws ErrorException DCM.parse_inert(malformed)
    end
    for malformed in ("", "7", "7=", "=100:1", "7=100:1=EXTRA", "7=100:1/7=100:2")
        @test_throws ErrorException DCM.parse_snapshots(malformed)
    end
    @test isempty(DCM.parse_events("-"))
    @test isempty(DCM.parse_inert("-"))
    @test isempty(DCM.parse_snapshots("-"))
    @test DCM.parse_snapshots("7=-") == [(U(7), Tuple{U,U}[])]
    @test_throws ErrorException execute_fixture(IOBuffer(
        replace(valid, "100:7:2 1 -" => "100:7:2 1,1 -")))
    @test_throws ErrorException execute_fixture(IOBuffer(
        replace(valid, "100:7:2 1 -" => "100:7:2 1 0")))
    @test_throws ErrorException execute_fixture(IOBuffer(
        replace(valid, "100:7:2 1 -" => "100:7:2 1 00")))
    for malformed in ("+1", "-0", "0x1", "", "١", " 1")
        @test_throws ErrorException DCM.parse_u(malformed)
    end
    @test DCM.parse_u("0001") == U(1)
    @test DCM.parse_u("18446744073709551615") == typemax(U)
    @test_throws Exception DCM.parse_u("18446744073709551616")
    # PolicyMismatch es un error local de API; no un veredicto de historia del fixture.
    @test_throws ErrorException DCM.parse_outcome("PolicyMismatch")
end

@testset "política fijada en la vista sin mutación por mismatch" begin
    blocks = [BlockSpec(U(1), U(1), U(7), U(1), RedK, U[]),
              BlockSpec(U(2), U(1), U(7), U(2), Blue, U[]),
              BlockSpec(U(3), U(3), U(8), U(3), Blue, U[]),
              BlockSpec(U(4), U(4), U(9), U(4), Blue, U[]),
              BlockSpec(U(5), U(5), U(10), U(5), Blue, U[])]
    histories = [HistorySpec(U(100), U(0), U(7), U[1,2]),
                 HistorySpec(U(200), U(100), U(8), U[3]),
                 HistorySpec(U(300), U(100), U(9), U[4]),
                 HistorySpec(U(400), U(200), U(10), U[5])]
    truth = Dict((h.id,b.id) => true for h in histories for b in blocks)
    cat = Catalog(blocks, histories; context_truth=truth)
    for (View, apply, replay, undo) in (
        (RefView, apply_reference!, replay_reference!, undo_reference!),
        (FastView, apply_fast!, replay_fast!, undo_fast!),
    ), policy in (P0, P1)
        view = View("policy", cat; policy)
        other = policy === P0 ? P1 : P0
        @test projection(view).policy === policy
        @test_throws ErrorException setproperty!(view, :policy, other)
        for b in blocks
            @test deliver_header!(view, b.id)
            b.id == 5 || @test deliver_body!(view, b.id, true)
        end
        for ((hid,bid), value) in truth
            @test deliver_context!(view, hid, bid, value)
        end
        initial = evidence_projection(view)
        @test apply(view, cat, U(100), other) === PolicyMismatch
        @test replay(view, cat, U(0), other) === PolicyMismatch
        @test evidence_projection(view) == initial
        @test apply(view, cat, U(100), policy) === Applied
        winner = policy === P0 ? U(1) : U(2)
        @test projection(view).public.journal == [(U(100), winner)]
        at_tip = evidence_projection(view)
        @test apply(view, cat, U(200), other) === PolicyMismatch
        @test replay(view, cat, U(100), other) === PolicyMismatch
        @test replay(view, cat, U(300), other) === PolicyMismatch
        @test replay(view, cat, U(0), other) === PolicyMismatch
        @test evidence_projection(view) == at_tip
        @test apply(view, cat, U(200), policy) === Applied
        @test apply(view, cat, U(400), policy) === Pending
        at_pending = evidence_projection(view)
        @test apply(view, cat, U(999), other) === PolicyMismatch
        @test replay(view, cat, U(300), other) === PolicyMismatch
        @test replay(view, cat, U(0), other) === PolicyMismatch
        @test evidence_projection(view) == at_pending
        @test undo(view, U(200)) === Applied
        @test view.policy === policy
        @test replay(view, cat, U(0), policy) === Applied
        @test projection(view).public.current == 0 && view.policy === policy
        @test replay(view, cat, U(300), policy) === Applied
        @test projection(view).public.journal == [(U(100), winner), (U(300), U(4))]
        @test view.policy === policy
    end
end

@testset "verdad contextual explícita y owned" begin
    blocks = [BlockSpec(U(1), U(1), U(7), U(1), Blue, U[]),
              BlockSpec(U(2), U(2), U(7), U(2), Blue, U[])]
    histories = [HistorySpec(U(100), U(0), U(7), U[1,2])]
    truth = Dict((U(100), U(1)) => true, (U(100), U(2)) => false)
    cat = Catalog(blocks, histories; context_truth=truth)
    truth[(U(100), U(1))] = false
    @test cat.context_truth[(U(100), U(1))]
    unknown_truth = Dict((U(999), U(1)) => true)
    @test_throws ArgumentError Catalog(blocks, histories; context_truth=unknown_truth)
    @test_throws ArgumentError Catalog(blocks, histories;
        context_truth=Dict((U(100), U(999)) => false))
    absent = Catalog(blocks, histories)
    for View in (RefView, FastView)
        view = View("declared", cat)
        @test deliver_context!(view, U(100), U(1), true)
        @test deliver_context!(view, U(100), U(2), false)
        before = evidence_projection(view)
        @test !deliver_context!(view, U(100), U(1), false)
        @test !deliver_context!(view, U(100), U(2), true)
        @test evidence_projection(view) == before
        without_truth = View("absent", absent)
        before_absent = evidence_projection(without_truth)
        @test !deliver_context!(without_truth, U(100), U(1), true)
        @test !deliver_context!(without_truth, U(100), U(1), false)
        @test evidence_projection(without_truth) == before_absent
    end
end

@testset "rechazos reparables y BodyInvalid coherentes" begin
    cat = Catalog([BlockSpec(U(1), U(1), U(7), U(1), Blue, U[])], HistorySpec[];
                  invalid_bodies=Set(U[1]))
    for View in (RefView, FastView)
        view = View("invalid", cat)
        @test deliver_body!(view, U(1), false)
        @test !isempty(view.rejected)
        @test deliver_invalid_body!(view, U(1))
        @test isempty(view.rejected)
        @test deliver_body!(view, U(1), false)
        @test isempty(view.rejected)
        @test !deliver_body!(view, U(1), true)
        @test !isempty(view.invalid) && isempty(view.good)
    end
end

@testset "dominio de ceros por tipo de ID" begin
    block = BlockSpec(U(1), U(1), U(0), U(0), Blue, U[])
    history = HistorySpec(U(1), U(0), U(0), U[1])
    @test_throws ArgumentError Catalog(
        [BlockSpec(U(0), U(1), U(0), U(0), Blue, U[])], [history])
    @test_throws ArgumentError Catalog(
        [BlockSpec(U(1), U(0), U(0), U(0), Blue, U[])], [history])
    @test_throws ArgumentError Catalog([block], [HistorySpec(U(0), U(0), U(0), U[1])])
    cat = Catalog([block], [history]; context_truth=Dict((U(1), U(1)) => true))
    for (View, apply, replay, undo) in (
        (RefView, apply_reference!, replay_reference!, undo_reference!),
        (FastView, apply_fast!, replay_fast!, undo_fast!),
    )
        view = View("zero", cat)
        before = evidence_projection(view)
        @test !deliver_header!(view, U(0))
        @test !deliver_body!(view, U(0), true)
        @test !deliver_invalid_body!(view, U(0))
        @test !deliver_context!(view, U(0), U(1), true)
        @test !deliver_context!(view, U(1), U(0), true)
        @test evidence_projection(view) == before
        @test deliver_header!(view, U(1))
        @test deliver_body!(view, U(1), true)
        @test deliver_context!(view, U(1), U(1), true)
        @test apply(view, cat, U(1), P0) === Applied
        @test projection(view).public.counted == [(U(0), [(U(1), U(1))])]
        @test undo(view, U(1)) === Applied
        @test replay(view, cat, U(0), P0) === Applied
    end
end

function structural_reachability_oracle(adjacency::Matrix{Bool}, stages::Vector{Int})
    included = stages .> 0
    for child in 1:3, parent in 1:3
        included[child] || continue
        if adjacency[child, parent]
            included[parent] || return false
            stages[parent] <= stages[child] || return false
        end
    end
    reach = copy(adjacency)
    for k in 1:3, i in 1:3, j in 1:3
        included[i] && included[j] && included[k] || continue
        reach[i,j] |= reach[i,k] && reach[k,j]
    end
    return !any(included[i] && reach[i,i] for i in 1:3)
end

@testset "oráculo estructural independiente exhaustivo n=3" begin
    for edge_bits in 0:511, placement in 0:26
        stages = [mod(div(placement, 3^(i-1)),3) for i in 1:3]
        adjacency = [((edge_bits >> ((i-1)*3+j-1)) & 1) == 1 for i in 1:3, j in 1:3]
        blocks = [BlockSpec(U(i), U(i), stages[i] == 2 ? U(20) : U(10), U(i), Blue,
                           U[j for j in 1:3 if adjacency[i,j]]) for i in 1:3]
        histories = [HistorySpec(U(900), U(0), U(10), U[i for i in 1:3 if stages[i] == 1]),
                     HistorySpec(U(2), U(900), U(20), U[i for i in 1:3 if stages[i] == 2])]
        cat = Catalog(blocks, histories)
        @test DCM.history_structure_valid(cat, U(2)) == structural_reachability_oracle(adjacency, stages)
    end
end

@testset "replay de dos etapas Pending e Invalid es atómico" begin
    blocks = [BlockSpec(U(1),U(1),U(1),U(1),Blue,U[]),
              BlockSpec(U(2),U(2),U(2),U(2),Blue,U[1]),
              BlockSpec(U(3),U(3),U(3),U(3),Blue,U[1]),
              BlockSpec(U(4),U(4),U(4),U(4),Blue,U[3])]
    histories = [HistorySpec(U(10),U(0),U(1),U[1]),
                 HistorySpec(U(20),U(10),U(2),U[2]),
                 HistorySpec(U(30),U(10),U(3),U[3]),
                 HistorySpec(U(40),U(30),U(4),U[4])]
    truth = Dict((h.id,b.id) => (h.id,b.id) != (U(40),U(4)) for h in histories for b in blocks)
    cat = Catalog(blocks, histories; context_truth=truth)
    for (view, apply, replay) in ((RefView("R",cat),apply_reference!,replay_reference!),
                                  (FastView("F",cat),apply_fast!,replay_fast!))
        for b in blocks
            @test deliver_header!(view,b.id)
            b.id != 4 && deliver_body!(view,b.id,true)
        end
        for ((hid,bid), valid) in truth
            valid && deliver_context!(view,hid,bid,true)
        end
        @test apply(view,cat,U(10),P0) === Applied
        @test apply(view,cat,U(20),P0) === Applied
        before = projection(view)
        @test replay(view,cat,U(40),P0) === Pending
        after_pending = projection(view)
        @test before.public == after_pending.public && before.undo == after_pending.undo
        @test after_pending.pending == 40
        @test deliver_body!(view,U(4),true)
        @test deliver_context!(view,U(40),U(4),false)
        @test replay(view,cat,U(40),P0) === Invalid
        after_invalid = projection(view)
        @test before.public == after_invalid.public && before.undo == after_invalid.undo
        @test after_invalid.pending == 0
    end
end
