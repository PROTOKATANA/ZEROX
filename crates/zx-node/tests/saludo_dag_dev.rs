//! Pruebas del saludo de identidad DAG de **desarrollo** (incremento F4/C3).
//!
//! # Qué cubre
//!
//! 1. [`ManejadorDagDev::estado`] contra el **hash literal externo** congelado y callbacks que
//!    ignoran sin aceptar ni retransmitir.
//! 2. El coordinador: `PeerConectado` no marca listo; un `Estado` con los cuatro campos correctos
//!    sí; hash, tip, altura o trabajo alterados no; un evento tardío y el vencimiento del plazo
//!    tampoco. El motivo de desconexión se **observa** por API y se comprueba que no puntúa.
//! 3. Tres `Swarm<ZxBehaviour>` reales sobre `MemoryTransport` puro con el perfil `dag_dev`, el
//!    handler y el coordinador del mismo código del binario: A–B–C, sin sleeps fijos.
//! 4. Un impostor con otro génesis y un peer con perfil testnet: nunca quedan listos.
//!
//! # Qué NO afirma
//!
//! No hay producción de bloques ni convergencia de cadena: el fixture dev no admite PoST. El códec
//! dev solo negocia el saludo, así que estas pruebas no acreditan propagación de bloques.

#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    reason = "los tests fallan con panic por diseño"
)]

use std::sync::Arc;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{Duration, Instant};

use libp2p::core::transport::{MemoryTransport, Transport};
use libp2p::core::upgrade;
use libp2p::{Multiaddr, PeerId, Swarm, identity, noise, yamux};
use zx_core::Amount;
use zx_core::digest::{BlockHash, BodyCommitment, Digest, MerkleRoot, TxId};
use zx_core::firma::ClavePublica;
use zx_core::preimage::block::BlockHeader;
use zx_core::preimage::dag::{DagBlockHeader, PadresDag, SolucionPoas};
use zx_core::red::Red;
use zx_core::tx::{Lock, OutPoint, Tx, TxIn, TxOut};
use zx_node::bootstrap_dag_dev::{EstadoBootstrapDagDev, iniciar_bootstrap_dag_dev};
use zx_node::nodo_dag_dev::{
    MOTIVO_ESTADO_DISCREPANTE, MOTIVO_SALUDO_VENCIDO, ManejadorDagDev, NodoDagDev, PLAZO_SALUDO_DEV,
};
use zx_p2p::behaviour::ZxBehaviour;
use zx_p2p::config::ParametrosRed;
use zx_p2p::entrante::{ManejadorEntrante, Veredicto};
use zx_p2p::error::MotivoDesconexion;
use zx_p2p::limites;
use zx_p2p::mensaje::{BloqueRed, Estado, Respuesta};
use zx_p2p::presupuesto::Presupuesto;
use zx_p2p::rele_compacto::AnuncioCompacto;
use zx_p2p::servicio::{EventoRed, ManejoRed, arrancar_con};

/// `block_hash` congelado del fixture dev, el mismo literal del perfil de producción.
const HASH_DEV: [u8; 32] = [
    4, 0, 228, 160, 3, 45, 150, 243, 155, 108, 165, 251, 38, 47, 168, 55, 66, 41, 232, 57, 230, 84,
    144, 102, 6, 224, 105, 216, 129, 184, 225, 127,
];

/// Plazo acotado para las esperas de red; en `MemoryTransport` la convergencia es de milisegundos.
const PLAZO_RED: Duration = Duration::from_secs(15);

// ── Fixtures ─────────────────────────────────────────────────────────────────────────────────

/// Un `PeerId` distinto por llamada, para eventos sintéticos.
fn un_peer() -> PeerId {
    identity::Keypair::generate_ed25519().public().to_peer_id()
}

/// Una `Respuesta::Estado` envuelta en el evento que la transporta.
fn respuesta_estado(peer: PeerId, estado: Estado) -> EventoRed {
    EventoRed::Respuesta {
        peer,
        peticion: 0,
        respuesta: Box::new(Respuesta::Estado(estado)),
    }
}

/// Un `BloqueRed` lineal de relleno: el handler dev no debe tocarlo.
fn bloque_red() -> BloqueRed {
    BloqueRed {
        cabecera: BlockHeader {
            consensus_branch_id: 0xc478_80ea,
            prev_hash: BlockHash::from_digest(Digest::from_bytes([0x01; 32])),
            merkle_root: MerkleRoot::from_digest(Digest::from_bytes([0x02; 32])),
            timestamp: 1_788_480_000,
            bits: 0x1c07_fff8,
            nonce: 1,
            height: 1,
        },
        txs: Vec::new(),
        testigos: Vec::new(),
    }
}

/// Una transacción mínima, para el anuncio compacto.
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
            value: Amount::nuevo(1_000).expect("importe"),
            lock: Lock::PubKey {
                pubkey: ClavePublica::desde_bytes([n; 32]),
            },
        }],
        lock_time: 0,
        expiry_height: 0,
    }
}

