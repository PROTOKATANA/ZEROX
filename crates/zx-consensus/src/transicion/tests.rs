//! Tests unitarios del motor de transición (`ORDEN-W03` V5).
//!
//! Cubren lo que el arnés diferencial contra T01 **no** cubre: el testigo real, el cambio de un
//! depósito (F-07), `MultiSig`, y los rechazos de coinbase/Posición/productor. Los tests del
//! diferencial viven en `tests/diferencial_t01.rs`.

#![expect(clippy::unwrap_used, reason = "los tests fallan con panic por diseño")]
#![expect(
    clippy::indexing_slicing,
    reason = "índices sobre arrays de tamaño fijo en el test"
)]

use ed25519_zebra::{SigningKey, VerificationKey};
use primitive_types::U256;
use zx_core::{
    Amount, BlockHash, CBID_RED_DEV, ClavePublica, Digest, ExtensionTx, HashType, Lock, OutPoint,
    SpentOutput, TipoGarantia, Tx, TxId, TxIn, TxOut,
};

use crate::transicion::estado::{invariante_i1, invariante_i1b};
use crate::transicion::{
    BloqueTransicion, EnRetirada, EntradaUtxo, ErrorTransicion, Estado, Fase, Garantia,
    HechosCabecera, Origen, ParametrosTransicion, Punto, aplicar, aplicar_fusion,
};

fn subsidio_pow_test(_h: u32) -> Amount {
    Amount::nuevo(10).unwrap()
}

fn subsidio_post_test(_s: u64) -> Amount {
    Amount::nuevo(3).unwrap()
}

fn params() -> ParametrosTransicion {
    ParametrosTransicion {
        h_dep: 1,
        m_cb: 1,
        m_dep: 0,
        h_corte_min: 100,
        w_min: U256::one(),
        s_min: Amount::nuevo(1).unwrap(),
        q: Amount::nuevo(1).unwrap(),
        k_min: 1,
        m_res_slots: 1,
        m_dep_slots: 1,
        m_rec_slots: 1,
        r_slots: 3,
        f_slots: None,
        subsidio_pow: subsidio_pow_test,
        subsidio_post: subsidio_post_test,
    }
}

fn hash(n: u8) -> BlockHash {
    BlockHash::from_digest(Digest::from_bytes([n; 32]))
}

fn par(semilla: u8) -> (SigningKey, ClavePublica) {
    let sk = SigningKey::from([semilla; 32]);
    let vk = VerificationKey::from(&sk);
    (sk, ClavePublica::desde_bytes(vk.into()))
}

fn outpoint(n: u8, idx: u32) -> OutPoint {
    OutPoint {
        prev_txid: TxId::from_digest(Digest::from_bytes([n; 32])),
        prev_index: idx,
    }
}

fn txin(op: OutPoint) -> TxIn {
    TxIn {
        outpoint: op,
        sequence: 0,
    }
}

fn tx_out(valor: i64, pk: ClavePublica) -> TxOut {
    TxOut {
        value: Amount::nuevo(valor).unwrap(),
        lock: Lock::PubKey { pubkey: pk },
    }
}

fn entrada(valor: i64, lock: Lock, origen: Origen, creada: Punto) -> EntradaUtxo {
    EntradaUtxo {
        valor: Amount::nuevo(valor).unwrap(),
        lock,
        origen,
        creada,
    }
}

fn tx_coinbase_pow(salidas: Vec<TxOut>) -> Tx {
    Tx {
        version: 1,
        inputs: Vec::new(),
        outputs: salidas,
        lock_time: 0,
        expiry_height: 0,
        extension: ExtensionTx::Ninguna,
    }
}

fn tx_coinbase_post(clave: ClavePublica, importe: i64) -> Tx {
    Tx {
        version: 3,
        inputs: Vec::new(),
        outputs: Vec::new(),
        lock_time: 0,
        expiry_height: 0,
        extension: ExtensionTx::CoinbasePost {
            clave,
            importe: Amount::nuevo(importe).unwrap(),
        },
    }
}

