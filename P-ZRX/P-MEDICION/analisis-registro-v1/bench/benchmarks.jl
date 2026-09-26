# benchmarks.jl — V5: coste del análisis real (W06d4) y de un sintético de 10⁶ eventos
#
# Uso:
#   JULIA_DEPOT_PATH=<zona>/.julia-depot:/home/katana/.julia \
#     env -u LD_LIBRARY_PATH julia --project=. bench/benchmarks.jl

using BenchmarkTools
using StableRNGs
using Printf
using Profile

include(joinpath(@__DIR__, "..", "src", "analisis_registro_v1.jl"))
using .AnalisisRegistroV1
const AR = AnalisisRegistroV1

const RAIZ = dirname(@__DIR__)
const REAL = joinpath(RAIZ, "..", "datos", "W06d4-real")

# ---------------------------------------------------------------------------
# Generador reproducible de un registro sintético (Julia; nunca Python)
# ---------------------------------------------------------------------------
function generar_sintetico(destino::AbstractString, n_bloques::Int, semilla::Integer)
    nodos = ["A", "B", "C"]
    rng = StableRNG(UInt64(semilla))
    for n in nodos
        mkpath(joinpath(destino, n))
    end
    ios = Dict(n => open(joinpath(destino, n, "registro.jsonl"), "w") for n in nodos)
    try
        for n in nodos
            println(ios[n], "{\"tipo\":\"arranque\",\"reloj_ns\":0,\"reloj_pared_ns\":0,\"version_esquema\":1,\"fase\":\"limpio\"}")
        end
        for k in 1:n_bloques
            base = Int64(k) * 1_000_000
            a = nodos[rand(rng, 1:3)]
            h = "h" * string(k)
            println(ios[a], "{\"tipo\":\"bloque_producido\",\"reloj_ns\":", base,
                            ",\"reloj_pared_ns\":", base, ",\"hash\":\"", h,
                            "\",\"slot\":", k, ",\"n_padres\":1,\"bytes\":120,\"azules_mergeset\":2,\"rojos_mergeset\":1}")
            for b in nodos
                b == a && continue
                t = base + rand(rng, 1:999_999)
                println(ios[b], "{\"tipo\":\"bloque_red_admitido\",\"reloj_ns\":", t,
                                ",\"reloj_pared_ns\":", t, ",\"hash\":\"", h,
                                "\",\"familia\":\"post\",\"slot\":", k,
                                ",\"n_padres\":1,\"bytes\":120,\"t_cabecera_ns\":10,\"t_admision_ns\":100,",
                                "\"t_persistencia_ns\":7,\"t_total_ns\":200,\"n_bloques_dag\":", k,
                                ",\"azules_mergeset\":2,\"rojos_mergeset\":1}")
            end
            c = nodos[rand(rng, 1:3)]
            p = "p" * string(rand(rng, 1:1000))
            t = base + rand(rng, 1:500_000)
            println(ios[c], "{\"tipo\":\"cambio_punta\",\"reloj_ns\":", t, ",\"reloj_pared_ns\":", t,
                            ",\"punta\":\"", p, "\",\"resumen_estado\":\"s", rand(rng, 1:100), "\"}")
        end
        for n in nodos
            println(ios[n], "{\"tipo\":\"parada\",\"reloj_ns\":", Int64(n_bloques) * 1_000_000 + 1_000_000,
                            ",\"reloj_pared_ns\":", Int64(n_bloques) * 1_000_000 + 1_000_000, ",\"motivo\":\"fin\"}")
        end
    finally
        for io in values(ios)
            close(io)
        end
    end
    return destino
end

function conteo_lineas(destino, nodos)
    return sum(countlines(joinpath(destino, n, "registro.jsonl")) for n in nodos)
end

function main()
    println("== V5: análisis W06d4 real (3 nodos) ==")
    nodos_real = ["A", "B", "C"]
    AR.analizar(REAL, nodos_real)                      # calienta JIT
    t_real = @benchmark AR.analizar($REAL, $nodos_real) samples = 20 evals = 1
    @show minimum(t_real).time minimum(t_real).memory minimum(t_real).allocs
    @printf("real: mediana=%.3f ms  memoria=%.1f MiB  allocs=%d\n",
            median(t_real).time / 1e6, median(t_real).memory / 2^20, median(t_real).allocs)

    println("== V5: sintético 10^6 eventos ==")
    dest = joinpath(RAIZ, "resultados", "sintetico-1e6")
    if !isfile(joinpath(dest, "A", "registro.jsonl"))
        # 250 000 bloques × 4 eventos (1 producido + 2 admitidos + 1 cambio) = 10^6 eventos
        generar_sintetico(dest, 250_000, 0x5a5a)
    end
    nl = conteo_lineas(dest, ["A", "B", "C"])
    @printf("sintético: %d líneas en total\n", nl)
    AR.analizar(dest, ["A", "B", "C"])                 # calienta
    t0 = time()
    @time begin
        res = AR.analizar(dest, ["A", "B", "C"])
        println("  latencias por par: ", length(res.latencias),
                " | divergencia medida: ", res.divergencia_medida)
    end
    println("  tiempo de pared (segunda corrida): ", round(time() - t0; digits = 3), " s")

    # BenchmarkTools con pocas muestras (el análisis tarda segundos)
    ts = @benchmark AR.analizar($dest, $(String["A", "B", "C"])) samples = 3 evals = 1
    @show minimum(ts).time minimum(ts).memory minimum(ts).allocs
    @printf("sintético: mediana=%.3f s  memoria=%.1f MiB  allocs=%d\n",
            median(ts).time / 1e9, median(ts).memory / 2^20, median(ts).allocs)

    if median(ts).time / 1e9 > 60
        println("== >60 s: perfil (Profile) ==")
        Profile.clear()
        Profile.@profile AR.analizar(dest, ["A", "B", "C"])
        io = IOBuffer()
        Profile.print(io; format = :flat, sortedby = :count, mincount = 20)
        print(String(take!(io)))
    end
    return 0
end

exit(main())
