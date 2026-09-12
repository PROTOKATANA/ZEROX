using BenchmarkTools
using ComprobacionDecisiva

function report_trial(profile, engine, depth, trial)
    m = median(trial)
    println("profile=$profile engine=$engine branch_depth=$depth median_ns=$(m.time) " *
            "bytes=$(m.memory) allocs=$(m.allocs) samples=$(length(trial))")
end

function main(args::Vector{String})
    seed = parse_seed(args)
    println("model=comprobacion-decisiva-v1 seed=$seed rng=none threads=$(Threads.nthreads())")
    for depth in (8, 16, 32)
        fixture = fixture_rama(depth)
        objetivo, respaldo = fixture.objetivo, fixture.respaldo
        prepared_ref = entregar_todo!(ReferenceNode(fixture.modelo, "ref",
            DeliveryEvent[], objetivo, respaldo))
        prepared_fast = entregar_todo!(FastNode(fixture.modelo, "fast",
            DeliveryEvent[], objetivo, respaldo))
        ref_a, fast_a = deepcopy(prepared_ref), deepcopy(prepared_fast)
        first_ref = @elapsed replay!(ref_a, objetivo)
        first_fast = @elapsed replay!(fast_a, objetivo)
        proyeccion_nodo(ref_a) == proyeccion_nodo(fast_a) ||
            error("genesis reference mismatch")
        println("branch_depth=$depth first_reference_wall_s_including_compile=$first_ref " *
                "first_fast_wall_s_including_compile=$first_fast")
        reference = @benchmark replay!(v, $objetivo) setup=(v=deepcopy($prepared_ref)) samples=10 evals=1
        fast = @benchmark replay!(v, $objetivo) setup=(v=deepcopy($prepared_fast)) samples=10 evals=1
        report_trial("from_genesis", "BigInt_reference", depth, reference)
        report_trial("from_genesis", "UInt128_replay", depth, fast)
        check_ref, check_fast = deepcopy(ref_a), deepcopy(fast_a)
        replay!(check_ref, respaldo) === DCM.Applied || error("reference reorg")
        replay!(check_fast, respaldo) === DCM.Applied || error("fast reorg")
        proyeccion_nodo(check_ref) == proyeccion_nodo(check_fast) ||
            error("reorg reference mismatch")
        reorg_ref = @benchmark replay!(v, $respaldo) setup=(v=deepcopy($ref_a)) samples=10 evals=1
        reorg_fast = @benchmark replay!(v, $respaldo) setup=(v=deepcopy($fast_a)) samples=10 evals=1
        report_trial("reorg", "BigInt_reference", depth, reorg_ref)
        report_trial("reorg", "UInt128_replay", depth, reorg_fast)
    end
end

main(ARGS)
