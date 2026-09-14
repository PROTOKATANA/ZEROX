# GDR-v0.2 — memoria del estado del kernel frente a n (LINEO pregunta 1). Salida → resultados/MEMORIA.txt
# Recuperado al migrar: la corrección 1 midió desde tmp/medir_memoria.jl y borró el script.
# Uso: veritas/julia.sh --project=veritas/consenso/ghostdag-rank-v1 \
#        veritas/consenso/ghostdag-rank-v1/bench/memoria.jl [--seed 0xB0E1]
using GhostdagRank
using StableRNGs
using Dates

function cabecera(comando::String, seed::UInt64)
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
    println("RAM total (GB)       = ", round(Sys.total_memory() / 2^30, digits=1))
    println("comando              = ", comando)
    println("seed                 = 0x", string(seed, base=16))
end

function parsear_seed(defecto::UInt64)
    i = findfirst(==("--seed"), ARGS)
    (i === nothing || i == length(ARGS)) && return defecto
    return parse(UInt64, ARGS[i + 1])
end

"Construye los n−1 primeros bloques y mide @allocated del último `anadir!`."
function medir(especs::Vector{BloqueEspec}, params::Params)
    n = length(especs)
    est = EstadoRapido(params, "G")
    for i in 2:(n - 1)
        e = especs[i]
        anadir!(est, params, e.id, e.padres, e.slot, e.sd, e.sr, e.ident) || error("bloque inválido $(e.id)")
    end
    e = especs[n]
    asignado = @allocated anadir!(est, params, e.id, e.padres, e.slot, e.sd, e.sr, e.ident)
    return Base.summarysize(est), asignado
end

seed = parsear_seed(UInt64(0xB0E1))
println("== MEMORIA GDR-v0.2 ==")
cabecera("veritas/julia.sh --project=veritas/consenso/ghostdag-rank-v1 veritas/consenso/ghostdag-rank-v1/bench/memoria.jl", seed)
println("(Base.summarysize del EstadoRapido tras n bloques y @allocated del último anadir!;")
println(" generador con ventana de padres 30, regla C por defecto. Memoria O(n²) en total:")
println(" est.anc guarda un BitSet de ancestros por bloque y blue_idents se copia por bloque.)")
println()
medir(generar_dag(StableRNG(seed), 50; ventana=30), P_DEFECTO)   # compilar antes de medir
rng = StableRNG(seed)
println(rpad("n", 8), lpad("summarysize (bytes)", 22), lpad("bytes/bloque", 15), lpad("@allocated último", 20))
for n in (100, 200, 400, 800, 1600, 3200, 6400)
    especs = generar_dag(rng, n; ventana=30)
    tam, asignado = medir(especs, P_DEFECTO)
    println(rpad(n, 8), lpad(tam, 22), lpad(round(Int, tam / n), 15), lpad(asignado, 20))
end
