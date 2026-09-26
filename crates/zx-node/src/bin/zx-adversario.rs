//! `zx-adversario`: herramienta adversarial separada (`ORDEN-W06d2` decisión 6).
//!
//! Un binario aparte —**nunca** un modo de `zx-node`— que habla el protocolo real de `zx-p2p`
//! (mismo transporte, mismo behaviour, misma red dev) para enviarle a un nodo objetivo las
//! entradas inválidas de `P-ZRX/P-MEDICION/ESCENARIOS-0.0.1.md` §3 E-7 y E-8, y observar si las
//! rechaza sin cambiar de estado.
//!
//! # Qué cubre esta versión, y qué no (ver `PROGRESO.md` del encargo)
//!
//! `BloqueRed::Post` no lleva `JustificacionPot` (bloqueo documentado): `zx-node` trata **todo**
//! bloque PoST de red como no juzgable (`Ignorar`) sin mirar su contenido. Los escenarios de E-7
//! que dependen de PoAS/PoT/sello **PoST** malos, y el escenario E-8 (equivocación), no se pueden
//! observar todavía como un rechazo con motivo específico por esta vía: el objetivo los ignora por
//! el formato, no por el contenido. Se envían igualmente (ejercitan de verdad el códec y el
//! transporte) pero el veredicto esperado documentado aquí es «ignorado por bloqueo de formato»,
//! no «rechazado por PoAS/PoT inválido». Los escenarios de la familia **PoW** sí se validan de
//! extremo a extremo: esta herramienta primero pregunta el estado real del objetivo (`Peticion::
//! Estado`) y construye los bloques adversariales **extendiendo su punta real**, para que lleguen
//! al validador de verdad en vez de quedarse en «huérfano, no juzgable».
//!
//! # Cómo se usa
//!
//! ```text
//! zx-adversario --objetivo /ip4/127.0.0.1/tcp/PUERTO
//! ```
//!
//! Corre cada escenario una vez, en orden, con una pausa entre cada uno para poder leer el
//! registro estructurado del objetivo. Imprime a stdout qué mandó y qué observó (conexión viva o
//! cortada) en cada paso; el veredicto de fondo (aceptado/ignorado/rechazado, y por qué) se lee en
//! el registro del nodo objetivo, no aquí — esta herramienta no tiene acceso a su estado interno,
//! solo al protocolo de red, que es exactamente el punto.

use std::time::Duration;

use clap::Parser;
use libp2p::core::transport::Transport as _;
use libp2p::{Multiaddr, PeerId, Swarm, identity, noise, yamux};
use zx_core::amount::Amount;
use zx_core::digest::{BlockHash, Digest, MerkleRoot, TxId};
use zx_core::firma::ClavePublica;
use zx_core::preimage::block::{BlockHeader, merkle_root};
use zx_core::preimage::dag::{DagBlockHeader, PadresDag, SolucionPoas};
use zx_core::red::Red;
use zx_core::tx::{ExtensionTx, Lock, OutPoint, Tx, TxIn, TxOut};
use zx_p2p::behaviour::ZxBehaviour;
use zx_p2p::config::ParametrosRed;
use zx_p2p::entrante::{IdDiferido, ManejadorEntrante, Veredicto};
use zx_p2p::mensaje::{BloqueRed, Estado, FamiliaBloque, Fase, Peticion, Respuesta};
use zx_p2p::servicio::{EventoRed, arrancar};

/// CLI de la herramienta adversarial.
#[derive(Parser, Debug)]
#[command(
    name = "zx-adversario",
    about = "Herramienta adversarial de ORDEN-W06d2 (E-7/E-8)"
)]
struct Cli {
    /// Dirección del nodo objetivo.
    #[arg(long, value_name = "MULTIADDR")]
    objetivo: Multiaddr,

    /// Pausa entre escenarios, en milisegundos (para poder leer el registro del objetivo).
    #[arg(long, default_value_t = 300)]
    pausa_ms: u64,
}

/// Manejador espía: no se necesita servir nada de verdad (la herramienta no es un nodo, no tiene
/// cadena que ofrecer); cuenta lo que le llega para el resumen final.
#[derive(Default)]
struct Espia {
    respuestas: std::sync::atomic::AtomicUsize,
}

