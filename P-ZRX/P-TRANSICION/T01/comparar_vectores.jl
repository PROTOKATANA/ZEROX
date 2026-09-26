# comparar_vectores.jl — diferencia dos exportaciones T01 caso por caso (SL-4c-O).
#
#     julia comparar_vectores.jl A.txt B.txt SALIDA.md
#
# Comparación de **texto**, sin `using Transicion`. Empareja los `CASO` por
# `(nombre, punto, semilla)` más su índice de repetición —el `n=` secuencial
# cambia al insertar casos nuevos y por eso no se usa—, exige que el **cuerpo**
# (todas las líneas salvo `CASO` y `RES`) sea idéntico en cada par y lista los
# cambios de `RES` y los casos nuevos. Sale con código ≠ 0 si un par emparejado
# difiere en algo que no sea `RES` o si falta en B un caso de A.
#
# Escribe el informe en `SALIDA.md`. No es código de producto del oráculo: es el
# artefacto del punto 4 de `ORDEN-SL4c-O.md`.

using SHA

const RE_CASO = r"^CASO n=(\d+) nombre=(\S+) punto=(\S+) semilla=(\S+)"
const RE_RES = r"^RES bloque=(\d+) res=(\S+)"

function leer(ruta::AbstractString)
    casos = Dict{Tuple{Tuple{String,String,String},Int},String}()
    idx = Dict{Tuple{String,String,String},Int}()
    actual = String[]
    clave = nothing
    for linea in eachline(ruta)
        if startswith(linea, "CASO ")
            actual = String[linea]
            m = match(RE_CASO, linea)
            m === nothing && error("CASO malformado: $linea")
            base = (String(m[2]), String(m[3]), String(m[4]))
            k = get(idx, base, 0) + 1
            idx[base] = k
            clave = (base, k)
        elseif startswith(linea, "FIN")
            clave === nothing && error("FIN sin CASO")
            push!(actual, linea)
            casos[clave] = join(actual, "\n")
            actual = String[]
            clave = nothing
        elseif !isempty(actual)
            push!(actual, linea)
        end
    end
    return casos
end

# `(n, nombre, punto, semilla)` del `CASO` que abre el bloque.
function meta(bloque::AbstractString)
    m = match(RE_CASO, first(split(bloque, "\n")))
    return (parse(Int, m[1]), String(m[2]), String(m[3]), String(m[4]))
end

function cuerpo_res(bloque::AbstractString)
    cuerpo = String[]
    res = Dict{Int,String}()
    for l in split(bloque, "\n")
        (startswith(l, "CASO ") || l == "FIN") && continue
        m = match(RE_RES, l)
        if m === nothing
            push!(cuerpo, l)
        else
            res[parse(Int, m[1])] = String(m[2])
        end
    end
    return join(cuerpo, "\n"), res
end

sha256_archivo(p::AbstractString) = bytes2hex(sha256(read(p)))

# `comparar_vectores.jl` es autónomo (no carga `Transicion`): define localmente
# los alias viejos del texto de v0.4, como pide ORDEN-SL4c-O-B. Ya no se
# exportan desde el módulo. SL-4c-O-C añade el renombre del defecto estructural
# de EV-04.
const ALIAS_CBID = "ErrCbidAjeno"
const ALIAS_ORDEN = "ErrOrdenCanonico"
const ALIAS_ENTRADAS = "ErrEvidenciaConEntradas"

es_cambio_forma(va, vb) =
    (va == ALIAS_CBID && vb == "ErrForma(EvidenciaCbidAjeno)") ||
    (va == ALIAS_ORDEN && vb == "ErrForma(OrdenCanonicoInvalido)") ||
    (va == ALIAS_ENTRADAS && vb == "ErrForma(EvidenciaConEntradasOSalidas)")

motivo(va, vb) = es_cambio_forma(va, vb) ?
    (va == ALIAS_CBID ? "RAT-1: semántico → forma" :
     va == ALIAS_ORDEN ? "EV-01/EV-04: semántico → forma" :
                         "EV-04: semántico → forma") :
    "clasificación"

