//! **El hito de la Fase 5: una testnet local de tres nodos.**
//!
//! # Qué prueba esto que no probaba el arnés de dos
//!
//! Dos cosas, y la segunda importa más que la primera.
//!
//! **1 · Que la sincronización es transitiva.** A tiene cadena, B se la coge de A, y C se la coge
//! **de B** — que no la había minado, solo recibido. Con dos nodos no se puede distinguir "sabe
//! servir lo suyo" de "sabe servir lo que le dieron", y son cosas distintas: la segunda es la que
//! hace que una red crezca más allá del nodo que mina.
//!
//! **2 · Que el código bajo test es el que corre.** El arnés de dos nodos conduce el protocolo a
//! mano: pide el saludo, compara el trabajo, pide cabeceras y las aplica, todo escrito en el test.
//! Eso probaba que las piezas encajan, no que el nodo funcione — el driver de verdad vivía en
//! `main.rs`, privado, y ninguna prueba lo tocaba. Aquí cada nodo es un [`Nodo`] real, conducido
//! por el mismo bucle que el binario, y nadie escribe el protocolo por segunda vez.
//!
//! # Por qué en malla de memoria y no por sockets
//!
//! `MemoryTransport` da la pila entera —Noise, Yamux, multiplexación, `request_response`— sin
//! puertos del sistema. Un test que abre puertos es un test que falla en CI cuando otro los tiene
//! cogidos, y esa clase de fallo enseña a la gente a reintentar en vez de a mirar.
//!
//! # Lo que este arnés encontró nada más existir
//!
//! Los tres tests del hito **no pasan**, y el motivo no es el arnés: es que el nodo real comprueba
//! el PoW y las cabeceras sintéticas no lo tienen. El arnés de dos nodos no lo veía porque llamaba
//! a `validar_estructura` a mano y **se saltaba `comprobar_pow`** — validaba menos que el nodo. El
//! hito «dos nodos se sincronizan» describía una segunda copia del protocolo, más permisiva que la
//! que corre.
//!
//! No se puede arreglar desde el test. El target más fácil que el protocolo admite es
//! `POW_LIMIT = 2²²⁴ − 1`, así que **la cabecera más barata que existe cuesta ~2³² hashes**. Es la
//! misma pared que Bitcoin y Zcash rodean con una red `regtest` de dificultad trivial, y esa es una
//! decisión de consenso que no me corresponde tomar sola: está abierta como **P-031**.
//!
//! Mientras tanto los tres tests del hito quedan `#[ignore]` —con el motivo escrito en cada uno— y
//! el que sí corre es [`el_nodo_real_rechaza_cabeceras_sin_pow`], que fija el hallazgo para que no
//! se pierda.

#![expect(
    clippy::expect_used,
    clippy::panic,
    reason = "los tests fallan con panic por diseño"
)]

use std::sync::Arc;
use std::time::Duration;

use libp2p::core::transport::{MemoryTransport, Transport};
use libp2p::core::upgrade;
use libp2p::{Multiaddr, Swarm, identity, noise, yamux};
use tokio::task::JoinHandle;
use zx_core::digest::{Digest, MerkleRoot};
use zx_core::preimage::block::BlockHeader;
use zx_core::red::Red;
use zx_node::cadena::Cadena;
use zx_node::nodo::{Fin, Nodo};
use zx_p2p::behaviour::ZxBehaviour;
use zx_p2p::config::ParametrosRed;
use zx_p2p::entrante::ManejadorEntrante;
use zx_p2p::limites;
use zx_p2p::servicio::{ManejoRed, arrancar};

/// Cuánto se le da a la red para converger antes de declarar el fallo.
///
/// Generoso a propósito: en `MemoryTransport` la convergencia real son milisegundos, así que
/// agotar quince segundos no significa "iba lento", significa **atascado**. Un plazo justo
/// convertiría un test correcto en uno que parpadea, y un test que parpadea se acaba ignorando.
const PLAZO: Duration = Duration::from_secs(15);

