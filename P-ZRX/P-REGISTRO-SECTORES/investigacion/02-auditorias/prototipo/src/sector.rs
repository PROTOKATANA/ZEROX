//! Plotter real (Autonomys `plot_sector`) y construcción del `Sector` comprometible.
//!
//! No se reimplementa PoS, KZG ni erasure coding: se llama a la API pública del clon fijado
//! `f8842d0` exactamente como el antiguo `farmer.rs` de ZEROX. La historia archivada se construye
//! con el `Archiver` real sobre un `RecordedHistorySegment` determinista (misma receta que
//! `historia_dag_dev.rs` de L01), y el ploteo usa `CpuRecordsEncoder::<ChiaTable>` con la ruta
//! **paralela** de generación de tablas.

use std::io::Write as _;
use std::num::{NonZeroU64, NonZeroUsize};
use std::path::Path;
use std::sync::atomic::AtomicBool;

use subspace_archiving::archiver::{Archiver, NewArchivedSegment};
use subspace_core_primitives::pieces::{PieceIndex, Record};
use subspace_core_primitives::pot::PotOutput;
use subspace_core_primitives::segments::{HistorySize, RecordedHistorySegment, SegmentCommitment};
use subspace_core_primitives::sectors::{SBucket, SectorId, SectorIndex};
use subspace_core_primitives::solutions::Solution;
use subspace_core_primitives::{PublicKey, ScalarBytes};
use subspace_erasure_coding::ErasureCoding;
use subspace_farmer_components::FarmerProtocolInfo;
use subspace_farmer_components::auditing::{AuditResult, audit_sector_sync};
use subspace_farmer_components::plotting::{
    CpuRecordsEncoder, PlotSectorOptions, PlottedSector, plot_sector,
};
use subspace_farmer_components::reading::ReadSectorRecordChunksMode;
use subspace_farmer_components::sector::{
    SectorContentsMap, SectorMetadataChecksummed, sector_record_chunks_size,
    sector_record_metadata_size, sector_size,
};
use subspace_kzg::Kzg;
use subspace_proof_of_space::Table as _;
use subspace_proof_of_space::TableGenerator as _;
use subspace_proof_of_space::chia::ChiaTable;
use subspace_verification::{PieceCheckParams, VerifySolutionParams, verify_solution};

use crate::merkle::Merkle;
use crate::r2::{
    Apertura, CamposPublicos, CompromisoR1, CompromisoR2, NUM_CHUNKS, compromiso_r1, compromiso_r2,
    digest_mapa, digest_meta, hoja,
};

/// Número de s-buckets por registro (`Record::NUM_S_BUCKETS = 2^16`).
pub const NUM_S_BUCKETS: u32 = 65_536;

/// Semilla del splitmix64 que llena la entrada determinista del fixture dev (idéntica a la de
/// `historia_dag_dev.rs` y a la del antiguo `farmer_disco.rs`).
pub const SEMILLA_SPLITMIX_DEV: u64 = 0x9E37_79B9_7F4A_7C15;

/// Parámetros de plot de **desarrollo** (no de ZEROX ni de red): los del `farmer_disco.rs` antiguo.
#[derive(Debug, Clone, Copy)]
pub struct ParametrosPlot {
    /// Clave pública con la que se plotea.
    pub public_key: PublicKey,
    /// Índice de sector (el antiguo fixture usa 2, distinto de cero).
    pub sector_index: SectorIndex,
    /// Piezas del sector.
    pub pieces_in_sector: u16,
    /// `history_size` de desarrollo, en segmentos (`1`).
    pub history_size: u64,
    /// `recent_segments` de desarrollo (`5`).
    pub recent_segments: u64,
    /// Fracción reciente de desarrollo (`(1, 10)`).
    pub recent_history_fraction: (u64, u64),
    /// Vida mínima de sector de desarrollo (`4`).
    pub min_sector_lifetime: u64,
    /// Slot de alta (para R1). No es un dato de consenso.
    pub slot_alta: u64,
}

