using BenchmarkTools
using InteractiveUtils
using JET
using Profile
using SembradorV1

function carga_sintetica(n::Int)
    parametros = Vector{ParametrosMargen{Float64}}(undef, n)
    for i in eachindex(parametros)
        rho = (1.001, 1.5, 3.0, 10.0)[mod1(i, 4)]
        L = (1_224.0, 3_600.0, 7_200.0, 19_080.0)[mod1(i, 4)]
        I = (300.0, 491.0, 602.0, 851.0)[mod1(i, 4)]
        Wdec = (10.0, 20.0, 45.0)[mod1(i, 3)]
        espacio = (1e6, 1e9, 1e12)[mod1(i, 3)]
        parametros[i] = ParametrosMargen(rho, L, I, Wdec, 1.0, 1.0, espacio)
    end
    return parametros
end

function main()
    directorio = normpath(joinpath(@__DIR__, "..", "resultados"))
    mkpath(directorio)
    parametros = carga_sintetica(100_000)
    salida = Vector{ResultadoMargen{Float64}}(undef, length(parametros))

    barrer!(salida, parametros)
    asignados = @allocated barrer!(salida, parametros)
    prueba = @benchmark barrer!($salida, $parametros) samples = 50 evals = 1 seconds = 2
    prueba_ref = @benchmark evaluar_referencia($parametros[1]) samples = 20 evals = 1 seconds = 1

    open(joinpath(directorio, "BENCH.txt"), "w") do io
        println(io, "modelo=sembrador-v1 carga=sintetica_solo_rendimiento n=$(length(parametros))")
        println(io, "julia=$VERSION cpu=$(Sys.CPU_NAME) threads=$(Threads.nthreads(:default))/$(Threads.nthreads(:interactive))")
        println(io, "kernel_allocated_bytes=$asignados")
        for (nombre, prueba_actual) in (("kernel", prueba), ("referencia", prueba_ref))
            mediana = median(prueba_actual)
            minimo = minimum(prueba_actual)
            println(io, "$nombre median_ns=$(mediana.time) median_bytes=$(mediana.memory) median_allocs=$(mediana.allocs) min_ns=$(minimo.time)")
        end
    end

    open(joinpath(directorio, "WARNTYPE.txt"), "w") do io
        code_warntype(
            io,
            evaluar_margen,
            Tuple{ParametrosMargen{Float64}};
            debuginfo = :none,
        )
    end

    open(joinpath(directorio, "JET.txt"), "w") do io
        informe = JET.report_opt(evaluar_margen, Tuple{ParametrosMargen{Float64}})
        show(io, MIME("text/plain"), informe)
        println(io)
    end

    Profile.clear()
    Profile.@profile for _ in 1:50
        barrer!(salida, parametros)
    end
    open(joinpath(directorio, "PERFIL.txt"), "w") do io
        Profile.print(io; format = :flat, sortedby = :count)
    end

    print(read(joinpath(directorio, "BENCH.txt"), String))
end

main()
