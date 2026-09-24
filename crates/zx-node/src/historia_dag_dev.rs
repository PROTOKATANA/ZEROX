//! Historia archivada común de **desarrollo** y contexto de pieza dev (incremento D2/A3).
//!
//! # Qué es y qué no es
//!
//! [`HistoriaDagDev`] archiva **una vez** un `RecordedHistorySegment` determinista con el
//! `Archiver` real del clon fijado (`PDF/autonomys-subspace` @ `f8842d0`) y expone, de forma
//! inmutable:
//!
//! - el segmento archivado [`NewArchivedSegment`] que produjo esa archivación;
//! - el [`Kzg`] y el [`ErasureCoding`] con los que se archivó;
//! - el [`FarmerProtocolInfo`] de **fixture local** que describe ese archivo;
//! - el contexto de pieza [`PieceCheckParams`] coherente con el segmento y con ese protocolo.
//!
//! Es la **fuente única** que productor, auditor y verificador pueden compartir para no reconstruir
//! cada uno su propia historia. Su receta reproduce, línea por línea, el fixture que vivía en
//! `tests/farmer_disco.rs`: `Kzg::new()`, `ErasureCoding` con
//! `Record::NUM_S_BUCKETS.next_power_of_two().ilog2()`, un `RecordedHistorySegment::new_boxed()`
//! llenado por el mismo splitmix64 con semilla `0x9E37_79B9_7F4A_7C15`, `add_block(.., .., true)` y
//! el primer `NewArchivedSegment` del resultado. No se reinterpreta el contenido ni se sustituye el
//! `Archiver` por un `PieceGetter` de bytes arbitrarios.
//!
//! **No acredita validez.** No hay ninguna función que declare válida una cabecera ni un bloque.
//! `params_pieza` devuelve un contexto de pieza **coherente con esta historia dev**, pero el cableado
//! a A3 (snapshot causal del pasado, flujo, rango, cabecera) sigue pendiente; este objeto no admite
//! bloques ni cierra D2.
//!
//! # Los números son del fixture local, no de red
//!
//! [`FarmerProtocolInfo`] se fija con `history_size = 1`, `max_pieces_in_sector = 2`,
//! `recent_segments = 5`, `recent_history_fraction = (1, 10)` y `min_sector_lifetime = 4`, los
//! mismos valores de desarrollo que usaba `farmer_disco.rs` y cuya fuente es el test upstream
//! `subspace-farmer-components/tests/plot_read_roundtrip.rs`. **No son parámetros de red** ni un
//! compromiso de génesis: el compromiso que expone [`HistoriaDagDev::segment_commitment`] es el
//! **compromiso congelado del fixture dev** (`COMPROMISO_DEV`), una medición reproducible de esta
//! receta. No es un compromiso de mainnet/testnet; [`HistoriaDagDev::construir`] lo coteja solo para
//! detectar divergencia **local** del archivo determinista, no para acreditar disponibilidad de
//! historia en red ni validar cabeceras.
//!
//! El archivo no genera historia de red: archiva ~130 MB de entrada determinista y no demuestra
//! disponibilidad de historia en red.
//!
//! # Inmutabilidad de la fuente
//!
//! Los getters exponen el segmento, el KZG, el erasure coding y el protocolo **tal como se
//! archivaron**, y `params_pieza` los deriva de ellos. No existe constructor alterno, no se acepta
//! un compromiso, una historia ni unos parámetros suministrados por un candidato o un usuario. Por
//! eso la identidad del contexto no puede venir del bloque que se intenta validar.

use std::num::{NonZeroU64, NonZeroUsize};

use subspace_archiving::archiver::{Archiver, NewArchivedSegment};
use subspace_core_primitives::pieces::Record;
use subspace_core_primitives::segments::{HistorySize, RecordedHistorySegment, SegmentCommitment};
use subspace_erasure_coding::ErasureCoding;
use subspace_farmer_components::FarmerProtocolInfo;
use subspace_kzg::Kzg;
use subspace_verification::PieceCheckParams;
use thiserror::Error;

/// Piezas por sector del fixture local. Valor de **desarrollo**, no de red.
const PIEZAS_POR_SECTOR_DEV: u16 = 2;

/// `history_size` del fixture local, en segmentos. Valor de **desarrollo**, no de red.
const TAMANO_HISTORIA_DEV: u64 = 1;

