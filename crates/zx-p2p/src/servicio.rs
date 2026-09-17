//! El bucle de eventos y su handle (SPEC §16).
//!
//! # Por qué un bucle con canales y no un `Arc<Mutex<Swarm>>`
//!
//! Un `Swarm` de libp2p **hay que pollearlo continuamente** — es perezoso como un `Future` y no
//! hace absolutamente nada si nadie lo consulta— y además es `!Sync`, así que no se puede
//! compartir entre tareas. Solo hay una forma sensata: **una tarea lo posee en exclusiva** y todo
//! el mundo habla con ella por canales.
//!
//! Es el patrón de `examples/file-sharing` de rust-libp2p, y el mismo esqueleto que usa lighthouse
//! en producción (`beacon_node/network/src/service.rs`): un `tokio::select!` sobre el `Swarm` y los
//! canales de entrada.
//!
//! # El `Swarm` NO sale de este módulo
//!
//! Nadie fuera ve un tipo de `libp2p::swarm`. Lo que sale son [`EventoRed`], que son tipos nuestros.
//! Es lo que hace lighthouse envolviendo el `Swarm` en su propio `Network<T>` que expone
//! `next_event() -> NetworkEvent`, y la razón es que si los tipos de libp2p se filtran, actualizar
//! libp2p pasa de ser un cambio de un crate a un cambio de todo el nodo.
//!
//! # El error de un peer NO es un error del nodo
//!
//! Regla dura de este bucle: **nada que venga de un peer puede propagar un `Err` fuera del
//! `select!`**. Se registra, se desconecta a quien haga falta, y se sigue. Solo los fallos de la
//! propia infraestructura —no se puede escuchar en el puerto, el canal de comandos murió— terminan
//! el bucle, y aun esos salen por un canal, nunca por un `panic!`.
//!
//! Zebra dedica ~100 líneas de comentarios de corrección a esta distinción, y su `PeerSet` solo
//! devuelve `Err` cuando **no queda ningún peer viable**, nunca cuando falla uno.

use std::sync::Arc;

use libp2p::swarm::SwarmEvent;
use libp2p::{Multiaddr, PeerId, Swarm};
use tokio::sync::{mpsc, oneshot};

use libp2p::{gossipsub, request_response};

use crate::behaviour::{ZxBehaviour, ZxBehaviourEvent};
use crate::entrante::{ManejadorEntrante, Veredicto};
use crate::error::{MotivoDesconexion, P2pError};
use crate::mensaje::{Peticion, Respuesta};

/// Capacidad del canal de comandos.
///
/// **Nunca cero.** Un canal de capacidad cero es un *rendezvous*: el que envía se bloquea hasta que
/// el bucle recoge. Y si el bucle está bloqueado enviando un evento que nadie consume, deja de
/// pollear el `Swarm` — y **la red entera se para**. Es el footgun del ejemplo de libp2p, que usa
/// `mpsc::channel(0)` por brevedad.
pub const CAPACIDAD_COMANDOS: usize = 256;

/// Capacidad del canal de eventos hacia el nodo.
pub const CAPACIDAD_EVENTOS: usize = 1024;

/// Lo que se le pide al bucle desde fuera.
#[derive(Debug)]
pub enum Comando {
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
    /// Difundir bytes ya serializados por un tópico.
    Difundir {
        /// Tópico.
        topico: String,
        /// Contenido.
        datos: Vec<u8>,
    },
    /// Cortar con un peer, y por qué (C-NET-05).
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
    /// La respuesta va en `Box` porque `Respuesta::Bloques` puede ser grande, y un enum cuyo tamaño
    /// lo fija su variante mayor haría que **cada** evento de red ocupara eso.
    Respuesta {
        /// Quién respondió.
        peer: PeerId,
        /// Identificador de la petición que se contesta.
        peticion: u64,
        /// Lo que respondió.
        respuesta: Box<Respuesta>,
    },
    /// Una petición no llegó a completarse. **No puntúa** (C-NET-05).
    PeticionFallida {
        /// A quién se le había pedido.
        peer: PeerId,
    },
}

/// El handle con el que el resto del nodo habla con la red.
///
/// `Clone`, `Send` y `Sync` porque solo lleva un `Sender`. El `Swarm` se queda en su tarea.
#[derive(Clone, Debug)]
pub struct ManejoRed {
    comandos: mpsc::Sender<Comando>,
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

