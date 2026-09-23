# benchmarks.jl — tabla de rendimiento LINEO §6
# Uso: veritas/julia.sh --project=. bench/benchmarks.jl
using BenchmarkTools
using Dates

include("../src/modelo.jl")
include("../src/referencia.jl")
include("../src/rapido.jl")
include("../src/validacion.jl")

const RB = Rational{BigInt}

function main()
    open("resultados/BENCH.txt", "w") do io
        println(io, "# BENCH — secreto-atestiguacion-v1")
        println(io, "# uptime antes: ", read(`uptime`, String))
        println(io, "# VERSION ", VERSION, " | CPU ", Sys.CPU_NAME, " | hilos ", Threads.nthreads())

        # calentamiento
        captura_reemplazo(RB(1, 3), 8)
        captura_cadena(RB(1, 3), 8, 100)
        fraccion_produce(RB(1, 3), RB(1), 8)
        paro_particion(RB(1, 2), 4)
        p_no_fuga_exacta(RB(1, 3), RB(1, 2), 2, 3)
        p_cabe_multihop_conv(1.0, 0.60, 8, 3, 0.02)
        log10_p_no_fuga(0.33, 0.5, 4, 1000)
        cdf_suma_enlaces(6, 6.0, 4000)
        mc_p_cabe(1.0, 0.60, 4, 3, 0.02, 1000, UInt64(0x5EC5E70))
        validar_captura(6, 3)
        validar_produce(5, 3)

        println(io, "\n| Variante | Tiempo mínimo | Asignaciones | Memoria |")
        println(io, "|---|---:|---:|---:|")
        for (nombre, f) in [
            ("captura_reemplazo (exacto, k=8)", () -> captura_reemplazo(RB(1, 3), 8)),
            ("captura_cadena (exacto, k=8, d=100)", () -> captura_cadena(RB(1, 3), 8, 100)),
            ("captura_cadena (exacto, k=4, d=7200)", () -> captura_cadena(RB(1, 3), 4, 7200)),
            ("fraccion_produce (exacto, k=8)", () -> fraccion_produce(RB(1, 3), RB(1), 8)),
            ("p_no_fuga_exacta (exacto, k=2, d=3)", () -> p_no_fuga_exacta(RB(1, 3), RB(1, 2), 2, 3)),
            ("log10_p_no_fuga (BigFloat, d=7200)", () -> log10_p_no_fuga(0.33, 0.5, 4, 7200)),
            ("cdf_suma_enlaces (m=6, npts=4000)", () -> cdf_suma_enlaces(6, 6.0, 4000)),
            ("p_cabe_multihop_conv (k=8, h=3)", () -> p_cabe_multihop_conv(1.0, 0.60, 8, 3, 0.02)),
            ("mc_p_cabe (k=4, h=3, n=100k)", () -> mc_p_cabe(1.0, 0.60, 4, 3, 0.02, 100_000, UInt64(0x5EC5E70))),
            ("validar_captura (oráculo, 54 celdas)", () -> validar_captura(6, 3)),
            ("validar_produce (oráculo, 90 celdas)", () -> validar_produce(5, 3)),
        ]
            t = @benchmark $f() samples = 100
            println(io, "| ", nombre, " | ", round(minimum(t).time / 1e6, digits = 4), " ms | ",
                    minimum(t).allocs, " | ", minimum(t).memory, " B |")
        end
        println(io, "\n# uptime después: ", read(`uptime`, String))
    end
    println("BENCH.txt escrito")
end

main()
