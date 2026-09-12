module CBE
using Base.Checked: checked_add
struct Tx
    id::UInt64
    domain::UInt8
    key::UInt64
    fee::UInt64
end
struct Block
    id::UInt64
    ticket::UInt64
    slot::UInt64
    rank::UInt64
    color::UInt8
    body::UInt8
    subsidy::UInt64
    txs::Vector{Tx}
end
struct Batch
    ctx::UInt64
    parent::UInt64
    slot::UInt64
    window::UInt64
    blocks::Vector{Block}
end
struct Award
    ticket::UInt64
    block::UInt64
    ctx::UInt64
    slot::UInt64
end
mutable struct State
    ctx::UInt64
    slot::UInt64
    count::UInt64
    subsidy::UInt64
    fees::UInt64
    ledger::Vector{Award}
    accepted::Vector{UInt64}
    spent::Vector{Tuple{UInt8,UInt64}}
    seen::Vector{UInt64}
    active::Vector{UInt64}
end
State() = State(0,0,0,0,0,Award[],UInt64[],Tuple{UInt8,UInt64}[],UInt64[],UInt64[0])
Base.copy(s::State) = State(s.ctx,s.slot,s.count,s.subsidy,s.fees,copy(s.ledger),copy(s.accepted),copy(s.spent),copy(s.seen),copy(s.active))
function restore!(s::State, old::State)
    s.ctx=old.ctx; s.slot=old.slot; s.count=old.count; s.subsidy=old.subsidy; s.fees=old.fees
    s.ledger=copy(old.ledger); s.accepted=copy(old.accepted); s.spent=copy(old.spent); s.seen=copy(old.seen)
    s.active=copy(old.active)
    s
end
equivalent(a::State,b::State)=snapshot(a)==snapshot(b) && a.active==b.active
struct Undo
    before::State
    after::State
end
function undo!(s::State,u::Undo)
    equivalent(s,u.after) || return :Invalid
    restore!(s,u.before); :Reverted
end
function reorganize!(s::State,undos::Vector{Undo},batches::Vector{Batch},blue::Bool=false)
    staged=copy(s)
    for u in undos
        undo!(staged,u)==:Reverted || return :Invalid
    end
    for b in batches
        status=transition!(staged,b,blue)
        status==:Applied || return status
    end
    restore!(s,staged); :Applied
end
function snapshot(s::State)
    entries=sort(s.ledger;by=x->x.ticket)
    ledger=isempty(entries) ? "-" : join(("$(x.ticket):$(x.block):$(x.ctx):$(x.slot)" for x in entries),",")
    accepted=isempty(s.accepted) ? "-" : join(s.accepted,",")
    spent=isempty(s.spent) ? "-" : join(("$(Char(d)):$(k)" for (d,k) in sort(s.spent;by=x->(x[1]==UInt8('T') ? 0 : 1,x[2]))),",")
    seen=isempty(s.seen) ? "-" : join(sort(s.seen),",")
    "$(s.ctx) $(s.slot) $(s.count) $(s.subsidy) $(s.fees) $ledger $accepted $spent $seen"
end
include("referencia.jl")
include("rapido.jl")
include("validacion.jl")
end