fn tx_transferencia(inputs: Vec<TxIn>, outputs: Vec<TxOut>) -> Tx {
    Tx {
        version: 1,
        inputs,
        outputs,
        lock_time: 0,
        expiry_height: 0,
        extension: ExtensionTx::Ninguna,
    }
}

fn tx_garantia(tipo: TipoGarantia, clave: ClavePublica, importe: i64) -> Tx {
    Tx {
        version: 2,
        inputs: Vec::new(),
        outputs: Vec::new(),
        lock_time: 0,
        expiry_height: 0,
        extension: ExtensionTx::Garantia {
            tipo,
            clave,
            importe: Amount::nuevo(importe).unwrap(),
        },
    }
}

fn tx_deposito(inputs: Vec<TxIn>, outputs: Vec<TxOut>, clave: ClavePublica, importe: i64) -> Tx {
    Tx {
        version: 2,
        inputs,
        outputs,
        lock_time: 0,
        expiry_height: 0,
        extension: ExtensionTx::Garantia {
            tipo: TipoGarantia::Deposito,
            clave,
            importe: Amount::nuevo(importe).unwrap(),
        },
    }
}

fn firma_entrada(sk: &SigningKey, tx: &Tx, gastadas: &[SpentOutput], i: usize) -> Vec<u8> {
    let digest = zx_core::sighash(tx, gastadas, HashType::All, i, CBID_RED_DEV).unwrap();
    let firma: [u8; 64] = sk.sign(digest.as_bytes()).into();
    firma.to_vec()
}

fn aceptacion(sk: &SigningKey, tx: &Tx) -> Vec<u8> {
    let mensaje = zx_core::mensaje_aceptacion(tx, CBID_RED_DEV);
    let firma: [u8; 64] = sk.sign(&mensaje).into();
    firma.to_vec()
}

fn estado_pow() -> Estado {
    let mut estado = Estado::inicial();
    estado.fase = Fase::PoW;
    estado
}

fn estado_post() -> Estado {
    let mut estado = Estado::inicial();
    estado.fase = Fase::PoST;
    estado
}

fn con_garantia(estado: &mut Estado, pk: ClavePublica, activo: i64) {
    estado.garantias.insert(
        pk,
        Garantia {
            activo: Amount::nuevo(activo).unwrap(),
            pendientes: Vec::new(),
            en_retirada: Vec::new(),
            congelado: Amount::CERO,
            creditos: Vec::new(),
        },
    );
}

fn bloque_pow(altura: u32, txs: Vec<(Tx, Vec<Vec<u8>>)>) -> BloqueTransicion {
    BloqueTransicion::nuevo(
        HechosCabecera::PoW {
            hash: hash(1),
            padre: hash(0),
            altura,
            trabajo: U256::one(),
            pow_valido: true,
        },
        txs,
    )
}

fn bloque_post(
    slot: u64,
    productor: ClavePublica,
    txs: Vec<(Tx, Vec<Vec<u8>>)>,
) -> BloqueTransicion {
    BloqueTransicion::nuevo(
        HechosCabecera::PoST {
            hash: hash(2),
            padre: hash(1),
            slot,
            productor,
            peso: 1,
            prueba_valida: true,
            requisito_declarado: 0,
        },
        txs,
    )
}

// ── V5 · testigo real ──────────────────────────────────────────────────────

