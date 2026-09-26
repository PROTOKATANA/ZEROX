//! Reproducción RI-3a (revisor independiente de red, `ORDEN-RI-3.md`).
//!
//! Hallazgo: `RedArrancada`/`ManijaRed` (crates/zx-node/src/red/mod.rs) usa
//! `tokio::sync::mpsc::unbounded_channel()` para `TrabajoRed`, la cola por la que
//! `ManejadorRed::bloque_difundido` (crates/zx-node/src/red/manejador.rs) y
//! `sync::atender_respuesta` (crates/zx-node/src/red/sync.rs) entregan bloques al hilo de consenso.
//! Cada bloque de gossipsub que pasa el parseo del códec de `zx-p2p` (formato válido; **no** hace
//! falta que su PoW/PoAS/PoT sea válido, eso lo decide después el hilo de consenso) se clona
//! íntegro y se encola **sin ningún tope**, ni de número de elementos ni de bytes. Si el hilo de
//! consenso se queda por detrás del ritmo de llegada (un bloque PoST real tarda del orden de
//! decenas de milisegundos en verificar PoT+PoAS, según la documentación del propio módulo), la cola
//! crece sin límite: no hay *backpressure*, no hay descarte determinista, no hay nada análogo al
//! `MAX_DIFERIDOS_PENDIENTES` (4 096) que sí tiene la tabla de correlación de `zx-p2p`.
//!
//! Este test demuestra la ausencia de tope: encola muchos más elementos que
//! `zx_p2p::limites::MAX_DIFERIDOS_PENDIENTES` sin que el productor espere ni falle nunca, y sin
//! que nadie lea del otro extremo. `V-ZRX/LINEO.md`: sin Python; sin aleatoriedad; documentado con
//! el comando exacto en el informe.

use std::sync::Arc;
use std::time::Instant;

use zx_core::digest::{BlockHash, Digest, MerkleRoot};
use zx_core::preimage::block::BlockHeader;
use zx_core::red::Red;
use zx_node::red::manejador::ManejadorRed;
use zx_node::red::vista::VistaRed;
use zx_p2p::entrante::{IdDiferido, ManejadorEntrante, Veredicto};
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

fn bloque(n: u32) -> BloqueRed {
    BloqueRed::Pow {
        cabecera: BlockHeader {
            consensus_branch_id: 0xa8b4_66a7,
            prev_hash: h(n),
            merkle_root: MerkleRoot::from_digest(Digest::from_bytes([0x11; 32])),
            timestamp: 1_000 + u64::from(n),
            bits: 0x1c07_fff8,
            nonce: u64::from(n),
            height: n,
        },
        txs: Vec::new(),
        testigos: Vec::new(),
    }
}

/// **CONFIRMADO.** La cola `TrabajoRed` no tiene tope: acepta muchísimos más elementos que
/// `MAX_DIFERIDOS_PENDIENTES` (la cota que sí existe en `zx-p2p` para la tabla de correlación) sin
/// bloquear al productor ni descartar nada, aunque nadie lea del otro extremo.
#[test]
fn la_cola_de_trabajo_hacia_consenso_no_tiene_tope() {
    let (tx, rx) = tokio::sync::mpsc::unbounded_channel();
    let vista = Arc::new(VistaRed::nueva(estado_vacio()));
    let m = ManejadorRed::nuevo(tx, vista);

    // Un orden de magnitud por encima de MAX_DIFERIDOS_PENDIENTES (4 096) de zx-p2p, para mostrar
    // que aquí no hay un tope equivalente.
    let n: u32 = zx_p2p::limites::MAX_DIFERIDOS_PENDIENTES as u32 * 10;
    assert!(n > 40_000);

    let inicio = Instant::now();
    for i in 0..n {
        // `bloque_difundido` es exactamente lo que `zx-p2p` llama por cada mensaje de gossipsub que
        // pasa el parseo del códec (`servicio.rs::despachar`): no requiere PoW/PoAS válidos.
        let v = m.bloque_difundido(IdDiferido::default(), &bloque(i));
        assert_eq!(v, Veredicto::Diferir, "siempre difiere y encola (manejador.rs)");
    }
    let transcurrido = inicio.elapsed();

    assert_eq!(
        rx.len(),
        n as usize,
        "los {n} bloques quedan todos en cola: nada los ha leído, descartado ni limitado"
    );

    eprintln!(
        "RI-3a: {n} bloques encolados en {transcurrido:?} sin backpressure ni tope \
         (MAX_DIFERIDOS_PENDIENTES de zx-p2p = {}); la cola sigue creciendo mientras el \
         hilo de consenso no la vacíe",
        zx_p2p::limites::MAX_DIFERIDOS_PENDIENTES
    );
}
