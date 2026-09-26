# exportar.jl — exportador determinista de vectores de transición (ORDEN-T01-B,
# revisado por T01-D: campo `nonce=` de F-15; T01-E: id de liberación F-18).
#
#     julia --project=. exportar.jl [--fecha <ISO-8601>] [--salida RUTA] \
#         [--contrato RUTA] [--dirigidos 1] [--aleatorios 2000]
#
# Escribe `resultados/vectores-transicion-v0.4.txt` (formato de texto neutral de
# v0.1, §3.4 de la orden, con el `nonce=` de F-15 y el `ev=` de SL-3) y su
# sha256 en `resultados/vectores-transicion-v0.4.sha256` (formato `sha256sum`).
# Solo interfaces por defecto: CUT_HWPhi, FC3, SEC0. Un hilo, sin Python.
#
# El lector independiente vive en `src/lector_vectores.jl` y NO reutiliza ninguna
# función de este fichero.

using Transicion
using StableRNGs
using SHA
using Printf

const CONTRATO_DEF = "/home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/CONTRATO-v0.md"
# SL-3b: vectores v0.4 con RAT-2′ (recompensa `suelo(C·2/8)`); v0..v0.3 se conservan.
const SALIDA_DEF = "resultados/vectores-transicion-v0.4.txt"
const COBERTURA_DEF = "resultados/cobertura-v0.4.txt"

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

# Puntos reducidos con las interfaces por defecto (CUT_HWPhi, FC3, SEC0).
function puntos_por_defecto()
    return [P for P in puntos_rejilla(rejilla = :reducida)
            if P.sec == SEC0 && P.corte == CUT_HWPhi && P.seleccion == FC3]
end

# --- render del formato ----------------------------------------------------

param_str(P::Params) = string(
    "PARAM H_dep=", P.H_dep, " M_cb=", P.M_cb, " M_dep=", P.M_dep,
    " H_corte_min=", P.H_corte_min, " W_min=", P.W_min, " S_min=", P.S_min,
    " K_min=", P.K_min, " q=", P.q, " M_res_slots=", P.M_res_slots,
    " M_dep_slots=", P.M_dep_slots, " M_rec_slots=", P.M_rec_slots,
    " R_slots=", P.R_slots, " F_slots=",
    P.F_slots == typemax(Int) ? "inf" : string(P.F_slots),
    " f_num=", P.f_num, " f_den=", P.f_den, " Plazo_slots=", P.Plazo_slots,
    " M_margen_slots=", P.M_margen_slots, " cbid=", P.cbid,
    " evp=", P.evp ? 1 : 0)

bloque_str(b::Bloque) = string(
    "BLOQUE id=", b.id, " fam=", NOMBRE_FAMILIA[b.familia], " padre=", b.padre,
    " altura=", b.altura, " trabajo=", b.trabajo,
    " pow_ok=", b.pow_ok ? 1 : 0, " slot=", b.slot, " prod=", b.productor,
    " peso=", b.peso, " reqdecl=", b.requisito_declarado, " ntx=", length(b.txs))

# SL-3: cabeceras de evidencia `cb:clave:sector:historia:chunk:slot:ph:sello|...`.
function ev_str(ev::Evidencia)
    return string(ev.id1.cbid, ":", ev.id1.clave, ":", ev.id1.sector, ":",
                  ev.id1.historia, ":", ev.id1.chunk, ":", ev.id1.slot, ":",
                  ev.h1.pre_hash, ":", ev.h1.sello_ok ? 1 : 0, "|",
                  ev.id2.cbid, ":", ev.id2.clave, ":", ev.id2.sector, ":",
                  ev.id2.historia, ":", ev.id2.chunk, ":", ev.id2.slot, ":",
                  ev.h2.pre_hash, ":", ev.h2.sello_ok ? 1 : 0)
end

