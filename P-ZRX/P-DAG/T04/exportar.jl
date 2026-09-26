# exportar.jl — exportador determinista de vectores de estado DAG (ORDEN-T04 §4).
#
#     julia --project=. exportar.jl [--fecha ISO-8601] [--salida RUTA] \
#         [--contrato RUTA] [--dirigidos 1] [--aleatorios 600]
#
# Escribe `resultados/vectores-estado-dag-v0.txt` (formato de T01-B ampliado con
# `padres=[…]` y líneas `DESC`) y su `sha256` en el `.sha256`. Solo interfaces por
# defecto (CUT_HWPhi, FC3, SEC0) y la rejilla declarada de T04. Un hilo, sin Python.
#
# El lector independiente vive en `src/lector_vectores.jl` y NO reutiliza ninguna
# función de este fichero.

using EstadoDAG
using EstadoDAG.Transicion
using StableRNGs
using SHA
using Printf

const CONTRATO_DEF = "/home/katana/zeo/ZEROX/P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md"
const SALIDA_DEF = "resultados/vectores-estado-dag-v0.txt"

const NOMBRE_FAMILIA = Dict(Transicion.Genesis => "Genesis", Transicion.PoW => "PoW",
                            Transicion.PoST => "PoST")
const NOMBRE_FASE = Dict(Transicion.FaseGenesis => "FaseGenesis",
                         Transicion.FasePoW => "FasePoW",
                         Transicion.FasePoST => "FasePoST")
const NOMBRE_ORIGEN = Dict(Transicion.OrigenCoinbasePow => "CoinbasePow",
                           Transicion.OrigenTx => "Tx",
                           Transicion.OrigenLiberacion => "Liberacion")
const ORDEN_ORIGEN = Dict(Transicion.OrigenCoinbasePow => 0, Transicion.OrigenTx => 1,
                          Transicion.OrigenLiberacion => 2)
const NOMBRE_TIPO = Dict(Transicion.TxCoinbase => "Coinbase",
                         Transicion.TxCoinbasePost => "CoinbasePost",
                         Transicion.TxTransferencia => "Transferencia",
                         Transicion.TxDeposito => "Deposito",
                         Transicion.TxRetiro => "Retiro",
                         Transicion.TxLiberacion => "Liberacion",
                         Transicion.TxEvidencia => "Evidencia",
                         Transicion.TxAltaSector => "AltaSector",
                         Transicion.TxPruebaSector => "PruebaSector")

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

fecha_por_defecto() = try
    strip(read(`date -Is`, String))
catch
    string(time())
end

sha256_archivo(path::AbstractString) = bytes2hex(sha256(read(path)))

# --- render -----------------------------------------------------------------

param_str(pd::ParamsDAG) = begin
    P = pd.P
    string("PARAM H_dep=", P.H_dep, " M_cb=", P.M_cb, " M_dep=", P.M_dep,
           " H_corte_min=", P.H_corte_min, " W_min=", P.W_min, " S_min=", P.S_min,
           " K_min=", P.K_min, " q=", P.q, " M_res_slots=", P.M_res_slots,
           " M_dep_slots=", P.M_dep_slots, " M_rec_slots=", P.M_rec_slots,
           " R_slots=", P.R_slots, " F_slots=",
           P.F_slots == typemax(Int) ? "inf" : string(P.F_slots),
           " k=", pd.k, " sec=SEC0 corte=CUT_HWPhi seleccion=FC3")
end

function tx_str(tx::Transicion.Tx)
    ent = join(string.(tx.entradas), ",")
    sal = join(["$(s.id):$(s.valor):$(s.dueño)" for s in tx.salidas], ",")
    string("TX tipo=", NOMBRE_TIPO[tx.tipo], " firmante=", tx.firmante,
           " clave=", tx.clave, " importe=", tx.importe, " ent=[", ent,
           "] sal=[", sal, "]")
end

function bloque_pow_str(b::Transicion.Bloque)
    return string("BLOQUE id=", b.id, " fam=", NOMBRE_FAMILIA[b.familia],
                  " padres=[", b.padre == 0 ? "" : string(b.padre), "]",
                  " altura=", b.altura, " trabajo=", b.trabajo,
                  " pow_ok=", b.pow_ok ? 1 : 0, " slot=0 prod=0 peso=0 sr=0 sd=0",
                  " ident=0 reqdecl=0 ntx=", length(b.txs))
end

bloque_post_str(b::BloquePost) =
    string("BLOQUE id=", b.id, " fam=PoST padres=[", join(string.(b.padres), ","),
           "] altura=0 trabajo=0 pow_ok=1 slot=", b.slot, " prod=", b.productor,
           " peso=", b.peso, " sr=", b.sr, " sd=", b.sd, " ident=", b.ident,
           " reqdecl=0 ntx=", length(b.txs))

function utxo_str(E::Transicion.Estado)
    salidas = collect(values(E.utxo))
    sort!(salidas, by = o -> (o.dueño, o.valor, ORDEN_ORIGEN[o.origen],
                              o.creada_en_altura, o.creada_en_slot))
    return [string("UTXO dueño=", o.dueño, " valor=", o.valor, " origen=",
                   NOMBRE_ORIGEN[o.origen], " altura=",
                   o.creada_en_altura == -1 ? "-" : string(o.creada_en_altura),
                   " slot=", o.creada_en_slot == -1 ? "-" : string(o.creada_en_slot))
            for o in salidas]
