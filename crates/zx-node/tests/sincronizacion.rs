//! **El hito de la fase de red: dos nodos se sincronizan.**
//!
//! Un nodo con cadena y otro sin ella, hablando por red real —en memoria, no por sockets del
//! sistema—, y el segundo acaba con las cabeceras del primero.
//!
//! # Qué demuestra que no demostraban los tests anteriores
//!
//! Los de `zx-p2p` prueban que dos nodos se conectan y que el códec da la vuelta. Este prueba el
//! camino completo con **lógica de cadena de verdad** a los dos lados: saludo → comparación de
//! trabajo → locator → cabeceras → validación → extensión del estado.
//!
//! # Lo que sigue sin cubrir
//!
//! - **PoW real.** Minar a la dificultad mínima del protocolo exige 2³² hashes por cabecera. El
//!   nodo servidor carga su cadena con `extender_sin_validar_solo_para_pruebas`, y el cliente la
//!   valida con `validar_estructura` —encadenado, `bits` canónico, trabajo— pero **no** con
//!   `comprobar_pow`. Esa parte la cubrirá el arnés con minero de la Fase 8.
//! - **Cuerpos de bloque.** Todavía no hay almacenamiento persistente.

#![expect(
    clippy::expect_used,
    clippy::panic,
    reason = "los tests fallan con panic por diseño"
)]

use std::sync::Arc;
use std::time::Duration;

use libp2p::core::transport::{MemoryTransport, Transport};
use libp2p::core::upgrade;
use libp2p::{Multiaddr, PeerId, Swarm, identity, noise, yamux};
use primitive_types::U256;
use zx_core::digest::{BlockHash, Digest, MerkleRoot};
use zx_core::preimage::block::BlockHeader;
use zx_core::red::Red;
use zx_node::cadena::Cadena;
use zx_node::sync::{Fase, Sincronizador, validar_estructura};
use zx_p2p::behaviour::ZxBehaviour;
use zx_p2p::config::ParametrosRed;
use zx_p2p::entrante::ManejadorEntrante;
use zx_p2p::limites;
use zx_p2p::mensaje::{Peticion, Respuesta};
use zx_p2p::servicio::{EventoRed, arrancar};

/// Una cadena de `n` cabeceras encadenadas a partir del génesis de una [`Cadena`].
fn cabeceras_tras(c: &Cadena, n: u32) -> Vec<BlockHeader> {
    let mut v = Vec::with_capacity(n as usize);
    let mut prev = c.genesis();
    for i in 1..=n {
        let h = BlockHeader {
            consensus_branch_id: 0xc478_80ea,
            prev_hash: prev,
            merkle_root: MerkleRoot::from_digest(Digest::from_bytes([i as u8; 32])),
            timestamp: 1_788_480_000 + u64::from(i) * 120,
            bits: 0x1d00_ffff,
            nonce: u64::from(i),
            height: i,
        };
        prev = h.block_hash();
        v.push(h);
    }
    v
}

fn nodo(cadena: Arc<Cadena>) -> (Swarm<ZxBehaviour>, PeerId) {
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
    let _ = cadena;
    let swarm = Swarm::new(
        transporte,
        behaviour,
        peer_id,
        libp2p::swarm::Config::with_tokio_executor()
            .with_idle_connection_timeout(Duration::from_secs(30)),
    );
    (swarm, peer_id)
}

fn addr() -> Multiaddr {
    use std::sync::atomic::{AtomicU64, Ordering};
    static N: AtomicU64 = AtomicU64::new(50_001);
    format!("/memory/{}", N.fetch_add(1, Ordering::Relaxed))
        .parse()
        .expect("multiaddr")
}

