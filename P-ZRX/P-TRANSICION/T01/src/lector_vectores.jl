# lector_vectores.jl — relectura INDEPENDIENTE de los vectores de T01-B.
#
#     julia --project=. src/lector_vectores.jl [RUTA]
#
# No reutiliza ninguna función de `exportar.jl`: define su propio analizador y
# su propio render (con las mismas reglas de orden que fija §3.4 de
# ORDEN-T01-B). Reconstruye cada caso, lo reejecuta con el oráculo
# (`aplicar`/`seleccionar`/`construir_validos`) y compara RES, SEL, UTXO, GAR y
# EST. Además comprueba, para X-16, la independencia del orden de entrega, y
# para X-19/X-20, el undo exacto por hash canónico. Sale con código ≠ 0 si hay
# cualquier discrepancia.

using Transicion
using SHA

const RUTA_DEF = "resultados/vectores-transicion-v0.3.txt"

# --- nombres del formato (propios del lector) ------------------------------

const FAMILIA_DE = Dict("Genesis" => Genesis, "PoW" => PoW, "PoST" => PoST)
const ORIGEN_NOMBRE = Dict(OrigenCoinbasePow => "CoinbasePow",
                           OrigenTx => "Tx", OrigenLiberacion => "Liberacion")
const ORIGEN_ORDEN = Dict(OrigenCoinbasePow => 0, OrigenTx => 1,
                          OrigenLiberacion => 2)
const FASE_NOMBRE = Dict(FaseGenesis => "FaseGenesis", FasePoW => "FasePoW",
                         FasePoST => "FasePoST")

# --- render independiente --------------------------------------------------

function r_utxo(E::Estado)
    os = collect(values(E.utxo))
    sort!(os, by = o -> (o.dueño, o.valor, ORIGEN_ORDEN[o.origen],
                         o.creada_en_altura, o.creada_en_slot))
    return [string("UTXO dueño=", o.dueño, " valor=", o.valor, " origen=",
                   ORIGEN_NOMBRE[o.origen], " altura=",
                   o.creada_en_altura == -1 ? "-" : string(o.creada_en_altura),
                   " slot=",
                   o.creada_en_slot == -1 ? "-" : string(o.creada_en_slot))
            for o in os]
end

function r_gar(E::Estado)
    ls = String[]
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
        push!(ls, string("GAR clave=", k, " activo=", g.activo,
                         " pend=[", ps, "] ret=[", rs, "] cred=[", cs,
                         "] congelado=", g.congelado,
                         " nonce=", g.nonce_siguiente, is_))
    end
    return ls
end

function r_est(E::Estado)
    return string("EST emitido=", E.emitido, " quemado=", E.quemado,
                  " fase=", FASE_NOMBRE[E.fase], " terminal=", E.terminal,
                  " altura=", E.altura, " slot=", E.slot,
                  " peso_sufijo=", E.peso_sufijo)
end

# --- análisis --------------------------------------------------------------

function campos(linea::AbstractString)
    d = Dict{String,String}()
    for t in split(linea)[2:end]
        p = split(t, "=", limit = 2)
        d[String(p[1])] = String(p[2])
    end
    return d
end

function parsear_salidas(s::AbstractString)
    interior = s[findfirst('[', s)+1:findlast(']', s)-1]
    isempty(interior) && return Salida[]
    out = Salida[]
    for it in split(interior, ",")
        p = split(it, ":")
        push!(out, Salida(parse(Int, p[1]), parse(UInt64, p[2]),
                          parse(Int, p[3]), OrigenTx, -1, -1))
    end
    return out
end

function parsear_entradas(s::AbstractString)
    interior = s[findfirst('[', s)+1:findlast(']', s)-1]
    isempty(interior) && return Int[]
    return [parse(Int, x) for x in split(interior, ",")]
end

# SL-3: `cb:clave:sector:historia:chunk:slot:pre_hash:sello|...` (dos cabeceras).
function parsear_evidencia(s::AbstractString)
    partes = split(s, "|")
    length(partes) == 2 || error("evidencia malformada: $s")
    ids = Vector{IdentidadEvidencia}(undef, 2)
    cabs = Vector{CabeceraEvidencia}(undef, 2)
    for (j, p) in enumerate(partes)
        f = split(p, ":")
        length(f) == 8 || error("cabecera de evidencia malformada: $p")
        ids[j] = IdentidadEvidencia(parse(Int, f[1]), parse(Int, f[2]),
                                    parse(Int, f[3]), parse(Int, f[4]),
                                    parse(Int, f[5]), parse(Int, f[6]))
        cabs[j] = CabeceraEvidencia(parse(UInt64, f[7]), f[8] == "1")
    end
    return Evidencia(ids[1], ids[2], cabs[1], cabs[2])
