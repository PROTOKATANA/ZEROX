@inline function mix64(x::UInt64)
    x ⊻= x >> 30
    x *= 0xbf58476d1ce4e5b9
    x ⊻= x >> 27
    x *= 0x94d049bb133111eb
    return x ⊻ (x >> 31)
end

function generate_trace(seed::UInt64, horizon::UInt64, honest_attempts::UInt64,
                        adversary_attempts::UInt64)
    nh = Base.Checked.checked_mul(horizon, honest_attempts)
    na = Base.Checked.checked_mul(horizon, adversary_attempts)
    honest = Vector{Opportunity}(undef, Int(nh))
    adversary = Vector{Opportunity}(undef, Int(na))
    if honest_attempts > 0
        for slot in UInt64(0):(horizon - UInt64(1)), attempt in UInt64(0):(honest_attempts - UInt64(1))
            i = Base.Checked.checked_add(Base.Checked.checked_mul(slot, honest_attempts), attempt)
            # i is the injective encoding of (slot, actor-local attempt); actor and
            # draw kind use disjoint domain constants.
            key = mix64(seed ⊻ i ⊻ 0x484f4e4553540001)
            honest[Int(Base.Checked.checked_add(i, UInt64(1)))] =
                Opportunity(key, mix64(key ⊻ 0x44454c4159000001), mix64(key ⊻ 0x434f505900000001))
        end
    end
    if adversary_attempts > 0
        for slot in UInt64(0):(horizon - UInt64(1)), attempt in UInt64(0):(adversary_attempts - UInt64(1))
            i = Base.Checked.checked_add(Base.Checked.checked_mul(slot, adversary_attempts), attempt)
            key = mix64(seed ⊻ i ⊻ 0x4144564552530001)
            adversary[Int(Base.Checked.checked_add(i, UInt64(1)))] =
                Opportunity(key, mix64(key ⊻ 0x44454c4159000001), mix64(key ⊻ 0x434f505900000001))
        end
    end
    return ExogenousTrace(seed, honest, adversary)
end

@inline function checked_slot_add(a::UInt64, b::UInt64)
    return Base.Checked.checked_add(a, b)
end

@inline checked_inc(a::UInt64) = Base.Checked.checked_add(a, UInt64(1))

function stable_opportunity_ids(s::Scenario, honest::Bool, index::UInt64)
    honest_total = Base.Checked.checked_mul(s.horizon_slots, s.honest_attempts)
    ordinal = honest ? index : Base.Checked.checked_add(honest_total, index)
    primary_block = checked_inc(Base.Checked.checked_mul(UInt64(2), ordinal))
    payment = honest ? checked_inc(index) : UInt64(0)
    return (ticket=primary_block, block=primary_block, copy_block=checked_inc(primary_block),
            payment=payment)
end

@inline function is_timely(p::Produced, slot::UInt64, scenario::Scenario)
    if scenario.late === L0
        lo = slot >= scenario.admission_width ? slot - scenario.admission_width : UInt64(0)
        return lo <= p.original_slot <= slot
    end
    id = p.original_slot ÷ scenario.window_width
    cutoff = checked_slot_add(Base.Checked.checked_mul(checked_inc(id), scenario.window_width),
                              scenario.grace)
    return slot < cutoff
end

@inline event_id(e::EconomicEvent) = (e.context_id, e.block_id)
@inline closure_has_unresolved(batch::Vector{Produced}, slot::UInt64) =
    any(p -> p.body_slot >= slot, batch)

function select_batch(batch::Vector{Produced}, slot::UInt64, scenario::Scenario)
    chosen = Dict{UInt64,Produced}()
    for p in batch
        is_timely(p, slot, scenario) || continue
        old = get(chosen, p.ticket_id, nothing)
        if old === nothing
            chosen[p.ticket_id] = p
        elseif scenario.selection === P0
            p.block_id < old.block_id && (chosen[p.ticket_id] = p)
        else
            key_p = (p.blue ? 0 : 1, p.block_id)
            key_o = (old.blue ? 0 : 1, old.block_id)
            key_p < key_o && (chosen[p.ticket_id] = p)
        end
    end
    result = collect(values(chosen))
    sort!(result; by=p -> p.block_id)
    return result
end

