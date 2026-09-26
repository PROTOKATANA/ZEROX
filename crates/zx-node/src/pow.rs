//! Fase PoW: plantilla, depósito F-15, minero en su hilo (decisión 3 y 5 de la orden).
//!
//! El bucle de consenso construye la plantilla completa (cabecera sin `nonce`, transacciones y
//! testigos) con el estado que solo él conoce (nonces de garantía, madurez de coinbases propias);
//! el hilo minero **solo** busca el `nonce` con [`zx_consensus::minar`] y lo devuelve. El hilo
//! minero no decide nada de consenso: es CPU pura.

use core::sync::atomic::AtomicBool;
use std::sync::mpsc::{Receiver, Sender};

use ed25519_zebra::SigningKey;
use primitive_types::U256;
use zx_consensus::dificultad::{VentanaRetarget, siguiente_target};
use zx_consensus::{PARAMETROS_POW_DEV, Sha3Dev, minar};
use zx_core::preimage::block::{BlockHeader, merkle_root};
use zx_core::{
    Amount, ClavePublica, EncodingError, ExtensionTx, HashType, Lock, OutPoint, SpentOutput,
    TipoGarantia, Tx, TxId, TxIn, TxOut, codificar_con, decodificar_con, txid,
};

use crate::claves::ClaveDev;
use crate::error::ErrorNodo;
use crate::perfil::subsidio_pow;

/// Una salida de coinbase PoW propia, para seguir su madurez (decisión 5).
#[derive(Clone, Copy, Debug)]
pub struct CoinbasePropia {
    /// Índice de la clave dueña (posición en `claves`, no el índice de derivación).
    pub indice_clave: usize,
    /// Altura en la que se creó.
    pub altura: u32,
    /// `txid` de la coinbase.
    pub txid: TxId,
    /// Importe de la salida (única, índice 0).
    pub valor: Amount,
    /// ¿Ya se depositó (para no repetirlo)?
    pub depositada: bool,
}

/// Plantilla PoW completa que el bucle entrega al hilo minero.
#[derive(Clone)]
pub struct PlantillaPow {
    /// Cabecera con `nonce = 0`; el minero solo itera ese campo.
    pub cabecera_base: BlockHeader,
    /// Target que debe cumplir `hash_pow`.
    pub target: U256,
    /// Transacciones del cuerpo (coinbase, y depósitos si tocan).
    pub txs: Vec<Tx>,
    /// Testigos paralelos a `txs`.
    pub testigos: Vec<Vec<Vec<u8>>>,
}

/// Calcula el target de la altura `altura` (1-based) a partir del historial de cabeceras
/// `historial[0..=altura-1]` (índice = altura, `historial[0]` es el génesis).
///
/// # Errores
/// Los de `zx_consensus::dificultad`/`decodificar_con` si el historial es insuficiente o los bits no
/// decodifican.
pub fn target_de_altura(
    historial: &[BlockHeader],
    altura: u32,
) -> Result<U256, zx_consensus::ErrorPow> {
    let n = PARAMETROS_POW_DEV.n;
    let altura_usize = altura as usize;
    if altura_usize <= n {
        return decodificar_con(
            PARAMETROS_POW_DEV.bits_iniciales,
            &PARAMETROS_POW_DEV.limites,
        )
        .map_err(|_| zx_consensus::ErrorPow::DesbordamientoAritmetico);
    }
    // H > N: ventana de N+1 timestamps [H-N-1, H-1] y N targets [H-N, H-1].
    let desde_ts = altura_usize - n - 1;
    let timestamps: Vec<i64> = historial
        .get(desde_ts..altura_usize)
        .ok_or(zx_consensus::ErrorPow::VentanaVacia)?
        .iter()
        .map(|h| i64::try_from(h.timestamp).unwrap_or(i64::MAX))
        .collect();
    let desde_target = altura_usize - n;
    let mut targets = Vec::with_capacity(n);
    for h in historial
        .get(desde_target..altura_usize)
        .ok_or(zx_consensus::ErrorPow::VentanaVacia)?
    {
        let t = decodificar_con(h.bits, &PARAMETROS_POW_DEV.limites)
            .map_err(|_| zx_consensus::ErrorPow::DesbordamientoAritmetico)?;
        targets.push(t);
    }
    siguiente_target(
        VentanaRetarget {
            timestamps: &timestamps,
            targets: &targets,
        },
        &PARAMETROS_POW_DEV,
    )
}

/// Construye la coinbase PoW (F-16): v1, sin entradas, una salida a `clave` con `subsidio_pow`.
#[must_use]
pub fn construir_coinbase_pow(clave: ClavePublica, altura: u32) -> Tx {
    Tx {
        version: 1,
        inputs: Vec::new(),
        outputs: vec![TxOut {
            value: subsidio_pow(altura),
            lock: Lock::PubKey { pubkey: clave },
        }],
        lock_time: 0,
        // F-16/C-EMIT-04: `expiry_height` MUST ser la altura del propio bloque.
        expiry_height: altura,
        extension: ExtensionTx::Ninguna,
    }
}

