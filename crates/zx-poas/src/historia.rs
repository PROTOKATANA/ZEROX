//! Historia archivada del **génesis dev** (D-P12) y contexto de pieza coherente con ella.
//!
//! # Qué es y qué no es
//!
//! [`HistoriaGenesis`] archiva **una vez** el cuerpo del génesis dev de W04
//! (`zx_consensus::GENESIS_DEV`) —codificado con la red de `zx_core::wire`— rellenado hasta
//! `RecordedHistorySegment::SIZE` con `ChaCha8Rng` sembrado con `block_hash(génesis)`, usando el
//! `Archiver` real del clon fijado (`PDF/autonomys-subspace` @ `f8842d0`). Expone, de forma
//! inmutable:
//!
//! - el segmento archivado [`NewArchivedSegment`] que produjo esa archivación (el **primero**, es
//!   decir el segmento 0);
//! - el [`Kzg`] y el [`ErasureCoding`] con los que se archivó;
//! - el [`FarmerProtocolInfo`] de desarrollo ([`crate::protocolo_dev`]);
//! - el contexto de pieza [`PieceCheckParams`] coherente con el segmento y con ese protocolo.
//!
//! Es la **fuente única** que productor, auditor y verificador comparten para no reconstruir cada
//! uno su propia historia. Sustituye a `HistoriaDagDev` de `9681061`, que archivaba un
//! `RecordedHistorySegment` llenado por splitmix64 con semilla fija: ahora el contenido deriva del
//! génesis real de la red dev (D-P12).
//!
//! **No acredita validez.** No hay ninguna función que declare válida una cabecera ni un bloque.
//! `params_pieza` devuelve un contexto de pieza coherente con esta historia dev, pero el cableado a
//! la puerta conjunta (snapshot causal del pasado, flujo, rango, cabecera) es de W05b2; este objeto
//! no admite bloques.
//!
//! # La receta, byte a byte (D-P12)
//!
//! 1. `bytes = cuerpo_a_bytes(génesis dev)`: cabecera PoW de 92 B + `CompactSize(n_tx)` + la
//!    coinbase del génesis con sus testigos (ninguno).
//! 2. `bytes.resize(RecordedHistorySegment::SIZE, 0)`.
//! 3. `ChaCha8Rng::from_seed(block_hash(génesis))` y `rng.fill` sobre la cola `[cuerpo.len(), SIZE)`
//!    — el mismo patrón de Autonomys `sc-consensus-subspace/src/archiver.rs:524-541`, que siembra
//!    con el `state_root`.
//! 4. `Archiver::new(kzg, erasure_coding).add_block(bytes, BlockObjectMapping::default(), false)`.
//! 5. El **primer** `NewArchivedSegment` es el segmento 0.
//!
//! Nuestra semilla y nuestro RNG son una **definición propia** (D-P12): Autonomys siembra con el
//! `state_root` y usa `rand_chacha 0.3.1`; aquí se siembra con `block_hash(génesis)` y se usa
//! `rand_chacha =0.9.0`.
//!
//! # Inmutabilidad de la fuente
//!
//! Los getters exponen el segmento, el KZG, el erasure coding y el protocolo **tal como se
//! archivaron**, y `params_pieza` los deriva de ellos. No existe constructor alterno: no se acepta
//! un compromiso, una historia ni unos parámetros suministrados por un candidato o un usuario.

use std::num::NonZeroUsize;

use rand::{Rng as _, SeedableRng as _};
use rand_chacha::ChaCha8Rng;
use subspace_archiving::archiver::{Archiver, NewArchivedSegment};
use subspace_core_primitives::objects::BlockObjectMapping;
use subspace_core_primitives::pieces::Record;
use subspace_core_primitives::segments::{HistorySize, RecordedHistorySegment, SegmentCommitment};
use subspace_erasure_coding::ErasureCoding;
use subspace_farmer_components::FarmerProtocolInfo;
use subspace_kzg::Kzg;
use subspace_verification::PieceCheckParams;
use thiserror::Error;
use zx_consensus::{ErrorPow, GENESIS_DEV, construir as construir_genesis};
use zx_core::wire::cuerpo_a_bytes;