function simulate_kernel(trace::ExogenousTrace, scenario::Scenario)
    expected_h = Base.Checked.checked_mul(scenario.horizon_slots, scenario.honest_attempts)
    expected_a = Base.Checked.checked_mul(scenario.horizon_slots, scenario.adversary_attempts)
    length(trace.honest) == expected_h && length(trace.adversary) == expected_a ||
        throw(ArgumentError("trace shape differs from scenario"))

    active = scenario.controller.initial_range
    scheduled = Dict{UInt64,UInt64}()
    deliveries = Dict{UInt64,Vector{Produced}}()
    visible_pending = Produced[]
    events = EconomicEvent[]
    sealed = Dict{UInt64,Vector{Tuple{UInt64,UInt64}}}()
    events_by_window = Dict{UInt64,Vector{Tuple{UInt64,UInt64}}}()
    payment_queue = Vector{Tuple{UInt64,UInt64}}() # (payment_id, origin_slot)
    payment_head = 1
    accepted_payments = Set{UInt64}()
    ranges = Vector{UInt64}(undef, Int(scenario.horizon_slots))
    next_window = UInt64(0)
    context = UInt64(0)
    honest_produced = UInt64(0)
    honest_excluded = UInt64(0)
    reincluded = UInt64(0)
    reinclusion_delay_sum = UInt64(0)
    pending_slots = UInt64(0)
    pending_streak = UInt64(0)
    empty_streak = UInt64(0)
    max_pending_streak = UInt64(0)
    max_empty_streak = UInt64(0)
    no_event_streak = UInt64(0)
    max_no_event_streak = UInt64(0)
    max_pending_headers = UInt64(0)
    clamp_count = UInt64(0)
    missed_updates = UInt64(0)

    hi = 1
    ai = 1
    for slot in UInt64(0):(scenario.horizon_slots - UInt64(1))
        # Phase 1: activate an already scheduled proposal.
        if haskey(scheduled, slot)
            active = pop!(scheduled, slot)
        end
        ranges[Base.Checked.checked_add(Int(slot), 1)] = active

        # Phase 2: close windows in strict order, using only previously visible headers.
        while true
            cutoff = checked_slot_add(
                Base.Checked.checked_mul(checked_inc(next_window), scenario.window_width),
                scenario.grace)
            slot >= cutoff || break
            # DA0 blocks publication of the applied history, hence every later causal close.
            # Cierre precede a disponibilidad/incorporación dentro del slot: cuerpo en
            # este mismo slot aún no pertenece a la historia visible para el cierre.
            unresolved = closure_has_unresolved(visible_pending, slot)
            unresolved && break
            ids = copy(get(events_by_window, next_window, Tuple{UInt64,UInt64}[]))
            sealed[next_window] = ids
            code, proposed, activation, clamped = causal_step(
                active, UInt64(length(ids)), cutoff, slot, scenario.window_width,
                scenario.controller; reference=false)
            code === StepMissedUpdate && (missed_updates = checked_inc(missed_updates))
            # Enmienda Z0: sólo Scheduled se agenda; HeldZero devuelve activación 0 y no agenda.
            if code === StepScheduled
                haskey(scheduled, activation) && throw(ArgumentError("activation collision"))
                scheduled[activation] = proposed
                clamped && (clamp_count = checked_inc(clamp_count))
            end
            next_window = checked_inc(next_window)
        end

        # Phase 3a: produce from the common exogenous trace under this variant's own range.
        for _ in UInt64(1):scenario.honest_attempts
            opportunity_index = UInt64(hi - 1)
            op = trace.honest[hi]; hi = Base.Checked.checked_add(hi, 1)
            if (op.draw & (scenario.draw_scale - UInt64(1))) < active
                honest_produced = checked_inc(honest_produced)
                ids = stable_opportunity_ids(scenario, true, opportunity_index)
                base_delay = scenario.honest_delay_max == 0 ? UInt64(0) :
                             op.delay_draw % checked_inc(scenario.honest_delay_max)
                congestion = scenario.congestion_period > 0 &&
                             slot % scenario.congestion_period == 0 ? scenario.congestion_delay : UInt64(0)
                header = checked_slot_add(slot, checked_slot_add(base_delay, congestion))
                body = checked_slot_add(header, op.delay_draw & UInt64(1))
                copy = scenario.copy_modulus > 0 && op.copy_draw % scenario.copy_modulus == 0
                produced = Produced(ids.ticket, ids.block, ids.payment, slot, header, body, true, !copy)
                push!(get!(deliveries, header, Produced[]), produced)
                if copy
                    produced = Produced(ids.ticket, ids.copy_block, ids.payment, slot,
                                        header, body, true, true)
                    push!(get!(deliveries, header, Produced[]), produced)
                end
            end
        end
        for _ in UInt64(1):scenario.adversary_attempts
            opportunity_index = UInt64(ai - 1)
            op = trace.adversary[ai]; ai = Base.Checked.checked_add(ai, 1)
            if (op.draw & (scenario.draw_scale - UInt64(1))) < active
                ids = stable_opportunity_ids(scenario, false, opportunity_index)
                header = checked_slot_add(slot, scenario.adversary_header_delay)
                body = checked_slot_add(header, scenario.adversary_body_hold)
                copy = scenario.copy_modulus > 0 && op.copy_draw % scenario.copy_modulus == 0
                produced = Produced(ids.ticket, ids.block, 0, slot, header, body, false, !copy)
                push!(get!(deliveries, header, Produced[]), produced)
                if copy
                    produced = Produced(ids.ticket, ids.copy_block, 0, slot, header, body,
                                        false, true)
                    push!(get!(deliveries, header, Produced[]), produced)
                end
            end
        end

        # Phase 3b: headers become visible; DA0 waits for every visible body.
        append!(visible_pending, pop!(deliveries, slot, Produced[]))
        max_pending_headers = max(max_pending_headers, UInt64(length(visible_pending)))
        if !isempty(visible_pending) && any(p -> p.body_slot > slot, visible_pending)
            pending_slots = checked_inc(pending_slots)
            pending_streak = checked_inc(pending_streak)
            empty_streak = UInt64(0)
            max_pending_streak = max(max_pending_streak, pending_streak)
            no_event_streak = Base.Checked.checked_add(no_event_streak, UInt64(1))
            max_no_event_streak = max(max_no_event_streak, no_event_streak)
            continue
        end

        winners = select_batch(visible_pending, slot, scenario)
        winner_blocks = Set(p.block_id for p in winners)
        winner_tickets = Set(p.ticket_id for p in winners)
        context = checked_inc(context)
        excluded_tickets = Set{UInt64}()
        for p in visible_pending
            if p.honest && !(p.block_id in winner_blocks)
                # Count one exclusion per economic ticket, not once per copy.
                if !(p.ticket_id in winner_tickets)
                    if !(p.ticket_id in excluded_tickets)
                        honest_excluded = checked_inc(honest_excluded)
                        push!(payment_queue, (p.payment_id, p.original_slot))
                        push!(excluded_tickets, p.ticket_id)
                    end
                end
            end
        end
        for p in winners
            window = p.original_slot ÷ scenario.window_width
            push!(events, EconomicEvent(context, p.block_id, p.ticket_id, p.original_slot,
                                        slot, window, p.honest))
            push!(get!(events_by_window, window, Tuple{UInt64,UInt64}[]), (context, p.block_id))
            if p.honest
                if payment_head > length(payment_queue)
                    push!(accepted_payments, p.payment_id)
                else
                    payment, origin = payment_queue[payment_head]
                    payment_head = Base.Checked.checked_add(payment_head, 1)
                    if !(payment in accepted_payments)
                        push!(accepted_payments, payment)
                        reincluded = Base.Checked.checked_add(reincluded, UInt64(1))
                        reinclusion_delay_sum = Base.Checked.checked_add(
                            reinclusion_delay_sum, slot - origin)
                    end
                    p.payment_id in accepted_payments || push!(payment_queue, (p.payment_id, p.original_slot))
                end
            end
        end
        empty!(visible_pending)
        if isempty(winners)
            empty_streak = checked_inc(empty_streak)
            pending_streak = UInt64(0)
            max_empty_streak = max(max_empty_streak, empty_streak)
            no_event_streak = Base.Checked.checked_add(no_event_streak, UInt64(1))
            max_no_event_streak = max(max_no_event_streak, no_event_streak)
        else
            empty_streak = UInt64(0)
            pending_streak = UInt64(0)
            no_event_streak = UInt64(0)
        end
    end

    payable = Dict{UInt64,Vector{Tuple{UInt64,UInt64}}}()
    for e in events
        push!(get!(payable, e.window_id, Tuple{UInt64,UInt64}[]), event_id(e))
    end
    originated = honest_produced
    never = originated - UInt64(length(accepted_payments))
    return SimulationMetrics(scenario.label, scenario.horizon_slots, active, ranges, events,
        sealed, payable, honest_produced, honest_excluded, reincluded,
        reinclusion_delay_sum, pending_slots, max_pending_streak, max_empty_streak,
        max_no_event_streak, no_event_streak > 0,
        max_pending_headers, originated, never, clamp_count, missed_updates,
        MetricPending(:no_branch_model), MetricPending(:single_observer_model),
        MetricPending(:scheduled_deliveries_not_service_queue))
end

simulate_fast(trace::ExogenousTrace, scenario::Scenario) = simulate_kernel(trace, scenario)
