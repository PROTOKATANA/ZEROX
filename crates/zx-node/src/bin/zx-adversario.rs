//! `zx-adversario`: herramienta adversarial separada (`ORDEN-W06d2` decisión 6).
//!
//! Un binario aparte —**nunca** un modo de `zx-node`— que habla el protocolo real de `zx-p2p`
//! (mismo transporte, mismo behaviour, misma red dev) para enviarle a un nodo objetivo las
//! entradas inválidas de `P-ZRX/P-MEDICION/ESCENARIOS-0.0.1.md` §3 E-7 y E-8, y observar si las
//! rechaza sin cambiar de estado.
//!
//! # Qué cubre esta versión, y qué no (ver `PROGRESO.md` del encargo)
//!
//! `BloqueRed::Post` ya lleva `JustificacionPot` (`ORDEN-W06d3` decisión 1): el objetivo puede
//! verificar de verdad la cabecera conjunta de un PoST ajeno. Los escenarios de E-7 con PoAS/PoT/
//! sello **PoST** malos declaran como único padre el **terminal real** del objetivo (pedido con
//! `Peticion::Estado`, igual que ya hacían los de PoW): así el bloque llega a la verificación de
//! contenido en vez de quedarse en «huérfano, padre desconocido». Si el objetivo todavía no tiene
//! terminal (sigue en fase PoW), esos escenarios se omiten: enviarlos sin un padre real solo
//! probaría el camino de huérfanos, ya cubierto por la ráfaga de E-7. El escenario **E-8**
//! (equivocación) sigue limitado: esta herramienta no tiene la clave privada de ningún productor
//! real, así que no puede construir dos bloques **válidos** del mismo slot y observar cómo los
//! colorea GHOSTDAG (eso se demuestra en un test dedicado con claves propias, no por red); lo que
//! sí demuestra es que dos bloques distintos con contenido inválido para el mismo slot se rechazan
//! cada uno por su motivo, sin que el segundo cambie el estado. Los escenarios de la familia
//! **PoW** se validan de extremo a extremo: esta herramienta primero pregunta el estado real del
//! objetivo (`Peticion::Estado`) y construye los bloques adversariales **extendiendo su punta
//! real**, para que lleguen al validador de verdad en vez de quedarse en «huérfano, no juzgable».
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

