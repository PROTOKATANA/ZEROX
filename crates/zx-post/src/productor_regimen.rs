//! Productor PoST **en régimen**: bloque DAG con varios padres, justificación PoT del rango
//! `(slot(sp(B)) + D, slot(B) + D]` y cuerpo con coinbase v3 (`C-POT-03`, `C-POT-05`, `C-HDR-03`,
//! `C-HDR-04`, `C-HDR-07`, `C-BON-03`, F-03, F-09, F-17, D-P09…D-P11).
//!
//! # Qué produce
//!
//! [`producir_en_regimen_sin_firmante`] recibe los **padres ya elegidos** por el llamante (`PadresDag`),
//! el **slot objetivo**, el [`ServicioPot`] ya arrancado en el terminal, una fuente de soluciones
//! PoAS, la clave que firma, los parámetros dev y el cuerpo (transacciones sin la coinbase) y
//! devuelve el bloque completo con la cabecera sellada.
//!
//! 1. Localiza `slot(sp(B))` en el pasado **registrado** del servicio (el terminal en slot 0 o un
//!    bloque que el llamante registró con [`ServicioPot::registrar_validado`]).
//! 2. Exige `slot(B) > slot(sp)` y que la diferencia no supere `MAX_BUNDLES_POT = 150`
//!    (`C-HDR-07`). Con `D = 0` (D-P10), `pot_output = salida(f, slot(B))`.
//! 3. Avanza el servicio hasta el slot objetivo si hace falta y audita la parcela **solo** en ese
//!    slot (el slot es exacto: los hermanos de un slot ya calculado se pueden producir sin volver
//!    a avanzar).
//! 4. Con la primera solución verificada construye: `padres` tal cual, `height = 0` (F-03), `slot`,
//!    `pot_output`, el rango `SR_dev`, los campos de la solución, la **justificación** con los
//!    portadores de `(slot(sp), slot(B)]`, el compromiso del cuerpo —coinbase v3 con **el slot de
//!    este bloque** (F-17) y las transacciones del llamante— y el **sello** sobre la prefirma.
//!
//! # Lo que NO hace
//!
//! **No elige padres ni su orden**: recibe el `PadresDag` ya construido (seleccionado primero).
//! No decide si la clave tiene garantía: eso es del motor de estado (`zx-cadena`). No elige `SR`
//! (constante dev, D-P11), no admite el bloque, no comprueba el cuerpo y no publica.
//!
//! # Firmante seguro (SL-4b1, SL-4b3)
//!
//! [`producir_en_regimen_sin_firmante`] sella directamente y **no** protege contra la doble firma:
//! **solo para tests y arneses**; el nodo ya no la alcanza (SL-4b2 lo dejó fuera y SL-4b3 lo hace
//! explícito con un guardián de CI). La variante [`producir_en_regimen_con_firmante`] construye
//! **exactamente** el mismo bloque y lo sella **solo** a través de [`Firmante`] (`C-EVP-06`,
//! FIR-01…FIR-15).
//!
//! # Frontera de confianza
//!
//! [`FuenteSoluciones`] afirma que la solución verificó contra las entradas proporcionadas; el
//! productor vuelve a exigir que sea de la clave que firma (C-HDR-04) y construye el sello. La
//! puerta conjunta de [`crate::cabecera_conjunta`] vuelve a comprobar todo con su contexto.
//! Producir no es admitir.

use ed25519_zebra::SigningKey;
use zx_core::firma::LONGITUD_FIRMA;
use zx_core::preimage::block::merkle_root;
use zx_core::wire_dag::{BloqueDag, JustificacionPot, MAX_BUNDLES_POT};
use zx_core::{
    ClavePublica, DagBlockHeader, EncodingError, ExtensionTx, PadresDag, Tx, body_commitment, txid,
};

use crate::firmante::{Firmante, FirmanteError};
use crate::productor::{
    CandidatoPoST, ErrorSellado, FuenteSoluciones, ParametrosProductor, ProductoFirmado,
    clave_publica_de, finalizar_con_firmante, finalizar_directo,
};
use crate::servicio_pot::{ErrorServicioPot, ServicioPot};

