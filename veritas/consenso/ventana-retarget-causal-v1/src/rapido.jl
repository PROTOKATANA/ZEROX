function select_fast(state::State, batch::Batch, scenario::Scenario)
    order = sortperm(batch.blocks; by=b -> scenario.selection === P0 ?
        winner_key(Val(P0), b) : winner_key(Val(P1), b))
    claimed = Set{UInt64}()
    selected = Candidate[]
    sizehint!(selected, length(batch.blocks))
    for index in order
        b = batch.blocks[index]
        (b.ticket_id in claimed || haskey(state.used_tickets, b.ticket_id)) && continue
        economically_colored(b) || continue
        timely(scenario.late, scenario.controller, b, batch.incorporation_slot) || continue
        push!(claimed, b.ticket_id)
        push!(selected, b)
    end
    sort!(selected; by=b -> b.rank)
    return selected
end

function apply_fast(state::State, batch::Batch, scenario::Scenario)
    check = basic_validation(state, batch)
    check === :pending_data && return ApplyResult(Pending, state, nothing, UInt64[], check)
    check === :ok || return ApplyResult(Invalid, state, nothing, UInt64[], check)
    selected = select_fast(state, batch, scenario)
    applied = Candidate[]
    exclusions_before = length(state.causal_exclusions)
    journal_before = length(state.journal)
    for b in selected
        event = event_for(state, batch, scenario.controller, b)
        push!(state.journal, event)
        state.used_tickets[b.ticket_id] = event.event_id
        state.ticket_slots[b.ticket_id] = b.original_slot
        push!(applied, b)
    end
    added_blocks = UInt64[b.block_id for b in batch.blocks]
    union!(state.seen_blocks, added_blocks)
    undo = UndoRecord(state.context_id, state.context_slot, batch.context_id, journal_before,
                      UInt64[b.ticket_id for b in applied], added_blocks, exclusions_before)
    state.context_id = batch.context_id
    state.context_slot = batch.incorporation_slot
    return ApplyResult(Applied, state, undo, UInt64[b.block_id for b in applied], :ok)
end
