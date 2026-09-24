//! Almacén de **candidatos** DAG: cola por `block_hash`, sin validar (preparación C1, SPEC §6).
//!
//! # Qué es y qué no es
//!
//! Este módulo guarda bloques DAG **no validados** —candidatos llegados de la red o de la
//! producción local— en una entrada por `block_hash`. **No decide nada de consenso:**
//!
//! - **No da `Válido`.** Guardar o recuperar un candidato no dice que su PoAS, su sello, sus
//!   compromisos de cuerpo ni su justificación PoT sean correctos. Guardar el códec **no
//!   sustituye la validación**: es exactamente lo que advierte C-WIRE-07.
//! - **No marca punta**, no alimenta GHOSTDAG, ni el UTXO set, ni el orden DAG. La
//!   admisión/orden/estado DAG sigue pendiente (SPEC §15.1, `C-STORE-06`).
//! - `Ok(None)` significa **que el candidato no está**, nunca que sea inválido o válido: un
//!   consumidor **MUST NOT** inferir validez por presencia (C-HDR-07).
//!
//! # Por qué la clave es el `block_hash` y por qué hay versiones
//!
//! La clave es `bloque.cabecera.block_hash()`, el canónico de C-HDR-09 —prefirma **con** sello—.
//! No se indexa por `height`, slot, orden de llegada ni punta: dos cabeceras distintas con el
//! mismo `slot` **MUST** coexistir.
//!
//! La justificación PoT **no entra en `block_hash`** (C-HDR-07): la cabecera firma/hashea `slot`,
//! `pot_output` y los padres, pero el PoT es evidencia contextual reemplazable. Por eso la misma
//! cabecera puede reintentarse con otra justificación y este almacén la trata como una **versión**
//! de la misma entrada: guardar bajo un `block_hash` ya presente reemplaza la entrada completa
//! —cabecera, justificación y cuerpo— de forma atómica. Nunca se mezcla justificación vieja con
//! cuerpo nuevo, ni se expone una escritura a medias.
//!
//! # Frontera de confianza: esto es la cola **no confiable**
//!
//! El reemplazo por hash es una política **solo para la cola no confiable**: una prueba posterior
//! mala puede desalojar una buena. La futura ruta validada **MUST** promover la evidencia
//! verificada a un almacén separado o protegerla contra sobrescritura. Este almacén **no** promete
//! resistencia DoS ni finalidad, y no las promete porque no las tiene.
//!
//! C-HDR-07 exige que la justificación acompañe al bloque para poder declararlo válido o adoptarlo,
//! y que la sincronización distinga datos pendientes de pruebas verificadas como inválidas. Aquí
//! solo se guarda el dato completo; la distinción la hace la futura admisión.

use zx_core::digest::BlockHash;
use zx_core::wire_dag::BloqueDag;

use crate::error::StorageError;

/// Cola de candidatos DAG indexada por `block_hash`, **sin validar**.
///
/// # Contrato
///
/// - Solo almacena **candidatos no validados**: no da `Válido`, no marca punta y no alimenta
///   GHOSTDAG ni el UTXO set.
/// - `Ok(None)` significa que no existe el candidato, no que sea inválido o válido. La presencia
///   no es prueba de validez ni la ausencia una refutación.
/// - La clave es `bloque.cabecera.block_hash()` (C-HDR-09). Dos cabeceras distintas con el mismo
///   `slot` coexisten: no se indexa por `height`, slot, orden de llegada ni punta.
/// - Guardar bajo un `block_hash` ya presente **reemplaza la entrada completa de forma atómica**.
///   Es la vía para reintentar con otra justificación PoT, que queda fuera de `block_hash` por
///   C-HDR-07. La implementación **MUST NOT** mezclar justificación vieja con cuerpo nuevo ni
///   exponer escrituras parciales.
///
/// # Limitación de la cola
///
/// Reemplazar por hash es una política **solo para la cola no confiable**: una prueba posterior
/// mala puede desalojar una buena. La futura ruta validada **MUST** promover la evidencia
/// verificada a un almacén separado o protegerla contra sobrescritura. Este trait **no** promete
/// resistencia DoS ni finalidad.
pub trait AlmacenCandidatosDag: Send + Sync {
    /// Guarda o reemplaza el bloque DAG completo de un candidato.
    ///
    /// La clave es `bloque.cabecera.block_hash()`; cabecera, justificación y cuerpo entran en
    /// **una** entrada. Una versión nueva bajo el mismo hash reemplaza la anterior entera.
    ///
    /// **No valida nada**: ni el sello (C-HDR-04), ni los compromisos del cuerpo (C-WIRE-07), ni
    /// la justificación PoT (C-HDR-07). Guardar no es admitir.
    ///
    /// # Errores
    /// [`StorageError`] si el backend falla.
    fn guardar_candidato_dag(&self, bloque: &BloqueDag) -> Result<(), StorageError>;