/// Cuerpo que aporta el llamante: transacciones **sin** la coinbase y sus testigos, en paralelo.
///
/// La coinbase v3 la construye [`producir_en_regimen_sin_firmante`] con el `slot` del bloque (F-17);
/// por eso una coinbase en esta lista es un error explícito y no una segunda coinbase silenciosa.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CuerpoProductor {
    txs: Vec<Tx>,
    testigos: Vec<Vec<Vec<u8>>>,
}

/// Cuerpo inválido para el productor.
#[derive(Debug, PartialEq, Eq, thiserror::Error)]
pub enum ErrorCuerpo {
    /// El número de listas de testigos no es el de transacciones.
    #[error("cuerpo: {txs} transacciones y {testigos} listas de testigos")]
    Descuadre {
        /// Transacciones.
        txs: usize,
        /// Listas de testigos.
        testigos: usize,
    },
    /// Una de las transacciones ya es una coinbase (v3, o v1 sin entradas).
    #[error("cuerpo: la transacción {indice} ya es una coinbase; la construye el productor")]
    CoinbaseEnCuerpo {
        /// Índice de la transacción infractora.
        indice: usize,
    },
}

impl CuerpoProductor {
    /// Cuerpo vacío: solo la coinbase que antepone el productor.
    #[must_use]
    pub const fn vacio() -> Self {
        Self {
            txs: Vec::new(),
            testigos: Vec::new(),
        }
    }

    /// Construye el cuerpo a partir de las transacciones **sin** la coinbase y sus testigos.
    ///
    /// # Errores
    /// [`ErrorCuerpo::Descuadre`] si las dos listas no miden lo mismo;
    /// [`ErrorCuerpo::CoinbaseEnCuerpo`] si alguna transacción es ya una coinbase.
    pub fn nuevo(txs: Vec<Tx>, testigos: Vec<Vec<Vec<u8>>>) -> Result<Self, ErrorCuerpo> {
        if txs.len() != testigos.len() {
            return Err(ErrorCuerpo::Descuadre {
                txs: txs.len(),
                testigos: testigos.len(),
            });
        }
        if let Some(indice) = txs.iter().position(es_coinbase) {
            return Err(ErrorCuerpo::CoinbaseEnCuerpo { indice });
        }
        Ok(Self { txs, testigos })
    }

    /// Las transacciones, en orden (sin la coinbase).
    #[must_use]
    pub fn txs(&self) -> &[Tx] {
        &self.txs
    }

    /// Las listas de testigos, paralelas a [`Self::txs`].
    #[must_use]
    pub fn testigos(&self) -> &[Vec<Vec<u8>>] {
        &self.testigos
    }

    /// ¿El cuerpo solo llevará la coinbase?
    #[must_use]
    pub fn esta_vacio(&self) -> bool {
        self.txs.is_empty()
    }
}

/// ¿La transacción es una coinbase (v3, o v1 sin entradas)?
fn es_coinbase(tx: &Tx) -> bool {
    tx.version == 3 || (tx.version == 1 && tx.inputs.is_empty())
}

