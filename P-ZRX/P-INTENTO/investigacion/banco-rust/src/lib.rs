#![feature(generic_const_exprs)]
#![expect(incomplete_features, reason = "ab-proof-of-space usa generic_const_exprs; hay que nombrar Proofs<20>")]

//! Utilidades compartidas del banco P-INTENTO.
//!
//! Todo lo que hay aqui llama a la API PUBLICA del clon fijado
//! (`/home/katana/zeo/fuentes/subspace` @ `f8842d0`). No se copia ni se reimplementa
//! codigo de Autonomys.

use ab_proof_of_space::chiapos::{Proofs, Tables, TablesCache};
use subspace_core_primitives::hashes::{Blake3Hash, blake3_hash};
use subspace_core_primitives::pieces::{PieceOffset, Record};
use subspace_core_primitives::pos::PosSeed;
use subspace_core_primitives::sectors::{SBucket, SectorId, SectorSlotChallenge};
use subspace_core_primitives::segments::HistorySize;

/// Numero de s-buckets por registro/sector. Comprobado en tiempo de compilacion contra el clon.
pub const NUM_S_BUCKETS: usize = Record::NUM_S_BUCKETS;
/// Numero de chunks (escalares) por registro.
pub const NUM_CHUNKS: usize = Record::NUM_CHUNKS;
/// `K` de la prueba de espacio.
pub const K: u8 = 20;
/// Palabras de 64 bits del mapa de bits de presencia de pruebas.
pub const FOUND_WORDS: usize = NUM_S_BUCKETS / 64;
/// Tamano en bytes de `Proofs<20>`: lo que ocupa una "tabla viva" segun la API del clon.
pub const PROOFS_BYTES: usize = core::mem::size_of::<Proofs<20>>();

const _: () = {
    assert!(NUM_S_BUCKETS == 1 << 16);
    assert!(NUM_CHUNKS == 1 << 15);
    assert!(NUM_S_BUCKETS == (u16::MAX as usize) + 1);
};

/// Semilla determinista y distinta por identidad candidata.
///
/// El atacante elige `public_key`, `sector_index`, `history_size` y `piece_offset`; aqui se
/// empaquetan en un contador de 64 bits para reproducir esa libertad sin materializar claves.
#[inline]
pub fn seed_i(i: u64) -> PosSeed {
    let mut buf = [0_u8; 16];
    buf[..8].copy_from_slice(b"INTENTO1");
    buf[8..].copy_from_slice(&i.to_le_bytes());
    PosSeed::from(*blake3_hash(&buf))
}

/// Reto global sintetico por indice de slot.
///
/// `Blake3Hash` uniforme. La derivacion real del reto (salida del PoT) NO entra en esta medida:
/// es el objeto de `P-ZRX/P-REVELACION/`. Lo que se mide aqui es el coste de cruzar una tabla
/// ya generada con un reto, que no depende de como se obtuvo el reto.
#[inline]
pub fn global_challenge_i(i: u64) -> Blake3Hash {
    let mut buf = [0_u8; 16];
    buf[..8].copy_from_slice(b"SLOTRETO");
    buf[8..].copy_from_slice(&i.to_le_bytes());
    blake3_hash(&buf)
}

/// Identidad de sector determinista.
#[inline]
pub fn sector_id_i(i: u64) -> SectorId {
    let mut buf = [0_u8; 16];
    buf[..8].copy_from_slice(b"IDSECTOR");
    buf[8..].copy_from_slice(&i.to_le_bytes());
    let public_key_hash = blake3_hash(&buf);
    SectorId::new(
        public_key_hash,
        (i & 0xffff) as u16,
        HistorySize::from(core::num::NonZeroU64::new(1).expect("no cero; qed")),
    )
}

/// Genera una tabla con la API publica del clon (`Tables::create_proofs`).
///
/// Es exactamente lo que hace `ChiaV2TableGenerator::generate`
/// (`crates/subspace-proof-of-space/src/chia_v2.rs:28-36`).
#[inline]
pub fn tabla(seed: &PosSeed, cache: &TablesCache) -> Box<Proofs<20>> {
    Tables::<20>::create_proofs((*seed).into(), cache)
}

/// Genera una tabla por el camino paralelo (`create_proofs_parallel`).
#[inline]
pub fn tabla_paralela(seed: &PosSeed, cache: &TablesCache) -> Box<Proofs<20>> {
    Tables::<20>::create_proofs_parallel((*seed).into(), cache)
}

