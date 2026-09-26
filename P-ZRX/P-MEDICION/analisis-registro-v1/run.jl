#!/usr/bin/env julia
# run.jl — CLI reproducible del analizador (ORDEN §3.6)
#
# Uso:
#   julia --project=. run.jl --ejecucion <dir> --nodos A,B,C[,D] --salida <dir>
#
# Lee <dir>/<nodo>/registro.jsonl y, si existen, <dir>/recursos-<nodo>.csv.
# Escribe metricas.tsv, latencias.tsv, admision-vs-profundidad.tsv, rechazos.tsv,
# convergencia.tsv y RESUMEN.md en <salida>.

include(joinpath(@__DIR__, "src", "analisis_registro_v1.jl"))
using .AnalisisRegistroV1
using Printf

function uso()
    println(stderr, "uso: julia --project=. run.jl --ejecucion <dir> --nodos A,B,C[,D] --salida <dir> [--modelo <nombre>]")
    exit(2)
end

function parsear_args(args::Vector{String})
    opts = Dict{String,String}()
    i = 1
    while i <= length(args)
        a = args[i]
        if startswith(a, "--")
            key = a[3:end]
            i + 1 <= length(args) || (println(stderr, "falta el valor de --$key"); uso())
            opts[key] = args[i+1]
            i += 2
        else
            i += 1
        end
    end
    return opts
end

function main()
    opts = parsear_args(ARGS)
    haskey(opts, "ejecucion") || uso()
    haskey(opts, "nodos") || uso()
    ejecucion = abspath(opts["ejecucion"])
    nodos = [String(strip(n)) for n in split(opts["nodos"], ',') if !isempty(strip(n))]
    isempty(nodos) && uso()
    salida = haskey(opts, "salida") ? abspath(opts["salida"]) :
             abspath(joinpath(@__DIR__, "resultados", "analisis-" * basename(ejecucion)))
    modelo = get(opts, "modelo", "deepseek-flash")
    manifest = joinpath(@__DIR__, "Manifest.toml")
    manifest_sha = isfile(manifest) ? sha256_archivo(manifest) : "(sin Manifest.toml)"
    comando = string(Base.julia_cmd(), " --project=", @__DIR__, " run.jl ", join(ARGS, " "))

    res = analizar(ejecucion, nodos; modelo = modelo, comando = comando,
                   manifest_sha256 = manifest_sha)
    escribir_salidas(res, salida)

    println("W07c: análisis escrito en ", salida)
    for r in res.procedencia.nodos_info
        println("  nodo ", r.nombre, " (", r.version, "): ", r.lineas, " líneas, ",
                r.truncadas, " truncada(s)")
    end
    println("  latencias por par: ", length(res.latencias),
            " | divergencia: ", res.divergencia_medida ?
              @sprintf("%.4f", res.divergencia_fraccion) : "no medida")
    if res.estado_final_igual !== missing
        println("  estado final igual: ", res.estado_final_igual)
    end
    return 0
end

exit(main())
