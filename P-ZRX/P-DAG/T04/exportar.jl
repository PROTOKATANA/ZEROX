# exportar.jl — exportador determinista de vectores de estado DAG (ORDEN-T04 §4).
#
#     julia --project=. exportar.jl [--fecha ISO-8601] [--salida RUTA] \
#         [--contrato RUTA] [--dirigidos 1] [--aleatorios 900] [--cobertura RUTA]
#
# Escribe `resultados/vectores-estado-dag-v0.6.txt` (formato de T01-B ampliado con
# `padres=[…]`, líneas `DESC` y `nonce=` en depósito/retiro/liberación y `GAR`) y su
# `sha256` en el `.sha256` (formato `sha256sum`). Además escribe
# `resultados/cobertura-v0.6.txt` (apartados vectores, forma SL-4c-O y run.jl) con
# la tabla de cobertura por tipo de operación de la ORDEN-T04-C §2. Solo interfaces
# por defecto (CUT_HWPhi, FC3, SEC0) y la rejilla declarada de T04. Un hilo, sin
# Python.
#
# SL-4c-O: v0.6 mueve `cbid` ajeno y orden no canónico de la `EvidenceTx` a la
# forma (bloque inválido, no descarte) y añade casos dedicados de cobertura.
# SL-4c-O-B: precedencia por transacción (estructura → cbid → orden, primera
# transacción defectuosa) y cobertura de los dos tipos de orden no canónico
# (igualdad `H1 = H2` y descendente `pre_hash(H1) > pre_hash(H2)`).
# SL-4c-O-C: la estructura de EV-04 (entradas/salidas; `testigos`/`n_wit` no
# existe en el modelo `Tx` de T01) también es forma y precede a cbid/orden.
#
# El lector independiente vive en `src/lector_vectores.jl` y NO reutiliza ninguna
# función de este fichero.

using EstadoDAG
using EstadoDAG.Transicion
using StableRNGs
using SHA
using Printf

const CONTRATO_DEF = "/home/katana/zeo/ZEROX/P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md"
# SL-4c-O: vectores v0.6 con la forma v4 (cbid/orden) y cobertura dedicada;
# v0…v0.5 se conservan.
const SALIDA_DEF = "resultados/vectores-estado-dag-v0.6.txt"
const COBERTURA_DEF = "resultados/cobertura-v0.6.txt"

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
`cobertura-v0.6.txt`):

 * `construida`   — EvidenceTx presente en la historia de aplicación seleccionada.
 * `aplicada`     — se aplica sin descarte al aplicarse su bloque.
 * `sin_saldo`    — aplicada con `V = 0` en su clave (EV-22): pérdida 0, incidente
                    registrado; se mide contra el estado `past(bloque)`.
 * `duplicada`    — descartada por `ErrEvidenciaDuplicada` (EV-12).
 * `tardia`       — descartada por `ErrEvidenciaTardia` (EV-14).
 * `con_entradas` — obsoleto desde SL-4c-O-C: la estructura de EV-04
                    (entradas/salidas) ya no es un descarte semántico al fusionar,
                    sino forma que invalida el bloque; se cuenta en
                    `contar_forma_evidencia`.
 * `sin_evidencia`/`otro` — resto de descartes semánticos.
 * `deshecha`     — aplicada en la historia seleccionada en algún momento y luego
                    retirada por una reorganización (EV-27/EV-28). No cuenta el
                    undo exacto de un bloque que sigue en la cadena seleccionada.

SL-4c-O: `cbid` ajeno y orden no canónico ya no son descartes semánticos (no
aparecen aquí); se cuentan en `contar_forma_evidencia`.
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
                    e == Transicion.ErrSinEvidencia       ? "sin_evidencia" : "otro"
                inc!(acc, k)
            end
        end
    end
    n_deshechas = length(EstadoDAG.evidencias_deshechas_por_reorg(A))
    n_deshechas > 0 && (acc["deshecha"] = get(acc, "deshecha", 0) + n_deshechas)
    return acc
end

