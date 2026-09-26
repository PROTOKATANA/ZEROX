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

"""
D-12 · Retiro, liberación y transferencia que gasta la salida de la liberación
en la rama A; reorganización a la rama B, que no las contiene: al pasar A a ser
bloque de lado (aplicado en `slot(V)`), la liberación deja de estar vencida, la
salida de la liberación desaparece, la garantía vuelve al estado previo (el
retiro sigue en `en_retirada`) y la transferencia no existe; vuelta a A: todo
reaparece una sola vez.
"""
function caso_retiro_liberacion_reorg(pd::ParamsDAG; seed::Int = 22)
    A, pow = base_dirigida(pd; seed = seed)
    id1 = pow[3]
    Tb = BloquePost(id = id1, padres = [A._id_T], slot = 1, productor = 1, peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, Tb)
    S0 = A.post[Tb.id]
    activo0 = S0.garantias[1].activo
    activo0 >= UInt64(1) || error("D-12: clave 1 sin activo")
    n0 = Transicion.nonce_de(S0, 1)
    # Rama A: retiro (slot 2) → liberación (slot 3) → transferencia (slot 4).
    A1 = BloquePost(id = id1 + 1, padres = [Tb.id], slot = 2, sr = 0, sd = 5,
                    productor = 1, peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3),
                        Transicion.tx_retiro(1, 1, 1; nonce = n0)])
    procesar_uno!(A, A1)
    A2 = BloquePost(id = id1 + 2, padres = [A1.id], slot = 3, sr = 0, productor = 1,
                    peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3),
                        Transicion.tx_liberacion(1, 1, 1;
                            nonce = Transicion.nonce_de(A.post[A1.id], 1))])
    procesar_uno!(A, A2)
    libA = [o for (_, o) in A.post[A2.id].utxo
            if o.origen == Transicion.OrigenLiberacion]
    length(libA) == 1 || error("D-12: la liberación no creó su salida")
    lib = libA[1]
    A3 = BloquePost(id = id1 + 3, padres = [A2.id], slot = 4, sr = 0, sd = 5,
                    productor = 1, peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3),
                        Transicion.tx_transferencia([lib.id],
                            [Transicion.Salida(9501, lib.valor, 1,
                                               Transicion.OrigenTx, -1, -1)], 1)])
    procesar_uno!(A, A3)
    SA = A.post[A3.id]
    # Rama B (sin retiro/liberación/transferencia): mismos slots, sd menor ⇒ gana.
    B1 = BloquePost(id = id1 + 4, padres = [Tb.id], slot = 2, sr = 0, sd = 0,
                    productor = 1, peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, B1)
    B2 = BloquePost(id = id1 + 5, padres = [B1.id], slot = 3, sr = 0, productor = 1,
                    peso = 1, txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, B2)
    B3 = BloquePost(id = id1 + 6, padres = [B2.id], slot = 4, sr = 0, sd = 0,
                    productor = 1, peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, B3)
    tipB = mejor_punta(A, tips_validas(A))
    SB, _, _ = estado_virtual(A)
    # Vuelta a A: un bloque pesado más.
    A4 = BloquePost(id = id1 + 7, padres = [A3.id], slot = 5, sr = 0, productor = 1,
                    peso = 1, txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, A4)
    tipA = mejor_punta(A, tips_validas(A))
    SA2, _, _ = estado_virtual(A)
    cuenta(E, campo) = campo == :lib ?
        count(o -> o.origen == Transicion.OrigenLiberacion, values(E.utxo)) :
        count(o -> o.id == 9501, values(E.utxo))
    return "D-12", A, (Tb = Tb.id, A1 = A1.id, A2 = A2.id, A3 = A3.id,
                       B1 = B1.id, B2 = B2.id, B3 = B3.id, A4 = A4.id,
                       tipA3 = A3.id, tipB = tipB, tipA = tipA, lib = lib.id,
                       libA = length(libA), activo0 = activo0, n0 = n0,
                       libSA = cuenta(SA, :lib), outSA = cuenta(SA, :out),
                       libSB = cuenta(SB, :lib), outSB = cuenta(SB, :out),
                       libSA2 = cuenta(SA2, :lib), outSA2 = cuenta(SA2, :out),
                       retSA = length(SA.garantias[1].en_retirada),
                       retSB = length(SB.garantias[1].en_retirada),
                       retSA2 = length(SA2.garantias[1].en_retirada),
                       nonceSA = Transicion.nonce_de(SA, 1),
                       nonceSB = Transicion.nonce_de(SB, 1),
                       nonceSA2 = Transicion.nonce_de(SA2, 1))