/// Un nodo de la malla: su cadena, su asa a la red y las tareas que lo mantienen vivo.
struct EnMalla {
    manejo: ManejoRed,
    addr: Multiaddr,
    tareas: Vec<JoinHandle<()>>,
}

impl EnMalla {
    /// Corta este nodo en seco, como un `kill -9`.
    ///
    /// Se abortan las tareas en vez de cerrar el canal a propósito: un apagado limpio prueba el
    /// apagado limpio, y lo que hace falta probar es que **los demás sobreviven a una caída**.
    fn matar(self) {
        for t in &self.tareas {
            t.abort();
        }
        drop(self.manejo);
    }
}

/// Levanta un nodo completo: swarm, bucle de red y el driver de `zx_node::nodo`.
async fn levantar(cadena: Arc<Cadena>) -> EnMalla {
    trazas();
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
    let swarm = Swarm::new(
        transporte,
        behaviour,
        peer_id,
        libp2p::swarm::Config::with_tokio_executor()
            .with_idle_connection_timeout(Duration::from_secs(30)),
    );

    let piezas = arrancar(swarm, Arc::clone(&cadena));
    let manejo = piezas.manejo.clone();
    let mut eventos = piezas.eventos;
    // El `manejo` original se suelta aquí; el que se guarda es el clon. Si se soltaran TODOS, el
    // bucle de red terminaría solo —es su apagado cooperativo— y el nodo moriría sin que nadie lo
    // hubiera matado. Ya pasó una vez en el arnés de dos, y el test parecía un fallo del código.
    let bucle = tokio::spawn(async move {
        piezas.bucle.correr().await;
    });

    // El driver: el MISMO que corre en el binario.
    let mut nodo = Nodo::nuevo(Arc::clone(&cadena), manejo.clone());
    let driver = tokio::spawn(async move {
        while let Some(e) = eventos.recv().await {
            if nodo.atender(e).await == Fin::Detener {
                break;
            }
        }
    });

    let addr = direccion();
    manejo.escuchar(addr.clone()).await.expect("escuchar");

    EnMalla {
        manejo,
        addr,
        tareas: vec![bucle, driver],
    }
}

/// Enciende las trazas una sola vez, si `RUST_LOG` lo pide.
fn trazas() {
    use std::sync::Once;
    static UNA: Once = Once::new();
    UNA.call_once(|| {
        let _ = tracing_subscriber::fmt()
            .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
            .with_test_writer()
            .try_init();
    });
}

/// Una dirección `/memory/N` distinta cada vez, para que dos tests en paralelo no colisionen.
fn direccion() -> Multiaddr {
    use std::sync::atomic::{AtomicU64, Ordering};
    static N: AtomicU64 = AtomicU64::new(60_001);
    format!("/memory/{}", N.fetch_add(1, Ordering::Relaxed))
        .parse()
        .expect("multiaddr")
}

/// Una cabecera encadenada a `prev`, con raíz de relleno.
fn cab_base(i: u32, prev: zx_core::digest::BlockHash) -> BlockHeader {
    BlockHeader {
        consensus_branch_id: 0xc478_80ea,
        prev_hash: prev,
        merkle_root: MerkleRoot::from_digest(Digest::from_bytes([i as u8; 32])),
        timestamp: 1_788_480_000 + u64::from(i) * 120,
        bits: 0x1d00_ffff,
        nonce: u64::from(i),
        height: i,
    }
}

/// Una cadena de `n` cabeceras encadenadas tras el génesis.
fn cabeceras_tras(c: &Cadena, n: u32) -> Vec<BlockHeader> {
    let mut v = Vec::with_capacity(n as usize);
    let mut prev = c.genesis();
    for i in 1..=n {
        let h = cab_base(i, prev);
        prev = h.block_hash();
        v.push(h);
    }
    v
}

