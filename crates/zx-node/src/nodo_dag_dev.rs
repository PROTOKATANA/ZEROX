//! Saludo de identidad de la red DAG de **desarrollo** (incremento F4/C3, sin cerrar pieza).
//!
//! # Qué es
//!
//! Conecta dos piezas que ya existen por separado: el bootstrap aislado del génesis dev
//! ([`crate::bootstrap_dag_dev`]) y la identidad de transporte DAG dev de `zx-p2p`
//! (`ParametrosRed::dag_dev`, códec `SoloEstado`). Aquí viven:
//!
//! - [`ManejadorDagDev`], la implementación de [`ManejadorEntrante`] que **sirve** el saludo
//!   `Peticion::Estado`/`Respuesta::Estado` y nada más.
//! - [`NodoDagDev`], el coordinador que **verifica** el saludo del otro extremo: marca un peer
//!   `listo` solo cuando su `Estado` coincide con el estado inicial local completo.
//!
//! # Qué certifica, y qué no
//!
//! Marca `listo` a un peer únicamente si `Respuesta::Estado` coincide en los **cuatro** campos con
//! `Estado { genesis = tip = hash_dev, altura = 0, trabajo = [0; 32] }` y el peer estaba pendiente
//! de saludo. Ese es el estado **inicial de transporte** del génesis dev, **no** `blue_work` ni un
//! orden DAG calculado.
//!
//! Ni [`NodoDagDev::atender`] ni el handler aceptan o retransmiten bloques, transacciones ni
//! anuncios compactos: los tres callbacks devuelven `Ignorar`, `cabeceras_desde`/`bloques_por_hash`
//! devuelven vacío y el códec dev ya prohíbe esas variantes en el wire. **No hay producción de
//! bloques** y no se afirma convergencia de cadena.
//!
//! `PeerConectado` y `EventoRed::Suscripcion` **no** cuentan como identidad verificada: un
//! `magic` distinto no está en el wire (C-NET-01 sigue pendiente de cableado) y una conexión
//! Noise cruzada puede establecerse hasta que este saludo la coteje y la corte. Por eso una
//! discrepancia de génesis, una respuesta de otra variante, un fallo de petición o el vencimiento
//! del plazo desconectan con motivo **no puntuable** (C-NET-05): no son mala fe demostrable.
//!
//! # El plazo es de desarrollo
//!
//! [`PLAZO_SALUDO_DEV`] son `10 s` **elegidos solo para desarrollo**, no un parámetro de consenso.
//! El vencimiento no se observa con `sleep` fijo en las pruebas: [`NodoDagDev::expirar`] recibe el
//! `Instant` actual, de modo que un test puede adelantarlo sin esperar.
//!
//! # Qué NO hace
//!
//! No usa `Nodo`, `Cadena`, `Sincronizador` ni `AlmacenGhostdag::anadir_sintetico`: todos
//! pertenecen a la ruta lineal o atribuirían admisión PoST al fixture. La coinbase del génesis dev
//! no entra en ningún UTXO.

use std::collections::{BTreeMap, BTreeSet};
use std::time::{Duration, Instant};

use libp2p::PeerId;

use zx_core::BlockHash;
use zx_core::preimage::block::BlockHeader;
use zx_p2p::entrante::{ManejadorEntrante, Veredicto};
use zx_p2p::error::MotivoDesconexion;
use zx_p2p::mensaje::{BloqueRed, Estado, Peticion, Respuesta};
use zx_p2p::rele_compacto::AnuncioCompacto;
use zx_p2p::servicio::{EventoRed, ManejoRed};

use crate::bootstrap_dag_dev::EstadoBootstrapDagDev;

/// Plazo del saludo local de la red DAG dev.
///
/// **Diez segundos elegidos solo para desarrollo**, no un parámetro de consenso ni un valor
/// medido. [`NodoDagDev::expirar`] lo aplica contra un `Instant` inyectado, así que las pruebas no
/// duermen.
pub const PLAZO_SALUDO_DEV: Duration = Duration::from_secs(10);

/// Motivo con el que se corta a un peer cuyo `Estado` **discrepa** del génesis dev.
///
/// Es [`MotivoDesconexion::Ilegible`]: puede ser otra red u otra bifurcación, y por C-NET-05 no es
/// mala fe demostrable, así que **no puntúa**.
pub const MOTIVO_ESTADO_DISCREPANTE: MotivoDesconexion = MotivoDesconexion::Ilegible;

/// Motivo con el que se corta a un peer que **no completó** el saludo dentro de
/// [`PLAZO_SALUDO_DEV`].
///
/// Es [`MotivoDesconexion::Lento`]: por C-NET-05 la lentitud **no puntúa**. También cubre el fallo
/// de una petición de saludo, que no distingue lentitud de caída.
pub const MOTIVO_SALUDO_VENCIDO: MotivoDesconexion = MotivoDesconexion::Lento;