/// Un `AnuncioCompacto` real, serializable con `a_bytes`.
fn anuncio() -> AnuncioCompacto {
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
            .expect("padres"),
        sello: [0; 64],
    };
    AnuncioCompacto::nuevo(
        cabecera,
        7,
        tx_llave(0x11),
        vec![vec![0x66; 64]],
        vec![[0x77; 6]],
    )
    .expect("anuncio")
}

/// Handler de prueba con un `Estado` fijo: sirve de impostor o de peer de otro perfil.
struct EstadoFijo(Estado);

impl ManejadorEntrante for EstadoFijo {
    fn estado(&self) -> Estado {
        self.0
    }

    fn bloque_difundido(&self, _: &BloqueRed) -> Veredicto {
        Veredicto::Ignorar
    }

    fn tx_difundida(&self, _: &[u8]) -> Veredicto {
        Veredicto::Ignorar
    }

    fn cabeceras_desde(&self, _: &[BlockHash], _: Option<BlockHash>) -> Vec<BlockHeader> {
        Vec::new()
    }

    fn bloques_por_hash(&self, _: &[BlockHash]) -> Vec<BloqueRed> {
        Vec::new()
    }
}

// ── Malla en memoria ─────────────────────────────────────────────────────────────────────────

/// Un nodo dev en malla: su asa, su flujo de eventos, su tarea y su dirección.
struct EnMalla {
    manejo: ManejoRed,
    eventos: tokio::sync::mpsc::Receiver<EventoRed>,
    tarea: tokio::task::JoinHandle<()>,
    addr: Multiaddr,
}

/// Un `Swarm` sobre `MemoryTransport` puro con el perfil pedido, sin sockets del sistema.
fn swarm_en_memoria(p: ParametrosRed, presupuesto: &Presupuesto) -> Swarm<ZxBehaviour> {
    let clave = identity::Keypair::generate_ed25519();
    let peer_id = clave.public().to_peer_id();
    let transporte = MemoryTransport::default()
        .upgrade(upgrade::Version::V1)
        .authenticate(noise::Config::new(&clave).expect("noise"))
        .multiplex(yamux::Config::default())
        .boxed();
    let behaviour = ZxBehaviour::con_presupuesto(
        &clave,
        p,
        limites::LIMITE_BLOQUE_GENESIS,
        presupuesto.clone(),
    )
    .expect("behaviour");
    Swarm::new(
        transporte,
        behaviour,
        peer_id,
        libp2p::swarm::Config::with_tokio_executor()
            .with_idle_connection_timeout(Duration::from_secs(30)),
    )
}

/// Levanta un nodo en malla que escucha en una dirección de memoria única.
async fn levantar_con<M: ManejadorEntrante>(p: ParametrosRed, manejador: M) -> EnMalla {
    let presupuesto = Presupuesto::default();
    let swarm = swarm_en_memoria(p, &presupuesto);
    let piezas = arrancar_con(swarm, Arc::new(manejador), presupuesto);
    let manejo = piezas.manejo.clone();
    let eventos = piezas.eventos;
    let tarea = tokio::spawn(piezas.bucle.correr());
    let addr = addr_memoria();
    manejo.escuchar(addr.clone()).await.expect("escuchar");
    EnMalla {
        manejo,
        eventos,
        tarea,
        addr,
    }
}

/// Levanta un nodo con el handler y el perfil dev del binario.
async fn levantar_dev(estado: &EstadoBootstrapDagDev) -> EnMalla {
    levantar_con(
        ParametrosRed::dag_dev(),
        ManejadorDagDev::desde_estado_dev(estado),
    )
    .await
}

/// Una dirección `/memory/N` distinta de las de otros arneses.
fn addr_memoria() -> Multiaddr {
    static SIGUIENTE: AtomicU64 = AtomicU64::new(71_001);
    let puerto = SIGUIENTE.fetch_add(1, Ordering::Relaxed);
    format!("/memory/{puerto}").parse().expect("multiaddr")
}

/// El `Estado` del impostor: mismo perfil dev, **génesis distinto**.
fn estado_impostor() -> Estado {
    let ajeno = BlockHash::from_digest(Digest::from_bytes([0xAB; 32]));
    Estado {
        genesis: ajeno,
        tip: ajeno,
        altura: 0,
        trabajo: [0u8; 32],
    }
}

/// Espera acotada al primer `PeerConectado` del flujo, descartando eventos que no interesan.
async fn esperar_peer_conectado(rx: &mut tokio::sync::mpsc::Receiver<EventoRed>) -> PeerId {
    let limite = tokio::time::Instant::now() + PLAZO_RED;
    loop {
        let resto = limite.saturating_duration_since(tokio::time::Instant::now());
        assert!(!resto.is_zero(), "no llegó PeerConectado dentro del plazo");
        let e = tokio::time::timeout(resto, rx.recv())
            .await
            .expect("plazo de red")
            .expect("canal de eventos");
        if let EventoRed::PeerConectado(p) = e {
            return p;
        }
    }
}

