# T04 — generadores de historias DAG y conversiones. Solo para pruebas y vectores.

"Peso PoST → `sr` arbitrario (el peso GHOSTDAG no entra en el estado; IE-5 usa `peso`)."
sr_peso(::Integer) = typemax(UInt64)

"Convierte un `Bloque` de T01 en `BloquePost` (cadena de un solo padre)."
bl_desde_post(b::Transicion.Bloque) =
    BloquePost(id = b.id, padres = [b.padre], slot = b.slot, sr = typemax(UInt64),
               sd = 0, ident = 0, productor = b.productor, peso = max(b.peso, 1),
               txs = b.txs)

"Convierte una lista de `Bloque` PoST de T01 en `BloquePost`."
bloques_desde_post(bs::Vector{Transicion.Bloque}) = BloquePost[bl_desde_post(b) for b in bs]

"""
Prefijo PoW válido hasta un terminal, con depósitos (garantía para las claves 1 y 2).
Devuelve `(bloques, estados, next_id, out_id, prod)` de T01.
"""
function generar_pow_terminal(rng::AbstractRNG, P::Transicion.Params;
                              hasta::Int = 0, transferir::Bool = false)
    h = hasta > 0 ? hasta : max(P.H_corte_min, 4) + 6
    out = Transicion.construir_poW(rng, P; hasta = h, depositar = true,
                                   alta_en = -1, prueba_en = -1, transferir = transferir)
    E = out[2][end]
    E.terminal == -1 && error("el prefijo PoW no alcanzó terminal (hasta=$h)")
    return out
end

"Construye una `Admision` a partir del prefijo PoW."
function _admision_desde_pow(pd::ParamsDAG, pow)
    idT = pow[1][end].id
    return Admision(pd, pow[1], idT)
end

# --- operaciones de garantía del generador (ORDEN-T04-C §1.2) ----------------

"Pesos de partida por tipo (transferencia / depósito / retiro / liberación)."
const PESO_TRANSFERENCIA = 0.35
const PESO_DEPOSITO = 0.30
const PESO_RETIRO = 0.20
const PESO_LIBERACION = 0.15
const P_ERROR_NONCE = 0.10

"""
Pesos ajustados de T04-C. Los de partida (0,35/0,30/0,20/0,15) no alcanzaban el
mínimo de liberaciones aplicadas; se sesga hacia retiro/liberación (el generador
solo elige entre los tipos factibles, así que el sesgo no inventa factibilidad).
"""
const PESOS_AJUSTADOS = (0.12, 0.18, 0.22, 0.48)

"`npost` de los vectores v0.2 y de `run.jl`: 15…16 (el tope es 16)."
npost_t04c(r::Int) = 15 + (r % 2)

"Elige un índice de `pesos` (no todos cero) proporcionalmente a su valor."
function elegir_ponderado(rng::AbstractRNG, pesos::Vector{Float64})
    total = sum(pesos)
    x = rand(rng) * total
    acc = 0.0
    for i in eachindex(pesos)
        acc += pesos[i]
        x <= acc && return i
    end
    return length(pesos)
end

"Importe vencido de una garantía en un `slot`, con la regla de `aplicar_liberacion!`."
function vencido_en(g::Transicion.Garantia, slot::Int, P::Transicion.Params)
    v = UInt64(0)
    for r in g.en_retirada
        r.inicio_slot + P.R_slots <= slot && (v += r.importe)
    end
    return v
end

"""
Nonce de una operación de garantía contra `S`: `nonce_de(S, clave)` con un 10 %
de error deliberado (`n+1`, o `n-1` si `n > 0` al 50 %). Se compara contra el
estado en el que se construye, como exige la orden.
"""
function nonce_operacion(rng::AbstractRNG, S::Transicion.Estado, clave::Int)
    n = Transicion.nonce_de(S, clave)
    if rand(rng) < P_ERROR_NONCE
        n > 0 && rand(rng) < 0.5 && return n - UInt64(1)
        return n + UInt64(1)
    end
    return n
end

