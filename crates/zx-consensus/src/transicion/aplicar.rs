//! Aplicación **estricta** de un bloque sobre un estado (`ORDEN-W03` §3.6–§3.7).
//!
//! El orden es el de `ORDEN-T01` §3.9: (a) forma y familia; (b) promoción de pendientes; (c) garantía
//! del productor en PoST; (d) transacciones, coinbase primera; (e) terminal en PoW. Cualquier fallo
//! invalida el bloque entero.

use std::collections::BTreeSet;

use primitive_types::U256;
use zx_core::{
    Amount, ClavePublica, DagBlockHeader, ErrorFormaTx, ExtensionTx, Firma, HashType, Lock,
    OutPoint, SpentOutput, TipoGarantia, Tx, TxId, TxOut, ZX_VALUE_SANITY_LIMIT,
    incident_id_evidencia, validar_forma_cabecera_post, validar_forma_tx, validar_forma_tx_v4,
};

use crate::transicion::ErrorTransicion;
use crate::transicion::estado::{
    Aplicador, acreditar_credito, acreditar_pendiente, debitar_garantia, gastable_en, phi,
    podar_incidentes, suelo_dos_octavos, techo_fraccion, total_garantia,
};
use crate::transicion::tipos::{
    BloqueTransicion, EnRetirada, EntradaUtxo, Estado, Fase, HechosCabecera, Incidente, Origen,
    ParametrosEvidencia, ParametrosTransicion, Pendiente, Punto, Undo,
};

/// Aplica un bloque y devuelve el estado nuevo (sin undo).
///
/// # Errores
/// La variante de [`ErrorTransicion`] que corresponda a la regla incumplida.
pub fn aplicar(
    estado: &Estado,
    bloque: &BloqueTransicion,
    params: &ParametrosTransicion,
    cbid: u32,
    evp: &ParametrosEvidencia,
) -> Result<Estado, ErrorTransicion> {
    let (nuevo, _) = aplicar_con_undo(estado, bloque, params, cbid, evp)?;
    Ok(nuevo)
}

/// Aplica un bloque y devuelve `(estado nuevo, undo por delta)`.
///
/// Propiedad exigida: `deshacer(&nuevo, &undo) == *estado` (igualdad estructural).
///
/// # Errores
/// La variante de [`ErrorTransicion`] que corresponda a la regla incumplida.
pub fn aplicar_con_undo(
    estado: &Estado,
    bloque: &BloqueTransicion,
    params: &ParametrosTransicion,
    cbid: u32,
    evp: &ParametrosEvidencia,
) -> Result<(Estado, Undo), ErrorTransicion> {
    validar_bloque(bloque, evp)?;
    let mut ap = Aplicador::nuevo(estado.clone());
    match &bloque.hechos {
        HechosCabecera::Genesis { .. } => aplicar_genesis(&mut ap, &bloque.txs)?,
        HechosCabecera::PoW { .. } => aplicar_pow(&mut ap, bloque, params, cbid, evp)?,
        HechosCabecera::PoST { .. } => aplicar_post(&mut ap, bloque, params, cbid, evp)?,
    }
    Ok((ap.estado, ap.undo))
}

/// `validar_forma_tx` para cada transacción y `validar_forma_cabecera_post` si hay cabecera (§3.6).
///
/// SL-4a: la v4 solo se valida con su forma propia cuando el perfil activa la evidencia (`evp`); en
/// otro caso `validar_forma_tx` la rechaza como inactiva, como antes.
///
/// SL-4c: la forma de la v4 incluye `RAT-1` (las dos cabeceras con el `consensus_branch_id` de la
/// red local, `evp.cbid`) y el orden canónico (`EV-01`/`EV-04`); un fallo de forma de una
/// transacción invalida el bloque entero (el modo fusión también llama a esta función).
pub(crate) fn validar_bloque(
    bloque: &BloqueTransicion,
    evp: &ParametrosEvidencia,
) -> Result<(), ErrorTransicion> {
    if let Some(cabecera) = &bloque.cabecera_post {
        validar_forma_cabecera_post(cabecera)?;
    }
    for (tx, testigos) in &bloque.txs {
        if tx.version == 4 && evp.evp {
            validar_forma_tx_v4(tx, testigos, evp.cbid)?;
        } else {
            validar_forma_tx(tx, testigos)?;
        }
    }
    Ok(())
}

/// ¿La transacción es una coinbase (PoW v1 sin entradas, o PoST v3)?
pub(crate) fn es_coinbase(tx: &Tx) -> bool {
    (tx.version == 1 && tx.inputs.is_empty()) || tx.version == 3
}

/// Construye el `OutPoint` de la salida `j` de `txid`.
fn outpoint(txid: TxId, j: usize) -> Result<OutPoint, ErrorTransicion> {
    let prev_index = u32::try_from(j).map_err(|_| ErrorTransicion::ErrDesbordamiento)?;
    Ok(OutPoint {
        prev_txid: txid,
        prev_index,
    })
}

