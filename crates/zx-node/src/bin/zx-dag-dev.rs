//! `zx-dag-dev`: bootstrap aislado del génesis DAG de **desarrollo** y runner P2P local.
//!
//! # Alcance
//!
//! Primero llama **solo** a [`iniciar_bootstrap_dag_dev`] y comprueba estructura y hash contra el
//! literal congelado del perfil dev; si eso falla, sale con código distinto de cero **antes de
//! abrir ningún socket** (`C-GEN-07`). Solo entonces, y únicamente si se pide con `--listen` o
//! `--peer`, monta un `Swarm` DAG dev con transportes TCP+Noise+Yamux y el perfil
//! [`ParametrosRed::dag_dev`] (C-NET-02), con el mismo `Presupuesto` compartido entre el códec y el
//! bucle.
//!
//! Sin `--listen` ni `--peer` el binario **no abre red**: verifica el bootstrap, imprime su alcance
//! y termina. Esa es la salida de bootstrap/hash ya probada, que se conserva.
//!
//! # Límites, dichos sin adorno
//!
//! - **No admite PoST ni propaga bloques.** El handler solo sirve el saludo `Peticion::Estado`;
//!   los callbacks de difusión devuelven `Ignorar`.
//! - No acepta `--red` ni `--datos`, no abre RocksDB y no reutiliza ninguna instancia ni protocolo
//!   de testnet.
//! - `--listen` y cada `--peer` se restringen a loopback (`127.0.0.1` o `::1`); una IP o un
//!   hostname externo se rechazan explícitamente antes de abrir sockets.
//! - El plazo del saludo es de desarrollo (`PLAZO_SALUDO_DEV`), no un parámetro de consenso.

use std::net::{Ipv4Addr, Ipv6Addr};
use std::process::ExitCode;
use std::sync::Arc;
use std::time::{Duration, Instant};

use clap::Parser;
use libp2p::multiaddr::Protocol;
use libp2p::{Multiaddr, identity};

use zx_node::bootstrap_dag_dev::{EstadoBootstrapDagDev, iniciar_bootstrap_dag_dev};
use zx_node::nodo_dag_dev::{ManejadorDagDev, NodoDagDev};
use zx_p2p::behaviour::ZxBehaviour;
use zx_p2p::config::ParametrosRed;
use zx_p2p::limites;
use zx_p2p::presupuesto::Presupuesto;
use zx_p2p::servicio::{EventoRed, Piezas, arrancar_con};

/// Cadena del flag `--listen` cuando se pasa sin valor: loopback y puerto efímero.
const ESCUCHA_POR_DEFECTO: &str = "/ip4/127.0.0.1/tcp/0";

/// Argumentos del runner dev.
///
/// Un argumento desconocido lo rechaza clap antes de ejecutar nada.
#[derive(Parser, Debug)]
#[command(
    name = "zx-dag-dev",
    version,
    about = "Bootstrap local del génesis DAG de desarrollo y saludo P2P loopback (sin PoST)"
)]
struct Args {
    /// Dirección de escucha local. Sin valor usa `/ip4/127.0.0.1/tcp/0`.
    ///
    /// Solo se escucha si este flag está presente o si hay algún `--peer`.
    #[arg(long, num_args = 0..=1, default_missing_value = ESCUCHA_POR_DEFECTO)]
    listen: Option<Multiaddr>,

    /// Peer loopback al que conectarse al arrancar. Repetible.
    #[arg(long = "peer")]
    peers: Vec<Multiaddr>,
}

#[tokio::main]
async fn main() -> ExitCode {
    let args = Args::parse();

    // ── 1 · El bootstrap, antes que nada ─────────────────────────────────────────────────────
    //
    // Si el hash no coincide se sale aquí, sin haber abierto un socket.
    let estado = match iniciar_bootstrap_dag_dev() {
        Ok(estado) => estado,
        Err(e) => {
            eprintln!("fallo del bootstrap DAG dev: {e}");
            return ExitCode::FAILURE;
        }
    };
    let hash_hex = hex(estado.hash_congelado_dev().as_bytes());
    println!("bootstrap DAG dev: estructura y hash congelado, OK");
    println!("hash dev: {hash_hex}");

    // ── 2 · La red solo si se pidió ──────────────────────────────────────────────────────────
    //
    // El aviso se elige según el modo **antes** de imprimirlo: sin flags no se abre red, y con
    // `--listen`/`--peer` sería falso decir que no hay red.
    let hay_red = args.listen.is_some() || !args.peers.is_empty();
    if !hay_red {
        println!("aviso: solo bootstrap local; sin red, persistencia ni admisión PoST");
        println!("aviso: no admite PoST ni propaga bloques; solo saludo de identidad DAG dev");
        return ExitCode::SUCCESS;
    }

    let escucha = args.listen.clone().unwrap_or_else(direccion_por_defecto);

    // Restricción a loopback ANTES de abrir sockets: una IP o un hostname externo se rechazan.
    if let Err(e) = validar_loopback(&escucha, "--listen") {
        eprintln!("{e}");
        return ExitCode::FAILURE;
    }
    for peer in &args.peers {
        if let Err(e) = validar_loopback(peer, "--peer") {
            eprintln!("{e}");
            return ExitCode::FAILURE;
        }
    }

    // Aviso veraz del modo red: **sí** hay saludo P2P loopback, pero sigue sin persistencia ni
    // admisión PoST y no se propaga ningún bloque. No es una medida Δ ni una validación PoST.
    println!("aviso: bootstrap local; saludo P2P loopback, sin persistencia ni admisión PoST");
    println!("aviso: no admite PoST ni propaga bloques; solo saludo de identidad DAG dev");

    match correr_red(&estado, escucha, &args.peers, &hash_hex).await {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("fallo de la red DAG dev: {e}");
            ExitCode::FAILURE
        }
    }
}

