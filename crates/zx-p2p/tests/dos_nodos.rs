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

#![expect(
    clippy::expect_used,
    clippy::panic,
    reason = "los tests fallan con panic por diseño"
)]

use std::sync::Arc;
use std::sync::atomic::{AtomicU64, AtomicUsize, Ordering};
use std::time::Duration;

use libp2p::core::transport::{MemoryTransport, Transport};
use libp2p::core::upgrade;
use libp2p::{Multiaddr, PeerId, Swarm, identity, noise, yamux};
use zx_core::digest::{BlockHash, Digest};
use zx_core::preimage::block::BlockHeader;
use zx_core::red::Red;
use zx_p2p::behaviour::ZxBehaviour;
use zx_p2p::config::ParametrosRed;
use zx_p2p::entrante::{ManejadorEntrante, Veredicto};
use zx_p2p::limites;
use zx_p2p::mensaje::{BloqueRed, Estado, Peticion, Respuesta};
use zx_p2p::servicio::{EventoRed, arrancar};

/// Manejador de juguete: cuenta llamadas y sirve un estado reconocible.
struct Contador {
    bloques: AtomicUsize,
    txs: AtomicUsize,
    /// Para distinguir de quién es la respuesta en un test con dos nodos.
    marca: u8,
    /// Cabeceras que este nodo dice tener.
    cabeceras: Vec<BlockHeader>,
}

impl Contador {
    fn nuevo(marca: u8) -> Self {
        Self {
            bloques: AtomicUsize::new(0),
            txs: AtomicUsize::new(0),
            marca,
            cabeceras: Vec::new(),
        }
    }

    fn con_cabeceras(marca: u8, n: usize) -> Self {
        let cabeceras = (0..n)
            .map(|i| BlockHeader {
                consensus_branch_id: 0xc478_80ea,
                prev_hash: BlockHash::from_digest(Digest::from_bytes([i as u8; 32])),
                merkle_root: zx_core::digest::MerkleRoot::from_digest(Digest::from_bytes([9; 32])),
                timestamp: 1_788_480_000 + i as u64,
                bits: 0x1c07_fff8,
                nonce: i as u64,
                height: i as u32,
            })
            .collect();
        Self {
            bloques: AtomicUsize::new(0),
            txs: AtomicUsize::new(0),
            marca,
            cabeceras,
        }
    }
}

impl Default for Contador {
    fn default() -> Self {
        Self::nuevo(0)
    }
}

