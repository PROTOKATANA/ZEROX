# exportar_negativos.jl — T01-C: exportador determinista de vectores NEGATIVOS
# de transacción (ORDEN-T01-C §3.3).
#
#     julia --project=. exportar_negativos.jl [--fecha <ISO-8601>] \
#         [--salida RUTA] [--contrato RUTA]
#
# Escribe `resultados/vectores-transicion-negativos-v0.txt` (mismo formato de
# líneas que T01-B, §3.4 de ORDEN-T01-B) y su sha256 en formato `sha256sum`
# (`<hash>  <nombre>`). Solo interfaces por defecto (CUT_HWPhi, FC3, SEC0); un
# hilo; sin Python.
#
# Cada caso trae el error esperado escrito a mano (`CasoNegativo.esperado`) y se
# comprueba contra el oráculo antes de escribirlo; si alguno no coincide, no se
# escribe y el proceso termina con código ≠ 0.

using Transicion
using SHA
using Printf

const CONTRATO_DEF = "/home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/CONTRATO-v0.md"
const SALIDA_DEF = "resultados/vectores-transicion-negativos-v0.txt"

# --- nombres del formato ---------------------------------------------------

const NOMBRE_FAMILIA = Dict(Genesis => "Genesis", PoW => "PoW", PoST => "PoST")
const NOMBRE_FASE = Dict(FaseGenesis => "FaseGenesis", FasePoW => "FasePoW",
                         FasePoST => "FasePoST")
const NOMBRE_ORIGEN = Dict(OrigenCoinbasePow => "CoinbasePow",
                           OrigenTx => "Tx", OrigenLiberacion => "Liberacion")
const ORDEN_ORIGEN = Dict(OrigenCoinbasePow => 0, OrigenTx => 1,
                          OrigenLiberacion => 2)
const NOMBRE_TIPO = Dict(TxCoinbase => "Coinbase",
                         TxCoinbasePost => "CoinbasePost",
                         TxTransferencia => "Transferencia",
                         TxDeposito => "Deposito", TxRetiro => "Retiro",
                         TxLiberacion => "Liberacion", TxEvidencia => "Evidencia",
                         TxAltaSector => "AltaSector",
                         TxPruebaSector => "PruebaSector")

# --- utilidades ------------------------------------------------------------

function parsear(args::Vector{String})
    cfg = Dict{String,String}()
    i = 1
    while i <= length(args)
        a = args[i]
        if startswith(a, "--")
            clave = a[3:end]
            if occursin("=", clave)
                k, v = split(clave, "=", limit = 2)
                cfg[k] = v
            else
                i += 1
                i <= length(args) || error("falta valor para --$clave")
                cfg[clave] = args[i]
            end
        end
        i += 1
    end
    return cfg
end

function fecha_por_defecto()
    try
        return strip(read(`date -Is`, String))
    catch
        return string(time())
    end
end

sha256_archivo(path::AbstractString) = bytes2hex(sha256(read(path)))

# --- render del formato (idéntico a ORDEN-T01-B §3.4) ----------------------

param_str(P::Params) = string(
    "PARAM H_dep=", P.H_dep, " M_cb=", P.M_cb, " M_dep=", P.M_dep,
    " H_corte_min=", P.H_corte_min, " W_min=", P.W_min, " S_min=", P.S_min,
    " K_min=", P.K_min, " q=", P.q, " M_res_slots=", P.M_res_slots,
    " M_dep_slots=", P.M_dep_slots, " M_rec_slots=", P.M_rec_slots,
    " R_slots=", P.R_slots, " F_slots=",
    P.F_slots == typemax(Int) ? "inf" : string(P.F_slots))

bloque_str(b::Bloque) = string(
    "BLOQUE id=", b.id, " fam=", NOMBRE_FAMILIA[b.familia], " padre=", b.padre,
    " altura=", b.altura, " trabajo=", b.trabajo,
    " pow_ok=", b.pow_ok ? 1 : 0, " slot=", b.slot, " prod=", b.productor,
    " peso=", b.peso, " reqdecl=", b.requisito_declarado, " ntx=", length(b.txs))

