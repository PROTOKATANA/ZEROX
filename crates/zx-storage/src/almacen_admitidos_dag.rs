//! Índice de **bloques DAG plenamente admitidos** —destino; hoy **vacío en la ruta activa**—: API
//! de lectura separada (C-STORE-06, C-STORE-08).
//!
//! # Qué es y qué no es
//!
//! Este módulo define el acceso de lectura a un índice de bloques DAG que habrían superado la ruta
//! de admisión completa —orden de `C-POT-08`, flujo de `C-FLU-14`— y que por eso podrían alimentar
//! respuestas como el pasado validado que exige `C-POT-06`. **No implementa esa admisión.**
//!
//! - **El índice está vacío en la ruta activa.** Es el **destino** del futuro escritor, no una
//!   fuente de producción. Solo las **inyecciones de fixture** `#[cfg(test)]` de los backends lo
//!   llenan, y lo hacen con bytes que **no** son evidencia PoST verificada; ningún binario de
//!   producción las compila. La frontera no se prueba con un test artificial, es una propiedad
//!   revisada del API: el trait no declara escritura.
//! - **Hoy no existe un escritor de producción.** El trait [`AlmacenAdmitidosDag`] declara **solo**
//!   la lectura. Ninguna función pública de `zx-storage` puede promocionar un `BloqueDag`
//!   arbitrario a este índice: la presencia no se fabrica desde aquí.
//! - **No da `Válido`.** Leer un bloque del índice no vuelve a verificar nada: quien lo guardó será
//!   la futura ruta de admisión, que todavía no existe. `Ok(None)` significa que la clave **no está
//!   en el índice**, nunca que el bloque sea inválido. La ausencia no refuta; la presencia no
//!   certifica.
//! - **Guarda el bloque completo.** El formato canónico incluye la justificación PoT, el cuerpo,
//!   y dentro de la cabecera `pot_output` y `sol.chunk`. Esos campos viajan porque el bloque se
//!   guarda entero, pero **su presencia por sí sola no demuestra validez** fuera de la futura ruta
//!   de admisión (C-HDR-07).
//! - **No toca la cadena lineal.** Ni `alturas`, ni la punta, ni el UTXO set; tampoco el índice de
//!   candidatos de [`crate::almacen_dag`], del que está separado y al que **nunca** consulta como
//!   respaldo.
//!
//! # Clave, formato y versionado
//!
//! La clave es `bloque.cabecera.block_hash()` —el canónico de C-HDR-09, prefirma **con** sello—.
//! No se indexa por altura, `slot`, orden de llegada ni punta: dos cabeceras distintas con el mismo
//! `slot` coexisten (C-HDR-05).
//!
//! Cada entrada se guarda como el bloque canónico de C-WIRE-07 precedido por un **discriminante de
//! versión** ([`VERSION_ADMITIDOS_DAG`]). Al leer se exige que la versión sea conocida, que el
//! decodificador consuma **exactamente** todos los bytes y que `cabecera.block_hash()` coincida con
//! la clave; cualquier otra cosa es [`StorageError::Corrupto`], no `None` y no un bloque «casi
//! bueno».
//!
//! # Frontera futura
//!
//! El escritor futuro **MUST** ser un único lote lógico —cabecera, cuerpo, estado, undo, GHOSTDAG—
//! publicado de forma serializada y atómica, no una `guardar_admitido` suelta que este incremento
//! reservara. La **inmutabilidad de la evidencia verificada es un requisito de ese escritor
//! futuro**, todavía no implementado, y la diferencia con la cola reemplazable de
//! [`crate::almacen_dag`]: allí reintentar con otra justificación PoT es la norma; en el destino,
//! una entrada admitida **no se reemplaza**. Hoy ningún mecanismo de producción lo garantiza: el
//! índice está vacío y solo lo tocan las inyecciones de fixture de los tests.

use zx_core::digest::BlockHash;
use zx_core::wire_dag::{BloqueDag, bloque_dag_desde_bytes};

use crate::error::StorageError;

/// Versión del sobre binario de una entrada admitida.
///
/// Se reserva para poder cambiar el códec sin confundir una entrada antigua con corrupción: un
/// discriminante distinto se rechaza, no se reinterpreta.
pub const VERSION_ADMITIDOS_DAG: u8 = 1;

