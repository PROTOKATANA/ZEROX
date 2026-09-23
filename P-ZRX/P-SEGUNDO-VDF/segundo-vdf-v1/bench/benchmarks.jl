# ─────────────────────────────────────────────────────────────────────────────
# bench/benchmarks.jl — rendimiento, asignaciones y escalado de hilos.
#   JULIA_DEPOT_PATH="/tmp/segundo-vdf-julia-depot:$HOME/.julia" \
#     ../../../veritas/julia.sh --project=. --threads=16,0 bench/benchmarks.jl
# ─────────────────────────────────────────────────────────────────────────────
using SegundoVdfV1
using BenchmarkTools, Printf, StableRNGs

println("Julia=", VERSION, " CPU=", Sys.CPU_NAME,
        " hilos_default=", Threads.nthreads(:default), " semilla=0x5a5a")

J = 1500
cfg = cfg_base(I = 851.0, Lrev = 7050.0, con_h = true)
off = zeros(Float64, J + 1); propia = falses(J + 1)
b = Bufs{Float64}(J, 400)

# calentamiento (JIT) antes de medir
simular_replica!(b, cfg, off, propia, 2.5, J, 64.0, 0.0, true)

println("== kernel: una réplica, J=$J, hilo único ==")
t = @benchmark simular_replica!($b, $cfg, $off, $propia, 2.5, $J, 64.0, 0.0, true)
@printf("mediana = %.3f ms   mínimo = %.3f ms   asignaciones = %d   memoria = %d B\n",
        median(t).time / 1e6, minimum(t).time / 1e6, minimum(t).allocs, minimum(t).memory)
@printf("@allocated una llamada = %d B\n", @allocated simular_replica!(b, cfg, off, propia, 2.5, J, 64.0, 0.0, true))

println("\n== barrido réplicas × ρ ==")
println("hilos reales del proceso = ", Threads.nthreads(:default),
        " (para medir 2/4/8/16, iniciar procesos Julia separados con --threads=N,0)")
for (R, nrho) in ((64, 12), (256, 12))
    rhos = collect(range(1.01, 9.0, length = nrho))
    for h in unique((1, Threads.nthreads(:default)))
        tb = @elapsed barrido(cfg, rhos, J, R, UInt64(0x5a5a), 400, 64.0, 0.0, 0.33;
                              nthreads = h, con_hist = false)
        tb1 = @elapsed barrido(cfg, rhos, J, R, UInt64(0x5a5a), 400, 64.0, 0.0, 0.33;
                               nthreads = 1, con_hist = false)
        @printf("R=%3d ρ=%2d hilos_reales=%2d  %8.2f ms   speedup vs serie = %5.2f×\n",
                R, nrho, h == 1 ? 1 : Threads.nthreads(:default), tb * 1e3, tb1 / tb)
    end
end

println("\n== determinismo entre hilos (checksum) ==")
ch(h) = (r = barrido(cfg, [2.0, 2.5, 3.0], J, 64, UInt64(0x5a5a), 400, 64.0, 0.0, 0.33;
                     nthreads = h);
         (sum(r.vmax), sum(r.hist), sum(r.bajo), sum(r.sobre)))
base = ch(1)
for h in unique((1, Threads.nthreads(:default)))
    @printf("hilos=%2d  checksum idéntico = %s\n", h, ch(h) == base)
end
