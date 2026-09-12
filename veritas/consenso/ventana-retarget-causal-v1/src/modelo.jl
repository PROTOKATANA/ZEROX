@enum ApplyCode::UInt8 Applied Pending Invalid
@enum BlockStatus::UInt8 Complete PendingData Bad
@enum Color::UInt8 Blue RedK RedU3
@enum SelectionPolicy::UInt8 P0 P1
@enum ControllerCode::UInt8 Bootstrap ControllerPending Ready

struct WindowSpec
    origin::UInt64
    width::UInt64
    grace::UInt64
    function WindowSpec(origin::UInt64, width::UInt64, grace::UInt64)
        origin == 0 || throw(ArgumentError("this profile anchors controller origin at genesis"))
        width > 0 || throw(ArgumentError("window width must be positive"))
        Base.Checked.checked_add(origin, width)
        Base.Checked.checked_add(Base.Checked.checked_add(origin, width), grace)
        new(origin, width, grace)
    end
end
WindowSpec(origin::Integer, width::Integer, grace::Integer) =
    WindowSpec(UInt64(origin), UInt64(width), UInt64(grace))

abstract type LateRule end
struct L0Rule <: LateRule
    admission_width::UInt64
end
L0Rule(width::Integer) = L0Rule(UInt64(width))
struct LGRule <: LateRule end

struct Scenario{R<:LateRule}
    selection::SelectionPolicy
    late::R
    controller::WindowSpec
end

struct Candidate
    block_id::UInt64
    ticket_id::UInt64
    original_slot::UInt64
    rank::UInt64
    color::Color
    status::BlockStatus
    subsidy::UInt64
    fees::UInt64
end
Candidate(block_id::Integer, ticket_id::Integer, original_slot::Integer, rank::Integer,
          color::Color, status::BlockStatus, subsidy::Integer, fees::Integer) =
    Candidate(UInt64(block_id), UInt64(ticket_id), UInt64(original_slot), UInt64(rank),
              color, status, UInt64(subsidy), UInt64(fees))

struct Batch
    context_id::UInt64
    parent_context::UInt64
    incorporation_slot::UInt64
    blocks::Vector{Candidate}
end
Batch(context_id::Integer, parent_context::Integer, incorporation_slot::Integer,
      blocks::Vector{Candidate}) =
    Batch(UInt64(context_id), UInt64(parent_context), UInt64(incorporation_slot), blocks)

struct EventId
    context_id::UInt64
    block_id::UInt64
end
EventId(context_id::Integer, block_id::Integer) = EventId(UInt64(context_id), UInt64(block_id))

Base.isless(a::EventId, b::EventId) = (a.context_id, a.block_id) < (b.context_id, b.block_id)

struct Event
    event_id::EventId
    ticket_id::UInt64
    block_id::UInt64
    original_slot::UInt64
    incorporation_slot::UInt64
    context_id::UInt64
    accounting_window::Union{Nothing,UInt64}
    subsidy::UInt64
    fees::UInt64
end

struct WindowSeal
    event_ids::Vector{EventId}
    context_id::UInt64
    context_slot::UInt64
end

mutable struct State
    context_id::UInt64
    context_slot::UInt64
    journal::Vector{Event}
    used_tickets::Dict{UInt64,EventId}
    ticket_slots::Dict{UInt64,UInt64}
    seen_blocks::Set{UInt64}
    sealed_windows::Dict{UInt64,WindowSeal}
    causal_exclusions::Vector{UInt64}
end

State() = State(0, 0, Event[], Dict{UInt64,EventId}(), Dict{UInt64,UInt64}(), Set{UInt64}(),
                Dict{UInt64,WindowSeal}(), UInt64[])

struct UndoRecord
    old_context::UInt64
    old_slot::UInt64
    new_context::UInt64
    journal_length::Int
    added_tickets::Vector{UInt64}
    added_blocks::Vector{UInt64}
    exclusion_length::Int
end

struct ApplyResult
    code::ApplyCode
    state::State
    undo_state::Union{Nothing,UndoRecord}
    winners::Vector{UInt64}
    reason::Symbol
end

struct ControllerResult
    code::ControllerCode
    window_id::UInt64
    event_ids::Vector{EventId}
end

@inline function window_id(spec::WindowSpec, slot::UInt64)
    slot >= spec.origin || return nothing
    return (slot - spec.origin) ÷ spec.width
end

@inline function window_bounds(spec::WindowSpec, id::UInt64)
    start = Base.Checked.checked_add(spec.origin, Base.Checked.checked_mul(id, spec.width))
    stop = Base.Checked.checked_add(start, spec.width)
    cutoff = Base.Checked.checked_add(stop, spec.grace)
    return start, stop, cutoff
end

@inline economically_colored(b::Candidate) = b.color === Blue || b.color === RedK

@inline function timely(rule::L0Rule, ::WindowSpec, b::Candidate, incorporation::UInt64)
    lo = incorporation >= rule.admission_width ? incorporation - rule.admission_width : UInt64(0)
    return lo <= b.original_slot <= incorporation
end

@inline function timely(::LGRule, spec::WindowSpec, b::Candidate, incorporation::UInt64)
    id = window_id(spec, b.original_slot)
    id === nothing && return false
    start, stop, cutoff = window_bounds(spec, id)
    # The cutoff slot is processed in two phases: close first, then incorporate.
    return start <= b.original_slot < stop && incorporation < cutoff
