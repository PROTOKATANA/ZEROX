# Oráculo deliberadamente simple: listas lineales para entregas, ventanas y selección.
# No llama a `simulate` ni a sus índices rápidos.
function ref_timely(p::Produced, slot::UInt64, s::Scenario)
    if s.late === L0
        return (slot >= s.admission_width ? slot - s.admission_width : UInt64(0)) <=
               p.original_slot <= slot
    end
    cutoff = checked_slot_add(Base.Checked.checked_mul(
        checked_inc(p.original_slot ÷ s.window_width), s.window_width), s.grace)
    return slot < cutoff
end

function ref_select(batch::Vector{Produced}, slot::UInt64, s::Scenario)
    tickets = unique(p.ticket_id for p in batch)
    winners = Produced[]
    for ticket in tickets
        candidates = [p for p in batch if p.ticket_id == ticket && ref_timely(p, slot, s)]
        isempty(candidates) && continue
        if s.selection === P0
            push!(winners, reduce((a, b) -> a.block_id < b.block_id ? a : b, candidates))
        else
            push!(winners, reduce((a, b) ->
                (a.blue ? 0 : 1, a.block_id) < (b.blue ? 0 : 1, b.block_id) ? a : b,
                candidates))
        end
    end
    sort!(winners; by=p -> p.block_id)
    return winners
end

@inline ref_closure_has_unresolved(batch::Vector{Produced}, slot::UInt64) =
    any(p -> p.body_slot >= slot, batch)

