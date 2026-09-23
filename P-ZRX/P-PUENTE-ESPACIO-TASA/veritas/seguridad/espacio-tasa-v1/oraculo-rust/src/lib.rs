#![feature(generic_const_exprs)]
#![expect(
    incomplete_features,
    reason = "ab-proof-of-space usa generic_const_exprs; hay que nombrar Proofs<20>"
)]

//! Oraculo Rust del instrumento `espacio-tasa-v1`.
//!
//! **Contrato.** Todo lo que hay aqui llama a la API **publica** de Autonomys @ `f8842d0`
//! (`/home/katana/zeo/fuentes/subspace`). No se copia ni se reimplementa ninguna primitiva
//! criptografica: la tabla PoS la construye `ab_proof_of_space::chiapos::Tables`, el codigo de
//! borrado `subspace_erasure_coding::ErasureCoding`, el hash con clave
//! `subspace_core_primitives::hashes::blake3_hash_with_key` y la distancia circular
//! `subspace_core_primitives::solutions::bidirectional_distance`.
//!
//! Lo unico que este crate **recompone** es la *secuencia* de operaciones que el granjero ejecuta
//! al plotear (`record_encoding`, `subspace-farmer-components/src/plotting.rs:615-680`) y al
//! auditar (`auditing.rs:198-271`). Esa recomposicion es la **referencia independiente** que el
//! encargo §4 pide, y se contrasta contra la via upstream (`is_within_solution_range`) en cada
//! muestra: si las dos discrepan, el programa **falla**, no promedia.

use ab_proof_of_space::chiapos::{Proofs, Tables, TablesCache};
use rayon::prelude::*;
use core::num::NonZeroU64;
use std::num::NonZeroUsize;
use subspace_core_primitives::hashes::{Blake3Hash, blake3_hash, blake3_hash_with_key};
use subspace_core_primitives::pieces::{PieceOffset, Record};
use subspace_core_primitives::pos::{PosProof, PosSeed};
use subspace_core_primitives::sectors::{SBucket, SectorId, SectorSlotChallenge};
use subspace_core_primitives::segments::HistorySize;
use subspace_core_primitives::solutions::{SolutionRange, bidirectional_distance};
use subspace_kzg::Scalar;
use subspace_verification::is_within_solution_range;

/// `K` de la prueba de espacio (`subspace-core-primitives/src/pos.rs:103`).
pub const K: u8 = 20;
/// Chunks (escalares) por registro. `pieces.rs:561`.
pub const NUM_CHUNKS: usize = Record::NUM_CHUNKS;
/// s-buckets por registro/sector. `pieces.rs:565`.
pub const NUM_S_BUCKETS: usize = Record::NUM_S_BUCKETS;
/// Bytes del mapa de presencia de pruebas: `NUM_S_BUCKETS / 8`.
pub const BITMAP_BYTES: usize = NUM_S_BUCKETS / 8;
/// Bytes por chunk (escalar). `ScalarBytes::FULL_BYTES`.
pub const CHUNK_BYTES: usize = 32;
/// Escala del codigo de borrado: `2^16` shards = `2^15` fuente + `2^15` paridad.
pub const ERASURE_SCALE: usize = 16;

const _: () = {
    assert!(NUM_S_BUCKETS == 1 << 16);
    assert!(NUM_CHUNKS == 1 << 15);
    assert!(BITMAP_BYTES == 8192);
    assert!(Record::SIZE == NUM_CHUNKS * CHUNK_BYTES);
    // `sector_size` con los metadatos reales (ver `PROCEDENCIA.md`).
    assert!(ERASURE_SCALE == 16);
};

// ---------------------------------------------------------------------------------------------
// Derivaciones deterministas (el reto real lo producira el PoT; aqui es un vector reproducible)
// ---------------------------------------------------------------------------------------------

/// Semilla determinista y distinta por identidad candidata.
#[inline]
pub fn semilla_clave(i: u64) -> Blake3Hash {
    let mut buf = [0_u8; 16];
    buf[..8].copy_from_slice(b"PUENTE01");
    buf[8..].copy_from_slice(&i.to_le_bytes());
    blake3_hash(&buf)
}

/// `HistorySize` usado en todas las muestras. Constante y declarado; no es una decision de red.
#[inline]
pub fn history_size_fija() -> HistorySize {
    HistorySize::from(NonZeroU64::new(1).expect("uno no es cero; qed"))
}