    /// Difunde bytes por un tópico.
    ///
    /// # Errores
    /// [`P2pError::Transporte`] si el bucle ya no está.
    pub async fn difundir(&self, topico: String, datos: Vec<u8>) -> Result<(), P2pError> {
        self.enviar(Comando::Difundir { topico, datos }).await
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

/// Prepara las tres piezas. **No arranca nada**: quien decide dónde corre el bucle es `zx-node`.
///
/// Devolver el bucle sin ejecutarlo, en vez de hacer el `tokio::spawn` aquí dentro, es deliberado:
/// quien lo lanza se queda con el `JoinHandle`, y **soltar un `JoinHandle` en tokio no cancela la
/// tarea** — solo pierdes la forma de pararla. Un crate que spawnea por su cuenta deja tareas
/// huérfanas que sobreviven al nodo.
pub fn arrancar<M: ManejadorEntrante>(swarm: Swarm<ZxBehaviour>, manejador: Arc<M>) -> Piezas<M> {
    let (tx_cmd, rx_cmd) = mpsc::channel(CAPACIDAD_COMANDOS);
    let (tx_ev, rx_ev) = mpsc::channel(CAPACIDAD_EVENTOS);

    Piezas {
        manejo: ManejoRed { comandos: tx_cmd },
        eventos: rx_ev,
        bucle: BucleRed {
            swarm,
            comandos: rx_cmd,
            eventos: tx_ev,
            manejador,
        },
    }
}

impl<M: ManejadorEntrante> BucleRed<M> {
    /// Corre hasta que se sueltan todos los [`ManejoRed`].
    ///
    /// Termina **de forma cooperativa**: cuando el canal de comandos se cierra —porque nadie
    /// conserva un handle—, el bucle sale tras procesar lo que tuviera entre manos. No hace falta
    /// abortarlo desde fuera para este caso, y eso evita cortar el `Swarm` a mitad de una escritura.
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
    ///
    /// **Ningún camino de aquí puede propagar un error hacia arriba.** Lo que va mal con un peer se
    /// registra y se sigue.
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
    ///
    /// **Servir una petición es trabajo del manejador, no del bucle.** El bucle solo traduce entre
    /// los tipos de libp2p y los nuestros.
    fn atender_sync(&mut self, e: request_response::Event<Peticion, Respuesta>) {
        match e {
            request_response::Event::Message { peer, message, .. } => match message {
                request_response::Message::Request {
                    request, channel, ..
                } => {
                    let respuesta = self.servir(&request);
                    // Que el canal esté cerrado significa que el peer se fue mientras
                    // preparábamos la respuesta. Es normal, no es culpa de nadie.
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
            // Un peer que no responde o falla **no puntúa** (C-NET-05): puede ir lento, puede
            // haberse caído, puede hablar otra versión. Nada de eso es violación de consenso.
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
            Peticion::Cabeceras { locator, hasta } => {
                let cs = self.manejador.cabeceras_desde(locator, *hasta);
                Respuesta::Cabeceras(recortar(cs, crate::limites::MAX_CABECERAS_POR_RESPUESTA))
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
            Peticion::FaltantesCompactas { bloque, indices } => {
                let ts = self.manejador.transacciones_compactas(bloque, indices);
                if ts.is_empty() {
                    Respuesta::NoDisponible
                } else {
                    Respuesta::FaltantesCompactas {
                        bloque: *bloque,
                        transacciones: ts,
                    }
                }
            }
        }
    }

    /// Atiende la difusión. **C-NET-12: validar antes de retransmitir.**
    fn atender_gossip(&mut self, e: gossipsub::Event) {
        let gossipsub::Event::Message {
            propagation_source,
            message_id,
            message,
        } = e
        else {
            return;
        };

        let veredicto = self.juzgar(&message);

        let acceptance = match veredicto {
            Veredicto::Aceptar => gossipsub::MessageAcceptance::Accept,
            Veredicto::Ignorar => gossipsub::MessageAcceptance::Ignore,
            Veredicto::Rechazar => gossipsub::MessageAcceptance::Reject,
        };

        // Sin esta llamada el mensaje se queda **pendiente para siempre** en la cola de validación:
        // ni se reenvía ni se descarta. Es la consecuencia de haber activado `validate_messages`,
        // y olvidarla convierte una defensa en una fuga de memoria.
        // Devuelve `bool`, no `Result`: `false` significa que el mensaje ya no estaba en la caché
        // de validación —normalmente porque expiró—. No es un error, pero sí una señal de que
        // estamos tardando demasiado en juzgar.
        if !self
            .swarm
            .behaviour_mut()
            .gossipsub
            .report_message_validation_result(&message_id, &propagation_source, acceptance)
        {
            tracing::debug!(
                ?veredicto,
                "el mensaje ya no estaba en la caché de validación"
            );
        }
    }

    /// Decide qué es el mensaje y se lo pasa al manejador.
    ///
    /// Un mensaje que no decodifica es `Rechazar`: no es ambigüedad de *timing* como un huérfano,
    /// es basura. Pero ojo — `Rechazar` penaliza al que **lo propagó**, no al que lo creó, así que
    /// se reserva para lo indiscutiblemente inválido.
    fn juzgar(&self, m: &gossipsub::Message) -> Veredicto {
        let topico = m.topic.as_str();
        if topico.contains("/blocks/") {
            match crate::codec::respuesta_desde_bytes(&m.data) {
                Ok(Respuesta::Bloques(bs)) => bs
                    .first()
                    .map_or(Veredicto::Rechazar, |b| self.manejador.bloque_difundido(b)),
                _ => Veredicto::Rechazar,
            }
        } else if topico.contains("/txs/") {
            self.manejador.tx_difundida(&m.data)
        } else {
            // Un tópico al que no estamos suscritos no debería llegar. Ignorar sin penalizar:
            // puede ser una versión nueva del protocolo, no un ataque.
            Veredicto::Ignorar
        }
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
                // Si el que preguntó ya no está, da igual: no es un fallo del nodo.
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
            Comando::Difundir { topico, datos } => {
                let t = libp2p::gossipsub::IdentTopic::new(topico);
                // Que una publicación falle —sin peers en la malla todavía, por ejemplo— es normal
                // y no es motivo de nada. Se registra y se sigue.
                if let Err(e) = self.swarm.behaviour_mut().gossipsub.publish(t, datos) {
                    tracing::debug!(%e, "no se pudo difundir");
                }
            }
            Comando::Desconectar { peer, motivo } => {
                tracing::debug!(%peer, ?motivo, puntua = motivo.puntua(), "desconectando");

                // C-NET-05 + C-NET-20 · solo una violación de consenso puntúa, y puntúa contra el
                // **prefijo de red**, no contra el `PeerId` — que es gratis de renovar.
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
    /// `try_send` y no `send().await` a propósito, por dos razones que resultaron ser la misma:
    ///
    /// 1. Si el consumidor de eventos se retrasa, esperar aquí dejaría de pollear el `Swarm` y
    ///    **pararía la red entera**. Perder una notificación es malo; parar la red es peor.
    /// 2. Y además **no compila de la otra forma**: `Swarm` es `!Sync`, así que mantener `&self`
    ///    vivo a través de un `await` haría que el futuro del bucle dejara de ser `Send` y
    ///    `tokio::spawn` lo rechazaría. El compilador llegó a la misma conclusión por su cuenta.
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

/// Recorta una lista al límite del protocolo.
///
/// Se aplica **aquí** y no se confía en que el manejador lo respete: el límite es de transporte, y
/// el transporte es responsabilidad de este crate. Un manejador que devolviera de más produciría
/// una respuesta que el otro extremo rechaza por tamaño — un fallo difícil de rastrear hasta aquí.
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
///
/// El identificador de libp2p no debe asomar fuera —ver la nota de módulo—, pero el nodo necesita
/// **algo** para correlacionar su petición con la respuesta. Un `u64` opaco basta.
fn request_id_a_u64(id: request_response::OutboundRequestId) -> u64 {
    // `OutboundRequestId` no expone su valor; su `Display` sí. Es feo, y la alternativa —filtrar el
    // tipo de libp2p hacia `zx-node`— sería peor.
    id.to_string().parse().unwrap_or(0)
}