/// Suma de salidas con aritmética comprobada.
fn sumar_salidas(salidas: &[TxOut]) -> Result<Amount, ErrorTransicion> {
    let mut total = Amount::CERO;
    for s in salidas {
        total = total
            .suma_comprobada(s.value)
            .ok_or(ErrorTransicion::ErrDesbordamiento)?;
    }
    Ok(total)
}

/// Salidas gastadas por las entradas, en orden (para el sighash).
fn gastadas_de(ap: &Aplicador, tx: &Tx) -> Result<Vec<SpentOutput>, ErrorTransicion> {
    let mut gastadas = Vec::with_capacity(tx.inputs.len());
    for e in &tx.inputs {
        let entrada = ap
            .estado
            .utxo
            .get(&e.outpoint)
            .ok_or(ErrorTransicion::ErrDobleGasto)?;
        gastadas.push(SpentOutput {
            value: entrada.valor,
            lock: entrada.lock.clone(),
        });
    }
    Ok(gastadas)
}

/// Verifica la autorización de la entrada `i` con `SIGHASH_ALL`.
fn autorizar(
    lock: &Lock,
    testigo: &[u8],
    tx: &Tx,
    gastadas: &[SpentOutput],
    i: usize,
    cbid: u32,
) -> Result<(), ErrorTransicion> {
    let digest = zx_core::sighash(tx, gastadas, HashType::All, i, cbid)
        .map_err(|_| ErrorTransicion::ErrFirma)?;
    match lock {
        Lock::PubKey { pubkey } => {
            let bytes: [u8; 64] = testigo.try_into().map_err(|_| ErrorTransicion::ErrFirma)?;
            let firma = Firma::desde_bytes(bytes);
            zx_core::verificar(pubkey, &firma, digest.as_bytes())
                .map_err(|_| ErrorTransicion::ErrFirma)
        }
        Lock::MultiSig { k, pubkeys } => {
            let mut resto = testigo;
            let mut anterior: Option<u8> = None;
            for _ in 0..*k {
                let (idx_bytes, r) = resto.split_at_checked(1).ok_or(ErrorTransicion::ErrFirma)?;
                let idx = *idx_bytes.first().ok_or(ErrorTransicion::ErrFirma)?;
                if anterior.is_some_and(|prev| idx <= prev) {
                    return Err(ErrorTransicion::ErrFirma);
                }
                anterior = Some(idx);
                let (fb, r2) = r.split_at_checked(64).ok_or(ErrorTransicion::ErrFirma)?;
                let key = pubkeys
                    .get(usize::from(idx))
                    .ok_or(ErrorTransicion::ErrFirma)?;
                let bytes: [u8; 64] = fb.try_into().map_err(|_| ErrorTransicion::ErrFirma)?;
                zx_core::verificar(key, &Firma::desde_bytes(bytes), digest.as_bytes())
                    .map_err(|_| ErrorTransicion::ErrFirma)?;
                resto = r2;
            }
            if resto.is_empty() {
                Ok(())
            } else {
                Err(ErrorTransicion::ErrFirma)
            }
        }
        Lock::Htlc { .. } => Err(ErrorTransicion::ErrFirma),
    }
}

/// Consume las entradas de `tx`: duplicados, existencia, firma y madurez, en ese orden.
fn consumir_entradas(
    ap: &mut Aplicador,
    tx: &Tx,
    testigos: &[Vec<u8>],
    gastadas: &[SpentOutput],
    params: &ParametrosTransicion,
    cbid: u32,
    punto: Punto,
) -> Result<Amount, ErrorTransicion> {
    let mut vistos: BTreeSet<OutPoint> = BTreeSet::new();
    for e in &tx.inputs {
        if !vistos.insert(e.outpoint) {
            return Err(ErrorTransicion::ErrDobleGasto);
        }
    }
    let mut total = Amount::CERO;
    for (i, e) in tx.inputs.iter().enumerate() {
        let Some(entrada) = ap.estado.utxo.get(&e.outpoint) else {
            return Err(ErrorTransicion::ErrDobleGasto);
        };
        let testigo = testigos.get(i).ok_or(ErrorTransicion::ErrFirma)?;
        autorizar(&entrada.lock, testigo, tx, gastadas, i, cbid)?;
        if !gastable_en(
            entrada,
            ap.estado.fase,
            ap.estado.altura_terminal,
            ap.estado.s0,
            params,
            punto,
        ) {
            return Err(ErrorTransicion::ErrInmaduro);
        }
        total = total
            .suma_comprobada(entrada.valor)
            .ok_or(ErrorTransicion::ErrDesbordamiento)?;
    }
    for e in &tx.inputs {
        ap.borrar_utxo(e.outpoint);
    }
    let _ = cbid;
    Ok(total)
}

/// Verifica la firma de aceptación (último testigo) de una v2.
fn verificar_aceptacion_tx(
    tx: &Tx,
    testigos: &[Vec<u8>],
    cbid: u32,
) -> Result<(), ErrorTransicion> {
    let aceptacion = testigos.last().ok_or(ErrorTransicion::ErrFirma)?;
    zx_core::verificar_aceptacion(tx, aceptacion, cbid).map_err(|_| ErrorTransicion::ErrFirma)
}

