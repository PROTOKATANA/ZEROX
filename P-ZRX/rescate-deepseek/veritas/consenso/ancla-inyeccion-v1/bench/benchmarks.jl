# Benchmarks del instrumento (LINEO §5.1/§6). No decide corrección.
#
#   julia --project=. --threads=1 bench/benchmarks.jl
using AnclaInyeccion
using BenchmarkTools
using Printf

pr = ParametrosRed(100, 8, 1.0, 120.0, 65e-6, log(0.08), 0.7879, 15, UInt64(1000),
                   UInt64(0x5a5a))
d = simular_red(pr)                      # calienta JIT
acc = medir_transitorio(d, P_DEFECTO, collect(1:100), 120.0, 1.0, 6)

println("## simular_red (n=100, T=120s, λ=1)")
t1 = @benchmark simular_red($pr)
@printf("min=%.4f s  allocs=%d  mem=%.1f MiB\n",
        minimum(t1).time / 1e9, minimum(t1).allocs, minimum(t1).memory / 2^20)

println("## medir_transitorio (obs=100, cortes=1s, Dmax=6)")
t2 = @benchmark medir_transitorio($d, $P_DEFECTO, $(collect(1:100)), 120.0, 1.0, 6)
@printf("min=%.4f s  allocs=%d  mem=%.1f MiB\n",
        minimum(t2).time / 1e9, minimum(t2).allocs, minimum(t2).memory / 2^20)
