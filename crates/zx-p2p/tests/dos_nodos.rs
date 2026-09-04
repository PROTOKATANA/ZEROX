//! Arnés de dos nodos sobre transporte **en memoria** (SPEC §16).
//!
//! # Por qué se construye a mano y no con `libp2p-swarm-test`
//!
//! `swarm-test` es el crate de utilidades del propio libp2p y para dos nodos sería más corto. Pero
//! su `listen()` escucha **siempre en TCP real** además de en memoria, sin importar qué helper se
//! use después (`swarm-test/src/lib.rs:397-441`), y eso tiene dos consecuencias:
//!
//! 1. Con **mDNS** activo —y testnet lo tiene, por C-NET-14— el nodo empieza a descubrir a los
//!    vecinos reales de la LAN. Es el issue #6062 de rust-libp2p, todavía abierto: el reportante ve
//!    `Discovered(...)` con IPs de Docker en un test que creía hermético.
//! 2. `ListenFuture::wait` hace **`panic!`** ante un evento inesperado. Con mDNS eso convierte a
//!    cualquier vecino de la red en una causa de fallo intermitente.
//!
//! Así que el transporte es `MemoryTransport` **puro**, siguiendo el patrón de
//! `protocols/kad/src/behaviour/test.rs`, que construye redes de hasta 20 nodos así.
//!
//! # Lo que este arnés NO cubre, y conviene tenerlo escrito
//!
//! - **Latencia, pérdida y reordenamiento reales.** `MemoryTransport` son canales `mpsc` de 4096.
//! - **NAT y hole punching.** Necesitan procesos y contenedores reales.
//! - **Caída de proceso.** Aquí "caer" un nodo es soltar su `Swarm`: prueba el cierre limpio, no un
//!   `kill -9` con estado a medio escribir.
//! - **Determinismo estricto.** Es hermético y rápido, no reproducible byte a byte: el orden de
//!   entrega sigue dependiendo del planificador.

#![expect(clippy::expect_used, reason = "los tests fallan con panic por diseño")]

use std::sync::Arc;
use std::sync::atomic::{AtomicU64, AtomicUsize, Ordering};
use std::time::Duration;

use libp2p::core::transport::{MemoryTransport, Transport};
use libp2p::core::upgrade;
use libp2p::{Multiaddr, Swarm, identity, noise, yamux};
use zx_core::digest::{BlockHash, Digest};
use zx_core::preimage::block::BlockHeader;
use zx_core::red::Red;
use zx_p2p::behaviour::ZxBehaviour;
use zx_p2p::config::ParametrosRed;
use zx_p2p::entrante::{ManejadorEntrante, Veredicto};
use zx_p2p::limites;
use zx_p2p::mensaje::{BloqueRed, Estado};
use zx_p2p::servicio::{EventoRed, arrancar};

/// Manejador de juguete que solo cuenta llamadas.
#[derive(Default)]
struct Contador {
    bloques: AtomicUsize,
    txs: AtomicUsize,
}

impl ManejadorEntrante for Contador {
    fn estado(&self) -> Estado {
        Estado {
            genesis: BlockHash::from_digest(Digest::from_bytes([0; 32])),
            tip: BlockHash::from_digest(Digest::from_bytes([1; 32])),
            altura: 0,
            trabajo: [0; 32],
        }
    }
    fn bloque_difundido(&self, _: &BloqueRed) -> Veredicto {
        self.bloques.fetch_add(1, Ordering::Relaxed);
        Veredicto::Aceptar
    }
    fn tx_difundida(&self, _: &[u8]) -> Veredicto {
        self.txs.fetch_add(1, Ordering::Relaxed);
        Veredicto::Aceptar
    }
    fn cabeceras_desde(&self, _: &[BlockHash], _: Option<BlockHash>) -> Vec<BlockHeader> {
        Vec::new()
    }
    fn bloques_por_hash(&self, _: &[BlockHash]) -> Vec<BloqueRed> {
        Vec::new()
    }
}

/// Un `Swarm` sobre transporte en memoria. **Sin TCP**, a diferencia de `swarm-test`.
fn nodo_en_memoria() -> Swarm<ZxBehaviour> {
    let clave = identity::Keypair::generate_ed25519();
    let peer_id = clave.public().to_peer_id();

    let transporte = MemoryTransport::default()
        .upgrade(upgrade::Version::V1)
        .authenticate(noise::Config::new(&clave).expect("noise"))
        .multiplex(yamux::Config::default())
        .boxed();

    let behaviour = ZxBehaviour::nueva(
        &clave,
        ParametrosRed::de(Red::Testnet),
        limites::LIMITE_BLOQUE_GENESIS,
    )
    .expect("behaviour");

    Swarm::new(
        transporte,
        behaviour,
        peer_id,
        libp2p::swarm::Config::with_tokio_executor()
            // Los tests no deben depender de que la conexión sobreviva a un hueco de tráfico.
            .with_idle_connection_timeout(Duration::from_secs(30)),
    )
}