/// `recent_segments` del fixture local, en segmentos. Valor de **desarrollo**, no de red.
const SEGMENTOS_RECIENTES_DEV: u64 = 5;

/// Divisor de `recent_history_fraction` del fixture local. Valor de **desarrollo**, no de red.
const FRACCION_RECIENTE_DIVISOR_DEV: u64 = 1;

/// Multiplicador de `recent_history_fraction` del fixture local. Valor de **desarrollo**, no de red.
const FRACCION_RECIENTE_MULTIPLICADOR_DEV: u64 = 10;

/// `min_sector_lifetime` del fixture local, en segmentos. Valor de **desarrollo**, no de red.
const VIDA_MINIMA_SECTOR_DEV: u64 = 4;

/// Semilla del splitmix64 que llena la entrada determinista del fixture local.
///
/// Es la misma semilla que usaba `tests/farmer_disco.rs`; cambiarla cambiaría el compromiso del
/// segmento y no es una decisión de red.
const SEMILLA_SPLITMIX_DEV: u64 = 0x9E37_79B9_7F4A_7C15;

/// Compromiso de segmento **congelado del fixture dev**, en bytes.
///
/// Es el valor medido por dos procesos independientes sobre la receta de este módulo (`Kzg::new()`,
/// el erasure coding del fixture, un `RecordedHistorySegment` llenado por splitmix64 con
/// [`SEMILLA_SPLITMIX_DEV`] y el primer `NewArchivedSegment`). Se congela para detectar divergencia
/// **local** del archivo determinista: **no** es un compromiso de génesis ni un parámetro de
/// mainnet/testnet, y su cotejo no acredita disponibilidad de historia en red ni valida cabeceras.
const COMPROMISO_DEV: [u8; 48] = [
    0x97, 0xa1, 0xf2, 0x0f, 0x77, 0x05, 0x1b, 0x88, 0xd6, 0x0a, 0x2f, 0x54, 0x38, 0x41, 0xdc, 0x29,
    0x34, 0xa2, 0xe6, 0x07, 0x9c, 0x3b, 0xe1, 0xc3, 0x1a, 0x68, 0x7f, 0x43, 0x01, 0x5f, 0x54, 0x75,
    0x94, 0xe8, 0xff, 0x9a, 0x62, 0x75, 0x35, 0x15, 0xf9, 0x43, 0xdc, 0x1c, 0x3f, 0x96, 0xdf, 0x96,
];

/// Error tipado de la construcción de la historia archivada de desarrollo.
///
/// Separa el fallo al instanciar el erasure coding, un tamaño de historia no representable como
/// `NonZeroU64` y la ausencia de segmento archivado. Ninguno se convierte en un objeto a medias:
/// [`HistoriaDagDev::construir`] solo devuelve `Ok` con el segmento ya archivado.
#[derive(Debug, Error)]
pub enum ErrorHistoriaDagDev {
    /// La escala del erasure coding del fixture no cabe en `usize` o es cero.
    #[error("escala de erasure coding inválida para el fixture dev")]
    EscalaErasureCoding,
    /// `ErasureCoding::new` rechazó la escala calculada.
    ///
    /// El upstream devuelve `String`, de tipado pobre; se conserva textualmente sin fabricar éxito.
    #[error("el erasure coding del fixture dev no se pudo construir: {0}")]
    ErasureCoding(String),
    /// Un tamaño de historia del fixture sería cero y no es representable como `HistorySize`.
    #[error("tamaño de historia dev cero para {segmentos} segmentos")]
    TamanoHistoriaCero {
        /// Tamaño de historia pedido, en segmentos.
        segmentos: u64,
    },
    /// El bloque determinista no produjo ningún segmento archivado.
    #[error("el archivo determinista dev no produjo ningún segmento archivado")]
    SinSegmentoArchivado,
    /// El segmento archivado no reprodujo el compromiso congelado del fixture dev.
    ///
    /// Lleva ambos valores para que el fallo sea diagnosticable; el esperado no se deriva de la
    /// ejecución y el observado no se acepta: [`HistoriaDagDev::construir`] no crea el objeto.
    #[error(
        "compromiso de segmento dev inesperado: esperado {esperado:?}, observado {observado:?}"
    )]
    CompromisoInesperado {
        /// Compromiso congelado del fixture dev.
        esperado: SegmentCommitment,
        /// Compromiso que produjo esta ejecución del archivo determinista.
        observado: SegmentCommitment,
    },
}

