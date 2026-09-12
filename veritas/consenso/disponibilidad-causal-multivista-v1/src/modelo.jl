@enum Policy::UInt8 P0 P1
@enum Color::UInt8 Blue RedK RedU
@enum Outcome::UInt8 Applied Pending Invalid PolicyMismatch

struct BlockSpec
    id::UInt64
    ticket::UInt64
    origin_window::UInt64
    rank::UInt64
    color::Color
    parents::Vector{UInt64}
end

struct HistorySpec
    id::UInt64
    parent::UInt64
    window::UInt64
    blocks::Vector{UInt64}
end

struct EventId
    history::UInt64
    block::UInt64
end
Base.:(==)(a::EventId, b::EventId) = a.history == b.history && a.block == b.block
Base.hash(x::EventId, h::UInt) = hash(x.block, hash(x.history, h))

struct InertKey
    history::UInt64
    window::UInt64
    block::UInt64
end
Base.:(==)(a::InertKey, b::InertKey) =
    a.history == b.history && a.window == b.window && a.block == b.block
Base.hash(x::InertKey, h::UInt) = hash(x.block, hash(x.window, hash(x.history, h)))

struct Catalog
    blocks::Dict{UInt64,BlockSpec}
    histories::Dict{UInt64,HistorySpec}
    block_index::Dict{UInt64,Int}
    invalid_bodies::Set{UInt64}
    context_truth::Dict{Tuple{UInt64,UInt64},Bool}
end

function Catalog(blocks::Vector{BlockSpec}, histories::Vector{HistorySpec};
                 invalid_bodies=Set{UInt64}(),
                 context_truth=Dict{Tuple{UInt64,UInt64},Bool}())
    bd = Dict{UInt64,BlockSpec}()
    hd = Dict{UInt64,HistorySpec}()
    for b in blocks
        b.id > 0 && b.ticket > 0 || throw(ArgumentError("block/ticket zero reserved"))
        haskey(bd, b.id) && throw(ArgumentError("duplicate block"))
        bd[b.id] = BlockSpec(b.id, b.ticket, b.origin_window, b.rank, b.color, copy(b.parents))
    end
    ticket_windows = Dict{UInt64,UInt64}()
    for b in blocks
        prior = get(ticket_windows, b.ticket, b.origin_window)
        prior == b.origin_window || throw(ArgumentError("ticket changes origin window"))
        ticket_windows[b.ticket] = b.origin_window
    end
    for h in histories
        h.id > 0 || throw(ArgumentError("history zero reserved"))
        haskey(hd, h.id) && throw(ArgumentError("duplicate history"))
        hd[h.id] = HistorySpec(h.id, h.parent, h.window, copy(h.blocks))
    end
    index = Dict{UInt64,Int}(id => i for (i, id) in enumerate(sort!(collect(keys(bd)))))
    all(id -> haskey(bd, id), invalid_bodies) || throw(ArgumentError("invalid body truth unknown"))
    all(x -> haskey(hd, x[1]) && haskey(bd, x[2]), keys(context_truth)) ||
        throw(ArgumentError("context truth unknown"))
    return Catalog(bd, hd, index, Set(invalid_bodies),
                   Dict{Tuple{UInt64,UInt64},Bool}(context_truth))
end

@inline eligible(c::Color) = c === Blue || c === RedK
@inline select_key(b::BlockSpec, p::Policy) =
    p === P0 ? (UInt8(0), b.rank, b.id) : (b.color === Blue ? UInt8(0) : UInt8(1), b.rank, b.id)

function objective_winners(cat::Catalog, h::HistorySpec, policy::Policy,
                           consumed::Set{UInt64}=Set{UInt64}())
    chosen = Dict{UInt64,BlockSpec}()
    for id in h.blocks
        b = cat.blocks[id]
        b.ticket in consumed && continue
        b.origin_window == h.window || continue
        eligible(b.color) || continue
        old = get(chosen, b.ticket, nothing)
        (old === nothing || select_key(b, policy) < select_key(old, policy)) && (chosen[b.ticket] = b)
    end
    out = collect(values(chosen))
    sort!(out; by=b -> (b.rank, b.id))
    return out
end