function simulate_reference(trace::ExogenousTrace, s::Scenario)
    length(trace.honest) == Base.Checked.checked_mul(s.horizon_slots, s.honest_attempts) || throw(ArgumentError("trace"))
    length(trace.adversary) == Base.Checked.checked_mul(s.horizon_slots, s.adversary_attempts) || throw(ArgumentError("trace"))
    active = s.controller.initial_range
    agenda = Pair{UInt64,UInt64}[]
    produced = Produced[]
    visible = Produced[]
    events = EconomicEvent[]
    sealed = Dict{UInt64,Vector{Tuple{UInt64,UInt64}}}()
    payment_queue = Tuple{UInt64,UInt64}[]
    payment_head = 1
    accepted = Set{UInt64}()
    ranges = Vector{UInt64}(undef, Int(s.horizon_slots))
    next_window = UInt64(0)
    context = UInt64(0); honest_produced = UInt64(0); honest_excluded = UInt64(0)
    reincluded = UInt64(0); reinclusion_sum = UInt64(0); pending_slots = UInt64(0)
    pending_streak = UInt64(0); empty_streak = UInt64(0); all_streak = UInt64(0)
    max_pending = UInt64(0); max_empty = UInt64(0); max_all = UInt64(0)
    max_headers = UInt64(0); clamps = UInt64(0); missed = UInt64(0)
    hi = 1; ai = 1
    for slot in UInt64(0):(s.horizon_slots - UInt64(1))
        activation_index = findfirst(p -> p.first == slot, agenda)
        if activation_index !== nothing
            active = agenda[activation_index].second
            deleteat!(agenda, activation_index)
        end
        ranges[Base.Checked.checked_add(Int(slot), 1)] = active

        while true
            cutoff = checked_slot_add(Base.Checked.checked_mul(checked_inc(next_window), s.window_width), s.grace)
            slot >= cutoff || break
            ref_closure_has_unresolved(visible, slot) && break
            ids = Tuple{UInt64,UInt64}[(e.context_id, e.block_id) for e in events
                                        if e.window_id == next_window]
            sealed[next_window] = ids
            code, proposal, activation, clamped = causal_step(
                active, UInt64(length(ids)), cutoff, slot, s.window_width, s.controller;
                reference=true)
            code === StepMissedUpdate && (missed = checked_inc(missed))
            # Enmienda Z0: sólo Scheduled se agenda; HeldZero devuelve activación 0 y no agenda.
            if code === StepScheduled
                any(p -> p.first == activation, agenda) && throw(ArgumentError("activation collision"))
                push!(agenda, activation => proposal)
                clamped && (clamps = checked_inc(clamps))
            end
            next_window = checked_inc(next_window)
        end

        for _ in UInt64(1):s.honest_attempts
            opportunity_index = UInt64(hi - 1)
            op = trace.honest[hi]; hi = Base.Checked.checked_add(hi, 1)
            if (op.draw & (s.draw_scale - UInt64(1))) < active
                honest_produced = checked_inc(honest_produced)
                ids = stable_opportunity_ids(s, true, opportunity_index)
                delay = s.honest_delay_max == 0 ? UInt64(0) :
                        op.delay_draw % checked_inc(s.honest_delay_max)
                extra = s.congestion_period > 0 && slot % s.congestion_period == 0 ?
                        s.congestion_delay : UInt64(0)
                header = checked_slot_add(slot, checked_slot_add(delay, extra))
                body = checked_slot_add(header, op.delay_draw & UInt64(1))
                copy = s.copy_modulus > 0 && op.copy_draw % s.copy_modulus == 0
                push!(produced, Produced(ids.ticket, ids.block, ids.payment, slot, header, body,
                                         true, !copy))
                if copy
                    push!(produced, Produced(ids.ticket, ids.copy_block, ids.payment, slot, header,
                                             body, true, true))
                end
            end
        end
        for _ in UInt64(1):s.adversary_attempts
            opportunity_index = UInt64(ai - 1)
            op = trace.adversary[ai]; ai = Base.Checked.checked_add(ai, 1)
            if (op.draw & (s.draw_scale - UInt64(1))) < active
                ids = stable_opportunity_ids(s, false, opportunity_index)
                header = checked_slot_add(slot, s.adversary_header_delay)
                body = checked_slot_add(header, s.adversary_body_hold)
                copy = s.copy_modulus > 0 && op.copy_draw % s.copy_modulus == 0
                push!(produced, Produced(ids.ticket, ids.block, 0, slot, header, body,
                                         false, !copy))
                if copy
                    push!(produced, Produced(ids.ticket, ids.copy_block, 0, slot, header,
                                             body, false, true))
                end
            end
        end
        append!(visible, [p for p in produced if p.header_slot == slot])
        max_headers = max(max_headers, UInt64(length(visible)))
        if !isempty(visible) && any(p -> p.body_slot > slot, visible)
            pending_slots = checked_inc(pending_slots); pending_streak = checked_inc(pending_streak)
            empty_streak = UInt64(0); all_streak = checked_inc(all_streak)
            max_pending = max(max_pending, pending_streak); max_all = max(max_all, all_streak)
            continue
        end

        winners = ref_select(visible, slot, s)
        winner_blocks = [p.block_id for p in winners]
        winner_tickets = [p.ticket_id for p in winners]
        context = checked_inc(context)
        excluded = UInt64[]
        for p in visible
            if p.honest && !(p.block_id in winner_blocks) && !(p.ticket_id in winner_tickets) &&
               !(p.ticket_id in excluded)
                honest_excluded = checked_inc(honest_excluded)
                push!(payment_queue, (p.payment_id, p.original_slot)); push!(excluded, p.ticket_id)
            end
        end
        for p in winners
            window = p.original_slot ÷ s.window_width
            push!(events, EconomicEvent(context, p.block_id, p.ticket_id, p.original_slot,
                                        slot, window, p.honest))
            if p.honest
                if payment_head > length(payment_queue)
                    push!(accepted, p.payment_id)
                else
                    payment, origin = payment_queue[payment_head]
                    payment_head = Base.Checked.checked_add(payment_head, 1)
                    if !(payment in accepted)
                        push!(accepted, payment); reincluded = checked_inc(reincluded)
                        reinclusion_sum = Base.Checked.checked_add(reinclusion_sum, slot - origin)
                    end
                    p.payment_id in accepted || push!(payment_queue, (p.payment_id, p.original_slot))
                end
            end
        end
        empty!(visible)
        if isempty(winners)
            empty_streak = checked_inc(empty_streak); pending_streak = UInt64(0)
            all_streak = checked_inc(all_streak)
            max_empty = max(max_empty, empty_streak); max_all = max(max_all, all_streak)
        else
            empty_streak = UInt64(0); pending_streak = UInt64(0); all_streak = UInt64(0)
        end
    end
    payable = Dict{UInt64,Vector{Tuple{UInt64,UInt64}}}()
    for e in events
        push!(get!(payable, e.window_id, Tuple{UInt64,UInt64}[]), (e.context_id, e.block_id))
    end
    never = honest_produced - UInt64(length(accepted))
    return SimulationMetrics(s.label, s.horizon_slots, active, ranges, events, sealed, payable,
        honest_produced, honest_excluded, reincluded, reinclusion_sum, pending_slots,
        max_pending, max_empty, max_all, all_streak > 0, max_headers, honest_produced, never,
        clamps, missed, MetricPending(:no_branch_model), MetricPending(:single_observer_model),
        MetricPending(:scheduled_deliveries_not_service_queue))
end