/// Espera a que una condición se cumpla, o falla con un mensaje que dice dónde se quedó.
///
/// Sondea en vez de escuchar eventos porque lo que se afirma es **el estado final de la cadena**,
/// no la secuencia de mensajes. Un test que espera una secuencia concreta se rompe cada vez que el
/// orden de los eventos cambia sin que el resultado cambie.
async fn hasta_que<F: Fn() -> bool>(que: &str, f: F) {
    let limite = tokio::time::Instant::now() + PLAZO;
    while tokio::time::Instant::now() < limite {
        if f() {
            return;
        }
        tokio::time::sleep(Duration::from_millis(20)).await;
    }
    panic!("se agotaron {PLAZO:?} esperando a que {que}");
}

/// **El hito.** Tres nodos en línea: A tiene la cadena, B la coge de A, C la coge de B.
///
/// C nunca habla con A. Si acaba con las doce cabeceras es porque B **sirvió lo que había
/// recibido**, no lo que había minado, y eso es lo que distingue una red de un par de nodos.
#[tokio::test]
#[ignore = "P-031: hace falta una red de dificultad trivial para minar PoW real en un test"]
async fn tres_nodos_en_linea_convergen() {
    let a = Arc::new(Cadena::nueva(Red::Testnet).expect("génesis"));
    let b = Arc::new(Cadena::nueva(Red::Testnet).expect("génesis"));
    let c = Arc::new(Cadena::nueva(Red::Testnet).expect("génesis"));

    let cadena_real = cabeceras_tras(&a, 12);
    a.extender_sin_validar_solo_para_pruebas(&cadena_real);
    assert_eq!(a.altura(), 12);
    assert_eq!((b.altura(), c.altura()), (0, 0));

    let na = levantar(Arc::clone(&a)).await;
    let nb = levantar(Arc::clone(&b)).await;
    let nc = levantar(Arc::clone(&c)).await;

    // Topología en línea: A ── B ── C. C no conoce la dirección de A.
    nb.manejo.marcar(na.addr.clone()).await.expect("B marca A");
    hasta_que("B se ponga al día con A", || b.altura() == 12).await;

    nc.manejo.marcar(nb.addr.clone()).await.expect("C marca B");
    hasta_que("C se ponga al día con B", || c.altura() == 12).await;

    assert_eq!(
        (a.estado().tip, b.estado().tip, c.estado().tip),
        (a.estado().tip, a.estado().tip, a.estado().tip),
        "los tres deben acabar en la misma punta"
    );
    assert_eq!(a.trabajo(), c.trabajo(), "y con el mismo trabajo acumulado");

    na.matar();
    nb.matar();
    nc.matar();
}

/// **Matas a B, vuelve sin nada, y se recupera solo.**
///
/// El hito de la Fase 5 dice «matas B, reinicia y re-sincroniza». Aquí B vuelve **con la cadena
/// vacía**, que es el caso peor: no es que le falten los últimos bloques, es que no tiene ninguno.
///
/// Lo que se comprueba de verdad son dos cosas. Que A **sobrevive** a que un peer se caiga en seco
/// sin cerrar nada —abortar las tareas es un `kill -9`, no un apagado— y que el B nuevo se pone al
/// día sin que nadie intervenga.
#[tokio::test]
#[ignore = "P-031: hace falta una red de dificultad trivial para minar PoW real en un test"]
async fn un_nodo_que_muere_vuelve_y_se_pone_al_dia_solo() {
    let a = Arc::new(Cadena::nueva(Red::Testnet).expect("génesis"));
    a.extender_sin_validar_solo_para_pruebas(&cabeceras_tras(&a, 9));

    let b1 = Arc::new(Cadena::nueva(Red::Testnet).expect("génesis"));
    let na = levantar(Arc::clone(&a)).await;
    let nb1 = levantar(Arc::clone(&b1)).await;

    nb1.manejo.marcar(na.addr.clone()).await.expect("B marca A");
    hasta_que("B se ponga al día", || b1.altura() == 9).await;

    // ── kill -9 ──────────────────────────────────────────────────────────────
    nb1.matar();
    drop(b1);

    // A sigue en pie y sirviendo: eso es lo que hay que comprobar antes de seguir.
    assert_eq!(a.altura(), 9, "la caída de un peer no toca la cadena de A");

    // ── B vuelve, y vuelve vacío ─────────────────────────────────────────────
    let b2 = Arc::new(Cadena::nueva(Red::Testnet).expect("génesis"));
    assert_eq!(b2.altura(), 0, "el B nuevo no recuerda nada");
    let nb2 = levantar(Arc::clone(&b2)).await;
    nb2.manejo
        .marcar(na.addr.clone())
        .await
        .expect("el B nuevo marca A");

    hasta_que("el B nuevo se ponga al día", || b2.altura() == 9).await;
    assert_eq!(b2.estado().tip, a.estado().tip, "misma punta que A");

    na.matar();
    nb2.matar();
}