/// Efecto de una transacción sobre la contabilidad del bloque.
pub(crate) enum Efecto {
    /// Tarifa aportada (puede ser 0).
    Fee(Amount),
    /// Importe de la coinbase.
    Coinbase(Amount),
}

/// Aplica una transferencia v1 y devuelve su tarifa.
fn aplicar_transferencia(
    ap: &mut Aplicador,
    params: &ParametrosTransicion,
    cbid: u32,
    punto: Punto,
    tx: &Tx,
    testigos: &[Vec<u8>],
) -> Result<Amount, ErrorTransicion> {
    if tx.outputs.is_empty() {
        return Err(ErrorTransicion::ErrSaldo);
    }
    let mut total = Amount::CERO;
    for e in &tx.inputs {
        let Some(entrada) = ap.estado.utxo.get(&e.outpoint) else {
            return Err(ErrorTransicion::ErrDobleGasto);
        };
        total = total
            .suma_comprobada(entrada.valor)
            .ok_or(ErrorTransicion::ErrDesbordamiento)?;
    }
    let salidas = sumar_salidas(&tx.outputs)?;
    if salidas > total {
        return Err(ErrorTransicion::ErrSaldo);
    }
    let gastadas = gastadas_de(ap, tx)?;
    consumir_entradas(ap, tx, testigos, &gastadas, params, cbid, punto)?;
    let txid = zx_core::txid(tx, cbid);
    for (j, out) in tx.outputs.iter().enumerate() {
        let op = outpoint(txid, j)?;
        if ap.estado.utxo.contains_key(&op) {
            return Err(ErrorTransicion::ErrDobleGasto);
        }
        ap.insertar_utxo(
            op,
            EntradaUtxo {
                valor: out.value,
                lock: out.lock.clone(),
                origen: Origen::Tx,
                creada: punto,
            },
        );
    }
    total
        .resta_comprobada(salidas)
        .ok_or(ErrorTransicion::ErrDesbordamiento)
}

/// Aplica una coinbase PoW v1.
fn aplicar_coinbase_pow(
    ap: &mut Aplicador,
    cbid: u32,
    punto: Punto,
    tx: &Tx,
) -> Result<Amount, ErrorTransicion> {
    if ap.estado.fase != Fase::PoW {
        return Err(ErrorTransicion::ErrOperacionFase);
    }
    if tx.outputs.is_empty() {
        return Err(ErrorTransicion::ErrEmision);
    }
    let altura = punto
        .como_altura()
        .ok_or(ErrorTransicion::ErrOperacionFase)?;
    // F-16: en la coinbase PoW `expiry_height` MUST ser la altura del bloque (restituye
    // `C-EMIT-04`); cualquier otro valor ⇒ `ErrEmision`. El génesis (altura 0) lo valida
    // `aplicar_genesis`, que no pasa por aquí.
    if tx.expiry_height != altura {
        return Err(ErrorTransicion::ErrEmision);
    }
    let txid = zx_core::txid(tx, cbid);
    let mut pagada = Amount::CERO;
    for (j, out) in tx.outputs.iter().enumerate() {
        let op = outpoint(txid, j)?;
        if ap.estado.utxo.contains_key(&op) {
            return Err(ErrorTransicion::ErrDobleGasto);
        }
        ap.insertar_utxo(
            op,
            EntradaUtxo {
                valor: out.value,
                lock: out.lock.clone(),
                origen: Origen::CoinbasePow,
                creada: Punto::Altura(altura),
            },
        );
        pagada = pagada
            .suma_comprobada(out.value)
            .ok_or(ErrorTransicion::ErrDesbordamiento)?;
    }
    Ok(pagada)
}

/// Acredita un crédito de coinbase PoST (D-T08) con madurez `M_rec_slots` desde `punto`.
fn creditar_post(
    ap: &mut Aplicador,
    productor: zx_core::ClavePublica,
    importe: Amount,
    punto: Punto,
    params: &ParametrosTransicion,
) -> Result<(), ErrorTransicion> {
    let slot = punto.como_slot().ok_or(ErrorTransicion::ErrOperacionFase)?;
    let madura = slot
        .checked_add(params.m_rec_slots)
        .ok_or(ErrorTransicion::ErrDesbordamiento)?;
    let g = ap.garantia_mut(productor);
    acreditar_credito(
        g,
        Pendiente {
            importe,
            madura_en_altura: None,
            madura_en_slot: Some(madura),
        },
        punto,
    )
}

