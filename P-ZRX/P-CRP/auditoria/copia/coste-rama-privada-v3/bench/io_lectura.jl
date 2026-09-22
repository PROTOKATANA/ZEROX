# io_lectura.jl — microbenchmark de I/O de SOLO LECTURA, acotado (encargo D9).
#
# Reglas respetadas:
#  - solo lectura; no se escribe en dispositivos raw ni se tocan cachés del sistema;
#  - el dataset es acotado y vive en /tmp/opencode, nunca dentro del repositorio;
#  - no se usa `drop_caches`: por tanto lo medido es PAGE CACHE CALIENTE. No se
#    distingue page cache de almacenamiento, y así se declara.
#  - `S_adversario` NO se deriva de estos números: queda PENDIENTE sin un perfil de
#    hardware compatible con medición de cola, núcleos y PoAS/KZG por slot.
using Printf
using Random

const RUTA = let
    d = "/tmp/opencode"
    isdir(d) || mkpath(d)
    joinpath(d, "crp-v03-io.bin")
end
const TAM = 64 * 1024 * 1024      # 64 MiB acotados
const BLOQUE = 4096

function preparar()
    if !isfile(RUTA) || filesize(RUTA) != TAM
        open(RUTA, "w") do io
            buf = rand(UInt8, BLOQUE)
            for _ in 1:(TAM ÷ BLOQUE)
                write(io, buf)
            end
        end
    end
    return RUTA
end

function latencias_aleatorias(n::Int; seed::Int=1234)
    rng = MersenneTwister(seed)
    nbloques = TAM ÷ BLOQUE
    tiempos = Float64[]
    buf = Vector{UInt8}(undef, BLOQUE)
    io = open(RUTA, "r")
    try
        for _ in 1:n
            b = rand(rng, 0:(nbloques - 1))
            t0 = time_ns()
            seek(io, b * BLOQUE)
            read!(io, buf)
            push!(tiempos, (time_ns() - t0) / 1e6)   # ms
        end
    finally
        close(io)
    end
    sort!(tiempos)
    return tiempos
end

function percentil(t, p)
    isempty(t) && return 0.0
    return t[max(1, min(length(t), ceil(Int, p * length(t))))]
end

function main()
    preparar()
    println("I/O solo lectura — destino=", RUTA, " bytes=", filesize(RUTA))
    println("caché = PAGE CACHE CALIENTE (no se ejecutó drop_caches)")
    println("no distingue page cache de almacenamiento; profundidad de cola = 1 (secuencial síncrona)")
    t = latencias_aleatorias(20_000)
    @printf("p50=%.3f ms  p95=%.3f ms  p99=%.3f ms  max=%.3f ms\n",
            percentil(t, 0.50), percentil(t, 0.95), percentil(t, 0.99), t[end])
    tp = length(t) * BLOQUE / (sum(t) / 1000) / 1e6
    @printf("rendimiento medio sostenido = %.1f MiB/s (bloque=%d B)\n", tp, BLOQUE)
    println("S_microbenchmark = NO acreditado como flujo completo (solo componente I/O de lectura).")
    println("S_adversario = PENDIENTE: falta perfil de hardware compatible (CPU, PoAS/KZG, PoT por slot).")
end

main()
