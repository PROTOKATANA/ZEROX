# T04 — revalidación de GDR-v0.2 (ORDEN-T04 §3.1): reproducir EXACTAMENTE el
# corpus y los fixtures kaspa del instrumento antiguo. Si no se reproducen, se para.
#
# No se reutiliza ningún parser del instrumento antiguo: se analiza el corpus y el
# JSON de los fixtures con un lector propio mínimo (I/O dinámica, no camino caliente).

"Texto de un `ID32` (corta en el primer byte 0), como `id_a_texto` de GDR."
function texto_id32(id::GDR.ID32)
    i = findfirst(==(0x00), id)
    return String(collect(id[1:(i === nothing ? 32 : i - 1)]))
end

_texto_id(est::GDR.EstadoReferencia, i::Int) = i == 0 ? "-" : texto_id32(est.ids[i])
_csv(est::GDR.EstadoReferencia, xs) = join((_texto_id(est, x) for x in xs), ",")
_csv_colores(est::GDR.EstadoReferencia, gd, orden) =
    join(("$( _texto_id(est, x))=$(Int(gd.tipos[x]))" for x in orden if haskey(gd.tipos, x)), ",")

"Campo `clave=valor` de una línea, separado por el primer `=`."
function _campo(linea::AbstractString, clave::AbstractString)
    for t in split(linea)
        p = split(t, "=", limit = 2)
        length(p) == 2 && p[1] == clave && return String(p[2])
    end
    return nothing
end

"""
Reproduce el corpus GDR-v0.2 (`corpus-rust.txt`) con `modelo.jl`+`referencia.jl`.
Devuelve `(n_dags, n_bloques, discrepancias)`.
"""
function revalidar_corpus(ruta::AbstractString)
    discrepancias = String[]
    n_dags = 0
    n_bloques = 0
    params = GDR.Params()
    est = nothing
    nombres = Dict{String,Int}()
    idx = 0
    for linea in eachline(ruta)
        s = strip(linea)
        (isempty(s) || startswith(s, "#")) && continue
        cab = split(s)
        tipo = cab[1]
        if tipo == "DAG"
            n_dags += 1
            k = parse(Int, _campo(s, "k"))
            u2 = _campo(s, "u2") == "1"
            u3v = _campo(s, "u3")
            u3 = u3v == "2" ? GDR.U3_DYNAMIC :
                 (u3v == "1" ? GDR.U3_FILTER : GDR.U3_OFF)
            params = GDR.Params(k = k, u2 = u2, u3_mode = u3,
                                sp_mode = GDR.SP_ZEROX, merge_mode = GDR.MERGE_SPEC)
            est = nothing
            nombres = Dict{String,Int}()
            idx = 0
        elseif tipo == "B"
            idt = String(cab[2])
            padres_txt = _campo(s, "padres")
            padres = (padres_txt === nothing || isempty(padres_txt)) ? Int[] :
                     [nombres[p] for p in split(padres_txt, ",")]
            if est === nothing
                est = GDR.EstadoReferencia(params, idt)
                nombres[idt] = 1
                idx = 1
            else
                ok = GDR.anadir!(est, params, idt, padres,
                                 parse(UInt64, _campo(s, "slot")),
                                 parse(UInt64, _campo(s, "sd")),
                                 parse(UInt64, _campo(s, "sr")),
                                 parse(UInt64, _campo(s, "ident")))
                ok || push!(discrepancias, "corpus: anadir! rechazó $idt ($(est.motivo[end]))")
                idx += 1
                nombres[idt] = idx
            end
        elseif tipo == "E"
            idt = String(cab[2])
            gd = est.gd[idx]
            n_bloques += 1
            _texto_id(est, gd.sp) == _campo(s, "sp") ||
                push!(discrepancias, "corpus $idt sp: $( _texto_id(est, gd.sp)) != $(_campo(s, "sp"))")
            string(gd.blue_score) == _campo(s, "score") ||
                push!(discrepancias, "corpus $idt score")
            string(BigInt(gd.bw)) == _campo(s, "bw") ||
                push!(discrepancias, "corpus $idt bw")
            _csv(est, gd.ms_ordenado) == _campo(s, "ms") ||
                push!(discrepancias, "corpus $idt ms")
            _csv(est, gd.blues) == _campo(s, "blues") ||
                push!(discrepancias, "corpus $idt blues")
            _csv(est, gd.reds) == _campo(s, "reds") ||
                push!(discrepancias, "corpus $idt reds")
            _csv_colores(est, gd, gd.ms_ordenado) == _campo(s, "colores") ||
                push!(discrepancias, "corpus $idt colores")
            rank = string(BigInt(gd.bw), ":", est.sds[idx], ":", idt)
            rank == _campo(s, "rank") ||
                push!(discrepancias, "corpus $idt rank")
        elseif tipo == "END"
            # fin de DAG
        else
            push!(discrepancias, "corpus: línea desconocida: $s")
        end
    end
    return n_dags, n_bloques, discrepancias
end

# ---------------------------------------------------------------------------
# Lector JSON mínimo (solo para los fixtures kaspa; ASCII)
# ---------------------------------------------------------------------------