/// Los `w` retos globales que el atacante conoce por adelantado.
///
/// NO forman parte del coste del intento: los produce el PoT una sola vez y son **compartidos por
/// todas las identidades candidatas**. Se separan de la derivacion por identidad justamente para no
/// cargarle al atacante un coste que no paga. La sintesis con `blake3` es un sustituto uniforme de
/// la salida real del PoT, cuyo calendario es objeto de `P-ZRX/P-POT` y `P-ZRX/P-REVELACION`; lo
/// que importa aqui es que el vector es el mismo para todas las identidades.
pub fn retos_globales(w: usize, base_slot: u64) -> Vec<Blake3Hash> {
    (0..w)
        .map(|j| global_challenge_i(base_slot + j as u64))
        .collect()
}

/// Los `w` s-buckets que seleccionan los retos conocidos para UNA identidad de sector.
///
/// Replica la derivacion real: `SectorSlotChallenge = SectorId XOR global_challenge`
/// (`crates/subspace-core-primitives/src/sectors.rs:117-123`) y `s_bucket` = dos primeros bytes LE
/// (`sectors.rs:32-39`). Esto SI es coste por intento: la identidad cambia en cada intento.
pub fn buckets_de_retos(
    sector_id: &SectorId,
    retos: &[Blake3Hash],
) -> (Vec<SBucket>, Vec<SectorSlotChallenge>) {
    let mut buckets = Vec::with_capacity(retos.len());
    let mut challenges = Vec::with_capacity(retos.len());
    for gc in retos {
        let ssc = sector_id.derive_sector_slot_challenge(gc);
        buckets.push(ssc.s_bucket_audit_index());
        challenges.push(ssc);
    }
    (buckets, challenges)
}

/// Comodidad: retos globales + derivacion por identidad, en un solo paso.
pub fn buckets_para_w(
    sector_id: &SectorId,
    w: usize,
    base_slot: u64,
) -> (Vec<SBucket>, Vec<SectorSlotChallenge>, Vec<Blake3Hash>) {
    let retos = retos_globales(w, base_slot);
    let (buckets, challenges) = buckets_de_retos(sector_id, &retos);
    (buckets, challenges, retos)
}

/// Mapa de bits de 64 KiB con los buckets objetivo (uno por bit).
#[inline]
pub fn bitset_objetivo(buckets: &[SBucket]) -> Vec<u64> {
    let mut bs = vec![0_u64; FOUND_WORDS];
    for b in buckets {
        let idx = usize::from(*b);
        bs[idx / 64] |= 1_u64 << (idx % 64);
    }
    bs
}

/// Cruce EN LOTE de una tabla con `w` buckets: `w` bits contra el mapa de presencia.
///
/// `AND` palabra a palabra del mapa de presencia (8 KiB) con el mapa objetivo. El coste es
/// `O(NUM_S_BUCKETS/64)` sea cual sea `w`, frente a `O(w)` rank/select del camino por bucket.
#[inline]
pub fn cruce_lote(found_proofs: &[u8; NUM_S_BUCKETS / 8], objetivo: &[u64]) -> u32 {
    let mut hits = 0_u32;
    for (i, objetivo) in objetivo.iter().enumerate() {
        let palabra = u64::from_le_bytes(
            found_proofs[i * 8..i * 8 + 8]
                .try_into()
                .expect("8 bytes; qed"),
        );
        hits += (palabra & *objetivo).count_ones();
    }
    hits
}

/// Rank/select sobre el mapa de presencia, equivalente exacto de
/// `PosProofs::proof_index_for_s_bucket` (`shared/ab-proof-of-space/src/lib.rs:63-84`), que es
/// privado. El coste es lo que define `t_reto` en el camino por bucket.
#[inline]
pub fn proof_index_para_bucket(
    found_proofs: &[u8; NUM_S_BUCKETS / 8],
    bucket: SBucket,
) -> Option<usize> {
    let bits_offset = usize::from(bucket);
    let byte = bits_offset / 8;
    let bit = (bits_offset % 8) as u32;
    let (antes, despues) = found_proofs.split_at(byte);
    if (despues[0] & (1 << bit)) == 0 {
        return None;
    }
    let idx = antes.iter().map(|b| b.count_ones()).sum::<u32>()
        + despues[0].unbounded_shl(8 - bit).count_ones();
    Some(idx as usize)
}

/// Numero de bits puestos en el mapa de presencia (numero de pruebas de la tabla).
#[inline]
pub fn pruebas_presentes(found_proofs: &[u8; NUM_S_BUCKETS / 8]) -> usize {
    found_proofs.iter().map(|b| b.count_ones() as usize).sum()
}

/// Offset de pieza usado en todas las medidas (el atacante lo elige libremente).
pub const PIECE_OFFSET: PieceOffset = PieceOffset::ZERO;