end

"""
D-13 · Liberación inmadura en el slot propio de X (`inicio + R_slots > s`) que sí
madura en el slot de su fusionador Y (`slot(Y) ≥ inicio + R_slots`). RD-4 fija el
punto de aplicación: un bloque de lado se aplica en el slot del fusionador. Se
documentan las dos vistas: en `Estado(past(X))` la liberación se descarta
(`ErrSaldo`); en `Estado(past(Y))` se aplica y crea la salida en `slot(Y)`.
"""
function caso_liberacion_punto_aplicacion(pd::ParamsDAG; seed::Int = 23)
    A, pow = base_dirigida(pd; seed = seed)
    id1 = pow[3]
    Tb = BloquePost(id = id1, padres = [A._id_T], slot = 1, productor = 1, peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, Tb)
    n0 = Transicion.nonce_de(A.post[Tb.id], 1)
    # W: retiro en el slot 2 (inicio = 2).
    W = BloquePost(id = id1 + 1, padres = [Tb.id], slot = 2, sr = 0, productor = 1,
                   peso = 1,
                   txs = Transicion.Tx[Transicion.tx_coinbase_post(3),
                       Transicion.tx_retiro(1, 1, 1; nonce = n0)])
    procesar_uno!(A, W)
    # X: liberación en su propio slot 2 (2 + R_slots = 3 > 2 ⇒ inmadura).
    X = BloquePost(id = id1 + 2, padres = [W.id], slot = 2, sr = typemax(UInt64),
                   sd = 10, productor = 1, peso = 1,
                   txs = Transicion.Tx[Transicion.tx_coinbase_post(3),
                       Transicion.tx_liberacion(1, 1, 1;
                           nonce = Transicion.nonce_de(A.post[W.id], 1))])
    procesar_uno!(A, X)
    # Z: bloque de cadena en el slot 3 (hijo de W), gana el desempate por `sd`.
    Z = BloquePost(id = id1 + 3, padres = [W.id], slot = 3, sr = 0, sd = 0,
                   productor = 1, peso = 1,
                   txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, Z)
    # Y: fusiona Z (sp) y X en el slot 3 ⇒ X se aplica en slot 3 (vencida).
    Y = BloquePost(id = id1 + 4, padres = [Z.id, X.id], slot = 3, sr = 0,
                   productor = 1, peso = 1,
                   txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, Y)
    spY = A.id_g[A.gdr.gd[A.gidx[Y.id]].sp]
    libX = [o for (_, o) in A.post[X.id].utxo
            if o.origen == Transicion.OrigenLiberacion]
    libY = [o for (_, o) in A.past[Y.id].utxo
            if o.origen == Transicion.OrigenLiberacion]
    return "D-13", A, (Tb = Tb.id, W = W.id, X = X.id, Z = Z.id, Y = Y.id,
                       spY = spY, slotX = A.por_id[X.id].slot,
                       slotY = A.por_id[Y.id].slot, libX = length(libX),
                       libY = length(libY),
                       libY_slot = isempty(libY) ? -1 : libY[1].creada_en_slot,
                       nonceX = Transicion.nonce_de(A.post[X.id], 1),
                       nonceY = Transicion.nonce_de(A.past[Y.id], 1),
                       n0 = n0,
                       descX = copy(get(A.descartes, X.id,
                                        Tuple{Int,Transicion.Err}[])))
end

