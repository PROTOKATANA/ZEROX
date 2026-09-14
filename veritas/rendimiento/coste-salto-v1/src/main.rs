//! Banco de costes del salto (Q4, TAREAS.md §3.1).
//!
//! Contexto PoAS SINTÉTICO (el mismo de prototipos/poas-identidad): raíz KZG
//! construida aquí, no historia ZEROX/Archiver acreditada. Mide SOLO la
//! verificación, nunca la construcción de entradas. Controles positivo y
//! negativo de cada operación antes de medir.
#![feature(generic_const_exprs)]
#![allow(incomplete_features)]
// El binario `target-soft` se compila con RUSTFLAGS='--cfg aes_backend="soft"'
// (Corrección 1, 3.2): rustc no conoce ese cfg de antemano en el binario base,
// así que lo declaramos permitido en vez de que salga como warning.
#![allow(unexpected_cfgs)]

use std::hint::black_box;
use std::io::Write;
use std::num::{NonZeroU32, NonZeroU64};
use std::time::Instant;

use ab_proof_of_space::chiapos::{Tables, TablesCache};
use ed25519_zebra::{SigningKey, VerificationKey};
use pot_estable::tipos::{PotSeed, Ruta};
use sha3::{Digest as _, Sha3_256};
use subspace_core_primitives::hashes::blake3_254_hash_to_scalar;
use subspace_core_primitives::pieces::{PieceOffset, RawRecord, Record};
use subspace_core_primitives::pos::PosProof;
use subspace_core_primitives::pot::PotOutput;
use subspace_core_primitives::sectors::SectorId;
use subspace_core_primitives::segments::{ArchivedHistorySegment, HistorySize};
use subspace_core_primitives::solutions::{ChunkWitness, Solution, SolutionPotVerifier};
use subspace_core_primitives::{PublicKey, ScalarBytes};
use subspace_kzg::{Commitment, Kzg, Scalar, Witness};
use subspace_proof_of_space::chia::ChiaTable;
use subspace_verification::{PieceCheckParams, VerifySolutionParams, verify_solution};
use zx_core::amount::Amount;
use zx_core::digest::Digest;
use zx_core::firma::{ClavePublica, Firma, verificar};
use zx_core::preimage::block::{BlockHeader, merkle_root};
use zx_core::preimage::tx::txid as calcular_txid;
use zx_core::tx::{Lock, OutPoint, Tx, TxIn, TxOut};
use zx_core::wire::{tx_a_bytes, tx_desde_bytes};
use zx_core::{BlockHash, MerkleRoot, TxId};

// ── Constantes del banco ────────────────────────────────────────────────────

/// Iteraciones por slot del ancla (research/dag-poas-ancla-de-orden.md:342 y
/// benches/pot.rs de subspace @ f8842d0).
const POT_ITERACIONES: u32 = 200_032_000;
/// Etiqueta de dominio C-HDR-09 (SPEC.md:898): H_d("ZZKBlkHeader____", ·).
const TAG_BLK_HEADER: &[u8; 16] = b"ZZKBlkHeader____";
/// Base PoAS lineal, C-HDR-01 (SPEC.md:843): 556 bytes.
const TAMANO_BASE: usize = 556;
/// Prefirma: header_encoding[0, 492), C-HDR-03 (SPEC.md:878).
const TAMANO_PREFIRMA: usize = 492;
/// Justificación PoT por slot: 8 checkpoints × 16 B = 128 B (Q4).
const JUSTIFICACION_SLOT: usize = 128;
/// S_max: 150 slots de justificación (TAREAS.md §3.1 Q2).
const S_MAX: usize = 150;
/// `consensus_branch_id` de fixture, igual al usado en D para la cabecera.
const BRANCH_ID: u32 = 0xc478_80ea;

// ── Fixture PoAS (misma construcción que prototipos/poas-identidad) ─────────

fn history(size: u64) -> HistorySize {
    HistorySize::from(NonZeroU64::new(size).expect("constante positiva de fixture"))
}

fn bucket(sector: &SectorId, pot: PotOutput, slot: u64) -> u32 {
    let global = pot.derive_global_randomness().derive_global_challenge(slot);
    u16::from(
        sector
            .derive_sector_slot_challenge(&global)
            .s_bucket_audit_index(),
    )
    .into()
}

fn prefix(s_bucket: u32) -> u32 {
    // Misma costura endian que ChiaTable::is_proof_valid, K=20 del commit fijado.
    u32::from_be_bytes(s_bucket.to_le_bytes()) >> (32 - u32::from(PosProof::K))
}

struct Contexto {
    kzg: Kzg,
    sector: SectorId,
    slot: u64,
    audit_bucket: u32,
    params: VerifySolutionParams,
    primera: Solution<()>,
    record_commitment: Commitment,
    sello: [u8; 64],
    clave: [u8; 32],
    base_556: [u8; 556],
}

