//! **El nodo como pieza probable: qué hace ante cada evento de red.**
//!
//! # Por qué existe este módulo
//!
//! Esta lógica vivía dentro de `main.rs`, en funciones privadas de un binario. Un binario no se
//! importa desde un test de integración, así que los tests de dos nodos **reimplementaban el
//! protocolo a mano**: pedían el saludo, comparaban el trabajo, pedían cabeceras y las aplicaban,
//! todo escrito otra vez en el test.
//!
//! Eso probaba que las piezas encajan. No probaba que **el nodo** funcione, que es distinto: el
//! código que corría en producción no era el que estaba bajo test, y las dos copias podían
//! divergir sin que nada fallara. Es el mismo patrón que el resto del proyecto ya ha pagado tres
//! veces —dos fuentes para una sola verdad— trasladado de los números al comportamiento.
//!
//! El `lib.rs` de este crate incluso lo decía: *«un hito que se comprueba a mano es un hito que
//! deja de comprobarse»*. El driver se quedó en el binario igualmente.
//!
//! Ahora `main.rs` es cableado y apagado, los tests conducen **este** código, y el arnés de tres
//! nodos es posible sin escribir el protocolo una tercera vez.
//!
//! # Qué NO hace
//!
//! No posee el swarm ni el bucle de eventos: eso es de `zx-p2p`. Recibe un [`EventoRed`] ya
//! entregado y decide qué responder. Es deliberado —así el mismo `Nodo` se conduce desde un
//! `select!` con señales en el binario y desde un bucle determinista en un test.

use std::sync::Arc;

use libp2p::PeerId;
use primitive_types::U256;
use zx_p2p::entrante::ManejadorEntrante;
use zx_p2p::error::MotivoDesconexion;
use zx_p2p::mensaje::{Peticion, Respuesta};
use zx_p2p::servicio::{EventoRed, ManejoRed};

use crate::cadena::{Adopcion, Cadena};
use crate::dificultad::comprobar_dificultad;
use crate::sync::{Fase, Sincronizador, validar_cadena_de_cabeceras};

/// Si el nodo debe seguir o pararse tras atender un evento.
///
/// Un `enum` de dos variantes en vez de un `bool` porque el que para es **C-REORG-07**, y un `bool`
/// en la firma no dice cuál de los dos valores es el excepcional.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Fin {
    /// Todo normal.
    Seguir,
    /// Condición no recuperable: el nodo se detiene y avisa al operador.
    Detener,
}

/// El nodo: una cadena, un sincronizador y un asa a la red.
pub struct Nodo {
    cadena: Arc<Cadena>,
    sinc: Sincronizador,
    manejo: ManejoRed,
}

impl Nodo {
    /// Un nodo sobre una cadena ya abierta y una red ya arrancada.
    pub fn nuevo(cadena: Arc<Cadena>, manejo: ManejoRed) -> Self {
        Self {
            cadena,
            sinc: Sincronizador::nuevo(),
            manejo,
        }
    }

    /// La cadena, para que quien conduce el nodo pueda mirarla.
    pub fn cadena(&self) -> &Arc<Cadena> {
        &self.cadena
    }

    /// En qué punto de la sincronización está.
    pub fn fase(&self) -> Fase {
        self.sinc.fase()
    }

    /// **Qué hace el nodo ante un evento de red.**
    ///
    /// El caso de canal cerrado no está aquí a propósito: eso no es un evento del protocolo, es que
    /// la red se ha caído, y quién decide qué hacer con eso es quien posee el bucle.
    pub async fn atender(&mut self, evento: EventoRed) -> Fin {
        match evento {
            EventoRed::PeerConectado(p) => {
                tracing::info!(peer = %p, "conectado");
                // Lo primero que se le dice a un peer nuevo es "¿quién eres?" (§16.1). Sin el
                // saludo no se sabe quién va por delante, ni si es de esta cadena.
                if let Err(e) = self.manejo.pedir(p, Peticion::Estado).await {
                    tracing::warn!(peer = %p, %e, "no se pudo saludar");
                }
                Fin::Seguir
            }
            EventoRed::PeerDesconectado(p) => {
                tracing::info!(peer = %p, "desconectado");
                // Perder al peer del que descargábamos vuelve a saludar; NO penaliza.
                self.sinc.peer_perdido(p);
                Fin::Seguir
            }
            EventoRed::Escuchando(a) => {
                tracing::info!(addr = %a, "escuchando en");
                Fin::Seguir
            }
            EventoRed::PeticionFallida { peer } => {
                // C-NET-05 · una petición fallida no puntúa: puede ser lentitud o una caída.
                tracing::debug!(peer = %peer, "petición fallida");
                self.sinc.peer_perdido(peer);
                Fin::Seguir
            }
            EventoRed::Respuesta {
                peer, respuesta, ..
            } => self.atender_respuesta(peer, *respuesta).await,
        }
    }

