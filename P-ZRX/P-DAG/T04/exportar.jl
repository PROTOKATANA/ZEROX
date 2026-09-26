# exportar.jl — exportador determinista de vectores de estado DAG (ORDEN-T04 §4).
#
#     julia --project=. exportar.jl [--fecha ISO-8601] [--salida RUTA] \
#         [--contrato RUTA] [--dirigidos 1] [--aleatorios 900] [--cobertura RUTA]
#
# Escribe `resultados/vectores-estado-dag-v0.5.txt` (formato de T01-B ampliado con
# `padres=[…]`, líneas `DESC` y `nonce=` en depósito/retiro/liberación y `GAR`) y su
# `sha256` en el `.sha256` (formato `sha256sum`). Además escribe
# `resultados/cobertura-v0.5.txt` (apartados vectores y run.jl) con la tabla de
# cobertura por tipo de operación de la ORDEN-T04-C §2. Solo interfaces por defecto
# (CUT_HWPhi, FC3, SEC0) y la rejilla declarada de T04. Un hilo, sin Python.
#
# El lector independiente vive en `src/lector_vectores.jl` y NO reutiliza ninguna
# función de este fichero.

using EstadoDAG
using EstadoDAG.Transicion
using StableRNGs
using SHA
using Printf

const CONTRATO_DEF = "/home/katana/zeo/ZEROX/P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md"
# SL-3b: vectores v0.5 con EvidenceTx (RAT-2′) y cobertura de sin_saldo/reorg;
# v0..v0.4 se conservan.
const SALIDA_DEF = "resultados/vectores-estado-dag-v0.5.txt"
const COBERTURA_DEF = "resultados/cobertura-v0.5.txt"

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
           " f_num=", P.f_num, " f_den=", P.f_den, " Plazo_slots=", P.Plazo_slots,
           " M_margen_slots=", P.M_margen_slots, " cbid=", P.cbid,
           " evp=", P.evp ? 1 : 0,
           " k=", pd.k, " sec=SEC0 corte=CUT_HWPhi seleccion=FC3")
end

# SL-3: cabeceras de evidencia.
function ev_str(ev::Transicion.Evidencia)
    return string(ev.id1.cbid, ":", ev.id1.clave, ":", ev.id1.sector, ":",
                  ev.id1.historia, ":", ev.id1.chunk, ":", ev.id1.slot, ":",
                  ev.h1.pre_hash, ":", ev.h1.sello_ok ? 1 : 0, "|",
                  ev.id2.cbid, ":", ev.id2.clave, ":", ev.id2.sector, ":",
                  ev.id2.historia, ":", ev.id2.chunk, ":", ev.id2.slot, ":",
                  ev.h2.pre_hash, ":", ev.h2.sello_ok ? 1 : 0)
end

# T04-B: `nonce=` al final de la línea en depósito, retiro y liberación (F-15),
# siguiendo la convención de T01-D (D/AMBIGUEDAD-6).
function tx_str(tx::Transicion.Tx)
    ent = join(string.(tx.entradas), ",")
    sal = join(["$(s.id):$(s.valor):$(s.dueño)" for s in tx.salidas], ",")
    base = string("TX tipo=", NOMBRE_TIPO[tx.tipo], " firmante=", tx.firmante,
                  " clave=", tx.clave, " importe=", tx.importe, " ent=[", ent,
                  "] sal=[", sal, "]")
    if tx.tipo in (Transicion.TxDeposito, Transicion.TxRetiro, Transicion.TxLiberacion)
        return base * " nonce=" * string(tx.nonce)
    end
    if tx.tipo == Transicion.TxEvidencia && tx.evidencia !== nothing
        return base * " ev=" * ev_str(tx.evidencia)
    end
    return base
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
        inc = sort(g.incidentes, by = x -> x[1])
        is_ = isempty(inc) ? "" :
              string(" inc=", join(["$(iid)@$(sf)" for (iid, sf) in inc], ","))
        push!(ls, string("GAR clave=", k, " activo=", g.activo, " pend=[", ps,
                         "] ret=[", rs, "] cred=[", cs, "] congelado=", g.congelado,
                         " nonce=", g.nonce_siguiente, is_))
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

# --- SL-3: cobertura de evidencia en el DAG ---------------------------------

inc!(d::Dict{String,Int}, k::AbstractString) = (d[k] = get(d, k, 0) + 1)