"""
Construye **una** operación opcional (transferencia, depósito, retiro o
liberación) contra `S = A.post[pv]`, entre las factibles en `S` y el `slot` del
bloque nuevo, con los pesos recibidos. Devuelve `(tx, out_id)` o `nothing` si
ninguna es factible. `out_id` se conserva para las salidas de transferencia.
"""
function operacion_aleatoria(rng::AbstractRNG, S::Transicion.Estado,
                             P::Transicion.Params, slot::Int, out_id::Int;
                             pesos = (PESO_TRANSFERENCIA, PESO_DEPOSITO,
                                      PESO_RETIRO, PESO_LIBERACION))
    gastables = Transicion.Salida[]
    for (_, o) in S.utxo
        if o.valor >= UInt64(2) && Transicion.gastable(S, o, P, slot)
            push!(gastables, o)
        end
    end
    claves_retiro = Int[]
    claves_lib = Int[]
    for (k, g) in S.garantias
        g.activo > 0 && isempty(g.en_retirada) && push!(claves_retiro, k)
        vencido_en(g, slot, P) > 0 && push!(claves_lib, k)
    end
    sort!(claves_retiro)
    sort!(claves_lib)
    pesos = Float64[isempty(gastables) ? 0.0 : pesos[1],
                    isempty(gastables) ? 0.0 : pesos[2],
                    isempty(claves_retiro) ? 0.0 : pesos[3],
                    isempty(claves_lib) ? 0.0 : pesos[4]]
    sum(pesos) <= 0.0 && return nothing
    idx = elegir_ponderado(rng, pesos)
    if idx == 1
        o = gastables[rand(rng, 1:length(gastables))]
        salida = Transicion.Salida(out_id, o.valor - UInt64(1), rand(rng, 1:3),
                                   Transicion.OrigenTx, -1, -1)
        return (tx = Transicion.tx_transferencia([o.id], [salida], o.dueño),
                out_id = out_id + 1)
    elseif idx == 2
        o = gastables[rand(rng, 1:length(gastables))]
        k = o.dueño
        return (tx = Transicion.tx_deposito([o.id], k, o.valor, k;
                                            nonce = nonce_operacion(rng, S, k)),
                out_id = out_id)
    elseif idx == 3
        k = claves_retiro[rand(rng, 1:length(claves_retiro))]
        g = S.garantias[k]
        importe = rand(rng, UInt64(1):g.activo)
        return (tx = Transicion.tx_retiro(k, importe, k;
                                         nonce = nonce_operacion(rng, S, k)),
                out_id = out_id)
    else
        k = claves_lib[rand(rng, 1:length(claves_lib))]
        g = S.garantias[k]
        vencido = vencido_en(g, slot, P)
        importe = rand(rng, UInt64(1):vencido)
        return (tx = Transicion.tx_liberacion(k, importe, k;
                                              nonce = nonce_operacion(rng, S, k)),
                out_id = out_id)
    end
end

"""
Evidencia aleatoria (SL-3) contra `S`. `modo` selecciona la variante: válida,
`cbid` ajeno, fuera de plazo, clave sin saldo o una clave con saldo. SL-4c-O
añadió `:ambos` (las dos anteriores). SL-4c-O-B distingue los **dos tipos** de
orden no canónico: `:orden_igual` (`pre_hash(H1) = pre_hash(H2)`) y
`:orden_desc` (`pre_hash(H1) > pre_hash(H2)`), más `:ambos_desc` (cbid ajeno +
orden descendente). Con `:ambos`/`:ambos_desc` gana `cbid` por la precedencia.
"""
function evidencia_aleatoria(rng::AbstractRNG, S::Transicion.Estado,
                             P::Transicion.Params, slot::Int; modo::Symbol = :valida)
    c = P.cbid
    k = 1
    s = slot
    if modo == :cbid || modo == :ambos || modo == :ambos_desc
        c = P.cbid + 1
    elseif modo == :tardia
        s = slot - P.Plazo_slots
    elseif modo == :sin_saldo
        k = 99
    elseif modo == :clave
        ks = sort(collect(keys(S.garantias)))
        isempty(ks) || (k = ks[rand(rng, 1:length(ks))])
    end
    es_igual = modo == :orden_igual || modo == :ambos
    r1 = rand(rng, UInt64)
    r2 = rand(rng, UInt64)
    if es_igual
        r2 = r1                       # H1 = H2 ⇒ el orden estricto no se cumple
    elseif r1 == r2
        r2 = r1 + UInt64(1)
    end
    lo, hi = min(r1, r2), max(r1, r2)
    # `:orden_desc` / `:ambos_desc` invierten el par para que `pre_hash(H1) > pre_hash(H2)`.
    descendente = modo == :orden_desc || modo == :ambos_desc
    ev = descendente ? Transicion.evidencia(c, k, 0, 0, 0, s, hi, lo) :
                       Transicion.evidencia(c, k, 0, 0, 0, s, lo, hi)
    return Transicion.tx_evidencia(ev)