/// El estado inicial de transporte del génesis dev.
///
/// Es exactamente `Estado { genesis = tip = hash_dev, altura = 0, trabajo = [0; 32] }`. No es
/// `blue_work` ni un orden DAG calculado: es solo el dato con el que se coteja el saludo.
fn estado_inicial_dev(hash_dev: BlockHash) -> Estado {
    Estado {
        genesis: hash_dev,
        tip: hash_dev,
        altura: 0,
        trabajo: [0u8; 32],
    }
}

/// Handler de `zx-p2p` para la red DAG dev.
///
/// Se construye **solo** desde un [`EstadoBootstrapDagDev`] ya comprobado; no existe constructor a
/// partir de un hash libre. Sirve el saludo y devuelve `Ignorar` en los tres callbacks de
/// difusión, sin aceptar ni retransmitir. El códec dev ya prohíbe pedir cabeceras o bloques.
#[derive(Clone, Debug)]
pub struct ManejadorDagDev {
    hash_dev: BlockHash,
}

impl ManejadorDagDev {
    /// Construye el handler desde el estado del bootstrap dev.
    ///
    /// Es la única vía: el hash sale de un estado que ya superó estructura y hash contra el literal
    /// congelado (`C-GEN-07`), no de un argumento libre.
    #[must_use]
    pub fn desde_estado_dev(estado: &EstadoBootstrapDagDev) -> Self {
        Self {
            hash_dev: estado.hash_congelado_dev(),
        }
    }

    /// Hash congelado del génesis dev que este handler sirve.
    #[must_use]
    pub fn hash_dev(&self) -> BlockHash {
        self.hash_dev
    }

    /// El `Estado` que este handler responde al saludo.
    #[must_use]
    pub fn estado_dev(&self) -> Estado {
        estado_inicial_dev(self.hash_dev)
    }
}

impl ManejadorEntrante for ManejadorDagDev {
    fn estado(&self) -> Estado {
        self.estado_dev()
    }

    fn bloque_difundido(&self, _bloque: &BloqueRed) -> Veredicto {
        // No admite PoST ni produce bloques: el bloque completo no entra por esta ruta.
        Veredicto::Ignorar
    }

    fn tx_difundida(&self, _tx_serializada: &[u8]) -> Veredicto {
        Veredicto::Ignorar
    }

    fn anuncio_compacto(&self, _anuncio: &AnuncioCompacto) -> Veredicto {
        // Sin validación DAG causal no se acepta ni se retransmite (C-NET-12).
        Veredicto::Ignorar
    }

    fn cabeceras_desde(
        &self,
        _locator: &[BlockHash],
        _hasta: Option<BlockHash>,
    ) -> Vec<BlockHeader> {
        // El códec dev no permite pedir cabeceras; aunque llegara, no hay historia que servir.
        Vec::new()
    }

    fn bloques_por_hash(&self, _hashes: &[BlockHash]) -> Vec<BloqueRed> {
        Vec::new()
    }
}

/// Coordinador de eventos del saludo DAG dev.
///
/// Mantiene, por `PeerId`, quién está **pendiente** de responder al saludo y quién quedó **listo**
/// tras cotejar el `Estado`. Marca `listo` solo si el peer estaba pendiente y los cuatro campos
/// coinciden; cualquier discrepancia, otra variante, un fallo de petición o el vencimiento del
/// plazo lo desconectan con motivo no puntuable y lo eliminan de ambos conjuntos.
pub struct NodoDagDev {
    manejo: ManejoRed,
    hash_dev: BlockHash,
    pendientes: BTreeMap<PeerId, Instant>,
    listos: BTreeSet<PeerId>,
    motivos: BTreeMap<PeerId, MotivoDesconexion>,
}

impl NodoDagDev {
    /// Crea el coordinador a partir del estado del bootstrap dev y un asa de red.
    #[must_use]
    pub fn nuevo(estado: &EstadoBootstrapDagDev, manejo: ManejoRed) -> Self {
        Self {
            manejo,
            hash_dev: estado.hash_congelado_dev(),
            pendientes: BTreeMap::new(),
            listos: BTreeSet::new(),
            motivos: BTreeMap::new(),
        }
    }

    /// El estado inicial local completo con el que se coteja cada saludo.
    #[must_use]
    pub fn estado_local(&self) -> Estado {
        estado_inicial_dev(self.hash_dev)
    }

    /// Hash congelado del génesis dev de este coordinador.
    #[must_use]
    pub fn hash_dev(&self) -> BlockHash {
        self.hash_dev
    }

    /// ¿Quedó este peer `listo` tras cotejar el `Estado`?
    #[must_use]
    pub fn esta_listo(&self, peer: &PeerId) -> bool {
        self.listos.contains(peer)
    }

