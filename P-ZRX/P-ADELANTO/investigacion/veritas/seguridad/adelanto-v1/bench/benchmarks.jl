#!/usr/bin/env julia
#
# benchmarks.jl — ADL-v1. Calienta el JIT, mide el kernel con BenchmarkTools, mide
# asignaciones, perfila y ejecuta los diagnósticos de tipos (LINEO §5.1, §6).
# Escribe resultados/BENCH.txt, WARNTYPE.txt, JET.txt y PERFIL.txt.

using AdelantoV1
using BenchmarkTools
using Profile
using InteractiveUtils
using Dates

const JET_DISPONIBLE = try
    @eval using JET
    true
catch
    false
end

const RAIZ = @__DIR__
const RES = joinpath(dirname(RAIZ), "resultados")
mkpath(RES)

const N_FILAS = 100_000

"""Rejilla representativa: 100 000 filas variando los siete ejes."""
function rejilla_bench(n::Int)
    rhos = [1.0 + 9.0 * (k - 1) / (n - 1) for k in 1:n]
    filas = Vector{ParametrosAdelanto{Float64}}(undef, n)
    for k in 1:n
        filas[k] = ParametrosAdelanto(
            rhos[k], 851.0 + 4000.0 * ((k % 97) / 97), 20.0 + 25.0 * ((k % 13) / 13),
            4.0 * ((k % 7)), 150.0, 1019.0 + 18000.0 * ((k % 53) / 53),
            300.0 * ((k % 11)), 1.0e6, 2.5, COSTE_VERIFY_SLOT_S,
        )
    end
    return filas
end

function main()
    filas = rejilla_bench(N_FILAS)
    salida = Vector{ResultadoAdelanto{Float64}}(undef, N_FILAS)

    # Calentamiento (JIT) antes de medir: lo primero que se paga es compilación.
    barrer!(salida, filas)
    barrer_hilos!(salida, filas)

    hilos = Threads.nthreads(:default)
    open(joinpath(RES, "BENCH-h$(hilos).txt"), "w") do io
        println(io, "# ADL-v1 · benchmark del barrido — ", Dates.now())
        println(io, "julia  = ", VERSION)
        println(io, "cpu    = ", Sys.CPU_NAME)
        println(io, "hilos  = ", Threads.nthreads(:default))
        println(io, "filas  = ", N_FILAS)
        println(io)

        # Asignaciones del barrido completo
        a1 = @allocated barrer!(salida, filas)
        println(io, "@allocated barrer! (serial, $N_FILAS filas) = ", a1, " bytes")

        t1 = @benchmark barrer!($salida, $filas)
        println(io, "serial       : mediana ", minimum(t1).time / 1e6, " ms  mínimo ",
            minimum(t1).time / 1e6, " ms  allocs ", minimum(t1).allocs,
            "  mem ", minimum(t1).memory)

        println(io, "hilos reales = ", hilos,
            "  (el escalado se mide reejecutando con JULIA_NUM_THREADS=1,2,4,8)")

        tres = @benchmark barrer_hilos!($salida, $filas)
        println(io, "con hilos    : mediana ", minimum(tres).time / 1e6, " ms  allocs ",
            minimum(tres).allocs, "  mem ", minimum(tres).memory)

        # Una fila aislada (kernel puro)
        p = filas[1]
        evaluar_fila(p)
        t3 = @benchmark evaluar_fila($p)
        println(io, "una fila     : mediana ", minimum(t3).time, " ns  allocs ",
            minimum(t3).allocs, "  mem ", minimum(t3).memory)

        # Referencia BigFloat de una fila, para comparar el coste del oráculo
        referencia_bigfloat(p)
        t4 = @benchmark referencia_bigfloat($p)
        println(io, "BigFloat 256 : mediana ", minimum(t4).time / 1e3, " µs  allocs ",
            minimum(t4).allocs, "  mem ", minimum(t4).memory)

        # Sim-v1 (oráculo de eventos)
        off = rejilla_offsets(400, 0)
        simular_fronteras(Rational{Int}(15, 10), 7200, 851, 20, 4, 400; off = off)
        t5 = @benchmark simular_fronteras(Rational{Int}(15, 10), 7200, 851, 20, 4, 400; off = $off)
        println(io, "Sim-v1 400ep : mediana ", minimum(t5).time / 1e3, " µs  allocs ",
            minimum(t5).allocs, "  mem ", minimum(t5).memory)

        # Verificación de que el barrido con hilos coincide con el serial
        s1 = Vector{ResultadoAdelanto{Float64}}(undef, N_FILAS)
        barrer!(s1, filas)
        println(io)
        println(io, "barrido con hilos == serial : ", salida == s1)
    end

    # Diagnósticos de tipos
    open(joinpath(RES, "WARNTYPE.txt"), "w") do io
        println(io, "# ADL-v1 · @code_warntype del kernel — ", Dates.now())
        p = filas[1]
        b = IOBuffer()
        code_warntype(b, evaluar_fila, Tuple{ParametrosAdelanto{Float64}})
        println(io, String(take!(b)))
    end

    if JET_DISPONIBLE
        open(joinpath(RES, "JET.txt"), "w") do io
            println(io, "# ADL-v1 · JET sobre el kernel — ", Dates.now())
            println(io, "julia  = ", VERSION)
            println(io, "jet    = ", pkgversion(JET))
            println(io)
            rep_call = JET.report_call(evaluar_fila, (ParametrosAdelanto{Float64},))
            println(io, "## report_call(evaluar_fila)")
            show(io, MIME"text/plain"(), rep_call)
            println(io)
            println(io, "n_errores_call = ", length(JET.get_reports(rep_call)))
            println(io)
            rep_opt = JET.report_opt(evaluar_fila, (ParametrosAdelanto{Float64},))
            println(io, "## report_opt(evaluar_fila)")
            show(io, MIME"text/plain"(), rep_opt)
            println(io)
            println(io, "n_errores_opt = ", length(JET.get_reports(rep_opt)))
            println(io)
            rep_b = JET.report_call(barrer!, (Vector{ResultadoAdelanto{Float64}}, Vector{ParametrosAdelanto{Float64}}))
            println(io, "## report_call(barrer!)")
            println(io, "n_errores_barrer = ", length(JET.get_reports(rep_b)))
        end
    else
        open(joinpath(RES, "JET.txt"), "w") do io
            println(io, "# ADL-v1 · JET no disponible en este entorno")
        end
    end

    # Perfil del barrido. El barrido de 100 000 filas dura < 1 ms, por debajo del intervalo de
    # muestreo del perfilador: se repite para que el perfil tenga muestras.
    repet = 3000
    barrer!(salida, filas)
    Profile.clear()
    @profile for _ in 1:repet
        barrer!(salida, filas)
    end
    open(joinpath(RES, "PERFIL.txt"), "w") do io
        println(io, "# ADL-v1 · Profile del barrido serial — ", Dates.now())
        println(io, "# ", repet, " repeticiones de ", N_FILAS,
            " filas = ", repet * N_FILAS, " filas evaluadas")
        Profile.print(io; format = :flat, sortedby = :count, mincount = 5)
    end

    println("benchmarks: listo en ", RES)
end

main()
