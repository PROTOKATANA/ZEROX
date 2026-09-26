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

"""
Historia DAG aleatoria: prefijo PoW con terminal + `npost` bloques PoST con ≤3
padres. Las transacciones se construyen contra `post[padre]` (por lo que suelen
validar; si un bloque fusionado consume la misma salida, el oráculo la descarta).
Devuelve la `Admision` ya resuelta.
"""
function generar_dag_aleatorio(rng::AbstractRNG, pd::ParamsDAG;
                               npost::Int = 8, p_tx::Float64 = 0.5,
                               p_invalido::Float64 = 0.12)
    P = pd.P
    pow = generar_pow_terminal(rng, P)
    A = _admision_desde_pow(pd, pow)
    ids = Int[]                 # todos los ids PoST creados
    validos = Int[]             # ids PoST válidos
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
        # Transacción opcional contra un padre válido.
        if rand(rng) < p_tx && !isempty(validos)
            pv = validos[rand(rng, 1:length(validos))]
            S = A.post[pv]
            gastables = Transicion.Salida[]
            for (_, o) in S.utxo
                if o.valor >= UInt64(2) && Transicion.gastable(S, o, P, slot)
                    push!(gastables, o)
                end
            end
            if !isempty(gastables)
                o = gastables[rand(rng, 1:length(gastables))]
                if rand(rng) < 0.5
                    push!(txs, Transicion.tx_transferencia([o.id],
                          [Transicion.Salida(out_id, o.valor - UInt64(1), rand(rng, 1:3),
                                             Transicion.OrigenTx, -1, -1)], o.dueño))
                    out_id += 1
                else
                    push!(txs, Transicion.tx_deposito([o.id], o.dueño, o.valor, o.dueño))
                end
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
