#=  benchmarks.jl — medición del instrumento ANR-v0.1.

    JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
      ./veritas/julia.sh --project=<dir> <dir>/bench/benchmarks.jl

Se calienta la JIT antes de medir (LINEO §5.6). El barrido grande usa el kernel Float64; la
referencia BigFloat se mide aparte porque su coste es el de la certificación, no el del barrido.
=#

using BenchmarkTools
using Printf
include(joinpath(@__DIR__, "..", "src", "ANR.jl"))
using .ANR

println("julia ", VERSION, "  hilos=", Threads.nthreads(:default), "  CPU=", Sys.CPU_NAME)

# --- calentamiento
ANR.umbral_c_medio(3; prec=128)
ANR.phi_c_f64(3)
ANR.umbral_c_f64(3)
ANR.phi_por_maximo(3; prec=128)
ANR.brw_minimo(2; k=3, haz=32, hijos=8, replicas=2)
ANR.c_para_umbral(0.40; cmax=1000, prec=128)

println("\n-- kernel Float64 (barrido de tablas)")
for c in (1, 10, 1000, 20000)
    t = @benchmark ANR.phi_c_f64($c)
    @printf("  phi_c_f64(%-6d) mediana %10.3f ns   allocs %d   mem %d B\n",
            c, minimum(t).time, minimum(t).allocs, minimum(t).memory)
end

println("\n-- referencia BigFloat certificada")
for c in (10, 50)
    t = @benchmark ANR.umbral_c_medio($c)
    @printf("  umbral_c_medio(%-4d) mediana %10.3f us   allocs %d   mem %d B\n",
            c, minimum(t).time / 1000, minimum(t).allocs, minimum(t).memory)
end

println("\n-- oráculo por maximización (ruta independiente)")
t = @benchmark ANR.phi_por_maximo(50; prec=192)
@printf("  phi_por_maximo(50) mediana %10.3f us   allocs %d\n", minimum(t).time / 1000, minimum(t).allocs)

println("\n-- simulación del BRW")
t = @benchmark ANR.brw_minimo(2; k=5, haz=200, hijos=20, replicas=16)
@printf("  brw_minimo(c=2,k=5,haz=200,hijos=20,rep=16) mediana %10.3f ms\n", minimum(t).time / 1e6)

println("\n-- tipo de cambio (inversión por bisección)")
t = @benchmark ANR.c_para_umbral(0.45; cmax=10^5, prec=160)
@printf("  c_para_umbral(0.45) mediana %10.3f ms\n", minimum(t).time / 1e6)