    /// Recupera el bloque DAG completo de un candidato por su `block_hash`.
    ///
    /// `Ok(None)` significa que **no existe el candidato**, no que sea inválido o válido. La
    /// presencia no acredita validez; la ausencia no la refuta.
    ///
    /// Una entrada que no decodifique por completo —incluidos bytes finales sobrantes— o cuyo
    /// `block_hash()` no coincida con la clave solicitada se rechaza como
    /// [`StorageError::Corrupto`]; **no** se convierte en `None` ni se acepta por haber
    /// deserializado.
    ///
    /// # Errores
    /// [`StorageError::Corrupto`] si lo guardado no decodifica o no corresponde a la clave;
    /// [`StorageError`] si el backend falla.
    fn candidato_dag(&self, hash: &BlockHash) -> Result<Option<BloqueDag>, StorageError>;
}

#[cfg(test)]
#[expect(clippy::expect_used, reason = "los tests fallan con panic por diseño")]
mod tests {
    use super::AlmacenCandidatosDag;
    use crate::memoria::AlmacenEnMemoria;
    use zx_core::amount::Amount;
    use zx_core::digest::{BlockHash, BodyCommitment, Digest, MerkleRoot, TxId};
    use zx_core::firma::ClavePublica;
    use zx_core::preimage::dag::{DagBlockHeader, PadresDag, SolucionPoas};
    use zx_core::tx::{Lock, OutPoint, Tx, TxIn, TxOut};
    use zx_core::wire_dag::{
        BUNDLE_BYTES, BloqueDag, JustificacionPot, PotCheckpoints, bloque_dag_a_bytes,
    };

    /// Cabecera de fixture, etiquetada **candidata**: **no** es una PoAS válida y no pretende
    /// serlo. Dos llamadas con distinto `marca` producen cabeceras distintas con el **mismo
    /// `slot`**, que es el caso que el almacén debe hacer coexistir sin ordenar por llegada.
    fn cabecera_candidata(slot: u64, marca: u8) -> DagBlockHeader {
        DagBlockHeader {
            consensus_branch_id: 0xc478_80ea,
            merkle_root: MerkleRoot::from_digest(Digest::from_bytes([marca; 32])),
            timestamp: 1_788_480_000 + slot,
            height: 1,
            slot,
            pot_output: [marca; 16],
            rango_solucion: u64::from(marca),
            sol: SolucionPoas::default(),
            body_commitment: BodyCommitment::from_digest(Digest::from_bytes([marca; 32])),
            padres: PadresDag::nuevo(BlockHash::from_digest(Digest::from_bytes([0x07; 32])), &[])
                .expect("un padre seleccionado es canónico"),
            sello: [marca; 64],
        }
    }

    fn tx(n: u8) -> Tx {
        Tx {
            version: 1,
            inputs: vec![TxIn {
                outpoint: OutPoint {
                    prev_txid: TxId::from_digest(Digest::from_bytes([n; 32])),
                    prev_index: u32::from(n),
                },
                sequence: 0,
            }],
            outputs: vec![TxOut {
                value: Amount::nuevo(i64::from(n) * 100).expect("importe válido"),
                lock: Lock::PubKey {
                    pubkey: ClavePublica::desde_bytes([n; 32]),
                },
            }],
            lock_time: 0,
            expiry_height: 0,
        }
    }