end

"""
Historia DAG aleatoria: prefijo PoW con terminal + `npost` bloques PoST con ≤3
padres. Las transacciones se construyen contra `post[padre]` (por lo que suelen
validar; si un bloque fusionado consume la misma salida, el oráculo la descarta).
El tipo se elige entre los factibles en `S` (transferencia, depósito, retiro,
liberación) con los pesos de la orden, y el nonce es el del estado contra el que
se construye, con un 10 % de error deliberado. Con `P.evp`, además inyecta
`EvidenceTx` (SL-3) con probabilidad `p_ev`. Devuelve la `Admision` resuelta.
"""
function generar_dag_aleatorio(rng::AbstractRNG, pd::ParamsDAG;
                               npost::Int = 8, p_tx::Float64 = 0.5,
                               p_invalido::Float64 = 0.12, p_ev::Float64 = 0.12,
                               p_dup::Float64 = 0.50,
                               pesos = (PESO_TRANSFERENCIA, PESO_DEPOSITO,
                                        PESO_RETIRO, PESO_LIBERACION))
    P = pd.P
    pow = generar_pow_terminal(rng, P)
    A = _admision_desde_pow(pd, pow)
    ids = Int[]                 # todos los ids PoST creados
    validos = Int[]             # ids PoST válidos
    evidencias = Transicion.Evidencia[]  # SL-3: evidencias ya emitidas (duplicados)
    next_id = pow[3]
    out_id = pow[4]
    ident_pendiente = UInt64(0)
    ident_padres = Int[]
    ident_slot = 0
    for i in 1:npost
        ident = UInt64(0)
        usar_hermano = ident_pendiente != 0
        if usar_hermano
            padres = copy(ident_padres)
            slot = ident_slot
            ident = ident_pendiente
        else
            if i == 1
                padres = [A._id_T]
            else
                cand = copy(ids)
                isempty(cand) && (cand = [A._id_T])
                np = min(length(cand), rand(rng, 1:3))
                padres = Int[]
                while length(padres) < np
                    p = cand[rand(rng, 1:length(cand))]
                    p in padres && continue
                    push!(padres, p)
                end
            end
            slot = if i == 1
                rand(rng, 1:2)
            else
                punto = maximum(A.por_id[p].slot for p in padres)
                punto + rand(rng, 0:2)
            end
            # Hermano con el mismo billete (U3 dinámica) en el bloque siguiente.
            if rand(rng) < 0.15 && i < npost
                ident = UInt64(next_id)
                ident_pendiente = ident
                ident_padres = copy(padres)
                ident_slot = slot
            end
        end
        sr = rand(rng, (UInt64(0), UInt64(1), typemax(UInt64) - 1, typemax(UInt64)))
        sd = UInt64(rand(rng, 0:1_000_000))
        productor = rand(rng) < p_invalido ? 99 : (rand(rng) < 0.85 ? 1 : 2)
        sub = Transicion.subsidio_post(slot, P)
        declarado = rand(rng) < 0.5 ? sub : sub + UInt64(rand(rng, 0:3))
        txs = Transicion.Tx[Transicion.tx_coinbase_post(declarado)]
        # Una operación opcional contra un padre válido, entre las factibles en S.
        if rand(rng) < p_tx && !isempty(validos)
            pv = validos[rand(rng, 1:length(validos))]
            S = A.post[pv]
            op = operacion_aleatoria(rng, S, P, slot, out_id; pesos = pesos)
            if op !== nothing
                push!(txs, op.tx)
                out_id = op.out_id
            end
        end
        # SL-3: evidencia aleatoria (solo con C-EVP activo). Con probabilidad
        # `p_dup` se reemite una evidencia anterior para cubrir EV-12.
        if P.evp && !isempty(validos) && rand(rng) < p_ev
            pv = validos[rand(rng, 1:length(validos))]
            S = A.post[pv]
            if !isempty(evidencias) && rand(rng) < p_dup
                push!(txs, Transicion.tx_evidencia(evidencias[rand(rng, 1:length(evidencias))]))
            else
                # SL-4c-O / SL-4c-O-B: `:orden_igual`/`:orden_desc` (los dos
                # tipos de orden no canónico) y `:ambos`/`:ambos_desc`.
                modo = rand(rng, (:valida, :valida, :clave, :cbid, :orden_igual,
                                  :orden_desc, :tardia, :sin_saldo, :ambos,
                                  :ambos_desc))
                txev = evidencia_aleatoria(rng, S, P, slot; modo = modo)
                push!(txs, txev)
                txev.evidencia !== nothing && push!(evidencias, txev.evidencia)
            end
        end
        b = BloquePost(id = next_id, padres = padres, slot = slot, sr = sr, sd = sd,
                       ident = ident, productor = productor, peso = 1, txs = txs)
        next_id += 1
        r = procesar_uno!(A, b)
        push!(ids, b.id)
        r == :OK && push!(validos, b.id)
        usar_hermano && (ident_pendiente = UInt64(0))
    end
    return A