/// Regresión `compromiso != autorización`: un testigo criptográficamente inválido puede coincidir
/// con el `body_commitment` calculado sobre él, y el motor lo rechaza igualmente.
#[test]
fn un_testigo_invalido_puede_coincidir_con_el_compromiso() {
    let (_, pk) = par(42);
    let op = outpoint(7, 0);
    let tx = tx_transferencia(vec![txin(op)], vec![tx_out(9, pk)]);
    let testigos: Vec<Vec<u8>> = vec![vec![0x00u8; 64]];

    let compromiso = zx_core::body_commitment(
        std::slice::from_ref(&tx),
        std::slice::from_ref(&testigos),
        CBID_RED_DEV,
    )
    .unwrap();
    let recomputado = zx_core::body_commitment(
        std::slice::from_ref(&tx),
        std::slice::from_ref(&testigos),
        CBID_RED_DEV,
    )
    .unwrap();
    assert_eq!(
        compromiso, recomputado,
        "el compromiso es fiel a los testigos inválidos"
    );

    let mut estado = estado_pow();
    estado.utxo.insert(
        op,
        entrada(
            10,
            Lock::PubKey { pubkey: pk },
            Origen::Tx,
            Punto::Altura(0),
        ),
    );
    let bloque = bloque_pow(1, vec![(tx, testigos)]);
    assert_eq!(
        aplicar(&estado, &bloque, &params(), CBID_RED_DEV),
        Err(ErrorTransicion::ErrFirma),
        "la verificación criptográfica MUST rechazarlos"
    );
}

// ── V5 · depósito con cambio (F-07) ────────────────────────────────────────

#[test]
fn deposito_con_cambio_crea_el_cambio_y_acredita_la_garantia() {
    let (sk, pk) = par(1);
    let op = outpoint(7, 0);
    let tx = tx_deposito(vec![txin(op)], vec![tx_out(4, pk)], pk, 6);
    let gastadas = vec![SpentOutput {
        value: Amount::nuevo(10).unwrap(),
        lock: Lock::PubKey { pubkey: pk },
    }];
    let mut testigos = vec![firma_entrada(&sk, &tx, &gastadas, 0)];
    testigos.push(aceptacion(&sk, &tx));

    let mut estado = estado_pow();
    estado.utxo.insert(
        op,
        entrada(
            10,
            Lock::PubKey { pubkey: pk },
            Origen::Tx,
            Punto::Altura(0),
        ),
    );
    // Estado de partida consistente con I-1 (UTXO 10).
    estado.emitido = 10;
    estado.subsidio_acum = 10;
    let bloque = bloque_pow(1, vec![(tx, testigos)]);
    let nuevo = aplicar(&estado, &bloque, &params(), CBID_RED_DEV).unwrap();

    assert!(invariante_i1(&nuevo));
    assert!(invariante_i1b(&nuevo));
    assert_eq!(nuevo.activo_de(&pk), Amount::nuevo(6).unwrap());
    assert!(
        nuevo
            .utxo
            .values()
            .any(|e| e.valor == Amount::nuevo(4).unwrap() && e.origen == Origen::Tx),
        "el cambio MUST existir en el UTXO"
    );
}

// ── V5 · MultiSig ──────────────────────────────────────────────────────────

#[test]
fn multisig_2_de_3_autoriza_y_el_orden_importa() {
    let (sk0, pk0) = par(10);
    let (_, pk1) = par(11);
    let (sk2, pk2) = par(12);
    let lock = Lock::multisig(2, vec![pk0, pk1, pk2]).unwrap();
    let op = outpoint(9, 0);
    let tx = tx_transferencia(vec![txin(op)], vec![tx_out(9, pk0)]);
    let gastadas = vec![SpentOutput {
        value: Amount::nuevo(10).unwrap(),
        lock: lock.clone(),
    }];
    let digest = zx_core::sighash(&tx, &gastadas, HashType::All, 0, CBID_RED_DEV).unwrap();
    let f0: [u8; 64] = sk0.sign(digest.as_bytes()).into();
    let f2: [u8; 64] = sk2.sign(digest.as_bytes()).into();

    let mut ordenado = vec![0u8];
    ordenado.extend_from_slice(&f0);
    ordenado.push(2u8);
    ordenado.extend_from_slice(&f2);

    let mut desordenado = vec![2u8];
    desordenado.extend_from_slice(&f2);
    desordenado.push(0u8);
    desordenado.extend_from_slice(&f0);

    let mut estado = estado_pow();
    estado
        .utxo
        .insert(op, entrada(10, lock, Origen::Tx, Punto::Altura(0)));
    let valido = bloque_pow(1, vec![(tx.clone(), vec![ordenado])]);
    assert!(aplicar(&estado, &valido, &params(), CBID_RED_DEV).is_ok());

    let invalido = bloque_pow(1, vec![(tx, vec![desordenado])]);
    assert_eq!(
        aplicar(&estado, &invalido, &params(), CBID_RED_DEV),
        Err(ErrorTransicion::ErrFirma),
        "los índices de MultiSig MUST ser estrictamente crecientes"
    );
}