impl Default for ParametrosPlot {
    fn default() -> Self {
        Self {
            public_key: PublicKey::default(),
            sector_index: 2,
            pieces_in_sector: 2,
            history_size: 1,
            recent_segments: 5,
            recent_history_fraction: (1, 10),
            min_sector_lifetime: 4,
            slot_alta: 1_000,
        }
    }
}

impl ParametrosPlot {
    /// `FarmerProtocolInfo` de Autonomys derivado de los parámetros de desarrollo.
    ///
    /// `max_pieces_in_sector` se fija igual a `pieces_in_sector`: para medir varios tamaños (§6) el
    /// protocolo debe poder colocar todas las piezas. Los demás valores son los del fixture.
    #[must_use]
    pub fn protocolo(&self) -> FarmerProtocolInfo {
        FarmerProtocolInfo {
            history_size: hs(self.history_size),
            max_pieces_in_sector: self.pieces_in_sector,
            recent_segments: hs(self.recent_segments),
            recent_history_fraction: (
                hs(self.recent_history_fraction.0),
                hs(self.recent_history_fraction.1),
            ),
            min_sector_lifetime: hs(self.min_sector_lifetime),
        }
    }
}

/// `HistorySize` a partir de segmentos no nulos.
#[must_use]
pub fn hs(segmentos: u64) -> HistorySize {
    HistorySize::new(NonZeroU64::new(segmentos).expect("los parámetros dev no son cero"))
}

/// Historia archivada común de desarrollo más las instancias KZG y erasure coding del fixture.
///
/// Se construye una vez (~130 MiB de entrada determinista) y se reutiliza para todos los sectores.
pub struct Entorno {
    historial: NewArchivedSegment,
    kzg: Kzg,
    erasure_coding: ErasureCoding,
}

impl Entorno {
    /// Construye el entorno con la receta del fixture dev.
    ///
    /// # Errores
    ///
    /// Devuelve [`ErrorSector`] si el erasure coding no se puede instanciar o si el `Archiver` no
    /// produce ningún segmento archivado.
    pub fn construir_dev() -> Result<Self, ErrorSector> {
        let escala = NonZeroUsize::new(
            usize::try_from(Record::NUM_S_BUCKETS.next_power_of_two().ilog2())
                .map_err(|_| ErrorSector::ErasureCoding("escala no representable".into()))?,
        )
        .ok_or_else(|| ErrorSector::ErasureCoding("escala cero".into()))?;
        let erasure_coding = ErasureCoding::new(escala).map_err(ErrorSector::ErasureCoding)?;
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
            .ok_or(ErrorSector::SinSegmentoArchivado)?;

        Ok(Self {
            historial,
            kzg,
            erasure_coding,
        })
    }

    /// Compromiso del segmento archivado (dato del fixture, no parámetro de red).
    #[must_use]
    pub fn segment_commitment(&self) -> SegmentCommitment {
        self.historial.segment_header.segment_commitment()
    }

    /// Historia archivada local, que implementa `PieceGetter`. S02a la usa para regenerar
    /// registros asumiendo que la historia es **pública y local** (coste de red declarado fuera).
    #[must_use]
    pub fn historial(&self) -> &NewArchivedSegment {
        &self.historial
    }

    /// KZG del fixture.
    #[must_use]
    pub fn kzg(&self) -> &Kzg {
        &self.kzg
    }

    /// Erasure coding del fixture.
    #[must_use]
    pub fn erasure_coding(&self) -> &ErasureCoding {
        &self.erasure_coding
    }

    /// `PieceCheckParams` coherentes con los parámetros de plot y el segmento archivado.
    #[must_use]
    pub fn params_pieza(&self, p: &ParametrosPlot) -> PieceCheckParams {
        PieceCheckParams {
            max_pieces_in_sector: p.pieces_in_sector,
            segment_commitment: self.segment_commitment(),
            recent_segments: hs(p.recent_segments),
            recent_history_fraction: (
                hs(p.recent_history_fraction.0),
                hs(p.recent_history_fraction.1),
            ),
            min_sector_lifetime: hs(p.min_sector_lifetime),
            current_history_size: hs(p.history_size),
            sector_expiration_check_segment_commitment: None,
        }
    }

