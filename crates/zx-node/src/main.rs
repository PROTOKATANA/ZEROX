//! El nodo de ZEROX.
//!
//! # Su papel en la arquitectura
//!
//! Es el **único** crate que ve las cuatro capas a la vez: `zx-core`, `zx-consensus`, `zx-storage`,
//! `zx-mempool` y `zx-p2p`. Eso no es casualidad ni comodidad, es el diseño:
//!
//! ```text
//! zx-node ──▶ zx-p2p ──▶ zx-core
//!    │                      ▲
//!    ├──▶ zx-consensus ─────┤
//!    ├──▶ zx-storage ───────┤
//!    └──▶ zx-mempool ───────┘
//! ```
//!
//! Red y consenso se necesitan en las dos direcciones —la red valida lo que recibe, el
//! sincronizador pide bloques por la red—, así que el ciclo tiene que romperse en algún sitio.
//! Se rompe aquí: `zx-p2p` **declara** el trait `ManejadorEntrante` y este crate lo **implementa**.
//! Un job de CI comprueba que `zx-p2p` nunca gane una dependencia hacia consenso.
//!
//! # El orden de arranque no es arbitrario
//!
//! 1. **Génesis primero.** Antes de abrir un socket o tocar el disco. Si el binario no es de esta
//!    cadena, mejor saberlo antes de haber hecho nada (C-GEN-01, C-GEN-06, C-GEN-07).
//! 2. Estado y mempool, que no dependen de la red.
//! 3. La red, que sí depende de ellos.
//!
//! Ese orden es lo que nos ahorra el arranque diferido con `oneshot` que Zebra necesita: allí el
//! servicio de red necesita el verificador **ya construido** para aceptar handshakes desde el
//! segundo cero. Aquí no, así que la inicialización es estrictamente lineal.

use std::sync::Arc;
use std::time::Duration;

use clap::Parser;
use libp2p::identity;
use zx_core::red::Red;
use zx_p2p::behaviour::ZxBehaviour;
use zx_p2p::config::ParametrosRed;
use zx_p2p::limites;
use zx_p2p::servicio::{EventoRed, arrancar};

use primitive_types::U256;
use zx_p2p::mensaje::{Peticion, Respuesta};

use zx_p2p::entrante::ManejadorEntrante;

use zx_node::cadena::Cadena;
use zx_node::sync::{Fase, Sincronizador, validar_cadena_de_cabeceras};

/// Nodo de ZEROX.
#[derive(Parser, Debug)]
#[command(name = "zx-node", version, about = "Nodo de la cadena ZEROX")]
struct Args {
    /// Red a la que conectarse.
    #[arg(long, default_value = "testnet")]
    red: String,

    /// Puerto de escucha. Por defecto, el de la red.
    #[arg(long)]
    puerto: Option<u16>,

