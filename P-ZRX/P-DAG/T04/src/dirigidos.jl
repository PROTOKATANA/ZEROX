# T04 — casos dirigidos (ORDEN-T04 §4). Cada caso construye a mano una historia
# pequeña y deja la `Admision` lista para su verificación y su exportación.

"Primer UTXO gastable (por id) con `valor ≥ minvalor` en el estado `E` al punto `punto`."
function utxo_gastable(E::Transicion.Estado, P::Transicion.Params, punto::Int, minvalor::Int = 2)
    gast = Transicion.Salida[]
    for (_, o) in E.utxo
        if o.valor >= UInt64(minvalor) && Transicion.gastable(E, o, P, punto)
            push!(gast, o)
        end
    end
    sort!(gast, by = o -> o.id)
    return isempty(gast) ? nothing : gast[1]
end

"Historia base con prefijo PoW válido y `Admision` vacía."
function base_dirigida(pd::ParamsDAG; seed::Int = 1, hasta::Int = 0)
    rng = StableRNG(seed)
    pow = generar_pow_terminal(rng, pd.P; hasta = hasta)
    A = _admision_desde_pow(pd, pow)
    return A, pow
end

cb3(P) = Transicion.tx_coinbase_post(Transicion.subsidio_post(0, P))  # placeholder, no usado

"""
D-1 · Doble gasto entre dos bloques fusionados: gana el primero en orden C-GD-05,
el otro se descarta (`ErrDobleGasto`).
"""
function caso_doble_gasto(pd::ParamsDAG; seed::Int = 11)
    A, pow = base_dirigida(pd; seed = seed)
    P = pd.P
    idT = A._id_T
    id1 = pow[3]
    Tb = BloquePost(id = id1, padres = [idT], slot = 1, productor = 1, peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, Tb)
    o = utxo_gastable(A.post[Tb.id], P, 2, 2)
    o === nothing && error("D-1: sin UTXO gastable")
    X1 = BloquePost(id = id1 + 1, padres = [Tb.id], slot = 2, sd = 0, productor = 1,
                    peso = 1, txs = Transicion.Tx[Transicion.tx_coinbase_post(3),
                    Transicion.tx_transferencia([o.id],
                        [Transicion.Salida(9001, o.valor - UInt64(1), 1,
                                           Transicion.OrigenTx, -1, -1)], o.dueño)])
    X2 = BloquePost(id = id1 + 2, padres = [Tb.id], slot = 2, sd = 1, productor = 1,
                    peso = 1, txs = Transicion.Tx[Transicion.tx_coinbase_post(3),
                    Transicion.tx_transferencia([o.id],
                        [Transicion.Salida(9002, o.valor - UInt64(1), 1,
                                           Transicion.OrigenTx, -1, -1)], o.dueño)])
    procesar_uno!(A, X1)
    procesar_uno!(A, X2)
    B = BloquePost(id = id1 + 3, padres = [X1.id, X2.id], slot = 3, productor = 1,
                   peso = 1, txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, B)
    return "D-1", A, (o_id = o.id, X1 = X1.id, X2 = X2.id, B = B.id)
end

"""
D-2 · Coinbase PoST recortada al descartar una tarifa: se acredita
`mín(declarado, subsidio + tarifas aceptadas)`.
"""
function caso_coinbase_recortada(pd::ParamsDAG; seed::Int = 12)
    A, pow = base_dirigida(pd; seed = seed)
    P = pd.P
    id1 = pow[3]
    Tb = BloquePost(id = id1, padres = [A._id_T], slot = 1, productor = 1, peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, Tb)
    o = utxo_gastable(A.post[Tb.id], P, 2, 2)
    o === nothing && error("D-2: sin UTXO gastable")
    declarado = UInt64(Transicion.subsidio_post(2, P)) + UInt64(1) + UInt64(5)  # 3+1+5
    X = BloquePost(id = id1 + 1, padres = [Tb.id], slot = 2, productor = 1, peso = 1,
                   txs = Transicion.Tx[Transicion.tx_coinbase_post(declarado),
                   Transicion.tx_transferencia([o.id],
                       [Transicion.Salida(9101, o.valor - UInt64(1), 1,
                                          Transicion.OrigenTx, -1, -1)], o.dueño),
                   Transicion.tx_transferencia([999_999],
                       [Transicion.Salida(9102, UInt64(1), 1,
                                          Transicion.OrigenTx, -1, -1)], 1)])
    procesar_uno!(A, X)
    return "D-2", A, (X = X.id, )
