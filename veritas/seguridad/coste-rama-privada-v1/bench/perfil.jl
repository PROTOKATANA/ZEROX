# CRP-v0.1 — perfil de la ruta real (LINEO §6). Ejecutar con --threads=1 para perfil serial.
using Profile
using StableRNGs

include(joinpath(@__DIR__, "..", "src", "CosteRamaPrivada.jl"))
using .CosteRamaPrivada

const P = P_DEFECTO

# calentamiento (no se perfila el JIT)
barrido_alpha(P, (0.5,); n_rep=100, n_slots=50)
simular_rama_rapido(StableRNG(1), 0.5, P; n_slots=100)

Profile.clear()
@profile barrido_alpha(P, (0.42, 0.50, 0.58); n_rep=6000, n_slots=400,
                       semilla=UInt64(0xE5CA1A))

println("== Perfil CRP-v0.1 (barrido_alpha, hilos=", Threads.nthreads(:default), ") ==")
Profile.print(format=:flat, sortedby=:count, mincount=5)