    /// Plotea un sector real y devuelve sus bytes crudos y su `PlottedSector`.
    ///
    /// Separado de [`Entorno::plotear`] para poder medir por separado el ploteo y la construcción
    /// del objeto comprometible (R2).
    ///
    /// # Errores
    ///
    /// Propaga el error del plotter; nunca devuelve bytes a medias.
    pub fn plotear_crudo(
        &self,
        p: &ParametrosPlot,
    ) -> Result<(Vec<u8>, PlottedSector), ErrorSector> {
        let protocolo = p.protocolo();
        let mut generador = ChiaTable::generator();
        let mut salida: Vec<u8> = Vec::new();
        let abortar = AtomicBool::new(false);
        let mutex_global = async_lock::Mutex::new(());
        let mut encoder = CpuRecordsEncoder::<ChiaTable>::new(
            std::slice::from_mut(&mut generador),
            &self.erasure_coding,
            &mutex_global,
        );

        let trazado = futures::executor::block_on(plot_sector(PlotSectorOptions {
            public_key: &p.public_key,
            sector_index: p.sector_index,
            piece_getter: &self.historial,
            farmer_protocol_info: protocolo,
            kzg: &self.kzg,
            erasure_coding: &self.erasure_coding,
            pieces_in_sector: p.pieces_in_sector,
            sector_output: &mut salida,
            downloading_semaphore: None,
            encoding_semaphore: None,
            records_encoder: &mut encoder,
            abort_early: &abortar,
        }))?;

        if trazado.sector_index != p.sector_index {
            return Err(ErrorSector::Coherencia(format!(
                "sector_index del ploteo {} != {}",
                trazado.sector_index, p.sector_index
            )));
        }

        Ok((salida, trazado))
    }

    /// Plotea un sector real y construye su objeto comprometible.
    ///
    /// # Errores
    ///
    /// Propaga el error del plotter o de la construcción del objeto; nunca devuelve un `Sector` a
    /// medias.
    pub fn plotear(&self, p: &ParametrosPlot) -> Result<Sector, ErrorSector> {
        let (salida, trazado) = self.plotear_crudo(p)?;
        Sector::construir(salida, trazado, p.public_key, p.slot_alta)
    }

    /// s-bucket auditado por el contexto para un `(salida, slot)`, tal como lo deriva el
    /// verificador real (no se toma de la solución).
    #[must_use]
    pub fn s_bucket_auditado(&self, sector: &Sector, salida: [u8; 16], slot: u64) -> u16 {
        let pot = PotOutput::from(salida);
        let global_challenge = pot.derive_global_randomness().derive_global_challenge(slot);
        let ssc = sector
            .sector_id
            .derive_sector_slot_challenge(&global_challenge);
        u16::from(ssc.s_bucket_audit_index())
    }

    /// Auditoría real de un sector para un slot y conversión de candidatos en soluciones.
    ///
    /// Usa `audit_sector_sync` y `SolutionCandidates::into_solutions` del clon. No fabrica
    /// candidatos: si no hay, devuelve un vector vacío.
    pub fn soluciones_slot(
        &self,
        sector: &Sector,
        salida: [u8; 16],
        slot: u64,
        rango: u64,
    ) -> Result<Vec<Solution<()>>, ErrorSector> {
        let pot = PotOutput::from(salida);
        let global_challenge = pot.derive_global_randomness().derive_global_challenge(slot);

        let Some(AuditResult {
            solution_candidates,
            ..
        }) = audit_sector_sync(
            &sector.public_key,
            &global_challenge,
            rango,
            sector.bytes.as_slice(),
            &sector.metadata,
        )?
        else {
            return Ok(Vec::new());
        };

        let generador = ChiaTable::generator();
        let soluciones = solution_candidates.into_solutions(
            &(),
            &self.kzg,
            &self.erasure_coding,
            ReadSectorRecordChunksMode::ConcurrentChunks,
            move |seed| generador.generate_parallel(seed),
        )?;

        let mut out = Vec::new();
        for solucion in soluciones {
            match solucion {
                Ok(s) => out.push(s),
                Err(e) => return Err(ErrorSector::Proving(e)),
            }
        }
        Ok(out)
    }