/// Historia archivada común de desarrollo, inmutable una vez construida.
///
/// Se crea con [`HistoriaDagDev::construir`] y solo se lee por sus getters. Los campos son privados
/// a propósito: no se puede construir una instancia con un compromiso, una historia o un protocolo
/// traídos de fuera.
#[derive(Debug)]
pub struct HistoriaDagDev {
    historial: NewArchivedSegment,
    kzg: Kzg,
    erasure_coding: ErasureCoding,
    protocolo: FarmerProtocolInfo,
}

impl HistoriaDagDev {
    /// Construye la historia archivada de desarrollo.
    ///
    /// Reproduce la receta del fixture D1: instancia `Kzg` y `ErasureCoding`, archiva un
    /// `RecordedHistorySegment` llenado por splitmix64 con la semilla [`SEMILLA_SPLITMIX_DEV`] y
    /// toma el primer `NewArchivedSegment`. Coteja que su compromiso coincida con el congelado
    /// `COMPROMISO_DEV`. No usa `unwrap` ni `expect`: si el erasure coding falla, no sale segmento o
    /// el compromiso diverge, devuelve [`ErrorHistoriaDagDev`] sin construir el objeto.
    ///
    /// # Errores
    ///
    /// [`ErrorHistoriaDagDev::EscalaErasureCoding`] o [`ErrorHistoriaDagDev::ErasureCoding`] si el
    /// erasure coding no se puede instanciar, [`ErrorHistoriaDagDev::TamanoHistoriaCero`] si algún
    /// tamaño del protocolo dev fuera cero, [`ErrorHistoriaDagDev::SinSegmentoArchivado`] si el
    /// archiver no produjo ningún segmento y [`ErrorHistoriaDagDev::CompromisoInesperado`] si el
    /// compromiso observado no es el congelado del fixture.
    pub fn construir() -> Result<Self, ErrorHistoriaDagDev> {
        let escala = NonZeroUsize::new(
            usize::try_from(Record::NUM_S_BUCKETS.next_power_of_two().ilog2())
                .map_err(|_| ErrorHistoriaDagDev::EscalaErasureCoding)?,
        )
        .ok_or(ErrorHistoriaDagDev::EscalaErasureCoding)?;
        let erasure_coding =
            ErasureCoding::new(escala).map_err(ErrorHistoriaDagDev::ErasureCoding)?;
        let kzg = Kzg::new();

        let mut archiver = Archiver::new(kzg.clone(), erasure_coding.clone());
        let mut entrada = RecordedHistorySegment::new_boxed();
        llenar_determinista(AsMut::<[u8]>::as_mut(entrada.as_mut()));
        let salida = archiver.add_block(
            AsRef::<[u8]>::as_ref(entrada.as_ref()).to_vec(),
            Default::default(),
            true,
        );
        let historial = salida
            .archived_segments
            .into_iter()
            .next()
            .ok_or(ErrorHistoriaDagDev::SinSegmentoArchivado)?;

        // Antes de devolver el objeto: el compromiso del archivo determinista debe ser el congelado.
        comprobar_compromiso(historial.segment_header.segment_commitment())?;

        let protocolo = FarmerProtocolInfo {
            history_size: a_tamano_historia(TAMANO_HISTORIA_DEV)?,
            max_pieces_in_sector: PIEZAS_POR_SECTOR_DEV,
            recent_segments: a_tamano_historia(SEGMENTOS_RECIENTES_DEV)?,
            recent_history_fraction: (
                a_tamano_historia(FRACCION_RECIENTE_DIVISOR_DEV)?,
                a_tamano_historia(FRACCION_RECIENTE_MULTIPLICADOR_DEV)?,
            ),
            min_sector_lifetime: a_tamano_historia(VIDA_MINIMA_SECTOR_DEV)?,
        };

        Ok(Self {
            historial,
            kzg,
            erasure_coding,
            protocolo,
        })
    }

    /// Segmento archivado que produjo el `Archiver` real del fixture.
    #[must_use]
    pub fn historial(&self) -> &NewArchivedSegment {
        &self.historial
    }

    /// Parámetros KZG del fixture, los mismos con los que se archivó el segmento.
    #[must_use]
    pub fn kzg(&self) -> &Kzg {
        &self.kzg
    }

