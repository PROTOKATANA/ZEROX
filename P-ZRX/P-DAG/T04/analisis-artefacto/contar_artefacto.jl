# contar_artefacto.jl — T04-D: cuenta el artefacto de ids de la liberación.
#
#   julia --project=. analisis-artefacto/contar_artefacto.jl
#
# Relee los vectores con un oráculo propio (módulo parametrizado) y cuenta, con la
# instrumentación de `crear_utxos!`, cuántas transacciones se descartan porque la
# salida de una transferencia choca con una salida ya existente de una liberación.
#   * v0.2 con el T01 viejo (`prox_salida`)  -> artefacto real;
#   * v0.3 con el T01 actual (F-18)          -> debe ser 0.
# No modifica ningún fichero.

include(joinpath(@__DIR__, "EstadoDAGViejo.jl"))
include(joinpath(@__DIR__, "EstadoDAGNuevo.jl"))

# --- analizador independiente (parametrizado por módulo) --------------------

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

function parsear_salidas(T, s::AbstractString)
    interior = s[findfirst('[', s)+1:findlast(']', s)-1]
    isempty(interior) && return T.Salida[]
    out = T.Salida[]
    for it in split(interior, ",")
        p = split(it, ":")
        push!(out, T.Salida(parse(Int, p[1]), parse(UInt64, p[2]), parse(Int, p[3]),
                            T.OrigenTx, -1, -1))
    end
    return out
end

function parsear_entradas(s::AbstractString)
    interior = s[findfirst('[', s)+1:findlast(']', s)-1]
    isempty(interior) && return Int[]
    return [parse(Int, x) for x in split(interior, ",")]
end

function parsear_tx(T, linea::AbstractString)
    c = campos(linea)
    tipo = c["tipo"]
    firmante = parse(Int, c["firmante"])
    clave = parse(Int, c["clave"])
    importe = parse(UInt64, c["importe"])
    ent = parsear_entradas(c["ent"])
    sal = parsear_salidas(T, c["sal"])
    nonce = haskey(c, "nonce") ? parse(UInt64, c["nonce"]) : UInt64(0)
    if tipo == "Coinbase"
        return T.tx_coinbase(sal)
    elseif tipo == "CoinbasePost"
        return T.tx_coinbase_post(importe)
    elseif tipo == "Transferencia"
        return T.tx_transferencia(ent, sal, firmante)
    elseif tipo == "Deposito"
        return T.tx_deposito(ent, clave, importe, firmante; nonce = nonce)
    elseif tipo == "Retiro"
        return T.tx_retiro(clave, importe, firmante; nonce = nonce)
    elseif tipo == "Liberacion"
        return T.tx_liberacion(clave, importe, firmante; nonce = nonce)
    elseif tipo == "Evidencia"
        return T.tx_evidencia(clave)
    end
    error("tipo de tx no releíble: $tipo")
end

function parsear_params(M, c::Dict{String,String})
    T = M.Transicion
    f = c["F_slots"] == "inf" ? typemax(Int) : parse(Int, c["F_slots"])
    P = T.Params(H_dep = parse(Int, c["H_dep"]), M_cb = parse(Int, c["M_cb"]),
                 M_dep = parse(Int, c["M_dep"]), H_corte_min = parse(Int, c["H_corte_min"]),
                 W_min = parse(Int, c["W_min"]), S_min = parse(Int, c["S_min"]),
                 K_min = parse(Int, c["K_min"]), q = parse(Int, c["q"]),
                 M_res_slots = parse(Int, c["M_res_slots"]),
                 M_dep_slots = parse(Int, c["M_dep_slots"]),
                 M_rec_slots = parse(Int, c["M_rec_slots"]),
                 R_slots = parse(Int, c["R_slots"]), F_slots = f,
                 sec = T.SEC0, corte = T.CUT_HWPhi, seleccion = T.FC3)
    return M.ParamsDAG(P, parse(Int, c["k"]))
end

struct CasoLeido
    n::Int
    pd::Any
    pow::Vector{Any}
    post::Vector{Any}
    desc::Vector{String}
    sel::Int
end

