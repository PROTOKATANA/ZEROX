//! Proyección UTXO **local de prueba** del primer hijo DAG de desarrollo (incremento B1/D2 parcial).
//!
//! # Qué es y qué no es
//!
//! [`simular_utxo_primer_hijo_dag_dev`] aplica el cuerpo del primer hijo `{G}` a un
//! [`ConjuntoEnMemoria`] vacío y conserva el [`UndoData`] resultante. La palabra **simular** es
//! intencional: produce una **proyección local de prueba**, no el estado seleccionado del nodo ni
//! una admisión. No existe aquí ningún `admitir`, `seleccionar` ni `publicar`; no se escribe en
//! RocksDB ni en el índice de admitidos; no se aplican mergesets, gastos ni transacciones de
//! usuario; y nada de lo que devuelve esta función se conecta a la ruta viva.
//!
//! El único cotejo que la función hace sobre la evidencia de la puerta conjunta A3 es de
//! **identidad**: `comprobacion.block_hash() == bloque.cabecera.block_hash()` y
//! `comprobacion.slot_auditado() == bloque.cabecera.slot`. Una [`ComprobacionCabecera`] **no** se
//! convierte aquí en certificado de admisión: su procedencia causal, el reloj de pared, la
//! economía completa, el orden GHOSTDAG y la atomicidad de publicación siguen **pendientes**
//! (`TAREAS.md` §2.3 y §2.6). Este módulo no los fabrica ni los presenta como verificados.
//!
//! # Orden de las comprobaciones
//!
//! 1. **Identidad de la evidencia**: hash y slot de la comprobación contra la cabecera del
//!    bloque. Si no coinciden, error tipado propio y **nunca** `Ok`, antes de tocar el UTXO.
//! 2. **Cuerpo coinbase cero**: [`comprobar_cuerpo_coinbase_cero_dev`], conservando su error
//!    tipado ([`ErrorCuerpoCoinbaseDev`]).
//! 3. **C-GEN-03**: solo entonces se crea un [`ConjuntoEnMemoria::nuevo`] **vacío**. La coinbase
//!    del génesis `G` no se conecta: la proyección arranca sin ningún UTXO del génesis.
//! 4. **Aplicación**: `zx_storage::aplicar_bloque(&mut conjunto, bloque.txs(), altura, rama)`, con
//!    la altura y el `consensus_branch_id` **de la cabecera**, no de un literal. El `txid` de cada
//!    salida depende de la rama (`C-TX-05`); `aplicar_bloque` la recibe de la cabecera ya cotejada
//!    por el perfil dev. No se recalcula ningún `txid` aquí ni se elige la rama por otra vía.
//!
//! # Qué no cubre
//!
//! - **No es admisión ni validez global.** No verifica PoT, PoAS, sello, ni publicación atómica;
//!   el sello y el PoT los comprueba (o no) la puerta A3 cuyo resultado se pasa como dato. Esta
//!   función **no** vuelve a ejecutar A3 ni confía en que se haya ejecutado: solo coteja hash y
//!   slot.
//! - **No es el orden de C-ORD-03.** Esa regla ordena `[sp(C)] ++ mergeset(C)` sobre la cadena
//!   seleccionada; aquí se aplica **un solo** bloque y ni siquiera se recorre `sp(C)`. No hay
//!   mergeset, ni coloreo, ni descarte silencioso de conflictos de transacción sobre ese orden.
//! - **No hay estado viviente.** El [`ConjuntoEnMemoria`] es local al valor devuelto; no hay
//!   persistencia, ni índice de admitidos, ni reconciliación al arrancar.
//!
//! # Reglas citadas
//!
//! - `C-GEN-03`: la coinbase del génesis tiene `Σ value(salidas) = 0` y no se inserta en el UTXO.
//! - `C-TX-05`: el `txid` depende del `consensus_branch_id`; la clave de cada salida se indexa con
//!   la rama de la cabecera.
//! - `C-REORG-01`: `aplicar_bloque` conserva el `UndoData` completo por bloque conectado.
//! - `C-REORG-02`: `revertir_bloque` comprueba existencia y **contenido** de lo creado antes de
//!   retirarlo, y reinserta lo consumido en orden inverso.
//! - `C-REORG-03`: aplicar y revertir publican el conjunto solo si todo sale bien; la copia de
//!   trabajo no deja el estado a medias.
//! - `C-ORD-03`: **no** se ejecuta aquí; el orden de la cadena seleccionada y su mergeset siguen
//!   pendientes de cableado.

use thiserror::Error;

use zx_consensus::ComprobacionCabecera;
use zx_core::{BlockHash, BloqueDag};
use zx_storage::{ConjuntoEnMemoria, StorageError, UndoData, aplicar_bloque, revertir_bloque};