"""
Clasifica las `EvidenceTx` de `A` por su resultado en la historia seleccionada y
acumula los contadores. Definición de cada contador (se copia a
`cobertura-v0.5.txt`):

 * `construida`   — EvidenceTx presente en la historia de aplicación seleccionada.
 * `aplicada`     — se aplica sin descarte al aplicarse su bloque.
 * `sin_saldo`    — aplicada con `V = 0` en su clave (EV-22): pérdida 0, incidente
                    registrado; se mide contra el estado `past(bloque)`.
 * `duplicada`    — descartada por `ErrEvidenciaDuplicada` (EV-12).
 * `tardia`       — descartada por `ErrEvidenciaTardia` (EV-14).
 * `cbid_ajeno`   — descartada por `ErrCbidAjeno` (RAT-1).
 * `con_entradas` — descartada por `ErrEvidenciaConEntradas` (EV-04).
 * `orden_canonico` / `sin_evidencia` / `otro` — resto de descartes.
 * `deshecha`     — aplicada en la historia seleccionada en algún momento y luego
                    retirada por una reorganización (EV-27/EV-28). No cuenta el
                    undo exacto de un bloque que sigue en la cadena seleccionada.
"""
function contar_evidencia(A::Admision, acc::Dict{String,Int})
    _, orden, desc = aplicar_historia(A)
    dm = Dict{Tuple{Int,Int},Transicion.Err}()
    for (idb, itx, e) in desc
        dm[(idb, itx)] = e
    end
    for bid in orden
        b = A.por_id[bid]
        for (i, tx) in enumerate(b.txs)
            tx.tipo == Transicion.TxEvidencia || continue
            inc!(acc, "construida")
            e = get(dm, (bid, i), nothing)
            if e === nothing
                ev = tx.evidencia
                if ev === nothing
                    inc!(acc, "malformada")
                    continue
                end
                g = get(A.past[bid].garantias, ev.id1.clave, nothing)
                V = g === nothing ? Int128(0) : Transicion.total_garantia(g)
                inc!(acc, V == 0 ? "sin_saldo" : "aplicada")
            else
                k = e == Transicion.ErrEvidenciaDuplicada ? "duplicada" :
                    e == Transicion.ErrEvidenciaTardia    ? "tardia" :
                    e == Transicion.ErrCbidAjeno          ? "cbid_ajeno" :
                    e == Transicion.ErrEvidenciaConEntradas ? "con_entradas" :
                    e == Transicion.ErrOrdenCanonico      ? "orden_canonico" :
                    e == Transicion.ErrSinEvidencia       ? "sin_evidencia" : "otro"
                inc!(acc, k)
            end
        end
    end
    n_deshechas = length(EstadoDAG.evidencias_deshechas_por_reorg(A))
    n_deshechas > 0 && (acc["deshecha"] = get(acc, "deshecha", 0) + n_deshechas)
    return acc
end

# --- main -------------------------------------------------------------------

