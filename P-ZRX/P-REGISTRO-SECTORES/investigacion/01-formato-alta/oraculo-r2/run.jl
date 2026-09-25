# CLI reproducible del oráculo S01.
#
#   julia --project=. run.jl <volcado>
#
# Imprime una línea `clave=valor` por magnitud. El prototipo Rust compara `raiz_chunks` y `r2`.

include(joinpath(@__DIR__, "src", "oraculo.jl"))
using .OraculoS01

function main()
    if isempty(ARGS)
        println(stderr, "uso: julia --project=. run.jl <volcado>")
        exit(2)
    end
    ruta = ARGS[1]
    bytes = read(ruta)
    t0 = time()
    r = OraculoS01.recalcular(bytes)
    espera = time() - t0

    println("dump=", ruta)
    println("version=1")
    println("cbid=", r.cbid)
    println("sector_index=", r.sector_index)
    println("history_size=", r.history_size)
    println("pieces_in_sector=", r.pieces_in_sector)
    println("n=", r.n)
    println("digest_mapa=", bytes2hex(r.digest_mapa))
    println("digest_meta=", bytes2hex(r.digest_meta))
    println("raiz_chunks=", bytes2hex(r.raiz_chunks))
    println("r2=", bytes2hex(r.r2))
    println("t_oraculo_s=", espera)
    return 0
end

exit(main())