/// Índice de **solo lectura** de bloques DAG plenamente admitidos (destino; hoy vacío en la ruta
/// activa), por `block_hash`.
///
/// # Contrato
///
/// - **No acredita validez ni PoST.** Leer no re-verifica. Que un bloque esté en el índice es una
///   afirmación de la ruta que lo escribió, no de esta API. Hoy el índice está vacío en la ruta
///   activa y solo los tests lo llenan con bytes no verificados: leer de él no certifica nada.
/// - `Ok(None)` es «no está en el índice», **no** «inválido». La ausencia no refuta y la presencia
///   no certifica.
/// - Una entrada que no decodifica completa, con versión desconocida o bajo una clave que no es su
///   `block_hash` se rechaza como [`StorageError::Corrupto`]; no se convierte en `None`.
/// - **No** se consulta el índice de candidatos como respaldo.
/// - No hay método de escritura: promocionar un bloque exige la futura ruta de admisión completa y
///   su publicación atómica.
pub trait AlmacenAdmitidosDag: Send + Sync {
    /// Lee el bloque DAG admitido de `hash`.
    ///
    /// `Ok(None)` significa que la clave no está en el índice, **nunca** que el bloque sea
    /// inválido. Una entrada corrupta se devuelve como [`StorageError::Corrupto`], no como `None`.
    ///
    /// # Errores
    /// [`StorageError::Corrupto`] si lo guardado no decodifica, tiene una versión desconocida, deja
    /// bytes sobrantes o no corresponde a la clave; [`StorageError`] si el backend falla.
    fn bloque_admitido(&self, hash: &BlockHash) -> Result<Option<BloqueDag>, StorageError>;
}

/// Codifica un bloque admitido con el sobre versionado.
///
/// Solo la usan las inyecciones de fixture de los tests: **no** hay escritor de producción. Vive
/// junto al decodificador para que el formato quede en un único sitio.
#[cfg(test)]
pub(crate) fn bloque_admitido_a_bytes(bloque: &BloqueDag) -> Vec<u8> {
    let mut bytes = Vec::new();
    bytes.push(VERSION_ADMITIDOS_DAG);
    zx_core::wire_dag::bloque_dag_a_bytes(&mut bytes, bloque);
    bytes
}

/// Decodifica un bloque admitido exigiendo versión conocida y consumo exacto.
///
/// # Errores
/// [`StorageError::Corrupto`] si el sobre está vacío, la versión es desconocida, el bloque no
/// decodifica o sobran bytes.
pub(crate) fn bloque_admitido_desde_bytes(bytes: &[u8]) -> Result<BloqueDag, StorageError> {
    let Some((version, resto)) = bytes.split_first() else {
        return Err(StorageError::Corrupto {
            que: "una entrada admitida vacía",
        });
    };
    if *version != VERSION_ADMITIDOS_DAG {
        return Err(StorageError::Corrupto {
            que: "una entrada admitida con versión desconocida",
        });
    }
    let (bloque, resto) = bloque_dag_desde_bytes(resto).map_err(|_| StorageError::Corrupto {
        que: "una entrada admitida que no decodifica",
    })?;
    if !resto.is_empty() {
        return Err(StorageError::Corrupto {
            que: "una entrada admitida con bytes finales",
        });
    }
    Ok(bloque)
}

/// Decodifica y comprueba que el bloque corresponde a `clave` (C-HDR-09).
///
/// Es la puerta de lectura compartida por los dos backends.
///
/// # Errores
/// [`StorageError::Corrupto`] si el sobre no decodifica o el `block_hash()` no coincide con la
/// clave.
pub(crate) fn bloque_admitido_con_clave(
    clave: &BlockHash,
    bytes: &[u8],
) -> Result<BloqueDag, StorageError> {
    let bloque = bloque_admitido_desde_bytes(bytes)?;
    if bloque.cabecera.block_hash() != *clave {
        return Err(StorageError::Corrupto {
            que: "una entrada admitida bajo una clave que no es su block_hash",
        });
    }
    Ok(bloque)
}

#[cfg(test)]
#[expect(clippy::expect_used, reason = "los tests fallan con panic por diseño")]
mod tests {
    use super::{AlmacenAdmitidosDag, VERSION_ADMITIDOS_DAG, bloque_admitido_a_bytes};
    use crate::almacen_dag::AlmacenCandidatosDag;
    use crate::error::StorageError;
    use crate::memoria::AlmacenEnMemoria;
    use zx_core::digest::{BlockHash, BodyCommitment, Digest, MerkleRoot};
    use zx_core::preimage::dag::{DagBlockHeader, PadresDag, SolucionPoas};
    use zx_core::wire_dag::{BUNDLE_BYTES, BloqueDag, JustificacionPot, PotCheckpoints};