function tx_str(tx::Tx)
    ent = join(string.(tx.entradas), ",")
    sal = join(["$(s.id):$(s.valor):$(s.dueño)" for s in tx.salidas], ",")
    base = string("TX tipo=", NOMBRE_TIPO[tx.tipo], " firmante=", tx.firmante,
                  " clave=", tx.clave, " importe=", tx.importe,
                  " ent=[", ent, "] sal=[", sal, "]")
    # F-15: `nonce=` solo en las tres operaciones de garantía.
    if tx.tipo == TxDeposito || tx.tipo == TxRetiro || tx.tipo == TxLiberacion
        return string(base, " nonce=", tx.nonce)
    end
    # SL-3: cabeceras de la evidencia.
    if tx.tipo == TxEvidencia && tx.evidencia !== nothing
        return string(base, " ev=", ev_str(tx.evidencia))
    end
    return base
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
        inc = sort(g.incidentes, by = x -> x[1])
        is_ = isempty(inc) ? "" :
              string(" inc=", join(["$(iid)@$(sf)" for (iid, sf) in inc], ","))
        push!(lineas, string("GAR clave=", k, " activo=", g.activo,
                             " pend=[", ps, "] ret=[", rs, "] cred=[", cs,
                             "] congelado=", g.congelado,
                             " nonce=", g.nonce_siguiente, is_))
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

# --- historias dirigidas X-16…X-20 (mismas que test/runtests.jl) -----------

function historia_x16(P::Params, seed::Int)
    rng = StableRNG(seed)
    alta = P.sec == SECA ? max(P.H_dep, 1) : -1
    pref = construir_poW(rng, P; hasta = max(P.H_corte_min - 1, 1),
                         depositar = true, alta_en = alta, prueba_en = alta,
                         transferir = false)
    bloques, estados = pref[1], pref[2]
    E0 = estados[end]
    p0 = bloques[end].id
    h = P.H_corte_min
    B1 = gen_pow(id = pref[3], padre = p0, altura = h,
                 txs = [tx_coinbase([Salida(960000, UInt64(10), 1, OrigenTx,
                                            -1, -1)])])
    E1, _ = hijo_pow(P, E0, B1.id, p0, h; txs = B1.txs)
    E1 === nothing && return Bloque[]
    sector = P.sec == SECA ? 1 : 0
    post, _, _ = cadena_post(P, E1, pref[3] + 50, B1.id, 2;
                             productor = 1, peso = 1, sector = sector)
    return vcat(bloques, [B1], post)
end

function historia_x19(P::Params)
    pref, sin1 = historia_reorg(P)
    sin1[2][end].terminal == -1 && return Bloque[]
    TB = sin1[1][end]
    B = gen_post(id = TB.id + 1, padre = TB.id, slot = 1, productor = 1,
                 peso = 1)
    return vcat(sin1[1], [B])
end

reencadenar(B::Bloque, padre::Int) =
    Bloque(B.id, B.familia, padre, B.altura, B.trabajo, B.pow_ok, B.slot,
           B.productor, B.sector, B.peso, B.requisito_declarado, B.txs)

# Casos dirigidos para un punto por defecto: (nombre, bloques).
# `n_esperado_fallos` cuenta los dirigidos cuyo `RES` releíble no coincide con
# el error construido a mano en `escenarios_rechazo` (debe ser 0).
function casos_dirigidos(P::Params, punto::Int, n_esperado_fallos::Base.RefValue{Int})
    out = Tuple{String,Vector{Bloque}}[]
    # X-01…X-15 (escenarios_rechazo), salvo X-12 (no releíble) y X-15 (SEC-A).
    for c in escenarios_rechazo(P)
        (c.nombre == "X-12" || startswith(c.nombre, "X-15")) && continue
        pre = c.prefijo
        isempty(pre) && continue
        B = c.B.padre == pre[end].id ? c.B : reencadenar(c.B, pre[end].id)
        story = vcat(pre, [B])
        rm = res_por_bloque(story, P)
        if rm[B.id] != string(c.esperado)
            n_esperado_fallos[] += 1
            @warn "dirigido con error inesperado" c.nombre punto rm[B.id] c.esperado
        end
        push!(out, (c.nombre, story))
    end
    # X-16: mismo conjunto en orden de entrega natural.
    h16 = historia_x16(P, 0x1600 + punto)
    isempty(h16) || push!(out, ("X-16", h16))
    # X-17 / X-18: dos terminales, pesos (2,1) y rama PoW tardía (2,0).
    h17 = historia_dos_terminales(P; pesos = (2, 1), trabajo_extra = 1)
    h17 === nothing || push!(out, ("X-17", h17))
    h18 = historia_dos_terminales(P; pesos = (2, 0), trabajo_extra = 100)
    h18 === nothing || push!(out, ("X-18", h18))
    # X-19: rama sin el depósito habilitante + transición ⇒ ErrGarantia.
    h19 = historia_x19(P)
    isempty(h19) || push!(out, ("X-19", h19))
    # X-20: historia aleatoria válida (más inválidas) con undo exacto.
    h20 = generar_historia(StableRNG(0x2020), P; max_altura = 8, max_post = 2)
    push!(out, ("X-20", h20))
    return out