function history_chain(cat::Catalog, id::UInt64)
    chain = UInt64[]
    seen = Set{UInt64}()
    while id != 0
        id in seen && return nothing
        push!(seen, id)
        h = get(cat.histories, id, nothing)
        h === nothing && return nothing
        push!(chain, id)
        id = h.parent
    end
    reverse!(chain)
    return chain
end

function history_structure_valid(cat::Catalog, id::UInt64)
    chain = history_chain(cat, id)
    chain === nothing && return false
    past_blocks = Set{UInt64}()
    past_windows = Set{UInt64}()
    for hid in chain
        h = cat.histories[hid]
        length(unique(h.blocks)) == length(h.blocks) || return false
        h.window in past_windows && return false
        current = Set(h.blocks)
        for bid in h.blocks
            haskey(cat.blocks, bid) || return false
            bid in past_blocks && return false
            origin = cat.blocks[bid].origin_window
            (origin == h.window || origin in past_windows) || return false
        end
        allowed = union(past_blocks, current)
        for bid in h.blocks, parent in cat.blocks[bid].parents
            parent in allowed || return false
        end
        union!(past_blocks, current)
        push!(past_windows, h.window)
    end
    # Kahn tipado evita una clausura recursiva y comprueba ciclos en O(B+E).
    indegree = Dict{UInt64,Int}()
    children = Dict{UInt64,Vector{UInt64}}()
    for bid in past_blocks
        parents = cat.blocks[bid].parents
        indegree[bid] = length(parents)
        for parent in parents
            push!(get!(children, parent, UInt64[]), bid)
        end
    end
    ready = UInt64[bid for (bid, degree) in indegree if degree == 0]
    visited = 0
    while !isempty(ready)
        parent = pop!(ready)
        visited = Base.Checked.checked_add(visited, 1)
        for child in get(children, parent, UInt64[])
            degree = Base.Checked.checked_sub(indegree[child], 1)
            indegree[child] = degree
            degree == 0 && push!(ready, child)
        end
    end
    return visited == length(past_blocks)
end

function required_body_ids(cat::Catalog, winners::Vector{BlockSpec})
    needed = Set{UInt64}()
    stack = UInt64[b.id for b in winners]
    while !isempty(stack)
        id = pop!(stack)
        id in needed && continue
        push!(needed, id)
        append!(stack, cat.blocks[id].parents)
    end
    return needed
end

abstract type AbstractView end

mutable struct PublicState
    current::UInt64
    journal::Vector{EventId}
    counted::Dict{UInt64,Vector{EventId}}
    payable::Dict{UInt64,Vector{EventId}}
    inert::Set{InertKey}
    applied_blocks::Set{UInt64}
    consumed::Set{UInt64}
    path::Vector{UInt64}
end
PublicState() = PublicState(0, EventId[], Dict{UInt64,Vector{EventId}}(),
    Dict{UInt64,Vector{EventId}}(), Set{InertKey}(), Set{UInt64}(), Set{UInt64}(), UInt64[])

mutable struct RefView <: AbstractView
    name::String
    const policy::Policy
    block_ids::Set{UInt64}
    history_ids::Set{UInt64}
    invalid_body_truth::Set{UInt64}
    context_truth::Dict{Tuple{UInt64,UInt64},Bool}
    headers::Set{UInt64}
    good::Set{UInt64}
    rejected::Set{UInt64}
    invalid::Set{UInt64}
    context_good::Set{Tuple{UInt64,UInt64}}
    context_invalid::Set{Tuple{UInt64,UInt64}}
    public::PublicState
    undo::Vector{PublicState}
    pending::UInt64
end
RefView(name::String, cat::Catalog; policy::Policy=P0) =
    RefView(name, policy, Set(keys(cat.blocks)), Set(keys(cat.histories)),
    cat.invalid_bodies, cat.context_truth,
    Set{UInt64}(), Set{UInt64}(), Set{UInt64}(), Set{UInt64}(),
    Set{Tuple{UInt64,UInt64}}(), Set{Tuple{UInt64,UInt64}}(),
    PublicState(), PublicState[], 0)

mutable struct FastView <: AbstractView
    name::String
    const policy::Policy
    block_index::Dict{UInt64,Int}
    history_ids::Set{UInt64}
    invalid_body_truth::Set{UInt64}
    context_truth::Dict{Tuple{UInt64,UInt64},Bool}
    headers::BitSet
    good::BitSet
    rejected::BitSet
    invalid::BitSet
    context_good::Dict{UInt64,BitSet}
    context_invalid::Dict{UInt64,BitSet}
    public::PublicState
    undo::Vector{PublicState}
    pending::UInt64
