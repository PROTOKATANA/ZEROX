function metrics_projection(m::SimulationMetrics)
    events = [(e.context_id, e.block_id, e.ticket_id, e.original_slot,
               e.incorporation_slot, e.window_id, e.honest) for e in m.events]
    seals = sort!([(k, v) for (k, v) in m.sealed_counted]; by=first)
    payable = sort!([(k, v) for (k, v) in m.payable_by_window]; by=first)
    return (m.final_range, m.ranges_by_slot, events, seals, payable, m.honest_produced,
            m.honest_excluded, m.reincluded, m.reinclusion_delay_sum, m.pending_slots,
            m.max_no_progress_pending, m.max_no_progress_empty, m.max_no_event_progress,
            m.no_event_streak_censored, m.max_pending_headers,
            m.payments_originated, m.payments_never_accepted, m.clamp_count,
            m.missed_updates)
end

validate_equivalence(trace::ExogenousTrace, scenario::Scenario) =
    metrics_projection(simulate_reference(trace, scenario)) ==
    metrics_projection(simulate_fast(trace, scenario))

function parse_round(s::AbstractString)
    s == "Floor" && return RoundFloor
    s == "NearestEven" && return RoundNearestEven
    error("unknown rounding $s")
end

function execute_fixtures(path::AbstractString)
    assertions = 0
    cases = 0
    for (line_number, raw) in enumerate(eachline(path))
        line = strip(first(split(raw, '#'; limit=2)))
        isempty(line) && continue
        f = split(line)
        f[1] == "STEP" || error("fixture line $line_number: expected STEP")
        length(f) == 19 || error("fixture line $line_number: arity")
        # STEP current observed|- cutoff seal W Q a d lo_n lo_d hi_n hi_d min max delay round code next activation clamped
        current = parse(UInt64, f[2])
        observed = f[3] == "-" ? nothing : parse(UInt64, f[3])
        cutoff, seal, width = parse.(UInt64, f[4:6])
        cfg = ControllerConfig(current, parse(UInt64, f[7]), parse(UInt64, f[8]),
            parse(UInt64, f[9]), parse(UInt64, f[10]), parse(UInt64, f[11]),
            parse(UInt64, f[12]), parse(UInt64, f[13]), parse(UInt64, f[14]),
            parse(UInt64, f[15]), parse(UInt64, f[16]), parse_round(f[17]))
        result_ref = causal_step(current, observed, cutoff, seal, width, cfg; reference=true)
        result_fast = causal_step(current, observed, cutoff, seal, width, cfg; reference=false)
        result_ref == result_fast || error("fixture line $line_number: reference divergence")
        expected_code = f[18] == "Pending" ? StepPending : f[18] == "HeldZero" ? StepHeldZero :
                        f[18] == "Scheduled" ? StepScheduled : f[18] == "Missed" ? StepMissedUpdate :
                        error("fixture line $line_number: code")
        # Compact fixture encodes next:activation:clamped as final token.
        tail = split(f[19], ':')
        expected = (expected_code, parse(UInt64, tail[1]), parse(UInt64, tail[2]),
                    tail[3] == "1")
        result_fast == expected || error("fixture line $line_number: expected $expected got $result_fast")
        assertions = Base.Checked.checked_add(assertions, 2)
        cases = Base.Checked.checked_add(cases, 1)
    end
    return (cases=cases, assertions=assertions)
end
