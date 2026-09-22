# benchmarks.jl — microbenchmarks CRP-v0.3 (LINEO §5.1, §6).
using BenchmarkTools, Printf, StableRNGs
include(joinpath(@__DIR__, "..", "src", "CosteRamaPrivadaV3.jl"))
using .CosteRamaPrivadaV3

function main()
    println("Benchmark CRP-v0.3")
    prob_superar_dp(Float64, 6, 0.9, 0.1, 200)
    resultado_eventos(Float64, 4, 0.9, 0.1, 100)
    simular_v3!(ConfigSimV3(; n_honestos=4, alpha=0.2, delta=2, S=4, T=100, t_fork=1),
                StableRNG(1))

    t_dp = @benchmark prob_superar_dp(Float64, 6, 0.9, 0.1, 2000)
    t_ev = @benchmark resultado_eventos(Float64, 4, 0.9, 0.1, 200)
    t_sim = @benchmark simular_v3!(ConfigSimV3(; n_honestos=4, alpha=0.2, delta=2, S=4,
                                               T=200, t_fork=1), $(StableRNG(1)))
    @printf("| %-28s | %10.3f µs | %9d |\n", "DP d=6 T=2000", minimum(t_dp).time / 1e3, minimum(t_dp).allocs)
    @printf("| %-28s | %10.3f µs | %9d |\n", "eventos terminal+paso T=200", minimum(t_ev).time / 1e3, minimum(t_ev).allocs)
    @printf("| %-28s | %10.3f ms | %9d |\n", "DAG S=4 4 nodos 200 slots", minimum(t_sim).time / 1e6, minimum(t_sim).allocs)
    println("Nota: el simulador es serial y determinista; no se barajan hilos en caliente.")
end
main()