use std::collections::BTreeSet;
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
use zx_core::wire_dag::{JustificacionPot, PotCheckpoints};
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
        // `ORDEN-W06d6` decisión 3 (V7), hallazgo en vivo: la herramienta declaraba un
        // `hash_genesis` vacío (`[0xEE; 32]`) a propósito ("si el objetivo comprueba esto y
        // desconecta, no rompe nada del lado de la herramienta"). Eso era cierto con un objetivo
        // recién arrancado, pero deja de serlo con un objetivo real en marcha (500+ bloques): el
        // saludo recíproco del propio objetivo (`sync.rs::atender_respuesta`, `Respuesta::Estado`)
        // ve el génesis ajeno y llama a `desconectar(ViolacionDeConsenso)` **de inmediato** — y como
        // la respuesta de esta herramienta (trivial) siempre llega antes que la del objetivo
        // (construir la suya es más caro cuantos más bloques tenga), el objetivo gana la carrera
        // sistemáticamente y corta la conexión antes de que la herramienta reciba nada, dejando
        // "el objetivo no respondió el saludo" — la ráfaga de escenarios nunca llegaba a mandarse.
        // Reproducido en vivo contra un objetivo con 500+ bloques PoST (`PROGRESO.md`). El génesis
        // dev es una constante pública y fija (`HASH_GENESIS_DEV`); declararlo de verdad no debilita
        // ningún escenario adversarial (el génesis no es parte de ningún ataque de E-7/E-8) y evita
        // el corte antes de que la herramienta pueda hacer su trabajo.
        Estado {
            hash_genesis: BlockHash::from_digest(Digest::from_bytes(
                zx_consensus::genesis::HASH_GENESIS_DEV,
            )),
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
            longitud_registro: 0,
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

/// Justificación PoT que no corresponde a ningún flujo real: basta un portador de relleno para que
/// `verificar_cabecera_conjunta` la lea y la rechace en la comprobación de PoT, en vez de fallar
/// antes por tener la lista vacía (que también sería un rechazo, pero uno de forma, no de PoT).
fn justificacion_mala(variante: u8) -> JustificacionPot {
    let portador = PotCheckpoints::desde_outputs([[0xEE ^ variante; 16]; 8]);
    JustificacionPot::nueva(vec![portador]).unwrap_or_else(|_| unreachable!("1 <= MAX_BUNDLES_POT"))
}

/// E-7 «PoST con PoAS/PoT/sello malos» y E-8 «equivocación» (ver el docstring del módulo: E-8
/// sigue limitado por no tener claves reales). `variante` distingue el hash de dos bloques del
/// mismo `slot` sin cambiar nada más. Declara como único padre el **terminal real** del objetivo:
/// sin eso, el objetivo lo trataría como huérfano (`Ignorar`) en vez de verificar su contenido.
/// `None` si el objetivo todavía no tiene terminal (nada útil que demostrar por esta vía todavía).
fn escenario_post_malo(slot: u8, variante: u8, estado_objetivo: &Estado) -> Option<BloqueRed> {
    let terminal = estado_objetivo.terminal?;
    Some(BloqueRed::Post {
        cabecera: DagBlockHeader {
            consensus_branch_id: zx_core::CBID_RED_DEV,
            merkle_root: MerkleRoot::from_digest(Digest::from_bytes([0x99 ^ variante; 32])),
            timestamp: 1_800_000_000,
            height: 0,
            slot: u64::from(slot),
            pot_output: [0xFF; 16], // PoT que no corresponde a ningún flujo real.
            rango_solucion: 1,
            sol: SolucionPoas::default(), // PoAS vacía/inválida.
            body_commitment: zx_core::digest::BodyCommitment::from_digest(Digest::from_bytes(
                [0x11 ^ variante; 32],
            )),
            padres: PadresDag::nuevo(terminal, &[])
                .unwrap_or_else(|_| unreachable!("un solo padre siempre construye")),
            sello: [0xFF; 64], // sello arbitrario, no una firma real.
        },
        justificacion: justificacion_mala(variante),
        txs: vec![tx_llave(slot)],
        testigos: vec![vec![vec![0xBB; 64]]],
    })
}

#[tokio::main]
async fn main() {
    // `ORDEN-W06d6` decisión 3 (V7): sin esto, ningún `tracing::debug!`/`tracing::warn!` de esta
    // herramienta ni de `zx-p2p` (el motivo real de un rechazo local de gossipsub, penalizaciones
    // de par, etc.) se imprime en ningún sitio — la mitad de por qué V7 quedó "parcial" en
    // `REVISION-W06d5.md`: el motivo existía en el código pero nada lo mostraba. `DEBUG` fijo (no
    // `RUST_LOG`): esta es una herramienta de diagnóstico de un solo uso, no un servicio con
    // configuración propia.
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(true)
        .init();

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

    // `ORDEN-W06d5` decisión 5 (`REVISION-W06d4.md`, V7): la conexión TCP no es la malla de
    // gossipsub; publicar antes de que el objetivo confirme sus dos suscripciones (bloques
    // pow/post) falla localmente con `NoPeersSubscribedToTopic`. Se pide el saludo y se esperan las
    // suscripciones **en el mismo bucle** (`pedir_estado_y_suscripciones`): hacerlo en dos bucles
    // consecutivos sobre el mismo canal perdía los eventos de suscripción que llegaran mientras se
    // esperaba el saludo (ver el docstring de la función — encontrado en vivo, no hipotético).
    let (estado_objetivo, pendientes) =
        pedir_estado_y_suscripciones(&manejo, &mut eventos, peer, Duration::from_secs(10)).await;
    let Some(estado_objetivo) = estado_objetivo else {
        eprintln!("zx-adversario: el objetivo no respondió el saludo");
        std::process::exit(1);
    };
    println!(
        "zx-adversario: objetivo declara altura PoW {} fase {:?}",
        estado_objetivo.punta_pow.altura, estado_objetivo.fase
    );

    let pausa = Duration::from_millis(cli.pausa_ms);

    if pendientes.is_empty() {
        println!("zx-adversario: el objetivo confirmó su suscripción a los dos temas de gossipsub");
    } else {
        println!(
            "zx-adversario: el objetivo no confirmó suscripción a {pendientes:?} en el plazo \
             esperado; prosigo igualmente (la ráfaga puede perder mensajes por esto)"
        );
    }

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

    if let Some(b) = escenario_post_malo(1, 0, &estado_objetivo) {
        ejecutar_escenario(
            &manejo,
            &mut eventos,
            "E-7 PoST con PoAS/PoT/sello malos (padre = terminal real del objetivo)",
            vec![b],
            pausa,
        )
        .await;
    } else {
        println!(
            "zx-adversario: E-7 PoST malo OMITIDO (el objetivo todavía no fijó terminal, sigue en \
             fase PoW)"
        );
    }

    match (
        escenario_post_malo(2, 1, &estado_objetivo),
        escenario_post_malo(2, 2, &estado_objetivo),
    ) {
        (Some(b1), Some(b2)) => {
            ejecutar_escenario(
                &manejo,
                &mut eventos,
                "E-8 equivocación: dos bloques distintos del mismo slot (limitado: ver docstring)",
                vec![b1, b2],
                pausa,
            )
            .await;
        }
        _ => println!(
            "zx-adversario: E-8 OMITIDO (el objetivo todavía no fijó terminal, sigue en fase PoW)"
        ),
    }

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

/// Pide el saludo **y**, en el mismo bucle de consumo del canal de eventos, acumula las
/// suscripciones de gossipsub del objetivo que lleguen mientras tanto.
///
/// `ORDEN-W06d5` decisión 5, corrección tras el primer intento de V7 con esta misma orden: separar
/// esto en dos funciones consecutivas —cada una con su propio bucle sobre el **mismo** canal— hacía
/// que la que corría primero (`pedir_estado`) descartara en silencio (`Ok(Some(_)) => {}`) los
/// eventos `Suscripcion` que llegaran mientras esperaba el saludo, exactamente los que la segunda
/// (`esperar_suscripcion`) necesitaba después: con las dos suscripciones anunciándose casi siempre
/// junto con la respuesta al saludo (ambas llegan justo tras la conexión), la carrera se perdía casi
/// siempre y el plazo de la segunda función expiraba sin ver nada — reproducido en vivo, no una
/// hipótesis: el registro del intento anterior mostraba exactamente `"el objetivo no confirmó
/// suscripción"` seguido de `NoPeersSubscribedToTopic` en la ráfaga.
async fn pedir_estado_y_suscripciones(
    manejo: &zx_p2p::servicio::ManejoRed,
    eventos: &mut tokio::sync::mpsc::Receiver<EventoRed>,
    peer: PeerId,
    plazo_suscripcion: Duration,
) -> (Option<Estado>, BTreeSet<&'static str>) {
    manejo.pedir(peer, Peticion::Estado).await.ok();
    let mut pendientes: BTreeSet<&'static str> = [
        ParametrosRed::dag_dev().topic_bloques_pow(),
        ParametrosRed::dag_dev().topic_bloques_post(),
    ]
    .into_iter()
    .collect();
    let mut estado = None;
    // El plazo total es el mayor de los dos: seguimos escuchando suscripciones después de tener ya
    // el saludo, hasta `plazo_suscripcion`, pero no más allá de 10s si el saludo mismo no llega.
    let fin_saludo = tokio::time::Instant::now() + Duration::from_secs(10);
    let fin_suscripcion = tokio::time::Instant::now() + plazo_suscripcion;
    loop {
        if estado.is_some() && pendientes.is_empty() {
            break;
        }
        let limite = if estado.is_some() {
            fin_suscripcion
        } else {
            fin_saludo.min(fin_suscripcion)
        };
        let resto = limite.saturating_duration_since(tokio::time::Instant::now());
        if resto.is_zero() {
            break;
        }
        match tokio::time::timeout(resto, eventos.recv()).await {
            Ok(Some(EventoRed::Respuesta { respuesta, .. })) => {
                if let Respuesta::Estado(e) = *respuesta {
                    estado = Some(e);
                }
            }
            Ok(Some(EventoRed::Suscripcion {
                peer: p,
                topico,
                suscrito: true,
            })) if p == peer => {
                pendientes.retain(|t| topico != *t);
            }
            Ok(Some(_)) => {}
            _ => break,
        }
    }
    (estado, pendientes)
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
