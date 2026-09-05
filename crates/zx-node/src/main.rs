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
use zx_p2p::servicio::arrancar;

use zx_node::cadena::Cadena;
use zx_node::nodo::{Fin, Nodo};

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

    /// Dónde guardar la cadena. Sin esto, la cadena vive en RAM y se pierde al cerrar.
    #[cfg(feature = "disco")]
    #[arg(long)]
    datos: Option<std::path::PathBuf>,
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
    let cadena = Arc::new(abrir_cadena(red, &args)?);
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
    let mut nodo = Nodo::nuevo(Arc::clone(&cadena), manejo.clone());

    loop {
        tokio::select! {
            biased;
            _ = tokio::signal::ctrl_c() => {
                tracing::info!("señal recibida, apagando");
                break;
            }
            e = eventos.recv() => match e {
                // Todo lo que el nodo hace ante un evento vive en `zx_node::nodo`, no aquí: es la
                // única forma de que los tests de integración conduzcan el MISMO código que corre
                // en producción, en vez de una segunda copia del protocolo escrita a mano.
                Some(evento) => {
                    if nodo.atender(evento).await == Fin::Detener {
                        break;
                    }
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
        Ok(_) => tracing::info!("bucle de red detenido"),
        Err(_) => tracing::warn!("el bucle no terminó en 10 s; se abandona"),
    }

    // Y AHORA se fuerza el volcado a disco, con la red ya parada para que nada escriba después.
    //
    // C-STORE-10 dice que no se sincroniza en cada bloque: perder los últimos bloques enteros tras
    // un corte de corriente es recuperable resincronizando. Pero un apagado **deliberado** es otra
    // cosa: aquí el volcado es gratis —ocurre una vez— y convierte "pierdes los últimos bloques"
    // en "no pierdes nada". No hacerlo era desperdiciar la única ocasión en que sale de balde.
    if let Err(e) = cadena.almacen().sincronizar() {
        tracing::error!(%e, "no se pudo volcar el almacén a disco");
    } else {
        tracing::info!("apagado limpio");
    }

    Ok(())
}

/// Abre la cadena, sobre disco si se pidió y hay soporte compilado.
fn abrir_cadena(red: Red, args: &Args) -> Result<Cadena, Box<dyn std::error::Error>> {
    #[cfg(feature = "disco")]
    if let Some(ruta) = &args.datos {
        let almacen = zx_storage::AlmacenEnDisco::abrir(ruta)?;
        tracing::info!(ruta = %ruta.display(), "almacén en disco");
        return Ok(Cadena::con_almacen(red, Arc::new(almacen))?);
    }
    let _ = args;
    tracing::warn!("sin --datos: la cadena vive en RAM y se pierde al cerrar");
    Ok(Cadena::nueva(red)?)
}

/// Hexadecimal, para los logs.
fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}
