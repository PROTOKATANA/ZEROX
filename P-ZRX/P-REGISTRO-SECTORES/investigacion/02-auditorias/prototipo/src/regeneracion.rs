//! Regeneración real de chunks para S02a.
//!
//! Reproduce `record_encoding` del plotter (privada en el clon): genera la tabla de prueba de
//! espacio del registro con `generate_parallel`, extiende el registro con erasure coding y
//! enmascara el chunk con `proof.hash()`. No se reimplementa PoS ni erasure coding: se llama a la
//! API pública del clon fijado `f8842d0`.
//!
//! La pieza se obtiene de la historia archivada **local** del fixture. Por decisión de la orden
//! (S02a §3.3) el coste de red de esa obtención no se mide: la historia es pública y se supone
//! gratuita y local. La medición separa la obtención (una sola vez por registro, fuera del camino
//! cronometrado) de la generación de la tabla y la codificación.

use futures::executor::block_on;
use subspace_core_primitives::pieces::{PieceOffset, Record};
use subspace_core_primitives::pos::PosProof;
use subspace_core_primitives::sectors::SectorId;
use subspace_data_retrieval::piece_getter::PieceGetter;
use subspace_kzg::Scalar;
use subspace_proof_of_space::chia::ChiaTable;
use subspace_proof_of_space::{Table, TableGenerator};

use crate::sector::{Entorno, ErrorSector, ParametrosPlot, hs};

/// Tabla de prueba de espacio de un registro más su codificación erasure.
///
/// `fuente` son los `NUM_CHUNKS = 2^15` escalares del registro; `paridad` los `2^15` de paridad.
/// El chunk del s-bucket `b` es `fuente[b/2]` si `b` es par y `paridad[b/2]` si es impar, igual que
/// el `interleave` de `record_encoding`.
pub struct TablaRegistro {
    tabla: ChiaTable,
    fuente: Vec<[u8; 32]>,
    paridad: Vec<[u8; 32]>,
}

impl TablaRegistro {
    /// Obtiene de la historia local el registro `piece_offset` y lo devuelve en un `Box` (el
    /// `Record` completo mide 1 MiB y no debe copiarse por la pila).
    ///
    /// # Errores
    ///
    /// Falla si la pieza no está en la historia local o si `get_piece` falla.
    pub fn pieza_de(
        entorno: &Entorno,
        p: &ParametrosPlot,
        sector_id: &SectorId,
        piece_offset: u16,
    ) -> Result<Box<Record>, ErrorSector> {
        let po = PieceOffset::from(piece_offset);
        let pieza_idx = sector_id.derive_piece_index(
            po,
            hs(p.history_size),
            p.pieces_in_sector,
            hs(p.recent_segments),
            (
                hs(p.recent_history_fraction.0),
                hs(p.recent_history_fraction.1),
            ),
        );
        let pieza = block_on(entorno.historial().get_piece(pieza_idx))
            .map_err(|e| ErrorSector::Regeneracion(format!("get_piece: {e}")))?
            .ok_or_else(|| ErrorSector::Regeneracion(format!("pieza {pieza_idx} no encontrada")))?;
        let mut record = Record::new_boxed();
        let destino: &mut [u8] = AsMut::<[u8]>::as_mut(record.as_mut());
        destino.copy_from_slice(AsRef::<[u8]>::as_ref(pieza.record()));
        Ok(record)
    }

    /// Genera la tabla PoS del registro y su codificación erasure. **Camino cronometrado.**
    ///
    /// # Errores
    ///
    /// Falla si el registro no es un escalar válido o si el erasure coding falla.
    pub fn desde_pieza(
        entorno: &Entorno,
        record: &Record,
        sector_id: &SectorId,
        piece_offset: u16,
    ) -> Result<Self, ErrorSector> {
        let po = PieceOffset::from(piece_offset);
        let semilla = sector_id.derive_evaluation_seed(po);
        let tabla = ChiaTable::generator().generate_parallel(&semilla);
        let fuente: Vec<[u8; 32]> = record.to_vec();
        let escalares: Vec<Scalar> = fuente
            .iter()
            .map(|b| Scalar::try_from(b).expect("el chunk de un registro es un escalar válido"))
            .collect();
        let paridad: Vec<[u8; 32]> = entorno
            .erasure_coding()
            .extend(&escalares)
            .map_err(|e| ErrorSector::Regeneracion(format!("erasure extend: {e}")))?
            .into_iter()
            .map(<[u8; 32]>::from)
            .collect();
        Ok(Self {
            tabla,
            fuente,
            paridad,
        })
    }

    /// Chunk fuente/paridad del s-bucket, sin enmascarar.
    #[must_use]
    pub fn chunk_fuente(&self, s_bucket: u16) -> [u8; 32] {
        let b = usize::from(s_bucket);
        if b % 2 == 0 {
            self.fuente[b / 2]
        } else {
            self.paridad[b / 2]
        }
    }

    /// Prueba de espacio del s-bucket, si existe (`None` si no la hay).
    #[must_use]
    pub fn proof(&self, s_bucket: u16) -> Option<PosProof> {
        self.tabla.find_proof(u32::from(s_bucket))
    }

    /// Enmascara un chunk fuente con la prueba: `fuente XOR proof.hash()`.
    #[must_use]
    pub fn enmascarar(fuente: &[u8; 32], proof: &PosProof) -> [u8; 32] {
        let ph: [u8; 32] = *proof.hash();
        let mut salida = [0u8; 32];
        for i in 0..32 {
            salida[i] = fuente[i] ^ ph[i];
        }
        salida
    }

    /// Chunk **almacenado** del s-bucket para el bit `codificado` del mapa:
    /// si `codificado` es 1, `fuente XOR proof.hash()` (exige prueba); si es 0, el chunk fuente.
    ///
    /// # Errores
    ///
    /// Falla si el mapa declara `codificado = 1` pero la tabla no tiene prueba en ese s-bucket.
    pub fn chunk_para_hoja(
        &self,
        s_bucket: u16,
        codificado: u8,
    ) -> Result<[u8; 32], ErrorSector> {
        let fuente = self.chunk_fuente(s_bucket);
        if codificado == 1 {
            let proof = self.proof(s_bucket).ok_or_else(|| {
                ErrorSector::Regeneracion(format!(
                    "el mapa declara codificado = 1 en s_bucket {s_bucket} pero no hay prueba"
                ))
            })?;
            Ok(Self::enmascarar(&fuente, &proof))
        } else {
            Ok(fuente)
        }
    }
}