fn construir_contexto() -> Result<Contexto, String> {
    // Clave Ed25519 ordinaria de semilla pública [0x42;32], fijada y comprobada en
    // crates/zx-core/tests/ed25519_no_unicidad.rs. Este banco NO verifica sellos.
    let public_key = PublicKey::from([
        0x21, 0x52, 0xf8, 0xd1, 0x9b, 0x79, 0x1d, 0x24, 0x45, 0x32, 0x42, 0xe1, 0x5f, 0x2e, 0xab,
        0x6c, 0xb7, 0xcf, 0xfa, 0x7b, 0x6a, 0x5e, 0xd3, 0x00, 0x97, 0x96, 0x0e, 0x06, 0x98, 0x81,
        0xdb, 0x12,
    ]);
    let history_size = history(3);
    let sector_index = 7;
    let sector = SectorId::new(public_key.hash(), sector_index, history_size);
    let pot = PotOutput::from([0x35; 16]);
    let kzg = Kzg::new();

    // Record repetido: no se presupone que chunks de piezas diferentes sean distintos.
    let value = Scalar::from([0x17; ScalarBytes::SAFE_BYTES]);
    let record_polynomial = kzg.poly(&vec![value; Record::NUM_CHUNKS])?;
    let record_commitment = kzg.commit(&record_polynomial)?;
    let commitment_bytes: [u8; 48] = (&record_commitment).into();
    let record_hash = Scalar::try_from(blake3_254_hash_to_scalar(&commitment_bytes))?;
    let segment_polynomial = kzg.poly(&vec![record_hash; ArchivedHistorySegment::NUM_PIECES])?;
    let segment_commitment = kzg.commit(&segment_polynomial)?;
    let params = VerifySolutionParams {
        proof_of_time: pot,
        // Sólo perfil permisivo de fixture; NO rango ni probabilidad de producción.
        solution_range: u64::MAX,
        piece_check_params: Some(PieceCheckParams {
            max_pieces_in_sector: 2,
            segment_commitment: segment_commitment.into(),
            recent_segments: history(5),
            recent_history_fraction: (history(1), history(10)),
            min_sector_lifetime: history(4),
            current_history_size: history_size,
            sector_expiration_check_segment_commitment: None,
        }),
    };
    let cache = TablesCache::default();
    let table0 = Tables::<20>::create(
        sector.derive_evaluation_seed(PieceOffset::from(0)).into(),
        &cache,
    );
    let table1 = Tables::<20>::create(
        sector.derive_evaluation_seed(PieceOffset::from(1)).into(),
        &cache,
    );

    // Búsqueda determinista acotada, mismo resultado fijado que poas-identidad.
    let mut selected = None;
    for slot in 1..=4096 {
        let audit_bucket = bucket(&sector, pot, slot);
        let proofs0: Vec<_> = table0
            .find_proof_raw(prefix(audit_bucket))
            .take(2)
            .collect();
        if let ([first, second], Some(other)) = (
            proofs0.as_slice(),
            table1.find_proof_raw(prefix(audit_bucket)).next(),
        ) && first != second
        {
            selected = Some((slot, audit_bucket, *first, *second, other));
            break;
        }
    }
    let (slot, audit_bucket, proof0a, proof0b, proof1) =
        selected.ok_or("sin fixture en los 4096 slots; inconcluso")?;
    assert_eq!(
        (slot, audit_bucket),
        (4, 22412),
        "fixture fijada; no regenerar silenciosamente"
    );
    let piece_params = params
        .piece_check_params
        .as_ref()
        .ok_or("falta contexto de pieza")?;
    let make_solution = |offset: u16, proof: [u8; 160]| -> Result<Solution<()>, String> {
        let piece_offset = PieceOffset::from(offset);
        let position = sector
            .derive_piece_index(
                piece_offset,
                history_size,
                piece_params.max_pieces_in_sector,
                piece_params.recent_segments,
                piece_params.recent_history_fraction,
            )
            .position();
        Ok(Solution {
            public_key,
            reward_address: (),
            sector_index,
            history_size,
            piece_offset,
            record_commitment: record_commitment.into(),
            record_witness: kzg
                .create_witness(
                    &segment_polynomial,
                    ArchivedHistorySegment::NUM_PIECES,
                    position,
                )?
                .into(),
            chunk: value.into(),
            chunk_witness: kzg
                .create_witness(&record_polynomial, Record::NUM_S_BUCKETS, audit_bucket)?
                .into(),
            proof_of_space: PosProof::from(proof),
        })
    };
    let primera = make_solution(0, proof0a)?;
    let alterna = make_solution(0, proof0b)?;
    let otra = make_solution(1, proof1)?;
    let check = |solution: &Solution<()>, context: &VerifySolutionParams, s: u64| {
        verify_solution::<ChiaTable, _>(solution, s, context, &kzg)
    };
    let distance = check(&primera, &params, slot).map_err(|error| error.to_string())?;
    let alternate_distance = check(&alterna, &params, slot).map_err(|error| error.to_string())?;
    let other_distance = check(&otra, &params, slot).map_err(|error| error.to_string())?;
    assert_eq!(
        (distance, alternate_distance, other_distance),
        (
            4352823087875908110,
            8322768934019865430,
            3650123740992092631
        ),
        "distancias de la fixture fijada"
    );

    // Base PoAS de 556 B (C-HDR-01) con valores reales del contexto + sello C.
    let mut base = [0u8; TAMANO_BASE];
    {
        let mut o = 0usize;
        let mut w = |b: &[u8]| {
            base[o..o + b.len()].copy_from_slice(b);
            o += b.len();
        };
        w(&0xc478_80ea_u32.to_le_bytes()); // consensus_branch_id
        w(&[0x11; 32]); // prev_hash
        w(&[0x22; 32]); // merkle_root
        w(&1_767_225_600_u64.to_le_bytes()); // timestamp
        w(&1_u32.to_le_bytes()); // height
        w(&slot.to_le_bytes()); // slot
        w(&*pot); // pot_output (Deref a [u8;16])
        w(&u64::MAX.to_le_bytes()); // rango_solucion (perfil permisivo)
        w(&*public_key); // sol.public_key
        w(&sector_index.to_le_bytes()); // sol.sector_index
        w(&NonZeroU64::from(history_size).get().to_le_bytes()); // sol.history_size
        w(&0_u16.to_le_bytes()); // sol.piece_offset
        w(&commitment_bytes); // sol.record_commitment
        w(&<[u8; 48]>::from(primera.record_witness)); // sol.record_witness
        w(&<[u8; 32]>::from(primera.chunk)); // sol.chunk
        w(primera.chunk_witness.as_ref()); // sol.chunk_witness
        w(&*primera.proof_of_space); // sol.proof_of_space
        assert_eq!(o, TAMANO_PREFIRMA, "prefirma 492 B antes del sello");
    }
    // Sello (C): firma Ed25519 sobre la prefirma, clave determinista del banco.
    let sk = SigningKey::from([0x5a; 32]);
    let vk = VerificationKey::from(&sk);
    let clave: [u8; 32] = vk.into();
    let sello: [u8; 64] = sk.sign(&base[..TAMANO_PREFIRMA]).into();
    base[TAMANO_PREFIRMA..TAMANO_BASE].copy_from_slice(&sello);

    Ok(Contexto {
        kzg,
        sector,
        slot,
        audit_bucket,
        params,
        primera,
        record_commitment,
        sello,
        clave,
        base_556: base,
    })
}