end

"""
Cadena PoST para IE-5: usa `Transicion.cadena_post` (T01, sin fusiones) y
devuelve `(pow, bloques_post, estado_final_T01)`.
"""
function generar_cadena_post(rng::AbstractRNG, P::Transicion.Params; npost::Int = 4)
    pow = generar_pow_terminal(rng, P)
    E = pow[2][end]
    post, Efin, _ = Transicion.cadena_post(P, E, pow[3], pow[1][end].id, npost;
                                          peso = 1, productor = 1, sector = 0)
    return pow, bloques_desde_post(post), Efin
end

"Historia sin fusiones (cadena) como `Vector{BloquePost}` con ids únicos."
function cadena_sin_fusiones(rng::AbstractRNG, pd::ParamsDAG; npost::Int = 4)
    pow, bps, Efin = generar_cadena_post(rng, pd.P; npost = npost)
    A = Admision(pd, pow[1], pow[1][end].id)
    resolver!(A, bps)
    return A, Efin
end

# ---------------------------------------------------------------------------
# Cobertura por tipo de operación (ORDEN-T04-C §2)
# ---------------------------------------------------------------------------

"Tipos de transacción de la tabla de cobertura (no incluye coinbases)."
const TIPOS_COBERTURA = (Transicion.TxTransferencia, Transicion.TxDeposito,
                         Transicion.TxRetiro, Transicion.TxLiberacion)
"Tipos de operación de garantía (denominador del tope de `ErrNonce`)."
const TIPOS_GARANTIA = (Transicion.TxDeposito, Transicion.TxRetiro,
                        Transicion.TxLiberacion)
"Nombres de los tipos en la tabla de cobertura."
const NOMBRE_TIPO_COBERTURA =
    Dict(Transicion.TxTransferencia => "Transferencia",
         Transicion.TxDeposito => "Deposito", Transicion.TxRetiro => "Retiro",
         Transicion.TxLiberacion => "Liberacion")

"""
Acumulador de la tabla de cobertura. `construidas` = operaciones construidas por
el generador en cualquier bloque PoST; `aplicadas` y `descartes` por motivo se
miden en `Estado` de la punta seleccionada final; `reorgs_garantia` = número de
reorganizaciones que deshacen al menos una operación de garantía aplicada.
"""
mutable struct AcumuladorCobertura
    construidas::Dict{Transicion.TipoTx,Int}
    aplicadas::Dict{Transicion.TipoTx,Int}
    descartes::Dict{Transicion.TipoTx,Dict{Transicion.Err,Int}}
    reorgs_garantia::Int
    casos::Int
end

function AcumuladorCobertura()
    v = () -> Dict{Transicion.TipoTx,Int}(t => 0 for t in TIPOS_COBERTURA)
    d = () -> Dict{Transicion.TipoTx,Dict{Transicion.Err,Int}}(
        t => Dict{Transicion.Err,Int}() for t in TIPOS_COBERTURA)
    return AcumuladorCobertura(v(), v(), d(), 0, 0)
end