/// Aplica una coinbase PoST v3 (crédito pendiente al productor).
fn aplicar_coinbase_post(
    ap: &mut Aplicador,
    bloque: &BloqueTransicion,
    params: &ParametrosTransicion,
    punto: Punto,
    tx: &Tx,
) -> Result<Amount, ErrorTransicion> {
    if ap.estado.fase != Fase::PoST {
        return Err(ErrorTransicion::ErrOperacionFase);
    }
    let ExtensionTx::CoinbasePost {
        clave,
        importe,
        slot,
    } = &tx.extension
    else {
        return Err(ErrorTransicion::ErrForma(
            ErrorFormaTx::ExtensionIncoherente {
                version: tx.version,
                esperada: "CoinbasePost",
            },
        ));
    };
    let productor = bloque
        .hechos
        .productor()
        .ok_or(ErrorTransicion::ErrGenesis)?;
    if *clave != productor {
        return Err(ErrorTransicion::ErrAutorizacion);
    }
    // F-17: el `slot` de la v3 MUST ser el slot del bloque que la contiene.
    if Some(*slot) != bloque.hechos.slot() {
        return Err(ErrorTransicion::ErrEmision);
    }
    creditar_post(ap, productor, *importe, punto, params)?;
    Ok(*importe)
}

/// Aplica una operación de garantía v2.
#[expect(
    clippy::too_many_arguments,
    reason = "el contexto de aplicación ya viene partido; agruparlo escondería la regla"
)]
fn aplicar_garantia(
    ap: &mut Aplicador,
    bloque: &BloqueTransicion,
    params: &ParametrosTransicion,
    cbid: u32,
    evp: &ParametrosEvidencia,
    punto: Punto,
    tx: &Tx,
    testigos: &[Vec<u8>],
    tipo: TipoGarantia,
    clave: zx_core::ClavePublica,
    importe: Amount,
    nonce: u64,
) -> Result<(), ErrorTransicion> {
    // F-15 · el nonce se comprueba **antes** que el resto de reglas de la operación, para toda
    // operación de garantía de `clave` (depósito, retiro y liberación). Una clave sin registro se
    // crea con `nonce_siguiente = 0` (lo hace `garantia_mut`). El incremento se registra en el undo
    // por delta, así que un descarte en modo fusión lo revierte.
    {
        let g = ap.garantia_mut(clave);
        if nonce != g.nonce_siguiente {
            return Err(ErrorTransicion::ErrNonce);
        }
        g.nonce_siguiente = g
            .nonce_siguiente
            .checked_add(1)
            .ok_or(ErrorTransicion::ErrDesbordamiento)?;
    }
    match tipo {
        TipoGarantia::Deposito => {
            if ap.estado.fase == Fase::PoW {
                let altura = bloque.hechos.altura().ok_or(ErrorTransicion::ErrGenesis)?;
                if altura < params.h_dep {
                    return Err(ErrorTransicion::ErrDepositoTemprano);
                }
            }
            verificar_aceptacion_tx(tx, testigos, cbid)?;
            let gastadas = gastadas_de(ap, tx)?;
            let total = consumir_entradas(ap, tx, testigos, &gastadas, params, cbid, punto)?;
            let salidas = sumar_salidas(&tx.outputs)?;
            let esperado = salidas
                .suma_comprobada(importe)
                .ok_or(ErrorTransicion::ErrDesbordamiento)?;
            if total != esperado {
                return Err(ErrorTransicion::ErrSaldo);
            }
            let txid = zx_core::txid(tx, cbid);
            for (j, out) in tx.outputs.iter().enumerate() {
                let op = outpoint(txid, j)?;
                if ap.estado.utxo.contains_key(&op) {
                    return Err(ErrorTransicion::ErrDobleGasto);
                }
                ap.insertar_utxo(
                    op,
                    EntradaUtxo {
                        valor: out.value,
                        lock: out.lock.clone(),
                        origen: Origen::Tx,
                        creada: punto,
                    },
                );
            }
            let es_post = ap.estado.fase == Fase::PoST;
            let s0 = ap.estado.s0;
            let (madura_altura, madura_slot) = match punto {
                Punto::Altura(h) => {
                    let ma = h
                        .checked_add(params.m_dep)
                        .ok_or(ErrorTransicion::ErrDesbordamiento)?;
                    let ms = s0
                        .checked_add(params.m_dep_slots)
                        .ok_or(ErrorTransicion::ErrDesbordamiento)?;
                    (Some(ma), Some(ms))
                }
                Punto::Slot(s) => {
                    let ms = s
                        .checked_add(params.m_dep_slots)
                        .ok_or(ErrorTransicion::ErrDesbordamiento)?;
                    (None, Some(ms))
                }
            };
            let g = ap.garantia_mut(clave);
            acreditar_pendiente(
                g,
                Pendiente {
                    importe,
                    madura_en_altura: madura_altura,
                    madura_en_slot: madura_slot,
                },
                punto,
                es_post,
            )
        }
        TipoGarantia::Retiro => {
            verificar_aceptacion_tx(tx, testigos, cbid)?;
            let es_post = ap.estado.fase == Fase::PoST;
            let s0 = ap.estado.s0;
            let inicio = if es_post {
                punto.como_slot().ok_or(ErrorTransicion::ErrOperacionFase)?
            } else {
                s0
            };
            let g = ap.garantia_mut(clave);
            if importe > g.activo {
                return Err(ErrorTransicion::ErrSaldo);
            }
            if !g.en_retirada.is_empty() {
                return Err(ErrorTransicion::ErrRetiroPendiente);
            }
            g.activo = g
                .activo
                .resta_comprobada(importe)
                .ok_or(ErrorTransicion::ErrSaldo)?;
            g.en_retirada.push(EnRetirada {
                importe,
                inicio_slot: inicio,
            });
            Ok(())
        }
        TipoGarantia::Liberacion => {
            if ap.estado.fase != Fase::PoST {
                return Err(ErrorTransicion::ErrOperacionFase);
            }
            verificar_aceptacion_tx(tx, testigos, cbid)?;
            let slot = punto.como_slot().ok_or(ErrorTransicion::ErrOperacionFase)?;
            let r_slots = params.r_slots;
            // EV-24(i): un incidente admitido y no liquidado bloquea la liberación.
            {
                let g = ap.garantia_mut(clave);
                if !g.incidentes.is_empty() {
                    return Err(ErrorTransicion::ErrCasoAbierto);
                }
            }
            // EV-24(ii)/EV-15b/RAT-3: ventana desde el último bloque producido por P.
            if let Some(usp) = ap.estado.ultimo_slot_producido.get(&clave).copied() {
                let limite = usp
                    .saturating_add(evp.plazo_slots)
                    .saturating_add(evp.m_margen_slots);
                if slot < limite {
                    return Err(ErrorTransicion::ErrVentanaAbierta);
                }
            }
            let g = ap.garantia_mut(clave);
            let mut vencido = Amount::CERO;
            for r in &g.en_retirada {
                if r.inicio_slot
                    .checked_add(r_slots)
                    .is_some_and(|x| x <= slot)
                {
                    vencido = vencido
                        .suma_comprobada(r.importe)
                        .ok_or(ErrorTransicion::ErrDesbordamiento)?;
                }
            }
            if importe > vencido {
                return Err(ErrorTransicion::ErrSaldo);
            }
            let mut restante = importe;
            let mut nuevas: Vec<EnRetirada> = Vec::with_capacity(g.en_retirada.len());
            for r in &g.en_retirada {
                let vencida = r
                    .inicio_slot
                    .checked_add(r_slots)
                    .is_some_and(|x| x <= slot);
                if restante.brek() > 0 && vencida {
                    if r.importe <= restante {
                        restante = restante
                            .resta_comprobada(r.importe)
                            .ok_or(ErrorTransicion::ErrDesbordamiento)?;
                    } else {
                        nuevas.push(EnRetirada {
                            importe: r
                                .importe
                                .resta_comprobada(restante)
                                .ok_or(ErrorTransicion::ErrDesbordamiento)?,
                            inicio_slot: r.inicio_slot,
                        });
                        restante = Amount::CERO;
                    }
                } else {
                    nuevas.push(r.clone());
                }
            }
            g.en_retirada = nuevas;
            // F-18: la salida implícita de la liberación es `(txid, 0)`; con F-15 el `txid` de cada
            // liberación de la clave ya es único, así que no hace falta contador de salidas.
            let txid = zx_core::txid(tx, cbid);
            let op = OutPoint {
                prev_txid: txid,
                prev_index: 0,
            };
            if ap.estado.utxo.contains_key(&op) {
                return Err(ErrorTransicion::ErrDobleGasto);
            }
            ap.insertar_utxo(
                op,
                EntradaUtxo {
                    valor: importe,
                    lock: Lock::PubKey { pubkey: clave },
                    origen: Origen::Liberacion,
                    creada: Punto::Slot(slot),
                },
            );
            Ok(())
        }
    }
}

