#= escalado del kernel MC · se ejecuta con JULIA_NUM_THREADS=h para h = 1,2,4,8 =#
using Printf, StableRNGs
const DIR = @__DIR__
include(joinpath(DIR, "..", "src", "modelo.jl"))
include(joinpath(DIR, "..", "src", "referencia.jl"))
include(joinpath(DIR, "..", "src", "rapido.jl"))
using .Modelo, .Rapido
ret = Retencion(0.5, 3600.0)
# calentamiento
saldo_mc(UInt64(0x9), 1000, 1.0, 0.01, ret, 1.0; K = 32, hilos = true)
t = @elapsed v = saldo_mc(UInt64(0x9), 2_000_000, 1.0, 0.01, ret, 1.0; K = 32, hilos = true)
@printf("%d\t%.4f\n", Threads.nthreads(:default), t)