    async fn atender_respuesta(&mut self, peer: PeerId, respuesta: Respuesta) -> Fin {
        match respuesta {
            Respuesta::Estado(e) => {
                if e.genesis != self.cadena.genesis() {
                    // Otra cadena. El prefijo mágico (C-NET-01) evita que dos REDES se saluden;
                    // esto detecta que, dentro de la misma red, no compartimos génesis.
                    // Desconectar sin penalizar: no es mala fe, es que no hay nada que hablar.
                    tracing::warn!(peer = %peer, "génesis distinto: no es nuestra cadena");
                    let _ = self
                        .manejo
                        .desconectar(peer, MotivoDesconexion::Ilegible)
                        .await;
                    return Fin::Seguir;
                }
                tracing::info!(peer = %peer, altura = e.altura, "saludo");

                // La comparación es por TRABAJO, no por altura: la altura la elige el peer.
                let suyo = U256::from_big_endian(&e.trabajo);
                let nuestro = U256::from_big_endian(&self.cadena.estado().trabajo);
                self.sinc.saludo_recibido(peer, suyo, nuestro);

                if self.sinc.fase() == Fase::Cabeceras {
                    tracing::info!(peer = %peer, "va por delante: pidiendo cabeceras");
                    self.pedir_cabeceras(peer).await;
                }
                Fin::Seguir
            }
            Respuesta::Cabeceras(cs) => self.atender_cabeceras(peer, cs).await,
            Respuesta::Bloques(bs) => {
                tracing::debug!(peer = %peer, n = bs.len(), "bloques recibidos");
                Fin::Seguir
            }
            Respuesta::NoDisponible => {
                // No es un error y no puntúa (C-NET-05).
                tracing::debug!(peer = %peer, "el peer no tiene lo que se le pidió");
                Fin::Seguir
            }
        }
    }

