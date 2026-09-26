# diferencias.jl — informe DIFERENCIAS-v0.5-v0.6 (SL-4c-O / SL-4c-O-B).
#
#     julia --project=. src/diferencias.jl [RUTA_V0.5] [SALIDA_MD]
#
# La orden SL-4c-O (ajustada por SL-4c-O-B y SL-4c-O-C) exige un informe que
# liste, caso por caso, los vectores que cambian de resultado entre v0.5 y v0.6,
# y que **todo** caso que cambie lleve uno de los defectos de forma (estructura
# de EV-04, `cbid` ajeno u orden no canónico). Como el generador de v0.6 se
# amplía (modos de orden igualdad y descendente y modos de estructura) y no
# reproduce byte a byte los casos aleatorios de v0.5, la comparación exacta se
# hace reproduciendo las **entradas congeladas** de
# `vectores-estado-dag-v0.5.txt` con el oráculo corregido y comparándolas con la
# salida registrada en v0.5. Los casos nuevos de v0.6 no intervienen en el diff
# (v0.5 no los tenía).
#
# El lector independiente se `include`a para reutilizar su analizador y su render
# (no arranca `main`). Sale con código ≠ 0 si algún caso cambia sin defecto.

using EstadoDAG
import EstadoDAG.Transicion
using SHA
using Printf

include(joinpath(@__DIR__, "lector_vectores.jl"))

"Reconstruye la `Admision` de un caso leído (mismo camino que el lector)."
function reconstruir(caso::CasoLeido)
    pd = parsear_params(caso.param)
    isempty(caso.pow_bloques) && return (nothing, pd)
    idT = caso.pow_bloques[end].id
    A = Admision(pd, caso.pow_bloques, idT)
    resolver!(A, caso.post_bloques)
    return (A, pd)
end

"Defectos de forma v4 por bloque PoST del caso (`:estructura`, `:cbid` y/o `:orden`)."
function defectos_del_caso(caso::CasoLeido, pd::ParamsDAG)
    cbid_red = pd.P.cbid
    def = Dict{Int,Vector{Symbol}}()
    for b in caso.post_bloques
        ds = Symbol[]
        for tx in b.txs
            tx.tipo == Transicion.TxEvidencia || continue
            ev = tx.evidencia
            ev === nothing && continue
            (!isempty(tx.entradas) || !isempty(tx.salidas)) &&
                !(:estructura in ds) && push!(ds, :estructura)
            (ev.id1.cbid != cbid_red || ev.id2.cbid != cbid_red) &&
                !(:cbid in ds) && push!(ds, :cbid)
            !(ev.h1.pre_hash < ev.h2.pre_hash) && !(:orden in ds) && push!(ds, :orden)
        end
        isempty(ds) || (def[b.id] = ds)
    end
    return def
end

"Resultado corregido (v0.6) de un caso: RES por bloque y render de estado."
function resultado_corregido(A::Admision, caso::CasoLeido)
    res = Dict{Int,String}()
    for b in caso.post_bloques
        res[b.id] = get(A.validos, b.id, false) ? "OK" :
                    string(get(A.motivos, b.id, :ErrSinPadre))
    end
    S, _, desc = aplicar_historia(A)
    descs = String[string("DESC bloque=", idb, " tx=", itx, " motivo=", err)
                   for (idb, itx, err) in desc]
    tips = tips_validas(A)
    sp = isempty(tips) ? -1 : mejor_punta(A, tips)
    return (res = res, desc = descs, sel = sp, utxo = r_utxo(S), gar = r_gar(S),
            est = r_est(S))
end