end

"""
D-3 · Depósito fusionado habilita a un productor posterior (clave 3).
"""
function caso_deposito_habilita(pd::ParamsDAG; seed::Int = 13)
    A, pow = base_dirigida(pd; seed = seed)
    P = pd.P
    id1 = pow[3]
    Tb = BloquePost(id = id1, padres = [A._id_T], slot = 1, productor = 1, peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, Tb)
    o = utxo_gastable(A.post[Tb.id], P, 2, 2)
    o === nothing && error("D-3: sin UTXO gastable")
    X = BloquePost(id = id1 + 1, padres = [Tb.id], slot = 2, productor = 1, peso = 1,
                   txs = Transicion.Tx[Transicion.tx_coinbase_post(3),
                   Transicion.tx_transferencia([o.id],
                       [Transicion.Salida(9201, o.valor - UInt64(1), 3,
                                          Transicion.OrigenTx, -1, -1)], o.dueño)])
    procesar_uno!(A, X)
    Y = BloquePost(id = id1 + 2, padres = [X.id], slot = 3, productor = 1, peso = 1,
                   txs = Transicion.Tx[Transicion.tx_coinbase_post(3),
                   Transicion.tx_deposito([9201], 3, o.valor - UInt64(1), 3)])
    procesar_uno!(A, Y)
    Z = BloquePost(id = id1 + 3, padres = [Y.id], slot = 4, productor = 3, peso = 1,
                   txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, Z)
    # Mismo productor 3 sin el depósito en su pasado ⇒ inválido.
    W = BloquePost(id = id1 + 4, padres = [Tb.id], slot = 2, productor = 3, peso = 1,
                   txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, W)
    return "D-3", A, (X = X.id, Y = Y.id, Z = Z.id, W = W.id)
end

"""
D-4 · Bloque PoST cuyo productor solo tiene garantía en una rama no fusionada:
inválido (`ErrGarantia`).
"""
function caso_garantia_rama(pd::ParamsDAG; seed::Int = 14)
    A, pow = base_dirigida(pd; seed = seed)
    P = pd.P
    id1 = pow[3]
    Tb = BloquePost(id = id1, padres = [A._id_T], slot = 1, productor = 1, peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, Tb)
    o = utxo_gastable(A.post[Tb.id], P, 2, 2)
    o === nothing && error("D-4: sin UTXO gastable")
    # Rama A: depósito a clave 3.
    X = BloquePost(id = id1 + 1, padres = [Tb.id], slot = 2, productor = 1, peso = 1,
                   txs = Transicion.Tx[Transicion.tx_coinbase_post(3),
                   Transicion.tx_transferencia([o.id],
                       [Transicion.Salida(9301, o.valor - UInt64(1), 3,
                                          Transicion.OrigenTx, -1, -1)], o.dueño)])
    procesar_uno!(A, X)
    Yd = BloquePost(id = id1 + 2, padres = [X.id], slot = 3, productor = 1, peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3),
                    Transicion.tx_deposito([9301], 3, o.valor - UInt64(1), 3)])
    procesar_uno!(A, Yd)
    # Rama B (no fusiona X): productor 3 sin garantía.
    B = BloquePost(id = id1 + 3, padres = [Tb.id], slot = 2, productor = 3, peso = 1,
                   txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, B)
    return "D-4", A, (X = X.id, Yd = Yd.id, B = B.id)
end

"""
D-5 · `rojo_U3` inerte: X2 comparte billete con X1 y no se aplica.
"""
function caso_rojo_u3(pd::ParamsDAG; seed::Int = 15)
    A, pow = base_dirigida(pd; seed = seed)
    P = pd.P
    id1 = pow[3]
    Tb = BloquePost(id = id1, padres = [A._id_T], slot = 1, productor = 1, peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, Tb)
    o = utxo_gastable(A.post[Tb.id], P, 2, 2)
    o === nothing && error("D-5: sin UTXO gastable")
    X1 = BloquePost(id = id1 + 1, padres = [Tb.id], slot = 2, sd = 0, ident = 777,
                    productor = 1, peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, X1)
    X2 = BloquePost(id = id1 + 2, padres = [Tb.id], slot = 2, sd = 1, ident = 777,
                    productor = 1, peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3),
                    Transicion.tx_transferencia([o.id],
                        [Transicion.Salida(9402, o.valor - UInt64(1), 1,
                                           Transicion.OrigenTx, -1, -1)], o.dueño)])
    procesar_uno!(A, X2)
    B = BloquePost(id = id1 + 3, padres = [X1.id, X2.id], slot = 3, productor = 1,
                   peso = 1, txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, B)
    return "D-5", A, (X1 = X1.id, X2 = X2.id, B = B.id)