"Conjunto de operaciones de garantía aplicadas en `Estado` de la punta final."
function operaciones_garantia_aplicadas(A::Admision)
    _, orden, desc = aplicar_historia(A)
    descartadas = Set{Tuple{Int,Int}}()
    for (idb, itx, _) in desc
        push!(descartadas, (idb, itx))
    end
    ops = Set{Tuple{Int,Int}}()
    for bid in orden
        b = A.por_id[bid]
        for (i, tx) in enumerate(b.txs)
            tx.tipo in TIPOS_GARANTIA || continue
            (bid, i) in descartadas || push!(ops, (bid, i))
        end
    end
    return ops
end

"""
Reorganizaciones que deshacen al menos una operación de garantía aplicada.
Reprocesa los bloques en orden de `id` (orden de generación, topológico) sobre
una `Admision` nueva y, tras cada bloque, compara la punta seleccionada y el
conjunto de operaciones de garantía aplicadas en su `Estado`.
"""
function reorgs_que_deshacen_garantia(A::Admision)
    A2 = Admision(A.pd, A.pow_bloques, A._id_T)
    bloques = sort(collect(values(A.por_id)); by = b -> b.id)
    prev_tip = A._id_T
    prev_ops = Set{Tuple{Int,Int}}()
    reorgs = 0
    for b in bloques
        b.id in A2.procesados && continue
        procesar_uno!(A2, b)
        tips = tips_validas(A2)
        isempty(tips) && continue
        tip = mejor_punta(A2, tips)
        tip == prev_tip && continue
        ops = operaciones_garantia_aplicadas(A2)
        isempty(setdiff(prev_ops, ops)) || (reorgs += 1)
        prev_tip = tip
        prev_ops = ops
    end
    return reorgs
end

"¿Contiene `A` alguna `EvidenceTx` en algún bloque PoST?"
function _hay_evidencia(A::Admision)
    for b in values(A.por_id)
        for tx in b.txs
            tx.tipo == Transicion.TxEvidencia && return true
        end
    end
    return false
end

"Conjunto `(idBloque, índiceTx)` de evidencias aplicadas en la historia seleccionada."
function evidencias_aplicadas(A::Admision)
    _, orden, desc = aplicar_historia(A)
    descartadas = Set{Tuple{Int,Int}}((idb, itx) for (idb, itx, _) in desc)
    ops = Set{Tuple{Int,Int}}()
    for bid in orden
        b = A.por_id[bid]
        for (i, tx) in enumerate(b.txs)
            tx.tipo == Transicion.TxEvidencia || continue
            (bid, i) in descartadas || push!(ops, (bid, i))
        end
    end
    return ops
end

"""
Evidencias **aplicadas en algún estado y luego deshechas por una reorganización**
(EV-27/EV-28): se reprocesa la historia en orden de `id` sobre una `Admision`
nueva y, tras cada bloque que cambia la punta seleccionada, se cuentan las
evidencias que estaban aplicadas en la historia anterior y ya no lo están. No
cuenta el undo exacto de un bloque que sigue en la cadena seleccionada. Devuelve
el conjunto de pares `(idBloque, índiceTx)`.
"""
function evidencias_deshechas_por_reorg(A::Admision)
    _hay_evidencia(A) || return Set{Tuple{Int,Int}}()
    A2 = Admision(A.pd, A.pow_bloques, A._id_T)
    bloques = sort(collect(values(A.por_id)); by = b -> b.id)
    prev_tip = A._id_T
    prev_ev = Set{Tuple{Int,Int}}()
    deshechas = Set{Tuple{Int,Int}}()
    for b in bloques
        b.id in A2.procesados && continue
        procesar_uno!(A2, b)
        tips = tips_validas(A2)
        isempty(tips) && continue
        tip = mejor_punta(A2, tips)
        ev = evidencias_aplicadas(A2)
        if tip != prev_tip
            for x in setdiff(prev_ev, ev)
                push!(deshechas, x)
            end
        end
        prev_tip = tip
        prev_ev = ev
    end
    return deshechas
end

