//! Red del nodo (`ORDEN-W06d2`): puente entre el bucle asíncrono de `zx-p2p` y el hilo de consenso
//! síncrono que posee `zx-cadena`/`zx-storage` (D-N07).
//!
//! Ver los submódulos para cada pieza: [`huerfanos`] (depósito acotado, decisión 3),
//! [`vista`] (instantánea de solo lectura que sirve el saludo y las peticiones de sincronización),
//! [`manejador`] ([`zx_p2p::entrante::ManejadorEntrante`] real, decisión 1) y [`sync`] (localizador
//! PoW + recorrido hacia atrás del DAG, decisión 4).

pub mod huerfanos;
pub mod manejador;
pub mod sync;
pub mod vista;

use std::sync::Arc;

use zx_core::BlockHash;
use zx_p2p::entrante::IdDiferido;
use zx_p2p::mensaje::BloqueRed;

/// Lo que el manejador (lado asíncrono) encola para que el hilo de consenso lo procese.
///
/// El manejador **nunca** valida nada: solo mete esto en la cola y devuelve
/// [`zx_p2p::entrante::Veredicto::Diferir`] de inmediato (decisión 1). El hilo de consenso decide,
/// a su ritmo, y responde con [`zx_p2p::servicio::ManejoRed::informar_validacion_bloqueante`].
pub enum TrabajoRed {
    /// Un bloque llegó por difusión (gossipsub) y su veredicto está diferido con `id`.
    BloqueDifundido {
        /// El identificador opaco a devolver.
        id: IdDiferido,
        /// El bloque, ya deserializado.
        bloque: BloqueRed,
    },
    /// Un bloque llegó como respuesta a una petición de sincronización (no lleva `IdDiferido`: no
    /// pasó por gossipsub, así que no hay nada que informarle a `report_message_validation_result`).
    /// Penalizar a quien lo mandó, si hace falta, es cosa de quien conduce la sincronización
    /// ([`sync`]), no de esta cola.
    BloqueDeSincronizacion {
        /// Quién lo mandó (para que la sincronización pueda desconectar si es basura).
        de: libp2p::PeerId,
        /// El bloque.
        bloque: BloqueRed,
    },
}

/// Un límite de recursión declarado para el recorrido hacia atrás del DAG (decisión 3 y 4): cuántos
/// saltos de "pide al padre que falta" se permiten antes de darse por vencido con esa rama. Evita
/// una cascada sin fin si un par miente sobre una cadena de padres arbitrariamente larga.
pub const LIMITE_SALTOS_RECORRIDO_ATRAS: u32 = 4096;

/// Cuántos huérfanos puede tener el depósito en total (decisión 3).
///
/// Valor dev: generoso para no penalizar una ráfaga honesta durante IBD, acotado para no crecer sin
/// límite. 🔶 Revisable con medición real (W07).
pub const MAX_HUERFANOS_TOTAL: usize = 4_096;

/// Cuántos huérfanos puede tener el depósito esperando al **mismo** padre.
pub const MAX_HUERFANOS_POR_PADRE: usize = 64;

/// Construye el depósito de huérfanos con los topes de producción declarados arriba.
#[must_use]
pub fn nuevo_deposito_huerfanos() -> huerfanos::DepositoHuerfanos {
    huerfanos::DepositoHuerfanos::nuevo(MAX_HUERFANOS_TOTAL, MAX_HUERFANOS_POR_PADRE)
}

/// Los tres hashes de un bloque que hacen falta para decidir si es huérfano, ya extraídos de
/// [`BloqueRed`] sin tocar consenso (`zx-p2p` no expone `padres()`, así que se replica aquí lo
/// mínimo: el padre PoW o los padres PoST declarados).
#[must_use]
pub fn padres_declarados(bloque: &BloqueRed) -> Vec<BlockHash> {
    match bloque {
        BloqueRed::Pow { cabecera, .. } => {
            if cabecera.height == 0 {
                Vec::new()
            } else {
                vec![cabecera.prev_hash]
            }
        }
        BloqueRed::Post { cabecera, .. } => {
            let p = &cabecera.padres;
            if p.es_genesis() {
                Vec::new()
            } else {
                let mut v = vec![p.seleccionado()];
                v.extend_from_slice(p.extras());
                v
            }
        }
    }
}

/// Hash del bloque, sin depender de a qué familia pertenece.
#[must_use]
pub fn hash_de(bloque: &BloqueRed) -> BlockHash {
    match bloque {
        BloqueRed::Pow { cabecera, .. } => cabecera.block_hash(),
        BloqueRed::Post { cabecera, .. } => cabecera.block_hash(),
    }
}

/// Handle compartido hacia la red, más los canales por los que el hilo de consenso recibe trabajo y
/// eventos de sincronización. Construido por [`crate::nodo::Nodo`] al arrancar con red.
pub struct ManijaRed {
    /// Para hablarle a `zx-p2p` desde el hilo de consenso (métodos bloqueantes o vía `runtime`).
    pub manejo: zx_p2p::servicio::ManejoRed,
    /// El `Handle` del runtime `tokio` que corre el bucle de `zx-p2p`, para los métodos de
    /// `ManejoRed` que sólo existen en versión `async` (`pedir`, `desconectar`, `difundir_bloque`).
    pub runtime: tokio::runtime::Handle,
    /// Instantánea compartida que sirve el saludo y las respuestas de sincronización.
    pub vista: Arc<vista::VistaRed>,
}

impl ManijaRed {
    /// Difunde un bloque propio. Bloqueante: se llama desde el hilo de consenso.
    pub fn difundir_bloque(&self, bloque: &BloqueRed) -> Result<(), zx_p2p::error::P2pError> {
        self.runtime.block_on(self.manejo.difundir_bloque(bloque))
    }