/// Monta el `Swarm` DAG dev, saluda y corre hasta la señal de apagado.
async fn correr_red(
    estado: &EstadoBootstrapDagDev,
    escucha: Multiaddr,
    peers: &[Multiaddr],
    hash_hex: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    let clave = identity::Keypair::generate_ed25519();
    let peer_id = clave.public().to_peer_id();

    // Una sola instancia de `Presupuesto` para el códec y el bucle (C-NET-21).
    let presupuesto = Presupuesto::default();
    let behaviour = ZxBehaviour::con_presupuesto(
        &clave,
        ParametrosRed::dag_dev(),
        limites::LIMITE_BLOQUE_GENESIS,
        presupuesto.clone(),
    )?;

    let swarm = libp2p::SwarmBuilder::with_existing_identity(clave)
        .with_tokio()
        .with_tcp(
            libp2p::tcp::Config::default(),
            libp2p::noise::Config::new,
            libp2p::yamux::Config::default,
        )?
        .with_behaviour(move |_| behaviour)?
        .with_swarm_config(|c| c.with_idle_connection_timeout(Duration::from_secs(60)))
        .build();

    // Se desestructura `Piezas` en vez de clonar `piezas.manejo`: así `manejo` es el **único**
    // handle original y no queda una copia escondida dentro de `piezas` que impida cerrar el canal
    // de comandos al apagar.
    let Piezas {
        manejo,
        eventos,
        bucle,
    } = arrancar_con(
        swarm,
        Arc::new(ManejadorDagDev::desde_estado_dev(estado)),
        presupuesto,
    );
    let mut eventos = eventos;
    let bucle = tokio::spawn(bucle.correr());
    let mut nodo = NodoDagDev::nuevo(estado, manejo.clone());

    println!("nodo DAG dev {peer_id} (saludo de identidad; no admite PoST ni propaga bloques)");
    manejo.escuchar(escucha).await?;
    for peer in peers {
        if let Err(e) = manejo.marcar(peer.clone()).await {
            eprintln!("no se pudo marcar {peer}: {e}");
        }
    }

    // El tick solo evalúa vencimientos; el `Instant` del plazo es de desarrollo.
    let mut tick = tokio::time::interval(Duration::from_secs(1));
    loop {
        tokio::select! {
            _ = tokio::signal::ctrl_c() => {
                println!("señal recibida, apagando");
                break;
            }
            _ = tick.tick() => {
                let _ = nodo.expirar(Instant::now()).await;
            }
            evento = eventos.recv() => match evento {
                Some(e) => {
                    if let EventoRed::Escuchando(addr) = &e {
                        println!("escuchando en {addr}");
                    }
                    for listo in nodo.atender(e).await {
                        println!("peer listo {listo} {hash_hex}");
                    }
                }
                None => {
                    eprintln!("el bucle de red terminó solo");
                    break;
                }
            },
        }
    }

    // Apagado cooperativo: soltar `nodo` y **todos** los clones de `ManejoRed` cierra el canal de
    // comandos, y el bucle sale tras acabar lo que tuviera entre manos. No se aborta ni se oculta
    // un plazo agotado: un bucle que no termina o que paniquea es un fallo, no un apagado limpio.
    drop(nodo);
    drop(manejo);
    match tokio::time::timeout(Duration::from_secs(10), bucle).await {
        Ok(Ok(())) => Ok(()),
        Ok(Err(e)) if e.is_panic() => Err(format!("el bucle de red terminó con panic: {e}").into()),
        Ok(Err(e)) => Err(format!("el bucle de red se canceló antes de tiempo: {e}").into()),
        Err(_) => Err("el bucle de red no terminó tras soltar todos los handles".into()),
    }
}

/// Dirección de escucha por defecto: `/ip4/127.0.0.1/tcp/0`, construida sin parsear texto.
fn direccion_por_defecto() -> Multiaddr {
    Multiaddr::empty()
        .with(Protocol::Ip4(Ipv4Addr::LOCALHOST))
        .with(Protocol::Tcp(0))
}