impl ManejadorEntrante for Contador {
    fn estado(&self) -> Estado {
        Estado {
            genesis: BlockHash::from_digest(Digest::from_bytes([0; 32])),
            tip: BlockHash::from_digest(Digest::from_bytes([self.marca; 32])),
            altura: u32::from(self.marca) * 100,
            trabajo: [self.marca; 32],
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
        self.cabeceras.clone()
    }
    fn bloques_por_hash(&self, _: &[BlockHash]) -> Vec<BloqueRed> {
        Vec::new()
    }
}

/// Conecta dos nodos y devuelve sus piezas ya corriendo.
///
/// Se factoriza porque los tres tests de protocolo necesitan exactamente lo mismo, y repetirlo
/// invitaría a que uno de ellos se desincronizara del resto.
type Conectados = (
    zx_p2p::servicio::ManejoRed,
    tokio::sync::mpsc::Receiver<EventoRed>,
    PeerId,
    Vec<tokio::task::JoinHandle<()>>,
    // El handle de B, que hay que mantener vivo o su bucle termina. Ver la nota de abajo.
    zx_p2p::servicio::ManejoRed,
    tokio::sync::mpsc::Receiver<EventoRed>,
);

async fn dos_conectados(a: Arc<Contador>, b: Arc<Contador>) -> Conectados {
    let swarm_a = nodo_en_memoria();
    let swarm_b = nodo_en_memoria();
    let id_b = *swarm_b.local_peer_id();

    let pa = arrancar(swarm_a, a);
    let pb = arrancar(swarm_b, b);

    let manejo_a = pa.manejo.clone();
    let mut ev_a = pa.eventos;
    let tareas = vec![
        tokio::spawn(pa.bucle.correr()),
        tokio::spawn(pb.bucle.correr()),
    ];

    // B escucha, A marca: así A conoce la dirección de B y puede pedirle cosas.
    let addr = addr_memoria();
    pb.manejo.escuchar(addr.clone()).await.expect("B escucha");
    // No hay evento de "B escucha" en el canal de A, así que se espera a que A vea la conexión.
    manejo_a.marcar(addr).await.expect("A marca");
    assert!(
        esperar(&mut ev_a, |e| matches!(e, EventoRed::PeerConectado(_)))
            .await
            .is_some(),
        "A debería conectarse con B"
    );

    // ⚠️ El handle de B se DEVUELVE, no se suelta.
    //
    // La primera versión de este arnés hacía `drop(pb.manejo)` razonando que el test solo habla
    // desde A. Los tres tests de protocolo se quedaban esperando hasta el tope de 10 s.
    //
    // La causa es el apagado cooperativo funcionando exactamente como debe: soltar el último
    // `ManejoRed` cierra el canal de comandos, `comandos.recv()` devuelve `None`, y **el bucle de B
    // termina**. B dejaba de existir antes de que A le preguntara nada.
    (manejo_a, ev_a, id_b, tareas, pb.manejo, pb.eventos)
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

/// **El saludo, de extremo a extremo.**
///
/// A le pregunta a B quién es, y B responde con **su** estado, no con el de A. Es el primer test
/// que recorre el camino completo: comando → códec → transporte → manejador → códec → evento.
#[tokio::test]
async fn el_saludo_recorre_el_camino_completo() {
    let (manejo_a, mut ev_a, id_b, tareas, _vivo_b, _ev_b) =
        dos_conectados(Arc::new(Contador::nuevo(1)), Arc::new(Contador::nuevo(7))).await;

    manejo_a
        .pedir(id_b, Peticion::Estado)
        .await
        .expect("A pregunta");

    let e = esperar(&mut ev_a, |e| matches!(e, EventoRed::Respuesta { .. }))
        .await
        .expect("A debería recibir el estado de B");

    let EventoRed::Respuesta { respuesta, .. } = e else {
        panic!("se esperaba una respuesta");
    };
    match *respuesta {
        Respuesta::Estado(s) => {
            // La marca 7 es la de B. Si llegara la 1, el nodo se estaría respondiendo a sí mismo.
            assert_eq!(s.altura, 700, "debe ser el estado de B, no el de A");
            assert_eq!(s.trabajo, [7; 32]);
        }
        otra => panic!("se esperaba Estado, llegó {otra:?}"),
    }

    for t in tareas {
        t.abort();
    }
}

/// **Pedir cabeceras y que el manejador de B las sirva.**
#[tokio::test]
async fn pedir_cabeceras_llega_al_manejador_del_otro_lado() {
    let (manejo_a, mut ev_a, id_b, tareas, _vivo_b, _ev_b) = dos_conectados(
        Arc::new(Contador::nuevo(1)),
        Arc::new(Contador::con_cabeceras(2, 5)),
    )
    .await;

    manejo_a
        .pedir(
            id_b,
            Peticion::Cabeceras {
                locator: vec![BlockHash::from_digest(Digest::from_bytes([0; 32]))],
                hasta: None,
            },
        )
        .await
        .expect("A pide");

    let e = esperar(&mut ev_a, |e| matches!(e, EventoRed::Respuesta { .. }))
        .await
        .expect("A debería recibir cabeceras");

    let EventoRed::Respuesta { respuesta, .. } = e else {
        panic!("se esperaba una respuesta");
    };
    match *respuesta {
        Respuesta::Cabeceras(cs) => assert_eq!(cs.len(), 5, "las cinco que B dice tener"),
        otra => panic!("se esperaba Cabeceras, llegó {otra:?}"),
    }

    for t in tareas {
        t.abort();
    }
}

/// **"No tengo eso" es una respuesta, no un error.**
///
/// B no tiene ningún bloque, así que responde `NoDisponible`. Por C-NET-05 eso **no puntúa**: un
/// peer honesto puede haber podado el bloque, o pertenecer a una rama que descartó.
#[tokio::test]
async fn no_tener_un_bloque_es_una_respuesta_legitima() {
    let (manejo_a, mut ev_a, id_b, tareas, _vivo_b, _ev_b) =
        dos_conectados(Arc::new(Contador::nuevo(1)), Arc::new(Contador::nuevo(2))).await;

    manejo_a
        .pedir(
            id_b,
            Peticion::Bloques {
                hashes: vec![BlockHash::from_digest(Digest::from_bytes([42; 32]))],
            },
        )
        .await
        .expect("A pide");

    let e = esperar(&mut ev_a, |e| matches!(e, EventoRed::Respuesta { .. }))
        .await
        .expect("A debería recibir algo");

    let EventoRed::Respuesta { respuesta, .. } = e else {
        panic!("se esperaba una respuesta");
    };
    assert_eq!(
        *respuesta,
        Respuesta::NoDisponible,
        "no tener el bloque MUST decirse, no callarse"
    );

    for t in tareas {
        t.abort();
    }
}