end

# --- SL-3: cobertura por tipo de evidencia --------------------------------

inc!(d::Dict{String,Int}, k::AbstractString) = (d[k] = get(d, k, 0) + 1)

function contar_cobertura(bloques::Vector{Bloque}, P::Params, acc::Dict{String,Int})
    memo, _ = construir_validos(bloques, P)
    for b in bloques
        txev = nothing
        for tx in b.txs
            if tx.tipo == TxEvidencia
                txev = tx
                break
            end
        end
        txev === nothing && continue
        Ep = get(memo, b.padre, nothing)
        if haskey(memo, b.id)
            ev = txev.evidencia
            if ev === nothing
                inc!(acc, "malformada")
                continue
            end
            V = (Ep !== nothing && haskey(Ep.garantias, ev.id1.clave)) ?
                total_garantia(Ep.garantias[ev.id1.clave]) : Int128(0)
            inc!(acc, V == 0 ? "sin_saldo" : "aplicada")
            if Ep !== nothing
                r = aplicar_con_undo(Ep, b, P)
                if !(r isa Err)
                    E2, undo = r
                    hash_canonico(deshacer(E2, undo)) == hash_canonico(Ep) &&
                        inc!(acc, "deshecha")
                end
            end
        elseif Ep === nothing
            inc!(acc, "sin_padre")
        else
            r = aplicar(Ep, b, P)
            nombre = r == ErrEvidenciaDuplicada ? "duplicada" :
                     r == ErrEvidenciaTardia    ? "tardia" :
                     r == ErrCbidAjeno          ? "cbid_ajeno" :
                     r == ErrOrdenCanonico      ? "orden_canonico" :
                     r == ErrSinEvidencia       ? "sin_evidencia" :
                     r == ErrEvidenciaConEntradas ? "con_entradas" :
                     r == ErrPuertaRAT3         ? "puerta_rat3" : "otro_error"
            inc!(acc, nombre)
        end
    end
    return acc
end

# --- main ------------------------------------------------------------------