// ── V5 · rechazos de coinbase ──────────────────────────────────────────────

#[test]
fn coinbase_pow_sin_salidas_se_rechaza() {
    let (_, _pk) = par(3);
    let estado = estado_pow();
    let bloque = bloque_pow(1, vec![(tx_coinbase_pow(Vec::new()), Vec::new())]);
    assert_eq!(
        aplicar(&estado, &bloque, &params(), CBID_RED_DEV),
        Err(ErrorTransicion::ErrEmision)
    );
}

#[test]
fn dos_coinbases_se_rechazan() {
    let (_, pk) = par(4);
    let estado = estado_pow();
    let cb = tx_coinbase_pow(vec![tx_out(1, pk)]);
    let bloque = bloque_pow(1, vec![(cb.clone(), Vec::new()), (cb, Vec::new())]);
    assert_eq!(
        aplicar(&estado, &bloque, &params(), CBID_RED_DEV),
        Err(ErrorTransicion::ErrEmision)
    );
}

#[test]
fn coinbase_post_en_posicion_dos_se_rechaza() {
    let (sk, pk) = par(5);
    let estado = {
        let mut e = estado_post();
        con_garantia(&mut e, pk, 10);
        e
    };
    let retiro = tx_garantia(TipoGarantia::Retiro, pk, 1);
    let testigo = aceptacion(&sk, &retiro);
    let cb = tx_coinbase_post(pk, 3);
    let bloque = bloque_post(1, pk, vec![(retiro, vec![testigo]), (cb, Vec::new())]);
    assert_eq!(
        aplicar(&estado, &bloque, &params(), CBID_RED_DEV),
        Err(ErrorTransicion::ErrEmision)
    );
}

#[test]
fn coinbase_post_a_otra_clave_se_rechaza() {
    let (_, pk) = par(6);
    let (_, otra) = par(7);
    let estado = {
        let mut e = estado_post();
        con_garantia(&mut e, pk, 10);
        e
    };
    let cb = tx_coinbase_post(otra, 3);
    let bloque = bloque_post(1, pk, vec![(cb, Vec::new())]);
    assert_eq!(
        aplicar(&estado, &bloque, &params(), CBID_RED_DEV),
        Err(ErrorTransicion::ErrAutorizacion)
    );
}

// ── V5 · modo fusión ───────────────────────────────────────────────────────

#[test]
fn fusion_descarta_doble_gasto() {
    let (sk, pk) = par(20);
    let op = outpoint(5, 0);
    let t1 = tx_transferencia(vec![txin(op)], vec![tx_out(9, pk)]);
    let t2 = tx_transferencia(vec![txin(op)], vec![tx_out(8, pk)]);
    let gastadas = vec![SpentOutput {
        value: Amount::nuevo(10).unwrap(),
        lock: Lock::PubKey { pubkey: pk },
    }];
    let w1 = vec![firma_entrada(&sk, &t1, &gastadas, 0)];
    let w2 = vec![firma_entrada(&sk, &t2, &gastadas, 0)];
    let cb = tx_coinbase_post(pk, 3);

    let mut estado = estado_post();
    con_garantia(&mut estado, pk, 10);
    estado.utxo.insert(
        op,
        entrada(
            10,
            Lock::PubKey { pubkey: pk },
            Origen::Tx,
            Punto::Altura(0),
        ),
    );
    // Estado de partida consistente con I-1 (UTXO 10 + garantía 10).
    estado.emitido = 20;
    estado.subsidio_acum = 20;
    let bloque = bloque_post(1, pk, vec![(cb, Vec::new()), (t1, w1), (t2, w2)]);
    let (nuevo, _undo, descartadas) =
        aplicar_fusion(&estado, &bloque, Punto::Slot(1), &params(), CBID_RED_DEV).unwrap();
    assert_eq!(descartadas.len(), 1);
    assert_eq!(descartadas[0].motivo, ErrorTransicion::ErrDobleGasto);
    assert!(invariante_i1(&nuevo));
}

