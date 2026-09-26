//! Identidad de GHOSTDAG del bloque producido: compromiso documentado (`PROGRESO.md` punto 3).
//!
//! `zx-cadena::BloquePost::identidad` es `u64` (dominio de fixture de `IdentidadGhostdag::
//! de_fixture`), no `IdentidadGhostdag::Billete(IdentidadTicket)`. `C-GD-07` exige la tupla literal
//! `(public_key, sector_index, history_size, chunk, slot)`; comprimirla a un `u64` **no es
//! inyectivo** (lo dice `zx_dag::identidad`). Este módulo trunca la huella SHA3-256 de 32 B —ya
//! separada por dominio y versión— a sus primeros 8 bytes. Es un compromiso, no una prueba de
//! unicidad de billete: se declara en `INFORME.md` §"lo no demostrado".

use zx_core::DagBlockHeader;
use zx_dag::identidad_de_cabecera;

/// Deriva la identidad `u64` (dominio de fixture) de una cabecera PoST ya construida.
///
/// `0` se traduce a `1`: en el dominio de fixture, `0` es el centinela `SinBillete`
/// (`IdentidadGhostdag::de_fixture`), y un billete real nunca debe leerse como ausencia. La
/// probabilidad de que la huella trunque a `0` es `2^-64`; el ajuste no cambia la propiedad
/// criptográfica, solo evita el único valor reservado.
#[must_use]
pub fn identidad_u64_de_cabecera(cabecera: &DagBlockHeader) -> u64 {
    let huella = identidad_de_cabecera(cabecera).huella();
    #[expect(
        clippy::unwrap_used,
        reason = "huella() siempre da 32 bytes; los primeros 8 siempre convierten"
    )]
    let primeros8: [u8; 8] = huella[..8].try_into().unwrap();
    let v = u64::from_be_bytes(primeros8);
    if v == 0 { 1 } else { v }
}

#[cfg(test)]
mod tests {
    use super::identidad_u64_de_cabecera;
    use zx_core::digest::{BodyCommitment, Digest, MerkleRoot};
    use zx_core::{DagBlockHeader, PadresDag, SolucionPoas};

    fn cabecera(slot: u64, chunk: u8) -> DagBlockHeader {
        DagBlockHeader {
            consensus_branch_id: zx_core::CBID_RED_DEV,
            merkle_root: MerkleRoot::from_digest(Digest::from_bytes([1; 32])),
            timestamp: 1_788_480_000,
            height: 0,
            slot,
            pot_output: [0u8; 16],
            rango_solucion: 1,
            sol: SolucionPoas {
                chunk: [chunk; 32],
                ..SolucionPoas::default()
            },
            body_commitment: BodyCommitment::from_digest(Digest::from_bytes([2; 32])),
            padres: PadresDag::genesis(),
            sello: [0u8; 64],
        }
    }

    #[test]
    fn es_determinista_y_nunca_cero() {
        let a = identidad_u64_de_cabecera(&cabecera(1, 0xAA));
        let b = identidad_u64_de_cabecera(&cabecera(1, 0xAA));
        let c = identidad_u64_de_cabecera(&cabecera(1, 0xBB));
        assert_eq!(a, b);
        assert_ne!(a, c);
        assert_ne!(a, 0);
        assert_ne!(c, 0);
    }
}