/// Una dirección de memoria distinta por test, para que no colisionen en paralelo.
fn addr_memoria() -> Multiaddr {
    static SIGUIENTE: AtomicU64 = AtomicU64::new(40_001);
    let puerto = SIGUIENTE.fetch_add(1, Ordering::Relaxed);
    format!("/memory/{puerto}").parse().expect("multiaddr")
}

/// Espera al primer evento que cumpla el predicado, con tope de tiempo.
///
/// Se espera **al evento concreto**, no a que pase un rato. Un `sleep` fijo es la receta de los
/// tests intermitentes: pasa en tu máquina y falla en un CI cargado. Es exactamente el antipatrón
/// que rust-libp2p documenta en su issue #6421.
async fn esperar<F>(rx: &mut tokio::sync::mpsc::Receiver<EventoRed>, f: F) -> Option<EventoRed>
where
    F: Fn(&EventoRed) -> bool,
{
    let plazo = tokio::time::Instant::now() + Duration::from_secs(10);
    loop {
        let resto = plazo.saturating_duration_since(tokio::time::Instant::now());
        if resto.is_zero() {
            return None;
        }
        match tokio::time::timeout(resto, rx.recv()).await {
            Ok(Some(e)) if f(&e) => return Some(e),
            Ok(Some(_)) => {}
            Ok(None) | Err(_) => return None,
        }
    }
}

/// **Dos nodos se encuentran y se ven.**
///
/// Demuestra que el bucle de eventos hace su trabajo: escucha, marca, y ambos extremos reciben
/// `PeerConectado`. Sin sockets reales y sin dormir a ciegas.
#[tokio::test]
async fn dos_nodos_se_conectan_y_se_ven() {
    let piezas_a = arrancar(nodo_en_memoria(), Arc::new(Contador::default()));
    let piezas_b = arrancar(nodo_en_memoria(), Arc::new(Contador::default()));

    let manejo_a = piezas_a.manejo.clone();
    let manejo_b = piezas_b.manejo.clone();
    let mut ev_a = piezas_a.eventos;
    let mut ev_b = piezas_b.eventos;

    let tarea_a = tokio::spawn(piezas_a.bucle.correr());
    let tarea_b = tokio::spawn(piezas_b.bucle.correr());

    let addr = addr_memoria();
    manejo_a.escuchar(addr.clone()).await.expect("A escucha");

    // Esperar a que A confirme que escucha, antes de que B marque.
    assert!(
        esperar(&mut ev_a, |e| matches!(e, EventoRed::Escuchando(_)))
            .await
            .is_some(),
        "A debería anunciar que escucha"
    );

    manejo_b.marcar(addr).await.expect("B marca");

    let a_vio = esperar(&mut ev_a, |e| matches!(e, EventoRed::PeerConectado(_))).await;
    let b_vio = esperar(&mut ev_b, |e| matches!(e, EventoRed::PeerConectado(_))).await;

    assert!(a_vio.is_some(), "A debería ver conectarse a B");
    assert!(b_vio.is_some(), "B debería ver conectarse a A");

    tarea_a.abort();
    tarea_b.abort();
}

/// **El bucle termina solo cuando se sueltan todos los handles.**
///
/// Apagado cooperativo: sin `abort()`, sin señal, sin tarea huérfana. Importa porque **soltar un
/// `JoinHandle` en tokio NO cancela la tarea** — un bucle que no supiera terminar por su cuenta
/// sobreviviría al nodo.
#[tokio::test]
async fn el_bucle_termina_al_soltar_los_handles() {
    let piezas = arrancar(nodo_en_memoria(), Arc::new(Contador::default()));
    let manejo = piezas.manejo;
    let eventos = piezas.eventos;
    let tarea = tokio::spawn(piezas.bucle.correr());

    drop(manejo);
    drop(eventos);

    let fin = tokio::time::timeout(Duration::from_secs(5), tarea).await;
    assert!(
        fin.is_ok(),
        "el bucle MUST terminar al soltarse el último handle, sin necesidad de abort()"
    );
}

/// **Un handle huérfano devuelve error, no entra en pánico.**
///
/// En un nodo real esto pasa durante el apagado, y ahí un pánico sería un apagado sucio.
#[tokio::test]
async fn un_handle_sin_bucle_devuelve_error_y_no_panic() {
    let piezas = arrancar(nodo_en_memoria(), Arc::new(Contador::default()));
    let manejo = piezas.manejo.clone();

    drop(piezas.bucle); // el bucle nunca corre
    drop(piezas.eventos);

    assert!(
        manejo.escuchar(addr_memoria()).await.is_err(),
        "sin bucle, el comando MUST fallar limpiamente"
    );
}