function main()
    length(ARGS) == 3 || error("uso: comparar_vectores.jl A.txt B.txt SALIDA.md")
    ruta_a, ruta_b, salida = ARGS
    ca = leer(ruta_a)
    cb = leer(ruta_b)

    cambios = NamedTuple[]     # (caso, n, punto, bloque, viejo, nuevo, motivo)
    fallos = String[]
    nuevos = Dict{Tuple{String,String},Int}()

    for (k, bloque_a) in sort(collect(ca); by = x -> string(x[1]))
        if !haskey(cb, k)
            push!(fallos, "falta en B: $(k[1][1]) punto $(k[1][2]) rep $(k[2])")
            continue
        end
        bloque_b = cb[k]
        cuerpo_a, res_a = cuerpo_res(bloque_a)
        cuerpo_b, res_b = cuerpo_res(bloque_b)
        cuerpo_a == cuerpo_b ||
            push!(fallos, "cuerpo distinto: $(k[1][1]) punto $(k[1][2]) rep $(k[2])")
        n_a, nombre_a, punto_a = meta(bloque_a)[1:3]
        for bid in sort(collect(union(keys(res_a), keys(res_b))))
            va = get(res_a, bid, "<falta>")
            vb = get(res_b, bid, "<falta>")
            va == vb || push!(cambios, (caso = nombre_a, n = n_a, punto = punto_a,
                                        bloque = bid, viejo = va, nuevo = vb,
                                        motivo = motivo(va, vb)))
        end
    end
    for (k, bloque_b) in sort(collect(cb); by = x -> string(x[1]))
        haskey(ca, k) && continue
        _, nombre_b, punto_b = meta(bloque_b)[1:3]
        nuevos[(nombre_b, punto_b)] = get(nuevos, (nombre_b, punto_b), 0) + 1
    end

    ok = isempty(fallos) && all(c -> es_cambio_forma(c.viejo, c.nuevo), cambios)

    open(salida, "w") do io
        println(io, "# DIFERENCIAS v0.4 → v0.5 — T01 (SL-4c-O-C)")
        println(io)
        println(io, "**Generado por:** `comparar_vectores.jl ",
                basename(ruta_a), " ", basename(ruta_b), " ", basename(salida), "`.")
        println(io, "**Modelo:** DeepSeek `deepseek-flash` (esfuerzo `high`).")
        println(io, "**Fecha:** ", strip(read(`date -Is`, String)), ".")
        println(io)
        println(io, "| Fichero | sha256 |")
        println(io, "|---|---|")
        println(io, "| `", basename(ruta_a), "` | `", sha256_archivo(ruta_a), "` |")
        println(io, "| `", basename(ruta_b), "` | `", sha256_archivo(ruta_b), "` |")
        println(io)
        println(io, "## Resumen")
        println(io)
        println(io, "- Casos en v0.4: **", length(ca), "**; casos en v0.5: **",
                length(cb), "**.")
        println(io, "- Casos emparejados con el cuerpo idéntico y **algún `RES` cambiado**: **",
                length(cambios), "**.")
        println(io, "- Casos nuevos en v0.5 (sin pareja en v0.4): **",
                sum(values(nuevos); init = 0), "** (", length(nuevos),
                " grupos `nombre`/`punto`).")
        println(io, "- Pares con diferencia de cuerpo (debe ser **0**): **",
                length(fallos), "**.")
        println(io, "- Cambios que **no** son renombres a `ErrForma(...)` de `cbid` ajeno, ",
                "orden no canónico o entradas/salidas (debe ser **0**): **",
                count(c -> !es_cambio_forma(c.viejo, c.nuevo), cambios), "**.")
        println(io)
        if !isempty(fallos)
            println(io, "### FALLOS (no debería haber ninguno)")
            println(io)
            for f in fallos
                println(io, "- ", f)
            end
            println(io)
        end
        println(io, "## Cambios de resultado, caso por caso")
        println(io)
        if isempty(cambios)
            println(io, "(ninguno)")
        else
            println(io, "| Caso | `CASO n` (v0.4) | Punto | Bloque | `RES` v0.4 | `RES` v0.5 | Motivo |")
            println(io, "|---|---:|---:|---:|---|---|---|")
            for c in cambios
                println(io, "| ", c.caso, " | ", c.n, " | ", c.punto, " | ", c.bloque,
                        " | `", c.viejo, "` | `", c.nuevo, "` | ", c.motivo, " |")
            end
        end
        println(io)
        println(io, "## Casos nuevos en v0.5 (adición, no cambio)")
        println(io)
        if isempty(nuevos)
            println(io, "(ninguno)")
        else
            println(io, "| Caso | Punto | Casos |")
            println(io, "|---|---:|---:|")
            for (k, v) in sort(collect(nuevos); by = x -> (x[1][1], parse(Int, x[1][2])))
                println(io, "| ", k[1], " | ", k[2], " | ", v, " |")
            end
        end
        println(io)
        println(io, "## Veredicto")
        println(io)
        println(io, ok ?
            "**SIN FALLOS.** Todo caso cuyo `RES` cambia es un renombre a `ErrForma(...)` " *
            "de la evidencia con `cbid` ajeno, con orden no canónico o con " *
            "entradas/salidas; ningún caso cambia sin uno de esos defectos, y ningún " *
            "cuerpo difiere. Los casos nuevos son adiciones (`ev-orden`, " *
            "`ev-orden_igual`, `ev-ambos`, `ev-dir-orden-cbid`, `ev-dir-cbid-orden`), " *
            "no cambios de casos de v0.4." :
            "**CON FALLOS.** Hay cambios o diferencias de cuerpo no explicados por los defectos.")
    end

    println("comparar: v0.4=", length(ca), " v0.5=", length(cb),
            " cambios=", length(cambios), " nuevos=", sum(values(nuevos); init = 0),
            " fallos=", length(fallos), " -> ", salida)
    return ok ? 0 : 1
end

exit(main())
