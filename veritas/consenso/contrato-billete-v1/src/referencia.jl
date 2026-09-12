# Independent exact oracle: linear scans, group selection, BigInt money.
function reference(s::State,b::Batch,blue::Bool=false)
    invalid = b.ctx==0 || b.ctx in s.active || b.parent!=s.ctx || b.slot<s.slot
    ids=UInt64[]; ranks=UInt64[]
    txseen=Tx[]
    for (i,x) in enumerate(b.blocks)
        invalid |= x.id==0 || x.ticket==0 || x.id in ids || x.id in s.seen || x.rank in ranks || x.slot>b.slot
        invalid |= !(x.color in UInt8.(['B','R','U'])) || !(x.body in UInt8.(['V','P','I'])) || x.body==UInt8('I')
        for y in b.blocks[1:i-1]
            invalid |= x.ticket==y.ticket && x.slot!=y.slot
        end
        for a in s.ledger
            invalid |= x.ticket==a.ticket && x.slot!=a.slot
        end
        for tx in x.txs
            invalid |= tx.id==0 || tx.key==0 || !(tx.domain in UInt8.(['T','S']))
            for prev in txseen
                invalid |= tx.id==prev.id && (tx.domain!=prev.domain || tx.key!=prev.key || tx.fee!=prev.fee)
            end
            push!(txseen,tx)
        end
        push!(ids,x.id); push!(ranks,x.rank)
    end
    invalid && return (:Invalid,copy(s))
    any(x->x.body==UInt8('P'),b.blocks) && return (:Pending,copy(s))
    lo=b.slot>b.window ? b.slot-b.window : UInt64(0)
    eligible=[x for x in b.blocks if x.slot>=lo && x.color!=UInt8('U') && !any(a->a.ticket==x.ticket,s.ledger)]
    winners=Block[]
    for ticket in unique([x.ticket for x in eligible])
        group=[x for x in eligible if x.ticket==ticket]
        if blue && any(x->x.color==UInt8('B'),group)
            group=[x for x in group if x.color==UInt8('B')]
        end
        push!(winners,group[argmin([x.rank for x in group])])
    end
    sort!(winners;by=x->x.rank)
    out=copy(s); n=BigInt(s.count); sub=BigInt(s.subsidy); fees=BigInt(s.fees)
    for x in winners
        push!(out.ledger,Award(x.ticket,x.id,b.ctx,x.slot)); n+=1; sub+=BigInt(x.subsidy)
        for tx in x.txs
            key=(tx.domain,tx.key)
            if !(tx.id in out.accepted) && !(key in out.spent)
                push!(out.accepted,tx.id); push!(out.spent,key); fees+=BigInt(tx.fee)
            end
        end
    end
    any(v->v>typemax(UInt64),(n,sub,fees)) && return (:Invalid,copy(s))
    out.count=UInt64(n); out.subsidy=UInt64(sub); out.fees=UInt64(fees)
    append!(out.seen,ids); out.ctx=b.ctx; out.slot=b.slot
    push!(out.active,b.ctx)
    (:Applied,out)
end