#[test]
fn fusion_descarta_retiro_duplicado() {
    let (sk, pk) = par(21);
    let t1 = tx_garantia(TipoGarantia::Retiro, pk, 3);
    let t2 = tx_garantia(TipoGarantia::Retiro, pk, 2);
    let w1 = vec![aceptacion(&sk, &t1)];
    let w2 = vec![aceptacion(&sk, &t2)];
    let cb = tx_coinbase_post(pk, 3);

    let mut estado = estado_post();
    con_garantia(&mut estado, pk, 10);
    estado.emitido = 10;
    estado.subsidio_acum = 10;
    let bloque = bloque_post(1, pk, vec![(cb, Vec::new()), (t1, w1), (t2, w2)]);
    let (nuevo, _undo, descartadas) =
        aplicar_fusion(&estado, &bloque, Punto::Slot(1), &params(), CBID_RED_DEV).unwrap();
    assert_eq!(descartadas.len(), 1);
    assert_eq!(descartadas[0].motivo, ErrorTransicion::ErrRetiroPendiente);
    let g = nuevo.garantias.get(&pk).unwrap();
    assert_eq!(g.activo, Amount::nuevo(7).unwrap());
    assert_eq!(g.en_retirada.len(), 1);
}

#[test]
fn fusion_descarta_liberacion_prematura() {
    let (sk, pk) = par(22);
    let t1 = tx_garantia(TipoGarantia::Liberacion, pk, 5);
    let w1 = vec![aceptacion(&sk, &t1)];
    let cb = tx_coinbase_post(pk, 3);

    let mut estado = estado_post();
    con_garantia(&mut estado, pk, 1);
    if let Some(g) = estado.garantias.get_mut(&pk) {
        g.en_retirada.push(EnRetirada {
            importe: Amount::nuevo(5).unwrap(),
            inicio_slot: 0,
        });
    }
    estado.emitido = 6;
    estado.subsidio_acum = 6;
    let bloque = bloque_post(1, pk, vec![(cb, Vec::new()), (t1, w1)]);
    let (nuevo, _undo, descartadas) =
        aplicar_fusion(&estado, &bloque, Punto::Slot(1), &params(), CBID_RED_DEV).unwrap();
    assert_eq!(descartadas.len(), 1);
    assert_eq!(descartadas[0].motivo, ErrorTransicion::ErrSaldo);
    let _ = nuevo;
}

#[test]
fn fusion_recorta_la_coinbase_post() {
    let (_, pk) = par(23);
    let cb = tx_coinbase_post(pk, 100);
    let mut estado = estado_post();
    con_garantia(&mut estado, pk, 10);
    estado.emitido = 10;
    estado.subsidio_acum = 10;
    let bloque = bloque_post(1, pk, vec![(cb, Vec::new())]);
    let (nuevo, _undo, descartadas) =
        aplicar_fusion(&estado, &bloque, Punto::Slot(1), &params(), CBID_RED_DEV).unwrap();
    assert!(descartadas.is_empty());
    let g = nuevo.garantias.get(&pk).unwrap();
    assert_eq!(
        g.activo,
        Amount::nuevo(10).unwrap(),
        "no se emite el exceso"
    );
    assert_eq!(g.creditos.len(), 1);
    assert_eq!(g.creditos[0].importe, Amount::nuevo(3).unwrap());
    assert_eq!(g.creditos[0].madura_en_slot, Some(2));
    assert!(invariante_i1(&nuevo));
    assert!(invariante_i1b(&nuevo));
}
