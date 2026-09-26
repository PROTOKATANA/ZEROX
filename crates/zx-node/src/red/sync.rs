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

use libp2p::PeerId;
use tokio::sync::mpsc;

use zx_p2p::error::MotivoDesconexion;
use zx_p2p::mensaje::{Peticion, Respuesta};
use zx_p2p::servicio::{EventoRed, ManejoRed};

use super::TrabajoRed;
use super::vista::VistaRed;
use std::sync::Arc;

/// Cuántos hashes se piden a la vez en una `Peticion::Bloques` de sincronización (el tope del
/// protocolo, no un valor propio: pedir más de golpe es un `Excedido` seguro).
const LOTE_BLOQUES: usize = zx_p2p::limites::MAX_HASHES_POR_PETICION;

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
    while let Some(evento) = eventos.recv().await {
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
            EventoRed::Respuesta {
                peer, respuesta, ..
            } => atender_respuesta(&manejo, &vista, &trabajo, &mut peers, peer, *respuesta).await,
            EventoRed::Escuchando(_) | EventoRed::Suscripcion { .. } => {}
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

            // Fase PoW: si el par declara más altura que nosotros, pedimos cabeceras desde nuestro
            // propio localizador (denso cerca de nuestra punta, espaciado hacia atrás).
            if otro.punta_pow.altura > vista.altura_pow() {
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