    /// Peers a los que conectarse al arrancar, como multiaddr.
    #[arg(long = "peer")]
    peers: Vec<String>,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "zx_node=info,zx_p2p=info".into()),
        )
        .init();

    let args = Args::parse();
    let red = match args.red.as_str() {
        "mainnet" => Red::Mainnet,
        "testnet" => Red::Testnet,
        otra => return Err(format!("red desconocida: {otra} (usa mainnet o testnet)").into()),
    };

    // ── 1 · El génesis, antes que nada ───────────────────────────────────────
    //
    // Si esto falla, el nodo no ha abierto un socket ni ha tocado el disco. Con mainnet falla hoy
    // a propósito: C-GEN-06 y C-GEN-07 lo bloquean mientras P-017 siga abierto.
    let cadena = Arc::new(Cadena::nueva(red)?);
    tracing::info!(
        red = red.nombre(),
        genesis = %hex(cadena.genesis().as_bytes()),
        altura = cadena.altura(),
        "génesis verificado"
    );

    // ── 2 · La red ───────────────────────────────────────────────────────────
    let params = ParametrosRed::de(red);
    let clave = identity::Keypair::generate_ed25519();
    let peer_id = clave.public().to_peer_id();

    // El límite de bloque vigente decide el límite de transporte (C-NET-13). Con la cadena en el
    // génesis es el de arranque; cuando exista el sincronizador saldrá de la mediana larga real.
    let behaviour = ZxBehaviour::nueva(&clave, params, limites::LIMITE_BLOQUE_GENESIS)?;

    let swarm = libp2p::SwarmBuilder::with_existing_identity(clave)
        .with_tokio()
        .with_tcp(
            libp2p::tcp::Config::default(),
            libp2p::noise::Config::new,
            libp2p::yamux::Config::default,
        )?
        .with_quic()
        // El behaviour se construye ANTES y se mueve dentro, en vez de dejar que el closure lo
        // cree: así el error de C-NET-13 —margen de transporte insuficiente— sale con su tipo y su
        // mensaje, en vez de envuelto en un `Box<dyn Error>` del builder.
        .with_behaviour(move |_| behaviour)?
        // El default son 10 s desde libp2p 0.55, y es corto para un enlace de sincronización con
        // huecos: una conexión abierta solo para pedir rangos puede cerrarse entre peticiones.
        .with_swarm_config(|c| c.with_idle_connection_timeout(Duration::from_secs(60)))
        .build();

    let piezas = arrancar(swarm, Arc::clone(&cadena));
    let manejo = piezas.manejo.clone();
    let mut eventos = piezas.eventos;
    let bucle = tokio::spawn(piezas.bucle.correr());

    let puerto = args.puerto.unwrap_or(params.puerto());
    manejo
        .escuchar(format!("/ip4/0.0.0.0/tcp/{puerto}").parse()?)
        .await?;
    tracing::info!(%peer_id, puerto, "escuchando");

    tracing::info!(
        rama = format!("{:#010x}", cadena.rama()?),
        "rama de consenso activa"
    );

    for p in &args.peers {
        match p.parse() {
            Ok(addr) => {
                if let Err(e) = manejo.marcar(addr).await {
                    tracing::warn!(peer = %p, %e, "no se pudo marcar");
                }
            }
            Err(e) => tracing::warn!(peer = %p, %e, "multiaddr inválida"),
        }
    }

    // ── 3 · Correr hasta que nos digan que paremos ───────────────────────────
    //
    // `biased` para que la señal de apagado se compruebe **primero**: sin ello, un flujo constante
    // de eventos de red podría dejar la señal sin atender indefinidamente. Es el patrón de
    // `zebrad/src/components/tokio.rs`.
    let mut sinc = Sincronizador::nuevo();

    loop {
        tokio::select! {
            biased;
            _ = tokio::signal::ctrl_c() => {
                tracing::info!("señal recibida, apagando");
                break;
            }
            e = eventos.recv() => match e {
                Some(EventoRed::PeerConectado(p)) => {
                    tracing::info!(peer = %p, "conectado");
                    // Lo primero que se le dice a un peer nuevo es "¿quién eres?" (§16.1). Sin el
                    // saludo no se sabe quién va por delante, ni si es de esta cadena.
                    if let Err(e) = manejo.pedir(p, Peticion::Estado).await {
                        tracing::warn!(peer = %p, %e, "no se pudo saludar");
                    }
                }
                Some(EventoRed::PeerDesconectado(p)) => {
                    tracing::info!(peer = %p, "desconectado");
                    // Perder al peer del que descargábamos vuelve a saludar; NO penaliza.
                    sinc.peer_perdido(p);
                }
                Some(EventoRed::Escuchando(a)) => tracing::info!(addr = %a, "escuchando en"),
                Some(EventoRed::PeticionFallida { peer }) => {
                    // C-NET-05 · una petición fallida no puntúa: puede ser lentitud o una caída.
                    tracing::debug!(peer = %peer, "petición fallida");
                    sinc.peer_perdido(peer);
                }
                Some(EventoRed::Respuesta { peer, respuesta, .. }) => {
                    atender_respuesta(&mut sinc, &cadena, peer, *respuesta, &manejo).await;
                }
                None => {
                    tracing::error!("el bucle de red terminó solo");
                    break;
                }
            },
        }
    }

    // Soltar el handle cierra el canal de comandos, y el bucle termina **solo**, tras acabar lo que
    // tuviera entre manos. Abortarlo sin más podría cortarlo a mitad de una escritura.
    drop(manejo);
    match tokio::time::timeout(Duration::from_secs(10), bucle).await {
        Ok(_) => tracing::info!("apagado limpio"),
        Err(_) => tracing::warn!("el bucle no terminó en 10 s; se abandona"),
    }

    Ok(())
}

