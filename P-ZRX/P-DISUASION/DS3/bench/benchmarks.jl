#!/usr/bin/env julia
# =============================================================================
# DS-3 · bench/benchmarks.jl — tabla de rendimiento LINEO §6
#
# Comando:
#   JULIA_DEPOT_PATH="$PWD/.julia-depot:/home/katana/.julia" \
#   JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
#     julia --project=. --threads=4,0 bench/benchmarks.jl
# =============================================================================

using DS3
using BenchmarkTools
using Printf

salida = open(joinpath(@__DIR__, "..", "resultados", "BENCH.txt"), "w")

function publicar(io, nombre, trial; hilos = 1, nota = "")
    t = minimum(trial)
    @printf(io, "%-46s %12.4f ms  %8d allocs  %10d B  %2d hilo(s)  %s\n",
            nombre, t.time / 1e6, t.allocs, t.memory, hilos, nota)
end

@printf(salida, "DS-3 · BENCH · Julia %s · %s · hilos=%d\n\n", VERSION, Sys.CPU_NAME,
        Threads.nthreads())

# Calentamiento (JIT) antes de medir
primera_dp(0.33, 346, 1019)
primera_dp_absorbente(0.33, 346, 1019)
let t = TablaLogFact(1_048_480)
    cola_hiper_rapida(t, 1_048_480, 189_670, 1_000_000, 181_092)
end

publicar(salida, "primera_dp(0.33, 346, 1019) [regresión §4.2]",
         @benchmark primera_dp(0.33, 346, 1019); nota = "DP certificada (mínimo, pos)")
publicar(salida, "primera_dp_absorbente(0.33, 346, 1019)",
         @benchmark primera_dp_absorbente(0.33, 346, 1019); nota = "vía rápida equivalente")
publicar(salida, "primera_dp(0.33, 10, 1019)",
         @benchmark primera_dp(0.33, 10, 1019); nota = "cola alcanzable")

let t = TablaLogFact(1_048_480)
    publicar(salida, "cola_hiper_rapida(N=1.048.480,k=1e6,B=181.092)",
             @benchmark cola_hiper_rapida($t, 1_048_480, 189_670, 1_000_000, 181_092);
             nota = "cobertura certificada")
end

publicar(salida, "mc_ventana(1/3, 5, 400, 10.000)",
         @benchmark mc_ventana(1 / 3, 5, 400, 10_000, UInt64(0x5a5a);
                               hilos = false, etiqueta = UInt64(7)); nota = "MC serial")
publicar(salida, "mc_ventana(1/3, 5, 400, 10.000) [hilos]",
         @benchmark mc_ventana(1 / 3, 5, 400, 10_000, UInt64(0x5a5a);
                               hilos = true, etiqueta = UInt64(7));
         hilos = Threads.nthreads(), nota = "MC paralelo (mismo resultado)")

publicar(salida, "beta_minimo_para_p(0.33, 1019, 1e-6) [rápida]",
         @benchmark beta_minimo_para_p(0.33, 1019, 1e-6); nota = "bisección, DP absorbente")
publicar(salida, "beta_minimo_para_p(...) [certificada]",
         @benchmark beta_minimo_para_p(0.33, 1019, 1e-6; via = :certificada);
         nota = "bisección, DP (mínimo, posición)")

close(salida)
println(read(joinpath(@__DIR__, "..", "resultados", "BENCH.txt"), String))
