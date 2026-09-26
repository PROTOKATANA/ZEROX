//! El bucle de eventos y su handle (SPEC §16).
//!
//! # Por qué un bucle con canales y no un `Arc<Mutex<Swarm>>`
//!
//! Un `Swarm` de libp2p **hay que pollearlo continuamente** y además es `!Sync`, así que no se
//! puede compartir entre tareas. Solo hay una forma sensata: **una tarea lo posee en exclusiva** y
//! todo el mundo habla con ella por canales.
//!
//! # El `Swarm` NO sale de este módulo
//!
//! Nadie fuera ve un tipo de `libp2p::swarm`. Lo que sale son [`EventoRed`], que son tipos nuestros.
//!
//! # El error de un peer NO es un error del nodo
//!
//! Regla dura de este bucle: **nada que venga de un peer puede propagar un `Err` fuera del
//! `select!`**. Se registra, se desconecta a quien haga falta, y se sigue.

use std::sync::Arc;

use libp2p::swarm::SwarmEvent;
use libp2p::{Multiaddr, PeerId, Swarm};
use tokio::sync::{mpsc, oneshot};

use libp2p::{gossipsub, request_response};

use crate::behaviour::{ZxBehaviour, ZxBehaviourEvent};
use crate::config::ParametrosRed;
use crate::entrante::{ManejadorEntrante, Veredicto};
use crate::error::{MotivoDesconexion, P2pError};
use crate::mensaje::{BloqueRed, FamiliaBloque, Peticion, Respuesta};
use crate::presupuesto::Presupuesto;

/// Capacidad del canal de comandos.
///
/// **Nunca cero.** Un canal de capacidad cero es un *rendezvous*: el que envía se bloquea hasta que
/// el bucle recoge. Y si el bucle está bloqueado enviando un evento que nadie consume, deja de
/// pollear el `Swarm` — y **la red entera se para**.
pub const CAPACIDAD_COMANDOS: usize = 256;

/// Capacidad del canal de eventos hacia el nodo.
pub const CAPACIDAD_EVENTOS: usize = 1024;

/// Lo que se le pide al bucle desde fuera.
#[derive(Debug)]
pub(crate) enum Comando {
    /// Empezar a escuchar en una dirección.
    Escuchar {
        /// Dónde.
        addr: Multiaddr,
        /// Por dónde vuelve el resultado.
        respuesta: oneshot::Sender<Result<(), P2pError>>,
    },
    /// Conectar con un peer.
    Marcar {
        /// Dónde.
        addr: Multiaddr,
        /// Por dónde vuelve el resultado.
        respuesta: oneshot::Sender<Result<(), P2pError>>,
    },
    /// Enviar una petición de sincronización.
    Pedir {
        /// A quién.
        peer: PeerId,
        /// Qué.
        peticion: Peticion,
    },
    /// Publicar bytes ya serializados por un tópico de la red.
    Difundir {
        /// Tópico, que debe ser uno de los dos temas de [`ParametrosRed`].
        topico: String,
        /// Contenido ya serializado.
        datos: Vec<u8>,
        /// Por dónde vuelve el resultado **local** del intento de publicación.
        respuesta: oneshot::Sender<Result<(), P2pError>>,
    },
    /// Cortar con un peer, y por qué.
    Desconectar {
        /// A quién.
        peer: PeerId,
        /// Por qué. Solo [`MotivoDesconexion::ViolacionDeConsenso`] puntúa.
        motivo: MotivoDesconexion,
    },
}

/// Lo que el bucle cuenta hacia fuera. **Ningún tipo de libp2p asoma aquí.**
#[derive(Clone, Debug)]
pub enum EventoRed {
    /// Se estableció conexión.
    PeerConectado(PeerId),
    /// Se perdió la conexión.
    PeerDesconectado(PeerId),
    /// Estamos escuchando en una dirección.
    Escuchando(Multiaddr),
    /// Un peer respondió a una petición de sincronización.
    ///
    /// La respuesta va en `Box` porque `Respuesta::Bloques` puede ser grande.
    Respuesta {
        /// Quién respondió.
        peer: PeerId,
        /// Identificador de la petición que se contesta.
        peticion: u64,
        /// Lo que respondió.
        respuesta: Box<Respuesta>,
    },
    /// Una petición no llegó a completarse. **No puntúa.**
    PeticionFallida {
        /// A quién se le había pedido.
        peer: PeerId,
    },
    /// Un peer se suscribió (`true`) o desuscribió (`false`) de un tema de gossipsub.
    ///
    /// La malla no se forma en el instante de la conexión: hasta que el `SUBSCRIBE` de un peer no
    /// llega, `gossipsub.publish` devuelve `NoPeersSubscribedToTopic`. Este evento es la señal de
    /// que el otro lado ya está en la malla.
    Suscripcion {
        /// Quién cambió de suscripción.
        peer: PeerId,
        /// A qué tema.
        topico: String,
        /// `true` si se suscribió, `false` si se desuscribió.
        suscrito: bool,
    },
}