function main()
    cfg = parsear(ARGS)
    fecha = get(cfg, "fecha", fecha_por_defecto())
    salida = get(cfg, "salida", SALIDA_DEF)
    cobertura = get(cfg, "cobertura", COBERTURA_DEF)
    contrato = get(cfg, "contrato", CONTRATO_DEF)
    con_dirigidos = get(cfg, "dirigidos", "1") != "0"
    n_aleatorios = parse(Int, get(cfg, "aleatorios", "900"))
    n_ev = parse(Int, get(cfg, "ev-replicas", "60"))

    puntos = PUNTOS_T04
    @printf("exportar: puntos=%d aleatorios=%d ev-replicas=%d salida=%s\n",
            length(puntos), n_aleatorios, n_ev, salida)
    flush(stdout)
    mkpath(dirname(salida))
    io = open(salida, "w")
    println(io, "# vectores-estado-dag-v0.5 · T04-SL3b (EvidenceTx, RAT-2′) · ",
            fecha, " · sha256 del contrato ", sha256_archivo(contrato))
    n = 0
    aev = Dict{String,Int}()
    if con_dirigidos
        pd = ParamsDAG(PARAMS_DAG_BASE[1], 1)
        for (nombre, A, _) in casos_dirigidos(pd)
            n += 1
            escribir_caso(io, n, nombre, 1, 1, "-", A)
            startswith(nombre, "D-1") && contar_evidencia(A, aev)
        end
    end
    ac = EstadoDAG.AcumuladorCobertura()
    N = length(puntos)
    for r in 1:n_aleatorios
        idx = N == 1 ? 1 : 1 + round(Int, (r - 1) * (N - 1) / (n_aleatorios - 1))
        (pi, k) = puntos[idx]
        pd = ParamsDAG(PARAMS_DAG_BASE[pi], k)
        semilla = UInt64(0x5a5a) + UInt64(r)
        rng = StableRNG(semilla)
        A = EstadoDAG.generar_dag_aleatorio(rng, pd; npost = EstadoDAG.npost_t04c(r),
                                            pesos = EstadoDAG.PESOS_AJUSTADOS)
        n += 1
        escribir_caso(io, n, "aleatorio", pi, k, string(semilla), A)
        EstadoDAG.acumular_caso!(ac, A)
        (r % 100 == 0) && (@printf("  aleatorios %d/%d\n", r, n_aleatorios); flush(stdout))
    end
    # SL-3: evidencias sobre la rejilla con C-EVP activo.
    for (i, pdev) in enumerate(PARAMS_DAG_EV)
        for r in 1:n_ev
            semilla = UInt64(0x6000) + UInt64(100 * i + r)
            rng = StableRNG(semilla)
            A = EstadoDAG.generar_dag_aleatorio(rng, pdev; npost = EstadoDAG.npost_t04c(r),
                                                pesos = EstadoDAG.PESOS_AJUSTADOS)
            n += 1
            escribir_caso(io, n, "ev-aleatorio", i, Int(pdev.k), string(semilla), A)
            contar_evidencia(A, aev)
        end
        @printf("  evidencia punto %d/%d\n", i, length(PARAMS_DAG_EV))
        flush(stdout)
    end
    close(io)
    h = sha256_archivo(salida)
    sha_path = replace(salida, r"\.txt$" => "") * ".sha256"
    write(sha_path, h * "  " * salida * "\n")   # formato `sha256sum` (T04-B)
    @printf("exportar: casos=%d sha256=%s -> %s\n", n, h, sha_path)
    # Cobertura (ORDEN-T04-C §2): apartado vectores y apartado run.jl.
    mkpath(dirname(cobertura))
    ioc = open(cobertura, "w")
    println(ioc, "# cobertura T04-SL3b v0.5 · ", fecha, " · contrato ",
            sha256_archivo(contrato))
    println(ioc, "# definiciones de los contadores de evidencia (sec. evidencia):")
    println(ioc, "#  construida   = EvidenceTx presente en la historia de aplicación seleccionada")
    println(ioc, "#  aplicada     = se aplica sin descarte al aplicarse su bloque")
    println(ioc, "#  sin_saldo    = aplicada con V=0 en su clave (EV-22, pérdida 0, incidente registrado)")
    println(ioc, "#  duplicada    = descartada por ErrEvidenciaDuplicada (EV-12)")
    println(ioc, "#  tardia       = descartada por ErrEvidenciaTardia (EV-14)")
    println(ioc, "#  cbid_ajeno   = descartada por ErrCbidAjeno (RAT-1)")
    println(ioc, "#  con_entradas = descartada por ErrEvidenciaConEntradas (EV-04)")
    println(ioc, "#  deshecha     = aplicada en la historia seleccionada en algún momento y luego")
    println(ioc, "#                 retirada por una reorganización (EV-27/EV-28); no cuenta el undo")
    println(ioc, "#                 exacto de un bloque que sigue en la cadena seleccionada")
    println(ioc, "# generador: pesos=", EstadoDAG.PESOS_AJUSTADOS,
            " npost=", min(EstadoDAG.npost_t04c(0), EstadoDAG.npost_t04c(1)), "..",
            max(EstadoDAG.npost_t04c(0), EstadoDAG.npost_t04c(1)),
            " p_tx=0.5 p_invalido=0.12 p_error_nonce=0.10 p_ev=0.12")
    println(ioc, "# minimos: depositos_aplicados>=150 retiros_aplicados>=100 ",
            "liberaciones_aplicadas>=100 ErrNonce>=30 y <=25% de garantia ",
            "construida ErrDobleGasto>=200 reorgs_garantia>=20")
    EstadoDAG.escribir_cobertura(ioc, "vectores-v0.5 (casos aleatorios)", ac)
    println(ioc, "SECCION evidencia SL-3b (dirigidos + aleatorios C-EVP)")
    for k in sort(collect(keys(aev)))
        println(ioc, "EV ", k, " = ", aev[k])
    end
    acr = EstadoDAG.cobertura_run()
    EstadoDAG.escribir_cobertura(ioc, "run.jl (seed 0x5a5a, replicas 200)", acr)
    close(ioc)
    @printf("exportar: cobertura -> %s evidencia=%s\n", cobertura, string(aev))
    flush(stdout)
end

main()
