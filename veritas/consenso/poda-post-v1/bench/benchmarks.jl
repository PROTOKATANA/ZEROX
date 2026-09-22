# PPP-v0.1 — microbenchmarks del kernel (LINEO §6). Un hilo salvo que se indique.
using BenchmarkTools
using Printf

include(joinpath(@__DIR__, "..", "src", "PodaPost.jl"))
using .PodaPost
using StableRNGs

const SR = UInt64(1) << 62
const N = 1_000_000

function calentar()
    rng = StableRNG(UInt64(1))
    c = zeros(Int, 48)
    contar_niveles!(c, rng, 8, SR, 1000, 48)
    return nothing
end
calentar()

println("julia ", VERSION, "  hilos=", Threads.nthreads(:default), "  cpu=", Sys.CPU_NAME)
for C in (1, 8, 64)
    rng = StableRNG(UInt64(0xC0FFEE))
    conteo = zeros(Int, 48)
    trial = @benchmark contar_niveles!($conteo, $rng, $C, $SR, $N, 48)
    mn = minimum(trial)
    @printf("C=%3d  N=%d  mediana=%.3f ms  min=%.3f ms  allocs=%d  mem=%d B\n",
            C, N, median(trial).time / 1e6, mn.time / 1e6, mn.allocs, mn.memory)
end
