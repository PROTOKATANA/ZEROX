function apply_reference!(v::RefView, cat::Catalog, hid::UInt64, policy::Policy)
    policy === v.policy || return PolicyMismatch
    h = get(cat.histories, hid, nothing)
    if h === nothing || !history_structure_valid(cat, hid) || h.parent != v.public.current
        v.pending = 0; return Invalid
    end
    all(id -> id in v.headers, h.blocks) || (v.pending = hid; return Pending)
    winners = objective_winners(cat, h, policy, v.public.consumed)
    required = required_body_ids(cat, winners)
    any(id -> id in v.invalid, required) && (v.pending = 0; return Invalid)
    any(id -> (hid, id) in v.context_invalid, required) && (v.pending = 0; return Invalid)
    all(id -> id in v.good, required) || (v.pending = hid; return Pending)
    all(id -> (hid, id) in v.context_good, required) || (v.pending = hid; return Pending)

    before = clone_public(v.public)
    winner_ids = Set(b.id for b in winners)
    new_events = EventId[EventId(h.id, b.id) for b in winners]
    push!(v.undo, before)
    append!(v.public.journal, new_events)
    v.public.counted[h.window] = copy(new_events)
    v.public.payable[h.window] = copy(new_events)
    for b in winners
        push!(v.public.consumed, b.ticket)
    end
    for id in h.blocks
        id in winner_ids || push!(v.public.inert, InertKey(h.id, h.window, id))
        push!(v.public.applied_blocks, id)
    end
    v.public.current = h.id
    push!(v.public.path, h.id)
    v.pending = 0
    return Applied
end

function undo_reference!(v::RefView, expected::UInt64)
    if v.public.current != expected || isempty(v.undo)
        v.pending = 0; return Invalid
    end
    v.public = pop!(v.undo)
    v.pending = 0
    return Applied
end

function replay_reference!(v::RefView, cat::Catalog, target::UInt64, policy::Policy)
    policy === v.policy || return PolicyMismatch
    target_chain = history_chain(cat, target)
    if target_chain === nothing || !history_structure_valid(cat, target)
        v.pending = 0; return Invalid
    end
    current_chain = copy(v.public.path)
    common = 0
    limit = min(length(current_chain), length(target_chain))
    while common < limit && current_chain[common + 1] == target_chain[common + 1]
        common += 1
    end
    temp = deepcopy(v)
    while length(temp.public.path) > common
        undo_reference!(temp, temp.public.current) === Applied || return Invalid
    end
    for i in (common + 1):length(target_chain)
        hid = target_chain[i]
        outcome = apply_reference!(temp, cat, hid, policy)
        if outcome !== Applied
            outcome === Pending && (v.pending = temp.pending)
            outcome === Invalid && (v.pending = 0)
            return outcome
        end
    end
    v.public = temp.public; v.undo = temp.undo; v.pending = 0
    return Applied
end
