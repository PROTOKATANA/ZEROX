# lector_vectores.jl — relectura INDEPENDIENTE de los vectores de T04.
#
#     julia --project=. src/lector_vectores.jl [RUTA]
#
# No reutiliza ninguna función de `exportar.jl`: define su propio analizador y su
# propio render. Reconstruye cada caso (prefijo PoW + DAG PoST), lo reejecuta con
# el oráculo y compara RES, DESC, SEL, UTXO, GAR y EST. Comprueba además I-1 y el
# undo exacto de cada bloque válido. Sale con código ≠ 0 si hay discrepancia.

using EstadoDAG
import EstadoDAG.Transicion
using SHA

const RUTA_DEF = "resultados/vectores-estado-dag-v0.5.txt"

const FAMILIA_DE = Dict("Genesis" => Transicion.Genesis, "PoW" => Transicion.PoW,
                        "PoST" => Transicion.PoST)
const ORIGEN_NOMBRE = Dict(Transicion.OrigenCoinbasePow => "CoinbasePow",
                           Transicion.OrigenTx => "Tx",
                           Transicion.OrigenLiberacion => "Liberacion")
const ORIGEN_ORDEN = Dict(Transicion.OrigenCoinbasePow => 0, Transicion.OrigenTx => 1,
                          Transicion.OrigenLiberacion => 2)
const FASE_NOMBRE = Dict(Transicion.FaseGenesis => "FaseGenesis",
                         Transicion.FasePoW => "FasePoW",
                         Transicion.FasePoST => "FasePoST")

# --- render independiente ---------------------------------------------------

function r_utxo(E::Transicion.Estado)
    os = collect(values(E.utxo))
    sort!(os, by = o -> (o.dueño, o.valor, ORIGEN_ORDEN[o.origen],
                         o.creada_en_altura, o.creada_en_slot))
    return [string("UTXO dueño=", o.dueño, " valor=", o.valor, " origen=",
                   ORIGEN_NOMBRE[o.origen], " altura=",
                   o.creada_en_altura == -1 ? "-" : string(o.creada_en_altura),
                   " slot=", o.creada_en_slot == -1 ? "-" : string(o.creada_en_slot))
            for o in os]
end

function r_gar(E::Transicion.Estado)
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

r_est(E::Transicion.Estado) =
    string("EST emitido=", E.emitido, " quemado=", E.quemado, " fase=",
           FASE_NOMBRE[E.fase], " terminal=", E.terminal, " altura=", E.altura,
           " slot=", E.slot, " peso_sufijo=", E.peso_sufijo)

# --- análisis ---------------------------------------------------------------

function campos(linea::AbstractString)
    d = Dict{String,String}()
    for t in split(linea)[2:end]
        p = split(t, "=", limit = 2)
        length(p) == 2 && (d[String(p[1])] = String(p[2]))
    end
    return d
end

function lista_ids(s::AbstractString)
    interior = s[findfirst('[', s)+1:findlast(']', s)-1]
    isempty(interior) && return Int[]
    return [parse(Int, x) for x in split(interior, ",")]
end

function parsear_salidas(s::AbstractString)
    interior = s[findfirst('[', s)+1:findlast(']', s)-1]
    isempty(interior) && return Transicion.Salida[]
    out = Transicion.Salida[]
    for it in split(interior, ",")
        p = split(it, ":")
        push!(out, Transicion.Salida(parse(Int, p[1]), parse(UInt64, p[2]),
                                     parse(Int, p[3]), Transicion.OrigenTx, -1, -1))
    end
    return out
end

function parsear_entradas(s::AbstractString)
    interior = s[findfirst('[', s)+1:findlast(']', s)-1]
    isempty(interior) && return Int[]
    return [parse(Int, x) for x in split(interior, ",")]
end

# SL-3: `cb:clave:sector:historia:chunk:slot:pre_hash:sello|...`.
function parsear_evidencia(s::AbstractString)
    partes = split(s, "|")
    length(partes) == 2 || error("evidencia malformada: $s")
    ids = Vector{Transicion.IdentidadEvidencia}(undef, 2)
    cabs = Vector{Transicion.CabeceraEvidencia}(undef, 2)
    for (j, p) in enumerate(partes)
        f = split(p, ":")
        length(f) == 8 || error("cabecera de evidencia malformada: $p")
        ids[j] = Transicion.IdentidadEvidencia(parse(Int, f[1]), parse(Int, f[2]),
                                               parse(Int, f[3]), parse(Int, f[4]),
                                               parse(Int, f[5]), parse(Int, f[6]))
        cabs[j] = Transicion.CabeceraEvidencia(parse(UInt64, f[7]), f[8] == "1")
    end
    return Transicion.Evidencia(ids[1], ids[2], cabs[1], cabs[2])
