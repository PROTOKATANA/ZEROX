//! Compromisos R1/R2, hoja de chunk, apertura y verificación.
//!
//! Toda la construcción binaria está fijada en `ESPECIFICACION-BYTES.md`. Resumen:
//!
//! ```text
//! hoja(i) = H_d("ZZKSectorHoja___", s_bucket u16 LE ‖ piece_offset u16 LE ‖ codificado u8 ‖ chunk_almacenado 32 B)
//! nodo    = H_d("ZZKSectorNodo___", izquierdo 32 B ‖ derecho 32 B)
//! vacío   = H_d("ZZKSectorVacio__", "")
//! R2      = H_d("ZZKSectorRaiz___", 0x01 ‖ CBID u32 LE ‖ public_key 32 ‖ sector_index u16 LE ‖
//!                history_size u64 LE ‖ pieces_in_sector u16 LE ‖
//!                H_d("ZZKSectorMapa___", bytes del SectorContentsMap) ‖
//!                H_d("ZZKSectorMeta___", bytes de la región de metadatos) ‖
//!                raiz_chunks 32 ‖ n u32 LE)
//! ```
//!
//! R1 se define **solo en S01** (la orden no fija su serialización): es un alta de contabilidad con
//! `(public_key, sector_index, history_size, slot_alta)`.

use crate::h_d::{TAG_ALTA, TAG_HOJA, TAG_MAPA, TAG_META, TAG_RAIZ, h_d};
use crate::merkle::raiz_desde_camino;
use subspace_core_primitives::solutions::Solution;

/// Versión del formato R2. Byte `0x01` que abre la preimagen de R2. La orden lo fija.
pub const VERSION_R2: u8 = 0x01;

/// `SectorIndex` en el formato (idéntico al tipo de Autonomys).
pub type SectorIndex = u16;

/// Chunks usados por registro. Constante del clon (`Record::NUM_CHUNKS = 2^15`), no un parámetro
/// de S01: `n = pieces_in_sector · NUM_CHUNKS` cuando el mapa tiene todos los chunks usados.
pub const NUM_CHUNKS: u32 = 32_768;

/// CBID de prueba, **declarado por S01**.
///
/// ORDEN-S01 §3 pide usar `CBID_RED_DEV` «si ya existe en `zx-core`». Se comprobó en el checkout de
/// la raíz que **no existe** ningún `CBID_RED_DEV` ni un `CBID` de red dev: lo único parecido es un
/// `CONSENSUS_BRANCH_ID` que se pasa como argumento y el valor `0xc478_80ea` usado en los tests de
/// `zx-core`/`zx-consensus`. Se declara aquí ese valor como CBID de prueba, explícitamente **no** un
/// parámetro de red.
pub const CBID_PRUEBA: u32 = 0xc478_80ea;

/// Campos públicos que fijan la identidad del objeto comprometido.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CamposPublicos {
    /// Dominio de red / rama de consenso (CBID).
    pub cbid: u32,
    /// Clave pública del granjero, 32 B.
    pub public_key: [u8; 32],
    /// Índice de sector.
    pub sector_index: SectorIndex,
    /// `history_size` con que se ploteó, en segmentos.
    pub history_size: u64,
    /// Piezas del sector que se comprometen.
    pub pieces_in_sector: u16,
    /// Número de hojas del árbol de chunks (`n`).
    pub n: u32,
}

/// Compromiso R2: 32 B.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CompromisoR2(pub [u8; 32]);

/// Alta R1: identidad y fecha, solo contabilidad.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CompromisoR1(pub [u8; 32]);

/// `hoja(i) = H_d("ZZKSectorHoja___", s_bucket u16 LE ‖ piece_offset u16 LE ‖ codificado u8 ‖
/// chunk_almacenado 32 B)`.
#[must_use]
pub fn hoja(
    s_bucket: u16,
    piece_offset: u16,
    codificado: u8,
    chunk_almacenado: &[u8; 32],
) -> [u8; 32] {
    let mut msg = [0u8; 2 + 2 + 1 + 32];
    msg[0..2].copy_from_slice(&s_bucket.to_le_bytes());
    msg[2..4].copy_from_slice(&piece_offset.to_le_bytes());
    msg[4] = codificado;
    msg[5..].copy_from_slice(chunk_almacenado);
    h_d(&TAG_HOJA, &msg)
}

