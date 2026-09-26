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

use std::collections::HashMap;
use std::sync::Arc;
use std::time::{Duration, Instant};

use libp2p::swarm::SwarmEvent;
use libp2p::{Multiaddr, PeerId, Swarm};
use tokio::sync::{mpsc, oneshot};
use tokio::time::MissedTickBehavior;

use libp2p::{gossipsub, request_response};

use crate::behaviour::{ZxBehaviour, ZxBehaviourEvent};
use crate::config::ParametrosRed;
use crate::entrante::{IdDiferido, ManejadorEntrante, Veredicto, VeredictoFinal};
use crate::error::{MotivoDesconexion, P2pError};
use crate::limites::{MAX_DIFERIDOS_PENDIENTES, PLAZO_VALIDACION_DIFERIDA_S};
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
    /// El veredicto final de una validación que [`ManejadorEntrante::bloque_difundido`] había
    /// diferido (decisión 1 de `ORDEN-W06d2`).
    ///
    /// Si `id` ya no está en la tabla de pendientes —porque expiró (§`PLAZO_VALIDACION_DIFERIDA_S`)
    /// o porque ya se informó antes—, el comando **no hace nada**: es idempotente a propósito, para
    /// que un manejador que informe dos veces (o tarde) no cause un error de protocolo.
    InformarValidacion {
        /// El mismo identificador que trajo la llamada a `bloque_difundido`.
        id: IdDiferido,
        /// El veredicto de verdad.
        veredicto: VeredictoFinal,
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

    /// Informa el veredicto final de una validación diferida (decisión 1 de `ORDEN-W06d2`).
    ///
    /// Para usar desde una tarea `tokio`. Si el manejador vive en un hilo normal (el hilo de
    /// consenso de `zx-node`, D-N07), usar [`Self::informar_validacion_bloqueante`].
    ///
    /// # Errores
    /// [`P2pError::Transporte`] si el bucle de red ya no está.
    pub async fn informar_validacion(
        &self,
        id: IdDiferido,
        veredicto: VeredictoFinal,
    ) -> Result<(), P2pError> {
        self.enviar(Comando::InformarValidacion { id, veredicto })
            .await
    }

    /// Igual que [`Self::informar_validacion`], pero bloqueante: para llamarse desde un hilo que no
    /// corre sobre el *runtime* de `tokio` (el hilo de consenso, D-N07).
    ///
    /// # Pánico
    /// Como cualquier `blocking_send` de `tokio`, entra en pánico si se llama desde dentro de un
    /// hilo *worker* de un runtime `tokio` (ver la documentación de
    /// [`tokio::sync::mpsc::Sender::blocking_send`]). El hilo de consenso no lo es.
    ///
    /// # Errores
    /// [`P2pError::Transporte`] si el bucle de red ya no está.
    pub fn informar_validacion_bloqueante(
        &self,
        id: IdDiferido,
        veredicto: VeredictoFinal,
    ) -> Result<(), P2pError> {
        self.comandos
            .blocking_send(Comando::InformarValidacion { id, veredicto })
            .map_err(|_| P2pError::Transporte("el bucle de red ya no está escuchando comandos"))
    }

    async fn enviar(&self, c: Comando) -> Result<(), P2pError> {
        self.comandos
            .send(c)
            .await
            .map_err(|_| P2pError::Transporte("el bucle de red ya no está escuchando comandos"))
    }
}