end

function parsear_tx(linea::AbstractString)
    c = campos(linea)
    tipo = c["tipo"]
    firmante = parse(Int, c["firmante"])
    clave = parse(Int, c["clave"])
    importe = parse(UInt64, c["importe"])
    ent = parsear_entradas(c["ent"])
    sal = parsear_salidas(c["sal"])
    if tipo == "Coinbase"
        return tx_coinbase(sal)
    elseif tipo == "CoinbasePost"
        return tx_coinbase_post(importe)
    elseif tipo == "Transferencia"
        return tx_transferencia(ent, sal, firmante)
    elseif tipo == "Deposito"
        return tx_deposito(ent, clave, importe, firmante;
                           nonce = parse(UInt64, c["nonce"]))
    elseif tipo == "Retiro"
        return tx_retiro(clave, importe, firmante;
                         nonce = parse(UInt64, c["nonce"]))
    elseif tipo == "Liberacion"
        return tx_liberacion(clave, importe, firmante;
                             nonce = parse(UInt64, c["nonce"]))
    elseif tipo == "Evidencia"
        if haskey(c, "ev")
            ev = parsear_evidencia(c["ev"])
            if isempty(ent) && isempty(sal)
                return tx_evidencia(ev)
            end
            return Tx(TxEvidencia, sal, ent, firmante, clave, importe, 0,
                      UInt64(0), ev)
        end
        return tx_evidencia(clave)
    end
    error("tipo de tx no releíble en formato v0 (SEC-0): $tipo")
end

function parsear_bloque(c::Dict{String,String}, txs::Vector{Tx})
    return Bloque(parse(Int, c["id"]), FAMILIA_DE[c["fam"]],
                  parse(Int, c["padre"]), parse(Int, c["altura"]),
                  parse(Int, c["trabajo"]), c["pow_ok"] == "1",
                  parse(Int, c["slot"]), parse(Int, c["prod"]),
                  0, parse(Int, c["peso"]), parse(Int, c["reqdecl"]), txs)
end

function parsear_params(c::Dict{String,String})
    f = c["F_slots"] == "inf" ? typemax(Int) : parse(Int, c["F_slots"])
    return Params(H_dep = parse(Int, c["H_dep"]), M_cb = parse(Int, c["M_cb"]),
                  M_dep = parse(Int, c["M_dep"]),
                  H_corte_min = parse(Int, c["H_corte_min"]),
                  W_min = parse(Int, c["W_min"]), S_min = parse(Int, c["S_min"]),
                  K_min = parse(Int, c["K_min"]), q = parse(Int, c["q"]),
                  M_res_slots = parse(Int, c["M_res_slots"]),
                  M_dep_slots = parse(Int, c["M_dep_slots"]),
                  M_rec_slots = parse(Int, c["M_rec_slots"]),
                  R_slots = parse(Int, c["R_slots"]), F_slots = f,
                  sec = SEC0, corte = CUT_HWPhi, seleccion = FC3,
                  f_num = parse(Int, get(c, "f_num", "1")),
                  f_den = parse(Int, get(c, "f_den", "1")),
                  Plazo_slots = parse(Int, get(c, "Plazo_slots", "0")),
                  M_margen_slots = parse(Int, get(c, "M_margen_slots", "0")),
                  cbid = parse(Int, get(c, "cbid", "0")),
                  evp = get(c, "evp", "0") == "1")
end

struct CasoLeido
    n::Int
    nombre::String
    punto::Int
    semilla::String
    param::Dict{String,String}
    bloques::Vector{Bloque}
    res::Dict{Int,String}
    sel::Int
    utxo::Vector{String}
    gar::Vector{String}
    est::String
end

