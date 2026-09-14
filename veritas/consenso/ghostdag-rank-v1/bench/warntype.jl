# GDR-v0.2 — @code_warntype del kernel (LINEO §3.1 y §6). Salida → resultados/WARNTYPE.txt
# Recuperado al migrar: la corrección 1 lo ejecutó desde tmp/warntype.jl y borró el script.
using GhostdagRank
using InteractiveUtils
using Dates
const G = GhostdagRank

function cabecera(comando::String)
    git_head = try
        strip(read(`git -C $(joinpath(@__DIR__, "..", "..", "..", "..")) rev-parse HEAD`, String))
    catch
        "desconocido (git no disponible)"
    end
    println("git HEAD             = ", git_head)
    println("fecha                = ", Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS"))
    println("julia VERSION        = ", VERSION)
    println("hilos default        = ", Threads.nthreads(:default))
    println("CPU                  = ", Sys.CPU_NAME)
    println("comando              = ", comando)
end

const FIRMAS = [
    ("peso(::UInt64)", G.peso, (UInt64,)),
    ("+(::BW256, ::BW256)", +, (BW256, BW256)),
    ("tam_anticono_azul", G.tam_anticono_azul, (EstadoRapido, G.GDKernel, Int)),
    ("revisar_con_bloque_cadena", G.revisar_con_bloque_cadena,
     (EstadoRapido, G.GDKernel, Int, Int, Dict{Int,UInt32}, UInt32, UInt32)),
    ("check_azul", G.check_azul, (EstadoRapido, G.GDKernel, Int, UInt32)),
    ("anadir!(::EstadoRapido, …)", anadir!,
     (EstadoRapido, Params, String, Vector{Int}, UInt64, UInt64, UInt64, UInt64)),
]

println("== WARNTYPE GDR-v0.2 ==")
cabecera("veritas/julia.sh --project=veritas/consenso/ghostdag-rank-v1 veritas/consenso/ghostdag-rank-v1/bench/warntype.jl")
println("JET.jl no se ejecuta (opcional por LINEO; no está en el Manifest del instrumento).")
println()
for (nombre, f, tipos) in FIRMAS
    io = IOBuffer()
    code_warntype(io, f, tipos; debuginfo=:none)
    texto = String(take!(io))
    cuerpo = match(r"Body::(\S+)", texto)
    anys = count(l -> occursin(r"::Any\b", l) && !occursin("PartialStruct", l), split(texto, '\n'))
    println("== @code_warntype: ", nombre, " ==")
    println("Body::", cuerpo === nothing ? "?" : cuerpo.captures[1],
            " | líneas con ::Any fuera de PartialStruct: ", anys)
    println(texto)
end