    async fn atender_cabeceras(
        &mut self,
        peer: PeerId,
        cs: Vec<zx_core::preimage::block::BlockHeader>,
    ) -> Fin {
        let n = cs.len();
        tracing::debug!(peer = %peer, n, "cabeceras recibidas");

        // Lo que se cuenta hacia "al día" es lo APLICADO, no lo recibido. Contar lo recibido deja
        // que un peer finja que estamos sincronizados mandando basura corta (C-NET-17).
        let mut aplicadas = 0usize;
        // C-NET-19 · a un peer condenado no se le vuelve a pedir en esta misma vuelta.
        // `Comando::Desconectar` solo **encola**, así que sin esta bandera el condenado se llevaba
        // una ronda extra de interacción antes de que la desconexión se procesara.
        let mut condenado = false;

        // El ancla es de dónde cuelgan: el `prev_hash` de la primera, que MUST ser algo nuestro. Si
        // no lo conocemos, la respuesta no continúa nuestro locator.
        let ancla = cs.first().map(|c| c.prev_hash);
        let hasta_ancla = ancla.and_then(|a| self.cadena.trabajo_hasta(a));

        match hasta_ancla {
            Some(w_ancla) if n > 0 => {
                let hash_ancla = ancla.unwrap_or_else(|| self.cadena.genesis());
                let r = validar_cadena_de_cabeceras(
                    &cs,
                    hash_ancla,
                    w_ancla,
                    self.cadena.trabajo(),
                    self.cadena.trabajo_de_un_bloque(),
                )
                // C-BLK-05, C-DIFF-09 · y que el `bits` sea el que el retarget exige. Va DESPUÉS
                // del PoW a propósito: comprobar la dificultad esperada cuesta reconstruir una
                // ventana de 91 ancestros, y no merece la pena gastarla en cabeceras que ni
                // siquiera cumplen su propio `bits`.
                .and_then(|w| {
                    let altura_ancla = self
                        .cadena
                        .altura_de(hash_ancla)
                        .ok_or(crate::sync::RechazoCabeceras::VentanaIncompleta)?;
                    comprobar_dificultad(&self.cadena, &cs, altura_ancla).map(|()| w)
                });
                match r {
                    Ok(_) => match self.cadena.adoptar(&cs) {
                        Ok(Adopcion::Extendida { aplicadas: a }) => {
                            aplicadas = a;
                            tracing::info!(
                                peer = %peer, aplicadas = a, recibidas = n,
                                altura = self.cadena.altura(), "cabeceras"
                            );
                        }
                        Ok(Adopcion::Reorganizada {
                            aplicadas: a,
                            desechadas,
                        }) => {
                            aplicadas = a;
                            // Una reorg no es un error, pero **sí** merece nivel de aviso: es el
                            // momento en que un pago que un comerciante daba por confirmado puede
                            // dejar de estarlo.
                            tracing::warn!(
                                peer = %peer, aplicadas = a, desechadas,
                                altura = self.cadena.altura(), "REORGANIZACIÓN"
                            );
                        }
                        Ok(otra) => {
                            // `NoGana` o `NoCuelgaDeNada`: **no es mala fe** —es lo que propone
                            // cualquiera que vaya por otra rama— pero reintentar con el mismo
                            // locator daría lo mismo indefinidamente (C-NET-18).
                            tracing::debug!(peer = %peer, ?otra, "no se adopta; se deja de pedir");
                            condenado = true;
                        }
                        // C-REORG-07 · una reorg de más de 99 bloques **detiene el nodo**. No es
                        // una condición recuperable: o hay un ataque de mayoría, o esta cadena no
                        // es la que creíamos. Seguir sería elegir en silencio.
                        Err(e) => {
                            tracing::error!(
                                peer = %peer, %e,
                                "C-REORG-07: reorganización demasiado profunda. EL NODO SE \
                                 DETIENE. Revisa la cadena antes de reiniciar."
                            );
                            return Fin::Detener;
                        }
                    },
                    Err(e) => {
                        tracing::warn!(peer = %peer, ?e, mala_fe = e.es_mala_fe(), "rechazadas");
                        // C-NET-05 · solo la mala fe corta. Ir por detrás, no.
                        if e.es_mala_fe() {
                            condenado = true;
                            let _ = self
                                .manejo
                                .desconectar(peer, MotivoDesconexion::ViolacionDeConsenso)
                                .await;
                        }
                    }
                }
            }
            Some(_) => {}
            None if n > 0 => {
                // Su `prev_hash` no está en nuestra cadena. **No se penaliza** —puede ser
                // desincronización— pero tampoco se le sigue pidiendo: con el mismo locator
                // respondería lo mismo indefinidamente.
                tracing::debug!(peer = %peer, "sus cabeceras no cuelgan de nada nuestro");
                self.sinc.peer_perdido(peer);
                return Fin::Seguir;
            }
            None => {}
        }

        if condenado {
            // Al peer condenado no se le pide nada más, y deja de ser nuestro sincronizador
            // **ahora**, sin esperar al evento de desconexión.
            self.sinc.peer_perdido(peer);
            return Fin::Seguir;
        }

        if self.sinc.respuesta_registrada(aplicadas) {
            tracing::info!(altura = self.cadena.altura(), "al día");
        } else if self.sinc.fase() == Fase::Cabeceras {
            // Seguir pidiendo desde la punta nueva.
            self.pedir_cabeceras(peer).await;
        }
        Fin::Seguir
    }

    async fn pedir_cabeceras(&self, peer: PeerId) {
        let p = Peticion::Cabeceras {
            locator: self.cadena.locator(),
            hasta: None,
        };
        if let Err(err) = self.manejo.pedir(peer, p).await {
            tracing::debug!(peer = %peer, %err, "no se pudieron pedir cabeceras");
        }
    }
}