use crate::protocolo_dev;

/// Compromiso de segmento **congelado** de la historia génesis dev (D-P12), en bytes.
///
/// Es el valor medido por dos procesos independientes sobre la receta de este módulo
/// ([`HistoriaGenesis::construir_bruto`]). Se congela para detectar divergencia local del archivo
/// determinista: **no** es un compromiso de mainnet/testnet ni un parámetro de red, y su cotejo no
/// acredita disponibilidad de historia en red ni valida cabeceras. El test
/// `el_compromiso_de_la_historia_genesis_esta_congelado` lo recalcula.
pub const COMPROMISO_HISTORIA_GENESIS_DEV: [u8; 48] = [
    0x81, 0x26, 0xfd, 0xbe, 0xd3, 0x26, 0x02, 0x27, 0xc9, 0xbe, 0xb6, 0x55, 0x67, 0x3b, 0x19, 0x54,
    0x5d, 0x3e, 0x41, 0x2b, 0xf9, 0xad, 0x7e, 0x8a, 0x36, 0xda, 0xf7, 0x0e, 0x64, 0xd3, 0x3d, 0x8c,
    0xea, 0xcd, 0xc9, 0x41, 0xac, 0x78, 0x1e, 0x9c, 0xe2, 0xfa, 0x1d, 0xf5, 0x29, 0xf2, 0x4a, 0xf9,
];

/// Error tipado de la construcción de la historia archivada del génesis dev.
///
/// Separa el fallo del génesis de W04, el del erasure coding, un tamaño de historia no
/// representable como `NonZeroU64`, la ausencia de segmento archivado y la divergencia del
/// compromiso congelado. Ninguno se convierte en un objeto a medias: [`HistoriaGenesis::construir`]
/// solo devuelve `Ok` con el segmento ya archivado.
#[derive(Debug, Error)]
pub enum ErrorHistoriaGenesis {
    /// El génesis dev de W04 no se pudo construir o comprobar.
    #[error("génesis dev de W04: {0}")]
    Genesis(#[from] ErrorPow),
    /// La escala del erasure coding no cabe en `usize` o es cero.
    #[error("escala de erasure coding inválida para la historia génesis dev")]
    EscalaErasureCoding,
    /// `ErasureCoding::new` rechazó la escala calculada.
    ///
    /// El upstream devuelve `String`, de tipado pobre; se conserva textualmente sin fabricar éxito.
    #[error("el erasure coding de la historia génesis dev no se pudo construir: {0}")]
    ErasureCoding(String),
    /// El cuerpo del génesis quedó vacío o más largo que un segmento: no hay cola que rellenar.
    #[error(
        "el cuerpo del génesis ({cuerpo} B) no deja cola dentro de un segmento de {segmento} B"
    )]
    RellenoInvalido {
        /// Longitud del cuerpo codificado del génesis.
        cuerpo: usize,
        /// Tamaño del segmento.
        segmento: usize,
    },
    /// Un tamaño de historia del protocolo dev sería cero y no es representable como `HistorySize`.
    #[error("tamaño de historia dev cero para {segmentos} segmentos")]
    TamanoHistoriaCero {
        /// Tamaño de historia pedido, en segmentos.
        segmentos: u64,
    },
    /// El bloque determinista no produjo ningún segmento archivado.
    #[error("la historia génesis dev no produjo ningún segmento archivado")]
    SinSegmentoArchivado,
    /// El segmento archivado no reprodujo el compromiso congelado.
    ///
    /// Lleva ambos valores para que el fallo sea diagnosticable; el esperado no se deriva del
    /// observado y el observado no se acepta: [`HistoriaGenesis::construir`] no crea el objeto.
    #[error("compromiso de segmento inesperado: esperado {esperado:?}, observado {observado:?}")]
    CompromisoInesperado {
        /// Compromiso congelado de la historia génesis dev.
        esperado: SegmentCommitment,
        /// Compromiso que produjo esta ejecución.
        observado: SegmentCommitment,
    },
}