/// **Cuatro nodos en estrella se sincronizan a la vez desde el mismo servidor.**
///
/// Tres clientes pidiéndole a A simultáneamente. Es el caso que no aparece con dos nodos: el
/// servidor atiende varias sincronizaciones concurrentes sobre el mismo estado, y si hubiera una
/// carrera al leer la cadena mientras se sirve un locator, saldría aquí.
#[tokio::test]
#[ignore = "P-031: hace falta una red de dificultad trivial para minar PoW real en un test"]
async fn varios_clientes_se_sincronizan_a_la_vez_del_mismo_servidor() {
    let a = Arc::new(Cadena::nueva(Red::Testnet).expect("génesis"));
    a.extender_sin_validar_solo_para_pruebas(&cabeceras_tras(&a, 20));
    let na = levantar(Arc::clone(&a)).await;

    let mut clientes = Vec::new();
    let mut cadenas = Vec::new();
    for _ in 0..3 {
        let c = Arc::new(Cadena::nueva(Red::Testnet).expect("génesis"));
        let n = levantar(Arc::clone(&c)).await;
        n.manejo.marcar(na.addr.clone()).await.expect("marca A");
        cadenas.push(c);
        clientes.push(n);
    }

    hasta_que("los tres clientes se pongan al día", || {
        cadenas.iter().all(|c| c.altura() == 20)
    })
    .await;

    for c in &cadenas {
        assert_eq!(
            c.estado().tip,
            a.estado().tip,
            "misma punta que el servidor"
        );
    }

    na.matar();
    for n in clientes {
        n.matar();
    }
}