end

"""
D-6 · Un bloque alcanzado por dos cadenas se aplica una sola vez (IE-2).
"""
function caso_una_vez(pd::ParamsDAG; seed::Int = 16)
    A, pow = base_dirigida(pd; seed = seed)
    id1 = pow[3]
    Tb = BloquePost(id = id1, padres = [A._id_T], slot = 1, productor = 1, peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, Tb)
    X = BloquePost(id = id1 + 1, padres = [Tb.id], slot = 2, productor = 1, peso = 1,
                   txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, X)
    Y1 = BloquePost(id = id1 + 2, padres = [X.id], slot = 3, productor = 1, peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    Y2 = BloquePost(id = id1 + 3, padres = [X.id], slot = 3, productor = 1, peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, Y1)
    procesar_uno!(A, Y2)
    return "D-6", A, (X = X.id, Y1 = Y1.id, Y2 = Y2.id)
end

"""
D-7 · Reorganización cambia la cadena seleccionada y recalcula el estado.
"""
function caso_reorg(pd::ParamsDAG; seed::Int = 17)
    A, pow = base_dirigida(pd; seed = seed)
    P = pd.P
    id1 = pow[3]
    Tb = BloquePost(id = id1, padres = [A._id_T], slot = 1, productor = 1, peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, Tb)
    # Rama A pesada (sr=0 ⇒ w=2^128).
    A1 = BloquePost(id = id1 + 1, padres = [Tb.id], slot = 2, sr = 0, productor = 1,
                    peso = 1, txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, A1)
    A2 = BloquePost(id = id1 + 2, padres = [A1.id], slot = 3, sr = 0, productor = 1,
                    peso = 1, txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, A2)
    tipA = mejor_punta(A, tips_validas(A))
    # Rama B ligera.
    B1 = BloquePost(id = id1 + 3, padres = [Tb.id], slot = 2, sr = typemax(UInt64),
                    productor = 1, peso = 1, txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, B1)
    tipB1 = mejor_punta(A, tips_validas(A))
    # B2 y B3 hacen que B pese más que A ⇒ reorganización.
    B2 = BloquePost(id = id1 + 4, padres = [B1.id], slot = 3, sr = 0, productor = 1,
                    peso = 1, txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, B2)
    B3 = BloquePost(id = id1 + 5, padres = [B2.id], slot = 4, sr = 0, productor = 1,
                    peso = 1, txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, B3)
    tipB3 = mejor_punta(A, tips_validas(A))
    return "D-7", A, (A2 = A2.id, B1 = B1.id, B2 = B2.id, B3 = B3.id, tipA = tipA,
                      tipB1 = tipB1, tipB3 = tipB3)
end

"""
D-8 · Bloque de transición con dos hermanos PoST en el mismo slot.
"""
function caso_hermanos_transicion(pd::ParamsDAG; seed::Int = 18)
    A, pow = base_dirigida(pd; seed = seed)
    id1 = pow[3]
    Tb1 = BloquePost(id = id1, padres = [A._id_T], slot = 1, productor = 1, peso = 1,
                     txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    Tb2 = BloquePost(id = id1 + 1, padres = [A._id_T], slot = 1, productor = 1, peso = 1,
                     txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, Tb1)
    procesar_uno!(A, Tb2)
    return "D-8", A, (Tb1 = Tb1.id, Tb2 = Tb2.id)
end

"Todos los casos dirigidos sobre la rejilla T04."
function casos_dirigidos(pd::ParamsDAG)
    return [caso_doble_gasto(pd), caso_coinbase_recortada(pd), caso_deposito_habilita(pd),
            caso_garantia_rama(pd), caso_rojo_u3(pd), caso_una_vez(pd),
            caso_reorg(pd), caso_hermanos_transicion(pd)]
end