use crate::bootstrap_dag_dev::EstadoBootstrapDagDev;
use crate::cuerpo_coinbase_dag_dev::{ErrorCuerpoCoinbaseDev, comprobar_cuerpo_coinbase_cero_dev};

/// Fallo de la simulación UTXO local del primer hijo DAG dev.
///
/// Distingue la evidencia A3 de otra cabecera (hash o slot) del fallo del cuerpo coinbase cero y
/// del fallo tipado del motor de estado. Ninguno de los dos primeros es una admisión fallida: son
/// puertas **previas** que ocurren antes de crear cualquier UTXO.
#[derive(Debug, Error)]
pub enum ErrorUtxoPrimerHijoDev {
    /// La evidencia A3 corresponde a otra cabecera según su `block_hash`.
    ///
    /// Es el caso de una cabecera mutada o de un cuerpo con compromisos recalculados: el bloque
    /// ya no es el que la puerta comprobó. La simulación **MUST NOT** publicar estado.
    #[error(
        "la comprobación A3 es de otra cabecera: evidencia {comprobacion:?}, bloque {bloque:?}"
    )]
    HashDeEvidenciaNoCoincide {
        /// `block_hash` que conserva la evidencia A3.
        comprobacion: BlockHash,
        /// `block_hash` de la cabecera entregada a la simulación.
        bloque: BlockHash,
    },
    /// La evidencia A3 auditó otro slot distinto del que declara la cabecera.
    ///
    /// Por construcción de la puerta A3 no debería ocurrir con la misma cabecera, pero se coteja
    /// igualmente para que un cambio futuro del tipo no cuele una evidencia de otro slot. La
    /// simulación **MUST NOT** publicar estado.
    #[error(
        "la comprobación A3 auditó el slot {comprobacion} y la cabecera declara el slot {bloque}"
    )]
    SlotDeEvidenciaNoCoincide {
        /// Slot auditado que conserva la evidencia A3.
        comprobacion: u64,
        /// Slot declarado por la cabecera entregada.
        bloque: u64,
    },
    /// El cuerpo no satisface el perfil dev del cuerpo coinbase cero.
    ///
    /// Se conserva el error tipado original de `zx-node::cuerpo_coinbase_dag_dev`, de modo que un
    /// Merkle roto, un `body_commitment` roto y una forma fuera de perfil siguen distinguibles.
    #[error("cuerpo coinbase cero del primer hijo: {0}")]
    Cuerpo(#[from] ErrorCuerpoCoinbaseDev),
    /// El motor de estado rechazó aplicar o revertir el bloque.
    ///
    /// Es un error tipado de corrupción o de estado incoherente (`C-REORG-01`..`C-REORG-03`), no
    /// un juicio de consenso sobre el candidato.
    #[error("fallo del conjunto UTXO en memoria: {0}")]
    Storage(#[from] StorageError),
}

/// Proyección UTXO local de prueba del primer hijo DAG dev, con su `UndoData`.
///
/// Los campos son privados y solo se exponen por getters de lectura. **No** es estado seleccionado
/// ni admitido: es la materia efímera de una comprobación local. No hay constructor público sin
/// pasar por [`simular_utxo_primer_hijo_dag_dev`], y no existe API para inyectar entradas.
#[derive(Clone, Debug)]
pub struct EstadoUtxoPrimerHijoDev {
    block_hash: BlockHash,
    conjunto: ConjuntoEnMemoria,
    undo: UndoData,
}

impl EstadoUtxoPrimerHijoDev {
    /// `block_hash` de la cabecera cuyo cuerpo se proyectó.
    ///
    /// Es el hash cotejado con la evidencia A3; no se recalcula de la cabecera.
    #[must_use]
    pub fn block_hash(&self) -> BlockHash {
        self.block_hash
    }

    /// Conjunto UTXO **en memoria** resultante de aplicar el cuerpo del bloque.
    ///
    /// Se expone como referencia de solo lectura para buscar salidas con el trait
    /// [`ConjuntoUtxo`](zx_consensus::ConjuntoUtxo). No hay mutador: el conjunto solo cambia al
    /// revertir, y [`Self::revertir`] consume el valor.
    #[must_use]
    pub fn conjunto(&self) -> &ConjuntoEnMemoria {
        &self.conjunto
    }

    /// Datos para deshacer el bloque aplicado (`C-REORG-01`).
    ///
    /// `creados` contiene, por cada salida que el bloque creó, el par completo `(OutPoint,
    /// EntradaUtxo)` que [`aplicar_bloque`] registró tras insertarla.
    #[must_use]
    pub fn undo(&self) -> &UndoData {
        &self.undo
    }

    /// Deshace el bloque aplicado y devuelve el conjunto resultante.
    ///
    /// Invoca [`zx_storage::revertir_bloque`] sobre el conjunto propio. Como la proyección parte
    /// de un conjunto **vacío**, el resultado debe ser un conjunto **vacío**; si el motor detecta
    /// corrupción, propaga [`StorageError`] y no publica el borrado (`C-REORG-02`, `C-REORG-03`).
    ///
    /// # Errores
    /// [`ErrorUtxoPrimerHijoDev::Storage`] si el undo data y el conjunto no concuerdan.
    pub fn revertir(self) -> Result<ConjuntoEnMemoria, ErrorUtxoPrimerHijoDev> {
        let Self {
            mut conjunto, undo, ..
        } = self;
        revertir_bloque(&mut conjunto, &undo)?;
        Ok(conjunto)
    }
}

/// Simula la aplicación UTXO del primer hijo DAG dev `{G}` sobre un conjunto **vacío**.
///
/// # Argumentos
///
/// - `bootstrap`: génesis congelado del perfil dev; fuente de `G` para el comprobador de cuerpo.
/// - `bloque`: bloque DAG completo. Solo se leen `cabecera` y `txs()`.
/// - `comprobacion`: evidencia conservada de la puerta A3. **No es un certificado de admisión**:
///   aquí solo se usa como prueba de identidad del candidato (hash y slot). La procedencia causal,
///   el reloj, la economía, el orden GHOSTDAG y la publicación atómica siguen pendientes.
///
/// # Orden
///
/// 1. Coteja hash y slot de `comprobacion` contra `bloque.cabecera`.
/// 2. Llama a [`comprobar_cuerpo_coinbase_cero_dev`].
/// 3. Crea el conjunto vacío (`C-GEN-03`, la coinbase del génesis no se conecta).
/// 4. Aplica **solo** `bloque.txs()` con `zx_storage::aplicar_bloque` usando la altura y la rama
///    de la cabecera (`C-TX-05`), y conserva `UndoData`.
///
/// # Errores
/// [`ErrorUtxoPrimerHijoDev::HashDeEvidenciaNoCoincide`] o
/// [`ErrorUtxoPrimerHijoDev::SlotDeEvidenciaNoCoincide`] si la evidencia no es de esta cabecera;
/// [`ErrorUtxoPrimerHijoDev::Cuerpo`] si el cuerpo no cumple el perfil coinbase cero;
/// [`ErrorUtxoPrimerHijoDev::Storage`] si el motor de estado rechaza la aplicación. En todos los
/// casos la simulación **MUST NOT** devolver `Ok` ni publicar estado.
///
/// # Límites
/// Ver la cabecera del módulo. No es admisión, no es la cadena seleccionada de `C-ORD-03`, no
/// persiste y no cablea nada a la ruta viva.
pub fn simular_utxo_primer_hijo_dag_dev(
    bootstrap: &EstadoBootstrapDagDev,
    bloque: &BloqueDag,
    comprobacion: &ComprobacionCabecera,
) -> Result<EstadoUtxoPrimerHijoDev, ErrorUtxoPrimerHijoDev> {
    // 1 · Identidad de la evidencia antes de tocar nada. La puerta A3 no vuelve a ejecutarse aquí:
    //     solo se exige que el candidato sea el mismo por hash y por slot.
    let hash_bloque = bloque.cabecera.block_hash();
    if comprobacion.block_hash() != hash_bloque {
        return Err(ErrorUtxoPrimerHijoDev::HashDeEvidenciaNoCoincide {
            comprobacion: comprobacion.block_hash(),
            bloque: hash_bloque,
        });
    }
    if comprobacion.slot_auditado() != bloque.cabecera.slot {
        return Err(ErrorUtxoPrimerHijoDev::SlotDeEvidenciaNoCoincide {
            comprobacion: comprobacion.slot_auditado(),
            bloque: bloque.cabecera.slot,
        });
    }

    // 2 · Forma del cuerpo coinbase cero y compromisos, con el error tipado de `cuerpo_coinbase`.
    comprobar_cuerpo_coinbase_cero_dev(bootstrap, bloque)?;

    // 3 · C-GEN-03: la proyección arranca vacía. La coinbase del génesis no se inserta.
    let mut conjunto = ConjuntoEnMemoria::nuevo();

    // 4 · Aplicación con la altura y la rama de la cabecera, nunca literales. No se recalcula txid.
    let undo = aplicar_bloque(
        &mut conjunto,
        bloque.txs(),
        bloque.cabecera.height,
        bloque.cabecera.consensus_branch_id,
    )?;

    Ok(EstadoUtxoPrimerHijoDev {
        block_hash: hash_bloque,
        conjunto,
        undo,
    })
}