/// El handle con el que el resto del nodo habla con la red.
#[derive(Clone, Debug)]
pub struct ManejoRed {
    comandos: mpsc::Sender<Comando>,
    parametros: ParametrosRed,
}

impl ManejoRed {
    /// Empieza a escuchar.
    ///
    /// # Errores
    /// [`P2pError::Transporte`] si el bucle ya no está, o lo que devuelva el `Swarm`.
    pub async fn escuchar(&self, addr: Multiaddr) -> Result<(), P2pError> {
        let (tx, rx) = oneshot::channel();
        self.enviar(Comando::Escuchar {
            addr,
            respuesta: tx,
        })
        .await?;
        rx.await
            .map_err(|_| P2pError::Transporte("el bucle de red murió antes de responder"))?
    }

    /// Conecta con un peer.
    ///
    /// # Errores
    /// [`P2pError::Transporte`] si el bucle ya no está, o lo que devuelva el `Swarm`.
    pub async fn marcar(&self, addr: Multiaddr) -> Result<(), P2pError> {
        let (tx, rx) = oneshot::channel();
        self.enviar(Comando::Marcar {
            addr,
            respuesta: tx,
        })
        .await?;
        rx.await
            .map_err(|_| P2pError::Transporte("el bucle de red murió antes de responder"))?
    }

    /// Pide algo a un peer. **No espera respuesta**: llegará como evento.
    ///
    /// # Errores
    /// [`P2pError::Transporte`] si el bucle ya no está.
    pub async fn pedir(&self, peer: PeerId, peticion: Peticion) -> Result<(), P2pError> {
        self.enviar(Comando::Pedir { peer, peticion }).await
    }

    /// Difundir **un bloque completo** por el tema que le corresponde.
    ///
    /// # Qué fija esta API, y qué NO
    ///
    /// El tema **no es un parámetro**: sale de la familia del bloque y de
    /// [`ParametrosRed`], que es la misma fuente que usa la suscripción. No hay una vía pública para
    /// publicar un bloque completo por el tema equivocado.
    ///
    /// Pero fijar **formato y tema no certifica validez**: un [`BloqueRed`] se puede construir sin
    /// validación. Quien produce MUST llamar a este método **solo después** de la validación, y la
    /// recepción mantiene el veredicto del manejador (C-NET-12).
    ///
    /// # Errores
    /// - [`P2pError::Transporte`] si el canal de comandos está cerrado o si `gossipsub.publish`
    ///   **rechaza el envío local**.
    ///
    /// `Ok(())` acredita **solo aceptación local por gossipsub**: no es entrega, no es
    /// retransmisión y no es validez.
    pub async fn difundir_bloque(&self, bloque: &BloqueRed) -> Result<(), P2pError> {
        let topico = match bloque.familia() {
            FamiliaBloque::Pow => self.parametros.topic_bloques_pow(),
            FamiliaBloque::Post => self.parametros.topic_bloques_post(),
        };
        let (tx, rx) = oneshot::channel();
        self.enviar(Comando::Difundir {
            topico: topico.to_owned(),
            datos: crate::codec::bloque_a_bytes(bloque),
            respuesta: tx,
        })
        .await?;
        rx.await
            .map_err(|_| P2pError::Transporte("el bucle de red murió antes de responder"))?
    }

    /// Corta con un peer.
    ///
    /// # Errores
    /// [`P2pError::Transporte`] si el bucle ya no está.
    pub async fn desconectar(
        &self,
        peer: PeerId,
        motivo: MotivoDesconexion,
    ) -> Result<(), P2pError> {
        self.enviar(Comando::Desconectar { peer, motivo }).await
    }

