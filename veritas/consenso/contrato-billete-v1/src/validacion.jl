using Test, Random, StableRNGs
u(s)=parse(UInt64,s)
function fixtures(path::String; output::IO=stdout)
    state=State(); ref=State(); undo=Undo[]; rundo=State[]
    batch=Batch(0,0,0,0,Block[]); blue=false; status=:Invalid; name=""; checks=0
    for raw in eachline(path)
        line=strip(first(split(raw,'#'))); isempty(line) && continue
        p=split(line); op=p[1]
        if op=="CASE"
            name=p[2]; blue=p[3]=="blue"; state=State(); ref=State(); empty!(undo); empty!(rundo)
        elseif op=="BATCH"
            batch=Batch(u(p[2]),u(p[3]),u(p[4]),u(p[5]),Block[])
        elseif op=="BLOCK"
            push!(batch.blocks,Block(u(p[2]),u(p[3]),u(p[4]),u(p[5]),UInt8(only(p[6])),UInt8(only(p[7])),u(p[8]),Tx[]))
        elseif op=="TX"
            push!(last(batch.blocks).txs,Tx(u(p[2]),UInt8(only(p[3])),u(p[4]),u(p[5])))
        elseif op=="APPLY"
            old=copy(state); rold=copy(ref)
            rs,rnext=reference(ref,batch,blue); status=transition!(state,batch,blue)
            @test status==rs
            @test snapshot(state)==snapshot(rnext)
            ref=rnext
            if status==:Applied
                push!(undo,Undo(old,copy(state))); push!(rundo,rold)
            else
                @test snapshot(state)==snapshot(old)
            end
        elseif op=="UNDO"
            if isempty(undo)
                status=:Invalid
            else
                status=undo!(state,pop!(undo)); ref=pop!(rundo)
            end
            @test snapshot(state)==snapshot(ref)
        elseif op=="EXPECT"
            got=string(status," ",snapshot(state)); want=join(p[2:end]," ")
            @test got==want
            println(output,name," ",got); checks+=1
        elseif op!="END"
            error("unknown fixture operation: $op")
        end
    end
    checks
end
function random_batch(rng,n::Int)
    xs=Block[]
    for i in 1:n
        ticket=rand(rng,1:max(1,n÷2)); slot=UInt64(ticket%8)
        txs=Tx[Tx(UInt64(i*10+j),rand(rng,UInt8.(['T','S'])),UInt64(rand(rng,1:8)),UInt64(rand(rng,0:20))) for j in 1:rand(rng,0:3)]
        push!(xs,Block(UInt64(i),UInt64(ticket),slot,UInt64(i-1),rand(rng,UInt8.(['B','R','U'])),UInt8('V'),UInt64(rand(rng,0:20)),txs))
    end
    shuffle!(rng,xs); Batch(1,0,10,rand(rng,UInt64(0):UInt64(12)),xs)
end
function save_failure(b::Batch,seed::UInt64,replica::Int,blue::Bool,status::Symbol,r::State)
    directory=joinpath(@__DIR__,"..","resultados"); mkpath(directory)
    path=joinpath(directory,"FALLO-$(seed)-$(replica)-$(blue).txt")
    open(path,"w") do io
        println(io,"# seed=$seed replica=$replica Julia=$VERSION; bounded input, not automatically minimized")
        println(io,"CASE replay ",blue ? "blue" : "first")
        println(io,"BATCH $(b.ctx) $(b.parent) $(b.slot) $(b.window)")
        for x in b.blocks
            println(io,"BLOCK $(x.id) $(x.ticket) $(x.slot) $(x.rank) $(Char(x.color)) $(Char(x.body)) $(x.subsidy)")
            for tx in x.txs
                println(io,"TX $(tx.id) $(Char(tx.domain)) $(tx.key) $(tx.fee)")
            end
        end
        println(io,"APPLY\nEXPECT $status ",snapshot(r),"\nEND")
    end
    path
end
function validate(seed::UInt64; replicas::Int=500)
    rng=StableRNG(seed)
    @testset "exact reference / typed kernel" begin
        for replica in 1:replicas
            b=random_batch(rng,rand(rng,0:40))
            for blue in (false,true)
                s=State(); rs,r=reference(s,b,blue); status=transition!(s,b,blue)
                if status!=rs || !equivalent(s,r)
                    save_failure(b,seed,replica,blue,rs,r)
                end
                @test status==rs
                @test equivalent(s,r)
                perm=Batch(b.ctx,b.parent,b.slot,b.window,shuffle(rng,b.blocks)); t=State()
                @test transition!(t,perm,blue)==status
                @test snapshot(t)==snapshot(s)
                @test length(unique(a.ticket for a in s.ledger))==length(s.ledger)
                @test s.count==length(s.ledger)
                @test length(unique(s.accepted))==length(s.accepted)
                old=copy(s); @test transition!(s,b,blue)==:Invalid
                @test snapshot(s)==snapshot(old)
            end
        end
        one=Block(1,1,0,0,UInt8('B'),UInt8('V'),1,Tx[])
        b=Batch(1,0,0,0,[one])
        for field in (:count,:subsidy)
            s=State(); setfield!(s,field,typemax(UInt64)); old=snapshot(s)
            rs,r=reference(s,b); @test rs==:Invalid
            @test transition!(s,b)==:Invalid; @test snapshot(s)==old==snapshot(r)
        end
        pend=Block(2,2,0,1,UInt8('U'),UInt8('P'),0,Tx[])
        s=State(); s.subsidy=typemax(UInt64)
        @test transition!(s,Batch(1,0,0,0,[one,pend]))==:Pending
        bad=Block(3,3,0,2,UInt8('R'),UInt8('I'),0,Tx[])
        @test transition!(s,Batch(1,0,0,0,[one,pend,bad]))==:Invalid
        initial=State(); applied=copy(initial); @test transition!(applied,b)==:Applied
        undo=Undo(copy(initial),copy(applied))
        wrong=copy(applied); wrong.fees=1; old=copy(wrong)
        @test undo!(wrong,undo)==:Invalid; @test equivalent(wrong,old)
        @test undo!(initial,undo)==:Invalid
        @test undo!(applied,undo)==:Reverted; @test equivalent(applied,State())
        transition!(applied,b); old=copy(applied)
        @test reorganize!(applied,[undo],[Batch(2,0,0,0,[pend])])==:Pending
        @test equivalent(applied,old)
        @test reorganize!(applied,[undo],[Batch(2,0,0,0,[bad])])==:Invalid
        @test equivalent(applied,old)
        first=Batch(2,0,0,0,[one])
        @test reorganize!(applied,[undo],[first,Batch(3,2,0,0,[pend])])==:Pending
        @test equivalent(applied,old)
        @test reorganize!(applied,[undo],[first,Batch(3,2,0,0,[bad])])==:Invalid
        @test equivalent(applied,old)
        @test reorganize!(applied,[undo],[Batch(2,0,0,0,[one])])==:Applied
        @test applied.ctx==2 && !(UInt64(1) in applied.active)
    end
    replicas
end
