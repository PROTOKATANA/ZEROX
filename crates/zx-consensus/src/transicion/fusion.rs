//! Modo **fusión** (`CONTRATO-ESTADO-DAG-v0` §3, `ORDEN-W03` §3.11).
//!
//! A diferencia de [`crate::transicion::aplicar`], aquí una transacción que no valida **se
//! descarta** con su motivo (`ED-4`…`ED-6`) en vez de invalidar el bloque; solo invalidan el bloque
//! las comprobaciones que la tabla de §3 marca como tales (forma, coinbase estructural, garantía del
//! productor). La coinbase PoST se acredita por `mín(declarado, subsidio_post(slot(B)) + tarifas
//! aceptadas)`.
//!
//! La orquestación completa del DAG (ED-1…ED-3, orden del mergeset, `rojo_U3`) es de W06a; aquí se
//! implementan las primitivas que W03 exige y se prueban con los casos de V5.

use zx_core::{Amount, ExtensionTx};

use crate::transicion::ErrorTransicion;
use crate::transicion::aplicar::{
    Efecto, aplicar_con_undo, aplicar_tx, es_coinbase, validar_bloque,
};
use crate::transicion::estado::{Aplicador, acreditar_credito};
use crate::transicion::tipos::{
    BloqueTransicion, Estado, Fase, HechosCabecera, ParametrosTransicion, Pendiente, Punto,
    TxDescartada, Undo,
};

/// Aplica un bloque en **modo fusión** desde `punto_aplicacion`.
///
/// Devuelve el estado nuevo, el undo por delta y las transacciones descartadas con su motivo.
///
/// # Errores
/// Solo los que invalidan el bloque según la tabla de §3 del contrato de estado DAG.
pub fn aplicar_fusion(
    estado: &Estado,
    bloque: &BloqueTransicion,
    punto_aplicacion: Punto,
    params: &ParametrosTransicion,
    cbid: u32,
) -> Result<(Estado, Undo, Vec<TxDescartada>), ErrorTransicion> {
    validar_bloque(bloque)?;
    if matches!(bloque.hechos, HechosCabecera::Genesis { .. }) {
        let (nuevo, undo) = aplicar_con_undo(estado, bloque, params, cbid)?;
        return Ok((nuevo, undo, Vec::new()));
    }
    let mut ap = Aplicador::nuevo(estado.clone());
    let mut descartadas: Vec<TxDescartada> = Vec::new();
    match &bloque.hechos {
        HechosCabecera::PoW { .. } => {
            fusion_pow(
                &mut ap,
                bloque,
                punto_aplicacion,
                params,
                cbid,
                &mut descartadas,
            )?;
        }
        HechosCabecera::PoST { .. } => {
            fusion_post(
                &mut ap,
                bloque,
                punto_aplicacion,
                params,
                cbid,
                &mut descartadas,
            )?;
        }
        HechosCabecera::Genesis { .. } => {}
    }
    Ok((ap.estado, ap.undo, descartadas))
}

/// Cuenta coinbases y comprueba posición (tabla de §3: invalida el bloque).
fn coinbase_unica(bloque: &BloqueTransicion) -> Result<Option<usize>, ErrorTransicion> {
    let mut ncb = 0usize;
    let mut idx = 0usize;
    for (i, (tx, _)) in bloque.txs.iter().enumerate() {
        if es_coinbase(tx) {
            ncb += 1;
            idx = i;
        }
    }
    if ncb > 1 {
        return Err(ErrorTransicion::ErrEmision);
    }
    if ncb == 1 && idx != 0 {
        return Err(ErrorTransicion::ErrEmision);
    }
    Ok((ncb == 1).then_some(idx))
}

/// Descartable auxiliar: aplica `tx` y, si falla, revierte y registra el motivo.
#[expect(
    clippy::too_many_arguments,
    reason = "reúne el contexto de la transacción; agruparlo escondería la regla"
)]
fn intentar(
    ap: &mut Aplicador,
    bloque: &BloqueTransicion,
    params: &ParametrosTransicion,
    cbid: u32,
    punto: Punto,
    indice: usize,
    tx: &zx_core::Tx,
    testigos: &[Vec<u8>],
    descartadas: &mut Vec<TxDescartada>,
) -> Result<Option<Amount>, ErrorTransicion> {
    let marca = ap.marcar();
    match aplicar_tx(ap, bloque, params, cbid, punto, tx, testigos) {
        Ok(Efecto::Fee(fee)) => Ok(Some(fee)),
        Ok(Efecto::Coinbase(_)) => Ok(None),
        Err(motivo) => {
            ap.revertir_a(marca);
            descartadas.push(TxDescartada {
                indice,
                txid: zx_core::txid(tx, cbid),
                motivo,
            });
            Ok(None)
        }
    }
}

