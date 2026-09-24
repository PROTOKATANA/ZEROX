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
    clippy::unwrap_used,
    clippy::panic,
    reason = "los tests fallan con panic por diseño"
)]

use std::sync::Arc;
use std::sync::atomic::{AtomicU64, AtomicUsize, Ordering};
use std::time::Duration;

use libp2p::core::transport::{MemoryTransport, Transport};
use libp2p::core::upgrade;
use libp2p::{Multiaddr, PeerId, Swarm, identity, noise, yamux};
use zx_core::Amount;
use zx_core::digest::{BlockHash, BodyCommitment, Digest, MerkleRoot, TxId};
use zx_core::preimage::block::BlockHeader;
use zx_core::preimage::dag::{DagBlockHeader, PadresDag, SolucionPoas};
use zx_core::red::Red;
use zx_core::tx::{Lock, OutPoint, Tx, TxIn, TxOut};
use zx_p2p::behaviour::ZxBehaviour;
use zx_p2p::config::ParametrosRed;
use zx_p2p::entrante::{ManejadorEntrante, Veredicto};
use zx_p2p::limites;
use zx_p2p::mensaje::{BloqueRed, Estado, Peticion, Respuesta};
use zx_p2p::presupuesto::Presupuesto;
use zx_p2p::rele_compacto::AnuncioCompacto;
use zx_p2p::servicio::{EventoRed, arrancar_con};

/// Manejador de juguete: cuenta llamadas y sirve un estado reconocible.
struct Contador {
    bloques: AtomicUsize,
    txs: AtomicUsize,
    /// Anuncios compactos que llegaron al callback. Sin validación DAG el callback devuelve
    /// `Ignorar`; este contador es lo que prueba que **llegó** y que no se aceptó.
    anuncios: AtomicUsize,
    /// Para distinguir de quién es la respuesta en un test con dos nodos.
    marca: u8,
    /// Cabeceras que este nodo dice tener.
    cabeceras: Vec<BlockHeader>,
    /// El mismo contador de C-NET-21 que se pasa al códec y al bucle de este nodo.
    presupuesto: Presupuesto,
}