/// B-kzg-hist · fixture con los MISMOS parámetros que el banco histórico
/// (`subspace-kzg/benches/kzg.rs:1-60`): `num_values = RawRecord::NUM_CHUNKS`,
/// índice 0. DIFERENCIA declarada: el histórico usa `rand::random()` (no
/// determinista); aquí, `ChaCha8Rng::seed_from_u64(0)`, para que el banco sea
/// reproducible. `check_proof_single` (lib.rs:788-816) no depende del RNG.
fn construir_kzg_hist(kzg: &Kzg) -> Result<(Commitment, Witness, Scalar, usize, u32), String> {
    use rand_chacha::ChaCha8Rng;
    use rand_core::{RngCore, SeedableRng};
    let mut rng = ChaCha8Rng::seed_from_u64(0);
    let num_values = RawRecord::NUM_CHUNKS;
    let index = 0u32;
    let values: Vec<Scalar> = (0..num_values)
        .map(|_| {
            let mut b = [0u8; ScalarBytes::SAFE_BYTES];
            rng.fill_bytes(&mut b);
            Scalar::from(b)
        })
        .collect();
    let polynomial = kzg.poly(&values)?;
    let commitment = kzg.commit(&polynomial)?;
    let witness = kzg.create_witness(&polynomial, num_values, index)?;
    Ok((commitment, witness, values[0], num_values, index))
}

/// B-kzg-hist · `Kzg::verify` con los parámetros del banco histórico.
fn op_b_kzg_hist(kzg: &Kzg, commitment: &Commitment, num_values: usize, index: u32, value: &Scalar, witness: &Witness) -> bool {
    kzg.verify(
        black_box(commitment),
        black_box(num_values),
        black_box(index),
        black_box(value),
        black_box(witness),
    )
}

// ── Operaciones medidas ─────────────────────────────────────────────────────

/// A · `verify_solution::<ChiaTable, _>` con piece_check_params (PoS + rango +
/// 2 KZG + límites de pieza).
fn op_a(c: &Contexto) -> u64 {
    verify_solution::<ChiaTable, _>(black_box(&c.primera), black_box(c.slot), black_box(&c.params), black_box(&c.kzg)).expect("A debe verificar")
}

/// B · prueba de espacio sola, K=20.
fn op_b_pos(c: &Contexto) -> bool {
    <ChiaTable as SolutionPotVerifier>::is_proof_valid(
        black_box(&c.sector.derive_evaluation_seed(c.primera.piece_offset)),
        black_box(c.audit_bucket),
        black_box(&c.primera.proof_of_space),
    )
}

/// B · `Kzg::verify` una vez (testigo de chunk contra el compromiso del record).
fn op_b_kzg(c: &Contexto) -> bool {
    c.kzg.verify(
        black_box(&c.record_commitment),
        black_box(Record::NUM_S_BUCKETS),
        black_box(c.audit_bucket),
        black_box(&Scalar::try_from(c.primera.chunk).expect("chunk de fixture")),
        black_box(&Witness::try_from(c.primera.chunk_witness).expect("witness de fixture")),
    )
}

/// C · sello Ed25519 (ZIP-215) sobre la prefirma de 492 B.
fn op_c(c: &Contexto) -> Result<(), zx_core::EncodingError> {
    verificar(
        black_box(&ClavePublica::desde_bytes(c.clave)),
        black_box(&Firma::desde_bytes(c.sello)),
        black_box(&c.base_556[..TAMANO_PREFIRMA]),
    )
}

/// D · `block_hash` de zx-core sobre la cabecera implementada (92 B).
fn op_d92(h: &BlockHeader) -> BlockHash {
    black_box(h.block_hash())
}

/// D · réplica de H_d (sha3 0.12.0) sobre la base PoAS de 556 B.
fn op_d556(base: &[u8; TAMANO_BASE]) -> [u8; 32] {
    let mut hasher = Sha3_256::new();
    hasher.update(TAG_BLK_HEADER);
    hasher.update(black_box(base));
    hasher.finalize().into()
}

/// E · `merkle_root` de zx-core.
fn op_e(txids: &[TxId]) -> MerkleRoot {
    black_box(merkle_root(black_box(txids)))
}

/// F · comparación de la justificación PoT contra la caché (Q4, salvaguarda 1):
/// `n` slots × 128 B.
fn op_f(cache: &[[u8; JUSTIFICACION_SLOT]], just: &[[u8; JUSTIFICACION_SLOT]], n: usize) -> bool {
    for i in 0..n {
        if black_box(&cache[i]) != black_box(&just[i]) {
            return false;
        }
    }
    true
}

/// H · construye una transacción sintética transparente, determinista por `i`,
/// con 2 entradas y 3 salidas P2K (Corrección 1, 3.4). Composición elegida para
/// acercarse a los 350 B del Modelo B350 (TAREAS.md §3.1 Q1) con `tx_a_bytes`:
/// 12 B cabecera + 1+2×40 entradas + 1+3×41 salidas + 1+2×65 testigos = 348 B
/// (comprobado con `.len()`, no supuesto — ver CONTROLES.txt).
fn construir_tx_h(i: u32) -> (Tx, Vec<Vec<u8>>) {
    let mut prev_bytes = [0x9a_u8; 32];
    prev_bytes[0..4].copy_from_slice(&i.to_le_bytes());
    let prev_txid = TxId::from_digest(Digest::from_bytes(prev_bytes));
    let inputs = vec![
        TxIn {
            outpoint: OutPoint { prev_txid, prev_index: 0 },
            sequence: 0xffff_ffff,
        },
        TxIn {
            outpoint: OutPoint { prev_txid, prev_index: 1 },
            sequence: 0xffff_ffff,
        },
    ];
    let mut pk_bytes = [0x77_u8; 32];
    pk_bytes[0..4].copy_from_slice(&i.to_le_bytes());
    let pubkey = ClavePublica::desde_bytes(pk_bytes);
    let outputs = vec![
        TxOut {
            value: Amount::nuevo(1_000_000 + i64::from(i)).expect("importe válido"),
            lock: Lock::PubKey { pubkey },
        },
        TxOut {
            value: Amount::nuevo(2_000_000).expect("importe válido"),
            lock: Lock::PubKey { pubkey },
        },
        TxOut {
            value: Amount::nuevo(3_000_000).expect("importe válido"),
            lock: Lock::PubKey { pubkey },
        },
    ];
    let tx = Tx { version: 1, inputs, outputs, lock_time: 0, expiry_height: 0 };
    let testigos = vec![vec![0xAB_u8; 64], vec![0xCD_u8; 64]];
    (tx, testigos)
}

/// H · construye `n` transacciones y sus bytes de wire (`tx_a_bytes`, con
/// testigos), fuera de lo cronometrado.
fn construir_lote_h(n: u32) -> Vec<Vec<u8>> {
    (0..n)
        .map(|i| {
            let (tx, testigos) = construir_tx_h(i);
            let mut bytes = Vec::new();
            tx_a_bytes(&mut bytes, &tx, &testigos);
            bytes
        })
        .collect()
}