function main()
    ruta = isempty(ARGS) ? "resultados/vectores-estado-dag-v0.5.txt" : ARGS[1]
    salida = length(ARGS) >= 2 ? ARGS[2] : "resultados/DIFERENCIAS-v0.5-v0.6.md"
    casos = parsear_fichero(ruta)
    println("diferencias: casos v0.5 = ", length(casos))
    lineas = String[]
    n_cambiados = 0
    fallos = String[]
    n_con_defecto = 0
    for caso in casos
        pd = parsear_params(caso.param)
        A, _ = reconstruir(caso)
        A === nothing && (push!(fallos, "caso $(caso.n): sin prefijo PoW"); continue)
        def = defectos_del_caso(caso, pd)
        isempty(def) || (n_con_defecto += 1)
        nuevo = resultado_corregido(A, caso)
        cambios = String[]
        for b in caso.post_bloques
            viejo = get(caso.res, b.id, "<falta>")
            nuevo.res[b.id] == viejo ||
                push!(cambios, "  - `RES bloque=$(b.id)`: `$(viejo)` → `$(nuevo.res[b.id])`")
        end
        caso.desc == nuevo.desc ||
            push!(cambios, "  - `DESC`: $(length(caso.desc)) → $(length(nuevo.desc)) líneas")
        caso.sel == nuevo.sel || push!(cambios, "  - `SEL`: $(caso.sel) → $(nuevo.sel)")
        caso.utxo == nuevo.utxo || push!(cambios, "  - `UTXO` distinto")
        caso.gar == nuevo.gar || push!(cambios, "  - `GAR` distinto")
        caso.est == nuevo.est ||
            push!(cambios, "  - `EST`: `$(caso.est)` → `$(nuevo.est)`")
        isempty(cambios) && continue
        n_cambiados += 1
        bloques_def = sort(collect(keys(def)))
        push!(lineas, "### Caso $(caso.n) · `$(caso.nombre)` · punto=$(caso.punto) k=$(caso.k) semilla=$(caso.semilla)")
        push!(lineas, "")
        if isempty(bloques_def)
            push!(lineas, "- **FALLO de SL-4c-O: cambia sin ningún defecto de forma.**")
            push!(fallos, "caso $(caso.n) ($(caso.nombre)) cambia sin defecto de forma")
        else
            for idb in bloques_def
                push!(lineas, "- Bloque $(idb) con defecto(s): $(join(string.(def[idb]), ", ")).")
            end
        end
        append!(lineas, cambios)
        push!(lineas, "")
    end
    mkpath(dirname(salida))
    io = open(salida, "w")
    println(io, "# DIFERENCIAS v0.5 → v0.6 · T04 SL-4c-O / SL-4c-O-B / SL-4c-O-C")
    println(io)
    println(io, "- Entrada comparada: `", ruta, "` (", length(casos), " casos congelados de v0.5).")
    println(io, "- Salida registrada de v0.5 reproducida con el oráculo corregido (v0.6).")
    println(io, "- Casos con algún defecto de forma en sus entradas: ", n_con_defecto, ".")
    println(io, "- Casos que cambian de resultado: ", n_cambiados, ".")
    println(io, "- Casos que cambian sin defecto de forma: ", length(fallos), ".")
    println(io)
    println(io, "Cada caso que cambia lleva al menos una `EvidenceTx` con entradas o")
    println(io, "salidas (EV-04), con `cbid` ajeno (RAT-1) o con")
    println(io, "`pre_hash(H1) ≥ pre_hash(H2)` (EV-04). El bloque que la contiene pasa de")
    println(io, "descartar la transacción y seguir válido a ser **inválido en la admisión**;")
    println(io, "sus descendientes caen por `ErrSinPadre` y desaparecen sus")
    println(io, "`DESC`/créditos/incidentes. La precedencia corregida es **por transacción**")
    println(io, "(SL-4c-O-B/-C): dentro del bloque, en su orden, cada `EvidenceTx` se")
    println(io, "comprueba `entradas/salidas/testigos` → `cbid` → orden y la primera")
    println(io, "defectuosa fija el motivo. v0.5 no contiene ningún caso con orden no")
    println(io, "canónico (el generador anterior siempre ordenaba) ni con estructura")
    println(io, "defectuosa (el generador anterior nunca daba entradas/salidas a una")
    println(io, "evidencia), así que todos los cambios observados son de `cbid` ajeno y")
    println(io, "las precedencias no alteran ningún resultado de este diff. Los casos")
    println(io, "nuevos de v0.6 (`forma-cbid`, `forma-orden-desc`, `forma-orden-igual`,")
    println(io, "`forma-ambos`, `forma-entradas`, `forma-salidas`,")
    println(io, "`forma-entradas-salidas`, `forma-entradas-cbid-orden`,")
    println(io, "`forma-dos-evidencias` y los aleatorios) no forman parte de este diff")
    println(io, "porque v0.5 no los tenía. T04 no modela `testigos`/`n_wit` (el modelo `Tx`")
    println(io, "de T01 solo tiene `entradas` y `salidas`), así que EV-04 solo puede")
    println(io, "manifestarse aquí por entradas/salidas.")
    println(io)
    if isempty(fallos)
        println(io, "**VEREDICTO = SIN CAMBIOS INJUSTIFICADOS.**")
    else
        println(io, "**VEREDICTO = FALLO** (", length(fallos), " casos):")
        for f in fallos
            println(io, "- ", f)
        end
    end
    println(io)
    println(io, "## Casos que cambian")
    println(io)
    if isempty(lineas)
        println(io, "(ninguno)")
    else
        for l in lineas
            println(io, l)
        end
    end
    close(io)
    @printf("diferencias: cambiados=%d con_defecto=%d fallos=%d -> %s\n",
            n_cambiados, n_con_defecto, length(fallos), salida)
    return isempty(fallos) ? 0 : 1
end

exit(main())