// ── 1 · Handler ─────────────────────────────────────────────────────────────────────────────

#[test]
fn el_estado_del_handler_es_el_hash_literal_congelado() {
    let estado = iniciar_bootstrap_dag_dev().expect("bootstrap dev");
    let manejador = ManejadorDagDev::desde_estado_dev(&estado);

    assert_eq!(
        manejador.hash_dev().as_bytes(),
        &HASH_DEV,
        "el handler MUST servir el hash congelado, no uno recalculado"
    );

    let e = manejador.estado();
    assert_eq!(e.genesis.as_bytes(), &HASH_DEV, "genesis");
    assert_eq!(e.tip.as_bytes(), &HASH_DEV, "tip");
    assert_eq!(e.altura, 0, "altura");
    assert_eq!(e.trabajo, [0u8; 32], "trabajo");
    assert_eq!(e, manejador.estado_dev(), "mismo estado por ambas vías");
}

/// **Callbacks**: el handler ignora bloque, tx y anuncio; no acepta ni retransmite.
#[test]
fn los_callbacks_del_handler_ignoran_sin_aceptar_ni_retransmitir() {
    let estado = iniciar_bootstrap_dag_dev().expect("bootstrap dev");
    let manejador = ManejadorDagDev::desde_estado_dev(&estado);

    assert_eq!(
        manejador.bloque_difundido(&bloque_red()),
        Veredicto::Ignorar
    );
    assert_eq!(manejador.tx_difundida(b"tx"), Veredicto::Ignorar);
    assert_eq!(manejador.anuncio_compacto(&anuncio()), Veredicto::Ignorar);
    assert!(manejador.cabeceras_desde(&[], None).is_empty());
    assert!(manejador.bloques_por_hash(&[]).is_empty());
}

// ── 2 · Coordinador ────────────────────────────────────────────────────────────────────────

/// `PeerConectado` solo deja pendiente: **nunca** marca listo por topología.
#[tokio::test]
async fn peer_conectado_no_marca_listo() {
    let estado = iniciar_bootstrap_dag_dev().expect("bootstrap dev");
    let nodo = levantar_dev(&estado).await;
    let mut coord = NodoDagDev::nuevo(&estado, nodo.manejo.clone());
    let peer = un_peer();

    let nuevos = coord.atender(EventoRed::PeerConectado(peer)).await;
    assert!(nuevos.is_empty(), "conectar no verifica identidad");
    assert!(
        !coord.esta_listo(&peer),
        "PeerConectado MUST NOT marcar listo"
    );
    assert!(coord.esta_pendiente(&peer), "queda pendiente de saludo");
    nodo.tarea.abort();
}

/// Un `Estado` con los cuatro campos correctos marca listo, y solo si estaba pendiente.
#[tokio::test]
async fn un_estado_correcto_marca_listo() {
    let estado = iniciar_bootstrap_dag_dev().expect("bootstrap dev");
    let nodo = levantar_dev(&estado).await;
    let mut coord = NodoDagDev::nuevo(&estado, nodo.manejo.clone());
    let peer = un_peer();

    coord.atender(EventoRed::PeerConectado(peer)).await;
    let esperado = coord.estado_local();
    let nuevos = coord.atender(respuesta_estado(peer, esperado)).await;

    assert_eq!(nuevos, vec![peer], "el peer recién verificado se anuncia");
    assert!(coord.esta_listo(&peer));
    assert!(!coord.esta_pendiente(&peer));
    assert_eq!(coord.motivo_de_desconexion(&peer), None);
    nodo.tarea.abort();
}

/// Alterar cualquiera de los cuatro campos impide marcar listo y desconecta sin puntuar.
#[tokio::test]
async fn un_estado_con_un_campo_alterado_no_marca_listo_y_desconecta() {
    let estado = iniciar_bootstrap_dag_dev().expect("bootstrap dev");
    let nodo = levantar_dev(&estado).await;
    let mut coord = NodoDagDev::nuevo(&estado, nodo.manejo.clone());

    let base = coord.estado_local();
    let mut alterados = Vec::new();

    let mut genesis = base;
    genesis.genesis = BlockHash::from_digest(Digest::from_bytes([0xE1; 32]));
    alterados.push(("genesis", genesis));

    let mut tip = base;
    tip.tip = BlockHash::from_digest(Digest::from_bytes([0xE2; 32]));
    alterados.push(("tip", tip));

    let mut altura = base;
    altura.altura = 1;
    alterados.push(("altura", altura));

    let mut trabajo = base;
    trabajo.trabajo = [0xE3; 32];
    alterados.push(("trabajo", trabajo));

    for (campo, alterado) in alterados {
        let peer = un_peer();
        coord.atender(EventoRed::PeerConectado(peer)).await;
        let nuevos = coord.atender(respuesta_estado(peer, alterado)).await;

        assert!(nuevos.is_empty(), "{campo}: no puede quedar listo");
        assert!(!coord.esta_listo(&peer), "{campo}");
        assert!(!coord.esta_pendiente(&peer), "{campo}");
        let motivo = coord
            .motivo_de_desconexion(&peer)
            .expect("el motivo se observa por API");
        assert_eq!(motivo, MOTIVO_ESTADO_DISCREPANTE, "{campo}");
        assert!(!motivo.puntua(), "{campo}: C-NET-05, no puntúa");
        assert_eq!(motivo.puntos(), 0, "{campo}");
    }
    nodo.tarea.abort();
}