/// H · decodifica (`wire::tx_desde_bytes`) y calcula `preimage::tx::txid` sobre
/// `n` transacciones ya codificadas.
fn op_h(lote_bytes: &[Vec<u8>]) -> u64 {
    let mut acc = 0u64;
    for bytes in lote_bytes {
        let ((tx, _testigos), _resto) =
            tx_desde_bytes(black_box(bytes)).expect("H debe decodificar");
        let id = calcular_txid(black_box(&tx), BRANCH_ID);
        acc ^= u64::from_le_bytes(id.as_bytes()[..8].try_into().unwrap());
    }
    black_box(acc)
}

/// H-txid · solo `preimage::tx::txid` sobre `n` transacciones YA decodificadas
/// (decodificar no se cronometra).
fn op_h_txid(txs: &[Tx]) -> u64 {
    let mut acc = 0u64;
    for tx in txs {
        let id = calcular_txid(black_box(tx), BRANCH_ID);
        acc ^= u64::from_le_bytes(id.as_bytes()[..8].try_into().unwrap());
    }
    black_box(acc)
}

fn controles_h() {
    let (tx, testigos) = construir_tx_h(0);
    let mut bytes1 = Vec::new();
    tx_a_bytes(&mut bytes1, &tx, &testigos);
    println!("CONTROL H    tamaño de una tx sintética : {} B (composición: 2 in, 3 out P2K, 2 testigos de 64 B)", bytes1.len());

    let ((tx_decodificada, testigos_decodificados), resto) =
        tx_desde_bytes(&bytes1).expect("decodifica");
    assert!(resto.is_empty(), "sin bytes sobrantes");
    let mut bytes2 = Vec::new();
    tx_a_bytes(&mut bytes2, &tx_decodificada, &testigos_decodificados);
    println!("CONTROL H+   bytes -> Tx -> bytes idéntico : {}", bytes1 == bytes2);

    let id_a = calcular_txid(&tx, BRANCH_ID);
    let id_b = calcular_txid(&tx, BRANCH_ID);
    println!("CONTROL H+   txid determinista : {}", id_a == id_b);

    let mut tx_mutada = tx.clone();
    tx_mutada.outputs[0].value = Amount::nuevo(9_999_999).expect("importe válido");
    let id_mutada = calcular_txid(&tx_mutada, BRANCH_ID);
    println!("CONTROL H-   cambiar el valor de una salida cambia el txid : {}", id_a != id_mutada);

    let truncados = &bytes1[..bytes1.len() - 1];
    println!(
        "CONTROL H-   bytes truncados devuelven error : {}",
        tx_desde_bytes(truncados).is_err()
    );
}

/// G · PoT por slot, ruta forzada, 200 032 000 iteraciones y 8 checkpoints.
fn op_g(
    seed: PotSeed,
    iterations: NonZeroU32,
    checkpoints: &pot_estable::tipos::PotCheckpoints,
    ruta: Ruta,
) -> bool {
    pot_estable::verify_con_ruta(
        black_box(seed),
        black_box(iterations),
        black_box(checkpoints),
        black_box(ruta),
    )
    .expect("G debe verificar")
}

// ── Harness de medición ─────────────────────────────────────────────────────

fn percentil(ordenadas: &[u128], p: f64) -> f64 {
    if ordenadas.is_empty() {
        return f64::NAN;
    }
    let idx = ((p / 100.0) * ordenadas.len() as f64).ceil() as usize - 1;
    ordenadas[idx.clamp(0, ordenadas.len() - 1)] as f64
}

#[derive(Clone, Copy)]
struct Stats {
    mediana: f64,
    p10: f64,
    p90: f64,
    min: f64,
    cv: f64,
}

fn stats(mut muestras: Vec<u128>) -> Stats {
    muestras.sort_unstable();
    let media = muestras.iter().sum::<u128>() as f64 / muestras.len() as f64;
    let var = muestras
        .iter()
        .map(|&x| {
            let d = x as f64 - media;
            d * d
        })
        .sum::<f64>()
        / muestras.len() as f64;
    Stats {
        mediana: percentil(&muestras, 50.0),
        p10: percentil(&muestras, 10.0),
        p90: percentil(&muestras, 90.0),
        min: muestras[0] as f64,
        cv: var.sqrt() / media,
    }
}

struct Medicion {
    id: &'static str,
    detalle: String,
    muestras: Vec<u128>,
    division: u64,
}

impl Medicion {
    fn nueva(id: &'static str, detalle: String, division: u64) -> Self {
        Self { id, detalle, muestras: Vec::new(), division }
    }

    /// Calentamiento (mínimo `warm_min` llamadas o `warm_ms` ms, tope `warm_max`)
    /// y `n` muestras. Si `lote>0`, cada muestra se anexa al CSV.
    fn ejecutar(
        &mut self,
        mut f: impl FnMut(),
        n: usize,
        warm_min: usize,
        warm_ms: u128,
        warm_max: usize,
        lote: u32,
        csv: &mut dyn std::io::Write,
    ) -> Stats {
        let t0 = Instant::now();
        let mut calientes = 0usize;
        while calientes < warm_min
            || (t0.elapsed().as_millis() < warm_ms && calientes < warm_max)
        {
            f();
            calientes += 1;
            if calientes >= warm_max {
                break;
            }
        }
        for i in 0..n {
            let t = Instant::now();
            f();
            let ns = t.elapsed().as_nanos() / self.division as u128;
            self.muestras.push(ns);
            if lote > 0 {
                writeln!(csv, "{},{},{},{},{}", self.id, self.detalle, lote, i, ns)
                    .expect("csv escribible");
            }
        }
        stats(self.muestras.clone())
    }
}