end

function parsear_tx(linea::AbstractString)
    c = campos(linea)
    tipo = c["tipo"]
    firmante = parse(Int, c["firmante"])
    clave = parse(Int, c["clave"])
    importe = parse(UInt64, c["importe"])
    ent = parsear_entradas(c["ent"])
    sal = parsear_salidas(c["sal"])
    # T04-B (F-15): el `nonce=` de las operaciones de garantía; 0 si no aparece.
    nonce = haskey(c, "nonce") ? parse(UInt64, c["nonce"]) : UInt64(0)
    if tipo == "Coinbase"
        return Transicion.tx_coinbase(sal)
    elseif tipo == "CoinbasePost"
        return Transicion.tx_coinbase_post(importe)
    elseif tipo == "Transferencia"
        return Transicion.tx_transferencia(ent, sal, firmante)
    elseif tipo == "Deposito"
        return Transicion.tx_deposito(ent, clave, importe, firmante; nonce = nonce)
    elseif tipo == "Retiro"
        return Transicion.tx_retiro(clave, importe, firmante; nonce = nonce)
    elseif tipo == "Liberacion"
        return Transicion.tx_liberacion(clave, importe, firmante; nonce = nonce)
    elseif tipo == "Evidencia"
        if haskey(c, "ev")
            ev = parsear_evidencia(c["ev"])
            if isempty(ent) && isempty(sal)
                return Transicion.tx_evidencia(ev)
            end
            return Transicion.Tx(Transicion.TxEvidencia, sal, ent, firmante, clave,
                                 importe, 0, UInt64(0), ev)
        end
        return Transicion.tx_evidencia(clave)
    end
    error("tipo de tx no releíble en formato v0.4 (SEC-0): $tipo")
end

function parsear_params(c::Dict{String,String})
    f = c["F_slots"] == "inf" ? typemax(Int) : parse(Int, c["F_slots"])
    P = Transicion.Params(H_dep = parse(Int, c["H_dep"]), M_cb = parse(Int, c["M_cb"]),
                          M_dep = parse(Int, c["M_dep"]),
                          H_corte_min = parse(Int, c["H_corte_min"]),
                          W_min = parse(Int, c["W_min"]), S_min = parse(Int, c["S_min"]),
                          K_min = parse(Int, c["K_min"]), q = parse(Int, c["q"]),
                          M_res_slots = parse(Int, c["M_res_slots"]),
                          M_dep_slots = parse(Int, c["M_dep_slots"]),
                          M_rec_slots = parse(Int, c["M_rec_slots"]),
                          R_slots = parse(Int, c["R_slots"]), F_slots = f,
                          sec = Transicion.SEC0, corte = Transicion.CUT_HWPhi,
                          seleccion = Transicion.FC3,
                          f_num = parse(Int, get(c, "f_num", "1")),
                          f_den = parse(Int, get(c, "f_den", "1")),
                          Plazo_slots = parse(Int, get(c, "Plazo_slots", "0")),
                          M_margen_slots = parse(Int, get(c, "M_margen_slots", "0")),
                          cbid = parse(Int, get(c, "cbid", "0")),
                          evp = get(c, "evp", "0") == "1")
    return ParamsDAG(P, parse(Int, c["k"]))
end

struct CasoLeido
    n::Int
    nombre::String
    punto::Int
    k::Int
    semilla::String
    param::Dict{String,String}
    pow_bloques::Vector{Transicion.Bloque}
    post_bloques::Vector{BloquePost}
    res::Dict{Int,String}
    desc::Vector{String}
    sel::Int
    utxo::Vector{String}
    gar::Vector{String}
    est::String
end