/// Compromiso R1 del alta. **Construcción elegida en S01** (la orden no fija bytes para R1):
/// `H_d("ZZKSectorAlta___", public_key 32 ‖ sector_index u16 LE ‖ history_size u64 LE ‖
/// slot_alta u64 LE)`.
#[must_use]
pub fn compromiso_r1(
    public_key: &[u8; 32],
    sector_index: SectorIndex,
    history_size: u64,
    slot_alta: u64,
) -> CompromisoR1 {
    let mut msg = [0u8; 32 + 2 + 8 + 8];
    msg[0..32].copy_from_slice(public_key);
    msg[32..34].copy_from_slice(&sector_index.to_le_bytes());
    msg[34..42].copy_from_slice(&history_size.to_le_bytes());
    msg[42..50].copy_from_slice(&slot_alta.to_le_bytes());
    CompromisoR1(h_d(&TAG_ALTA, &msg))
}

/// Digest del `SectorContentsMap` tal cual se almacena (incluye su checksum BLAKE3 interno).
#[must_use]
pub fn digest_mapa(bytes_mapa: &[u8]) -> [u8; 32] {
    h_d(&TAG_MAPA, bytes_mapa)
}

/// Digest de la región de metadatos de registros tal cual se almacena.
#[must_use]
pub fn digest_meta(bytes_meta: &[u8]) -> [u8; 32] {
    h_d(&TAG_META, bytes_meta)
}

/// Preimagen de R2 con una versión arbitraria. Se expone para poder probar el negativo «versión
/// cambiada» sin reimplementar la construcción en el test.
#[must_use]
pub fn preimagen_r2(
    version: u8,
    campos: &CamposPublicos,
    digest_mapa: &[u8; 32],
    digest_meta: &[u8; 32],
    raiz_chunks: &[u8; 32],
) -> Vec<u8> {
    let mut msg = Vec::with_capacity(1 + 4 + 32 + 2 + 8 + 2 + 32 + 32 + 32 + 4);
    msg.push(version);
    msg.extend_from_slice(&campos.cbid.to_le_bytes());
    msg.extend_from_slice(&campos.public_key);
    msg.extend_from_slice(&campos.sector_index.to_le_bytes());
    msg.extend_from_slice(&campos.history_size.to_le_bytes());
    msg.extend_from_slice(&campos.pieces_in_sector.to_le_bytes());
    msg.extend_from_slice(digest_mapa);
    msg.extend_from_slice(digest_meta);
    msg.extend_from_slice(raiz_chunks);
    msg.extend_from_slice(&campos.n.to_le_bytes());
    msg
}

/// R2 = `H_d("ZZKSectorRaiz___", preimagen_r2(VERSION_R2, ...))`.
#[must_use]
pub fn compromiso_r2_con_version(
    version: u8,
    campos: &CamposPublicos,
    digest_mapa: &[u8; 32],
    digest_meta: &[u8; 32],
    raiz_chunks: &[u8; 32],
) -> CompromisoR2 {
    CompromisoR2(h_d(
        &TAG_RAIZ,
        &preimagen_r2(version, campos, digest_mapa, digest_meta, raiz_chunks),
    ))
}

/// R2 con la versión fijada por la orden (`0x01`).
#[must_use]
pub fn compromiso_r2(
    campos: &CamposPublicos,
    digest_mapa: &[u8; 32],
    digest_meta: &[u8; 32],
    raiz_chunks: &[u8; 32],
) -> CompromisoR2 {
    compromiso_r2_con_version(VERSION_R2, campos, digest_mapa, digest_meta, raiz_chunks)
}