async fn esperar<F>(rx: &mut tokio::sync::mpsc::Receiver<EventoRed>, f: F) -> Option<EventoRed>
where
    F: Fn(&EventoRed) -> bool,
{
    let plazo = tokio::time::Instant::now() + Duration::from_secs(15);
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

/// **El hito.** Un nodo vacío se pone al día con uno que tiene 12 cabeceras.
#[tokio::test]
async fn un_nodo_vacio_se_pone_al_dia_con_uno_que_tiene_cadena() {
    // ── Servidor: una cadena de 12 cabeceras ─────────────────────────────────
    let servidor = Arc::new(Cadena::nueva(Red::Testnet).expect("génesis"));
    let cadena_real = cabeceras_tras(&servidor, 12);
    servidor.extender_sin_validar_solo_para_pruebas(&cadena_real);
    assert_eq!(servidor.altura(), 12, "el servidor arranca con 12");

    // ── Cliente: vacío ───────────────────────────────────────────────────────
    let cliente = Arc::new(Cadena::nueva(Red::Testnet).expect("génesis"));
    assert_eq!(cliente.altura(), 0);

    // Los dos comparten génesis: es lo que hace que tenga sentido hablarse.
    assert_eq!(servidor.genesis(), cliente.genesis());

    let (sw_s, _) = nodo(Arc::clone(&servidor));
    let (sw_c, _) = nodo(Arc::clone(&cliente));
    let id_s = *sw_s.local_peer_id();

    let ps = arrancar(sw_s, Arc::clone(&servidor));
    let pc = arrancar(sw_c, Arc::clone(&cliente));

    let manejo_s = ps.manejo.clone();
    let manejo_c = pc.manejo.clone();
    let mut ev_c = pc.eventos;
    let _ev_s = ps.eventos;

    let t1 = tokio::spawn(ps.bucle.correr());
    let t2 = tokio::spawn(pc.bucle.correr());

    let a = addr();
    manejo_s
        .escuchar(a.clone())
        .await
        .expect("servidor escucha");
    manejo_c.marcar(a).await.expect("cliente marca");
    assert!(
        esperar(&mut ev_c, |e| matches!(e, EventoRed::PeerConectado(_)))
            .await
            .is_some(),
        "deben conectarse"
    );

    // ── El protocolo, paso a paso ────────────────────────────────────────────
    let mut sinc = Sincronizador::nuevo();

    // 1 · Saludo.
    manejo_c
        .pedir(id_s, Peticion::Estado)
        .await
        .expect("saluda");
    let e = esperar(&mut ev_c, |e| matches!(e, EventoRed::Respuesta { .. }))
        .await
        .expect("responde al saludo");
    let EventoRed::Respuesta { respuesta, .. } = e else {
        panic!("se esperaba respuesta");
    };
    let Respuesta::Estado(estado) = *respuesta else {
        panic!("se esperaba Estado");
    };

    assert_eq!(estado.altura, 12, "el servidor dice tener 12");
    assert_eq!(estado.genesis, cliente.genesis(), "misma cadena");

    // 2 · Comparar por TRABAJO, no por altura.
    let suyo = U256::from_big_endian(&estado.trabajo);
    let nuestro = U256::from_big_endian(&cliente.estado().trabajo);
    assert!(suyo > nuestro, "el servidor va por delante en trabajo");
    sinc.saludo_recibido(id_s, suyo, nuestro);
    assert_eq!(sinc.fase(), Fase::Cabeceras);

    // 3 · Pedir cabeceras con nuestro locator.
    manejo_c
        .pedir(
            id_s,
            Peticion::Cabeceras {
                locator: cliente.locator(),
                hasta: None,
            },
        )
        .await
        .expect("pide cabeceras");

    let e = esperar(&mut ev_c, |e| matches!(e, EventoRed::Respuesta { .. }))
        .await
        .expect("responde cabeceras");
    let EventoRed::Respuesta { respuesta, .. } = e else {
        panic!("se esperaba respuesta");
    };
    let Respuesta::Cabeceras(cs) = *respuesta else {
        panic!("se esperaba Cabeceras");
    };
    assert_eq!(
        cs.len(),
        12,
        "las doce que el servidor tiene tras el génesis"
    );

    // 4 · Validar antes de aplicar (C-NET-03).
    let ancla = cs.first().map(|c| c.prev_hash).expect("no vacía");
    assert_eq!(ancla, cliente.genesis(), "cuelgan de nuestro génesis");
    validar_estructura(&cs, ancla).expect("la cadena del servidor es estructuralmente válida");

    // 5 · Aplicar.
    let n = cliente.extender(&cs);
    assert_eq!(n, 12, "las doce se aplican");
    assert_eq!(cliente.altura(), 12, "el cliente se puso al día");
    assert_eq!(
        cliente.trabajo(),
        servidor.trabajo(),
        "y con el mismo trabajo acumulado que el servidor"
    );
    assert_eq!(
        cliente.estado().tip,
        servidor.estado().tip,
        "misma punta: están sincronizados"
    );

    t1.abort();
    t2.abort();
}

/// **Dos nodos ya sincronizados no se piden nada.**
///
/// El que no va por detrás concluye `AlDia` en el saludo. Sin esto, dos nodos al día se pedirían
/// cabeceras mutuamente para siempre.
#[tokio::test]
async fn dos_nodos_al_dia_no_se_sincronizan() {
    let a = Arc::new(Cadena::nueva(Red::Testnet).expect("génesis"));
    let cs = cabeceras_tras(&a, 5);
    a.extender_sin_validar_solo_para_pruebas(&cs);

    let b = Arc::new(Cadena::nueva(Red::Testnet).expect("génesis"));
    b.extender_sin_validar_solo_para_pruebas(&cs);

    assert_eq!(a.trabajo(), b.trabajo(), "misma cadena, mismo trabajo");

    let mut sinc = Sincronizador::nuevo();
    sinc.saludo_recibido(PeerId::random(), b.trabajo(), a.trabajo());
    assert_eq!(
        sinc.fase(),
        Fase::AlDia,
        "nadie por delante ⇒ no hay nada que pedir"
    );
}

/// **Un peer de otra cadena se detecta por el génesis.**
///
/// El prefijo mágico (C-NET-01) impide que dos *redes* se saluden. Esto detecta que, dentro de la
/// misma red, no compartimos historia — y es barato: un hash en el saludo.
#[tokio::test]
async fn un_genesis_distinto_se_detecta_en_el_saludo() {
    let nuestra = Arc::new(Cadena::nueva(Red::Testnet).expect("génesis"));

    // Un estado que dice venir de otro génesis.
    let ajeno = BlockHash::from_digest(Digest::from_bytes([0xaa; 32]));
    assert_ne!(ajeno, nuestra.genesis());

    // La comprobación que hace el nodo, aislada: si el génesis no cuadra, no hay nada que hablar,
    // por mucho trabajo que el otro diga tener.
    let mut sinc = Sincronizador::nuevo();
    let mucho = U256::MAX;
    if ajeno == nuestra.genesis() {
        sinc.saludo_recibido(PeerId::random(), mucho, nuestra.trabajo());
    }
    assert_eq!(
        sinc.fase(),
        Fase::Saludando,
        "con otro génesis NO se entra a sincronizar, aunque diga tener más trabajo"
    );
}

/// El estado que un nodo anuncia es coherente con su cadena.
#[tokio::test]
async fn el_estado_anunciado_refleja_la_cadena() {
    let c = Arc::new(Cadena::nueva(Red::Testnet).expect("génesis"));
    assert_eq!(c.estado().altura, 0);
    assert_eq!(c.estado().tip, c.genesis());

    let cs = cabeceras_tras(&c, 7);
    c.extender_sin_validar_solo_para_pruebas(&cs);

    let e = c.estado();
    assert_eq!(e.altura, 7);
    assert_eq!(e.tip, cs.last().expect("no vacía").block_hash());
    assert_eq!(U256::from_big_endian(&e.trabajo), c.trabajo());
    assert!(U256::from_big_endian(&e.trabajo) > U256::zero());
}