impl ManejadorEntrante for Espia {
    fn estado(&self) -> Estado {
        // La herramienta no es un nodo real: declara un génesis vacío. Si el objetivo comprueba
        // esto y desconecta, es exactamente C-NET del lado del objetivo funcionando; no rompe nada
        // del lado de la herramienta (no le pedimos que confíe en nuestro estado).
        Estado {
            hash_genesis: BlockHash::from_digest(Digest::from_bytes([0xEE; 32])),
            red: Red::Dev,
            fase: Fase::Pow,
            punta_pow: zx_p2p::mensaje::PuntaPow {
                hash: BlockHash::from_digest(Digest::from_bytes([0xEE; 32])),
                altura: 0,
                trabajo_acumulado: [0; 32],
            },
            terminal: None,
            puntas_post: Vec::new(),
            blue_work_virtual: [0; 32],
        }
    }

    fn bloque_difundido(&self, _id: IdDiferido, _bloque: &BloqueRed) -> Veredicto {
        Veredicto::Ignorar
    }

    fn tx_difundida(&self, _tx: &[u8]) -> Veredicto {
        Veredicto::Ignorar
    }

    fn cabeceras_desde(
        &self,
        _locator: &[BlockHash],
        _hasta: Option<BlockHash>,
    ) -> Vec<BlockHeader> {
        Vec::new()
    }

    fn bloques_por_hash(&self, _hashes: &[BlockHash]) -> Vec<BloqueRed> {
        Vec::new()
    }
}

fn swarm_tcp() -> Result<Swarm<ZxBehaviour>, String> {
    let clave = identity::Keypair::generate_ed25519();
    let peer_id = clave.public().to_peer_id();
    let ruido = noise::Config::new(&clave).map_err(|e| format!("noise: {e}"))?;
    let transporte = libp2p::tcp::tokio::Transport::new(libp2p::tcp::Config::default())
        .upgrade(libp2p::core::upgrade::Version::V1Lazy)
        .authenticate(ruido)
        .multiplex(yamux::Config::default())
        .boxed();
    let behaviour = ZxBehaviour::nueva(
        &clave,
        ParametrosRed::dag_dev(),
        zx_p2p::limites::LIMITE_BLOQUE_DEV,
    )
    .map_err(|e| format!("behaviour de la red dev: {e}"))?;
    Ok(Swarm::new(
        transporte,
        behaviour,
        peer_id,
        libp2p::swarm::Config::with_tokio_executor()
            .with_idle_connection_timeout(Duration::from_secs(30)),
    ))
}

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
            value: Amount::nuevo(1_000).unwrap_or(Amount::CERO),
            lock: Lock::PubKey {
                pubkey: ClavePublica::desde_bytes([n; 32]),
            },
        }],
        lock_time: 0,
        expiry_height: 0,
        extension: ExtensionTx::Ninguna,
    }
}

/// E-7 «PoW con nonce malo»: extiende la punta real del objetivo con una cabecera cuyo `nonce` no
/// cumple el PoW real (probabilidad astronómicamente en contra de que cumpla por azar con la
/// dificultad dev). El motor de transición la rechazaría igual por su coinbase (no está firmada por
/// nadie que el objetivo conozca como productor válido de esa altura salvo que coincida una clave
/// real), pero la comprobación de PoW real es la primera de la tubería (`validar_cabecera_pow`) y
/// MUST fallar antes de llegar a mirar la coinbase.
fn escenario_pow_nonce_malo(estado_objetivo: &Estado) -> BloqueRed {
    let altura = estado_objetivo.punta_pow.altura + 1;
    let clave = ClavePublica::desde_bytes([0x41; 32]);
    let coinbase = zx_node::pow::construir_coinbase_pow(clave, altura);
    let txid_coinbase = zx_core::txid(&coinbase, zx_core::CBID_RED_DEV);
    BloqueRed::Pow {
        cabecera: BlockHeader {
            consensus_branch_id: zx_core::CBID_RED_DEV,
            prev_hash: estado_objetivo.punta_pow.hash,
            merkle_root: merkle_root(&[txid_coinbase]),
            timestamp: 1_800_000_000,
            bits: 0x1c07_fff8,
            nonce: 0, // no minado: no cumple `hash_pow < target` con la dificultad dev real.
            height: altura,
        },
        txs: vec![coinbase],
        testigos: vec![Vec::new()],
    }
}