/// Apertura de una solución ganadora frente a R2.
///
/// La orden define la apertura como `(chunk_location, camino Merkle)` más los dos digests que
/// transporta. Se añaden `s_bucket`, `piece_offset`, `codificado` y `raiz_chunks` como campos
/// redundantes **solo para poder atribuir el rechazo** a la causa concreta; el verificador los
/// coteja contra el contexto/la solución y contra el camino, y **no** confía en ellos.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Apertura {
    /// Posición global del chunk en la región de s-buckets.
    pub chunk_location: u32,
    /// Hermanos Merkle de abajo arriba.
    pub camino: Vec<[u8; 32]>,
    /// `1` si el chunk se guardó codificado con la prueba de espacio; `0` si no.
    pub codificado: u8,
    /// Raíz del árbol de chunks que el camino debe reproducir.
    pub raiz_chunks: [u8; 32],
    /// `H_d("ZZKSectorMapa___", bytes del SectorContentsMap)`.
    pub digest_mapa: [u8; 32],
    /// `H_d("ZZKSectorMeta___", bytes de la región de metadatos)`.
    pub digest_meta: [u8; 32],
    /// s-bucket auditado (contexto). Redundante, cotejado.
    pub s_bucket: u16,
    /// `piece_offset` de la solución. Redundante, cotejado.
    pub piece_offset: u16,
}

/// Motivo concreto de rechazo de una apertura.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum ErrorApertura {
    /// La clave pública de la solución no es la del compromiso.
    #[error("clave pública distinta de la comprometida")]
    ClaveDistinta,
    /// El índice de sector de la solución no es el del compromiso.
    #[error("sector_index distinto del comprometido")]
    SectorDistinto,
    /// El `history_size` de la solución no es el del compromiso.
    #[error("history_size distinto del comprometido")]
    HistoriaDistinta,
    /// El `piece_offset` de la apertura no es el de la solución.
    #[error("piece_offset de la apertura distinto del de la solución")]
    PieceOffsetDistinto,
    /// El `s_bucket` de la apertura no es el auditado por el contexto.
    #[error("s_bucket de la apertura distinto del auditado")]
    SBucketDistinto,
    /// El chunk no se declara codificado (`codificado != 1`).
    #[error("el chunk no está codificado (codificado = {0})")]
    CodificadoNoUno(u8),
    /// `chunk_location` cae fuera de `0 .. n`.
    #[error("chunk_location {0} fuera de rango (n = {1})")]
    ChunkLocationFueraDeRango(u32, u32),
    /// La longitud del camino no corresponde a `n` hojas.
    #[error("longitud de camino inválida para n = {0}")]
    CaminoLongitudInvalida(u32),
    /// El camino no reconstruye la `raiz_chunks` declarada.
    #[error("el camino no reconstruye la raíz de chunks declarada")]
    CaminoNoCoincide,
    /// La R2 recompuesta no coincide con la comprometida.
    #[error("R2 recompuesta distinta de la comprometida")]
    R2NoCoincide,
    /// El campo `n` del compromiso no es coherente con `pieces_in_sector`.
    #[error("n = {0} incoherente con pieces_in_sector = {1}")]
    IncoherenciaCardinalidad(u32, u16),
}