/// Exige que una multiaddr contenga **solo** la IP loopback exacta y ningún hostname.
///
/// La orden autoriza únicamente `127.0.0.1` o `::1`. Por eso se compara por igualdad exacta contra
/// [`Ipv4Addr::LOCALHOST`]/[`Ipv6Addr::LOCALHOST`] y se rechaza cualquier otra IP aunque
/// `Ipv4Addr::is_loopback` la aceptara (p. ej. `127.0.0.2` o el resto de `127/8`). Se rechaza
/// cualquier `Ip4`/`Ip6` que no sea exactamente esa —aunque aparezca detrás de otro protocolo— y
/// cualquier variante `Dns*`. Una dirección sin IP (por ejemplo `/memory/1`) tampoco pasa.
fn validar_loopback(addr: &Multiaddr, cual: &str) -> Result<(), String> {
    let mut hay_ip = false;
    for protocolo in addr.iter() {
        match protocolo {
            Protocol::Ip4(ip) => {
                hay_ip = true;
                if ip != Ipv4Addr::LOCALHOST {
                    return Err(format!(
                        "{cual}: {addr} no es loopback exacto; se exige 127.0.0.1 o ::1"
                    ));
                }
            }
            Protocol::Ip6(ip) => {
                hay_ip = true;
                if ip != Ipv6Addr::LOCALHOST {
                    return Err(format!(
                        "{cual}: {addr} no es loopback exacto; se exige 127.0.0.1 o ::1"
                    ));
                }
            }
            Protocol::Dns(_) | Protocol::Dns4(_) | Protocol::Dns6(_) | Protocol::Dnsaddr(_) => {
                return Err(format!(
                    "{cual}: {addr} usa un hostname; se exige una IP loopback literal"
                ));
            }
            _ => {}
        }
    }
    if !hay_ip {
        return Err(format!(
            "{cual}: {addr} no contiene una IP loopback; se exige 127.0.0.1 o ::1"
        ));
    }
    Ok(())
}

/// Hexadecimal en minúsculas, para la salida del hash.
fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

/// Pruebas de la validación de loopback, sin abrir sockets.
#[cfg(test)]
mod pruebas {
    #![allow(
        clippy::unwrap_used,
        clippy::expect_used,
        clippy::panic,
        clippy::indexing_slicing,
        reason = "las pruebas fallan con panic por diseño"
    )]

    use super::validar_loopback;
    use libp2p::Multiaddr;
    use libp2p::multiaddr::Protocol;
    use std::net::{Ipv4Addr, Ipv6Addr};

    fn dir(texto: &str) -> Multiaddr {
        texto.parse().expect("multiaddr de prueba")
    }

    /// Solo `127.0.0.1` y `::1` pasan; nada de `127.0.0.2` ni de otro `127/8`.
    #[test]
    fn solo_acepta_loopback_exacto() {
        assert!(validar_loopback(&dir("/ip4/127.0.0.1/tcp/0"), "--listen").is_ok());
        assert!(validar_loopback(&dir("/ip6/::1/tcp/0"), "--listen").is_ok());

        for mala in [
            "/ip4/127.0.0.2/tcp/0",
            "/ip4/127.1.2.3/tcp/0",
            "/ip4/0.0.0.0/tcp/0",
            "/ip4/8.8.8.8/tcp/1",
            "/ip6/::2/tcp/0",
            "/ip6/fe80::1/tcp/0",
            "/dns4/example.com/tcp/1",
            "/memory/1",
        ] {
            let error = validar_loopback(&dir(mala), "--listen").expect_err("MUST rechazarse");
            assert!(
                error.contains("loopback") || error.contains("hostname"),
                "{mala}: {error}"
            );
        }
    }

    /// Una dirección con dos IP, una de ellas externa, no pasa aunque la primera sea loopback.
    #[test]
    fn rechaza_una_direccion_con_dos_ip_y_una_externa() {
        let mixta4 = Multiaddr::empty()
            .with(Protocol::Ip4(Ipv4Addr::LOCALHOST))
            .with(Protocol::Ip4(Ipv4Addr::new(8, 8, 8, 8)))
            .with(Protocol::Tcp(1));
        let error = validar_loopback(&mixta4, "--listen").expect_err("el externo MUST rechazarse");
        assert!(error.contains("loopback"), "{mixta4}: {error}");

        let mixta6 = Multiaddr::empty()
            .with(Protocol::Ip6(Ipv6Addr::LOCALHOST))
            .with(Protocol::Ip4(Ipv4Addr::new(10, 0, 0, 1)))
            .with(Protocol::Tcp(1));
        assert!(
            validar_loopback(&mixta6, "--listen").is_err(),
            "{mixta6}: el externo MUST rechazarse"
        );
    }
}
