# PPP-v0.1 — escalado por hilos. Invocar con --threads=N,0 para N ∈ {1,2,4,8,16,24}.
using Printf
include(joinpath(@__DIR__, "..", "src", "PodaPost.jl"))
using .PodaPost

const SR = UInt64(1) << 62
const SLOTS = 200_000
const REPS = 96

# calentar JIT
monte_carlo_niveles(UInt64(1), 8, SR, 1000, 2; Lmax=12)

t0 = time()
res = monte_carlo_niveles(UInt64(0xE5CA1A), 8, SR, SLOTS, REPS; Lmax=12)
dt = time() - t0
total = SLOTS * REPS
@printf("hilos=%2d  réplicas=%3d  %.3f s  válidos=%d  sorteos/s=%.3e  bloques/s=%.3e\n",
        Threads.nthreads(:default), REPS, dt, res.validos, total / dt, total / dt)