/// Una respuesta de otra variante no responde al saludo: corta sin puntuar y nunca marca listo.
#[tokio::test]
async fn una_respuesta_de_otra_variante_no_marca_listo() {
    let estado = iniciar_bootstrap_dag_dev().expect("bootstrap dev");
    let nodo = levantar_dev(&estado).await;
    let mut coord = NodoDagDev::nuevo(&estado, nodo.manejo.clone());
    let peer = un_peer();

    coord.atender(EventoRed::PeerConectado(peer)).await;
    let nuevos = coord
        .atender(EventoRed::Respuesta {
            peer,
            peticion: 0,
            respuesta: Box::new(Respuesta::NoDisponible),
        })
        .await;

    assert!(nuevos.is_empty());
    assert!(!coord.esta_listo(&peer));
    assert!(!coord.esta_pendiente(&peer));
    let motivo = coord
        .motivo_de_desconexion(&peer)
        .expect("motivo observado");
    assert_eq!(motivo, MOTIVO_ESTADO_DISCREPANTE);
    assert!(!motivo.puntua());
    nodo.tarea.abort();
}

/// Un evento tardío sin pendiente **no puede** marcar listo.
#[tokio::test]
async fn un_evento_tardio_sin_pendiente_no_marca_listo() {
    let estado = iniciar_bootstrap_dag_dev().expect("bootstrap dev");
    let nodo = levantar_dev(&estado).await;
    let mut coord = NodoDagDev::nuevo(&estado, nodo.manejo.clone());
    let peer = un_peer();

    // Nunca hubo `PeerConectado`: no está pendiente.
    let esperado = coord.estado_local();
    let nuevos = coord.atender(respuesta_estado(peer, esperado)).await;
    assert!(nuevos.is_empty(), "sin pendiente no hay verificación");
    assert!(!coord.esta_listo(&peer));
    assert_eq!(coord.motivo_de_desconexion(&peer), None);
    nodo.tarea.abort();
}

/// El vencimiento del plazo elimina al pendiente, no lo marca listo y no puntúa.
#[tokio::test]
async fn el_vencimiento_del_plazo_no_marca_listo() {
    let estado = iniciar_bootstrap_dag_dev().expect("bootstrap dev");
    let nodo = levantar_dev(&estado).await;
    let mut coord = NodoDagDev::nuevo(&estado, nodo.manejo.clone());
    let peer = un_peer();

    coord.atender(EventoRed::PeerConectado(peer)).await;
    assert_eq!(coord.peers_pendientes().len(), 1);

    let vencidos = coord.expirar(Instant::now() + PLAZO_SALUDO_DEV).await;
    assert_eq!(vencidos, vec![peer]);
    assert!(!coord.esta_listo(&peer));
    assert!(!coord.esta_pendiente(&peer));

    let motivo = coord
        .motivo_de_desconexion(&peer)
        .expect("motivo observado");
    assert_eq!(motivo, MOTIVO_SALUDO_VENCIDO);
    assert!(!motivo.puntua(), "C-NET-05: la lentitud no puntúa");
    assert_eq!(motivo.puntos(), 0);
    assert_ne!(motivo, MotivoDesconexion::ViolacionDeConsenso);
    nodo.tarea.abort();
}

/// `PeerDesconectado` elimina al peer de pendientes y de listos.
#[tokio::test]
async fn peer_desconectado_elimina_de_pendientes_y_listos() {
    let estado = iniciar_bootstrap_dag_dev().expect("bootstrap dev");
    let nodo = levantar_dev(&estado).await;
    let mut coord = NodoDagDev::nuevo(&estado, nodo.manejo.clone());
    let peer = un_peer();

    coord.atender(EventoRed::PeerConectado(peer)).await;
    let esperado = coord.estado_local();
    coord.atender(respuesta_estado(peer, esperado)).await;
    assert!(coord.esta_listo(&peer));

    coord.atender(EventoRed::PeerDesconectado(peer)).await;
    assert!(!coord.esta_listo(&peer));
    assert!(!coord.esta_pendiente(&peer));
    nodo.tarea.abort();
}