impl Contador {
    fn nuevo(marca: u8) -> Self {
        Self {
            bloques: AtomicUsize::new(0),
            txs: AtomicUsize::new(0),
            anuncios: AtomicUsize::new(0),
            marca,
            cabeceras: Vec::new(),
            presupuesto: Presupuesto::default(),
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
            anuncios: AtomicUsize::new(0),
            marca,
            cabeceras,
            presupuesto: Presupuesto::default(),
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
    fn anuncio_compacto(&self, _: &AnuncioCompacto) -> Veredicto {
        self.anuncios.fetch_add(1, Ordering::Relaxed);
        // C-NET-12 · sin validación DAG causal no se acepta ni se retransmite. `Ignorar`, nunca
        // `Aceptar`: el éxito del parseo no es validación.
        Veredicto::Ignorar
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
    // Cada nodo entrega **el mismo** contador a su códec y a su bucle: `nodo_en_memoria` lo clona
    // dentro del `ZxCodec` y `arrancar_con` recibe otro clon.
    let swarm_a = nodo_en_memoria(&a.presupuesto);
    let swarm_b = nodo_en_memoria(&b.presupuesto);
    let id_b = *swarm_b.local_peer_id();
    let tema_bloques = swarm_a.behaviour().parametros_de_red().topic_bloques();
    let tema_txs = swarm_a.behaviour().parametros_de_red().topic_txs();

    let pa = arrancar_con(swarm_a, a.clone(), a.presupuesto.clone());
    let pb = arrancar_con(swarm_b, b.clone(), b.presupuesto.clone());

    let manejo_a = pa.manejo.clone();
    let mut ev_a = pa.eventos;
    let mut ev_b = pb.eventos;
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
    // **Sincronización acotada con la malla, y en la dirección correcta.**
    //
    // Quien publica en las pruebas de anuncio es B y el destinatario es A. Para que
    // `B.gossipsub.publish` tenga a alguien suscrito, la suscripción de **A** tiene que haber llegado
    // a B: por eso se espera en el canal de eventos de B (`ev_b`), no en el de A. Esperar en `ev_a`
    // la suscripción de B sería la dirección contraria. Publicar antes de que B vea a A tampoco
    // sirve: el intento queda en la caché de deduplicación por `message_id` y reintentarlo devuelve
    // `Duplicate` en vez de entregar.
    //
    // Se esperan **los dos temas**, en el orden en que lleguen: A los envía al establecerse la
    // conexión y el orden dentro del RPC no está garantizado. Esperar solo bloques y luego exigir
    // txs volvería a perder el evento si llegó antes; sin la suscripción a `/txs/1`, publicar una
    // transacción devolvería `NoPeersSubscribedToTopic`.
    //
    // La comparación es por **igualdad exacta** con el tema configurado, nunca `contains("/blocks/")`:
    // eso último daría por buenos `/zerox/blocks/20` o `/zerox/blocks/2/extra`.
    let mut vio_bloques = false;
    let mut vio_txs = false;
    while !(vio_bloques && vio_txs) {
        let Some(e) = esperar(&mut ev_b, |e| matches!(e, EventoRed::Suscripcion { .. })).await
        else {
            panic!("B no vio las dos suscripciones de A (bloques={vio_bloques}, txs={vio_txs})");
        };
        if let EventoRed::Suscripcion {
            topico,
            suscrito: true,
            ..
        } = &e
        {
            vio_bloques |= topico.as_str() == tema_bloques;
            vio_txs |= topico.as_str() == tema_txs;
        }
    }

    // ⚠️ El handle de B se DEVUELVE, no se suelta.
    //
    // La primera versión de este arnés hacía `drop(pb.manejo)` razonando que el test solo habla
    // desde A. Los tres tests de protocolo se quedaban esperando hasta el tope de 10 s.
    //
    // La causa es el apagado cooperativo funcionando exactamente como debe: soltar el último
    // `ManejoRed` cierra el canal de comandos, `comandos.recv()` devuelve `None`, y **el bucle de B
    // termina**. B dejaba de existir antes de que A le preguntara nada.
    (manejo_a, ev_a, id_b, tareas, pb.manejo, ev_b)
}

/// Arranca un nodo pasando **el mismo** `Presupuesto` de su manejador al bucle y al códec.
///
/// Es la forma de que estos tests ejerzan el contrato de C-NET-21: el contador del códec y el del
/// despacho de gossip son el mismo. Un `arrancar` con un presupuesto nuevo por nodo probaría otra
/// cosa.
fn arrancar_de(c: &Arc<Contador>) -> zx_p2p::servicio::Piezas<Contador> {
    arrancar_con(
        nodo_en_memoria(&c.presupuesto),
        Arc::clone(c),
        c.presupuesto.clone(),
    )
}

/// Un `Swarm` sobre transporte en memoria. **Sin TCP**, a diferencia de `swarm-test`.
///
/// El `Presupuesto` recibido se **clona dentro del `ZxCodec`** de `sync`. Quien construye el nodo
/// entrega después ese mismo contador a `arrancar_con`, de modo que el bucle de gossip y el códec
/// comparten techo (C-NET-21). Un `ZxBehaviour::nueva` aquí —que crea su propio
/// `Presupuesto::default()`— dejaría al códec con un contador distinto y el test de contador
/// compartido afirmaría algo falso.
fn nodo_en_memoria(presupuesto: &Presupuesto) -> Swarm<ZxBehaviour> {
    let clave = identity::Keypair::generate_ed25519();
    let peer_id = clave.public().to_peer_id();

    let transporte = MemoryTransport::default()
        .upgrade(upgrade::Version::V1)
        .authenticate(noise::Config::new(&clave).expect("noise"))
        .multiplex(yamux::Config::default())
        .boxed();

    let behaviour = ZxBehaviour::con_presupuesto(
        &clave,
        ParametrosRed::de(Red::Testnet),
        limites::LIMITE_BLOQUE_GENESIS,
        presupuesto.clone(),
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
    let piezas_a = arrancar_de(&Arc::new(Contador::default()));
    let piezas_b = arrancar_de(&Arc::new(Contador::default()));

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
    let piezas = arrancar_de(&Arc::new(Contador::default()));
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
    let piezas = arrancar_de(&Arc::new(Contador::default()));
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

/// Una transacción mínima con una entrada, para el anuncio compacto.
fn tx_llave(n: u8) -> Tx {
    Tx {
        version: 1,
        inputs: vec![TxIn {
            outpoint: OutPoint {
                prev_txid: TxId::from_digest(Digest::from_bytes([n; 32])),
                prev_index: 0,
            },
            sequence: 0,
        }],
        outputs: vec![TxOut {
            value: Amount::nuevo(1_000).unwrap(),
            lock: Lock::PubKey {
                pubkey: zx_core::firma::ClavePublica::desde_bytes([n; 32]),
            },
        }],
        lock_time: 0,
        expiry_height: 0,
    }
}

/// Un `AnuncioCompacto` real, serializable con `a_bytes`, con el nonce dado.
fn anuncio(nonce: u64) -> AnuncioCompacto {
    let cabecera = DagBlockHeader {
        consensus_branch_id: 0xc478_80ea,
        merkle_root: MerkleRoot::from_digest(Digest::from_bytes([0x33; 32])),
        timestamp: 1_788_480_000,
        height: 1,
        slot: 1,
        pot_output: [0; 16],
        rango_solucion: 1,
        sol: SolucionPoas::default(),
        body_commitment: BodyCommitment::from_digest(Digest::from_bytes([0x44; 32])),
        padres: PadresDag::nuevo(BlockHash::from_digest(Digest::from_bytes([0x55; 32])), &[])
            .unwrap(),
        sello: [0; 64],
    };
    AnuncioCompacto::nuevo(
        cabecera,
        nonce,
        tx_llave(0x11),
        vec![vec![0x66; 64]],
        vec![[0x77; 6]],
    )
    .unwrap()
}

/// **C-NET-25/C-NET-26/C-NET-12 · un anuncio real viaja y el callback lo ignora, sin retransmitir.**
///
/// B publica por la **API tipada** —no hay forma de elegir el tema desde el test— y A lo recibe en
/// su callback compacto. El callback devuelve `Ignorar`: como A no valida el DAG causal, no acepta
/// ni retransmite. La sincronización con la malla es acotada por el evento `Suscripcion`, no por un
/// `sleep` fijo.
///
/// # Límite declarado
///
/// Este arnés tiene **dos** nodos, así que no puede observar la retransmisión: para verla haría
/// falta un tercero en la malla de A. Lo que sí prueba es lo que C-NET-12 exige en este punto —que
/// el veredicto es `Ignorar` y no `Aceptar`—; la ausencia de retransmisión de extremo a extremo
/// queda como límite explícito de esta prueba, no como verificada.
#[tokio::test]
async fn un_anuncio_compacto_real_llega_al_callback_y_se_ignora() {
    let a = Arc::new(Contador::nuevo(1));
    let b = Arc::new(Contador::nuevo(2));
    let (manejo_a, mut ev_a, _id_b, tareas, manejo_b, _vivo_b) =
        dos_conectados(Arc::clone(&a), Arc::clone(&b)).await;

    manejo_b
        .difundir_anuncio(&anuncio(7))
        .await
        .expect("B publica el anuncio por su tema");

    // A recibe el callback compacto. No es un evento de `EventoRed` —el callback no cruza a un
    // evento— así que se espera al contador del manejador con un tope acotado y sin `sleep` fijo
    // como única condición.
    let plazo = tokio::time::Instant::now() + Duration::from_secs(10);
    while a.anuncios.load(Ordering::Relaxed) == 0 {
        assert!(
            tokio::time::Instant::now() < plazo,
            "el anuncio de B no llegó al callback de A"
        );
        // Se bombea el canal de eventos de B para que el planificador corra los dos bucles.
        let _ = tokio::time::timeout(Duration::from_millis(20), ev_a.recv()).await;
    }

    assert_eq!(a.anuncios.load(Ordering::Relaxed), 1, "una sola entrega");
    assert_eq!(a.txs.load(Ordering::Relaxed), 0, "no es una transacción");
    assert_eq!(a.bloques.load(Ordering::Relaxed), 0, "no es /blocks/1");
    // Un anuncio **distinto**: republicar el mismo daría `Duplicate` en la caché de gossipsub. Lo
    // que se comprueba es que el handle sigue vivo y que gossipsub acepta el envío local.
    assert!(
        manejo_a.difundir_anuncio(&anuncio(9)).await.is_ok(),
        "el handle sigue vivo"
    );

    for t in tareas {
        t.abort();
    }
}

/// **C-NET-25 · una transacción viaja por `/txs/1` y el canal de bloques no la recibe.**
///
/// B publica por la API tipada `difundir_tx` —que fija el tema a partir de los parámetros de red— y
/// A la recibe en su callback `tx_difundida`. El canal `/blocks/2` **no** la ve: ni el callback
/// compacto ni el de bloque lineal se disparan. La sincronización con la malla espera a las dos
/// suscripciones de A en `dos_conectados`, sin `sleep` fijo.
///
/// La transacción va serializada de verdad con `zx_core::wire::tx_a_bytes`; hoy el dispatcher pasa
/// los bytes crudos al manejador, pero el test no depende de que siga sin mirarlos.
#[tokio::test]
async fn una_transaccion_viaja_por_txs_y_no_por_el_canal_de_bloques() {
    let a = Arc::new(Contador::nuevo(1));
    let b = Arc::new(Contador::nuevo(2));
    let (_manejo_a, _ev_a, _id_b, tareas, manejo_b, _vivo_b) =
        dos_conectados(Arc::clone(&a), Arc::clone(&b)).await;

    let mut tx_bytes = Vec::new();
    zx_core::wire::tx_a_bytes(&mut tx_bytes, &tx_llave(0x22), &[vec![0x88; 64]]);

    manejo_b
        .difundir_tx(tx_bytes)
        .await
        .expect("B publica la transacción por /txs/1");

    let plazo = tokio::time::Instant::now() + Duration::from_secs(10);
    while a.txs.load(Ordering::Relaxed) == 0 {
        assert!(
            tokio::time::Instant::now() < plazo,
            "la transacción de B no llegó al callback de A"
        );
        tokio::time::sleep(Duration::from_millis(20)).await;
    }

    assert_eq!(a.txs.load(Ordering::Relaxed), 1, "una sola entrega");
    assert_eq!(
        a.anuncios.load(Ordering::Relaxed),
        0,
        "una transacción MUST NOT llegar por /blocks/2"
    );
    assert_eq!(
        a.bloques.load(Ordering::Relaxed),
        0,
        "una transacción MUST NOT llegar por /blocks/1"
    );

    for t in tareas {
        t.abort();
    }
}

/// **C-NET-21 · una reserva externa en el contador compartido agota el parseo de gossip.**
///
/// El nodo A entrega **el mismo** `Presupuesto` a su códec de `sync` y a su bucle de gossip. El test
/// reserva casi todo ese contador **desde fuera** —no ejerce una reserva simultánea del códec—; con
/// el techo ocupado, el anuncio de B no cabe en `desde_bytes`, el veredicto es `Ignorar` —recurso
/// **local**, no culpa del par (C-NET-05)— y el callback compacto **no** se llama. Al liberar la
/// reserva, el contador vuelve a cero y un anuncio distinto sí llega.
///
/// ⚠️ No es una garantía sobre objetos retenidos: la reserva del parseo se libera antes de retener
/// el anuncio. Este test cubre el techo **en vuelo** y su liberación, con una reserva que ocupa el
/// contador sin que el códec la haya pedido.
#[tokio::test]
async fn una_reserva_externa_en_el_contador_compartido_agota_el_parseo_de_gossip() {
    let a = Arc::new(Contador::nuevo(1));
    let b = Arc::new(Contador::nuevo(2));
    let (_manejo_a, _ev_a, _id_b, tareas, manejo_b, _vivo_b) =
        dos_conectados(Arc::clone(&a), Arc::clone(&b)).await;

    let bytes = anuncio(7).a_bytes();

    // Justo por debajo del techo: no cabe ninguna reserva de `bytes.len()`, pero sí queda sitio
    // para la reserva mínima que necesita el parseo si se liberara.
    let reservado = a
        .presupuesto
        .reservar(Presupuesto::default().disponible() - bytes.len() + 1)
        .expect("reserva local");
    assert!(
        a.presupuesto.disponible() < bytes.len(),
        "el anuncio debe superar el sitio libre"
    );

    // La publicación MUST ser aceptada localmente por gossipsub. Sin esta comprobación, que A no
    // llame al callback no probaría nada del presupuesto: el anuncio podría no haber salido nunca.
    let salio = manejo_b.difundir_anuncio(&anuncio(7)).await;
    assert!(
        salio.is_ok(),
        "la primera publicación debía aceptarse localmente: {salio:?}"
    );

    // Se da tiempo acotado a que A procese el evento; el callback no debe dispararse.
    let plazo = tokio::time::Instant::now() + Duration::from_secs(3);
    while tokio::time::Instant::now() < plazo && a.anuncios.load(Ordering::Relaxed) == 0 {
        tokio::time::sleep(Duration::from_millis(20)).await;
    }
    assert_eq!(
        a.anuncios.load(Ordering::Relaxed),
        0,
        "sin presupuesto no hay anuncio parseado ni callback"
    );

    drop(reservado);
    assert_eq!(a.presupuesto.en_vuelo(), 0, "el contador vuelve a cero");

    // Y ahora un anuncio distinto sí llega al callback: el agotamiento era local y pasajero. El
    // contenido distinto evita el `Duplicate` de la caché de deduplicación.
    let salio = manejo_b.difundir_anuncio(&anuncio(8)).await;
    assert!(
        salio.is_ok(),
        "el segundo anuncio debía aceptarse localmente: {salio:?}"
    );
    let plazo = tokio::time::Instant::now() + Duration::from_secs(10);
    while a.anuncios.load(Ordering::Relaxed) == 0 {
        assert!(
            tokio::time::Instant::now() < plazo,
            "con presupuesto liberado el anuncio debe llegar"
        );
        tokio::time::sleep(Duration::from_millis(20)).await;
    }
    assert_eq!(a.anuncios.load(Ordering::Relaxed), 1);
    assert_eq!(a.presupuesto.en_vuelo(), 0, "el parseo devolvió su reserva");

    for t in tareas {
        t.abort();
    }
}
