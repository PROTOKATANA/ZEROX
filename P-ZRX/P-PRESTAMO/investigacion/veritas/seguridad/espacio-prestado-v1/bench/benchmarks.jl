#= espacio-prestado-v1 · bench/benchmarks.jl
   Tabla de rendimiento LINEO §6. Ejecutar tras el JIT (BenchmarkTools calienta).
   Uso:
     JULIA_NUM_THREADS=8 OPENBLAS_NUM_THREADS=1 julia --project=. bench/benchmarks.jl
=#

using BenchmarkTools
using Printf

const DIR = dirname(@__DIR__)
include(joinpath(DIR, "src", "modelo.jl"))
include(joinpath(DIR, "src", "referencia.jl"))
include(joinpath(DIR, "src", "rapido.jl"))

using .Modelo
using .Referencia
using .Rapido

const RES = joinpath(DIR, "resultados")
mkpath(RES)

println("Julia ", VERSION, "  hilos=", Threads.nthreads(:default))
println("CPU = ", Sys.CPU_NAME)
println("uptime (carga ajena):")
run(`uptime`)

p = 0.45

println("\n== kernel DP (min,posicion), Float64 ==")
for (d, T) in ((10, 1_000), (50, 1_000), (100, 3_600), (350, 1_019))
    r = primera_dp(p, d, T)                     # calentamiento
    @assert r.paso ≥ 0.0
    t = @benchmark primera_dp($p, $d, $T)
    @printf("d=%-5d T=%-6d  mediana=%8.3f ms  allocs=%d  mem=%.1f KiB  P=%.3e\n",
            d, T, minimum(t).time / 1e6, minimum(t).allocs,
            minimum(t).memory / 1024, r.paso)
end

println("\n== DP exacta Rational{BigInt} (referencia lenta) ==")
for (d, T) in ((2, 12), (3, 16), (5, 20))
    t = @benchmark primera_dp(Rational{BigInt}($p), $d, $T)
    @printf("d=%-3d T=%-3d  mediana=%8.3f ms  allocs=%d\n",
            d, T, minimum(t).time / 1e6, minimum(t).allocs)
end

println("\n== enumeración exhaustiva (oráculo 2^T) ==")
for T in (10, 14, 18)
    t = @benchmark enumerar_exhaustivo(Rational{BigInt}(0.45), 2, $T)
    @printf("T=%-3d  mediana=%8.3f ms\n", T, minimum(t).time / 1e6)
end

println("\n== escalado del barrido paralelo (1..8 hilos) ==")
ps = [0.30, 0.35, 0.40, 0.45, 0.50]
ds = collect(0:40)
serial = rejilla_dp(ps, ds, 400)
par = rejilla_dp_par(ps, ds, 400)
@assert all(serial[i].paso == par[i].paso for i in eachindex(serial))
println("serial == paralelo en las ", length(serial), " celdas: OK")
t1 = @benchmark rejilla_dp($ps, $ds, 400)
t8 = @benchmark rejilla_dp_par($ps, $ds, 400)
@printf("serial      mediana=%8.3f ms\n", minimum(t1).time / 1e6)
@printf("paralelo mediana=%8.3f ms  speedup=%.2fx\n",
        minimum(t8).time / 1e6, minimum(t1).time / minimum(t8).time)

println("\n== controles de tipos y asignaciones ==")
r = primera_dp(0.45, 50, 1_000)
println("interior + paso = ", r.paso + r.interior)
using InteractiveUtils
@code_warntype primera_dp(0.45, 50, 1_000)