end

function basic_validation(state::State, batch::Batch)
    batch.parent_context == state.context_id || return :wrong_parent
    batch.context_id != state.context_id || return :reused_context
    batch.incorporation_slot >= state.context_slot || return :decreasing_context_slot
    ids = Set{UInt64}()
    ranks = Set{UInt64}()
    ticket_slots = Dict{UInt64,UInt64}()
    for b in batch.blocks
        b.block_id > 0 && b.ticket_id > 0 || return :zero_identifier
        b.original_slot <= batch.incorporation_slot || return :future_slot
        (b.block_id in ids || b.block_id in state.seen_blocks) && return :duplicate_block
        b.rank in ranks && return :duplicate_rank
        push!(ids, b.block_id)
        push!(ranks, b.rank)
        prior_slot = get(ticket_slots, b.ticket_id, b.original_slot)
        prior_slot == b.original_slot || return :ticket_slot_mismatch
        ticket_slots[b.ticket_id] = b.original_slot
        if haskey(state.used_tickets, b.ticket_id)
            get(state.ticket_slots, b.ticket_id, typemax(UInt64)) == b.original_slot ||
                return :ticket_slot_mismatch
        end
        b.status === Bad && return :invalid_block
    end
    any(b -> b.status === PendingData, batch.blocks) && return :pending_data
    return :ok
end

function event_for(state::State, batch::Batch, spec::WindowSpec, b::Candidate)
    id = window_id(spec, b.original_slot)
    return Event(EventId(batch.context_id, b.block_id), b.ticket_id, b.block_id, b.original_slot,
                 batch.incorporation_slot, batch.context_id, id, b.subsidy, b.fees)
end

function payable_ids(state::State, id::UInt64)
    paid = Set(values(state.used_tickets))
    return EventId[e.event_id for e in state.journal
                   if e.accounting_window === id && e.event_id in paid]
end
payable_ids(state::State, id::Integer) = payable_ids(state, UInt64(id))

# Conteo usa el snapshot sellado si existe; pago se deriva del ledger económico actual.
# Esa independencia permite detectar el contraejemplo retroactivo de L0.
function counted_ids(state::State, id::UInt64)
    seal = get(state.sealed_windows, id, nothing)
    seal === nothing || return copy(seal.event_ids)
    return EventId[e.event_id for e in state.journal if e.accounting_window === id]
end
counted_ids(state::State, id::Integer) = counted_ids(state, UInt64(id))

causal_sufficient(scenario::Scenario{L0Rule}) =
    scenario.controller.grace >= scenario.late.admission_width
causal_sufficient(::Scenario{LGRule}) = true

function unresolved_in_window(spec::WindowSpec, id::UInt64, pending_batches::Vector{Batch})
    start, stop, _ = window_bounds(spec, id)
    return any(batch -> any(b -> b.status === PendingData && start <= b.original_slot < stop,
                            batch.blocks), pending_batches)
end

function close_window!(state::State, spec::WindowSpec, id::UInt64, query_slot::UInt64;
                       pending_batches::Vector{Batch}=Batch[])
    _, _, cutoff = window_bounds(spec, id)
    query_slot <= state.context_slot || throw(ArgumentError("query exceeds applied history"))
    expected = isempty(state.sealed_windows) ? UInt64(0) :
               Base.Checked.checked_add(maximum(keys(state.sealed_windows)), UInt64(1))
    (haskey(state.sealed_windows, id) || id == expected) ||
        throw(ArgumentError("windows must close sequentially"))
    query_slot >= cutoff || return ControllerResult(Bootstrap, id, EventId[])
    existing = get(state.sealed_windows, id, nothing)
    existing === nothing || return ControllerResult(Ready, id, copy(existing.event_ids))
    unresolved_in_window(spec, id, pending_batches) &&
        return ControllerResult(ControllerPending, id, EventId[])
    ids = counted_ids(state, id)
    state.sealed_windows[id] = WindowSeal(copy(ids), state.context_id, state.context_slot)
    return ControllerResult(Ready, id, ids)
end
close_window!(state::State, spec::WindowSpec, id::Integer, query_slot::Integer; kwargs...) =
    close_window!(state, spec, UInt64(id), UInt64(query_slot); kwargs...)

function undo!(state::State, undo::UndoRecord)
    state.context_id == undo.new_context || throw(ArgumentError("undo context mismatch"))
    length(state.journal) >= undo.journal_length || throw(ArgumentError("undo journal mismatch"))
    resize!(state.journal, undo.journal_length)
    for ticket in undo.added_tickets
        delete!(state.used_tickets, ticket)
        delete!(state.ticket_slots, ticket)
    end
    for block in undo.added_blocks
        delete!(state.seen_blocks, block)
    end
    resize!(state.causal_exclusions, undo.exclusion_length)
    for (id, seal) in collect(state.sealed_windows)
        seal.context_id == undo.new_context && delete!(state.sealed_windows, id)
    end
    state.context_id = undo.old_context
    state.context_slot = undo.old_slot
    return state
end

@inline winner_key(::Val{P0}, b::Candidate) = (b.rank, b.rank)
@inline winner_key(::Val{P1}, b::Candidate) = (b.color === Blue ? UInt64(0) : UInt64(1), b.rank)