/// Un fallo de petición corta sin puntuar y no marca listo.
#[tokio::test]
async fn un_fallo_de_peticion_no_marca_listo() {
    let estado = iniciar_bootstrap_dag_dev().expect("bootstrap dev");
    let nodo = levantar_dev(&estado).await;
    let mut coord = NodoDagDev::nuevo(&estado, nodo.manejo.clone());
    let peer = un_peer();

    coord.atender(EventoRed::PeerConectado(peer)).await;
    coord.atender(EventoRed::PeticionFallida { peer }).await;

    assert!(!coord.esta_listo(&peer));
    assert!(!coord.esta_pendiente(&peer));
    let motivo = coord
        .motivo_de_desconexion(&peer)
        .expect("motivo observado");
    assert_eq!(motivo, MOTIVO_SALUDO_VENCIDO);
    assert!(!motivo.puntua());
    nodo.tarea.abort();
}

// ── 3 · Tres nodos reales sobre MemoryTransport ──────────────────────────────────────────────

/// A–B–C: cada enlace completa el saludo y los tres conservan el mismo hash dev.
///
/// No hay bloques: el fixture dev no admite PoST y el códec dev solo negocia `Estado`. A y C no se
/// marcan listos por topología ni por `PeerConectado`; cada enlace debe completar el cotejo.
#[tokio::test]
async fn tres_nodos_cotejan_el_mismo_hash_dev_sin_bloques() {
    let estado = iniciar_bootstrap_dag_dev().expect("bootstrap dev");

    let mut a = levantar_dev(&estado).await;
    let mut b = levantar_dev(&estado).await;
    let mut c = levantar_dev(&estado).await;

    let mut coord_a = NodoDagDev::nuevo(&estado, a.manejo.clone());
    let mut coord_b = NodoDagDev::nuevo(&estado, b.manejo.clone());
    let mut coord_c = NodoDagDev::nuevo(&estado, c.manejo.clone());

    // Topología en línea: A ── B ── C. A y C no se conocen.
    a.manejo.marcar(b.addr.clone()).await.expect("A marca B");
    c.manejo.marcar(b.addr.clone()).await.expect("C marca B");

    let limite = tokio::time::Instant::now() + PLAZO_RED;
    loop {
        if coord_a.peers_listos().len() == 1
            && coord_b.peers_listos().len() == 2
            && coord_c.peers_listos().len() == 1
        {
            break;
        }
        tokio::select! {
            ev = a.eventos.recv() => {
                let e = ev.expect("canal de A");
                let conectado = if let EventoRed::PeerConectado(p) = &e { Some(*p) } else { None };
                coord_a.atender(e).await;
                if let Some(p) = conectado {
                    assert!(!coord_a.esta_listo(&p), "A: PeerConectado no marca listo");
                }
            }
            ev = b.eventos.recv() => {
                let e = ev.expect("canal de B");
                let conectado = if let EventoRed::PeerConectado(p) = &e { Some(*p) } else { None };
                coord_b.atender(e).await;
                if let Some(p) = conectado {
                    assert!(!coord_b.esta_listo(&p), "B: PeerConectado no marca listo");
                }
            }
            ev = c.eventos.recv() => {
                let e = ev.expect("canal de C");
                let conectado = if let EventoRed::PeerConectado(p) = &e { Some(*p) } else { None };
                coord_c.atender(e).await;
                if let Some(p) = conectado {
                    assert!(!coord_c.esta_listo(&p), "C: PeerConectado no marca listo");
                }
            }
            _ = tokio::time::sleep_until(limite) => {
                panic!(
                    "A–B–C no cotejaron el saludo: A={}, B={}, C={}",
                    coord_a.peers_listos().len(),
                    coord_b.peers_listos().len(),
                    coord_c.peers_listos().len()
                );
            }
        }
    }

    // Los tres conservan el mismo hash dev y el mismo estado inicial de transporte.
    for (nombre, coord) in [("A", &coord_a), ("B", &coord_b), ("C", &coord_c)] {
        assert_eq!(coord.hash_dev().as_bytes(), &HASH_DEV, "{nombre}");
        assert_eq!(
            coord.estado_local().genesis.as_bytes(),
            &HASH_DEV,
            "{nombre}"
        );
        assert_eq!(coord.estado_local().altura, 0, "{nombre}");
        assert_eq!(coord.estado_local().trabajo, [0u8; 32], "{nombre}");
    }
    assert_eq!(coord_a.estado_local(), coord_b.estado_local());
    assert_eq!(coord_b.estado_local(), coord_c.estado_local());
    assert!(coord_a.peers_pendientes().is_empty());
    assert!(coord_b.peers_pendientes().is_empty());
    assert!(coord_c.peers_pendientes().is_empty());

    a.tarea.abort();
    b.tarea.abort();
    c.tarea.abort();
}

// ── 4 · Impostor y perfil ajeno ─────────────────────────────────────────────────────────────