end

function gar_str(E::Transicion.Estado)
    ls = String[]
    for k in sort(collect(keys(E.garantias)))
        g = E.garantias[k]
        pend = sort(g.pendientes, by = p -> (p.importe, p.madura_en_altura, p.madura_en_slot))
        ps = join([p.madura_en_altura != -1 ? "$(p.importe)@h$(p.madura_en_altura)" :
                   "$(p.importe)@s$(p.madura_en_slot)" for p in pend], ",")
        ret = sort(g.en_retirada, by = r -> (r.inicio_slot, r.importe))
        rs = join(["$(r.importe)@s$(r.inicio_slot)" for r in ret], ",")
        cred = sort(g.creditos, by = p -> (p.importe, p.madura_en_slot))
        cs = join(["$(p.importe)@s$(p.madura_en_slot)" for p in cred], ",")
        push!(ls, string("GAR clave=", k, " activo=", g.activo, " pend=[", ps,
                         "] ret=[", rs, "] cred=[", cs, "] congelado=", g.congelado))
    end
    return ls
end

est_str(E::Transicion.Estado) =
    string("EST emitido=", E.emitido, " quemado=", E.quemado, " fase=",
           NOMBRE_FASE[E.fase], " terminal=", E.terminal, " altura=", E.altura,
           " slot=", E.slot, " peso_sufijo=", E.peso_sufijo)

# --- escritura de un caso ---------------------------------------------------

function escribir_caso(io::IO, n::Int, nombre::AbstractString, punto::Int,
                       k::Int, semilla::AbstractString, A::Admision)
    pd = A.pd
    println(io, "CASO n=", n, " nombre=", nombre, " punto=", punto, " k=", k,
            " semilla=", semilla)
    println(io, param_str(pd))
    for b in A.pow_bloques
        println(io, bloque_pow_str(b))
        for tx in b.txs
            println(io, tx_str(tx))
        end
        println(io, "RES bloque=", b.id, " res=OK")
    end
    for b in sort(collect(values(A.por_id)), by = x -> x.id)
        println(io, bloque_post_str(b))
        for tx in b.txs
            println(io, tx_str(tx))
        end
        res = get(A.validos, b.id, false) ? "OK" : string(get(A.motivos, b.id, :ErrSinPadre))
        println(io, "RES bloque=", b.id, " res=", res)
    end
    S, _, desc = aplicar_historia(A)
    for (idb, itx, err) in desc
        println(io, "DESC bloque=", idb, " tx=", itx, " motivo=", err)
    end
    tips = tips_validas(A)
    sp = isempty(tips) ? -1 : mejor_punta(A, tips)
    println(io, "SEL punta=", sp)
    for l in utxo_str(S)
        println(io, l)
    end
    for l in gar_str(S)
        println(io, l)
    end
    println(io, est_str(S))
    println(io, "FIN")
    return nothing
end

# --- main -------------------------------------------------------------------

function main()
    cfg = parsear(ARGS)
    fecha = get(cfg, "fecha", fecha_por_defecto())
    salida = get(cfg, "salida", SALIDA_DEF)
    contrato = get(cfg, "contrato", CONTRATO_DEF)
    con_dirigidos = get(cfg, "dirigidos", "1") != "0"
    n_aleatorios = parse(Int, get(cfg, "aleatorios", "600"))

    puntos = PUNTOS_T04
    @printf("exportar: puntos=%d aleatorios=%d salida=%s\n", length(puntos),
            n_aleatorios, salida)
    flush(stdout)
    mkpath(dirname(salida))
    io = open(salida, "w")
    println(io, "# vectores-estado-dag-v0 · T04 · ", fecha,
            " · sha256 del contrato ", sha256_archivo(contrato))
    n = 0
    if con_dirigidos
        pd = ParamsDAG(PARAMS_DAG_BASE[1], 1)
        for (nombre, A, _) in casos_dirigidos(pd)
            n += 1
            escribir_caso(io, n, nombre, 1, 1, "-", A)
        end
    end
    N = length(puntos)
    for r in 1:n_aleatorios
        idx = N == 1 ? 1 : 1 + round(Int, (r - 1) * (N - 1) / (n_aleatorios - 1))
        (pi, k) = puntos[idx]
        pd = ParamsDAG(PARAMS_DAG_BASE[pi], k)
        semilla = UInt64(0x5a5a) + UInt64(r)
        rng = StableRNG(semilla)
        A = generar_dag_aleatorio(rng, pd; npost = 3 + (r % 12))
        n += 1
        escribir_caso(io, n, "aleatorio", pi, k, string(semilla), A)
        (r % 100 == 0) && (@printf("  aleatorios %d/%d\n", r, n_aleatorios); flush(stdout))
    end
    close(io)
    h = sha256_archivo(salida)
    sha_path = replace(salida, r"\.txt$" => "") * ".sha256"
    write(sha_path, h * "\n")
    @printf("exportar: casos=%d sha256=%s -> %s\n", n, h, sha_path)
    flush(stdout)
end

main()