"""
D-14 · F-18: dos liberaciones **distintas** de la misma clave (mismo `nonce` `n`,
importes `a ≠ b`) en dos ramas hermanas, cada una con un hijo que gasta su salida.
Al fusionar las ramas, una liberación aplica y la otra se descarta con `ErrNonce`;
la transferencia de la rama aplicada se aplica y la de la rama descartada se
descarta por entrada ausente (`ErrDobleGasto`). Nunca hay colisión de ids porque
`ID_LIB(1, n, a) ≠ ID_LIB(1, n, b)` (importes distintos). `A.past[B]` es
`Estado(past(B))`.
"""
function caso_dos_liberaciones_hermanas(pd::ParamsDAG; seed::Int = 24)
    A, pow = base_dirigida(pd; seed = seed)
    id1 = pow[3]
    Tb = BloquePost(id = id1, padres = [A._id_T], slot = 1, productor = 1, peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, Tb)
    n0 = Transicion.nonce_de(A.post[Tb.id], 1)
    v = UInt64(3)                       # retiro: activo de la clave 1 = 5
    a = UInt64(1)
    b = UInt64(2)
    # W: retiro de `v` en el slot 2 (inicio); vencido en 2 + R_slots.
    W = BloquePost(id = id1 + 1, padres = [Tb.id], slot = 2, productor = 1, peso = 1,
                   txs = Transicion.Tx[Transicion.tx_coinbase_post(3),
                       Transicion.tx_retiro(1, v, 1; nonce = n0)])
    procesar_uno!(A, W)
    n1 = Transicion.nonce_de(A.post[W.id], 1)
    # Xa (sd menor) y Xc: liberaciones hermanas, mismo nonce, importes a ≠ b.
    Xa = BloquePost(id = id1 + 2, padres = [W.id], slot = 3, sd = 0, productor = 1,
                    peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3),
                        Transicion.tx_liberacion(1, a, 1; nonce = n1)])
    Xc = BloquePost(id = id1 + 3, padres = [W.id], slot = 3, sd = 1, productor = 1,
                    peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3),
                        Transicion.tx_liberacion(1, b, 1; nonce = n1)])
    procesar_uno!(A, Xa)
    procesar_uno!(A, Xc)
    primero = GDR.cmp_orden(A.gdr, A.gidx[Xa.id], A.gidx[Xc.id]) < 0 ? Xa.id : Xc.id
    segundo = primero == Xa.id ? Xc.id : Xa.id
    id_a = Transicion.ID_LIB(1, n1, a)
    id_b = Transicion.ID_LIB(1, n1, b)
    id_a isa Transicion.Err && error("D-14: ID_LIB(a) fuera de rango")
    id_b isa Transicion.Err && error("D-14: ID_LIB(b) fuera de rango")
    # Xb hijo de Xa gasta ID_LIB(1,n1,a); Xd hijo de Xc gasta ID_LIB(1,n1,b).
    Xb = BloquePost(id = id1 + 4, padres = [Xa.id], slot = 3, productor = 1, peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3),
                        Transicion.tx_transferencia([id_a],
                            [Transicion.Salida(9701, a, 1, Transicion.OrigenTx, -1, -1)], 1)])
    Xd = BloquePost(id = id1 + 5, padres = [Xc.id], slot = 3, productor = 1, peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3),
                        Transicion.tx_transferencia([id_b],
                            [Transicion.Salida(9702, b, 1, Transicion.OrigenTx, -1, -1)], 1)])
    procesar_uno!(A, Xb)
    procesar_uno!(A, Xd)
    B = BloquePost(id = id1 + 6, padres = [Xb.id, Xd.id], slot = 4, productor = 1,
                   peso = 1, txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, B)
    SB = A.past[B.id]
    return "D-14", A, (Tb = Tb.id, W = W.id, Xa = Xa.id, Xc = Xc.id, Xb = Xb.id,
                       Xd = Xd.id, B = B.id, n0 = n0, n1 = n1, a = a, b = b,
                       primero = primero, segundo = segundo, id_a = id_a, id_b = id_b,
                       outXb = haskey(SB.utxo, 9701) ? 1 : 0,
                       outXd = haskey(SB.utxo, 9702) ? 1 : 0,
                       nonceS = Transicion.nonce_de(SB, 1),
                       validos = count(v -> v, values(A.validos)))
end

"Copia de un `ParamsDAG` con C-EVP activo (SL-3) y la puerta RAT-3 satisfecha."
function _pd_ev(pd::ParamsDAG; Plazo::Int = 3, Mm::Int = 0, fn::Int = 1, fd::Int = 1)
    P = pd.P
    R = max(P.R_slots, Plazo + Mm + 1)
    Pe = Transicion.Params(H_dep = P.H_dep, M_cb = P.M_cb, M_dep = P.M_dep,
        H_corte_min = P.H_corte_min, W_min = P.W_min, S_min = P.S_min,
        K_min = P.K_min, q = P.q, M_res_slots = P.M_res_slots,
        M_dep_slots = P.M_dep_slots, M_rec_slots = P.M_rec_slots, R_slots = R,
        F_slots = P.F_slots, sec = P.sec, M_sec = P.M_sec, P_sec = P.P_sec,
        C_min = P.C_min, corte = P.corte, seleccion = P.seleccion, f_num = fn,
        f_den = fd, Plazo_slots = Plazo, M_margen_slots = Mm, cbid = 7, evp = true)
    return ParamsDAG(Pe, pd.k)
end

"Bloque PoST con coinbase + una evidencia (SL-3)."
_ev_bloque(id, padres, slot, P, ev; sd = 0, productor = 1, txs_extra = Transicion.Tx[]) =
    BloquePost(id = id, padres = padres, slot = slot, sd = sd, productor = productor,
               peso = 1, txs = vcat(Transicion.Tx[Transicion.tx_coinbase_post(3)],
                                    txs_extra, Transicion.Tx[Transicion.tx_evidencia(ev)]))

