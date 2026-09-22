# ─────────────────────────────────────────────────────────────────────────────
# benchmarks.jl — REV-v1.0
#
#   JULIA_NUM_THREADS=N julia --project=. --threads=N,0 bench/benchmarks.jl [n_rep]
#
# Mide el caso representativo con el número de hilos del PROCESO (la única forma honesta de
# escalar en Julia: `Threads.@threads` usa todas las hebras disponibles). Imprime un checksum
# determinista de los resultados para comprobar que la cifra no depende del reparto por hilos.
# ─────────────────────────────────────────────────────────────────────────────
using BenchmarkTools
using RevelacionV1
using Printf

const NT = Threads.nthreads()
J = 1500
NREP = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 64
RHOS = [1.05, 1.1, 1.2, 1.5, 2.0, 2.5, 3.0, 5.0, 9.0, 12.0, 16.0, 20.0]

cfg = Config{Float64}(; L = 7200.0, I = 851.0, W_dec = 20.0, D = 4.0, S_max = 150.0,
                      Lrev = 7200.0 - 150.0, con_h = true, espera = false, cruce = true,
                      lead_h = 4.0, j_ini = 150)
kw = (rhos = RHOS, n_rep = NREP, J = J, alpha = 0.33, seed = UInt64(0x5a5a), nb = 4096,
      bin = 32.0, v_lo = -1024.0, boot_ref = 0.0, modo_off = :geom)

println("REV-v1.0 · bench · Julia ", VERSION, " · ", Sys.CPU_NAME, " · nthreads=", NT)
println("caso representativo: J=$J épocas, ", length(RHOS), " valores de ρ, $NREP réplicas; ",
        J * NREP * length(RHOS), " iteraciones de época")

b = Buffers{Float64}(J, 4096)
off = zeros(J + 1); propia = fill(false, J + 1)
simular_replica!(b, cfg, off, propia, 2.0, J, 32.0, -1024.0, 0.0)
t_rep = @benchmark simular_replica!($b, $cfg, $off, $propia, 2.0, $J, 32.0, -1024.0, 0.0)
@printf("kernel por réplica (J=%d, ρ=2): mediana %.3f ms · asignaciones %d · memoria %d B · @allocated %d B\n",
        J, minimum(t_rep).time / 1e6, minimum(t_rep).allocs, minimum(t_rep).memory,
        @allocated(simular_replica!(b, cfg, off, propia, 2.0, J, 32.0, -1024.0, 0.0)))

barrer!(cfg; kw..., nthreads = NT)                       # calentar JIT
t = @benchmark barrer!($cfg; $kw..., nthreads = $NT) samples = 10 evals = 1
@printf("barrido completo: mediana %.2f ms · mínimo %.2f ms · asignaciones %d\n",
        median(t).time / 1e6, minimum(t).time / 1e6, minimum(t).allocs)

r = barrer!(cfg; kw..., nthreads = NT)
println("checksum determinista: hash(vmax)=", hash(r.vmax), " hash(vmin)=", hash(r.vmin),
        " hash(hist)=", hash(r.hist), " hash(n_pro)=", hash(r.n_pro))