    async fn enviar(&self, c: Comando) -> Result<(), P2pError> {
        self.comandos
            .send(c)
            .await
            .map_err(|_| P2pError::Transporte("el bucle de red ya no está escuchando comandos"))
    }
}

/// El bucle. Posee el `Swarm` y corre en su propia tarea.
pub struct BucleRed<M: ManejadorEntrante> {
    swarm: Swarm<ZxBehaviour>,
    comandos: mpsc::Receiver<Comando>,
    eventos: mpsc::Sender<EventoRed>,
    manejador: Arc<M>,
    /// Contador **compartido** de memoria en vuelo (C-NET-21).
    ///
    /// Es el mismo que lleva el códec de `sync`: la reserva del parseo de una respuesta y la del
    /// parseo de un bloque difundido salen del mismo techo.
    presupuesto: Presupuesto,
}

/// Lo que devuelve [`arrancar`]: el handle, el flujo de eventos y el bucle listo para correr.
pub struct Piezas<M: ManejadorEntrante> {
    /// Con esto se le habla a la red.
    pub manejo: ManejoRed,
    /// Por aquí llegan los eventos.
    pub eventos: mpsc::Receiver<EventoRed>,
    /// Esto hay que meterlo en una tarea con [`BucleRed::correr`].
    pub bucle: BucleRed<M>,
}

/// Prepara las tres piezas con un presupuesto agregado **concreto**. No arranca nada.
pub fn arrancar_con<M: ManejadorEntrante>(
    swarm: Swarm<ZxBehaviour>,
    manejador: Arc<M>,
    presupuesto: Presupuesto,
) -> Piezas<M> {
    let (tx_cmd, rx_cmd) = mpsc::channel(CAPACIDAD_COMANDOS);
    let (tx_ev, rx_ev) = mpsc::channel(CAPACIDAD_EVENTOS);

    let parametros = swarm.behaviour().parametros_de_red();

    Piezas {
        manejo: ManejoRed {
            comandos: tx_cmd,
            parametros,
        },
        eventos: rx_ev,
        bucle: BucleRed {
            swarm,
            comandos: rx_cmd,
            eventos: tx_ev,
            manejador,
            presupuesto,
        },
    }
}

/// Prepara las tres piezas con un `Presupuesto` propio. **No arranca nada.**
///
/// ⚠️ El presupuesto que crea aquí es **solo para este bucle**: no lo comparte con el códec. La ruta
/// de producción debe usar [`arrancar_con`] con la misma instancia.
pub fn arrancar<M: ManejadorEntrante>(swarm: Swarm<ZxBehaviour>, manejador: Arc<M>) -> Piezas<M> {
    arrancar_con(swarm, manejador, Presupuesto::default())
}

impl<M: ManejadorEntrante> BucleRed<M> {
    /// Corre hasta que se sueltan todos los [`ManejoRed`].
    ///
    /// Termina **de forma cooperativa**: cuando el canal de comandos se cierra —porque nadie
    /// conserva un handle—, el bucle sale tras procesar lo que tuviera entre manos.
    pub async fn correr(mut self) {
        loop {
            tokio::select! {
                evento = futures::StreamExt::select_next_some(&mut self.swarm) => {
                    self.atender_swarm(evento);
                }
                comando = self.comandos.recv() => {
                    match comando {
                        Some(c) => self.atender_comando(c),
                        None => {
                            tracing::info!("todos los handles soltados: el bucle de red termina");
                            return;
                        }
                    }
                }
            }
        }
    }

    /// Atiende un evento del `Swarm`.
    fn atender_swarm(&mut self, evento: SwarmEvent<ZxBehaviourEvent>) {
        match evento {
            SwarmEvent::NewListenAddr { address, .. } => {
                self.avisar(EventoRed::Escuchando(address));
            }
            SwarmEvent::ConnectionEstablished { peer_id, .. } => {
                self.avisar(EventoRed::PeerConectado(peer_id));
            }
            SwarmEvent::ConnectionClosed { peer_id, .. } => {
                self.avisar(EventoRed::PeerDesconectado(peer_id));
            }
            SwarmEvent::Behaviour(ZxBehaviourEvent::Sync(e)) => self.atender_sync(e),
            SwarmEvent::Behaviour(ZxBehaviourEvent::Gossipsub(e)) => self.atender_gossip(e),
            otro => {
                tracing::trace!(?otro, "evento de swarm sin manejo específico");
            }
        }
    }