/// Camino de generacion de tablas PoS.
///
/// **Defecto de la fuente fijada, reproducido aqui.** `Tables::<K>::create_proofs` (la via
/// **serial**) aborta el proceso con `malloc(): corrupted top size` para ciertas semillas
/// derivadas de `(sector_id, piece_offset)`. Es el mismo defecto que `P-ZRX/P-INTENTO` documento
/// en su §13 como SIGSEGV reproducible para ciertas semillas, con la misma mitigacion: la via
/// **paralela** (`create_proofs_parallel`), que es ademas **la que usa el plotter honesto**
/// (`subspace-proof-of-space/src/chia_v2.rs:37-41`, `ChiaV2TableGenerator::generate_parallel`).
///
/// `PUENTE_TABLA=serial` fuerza la via serial, que solo sirve para reproducir el fallo en un
/// rango pequeno de piezas. Por defecto se usa la paralela.
#[inline]
pub fn usar_tabla_serial() -> bool {
    static MODO: std::sync::OnceLock<bool> = std::sync::OnceLock::new();
    *MODO.get_or_init(|| {
        std::env::var("PUENTE_TABLA")
            .map(|v| v == "serial")
            .unwrap_or(false)
    })
}

/// Camino declarado, para que quede escrito en los artefactos.
pub fn camino_tabla() -> &'static str {
    if usar_tabla_serial() {
        "serial"
    } else {
        "paralela"
    }
}

/// Genera la tabla PoS por el camino declarado.
#[inline]
fn tabla_pos(seed: PosSeed, cache: &TablesCache) -> Box<Proofs<K>> {
    if usar_tabla_serial() {
        Tables::<K>::create_proofs(seed.into(), cache)
    } else {
        Tables::<K>::create_proofs_parallel(seed.into(), cache)
    }
}

/// Identidad de sector determinista (via publica `SectorId::new`, `sectors.rs:61-67`).
#[inline]
pub fn sector_id_i(i: u64) -> SectorId {
    SectorId::new(semilla_clave(i), (i & 0xffff) as u16, history_size_fija())
}

/// Reto global sintetico por indice de slot.
///
/// **No es la derivacion real.** `C-POT-03` (derivar `reto` del slot) esta `pendiente`; el
/// instrumento usa un vector uniforme reproducible y lo declara como escenario experimental.
#[inline]
pub fn reto_i(i: u64) -> Blake3Hash {
    let mut buf = [0_u8; 16];
    buf[..8].copy_from_slice(b"RETOPUEN");
    buf[8..].copy_from_slice(&i.to_le_bytes());
    blake3_hash(&buf)
}

// ---------------------------------------------------------------------------------------------
// Pieza: mapa de presencia + chunks codificados, exactamente como al plotear
// ---------------------------------------------------------------------------------------------

/// Una pieza plotada: lo que el formato guarda de ella dentro de un sector.
///
/// - `bitmap`: `found_proofs` de `Proofs<20>`, campo **publico** de `ab-proof-of-space`.
/// - `rank`: prefijo de `popcount` por byte, para resolver `bucket -> indice denso` sin recorrer
///   el mapa entero (es el mismo `rank/select` que `proof_index_for_s_bucket`,
///   `shared/ab-proof-of-space/src/lib.rs:63-84`).
/// - `chunks`: array **denso** por bucket creciente, con `chunk = record_chunk XOR blake3(proof)`
///   (`subspace-farmer-components/src/plotting.rs:659-661`). Solo los buckets con prueba.
pub struct Pieza {
    /// Mapa de presencia de pruebas, un bit por s-bucket.
    pub bitmap: [u8; BITMAP_BYTES],
    /// `rank[b/8]` = numero de pruebas en los bytes `0..b/8`.
    pub rank: Vec<u32>,
    /// Chunks densos, en orden creciente de s-bucket.
    pub chunks: Vec<[u8; CHUNK_BYTES]>,
}

impl Pieza {
    /// Numero de pruebas (buckets ocupados) de la pieza. Siempre `NUM_CHUNKS` por construccion.
    #[inline]
    pub fn pruebas(&self) -> usize {
        self.chunks.len()
    }
}

/// Construye una pieza plotada real. Es la secuencia exacta de `record_encoding`
/// (`plotting.rs:615-680`), con la semilla de evaluacion que deriva `SectorId::derive_evaluation_seed`.
pub fn construir_pieza(
    sector_id: &SectorId,
    piece_offset: PieceOffset,
    cache: &TablesCache,
    erasure: &subspace_erasure_coding::ErasureCoding,
) -> Pieza {
    construir_pieza_con_tabla(sector_id, piece_offset, cache, erasure).0
}