/// Un impostor con otro génesis sobre el mismo protocolo dev: nunca queda listo y se desconecta.
#[tokio::test]
async fn el_impostor_con_otro_genesis_no_se_marca_y_se_desconecta() {
    let estado = iniciar_bootstrap_dag_dev().expect("bootstrap dev");
    let mut honesto = levantar_dev(&estado).await;
    let impostor = levantar_con(ParametrosRed::dag_dev(), EstadoFijo(estado_impostor())).await;

    honesto
        .manejo
        .marcar(impostor.addr.clone())
        .await
        .expect("el honesto marca al impostor");
    let mut coord = NodoDagDev::nuevo(&estado, honesto.manejo.clone());

    let mut peer: Option<PeerId> = None;
    let mut vio_respuesta = false;
    let mut vio_desconexion = false;
    let limite = tokio::time::Instant::now() + PLAZO_RED;
    while !(vio_respuesta && vio_desconexion) {
        let resto = limite.saturating_duration_since(tokio::time::Instant::now());
        assert!(!resto.is_zero(), "se agotó el plazo del impostor");
        let e = tokio::time::timeout(resto, honesto.eventos.recv())
            .await
            .expect("plazo de red")
            .expect("canal del honesto");
        match &e {
            EventoRed::PeerConectado(p) => peer = Some(*p),
            EventoRed::Respuesta { .. } => vio_respuesta = true,
            EventoRed::PeerDesconectado(p) if Some(*p) == peer => vio_desconexion = true,
            _ => {}
        }
        coord.atender(e).await;
        if let Some(p) = peer {
            assert!(!coord.esta_listo(&p), "el impostor nunca queda listo");
        }
    }

    let p = peer.expect("se vio la conexión del impostor");
    assert!(!coord.esta_listo(&p));
    assert!(!coord.esta_pendiente(&p));
    let motivo = coord.motivo_de_desconexion(&p).expect("motivo observado");
    assert_eq!(motivo, MOTIVO_ESTADO_DISCREPANTE);
    assert!(!motivo.puntua(), "C-NET-05: no puntúa");

    honesto.tarea.abort();
    impostor.tarea.abort();
}

/// Un peer con perfil testnet: los protocolos de sync no casan y el plazo lo corta.
///
/// La conexión Noise **puede** cruzarse —el `magic` no está en el wire (C-NET-01 pendiente)—, pero
/// el saludo de génesis no se completa y el coordinador lo desconecta sin puntuar. No se cuenta el
/// `magic` como barrera del wire.
#[tokio::test]
async fn un_peer_de_testnet_no_negocia_el_sync_dev_y_lo_corta_el_plazo() {
    let estado = iniciar_bootstrap_dag_dev().expect("bootstrap dev");
    let mut dev = levantar_dev(&estado).await;
    let testnet = levantar_con(
        ParametrosRed::de(Red::Testnet),
        EstadoFijo(estado_impostor()),
    )
    .await;

    assert_ne!(
        ParametrosRed::de(Red::Testnet).protocolo_sync(),
        ParametrosRed::dag_dev().protocolo_sync(),
        "el protocolo dev MUST ser propio"
    );

    dev.manejo
        .marcar(testnet.addr.clone())
        .await
        .expect("el dev marca al testnet");
    let mut coord = NodoDagDev::nuevo(&estado, dev.manejo.clone());

    // La conexión cruzada puede existir: se observa `PeerConectado`, que no es identidad DAG.
    let peer = esperar_peer_conectado(&mut dev.eventos).await;
    coord.atender(EventoRed::PeerConectado(peer)).await;
    assert!(!coord.esta_listo(&peer));
    assert!(coord.esta_pendiente(&peer));

    // El plazo de desarrollo lo corta: el sync dev no negocia con testnet.
    let vencidos = coord
        .expirar(Instant::now() + PLAZO_SALUDO_DEV + Duration::from_secs(1))
        .await;
    assert_eq!(vencidos, vec![peer]);
    assert!(!coord.esta_listo(&peer));
    assert!(!coord.esta_pendiente(&peer));
    let motivo = coord
        .motivo_de_desconexion(&peer)
        .expect("motivo observado");
    assert_eq!(motivo, MOTIVO_SALUDO_VENCIDO);
    assert!(!motivo.puntua());

    dev.tarea.abort();
    testnet.tarea.abort();
}

// ── 5 · El binario ──────────────────────────────────────────────────────────────────────────

/// Ejecuta el binario con un tope de tiempo y devuelve su salida; mata si se pasa.
fn ejecutar(exe: &str, args: &[&str], plazo: Duration) -> std::process::Output {
    use std::process::{Command, Stdio};

    let mut hijo = Command::new(exe)
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .expect("el binario dev MUST ejecutarse");
    let inicio = Instant::now();
    loop {
        match hijo.try_wait().expect("espera del binario dev") {
            Some(_) => break,
            None if inicio.elapsed() > plazo => {
                let _ = hijo.kill();
                let _ = hijo.wait();
                panic!("el binario dev no terminó en {plazo:?} con {args:?}");
            }
            None => std::thread::sleep(Duration::from_millis(10)),
        }
    }
    hijo.wait_with_output().expect("salida del binario dev")
}