/// Historia archivada del génesis dev, inmutable una vez construida.
///
/// Se crea con [`HistoriaGenesis::construir`] y solo se lee por sus getters. Los campos son
/// privados a propósito: no se puede construir una instancia con un compromiso, una historia o un
/// protocolo traídos de fuera.
#[derive(Debug)]
pub struct HistoriaGenesis {
    historial: NewArchivedSegment,
    kzg: Kzg,
    erasure_coding: ErasureCoding,
    protocolo: FarmerProtocolInfo,
}

impl HistoriaGenesis {
    /// Construye la historia archivada del génesis dev.
    ///
    /// Aplica la receta de la cabecera del módulo (D-P12) y coteja que el compromiso del primer
    /// segmento coincida con [`COMPROMISO_HISTORIA_GENESIS_DEV`]. No usa `unwrap` ni `expect`: si el
    /// génesis, el erasure coding, el relleno, el archiver o el compromiso fallan, devuelve
    /// [`ErrorHistoriaGenesis`] sin construir el objeto.
    ///
    /// # Errores
    ///
    /// [`ErrorHistoriaGenesis::Genesis`] si el génesis dev no se construye,
    /// [`ErrorHistoriaGenesis::EscalaErasureCoding`] o [`ErrorHistoriaGenesis::ErasureCoding`] si
    /// el erasure coding no se puede instanciar, [`ErrorHistoriaGenesis::RellenoInvalido`] si el
    /// cuerpo no deja cola en el segmento, [`ErrorHistoriaGenesis::TamanoHistoriaCero`] si algún
    /// tamaño del protocolo dev fuera cero, [`ErrorHistoriaGenesis::SinSegmentoArchivado`] si el
    /// archiver no produjo ningún segmento y [`ErrorHistoriaGenesis::CompromisoInesperado`] si el
    /// compromiso observado no es el congelado.
    pub fn construir() -> Result<Self, ErrorHistoriaGenesis> {
        let historia = Self::construir_bruto()?;
        comprobar_compromiso(historia.segment_commitment())?;
        Ok(historia)
    }

    /// Construye la historia sin cotejar el compromiso congelado.
    ///
    /// Es la receta de D-P12 sin la comprobación final. Existe para que el test V7 pueda **recalcular**
    /// el compromiso desde cero dos veces y compararlo, y para que `construir` no derive el esperado
    /// del observado.
    ///
    /// # Errores
    /// Las mismas que [`HistoriaGenesis::construir`] salvo
    /// [`ErrorHistoriaGenesis::CompromisoInesperado`].
    pub fn construir_bruto() -> Result<Self, ErrorHistoriaGenesis> {
        let escala = NonZeroUsize::new(
            usize::try_from(Record::NUM_S_BUCKETS.next_power_of_two().ilog2())
                .map_err(|_| ErrorHistoriaGenesis::EscalaErasureCoding)?,
        )
        .ok_or(ErrorHistoriaGenesis::EscalaErasureCoding)?;
        let erasure_coding =
            ErasureCoding::new(escala).map_err(ErrorHistoriaGenesis::ErasureCoding)?;
        let kzg = Kzg::new();

        let (cabecera, coinbase) =
            construir_genesis(GENESIS_DEV).map_err(ErrorHistoriaGenesis::Genesis)?;
        let mut bytes = Vec::new();
        cuerpo_a_bytes(&mut bytes, &cabecera, core::slice::from_ref(&coinbase), &[]);

        // Cola de relleno determinista (D-P12): `ChaCha8Rng` sembrado con `block_hash(génesis)`.
        let cuerpo = bytes.len();
        let segmento = RecordedHistorySegment::SIZE;
        bytes.resize(segmento, 0);
        let cola = bytes
            .get_mut(cuerpo..)
            .ok_or(ErrorHistoriaGenesis::RellenoInvalido { cuerpo, segmento })?;
        let mut rng = ChaCha8Rng::from_seed(*cabecera.block_hash().as_bytes());
        rng.fill(cola);

        let mut archiver = Archiver::new(kzg.clone(), erasure_coding.clone());
        let salida = archiver.add_block(bytes, BlockObjectMapping::default(), false);
        let historial = salida
            .archived_segments
            .into_iter()
            .next()
            .ok_or(ErrorHistoriaGenesis::SinSegmentoArchivado)?;

        let protocolo = protocolo_dev::parametros()?;

        Ok(Self {
            historial,
            kzg,
            erasure_coding,
            protocolo,
        })
    }