    /// Cabecera de **fixture**: bytes para probar el índice, **no** una cabecera admitida ni una
    /// PoAS válida. El nombre no acredita nada.
    fn cabecera_de_fixture(slot: u64, marca: u8) -> DagBlockHeader {
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
            padres: PadresDag::nuevo(BlockHash::from_digest(Digest::from_bytes([marca; 32])), &[])
                .expect("un padre seleccionado es canónico"),
            sello: [marca; 64],
        }
    }

    /// Justificación PoT de fixture, con `bundles` portadores distintos.
    fn justificacion(marca: u8, bundles: usize) -> JustificacionPot {
        let lista: Vec<PotCheckpoints> = (0..bundles)
            .map(|i| PotCheckpoints::desde_bytes([marca.wrapping_add(i as u8); BUNDLE_BYTES]))
            .collect();
        JustificacionPot::nueva(lista).expect("dentro del máximo de portadores")
    }

    /// Bloque de fixture sin cuerpo: solo cabecera y justificación.
    fn bloque_de_fixture(cabecera: DagBlockHeader, justificacion: JustificacionPot) -> BloqueDag {
        BloqueDag::nuevo(cabecera, justificacion, vec![], vec![]).expect("sin txs no hay descuadre")
    }

    /// **C-STORE-06/08 · la cola no es el índice.** Un candidato presente no aparece como admitido.
    #[test]
    fn un_candidato_presente_sin_entrada_admitida_devuelve_none() {
        let almacen = AlmacenEnMemoria::nuevo();
        let bloque = bloque_de_fixture(cabecera_de_fixture(41, 0x11), justificacion(0x11, 1));
        let hash = bloque.cabecera.block_hash();
        almacen
            .guardar_candidato_dag(&bloque)
            .expect("la cola guarda el candidato");
        assert_eq!(
            almacen.candidato_dag(&hash).expect("lee el candidato"),
            Some(bloque)
        );
        assert_eq!(
            almacen.bloque_admitido(&hash).expect("consulta el índice"),
            None,
            "un candidato no es una entrada admitida"
        );
    }

    /// Dos cabeceras distintas con el mismo `slot` coexisten y se leen por su hash.
    #[test]
    fn dos_cabeceras_con_el_mismo_slot_coexisten_en_el_indice() {
        let almacen = AlmacenEnMemoria::nuevo();
        let c1 = cabecera_de_fixture(41, 0x21);
        let c2 = cabecera_de_fixture(41, 0x22);
        assert_eq!(c1.slot, c2.slot, "el fixture comparte slot a propósito");
        assert_ne!(
            c1.block_hash(),
            c2.block_hash(),
            "distinta cabecera, distinto hash"
        );

        let b1 = bloque_de_fixture(c1, justificacion(0x21, 1));
        let b2 = bloque_de_fixture(c2, justificacion(0x22, 2));
        almacen
            .inyectar_fixture_admitido(&b1)
            .expect("fixture del primero");
        almacen
            .inyectar_fixture_admitido(&b2)
            .expect("fixture del segundo");

        assert_eq!(
            almacen.bloque_admitido(&c1.block_hash()).expect("lee 1"),
            Some(b1)
        );
        assert_eq!(
            almacen.bloque_admitido(&c2.block_hash()).expect("lee 2"),
            Some(b2)
        );
    }

    /// **Corrupción, no `None`.** Bytes que no decodifican bajo una clave existente se denuncian.
    #[test]
    fn la_corrupcion_en_memoria_no_se_convierte_en_none() {
        let almacen = AlmacenEnMemoria::nuevo();
        let hash = cabecera_de_fixture(60, 0x44).block_hash();
        almacen
            .inyectar_fixture_admitido_crudo(&hash, b"esto no es un bloque DAG")
            .expect("inyecta bytes crudos");
        assert!(
            matches!(
                almacen.bloque_admitido(&hash),
                Err(StorageError::Corrupto { .. })
            ),
            "una entrada ilegible MUST ser corrupción, nunca `None`"
        );
    }

    /// Una versión de sobre desconocida se rechaza: no se reinterpreta como otra cosa.
    #[test]
    fn una_version_desconocida_es_corrupcion() {
        let almacen = AlmacenEnMemoria::nuevo();
        let hash = cabecera_de_fixture(61, 0x45).block_hash();
        let mut bytes = vec![VERSION_ADMITIDOS_DAG.wrapping_add(1)];
        bytes.extend_from_slice(b"cuerpo de una version futura");
        almacen
            .inyectar_fixture_admitido_crudo(&hash, &bytes)
            .expect("inyecta bytes crudos");
        assert!(matches!(
            almacen.bloque_admitido(&hash),
            Err(StorageError::Corrupto { .. })
        ));
    }

    /// Un bloque válido de bytes bajo una clave que no es su `block_hash` es corrupción (C-HDR-09).
    #[test]
    fn una_clave_que_no_es_el_block_hash_es_corrupcion() {
        let almacen = AlmacenEnMemoria::nuevo();
        let bloque = bloque_de_fixture(cabecera_de_fixture(62, 0x46), justificacion(0x46, 1));
        let clave_ajena = cabecera_de_fixture(62, 0x47).block_hash();
        almacen
            .inyectar_fixture_admitido_crudo(&clave_ajena, &bloque_admitido_a_bytes(&bloque))
            .expect("inyecta bytes crudos");
        assert!(matches!(
            almacen.bloque_admitido(&clave_ajena),
            Err(StorageError::Corrupto { .. })
        ));
    }
}