/// Fallo al producir un bloque PoST en régimen.
#[derive(Debug, thiserror::Error)]
pub enum ErrorRegimen<E>
where
    E: std::error::Error + 'static,
{
    /// Una cabecera PoST sin padres es siempre inválida (D-P08).
    #[error("el bloque de régimen necesita al menos un padre (D-P08)")]
    SinPadres,
    /// `N_dev` del productor y del servicio no coinciden.
    #[error("N_dev discrepante: productor {productor}, servicio {servicio}")]
    NDevDiscrepante {
        /// `N_dev` de los parámetros del productor.
        productor: u64,
        /// `N_dev` del servicio PoT.
        servicio: u64,
    },
    /// El padre seleccionado no está registrado en el pasado del servicio.
    #[error("el padre seleccionado {padre} no está registrado en el ServicioPot")]
    PadreSeleccionadoDesconocido {
        /// Hash del padre seleccionado.
        padre: zx_core::BlockHash,
    },
    /// El slot objetivo no progresa respecto de `slot(sp(B))`.
    #[error("slot objetivo {slot} no progresa respecto de slot(sp) = {slot_sp}")]
    SlotNoProgreso {
        /// Slot objetivo.
        slot: u64,
        /// Slot del padre seleccionado.
        slot_sp: u64,
    },
    /// El rango `slot(B) − slot(sp)` supera `MAX_BUNDLES_POT`.
    #[error("el rango {d} excede MAX_BUNDLES_POT = {max}")]
    RangoExcedeMaximo {
        /// Diferencia pedida.
        d: u64,
        /// Cota del formato.
        max: u64,
    },
    /// Fallo del servicio PoT.
    #[error("servicio PoT: {0}")]
    Servicio(#[from] ErrorServicioPot),
    /// La solución no está sellada por la clave que firma (C-HDR-04, F-09).
    #[error("la solución no es de la clave que firma: solución {solucion:?}, firma {firma:?}")]
    ClaveDeLaSolucionNoCoincide {
        /// Clave de la solución.
        solucion: ClavePublica,
        /// Clave del firmante.
        firma: ClavePublica,
    },
    /// Fallo del firmante (clave ajena, sello inválido o E/S del registro).
    #[error("firmante: {0}")]
    Firmante(#[from] FirmanteError),
    /// Fallo de la fuente de soluciones.
    #[error("fuente de soluciones: {0}")]
    Fuente(#[source] E),
    /// No apareció ninguna solución en el slot objetivo.
    #[error("sin solución PoAS en el slot objetivo {slot}")]
    SinSolucion {
        /// Slot objetivo.
        slot: u64,
    },
    /// `zx-core` rechazó el formato (padres o compromiso del cuerpo).
    #[error("formato del bloque: {0}")]
    Formato(#[from] EncodingError),
}

impl<E> From<ErrorSellado> for ErrorRegimen<E>
where
    E: std::error::Error + 'static,
{
    fn from(fallo: ErrorSellado) -> Self {
        match fallo {
            ErrorSellado::Firmante(e) => Self::Firmante(e),
            ErrorSellado::Formato(e) => Self::Formato(e),
        }
    }
}

/// Produce un bloque PoST en régimen para los padres y el slot dados.
///
/// **Solo tests y arneses; no protege contra la doble firma:** sella directamente con `clave`. El
/// nodo produce **solo** con [`producir_en_regimen_con_firmante`] (SL-4b2/SL-4b3);
/// `ci/firmante-obligatorio.sh` comprueba que `crates/zx-node/src/` no invoca esta ruta.
///
/// # Argumentos
/// - `padres`: padres ya elegidos por el llamante (seleccionado primero, `≤ 15`). El productor no
///   los reordena.
/// - `slot_objetivo`: slot **exacto** del bloque; debe ser `> slot(sp)`.
/// - `servicio`: estado PoT local; se avanza hasta `slot_objetivo` si hace falta.
/// - `fuente`: soluciones PoAS verificadas contra `(salida, slot, SR_dev)`.
/// - `clave`: clave Ed25519 que firma el sello y a la que paga la coinbase.
/// - `parametros`: `N_dev` (debe coincidir con el del servicio), `SR_dev`, rama, timestamp e importe.
/// - `cuerpo`: transacciones sin la coinbase (el productor la antepone).
///
/// # Errores
/// [`ErrorRegimen`] con la variante que corresponda. En particular
/// [`ErrorRegimen::SlotNoProgreso`] si `slot ≤ slot(sp)` y
/// [`ErrorRegimen::RangoExcedeMaximo`] si el rango excede `MAX_BUNDLES_POT`.
pub fn producir_en_regimen_sin_firmante<F>(
    padres: PadresDag,
    slot_objetivo: u64,
    servicio: &mut ServicioPot,
    fuente: &F,
    clave: &SigningKey,
    parametros: &ParametrosProductor,
    cuerpo: CuerpoProductor,
) -> Result<BloqueDag, ErrorRegimen<F::Error>>
where
    F: FuenteSoluciones,
    F::Error: std::error::Error + 'static,
{
    let candidato = ensamblar_regimen(
        padres,
        slot_objetivo,
        servicio,
        fuente,
        clave,
        parametros,
        cuerpo,
    )?;
    finalizar_directo(candidato, clave).map_err(ErrorRegimen::from)
}

/// Produce un bloque PoST en régimen sellándolo **solo** con `firmante` (SL-4b1).
///
/// Construye exactamente el mismo bloque que [`producir_en_regimen_sin_firmante`] y lo sella por
/// [`Firmante::firmar`]. Devuelve [`ProductoFirmado::Abstenido`] cuando el firmante se niega
/// (conflicto o pérdida de registro) y [`ProductoFirmado::Bloque`] con su veredicto cuando sella.
///
/// # Errores
/// Los mismos que [`producir_en_regimen_sin_firmante`], más [`ErrorRegimen::Firmante`] para un fallo
/// real del registro (E/S, envenenamiento, corrupción), la clave ajena o un sello inválido.
#[expect(
    clippy::too_many_arguments,
    reason = "firma pública del productor seguro; agrupar rompería la simetría con producir_en_regimen_sin_firmante"
)]
pub fn producir_en_regimen_con_firmante<F>(
    padres: PadresDag,
    slot_objetivo: u64,
    servicio: &mut ServicioPot,
    fuente: &F,
    clave: &SigningKey,
    parametros: &ParametrosProductor,
    cuerpo: CuerpoProductor,
    firmante: &mut Firmante<'_>,
) -> Result<ProductoFirmado, ErrorRegimen<F::Error>>
where
    F: FuenteSoluciones,
    F::Error: std::error::Error + 'static,
{
    let candidato = ensamblar_regimen(
        padres,
        slot_objetivo,
        servicio,
        fuente,
        clave,
        parametros,
        cuerpo,
    )?;
    finalizar_con_firmante(candidato, clave, firmante).map_err(ErrorRegimen::from)
}

/// Valida el rango, avanza el servicio y ensambla cabecera (sin sello) y cuerpo (coinbase v3).
#[allow(
    clippy::too_many_arguments,
    reason = "mismos argumentos públicos del productor"
)]
fn ensamblar_regimen<F>(
    padres: PadresDag,
    slot_objetivo: u64,
    servicio: &mut ServicioPot,
    fuente: &F,
    clave: &SigningKey,
    parametros: &ParametrosProductor,
    cuerpo: CuerpoProductor,
) -> Result<CandidatoPoST, ErrorRegimen<F::Error>>
where
    F: FuenteSoluciones,
    F::Error: std::error::Error + 'static,
{
    if padres.es_genesis() || padres.count() == 0 {
        return Err(ErrorRegimen::SinPadres);
    }
    if parametros.n_dev != servicio.n_dev() {
        return Err(ErrorRegimen::NDevDiscrepante {
            productor: parametros.n_dev,
            servicio: servicio.n_dev(),
        });
    }

    let seleccionado = padres.seleccionado();
    let slot_sp =
        servicio
            .slot_de(&seleccionado)
            .ok_or(ErrorRegimen::PadreSeleccionadoDesconocido {
                padre: seleccionado,
            })?;
    if slot_objetivo <= slot_sp {
        return Err(ErrorRegimen::SlotNoProgreso {
            slot: slot_objetivo,
            slot_sp,
        });
    }
    let d = slot_objetivo - slot_sp;
    if d > MAX_BUNDLES_POT as u64 {
        return Err(ErrorRegimen::RangoExcedeMaximo {
            d,
            max: MAX_BUNDLES_POT as u64,
        });
    }

    // El slot objetivo puede estar ya calculado (hermanos del mismo slot) o por delante.
    if servicio.slot_actual() < slot_objetivo {
        servicio.avanzar_hasta(slot_objetivo)?;
    }
    let salida = servicio.salida_de(slot_objetivo)?;

    let candidatas = fuente
        .soluciones(salida, slot_objetivo, parametros.sr_dev)
        .map_err(ErrorRegimen::Fuente)?;
    let Some(candidata) = candidatas.into_iter().next() else {
        return Err(ErrorRegimen::SinSolucion {
            slot: slot_objetivo,
        });
    };

    // C-HDR-04 y F-09: la solución debe ser de la clave que firma y paga la coinbase.
    let productor = clave_publica_de(clave);
    if candidata.solucion.public_key != productor {
        return Err(ErrorRegimen::ClaveDeLaSolucionNoCoincide {
            solucion: candidata.solucion.public_key,
            firma: productor,
        });
    }

    // Justificación del rango `(slot(sp), slot(B)]` con `D = 0`.
    let portadores = servicio.portadores_para(slot_sp, slot_objetivo)?;

    // Coinbase v3 con **el slot de este bloque** (F-17).
    let coinbase = Tx {
        version: 3,
        inputs: Vec::new(),
        outputs: Vec::new(),
        lock_time: 0,
        expiry_height: 0,
        extension: ExtensionTx::CoinbasePost {
            clave: productor,
            importe: parametros.importe_coinbase,
            slot: slot_objetivo,
        },
    };
    let CuerpoProductor {
        txs: cuerpo_txs,
        testigos: cuerpo_testigos,
    } = cuerpo;
    let mut txs = Vec::with_capacity(cuerpo_txs.len() + 1);
    txs.push(coinbase);
    txs.extend(cuerpo_txs);
    let mut testigos = Vec::with_capacity(cuerpo_testigos.len() + 1);
    testigos.push(Vec::new());
    testigos.extend(cuerpo_testigos);

    let txids: Vec<_> = txs
        .iter()
        .map(|t| txid(t, parametros.consensus_branch_id))
        .collect();
    let merkle_root = merkle_root(&txids);
    let body_commitment = body_commitment(&txs, &testigos, parametros.consensus_branch_id)?;

    let cabecera = DagBlockHeader {
        consensus_branch_id: parametros.consensus_branch_id,
        merkle_root,
        timestamp: parametros.timestamp,
        // F-03: el campo `height` de la cabecera PoST está reservado y MUST ser 0 en v0.
        height: 0,
        slot: slot_objetivo,
        pot_output: salida,
        rango_solucion: parametros.sr_dev,
        sol: candidata.solucion,
        body_commitment,
        padres,
        sello: [0u8; LONGITUD_FIRMA],
    };

    let justificacion = JustificacionPot::nueva(portadores)?;
    Ok(CandidatoPoST {
        cabecera,
        justificacion,
        txs,
        testigos,
    })
}