/// E-7 «coinbase mayor que el subsidio»: mismo bloque que el anterior pero con PoW real (minado de
/// verdad, presupuesto acotado) y una coinbase que paga de más. Si la dificultad dev real tarda más
/// que el presupuesto de esta herramienta en encontrar un nonce válido, se declara `None` y el
/// escenario se omite (no se falsea un PoW).
fn escenario_coinbase_excesiva(estado_objetivo: &Estado) -> Option<BloqueRed> {
    let altura = estado_objetivo.punta_pow.altura + 1;
    let clave = ClavePublica::desde_bytes([0x42; 32]);
    let mut coinbase = zx_node::pow::construir_coinbase_pow(clave, altura);
    // El doble del subsidio dev declarado: demostrablemente por encima de lo que F-16 permite.
    let salida = coinbase.outputs.first_mut()?;
    let doble = salida.value.brek().checked_mul(2)?;
    salida.value = Amount::nuevo(doble).ok()?;
    let txid_coinbase = zx_core::txid(&coinbase, zx_core::CBID_RED_DEV);
    let objetivo_pow =
        zx_core::decodificar_con(0x1c07_fff8, &zx_consensus::PARAMETROS_POW_DEV.limites).ok()?;
    let cabecera_base = BlockHeader {
        consensus_branch_id: zx_core::CBID_RED_DEV,
        prev_hash: estado_objetivo.punta_pow.hash,
        merkle_root: merkle_root(&[txid_coinbase]),
        timestamp: 1_800_000_000,
        bits: 0x1c07_fff8,
        nonce: 0,
        height: altura,
    };
    // Presupuesto acotado y declarado, reusando el minero real (`zx_consensus::minar`): hasta
    // 2_000_000 intentos. Con la dificultad inicial dev real esto puede no bastar (se ha medido en
    // otras órdenes ~4-5 s/bloque en `debug`); si no se encuentra, se omite el escenario en vez de
    // mandar un PoW falso.
    let cancelar = core::sync::atomic::AtomicBool::new(false);
    let minada = zx_consensus::minar(
        &cabecera_base,
        objetivo_pow,
        &zx_consensus::Sha3Dev,
        2_000_000,
        &cancelar,
    )?;
    Some(BloqueRed::Pow {
        cabecera: minada,
        txs: vec![coinbase],
        testigos: vec![Vec::new()],
    })
}

/// E-7 «ráfaga de huérfanos»: muchos bloques PoW con padres inexistentes (aleatorios), para
/// comprobar que el objetivo los deposita acotado y no se cae ni penaliza al remitente (son
/// indistinguibles de "llegó antes que su padre").
fn escenario_rafaga_huerfanos(n: usize) -> Vec<BloqueRed> {
    (0..n)
        .map(|i| {
            // Un hash "aleatorio" distinto por índice basta: no necesita ser impredecible, solo no
            // coincidir con ningún padre real. `sha3_256_publico` de los bytes de `i` (`u64`
            // big-endian) da 32 bytes bien repartidos sin aritmética manual por byte.
            let semilla = u64::try_from(i).unwrap_or(0).to_be_bytes();
            let padre_inexistente = BlockHash::from_digest(zx_core::sha3_256_publico(&semilla));
            BloqueRed::Pow {
                cabecera: BlockHeader {
                    consensus_branch_id: zx_core::CBID_RED_DEV,
                    prev_hash: padre_inexistente,
                    merkle_root: MerkleRoot::from_digest(Digest::from_bytes([0x33; 32])),
                    timestamp: 1_800_000_000,
                    bits: 0x1c07_fff8,
                    nonce: u64::try_from(i).unwrap_or(0),
                    height: 1,
                },
                txs: vec![tx_llave(u8::try_from(i % 256).unwrap_or(0))],
                testigos: vec![vec![vec![0xAA; 64]]],
            }
        })
        .collect()
}