"Descartes de la aplicación del mergeset de `b` (id de bloque, índice de tx, error)."
function _descartes_mergeset(A::Admision, b::BloquePost)
    gd = A.gdr.gd[A.gidx[b.id]]
    sp_g = gd.sp
    base = sp_g == 1 ? Transicion.clonar(A.estado_T) :
                       Transicion.clonar(A.post[A.id_g[sp_g]])
    out = Tuple{Int,Int,Transicion.Err}[]
    for xg in gd.ms_ordenado
        get(gd.tipos, xg, 0x00) == 0x02 && continue
        x_id = A.id_g[xg]
        xb = A.por_id[x_id]
        base, d = aplicar_bloque_fusion!(A, base, xb, b.slot)
        for (i, e) in d
            push!(out, (x_id, i, e))
        end
    end
    return out
end

"""
D-15 · Evidencia aplicada en modo fusión: congela, confisca (RAT-2), registra el
incidente y conserva I-1.
"""
function caso_evidencia_aplicada(pd::ParamsDAG; seed::Int = 31)
    A, pow = base_dirigida(pd; seed = seed)
    id1 = pow[3]
    Tb = BloquePost(id = id1, padres = [A._id_T], slot = 1, productor = 1, peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, Tb)
    ev = Transicion.evidencia(pd.P.cbid, 1, 0, 0, 0, 2, UInt64(101), UInt64(202))
    X = _ev_bloque(id1 + 1, [Tb.id], 2, pd.P, ev)
    procesar_uno!(A, X)
    S = A.post[X.id]
    return "D-15", A, (Tb = Tb.id, X = X.id, valido = A.validos[X.id],
                       incidentes = isempty(S.garantias[1].incidentes) ? 0 : 1,
                       quemado = S.quemado, I1 = invariante_I1(S))
end

"""
D-16 · Dos evidencias del mismo incidente en ramas hermanas (EV-12): la primera
en orden C-GD-05 aplica; la segunda se descarta al fusionarse sin invalidar el
bloque ni volver a congelar.
"""
function caso_evidencia_hermanas(pd::ParamsDAG; seed::Int = 32)
    A, pow = base_dirigida(pd; seed = seed)
    id1 = pow[3]
    Tb = BloquePost(id = id1, padres = [A._id_T], slot = 1, productor = 1, peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, Tb)
    ev = Transicion.evidencia(pd.P.cbid, 1, 0, 0, 0, 2, UInt64(301), UInt64(302))
    Xa = _ev_bloque(id1 + 1, [Tb.id], 2, pd.P, ev; sd = 0)
    Xc = _ev_bloque(id1 + 2, [Tb.id], 2, pd.P, ev; sd = 1)
    procesar_uno!(A, Xa)
    procesar_uno!(A, Xc)
    B = BloquePost(id = id1 + 3, padres = [Xa.id, Xc.id], slot = 3, productor = 1,
                   peso = 1, txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, B)
    S = A.past[B.id]
    desc = _descartes_mergeset(A, B)
    dup = [d for d in desc if d[3] == Transicion.ErrEvidenciaDuplicada]
    return "D-16", A, (Tb = Tb.id, Xa = Xa.id, Xc = Xc.id, B = B.id,
                       dup = length(dup), incidentes = isempty(S.garantias[1].incidentes) ? 0 : 1,
                       validos = A.validos[Xa.id] && A.validos[Xc.id] && A.validos[B.id],
                       I1 = invariante_I1(S))
end

"""
D-17 · EV-27/EV-28: el incidente vive en la historia seleccionada. En el pasado
de la rama hermana no está; una evidencia del mismo incidente aplicada allí es
«primera»; el undo del bloque que la aplicó restituye el estado exacto.
"""
function caso_evidencia_reorg(pd::ParamsDAG; seed::Int = 33)
    A, pow = base_dirigida(pd; seed = seed)
    id1 = pow[3]
    Tb = BloquePost(id = id1, padres = [A._id_T], slot = 1, productor = 1, peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, Tb)
    ev = Transicion.evidencia(pd.P.cbid, 1, 0, 0, 0, 2, UInt64(401), UInt64(402))
    Xa = _ev_bloque(id1 + 1, [Tb.id], 2, pd.P, ev; sd = 0)
    Xc = BloquePost(id = id1 + 2, padres = [Tb.id], slot = 2, sd = 1, productor = 1,
                    peso = 1, txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, Xa)
    procesar_uno!(A, Xc)
    # Hermana que reaplica la misma evidencia en la rama sin la primera aplicación.
    Ye = _ev_bloque(id1 + 3, [Xc.id], 3, pd.P, ev)
    procesar_uno!(A, Ye)
    inc_past_Xc = length(A.past[Xc.id].garantias[1].incidentes)
    inc_post_Ye = length(A.post[Ye.id].garantias[1].incidentes)
    r = aplicar_fusion_con_undo(A, A.past[Xa.id], Xa, Xa.slot)
    ok_undo = !(r isa Tuple) ? false :
              hash_canonico(r[2]) == hash_canonico(A.past[Xa.id])
    return "D-17", A, (Tb = Tb.id, Xa = Xa.id, Xc = Xc.id, Ye = Ye.id,
                       inc_past_Xc = inc_past_Xc, inc_post_Ye = inc_post_Ye,
                       undo = ok_undo, I1 = invariante_I1(A.post[Ye.id]))