function tx_str(tx::Tx)
    ent = join(string.(tx.entradas), ",")
    sal = join(["$(s.id):$(s.valor):$(s.dueño)" for s in tx.salidas], ",")
    return string("TX tipo=", NOMBRE_TIPO[tx.tipo], " firmante=", tx.firmante,
                  " clave=", tx.clave, " importe=", tx.importe,
                  " ent=[", ent, "] sal=[", sal, "]")
end

function utxo_str(E::Estado)
    salidas = collect(values(E.utxo))
    sort!(salidas, by = o -> (o.dueño, o.valor, ORDEN_ORIGEN[o.origen],
                              o.creada_en_altura, o.creada_en_slot))
    return [string("UTXO dueño=", o.dueño, " valor=", o.valor, " origen=",
                   NOMBRE_ORIGEN[o.origen], " altura=",
                   o.creada_en_altura == -1 ? "-" : string(o.creada_en_altura),
                   " slot=",
                   o.creada_en_slot == -1 ? "-" : string(o.creada_en_slot))
            for o in salidas]
end

function gar_str(E::Estado)
    lineas = String[]
    for k in sort(collect(keys(E.garantias)))
        g = E.garantias[k]
        pend = sort(g.pendientes, by = p -> (p.importe, p.madura_en_altura,
                                             p.madura_en_slot))
        ps = join([p.madura_en_altura != -1 ?
                   "$(p.importe)@h$(p.madura_en_altura)" :
                   "$(p.importe)@s$(p.madura_en_slot)" for p in pend], ",")
        ret = sort(g.en_retirada, by = r -> (r.inicio_slot, r.importe))
        rs = join(["$(r.importe)@s$(r.inicio_slot)" for r in ret], ",")
        cred = sort(g.creditos, by = p -> (p.importe, p.madura_en_slot))
        cs = join(["$(p.importe)@s$(p.madura_en_slot)" for p in cred], ",")
        push!(lineas, string("GAR clave=", k, " activo=", g.activo,
                             " pend=[", ps, "] ret=[", rs, "] cred=[", cs,
                             "] congelado=", g.congelado))
    end
    return lineas
end

estado_str(E::Estado) = string(
    "EST emitido=", E.emitido, " quemado=", E.quemado,
    " fase=", NOMBRE_FASE[E.fase], " terminal=", E.terminal,
    " altura=", E.altura, " slot=", E.slot, " peso_sufijo=", E.peso_sufijo)

# Validez contextual releíble de cada bloque sobre el estado de su padre.
function res_por_bloque(bloques::Vector{Bloque}, P::Params)
    memo, por_id = construir_validos(bloques, P)
    res = Dict{Int,String}()
    for b in bloques
        if haskey(memo, b.id)
            res[b.id] = "OK"
        else
            p = get(por_id, b.padre, nothing)
            if p === nothing || !haskey(memo, b.padre)
                res[b.id] = "ErrSinPadre"
            else
                r = aplicar(memo[b.padre], b, P)
                res[b.id] = r isa Err ? string(r) : "OK"
            end
        end
    end
    return res
end

function escribir_caso(io::IO, n::Int, nombre::AbstractString, punto::Int,
                       semilla::AbstractString, bloques::Vector{Bloque},
                       P::Params)
    println(io, "CASO n=", n, " nombre=", nombre, " punto=", punto,
            " semilla=", semilla)
    println(io, param_str(P))
    resmap = res_por_bloque(bloques, P)
    for b in bloques
        println(io, bloque_str(b))
        for tx in b.txs
            println(io, tx_str(tx))
        end
        println(io, "RES bloque=", b.id, " res=", resmap[b.id])
    end
    sel = seleccionar(bloques, P)
    println(io, "SEL punta=", sel.punta)
    for l in utxo_str(sel.estado)
        println(io, l)
    end
    for l in gar_str(sel.estado)
        println(io, l)
    end
    println(io, estado_str(sel.estado))
    println(io, "FIN")
    return nothing