function parsear_fichero(ruta::AbstractString)
    casos = CasoLeido[]
    n = nombre = punto = semilla = 0
    param = Dict{String,String}()
    bloques = Bloque[]
    res = Dict{Int,String}()
    sel = -1
    utxo = String[]
    gar = String[]
    est = ""
    txs = Tx[]
    pendiente = nothing
    en_caso = false
    for linea in eachline(ruta)
        startswith(linea, "#") && continue
        isempty(strip(linea)) && continue
        primera = split(linea)[1]
        if primera == "CASO"
            c = campos(linea)
            n = parse(Int, c["n"]); nombre = c["nombre"]
            punto = parse(Int, c["punto"]); semilla = c["semilla"]
            param = Dict{String,String}(); bloques = Bloque[]; res = Dict{Int,String}()
            sel = -1; utxo = String[]; gar = String[]; est = ""
            txs = Tx[]; pendiente = nothing; en_caso = true
        elseif primera == "PARAM"
            param = campos(linea)
        elseif primera == "BLOQUE"
            pendiente = campos(linea)
            txs = Tx[]
        elseif primera == "TX"
            push!(txs, parsear_tx(linea))
        elseif primera == "RES"
            c = campos(linea)
            b = parsear_bloque(pendiente, txs)
            push!(bloques, b)
            res[parse(Int, c["bloque"])] = c["res"]
            pendiente = nothing
        elseif primera == "SEL"
            sel = parse(Int, campos(linea)["punta"])
        elseif primera == "UTXO"
            push!(utxo, linea)
        elseif primera == "GAR"
            push!(gar, linea)
        elseif primera == "EST"
            est = linea
        elseif primera == "FIN"
            en_caso || continue
            push!(casos, CasoLeido(n, nombre, punto, semilla, param, bloques,
                                   res, sel, utxo, gar, est))
            en_caso = false
        else
            error("línea desconocida: $linea")
        end
    end
    return casos
end

# --- reejecución -----------------------------------------------------------

function res_recomputado(bloques::Vector{Bloque}, P::Params)
    memo, por_id = construir_validos(bloques, P)
    out = Dict{Int,String}()
    for b in bloques
        if haskey(memo, b.id)
            out[b.id] = "OK"
        else
            p = get(por_id, b.padre, nothing)
            if p === nothing || !haskey(memo, b.padre)
                out[b.id] = "ErrSinPadre"
            else
                r = aplicar(memo[b.padre], b, P)
                out[b.id] = r isa Err ? string(r) : "OK"
            end
        end
    end
    return out
end

function verificar_caso(caso::CasoLeido, discrepancias::Vector{String})
    P = parsear_params(caso.param)
    # RES
    rec = res_recomputado(caso.bloques, P)
    for b in caso.bloques
        esp = get(caso.res, b.id, "<falta>")
        obt = get(rec, b.id, "<falta>")
        esp == obt || push!(discrepancias,
            "SOLO-1 RES caso=$(caso.n) bloque=$(b.id) esperado=$esp obtenido=$obt")
    end
    # SEL + estado de la punta
    sel = seleccionar(caso.bloques, P)
    sel.punta == caso.sel || push!(discrepancias,
        "SOLO-1 SEL caso=$(caso.n) esperado=$(caso.sel) obtenido=$(sel.punta)")
    u = r_utxo(sel.estado)
    g = r_gar(sel.estado)
    e = r_est(sel.estado)
    u == caso.utxo || push!(discrepancias, "SOLO-1 UTXO caso=$(caso.n)")
    g == caso.gar || push!(discrepancias, "SOLO-1 GAR caso=$(caso.n)")
    e == caso.est || push!(discrepancias,
        "SOLO-1 EST caso=$(caso.n) esperado=$(caso.est) obtenido=$e")
    # Propiedades extra de los dirigidos.
    if caso.nombre == "X-16" && length(caso.bloques) > 1
        inv = reverse(caso.bloques)
        selr = seleccionar(inv, P)
        (selr.punta == sel.punta &&
         hash_canonico(selr.estado) == hash_canonico(sel.estado)) ||
            push!(discrepancias, "SOLO-1 X-16 orden inverso caso=$(caso.n)")
    end
    if caso.nombre == "X-19" || caso.nombre == "X-20"
        memo, _ = construir_validos(caso.bloques, P)
        for (id, E) in memo
            b = nothing
            for x in caso.bloques
                if x.id == id
                    b = x
                    break
                end
            end
            b === nothing && continue
            b.familia == Genesis && continue
            Ep = get(memo, b.padre, nothing)
            Ep === nothing && continue
            r = aplicar_con_undo(Ep, b, P)
            r isa Err && continue
            E2, undo = r
            hash_canonico(deshacer(E2, undo)) == hash_canonico(Ep) ||
                push!(discrepancias, "SOLO-1 undo caso=$(caso.n) bloque=$(b.id)")
        end
    end
    return nothing
end

function main()
    ruta = isempty(ARGS) ? RUTA_DEF : ARGS[1]
    casos = parsear_fichero(ruta)
    discrepancias = String[]
    for c in casos
        verificar_caso(c, discrepancias)
    end
    println("leidos_casos = ", length(casos))
    println("discrepancias = ", length(discrepancias))
    for d in Iterators.take(discrepancias, 20)
        println(d)
    end
    salida = length(discrepancias) == 0 ? 0 : 1
    println("VEREDICTO_LECTURA = ",
            salida == 0 ? "SIN DISCREPANCIAS" : "CON DISCREPANCIAS")
    exit(salida)
end

main()