end
FastView(name::String, cat::Catalog; policy::Policy=P0) =
    FastView(name, policy, cat.block_index, Set(keys(cat.histories)),
    cat.invalid_bodies, cat.context_truth,
    BitSet(), BitSet(), BitSet(), BitSet(),
    Dict{UInt64,BitSet}(), Dict{UInt64,BitSet}(), PublicState(), PublicState[], 0)

function deliver_header!(v::AbstractView, block::UInt64)
    index = get(v.block_index, block, 0); index > 0 || return false
    push!(v.headers, index); return true
end
function deliver_header!(v::RefView, block::UInt64)
    block in v.block_ids || return false
    push!(v.headers, block); return true
end
function deliver_body!(v::AbstractView, block::UInt64, good::Bool)
    index = get(v.block_index, block, 0); index > 0 || return false
    if good
        block in v.invalid_body_truth && return false
        index in v.invalid && return false
        push!(v.good, index); delete!(v.rejected, index)
    elseif !(index in v.good) && !(index in v.invalid)
        push!(v.rejected, index)
    end
    return true
end
function deliver_body!(v::RefView, block::UInt64, good::Bool)
    block in v.block_ids || return false
    if good
        block in v.invalid_body_truth && return false
        block in v.invalid && return false
        push!(v.good, block); delete!(v.rejected, block)
    elseif !(block in v.good) && !(block in v.invalid)
        push!(v.rejected, block)
    end
    return true
end

function deliver_invalid_body!(v::AbstractView, block::UInt64)
    index = get(v.block_index, block, 0); index > 0 || return false
    block in v.invalid_body_truth || return false
    index in v.good && return false
    push!(v.invalid, index); delete!(v.rejected, index); return true
end
function deliver_invalid_body!(v::RefView, block::UInt64)
    block in v.block_ids || return false
    block in v.invalid_body_truth || return false
    block in v.good && return false
    push!(v.invalid, block); delete!(v.rejected, block); return true
end

function deliver_context!(v::RefView, history::UInt64, block::UInt64, valid::Bool)
    history in v.history_ids && block in v.block_ids || return false
    key = (history, block)
    get(v.context_truth, key, nothing) === valid || return false
    if valid
        key in v.context_invalid && return false
        push!(v.context_good, key)
    else
        key in v.context_good && return false
        push!(v.context_invalid, key)
    end
    return true
end
function deliver_context!(v::FastView, history::UInt64, block::UInt64, valid::Bool)
    history in v.history_ids || return false
    id = get(v.block_index, block, 0); id > 0 || return false
    get(v.context_truth, (history, block), nothing) === valid || return false
    good = get!(v.context_good, history, BitSet())
    bad = get!(v.context_invalid, history, BitSet())
    if valid
        id in bad && return false
        push!(good, id)
    else
        id in good && return false
        push!(bad, id)
    end
    return true
end

function clone_public(s::PublicState)
    counted = Dict{UInt64,Vector{EventId}}(window => copy(events)
                                                   for (window, events) in s.counted)
    payable = Dict{UInt64,Vector{EventId}}(window => copy(events)
                                                   for (window, events) in s.payable)
    return PublicState(s.current, copy(s.journal), counted, payable, copy(s.inert),
                       copy(s.applied_blocks), copy(s.consumed), copy(s.path))
end

function public_projection(s::PublicState)
    events = [(e.history, e.block) for e in s.journal]
    counted = sort([(w, [(e.history, e.block) for e in es]) for (w, es) in s.counted]; by=first)
    payable = sort([(w, [(e.history, e.block) for e in es]) for (w, es) in s.payable]; by=first)
    inert = sort([(x.history, x.window, x.block) for x in s.inert])
    return (current=s.current, journal=events, counted=counted, payable=payable,
            inert=inert, applied_blocks=sort!(collect(s.applied_blocks)),
            consumed=sort!(collect(s.consumed)), path=copy(s.path))
end

function projection(v::AbstractView)
    return (policy=v.policy, public=public_projection(v.public),
            undo=[public_projection(s) for s in v.undo], pending=v.pending)
end