function parsear_fichero(M, ruta::AbstractString)
    T = M.Transicion
    casos = CasoLeido[]
    n = 0; pd = nothing; sel = -1
    pow = Any[]; post = Any[]; desc = String[]
    pendiente = nothing; txs = T.Tx[]
    en_caso = false
    for linea in eachline(ruta)
        (startswith(linea, "#") || isempty(strip(linea))) && continue
        primera = split(linea)[1]
        if primera == "CASO"
            c = campos(linea); n = parse(Int, c["n"])
            pd = nothing; pow = Any[]; post = Any[]; desc = String[]; sel = -1
            txs = T.Tx[]; pendiente = nothing; en_caso = true
        elseif primera == "PARAM"
            pd = parsear_params(M, campos(linea))
        elseif primera == "BLOQUE"
            pendiente = campos(linea); txs = T.Tx[]
        elseif primera == "TX"
            push!(txs, parsear_tx(T, linea))
        elseif primera == "RES"
            c = campos(linea); idb = parse(Int, c["bloque"])
            fam = pendiente["fam"]
            padres = lista_ids(pendiente["padres"])
            if fam == "PoST"
                push!(post, M.BloquePost(id = idb, padres = padres,
                       slot = parse(Int, pendiente["slot"]),
                       sr = parse(UInt64, pendiente["sr"]),
                       sd = parse(UInt64, pendiente["sd"]),
                       ident = parse(UInt64, pendiente["ident"]),
                       productor = parse(Int, pendiente["prod"]),
                       peso = parse(Int, pendiente["peso"]), txs = txs))
            else
                famv = fam == "Genesis" ? T.Genesis : T.PoW
                push!(pow, T.Bloque(id = idb, familia = famv,
                       padre = isempty(padres) ? 0 : padres[1],
                       altura = parse(Int, pendiente["altura"]),
                       trabajo = parse(Int, pendiente["trabajo"]),
                       pow_ok = pendiente["pow_ok"] == "1",
                       slot = 0, productor = 0, sector = 0, peso = 0,
                       requisito_declarado = 0, txs = txs))
            end
            pendiente = nothing
        elseif primera == "DESC"
            push!(desc, linea)
        elseif primera == "SEL"
            sel = parse(Int, campos(linea)["punta"])
        elseif primera == "FIN"
            en_caso || continue
            push!(casos, CasoLeido(n, pd, pow, post, desc, sel))
            en_caso = false
        end
    end
    return casos
end

# --- recuento ---------------------------------------------------------------

function contar(M, ruta::AbstractString)
    T = M.Transicion
    casos = parsear_fichero(M, ruta)
    total = Ref(0)                 # colisiones salida-transferencia vs liberación
    desc_tx = Ref(0)               # DESC ErrDobleGasto en Transferencia
    disc_desc = Ref(0)             # discrepancias en las líneas DESC
    disc_sel = Ref(0)
    for caso in casos
        pd = caso.pd
        idT = caso.pow[end].id
        A = M.Admision(pd, T.Bloque[caso.pow...], idT)
        M.resolver!(A, M.BloquePost[caso.post...])
        T.COLISION_LIB_TX[] = 0
        _, _, desc = M.aplicar_historia(A)
        total[] += T.COLISION_LIB_TX[]
        # descartes de transferencia con ErrDobleGasto
        for (idb, itx, err) in desc
            if err == T.ErrDobleGasto
                b = A.por_id[idb]
                b.txs[itx].tipo == T.TxTransferencia && (desc_tx[] += 1)
            end
        end
        # contraste con el DESC exportado
        obtenidos = String[string("DESC bloque=", idb, " tx=", itx, " motivo=", err)
                            for (idb, itx, err) in desc]
        obtenidos == caso.desc || (disc_desc[] += 1)
        tips = M.tips_validas(A)
        sp = isempty(tips) ? -1 : M.mejor_punta(A, tips)
        sp == caso.sel || (disc_sel[] += 1)
    end
    return (casos = length(casos), colisiones = total[], desc_tx = desc_tx[],
            disc_desc = disc_desc[], disc_sel = disc_sel[])
end

const DIR = joinpath(@__DIR__, "..", "resultados")
const V02 = joinpath(DIR, "vectores-estado-dag-v0.2.txt")
const V03 = joinpath(DIR, "vectores-estado-dag-v0.3.txt")

println("== v0.2 con T01 viejo (prox_salida) ==")
r2 = contar(Main.EstadoDAGViejo, V02)
println(r2)
if isfile(V03)
    println("== v0.3 con T01 actual (F-18) ==")
    r3 = contar(Main.EstadoDAGNuevo, V03)
    println(r3)
else
    println("(v0.3 aún no existe: ", V03, ")")
end