#[cfg(test)]
#[expect(clippy::expect_used, reason = "los tests usan expect por diseño")]
mod pruebas {
    use zx_core::{ExtensionTx, Tx, TxId};

    use super::{CuerpoProductor, ErrorCuerpo};

    /// Transacción **de efecto** v1 (con una entrada): no es coinbase.
    fn tx_v1(min: u8) -> Tx {
        Tx {
            version: 1,
            inputs: vec![zx_core::TxIn {
                outpoint: zx_core::OutPoint {
                    prev_txid: TxId::from_digest(zx_core::digest::Digest::from_bytes([min; 32])),
                    prev_index: 0,
                },
                sequence: 0,
            }],
            outputs: vec![zx_core::TxOut {
                value: zx_core::Amount::nuevo(i64::from(min)).expect("importe"),
                lock: zx_core::Lock::PubKey {
                    pubkey: zx_core::ClavePublica::desde_bytes([min; 32]),
                },
            }],
            lock_time: 0,
            expiry_height: 0,
            extension: ExtensionTx::Ninguna,
        }
    }

    fn tx_v3() -> Tx {
        Tx {
            version: 3,
            inputs: Vec::new(),
            outputs: Vec::new(),
            lock_time: 0,
            expiry_height: 0,
            extension: ExtensionTx::CoinbasePost {
                clave: zx_core::ClavePublica::desde_bytes([9; 32]),
                importe: zx_core::Amount::nuevo(1).expect("importe"),
                slot: 1,
            },
        }
    }

    #[test]
    fn el_cuerpo_vacio_solo_lleva_la_coinbase() {
        let c = CuerpoProductor::vacio();
        assert!(c.esta_vacio());
        assert!(c.txs().is_empty());
        assert!(c.testigos().is_empty());
    }

    #[test]
    fn descuadre_y_coinbase_se_rechazan() {
        let tx = tx_v1(1);
        assert_eq!(
            CuerpoProductor::nuevo(vec![tx.clone()], Vec::new()),
            Err(ErrorCuerpo::Descuadre {
                txs: 1,
                testigos: 0
            })
        );
        assert_eq!(
            CuerpoProductor::nuevo(vec![tx], vec![Vec::new()])
                .expect("cuerpo válido")
                .txs()
                .len(),
            1
        );
        assert_eq!(
            CuerpoProductor::nuevo(vec![tx_v3()], vec![Vec::new()]),
            Err(ErrorCuerpo::CoinbaseEnCuerpo { indice: 0 })
        );
    }
}
