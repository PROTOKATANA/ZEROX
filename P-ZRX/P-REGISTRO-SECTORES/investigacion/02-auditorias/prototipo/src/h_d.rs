//! `H_d(tag, m) = SHA3-256(tag ‖ m)` (SPEC §3, C-HASH-04).
//!
//! # Por qué se reimplementa en vez de reutilizar `zx_core::hash`
//!
//! ORDEN-S01 §3 exige decir cuál de las dos vías se tomó. Se comprobó en el checkout de la raíz
//! (`L01/checkout/crates/zx-core/src/hash.rs`) que `h_d` es `pub(crate)` **a propósito y de forma
//! no negociable**, y `DomainTag` también: ningún crate externo puede alcanzarlos. Por tanto la
//! reutilización directa **no es posible** sin tocar `zx-core` (fuera de esta zona y prohibido por
//! ORDEN-S01 §9). Se reimplementa aquí la construcción, que es exactamente la del SPEC:
//!
//! ```text
//! H_d(tag, m) := SHA3-256( tag ‖ m ),  tag de 16 B
//! ```
//!
//! Las etiquetas son `[u8; 16]` literales `*b"..."`: una etiqueta de longitud distinta **no
//! compila**. El oráculo Julia independiente (`oraculo-r2/`) recalcula el mismo SHA3-256 con la
//! librería `SHA` de Julia, lo que da una segunda implementación.

use sha3::{Digest as _, Sha3_256};

/// Etiqueta de hoja de chunk. 16 B exactos.
pub const TAG_HOJA: [u8; 16] = *b"ZZKSectorHoja___";
/// Etiqueta de nodo interno del árbol de chunks. 16 B exactos.
pub const TAG_NODO: [u8; 16] = *b"ZZKSectorNodo___";
/// Etiqueta del relleno vacío hasta potencia de dos. 16 B exactos.
pub const TAG_VACIO: [u8; 16] = *b"ZZKSectorVacio__";
/// Etiqueta de la raíz R2. 16 B exactos.
pub const TAG_RAIZ: [u8; 16] = *b"ZZKSectorRaiz___";
/// Etiqueta del digest del `SectorContentsMap`. 16 B exactos.
pub const TAG_MAPA: [u8; 16] = *b"ZZKSectorMapa___";
/// Etiqueta del digest de la región de metadatos de registros. 16 B exactos.
pub const TAG_META: [u8; 16] = *b"ZZKSectorMeta___";
/// Etiqueta **elegida por S01** para R1 (la orden no fija una). 16 B exactos.
pub const TAG_ALTA: [u8; 16] = *b"ZZKSectorAlta___";

/// `H_d(tag, m) = SHA3-256(tag ‖ m)`.
#[must_use]
pub fn h_d(tag: &[u8; 16], msg: &[u8]) -> [u8; 32] {
    let mut hasher = Sha3_256::new();
    hasher.update(tag);
    hasher.update(msg);
    let salida = hasher.finalize();
    let mut bytes = [0u8; 32];
    bytes.copy_from_slice(&salida);
    bytes
}

#[cfg(test)]
mod tests {
    use super::h_d;
    use sha3::{Digest as _, Sha3_256};

    /// H_d debe ser exactamente SHA3-256(tag ‖ m), sin sustituir el crate.
    #[test]
    fn h_d_es_sha3_256_con_prefijo() {
        let tag = *b"ZZKSectorHoja___";
        let msg = b"mensaje de prueba";
        let mut hasher = Sha3_256::new();
        hasher.update(tag);
        hasher.update(msg);
        let esperado: [u8; 32] = hasher.finalize().into();
        assert_eq!(h_d(&tag, msg), esperado);
    }
}
