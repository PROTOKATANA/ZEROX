//! Pruebas de contrato de la historia archivada común dev (incremento D2/A3).
//!
//! # Qué prueba y qué no
//!
//! Comprueba que [`HistoriaDagDev`] es una **fuente única** coherente:
//!
//! - el protocolo del objeto coincide campo a campo con los literales de **desarrollo** esperados;
//! - el compromiso se lee de la cabecera archivada y `params_pieza()` lo reproduce;
//! - cada campo de `PieceCheckParams` sale del protocolo esperado, no de una comparación de la
//!   función consigo misma;
//! - el segmento archivado es el primero y contiene todas sus piezas reales;
//! - un **segundo productor** con otra clave e índice plotea, reabre y audita contra la misma
//!   historia sin duplicarla.
//!
//! **No** cierra D2: no hay cabecera, ni snapshot causal, ni selección de padres, ni firma, ni
//! publicación, y no se afirma una red de tres nodos. La prueba del segundo productor solo demuestra
//! que la API sirve a otro productor; la verificación PoAS con este contexto corresponde al paso 5
//! de `C-POT-08`, ya cubierto por D1/D2.
//!
//! La historia se construye **una sola vez por proceso** con `OnceLock`: las dos pruebas comparten
//! el mismo archivo archivado y no se duplica el archivo de ~130 MB.

#![cfg(feature = "farmer")]
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    reason = "instrumento de test: un fallo del fixture debe producir panic; sin índices sobre datos"
)]

use std::fs;
use std::num::NonZeroU64;
use std::path::PathBuf;
use std::sync::OnceLock;
use std::sync::atomic::{AtomicU64, Ordering};

use subspace_core_primitives::PublicKey;
use subspace_core_primitives::sectors::SectorIndex;
use subspace_core_primitives::segments::{
    ArchivedHistorySegment, HistorySize, SegmentCommitment, SegmentIndex,
};
use subspace_farmer_components::FarmerProtocolInfo;
use zx_node::farmer::{ParcelaDisco, plotear_sector_en_disco};
use zx_node::historia_dag_dev::HistoriaDagDev;

/// Piezas del sector del segundo productor; mismo valor de desarrollo que D1.
const PIEZAS: u16 = 2;

/// Índice del segundo productor, **distinto** del `2` del fixture D1.
const INDICE_SEGUNDO: SectorIndex = 9;

/// Rango elegido **de test** para que los ganadores sean frecuentes. No es un parámetro de red.
const RANGO_PRUEBA: u64 = u64::MAX;

static HISTORIA: OnceLock<HistoriaDagDev> = OnceLock::new();

/// Historia archivada dev compartida por las pruebas de este proceso.
fn historia() -> &'static HistoriaDagDev {
    HISTORIA.get_or_init(|| HistoriaDagDev::construir().expect("la historia dev debe construirse"))
}

/// Protocolo de **desarrollo** esperado, escrito como literales independientes del objeto bajo
/// prueba. No se recalcula desde [`HistoriaDagDev`].
fn protocolo_esperado() -> FarmerProtocolInfo {
    FarmerProtocolInfo {
        history_size: tamano(1),
        max_pieces_in_sector: PIEZAS,
        recent_segments: tamano(5),
        recent_history_fraction: (tamano(1), tamano(10)),
        min_sector_lifetime: tamano(4),
    }
}

fn tamano(segmentos: u64) -> HistorySize {
    HistorySize::from(NonZeroU64::new(segmentos).expect("los literales dev no son cero"))
}

struct DirTemporal {
    ruta: PathBuf,
}

impl DirTemporal {
    fn nuevo(nombre: &str) -> Self {
        static CONTADOR: AtomicU64 = AtomicU64::new(0);
        let n = CONTADOR.fetch_add(1, Ordering::Relaxed);
        let base = std::env::temp_dir().join(format!(
            "zx-historia-{}-{}-{}",
            std::process::id(),
            nombre,
            n
        ));
        let _ = fs::remove_dir_all(&base);
        fs::create_dir_all(&base).expect("crear directorio temporal");
        Self { ruta: base }
    }

    fn unir(&self, hijo: &str) -> PathBuf {
        self.ruta.join(hijo)
    }
}

impl Drop for DirTemporal {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.ruta);
    }
}