/// Igual que [`construir_pieza`] pero conservando la tabla PoS viva.
///
/// Se usa solo en la comprobacion de prueba completa (`is_proof_valid`), donde hacen falta los
/// objetos `PosProof`. Retener la tabla cuesta ~5 MiB por pieza, asi que no se usa en el barrido.
pub fn construir_pieza_con_tabla(
    sector_id: &SectorId,
    piece_offset: PieceOffset,
    cache: &TablesCache,
    erasure: &subspace_erasure_coding::ErasureCoding,
) -> (Pieza, Box<Proofs<K>>) {
    // 1) Semilla de evaluacion: `blake3_list([sector_id, piece_offset_le])` (sectors.rs:126-129).
    let seed: PosSeed = sector_id.derive_evaluation_seed(piece_offset);

    // 2) Tabla PoS con la API publica del clon.
    let tabla: Box<Proofs<K>> = tabla_pos(seed, cache);

    // 3) Registro fuente: 32768 escalares validos.
    //
    //    `ScalarBytes` es BIG-endian con el byte 0 reservado: los `SAFE_BYTES = 31` bytes utiles
    //    viven en las posiciones 1..32 (`shared/subspace-kzg/src/lib.rs:123-130`, que hace
    //    `bytes[1..].copy_from_slice(value)`). Dejando el byte 0 a cero el valor es `< 2^248`,
    //    muy por debajo del modulo del cuerpo escalar, y por tanto **siempre** valido.
    //    Los bytes de historia reales son publicos; su valor no interviene en la estadistica del
    //    puente, pero SI se codifica y se hashea de verdad.
    let mut fuente: Vec<[u8; CHUNK_BYTES]> = Vec::with_capacity(NUM_CHUNKS);
    {
        let base = blake3_hash_with_key(&seed.into(), b"registro-fuente-v1");
        for j in 0..NUM_CHUNKS {
            let mut buf = [0_u8; 40];
            buf[..32].copy_from_slice(base.as_ref());
            buf[32..].copy_from_slice(&(j as u64).to_le_bytes());
            let mut s = [0_u8; CHUNK_BYTES];
            let h = blake3_hash(&buf);
            let hb: &[u8] = AsRef::<[u8]>::as_ref(&h);
            s[1..].copy_from_slice(&hb[..CHUNK_BYTES - 1]);
            fuente.push(s);
        }
    }

    // 4) Codigo de borrado: paridad real (ErasureCoding::extend). Fuente y paridad se intercalan
    //    (`plotting.rs:655-657`): bucket par -> fuente, bucket impar -> paridad.
    let escalares: Vec<_> = fuente
        .iter()
        .map(|b| Scalar::try_from(b).expect("byte 0 a cero garantiza un escalar canonico; qed"))
        .collect();
    let paridad = erasure
        .extend(&escalares)
        .expect("la instancia se creo con la escala correcta; qed");

    // 5) Por cada bucket: si hay prueba, `chunk = record_chunk XOR blake3(proof)`; si no, cero.
    let mut bitmap = [0_u8; BITMAP_BYTES];
    let mut chunks: Vec<[u8; CHUNK_BYTES]> = Vec::with_capacity(NUM_CHUNKS);
    for b in 0..NUM_S_BUCKETS {
        let hay = tabla.found_proofs[b / 8] & (1 << (b % 8)) != 0;
        if !hay {
            continue;
        }
        bitmap[b / 8] |= 1 << (b % 8);
        let record_chunk: [u8; CHUNK_BYTES] = if b % 2 == 0 {
            fuente[b / 2]
        } else {
            paridad[(b - 1) / 2].into()
        };
        let proof = PosProof::from(
            tabla
                .for_s_bucket(SBucket::from(b as u16))
                .expect("el bit dice que hay prueba; qed"),
        );
        let mut c = [0_u8; CHUNK_BYTES];
        // `Blake3Hash` solo expone `AsRef<[u8]>`; se ata el temporal antes de prestarlo.
        let hash_prueba = proof.hash();
        let hb: &[u8] = AsRef::<[u8]>::as_ref(&hash_prueba);
        for k in 0..CHUNK_BYTES {
            c[k] = record_chunk[k] ^ hb[k];
        }
        chunks.push(c);
    }

    // El mapa de presencia reconstruido desde los bits DEBE coincidir con el del clon.
    debug_assert_eq!(&bitmap[..], &tabla.found_proofs[..]);
    debug_assert_eq!(chunks.len(), NUM_CHUNKS);

    // 6) Prefijo de popcount por byte (rank/select).
    let mut rank = vec![0_u32; BITMAP_BYTES + 1];
    let mut acc = 0_u32;
    for (i, byte) in bitmap.iter().enumerate() {
        rank[i] = acc;
        acc += byte.count_ones();
    }
    rank[BITMAP_BYTES] = acc;

    (Pieza { bitmap, rank, chunks }, tabla)
}

