//! Sincronización (`ORDEN-W06d2` decisión 4): saludo, localizador PoW y recorrido hacia atrás del
//! DAG por padres.
//!
//! # Por qué esto es una tarea `tokio` aparte, y no el hilo de consenso
//!
//! Orquestar peticiones (a quién le pido qué, cuándo reintentar) es protocolo, no consenso: no
//! necesita `zx-cadena`. Vive en su propia tarea asíncrona, hablando con [`zx_p2p::servicio::ManejoRed`]
//! directamente y leyendo [`super::vista::VistaRed`] para saber qué nos falta. Los bloques que
//! consigue no se admiten aquí: se encolan como [`super::TrabajoRed::BloqueDeSincronizacion`] para
//! que el hilo de consenso los pase por la tubería única — la misma que usa un bloque llegado por
//! gossip. Así ningún bloque de red evita la validación completa (decisión 2 de la orden), venga por
//! donde venga.
//!
//! # El recorrido del DAG reutiliza el depósito de huérfanos
//!
//! Esta tarea no implementa un algoritmo de recorrido de DAG propio: pide como `Bloques` las puntas
//! PoST que un par anuncia en su saludo. Si no tenemos sus padres, el hilo de consenso los deposita
//! como huérfanos y pide él mismo los padres que faltan (decisión 3) — la misma cascada que resuelve
//! un huérfano llegado por gossip resuelve, sin código nuevo, el "recorrido hacia atrás desde las
//! puntas del par" que pide la decisión 4. El límite de saltos
//! ([`super::LIMITE_SALTOS_RECORRIDO_ATRAS`]) lo aplica el hilo de consenso, no esta tarea.

use std::collections::HashMap;
use std::sync::Arc;
use std::time::Duration;

use libp2p::PeerId;
use tokio::sync::mpsc;
use tokio::time::{self, MissedTickBehavior};

use zx_p2p::error::MotivoDesconexion;
use zx_p2p::mensaje::{Peticion, Respuesta};
use zx_p2p::servicio::{EventoRed, ManejoRed};

use super::TrabajoRed;
use super::vista::VistaRed;

/// Cuántos hashes se piden a la vez en una `Peticion::Bloques` de sincronización (el tope del
/// protocolo, no un valor propio: pedir más de golpe es un `Excedido` seguro).
const LOTE_BLOQUES: usize = zx_p2p::limites::MAX_HASHES_POR_PETICION;

/// Cada cuánto se repite el saludo a los pares **ya conectados**, no solo al conectar.
///
/// `ORDEN-W06d3`, diagnóstico de la decisión 4 (`PROGRESO.md`): un bloque perdido por gossip —por
/// ejemplo, publicado antes de que la malla de gossipsub terminara de formarse tras conectar— deja
/// una cadena de huérfanos que **nadie vuelve a pedir**: `intentar_admitir_*_de_red` solo pide
/// activamente el padre que falta cuando conoce el origen (`Some(peer)`, la ruta de sincronización),
/// nunca para un huérfano llegado por gossip (`origen = None`, no se sabe quién lo propagó), y el
/// único disparador de un nuevo `Peticion::CabecerasPow`/`Peticion::Bloques` era el saludo **al
/// conectar**. Sin un reintento periódico, un nodo que se queda atrás una sola vez no se recupera
/// nunca por sí solo, aunque la red entera siga viva y minando. Valor dev: generoso frente al ritmo
/// de bloques PoW (dificultad trivial, sub-segundo) para no saturar de peticiones un par que va bien.
const PLAZO_REINTENTO_SALUDO: Duration = Duration::from_secs(5);

/// Qué sabemos de un par para no repetirle la misma petición sin sentido.
#[derive(Default)]
struct EstadoPeer {
    saludo_pedido: bool,
}

/// Corre para siempre (hasta que el canal de eventos se cierra): la tarea de sincronización.
pub async fn tarea_sincronizacion(
    mut eventos: mpsc::Receiver<EventoRed>,
    manejo: ManejoRed,
    vista: Arc<VistaRed>,
    trabajo: mpsc::UnboundedSender<TrabajoRed>,
) {
    let mut peers: HashMap<PeerId, EstadoPeer> = HashMap::new();
    let mut reintento = time::interval(PLAZO_REINTENTO_SALUDO);
    reintento.set_missed_tick_behavior(MissedTickBehavior::Delay);
    // El primer `tick()` de un `interval` es inmediato: se consume aquí, antes del bucle, para no
    // repetir el saludo del `PeerConectado` inicial un instante después de haberlo pedido ya.
    reintento.tick().await;
    loop {
        tokio::select! {
            evento = eventos.recv() => {
                let Some(evento) = evento else { break; };
                match evento {
                    EventoRed::PeerConectado(peer) => {
                        peers.entry(peer).or_default();
                        if manejo.pedir(peer, Peticion::Estado).await.is_err() {
                            tracing::debug!(%peer, "no se pudo pedir el saludo: el bucle de red ya no está");
                        }
                    }
                    EventoRed::PeerDesconectado(peer) => {
                        peers.remove(&peer);
                    }
                    EventoRed::PeticionFallida { peer } => {
                        tracing::debug!(%peer, "una petición de sincronización no llegó a completarse");
                    }
                    EventoRed::Respuesta { peer, respuesta, .. } => {
                        atender_respuesta(&manejo, &vista, &trabajo, &mut peers, peer, *respuesta).await;
                    }
                    EventoRed::Escuchando(_) | EventoRed::Suscripcion { .. } => {}
                }
            }
            _ = reintento.tick() => {
                for peer in peers.keys().copied().collect::<Vec<_>>() {
                    if manejo.pedir(peer, Peticion::Estado).await.is_err() {
                        tracing::debug!(%peer, "no se pudo repetir el saludo periódico");
                    }
                }
            }
        }
    }
}