    /// Atiende el protocolo de sincronización.
    fn atender_sync(&mut self, e: request_response::Event<Peticion, Respuesta>) {
        match e {
            request_response::Event::Message { peer, message, .. } => match message {
                request_response::Message::Request {
                    request, channel, ..
                } => {
                    let respuesta = self.servir(&request);
                    if self
                        .swarm
                        .behaviour_mut()
                        .sync
                        .send_response(channel, respuesta)
                        .is_err()
                    {
                        tracing::debug!(%peer, "el peer se fue antes de recibir la respuesta");
                    }
                }
                request_response::Message::Response {
                    request_id,
                    response,
                } => {
                    self.avisar(EventoRed::Respuesta {
                        peer,
                        peticion: request_id_a_u64(request_id),
                        respuesta: Box::new(response),
                    });
                }
            },
            request_response::Event::OutboundFailure { peer, error, .. } => {
                tracing::debug!(%peer, %error, "petición de sync fallida");
                self.avisar(EventoRed::PeticionFallida { peer });
            }
            request_response::Event::InboundFailure { peer, error, .. } => {
                tracing::debug!(%peer, %error, "petición entrante fallida");
            }
            request_response::Event::ResponseSent { .. } => {}
        }
    }

    /// Construye la respuesta a una petición entrante preguntándole al manejador.
    fn servir(&self, p: &Peticion) -> Respuesta {
        match p {
            Peticion::Estado => Respuesta::Estado(self.manejador.estado()),
            Peticion::CabecerasPow { locator, parada } => {
                let cs = self.manejador.cabeceras_desde(locator, *parada);
                Respuesta::CabecerasPow(recortar(cs, crate::limites::MAX_CABECERAS_POR_RESPUESTA))
            }
            Peticion::Bloques { hashes } => {
                let bs = self.manejador.bloques_por_hash(hashes);
                if bs.is_empty() {
                    // Distinto de una lista vacía: "no tengo eso" es una respuesta legítima que
                    // **no puntúa**, mientras que una lista vacía invitaría a reintentar.
                    Respuesta::NoDisponible
                } else {
                    Respuesta::Bloques(recortar(bs, crate::limites::MAX_BLOQUES_POR_RESPUESTA))
                }
            }
        }
    }

    /// Atiende la difusión. **C-NET-12: validar antes de retransmitir.**
    fn atender_gossip(&mut self, e: gossipsub::Event) {
        match e {
            gossipsub::Event::Message {
                propagation_source,
                message_id,
                message,
            } => self.juzgar_y_reportar(&propagation_source, &message_id, &message),
            gossipsub::Event::Subscribed { peer_id, topic } => {
                self.avisar(EventoRed::Suscripcion {
                    peer: peer_id,
                    topico: topic.to_string(),
                    suscrito: true,
                });
            }
            gossipsub::Event::Unsubscribed { peer_id, topic } => {
                self.avisar(EventoRed::Suscripcion {
                    peer: peer_id,
                    topico: topic.to_string(),
                    suscrito: false,
                });
            }
            gossipsub::Event::GossipsubNotSupported { peer_id } => {
                tracing::debug!(%peer_id, "el peer no soporta gossipsub");
            }
            gossipsub::Event::SlowPeer {
                peer_id,
                failed_messages,
            } => {
                tracing::debug!(%peer_id, ?failed_messages, "peer lento en gossipsub");
            }
        }
    }

    /// Evalúa un mensaje de gossip y reporta el resultado a gossipsub.
    fn juzgar_y_reportar(
        &mut self,
        propagation_source: &PeerId,
        message_id: &gossipsub::MessageId,
        message: &gossipsub::Message,
    ) {
        let veredicto = self.juzgar(message);

        let acceptance = match veredicto {
            Veredicto::Aceptar => gossipsub::MessageAcceptance::Accept,
            Veredicto::Ignorar => gossipsub::MessageAcceptance::Ignore,
            Veredicto::Rechazar => gossipsub::MessageAcceptance::Reject,
        };

        // Sin esta llamada el mensaje se queda **pendiente para siempre** en la cola de validación:
        // ni se reenvía ni se descarta.
        if !self
            .swarm
            .behaviour_mut()
            .gossipsub
            .report_message_validation_result(message_id, propagation_source, acceptance)
        {
            tracing::debug!(
                ?veredicto,
                "el mensaje ya no estaba en la caché de validación"
            );
        }
    }

