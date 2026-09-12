# Sparse opaque IDs: typed hash maps; private staging is the atomicity boundary.
# Expected O(n log n + transactions + state), memory O(n + transactions + state).
function transition!(s::State,b::Batch,blue::Bool=false)
    (b.ctx==0 || b.ctx in s.active || b.parent!=s.ctx || b.slot<s.slot) && return :Invalid
    ids=Set{UInt64}(); ranks=Set{UInt64}(); seen=Set(s.seen)
    slots=Dict{UInt64,UInt64}(a.ticket=>a.slot for a in s.ledger)
    pending=false
    txseen=Dict{UInt64,Tuple{UInt8,UInt64,UInt64}}()
    # Profile-driven capacity reservation only; no checks or ordering rules removed.
    n=length(b.blocks); ntx=sum(x->length(x.txs),b.blocks;init=0)
    sizehint!(ids,n); sizehint!(ranks,n); sizehint!(slots,length(s.ledger)+n)
    sizehint!(txseen,ntx)
    for x in b.blocks
        (x.id==0 || x.ticket==0 || x.id in ids || x.id in seen || x.rank in ranks || x.slot>b.slot) && return :Invalid
        (x.color!=UInt8('B') && x.color!=UInt8('R') && x.color!=UInt8('U')) && return :Invalid
        (x.body!=UInt8('V') && x.body!=UInt8('P')) && return :Invalid
        haskey(slots,x.ticket) && slots[x.ticket]!=x.slot && return :Invalid
        slots[x.ticket]=x.slot; push!(ids,x.id); push!(ranks,x.rank)
        pending |= x.body==UInt8('P')
        for tx in x.txs
            (tx.id==0 || tx.key==0 || (tx.domain!=UInt8('T') && tx.domain!=UInt8('S'))) && return :Invalid
            binding=(tx.domain,tx.key,tx.fee)
            haskey(txseen,tx.id) && txseen[tx.id]!=binding && return :Invalid
            txseen[tx.id]=binding
        end
    end
    pending && return :Pending
    occupied=Set(a.ticket for a in s.ledger)
    choices=Dict{UInt64,Int}()
    sizehint!(choices,n)
    lo=b.slot>b.window ? b.slot-b.window : UInt64(0)
    for (i,x) in enumerate(b.blocks)
        (x.slot<lo || x.color==UInt8('U') || x.ticket in occupied) && continue
        j=get(choices,x.ticket,0)
        if j==0
            choices[x.ticket]=i
        else
            y=b.blocks[j]
            better = blue && (x.color==UInt8('B'))!=(y.color==UInt8('B')) ? x.color==UInt8('B') : x.rank<y.rank
            better && (choices[x.ticket]=i)
        end
    end
    selected=collect(values(choices)); sort!(selected;by=i->b.blocks[i].rank)
    out=copy(s); spent=Set(s.spent); accepted=Set(s.accepted)
    sizehint!(out.ledger,length(s.ledger)+length(selected))
    sizehint!(spent,length(s.spent)+ntx); sizehint!(accepted,length(s.accepted)+ntx)
    sizehint!(out.accepted,length(s.accepted)+ntx); sizehint!(out.spent,length(s.spent)+ntx)
    sizehint!(out.seen,length(s.seen)+n)
    try
        for i in selected
            x=b.blocks[i]
            push!(out.ledger,Award(x.ticket,x.id,b.ctx,x.slot))
            out.count=checked_add(out.count,UInt64(1)); out.subsidy=checked_add(out.subsidy,x.subsidy)
            for tx in x.txs
                key=(tx.domain,tx.key)
                if !(tx.id in accepted) && !(key in spent)
                    out.fees=checked_add(out.fees,tx.fee)
                    push!(accepted,tx.id); push!(spent,key)
                    push!(out.accepted,tx.id); push!(out.spent,key)
                end
            end
        end
    catch err
        err isa OverflowError || rethrow()
        return :Invalid
    end
    append!(out.seen,(x.id for x in b.blocks)); out.ctx=b.ctx; out.slot=b.slot
    push!(out.active,b.ctx)
    s.ctx=out.ctx; s.slot=out.slot; s.count=out.count; s.subsidy=out.subsidy; s.fees=out.fees
    s.ledger=out.ledger; s.accepted=out.accepted; s.spent=out.spent; s.seen=out.seen
    s.active=out.active
    :Applied
end