async fn atender_respuesta(
    manejo: &ManejoRed,
    vista: &VistaRed,
    trabajo: &mpsc::UnboundedSender<TrabajoRed>,
    peers: &mut HashMap<PeerId, EstadoPeer>,
    peer: PeerId,
    respuesta: Respuesta,
) {
    match respuesta {
        Respuesta::Estado(otro) => {
            let nuestro = vista.estado();
            if otro.hash_genesis != nuestro.hash_genesis || otro.red != nuestro.red {
                tracing::warn!(%peer, "génesis o red ajenos: desconectando");
                manejo
                    .desconectar(peer, MotivoDesconexion::ViolacionDeConsenso)
                    .await
                    .ok();
                return;
            }
            if let Some(e) = peers.get_mut(&peer) {
                e.saludo_pedido = true;
            }

            // Fase PoW: pedimos cabeceras si el par declara más altura que nosotros, **o** si su
            // punta declarada es un hash que no reconocemos todavía (aunque su altura sea igual o
            // menor). `ORDEN-W06d3`, hallazgo en vivo (`PROGRESO.md`): comparar solo la altura
            // asume que "más alto" es siempre "más trabajo", lo que es falso frente a una
            // bifurcación real — un nodo que ha estado minando **en solitario** (p. ej. porque el
            // primer bloque de otro par se perdió antes de que la malla de gossipsub terminara de
            // formarse, el mismo diagnóstico de la decisión 4) puede alcanzar, sin compartir ningún
            // bloque con nadie, una altura igual o mayor que la de la red compartida, y entonces
            // esta condición **nunca** se disparaba: el nodo aislado se quedaba así para siempre,
            // sin pedir jamás las cabeceras de la rama que en realidad pesa más (`FC-3` lo decidiría
            // bien si llegara a verla; el problema es que nunca llega). Pedir también por "punta
            // desconocida" no cuesta más que una petición de más cuando de verdad coincide.
            let punta_desconocida = !vista.tiene_cuerpo(&otro.punta_pow.hash);
            if otro.punta_pow.altura > vista.altura_pow() || punta_desconocida {
                let locator = vista.locator();
                if manejo
                    .pedir(
                        peer,
                        Peticion::CabecerasPow {
                            locator,
                            parada: None,
                        },
                    )
                    .await
                    .is_err()
                {
                    tracing::debug!(%peer, "no se pudo pedir cabeceras PoW");
                }
            }

            // Fase PoST: pedimos directamente sus puntas que no tengamos ya. Si sus padres nos
            // faltan, el hilo de consenso los deposita como huérfanos y pide él mismo lo que falte
            // (ver el docstring del módulo): esto basta para arrancar el recorrido hacia atrás.
            let puntas_ausentes: Vec<_> = otro
                .puntas_post
                .iter()
                .copied()
                .filter(|h| !vista.tiene_cuerpo(h))
                .collect();
            for lote in puntas_ausentes.chunks(LOTE_BLOQUES) {
                if manejo
                    .pedir(
                        peer,
                        Peticion::Bloques {
                            hashes: lote.to_vec(),
                        },
                    )
                    .await
                    .is_err()
                {
                    tracing::debug!(%peer, "no se pudo pedir puntas PoST");
                }
            }
        }
        Respuesta::CabecerasPow(cabeceras) => {
            // No se valida aquí (esta tarea no ve consenso): se piden los cuerpos completos en
            // lotes, y es la tubería única del hilo de consenso la que decide si son válidas.
            let hashes: Vec<_> = cabeceras
                .iter()
                .map(zx_core::preimage::block::BlockHeader::block_hash)
                .filter(|h| !vista.tiene_cuerpo(h))
                .collect();
            for lote in hashes.chunks(LOTE_BLOQUES) {
                if manejo
                    .pedir(
                        peer,
                        Peticion::Bloques {
                            hashes: lote.to_vec(),
                        },
                    )
                    .await
                    .is_err()
                {
                    tracing::debug!(%peer, "no se pudo pedir cuerpos PoW");
                }
            }
        }
        Respuesta::Bloques(bloques) => {
            for bloque in bloques {
                if trabajo
                    .send(TrabajoRed::BloqueDeSincronizacion { de: peer, bloque })
                    .is_err()
                {
                    tracing::error!("hilo de consenso caído: bloque de sincronización descartado");
                    return;
                }
            }
        }
        Respuesta::NoDisponible => {
            // Legítimo (el par podó esa rama, o nunca la tuvo): no penaliza (C-NET-05).
        }
    }
}
