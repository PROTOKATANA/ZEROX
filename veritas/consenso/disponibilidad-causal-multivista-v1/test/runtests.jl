using Test
using DisponibilidadCausalMultivista

const ROOT = normpath(joinpath(@__DIR__, ".."))
const U = UInt64

apply_reference_or_fast!(v::RefView, c, h, p) = apply_reference!(v, c, h, p)
apply_reference_or_fast!(v::FastView, c, h, p) = apply_fast!(v, c, h, p)

@testset "fixtures multivista" begin
    @test execute_fixture(joinpath(ROOT, "fixtures", "CASOS.txt")) ==
          (cases=12, assertions=118)
end

@testset "evidencia monotónica y contradicciones" begin
    cat = Catalog([BlockSpec(U(1), U(1), U(1), U(1), Blue, U[]),
                   BlockSpec(U(2), U(2), U(1), U(2), Blue, U[])], HistorySpec[];
                  invalid_bodies=Set(U[2]))
    for view in (RefView("R", cat), FastView("F", cat))
        @test deliver_body!(view, U(1), false)
        @test deliver_body!(view, U(1), true)
        @test deliver_body!(view, U(1), false) # corrupto posterior no degrada COMPLETE
        @test !deliver_invalid_body!(view, U(1))
        @test deliver_invalid_body!(view, U(2))
        @test !deliver_body!(view, U(2), true)
    end
end

@testset "catálogo owned y dominio BitSet" begin
    parents = U[1]
    b1 = BlockSpec(U(1), U(1), U(1), U(1), Blue, U[])
    b2 = BlockSpec(U(2), U(2), U(1), U(2), Blue, parents)
    hblocks = U[1, 2]
    cat = Catalog([b1, b2], [HistorySpec(U(1), U(0), U(1), hblocks)])
    parents[1] = U(99); hblocks[1] = U(99)
    @test cat.blocks[U(2)].parents == U[1]
    @test cat.histories[U(1)].blocks == U[1, 2]
    sparse = Catalog([BlockSpec(U(1), U(3), U(2), U(1), Blue, U[]),
                      BlockSpec(typemax(U), U(4), U(2), U(2), Blue, U[])], HistorySpec[])
    fast = FastView("sparse", sparse)
    @test deliver_header!(fast, typemax(U))
    @test collect(fast.headers) == [2]
end

@testset "Pending obsoleto se limpia con Invalid" begin
    cat = Catalog([BlockSpec(U(1), U(1), U(1), U(1), Blue, U[])],
                  [HistorySpec(U(5), U(0), U(1), U[1])]; invalid_bodies=Set(U[1]))
    for view in (RefView("R", cat), FastView("F", cat))
        deliver_header!(view, U(1))
        @test apply_reference_or_fast!(view, cat, U(5), P0) === Pending
        deliver_invalid_body!(view, U(1))
        @test apply_reference_or_fast!(view, cat, U(5), P0) === Invalid
        @test projection(view).pending == 0
    end
end


@testset "verdad objetiva entre observadores" begin
    cat = Catalog([BlockSpec(U(1), U(1), U(1), U(1), Blue, U[])],
                  [HistorySpec(U(5), U(0), U(1), U[1])];
                  context_truth=Dict((U(5), U(1)) => false))
    for make in (name -> RefView(name, cat), name -> FastView(name, cat))
        ana = make("Ana"); bruno = make("Bruno")
        @test !deliver_context!(ana, U(5), U(1), true)
        @test deliver_context!(bruno, U(5), U(1), false)
        @test !deliver_invalid_body!(ana, U(1))
        @test deliver_body!(bruno, U(1), true)
    end
end

include("regresiones.jl")

@testset "IDs desconocidos no mutan evidencia" begin
    cat = Catalog([BlockSpec(U(1), U(1), U(1), U(1), Blue, U[])],
                  [HistorySpec(U(5), U(0), U(1), U[1])])
    ref = RefView("R", cat); fast = FastView("F", cat)
    for view in (ref, fast)
        @test !deliver_header!(view, U(99))
        @test !deliver_body!(view, U(99), true)
        @test !deliver_invalid_body!(view, U(99))
        @test !deliver_context!(view, U(99), U(1), true)
        @test !deliver_context!(view, U(5), U(99), true)
    end
    @test isempty(ref.headers) && isempty(ref.good) && isempty(ref.invalid) &&
          isempty(ref.context_good) && isempty(ref.context_invalid)
    @test isempty(fast.headers) && isempty(fast.good) && isempty(fast.invalid) &&
          isempty(fast.context_good) && isempty(fast.context_invalid)
end

@testset "tokens de evidencia cerrados" begin
    @test_throws ErrorException DisponibilidadCausalMultivista.parse_body_token("GOOD")
    @test_throws ErrorException DisponibilidadCausalMultivista.parse_body_token("CORRUPT")
    @test_throws ErrorException DisponibilidadCausalMultivista.parse_context_token("MAYBE")
    blocks = [BlockSpec(U(1), U(1), U(1), U(1), Blue, U[])]
    histories = [HistorySpec(U(5), U(0), U(1), U[1])]
    @test DisponibilidadCausalMultivista.truth_keys_known(
        blocks, histories, Dict((U(5), U(1)) => true))
    @test !DisponibilidadCausalMultivista.truth_keys_known(
        blocks, histories, Dict((U(99), U(1)) => true))
    @test !DisponibilidadCausalMultivista.truth_keys_known(
        blocks, histories, Dict((U(5), U(99)) => false))
end
