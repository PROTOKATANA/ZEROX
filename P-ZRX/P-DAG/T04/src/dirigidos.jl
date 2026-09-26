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

"""
D-9 · F-15: la **misma** operación de retiro (mismo `txid`, mismo nonce `n`) en dos
bloques hermanos fusionados. La primera en orden `C-GD-05` se aplica; la segunda se
**descarta** con `ErrNonce` (`ErrNonce`). Los dos bloques siguen válidos.
"""
function caso_nonce_repeticion_fusionada(pd::ParamsDAG; seed::Int = 19)
    A, pow = base_dirigida(pd; seed = seed)
    id1 = pow[3]
    Tb = BloquePost(id = id1, padres = [A._id_T], slot = 1, productor = 1, peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, Tb)
    n = Transicion.nonce_de(A.post[Tb.id], 1)
    ret = Transicion.tx_retiro(1, 1, 1; nonce = n)     # misma Tx reutilizada
    X1 = BloquePost(id = id1 + 1, padres = [Tb.id], slot = 2, sd = 0, productor = 1,
                    peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3), ret])
    X2 = BloquePost(id = id1 + 2, padres = [Tb.id], slot = 2, sd = 1, productor = 1,
                    peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3), ret])
    procesar_uno!(A, X1)
    procesar_uno!(A, X2)
    B = BloquePost(id = id1 + 3, padres = [X1.id, X2.id], slot = 3, productor = 1,
                   peso = 1, txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, B)
    primero = GDR.cmp_orden(A.gdr, A.gidx[X1.id], A.gidx[X2.id]) < 0 ? X1.id : X2.id
    segundo = primero == X1.id ? X2.id : X1.id
    return "D-9", A, (Tb = Tb.id, X1 = X1.id, X2 = X2.id, B = B.id, n = n,
                      primero = primero, segundo = segundo)
end

"""
D-10 · F-15: dos depósitos de la **misma clave** con nonces `n` y `n+1` en bloques
hermanos, en orden **inverso** a `C-GD-05`: el de `n+1` se aplica primero y se
descarta (`ErrNonce`); el de `n` —que llega después— se aplica. Como la comprobación
de nonce va antes de consumir entradas, el UTXO compartido no se quema con el
descarte.
"""
function caso_nonce_orden_inverso(pd::ParamsDAG; seed::Int = 20)
    A, pow = base_dirigida(pd; seed = seed)
    P = pd.P
    id1 = pow[3]
    Tb = BloquePost(id = id1, padres = [A._id_T], slot = 1, productor = 1, peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, Tb)
    o = utxo_gastable(A.post[Tb.id], P, 2, 2)
    o === nothing && error("D-10: sin UTXO gastable")
    n = Transicion.nonce_de(A.post[Tb.id], o.dueño)
    # Xa (sd=0) va primero en C-GD-05 y lleva el nonce n+1 (inválido).
    Xa = BloquePost(id = id1 + 1, padres = [Tb.id], slot = 2, sd = 0, productor = 1,
                    peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3),
                        Transicion.tx_deposito([o.id], o.dueño, o.valor, o.dueño;
                                               nonce = n + UInt64(1))])
    Xb = BloquePost(id = id1 + 2, padres = [Tb.id], slot = 2, sd = 1, productor = 1,
                    peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3),
                        Transicion.tx_deposito([o.id], o.dueño, o.valor, o.dueño;
                                               nonce = n)])
    procesar_uno!(A, Xa)
    procesar_uno!(A, Xb)
    B = BloquePost(id = id1 + 3, padres = [Xa.id, Xb.id], slot = 3, productor = 1,
                   peso = 1, txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, B)
    return "D-10", A, (Tb = Tb.id, Xa = Xa.id, Xb = Xb.id, B = B.id, n = n,
                       utxo = o.id, clave = o.dueño)
end

"""
D-11 · F-15 + ED-3: **repetición tras una reorganización**. El mismo retiro firmado
(mismo `txid`, nonce `n`) vive en dos ramas hermanas; al reorganizar hacia la rama
que lo contiene el efecto aparece **una sola vez** y `nonce_siguiente` avanza **una
sola vez**; al reorganizar de vuelta, sigue apareciendo una sola vez.
"""
function caso_nonce_reorg(pd::ParamsDAG; seed::Int = 21)
    A, pow = base_dirigida(pd; seed = seed)
    id1 = pow[3]
    Tb = BloquePost(id = id1, padres = [A._id_T], slot = 1, productor = 1, peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, Tb)
    n = Transicion.nonce_de(A.post[Tb.id], 1)
    ret = Transicion.tx_retiro(1, 1, 1; nonce = n)
    # Rama A (pesada de inmediato).
    A1 = BloquePost(id = id1 + 1, padres = [Tb.id], slot = 2, sr = 0, productor = 1,
                    peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3), ret])
    procesar_uno!(A, A1)
    tipA1 = mejor_punta(A, tips_validas(A))
    # Rama B (ligera al principio) con la MISMA operación.
    B1 = BloquePost(id = id1 + 2, padres = [Tb.id], slot = 2, sr = typemax(UInt64),
                    productor = 1, peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3), ret])
    procesar_uno!(A, B1)
    B2 = BloquePost(id = id1 + 3, padres = [B1.id], slot = 3, sr = 0, productor = 1,
                    peso = 1, txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    B3 = BloquePost(id = id1 + 4, padres = [B2.id], slot = 4, sr = 0, productor = 1,
                    peso = 1, txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, B2)
    procesar_uno!(A, B3)
    tipB3 = mejor_punta(A, tips_validas(A))
    SB, _, _ = estado_virtual(A)
    retiros_B = length(SB.garantias[1].en_retirada)
    nonce_B = SB.garantias[1].nonce_siguiente
    # Reorganización de vuelta a A.
    A2 = BloquePost(id = id1 + 5, padres = [A1.id], slot = 3, sr = 0, productor = 1,
                    peso = 1, txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    A3 = BloquePost(id = id1 + 6, padres = [A2.id], slot = 4, sr = 0, productor = 1,
                    peso = 1, txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, A2)
    procesar_uno!(A, A3)
    tipA3 = mejor_punta(A, tips_validas(A))
    return "D-11", A, (Tb = Tb.id, A1 = A1.id, A2 = A2.id, A3 = A3.id, B1 = B1.id,
                       B2 = B2.id, B3 = B3.id, n = n, tipA1 = tipA1, tipB3 = tipB3,
                       tipA3 = tipA3, retiros_B = retiros_B, nonce_B = nonce_B)
end

"Todos los casos dirigidos sobre la rejilla T04."
function casos_dirigidos(pd::ParamsDAG)
    return [caso_doble_gasto(pd), caso_coinbase_recortada(pd), caso_deposito_habilita(pd),
            caso_garantia_rama(pd), caso_rojo_u3(pd), caso_una_vez(pd),
            caso_reorg(pd), caso_hermanos_transicion(pd),
            caso_nonce_repeticion_fusionada(pd), caso_nonce_orden_inverso(pd),
            caso_nonce_reorg(pd)]
end
