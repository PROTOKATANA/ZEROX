//! Reproducción RI-3a (revisor independiente de red, `ORDEN-RI-3.md`).
//!
//! Hallazgo: la reserva de `leer_acotado` (crates/zx-p2p/src/codec.rs) se hace por el TAMAÑO MÁXIMO
//! del mensaje (`MAX_RESPUESTA_BYTES`), no por lo que de verdad llega, y se hace ANTES de leer ni un
//! solo byte. Un par que abre unos pocos streams de sincronización y no escribe nada (silencio total,
//! coste cero) retiene esa reserva durante todo `TIMEOUT_SYNC` (30 s) y puede agotar el presupuesto
//! agregado (`Presupuesto`, 256 MiB) usando **menos** streams que el propio tope por conexión
//! (`MAX_STREAMS_SYNC = 8`). Mientras dure, cualquier otra lectura de respuesta —de cualquier par,
//! honesto o no— se rechaza con `OutOfMemory`, aunque su respuesta ya esté completa y esperando en el
//! pipe.
//!
//! Este test no usa un `Swarm`: llama al códec directamente sobre `futures_ringbuf::Endpoint`, igual
//! que los tests propios de `codec.rs`. `V-ZRX/LINEO.md`: nada de Python; determinista (sin RNG);
//! documentado con el comando exacto en el informe.

use std::time::Duration;

use futures::AsyncWriteExt;
use futures_ringbuf::Endpoint;
use libp2p::StreamProtocol;
use libp2p::request_response::Codec;

use zx_p2p::codec::{ZxCodec, respuesta_a_bytes};
use zx_p2p::limites::MAX_RESPUESTA_BYTES;
use zx_p2p::mensaje::{Estado, Fase, PuntaPow, Respuesta};
use zx_p2p::presupuesto::{PRESUPUESTO_BYTES, Presupuesto};
use zx_core::digest::{BlockHash, Digest};
use zx_core::red::Red;

fn proto() -> StreamProtocol {
    StreamProtocol::new("/zx-dev/1")
}

fn h(n: u8) -> BlockHash {
    BlockHash::from_digest(Digest::from_bytes([n; 32]))
}

fn estado_minimo() -> Estado {
    Estado {
        hash_genesis: h(0),
        red: Red::Dev,
        fase: Fase::Pow,
        punta_pow: PuntaPow {
            hash: h(1),
            altura: 0,
            trabajo_acumulado: [0; 32],
        },
        terminal: None,
        puntas_post: vec![],
        blue_work_virtual: [0; 32],
    }
}

/// **CONFIRMADO.** Un solo par silencioso, con menos streams que `MAX_STREAMS_SYNC`, agota el
/// presupuesto agregado de producción y deniega el servicio a un par honesto que ya había mandado
/// su respuesta completa.
#[tokio::test]
async fn un_par_silencioso_agota_el_presupuesto_y_deniega_a_un_par_honesto() {
    let presupuesto = Presupuesto::nuevo(PRESUPUESTO_BYTES);

    // Cuántas lecturas de MAX_RESPUESTA_BYTES caben en el techo real de producción.
    let costo_por_lectura = MAX_RESPUESTA_BYTES + 1; // `leer_acotado` reserva `max + 1`.
    let cabida = (PRESUPUESTO_BYTES as u64) / costo_por_lectura;
    assert!(
        cabida >= 1 && cabida < zx_p2p::limites::MAX_STREAMS_SYNC as u64,
        "cabida = {cabida}: el ataque MUST caber por debajo del propio tope por conexión \
         (MAX_STREAMS_SYNC = {}) para que sea un solo par, no varios",
        zx_p2p::limites::MAX_STREAMS_SYNC
    );

    // El "par atacante": abre `cabida` streams de sincronización y NUNCA escribe nada.
    // `_silencio` se mantiene vivo (no se cierra, no se escribe) para que la lectura del otro
    // extremo se quede esperando datos indefinidamente, exactamente como un peer que abre la
    // conexión y calla.
    let mut silencio = Vec::new();
    let mut tareas = Vec::new();
    for _ in 0..cabida {
        let (a, mut b) = Endpoint::pair(4096, 4096);
        silencio.push(a);
        let p = presupuesto.clone();
        tareas.push(tokio::spawn(async move {
            let mut codec = ZxCodec::con_presupuesto(p);
            let _ = codec.read_response(&proto(), &mut b).await;
        }));
    }

    // Dar tiempo a que las `cabida` tareas hagan su reserva. La reserva ocurre ANTES de leer un
    // solo byte (`leer_acotado`), así que no hace falta que el atacante mande nada.
    tokio::time::sleep(Duration::from_millis(200)).await;

    let reservado_esperado = (cabida * costo_por_lectura) as usize;
    assert_eq!(
        presupuesto.en_vuelo(),
        reservado_esperado,
        "el par silencioso ya reservó {reservado_esperado} B sin mandar un solo byte"
    );
    assert!(
        presupuesto.disponible() < MAX_RESPUESTA_BYTES as usize,
        "ya no cabe ni una lectura de respuesta más: disponible = {}",
        presupuesto.disponible()
    );

    // Un par HONESTO responde de inmediato con un saludo pequeño y válido, ya completo.
    let (mut a_honesto, mut b_honesto) = Endpoint::pair(4096, 4096);
    let bytes = respuesta_a_bytes(&Respuesta::Estado(estado_minimo()));
    a_honesto.write_all(&bytes).await.unwrap();
    a_honesto.close().await.unwrap();

    let mut codec_honesto = ZxCodec::con_presupuesto(presupuesto.clone());
    let err = codec_honesto
        .read_response(&proto(), &mut b_honesto)
        .await
        .expect_err("MUST rechazarse: no queda presupuesto, aunque la respuesta ya esté completa");
    assert_eq!(err.kind(), std::io::ErrorKind::OutOfMemory);
    assert!(err.to_string().contains("C-NET-21"), "{err}");

    for t in tareas {
        t.abort();
    }
}