    /// Erasure coding del fixture, el mismo con el que se archivó el segmento.
    #[must_use]
    pub fn erasure_coding(&self) -> &ErasureCoding {
        &self.erasure_coding
    }

    /// Compromiso de segmento tomado de la cabecera archivada.
    ///
    /// Es una medición del fixture dev, no un compromiso de génesis ni de red.
    #[must_use]
    pub fn segment_commitment(&self) -> SegmentCommitment {
        self.historial.segment_header.segment_commitment()
    }

    /// Protocolo del fixture local, por copia.
    #[must_use]
    pub fn protocolo(&self) -> FarmerProtocolInfo {
        self.protocolo
    }

    /// Contexto de pieza coherente con el segmento archivado y el protocolo del fixture.
    ///
    /// Construye **todos** los campos a partir del segmento y del mismo [`FarmerProtocolInfo`],
    /// con `sector_expiration_check_segment_commitment: None`, igual que el antiguo
    /// `params_pieza_fixture` de `tests/farmer_disco.rs`. Este contexto vale para el paso 5 de
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

/// Convierte un número de segmentos a [`HistorySize`] sin aceptar el cero.
fn a_tamano_historia(segmentos: u64) -> Result<HistorySize, ErrorHistoriaDagDev> {
    NonZeroU64::new(segmentos)
        .map(HistorySize::new)
        .ok_or(ErrorHistoriaDagDev::TamanoHistoriaCero { segmentos })
}

/// Coteja un compromiso observado contra el congelado del fixture dev.
///
/// Se aísla para poder probar el rechazo con un [`SegmentCommitment`] mutado sin volver a archivar
/// ~130 MB. No deriva el esperado del observado ni acepta el valor nuevo: ante divergencia devuelve
/// [`ErrorHistoriaDagDev::CompromisoInesperado`] con ambos valores.
fn comprobar_compromiso(observado: SegmentCommitment) -> Result<(), ErrorHistoriaDagDev> {
    let esperado = SegmentCommitment::from(COMPROMISO_DEV);
    if observado == esperado {
        Ok(())
    } else {
        Err(ErrorHistoriaDagDev::CompromisoInesperado {
            esperado,
            observado,
        })
    }
}

/// Genera ~130 MB reproducibles sin depender de `rand`: splitmix64 sobre el buffer.
///
/// Es el mismo generador y la misma semilla que usaba `tests/farmer_disco.rs`; se mueve aquí para
/// que exista una sola fuente y no para reinterpretar el contenido.
fn llenar_determinista(bytes: &mut [u8]) {
    let mut estado: u64 = SEMILLA_SPLITMIX_DEV;
    for trozo in bytes.chunks_mut(8) {
        estado = estado.wrapping_add(SEMILLA_SPLITMIX_DEV);
        let mut z = estado;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^= z >> 31;
        let palabra = z.to_le_bytes();
        for (destino, origen) in trozo.iter_mut().zip(palabra.iter()) {
            *destino = *origen;
        }
    }
}

#[cfg(test)]
mod tests {
    //! Pruebas unitarias del cotejo congelado del fixture dev.

    use super::{COMPROMISO_DEV, ErrorHistoriaDagDev, SegmentCommitment, comprobar_compromiso};

    /// El compromiso congelado del fixture pasa el cotejo.
    #[test]
    fn el_compromiso_congelado_pasa_el_cotejo() {
        let congelado = SegmentCommitment::from(COMPROMISO_DEV);
        assert!(comprobar_compromiso(congelado).is_ok());
    }

    /// Un byte cambiado devuelve exactamente [`ErrorHistoriaDagDev::CompromisoInesperado`].
    #[test]
    fn un_compromiso_con_un_byte_cambiado_devuelve_el_error_tipado() {
        let mut mutado = COMPROMISO_DEV;
        if let Some(byte) = mutado.first_mut() {
            *byte ^= 0x01;
        }
        let observado = SegmentCommitment::from(mutado);

        match comprobar_compromiso(observado) {
            Err(ErrorHistoriaDagDev::CompromisoInesperado {
                esperado,
                observado,
            }) => {
                assert_eq!(esperado, SegmentCommitment::from(COMPROMISO_DEV));
                assert_eq!(observado, SegmentCommitment::from(mutado));
                assert_ne!(esperado, observado);
            }
            otro => unreachable!("se esperaba CompromisoInesperado; se obtuvo {otro:?}"),
        }
    }
}