/// Identidad de oportunidad de una cabecera de evidencia (`C-EVP-01` + `RAT-1`).
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
struct IdentidadEvidencia {
    cbid: u32,
    clave: ClavePublica,
    sector_index: u16,
    history_size: u64,
    chunk: [u8; 32],
    /// `i64`: el oráculo admite slots negativos; la cabecera los lleva en dos's complemento.
    slot: i64,
}

fn identidad_de_cabecera(h: &DagBlockHeader) -> IdentidadEvidencia {
    IdentidadEvidencia {
        cbid: h.consensus_branch_id,
        clave: h.sol.public_key,
        sector_index: h.sol.sector_index,
        history_size: h.sol.history_size,
        chunk: h.sol.chunk,
        slot: h.slot as i64,
    }
}

/// `Amount` saturado al límite de cordura, para el gravamen `congelado` (`EV-17`).
fn amount_saturado(v: i128) -> Amount {
    let b = i64::try_from(v)
        .unwrap_or(ZX_VALUE_SANITY_LIMIT)
        .min(ZX_VALUE_SANITY_LIMIT);
    Amount::nuevo(b).unwrap_or(Amount::CERO)
}

/// Aplica una `EvidenceTx` v4 (`EV-01`…`EV-22`, `RAT-1`/`RAT-2′`/`RAT-3`).
///
/// `RAT-1` (`cbid` de la red local), `EV-01` (orden canónico) y `EV-04` (sin entradas, salidas ni
/// testigos) ya son **forma** de la v4 y se comprueban en `validar_forma_tx_v4`, antes de esta
/// función; aquí solo queda la parte semántica. El orden es el del oráculo T01: identidad, sellos,
/// puerta RAT-3, ventana y deduplicación.
fn aplicar_evidencia(
    ap: &mut Aplicador,
    bloque: &BloqueTransicion,
    params: &ParametrosTransicion,
    evp: &ParametrosEvidencia,
    punto: Punto,
    tx: &Tx,
) -> Result<(), ErrorTransicion> {
    let ExtensionTx::Evidencia { h1, h2 } = &tx.extension else {
        return Err(ErrorTransicion::ErrForma(
            ErrorFormaTx::ExtensionIncoherente {
                version: 4,
                esperada: "Evidencia",
            },
        ));
    };
    // EV-06: identidad común exacta.
    let id1 = identidad_de_cabecera(h1);
    let id2 = identidad_de_cabecera(h2);
    if id1 != id2 {
        return Err(ErrorTransicion::ErrSinEvidencia);
    }
    // EV-07: sellos válidos bajo la misma `sol.public_key`.
    h1.verificar_sello()
        .map_err(|_| ErrorTransicion::ErrSinEvidencia)?;
    h2.verificar_sello()
        .map_err(|_| ErrorTransicion::ErrSinEvidencia)?;
    // RAT-3: puerta estructural.
    if params.r_slots <= evp.plazo_slots.saturating_add(evp.m_margen_slots) {
        return Err(ErrorTransicion::ErrPuertaRAT3);
    }
    // EV-13/EV-14: ventana de admisión en slots absolutos (i64: el oráculo admite negativos).
    let sf = id1.slot;
    let punto_slot = punto.como_slot().ok_or(ErrorTransicion::ErrOperacionFase)? as i64;
    let fin = sf.saturating_add(evp.plazo_slots as i64);
    if punto_slot < sf || punto_slot >= fin {
        return Err(ErrorTransicion::ErrEvidenciaTardia);
    }
    // EV-10/EV-12: `incident_id` y deduplicación.
    let clave = id1.clave;
    let iid = *incident_id_evidencia(
        id1.cbid,
        id1.clave.bytes(),
        id1.sector_index,
        id1.history_size,
        &id1.chunk,
        id1.slot as u64,
    )
    .as_bytes();
    {
        let g = ap.garantia_mut(clave);
        if g.incidentes.iter().any(|i| i.id == iid) {
            return Err(ErrorTransicion::ErrEvidenciaDuplicada);
        }
    }
    // EV-11: registro del incidente.
    let v = {
        let g = ap.garantia_mut(clave);
        g.incidentes.push(Incidente {
            id: iid,
            slot_falta: sf,
        });
        g.incidentes.sort_by_key(|a| a.id);
        total_garantia(g)
    };
    // EV-17: congelación total (gravamen derivado).
    {
        let g = ap.garantia_mut(clave);
        g.congelado = amount_saturado(v);
    }
    // EV-19: confiscación `C = min(V, techo(f·V))`.
    let c = core::cmp::min(v, techo_fraccion(v, evp.f_num, evp.f_den));
    {
        let g = ap.garantia_mut(clave);
        debitar_garantia(g, c)?;
    }
    // RAT-2′: `suelo(C·2/8)` a la coinbase del bloque que aplica; el resto se quema.
    let productor = bloque
        .hechos
        .productor()
        .ok_or(ErrorTransicion::ErrGenesis)?;
    let recompensa = suelo_dos_octavos(c);
    if recompensa > 0 {
        creditar_post(ap, productor, amount_saturado(recompensa), punto, params)?;
    }
    ap.estado.quemado += c - recompensa;
    // EV-20: remanente congelado tras la liquidación.
    {
        let g = ap.garantia_mut(clave);
        g.congelado = amount_saturado(total_garantia(g));
    }
    Ok(())
}