/// E-7 «PoST con PoAS/PoT/sello malos» y E-8 «equivocación»: se envían igual (ejercitan el códec y
/// el transporte reales), pero ver el docstring del módulo: el objetivo los ignora por el bloqueo
/// de formato, no por su contenido, en esta versión.
fn escenario_post_malo(n: u8) -> BloqueRed {
    BloqueRed::Post {
        cabecera: DagBlockHeader {
            consensus_branch_id: zx_core::CBID_RED_DEV,
            merkle_root: MerkleRoot::from_digest(Digest::from_bytes([0x99; 32])),
            timestamp: 1_800_000_000,
            height: 0,
            slot: u64::from(n),
            pot_output: [0xFF; 16], // PoT que no corresponde a ningún flujo real.
            rango_solucion: 1,
            sol: SolucionPoas::default(), // PoAS vacía/inválida.
            body_commitment: zx_core::digest::BodyCommitment::from_digest(Digest::from_bytes(
                [0x11; 32],
            )),
            padres: PadresDag::nuevo(BlockHash::from_digest(Digest::from_bytes([0x22; 32])), &[])
                .unwrap_or_else(|_| unreachable!("un solo padre siempre construye")),
            sello: [0xFF; 64], // sello arbitrario, no una firma real.
        },
        txs: vec![tx_llave(n)],
        testigos: vec![vec![vec![0xBB; 64]]],
    }
}

#[tokio::main]
async fn main() {
    let cli = Cli::parse();
    let swarm = match swarm_tcp() {
        Ok(s) => s,
        Err(e) => {
            eprintln!("zx-adversario: no se pudo construir la red: {e}");
            std::process::exit(1);
        }
    };
    let espia = std::sync::Arc::new(Espia::default());
    let piezas = arrancar(swarm, std::sync::Arc::clone(&espia));
    let manejo = piezas.manejo;
    let mut eventos = piezas.eventos;
    let tarea = tokio::spawn(piezas.bucle.correr());

    println!("zx-adversario: marcando {} ...", cli.objetivo);
    if let Err(e) = manejo.marcar(cli.objetivo.clone()).await {
        eprintln!("zx-adversario: no se pudo marcar: {e}");
        std::process::exit(1);
    }

    let Some(peer) = esperar_conexion(&mut eventos).await else {
        eprintln!("zx-adversario: el objetivo no conectó en el plazo esperado");
        std::process::exit(1);
    };
    println!("zx-adversario: conectado a {peer}");

    let Some(estado_objetivo) = pedir_estado(&manejo, &mut eventos, peer).await else {
        eprintln!("zx-adversario: el objetivo no respondió el saludo");
        std::process::exit(1);
    };
    println!(
        "zx-adversario: objetivo declara altura PoW {} fase {:?}",
        estado_objetivo.punta_pow.altura, estado_objetivo.fase
    );

    let pausa = Duration::from_millis(cli.pausa_ms);

    // La conexión TCP no es la malla de gossipsub: publicar antes de que las dos suscripciones
    // (bloques pow/post) terminen su propio intercambio de control falla localmente con
    // `NoPeersSubscribedToTopic` (mismo motivo que `dos_nodos.rs::dos_conectados`, en `zx-p2p`,
    // espera las suscripciones antes de publicar). Una espera fija y corta —no un consumo del
    // canal de eventos, para no interferir con `pedir_estado`— basta en la práctica: la
    // suscripción se negocia en el primer RPC tras la conexión, casi siempre antes de que termine
    // el saludo de arriba.
    tokio::time::sleep(Duration::from_millis(500)).await;

    // Orden deliberado: primero los escenarios que **no** violan consenso (`Ignorar`, la conexión
    // sigue viva) y al final los que sí (`Rechazar` con `MotivoDesconexion::ViolacionDeConsenso`,
    // que banea de un golpe — C-NET-05/`error.rs`). Con una sola conexión persistente por
    // simplicidad, un baneo temprano dejaría sin mesh de gossipsub los escenarios restantes (medido:
    // exactamente lo que pasaba con el orden anterior). Reconectar entre escenarios queda para una
    // versión futura de esta herramienta.
    ejecutar_escenario(
        &manejo,
        &mut eventos,
        "E-7 ráfaga de huérfanos (256 padres inexistentes)",
        escenario_rafaga_huerfanos(256),
        pausa,
    )
    .await;

    ejecutar_escenario(
        &manejo,
        &mut eventos,
        "E-7 PoST con PoAS/PoT/sello malos (limitado: ver docstring del módulo)",
        vec![escenario_post_malo(1)],
        pausa,
    )
    .await;

    ejecutar_escenario(
        &manejo,
        &mut eventos,
        "E-8 equivocación: misma clave, dos bloques del mismo slot (limitado: ver docstring)",
        vec![escenario_post_malo(2), escenario_post_malo(2)],
        pausa,
    )
    .await;

    // A partir de aquí, cada escenario puede banear la conexión: van al final.
    ejecutar_escenario(
        &manejo,
        &mut eventos,
        "E-7 PoW nonce malo",
        vec![escenario_pow_nonce_malo(&estado_objetivo)],
        pausa,
    )
    .await;

    if let Some(b) = escenario_coinbase_excesiva(&estado_objetivo) {
        ejecutar_escenario(
            &manejo,
            &mut eventos,
            "E-7 coinbase mayor que el subsidio",
            vec![b],
            pausa,
        )
        .await;
    } else {
        println!(
            "zx-adversario: E-7 coinbase excesiva OMITIDO (no se encontró nonce PoW real en el \
             presupuesto de esta herramienta; no se manda un PoW falso)"
        );
    }

    println!(
        "zx-adversario: fin. Respuestas de sincronización recibidas: {}. \
         El veredicto de fondo de cada envío se lee en el registro del objetivo.",
        espia.respuestas.load(std::sync::atomic::Ordering::Relaxed)
    );
    tarea.abort();
}

