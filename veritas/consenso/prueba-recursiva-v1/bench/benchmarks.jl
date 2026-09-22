# PRV-v0.1 — microbenchmarks del conteo y del modelo de coste (LINEO §6).
using BenchmarkTools
using Printf
using StableRNGs

include(joinpath(@__DIR__, "..", "src", "PruebaRecursiva.jl"))
using .PruebaRecursiva

GDR = incluir_ghostdag()
rng = StableRNG(UInt64(0xB0E1))
especs = GDR.generar_dag(rng, 512, "B"; ventana=6)
est = Base.invokelatest(construir_estado, GDR, especs)
c = contar_rapido(est)          # calienta JIT
coste_restricciones(c, 1000, P_FACTORES)

function main()
    println("julia ", VERSION, "  hilos=", Threads.nthreads(:default), "  cpu=", Sys.CPU_NAME)
    for n in (128, 512)
        local rng = StableRNG(UInt64(0xB0E1) + UInt64(n))
        local especs = GDR.generar_dag(rng, n, "B"; ventana=6)
        local est = Base.invokelatest(construir_estado, GDR, especs)
        contar_rapido(est)
        trial = @benchmark contar_rapido($est)
        mn = minimum(trial)
        @printf("contar_rapido n=%4d  mediana=%.3f ms  min=%.3f ms  allocs=%d\n",
                n, median(trial).time / 1e6, mn.time / 1e6, mn.allocs)
    end
    trial = @benchmark coste_restricciones($c, 1000, $P_FACTORES)
    @printf("coste_restricciones(1000)  mediana=%.3f µs  allocs=%d\n",
            median(trial).time / 1e3, minimum(trial).allocs)
end

main()
