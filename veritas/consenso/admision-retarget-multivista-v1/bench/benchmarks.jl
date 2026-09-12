using BenchmarkTools
using AdmisionRetargetMultivista

function report_trial(profile, engine, depth, trial)
    m = median(trial)
    println("profile=$profile engine=$engine branch_depth=$depth median_ns=$(m.time) " *
            "bytes=$(m.memory) allocs=$(m.allocs) samples=$(length(trial))")
end

function main(args::Vector{String})
    seed = parse_seed(args)
    println("model=ARM-v0.1 seed=$seed rng=none threads=$(Threads.nthreads())")
    for depth in (8,16,32)
        fixture = branch_model(depth)
        prepared_ref = deliver_all!(ReferenceView(fixture.model))
        prepared_fast = deliver_all!(FastView(fixture.model))
        target_a, target_b = fixture.target_a, fixture.target_b
        ref_a, fast_a = deepcopy(prepared_ref), deepcopy(prepared_fast)
        first_ref = @elapsed replay!(ref_a, target_a)
        first_fast = @elapsed replay!(fast_a, target_a)
        projection(ref_a) == projection(fast_a) || error("genesis reference mismatch")
        println("branch_depth=$depth first_reference_wall_s_including_compile=$first_ref " *
                "first_fast_wall_s_including_compile=$first_fast")
        reference = @benchmark replay!(v, $target_a) setup=(v=deepcopy($prepared_ref)) samples=10 evals=1
        fast = @benchmark replay!(v, $target_a) setup=(v=deepcopy($prepared_fast)) samples=10 evals=1
        report_trial("from_genesis", "BigInt_reference", depth, reference)
        report_trial("from_genesis", "UInt128_replay", depth, fast)
        check_ref, check_fast = deepcopy(ref_a), deepcopy(fast_a)
        replay!(check_ref,target_b) === DCM.Applied || error("reference reorg")
        replay!(check_fast,target_b) === DCM.Applied || error("fast reorg")
        projection(check_ref) == projection(check_fast) || error("reorg reference mismatch")
        reorg_ref = @benchmark replay!(v, $target_b) setup=(v=deepcopy($ref_a)) samples=10 evals=1
        reorg_fast = @benchmark replay!(v, $target_b) setup=(v=deepcopy($fast_a)) samples=10 evals=1
        report_trial("reorg", "BigInt_reference", depth, reorg_ref)
        report_trial("reorg", "UInt128_replay", depth, reorg_fast)
    end
end

main(ARGS)
