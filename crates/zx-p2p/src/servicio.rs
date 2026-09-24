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
use crate::config::ParametrosRed;
use crate::entrante::{ManejadorEntrante, Veredicto};
use crate::error::{MotivoDesconexion, P2pError};
use crate::mensaje::{Peticion, Respuesta};
use crate::presupuesto::Presupuesto;
use crate::rele_compacto::{AnuncioCompacto, ReleError};

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
///
/// Es `pub(crate)` y no `pub`: el único `Sender<Comando>` vive dentro de [`ManejoRed`], que no lo
/// expone, así que fuera del crate no hay forma de emitir un comando —ni, por tanto, de elegir un
/// tema de difusión—. La visibilidad de crate la necesitan los métodos de `ManejoRed`, pero ningún
/// llamante externo puede nombrar el enum.
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
    ///
    /// **Solo lo emiten los métodos de [`ManejoRed`]** —[`ManejoRed::difundir_anuncio`] y
    /// [`ManejoRed::difundir_tx`]—, y `BucleRed` vuelve a comprobarlo contra los dos temas
    /// configurados antes de publicar (C-NET-25). El `Sender` de comandos no se expone fuera de
    /// `ManejoRed`, así que no hay una vía pública para fabricar esta variante.
    Difundir {
        /// Tópico, que debe ser uno de los dos de [`ParametrosRed`].
        topico: String,
        /// Contenido ya serializado.
        datos: Vec<u8>,
        /// Por dónde vuelve el resultado **local** del intento de publicación.
        ///
        /// `Ok(())` acredita solo que `gossipsub.publish` aceptó el mensaje **en este nodo**: ni
        /// entrega, ni retransmisión, ni validez DAG. `Err` es que el tema no es uno de los dos
        /// configurados o que gossipsub rechazó la publicación local. Nunca se deja sin responder:
        /// un tema rechazado por defensa en profundidad responde `Err`, no cuelga al llamante.
        respuesta: oneshot::Sender<Result<(), P2pError>>,
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
    /// Un peer se suscribió (`true`) o desuscribió (`false`) de un tema de gossipsub.
    ///
    /// # Por qué el nodo lo ve
    ///
    /// La malla no se forma en el instante de la conexión: hasta que el `SUBSCRIBE` de un peer no
    /// llega, `gossipsub.publish` devuelve `NoPeersSubscribedToTopic` **y mete el mensaje en su
    /// caché de deduplicación**, así que reintentarlo después da `Duplicate` en vez de entregarlo.
    /// Es decir, publicar «a ciegas» pierde el anuncio. Este evento es la señal de que el otro lado
    /// ya está en la malla, y quien publica puede esperarla en vez de dormir a ciegas.
    ///
    /// No es un evento de consenso: es transporte, y por eso viaja por [`EventoRed`] sin tocar
    /// [`Veredicto`].
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
///
/// `Clone`, `Send` y `Sync` porque solo lleva un `Sender` y los parámetros de red (que son `Copy`).
/// El `Swarm` se queda en su tarea.
///
/// Lleva [`ParametrosRed`] para que las APIs de difusión **no acepten un tema libre**: el canal de
/// cada mensaje es una decisión del tipo, no de quien llama (C-NET-25).
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

    /// Difundir **un anuncio compacto** por el canal que le corresponde (C-NET-25/C-NET-26).
    ///
    /// # Qué fija esta API, y qué NO
    ///
    /// La versión anterior exponía `difundir(topico, datos)` con un `String` libre. Eso permitía
    /// publicar un bloque completo por `/blocks/1` —lo que C-NET-25 prohíbe— o meter bytes en el
    /// canal equivocado, y el compilador no decía nada. Aquí el tema **no es un parámetro**: sale de
    /// [`ParametrosRed::topic_bloques`], que es la misma fuente que usa la suscripción.
    ///
    /// Pero fijar **formato y tema no certifica validez**. Un [`AnuncioCompacto`] se puede construir
    /// sin validación —este mismo módulo lo hace en sus tests con sello cero y PoAS por defecto—, así
    /// que la API **no** impide publicar un anuncio que nunca fue admitido en el DAG. El productor
    /// futuro (`zx-node`) MUST llamar a este método **solo después** de la admisión del DAG; la
    /// recepción mantiene `Ignorar` mientras esa validación no exista (C-NET-12).
    ///
    /// Serializa con [`AnuncioCompacto::a_bytes`], el codec del relé.
    ///
    /// # Errores
    /// - [`P2pError::Transporte`] si el canal de comandos está cerrado —el bucle de red ya no
    ///   existe— o si `gossipsub.publish` **rechaza el envío local** (por ejemplo,
    ///   `NoPeersSubscribedToTopic` porque nadie está en la malla todavía, o `Duplicate` porque
    ///   esos mismos bytes ya se publicaron o recibieron).
    ///
    /// `Ok(())` acredita **solo aceptación local por gossipsub**: no es entrega, no es
    /// retransmisión y no es validez DAG. Quien necesite saber que el otro extremo está suscrito
    /// espera al evento [`EventoRed::Suscripcion`].
    pub async fn difundir_anuncio(&self, anuncio: &AnuncioCompacto) -> Result<(), P2pError> {
        let (tx, rx) = oneshot::channel();
        self.enviar(Comando::Difundir {
            topico: self.parametros.topic_bloques().to_owned(),
            datos: anuncio.a_bytes(),
            respuesta: tx,
        })
        .await?;
        rx.await
            .map_err(|_| P2pError::Transporte("el bucle de red murió antes de responder"))?
    }

    /// Difundir una **transacción** por `/txs/1` (C-NET-25).
    ///
    /// API separada de [`Self::difundir_anuncio`] a propósito: cada canal lleva su contenido, y el
    /// tema de cada uno sale de los parámetros de red, no del llamante. Igual que aquella, fija
    /// **formato y tema**, no validez: quien produzca una transacción MUST difundirla solo tras la
    /// admisión que corresponda.
    ///
    /// # Errores
    /// - [`P2pError::Transporte`] si el canal de comandos está cerrado —el bucle ya no existe— o si
    ///   `gossipsub.publish` **rechaza el envío local**.
    ///
    /// `Ok(())` acredita **solo aceptación local por gossipsub**, nunca entrega.
    pub async fn difundir_tx(&self, tx_serializada: Vec<u8>) -> Result<(), P2pError> {
        let (tx, rx) = oneshot::channel();
        self.enviar(Comando::Difundir {
            topico: self.parametros.topic_txs().to_owned(),
            datos: tx_serializada,
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
    /// parseo de un anuncio compacto salen del mismo techo. Se guarda aquí para **no** estrenar un
    /// contador por mensaje —que es lo que hacía `Presupuesto::default()` dentro de `juzgar` y no
    /// acreditaba ningún techo agregado—.
    ///
    /// ⚠️ Compartir el contador **no** cierra C-NET-21: la reserva del parseo se libera antes de
    /// retener el anuncio o llamar al callback, así que la memoria que el nodo **retiene** después
    /// del parseo sigue fuera de este techo. Tampoco existe aquí la cola acotada de anuncios sin
    /// padres que la regla hermana exige: retener un huérfano y reevaluarlo cuando lleguen sus
    /// dependencias es trabajo de `zx-node`, todavía pendiente.
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
///
/// `presupuesto` es el contador de C-NET-21. `zx-node` debe crear **una sola instancia** y pasar
/// clones de la misma tanto a [`ZxBehaviour::con_presupuesto`] —el códec de `sync`— como aquí:
/// compartir el contador es lo que hace que el techo sea agregado y no por mensaje.
///
/// # Por qué hay dos constructores
///
/// [`arrancar`] conserva la firma histórica de dos argumentos para no romper a los llamantes que
/// no necesitan controlar el presupuesto —varios arneses de `zx-node`—. Este es el que usa la ruta
/// de producción: la única forma de que el bucle de gossip y el códec compartan contador es que
/// quien monta el `Swarm` entregue el mismo clon a los dos.
pub fn arrancar_con<M: ManejadorEntrante>(
    swarm: Swarm<ZxBehaviour>,
    manejador: Arc<M>,
    presupuesto: Presupuesto,
) -> Piezas<M> {
    let (tx_cmd, rx_cmd) = mpsc::channel(CAPACIDAD_COMANDOS);
    let (tx_ev, rx_ev) = mpsc::channel(CAPACIDAD_EVENTOS);

    // El handle necesita los parámetros de red para no aceptar un tema libre en la difusión. Salen
    // del behaviour, que es la misma fuente que usó la suscripción: no se pueden desincronizar.
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
/// Devolver el bucle sin ejecutarlo, en vez de hacer el `tokio::spawn` aquí dentro, es deliberado:
/// quien lo lanza se queda con el `JoinHandle`, y **soltar un `JoinHandle` en tokio no cancela la
/// tarea** — solo pierdes la forma de pararla. Un crate que spawnea por su cuenta deja tareas
/// huérfanas que sobreviven al nodo.
///
/// ⚠️ El presupuesto que crea aquí es **solo para este bucle**: no lo comparte con el códec. La ruta
/// de producción debe usar [`arrancar_con`] con la misma instancia que
/// [`ZxBehaviour::con_presupuesto`]; este constructor sobrevive para los arneses que no controlan el
/// contador y **no** acredita el techo agregado de C-NET-21.
pub fn arrancar<M: ManejadorEntrante>(swarm: Swarm<ZxBehaviour>, manejador: Arc<M>) -> Piezas<M> {
    arrancar_con(swarm, manejador, Presupuesto::default())
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
        match e {
            gossipsub::Event::Message {
                propagation_source,
                message_id,
                message,
            } => self.juzgar_y_reportar(&propagation_source, &message_id, &message),
            // La malla de gossipsub cambia: se cuenta hacia fuera para que quien publique pueda
            // esperar a que el otro extremo esté suscrito. Publicar antes no entrega el mensaje y
            // además lo envenena en la caché de deduplicación.
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
                // C-NET-05 · lentitud no es violación de consenso: se registra, no se puntúa.
                tracing::debug!(%peer_id, ?failed_messages, "peer lento en gossipsub");
            }
        }
    }

    /// Evalúa un mensaje de gossip y reporta el resultado a gossipsub.
    ///
    /// **C-NET-12.** Separado de [`Self::atender_gossip`] para que el `match` de eventos no mezcle
    /// la clasificación con las variantes de malla.
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
        // ni se reenvía ni se descarta. Es la consecuencia de haber activado `validate_messages`,
        // y olvidarla convierte una defensa en una fuga de memoria.
        // Devuelve `bool`, no `Result`: `false` significa que el mensaje ya no estaba en la caché
        // de validación —normalmente porque expiró—. No es un error, pero sí una señal de que
        // estamos tardando demasiado en juzgar.
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
    ///
    /// **C-NET-25 · la clasificación es por igualdad exacta.** Cada canal lleva un contenido
    /// distinto y un mensaje que llegue por el que no le corresponde MUST descartarse; nada de
    /// prefijos ni subcadenas. La versión anterior usaba `topico.contains("/blocks/")`, que daba por
    /// buenos `/zerox/blocks/2/extra` y `/zerox/blocks/20`. Un tema desconocido se ignora **sin
    /// decodificar y sin llamar al manejador**.
    ///
    /// Un mensaje que no decodifica es `Rechazar`: no es ambigüedad de *timing* como un huérfano,
    /// es basura. Pero ojo — `Rechazar` penaliza al que **lo propagó**, no al que lo creó, así que
    /// se reserva para lo indiscutiblemente inválido. El éxito del parseo **no** es validación: por
    /// C-NET-12 el veredicto de un anuncio compacto lo decide el manejador, no el codec.
    fn juzgar(&self, m: &gossipsub::Message) -> Veredicto {
        // C-NET-21 · se reserva del contador **compartido** del bucle, el mismo que usa el códec de
        // `sync`. Antes se estrenaba un `Presupuesto::default()` por mensaje: misma estructura, pero
        // el techo dejaba de ser agregado —cada mensaje empezaba de cero—. Con la instancia única de
        // `BucleRed`, ambos caminos compiten por el mismo techo.
        //
        // ⚠️ Esto **no** cierra C-NET-21: `AnuncioCompacto::desde_bytes` libera su reserva antes de
        // devolver el anuncio, así que la memoria que se **retiene** después —el anuncio parseado, la
        // cola acotada de anuncios sin padres que la regla hermana exige, el callback— no está
        // contabilizada. Tampoco existe esa cola.
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
            Comando::Difundir {
                topico,
                datos,
                respuesta,
            } => {
                // C-NET-25 · defensa en profundidad. `Comando` es `pub(crate)` y su único emisor es
                // `ManejoRed`, cuyo `Sender` no se expone; aun así esta comprobación impide publicar
                // por `/blocks/1` o por un tema de la otra red si alguna vez se añade un camino
                // interno. Los dos temas permitidos salen del behaviour, que es la misma fuente que
                // la suscripción.
                let permitidos = [
                    self.swarm.behaviour().parametros_de_red().topic_bloques(),
                    self.swarm.behaviour().parametros_de_red().topic_txs(),
                ];
                if !permitidos.contains(&topico.as_str()) {
                    tracing::warn!(
                        %topico,
                        "difusión rechazada: el tema no es uno de los dos configurados (C-NET-25)"
                    );
                    // Nunca se deja colgado al llamante: un tema rechazado responde `Err`.
                    let _ = respuesta.send(Err(P2pError::Transporte(
                        "tema de difusión fuera de los dos configurados (C-NET-25)",
                    )));
                    return;
                }

                let t = libp2p::gossipsub::IdentTopic::new(topico);
                // El resultado **local** de `publish` vuelve a quien encoló el comando. `Ok` solo
                // acredita aceptación local por gossipsub; no es entrega ni validez DAG. Antes este
                // fallo se silenciaba y una prueba negativa podía pasar con el anuncio sin salir.
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

/// A qué canal de difusión pertenece un tema, por **igualdad exacta**.
///
/// C-NET-25 asigna a cada canal un contenido distinto y exige descartar un mensaje que llegue por
/// el canal que no le corresponde. `contains("/blocks/")` —lo que había— clasificaba como bloques
/// `/zerox/blocks/2/extra`, `/otra/zerox/blocks/2` y `/zerox/blocks/20`, y el primero habría ido a
/// un decodificador que no entiende sus bytes.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
enum TemaDifusion {
    /// `/zerox[/testnet]/blocks/1`: bloque completo de la ruta lineal **todavía activa**.
    BloqueLineal,
    /// `/zerox[/testnet]/blocks/2`: **solo** anuncio compacto (C-NET-25, C-NET-26).
    AnuncioCompacto,
    /// `/zerox[/testnet]/txs/1`: transacción difundida.
    Transaccion,
    /// Cualquier otro tema.
    Desconocido,
}

/// Clasifica un tema de difusión por igualdad exacta, nunca por prefijo ni subcadena.
fn clasificar_tema(topico: &str) -> TemaDifusion {
    match topico {
        "/zerox/blocks/1" | "/zerox-testnet/blocks/1" => TemaDifusion::BloqueLineal,
        "/zerox/blocks/2" | "/zerox-testnet/blocks/2" => TemaDifusion::AnuncioCompacto,
        "/zerox/txs/1" | "/zerox-testnet/txs/1" => TemaDifusion::Transaccion,
        _ => TemaDifusion::Desconocido,
    }
}

/// Decide el veredicto de un mensaje de difusión a partir de su tema y sus bytes.
///
/// Es una función libre —no un método de [`BucleRed`]— para poder probar el despacho **sin**
/// construir un `Swarm`: montar un `Swarm` entero solo para ejercitar un `match` probaría libp2p,
/// no este crate. [`BucleRed::juzgar`] es su único llamante de producción.
///
/// El `presupuesto` se **inyecta** en vez de crearse dentro: es lo que permite a un test forzar una
/// reserva fallida con `Presupuesto::nuevo(0)` y comprobar que el agotamiento local no penaliza. El
/// techo de C-NET-21 es **agregado**, de modo que en producción la instancia compartida es la que
/// debe llegar aquí; un `default` recién creado por mensaje no lo acredita.
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
    match clasificar_tema(topico) {
        // El bloque completo de la ruta lineal sigue por su camino de siempre.
        TemaDifusion::BloqueLineal => match crate::codec::respuesta_desde_bytes(datos) {
            Ok(Respuesta::Bloques(bs)) => bs
                .first()
                .map_or(Veredicto::Rechazar, |b| manejador.bloque_difundido(b)),
            _ => Veredicto::Rechazar,
        },
        // La transacción se pasa cruda: su validación es del manejador.
        TemaDifusion::Transaccion => manejador.tx_difundida(datos),
        TemaDifusion::AnuncioCompacto => {
            // C-NET-26 · el relé compacto es obligatorio, así que el transporte sabe leer el
            // anuncio. Lo que `desde_bytes` **no** certifica es contenido ni padres: solo
            // comprueba formato, presupuesto y que no sobre ni falte un byte.
            //
            // C-NET-12 · validar antes de retransmitir. El veredicto no puede salir del parseo: lo
            // decide `anuncio_compacto`, cuyo default es `Ignorar` mientras `zx-node` no valide el
            // DAG causal.
            //
            // Pero no todo fallo del codec es culpa del par que propagó el mensaje. Agotar el
            // presupuesto es un recurso **local** de este nodo (C-NET-21): el mismo anuncio, con
            // presupuesto, se juzgaría con normalidad. Penalizarlo castigaría a un par honesto por
            // nuestra falta de memoria, así que es `Ignorar` (C-NET-05) y **no** `Rechazar`. Un
            // fallo de formato o un byte residual sí es basura indiscutible y sí penaliza.
            //
            // Nótese que esto **no** es el presupuesto de CPU de C-NET-33, que gobierna la
            // verificación PoT de flujo ajeno: aquí se habla solo del techo de bytes en vuelo.
            // `ReleError::Presupuesto` **no** llega al callback: sin anuncio parseado no hay nada
            // que pasarle al manejador.
            match AnuncioCompacto::desde_bytes(datos, presupuesto) {
                Ok((anuncio, [])) => manejador.anuncio_compacto(&anuncio),
                Err(ReleError::Presupuesto) => Veredicto::Ignorar,
                _ => Veredicto::Rechazar,
            }
        }
        TemaDifusion::Desconocido => Veredicto::Ignorar,
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

#[cfg(test)]
#[expect(clippy::unwrap_used, reason = "los tests fallan con panic por diseño")]
mod tests {
    use super::{TemaDifusion, clasificar_tema, despachar};
    use crate::codec::respuesta_a_bytes;
    use crate::entrante::{ManejadorEntrante, Veredicto};
    use crate::mensaje::{BloqueRed, Estado, Respuesta};
    use crate::presupuesto::Presupuesto;
    use crate::rele_compacto::AnuncioCompacto;
    use std::sync::atomic::{AtomicUsize, Ordering};
    use zx_core::Amount;
    use zx_core::digest::{BlockHash, BodyCommitment, Digest, MerkleRoot, TxId};
    use zx_core::firma::ClavePublica;
    use zx_core::preimage::block::BlockHeader;
    use zx_core::preimage::dag::{DagBlockHeader, PadresDag, SolucionPoas};
    use zx_core::tx::{Lock, OutPoint, Tx, TxIn, TxOut};

    /// Manejador espía: cuenta cada callback y **no valida nada**.
    ///
    /// Devuelve `Ignorar` a los anuncios, que es lo que `zx-node` puede devolver hoy —sin validación
    /// DAG causal—, y lo que el test comprueba que nunca se convierte en `Aceptar` por el mero
    /// parseo. El `Aceptar` de bloque y tx es solo para verificar que su callback se alcanza.
    #[derive(Default)]
    struct Espia {
        bloques: AtomicUsize,
        txs: AtomicUsize,
        anuncios: AtomicUsize,
    }

    impl ManejadorEntrante for Espia {
        fn estado(&self) -> Estado {
            Estado {
                genesis: BlockHash::from_digest(Digest::from_bytes([0; 32])),
                tip: BlockHash::from_digest(Digest::from_bytes([1; 32])),
                altura: 0,
                trabajo: [0; 32],
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

        fn anuncio_compacto(&self, _: &AnuncioCompacto) -> Veredicto {
            self.anuncios.fetch_add(1, Ordering::Relaxed);
            // Sin validación DAG causal no se acepta ni se rechaza: se ignora.
            Veredicto::Ignorar
        }

        fn cabeceras_desde(&self, _: &[BlockHash], _: Option<BlockHash>) -> Vec<BlockHeader> {
            Vec::new()
        }

        fn bloques_por_hash(&self, _: &[BlockHash]) -> Vec<BloqueRed> {
            Vec::new()
        }
    }

    /// Implementa solo lo obligatorio para ejercitar el **default** de `anuncio_compacto`.
    struct Minimo;

    impl ManejadorEntrante for Minimo {
        fn estado(&self) -> Estado {
            Espia::default().estado()
        }

        fn bloque_difundido(&self, _: &BloqueRed) -> Veredicto {
            Veredicto::Rechazar
        }

        fn tx_difundida(&self, _: &[u8]) -> Veredicto {
            Veredicto::Rechazar
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
        }
    }

    /// Un anuncio compacto real, serializable con `a_bytes`.
    fn anuncio() -> AnuncioCompacto {
        let cabecera = DagBlockHeader {
            consensus_branch_id: 0xc478_80ea,
            merkle_root: MerkleRoot::from_digest(Digest::from_bytes([0x33; 32])),
            timestamp: 1_788_480_000,
            height: 1,
            slot: 1,
            pot_output: [0; 16],
            rango_solucion: 1,
            sol: SolucionPoas::default(),
            body_commitment: BodyCommitment::from_digest(Digest::from_bytes([0x44; 32])),
            padres: PadresDag::nuevo(BlockHash::from_digest(Digest::from_bytes([0x55; 32])), &[])
                .unwrap(),
            sello: [0; 64],
        };
        AnuncioCompacto::nuevo(
            cabecera,
            7,
            tx_llave(0x11),
            vec![vec![0x66; 64]],
            vec![[0x77; 6]],
        )
        .unwrap()
    }

    /// Bytes de una `Respuesta::Bloques` lineal, para comprobar que no se confunde con un anuncio.
    fn respuesta_lineal() -> Vec<u8> {
        let cabecera = BlockHeader {
            consensus_branch_id: 0xc478_80ea,
            prev_hash: BlockHash::from_digest(Digest::from_bytes([0x01; 32])),
            merkle_root: MerkleRoot::from_digest(Digest::from_bytes([0x02; 32])),
            timestamp: 1_788_480_000,
            bits: 0x1c07_fff8,
            nonce: 1,
            height: 1,
        };
        let bloque = BloqueRed {
            cabecera,
            txs: vec![tx_llave(0x03)],
            testigos: vec![vec![vec![0xAA; 64]]],
        };
        respuesta_a_bytes(&Respuesta::Bloques(vec![bloque]))
    }

    /// **La tabla de los seis temas exactos y sus falsos positivos.**
    ///
    /// El `contains("/blocks/")` anterior habría clasificado los cuatro falsos como bloques.
    #[test]
    fn la_clasificacion_es_exacta() {
        for (tema, esperado) in [
            ("/zerox/blocks/1", TemaDifusion::BloqueLineal),
            ("/zerox-testnet/blocks/1", TemaDifusion::BloqueLineal),
            ("/zerox/blocks/2", TemaDifusion::AnuncioCompacto),
            ("/zerox-testnet/blocks/2", TemaDifusion::AnuncioCompacto),
            ("/zerox/txs/1", TemaDifusion::Transaccion),
            ("/zerox-testnet/txs/1", TemaDifusion::Transaccion),
        ] {
            assert_eq!(clasificar_tema(tema), esperado, "{tema}");
        }

        for falso in [
            "/zerox/blocks/2/extra",
            "/otra/zerox/blocks/2",
            "/zerox/blocks/20",
            "/zerox/txs/2",
        ] {
            assert_eq!(
                clasificar_tema(falso),
                TemaDifusion::Desconocido,
                "{falso} no es ninguno de los seis temas"
            );
        }
    }

    /// Un anuncio de fixture llega **una sola vez** al callback compacto y no se acepta.
    #[test]
    fn el_anuncio_bien_formado_llega_una_vez_y_no_se_acepta() {
        let bytes = anuncio().a_bytes();
        for tema in ["/zerox/blocks/2", "/zerox-testnet/blocks/2"] {
            let espia = Espia::default();
            let v = despachar(&espia, tema, &bytes, &Presupuesto::default());

            assert_eq!(espia.anuncios.load(Ordering::Relaxed), 1, "{tema}");
            assert_eq!(
                v,
                Veredicto::Ignorar,
                "{tema}: sin validación, no se acepta"
            );
            assert_ne!(v, Veredicto::Aceptar, "{tema}: el parseo no es validación");
            assert_ne!(
                v,
                Veredicto::Rechazar,
                "{tema}: un anuncio bien formado no penaliza"
            );
        }
    }

    /// **El presupuesto agotado es un recurso local, no un defecto del par.**
    ///
    /// Con `Presupuesto::nuevo(0)` la reserva del códec falla antes de leer. El mismo anuncio, bien
    /// formado, se juzgaría con normalidad si hubiera memoria, así que penalizar al propagador sería
    /// castigar a un par honesto por nuestra falta de recursos (C-NET-21 + C-NET-05). El veredicto
    /// es `Ignorar`, el callback compacto **no** se invoca y no hay ningún `Rechazar`.
    #[test]
    fn el_presupuesto_agotado_ignora_y_no_penaliza() {
        let bytes = anuncio().a_bytes();

        let espia = Espia::default();
        assert_eq!(
            despachar(&espia, "/zerox/blocks/2", &bytes, &Presupuesto::nuevo(0)),
            Veredicto::Ignorar,
            "sin presupuesto no se puede juzgar: no se penaliza al propagador"
        );
        assert_ne!(
            despachar(&espia, "/zerox/blocks/2", &bytes, &Presupuesto::nuevo(0)),
            Veredicto::Rechazar,
            "agotar el presupuesto no es basura del par"
        );
        assert_eq!(
            espia.anuncios.load(Ordering::Relaxed),
            0,
            "sin anuncio parseado no se llama al callback"
        );

        // El mismo anuncio, con presupuesto suficiente, sí llega al callback.
        let espia = Espia::default();
        assert_eq!(
            despachar(&espia, "/zerox/blocks/2", &bytes, &Presupuesto::default()),
            Veredicto::Ignorar,
            "el manejador espía sigue devolviendo Ignorar"
        );
        assert_eq!(
            espia.anuncios.load(Ordering::Relaxed),
            1,
            "con presupuesto, el anuncio bien formado llega al callback"
        );
    }

    /// El **default** del trait ignora; no acepta ni reenvía, ni rechaza.
    #[test]
    fn el_default_ignora_sin_aceptar_ni_rechazar() {
        let a = anuncio();
        assert_eq!(Minimo.anuncio_compacto(&a), Veredicto::Ignorar);
    }

    /// Residuo, truncamiento y un bloque lineal no pasan por anuncio; el tema desconocido ni mira.
    #[test]
    fn residuo_truncado_y_lineal_no_son_anuncios() {
        let base = anuncio().a_bytes();

        let mut con_residuo = base.clone();
        con_residuo.push(0x00);
        let mut truncado = base;
        truncado.pop();

        let espia = Espia::default();
        assert_eq!(
            despachar(
                &espia,
                "/zerox/blocks/2",
                &con_residuo,
                &Presupuesto::default()
            ),
            Veredicto::Rechazar,
            "un byte residual invalida el anuncio"
        );
        assert_eq!(
            despachar(
                &espia,
                "/zerox/blocks/2",
                &truncado,
                &Presupuesto::default()
            ),
            Veredicto::Rechazar,
            "un anuncio truncado invalida"
        );
        assert_eq!(
            despachar(
                &espia,
                "/zerox/blocks/2",
                &respuesta_lineal(),
                &Presupuesto::default()
            ),
            Veredicto::Rechazar,
            "una Respuesta::Bloques no se interpreta como anuncio"
        );
        assert_eq!(
            espia.anuncios.load(Ordering::Relaxed),
            0,
            "ninguno de los tres llegó al callback compacto"
        );

        // El mismo contenido por un tema desconocido no decodifica ni penaliza.
        let espia2 = Espia::default();
        for falso in [
            "/zerox/blocks/2/extra",
            "/otra/zerox/blocks/2",
            "/zerox/blocks/20",
        ] {
            assert_eq!(
                despachar(&espia2, falso, &con_residuo, &Presupuesto::default()),
                Veredicto::Ignorar,
                "{falso}"
            );
        }
        assert_eq!(espia2.anuncios.load(Ordering::Relaxed), 0);
        assert_eq!(espia2.bloques.load(Ordering::Relaxed), 0);
        assert_eq!(espia2.txs.load(Ordering::Relaxed), 0);
    }

    /// `/blocks/1` sigue invocando el callback lineal y `/txs/1` conserva el suyo.
    #[test]
    fn el_bloque_lineal_y_la_transaccion_conservan_su_callback() {
        for tema in ["/zerox/blocks/1", "/zerox-testnet/blocks/1"] {
            let espia = Espia::default();
            assert_eq!(
                despachar(&espia, tema, &respuesta_lineal(), &Presupuesto::default()),
                Veredicto::Aceptar
            );
            assert_eq!(espia.bloques.load(Ordering::Relaxed), 1, "{tema}");
            assert_eq!(espia.anuncios.load(Ordering::Relaxed), 0, "{tema}");
        }

        let espia = Espia::default();
        assert_eq!(
            despachar(
                &espia,
                "/zerox/txs/1",
                b"bytes de transaccion",
                &Presupuesto::default()
            ),
            Veredicto::Aceptar
        );
        assert_eq!(espia.txs.load(Ordering::Relaxed), 1);
        assert_eq!(espia.bloques.load(Ordering::Relaxed), 0);
    }
}