function parsear_fichero(ruta::AbstractString)
    casos = CasoLeido[]
    n = 0; nombre = ""; punto = 0; k = 0; semilla = ""
    param = Dict{String,String}()
    pow = Transicion.Bloque[]
    post = BloquePost[]
    res = Dict{Int,String}()
    desc = String[]
    sel = -1
    utxo = String[]; gar = String[]; est = ""
    pendiente = nothing
    txs = Transicion.Tx[]
    en_caso = false
    for linea in eachline(ruta)
        startswith(linea, "#") && continue
        isempty(strip(linea)) && continue
        primera = split(linea)[1]
        if primera == "CASO"
            c = campos(linea)
            n = parse(Int, c["n"]); nombre = c["nombre"]
            punto = parse(Int, c["punto"]); k = parse(Int, c["k"])
            semilla = c["semilla"]
            param = Dict{String,String}(); pow = Transicion.Bloque[]
            post = BloquePost[]; res = Dict{Int,String}(); desc = String[]
            sel = -1; utxo = String[]; gar = String[]; est = ""
            txs = Transicion.Tx[]; pendiente = nothing; en_caso = true
        elseif primera == "PARAM"
            param = campos(linea)
        elseif primera == "BLOQUE"
            pendiente = campos(linea)
            txs = Transicion.Tx[]
        elseif primera == "TX"
            push!(txs, parsear_tx(linea))
        elseif primera == "RES"
            c = campos(linea)
            idb = parse(Int, c["bloque"])
            fam = FAMILIA_DE[pendiente["fam"]]
            if fam == Transicion.PoST
                padres = lista_ids(pendiente["padres"])
                push!(post, BloquePost(id = idb, padres = padres,
                                       slot = parse(Int, pendiente["slot"]),
                                       sr = parse(UInt64, pendiente["sr"]),
                                       sd = parse(UInt64, pendiente["sd"]),
                                       ident = parse(UInt64, pendiente["ident"]),
                                       productor = parse(Int, pendiente["prod"]),
                                       peso = parse(Int, pendiente["peso"]), txs = txs))
            else
                padres = lista_ids(pendiente["padres"])
                push!(pow, Transicion.Bloque(id = idb, familia = fam,
                        padre = isempty(padres) ? 0 : padres[1],
                        altura = parse(Int, pendiente["altura"]),
                        trabajo = parse(Int, pendiente["trabajo"]),
                        pow_ok = pendiente["pow_ok"] == "1",
                        slot = 0, productor = 0, sector = 0, peso = 0,
                        requisito_declarado = 0, txs = txs))
            end
            res[idb] = c["res"]
            pendiente = nothing
        elseif primera == "DESC"
            push!(desc, linea)
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
            push!(casos, CasoLeido(n, nombre, punto, k, semilla, param, pow, post,
                                   res, desc, sel, utxo, gar, est))
            en_caso = false
        else
            error("línea desconocida: $linea")
        end
    end
    return casos
end

# --- reejecución ------------------------------------------------------------

function verificar_caso(caso::CasoLeido, discrepancias::Vector{String})
    pd = parsear_params(caso.param)
    isempty(caso.pow_bloques) && (push!(discrepancias, "caso $(caso.n): sin prefijo PoW"); return)
    idT = caso.pow_bloques[end].id
    A = Admision(pd, caso.pow_bloques, idT)
    resolver!(A, caso.post_bloques)
    # RES
    for b in caso.pow_bloques
        esp = get(caso.res, b.id, "<falta>")
        esp == "OK" || push!(discrepancias, "RES PoW caso=$(caso.n) bloque=$(b.id) esperado=$esp")
    end
    for b in caso.post_bloques
        esp = get(caso.res, b.id, "<falta>")
        obt = get(A.validos, b.id, false) ? "OK" : string(get(A.motivos, b.id, :ErrSinPadre))
        esp == obt || push!(discrepancias,
            "RES caso=$(caso.n) bloque=$(b.id) esperado=$esp obtenido=$obt")
    end
    # DESC + SEL + estado
    S, _, desc = aplicar_historia(A)
    obtenidos = String[string("DESC bloque=", idb, " tx=", itx, " motivo=", err)
                        for (idb, itx, err) in desc]
    obtenidos == caso.desc || push!(discrepancias,
        "DESC caso=$(caso.n) esperado=$(caso.desc) obtenido=$obtenidos")
    tips = tips_validas(A)
    sp = isempty(tips) ? -1 : mejor_punta(A, tips)
    sp == caso.sel || push!(discrepancias,
        "SEL caso=$(caso.n) esperado=$(caso.sel) obtenido=$sp")
    r_utxo(S) == caso.utxo || push!(discrepancias, "UTXO caso=$(caso.n)")
    r_gar(S) == caso.gar || push!(discrepancias, "GAR caso=$(caso.n)")
    r_est(S) == caso.est || push!(discrepancias,
        "EST caso=$(caso.n) esperado=$(caso.est) obtenido=$(r_est(S))")
    # I-1 y undo
    invariante_I1(S) || push!(discrepancias, "I-1 caso=$(caso.n)")
    for (idb, val) in A.validos
        val || continue
        E = A.past[idb]
        b = A.por_id[idb]
        _, undo = aplicar_fusion_con_undo(A, E, b, b.slot)
        hash_canonico(undo) == hash_canonico(E) ||
            push!(discrepancias, "undo caso=$(caso.n) bloque=$idb")
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