function main()
    cfg = parsear(ARGS)
    fecha = get(cfg, "fecha", fecha_por_defecto())
    salida = get(cfg, "salida", SALIDA_DEF)
    cobertura = get(cfg, "cobertura", COBERTURA_DEF)
    contrato = get(cfg, "contrato", CONTRATO_DEF)
    con_dirigidos = get(cfg, "dirigidos", "1") != "0"
    n_aleatorios = parse(Int, get(cfg, "aleatorios", "2000"))
    n_ev_por_tipo = parse(Int, get(cfg, "ev-por-tipo", "40"))

    puntos = puntos_por_defecto()
    @printf("exportar: puntos por defecto=%d n_aleatorios=%d salida=%s\n",
            length(puntos), n_aleatorios, salida)
    flush(stdout)

    mkpath(dirname(salida))
    io = open(salida, "w")
    println(io, "# vectores-transicion-v0.4 · T01-SL3b (EvidenceTx, RAT-2′) · ",
            fecha, " · sha256 del contrato ", sha256_archivo(contrato))
    n = 0
    fallos_dirigidos = Ref(0)
    cov = Dict{String,Int}()

    if con_dirigidos
        N = length(puntos)
        idxs = unique([1, div(1 + N, 2), N])
        for punto in idxs
            P = puntos[punto]
            for (nombre, bloques) in casos_dirigidos(P, punto, fallos_dirigidos)
                n += 1
                escribir_caso(io, n, nombre, punto, "-", bloques, P)
            end
        end
    end

    if n_aleatorios > 0
        N = length(puntos)
        for r in 1:n_aleatorios
            punto = N == 1 ? 1 :
                    1 + round(Int, (r - 1) * (N - 1) / (n_aleatorios - 1))
            P = puntos[punto]
            semilla = UInt64(0x5a5a) + UInt64(r)
            rng = StableRNG(semilla)
            bloques = generar_historia(rng, P; max_altura = 9, max_post = 3)
            n += 1
            escribir_caso(io, n, "aleatorio", punto, string(semilla), bloques, P)
            (r % 500 == 0) && (@printf("  aleatorios %d/%d\n", r, n_aleatorios);
                               flush(stdout))
        end
    end
    # --- SL-3: casos con evidencia ----------------------------------------
    puntos_ev = puntos_evidencia()
    for (pi, P) in enumerate(puntos_ev)
        cam = caso_rat3_carrera(P)
        if cam !== nothing
            bl, _, _ = cam
            n += 1
            escribir_caso(io, n, "EV-RAT3-carrera", pi, "-", bl, P)
            contar_cobertura(bl, P, cov)
        end
        au = caso_autodenuncia(P)
        if !isempty(au[1])
            n += 1
            escribir_caso(io, n, "EV-autodenuncia", pi, "-", au[1], P)
            contar_cobertura(au[1], P, cov)
        end
        if pi <= 3
            for (nombre, bl) in casos_evidencia_cobertura(P; n = n_ev_por_tipo)
                n += 1
                escribir_caso(io, n, nombre, pi, "-", bl, P)
                contar_cobertura(bl, P, cov)
            end
        end
        (pi % 4 == 0) && (@printf("  evidencia punto %d/%d\n", pi,
                                  length(puntos_ev)); flush(stdout))
    end
    close(io)

    open(cobertura, "w") do ioc
        println(ioc, "# cobertura SL-3b T01 v0.4 · ", fecha)
        println(ioc, "# contadores de EvidenceTx (dirigidos + aleatorios de evidencia):")
        println(ioc, "#  aplicada    = aplicada sin descarte en la historia seleccionada")
        println(ioc, "#  sin_saldo   = aplicada con la clave sin garantía (V=0, EV-22)")
        println(ioc, "#  duplicada   = descartada por ErrEvidenciaDuplicada (EV-12)")
        println(ioc, "#  tardia      = descartada por ErrEvidenciaTardia (EV-14)")
        println(ioc, "#  cbid_ajeno  = descartada por ErrCbidAjeno (RAT-1)")
        println(ioc, "#  con_entradas= descartada por ErrEvidenciaConEntradas (EV-04)")
        println(ioc, "#  orden_canonico / sin_evidencia / puerta_rat3 / otro_error / malformada / sin_padre")
        println(ioc, "#  deshecha    = aplicada y deshecha exactamente con `deshacer` (EV-27);")
        println(ioc, "#                T01 no fusiona ramas, así que no mide reorganización")
        for k in sort(collect(keys(cov)))
            println(ioc, k, " = ", cov[k])
        end
    end

    h = sha256_archivo(salida)
    sha_path = replace(salida, r"\.txt$" => "") * ".sha256"
    write(sha_path, h * "  " * salida * "\n")
    @printf("exportar: casos=%d sha256=%s -> %s\n", n, h, sha_path)
    @printf("exportar: cobertura=%s %s\n", cobertura, string(cov))
    @printf("exportar: dirigidos_con_error_inesperado=%d\n", fallos_dirigidos[])
    flush(stdout)
end

main()