/// Contrato de extracción: el compromiso y el contexto de pieza salen de la historia archivada.
#[test]
fn el_compromiso_y_el_contexto_de_pieza_salen_de_la_historia_dev() {
    let historia = historia();
    let esperado = protocolo_esperado();

    // El protocolo del objeto coincide campo a campo con los literales dev, no con una copia de sí
    // mismo.
    let protocolo = historia.protocolo();
    assert_eq!(protocolo.history_size, esperado.history_size);
    assert_eq!(
        protocolo.max_pieces_in_sector,
        esperado.max_pieces_in_sector
    );
    assert_eq!(protocolo.recent_segments, esperado.recent_segments);
    assert_eq!(
        protocolo.recent_history_fraction,
        esperado.recent_history_fraction
    );
    assert_eq!(protocolo.min_sector_lifetime, esperado.min_sector_lifetime);

    // El compromiso se lee de la cabecera archivada; el contexto debe reproducir ese mismo valor.
    let desde_cabecera = historia.historial().segment_header.segment_commitment();
    let params = historia.params_pieza();
    assert_eq!(params.segment_commitment, desde_cabecera);

    // Cada campo de `PieceCheckParams` contra el protocolo esperado y el valor dev.
    assert_eq!(params.max_pieces_in_sector, esperado.max_pieces_in_sector);
    assert_eq!(params.recent_segments, esperado.recent_segments);
    assert_eq!(
        params.recent_history_fraction,
        esperado.recent_history_fraction
    );
    assert_eq!(params.min_sector_lifetime, esperado.min_sector_lifetime);
    assert_eq!(params.current_history_size, esperado.history_size);
    assert_eq!(params.sector_expiration_check_segment_commitment, None);

    // Índice de segmento y piezas reales: el primer segmento archivado con todas sus piezas.
    let historial = historia.historial();
    assert_eq!(
        historial.segment_header.segment_index(),
        SegmentIndex::ZERO,
        "la historia dev arranca en el segmento 0"
    );
    assert_eq!(
        historial.pieces.pieces().count(),
        ArchivedHistorySegment::NUM_PIECES,
        "el segmento archivado debe contener todas sus piezas"
    );
    assert_ne!(
        params.segment_commitment,
        SegmentCommitment::default(),
        "un segmento con piezas reales no puede tener el compromiso por defecto"
    );

    // El compromiso se imprime **solo** con `--nocapture` para que el líder lo mida; en esta fase
    // no se congela como literal.
    eprintln!(
        "[medición local, no consenso] compromiso de la historia dev (96 hex): {:?}",
        params.segment_commitment
    );
}

/// Un segundo productor, con otra clave e índice, usa la misma historia dev y audita su parcela.
#[test]
fn un_segundo_productor_plotea_y_audita_contra_la_misma_historia() {
    let historia = historia();
    let public_key = PublicKey::from([0xB7u8; 32]);
    assert!(
        public_key != PublicKey::default(),
        "la clave del segundo productor debe diferir de la del fixture D1"
    );

    let dir = DirTemporal::nuevo("segundo-productor");
    let ruta = dir.unir("sector.plot");
    plotear_sector_en_disco(
        &ruta,
        &public_key,
        INDICE_SEGUNDO,
        PIEZAS,
        historia.historial(),
        historia.protocolo(),
        historia.kzg(),
        historia.erasure_coding(),
    )
    .expect("el segundo productor debe plotear contra la misma historia dev");

    // Reabre el par y comprueba que la parcela pertenece al segundo productor.
    let parcela =
        ParcelaDisco::abrir(&ruta, &public_key).expect("reabrir la parcela del segundo productor");
    assert_eq!(parcela.sector_index(), INDICE_SEGUNDO);
    assert_eq!(parcela.pieces_in_sector(), PIEZAS);
    assert_eq!(
        parcela.metadata().history_size,
        historia.protocolo().history_size,
        "la historia de la parcela debe ser la de la fuente compartida"
    );

    // Audita un slot y exige que el resumen pertenezca al sector del segundo productor.
    let salida = [21u8; 16];
    let resumen = parcela
        .auditar_slot(salida, 0, RANGO_PRUEBA)
        .expect("auditar el slot del segundo productor");
    assert_eq!(
        resumen.len(),
        1,
        "un solo sector debe responder a la auditoría"
    );
    for fila in &resumen {
        assert_eq!(fila.sector_index, INDICE_SEGUNDO);
    }

    // Barrido de test acotado: la auditoría responde para varios slots sin depender de D1.
    let mut con_candidatos = 0usize;
    for slot in 0u64..16 {
        let resumen = parcela
            .auditar_slot(salida, slot, RANGO_PRUEBA)
            .expect("auditar el barrido del segundo productor");
        let total: usize = resumen.iter().map(|fila| fila.num_candidatos).sum();
        for fila in &resumen {
            assert_eq!(fila.sector_index, INDICE_SEGUNDO);
        }
        if total > 0 {
            con_candidatos += 1;
        }
    }

    eprintln!(
        "[medición local, no consenso] segundo productor: sector {INDICE_SEGUNDO}, clave \
         {public_key:?}, slots 0..16 con candidatos {con_candidatos}; historia compartida sin \
         duplicarla"
    );
}