/// Indice denso del chunk del bucket `b`, o `None` si el bucket esta vacio.
///
/// Referencia legible del `rank/select` de `proof_index_for_s_bucket`
/// (`shared/ab-proof-of-space/src/lib.rs:63-84`). Se contrasta con `Pieza::for_s_bucket_verifica`.
#[inline]
pub fn indice_denso(p: &Pieza, b: usize) -> Option<usize> {
    let byte = b / 8;
    let bit = b % 8;
    if p.bitmap[byte] & (1 << bit) == 0 {
        return None;
    }
    let previos = p.bitmap[byte] & ((1_u16 << bit) as u8).wrapping_sub(1);
    Some((p.rank[byte] + previos.count_ones()) as usize)
}

/// `audit_chunk = blake3_keyed(sector_slot_challenge, chunk)`
/// (`subspace-verification/src/lib.rs:118-131`). Se expone para que Julia pueda comprobar el
/// **orden de bytes** de la extraccion `u64` sin reimplementar blake3: Julia recibe los bytes y
/// solo reproduce la lectura little-endian y la distancia circular.
#[inline]
pub fn audit_chunk_de(ssc: &SectorSlotChallenge, chunk: &[u8; CHUNK_BYTES]) -> Blake3Hash {
    blake3_hash_with_key(ssc, chunk)
}

/// Construye **solo** el mapa de presencia y el numero de pruebas de una pieza.
///
/// Se usa en el barrido de ocupacion, donde los chunks no hacen falta: ahorra ~1 MiB por pieza.
pub fn construir_bitmap(
    sector_id: &SectorId,
    piece_offset: PieceOffset,
    cache: &TablesCache,
) -> ([u8; BITMAP_BYTES], usize) {
    let seed: PosSeed = sector_id.derive_evaluation_seed(piece_offset);
    let tabla: Box<Proofs<K>> = tabla_pos(seed, cache);
    (tabla.found_proofs, NUM_CHUNKS)
}

// ---------------------------------------------------------------------------------------------
// Auditoria: la secuencia de `auditing.rs:237-271`
// ---------------------------------------------------------------------------------------------

/// Resultado de auditar un sector contra un reto.
#[derive(Debug, Clone)]
pub struct Auditoria {
    /// s-bucket auditado.
    pub bucket: u16,
    /// Chunks leidos del s-bucket (piezas con prueba en ese bucket).
    pub chunks_leidos: usize,
    /// Chunks que superan el predicado barato.
    pub candidatos: usize,
    /// Distancias de los candidatos, en el orden en que se leyeron.
    pub distancias: Vec<u64>,
}

/// Distancia de solucion calculada con **primitivas upstream** pero sin pasar por
/// `is_within_solution_range` (que es privado en su parte de calculo). Es la referencia
/// independiente: `blake3_hash_with_key` y `bidirectional_distance` son publicos.
#[inline]
pub fn distancia_referencia(
    global_challenge: &Blake3Hash,
    chunk: &[u8; CHUNK_BYTES],
    ssc: &SectorSlotChallenge,
) -> SolutionRange {
    let audit_chunk = blake3_hash_with_key(ssc, chunk);
    let ac: &[u8] = audit_chunk.as_ref();
    let gc: &[u8] = global_challenge.as_ref();
    let mut a = [0_u8; 8];
    let mut b = [0_u8; 8];
    a.copy_from_slice(&ac[..8]);
    b.copy_from_slice(&gc[..8]);
    bidirectional_distance(&u64::from_le_bytes(b), &u64::from_le_bytes(a))
}

