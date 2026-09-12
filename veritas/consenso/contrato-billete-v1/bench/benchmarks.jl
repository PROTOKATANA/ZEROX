include("../src/modelo.jl")
using .CBE, BenchmarkTools, Profile, InteractiveUtils, JET, StableRNGs, Statistics, LinearAlgebra
function measured(b,blue)
    s=CBE.State(); CBE.transition!(s,b,blue); s
end
function benchmain()
    ix=findfirst(==("--seed"),ARGS); ix===nothing && error("required --seed")
    seed=parse(UInt64,ARGS[ix+1])
    out=joinpath(@__DIR__,"..","resultados"); mkpath(out)
    raw=CBE.random_batch(StableRNG(seed),180)
    b=CBE.Batch(raw.ctx,raw.parent,raw.slot,UInt64(10),raw.blocks)
    cold=@elapsed measured(b,false)
    rs,r=CBE.reference(CBE.State(),b,false); fast=measured(b,false)
    @assert rs==:Applied && CBE.snapshot(r)==CBE.snapshot(fast)
    measured(b,false); CBE.reference(CBE.State(),b,false)
    base=@benchmark CBE.reference(s,$b,false) setup=(s=CBE.State()) samples=100 evals=1 seconds=1
    typed=@benchmark measured($b,false) samples=100 evals=1 seconds=1
    alloc=@allocated measured(b,false)
    open(joinpath(out,"rendimiento.txt"),"w") do io
        println(io,"Julia=$VERSION CPU=$(Sys.CPU_NAME) threads=$(Threads.nthreads(:default))/$(Threads.nthreads(:interactive)) n=180 seed=$seed")
        println(io,"first_timed_call_seconds=$cold warmed_allocated_bytes=$alloc (excludes_process_startup_and_prior_compilation)")
        println(io,"W_adm=10 initial_state=empty applied_awards=$(fast.count) accepted_transactions=$(length(fast.accepted)) RAM_bytes=$(Sys.total_memory()) BLAS=$(BLAS.get_config())")
        for (name,t) in (("reference",base),("typed",typed))
            m=median(t); println(io,"$name median_ns=$(m.time) bytes=$(m.memory) allocations=$(m.allocs)")
        end
    end
    open(joinpath(out,"warntype.txt"),"w") do io
        code_warntype(io,CBE.transition!,Tuple{CBE.State,CBE.Batch,Bool};debuginfo=:none)
    end
    open(joinpath(out,"jet.txt"),"w") do io
        show(io,MIME("text/plain"),JET.report_opt(CBE.transition!,Tuple{CBE.State,CBE.Batch,Bool}))
    end
    Profile.clear()
    Profile.@profile for _ in 1:10000
        measured(b,false)
    end
    open(joinpath(out,"profile.txt"),"w") do io
        Profile.print(io;format=:flat,sortedby=:count)
    end
    println(read(joinpath(out,"rendimiento.txt"),String))
end
benchmain()