/// Aplica una transacción según su versión.
#[expect(
    clippy::too_many_arguments,
    reason = "sumar `evp` a la firma ya partida es preferible a agrupar el contexto en una struct opaca"
)]
pub(crate) fn aplicar_tx(
    ap: &mut Aplicador,
    bloque: &BloqueTransicion,
    params: &ParametrosTransicion,
    cbid: u32,
    evp: &ParametrosEvidencia,
    punto: Punto,
    tx: &Tx,
    testigos: &[Vec<u8>],
) -> Result<Efecto, ErrorTransicion> {
    match tx.version {
        1 => {
            if tx.inputs.is_empty() {
                let pagada = aplicar_coinbase_pow(ap, cbid, punto, tx)?;
                Ok(Efecto::Coinbase(pagada))
            } else {
                let fee = aplicar_transferencia(ap, params, cbid, punto, tx, testigos)?;
                Ok(Efecto::Fee(fee))
            }
        }
        2 => {
            let ExtensionTx::Garantia {
                tipo,
                clave,
                importe,
                nonce,
            } = &tx.extension
            else {
                return Err(ErrorTransicion::ErrForma(
                    ErrorFormaTx::ExtensionIncoherente {
                        version: 2,
                        esperada: "Garantia",
                    },
                ));
            };
            aplicar_garantia(
                ap, bloque, params, cbid, evp, punto, tx, testigos, *tipo, *clave, *importe, *nonce,
            )?;
            Ok(Efecto::Fee(Amount::CERO))
        }
        3 => {
            let importe = aplicar_coinbase_post(ap, bloque, params, punto, tx)?;
            Ok(Efecto::Coinbase(importe))
        }
        4 => {
            // X-13: la evidencia no existe en la fase PoW.
            if ap.estado.fase == Fase::PoW {
                return Err(ErrorTransicion::ErrOperacionFase);
            }
            if !evp.evp {
                return Err(ErrorTransicion::ErrFueraDeAlcanceV0);
            }
            aplicar_evidencia(ap, bloque, params, evp, punto, tx)?;
            Ok(Efecto::Fee(Amount::CERO))
        }
        version => Err(ErrorTransicion::ErrForma(ErrorFormaTx::VersionInactiva {
            version,
        })),
    }
}