fn controles(c: &Contexto, txids571: &[TxId], cache150: &[[u8; 128]]) {
    println!(
        "CONTROL cfg!(aes_backend=\"soft\") en este binario : {}",
        cfg!(aes_backend = "soft")
    );
    let check = |solution: &Solution<()>, context: &VerifySolutionParams, s: u64| {
        verify_solution::<ChiaTable, _>(solution, s, context, &c.kzg)
    };
    println!("CONTROL A+  verify_solution(primera) -> Ok(distance) : {:?}", check(&c.primera, &c.params, c.slot).map(|d| format!("Ok({d})")));
    let mut mutada = c.primera.clone();
    mutada.proof_of_space = PosProof::default();
    println!("CONTROL A-1 proof_of_space=default -> Err(InvalidProofOfSpace) : {:?}", check(&mutada, &c.params, c.slot).map(|d| format!("Ok({d})")));
    let mut mutada = c.primera.clone();
    mutada.chunk = Scalar::from([0x18; ScalarBytes::SAFE_BYTES]).into();
    println!("CONTROL A-2 chunk mutado -> Err(InvalidChunkWitness) : {:?}", check(&mutada, &c.params, c.slot).map(|d| format!("Ok({d})")));
    let mut mutada = c.primera.clone();
    mutada.chunk_witness = ChunkWitness::default();
    println!("CONTROL A-3 chunk_witness=default -> Err(InvalidChunkWitness) : {:?}", check(&mutada, &c.params, c.slot).map(|d| format!("Ok({d})")));
    let mut mutada = c.primera.clone();
    mutada.record_witness = Default::default();
    println!("CONTROL A-4 record_witness=default -> Err(InvalidPiece) : {:?}", check(&mutada, &c.params, c.slot).map(|d| format!("Ok({d})")));
    let mut mutada = c.primera.clone();
    mutada.piece_offset = PieceOffset::from(1);
    println!("CONTROL A-5 piece_offset=1 -> Err(InvalidProofOfSpace) : {:?}", check(&mutada, &c.params, c.slot).map(|d| format!("Ok({d})")));

    println!("CONTROL B+  PoS sola K=20 valida : {}", op_b_pos(c));
    println!("CONTROL B-  PoS sola proof=default : {}", <ChiaTable as SolutionPotVerifier>::is_proof_valid(&c.sector.derive_evaluation_seed(c.primera.piece_offset), c.audit_bucket, &PosProof::default()));
    println!("CONTROL B+  Kzg::verify chunk valido : {}", op_b_kzg(c));
    println!("CONTROL B-  Kzg::verify chunk mutado : {}", c.kzg.verify(&c.record_commitment, Record::NUM_S_BUCKETS, c.audit_bucket, &Scalar::from([0x18; ScalarBytes::SAFE_BYTES]), &Witness::try_from(c.primera.chunk_witness).expect("w")));

    println!("CONTROL C+  sello sobre prefirma 492 B : {:?}", op_c(c).map(|()| "Ok"));
    let mut prefirma_mutada = c.base_556;
    prefirma_mutada[0] ^= 0x01;
    println!(
        "CONTROL C-  prefirma mutada : {:?}",
        verificar(&ClavePublica::desde_bytes(c.clave), &Firma::desde_bytes(c.sello), &prefirma_mutada[..TAMANO_PREFIRMA]).map(|()| "Ok")
    );

    let cabecera = BlockHeader {
        consensus_branch_id: 0xc478_80ea,
        prev_hash: BlockHash::from_digest(Digest::from_bytes([0x11; 32])),
        merkle_root: MerkleRoot::from_digest(Digest::from_bytes([0x22; 32])),
        timestamp: 1_767_225_600,
        bits: 0x1d00_ffff,
        nonce: 0,
        height: 1,
    };
    let block_hash = cabecera.block_hash();
    let preimagen = cabecera.preimagen_pow();
    let mut hasher = Sha3_256::new();
    hasher.update(TAG_BLK_HEADER);
    hasher.update(&preimagen[16..]);
    let replica: [u8; 32] = hasher.finalize().into();
    println!("CONTROL D+  replica H_d == block_hash (92 B) : {} == {}", replica == *block_hash.as_bytes(), hex::encode(block_hash.as_bytes()));
    println!("CONTROL D+  replica H_d(556) determinista : {}", op_d556(&c.base_556) == op_d556(&c.base_556));

    println!("CONTROL E+  merkle 571 determinista : {}", merkle_root(txids571) == merkle_root(txids571));
    let mut txids_mutados = txids571.to_vec();
    txids_mutados[100] = TxId::from_digest(Digest::from_bytes([0xEE; 32]));
    println!("CONTROL E-  merkle 571 mutado difiere : {}", merkle_root(txids571) != merkle_root(&txids_mutados));

    let mut just_mutada = cache150.to_vec();
    just_mutada[0][0] ^= 0x01;
    println!("CONTROL F+  justificacion identica (1 slot) : {}", op_f(cache150, cache150, 1));
    println!("CONTROL F+  justificacion identica (150 slots) : {}", op_f(cache150, cache150, S_MAX));
    println!("CONTROL F-  justificacion mutada (150 slots) : {}", op_f(cache150, &just_mutada, S_MAX));
}

fn controles_g(seed: PotSeed, iterations: NonZeroU32, checkpoints: &pot_estable::tipos::PotCheckpoints) {
    println!(
        "CONTROL G+  verify auto : {}",
        pot_estable::verify(seed, iterations, checkpoints).expect("auto")
    );
    for ruta in [Ruta::Avx512fVaes, Ruta::Avx2Vaes, Ruta::AesSse41, Ruta::Generica] {
        println!(
            "CONTROL G+  verify_con_ruta {ruta:?} : {}",
            pot_estable::verify_con_ruta(seed, iterations, checkpoints, ruta).expect("ruta")
        );
    }
    let mut mutados = *checkpoints;
    mutados[0][0] ^= 0x01;
    for ruta in [Ruta::Avx512fVaes, Ruta::Avx2Vaes, Ruta::AesSse41, Ruta::Generica] {
        println!(
            "CONTROL G-  checkpoint mutado {ruta:?} : {}",
            pot_estable::verify_con_ruta(seed, iterations, &mutados, ruta).expect("ruta")
        );
    }
}

// ── Entrada principal ───────────────────────────────────────────────────────

fn uso() -> ! {
    eprintln!(
        "uso: coste-salto lote [--lote N] [--solo A,B,C,D,E,F,G,H] [--csv RUTA] [--ocupado RUTA]\n\
         \x20    coste-salto comparar [--csv RUTA]\n\
         \x20    coste-salto perfil --op A|G --n N   (para `perf stat -r 5`, LINEO §6)"
    );
    std::process::exit(1)
}