    /// Segmento archivado que produjo el `Archiver` real (el segmento 0).
    #[must_use]
    pub fn historial(&self) -> &NewArchivedSegment {
        &self.historial
    }

    /// Parámetros KZG, los mismos con los que se archivó el segmento.
    #[must_use]
    pub fn kzg(&self) -> &Kzg {
        &self.kzg
    }

    /// Erasure coding, el mismo con el que se archivó el segmento.
    #[must_use]
    pub fn erasure_coding(&self) -> &ErasureCoding {
        &self.erasure_coding
    }

    /// Compromiso de segmento tomado de la cabecera archivada.
    ///
    /// Es una medición de la historia génesis dev, no un compromiso de génesis de red.
    #[must_use]
    pub fn segment_commitment(&self) -> SegmentCommitment {
        self.historial.segment_header.segment_commitment()
    }

    /// Protocolo dev, por copia.
    #[must_use]
    pub fn protocolo(&self) -> FarmerProtocolInfo {
        self.protocolo
    }

    /// Tamaño de historia del protocolo dev, por copia.
    #[must_use]
    pub fn history_size(&self) -> HistorySize {
        self.protocolo.history_size
    }

    /// Contexto de pieza coherente con el segmento archivado y el protocolo dev.
    ///
    /// Construye **todos** los campos a partir del segmento y del mismo [`FarmerProtocolInfo`], con
    /// `sector_expiration_check_segment_commitment: None`. Este contexto vale para el paso 5 de
    /// `C-POT-08` cuando el resto del lote (slot, salida y rango) ya viene validado; no valida una
    /// cabecera por sí mismo.
    #[must_use]
    pub fn params_pieza(&self) -> PieceCheckParams {
        PieceCheckParams {
            max_pieces_in_sector: self.protocolo.max_pieces_in_sector,
            segment_commitment: self.segment_commitment(),
            recent_segments: self.protocolo.recent_segments,
            recent_history_fraction: self.protocolo.recent_history_fraction,
            min_sector_lifetime: self.protocolo.min_sector_lifetime,
            current_history_size: self.protocolo.history_size,
            sector_expiration_check_segment_commitment: None,
        }
    }
}

/// Coteja un compromiso observado contra el congelado de la historia génesis dev.
///
/// Se aísla para poder probar el rechazo con un [`SegmentCommitment`] mutado sin volver a archivar.
/// No deriva el esperado del observado ni acepta el valor nuevo: ante divergencia devuelve
/// [`ErrorHistoriaGenesis::CompromisoInesperado`] con ambos valores.
///
/// # Errores
/// [`ErrorHistoriaGenesis::CompromisoInesperado`] si `observado` no es el congelado.
pub fn comprobar_compromiso(observado: SegmentCommitment) -> Result<(), ErrorHistoriaGenesis> {
    let esperado = SegmentCommitment::from(COMPROMISO_HISTORIA_GENESIS_DEV);
    if observado == esperado {
        Ok(())
    } else {
        Err(ErrorHistoriaGenesis::CompromisoInesperado {
            esperado,
            observado,
        })
    }
}