    /// Verifica una solución con el verificador PoAS **real** (`verify_solution::<ChiaTable,_>`),
    /// con los parámetros del test antiguo. Devuelve la distancia de solución.
    pub fn verificar_solucion(
        &self,
        solucion: &Solution<()>,
        p: &ParametrosPlot,
        salida: [u8; 16],
        slot: u64,
        rango: u64,
    ) -> Result<u64, ErrorSector> {
        let params = VerifySolutionParams {
            proof_of_time: PotOutput::from(salida),
            solution_range: rango,
            piece_check_params: Some(self.params_pieza(p)),
        };
        verify_solution::<ChiaTable, ()>(solucion, slot, &params, &self.kzg)
            .map_err(ErrorSector::Poas)
    }
}

/// Sector PoAS real más el objeto comprometible R2 y el árbol de chunks.
pub struct Sector {
    /// Bytes del archivo de sector tal cual los escribió el plotter.
    pub bytes: Vec<u8>,
    /// Clave pública del sector.
    pub public_key: PublicKey,
    /// Metadata checksummeada del plotter.
    pub metadata: SectorMetadataChecksummed,
    /// Identidad de sector derivada.
    pub sector_id: SectorId,
    /// Índices de pieza ploteados.
    pub piece_indexes: Vec<PieceIndex>,
    /// Mapa de contenidos decodificado (con su checksum verificado).
    pub mapa: SectorContentsMap,
    /// `H_d(TAG_MAPA, bytes del mapa)`.
    pub digest_mapa: [u8; 32],
    /// `H_d(TAG_META, bytes de metadatos)`.
    pub digest_meta: [u8; 32],
    /// Árbol Merkle de chunks.
    pub arbol: Merkle,
    /// Campos públicos comprometidos.
    pub campos: CamposPublicos,
    /// Slot de alta para R1.
    pub slot_alta: u64,
}

