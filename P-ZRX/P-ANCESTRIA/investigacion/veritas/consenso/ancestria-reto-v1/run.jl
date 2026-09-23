#!/usr/bin/env bash
#=  run.jl — CLI reproducible de ANR-v0.1.

Uso:
    ./veritas/julia.sh --project=P-ZRX/P-ANCESTRIA/investigacion/veritas/consenso/ancestria-reto-v1 \
        P-ZRX/P-ANCESTRIA/investigacion/veritas/consenso/ancestria-reto-v1/run.jl --todo

Opciones: --control --tabla --tipo-cambio --cobertura --oraculos --kernel --todo
Escribe en `resultados/` con cabecera de entorno (git, fecha, julia, hilos, semilla).
=#

# El proyecto se fija con `--project=<este directorio>` en la línea de ejecución publicada.
# No se activa aquí: hacerlo mientras el proyecto ya está activo pelea por el fichero de uso de
# entorno de Pkg (error de `pidfile` verificado el 2026-09-22).
include(joinpath(@__DIR__, "src", "ANR.jl"))
using .ANR
using Dates
using Printf

const SEED = UInt64(0x5a5a5a5a)          # semilla maestra obligatoria; va en cada artefacto
const DIR_RES = joinpath(@__DIR__, "resultados")
mkpath(DIR_RES)

function cabecera(comando::String)
    git = try
        strip(read(`git -C $(dirname(dirname(dirname(dirname(dirname(dirname(@__DIR__))))))) rev-parse HEAD`, String))
    catch
        "no disponible"
    end
    L = String[]
    push!(L, "# ANR-v0.1 — anclaje del reto a profundidad d")
    push!(L, "# comando : $comando")
    push!(L, "# fecha   : $(Dates.now())")
    push!(L, "# julia   : $(VERSION)")
    push!(L, "# hilos   : $(Threads.nthreads(:default)) default, $(Threads.nthreads(:interactive)) interactive")
    push!(L, "# CPU     : $(Sys.CPU_NAME)")
    push!(L, "# semilla : 0x$(string(SEED, base=16))")
    push!(L, "# git     : $git")
    return L
end

function volcar(nombre::String, comando::String, ok::Bool, lineas::Vector{String})
    ruta = joinpath(DIR_RES, nombre)
    open(ruta, "w") do io
        for l in cabecera(comando); println(io, l); end
        println(io, "# estado  : ", ok ? "OK" : "FALLA")
        println(io, "")
        for l in lineas; println(io, l); end
    end
    println("== $nombre  [", ok ? "OK" : "FALLA", "]  ->  $ruta")
    for l in lineas; println("   ", l); end
    return ok
end

function main(args)
    hacer = Set(args)
    todo = isempty(hacer) || "--todo" in hacer
    fallos = 0

    if todo || "--control" in hacer
        ok, L = ANR.control_d0()
        fallos += !volcar("run-control-d0.txt", "run.jl --control", ok, L)
    end
    if todo || "--tabla" in hacer
        ok, L = ANR.tabla_umbral_d()
        fallos += !volcar("run-tabla-umbral-d.txt", "run.jl --tabla", ok, L)
    end
    if todo || "--tipo-cambio" in hacer
        ok, L = ANR.tabla_tipo_cambio()
        fallos += !volcar("run-tipo-cambio.txt", "run.jl --tipo-cambio", ok, L)
    end
    if todo || "--cobertura" in hacer
        ok, L = ANR.tabla_cobertura()
        fallos += !volcar("run-cobertura.txt", "run.jl --cobertura", ok, L)
    end
    if todo || "--kernel" in hacer
        ok, L = ANR.oraculo_kernel()
        fallos += !volcar("run-kernel.txt", "run.jl --kernel", ok, L)
        ok, L = ANR.monotonia_limites()
        fallos += !volcar("run-monotonia.txt", "run.jl --kernel", ok, L)
    end
    if todo || "--oraculos" in hacer
        ok, L = ANR.tabla_paper()
        fallos += !volcar("run-tabla3-paper.txt", "run.jl --oraculos", ok, L)
        ok, L = ANR.tabla_repo()
        fallos += !volcar("run-valores-repo.txt", "run.jl --oraculos", ok, L)
        ok, L = ANR.oraculo_maximo()
        fallos += !volcar("run-oraculo-maximo.txt", "run.jl --oraculos", ok, L)
        ok, L = ANR.oraculo_ventana()
        fallos += !volcar("run-oraculo-ventana.txt", "run.jl --oraculos", ok, L)
        ok, L = ANR.oraculo_many2one()
        fallos += !volcar("run-oraculo-many2one.txt", "run.jl --oraculos", ok, L)
    end
    if "--brw" in hacer || todo
        ok, L = ANR.oraculo_brw()
        fallos += !volcar("run-oraculo-brw.txt", "run.jl --brw", ok, L)
    end

    println()
    println(fallos == 0 ? "TODO OK" : "$fallos comprobacion(es) FALLIDA(S)")
    return fallos
end

exit(main(ARGS))