end

# --- main ------------------------------------------------------------------

function main()
    cfg = parsear(ARGS)
    fecha = get(cfg, "fecha", fecha_por_defecto())
    salida = get(cfg, "salida", SALIDA_DEF)
    contrato = get(cfg, "contrato", CONTRATO_DEF)
    idxs, puntos = puntos_negativos()

    @printf("exportar-negativos: puntos=%s salida=%s\n", string(idxs), salida)
    flush(stdout)

    mkpath(dirname(salida))
    parcial = salida * ".tmp"
    io = open(parcial, "w")
    println(io, "# vectores-transicion-negativos-v0 · T01-C · ", fecha,
            " · sha256 del contrato ", sha256_archivo(contrato))
    n = 0
    inesperados = 0
    conteo_err = Dict{String,Int}()
    conteo_fam = Dict{String,Int}()
    conteo_fase = Dict{String,Int}()
    porsub = Dict{String,Dict{String,Int}}()
    for i in idxs
        P = puntos[i]
        for c in casos_negativos(P)
            resmap = res_por_bloque(c.bloques, P)
            got = resmap[last(c.bloques).id]
            if got != string(c.esperado)
                inesperados += 1
                @printf(stderr,
                        "INESPERADO punto=%d nombre=%s esperado=%s obtenido=%s\n",
                        i, c.nombre, string(c.esperado), got)
                continue
            end
            n += 1
            escribir_caso(io, n, c.nombre, i, "-", c.bloques, P)
            e = string(c.esperado)
            conteo_err[e] = get(conteo_err, e, 0) + 1
            conteo_fam[c.familia] = get(conteo_fam, c.familia, 0) + 1
            conteo_fase[c.fase] = get(conteo_fase, c.fase, 0) + 1
            d = get!(porsub, c.nombre, Dict{String,Int}())
            d[e] = get(d, e, 0) + 1
        end
    end
    close(io)

    if inesperados > 0
        rm(parcial; force = true)
        @printf(stderr, "exportar-negativos: ABORTA, inesperados=%d\n",
                inesperados)
        exit(1)
    end
    mv(parcial, salida; force = true)

    h = sha256_archivo(salida)
    sha_path = replace(salida, r"\.txt$" => "") * ".sha256"
    write(sha_path, h * "  " * salida * "\n")

    @printf("exportar-negativos: casos=%d inesperados=%d\n", n, inesperados)
    @printf("exportar-negativos: sha256=%s -> %s\n", h, sha_path)
    println("RECUENTO POR ERROR")
    errores = ["ErrSaldo", "ErrDobleGasto", "ErrRetiroPendiente",
               "ErrAutorizacion", "ErrInmaduro", "ErrEmision",
               "ErrOperacionFase", "ErrGarantia"]
    for e in errores
        @printf("  %-22s = %d\n", e, get(conteo_err, e, 0))
    end
    println("RECUENTO POR FAMILIA")
    for f in ["Saldo", "DobleGasto", "RetiroPendiente", "Autorizacion",
              "Inmaduro", "Garantia", "Emision", "OperacionFase"]
        @printf("  %-22s = %d\n", f, get(conteo_fam, f, 0))
    end
    println("RECUENTO POR FASE")
    for f in ["PoW", "PoST"]
        @printf("  %-22s = %d\n", f, get(conteo_fase, f, 0))
    end
    println("RECUENTO POR SUBCASO (nombre -> error:cuenta)")
    for k in sort(collect(keys(porsub)))
        partes = sort(["$e:$v" for (e, v) in porsub[k]])
        @printf("  %-44s %s\n", k, join(partes, " "))
    end
    flush(stdout)
end

main()
