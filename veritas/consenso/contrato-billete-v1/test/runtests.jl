include("../src/modelo.jl")
using .CBE, Test
CBE.validate(UInt64(0x5a5a))
@testset "fixtures" begin
    CBE.fixtures(joinpath(@__DIR__,"..","fixtures","CASOS.txt"))
end