function _json_ws(b, i::Base.RefValue{Int})
    n = length(b)
    while i[] <= n && (b[i[]] in (UInt8(' '), UInt8('\n'), UInt8('\r'), UInt8('\t')))
        i[] += 1
    end
end

function _json_str(b, i::Base.RefValue{Int})
    i[] += 1
    io = IOBuffer()
    while b[i[]] != UInt8('"')
        if b[i[]] == UInt8('\\')
            i[] += 1
            c = b[i[]]
            if c == UInt8('n'); write(io, '\n')
            elseif c == UInt8('t'); write(io, '\t')
            else; write(io, c)
            end
        else
            write(io, b[i[]])
        end
        i[] += 1
    end
    i[] += 1
    return String(take!(io))
end

function _json_num(b, i::Base.RefValue{Int})
    j = i[]
    while i[] <= length(b) && (isdigit(Char(b[i[]])) ||
          b[i[]] in (UInt8('-'), UInt8('+'), UInt8('.'), UInt8('e'), UInt8('E')))
        i[] += 1
    end
    return parse(Float64, String(b[j:i[]-1]))
end

function _json_val(b, i::Base.RefValue{Int})
    _json_ws(b, i)
    c = b[i[]]
    if c == UInt8('{')
        i[] += 1
        d = Dict{String,Any}()
        _json_ws(b, i)
        b[i[]] == UInt8('}') && (i[] += 1; return d)
        while true
            _json_ws(b, i)
            k = _json_str(b, i)
            _json_ws(b, i)
            @assert b[i[]] == UInt8(':')
            i[] += 1
            d[k] = _json_val(b, i)
            _json_ws(b, i)
            if b[i[]] == UInt8(',')
                i[] += 1
            else
                @assert b[i[]] == UInt8('}')
                i[] += 1
                break
            end
        end
        return d
    elseif c == UInt8('[')
        i[] += 1
        v = Any[]
        _json_ws(b, i)
        b[i[]] == UInt8(']') && (i[] += 1; return v)
        while true
            push!(v, _json_val(b, i))
            _json_ws(b, i)
            if b[i[]] == UInt8(',')
                i[] += 1
            else
                @assert b[i[]] == UInt8(']')
                i[] += 1
                break
            end
        end
        return v
    elseif c == UInt8('"')
        return _json_str(b, i)
    elseif c == UInt8('t')
        i[] += 4; return true
    elseif c == UInt8('f')
        i[] += 5; return false
    elseif c == UInt8('n')
        i[] += 4; return nothing
    else
        return _json_num(b, i)
    end
end

leer_json(ruta::AbstractString) = _json_val(codeunits(read(ruta, String)), Ref(1))

"""
Reproduce los fixtures kaspa (`dag0..dag5.json`) con `SP_KASPA`/`MERGE_KASPA`,
`u2=false`, `U3_OFF`, `slot=0`, `sd=0`, `sr=typemax-1`, `ident=0`.
Devuelve `(n_bloques, discrepancias)`.
"""
function revalidar_kaspa(dir::AbstractString)
    discrepancias = String[]
    n_bloques = 0
    for dag in 0:5
        obj = leer_json(joinpath(dir, "dag$dag.json"))
        k = Int(obj["K"])
        gen = String(obj["GenesisID"])
        nombres = String[gen]
        especs = Tuple{String,Vector{Int}}[]
        for bl in obj["Blocks"]
            padres = Int[]
            for p in bl["Parents"]
                j = findfirst(==(String(p)), nombres)
                if j === nothing
                    push!(discrepancias, "kaspa dag$dag: padre desconocido $p")
                else
                    push!(padres, j)
                end
            end
            push!(nombres, String(bl["ID"]))
            push!(especs, (String(bl["ID"]), padres))
        end
        params = GDR.Params(k = k, u2 = false, u3_mode = GDR.U3_OFF,
                            sp_mode = GDR.SP_KASPA, merge_mode = GDR.MERGE_KASPA)
        est = GDR.EstadoReferencia(params, gen)
        for (idt, padres) in especs
            ok = GDR.anadir!(est, params, idt, padres, UInt64(0), UInt64(0),
                             typemax(UInt64) - 1, UInt64(0))
            ok || push!(discrepancias, "kaspa dag$dag: anadir! rechazó $idt")
        end
        for (j, bl) in enumerate(obj["Blocks"])
            i = 1 + j
            sp_esp = findfirst(==(String(bl["ExpectedSelectedParent"])), nombres)
            blues_esp = [findfirst(==(String(x)), nombres) for x in bl["ExpectedBlues"]]
            reds_esp = [findfirst(==(String(x)), nombres) for x in bl["ExpectedReds"]]
            n_bloques += 1
            (est.gd[i].sp == sp_esp && est.gd[i].blues == blues_esp &&
             est.gd[i].reds == reds_esp &&
             est.gd[i].blue_score == UInt64(bl["ExpectedScore"])) ||
                push!(discrepancias, "kaspa dag$dag bloque $i")
        end
    end
    return n_bloques, discrepancias
end
