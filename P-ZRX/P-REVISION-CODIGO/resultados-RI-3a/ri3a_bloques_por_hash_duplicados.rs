//! Reproducción RI-3a (revisor independiente de red, `ORDEN-RI-3.md`).
//!
//! Hallazgo: `VistaRed::bloques_por_hash` (crates/zx-node/src/red/vista.rs) no deduplica los hashes
//! pedidos, y `ManejadorRed::bloques_por_hash` (crates/zx-node/src/red/manejador.rs) los pasa tal
//! cual. Una `Peticion::Bloques` acepta hasta `zx_p2p::limites::MAX_HASHES_POR_PETICION` (256)
//! hashes, sin exigir que sean distintos (el códec de `zx-p2p` solo comprueba la **cuenta**, no la
//! unicidad: `codec.rs::leer_hashes`). El recorte a `MAX_BLOQUES_POR_RESPUESTA` (16) ocurre **después**
//! —en `zx_p2p::servicio::BucleRed::servir`, llamando a `recortar` sobre el vector ya construido—,
//! así que el manejador ya clonó el bloque completo tantas veces como hashes se pidieron.
//!
//! Consecuencia: un par pide, en una única petición pequeña (unos 8 KiB: 256 hashes de 32 B), el
//! **mismo** hash de un bloque grande ya admitido 256 veces. El nodo clona ese bloque 256 veces
//! —hasta `256 × MAX_BLOQUE_RED_BYTES` en el peor caso— **antes** de descartar 240 de esas copias sin
//! usarlas. Esa construcción ocurre dentro de `servir()`, en el mismo hilo que pollea el `Swarm`
//! (`atender_swarm → atender_sync → servir`): mientras dura, la red entera deja de atenderse, no solo
//! el par que preguntó.
//!
//! Este test mide, con un bloque de tamaño moderado (para no gastar minutos), que pedir el mismo
//! hash `k` veces produce exactamente `k` clones completos del bloque, sin deduplicar — el trabajo
//! desperdiciado que después tira `recortar` en `zx-p2p`. `V-ZRX/LINEO.md`: sin Python; sin
//! aleatoriedad; medido con `Instant`, no con una suposición.

use std::sync::Arc;
use std::time::Instant;

use zx_core::amount::Amount;
use zx_core::digest::{BlockHash, Digest, MerkleRoot, TxId};
use zx_core::firma::ClavePublica;
use zx_core::preimage::block::BlockHeader;
use zx_core::red::Red;
use zx_core::tx::{ExtensionTx, Lock, OutPoint, Tx, TxIn, TxOut};
use zx_node::red::manejador::ManejadorRed;
use zx_node::red::vista::VistaRed;
use zx_p2p::entrante::ManejadorEntrante;
use zx_p2p::mensaje::{BloqueRed, Estado, Fase, PuntaPow};

fn h(n: u32) -> BlockHash {
    let mut b = [0u8; 32];
    b[..4].copy_from_slice(&n.to_le_bytes());
    BlockHash::from_digest(Digest::from_bytes(b))
}

fn estado_vacio() -> Estado {
    Estado {
        hash_genesis: h(0),
        red: Red::Dev,
        fase: Fase::Pow,
        punta_pow: PuntaPow {
            hash: h(0),
            altura: 0,
            trabajo_acumulado: [0; 32],
        },
        terminal: None,
        puntas_post: Vec::new(),
        blue_work_virtual: [0; 32],
    }
}

fn tx_simple(n: u32) -> Tx {
    Tx {
        version: 1,
        inputs: vec![TxIn {
            outpoint: OutPoint {
                prev_txid: TxId::from_digest(Digest::from_bytes([(n % 251) as u8; 32])),
                prev_index: 0,
            },
            sequence: 0,
        }],
        outputs: vec![TxOut {
            value: Amount::nuevo(1_000).unwrap(),
            lock: Lock::PubKey {
                pubkey: ClavePublica::desde_bytes([(n % 251) as u8; 32]),
            },
        }],
        lock_time: 0,
        expiry_height: 0,
        extension: ExtensionTx::Ninguna,
    }
}