/// Qué hacer con lo que un peer responde.
///
/// Vive aparte del `select!` para que el bucle principal se lea de un vistazo: el `select!` decide
/// **qué** pasó, esto decide **qué se hace**.
async fn atender_respuesta(
    sinc: &mut Sincronizador,
    cadena: &Arc<Cadena>,
    peer: libp2p::PeerId,
    respuesta: Respuesta,
    manejo: &zx_p2p::servicio::ManejoRed,
) {
    match respuesta {
        Respuesta::Estado(e) => {
            if e.genesis != cadena.genesis() {
                // Otra cadena. El prefijo mágico (C-NET-01) evita que dos REDES se saluden; esto
                // detecta que, dentro de la misma red, no compartimos génesis. Desconectar sin
                // penalizar: no es mala fe, es que no tenemos nada que hablar.
                tracing::warn!(peer = %peer, "génesis distinto: no es nuestra cadena");
                let _ = manejo
                    .desconectar(peer, zx_p2p::error::MotivoDesconexion::Ilegible)
                    .await;
                return;
            }
            tracing::info!(peer = %peer, altura = e.altura, "saludo");

            // La comparación es por TRABAJO, no por altura: la altura la elige el peer.
            let suyo = U256::from_big_endian(&e.trabajo);
            let nuestro = U256::from_big_endian(&cadena.estado().trabajo);
            sinc.saludo_recibido(peer, suyo, nuestro);

            if sinc.fase() == Fase::Cabeceras {
                tracing::info!(peer = %peer, "va por delante: pidiendo cabeceras");
                let p = Peticion::Cabeceras {
                    locator: cadena.locator(),
                    hasta: None,
                };
                if let Err(err) = manejo.pedir(peer, p).await {
                    tracing::warn!(peer = %peer, %err, "no se pudieron pedir cabeceras");
                }
            }
        }
        Respuesta::Cabeceras(cs) => {
            let n = cs.len();
            tracing::debug!(peer = %peer, n, "cabeceras recibidas");

            // El ancla es de dónde cuelgan: el `prev_hash` de la primera, que MUST ser algo
            // nuestro. Si no lo conocemos, la respuesta no continúa nuestro locator.
            let ancla = cs.first().map(|c| c.prev_hash);
            let hasta_ancla = ancla.and_then(|a| cadena.trabajo_hasta(a));

            match hasta_ancla {
                Some(w_ancla) if n > 0 => {
                    let r = validar_cadena_de_cabeceras(
                        &cs,
                        ancla.unwrap_or_else(|| cadena.genesis()),
                        w_ancla,
                        cadena.trabajo(),
                        cadena.trabajo_de_un_bloque(),
                    );
                    match r {
                        Ok(_) => {
                            let anadidas = cadena.extender(&cs);
                            tracing::info!(
                                peer = %peer,
                                anadidas,
                                altura = cadena.altura(),
                                "cabeceras aplicadas"
                            );
                        }
                        Err(e) => {
                            tracing::warn!(peer = %peer, ?e, mala_fe = e.es_mala_fe(), "rechazadas");
                            // C-NET-05 · solo la mala fe corta. Ir por detrás, no.
                            if e.es_mala_fe() {
                                let _ = manejo
                                    .desconectar(
                                        peer,
                                        zx_p2p::error::MotivoDesconexion::ViolacionDeConsenso,
                                    )
                                    .await;
                            }
                        }
                    }
                }
                Some(_) => {}
                None if n > 0 => {
                    tracing::debug!(peer = %peer, "sus cabeceras no cuelgan de nada nuestro");
                }
                None => {}
            }

            if sinc.respuesta_registrada(n) {
                tracing::info!(altura = cadena.altura(), "al día");
            } else if sinc.fase() == Fase::Cabeceras {
                // Seguir pidiendo desde la punta nueva.
                let p = Peticion::Cabeceras {
                    locator: cadena.locator(),
                    hasta: None,
                };
                if let Err(err) = manejo.pedir(peer, p).await {
                    tracing::debug!(peer = %peer, %err, "no se pudo seguir pidiendo");
                }
            }
        }
        Respuesta::Bloques(bs) => {
            tracing::debug!(peer = %peer, n = bs.len(), "bloques recibidos");
        }
        Respuesta::NoDisponible => {
            // No es un error y no puntúa (C-NET-05).
            tracing::debug!(peer = %peer, "el peer no tiene lo que se le pidió");
        }
    }
}

/// Hexadecimal, para los logs.
fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}
