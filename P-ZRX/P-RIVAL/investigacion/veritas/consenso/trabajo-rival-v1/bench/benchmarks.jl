# bench/benchmarks.jl — tabla de rendimiento (LINEO §6).  Calienta JIT antes de medir.
#
#   JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
#     /home/katana/zeo/ZEROX/veritas/julia.sh --project=. bench/benchmarks.jl

using BenchmarkTools
using InteractiveUtils
using Printf
using Dates

include(joinpath(@__DIR__, "..", "src", "modelo.jl"))
include(joinpath(@__DIR__, "..", "src", "referencia.jl"))
include(joinpath(@__DIR__, "..", "src", "rapido.jl"))
include(joinpath(@__DIR__, "..", "src", "validacion.jl"))

const RES = joinpath(@__DIR__, "..", "resultados")
mkpath(RES)

function main()
    salida = joinpath(RES, "BENCH.txt")
    uptime = try
        read(`uptime`, String)
    catch
        "(uptime no disponible)"
    end
    io = open(salida, "w")
    println(io, "TR-v0.1 · BENCH · ", now())
    println(io, "Julia ", VERSION, " · hilos=", Threads.nthreads(:default), "/",
            Threads.nthreads(:interactive))
    println(io, "CPU=", Sys.CPU_NAME, " · RAM=", Sys.total_memory() ÷ 2^30, " GiB")
    println(io, "uptime: ", strip(uptime))
    println(io)

    # --- calentamiento ---
    α = R(1)//10; β_d = R(1)//5; β_x = R(1)//10; θ = R(1)//4; ρ = R(3)//2
    alpha_aditivo(β_d, β_x, θ, ρ)
    alpha_por_biseccion(β_d, β_x, θ, ρ)
    marginal_beta_d(θ, R(1))
    alpha_multiplicativo_biseccion(β_d, β_x, θ, _ -> R(1), _ -> R(1))
    umbral_enumera(5, 7, 16, 12, 4)

    dest = zeros(Float64, 10_000)
    bd = collect(range(0.0, 0.5; length = 10_000))
    rejilla_alpha!(dest, bd, 0.1, 0.25, 1.5)

    println(io, "| Variante | Tiempo mediano | Asignaciones | Hilos | Resultado |")
    println(io, "|---|---:|---:|---:|---|")

    t1 = @benchmark alpha_aditivo($β_d, $β_x, $θ, $ρ)
    println(io, @sprintf("| α* exacto (Rational{BigInt}) | %.3f µs | %d | %d | fuente de verdad |",
                         minimum(t1).time / 1000, minimum(t1).allocs, 1))

    t2 = @benchmark alpha_por_biseccion($β_d, $β_x, $θ, $ρ)
    println(io, @sprintf("| α* por bisección (512 it., oráculo) | %.1f µs | %d | %d | = forma cerrada |",
                         minimum(t2).time / 1000, minimum(t2).allocs, 1))

    t3 = @benchmark marginal_beta_d($θ, R(1))
    println(io, @sprintf("| ventaja marginal (diferencia finita exacta) | %.3f µs | %d | %d | = derivada |",
                         minimum(t3).time / 1000, minimum(t3).allocs, 1))

    t4 = @benchmark alpha_multiplicativo_biseccion($β_d, $β_x, $θ, _ -> R(1), _ -> R(1))
    println(io, @sprintf("| α* multiplicativo (bisección exacta) | %.1f µs | %d | %d | = control |",
                         minimum(t4).time / 1000, minimum(t4).allocs, 1))

    t5 = @benchmark rejilla_alpha!($dest, $bd, 0.1, 0.25, 1.5)
    println(io, @sprintf("| rejilla Float64, 10⁴ puntos | %.1f µs | %d | %d | sin fronteras |",
                         minimum(t5).time / 1000, minimum(t5).allocs, 1))

    asig = @allocated rejilla_alpha!(dest, bd, 0.1, 0.25, 1.5)
    println(io)
    println(io, "asignaciones de rejilla_alpha! (10⁴): ", asig, " B")
    println(io, "code_warntype(alpha_aditivo_f64): ", sprint(io -> code_warntype(io, alpha_aditivo_f64, Tuple{Float64,Float64,Float64,Float64})))
    close(io)
    print(read(salida, String))
end

main()