/// Un bloque PoW "grande" (miles de transacciones simples) para que clonarlo repetidamente sea
/// medible sin tener que llegar al máximo real de 2 MiB (que solo alargaría el test, no la
/// conclusión).
fn bloque_grande(n_txs: u32) -> BloqueRed {
    let txs: Vec<Tx> = (0..n_txs).map(tx_simple).collect();
    let testigos = vec![vec![vec![0xAAu8; 64]]; n_txs as usize];
    BloqueRed::Pow {
        cabecera: BlockHeader {
            consensus_branch_id: 0xa8b4_66a7,
            prev_hash: h(0),
            merkle_root: MerkleRoot::from_digest(Digest::from_bytes([0x22; 32])),
            timestamp: 1_000,
            bits: 0x1c07_fff8,
            nonce: 1,
            height: 1,
        },
        txs,
        testigos,
    }
}

/// **CONFIRMADO.** Pedir el mismo hash repetido no se deduplica: `k` repeticiones producen `k`
/// clones completos del bloque, muy por encima de `MAX_BLOQUES_POR_RESPUESTA` (16), el único tope
/// que existe y que se aplica **después**, en `zx-p2p`.
#[test]
fn pedir_el_mismo_hash_repetido_clona_el_bloque_una_vez_por_repeticion() {
    const N_TXS: u32 = 4_000; // unas pocas centenas de KB: suficiente para medir, barato de correr.
    const K: usize = zx_p2p::limites::MAX_HASHES_POR_PETICION; // 256: el máximo que permite el códec.

    let bloque = bloque_grande(N_TXS);
    let bytes_bloque = zx_p2p::codec::bloque_a_bytes(&bloque).len();
    println!("RI-3a: bloque de prueba = {bytes_bloque} B ({N_TXS} txs)");

    let vista = Arc::new(VistaRed::nueva(estado_vacio()));
    vista.registrar_pow(0, bloque.clone());
    let hash = zx_node::red::hash_de(&bloque);

    let (tx, _rx) = tokio::sync::mpsc::unbounded_channel();
    let m = ManejadorRed::nuevo(tx, Arc::clone(&vista));

    // Una única "petición" (como la validaría el códec: K <= MAX_HASHES_POR_PETICION) con el
    // MISMO hash repetido K veces. Nada en `codec.rs::leer_hashes` ni en `vista.rs` exige que sean
    // distintos.
    let hashes_repetidos = vec![hash; K];

    let inicio = Instant::now();
    let respuesta = m.bloques_por_hash(&hashes_repetidos);
    let transcurrido = inicio.elapsed();

    assert_eq!(
        respuesta.len(),
        K,
        "las {K} repeticiones del mismo hash producen {K} clones completos, sin deduplicar"
    );
    let bytes_totales_clonados: usize = respuesta
        .iter()
        .map(|b| zx_p2p::codec::bloque_a_bytes(b).len())
        .sum();

    let max_respuesta_real = zx_p2p::limites::MAX_BLOQUES_POR_RESPUESTA; // 16: el único tope, y es POSTERIOR
    assert!(
        K > max_respuesta_real,
        "el ataque solo tiene sentido si se piden más copias de las que jamás se van a servir"
    );

    println!(
        "RI-3a: {K} hashes IDÉNTICOS -> {} clones completos ({bytes_totales_clonados} B en total) \
         en {transcurrido:?}, dentro del hilo que pollea el Swarm; \
         zx-p2p recorta a MAX_BLOQUES_POR_RESPUESTA = {max_respuesta_real} DESPUÉS de este trabajo, \
         no antes: {} de los {} clones se tiran sin usarse",
        respuesta.len(),
        K - max_respuesta_real,
        K
    );

    // El desperdicio es de orden MAX_HASHES_POR_PETICION / MAX_BLOQUES_POR_RESPUESTA: con los
    // valores de producción, 256 / 16 = 16x el trabajo que hacía falta, pagado por una petición
    // de ~8 KiB (256 hashes de 32 B) que cualquier par puede mandar sin coste.
    assert_eq!(K / max_respuesta_real, 16);
}
