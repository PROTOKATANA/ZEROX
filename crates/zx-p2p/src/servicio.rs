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

use crate::behaviour::{ZxBehaviour, ZxBehaviourEvent};
use crate::entrante::ManejadorEntrante;
use crate::error::{MotivoDesconexion, P2pError};
use crate::mensaje::Peticion;

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
            // El resto de eventos del swarm todavía no se atienden: el sincronizador y el manejo de
            // gossip llegan en la tanda siguiente. Se registran a nivel traza y se descartan, que
            // es mejor que un `todo!()` en un bucle que no puede entrar en pánico.
            otro => {
                tracing::trace!(?otro, "evento de swarm todavía no atendido");
            }
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
                // TODO(P-025): aquí irá el registro de score por IP. Hoy solo se corta.
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
