using VentanaRetargetCausal

function main(args)
    isempty(args) || error("this structural run accepts no economic parameters")
    fixture = joinpath(@__DIR__, "fixtures", "CASOS.txt")
    reference = execute_fixtures(fixture; engine=apply_reference)
    fast = execute_fixtures(fixture; engine=apply_fast)
    reference == fast || error("reference/kernel fixture divergence")
    println("model=ventana-retarget-causal-v1")
    println("cases=$(fast.cases)")
    println("assertions=$(fast.assertions)")
    println("event_identity=context_id:block_id")
    println("retarget_formula=pending_not_implemented")
    println("result=structural_contract_ok")
end

main(ARGS)
