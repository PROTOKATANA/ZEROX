# CRP-v0.1 — microbenchmarks del kernel. Calienta JIT antes de medir.
using BenchmarkTools
using StableRNGs

include(joinpath(@__DIR__, "..", "src", "CosteRamaPrivada.jl"))
using .CosteRamaPrivada

const P = P_DEFECTO

# calentamiento
let rng = StableRNG(1)
    simular_rama_rapido(rng, 0.5, P; n_slots=100)
    prob_alcance_dp(0.4, 16.0, 600; d=6)
    peso_exacto(P.sr0)
    cota_invariancia(P.sr0)
end

println("== BenchmarkTools · CRP-v0.1 ==")
println("hilos: ", Threads.nthreads(:default))

t1 = @benchmark simular_rama_rapido($(StableRNG(1)), 0.5, $P; n_slots=1000)
println("\nsimular_rama_rapido (1000 slots, 1 rama):")
show(stdout, MIME("text/plain"), t1); println()
@show minimum(t1).time minimum(t1).memory minimum(t1).allocs

t2 = @benchmark prob_alcance_dp(0.4, 16.0, 600; d=6)
println("\nprob_alcance_dp (g=16, d=6):")
show(stdout, MIME("text/plain"), t2); println()
@show minimum(t2).time minimum(t2).memory minimum(t2).allocs

t3 = @benchmark cota_invariancia($P.sr0)
println("\ncota_invariancia (exacto, 7 sr):")
show(stdout, MIME("text/plain"), t3); println()
@show minimum(t3).time minimum(t3).memory minimum(t3).allocs

# barrido de α completo (paralelo interno por hilos)
t4 = @benchmark barrido_alpha($P, (0.4, 0.5, 0.6); n_rep=200, n_slots=300)
println("\nbarrido_alpha (3 α, 200 rep, 300 slots):")
show(stdout, MIME("text/plain"), t4); println()
@show minimum(t4).time minimum(t4).memory minimum(t4).allocs