end

"""
D-18/19/20 · Descartes de evidencia en modo fusión: `cbid` ajeno, tardía y
contra clave sin saldo (aplicada con pérdida cero).
"""
function caso_evidencia_descartes(pd::ParamsDAG; seed::Int = 34)
    A, pow = base_dirigida(pd; seed = seed)
    id1 = pow[3]
    Tb = BloquePost(id = id1, padres = [A._id_T], slot = 1, productor = 1, peso = 1,
                    txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, Tb)
    ev_cbid = Transicion.evidencia(pd.P.cbid + 1, 1, 0, 0, 0, 2, UInt64(501), UInt64(502))
    Xc = _ev_bloque(id1 + 1, [Tb.id], 2, pd.P, ev_cbid)
    procesar_uno!(A, Xc)
    ev_tar = Transicion.evidencia(pd.P.cbid, 1, 0, 0, 0,
                                  2 - pd.P.Plazo_slots, UInt64(503), UInt64(504))
    Xt = _ev_bloque(id1 + 2, [Tb.id], 2, pd.P, ev_tar; sd = 1)
    procesar_uno!(A, Xt)
    ev_ss = Transicion.evidencia(pd.P.cbid, 99, 0, 0, 0, 2, UInt64(505), UInt64(506))
    Xs = _ev_bloque(id1 + 3, [Tb.id], 2, pd.P, ev_ss; sd = 2)
    procesar_uno!(A, Xs)
    B = BloquePost(id = id1 + 4, padres = [Xc.id, Xt.id, Xs.id], slot = 3,
                   productor = 1, peso = 1,
                   txs = Transicion.Tx[Transicion.tx_coinbase_post(3)])
    procesar_uno!(A, B)
    S = A.past[B.id]
    # `sp(B)` no entra en el mergeset: su descarte vive en `A.descartes[sp]`.
    dsp = A.descartes[Xc.id]
    dms = _descartes_mergeset(A, B)
    cbid = count(x -> x[2] == Transicion.ErrCbidAjeno, dsp) +
           count(x -> x[3] == Transicion.ErrCbidAjeno, dms)
    tardia = count(x -> x[2] == Transicion.ErrEvidenciaTardia, dsp) +
             count(x -> x[3] == Transicion.ErrEvidenciaTardia, dms)
    return "D-18", A, (Tb = Tb.id, Xc = Xc.id, Xt = Xt.id, Xs = Xs.id, B = B.id,
                       cbid = cbid, tardia = tardia,
                       sin_saldo = any(k -> k == 99, keys(S.garantias)) &&
                                   length(S.garantias[99].incidentes) == 1,
                       I1 = invariante_I1(S))
end

"Todos los casos dirigidos sobre la rejilla T04 (incluye SL-3 con C-EVP activo)."
function casos_dirigidos(pd::ParamsDAG)
    base = [caso_doble_gasto(pd), caso_coinbase_recortada(pd), caso_deposito_habilita(pd),
            caso_garantia_rama(pd), caso_rojo_u3(pd), caso_una_vez(pd),
            caso_reorg(pd), caso_hermanos_transicion(pd),
            caso_nonce_repeticion_fusionada(pd), caso_nonce_orden_inverso(pd),
            caso_nonce_reorg(pd), caso_retiro_liberacion_reorg(pd),
            caso_liberacion_punto_aplicacion(pd), caso_dos_liberaciones_hermanas(pd)]
    pdev = _pd_ev(pd)
    return vcat(base, [caso_evidencia_aplicada(pdev), caso_evidencia_hermanas(pdev),
                       caso_evidencia_reorg(pdev), caso_evidencia_descartes(pdev)])
end