/// Audita un sector (conjunto de piezas) contra un reto, con el rango `sr`.
///
/// `contraste` activa la comprobacion contra la via upstream en cada chunk leido. Si una sola
/// muestra discrepa, se lanza un `panic`: preferimos fallar a publicar un numero fabricado.
pub fn auditar(
    piezas: &[&Pieza],
    global_challenge: &Blake3Hash,
    ssc: &SectorSlotChallenge,
    sr: SolutionRange,
    contraste: bool,
) -> Auditoria {
    let bucket = ssc.s_bucket_audit_index();
    let b = usize::from(bucket);
    let mut leidos = 0_usize;
    let mut distancias = Vec::new();
    for p in piezas {
        let Some(idx) = indice_denso(p, b) else {
            continue;
        };
        let chunk = &p.chunks[idx];
        leidos += 1;
        let d = distancia_referencia(global_challenge, chunk, ssc);
        if contraste {
            let upstream = is_within_solution_range(global_challenge, chunk, ssc, sr);
            let local_gana = d <= sr / 2;
            assert_eq!(
                upstream.is_some(),
                local_gana,
                "discrepancia referencia/upstream en bucket {b}"
            );
            if let Some(du) = upstream {
                assert_eq!(du, d, "distancia distinta en bucket {b}");
            }
        }
        if d <= sr / 2 {
            distancias.push(d);
        }
    }
    Auditoria {
        bucket: b as u16,
        chunks_leidos: leidos,
        candidatos: distancias.len(),
        distancias,
    }
}

/// Comprueba el `rank/select` local contra `Proofs::for_s_bucket` para todos los buckets.
///
/// Devuelve el numero de buckets contrastados. Falla si hay una sola discrepancia.
pub fn contrastar_rank_select(p: &Pieza, tabla: &Proofs<K>) -> usize {
    let mut n = 0_usize;
    for b in 0..NUM_S_BUCKETS {
        let local = indice_denso(p, b);
        let upstream = tabla.for_s_bucket(SBucket::from(b as u16));
        match (local, upstream) {
            (None, None) => {}
            (Some(i), Some(raw)) => {
                // El indice denso debe caer dentro del array de chunks y el hash de la prueba
                // upstream debe tener los 32 B que el plotter XOR-ea en el chunk almacenado.
                assert!(i < p.chunks.len(), "indice denso fuera de rango");
                let proof = PosProof::from(raw);
                let hash_prueba = proof.hash();
                let hb: &[u8] = AsRef::<[u8]>::as_ref(&hash_prueba);
                assert_eq!(hb.len(), 32);
            }
            _ => panic!("discrepancia rank/select en bucket {b}"),
        }
        n += 1;
    }
    n
}

// ---------------------------------------------------------------------------------------------
// Construccion paralela de un sector
// ---------------------------------------------------------------------------------------------

/// Construye `m` piezas de un mismo sector, en paralelo por offset de pieza.
///
/// Cada pieza usa su propio `TableGenerator` implicito a traves de `create_proofs`, que es
/// exactamente lo que hace el plotter. La escritura va a una posicion exclusiva por indice.
pub fn construir_sector(
    sector_id: &SectorId,
    m: usize,
    hilos: usize,
) -> Vec<Pieza> {
    let erasure = subspace_erasure_coding::ErasureCoding::new(
        NonZeroUsize::new(ERASURE_SCALE).expect("escala no nula; qed"),
    )
    .expect("escala 16 es valida; qed");

    // La generacion de tablas chiapos consume varios MiB de pila por llamada; el valor por
    // omision de rayon (2 MiB) desborda. 64 MiB por hilo es memoria virtual, no residente.
    let pool = rayon::ThreadPoolBuilder::new()
        .stack_size(64 * 1024 * 1024)
        .num_threads(hilos)
        .build()
        .expect("pool de hilos; qed");

    let mut piezas: Vec<Option<Pieza>> = (0..m).map(|_| None).collect();
    pool.install(|| {
        piezas.par_iter_mut().enumerate().for_each(|(i, slot)| {
            // `TablesCache` es memoria de trabajo **por llamada**: compartirla entre hilos corrompe
            // el monton (comprobado: `malloc(): corrupted top size`). El propio banco de P-INTENTO
            // la crea dentro de cada ambito concurrente (escalado.rs:135,160,180).
            let cache = TablesCache::default();
            *slot = Some(construir_pieza(
                sector_id,
                PieceOffset::from(i as u16),
                &cache,
                &erasure,
            ));
        });
    });
    piezas
        .into_iter()
        .map(|p| p.expect("todas las posiciones se rellenan; qed"))
        .collect()
}

/// Tiempo (segundos) que cuesta generar una tabla con el camino serial.
pub fn tiempo_tabla_serial(seed: &PosSeed, cache: &TablesCache) -> f64 {
    let t0 = std::time::Instant::now();
    let t = Tables::<K>::create_proofs((*seed).into(), cache);
    let dt = t0.elapsed().as_secs_f64();
    std::hint::black_box(t);
    dt
}
