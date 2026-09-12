include("src/modelo.jl")
using .CBE
using Test, Pkg, LinearAlgebra
function main(args)
    ix=findfirst(==("--seed"),args)
    ix===nothing && error("required: --seed INTEGER")
    seed=parse(UInt64,args[ix+1])
    directory=joinpath(@__DIR__,"resultados"); mkpath(directory)
    artifact=joinpath(directory,"validacion.txt")
    open(artifact,"w") do io
        redirect_stdout(io) do
            println("seed=$seed Julia=$(VERSION) CPU=$(Sys.CPU_NAME) threads=$(Threads.nthreads(:default))/$(Threads.nthreads(:interactive))")
            println("RAM_bytes=$(Sys.total_memory()) BLAS=$(BLAS.get_config()) args=$(join(args,' '))")
            println("git_head=",readchomp(`git rev-parse HEAD`))
            Pkg.status(;io=stdout)
            elapsed=@elapsed begin
                CBE.validate(seed)
                path=joinpath(@__DIR__,"fixtures","CASOS.txt")
                isfile(path) || error("shared fixtures missing")
                @testset "shared Rust/Julia fixtures" begin
                    checks=CBE.fixtures(path)
                    println("fixture_EXPECT_count=$checks")
                end
            end
            println("validation_wall_seconds=$elapsed")
        end
    end
    print(read(artifact,String))
end
main(ARGS)
