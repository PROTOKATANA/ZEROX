# benchmarks.jl — microbenchmarks del kernel (LINEO §5.1, §6).
# Ejecutar: env -u LD_LIBRARY_PATH julia --project=. bench/benchmarks.jl
using BenchmarkTools
using Printf
using StableRNGs
include(joinpath(@__DIR__, "..", "src", "CosteRamaPrivadaV2.jl"))
using .CosteRamaPrivadaV2

function main()
    println("Benchmark CRP-v0.2 — kernel y simulación")
    # calentamiento (JIT)
    prob_superar_dp(Float64, 6, 0.9, 0.1, 200)
    prob_superar_finita(6, 9//10, 1//10, 50)
    simular!(ConfigSim(; n_honestos=4, p_honesto=0.25, delta=2, S=1, T=100, t_fork=1),
             StableRNG(1); k=2)

    t_dp = @benchmark prob_superar_dp(Float64, 6, 0.9, 0.1, 2000)
    t_ex = @benchmark prob_superar_finita(6, 9//10, 1//10, 200)
    t_sim = @benchmark simular!(ConfigSim(; n_honestos=4, p_honesto=0.25, delta=2, S=1,
                                          T=400, t_fork=1, p_adversario=0.0), $(StableRNG(1)); k=2)

    @printf("| %-30s | %12.3f µs | %10d | %s |\n", "DP d=6 T=2000", minimum(t_dp).time / 1e3,
            minimum(t_dp).allocs, "referencia DP acotada")
    @printf("| %-30s | %12.3f µs | %10d | %s |\n", "exacta Rational d=6 T=200",
            minimum(t_ex).time / 1e3, minimum(t_ex).allocs, "oráculo exacto")
    @printf("| %-30s | %12.3f ms | %10d | %s |\n", "DAG sim 4 nodos 400 slots",
            minimum(t_sim).time / 1e6, minimum(t_sim).allocs, "GDR-v0.2 oráculo")

    println("\nEscalado de réplicas independientes (barrido MC) 1..8 hilos")
    for nthreads in (1, 2, 4, 8)
        # Julia no cambia nthreads en caliente; se documenta la línea de ejecución.
        @printf("hilos=%d (requiere JULIA_NUM_THREADS=%d en arranque)\n", nthreads, nthreads)
    end
    println("Nota: el barrido de réplicas es determinista por semilla de réplica;")
    println("la reducción es ordenada por ID, de modo que 1..N hilos dan el mismo resultado.")
    return nothing
end

main()
