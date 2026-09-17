//! Medición LINEO de `reconstruir` (H-02 §2, punto 3).
//!
//! Escenario: `n = 3 000` transacciones anunciadas, `m = 50 000` candidatos de mempool. Se mide el
//! mismo caso varias veces y se publican mínimo, mediana, máximo y dispersión. El cómputo es
//! **secuencial**: `reconstruir` no paraleliza, así que el número de hilos no cambia el resultado.
//!
//! Línea de ejecución (perfil release, dentro de `implementacion-02/`):
//!
//! ```text
//! CARGO_TARGET_DIR=<implementacion-02>/target \
//!   cargo run --offline --locked --release -p zx-p2p --example medir_reconstruccion
//! ```
//!
//! La versión anterior —`O(n·m)` hashes— **no se ejecutó a esta escala**: son ~150 millones de
//! `txid`, fuera del presupuesto de tiempo. No se extrapola; se declara.

#![expect(
    clippy::expect_used,
    clippy::indexing_slicing,
    clippy::integer_division,
    reason = "es un binario de medición: falla con panic por diseño y usa aritmética entera deliberada"
)]

use std::time::{Duration, Instant};

use zx_core::digest::{BlockHash, Digest, MerkleRoot, TxId};
use zx_core::firma::ClavePublica;
use zx_core::preimage::dag::{DagBlockHeader, PadresDag, SolucionPoas};
use zx_core::tx::{Lock, OutPoint, Tx, TxIn, TxOut};
use zx_core::{Amount, txid};

use zx_p2p::id_corto::{ClavesIdCorto, TAMANO_ID_CORTO};
use zx_p2p::rele_compacto::{AnuncioCompacto, CandidatoMempool, reconstruir};

const CBID: u32 = 0xc478_80ea;
const N_ANUNCIADAS: u32 = 3_000;
const M_MEMPOOL: u32 = 50_000;
const REPETICIONES: usize = 10;

fn tx(n: u32) -> Tx {
    let mut prev = [0u8; 32];
    prev[..4].copy_from_slice(&n.to_le_bytes());
    let mut clave = [0u8; 32];
    clave[..4].copy_from_slice(&n.to_le_bytes());
    Tx {
        version: 1,
        inputs: vec![TxIn {
            outpoint: OutPoint {
                prev_txid: TxId::from_digest(Digest::from_bytes(prev)),
                prev_index: 0,
            },
            sequence: 0,
        }],
        outputs: vec![TxOut {
            value: Amount::nuevo(i64::from(n)).unwrap_or(Amount::CERO),
            lock: Lock::PubKey {
                pubkey: ClavePublica::desde_bytes(clave),
            },
        }],
        lock_time: 0,
        expiry_height: 0,
    }
}

fn main() {
    let txs: Vec<Tx> = (1..=N_ANUNCIADAS).map(tx).collect();
    let testigos: Vec<Vec<Vec<u8>>> = (1..=N_ANUNCIADAS)
        .map(|n| vec![vec![n as u8; 64]])
        .collect();
    let txids: Vec<TxId> = txs.iter().map(|t| txid(t, CBID)).collect();
    let nonce = 0x1122_3344_5566_7788u64;

    let cabecera = DagBlockHeader {
        consensus_branch_id: CBID,
        merkle_root: MerkleRoot::from_digest(Digest::from_bytes([0; 32])),
        timestamp: 1_788_480_000,
        height: 1,
        slot: 1,
        pot_output: [0; 16],
        rango_solucion: 1,
        sol: SolucionPoas::default(),
        // El compromiso no interviene en `reconstruir`; se deja nulo a propósito.
        body_commitment: zx_core::BodyCommitment::from_digest(Digest::from_bytes([0; 32])),
        padres: PadresDag::nuevo(BlockHash::from_digest(Digest::from_bytes([9; 32])), &[])
            .expect("padres válidos"),
        sello: [0; 64],
    };

    let claves = ClavesIdCorto::derivar_dag(&cabecera, nonce);
    let ids_restantes: Vec<[u8; TAMANO_ID_CORTO]> =
        txids[1..].iter().map(|t| claves.id(t)).collect();
    let anuncio = AnuncioCompacto::nuevo(
        cabecera,
        nonce,
        txs[0].clone(),
        testigos[0].clone(),
        ids_restantes,
    )
    .expect("anuncio dentro de la cota");

    // Mempool: las 2 000 primeras anunciadas (coinciden) y 48 000 ajenas.
    let mut mempool: Vec<CandidatoMempool> = Vec::with_capacity(M_MEMPOOL as usize);
    for i in 1..2_000u32 {
        mempool.push(CandidatoMempool {
            tx: tx(i),
            testigos: testigos[i as usize].clone(),
        });
    }
    for j in 0..(M_MEMPOOL - 2_000) {
        mempool.push(CandidatoMempool {
            tx: tx(1_000_000 + j),
            testigos: vec![vec![0xEE; 64]],
        });
    }

    // Calentamiento (compilación JIT no aplica en Rust, pero sí cachés de CPU).
    let calentamiento = reconstruir(&anuncio, &mempool);
    let faltantes = calentamiento.faltantes().len();

    let mut tiempos = Vec::with_capacity(REPETICIONES);
    for _ in 0..REPETICIONES {
        let t = Instant::now();
        let rec = reconstruir(&anuncio, &mempool);
        tiempos.push(t.elapsed());
        debug_assert_eq!(rec.faltantes().len(), faltantes);
    }

    tiempos.sort();
    let min = tiempos.first().copied().unwrap_or(Duration::ZERO);
    let max = tiempos.last().copied().unwrap_or(Duration::ZERO);
    let mediana = tiempos[tiempos.len() / 2];
    let media = tiempos.iter().sum::<Duration>() / (tiempos.len() as u32);

    println!(
        "plataforma={} {}",
        std::env::consts::OS,
        std::env::consts::ARCH
    );
    println!(
        "hilos_disponibles={:?}",
        std::thread::available_parallelism()
    );
    println!("perfil=release");
    println!("n_anunciadas={N_ANUNCIADAS} m_mempool={M_MEMPOOL} repeticiones={REPETICIONES}");
    println!(
        "faltantes={faltantes} ambiguos={}",
        calentamiento.ambiguos().len()
    );
    println!("min_ms={:.3}", min.as_secs_f64() * 1e3);
    println!("mediana_ms={:.3}", mediana.as_secs_f64() * 1e3);
    println!("max_ms={:.3}", max.as_secs_f64() * 1e3);
    println!("media_ms={:.3}", media.as_secs_f64() * 1e3);
    println!(
        "dispersion_max_menos_min_ms={:.3}",
        (max - min).as_secs_f64() * 1e3
    );
}