"""
Cobertura de la **forma v4** de la `EvidenceTx` (SL-4c-O / SL-4c-O-B / SL-4c-O-C).
Recorre todos los bloques construidos (válidos o no) y clasifica los que la
comprobación de forma marca como inválidos:

 * `bloque_estructura` — bloque inválido con motivo
                  `ErrForma(EvidenciaConEntradasOSalidas)` (EV-04); se desglosa
                  según el **primer** sub-defecto estructural:
                  `bloque_estructura_entradas`, `_salidas` y `_ambos`
                  (`n_in ≠ 0` y `n_out ≠ 0` a la vez). `bloque_estructura_cbid_orden`
                  cuenta los que además llevan `cbid` ajeno y orden no canónico
                  (los tres defectos de la precedencia; gana la estructura).
 * `bloque_cbid`  — bloque inválido con motivo `ErrForma(EvidenciaCbidAjeno)`.
 * `bloque_orden` — bloque inválido con motivo `ErrForma(OrdenCanonicoInvalido)`;
                  se desglosa según el **primer** defecto de orden:
                  `bloque_orden_igual` (`H1 = H2`) y `bloque_orden_desc`
                  (`pre_hash(H1) > pre_hash(H2)`).
 * `ev_estructura` — `EvidenceTx` con algún sub-defecto estructural.
 * `ev_cbid` / `ev_orden` — `EvidenceTx` con cada defecto dentro de esos bloques;
                  `ev_orden_igual` / `ev_orden_desc` desglosan el orden.
 * `ambos_cbid`   — bloque con los dos defectos a la vez; gana el primero en el
                  orden de las transacciones (precedencia por transacción).
 * `con_tx_estructura` / `con_tx_cbid` / `con_tx_orden` — bloque inválido por ese
                    defecto que **además** contiene al menos una transacción
                    monetaria no-coinbase (transferencia/depósito/retiro/
                    liberación), para demostrar que la invalidez alcanza al bloque
                    entero.

`testigos`/`n_wit` no existe en el modelo `Tx` de T01, así que EV-04 solo puede
manifestarse aquí por `entradas`/`salidas` (declarado en SL-4c-O-C).
"""
function contar_forma_evidencia(A::Admision, acc::Dict{String,Int})
    cbid_red = A.pd.P.cbid
    for (id, b) in A.por_id
        motivo = get(A.motivos, id, :OK)
        (motivo == MOTIVO_FORMA_ESTRUCTURA || motivo == MOTIVO_FORMA_CBID ||
         motivo == MOTIVO_FORMA_ORDEN) || continue
        hay_tx = any(tx -> tx.tipo in (Transicion.TxTransferencia, Transicion.TxDeposito,
                                       Transicion.TxRetiro, Transicion.TxLiberacion),
                     b.txs)
        n_cbid = 0
        n_orden = 0
        n_ig = 0
        n_de = 0
        n_ent = 0
        n_sal = 0
        n_amb = 0
        n_tres = 0
        for tx in b.txs
            tx.tipo == Transicion.TxEvidencia || continue
            ev = tx.evidencia
            ev === nothing && continue
            c_ent = !isempty(tx.entradas)
            c_sal = !isempty(tx.salidas)
            c_cbid = ev.id1.cbid != cbid_red || ev.id2.cbid != cbid_red
            c_orden = !(ev.h1.pre_hash < ev.h2.pre_hash)
            c_ent && (n_ent += 1)
            c_sal && (n_sal += 1)
            (c_ent && c_sal) && (n_amb += 1)
            (c_ent && c_cbid && c_orden) && (n_tres += 1)
            c_cbid && (n_cbid += 1)
            if c_orden
                n_orden += 1
                ev.h1.pre_hash == ev.h2.pre_hash ? (n_ig += 1) : (n_de += 1)
            end
        end
        if motivo == MOTIVO_FORMA_ESTRUCTURA
            inc!(acc, "bloque_estructura")
            hay_tx && inc!(acc, "con_tx_estructura")
            d = primer_defecto_forma(A, b)
            d === :entradas ? inc!(acc, "bloque_estructura_entradas") :
                d === :salidas ? inc!(acc, "bloque_estructura_salidas") :
                inc!(acc, "bloque_estructura_ambos")
            n_tres > 0 && inc!(acc, "bloque_estructura_cbid_orden")
            # Txs distintas con estructura = entradas + salidas − ambas.
            acc["ev_estructura"] = get(acc, "ev_estructura", 0) +
                                   max(n_ent + n_sal - n_amb, 1)
        elseif motivo == MOTIVO_FORMA_CBID
            inc!(acc, "bloque_cbid")
            acc["ev_cbid"] = get(acc, "ev_cbid", 0) + max(n_cbid, 1)
            hay_tx && inc!(acc, "con_tx_cbid")
            n_orden > 0 && inc!(acc, "ambos_cbid")
        else
            inc!(acc, "bloque_orden")
            hay_tx && inc!(acc, "con_tx_orden")
            # El primer defecto de orden (el que fija el motivo) es igualdad o descenso.
            d = primer_defecto_forma(A, b)
            d === :orden_igual ? inc!(acc, "bloque_orden_igual") :
                                 inc!(acc, "bloque_orden_desc")
            acc["ev_orden"] = get(acc, "ev_orden", 0) + max(n_orden, 1)
            acc["ev_orden_igual"] = get(acc, "ev_orden_igual", 0) + n_ig
            acc["ev_orden_desc"] = get(acc, "ev_orden_desc", 0) + n_de
        end
    end
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
    n_ev = parse(Int, get(cfg, "ev-replicas", "120"))

    puntos = PUNTOS_T04
    @printf("exportar: puntos=%d aleatorios=%d ev-replicas=%d salida=%s\n",
            length(puntos), n_aleatorios, n_ev, salida)
    flush(stdout)
    mkpath(dirname(salida))
    io = open(salida, "w")
    println(io, "# vectores-estado-dag-v0.6 · T04-SL4c-O-C (forma v4: precedencia por tx; ",
            "entradas/salidas, cbid y orden) · ", fecha, " · sha256 del contrato ", sha256_archivo(contrato))
    n = 0
    aev = Dict{String,Int}()
    af = Dict{String,Int}()
    if con_dirigidos
        pd = ParamsDAG(PARAMS_DAG_BASE[1], 1)
        for (nombre, A, _) in casos_dirigidos(pd)
            n += 1
            escribir_caso(io, n, nombre, 1, 1, "-", A)
            startswith(nombre, "D-1") && contar_evidencia(A, aev)
            contar_forma_evidencia(A, af)
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
        contar_forma_evidencia(A, af)
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
            contar_forma_evidencia(A, af)
        end
        @printf("  evidencia punto %d/%d\n", i, length(PARAMS_DAG_EV))
        flush(stdout)
    end
    # SL-4c-O/SL-4c-O-B/SL-4c-O-C: casos dedicados de forma v4 (estructura,
    # cbid, orden y combinaciones) con transacción monetaria válida en el mismo
    # bloque; garantizan los mínimos de cobertura.
    pdev1 = EstadoDAG._pd_ev(ParamsDAG(PARAMS_DAG_BASE[1], 1))
    for (modo, con_tx, it) in casos_forma_cobertura()
        _, A, _ = caso_forma_evidencia(pdev1; modo = modo, con_tx = con_tx, iter = it)
        n += 1
        escribir_caso(io, n, "forma-" * string(modo), 1, Int(pdev1.k), "iter=" * string(it), A)
        contar_forma_evidencia(A, af)
        contar_evidencia(A, aev)
    end
    @printf("  forma SL-4c-O/-B/-C: %s\n", string(af))
    flush(stdout)
    close(io)
    h = sha256_archivo(salida)
    sha_path = replace(salida, r"\.txt$" => "") * ".sha256"
    write(sha_path, h * "  " * salida * "\n")   # formato `sha256sum` (T04-B)
    @printf("exportar: casos=%d sha256=%s -> %s\n", n, h, sha_path)
    # Cobertura (ORDEN-T04-C §2): apartados vectores, forma SL-4c-O y run.jl.
    mkpath(dirname(cobertura))
    ioc = open(cobertura, "w")
    println(ioc, "# cobertura T04-SL4c-O-C v0.6 · ", fecha, " · contrato ",
            sha256_archivo(contrato))
    println(ioc, "# definiciones de los contadores de evidencia (sec. evidencia):")
    println(ioc, "#  construida   = EvidenceTx presente en la historia de aplicación seleccionada")
    println(ioc, "#  aplicada     = se aplica sin descarte al aplicarse su bloque")
    println(ioc, "#  sin_saldo    = aplicada con V=0 en su clave (EV-22, pérdida 0, incidente registrado)")
    println(ioc, "#  duplicada    = descartada por ErrEvidenciaDuplicada (EV-12)")
    println(ioc, "#  tardia       = descartada por ErrEvidenciaTardia (EV-14)")
    println(ioc, "#  con_entradas = obsoleto: la estructura EV-04 es forma desde SL-4c-O-C")
    println(ioc, "#  deshecha     = aplicada en la historia seleccionada en algún momento y luego")
    println(ioc, "#                 retirada por una reorganización (EV-27/EV-28); no cuenta el undo")
    println(ioc, "#                 exacto de un bloque que sigue en la cadena seleccionada")
    println(ioc, "# forma v4 (SL-4c-O/SL-4c-O-B/SL-4c-O-C): estructura, cbid ajeno u orden no")
    println(ioc, "# canónico invalidan el bloque entero")
    println(ioc, "#  bloque_estructura = bloque inválido con motivo ErrForma(EvidenciaConEntradasOSalidas)")
    println(ioc, "#  bloque_estructura_entradas/salidas/ambos = PRIMER sub-defecto de EV-04")
    println(ioc, "#  bloque_estructura_cbid_orden = estructura + cbid ajeno + orden (gana estructura)")
    println(ioc, "#  ev_estructura = EvidenceTx con algún defecto estructural de EV-04")
    println(ioc, "#  con_tx_estructura = el bloque inválido por estructura lleva además una tx monetaria")
    println(ioc, "#  bloque_cbid  = bloque inválido con motivo ErrForma(EvidenciaCbidAjeno)")
    println(ioc, "#  bloque_orden = bloque inválido con motivo ErrForma(OrdenCanonicoInvalido)")
    println(ioc, "#  bloque_orden_igual/desc = el PRIMER defecto de orden es H1=H2 / H1>H2")
    println(ioc, "#  ev_cbid/ev_orden = EvidenceTx con cada defecto dentro de esos bloques")
    println(ioc, "#  ev_orden_igual/desc = EvidenceTx con H1=H2 / H1>H2 en esos bloques")
    println(ioc, "#  ambos_cbid   = bloque con los dos defectos (gana el primero en el orden de tx)")
    println(ioc, "#  con_tx_cbid/con_tx_orden = el bloque inválido lleva además una tx monetaria")
    println(ioc, "# generador: pesos=", EstadoDAG.PESOS_AJUSTADOS,
            " npost=", min(EstadoDAG.npost_t04c(0), EstadoDAG.npost_t04c(1)), "..",
            max(EstadoDAG.npost_t04c(0), EstadoDAG.npost_t04c(1)),
            " p_tx=0.5 p_invalido=0.12 p_error_nonce=0.10 p_ev=0.12")
    println(ioc, "# minimos: depositos_aplicados>=150 retiros_aplicados>=100 ",
            "liberaciones_aplicadas>=100 ErrNonce>=30 y <=25% de garantia ",
            "construida ErrDobleGasto>=200 reorgs_garantia>=20")
    println(ioc, "# minimos SL-4c-O: bloque_cbid>=30 bloque_orden>=30 con_tx_cbid>=10 ",
            "con_tx_orden>=10 ambos_cbid>=5")
    println(ioc, "# minimos SL-4c-O-B: bloque_orden_desc>=10 bloque_orden_igual>=10")
    println(ioc, "# minimos SL-4c-O-C: bloque_estructura>=30 con_tx_estructura>=10 ",
            "bloque_estructura_ambos>=5 bloque_estructura_cbid_orden>=5")
    EstadoDAG.escribir_cobertura(ioc, "vectores-v0.6 (casos aleatorios)", ac)
    println(ioc, "SECCION evidencia SL-3b/SL-4c-O (dirigidos + aleatorios C-EVP)")
    for k in sort(collect(keys(aev)))
        println(ioc, "EV ", k, " = ", aev[k])
    end
    println(ioc, "SECCION forma v4 SL-4c-O/SL-4c-O-B/SL-4c-O-C")
    for k in ("bloque_estructura", "bloque_estructura_entradas", "bloque_estructura_salidas",
              "bloque_estructura_ambos", "bloque_estructura_cbid_orden", "ev_estructura",
              "con_tx_estructura",
              "bloque_cbid", "bloque_orden", "bloque_orden_igual", "bloque_orden_desc",
              "ev_cbid", "ev_orden", "ev_orden_igual", "ev_orden_desc", "ambos_cbid",
              "con_tx_cbid", "con_tx_orden")
        println(ioc, "FORMA ", k, " = ", get(af, k, 0))
    end
    # Las órdenes SL-4c-O, SL-4c-O-B y SL-4c-O-C exigen estos mínimos: si no se
    # alcanzan, el exportador falla. `bloque_estructura_ambos` cubre los dos
    # sub-defectos representables (entradas+salidas); `_cbid_orden` cubre los tres
    # defectos de la precedencia (testigos/n_wit no existe en el modelo `Tx`).
    minimos_ok = get(af, "bloque_cbid", 0) >= 30 && get(af, "bloque_orden", 0) >= 30 &&
                 get(af, "con_tx_cbid", 0) >= 10 && get(af, "con_tx_orden", 0) >= 10 &&
                 get(af, "ambos_cbid", 0) >= 5 &&
                 get(af, "bloque_orden_desc", 0) >= 10 &&
                 get(af, "bloque_orden_igual", 0) >= 10 &&
                 get(af, "bloque_estructura", 0) >= 30 &&
                 get(af, "con_tx_estructura", 0) >= 10 &&
                 get(af, "bloque_estructura_ambos", 0) >= 5 &&
                 get(af, "bloque_estructura_cbid_orden", 0) >= 5
    println(ioc, "FORMA minimos_SL4cO = ", minimos_ok ? "OK" : "NO")
    minimos_ok || error("cobertura de forma SL-4c-O/-B/-C por debajo del mínimo: $(af)")
    acr = EstadoDAG.cobertura_run()
    EstadoDAG.escribir_cobertura(ioc, "run.jl (seed 0x5a5a, replicas 200)", acr)
    close(ioc)
    @printf("exportar: cobertura -> %s evidencia=%s forma=%s\n", cobertura,
            string(aev), string(af))
    flush(stdout)
end

main()