/// Aplica todas las transacciones del bloque y actualiza `Emitido`/`subsidio_acum`.
fn aplicar_txs(
    ap: &mut Aplicador,
    bloque: &BloqueTransicion,
    params: &ParametrosTransicion,
    cbid: u32,
    evp: &ParametrosEvidencia,
    punto: Punto,
) -> Result<(), ErrorTransicion> {
    let mut ncb = 0usize;
    let mut idx_cb = 0usize;
    for (i, (tx, _)) in bloque.txs.iter().enumerate() {
        if es_coinbase(tx) {
            ncb += 1;
            idx_cb = i;
        }
    }
    if ncb > 1 {
        return Err(ErrorTransicion::ErrEmision);
    }
    if ncb == 1 && idx_cb != 0 {
        return Err(ErrorTransicion::ErrEmision);
    }
    let mut tarifas = Amount::CERO;
    let mut coinbase_pagada = Amount::CERO;
    for (tx, testigos) in &bloque.txs {
        match aplicar_tx(ap, bloque, params, cbid, evp, punto, tx, testigos)? {
            Efecto::Fee(fee) => {
                tarifas = tarifas
                    .suma_comprobada(fee)
                    .ok_or(ErrorTransicion::ErrDesbordamiento)?;
            }
            Efecto::Coinbase(pagada) => {
                coinbase_pagada = pagada;
            }
        }
    }
    let subsidio = match &bloque.hechos {
        HechosCabecera::PoW { altura, .. } => (params.subsidio_pow)(*altura),
        HechosCabecera::PoST { slot, .. } => (params.subsidio_post)(*slot),
        HechosCabecera::Genesis { .. } => return Err(ErrorTransicion::ErrGenesis),
    };
    let tope = subsidio
        .suma_comprobada(tarifas)
        .ok_or(ErrorTransicion::ErrDesbordamiento)?;
    if coinbase_pagada > tope {
        return Err(ErrorTransicion::ErrEmision);
    }
    ap.estado.emitido += i128::from(coinbase_pagada.brek()) - i128::from(tarifas.brek());
    ap.estado.subsidio_acum += i128::from(subsidio.brek());
    Ok(())
}

/// Aplica el génesis: única coinbase v1, con al menos una salida y todas de valor cero, que **no**
/// entra en el UTXO (`C-GEN-03`).
fn aplicar_genesis(ap: &mut Aplicador, txs: &[(Tx, Vec<Vec<u8>>)]) -> Result<(), ErrorTransicion> {
    if ap.estado.fase != Fase::Genesis {
        return Err(ErrorTransicion::ErrGenesis);
    }
    if txs.len() > 1 {
        return Err(ErrorTransicion::ErrGenesis);
    }
    if let Some((tx, _)) = txs.first() {
        if !(tx.version == 1
            && tx.inputs.is_empty()
            && matches!(tx.extension, ExtensionTx::Ninguna))
        {
            return Err(ErrorTransicion::ErrGenesis);
        }
        if tx.outputs.is_empty() {
            return Err(ErrorTransicion::ErrEmision);
        }
        if tx.outputs.iter().any(|o| o.value != Amount::CERO) {
            return Err(ErrorTransicion::ErrGenesis);
        }
    }
    ap.estado.fase = Fase::PoW;
    ap.estado.terminal = None;
    ap.estado.altura = 0;
    ap.estado.trabajo = U256::zero();
    ap.estado.slot = 0;
    ap.estado.s0 = 0;
    ap.estado.altura_terminal = None;
    Ok(())
}

/// Condiciones de terminal con la interfaz por defecto `CUT-HWΦ` (`TRN-04`).
#[must_use]
pub fn es_terminal_condiciones(
    estado: &Estado,
    params: &ParametrosTransicion,
    altura: u32,
) -> bool {
    altura >= params.h_corte_min && estado.trabajo >= params.w_min && phi(estado, params)
}

