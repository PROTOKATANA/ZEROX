# CRP-v0.1 — escalado 1..24 hilos del barrido de α. Invocar con --threads=N.
# Uso: for n in 1 2 4 8 16 24; do julia --project=. --threads=$n bench/escalado.jl; done
using StableRNGs
using Dates

include(joinpath(@__DIR__, "..", "src", "CosteRamaPrivada.jl"))
using .CosteRamaPrivada

const P = P_DEFECTO
const NREP = 8000
const NSLOTS = 400

# calentamiento
barrido_alpha(P, (0.45,); n_rep=100, n_slots=50)

t0 = time_ns()
filas = barrido_alpha(P, (0.42, 0.48, 0.52); n_rep=NREP, n_slots=NSLOTS,
                      semilla=UInt64(0xE5CA1A))
t1 = time_ns()

# trabajo total: réplicas × slots × 2 ramas
trabajo = length(filas) * NREP * NSLOTS
dt = (t1 - t0) / 1e9
println("escalado CRP-v0.1")
println("hilos_julia=", Threads.nthreads(:default),
        "  nrep=", NREP, "  nslots=", NSLOTS, "  α=", length(filas))
println("tiempo_s=", round(dt; digits=4),
        "  slots_procesados/s=", round(trabajo / dt; digits=1))
println("resultado=", filas)