/// Construye un depósito v2 (F-15) que gasta **toda** una coinbase madura propia, ya firmado.
///
/// Consume `(coinbase.txid, 0)` entero como depósito (sin cambio): `q = 10 ZZK` y la coinbase vale
/// `50 ZZK`, así que un único depósito por clave basta con margen. Devuelve la transacción y sus
/// testigos (firma de la entrada 0 y aceptación, en ese orden: el mismo patrón que
/// `crates/zx-consensus/src/transicion/tests.rs`).
///
/// # Errores
/// [`EncodingError`] si el `sighash`/importe no son representables (no debería con las constantes
/// dev).
pub fn construir_deposito(
    coinbase: &CoinbasePropia,
    clave: &ClaveDev,
    nonce: u64,
    cbid: u32,
) -> Result<(Tx, Vec<Vec<u8>>), EncodingError> {
    let entrada = TxIn {
        outpoint: OutPoint {
            prev_txid: coinbase.txid,
            prev_index: 0,
        },
        sequence: 0,
    };
    let tx = Tx {
        version: 2,
        inputs: vec![entrada],
        outputs: Vec::new(),
        lock_time: 0,
        expiry_height: 0,
        extension: ExtensionTx::Garantia {
            tipo: TipoGarantia::Deposito,
            clave: clave.pk,
            importe: coinbase.valor,
            nonce,
        },
    };
    let testigos = testigos_deposito(&tx, coinbase.valor, clave.pk, &clave.sk, cbid)?;
    Ok((tx, testigos))
}

/// Testigos de un depósito construido por [`construir_deposito`]: firma de la entrada 0 y
/// aceptación, en ese orden.
///
/// # Errores
/// [`EncodingError`] si el `sighash` no se pudo calcular.
pub fn testigos_deposito(
    tx: &Tx,
    coinbase_valor: Amount,
    clave_lock: ClavePublica,
    sk: &SigningKey,
    cbid: u32,
) -> Result<Vec<Vec<u8>>, EncodingError> {
    let gastadas = [SpentOutput {
        value: coinbase_valor,
        lock: Lock::PubKey { pubkey: clave_lock },
    }];
    let digest = zx_core::sighash(tx, &gastadas, HashType::All, 0, cbid)?;
    let firma_entrada: [u8; 64] = sk.sign(digest.as_bytes()).into();
    let mensaje_aceptacion = zx_core::mensaje_aceptacion(tx, cbid);
    let firma_aceptacion: [u8; 64] = sk.sign(&mensaje_aceptacion).into();
    Ok(vec![firma_entrada.to_vec(), firma_aceptacion.to_vec()])
}

/// Construye la plantilla PoW de `altura`, con la coinbase de `clave_de_este_bloque` y los
/// depósitos ya decididos por el llamante (`bucle::preparar_depositos`).
///
/// # Errores
/// Los de `target_de_altura` si el historial es insuficiente (no debería con la construcción del
/// bucle, que siempre pide la siguiente altura contigua).
pub fn construir_plantilla(
    historial: &[BlockHeader],
    prev_hash: zx_core::BlockHash,
    altura: u32,
    timestamp: u64,
    cbid: u32,
    clave_de_este_bloque: ClavePublica,
    depositos: Vec<(Tx, Vec<Vec<u8>>)>,
) -> Result<(PlantillaPow, TxId, Amount), ErrorNodo> {
    let target = target_de_altura(historial, altura)
        .map_err(|e| ErrorNodo::Otro(format!("target de altura {altura}: {e}")))?;
    let bits = codificar_con(target, &PARAMETROS_POW_DEV.limites);

    let coinbase_tx = construir_coinbase_pow(clave_de_este_bloque, altura);
    let mut txs = vec![coinbase_tx.clone()];
    let mut testigos: Vec<Vec<Vec<u8>>> = vec![Vec::new()];
    for (tx, tst) in depositos {
        txs.push(tx);
        testigos.push(tst);
    }

    let txid_coinbase = txid(&coinbase_tx, cbid);
    #[expect(
        clippy::indexing_slicing,
        reason = "outputs tiene exactamente un elemento (construir_coinbase_pow)"
    )]
    let valor_coinbase = coinbase_tx.outputs[0].value;

    let txids: Vec<_> = txs.iter().map(|t| txid(t, cbid)).collect();
    let merkle = merkle_root(&txids);

    let cabecera_base = BlockHeader {
        consensus_branch_id: cbid,
        prev_hash,
        merkle_root: merkle,
        timestamp,
        bits,
        nonce: 0,
        height: altura,
    };
    Ok((
        PlantillaPow {
            cabecera_base,
            target,
            txs,
            testigos,
        },
        txid_coinbase,
        valor_coinbase,
    ))
}

/// Lo mínimo que el hilo minero necesita: cabecera base y target. No lleva transacciones ni
/// testigos (el bucle los conserva localmente; reenviarlos sería una copia inútil de datos que el
/// bucle ya tiene).
#[derive(Clone, Copy)]
pub struct TrabajoMinero {
    /// Cabecera con `nonce = 0`.
    pub cabecera_base: BlockHeader,
    /// Target que debe cumplir `hash_pow`.
    pub target: U256,
}

impl From<&PlantillaPow> for TrabajoMinero {
    fn from(p: &PlantillaPow) -> Self {
        Self {
            cabecera_base: p.cabecera_base,
            target: p.target,
        }
    }
}

/// Cuerpo del hilo minero: recibe trabajos, mina y devuelve la cabecera con `nonce`.
///
/// Se detiene (decisión 3, «se detiene en el corte») cuando el canal de entrada se cierra: el bucle
/// deja de enviar trabajos tras fijar el terminal.
pub fn hilo_minero(rx: Receiver<TrabajoMinero>, tx: Sender<BlockHeader>) {
    let cancelar = AtomicBool::new(false);
    for trabajo in rx {
        let Some(minada) = minar(
            &trabajo.cabecera_base,
            trabajo.target,
            &Sha3Dev,
            u64::MAX,
            &cancelar,
        ) else {
            // `max_intentos = u64::MAX` con `cancelar` siempre en `false`: no debería devolver
            // `None`. Si ocurriera, se detiene el hilo en vez de fingir una cabecera.
            break;
        };
        if tx.send(minada).is_err() {
            break;
        }
    }
}
