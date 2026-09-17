#!/usr/bin/env julia
# Volcado del oráculo GDR-v0.2 para el encargo 03 (Rust GHOSTDAG y rank).
#
# Este driver NO define ninguna regla: usa las funciones ya validadas de GDR-v0.2
# (EstadoReferencia / EstadoRapido, regla C por defecto) para generar un corpus de DAGs
# de prueba y volcar, por bloque, sp, mergeset ordenado, colores, blue_score, blue_work
# y rank. El test Rust lee este fichero en tiempo de ejecución y compara.
#
# Uso (desde este directorio, con el depot dentro de implementacion-03):
#   JULIA_DEPOT_PATH=... julia --check-bounds=yes --project=. volcar_corpus.jl
using GhostdagRank
using StableRNGs
using JSON3
using Dates

const DIR_SALIDA = joinpath(@__DIR__, "resultados")
const FICHERO_CORPUS = joinpath(DIR_SALIDA, "corpus-rust.txt")
const FICHERO_KASPA = joinpath(DIR_SALIDA, "kaspa-rust.txt")

id_de(est, i) = i == 0 ? "-" : id_a_texto(est.ids[i])
csv_ids(est, xs) = join((id_de(est, x) for x in xs), ",")
csv_colores(est, gd, orden) = join(
    ("$(id_de(est, x))=$(Int(gd.tipos[x]))" for x in orden if haskey(gd.tipos, x)), ",")

function volcar_dag(io, est_ref, params, etiqueta::String)
    println(io, "DAG $(etiqueta) k=$(params.k) u2=$(params.u2 ? 1 : 0) u3=$(params.u3_mode == U3_DYNAMIC ? 2 : 0)")
    for i in 1:est_ref.n
        e = est_ref
        println(io, "B ", id_de(e, i), " slot=", e.slots[i], " sd=", e.sds[i],
                " sr=", e.srs[i], " ident=", e.idents[i],
                " padres=", csv_ids(e, e.padres[i]))
        gd = e.gd[i]
        println(io, "E ", id_de(e, i), " sp=", id_de(e, gd.sp),
                " score=", gd.blue_score, " bw=", string(BigInt(gd.bw)),
                " ms=", csv_ids(e, gd.ms_ordenado),
                " blues=", csv_ids(e, gd.blues),
                " reds=", csv_ids(e, gd.reds),
                " colores=", csv_colores(e, gd, gd.ms_ordenado),
                " rank=", string(BigInt(gd.bw)), ":", e.sds[i], ":", id_de(e, i))
    end
    println(io, "END")
end

function generar_corpus()
    mkpath(DIR_SALIDA)
    open(FICHERO_CORPUS, "w") do io
        println(io, "# corpus GDR-v0.2 regla C -> Rust; generado ", Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS"))
        d = 0
        for k in (1, 3, 8, 30), ventana in (1, 2, 4, 6, 30)
            rng = StableRNG(0xC0FFEE + UInt64(1000 * k + ventana))
            n = 30 + rand(rng, 0:90)
            especs = generar_dag(rng, n; ventana=ventana)
            params = Params(k=k)
            est = entregar(EstadoReferencia, params, especs, collect(1:n), "G")
            volcar_dag(io, est, params, "$(d)")
            d += 1
        end
        # Una familia con hermanos/copias de billete forzadas y ventana pequeña.
        for semilla in 1:8
            rng = StableRNG(0xBEEF + UInt64(semilla))
            n = 60 + rand(rng, 0:40)
            especs = generar_dag(rng, n; ventana=6)
            params = Params()
            est = entregar(EstadoReferencia, params, especs, collect(1:n), "G")
            volcar_dag(io, est, params, "S$(semilla)")
        end
    end
    println("corpus escrito en ", FICHERO_CORPUS)
end

function generar_kaspa()
    open(FICHERO_KASPA, "w") do io
        println(io, "# vectores oficiales rusty-kaspa (SP_KASPA/MERGE_KASPA, u2 off, u3 off)")
        base = joinpath(@__DIR__, "fixtures", "kaspa")
        for dag in 0:5
            obj = JSON3.read(read(joinpath(base, "dag$dag.json"), String))
            k = Int(obj["K"])
            gen = String(obj["GenesisID"])
            nombres = String[gen]
            especs = BloqueEspec[]
            for b in obj["Blocks"]
                padres = [findfirst(==(String(p)), nombres) for p in b["Parents"]]
                push!(nombres, String(b["ID"]))
                push!(especs, BloqueEspec(String(b["ID"]); padres=padres, slot=0, sd=0,
                                          sr=typemax(UInt64) - 1, ident=0))
            end
            params = Params(k=k, u2=false, u3_mode=U3_OFF, sp_mode=SP_KASPA, merge_mode=MERGE_KASPA)
            est = EstadoReferencia(params, gen)
            _, motivos = construir(est, params, especs)
            any(!=(:ok), motivos) && error("vector kaspa dag$dag con rechazos: $motivos")
            println(io, "DAGK $(dag) k=$(k)")
            for i in 1:est.n
                println(io, "B ", id_de(est, i), " padres=", csv_ids(est, est.padres[i]))
                gd = est.gd[i]
                println(io, "E ", id_de(est, i), " sp=", id_de(est, gd.sp),
                        " score=", gd.blue_score,
                        " blues=", csv_ids(est, gd.blues),
                        " reds=", csv_ids(est, gd.reds))
            end
            println(io, "END")
        end
    end
    println("kaspa escrito en ", FICHERO_KASPA)
end

generar_corpus()
generar_kaspa()