    /// Justificación PoT de fixture, con `bundles` portadores distintos.
    fn justificacion(marca: u8, bundles: usize) -> JustificacionPot {
        let lista: Vec<PotCheckpoints> = (0..bundles)
            .map(|i| PotCheckpoints::desde_bytes([marca.wrapping_add(i as u8); BUNDLE_BYTES]))
            .collect();
        JustificacionPot::nueva(lista).expect("dentro del máximo de portadores")
    }

    fn bloque(cabecera: DagBlockHeader, justificacion: JustificacionPot) -> BloqueDag {
        BloqueDag::nuevo(
            cabecera,
            justificacion,
            vec![tx(1), tx(2)],
            vec![vec![vec![0x11; 64]], vec![vec![0x22; 64]]],
        )
        .expect("txs y testigos cuadran")
    }

    /// Comparación independiente: se re-serializa con el códec existente, no campo a campo.
    fn bytes_del_bloque(b: &BloqueDag) -> Vec<u8> {
        let mut v = Vec::new();
        bloque_dag_a_bytes(&mut v, b);
        v
    }

    /// Dos cabeceras distintas con **igual slot** sobreviven y se recuperan por su hash, con los
    /// bytes idénticos a los originales comparados con el códec existente.
    #[test]
    fn dos_cabeceras_con_el_mismo_slot_coexisten() {
        let a = AlmacenEnMemoria::nuevo();
        let c1 = cabecera_candidata(41, 0x11);
        let c2 = cabecera_candidata(41, 0x22);
        assert_eq!(c1.slot, c2.slot, "el fixture comparte slot a propósito");
        let h1 = c1.block_hash();
        let h2 = c2.block_hash();
        assert_ne!(h1, h2, "distinta cabecera, distinto hash");

        let b1 = bloque(c1, justificacion(0x11, 1));
        let b2 = bloque(c2, justificacion(0x22, 1));
        a.guardar_candidato_dag(&b1).expect("guarda el primero");
        a.guardar_candidato_dag(&b2).expect("guarda el segundo");

        let r1 = a.candidato_dag(&h1).expect("lee el primero").expect("está");
        let r2 = a.candidato_dag(&h2).expect("lee el segundo").expect("está");
        assert_eq!(r1, b1);
        assert_eq!(r2, b2);
        assert_eq!(bytes_del_bloque(&r1), bytes_del_bloque(&b1));
        assert_eq!(bytes_del_bloque(&r2), bytes_del_bloque(&b2));
        assert_ne!(
            bytes_del_bloque(&r1),
            bytes_del_bloque(&r2),
            "dos candidatos distintos no comparten bytes"
        );
    }

    /// **La segunda justificación reemplaza a la primera** sin cambiar el hash ni mezclar campos.
    #[test]
    fn la_segunda_justificacion_reemplaza_la_primera() {
        let a = AlmacenEnMemoria::nuevo();
        let cab = cabecera_candidata(50, 0x33);
        let h = cab.block_hash();

        let j1 = justificacion(0x01, 1);
        let j2 = justificacion(0x02, 2);
        let b1 = bloque(cab, j1);
        let b2 = bloque(cab, j2.clone());
        assert_eq!(b1.cabecera.block_hash(), b2.cabecera.block_hash());
        assert_ne!(b1.justificacion, b2.justificacion);

        a.guardar_candidato_dag(&b1).expect("guarda la primera");
        a.guardar_candidato_dag(&b2)
            .expect("reemplaza con la segunda");

        let r = a.candidato_dag(&h).expect("lee").expect("está");
        assert_eq!(r, b2, "gana la última versión completa");
        assert_eq!(r.cabecera, cab, "la cabecera no cambia");
        assert_eq!(
            r.justificacion, j2,
            "la justificación es la nueva, no una mezcla"
        );
        assert_eq!(r.justificacion.len(), 2);
        assert_eq!(bytes_del_bloque(&r), bytes_del_bloque(&b2));
    }

    /// Un hash desconocido devuelve `Ok(None)`: **no es un error** y **no** dice "inválido".
    #[test]
    fn un_hash_desconocido_devuelve_none() {
        let a = AlmacenEnMemoria::nuevo();
        let ajeno = BlockHash::from_digest(Digest::from_bytes([0xfe; 32]));
        assert_eq!(a.candidato_dag(&ajeno).expect("consulta"), None);
    }
}