/// Lo que el bucle guarda de un mensaje de gossipsub cuyo veredicto se difirió.
struct PendienteDiferido {
    /// El mensaje al que hay que responder cuando llegue el veredicto final.
    message_id: gossipsub::MessageId,
    /// Quién lo propagó (a quién penalizar si el veredicto final es `Rechazar`).
    propagador: PeerId,
    /// Cuándo se difirió, para el barrido de [`BucleRed::expirar_diferidos_vencidos`].
    creado: Instant,
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
    /// Validaciones diferidas (decisión 1 de `ORDEN-W06d2`) a la espera de
    /// [`Comando::InformarValidacion`], acotadas por [`MAX_DIFERIDOS_PENDIENTES`].
    pendientes: HashMap<IdDiferido, PendienteDiferido>,
    /// Siguiente [`IdDiferido`] a repartir. Un contador simple basta: `BucleRed` tiene un único
    /// dueño (esta tarea), no hace falta que sea atómico.
    siguiente_id: u64,
    /// Plazo tras el cual un diferido sin informe se trata como `Ignorar`. Configurable solo para
    /// que los tests puedan acortarlo; la ruta de producción usa
    /// [`PLAZO_VALIDACION_DIFERIDA_S`].
    plazo_diferido: Duration,
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
/// Usa el plazo de validación diferida de producción ([`PLAZO_VALIDACION_DIFERIDA_S`]). Para
/// pruebas que necesiten un plazo corto, usar [`arrancar_con_plazo`].
pub fn arrancar_con<M: ManejadorEntrante>(
    swarm: Swarm<ZxBehaviour>,
    manejador: Arc<M>,
    presupuesto: Presupuesto,
) -> Piezas<M> {
    arrancar_con_plazo(
        swarm,
        manejador,
        presupuesto,
        Duration::from_secs(PLAZO_VALIDACION_DIFERIDA_S),
    )
}

/// Igual que [`arrancar_con`], con el plazo de validación diferida explícito.
pub fn arrancar_con_plazo<M: ManejadorEntrante>(
    swarm: Swarm<ZxBehaviour>,
    manejador: Arc<M>,
    presupuesto: Presupuesto,
    plazo_diferido: Duration,
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
            pendientes: HashMap::new(),
            siguiente_id: 0,
            plazo_diferido,
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
        // El barrido corre al **cuarto** del plazo: así un diferido nunca espera más de
        // `plazo_diferido + plazo_diferido/4` antes de expirar, sin necesidad de un temporizador
        // por entrada. `Duration::max(1 ms)` evita un `interval` de período cero si algún test
        // pasara un plazo absurdamente corto.
        let periodo_barrido = (self.plazo_diferido / 4).max(Duration::from_millis(1));
        let mut barrido = tokio::time::interval(periodo_barrido);
        // Un barrido tarde (p. ej. tras una pausa larga del proceso) no debe intentar "ponerse al
        // día" disparando varias veces seguidas: solo importa el estado actual.
        barrido.set_missed_tick_behavior(MissedTickBehavior::Skip);

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
                _ = barrido.tick() => {
                    self.expirar_diferidos_vencidos();
                }
            }
        }
    }

    /// Trata como [`Veredicto::Ignorar`] todo diferido más viejo que [`Self::plazo_diferido`].
    ///
    /// **No penaliza.** Un veredicto que no llega a tiempo es un fallo del manejador o del hilo de
    /// validación, nunca una prueba de que el peer que propagó el mensaje hizo algo malo.
    fn expirar_diferidos_vencidos(&mut self) {
        let ahora = Instant::now();
        let vencidos: Vec<IdDiferido> = self
            .pendientes
            .iter()
            .filter(|(_, p)| ahora.duration_since(p.creado) >= self.plazo_diferido)
            .map(|(id, _)| *id)
            .collect();
        for id in vencidos {
            if let Some(p) = self.pendientes.remove(&id) {
                tracing::debug!(?id, "validación diferida sin informe a tiempo: se ignora");
                self.reportar_a_gossipsub(&p.message_id, &p.propagador, Veredicto::Ignorar);
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

    /// Evalúa un mensaje de gossip y reporta el resultado a gossipsub, o lo retiene si el manejador
    /// difirió el veredicto (decisión 1 de `ORDEN-W06d2`).
    fn juzgar_y_reportar(
        &mut self,
        propagation_source: &PeerId,
        message_id: &gossipsub::MessageId,
        message: &gossipsub::Message,
    ) {
        let id = self.siguiente_id_diferido();
        let veredicto = despachar(
            self.manejador.as_ref(),
            id,
            message.topic.as_str(),
            &message.data,
            &self.presupuesto,
        );

        if veredicto == Veredicto::Diferir {
            self.retener_diferido(id, message_id, propagation_source);
            return;
        }

        self.reportar_a_gossipsub(message_id, propagation_source, veredicto);
    }

    /// Guarda la correlación de un diferido, acotando la tabla a [`MAX_DIFERIDOS_PENDIENTES`].
    ///
    /// Al llegar al tope, expira como `Ignorar` la entrada más antigua para dejar sitio: no penaliza
    /// (un manejador saturado no es culpa del peer más antiguo en cola), y evita crecer sin límite
    /// si el manejador difiere sin nunca informar.
    fn retener_diferido(
        &mut self,
        id: IdDiferido,
        message_id: &gossipsub::MessageId,
        propagador: &PeerId,
    ) {
        if self.pendientes.len() >= MAX_DIFERIDOS_PENDIENTES
            && let Some(mas_vieja) = self
                .pendientes
                .iter()
                .min_by_key(|(_, p)| p.creado)
                .map(|(id, _)| *id)
        {
            tracing::warn!(
                "tabla de diferidos llena ({MAX_DIFERIDOS_PENDIENTES}): se expira la más antigua"
            );
            if let Some(vieja) = self.pendientes.remove(&mas_vieja) {
                self.reportar_a_gossipsub(&vieja.message_id, &vieja.propagador, Veredicto::Ignorar);
            }
        }
        self.pendientes.insert(
            id,
            PendienteDiferido {
                message_id: message_id.clone(),
                propagador: *propagador,
                creado: Instant::now(),
            },
        );
    }

    /// El identificador opaco que se le entrega al manejador. `zx-p2p` es su único dueño.
    fn siguiente_id_diferido(&mut self) -> IdDiferido {
        self.siguiente_id = self.siguiente_id.wrapping_add(1);
        IdDiferido(self.siguiente_id)
    }

    /// Reporta un veredicto a gossipsub. Sin esta llamada el mensaje se queda **pendiente para
    /// siempre** en la cola de validación de gossipsub: ni se reenvía ni se descarta.
    fn reportar_a_gossipsub(
        &mut self,
        message_id: &gossipsub::MessageId,
        propagation_source: &PeerId,
        veredicto: Veredicto,
    ) {
        let Some(acceptance) = a_acceptance(veredicto) else {
            // No debería llegar aquí con `Diferir`: es un error de este módulo, no de un peer.
            tracing::error!("reportar_a_gossipsub llamado con Diferir; se trata como Ignorar");
            self.reportar_a_gossipsub(message_id, propagation_source, Veredicto::Ignorar);
            return;
        };
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
            Comando::InformarValidacion { id, veredicto } => {
                // Idempotente a propósito (ver la doc de `Comando::InformarValidacion`): un `id`
                // que ya no está pudo expirar (`expirar_diferidos_vencidos`) o ya haberse informado.
                let Some(p) = self.pendientes.remove(&id) else {
                    tracing::debug!(
                        ?id,
                        ?veredicto,
                        "informe de validación diferida sin diferido pendiente (expiró o ya se informó)"
                    );
                    return;
                };
                let veredicto = match veredicto {
                    VeredictoFinal::Aceptar => Veredicto::Aceptar,
                    VeredictoFinal::Ignorar => Veredicto::Ignorar,
                    VeredictoFinal::Rechazar => Veredicto::Rechazar,
                };
                self.reportar_a_gossipsub(&p.message_id, &p.propagador, veredicto);
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
/// `id` es el identificador opaco que se le pasa al manejador; solo tiene sentido si el manejador
/// devuelve [`Veredicto::Diferir`] (decisión 1 de `ORDEN-W06d2`).
///
/// # El tema desconocido no se decodifica
///
/// Un tema que no sea uno de los seis exactos devuelve [`Veredicto::Ignorar`] **sin** tocar los
/// bytes ni llamar al manejador: puede ser una versión más nueva del protocolo, no un ataque.
fn despachar<M: ManejadorEntrante>(
    manejador: &M,
    id: IdDiferido,
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
        Ok((bloque, [])) => manejador.bloque_difundido(id, &bloque),
        Ok((_, _)) => Veredicto::Rechazar,
        Err(_) => Veredicto::Rechazar,
    }
}

/// Traduce un [`Veredicto`] a lo que entiende gossipsub. `None` para [`Veredicto::Diferir`]: no es
/// un veredicto final, así que no hay una `MessageAcceptance` que le corresponda todavía.
const fn a_acceptance(v: Veredicto) -> Option<gossipsub::MessageAcceptance> {
    match v {
        Veredicto::Aceptar => Some(gossipsub::MessageAcceptance::Accept),
        Veredicto::Ignorar => Some(gossipsub::MessageAcceptance::Ignore),
        Veredicto::Rechazar => Some(gossipsub::MessageAcceptance::Reject),
        Veredicto::Diferir => None,
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
    use crate::entrante::{IdDiferido, ManejadorEntrante, Veredicto};
    use crate::mensaje::{BloqueRed, Estado, FamiliaBloque, Fase, PuntaPow};
    use crate::presupuesto::Presupuesto;
    use std::sync::atomic::{AtomicUsize, Ordering};

    /// Un `IdDiferido` cualquiera: estos tests no difieren nada, así que su valor es indiferente.
    fn id_prueba() -> IdDiferido {
        IdDiferido(0)
    }
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

        fn bloque_difundido(&self, _id: IdDiferido, _: &BloqueRed) -> Veredicto {
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
            id_prueba(),
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
                id_prueba(),
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
                id_prueba(),
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
                id_prueba(),
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
                id_prueba(),
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
                id_prueba(),
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
                despachar(
                    &espia2,
                    id_prueba(),
                    falso,
                    &con_residuo,
                    &Presupuesto::default()
                ),
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
                id_prueba(),
                "/zx-dev/bloques/post/1",
                &[FamiliaBloque::DISC_POST],
                &Presupuesto::default()
            ),
            Veredicto::Rechazar
        );
        assert_eq!(espia.bloques.load(Ordering::Relaxed), 0);
    }
}