/// Repite SOLO la operación indicada `n` veces, sin E/S ni CSV, para que
/// `perf stat -r 5 ./coste-salto perfil --op A --n 20000` mida
/// mayoritariamente el bucle y no la construcción del contexto (LINEO.md,
/// «captura de entorno del §1» y protocolo de perfilado §6). El número de
/// llamadas se divide a mano sobre las cuentas que imprime `perf`.
fn modo_perfil(args: &[String]) {
    let op = arg_valor(args, "--op").unwrap_or_else(|| "A".into());
    let n: u64 = arg_valor(args, "--n").and_then(|v| v.parse().ok()).unwrap_or(1000);
    let contexto = construir_contexto().expect("contexto PoAS");
    match op.as_str() {
        "A" => {
            for _ in 0..n {
                op_a(black_box(&contexto));
            }
        }
        "G" => {
            let mut g_seed_bytes = [0u8; 16];
            {
                use rand_chacha::ChaCha8Rng;
                use rand_core::{RngCore, SeedableRng};
                let mut rng = ChaCha8Rng::from_seed(Default::default());
                rng.fill_bytes(&mut g_seed_bytes);
            }
            let g_seed = PotSeed::from(g_seed_bytes);
            let g_iterations = NonZeroU32::new(POT_ITERACIONES).expect("iteraciones > 0");
            let g_checkpoints = pot_estable::prove(g_seed, g_iterations).expect("prove");
            for _ in 0..n {
                op_g(black_box(g_seed), black_box(g_iterations), black_box(&g_checkpoints), Ruta::Avx512fVaes);
            }
        }
        otro => {
            eprintln!("perfil: op desconocida {otro} (usa A o G)");
            std::process::exit(1);
        }
    }
    eprintln!("perfil: {op} x {n} completado");
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        uso();
    }
    match args[1].as_str() {
        "lote" => modo_lote(&args[2..]),
        "comparar" => modo_comparar(&args[2..]),
        "perfil" => modo_perfil(&args[2..]),
        _ => uso(),
    }
}

fn arg_valor(args: &[String], clave: &str) -> Option<String> {
    args.iter()
        .position(|a| a == clave)
        .and_then(|i| args.get(i + 1).cloned())
}