async fn esperar_conexion(eventos: &mut tokio::sync::mpsc::Receiver<EventoRed>) -> Option<PeerId> {
    let plazo = tokio::time::Instant::now() + Duration::from_secs(15);
    loop {
        let resto = plazo.saturating_duration_since(tokio::time::Instant::now());
        if resto.is_zero() {
            return None;
        }
        match tokio::time::timeout(resto, eventos.recv()).await {
            Ok(Some(EventoRed::PeerConectado(p))) => return Some(p),
            Ok(Some(_)) => {}
            _ => return None,
        }
    }
}

async fn pedir_estado(
    manejo: &zx_p2p::servicio::ManejoRed,
    eventos: &mut tokio::sync::mpsc::Receiver<EventoRed>,
    peer: PeerId,
) -> Option<Estado> {
    manejo.pedir(peer, Peticion::Estado).await.ok()?;
    let plazo = tokio::time::Instant::now() + Duration::from_secs(10);
    loop {
        let resto = plazo.saturating_duration_since(tokio::time::Instant::now());
        if resto.is_zero() {
            return None;
        }
        match tokio::time::timeout(resto, eventos.recv()).await {
            Ok(Some(EventoRed::Respuesta { respuesta, .. })) => {
                if let Respuesta::Estado(e) = *respuesta {
                    return Some(e);
                }
            }
            Ok(Some(_)) => {}
            _ => return None,
        }
    }
}

async fn ejecutar_escenario(
    manejo: &zx_p2p::servicio::ManejoRed,
    eventos: &mut tokio::sync::mpsc::Receiver<EventoRed>,
    nombre: &str,
    bloques: Vec<BloqueRed>,
    pausa: Duration,
) {
    println!("--- {nombre} ({} mensaje(s)) ---", bloques.len());
    for b in &bloques {
        let familia = match b.familia() {
            FamiliaBloque::Pow => "pow",
            FamiliaBloque::Post => "post",
        };
        match manejo.difundir_bloque(b).await {
            Ok(()) => println!("  difundido ({familia}): aceptado localmente por gossipsub"),
            Err(e) => println!("  difundido ({familia}): RECHAZADO localmente: {e}"),
        }
        tokio::time::sleep(Duration::from_millis(20)).await;
    }
    // Ventana corta para ver si el objetivo nos corta la conexión (penalización).
    let vivo = tokio::time::timeout(pausa, esperar_desconexion(eventos)).await;
    match vivo {
        Ok(Some(_)) => println!("  el objetivo CORTÓ la conexión tras este escenario"),
        _ => println!("  la conexión sigue viva tras este escenario"),
    }
}

async fn esperar_desconexion(eventos: &mut tokio::sync::mpsc::Receiver<EventoRed>) -> Option<()> {
    loop {
        match eventos.recv().await {
            Some(EventoRed::PeerDesconectado(_)) => return Some(()),
            Some(_) => {}
            None => return None,
        }
    }
}