"Acumula la cobertura de una historia `A` en `ac`."
function acumular_caso!(ac::AcumuladorCobertura, A::Admision)
    for b in values(A.por_id)
        for tx in b.txs
            tx.tipo in TIPOS_COBERTURA && (ac.construidas[tx.tipo] += 1)
        end
    end
    _, orden, desc = aplicar_historia(A)
    descartes = Dict{Tuple{Int,Int},Transicion.Err}()
    for (idb, itx, err) in desc
        descartes[(idb, itx)] = err
    end
    for bid in orden
        b = A.por_id[bid]
        for (i, tx) in enumerate(b.txs)
            tx.tipo in TIPOS_COBERTURA || continue
            if haskey(descartes, (bid, i))
                err = descartes[(bid, i)]
                ac.descartes[tx.tipo][err] = get(ac.descartes[tx.tipo], err, 0) + 1
            else
                ac.aplicadas[tx.tipo] += 1
            end
        end
    end
    ac.reorgs_garantia += reorgs_que_deshacen_garantia(A)
    ac.casos += 1
    return ac
end

"""
Cobertura de la batería `run.jl` con sus valores por defecto (mismos casos que
`run.jl --seed 0x5a5a --replicas 200`). La usa `exportar.jl` para el apartado
`run.jl` de `resultados/cobertura-v0.5.txt`.
"""
function cobertura_run(; seed::UInt64 = UInt64(0x5a5a), replicas::Int = 200)
    ac = AcumuladorCobertura()
    for (pi, k) in PUNTOS_T04
        pd = ParamsDAG(PARAMS_DAG_BASE[pi], k)
        for r in 1:replicas
            rng = StableRNG(seed + UInt64(10_000 * pi + r))
            A = generar_dag_aleatorio(rng, pd; npost = npost_t04c(r),
                                      pesos = PESOS_AJUSTADOS)
            acumular_caso!(ac, A)
        end
    end
    return ac
end

"Motivos que la tabla de cobertura publica por separado, en este orden."
const MOTIVOS_COBERTURA = (Transicion.ErrNonce, Transicion.ErrDobleGasto,
                           Transicion.ErrSaldo, Transicion.ErrRetiroPendiente,
                           Transicion.ErrAutorizacion, Transicion.ErrInmaduro,
                           Transicion.ErrOperacionFase, Transicion.ErrEmision)

"Escribe un apartado de la tabla de cobertura (una línea por tipo + resumen)."
function escribir_cobertura(io::IO, titulo::AbstractString, ac::AcumuladorCobertura)
    println(io, "SECCION ", titulo)
    println(io, "casos = ", ac.casos)
    for t in TIPOS_COBERTURA
        dtot = sum(values(ac.descartes[t]); init = 0)
        motivos = join([string(m, "=", get(ac.descartes[t], m, 0))
                        for m in MOTIVOS_COBERTURA], " ")
        conocidos = sum(get(ac.descartes[t], m, 0) for m in MOTIVOS_COBERTURA)
        evaluadas = ac.aplicadas[t] + dtot
        println(io, "TIPO ", NOMBRE_TIPO_COBERTURA[t],
                " construidas=", ac.construidas[t],
                " aplicadas=", ac.aplicadas[t],
                " descartadas=", dtot,
                " evaluadas=", evaluadas,
                " en_ramas_no_seleccionadas=", ac.construidas[t] - evaluadas,
                " ", motivos,
                " otros=", dtot - conocidos)
    end
    cons_gar = sum(ac.construidas[t] for t in TIPOS_GARANTIA)
    eval_gar = sum(ac.aplicadas[t] + sum(values(ac.descartes[t]); init = 0)
                   for t in TIPOS_GARANTIA)
    errnonce = sum(get(ac.descartes[t], Transicion.ErrNonce, 0)
                   for t in TIPOS_GARANTIA)
    doble = sum(get(ac.descartes[t], Transicion.ErrDobleGasto, 0)
                for t in TIPOS_COBERTURA)
    println(io, "garantia_construidas = ", cons_gar)
    println(io, "garantia_evaluadas = ", eval_gar)
    println(io, "garantia_errnonce = ", errnonce)
    @printf(io, "garantia_errnonce_pct_construidas = %.2f\n",
            cons_gar == 0 ? 0.0 : 100.0 * errnonce / cons_gar)
    @printf(io, "garantia_errnonce_pct_evaluadas = %.2f\n",
            eval_gar == 0 ? 0.0 : 100.0 * errnonce / eval_gar)
    println(io, "err_doble_gasto_total = ", doble)
    println(io, "reorganizaciones_que_deshacen_garantia = ", ac.reorgs_garantia)
    return nothing
end

