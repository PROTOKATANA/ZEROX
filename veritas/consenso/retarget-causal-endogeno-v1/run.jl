using RetargetCausalEndogeno

const U = UInt64

function cfg(target)
    ControllerConfig(300, target, 1, 2, 1, 2, 2, 1, 10, 900, 1, RoundNearestEven)
end

function make_scenario(label, selection, late)
    Scenario(label, U(600), U(20), U(3), U(2), selection, late, U(1024),
             U(2), U(1), U(3), U(5), U(4), U(11), U(2), U(3), cfg(10))
end

function main(args)
    seed = isempty(args) ? U(20260911) : parse(U, args[1])
    trace = generate_trace(seed, U(600), U(2), U(1))
    println("model=retarget-causal-endogeno-v1 seed=$seed")
    for s in (make_scenario("P0-L0", P0, L0), make_scenario("P1-L0", P1, L0),
              make_scenario("P0-LG", P0, LG), make_scenario("P1-LG", P1, LG))
        validate_equivalence(trace, s) || error("reference/kernel divergence $(s.label)")
        m = simulate_fast(trace, s)
        sealed_equal = all(get(m.payable_by_window, id, Tuple{U,U}[]) == ids
                           for (id, ids) in m.sealed_counted)
        println("variant=$(s.label) events=$(length(m.events)) final_range=$(m.final_range) " *
                "rate_num=$(length(m.events)) rate_den=$(m.horizon_slots) " *
                "counted_payable_equal=$sealed_equal honest_excluded=$(m.honest_excluded) " *
                "reincluded=$(m.reincluded) pending_slots=$(m.pending_slots) " *
                "no_progress_pending=$(m.max_no_progress_pending) " *
                "no_progress_empty=$(m.max_no_progress_empty) " *
                "no_event_progress=$(m.max_no_event_progress) " *
                "no_event_censored=$(m.no_event_streak_censored) " *
                "pending_headers_max=$(m.max_pending_headers) " *
                "never_accepted=$(m.payments_never_accepted) missed_updates=$(m.missed_updates) " *
                "reversal=Pending:no_branch_model queue=Pending:scheduled_deliveries_not_service_queue")
    end
end

main(ARGS)