    /// Pide algo a un par. Bloqueante.
    pub fn pedir(&self, peer: libp2p::PeerId, peticion: zx_p2p::mensaje::Peticion) {
        if let Err(e) = self.runtime.block_on(self.manejo.pedir(peer, peticion)) {
            tracing::debug!(%e, "no se pudo encolar una petición de sincronización");
        }
    }

    /// Corta con un par por un motivo dado. Bloqueante.
    pub fn desconectar(&self, peer: libp2p::PeerId, motivo: zx_p2p::error::MotivoDesconexion) {
        let _ = self.runtime.block_on(self.manejo.desconectar(peer, motivo));
    }

    /// Informa el veredicto final de una validación diferida. Ya es bloqueante de por sí (no hace
    /// falta `runtime.block_on`, ver `informar_validacion_bloqueante`).
    pub fn informar_validacion(&self, id: IdDiferido, veredicto: zx_p2p::entrante::VeredictoFinal) {
        if let Err(e) = self.manejo.informar_validacion_bloqueante(id, veredicto) {
            tracing::debug!(%e, "no se pudo informar el veredicto diferido");
        }
    }
}

/// Todo lo que arranca la red de un nodo (`ORDEN-W06d2`): el runtime `tokio` (que hay que
/// mantener vivo mientras el nodo corra: soltarlo para el bucle y la sincronización), la
/// [`ManijaRed`] a entregarle a [`crate::nodo::Nodo::conectar_red`] y el receptor de trabajo.
pub struct RedArrancada {
    /// **No soltar** mientras el nodo esté vivo: al soltarse, `tokio` cancela sus tareas.
    pub runtime: tokio::runtime::Runtime,
    /// Para `Nodo::conectar_red`.
    pub manija: ManijaRed,
    /// Para `Nodo::conectar_red`.
    pub trabajo: tokio::sync::mpsc::UnboundedReceiver<TrabajoRed>,
}

/// Construye el transporte TCP real (decisión 8 de la orden: `127.0.0.1` en pruebas, cualquier
/// dirección en un despliegue), el behaviour de la red dev, y arranca el bucle y la tarea de
/// sincronización en un runtime `tokio` nuevo. Escucha en `escuchar` (si se da) y marca cada
/// dirección de `marcar`.
///
/// # Errores
/// [`zx_p2p::error::P2pError`] si el behaviour o el transporte no se pueden construir; un error
/// libre si el runtime `tokio` no arranca (out-of-resources, no un caso de test).
pub fn arrancar(
    escuchar: Option<libp2p::Multiaddr>,
    marcar: Vec<libp2p::Multiaddr>,
    vista: Arc<vista::VistaRed>,
) -> Result<RedArrancada, String> {
    let runtime = tokio::runtime::Builder::new_multi_thread()
        .worker_threads(2)
        .enable_all()
        .build()
        .map_err(|e| format!("runtime tokio: {e}"))?;

    let clave = libp2p::identity::Keypair::generate_ed25519();
    let behaviour = zx_p2p::behaviour::ZxBehaviour::nueva(
        &clave,
        zx_p2p::config::ParametrosRed::dag_dev(),
        zx_p2p::limites::LIMITE_BLOQUE_DEV,
    )
    .map_err(|e| format!("behaviour de red: {e}"))?;

    // Construcción síncrona (ninguno de estos métodos de `SwarmBuilder` es `async`): un cierre sin
    // argumentos con el tipo de retorno anotado, para que el `?` de `with_tcp` no confunda al
    // compilador con el `Result<_, Infallible>` de `with_behaviour` (`TryIntoBehaviour<B> for B`
    // tiene `Error = Infallible`: no hay nada que manejar salvo el `match` exhaustivo de abajo).
    let construir_swarm = || -> Result<libp2p::Swarm<zx_p2p::behaviour::ZxBehaviour>, String> {
        let builder = libp2p::SwarmBuilder::with_existing_identity(clave)
            .with_tokio()
            .with_tcp(
                libp2p::tcp::Config::default(),
                libp2p::noise::Config::new,
                libp2p::yamux::Config::default,
            )
            .map_err(|e| format!("transporte TCP: {e}"))?;
        let builder = match builder.with_behaviour(|_| behaviour) {
            Ok(b) => b,
            Err(nunca) => match nunca {},
        };
        Ok(builder
            .with_swarm_config(|c| {
                c.with_idle_connection_timeout(std::time::Duration::from_secs(30))
            })
            .build())
    };
    let swarm = construir_swarm()?;

    let (tx_trabajo, rx_trabajo) = tokio::sync::mpsc::unbounded_channel();
    let manejador = Arc::new(manejador::ManejadorRed::nuevo(
        tx_trabajo.clone(),
        Arc::clone(&vista),
    ));
    let piezas = zx_p2p::servicio::arrancar(swarm, manejador);
    let manejo = piezas.manejo;

    runtime.spawn(piezas.bucle.correr());
    runtime.spawn(sync::tarea_sincronizacion(
        piezas.eventos,
        manejo.clone(),
        Arc::clone(&vista),
        tx_trabajo,
    ));

    if let Some(addr) = escuchar {
        runtime
            .block_on(manejo.escuchar(addr))
            .map_err(|e| format!("escuchar: {e}"))?;
    }
    for addr in marcar {
        if let Err(e) = runtime.block_on(manejo.marcar(addr.clone())) {
            tracing::warn!(%addr, %e, "no se pudo marcar la dirección al arrancar");
        }
    }

    Ok(RedArrancada {
        manija: ManijaRed {
            manejo,
            runtime: runtime.handle().clone(),
            vista,
        },
        runtime,
        trabajo: rx_trabajo,
    })
}