    /// ¿Está este peer pendiente de completar el saludo?
    #[must_use]
    pub fn esta_pendiente(&self, peer: &PeerId) -> bool {
        self.pendientes.contains_key(peer)
    }

    /// Los peers verificados, por `PeerId`.
    #[must_use]
    pub fn peers_listos(&self) -> &BTreeSet<PeerId> {
        &self.listos
    }

    /// Los peers pendientes de saludo y su vencimiento.
    #[must_use]
    pub fn peers_pendientes(&self) -> &BTreeMap<PeerId, Instant> {
        &self.pendientes
    }

    /// El motivo con el que se desconectó a un peer, si consta.
    ///
    /// Permite a una prueba observar que el motivo es **no puntuable** (C-NET-05) sin leer el
    /// código fuente. El registro no se borra al recibir `PeerDesconectado`; sí al reconectar.
    #[must_use]
    pub fn motivo_de_desconexion(&self, peer: &PeerId) -> Option<MotivoDesconexion> {
        self.motivos.get(peer).copied()
    }

    /// Atiende un evento de red.
    ///
    /// Devuelve los peers que **acaban de quedar listos** con este evento, para que el runner
    /// pueda anunciarlos. `PeerConectado` solo marca pendiente y pide `Peticion::Estado`;
    /// `PeerConectado` y `EventoRed::Suscripcion` nunca marcan listo.
    pub async fn atender(&mut self, evento: EventoRed) -> Vec<PeerId> {
        match evento {
            EventoRed::PeerConectado(peer) => {
                // Una conexión nueva se vuelve a verificar desde cero.
                self.listos.remove(&peer);
                self.motivos.remove(&peer);
                self.pendientes
                    .insert(peer, Instant::now() + PLAZO_SALUDO_DEV);
                if let Err(e) = self.manejo.pedir(peer, Peticion::Estado).await {
                    tracing::debug!(%peer, %e, "no se pudo pedir el saludo dev");
                }
                Vec::new()
            }
            EventoRed::PeerDesconectado(peer) => {
                self.pendientes.remove(&peer);
                self.listos.remove(&peer);
                Vec::new()
            }
            EventoRed::PeticionFallida { peer } => {
                self.fallar(peer, MOTIVO_SALUDO_VENCIDO).await;
                Vec::new()
            }
            EventoRed::Respuesta {
                peer, respuesta, ..
            } => match *respuesta {
                Respuesta::Estado(estado) => {
                    if self.pendientes.remove(&peer).is_some() {
                        if estado == self.estado_local() {
                            self.listos.insert(peer);
                            return vec![peer];
                        }
                        // Discrepancia de génesis, tip, altura o trabajo.
                        self.fallar(peer, MOTIVO_ESTADO_DISCREPANTE).await;
                    } else if estado != self.estado_local() {
                        // Evento tardío sin pendiente: no marca listo, pero un estado que no es el
                        // nuestro delata que no comparte el génesis dev.
                        self.fallar(peer, MOTIVO_ESTADO_DISCREPANTE).await;
                    }
                    Vec::new()
                }
                // Otra variante no responde al saludo: el códec dev no debería entregarla, pero si
                // llega, el peer estaba pendiente y se corta sin puntuar.
                _ => {
                    if self.pendientes.remove(&peer).is_some() {
                        self.fallar(peer, MOTIVO_ESTADO_DISCREPANTE).await;
                    }
                    Vec::new()
                }
            },
            // `Escuchando` y `Suscripcion` son transporte: no son identidad verificada.
            EventoRed::Escuchando(_) | EventoRed::Suscripcion { .. } => Vec::new(),
        }
    }

    /// Desconecta a los peers pendientes cuyo plazo de saludo venció respecto a `ahora`.
    ///
    /// El `Instant` se **inyecta** para que una prueba pueda adelantar el reloj sin dormir. Es el
    /// runner quien lo llama periódicamente; el plazo es de desarrollo, no de consenso.
    pub async fn expirar(&mut self, ahora: Instant) -> Vec<PeerId> {
        let vencidos: Vec<PeerId> = self
            .pendientes
            .iter()
            .filter(|(_, vence)| **vence <= ahora)
            .map(|(peer, _)| *peer)
            .collect();
        for peer in &vencidos {
            self.fallar(*peer, MOTIVO_SALUDO_VENCIDO).await;
        }
        vencidos
    }

    /// Elimina al peer de pendientes y listos, registra el motivo y ordena desconectarlo.
    async fn fallar(&mut self, peer: PeerId, motivo: MotivoDesconexion) {
        self.pendientes.remove(&peer);
        self.listos.remove(&peer);
        self.motivos.insert(peer, motivo);
        if let Err(e) = self.manejo.desconectar(peer, motivo).await {
            tracing::debug!(%peer, %e, "no se pudo desconectar al peer del saludo dev");
        }
    }
}