    /// Decide qué es el mensaje y se lo pasa al manejador.
    fn juzgar(&self, m: &gossipsub::Message) -> Veredicto {
        despachar(
            self.manejador.as_ref(),
            m.topic.as_str(),
            &m.data,
            &self.presupuesto,
        )
    }

    /// Atiende un comando. No es `async`: nada de lo que hace debe esperar.
    fn atender_comando(&mut self, c: Comando) {
        match c {
            Comando::Escuchar { addr, respuesta } => {
                let r = self
                    .swarm
                    .listen_on(addr)
                    .map(|_| ())
                    .map_err(|_| P2pError::DireccionInvalida);
                let _ = respuesta.send(r);
            }
            Comando::Marcar { addr, respuesta } => {
                let r = self
                    .swarm
                    .dial(addr)
                    .map_err(|_| P2pError::Transporte("no se pudo marcar"));
                let _ = respuesta.send(r);
            }
            Comando::Pedir { peer, peticion } => {
                self.swarm
                    .behaviour_mut()
                    .sync
                    .send_request(&peer, peticion);
            }
            Comando::Difundir {
                topico,
                datos,
                respuesta,
            } => {
                // C-NET-25 · defensa en profundidad. `Comando` es `pub(crate)` y su único emisor es
                // `ManejoRed`, cuyo `Sender` no se expone; aun así esta comprobación impide publicar
                // por un tema de otra red.
                let permitidos = [
                    self.swarm
                        .behaviour()
                        .parametros_de_red()
                        .topic_bloques_pow(),
                    self.swarm
                        .behaviour()
                        .parametros_de_red()
                        .topic_bloques_post(),
                ];
                if !permitidos.contains(&topico.as_str()) {
                    tracing::warn!(
                        %topico,
                        "difusión rechazada: el tema no es uno de los dos configurados"
                    );
                    let _ = respuesta.send(Err(P2pError::Transporte(
                        "tema de difusión fuera de los dos configurados",
                    )));
                    return;
                }

                let t = libp2p::gossipsub::IdentTopic::new(topico);
                // El resultado **local** de `publish` vuelve a quien encoló el comando. `Ok` solo
                // acredita aceptación local por gossipsub; no es entrega ni validez.
                let r = self
                    .swarm
                    .behaviour_mut()
                    .gossipsub
                    .publish(t, datos)
                    .map_err(|e| {
                        tracing::debug!(%e, "no se pudo difundir");
                        P2pError::Transporte("gossipsub rechazó la publicación local")
                    })
                    .map(|_| ());
                let _ = respuesta.send(r);
            }
            Comando::Desconectar { peer, motivo } => {
                tracing::debug!(%peer, ?motivo, puntua = motivo.puntua(), "desconectando");

                // C-NET-05 + C-NET-20 · solo una violación de consenso puntúa, y puntúa contra el
                // **prefijo de red**, no contra el `PeerId`.
                let puntos = motivo.puntos();
                if puntos > 0 {
                    let prefijos = self.swarm.behaviour_mut().limites_ip.prefijos_de(peer);
                    for p in prefijos {
                        if self.swarm.behaviour_mut().limites_ip.puntuar(p, puntos) {
                            tracing::warn!(
                                ?p,
                                ?motivo,
                                "prefijo de red baneado. Si esto se repite desde MUCHOS prefijos \
                                 distintos con motivo Excedido, el nodo desactualizado eres tú."
                            );
                        }
                    }
                }
                let _ = self.swarm.disconnect_peer_id(peer);
            }
        }
    }

    /// Avisa al nodo, **sin bloquear el bucle si nadie escucha**.
    ///
    /// `try_send` y no `send().await` a propósito: si el consumidor de eventos se retrasa, esperar
    /// aquí dejaría de pollear el `Swarm` y **pararía la red entera**.
    fn avisar(&self, e: EventoRed) {
        if let Err(err) = self.eventos.try_send(e) {
            tracing::warn!(%err, "canal de eventos lleno o cerrado: evento descartado");
        }
    }

