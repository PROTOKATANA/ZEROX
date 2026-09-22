using BenchmarkTools
using InteractiveUtils
using JET
using Profile
using IntentoV1

"""
Instrumentación del kernel. NO produce cifras del modelo: solo mide el evaluador matemático.

El modelo es O(n) en las filas del barrido, O(1) por fila y O(n) de salida. No usa RNG, ni GPU, ni
BLAS. Si el kernel caliente no sale a 0 asignaciones, hay que arreglarlo antes de publicar.
"""

function carga_sintetica(n::Int)
    escenarios = Vector{Escenario{Float64}}(undef, n)
    ws = Vector{Float64}(undef, n)
    for i in 1:n
        r = (0.5, 1.3, 8.2, 100.0)[mod1(i, 4)]
        rango = (1.0e6, 1.0e9, 1.0e12, 4.29e9)[mod1(i, 4)]
        escenarios[i] = Escenario(;
            r = r,
            t_reto_s = 1.0e-6,
            o = 0.5,
            rango_solucion = rango,
            tau_s = 1.0,
            N_h = 1.0e9,
            alpha = 0.1,
            pi_DAG = 1.0,
            t_ganador_s = 0.8,
            bytes_por_pieza = 1_048_672,
        )
        ws[i] = 10.0^(2 + 3 * (i - 1) / max(1, n - 1))
    end
    return escenarios, ws
end

function main()
    directorio = normpath(joinpath(@__DIR__, "..", "resultados"))
    mkpath(directorio)

    n = 100_000
    escenarios, ws = carga_sintetica(n)
    salida = Vector{Resultado{Float64}}(undef, n)

    barrer!(salida, escenarios, ws)
    asignados = @allocated barrer!(salida, escenarios, ws)
    prueba = @benchmark barrer!($salida, $escenarios, $ws) samples = 50 evals = 1 seconds = 2

    # Oráculo de alta precisión sobre una sola fila: es lento a propósito.
    prueba_ref = @benchmark evaluar_referencia($(escenarios[1]), $(ws[1])) samples = 20 evals = 1 seconds = 1

    ok, error, comparaciones = validar_referencia([(escenarios[i], ws[i]) for i in 1:200])

    open(joinpath(directorio, "BENCH.txt"), "w") do io
        println(io, "modelo=intento-v1 carga=sintetica_solo_rendimiento n=$n")
        println(io, "julia=$VERSION cpu=$(Sys.CPU_NAME) threads=$(Threads.nthreads(:default))/$(Threads.nthreads(:interactive))")
        println(io, "kernel_allocated_bytes=$asignados")
        for (nombre, prueba_actual) in (("kernel", prueba), ("referencia", prueba_ref))
            mediana = median(prueba_actual)
            minimo = minimum(prueba_actual)
            println(io, "$nombre median_ns=$(mediana.time) median_bytes=$(mediana.memory) median_allocs=$(mediana.allocs) min_ns=$(minimo.time)")
        end
        println(io, "validacion_ok=$ok max_error_relativo=$error comparaciones=$comparaciones")
    end

    open(joinpath(directorio, "WARNTYPE.txt"), "w") do io
        code_warntype(io, evaluar, Tuple{Escenario{Float64},Float64}; debuginfo = :none)
        code_warntype(io, barrer!, Tuple{Vector{Resultado{Float64}},Vector{Escenario{Float64}},Vector{Float64}}; debuginfo = :none)
    end

    open(joinpath(directorio, "JET.txt"), "w") do io
        for (f, tipos) in (
            (evaluar, Tuple{Escenario{Float64},Float64}),
            (barrer!, Tuple{Vector{Resultado{Float64}},Vector{Escenario{Float64}},Vector{Float64}}),
            (rejilla_w, Tuple{Float64,Float64,Int}),
        )
            informe = JET.report_opt(f, tipos)
            show(io, MIME("text/plain"), informe)
            println(io)
        end
    end

    Profile.clear()
    Profile.@profile for _ in 1:50
        barrer!(salida, escenarios, ws)
    end
    open(joinpath(directorio, "PERFIL.txt"), "w") do io
        Profile.print(io; format = :flat, sortedby = :count)
    end

    print(read(joinpath(directorio, "BENCH.txt"), String))
end

main()