fn modo_lote(args: &[String]) {
    let lote: u32 = arg_valor(args, "--lote")
        .and_then(|v| v.parse().ok())
        .unwrap_or(1);
    let solo: Option<Vec<String>> = arg_valor(args, "--solo").map(|v| {
        v.split(',')
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
            .collect()
    });
    let csv_ruta = arg_valor(args, "--csv").unwrap_or_else(|| "resultados/MEDICIONES.csv".into());
    if let Some(ocupado) = arg_valor(args, "--ocupado") {
        if std::path::Path::new(&ocupado).exists() {
            eprintln!("ABORTO: {ocupado} presente; no se mide durante cálculo ajeno");
            std::process::exit(2);
        }
    }
    let incluye = |id: &str| solo.as_ref().is_none_or(|s| s.iter().any(|x| x == id));

    let csv_path = std::path::Path::new(&csv_ruta);
    if let Some(dir) = csv_path.parent() {
        if !dir.as_os_str().is_empty() {
            std::fs::create_dir_all(dir).expect("crear resultados/");
        }
    }
    let nuevo = !csv_path.exists();
    let mut csv = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(csv_path)
        .expect("abrir csv");
    if nuevo {
        writeln!(&mut csv, "operacion,detalle,lote,muestra,ns").expect("cabecera csv");
    }

    let contexto = construir_contexto().expect("contexto PoAS");

    // E · txids deterministas por semilla (SHA3-256 desnudo de zx-core).
    let txids_de = |n: usize, semilla: u8| -> Vec<TxId> {
        (0..n)
            .map(|i| {
                let mut buf = [0u8; 5];
                buf[0] = semilla;
                buf[1..].copy_from_slice(&(i as u32).to_le_bytes());
                TxId::from_digest(zx_core::sha3_256_publico(&buf))
            })
            .collect()
    };
    let txids571 = txids_de(571, 0x2e);
    let txids4464 = txids_de(4464, 0x2e);

    // F · caché de slots y justificación que acompaña al bloque.
    let mut cache150: Vec<[u8; JUSTIFICACION_SLOT]> = Vec::with_capacity(S_MAX);
    for slot in 0..S_MAX as u64 {
        let mut slot_bytes = [0u8; JUSTIFICACION_SLOT];
        for (i, b) in slot_bytes.iter_mut().enumerate() {
            *b = slot.wrapping_mul(7).wrapping_add(i as u64) as u8;
        }
        cache150.push(slot_bytes);
    }

    // G · mismo método de semilla que el ancla (benches/pot.rs @ f8842d0).
    let mut g_seed_bytes = [0u8; 16];
    {
        use rand_chacha::ChaCha8Rng;
        use rand_core::{RngCore, SeedableRng};
        let mut rng = ChaCha8Rng::from_seed(Default::default());
        rng.fill_bytes(&mut g_seed_bytes);
    }
    let g_seed = PotSeed::from(g_seed_bytes);
    let g_iterations = NonZeroU32::new(POT_ITERACIONES).expect("iteraciones > 0");

    println!("=== CONTROLES (no cronometrados) ===");
    controles(&contexto, &txids571, &cache150);
    controles_h();
    if incluye("G") {
        // prove una sola vez (ruta por defecto de `create`, AES-NI); la
        // construcción NO se cronometra.
        let g_checkpoints = pot_estable::prove(g_seed, g_iterations).expect("prove");
        controles_g(g_seed, g_iterations, &g_checkpoints);
        println!("=== MEDICIONES (lote {lote}) ===");
        println!(
            "G semilla={} checkpoints[0]={} checkpoints[7]={}",
            hex::encode(g_seed_bytes),
            hex::encode(g_checkpoints[0].iter().copied().collect::<Vec<_>>()),
            hex::encode(g_checkpoints[7].iter().copied().collect::<Vec<_>>())
        );
        // Binario `target-soft` (RUSTFLAGS='--cfg aes_backend="soft"', 3.2): SOLO
        // se mide G-pot-aes-soft (ruta genérica, ahora AES por software real);
        // ninguna otra operación de ese binario se publica (aes_sse41 se
        // ralentiza ~50 % con ese cfg global, sin explicación encontrada — ver
        // DIFF.md «Corrección 1»).
        let rutas: Vec<(Ruta, &str)> = if cfg!(aes_backend = "soft") {
            vec![(Ruta::Generica, "G-pot-aes-soft")]
        } else {
            vec![
                (Ruta::Avx512fVaes, "G-pot-avx512f_vaes"),
                (Ruta::Avx2Vaes, "G-pot-avx2_vaes"),
                (Ruta::AesSse41, "G-pot-aes_sse41"),
                (Ruta::Generica, "G-pot-crate-aes"),
            ]
        };
        for (ruta, id) in rutas {
            // Sondeo del coste para elegir nº de muestras (≥10 si tarda segundos).
            let t = Instant::now();
            op_g(g_seed, g_iterations, &g_checkpoints, ruta);
            let una = t.elapsed().as_secs_f64();
            let n = if una > 1.0 {
                10
            } else if una > 0.2 {
                15
            } else {
                30
            };
            let mut m = Medicion::nueva(id, format!("{POT_ITERACIONES} iteraciones; 8 checkpoints"), 1);
            let s = m.ejecutar(
                || { op_g(g_seed, g_iterations, &g_checkpoints, ruta); },
                n, 3, 1_500, 5, lote, &mut csv,
            );
            println!(
                "G {id:<22} n={n} med={:.3} ms p10={:.3} p90={:.3} min={:.3} cv={:.4}",
                s.mediana / 1e6, s.p10 / 1e6, s.p90 / 1e6, s.min / 1e6, s.cv
            );
        }
    } else {
        println!("=== MEDICIONES (lote {lote}) ===");
    }

    if incluye("A") {
        let mut m = Medicion::nueva("A", "verify_solution ChiaTable K=20; piece_check_params".into(), 1);
        let s = m.ejecutar(|| { op_a(&contexto); }, 100, 10, 500, 50, lote, &mut csv);
        println!("A  n=100 med={:.3} µs p10={:.3} p90={:.3} min={:.3} cv={:.4}", s.mediana / 1e3, s.p10 / 1e3, s.p90 / 1e3, s.min / 1e3, s.cv);
    }
    if incluye("B") {
        let mut m = Medicion::nueva("B-pos", "PoS sola ChiaTable K=20".into(), 1);
        let s = m.ejecutar(|| { assert!(op_b_pos(&contexto)); }, 50, 10, 500, 50, lote, &mut csv);
        println!("B-pos n=50 med={:.3} µs p10={:.3} p90={:.3} min={:.3} cv={:.4}", s.mediana / 1e3, s.p10 / 1e3, s.p90 / 1e3, s.min / 1e3, s.cv);
        let mut m = Medicion::nueva("B-kzg", "Kzg::verify chunk (NUM_S_BUCKETS)".into(), 1);
        let s = m.ejecutar(|| { assert!(op_b_kzg(&contexto)); }, 50, 10, 500, 50, lote, &mut csv);
        println!("B-kzg n=50 med={:.3} µs p10={:.3} p90={:.3} min={:.3} cv={:.4}", s.mediana / 1e3, s.p10 / 1e3, s.p90 / 1e3, s.min / 1e3, s.cv);

        let (hist_commitment, hist_witness, hist_value, hist_n, hist_idx) =
            construir_kzg_hist(&contexto.kzg).expect("fixture kzg-hist");
        println!("CONTROL B+  kzg-hist verify valido : {}", op_b_kzg_hist(&contexto.kzg, &hist_commitment, hist_n, hist_idx, &hist_value, &hist_witness));
        println!("CONTROL B-  kzg-hist verify mutado : {}", contexto.kzg.verify(&hist_commitment, hist_n, hist_idx, &Scalar::from([0x18; ScalarBytes::SAFE_BYTES]), &hist_witness));
        let mut m = Medicion::nueva("B-kzg-hist", "Kzg::verify parametros del banco historico (RawRecord::NUM_CHUNKS, indice 0)".into(), 1);
        let s = m.ejecutar(|| { assert!(op_b_kzg_hist(&contexto.kzg, &hist_commitment, hist_n, hist_idx, &hist_value, &hist_witness)); }, 50, 10, 500, 50, lote, &mut csv);
        println!("B-kzg-hist n=50 med={:.3} µs p10={:.3} p90={:.3} min={:.3} cv={:.4}", s.mediana / 1e3, s.p10 / 1e3, s.p90 / 1e3, s.min / 1e3, s.cv);
    }
    if incluye("C") {
        let mut m = Medicion::nueva("C", "sello Ed25519 ZIP-215 sobre 492 B".into(), 1);
        let s = m.ejecutar(|| { assert!(op_c(&contexto).is_ok()); }, 100, 10, 500, 50, lote, &mut csv);
        println!("C  n=100 med={:.3} µs p10={:.3} p90={:.3} min={:.3} cv={:.4}", s.mediana / 1e3, s.p10 / 1e3, s.p90 / 1e3, s.min / 1e3, s.cv);
    }
    if incluye("D") {
        let cabecera = BlockHeader {
            consensus_branch_id: 0xc478_80ea,
            prev_hash: BlockHash::from_digest(Digest::from_bytes([0x11; 32])),
            merkle_root: MerkleRoot::from_digest(Digest::from_bytes([0x22; 32])),
            timestamp: 1_767_225_600,
            bits: 0x1d00_ffff,
            nonce: 0,
            height: 1,
        };
        let mut m = Medicion::nueva("D-92", "block_hash cabecera 92 B (x100; dividido)".into(), 100);
        let s = m.ejecutar(|| { for _ in 0..100 { op_d92(&cabecera); } }, 300, 10, 300, 50, lote, &mut csv);
        println!("D-92 n=300 med={:.3} µs p10={:.3} p90={:.3} min={:.3} cv={:.4}", s.mediana / 1e3, s.p10 / 1e3, s.p90 / 1e3, s.min / 1e3, s.cv);
        let mut m = Medicion::nueva("D-556", "H_d replica sha3 0.12.0 sobre 556 B (x100; dividido)".into(), 100);
        let s = m.ejecutar(|| { for _ in 0..100 { op_d556(&contexto.base_556); } }, 300, 10, 300, 50, lote, &mut csv);
        println!("D-556 n=300 med={:.3} µs p10={:.3} p90={:.3} min={:.3} cv={:.4}", s.mediana / 1e3, s.p10 / 1e3, s.p90 / 1e3, s.min / 1e3, s.cv);
    }
    if incluye("E") {
        let mut m = Medicion::nueva("E-571", "merkle_root 571 txids".into(), 1);
        let s = m.ejecutar(|| { op_e(&txids571); }, 100, 10, 500, 50, lote, &mut csv);
        println!("E-571 n=100 med={:.3} µs p10={:.3} p90={:.3} min={:.3} cv={:.4}", s.mediana / 1e3, s.p10 / 1e3, s.p90 / 1e3, s.min / 1e3, s.cv);
        let mut m = Medicion::nueva("E-4464", "merkle_root 4464 txids (techo Q1)".into(), 1);
        let s = m.ejecutar(|| { op_e(&txids4464); }, 30, 5, 500, 30, lote, &mut csv);
        println!("E-4464 n=30 med={:.3} µs p10={:.3} p90={:.3} min={:.3} cv={:.4}", s.mediana / 1e3, s.p10 / 1e3, s.p90 / 1e3, s.min / 1e3, s.cv);
    }
    if incluye("F") {
        let mut m = Medicion::nueva("F-1", "justificacion PoT vs cache; 1 slot x128 B (x10000; dividido)".into(), 10_000);
        let s = m.ejecutar(|| { for _ in 0..10_000 { assert!(op_f(&cache150, &cache150, 1)); } }, 300, 10, 500, 50, lote, &mut csv);
        println!("F-1 n=300 med={:.3} µs p10={:.3} p90={:.3} min={:.3} cv={:.4}", s.mediana / 1e3, s.p10 / 1e3, s.p90 / 1e3, s.min / 1e3, s.cv);
        let mut m = Medicion::nueva("F-150", "justificacion PoT vs cache; 150 slots (S_max; x100; dividido)".into(), 100);
        let s = m.ejecutar(|| { for _ in 0..100 { assert!(op_f(&cache150, &cache150, S_MAX)); } }, 100, 5, 500, 50, lote, &mut csv);
        println!("F-150 n=100 med={:.3} µs p10={:.3} p90={:.3} min={:.3} cv={:.4}", s.mediana / 1e3, s.p10 / 1e3, s.p90 / 1e3, s.min / 1e3, s.cv);
    }
    if incluye("H") {
        let bytes571 = construir_lote_h(571);
        let bytes4464 = construir_lote_h(4464);
        let tam_tx = bytes571[0].len();

        let mut m = Medicion::nueva("H-571", format!("decode+txid 571 tx sinteticas ({tam_tx} B/tx)"), 1);
        let s = m.ejecutar(|| { op_h(&bytes571); }, 30, 5, 500, 30, lote, &mut csv);
        println!("H-571 n=30 med={:.3} µs p10={:.3} p90={:.3} min={:.3} cv={:.4}", s.mediana / 1e3, s.p10 / 1e3, s.p90 / 1e3, s.min / 1e3, s.cv);

        let mut m = Medicion::nueva("H-4464", format!("decode+txid 4464 tx sinteticas ({tam_tx} B/tx)"), 1);
        let s = m.ejecutar(|| { op_h(&bytes4464); }, 30, 5, 500, 30, lote, &mut csv);
        println!("H-4464 n=30 med={:.3} µs p10={:.3} p90={:.3} min={:.3} cv={:.4}", s.mediana / 1e3, s.p10 / 1e3, s.p90 / 1e3, s.min / 1e3, s.cv);

        // Decodificado FUERA de lo cronometrado, para H-txid.
        let txs571: Vec<Tx> = bytes571.iter().map(|b| tx_desde_bytes(b).expect("decodifica").0.0).collect();
        let txs4464: Vec<Tx> = bytes4464.iter().map(|b| tx_desde_bytes(b).expect("decodifica").0.0).collect();

        let mut m = Medicion::nueva("H-txid-571", format!("solo txid 571 tx sinteticas ({tam_tx} B/tx)"), 1);
        let s = m.ejecutar(|| { op_h_txid(&txs571); }, 30, 5, 500, 30, lote, &mut csv);
        println!("H-txid-571 n=30 med={:.3} µs p10={:.3} p90={:.3} min={:.3} cv={:.4}", s.mediana / 1e3, s.p10 / 1e3, s.p90 / 1e3, s.min / 1e3, s.cv);

        let mut m = Medicion::nueva("H-txid-4464", format!("solo txid 4464 tx sinteticas ({tam_tx} B/tx)"), 1);
        let s = m.ejecutar(|| { op_h_txid(&txs4464); }, 30, 5, 500, 30, lote, &mut csv);
        println!("H-txid-4464 n=30 med={:.3} µs p10={:.3} p90={:.3} min={:.3} cv={:.4}", s.mediana / 1e3, s.p10 / 1e3, s.p90 / 1e3, s.min / 1e3, s.cv);
    }
    println!("LOTE {lote} COMPLETO -> {csv_ruta}");
}