/// **La carencia que este arnés deja fijada: nadie anuncia un bloque nuevo.**
///
/// C se conecta a un B que todavía está vacío. Los dos tienen el mismo trabajo, así que el saludo
/// concluye `AlDia` — correctamente: en ese instante lo están. Después B se pone al día con A y
/// **C no se entera**, porque el único disparador de sincronización que hay hoy es el saludo, y el
/// saludo ya pasó.
///
/// No es un fallo del sincronizador: es que falta el camino de anuncio. Cuando la propagación por
/// gossip esté cableada al driver (C-NET-12), C debería acabar en 12 y **este test debe fallar**.
/// Está escrito para que falle: es un recordatorio con fecha de caducidad, no una afirmación de que
/// el comportamiento sea el bueno.
#[tokio::test]
#[ignore = "P-031: hace falta una red de dificultad trivial para minar PoW real en un test"]
async fn sin_anuncio_un_peer_que_saludo_pronto_se_queda_atras() {
    let a = Arc::new(Cadena::nueva(Red::Testnet).expect("génesis"));
    a.extender_sin_validar_solo_para_pruebas(&cabeceras_tras(&a, 12));
    let b = Arc::new(Cadena::nueva(Red::Testnet).expect("génesis"));
    let c = Arc::new(Cadena::nueva(Red::Testnet).expect("génesis"));

    let na = levantar(Arc::clone(&a)).await;
    let nb = levantar(Arc::clone(&b)).await;
    let nc = levantar(Arc::clone(&c)).await;

    // C saluda a B mientras B todavía no tiene nada.
    nc.manejo.marcar(nb.addr.clone()).await.expect("C marca B");
    tokio::time::sleep(Duration::from_millis(300)).await;
    assert_eq!(c.altura(), 0, "nada que coger: B está vacío");

    // Ahora B se pone al día con A.
    nb.manejo.marcar(na.addr.clone()).await.expect("B marca A");
    hasta_que("B se ponga al día", || b.altura() == 12).await;

    // Y C no se entera.
    tokio::time::sleep(Duration::from_millis(500)).await;
    assert_eq!(
        c.altura(),
        0,
        "C sigue a cero porque nadie le anunció nada.\n\
         Si este assert falla con altura 12, es que el anuncio de bloques YA funciona: borra este \
         test y quédate con el de propagación transitiva."
    );

    na.matar();
    nb.matar();
    nc.matar();
}

/// **El hallazgo, fijado: el nodo real rechaza cabeceras sin PoW, y las castiga.**
///
/// Este es el test que sí corre, y es el que explica por qué los otros no pueden.
///
/// A ofrece doce cabeceras perfectamente encadenadas, con `bits` canónico y trabajo creciente. Todo
/// correcto menos una cosa: ningún `nonce` satisface su propio target. B las pide, las valida con
/// el **driver de verdad** —el mismo que corre en el binario— y las tira.
///
/// Que B se quede en 0 no es el detalle interesante. Lo interesante es que
/// `RechazoCabeceras::PowInvalido` cuenta como **mala fe** (C-NET-05), así que B además desconecta a
/// A por violación de consenso. Un peer que sirve cabeceras sin trabajo no está desincronizado:
/// está mintiendo, y cuesta lo mismo mentir con doce que con doce millones.
///
/// El arnés de dos nodos nunca vio nada de esto porque conducía el protocolo a mano y solo llamaba
/// a `validar_estructura`. Con `comprobar_pow` por medio, el resultado es el contrario del que
/// aquel test afirmaba.
#[tokio::test]
async fn el_nodo_real_rechaza_cabeceras_sin_pow() {
    let a = Arc::new(Cadena::nueva(Red::Testnet).expect("génesis"));
    a.extender_sin_validar_solo_para_pruebas(&cabeceras_tras(&a, 12));
    let b = Arc::new(Cadena::nueva(Red::Testnet).expect("génesis"));

    let na = levantar(Arc::clone(&a)).await;
    let nb = levantar(Arc::clone(&b)).await;
    nb.manejo.marcar(na.addr.clone()).await.expect("B marca A");

    // Se le da tiempo de sobra a que la sincronización ocurra, si fuera a ocurrir. En
    // `MemoryTransport` el intercambio entero son milisegundos.
    tokio::time::sleep(Duration::from_millis(800)).await;

    assert_eq!(
        b.altura(),
        0,
        "B NO debe adoptar cabeceras sin PoW.\n\
         Si esto falla con altura 12, alguien ha quitado `comprobar_pow` de \
         `validar_cadena_de_cabeceras` y el nodo acepta cadenas sin trabajo: es una rotura de \
         consenso, no un test que se ha quedado viejo."
    );
    assert_eq!(a.altura(), 12, "A conserva la suya");

    na.matar();
    nb.matar();
}