/// `--help` muestra los flags locales y no expone `--red` ni `--datos`; una escucha no loopback
/// falla antes de abrir socket.
#[test]
fn el_bin_muestra_flags_locales_y_rechaza_escucha_no_loopback() {
    let exe = env!("CARGO_BIN_EXE_zx-dag-dev");

    let ayuda = ejecutar(exe, &["--help"], Duration::from_secs(10));
    assert!(ayuda.status.success(), "--help MUST salir con éxito");
    let texto = String::from_utf8_lossy(&ayuda.stdout);
    let opciones: Vec<&str> = texto.lines().map(str::trim_start).collect();
    assert!(
        opciones.iter().any(|l| l.starts_with("--listen")),
        "falta --listen: {texto}"
    );
    assert!(
        opciones.iter().any(|l| l.starts_with("--peer")),
        "falta --peer: {texto}"
    );
    assert!(
        !texto.contains("--red"),
        "--red MUST NOT aparecer en la ayuda: {texto}"
    );
    assert!(
        !texto.contains("--datos"),
        "--datos MUST NOT aparecer en la ayuda: {texto}"
    );

    // `127.0.0.2` es loopback técnico (`127/8`), pero la orden solo autoriza `127.0.0.1` o `::1`.
    // La dirección doble tiene una IP loopback y otra externa: debe rechazarse igualmente.
    let con_dos_ip = Multiaddr::empty()
        .with(libp2p::multiaddr::Protocol::Ip4(
            std::net::Ipv4Addr::LOCALHOST,
        ))
        .with(libp2p::multiaddr::Protocol::Ip4(std::net::Ipv4Addr::new(
            8, 8, 8, 8,
        )))
        .with(libp2p::multiaddr::Protocol::Tcp(1));
    let malas = [
        "/ip4/0.0.0.0/tcp/0".to_string(),
        "/ip4/8.8.8.8/tcp/1".to_string(),
        "/ip4/127.0.0.2/tcp/0".to_string(),
        "/dns4/example.com/tcp/1".to_string(),
        con_dos_ip.to_string(),
    ];
    for mala in &malas {
        let salida = ejecutar(exe, &["--listen", mala.as_str()], Duration::from_secs(10));
        assert!(!salida.status.success(), "{mala} MUST rechazarse");
        let err = String::from_utf8_lossy(&salida.stderr);
        assert!(
            err.to_lowercase().contains("loopback") || err.contains("hostname"),
            "{mala}: {err}"
        );
    }

    let salida = ejecutar(
        exe,
        &["--peer", "/ip4/8.8.8.8/tcp/1"],
        Duration::from_secs(10),
    );
    assert!(!salida.status.success(), "un peer externo MUST rechazarse");

    // Un peer `127.0.0.2` tampoco pasa: el rechazo es por igualdad exacta, no por `is_loopback`.
    let salida = ejecutar(
        exe,
        &["--peer", "/ip4/127.0.0.2/tcp/0"],
        Duration::from_secs(10),
    );
    assert!(
        !salida.status.success(),
        "un peer 127.0.0.2 MUST rechazarse"
    );
}

// ── 6 · Aviso del modo red y apagado acotado ────────────────────────────────────────────────

/// Proceso del binario en marcha con su `stdout` leído línea a línea en un hilo aparte.
///
/// La limpieza es RAII: [`Drop`] mata y cosecha al hijo si sigue vivo y recoge el hilo lector. Así,
/// si una aserción falla antes de [`BinarioVivo::interrumpir`], no queda proceso huérfano.
#[cfg(unix)]
struct BinarioVivo {
    /// `None` una vez cosechado: `esperar_fin` o `Drop` lo consumen, nunca ambos.
    hijo: Option<std::process::Child>,
    lineas: std::sync::mpsc::Receiver<String>,
    lector: Option<std::thread::JoinHandle<Vec<String>>>,
}

#[cfg(unix)]
impl BinarioVivo {
    /// Arranca el binario y empieza a leer su `stdout`.
    fn arrancar(exe: &str, args: &[&str]) -> Self {
        use std::io::{BufRead, BufReader};
        use std::process::{Command, Stdio};

        let mut hijo = Command::new(exe)
            .args(args)
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .spawn()
            .expect("el binario dev MUST ejecutarse");
        let stdout = hijo.stdout.take().expect("stdout del binario dev");
        let (tx, rx) = std::sync::mpsc::channel::<String>();
        let lector = std::thread::spawn(move || {
            let mut todas = Vec::new();
            for linea in BufReader::new(stdout).lines() {
                let Ok(l) = linea else { break };
                let _ = tx.send(l.clone());
                todas.push(l);
            }
            todas
        });
        Self {
            hijo: Some(hijo),
            lineas: rx,
            lector: Some(lector),
        }
    }