impl Sector {
    /// Construye el objeto comprometible a partir de los bytes del plotter, su metadata y la clave.
    ///
    /// # Errores
    ///
    /// Falla si el tamaño no es el de `sector_size(pieces)`, si el mapa no decodifica, o si la
    /// cardinalidad no cuadra. No hay camino que devuelva un objeto parcial.
    pub fn construir(
        bytes: Vec<u8>,
        plotted: PlottedSector,
        public_key: PublicKey,
        slot_alta: u64,
    ) -> Result<Self, ErrorSector> {
        let pieces = plotted.sector_metadata.pieces_in_sector;
        let mapa_size = SectorContentsMap::encoded_size(pieces);
        let chunks_size = sector_record_chunks_size(pieces);
        let meta_size = sector_record_metadata_size(pieces);
        let total = sector_size(pieces);
        if bytes.len() != total {
            return Err(ErrorSector::Coherencia(format!(
                "longitud de sector {} != {} (sector_size)",
                bytes.len(),
                total
            )));
        }

        let bytes_mapa = &bytes[..mapa_size];
        let mapa = SectorContentsMap::from_bytes(bytes_mapa, pieces)?;
        let bytes_meta = &bytes[mapa_size + chunks_size..mapa_size + chunks_size + meta_size];

        let d_mapa = digest_mapa(bytes_mapa);
        let d_meta = digest_meta(bytes_meta);

        // Hojas en orden físico: s-bucket ascendente y, dentro de cada uno,
        // `iter_s_bucket_records` (director: sector.rs:436-470).
        let mut hojas: Vec<[u8; 32]> = Vec::with_capacity(usize::from(pieces) * NUM_CHUNKS as usize);
        let mut loc = 0usize;
        for bucket in 0u32..NUM_S_BUCKETS {
            let s_bucket = SBucket::from(bucket as u16);
            for (piece_offset, codificado) in mapa
                .iter_s_bucket_records(s_bucket)
                .map_err(|e| ErrorSector::Coherencia(format!("iter_s_bucket_records: {e}")))?
            {
                let ini = mapa_size + loc * ScalarBytes::FULL_BYTES;
                let chunk: [u8; 32] = bytes[ini..ini + ScalarBytes::FULL_BYTES]
                    .try_into()
                    .map_err(|_| ErrorSector::Coherencia("chunk fuera de rango".into()))?;
                hojas.push(hoja(
                    bucket as u16,
                    piece_offset.into(),
                    u8::from(codificado),
                    &chunk,
                ));
                loc += 1;
            }
        }

        let n = u32::try_from(hojas.len())
            .map_err(|_| ErrorSector::Coherencia("n no cabe en u32".into()))?;
        if n != u32::from(pieces) * NUM_CHUNKS {
            return Err(ErrorSector::Coherencia(format!(
                "n = {n} != pieces·NUM_CHUNKS = {}",
                u32::from(pieces) * NUM_CHUNKS
            )));
        }

        let arbol = Merkle::nuevo(&hojas);
        let pk: [u8; 32] = public_key
            .as_ref()
            .try_into()
            .map_err(|_| ErrorSector::Coherencia("clave pública no mide 32 B".into()))?;
        let campos = CamposPublicos {
            cbid: crate::r2::CBID_PRUEBA,
            public_key: pk,
            sector_index: plotted.sector_metadata.sector_index,
            history_size: plotted.sector_metadata.history_size.get(),
            pieces_in_sector: pieces,
            n,
        };

        Ok(Self {
            bytes,
            public_key,
            metadata: plotted.sector_metadata.clone(),
            sector_id: plotted.sector_id,
            piece_indexes: plotted.piece_indexes,
            mapa,
            digest_mapa: d_mapa,
            digest_meta: d_meta,
            arbol,
            campos,
            slot_alta,
        })
    }

    /// R1 del alta (identidad y fecha; solo contabilidad).
    #[must_use]
    pub fn r1(&self) -> CompromisoR1 {
        compromiso_r1(
            &self.campos.public_key,
            self.campos.sector_index,
            self.campos.history_size,
            self.slot_alta,
        )
    }

    /// R2 del sector completo.
    #[must_use]
    pub fn r2(&self) -> CompromisoR2 {
        compromiso_r2(
            &self.campos,
            &self.digest_mapa,
            &self.digest_meta,
            &self.arbol.raiz(),
        )
    }

    /// Apertura de una solución ganadora frente a R2.
    ///
    /// # Errores
    ///
    /// Falla si `s_bucket` está fuera de rango, si el `(s_bucket, piece_offset)` no tiene chunk, o
    /// si ese chunk **no** está codificado (una solución ganadora siempre lo está, pero no se
    /// asume: se comprueba).
    pub fn apertura(&self, solucion: &Solution<()>, s_bucket: u16) -> Result<Apertura, ErrorSector> {
        if u32::from(s_bucket) >= NUM_S_BUCKETS {
            return Err(ErrorSector::Coherencia(format!(
                "s_bucket {s_bucket} fuera de rango"
            )));
        }
        let piece_offset: u16 = solucion.piece_offset.into();
        let offsets = self.metadata.s_bucket_offsets();
        let base = offsets[usize::from(s_bucket)];
        let mut idx: u32 = 0;
        let mut encontrado = false;
        for (offset, codificado) in self
            .mapa
            .iter_s_bucket_records(SBucket::from(s_bucket))
            .map_err(|e| ErrorSector::Coherencia(format!("iter_s_bucket_records: {e}")))?
        {
            if u16::from(offset) == piece_offset {
                if !codificado {
                    return Err(ErrorSector::Coherencia(
                        "el chunk de la solución no está codificado".into(),
                    ));
                }
                encontrado = true;
                break;
            }
            idx += 1;
        }
        if !encontrado {
            return Err(ErrorSector::Coherencia(format!(
                "no hay chunk en s_bucket {s_bucket} para piece_offset {piece_offset}"
            )));
        }
        let chunk_location = base
            .checked_add(idx)
            .ok_or_else(|| ErrorSector::Coherencia("chunk_location desborda u32".into()))?;
        let camino = self.arbol.camino(chunk_location as usize);

        Ok(Apertura {
            chunk_location,
            camino,
            codificado: 1,
            raiz_chunks: self.arbol.raiz(),
            digest_mapa: self.digest_mapa,
            digest_meta: self.digest_meta,
            s_bucket,
            piece_offset,
        })
    }