/// **La descarga de cuerpos, de extremo a extremo, con el driver real.**
///
/// Esta sí corre hoy, y el motivo es instructivo: B **ya tiene las cabeceras**, así que no hay PoW
/// que validar y la pared de P-031 no aparece. El saludo concluye que nadie va por delante —mismo
/// trabajo— y aun así B pide cuerpos, que es exactamente el caso de un nodo que se reinició a
/// mitad de la descarga.
///
/// Antes de esto el nodo **nunca pedía un cuerpo**: sincronizaba cabeceras y paraba. `Fase::Cuerpos`
/// existía en el enum y nada la construía.
#[tokio::test]
async fn un_nodo_con_las_cabeceras_pero_sin_cuerpos_los_descarga() {
    use zx_core::amount::Amount;
    use zx_core::digest::TxId;
    use zx_core::firma::ClavePublica;
    use zx_core::preimage::block::merkle_root;
    use zx_core::preimage::tx::txid;
    use zx_core::tx::{Lock, OutPoint, Tx, TxIn, TxOut};
    use zx_p2p::mensaje::BloqueRed;

    const N: u32 = 5;

    let a = Arc::new(Cadena::nueva(Red::Testnet).expect("génesis"));
    let b = Arc::new(Cadena::nueva(Red::Testnet).expect("génesis"));

    // Las cabeceras se construyen a partir de los cuerpos, no al revés: la raíz de Merkle las ata
    // (C-BLK-03, C-NET-23), y con una raíz de relleno el receptor rechazaría los cuerpos.
    let mut cabeceras = Vec::new();
    let mut bloques = Vec::new();
    let mut prev = a.genesis();
    for i in 1..=N {
        let tx = Tx {
            version: 1,
            inputs: vec![TxIn {
                outpoint: OutPoint {
                    prev_txid: TxId::from_digest(Digest::from_bytes([i as u8; 32])),
                    prev_index: 0,
                },
                sequence: 0xffff_fffe,
            }],
            outputs: vec![TxOut {
                value: Amount::nuevo(1_000 + i64::from(i)).expect("importe"),
                lock: Lock::PubKey {
                    pubkey: ClavePublica::desde_bytes([9; 32]),
                },
            }],
            lock_time: 0,
            expiry_height: i,
        };
        let mut cab = cab_base(i, prev);
        cab.merkle_root = merkle_root(&[txid(&tx, cab.consensus_branch_id)]);
        prev = cab.block_hash();
        cabeceras.push(cab);
        bloques.push(BloqueRed {
            cabecera: cab,
            txs: vec![tx],
            testigos: vec![vec![vec![0x5a; 64]]],
        });
    }

    // A: cabeceras y cuerpos. B: solo cabeceras — el estado de quien se reinició a media descarga.
    a.extender_sin_validar_solo_para_pruebas(&cabeceras);
    for bl in &bloques {
        a.guardar_bloque(bl).expect("A guarda los suyos");
    }
    b.extender_sin_validar_solo_para_pruebas(&cabeceras);

    assert_eq!(a.cuerpos_que_faltan(64).len(), 0, "A los tiene todos");
    assert_eq!(
        b.cuerpos_que_faltan(64).len(),
        N as usize,
        "a B le faltan los {N}"
    );
    assert_eq!(a.trabajo(), b.trabajo(), "nadie va por delante en cabeceras");

    let na = levantar(Arc::clone(&a)).await;
    let nb = levantar(Arc::clone(&b)).await;
    nb.manejo.marcar(na.addr.clone()).await.expect("B marca A");

    hasta_que("B descargue todos los cuerpos", || {
        b.cuerpos_que_faltan(64).is_empty()
    })
    .await;

    // Y son los cuerpos buenos, no cualquier cosa que quepa bajo esos hashes.
    for bl in &bloques {
        let recuperado = b.bloque(bl.cabecera.block_hash()).expect("B lo tiene");
        assert_eq!(recuperado.txs, bl.txs, "las transacciones deben ser las de A");
        assert_eq!(recuperado.testigos, bl.testigos);
    }

    na.matar();
    nb.matar();
}