fn modo_comparar(args: &[String]) {
    let csv_ruta = arg_valor(args, "--csv").unwrap_or_else(|| "resultados/MEDICIONES.csv".into());
    let contenido = std::fs::read_to_string(&csv_ruta).expect("leer csv");
    let mut grupos: std::collections::BTreeMap<(String, String, u32), Vec<u128>> = Default::default();
    for (i, linea) in contenido.lines().enumerate() {
        if i == 0 { continue; }
        // detalle puede contener comas; se parte por la derecha: ns, muestra y
        // lote no contienen comas.
        let mut it = linea.rsplitn(4, ',');
        let (Some(ns_s), Some(_muestra), Some(lote_s), Some(id_detalle)) =
            (it.next(), it.next(), it.next(), it.next())
        else {
            continue;
        };
        let Some((operacion, detalle)) = id_detalle.split_once(',') else {
            continue;
        };
        let ns: u128 = ns_s.parse().expect("ns");
        let lote: u32 = lote_s.parse().expect("lote");
        grupos.entry((operacion.into(), detalle.into(), lote)).or_default().push(ns);
    }
    let mut lotes: std::collections::BTreeSet<u32> = Default::default();
    for (_, _, l) in grupos.keys() { lotes.insert(*l); }
    let lotes: Vec<u32> = lotes.into_iter().collect();
    println!("operacion,deteccion entre lotes:");
    let mut claves: Vec<(String, String)> = Vec::new();
    for (id, detalle, lote) in grupos.keys() {
        if *lote == lotes[0] && !claves.contains(&(id.clone(), detalle.clone())) {
            claves.push((id.clone(), detalle.clone()));
        }
    }
    for (id, detalle) in claves {
        let mut medianas = Vec::new();
        for &lote in &lotes {
            if let Some(v) = grupos.get(&(id.clone(), detalle.clone(), lote)) {
                let mut ordenadas = v.clone();
                ordenadas.sort_unstable();
                medianas.push((lote, percentil(&ordenadas, 50.0)));
            }
        }
        if medianas.len() < 2 {
            println!("{id:<9} {detalle:<40} solo lote {}", medianas[0].0);
            continue;
        }
        let (l1, m1) = medianas[0];
        let (l2, m2) = medianas[1];
        let diff = 100.0 * (m2 - m1) / m1;
        println!(
            "{id:<9} {detalle:<40} lote{l1}={m1:.3} ns lote{l2}={m2:.3} ns dif={diff:+.2} %"
        );
    }
}