    /// Tamaño del mapa de contenidos, de la región de chunks y de la región de metadatos.
    #[must_use]
    pub fn tamanos_regiones(&self) -> (usize, usize, usize) {
        (
            SectorContentsMap::encoded_size(self.campos.pieces_in_sector),
            sector_record_chunks_size(self.campos.pieces_in_sector),
            sector_record_metadata_size(self.campos.pieces_in_sector),
        )
    }

    /// Escribe el volcado binario que consume el oráculo Julia. Formato en `ESPECIFICACION-BYTES.md`.
    ///
    /// # Errores
    ///
    /// E/S del archivo de volcado.
    pub fn escribir_volcado(&self, ruta: &Path) -> Result<(), ErrorSector> {
        let mut f = std::fs::File::create(ruta)?;
        f.write_all(b"ZZKS01D1")?;
        f.write_all(&1u32.to_le_bytes())?;
        f.write_all(&self.campos.cbid.to_le_bytes())?;
        f.write_all(&self.campos.public_key)?;
        f.write_all(&self.campos.sector_index.to_le_bytes())?;
        f.write_all(&self.campos.history_size.to_le_bytes())?;
        f.write_all(&self.campos.pieces_in_sector.to_le_bytes())?;
        let len = u64::try_from(self.bytes.len())
            .map_err(|_| ErrorSector::Coherencia("longitud no representable".into()))?;
        f.write_all(&len.to_le_bytes())?;
        f.write_all(&self.bytes)?;
        f.flush()?;
        Ok(())
    }
}

/// Error tipado del ploteo y de la construcción del objeto comprometible.
#[derive(Debug, thiserror::Error)]
pub enum ErrorSector {
    /// El erasure coding del fixture no se pudo construir.
    #[error("erasure coding: {0}")]
    ErasureCoding(String),
    /// El `Archiver` no produjo ningún segmento archivado.
    #[error("el archivo determinista no produjo segmento archivado")]
    SinSegmentoArchivado,
    /// El plotter falló.
    #[error("ploteo: {0}")]
    Plot(#[from] subspace_farmer_components::plotting::PlottingError),
    /// La auditoría falló.
    #[error("auditoría: {0}")]
    Auditoria(#[from] subspace_farmer_components::auditing::AuditingError),
    /// El mapa de contenidos no decodifica.
    #[error("mapa de contenidos: {0}")]
    Mapa(#[from] subspace_farmer_components::sector::SectorContentsMapFromBytesError),
    /// La conversión de candidatos a soluciones falló.
    #[error("conversión a soluciones: {0}")]
    Proving(#[from] subspace_farmer_components::proving::ProvingError),
    /// El verificador PoAS real rechazó la solución.
    #[error("verificación PoAS: {0}")]
    Poas(#[from] subspace_verification::Error),
    /// E/S del prototipo.
    #[error("E/S: {0}")]
    Eio(#[from] std::io::Error),
    /// Un invariante de forma o cardinalidad no se cumple.
    #[error("coherencia: {0}")]
    Coherencia(String),
    /// La regeneración de un chunk (tabla PoS + erasure coding) falló.
    #[error("regeneración: {0}")]
    Regeneracion(String),
}

/// Llena ~130 MiB reproducibles con splitmix64 (misma receta que el fixture dev).
pub fn llenar_determinista(bytes: &mut [u8]) {
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