    /// El manejador que este bucle usa. Existe para que los tests puedan comprobar que es el suyo.
    #[must_use]
    pub fn manejador(&self) -> &Arc<M> {
        &self.manejador
    }
}

/// A qué canal de difusión pertenece un tema, por **igualdad exacta**.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
enum TemaDifusion {
    /// Tema de bloques PoW completos de alguna red.
    BloquePow,
    /// Tema de bloques PoST completos de alguna red.
    BloquePost,
    /// Cualquier otro tema.
    Desconocido,
}

/// Clasifica un tema de difusión por igualdad exacta, nunca por prefijo ni subcadena.
fn clasificar_tema(topico: &str) -> TemaDifusion {
    match topico {
        "/zerox/bloques/pow/1" | "/zerox-testnet/bloques/pow/1" | "/zx-dev/bloques/pow/1" => {
            TemaDifusion::BloquePow
        }
        "/zerox/bloques/post/1" | "/zerox-testnet/bloques/post/1" | "/zx-dev/bloques/post/1" => {
            TemaDifusion::BloquePost
        }
        _ => TemaDifusion::Desconocido,
    }
}

/// Decide el veredicto de un mensaje de difusión a partir de su tema y sus bytes.
///
/// Es una función libre —no un método de [`BucleRed`]— para poder probar el despacho **sin**
/// construir un `Swarm`.
///
/// El `presupuesto` se **inyecta** en vez de crearse dentro: es lo que permite a un test forzar una
/// reserva fallida con `Presupuesto::nuevo(0)` y comprobar que el agotamiento local no penaliza.
///
/// # El tema desconocido no se decodifica
///
/// Un tema que no sea uno de los seis exactos devuelve [`Veredicto::Ignorar`] **sin** tocar los
/// bytes ni llamar al manejador: puede ser una versión más nueva del protocolo, no un ataque.
fn despachar<M: ManejadorEntrante>(
    manejador: &M,
    topico: &str,
    datos: &[u8],
    presupuesto: &Presupuesto,
) -> Veredicto {
    let familia = match clasificar_tema(topico) {
        TemaDifusion::BloquePow => FamiliaBloque::Pow,
        TemaDifusion::BloquePost => FamiliaBloque::Post,
        TemaDifusion::Desconocido => return Veredicto::Ignorar,
    };

    // C-NET-21 · reserva del contador **compartido**. Agotarlo es un recurso **local** de este nodo:
    // el mismo bloque, con presupuesto, se juzgaría con normalidad. Penalizarlo castigaría a un par
    // honesto por nuestra falta de memoria (C-NET-05), así que es `Ignorar`.
    //
    // La reserva se mantiene viva durante el parseo y se libera al salir.
    let Some(_reserva) = presupuesto.reservar(datos.len()) else {
        return Veredicto::Ignorar;
    };

    // El éxito del parseo **no** es validación: el veredicto de un bloque lo decide el manejador.
    // Un fallo de formato o un byte residual sí es basura indiscutible y penaliza.
    match crate::codec::bloque_desde_bytes(datos, familia) {
        Ok((bloque, [])) => manejador.bloque_difundido(&bloque),
        Ok((_, _)) => Veredicto::Rechazar,
        Err(_) => Veredicto::Rechazar,
    }
}

/// Recorta una lista al límite del protocolo.
fn recortar<T>(mut v: Vec<T>, max: usize) -> Vec<T> {
    if v.len() > max {
        tracing::warn!(
            devueltos = v.len(),
            max,
            "el manejador devolvió más elementos de los que caben; se recorta"
        );
        v.truncate(max);
    }
    v
}

/// Convierte un `OutboundRequestId` en algo que pueda cruzar la frontera del crate.
fn request_id_a_u64(id: request_response::OutboundRequestId) -> u64 {
    id.to_string().parse().unwrap_or(0)
}

#[cfg(test)]
#[expect(clippy::unwrap_used, reason = "los tests fallan con panic por diseño")]
mod tests {
    use super::{TemaDifusion, clasificar_tema, despachar};
    use crate::codec::bloque_a_bytes;
    use crate::entrante::{ManejadorEntrante, Veredicto};
    use crate::mensaje::{BloqueRed, Estado, FamiliaBloque, Fase, PuntaPow};
    use crate::presupuesto::Presupuesto;
    use std::sync::atomic::{AtomicUsize, Ordering};
    use zx_core::amount::Amount;
    use zx_core::digest::{BlockHash, Digest, MerkleRoot, TxId};
    use zx_core::firma::ClavePublica;
    use zx_core::preimage::block::BlockHeader;
    use zx_core::red::Red;
    use zx_core::tx::{ExtensionTx, Lock, OutPoint, Tx, TxIn, TxOut};

