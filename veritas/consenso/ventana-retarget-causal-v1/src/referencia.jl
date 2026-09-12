function select_reference(state::State, batch::Batch, scenario::Scenario)
    tickets = sort!(unique(UInt64[b.ticket_id for b in batch.blocks]))
    chosen = Candidate[]
    for ticket in tickets
        haskey(state.used_tickets, ticket) && continue
        eligible = Candidate[]
        for b in batch.blocks
            b.ticket_id == ticket || continue
            economically_colored(b) || continue
            timely(scenario.late, scenario.controller, b, batch.incorporation_slot) || continue
            push!(eligible, b)
        end
        isempty(eligible) && continue
        if scenario.selection === P0
            push!(chosen, reduce((a, b) -> a.rank <= b.rank ? a : b, eligible))
        else
            push!(chosen, reduce((a, b) ->
                winner_key(Val(P1), a) <= winner_key(Val(P1), b) ? a : b, eligible))
        end
    end
    sort!(chosen; by=b -> b.rank)
    return chosen
end

function publish_reference(state::State, batch::Batch, spec::WindowSpec, chosen::Vector{Candidate})
    result = deepcopy(state)
    applied = Candidate[]
    for b in chosen
        event = event_for(result, batch, spec, b)
        push!(result.journal, event)
        result.used_tickets[b.ticket_id] = event.event_id
        result.ticket_slots[b.ticket_id] = b.original_slot
        push!(applied, b)
    end
    union!(result.seen_blocks, (b.block_id for b in batch.blocks))
    result.context_id = batch.context_id
    result.context_slot = batch.incorporation_slot
    return result, applied
end

function apply_reference(state::State, batch::Batch, scenario::Scenario)
    check = basic_validation(state, batch)
    check === :pending_data && return ApplyResult(Pending, state, nothing, UInt64[], check)
    check === :ok || return ApplyResult(Invalid, state, nothing, UInt64[], check)
    selected = select_reference(state, batch, scenario)
    next, applied = publish_reference(state, batch, scenario.controller, selected)
    undo = UndoRecord(state.context_id, state.context_slot, batch.context_id,
                      length(state.journal), UInt64[b.ticket_id for b in applied],
                      UInt64[b.block_id for b in batch.blocks], length(state.causal_exclusions))
    return ApplyResult(Applied, next, undo, UInt64[b.block_id for b in applied], :ok)
end