/// Verifica una apertura contra `r2` con el contexto ya validado.
///
/// Es el paso que liga una **pieza** concreta al objeto comprometido. No verifica que la solución
/// PoAS sea válida: eso lo hace el verificador real (`verify_solution`) por separado, como exige
/// ORDEN-S01 §6, y no se sustituye aquí.
///
/// # Errores
///
/// Cada comprobación fallida devuelve su variante de [`ErrorApertura`]; ninguna se convierte en
/// `Ok` ni en un booleano.
pub fn verificar_apertura(
    r2: &CompromisoR2,
    apertura: &Apertura,
    solucion: &Solution<()>,
    s_bucket: u16,
    campos: &CamposPublicos,
) -> Result<(), ErrorApertura> {
    // 1-3. Identidad de la solución frente al compromiso (modelo de amenaza §5).
    let pk: [u8; 32] = solucion
        .public_key
        .as_ref()
        .try_into()
        .map_err(|_| ErrorApertura::ClaveDistinta)?;
    if pk != campos.public_key {
        return Err(ErrorApertura::ClaveDistinta);
    }
    if solucion.sector_index != campos.sector_index {
        return Err(ErrorApertura::SectorDistinto);
    }
    if u64::from(solucion.history_size.get()) != campos.history_size {
        return Err(ErrorApertura::HistoriaDistinta);
    }

    // 4-5. Coherencia de los campos redundantes de la apertura.
    let piece_offset: u16 = solucion.piece_offset.into();
    if apertura.piece_offset != piece_offset {
        return Err(ErrorApertura::PieceOffsetDistinto);
    }
    if apertura.s_bucket != s_bucket {
        return Err(ErrorApertura::SBucketDistinto);
    }

    // 6. La orden fija `codificado = 1` para una apertura de solución ganadora.
    if apertura.codificado != 1 {
        return Err(ErrorApertura::CodificadoNoUno(apertura.codificado));
    }
    if u32::from(apertura.s_bucket) != u32::from(s_bucket) {
        return Err(ErrorApertura::SBucketDistinto);
    }

    // 7. Cardinalidad coherente con las piezas.
    let n_esperado = u32::from(campos.pieces_in_sector) * NUM_CHUNKS;
    if campos.n == 0 || campos.n != n_esperado {
        return Err(ErrorApertura::IncoherenciaCardinalidad(
            campos.n,
            campos.pieces_in_sector,
        ));
    }
    if apertura.chunk_location >= campos.n {
        return Err(ErrorApertura::ChunkLocationFueraDeRango(
            apertura.chunk_location,
            campos.n,
        ));
    }

    // 8-9. `chunk_almacenado = chunk XOR proof_of_space.hash()` (director: lib.rs:248-249).
    let chunk: [u8; 32] = *solucion.chunk;
    let proof_hash: [u8; 32] = *solucion.proof_of_space.hash();
    let mut chunk_almacenado = [0u8; 32];
    for i in 0..32 {
        chunk_almacenado[i] = chunk[i] ^ proof_hash[i];
    }
    let hoja_calc = hoja(
        apertura.s_bucket,
        apertura.piece_offset,
        1,
        &chunk_almacenado,
    );

    // 10. El camino debe reproducir la raíz declarada con la longitud exacta.
    let raiz_calc = raiz_desde_camino(
        apertura.chunk_location as usize,
        hoja_calc,
        &apertura.camino,
        campos.n as usize,
    )
    .ok_or(ErrorApertura::CaminoLongitudInvalida(campos.n))?;
    if raiz_calc != apertura.raiz_chunks {
        return Err(ErrorApertura::CaminoNoCoincide);
    }

    // 11. Recomposición de R2 con los campos públicos y los digests que transporta la apertura.
    let r2_calc = compromiso_r2(
        campos,
        &apertura.digest_mapa,
        &apertura.digest_meta,
        &apertura.raiz_chunks,
    );
    if r2_calc != *r2 {
        return Err(ErrorApertura::R2NoCoincide);
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{
        CamposPublicos, VERSION_R2, compromiso_r1, compromiso_r2, compromiso_r2_con_version,
        preimagen_r2,
    };

    fn campos() -> CamposPublicos {
        CamposPublicos {
            cbid: super::CBID_PRUEBA,
            public_key: [7u8; 32],
            sector_index: 2,
            history_size: 1,
            pieces_in_sector: 2,
            n: 2 * super::NUM_CHUNKS,
        }
    }

    #[test]
    fn r1_es_estable_y_sensible_al_slot() {
        let a = compromiso_r1(&[1u8; 32], 2, 1, 1000);
        let b = compromiso_r1(&[1u8; 32], 2, 1, 1000);
        let c = compromiso_r1(&[1u8; 32], 2, 1, 1001);
        assert_eq!(a, b);
        assert_ne!(a, c);
    }

    #[test]
    fn la_version_entra_en_la_preimagen() {
        let c = campos();
        let dm = [1u8; 32];
        let dx = [2u8; 32];
        let rz = [3u8; 32];
        assert_ne!(
            compromiso_r2(&c, &dm, &dx, &rz),
            compromiso_r2_con_version(2, &c, &dm, &dx, &rz)
        );
        let pre = preimagen_r2(VERSION_R2, &c, &dm, &dx, &rz);
        assert_eq!(pre[0], VERSION_R2);
        assert_eq!(pre.len(), 1 + 4 + 32 + 2 + 8 + 2 + 32 + 32 + 32 + 4);
    }
}