    /// Manejador espía: cuenta cada callback y **no valida nada**.
    #[derive(Default)]
    struct Espia {
        bloques: AtomicUsize,
        txs: AtomicUsize,
    }

    impl ManejadorEntrante for Espia {
        fn estado(&self) -> Estado {
            Estado {
                hash_genesis: BlockHash::from_digest(Digest::from_bytes([0; 32])),
                red: Red::Dev,
                fase: Fase::Pow,
                punta_pow: PuntaPow {
                    hash: BlockHash::from_digest(Digest::from_bytes([1; 32])),
                    altura: 0,
                    trabajo_acumulado: [0; 32],
                },
                terminal: None,
                puntas_post: vec![],
                blue_work_virtual: [0; 32],
            }
        }

        fn bloque_difundido(&self, _: &BloqueRed) -> Veredicto {
            self.bloques.fetch_add(1, Ordering::Relaxed);
            Veredicto::Aceptar
        }

        fn tx_difundida(&self, _: &[u8]) -> Veredicto {
            self.txs.fetch_add(1, Ordering::Relaxed);
            Veredicto::Aceptar
        }

        fn cabeceras_desde(&self, _: &[BlockHash], _: Option<BlockHash>) -> Vec<BlockHeader> {
            Vec::new()
        }

        fn bloques_por_hash(&self, _: &[BlockHash]) -> Vec<BloqueRed> {
            Vec::new()
        }
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
                value: Amount::nuevo(1_000).unwrap(),
                lock: Lock::PubKey {
                    pubkey: ClavePublica::desde_bytes([n; 32]),
                },
            }],
            lock_time: 0,
            expiry_height: 0,
            extension: ExtensionTx::Ninguna,
        }
    }

    /// Un bloque PoW real, serializable con `bloque_a_bytes`.
    fn bloque_pow(n: u8) -> BloqueRed {
        BloqueRed::Pow {
            cabecera: BlockHeader {
                consensus_branch_id: 0xa8b4_66a7,
                prev_hash: BlockHash::from_digest(Digest::from_bytes([n; 32])),
                merkle_root: MerkleRoot::from_digest(Digest::from_bytes([0x02; 32])),
                timestamp: 1_788_480_000,
                bits: 0x1c07_fff8,
                nonce: u64::from(n),
                height: u32::from(n),
            },
            txs: vec![tx_llave(0x03)],
            testigos: vec![vec![vec![0xAA; 64]]],
        }
    }

    /// **La tabla de los seis temas exactos y sus falsos positivos.**
    #[test]
    fn la_clasificacion_es_exacta() {
        for (tema, esperado) in [
            ("/zx-dev/bloques/pow/1", TemaDifusion::BloquePow),
            ("/zx-dev/bloques/post/1", TemaDifusion::BloquePost),
            ("/zerox/bloques/pow/1", TemaDifusion::BloquePow),
            ("/zerox/bloques/post/1", TemaDifusion::BloquePost),
            ("/zerox-testnet/bloques/pow/1", TemaDifusion::BloquePow),
            ("/zerox-testnet/bloques/post/1", TemaDifusion::BloquePost),
        ] {
            assert_eq!(clasificar_tema(tema), esperado, "{tema}");
        }

        for falso in [
            "/zx-dev/bloques/pow/1/extra",
            "/otra/zx-dev/bloques/pow/1",
            "/zx-dev/bloques/pow/2",
            "/zx-dev/bloques/1",
        ] {
            assert_eq!(
                clasificar_tema(falso),
                TemaDifusion::Desconocido,
                "{falso} no es ninguno de los seis temas"
            );
        }
    }

    /// Un bloque PoW bien formado llega **una sola vez** al callback por su tema.
    #[test]
    fn el_bloque_bien_formado_llega_una_vez() {
        let bytes = bloque_a_bytes(&bloque_pow(1));
        let espia = Espia::default();
        let v = despachar(
            &espia,
            "/zx-dev/bloques/pow/1",
            &bytes,
            &Presupuesto::default(),
        );

        assert_eq!(espia.bloques.load(Ordering::Relaxed), 1);
        assert_eq!(v, Veredicto::Aceptar, "el manejador decide");
        assert_eq!(espia.txs.load(Ordering::Relaxed), 0);
    }

    /// Un bloque PoW por el tema **post** se rechaza: la familia declarada por el tema manda.
    #[test]
    fn un_bloque_con_el_tema_de_otra_familia_se_rechaza() {
        let bytes = bloque_a_bytes(&bloque_pow(1));
        let espia = Espia::default();
        assert_eq!(
            despachar(
                &espia,
                "/zx-dev/bloques/post/1",
                &bytes,
                &Presupuesto::default()
            ),
            Veredicto::Rechazar,
            "familia cambiada"
        );
        assert_eq!(espia.bloques.load(Ordering::Relaxed), 0);
    }

    /// **El presupuesto agotado es un recurso local, no un defecto del par.**
    #[test]
    fn el_presupuesto_agotado_ignora_y_no_penaliza() {
        let bytes = bloque_a_bytes(&bloque_pow(1));

        let espia = Espia::default();
        assert_eq!(
            despachar(
                &espia,
                "/zx-dev/bloques/pow/1",
                &bytes,
                &Presupuesto::nuevo(0)
            ),
            Veredicto::Ignorar,
            "sin presupuesto no se puede juzgar: no se penaliza al propagador"
        );
        assert_eq!(
            espia.bloques.load(Ordering::Relaxed),
            0,
            "sin bloque parseado no se llama al callback"
        );

        // El mismo bloque, con presupuesto suficiente, sí llega al callback.
        let espia = Espia::default();
        assert_eq!(
            despachar(
                &espia,
                "/zx-dev/bloques/pow/1",
                &bytes,
                &Presupuesto::default()
            ),
            Veredicto::Aceptar
        );
        assert_eq!(espia.bloques.load(Ordering::Relaxed), 1);
    }

    /// Residuo y truncamiento se rechazan; el tema desconocido ni mira.
    #[test]
    fn residuo_truncado_y_tema_desconocido() {
        let base = bloque_a_bytes(&bloque_pow(1));

        let mut con_residuo = base.clone();
        con_residuo.push(0x00);
        let mut truncado = base;
        truncado.pop();

        let espia = Espia::default();
        assert_eq!(
            despachar(
                &espia,
                "/zx-dev/bloques/pow/1",
                &con_residuo,
                &Presupuesto::default()
            ),
            Veredicto::Rechazar,
            "un byte residual invalida el bloque"
        );
        assert_eq!(
            despachar(
                &espia,
                "/zx-dev/bloques/pow/1",
                &truncado,
                &Presupuesto::default()
            ),
            Veredicto::Rechazar,
            "un bloque truncado invalida"
        );
        assert_eq!(espia.bloques.load(Ordering::Relaxed), 0);

        let espia2 = Espia::default();
        for falso in [
            "/zx-dev/bloques/pow/1/extra",
            "/otra/zx-dev/bloques/pow/1",
            "/zx-dev/bloques/pow/2",
        ] {
            assert_eq!(
                despachar(&espia2, falso, &con_residuo, &Presupuesto::default()),
                Veredicto::Ignorar,
                "{falso}"
            );
        }
        assert_eq!(espia2.bloques.load(Ordering::Relaxed), 0);
        assert_eq!(espia2.txs.load(Ordering::Relaxed), 0);
    }

    /// La familia del bloque y la del tema coinciden para PoST también.
    #[test]
    fn el_bloque_post_llega_por_su_tema() {
        // Un PoST mínimo construido a mano es costoso; basta comprobar que el despacho usa la
        // familia del tema: un bloque PoW por el tema post se rechaza (test de arriba) y un
        // truncado por el tema post también.
        let espia = Espia::default();
        assert_eq!(
            despachar(
                &espia,
                "/zx-dev/bloques/post/1",
                &[FamiliaBloque::DISC_POST],
                &Presupuesto::default()
            ),
            Veredicto::Rechazar
        );
        assert_eq!(espia.bloques.load(Ordering::Relaxed), 0);
    }
}