/// Aplica una coinbase PoST v3 acreditando `importe` (ya recortado).
fn acreditar_coinbase_post(
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

/// Fusiona un bloque PoW: la coinbase invalida el bloque si falla; el resto se descarta.
fn fusion_pow(
    ap: &mut Aplicador,
    bloque: &BloqueTransicion,
    punto: Punto,
    params: &ParametrosTransicion,
    cbid: u32,
    descartadas: &mut Vec<TxDescartada>,
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
    if !pow_valido {
        return Err(ErrorTransicion::ErrPow);
    }
    if trabajo.is_zero() {
        return Err(ErrorTransicion::ErrPow);
    }
    ap.promover(punto, false, params)?;
    let coinbase = coinbase_unica(bloque)?;
    let mut coinbase_pagada = Amount::CERO;
    if let Some(idx) = coinbase {
        let Some((tx, testigos)) = bloque.txs.get(idx) else {
            return Err(ErrorTransicion::ErrGenesis);
        };
        match aplicar_tx(ap, bloque, params, cbid, punto, tx, testigos)? {
            Efecto::Coinbase(pagada) => coinbase_pagada = pagada,
            Efecto::Fee(_) => return Err(ErrorTransicion::ErrEmision),
        }
    }
    let mut tarifas = Amount::CERO;
    for (i, (tx, testigos)) in bloque.txs.iter().enumerate() {
        if Some(i) == coinbase {
            continue;
        }
        if let Some(fee) = intentar(
            ap,
            bloque,
            params,
            cbid,
            punto,
            i,
            tx,
            testigos,
            descartadas,
        )? {
            tarifas = tarifas
                .suma_comprobada(fee)
                .ok_or(ErrorTransicion::ErrDesbordamiento)?;
        }
    }
    let subsidio = (params.subsidio_pow)(*altura);
    let tope = subsidio
        .suma_comprobada(tarifas)
        .ok_or(ErrorTransicion::ErrDesbordamiento)?;
    if coinbase_pagada > tope {
        return Err(ErrorTransicion::ErrEmision);
    }
    ap.estado.emitido += i128::from(coinbase_pagada.brek()) - i128::from(tarifas.brek());
    ap.estado.subsidio_acum += i128::from(subsidio.brek());
    ap.estado.trabajo = ap
        .estado
        .trabajo
        .checked_add(*trabajo)
        .ok_or(ErrorTransicion::ErrDesbordamiento)?;
    ap.estado.altura = *altura;
    if crate::transicion::aplicar::es_terminal_condiciones(&ap.estado, params, *altura) {
        ap.estado.terminal = Some(*hash);
        ap.estado.altura_terminal = Some(*altura);
    }
    Ok(())
}

/// Fusiona un bloque PoST: coinbase v3 recortada, resto descartable.
fn fusion_post(
    ap: &mut Aplicador,
    bloque: &BloqueTransicion,
    punto: Punto,
    params: &ParametrosTransicion,
    cbid: u32,
    descartadas: &mut Vec<TxDescartada>,
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
        Fase::PoST => {}
        Fase::Genesis => return Err(ErrorTransicion::ErrGenesis),
    }
    if !prueba_valida {
        return Err(ErrorTransicion::ErrPow);
    }
    if *peso < 1 {
        return Err(ErrorTransicion::ErrSlot);
    }
    ap.promover(punto, true, params)?;
    if ap.estado.activo_de(productor) < params.q {
        return Err(ErrorTransicion::ErrGarantia);
    }
    let Some(cero) = coinbase_unica(bloque)? else {
        return Err(ErrorTransicion::ErrEmision);
    };
    if cero != 0 {
        return Err(ErrorTransicion::ErrEmision);
    }
    // Pre-pasada sobre una copia: conjunto aceptado, tarifas y descartes.
    let mut temporal = Aplicador::nuevo(ap.estado.clone());
    let mut tarifas = Amount::CERO;
    let mut aceptadas: Vec<usize> = Vec::new();
    for (i, (tx, testigos)) in bloque.txs.iter().enumerate().skip(1) {
        let marca = temporal.marcar();
        match aplicar_tx(&mut temporal, bloque, params, cbid, punto, tx, testigos) {
            Ok(Efecto::Fee(fee)) => {
                tarifas = tarifas
                    .suma_comprobada(fee)
                    .ok_or(ErrorTransicion::ErrDesbordamiento)?;
                aceptadas.push(i);
            }
            Ok(Efecto::Coinbase(_)) => {}
            Err(motivo) => {
                temporal.revertir_a(marca);
                descartadas.push(TxDescartada {
                    indice: i,
                    txid: zx_core::txid(tx, cbid),
                    motivo,
                });
            }
        }
    }
    let Some((tx_coinbase, _)) = bloque.txs.get(cero) else {
        return Err(ErrorTransicion::ErrEmision);
    };
    let declarado = match &tx_coinbase.extension {
        ExtensionTx::CoinbasePost {
            clave,
            importe,
            slot: slot_tx,
        } => {
            if *clave != *productor {
                return Err(ErrorTransicion::ErrAutorizacion);
            }
            // F-17: el `slot` de la v3 MUST ser el slot del bloque que la contiene (FD-4).
            if *slot_tx != *slot {
                return Err(ErrorTransicion::ErrEmision);
            }
            *importe
        }
        _ => {
            return Err(ErrorTransicion::ErrForma(
                zx_core::ErrorFormaTx::ExtensionIncoherente {
                    version: tx_coinbase.version,
                    esperada: "CoinbasePost",
                },
            ));
        }
    };
    let subsidio = (params.subsidio_post)(*slot);
    let tope = subsidio
        .suma_comprobada(tarifas)
        .ok_or(ErrorTransicion::ErrDesbordamiento)?;
    let efectiva = if declarado <= tope { declarado } else { tope };
    acreditar_coinbase_post(ap, *productor, efectiva, punto, params)?;
    for i in aceptadas {
        let Some((tx, testigos)) = bloque.txs.get(i) else {
            continue;
        };
        let marca = ap.marcar();
        if let Err(motivo) = aplicar_tx(ap, bloque, params, cbid, punto, tx, testigos) {
            ap.revertir_a(marca);
            descartadas.push(TxDescartada {
                indice: i,
                txid: zx_core::txid(tx, cbid),
                motivo,
            });
        }
    }
    ap.estado.emitido += i128::from(efectiva.brek()) - i128::from(tarifas.brek());
    ap.estado.subsidio_acum += i128::from(subsidio.brek());
    Ok(())
}