/// Aplica un bloque PoW.
fn aplicar_pow(
    ap: &mut Aplicador,
    bloque: &BloqueTransicion,
    params: &ParametrosTransicion,
    cbid: u32,
    evp: &ParametrosEvidencia,
) -> Result<(), ErrorTransicion> {
    let HechosCabecera::PoW {
        hash,
        altura,
        trabajo,
        pow_valido,
        ..
    } = &bloque.hechos
    else {
        return Err(ErrorTransicion::ErrGenesis);
    };
    match ap.estado.fase {
        Fase::PoW => {}
        Fase::PoST => return Err(ErrorTransicion::ErrPowTrasCorte),
        Fase::Genesis => return Err(ErrorTransicion::ErrGenesis),
    }
    if ap.estado.terminal.is_some() {
        return Err(ErrorTransicion::ErrPowTrasCorte);
    }
    if !pow_valido {
        return Err(ErrorTransicion::ErrPow);
    }
    if trabajo.is_zero() {
        return Err(ErrorTransicion::ErrPow);
    }
    let esperada = ap
        .estado
        .altura
        .checked_add(1)
        .ok_or(ErrorTransicion::ErrDesbordamiento)?;
    if *altura != esperada {
        return Err(ErrorTransicion::ErrSlot);
    }
    ap.promover(Punto::Altura(*altura), false, params)?;
    aplicar_txs(ap, bloque, params, cbid, evp, Punto::Altura(*altura))?;
    ap.estado.trabajo = ap
        .estado
        .trabajo
        .checked_add(*trabajo)
        .ok_or(ErrorTransicion::ErrDesbordamiento)?;
    ap.estado.altura = *altura;
    if es_terminal_condiciones(&ap.estado, params, *altura) {
        ap.estado.terminal = Some(*hash);
        ap.estado.altura_terminal = Some(*altura);
    }
    Ok(())
}

/// Aplica un bloque PoST.
fn aplicar_post(
    ap: &mut Aplicador,
    bloque: &BloqueTransicion,
    params: &ParametrosTransicion,
    cbid: u32,
    evp: &ParametrosEvidencia,
) -> Result<(), ErrorTransicion> {
    let HechosCabecera::PoST {
        padre,
        slot,
        productor,
        peso,
        prueba_valida,
        ..
    } = &bloque.hechos
    else {
        return Err(ErrorTransicion::ErrGenesis);
    };
    match ap.estado.fase {
        Fase::PoW => {
            let terminal = ap.estado.terminal.ok_or(ErrorTransicion::ErrSinTerminal)?;
            if *padre != terminal {
                return Err(ErrorTransicion::ErrSinTerminal);
            }
            if *slot < 1 {
                return Err(ErrorTransicion::ErrSlot);
            }
            ap.estado.fase = Fase::PoST;
            ap.estado.s0 = 0;
        }
        Fase::PoST => {
            if *slot <= ap.estado.slot {
                return Err(ErrorTransicion::ErrSlot);
            }
        }
        Fase::Genesis => return Err(ErrorTransicion::ErrGenesis),
    }
    if !prueba_valida {
        return Err(ErrorTransicion::ErrPow);
    }
    if *peso < 1 {
        return Err(ErrorTransicion::ErrSlot);
    }
    ap.promover(Punto::Slot(*slot), true, params)?;
    podar_incidentes(&mut ap.estado, evp, *slot); // EV-11
    let activo = ap.estado.activo_de(productor);
    if activo < params.q {
        return Err(ErrorTransicion::ErrGarantia);
    }
    aplicar_txs(ap, bloque, params, cbid, evp, Punto::Slot(*slot))?;
    ap.estado.slot = *slot;
    ap.estado.peso_sufijo = ap
        .estado
        .peso_sufijo
        .checked_add(*peso)
        .ok_or(ErrorTransicion::ErrDesbordamiento)?;
    // EV-24(ii): el bloque en curso entra en el pasado de los siguientes.
    let prev = ap.estado.ultimo_slot_producido.get(productor).copied();
    if prev.is_none_or(|p| *slot > p) {
        ap.estado.ultimo_slot_producido.insert(*productor, *slot);
    }
    Ok(())
}

/// ¿El último bloque de `historia` es el primer terminal de su rama? (`TRN-04`).
///
/// # Errores
/// Cualquier error de aplicación de la historia.
pub fn es_terminal(
    historia: &[BloqueTransicion],
    params: &ParametrosTransicion,
    cbid: u32,
    evp: &ParametrosEvidencia,
) -> Result<bool, ErrorTransicion> {
    let mut estado = Estado::inicial();
    let mut terminal: Option<zx_core::BlockHash> = None;
    for bloque in historia {
        let (nuevo, _) = aplicar_con_undo(&estado, bloque, params, cbid, evp)?;
        if matches!(bloque.hechos, HechosCabecera::PoW { .. }) && terminal.is_none() {
            terminal = nuevo.terminal;
        }
        estado = nuevo;
    }
    Ok(historia.last().is_some_and(|b| terminal == Some(b.hash())))
}
