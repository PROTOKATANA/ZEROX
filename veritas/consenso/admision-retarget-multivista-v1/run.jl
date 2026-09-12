using AdmisionRetargetMultivista

function main(args::Vector{String})
    seed = parse_seed(args)
    result = validate_manual(seed)
    println("model=ARM-v0.1 status=conditional_structural_composition seed=$seed rng=none")
    println("observed_event_ids=$(result.observed) negative_control_detected=$(result.negative_detected)")
    println("naive_early_range=$(result.naive_early_range) naive_late_range=$(result.naive_late_range)")
    println("causal_convergence=$(result.causal_convergence) causal_range_at_slot21=$(result.causal_range_at_21)")
    println("dag_inclusion=oracle range_validation=Pending network=Pending cortex_finality=Pending")
end

main(ARGS)