    /// Espera a que la salida contenga `aguja` dentro del plazo.
    fn esperar_linea(&self, aguja: &str, plazo: Duration) -> bool {
        let limite = Instant::now() + plazo;
        while Instant::now() < limite {
            let resto = limite.saturating_duration_since(Instant::now());
            match self
                .lineas
                .recv_timeout(resto.min(Duration::from_millis(200)))
            {
                Ok(l) if l.contains(aguja) => return true,
                Ok(_) => {}
                Err(std::sync::mpsc::RecvTimeoutError::Timeout) => {}
                Err(std::sync::mpsc::RecvTimeoutError::Disconnected) => return false,
            }
        }
        false
    }

    /// Manda `SIGINT` al proceso, la señal con la que el runner se apaga.
    #[allow(unsafe_code, reason = "FFI mínima a kill(2); no se toca memoria")]
    fn interrumpir(&self) {
        // SIGINT = 2.
        unsafe extern "C" {
            fn kill(pid: i32, sig: i32) -> i32;
        }
        let hijo = self
            .hijo
            .as_ref()
            .expect("el binario sigue vivo antes de interrumpir");
        // SAFETY: `kill(2)` solo envía una señal al proceso indicado.
        let codigo = unsafe { kill(hijo.id() as i32, 2) };
        assert_eq!(codigo, 0, "no se pudo enviar SIGINT al binario dev");
    }

    /// Espera el fin dentro del plazo; si no termina, lo mata, lo cosecha y falla. Devuelve estado y
    /// salida. Deja el hijo cosechado: `Drop` no vuelve a esperarlo.
    fn esperar_fin(&mut self, plazo: Duration) -> (std::process::ExitStatus, Vec<String>) {
        let inicio = Instant::now();
        let estado;
        loop {
            let observado = {
                let hijo = self
                    .hijo
                    .as_mut()
                    .expect("el binario se espera una sola vez");
                hijo.try_wait().expect("espera del binario dev")
            };
            match observado {
                Some(estado_visto) => {
                    estado = estado_visto;
                    break;
                }
                None if inicio.elapsed() > plazo => {
                    // Cosecha explícita antes de fallar: sin huérfanos aunque el plazo venza.
                    self.cosechar();
                    panic!("el binario dev no se apagó en {plazo:?}");
                }
                None => std::thread::sleep(Duration::from_millis(10)),
            }
        }
        self.hijo = None;
        let salida = self
            .lector
            .take()
            .expect("el lector se toma una sola vez")
            .join()
            .expect("el lector de stdout no debe panicar");
        (estado, salida)
    }

    /// Mata y cosecha al hijo si sigue vivo. No propaga errores ni panics: es seguro en `Drop`.
    fn cosechar(&mut self) {
        if let Some(mut hijo) = self.hijo.take() {
            let _ = hijo.kill();
            let _ = hijo.wait();
        }
    }
}

#[cfg(unix)]
impl Drop for BinarioVivo {
    /// Limpieza garantizada: sin `assert` ni propagación de panic. Si el test falla antes de
    /// [`BinarioVivo::interrumpir`], el hijo se mata y se cosecha, y el hilo lector termina.
    fn drop(&mut self) {
        self.cosechar();
        // Con el hijo ya muerto y cosechado, su `stdout` llega a EOF y el lector termina solo; el
        // `join` no puede bloquearse indefinidamente ni propaga un panic del hilo.
        if let Some(lector) = self.lector.take() {
            let _ = lector.join();
        }
    }
}

/// Con `--listen` el aviso MUST ser veraz —hay red pero sin persistencia ni admisión PoST— y el
/// proceso MUST apagarse de forma acotada con `SIGINT`, cerrando todos los handles.
///
/// Se omite en plataformas no Unix: requiere `kill(2)` para mandar la señal.
#[cfg(unix)]
#[test]
fn el_aviso_de_modo_red_es_veraz_y_se_apaga_acotado() {
    let exe = env!("CARGO_BIN_EXE_zx-dag-dev");
    let mut vivo = BinarioVivo::arrancar(exe, &["--listen"]);

    assert!(
        vivo.esperar_linea("saludo P2P loopback", Duration::from_secs(10)),
        "el aviso del modo red MUST imprimirse"
    );
    assert!(
        vivo.esperar_linea("escuchando en", Duration::from_secs(10)),
        "el binario MUST confirmar la dirección realmente asignada"
    );

    vivo.interrumpir();
    let (estado, salida) = vivo.esperar_fin(Duration::from_secs(15));
    let texto = salida.join("\n");

    assert!(
        !texto.contains("solo bootstrap local; sin red"),
        "en modo red MUST NOT decir que no hay red: {texto}"
    );
    assert!(
        texto.contains("señal recibida"),
        "el apagado cooperativo MUST anunciarse: {texto}"
    );
    assert!(
        estado.success(),
        "el apagado MUST cerrar todos los handles y terminar sin error: {estado:?}\n{texto}"
    );
}
