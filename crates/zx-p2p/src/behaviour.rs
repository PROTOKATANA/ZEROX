//! Composición de behaviours de libp2p (SPEC §16).
//!
//! # Aquí no hay ni un solo default de transporte
//!
//! Es el punto del crate donde se aplica C-NET-11. Cada `Config` que se construye aquí sobrescribe
//! explícitamente lo que libp2p trae de fábrica, porque **sus defaults no son seguros para una
//! cadena y ninguno falla al compilar**. Si alguien borra una línea de este archivo, el código
//! sigue compilando y la red deja de funcionar de una de estas cuatro maneras:
//!
//! - los bloques dejan de propagarse (`max_transmit_size`),
//! - un bloque inválido se reenvía antes de validarse (`validate_messages`),
//! - un peer abre conexiones sin límite (`ConnectionLimits`),
//! - la DHT habla con IPFS (`kad::Config::default()`).
//!
//! Por eso cada uno lleva su test.

// `#[derive(NetworkBehaviour)]` genera `ZxBehaviourEvent` con una variante por campo, y no puede
// documentarlas por nosotros. La alternativa —declarar el evento a mano con `to_swarm`— duplicaría
// la lista de behaviours en dos sitios, que es peor: dos sitios se desincronizan.
#![expect(
    missing_docs,
    reason = "las variantes del evento las genera el derive de libp2p"
)]

use std::time::Duration;

use libp2p::{
    Multiaddr, PeerId, StreamProtocol, connection_limits, gossipsub, identify, identity, kad, mdns,
    ping, request_response, swarm::NetworkBehaviour, swarm::behaviour::toggle::Toggle,
};
use zx_core::red::Red;

use crate::codec::ZxCodec;
use crate::limites_ip::LimitesPorIp;
use crate::presupuesto::Presupuesto;

use crate::config::{IdentidadP2p, ParametrosRed};
use crate::error::P2pError;
use crate::limites;

/// Cada cuánto late gossipsub.
///
/// 🔶 **PLAUSIBLE NO DEMOSTRADO — P-019.** Ethereum usa 0,7 s para *slots* de 12 s; ZEROX tiene
/// bloques de **120 s**, un factor 10. No existe fuente que diga qué latido corresponde a esta
/// cadencia, así que se toma el default de libp2p (1 s) y se marca para **medir**, no para
/// justificar a posteriori. Ver `research/libp2p-arquitectura.md` §5.
const HEARTBEAT: Duration = Duration::from_secs(1);

/// Grado objetivo de la malla de gossipsub.
///
/// 8/6/12 en vez del default 6/5/12 de libp2p. La **topología** sí es transferible desde Ethereum
/// —no depende de la cadencia de bloque, solo de cuántos vecinos hacen falta para que la difusión
/// sea robusta—, a diferencia del latido. `consensus-specs`, `p2p-interface.md:528-540`.
const MESH_N: usize = 8;
/// Marca de agua inferior de la malla.
const MESH_N_BAJO: usize = 6;
/// Marca de agua superior de la malla.
const MESH_N_ALTO: usize = 12;

/// Cuánto se espera una respuesta de sincronización.
///
/// El default de `request_response::Config` son **10 s**, pensados para peticiones pequeñas. Un
/// lote de bloques puede ser de megabytes: por un enlace lento, 10 s se agotan y el peer parece
/// muerto cuando solo iba despacio — y eso, por C-NET-05, se clasificaría como `Lento` y se
/// desconectaría a peers perfectamente útiles.
///
/// 🔶 30 s es una estimación conservadora, no una medición. P-019.
const TIMEOUT_SYNC: Duration = Duration::from_secs(30);

// La coherencia de la malla es una aserción de compilación, no un test: gossipsub acepta valores
// incoherentes en tiempo de ejecución y se comporta de forma difícil de diagnosticar.
const _: () = assert!(
    MESH_N_BAJO < MESH_N && MESH_N < MESH_N_ALTO,
    "la malla MUST cumplir bajo < objetivo < alto"
);

/// Los behaviours que componen un nodo de ZEROX.
///
/// `#[derive(NetworkBehaviour)]` **solo funciona sobre `struct`** — sobre un `enum` el macro falla
/// explícitamente (`swarm-derive/src/lib.rs:41-48`).
#[derive(NetworkBehaviour)]
pub struct ZxBehaviour {
    /// Rechaza conexiones por encima de los límites. **Primero en la lista a propósito.**
    ///
    /// El macro genera las llamadas a `handle_pending_inbound_connection` en orden de declaración,
    /// cada una con `?`, así que denegar aquí corta antes de invocar a los demás. Verificado en
    /// `libp2p-swarm-derive-0.35.1/src/lib.rs:272-284`.
    ///
    /// Honestamente: **hoy el ahorro es cero**, porque ninguno de los otros cinco hace trabajo
    /// apreciable en esa fase. El orden vale como defensa en profundidad para el día en que se
    /// añada uno que sí lo haga, no como optimización actual.
    pub limites: connection_limits::Behaviour,
    /// Límites y baneo **por prefijo de red** (C-NET-20).
    ///
    /// Va junto al anterior porque hace lo que aquel no puede: `connection_limits` de libp2p no
    /// tiene **ningún** ajuste por IP, y como un `PeerId` es gratis, limitar por `PeerId` no limita
    /// nada. Ver [`crate::limites_ip`].
    pub limites_ip: LimitesPorIp,
    /// Intercambio de direcciones y protocolos soportados.
    pub identify: identify::Behaviour,
    /// Detecta peers muertos, y **mantiene viva** la conexión frente al `idle_connection_timeout`
    /// de 10 s, que es demasiado corto para un enlace de sincronización con huecos.
    pub ping: ping::Behaviour,
    /// Descubrimiento por DHT.
    pub kademlia: kad::Behaviour<kad::store::MemoryStore>,
    /// Descubrimiento en LAN. **Solo testnet** — ver [`ZxBehaviour::nueva`].
    ///
    /// `Toggle` y no `Option`: `Toggle<B>` implementa `NetworkBehaviour` y se puede desactivar sin
    /// cambiar el tipo del struct, que es lo que permite tener un solo `ZxBehaviour` para las dos
    /// redes en vez de dos composiciones que se desincronizarían.
    pub mdns: Toggle<mdns::tokio::Behaviour>,
    /// Difusión de bloques y transacciones.
    ///
    /// `pub(crate)` y no `pub`: es el behaviour **suscrito** a los temas, y [`crate::servicio::ManejoRed`]
    /// conserva su propia copia de esos temas para fijar el canal de difusión. Con el campo público,
    /// código externo podía suscribir o desuscribir temas por detrás del handle y dejar las dos
    /// vistas desincronizadas. La garantía —handle y suscripción leen la misma instancia— vale para
    /// la ruta construida por el nodo (el `Swarm` que este crate envuelve), no para un `ZxBehaviour`
    /// mutado por fuera.
    pub(crate) gossipsub: gossipsub::Behaviour,
    /// Sincronización punto a punto: `GetHeaders`/`Headers`, `GetBlocks`/`Blocks`.
    ///
    /// **Separado de gossipsub a propósito.** Gossipsub difunde hacia la malla actual y no es un
    /// almacén direccionable: no hay forma de pedirle "el bloque de la altura N de hace seis
    /// meses", y su caché de deduplicación dura 60 s. Un nodo que arrancara de cero esperando el
    /// historial por gossip **se quedaría atascado en el génesis para siempre**.
    ///
    /// Es la misma separación que hace Ethereum entre el dominio *gossip* —solo bloques nuevos— y
    /// el dominio *Req/Resp* —historial— (`consensus-specs`, `p2p-interface.md`).
    pub sync: request_response::Behaviour<ZxCodec>,
    /// Los parámetros de red con los que se construyó esta composición.
    ///
    /// Es un behaviour **sin tráfico propio** (ver [`ParametrosDelNodo`]) para poder viajar dentro
    /// del `#[derive(NetworkBehaviour)]` y ser la única fuente de los temas que usa el handle de
    /// difusión. Así `ManejoRed` no acepta un tema libre y no puede desincronizarse de la
    /// suscripción.
    ///
    /// `pub(crate)` por la misma razón que [`Self::gossipsub`]: este es el origen de los temas y
    /// [`crate::servicio::ManejoRed`] copia los suyos de aquí. La garantía de que ambos ven lo mismo
    /// se limita a la ruta construida por el nodo, no a un `ZxBehaviour` alterado desde fuera.
    pub(crate) parametros: ParametrosDelNodo,
}

/// Un behaviour de libp2p que **no hace nada**: solo transporta [`ParametrosRed`].
///
/// # Por qué existe
///
/// `#[derive(NetworkBehaviour)]` exige que **todos** los campos implementen `NetworkBehaviour`; no
/// admite un campo de datos al margen. Y «deducir» la red en el momento de construir el handle
/// sería adivinar: `Swarm` no expone los parámetros, y el `Red` elegido no basta porque
/// `ParametrosRed::de` es la única fuente de los temas y de los protocolos.
///
/// La alternativa —pasar un `ParametrosRed` aparte a [`crate::servicio::arrancar`]— rompe a todos
/// los llamantes de test, que hoy no lo tienen. Este envoltorio mantiene la firma y garantiza que
/// el handle y la suscripción leen **la misma** instancia.
///
/// `poll` devuelve `Pending` siempre —no genera eventos— y su `ConnectionHandler` es el
/// `dummy::ConnectionHandler` de libp2p, que no negocia ningún protocolo. Es deliberadamente
/// inerte: su único trabajo es hacer visible una invariante en el tipo.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct ParametrosDelNodo(ParametrosRed);

impl ParametrosDelNodo {
    /// Envuelve los parámetros de una red.
    #[must_use]
    pub const fn nuevos(p: ParametrosRed) -> Self {
        Self(p)
    }

    /// Los parámetros envueltos.
    #[must_use]
    pub const fn de_red(self) -> ParametrosRed {
        self.0
    }
}

impl NetworkBehaviour for ParametrosDelNodo {
    type ConnectionHandler = libp2p::swarm::dummy::ConnectionHandler;
    type ToSwarm = std::convert::Infallible;

    fn handle_pending_inbound_connection(
        &mut self,
        _: libp2p::swarm::ConnectionId,
        _: &Multiaddr,
        _: &Multiaddr,
    ) -> Result<(), libp2p::swarm::ConnectionDenied> {
        Ok(())
    }

    fn handle_established_inbound_connection(
        &mut self,
        _: libp2p::swarm::ConnectionId,
        _: PeerId,
        _: &Multiaddr,
        _: &Multiaddr,
    ) -> Result<libp2p::swarm::THandler<Self>, libp2p::swarm::ConnectionDenied> {
        Ok(libp2p::swarm::dummy::ConnectionHandler)
    }

    fn handle_established_outbound_connection(
        &mut self,
        _: libp2p::swarm::ConnectionId,
        _: PeerId,
        _: &Multiaddr,
        _: libp2p::core::Endpoint,
        _: libp2p::core::transport::PortUse,
    ) -> Result<libp2p::swarm::THandler<Self>, libp2p::swarm::ConnectionDenied> {
        Ok(libp2p::swarm::dummy::ConnectionHandler)
    }

    fn on_swarm_event(&mut self, _: libp2p::swarm::FromSwarm) {}

    fn on_connection_handler_event(
        &mut self,
        _: PeerId,
        _: libp2p::swarm::ConnectionId,
        evento: libp2p::swarm::THandlerOutEvent<Self>,
    ) {
        libp2p::core::util::unreachable(evento);
    }

    fn poll(
        &mut self,
        _: &mut std::task::Context<'_>,
    ) -> std::task::Poll<libp2p::swarm::ToSwarm<Self::ToSwarm, libp2p::swarm::THandlerInEvent<Self>>>
    {
        std::task::Poll::Pending
    }
}

impl ZxBehaviour {
    /// Los parámetros de red de esta composición (C-NET-02, C-NET-25).
    ///
    /// El nombre **no** es simplemente `parametros` a propósito: ese identificador ya lo usa un
    /// punto de entrada público de `zx-consensus` (`ghostdag::parametros`), y
    /// `ci/alcance-consenso.sh` es un guardián de grep que cuenta una mención en el código como una
    /// llamada. Una coincidencia de nombre aquí haría que el guardián diera por alcanzada una
    /// función que nadie llama —un falso positivo que esconde el hueco que ese guardián existe para
    /// ver—.
    #[must_use]
    pub const fn parametros_de_red(&self) -> ParametrosRed {
        self.parametros.de_red()
    }

    /// Construye la composición con **todos** los límites de C-NET-11 fijados explícitamente.
    ///
    /// `limite_bloque` es `LIMITE(H)` de la cadena **en el momento de arrancar** (C-WGT-09). No es
    /// una constante: el tamaño de bloque de ZEROX crece con la mediana larga, y un límite de
    /// transporte fijo se convierte en una partición de red silenciosa en un par de años. Ver
    /// [`limites::limite_gossip`].
    ///
    /// Quien lo calcula es `zx-node`, que sí ve el estado de la cadena. Este crate solo aplica el
    /// margen.
    ///
    /// # Errores
    /// [`P2pError::Configuracion`] si algún nombre de protocolo o parámetro es inválido, o
    /// [`P2pError::MargenDeTransporteInsuficiente`] si el límite de bloque ya se ha acercado
    /// demasiado a lo que este binario puede transportar.
    pub fn nueva(
        clave: &identity::Keypair,
        p: ParametrosRed,
        limite_bloque: u64,
    ) -> Result<Self, P2pError> {
        Self::con_presupuesto(clave, p, limite_bloque, Presupuesto::default())
    }

    /// Igual, pero con un presupuesto de memoria concreto. Para tests que quieran agotarlo.
    ///
    /// # Errores
    /// Las de [`Self::nueva`].
    pub fn con_presupuesto(
        clave: &identity::Keypair,
        p: ParametrosRed,
        limite_bloque: u64,
        presupuesto: Presupuesto,
    ) -> Result<Self, P2pError> {
        let peer_id = clave.public().to_peer_id();

        // ── C-NET-11 · límites de conexión. El default es `None` en todos los campos. ──
        let limites = connection_limits::Behaviour::new(
            connection_limits::ConnectionLimits::default()
                .with_max_pending_incoming(Some(limites::MAX_CONEXIONES_PENDIENTES))
                .with_max_established_incoming(Some(limites::MAX_PEERS_ENTRANTES))
                .with_max_established_outgoing(Some(limites::MAX_PEERS_SALIENTES))
                .with_max_established_per_peer(Some(limites::MAX_CONEXIONES_POR_PEER))
                .with_max_established(Some(limites::MAX_CONEXIONES)),
        );

        let limites_ip = LimitesPorIp::nuevo();

        let identify = identify::Behaviour::new(
            identify::Config::new(p.protocolo_identify().to_owned(), clave.public())
                .with_agent_version(p.agent_version()),
        );

        let ping = ping::Behaviour::default();

        // ── C-NET-02 · protocolo propio. El default es la DHT PÚBLICA de IPFS. ──
        let proto_kad = StreamProtocol::try_from_owned(p.protocolo_kad().to_owned())
            .map_err(|_| P2pError::Configuracion("nombre de protocolo de Kademlia inválido"))?;
        let kademlia = kad::Behaviour::with_config(
            peer_id,
            kad::store::MemoryStore::new(peer_id),
            kad::Config::new(proto_kad),
        );

        // mDNS **solo en testnet**. En mainnet un nodo anunciaría por multicast su presencia a
        // todo el segmento L2 — que en un VPS barato o en un datacenter compartido significa
        // decirle a los vecinos "aquí corre un nodo ZEROX". Es fuga de información gratuita, y un
        // punto de partida barato para un eclipse: descubrir nodos sin pasar por Kademlia ni por
        // los bootstrap. En testnet es justo lo que se quiere: el arnés multinodo local depende de
        // que tres nodos se encuentren sin configurar nada.
        //
        // `dag-dev` tampoco lo activa: su descubrimiento lo fija el runner local, y anunciarse por
        // multicast en una máquina de desarrollo es ruido que no aporta nada.
        let mdns = match p.identidad() {
            IdentidadP2p::Publica(Red::Testnet) => Toggle::from(Some(
                mdns::tokio::Behaviour::new(mdns::Config::default(), peer_id)
                    .map_err(|_| P2pError::Configuracion("no se pudo iniciar mDNS"))?,
            )),
            IdentidadP2p::Publica(Red::Mainnet) | IdentidadP2p::DagDev => Toggle::from(None),
        };

        let mut gossipsub = Self::gossipsub(clave, limite_bloque)?;

        // ── C-NET-25 / C-NET-26 · la suscripción es exacta y es obligatoria ──
        //
        // Un `ConfigBuilder` sin `subscribe` deja el behaviour **suscrito a nada**: los mensajes
        // entrantes de `/blocks/2` y `/txs/1` no llegan al bucle, y publicar falla con
        // `NoPeersSubscribedToTopic`. Eso no falla al compilar y se manifiesta como una red que no
        // propaga nada.
        //
        // Se suscriben **exactamente dos temas**, los de esta red, ni uno más. **No** se suscribe
        // `/blocks/1`: C-NET-25 reserva `/blocks/2` a los anuncios compactos y prohíbe difundir el
        // bloque completo por gossip; tener los dos temas a la vez haría viajar dos veces lo mismo.
        //
        // Suscribirse **no admite mensajes**: el callback compacto sigue `Ignorar` —el default de
        // `ManejadorEntrante`— mientras `zx-node` no valide el DAG causal. El tema es transporte, no
        // validez (C-NET-12).
        for tema in [p.topic_bloques(), p.topic_txs()] {
            let t = gossipsub::IdentTopic::new(tema);
            // `Ok(true)` es "suscripción nueva", `Ok(false)` es "ya estaba". Un `Err` sí es un
            // fallo: el `subscription_filter` por defecto rechaza cualquier tema que no empiece por
            // `/`, así que un nombre mal escrito debe impedir arrancar en vez de dejar el nodo mudo.
            //
            // Se hace **antes** de construir el `Swarm`, de modo que el error sale por el tipo de
            // `ZxBehaviour::con_presupuesto` —[`P2pError::Configuracion`]— y no envuelto por el
            // builder de `SwarmBuilder`.
            gossipsub.subscribe(&t).map_err(|_| {
                P2pError::Configuracion("no se pudo suscribir a un tema de gossipsub")
            })?;
        }

        let proto_sync = StreamProtocol::try_from_owned(p.protocolo_sync().to_owned())
            .map_err(|_| P2pError::Configuracion("nombre de protocolo de sync inválido"))?;
        // El modo del códec sale del perfil, no de una bandera pública: `dag-dev` solo habla el
        // saludo `Estado` y rechaza en lectura y escritura las variantes lineales; mainnet/testnet
        // conservan el códec completo. `solo_estado` es `pub(crate)`, así que nadie externo puede
        // degradar el códec de una red pública.
        let codec = match p.identidad() {
            IdentidadP2p::DagDev => ZxCodec::solo_estado(presupuesto),
            IdentidadP2p::Publica(_) => ZxCodec::con_presupuesto(presupuesto),
        };
        let sync = request_response::Behaviour::with_codec(
            codec,
            [(proto_sync, request_response::ProtocolSupport::Full)],
            request_response::Config::default()
                // El default son 10 s. Un lote de bloques por un enlace lento no cabe en 10 s, y un
                // timeout corto se manifiesta como "los peers lentos no sirven nunca", que es
                // difícil de diagnosticar. 🔶 Medir en P-019, no adivinar más allá de esto.
                .with_request_timeout(TIMEOUT_SYNC)
                // El default son 100 streams concurrentes. Con respuestas de hasta
                // MAX_RESPUESTA_BYTES, 100 × 25,6 MB = 2,56 GB reservables **por peer**. Bajarlo es
                // la mitad de la mitigación de P-027; la otra mitad es un presupuesto agregado que
                // todavía no existe.
                .with_max_concurrent_streams(limites::MAX_STREAMS_SYNC),
        );

        Ok(Self {
            limites,
            limites_ip,
            identify,
            ping,
            kademlia,
            mdns,
            gossipsub,
            sync,
            parametros: ParametrosDelNodo::nuevos(p),
        })
    }

    /// Gossipsub con los dos defaults peligrosos corregidos.
    fn gossipsub(
        clave: &identity::Keypair,
        limite_bloque: u64,
    ) -> Result<gossipsub::Behaviour, P2pError> {
        // C-NET-13 · se comprueba ANTES de construir nada. El límite de gossipsub se fija al crear
        // el behaviour y no se puede cambiar en caliente, así que si ya vamos justos, arrancar sería
        // arrancar roto.
        //
        // `limite_gossip` devuelve `None` ante un límite de bloque absurdo, y eso también aborta:
        // un valor corrupto NO debe traducirse en un techo infinito.
        let techo = limites::limite_gossip(limite_bloque).ok_or(
            P2pError::MargenDeTransporteInsuficiente {
                limite_bloque,
                limite_transporte: 0,
            },
        )?;
        if !limites::margen_suficiente(limite_bloque, techo) {
            return Err(P2pError::MargenDeTransporteInsuficiente {
                limite_bloque,
                limite_transporte: techo,
            });
        }

        let cfg = gossipsub::ConfigBuilder::default()
            // C-NET-11 · el default son 65 536 B y un bloque típico mide 100-200 KB.
            // C-NET-13 · derivado de LIMITE(H), no una constante: el bloque crece con la mediana.
            .max_transmit_size(techo)
            // C-NET-12 · el default es `false`: reenviaría antes de que validemos.
            .validate_messages()
            // Exige firma y `PeerId` válido en cada mensaje.
            .validation_mode(gossipsub::ValidationMode::Strict)
            // El default identifica por (emisor, secuencia), NO por contenido: el mismo bloque
            // llegado por dos caminos contaría como dos mensajes distintos.
            .message_id_fn(id_por_contenido)
            .heartbeat_interval(HEARTBEAT)
            .mesh_n(MESH_N)
            .mesh_n_low(MESH_N_BAJO)
            .mesh_n_high(MESH_N_ALTO)
            .build()
            .map_err(|_| P2pError::Configuracion("configuración de gossipsub inválida"))?;

        gossipsub::Behaviour::new(gossipsub::MessageAuthenticity::Signed(clave.clone()), cfg)
            .map_err(|_| P2pError::Configuracion("no se pudo construir gossipsub"))
    }
}

/// Identifica un mensaje por el **tema exacto y su contenido**, no por quién lo mandó.
///
/// # Por qué el tema entra en el ID
///
/// El default de libp2p usa `(source_peer_id, sequence_number)`. Con él, el mismo bloque recibido
/// por dos rutas son dos mensajes distintos: se valida dos veces y se reenvía dos veces. Para una
/// cadena, donde el mismo bloque llega por muchos caminos, eso es desperdicio puro.
///
/// Pero hashear **solo** `SHA3(datos)` tiene un agujero: gossipsub deduplica por `message_id`, y dos
/// temas distintos pueden llevar los mismos bytes. Un tercero podía emitir primero en `/txs/1` unos
/// bytes arbitrarios —válidos como transacción para el codec— y consumir el `message_id` que después
/// tendría un anuncio legítimo en `/blocks/2`: el anuncio real se descartaría por «ya visto». Con el
/// tema dentro del hash, mismo tema + mismos bytes = mismo ID; mismos bytes + otro tema = ID
/// distinto.
///
/// # Coste y naturaleza
///
/// `SHA3(SHA3(tema) ‖ SHA3(datos))`: dos digests intermedios de 32 B (64 B fijos) y ningún buffer
/// proporcional al mensaje —los bytes del anuncio ya están en memoria, no se copian—. Se usa
/// [`zx_core::sha3_256_publico`], la primitiva ya adoptada por el crate.
///
/// ⚠️ **Esto es un identificador de transporte, no un hash de consenso.** No entra en un `txid`, ni
/// en un `sighash`, ni en un hash de bloque: sirve solo para que gossipsub deduplique y no tiene
/// reglas de dominio. Por eso puede usar SHA3 desnudo (C-HASH-04 sería obligatorio si fuera
/// preimagen de consenso).
fn id_por_contenido(m: &gossipsub::Message) -> gossipsub::MessageId {
    let tema = zx_core::sha3_256_publico(m.topic.as_str().as_bytes());
    let datos = zx_core::sha3_256_publico(&m.data);
    let mut intermedio = [0u8; 64];
    intermedio[..32].copy_from_slice(tema.as_bytes());
    intermedio[32..].copy_from_slice(datos.as_bytes());
    gossipsub::MessageId::from(*zx_core::sha3_256_publico(&intermedio).as_bytes())
}

#[cfg(test)]
#[expect(clippy::unwrap_used, reason = "los tests fallan con panic por diseño")]
mod tests {
    use super::{
        MESH_N, MESH_N_ALTO, MESH_N_BAJO, ParametrosDelNodo, ZxBehaviour, id_por_contenido,
    };
    use crate::config::ParametrosRed;
    use crate::error::P2pError;
    use crate::limites;
    use libp2p::swarm::NetworkBehaviour;
    use libp2p::{PeerId, gossipsub, identity};
    use zx_core::red::Red;

    fn clave() -> identity::Keypair {
        identity::Keypair::generate_ed25519()
    }

    /// Necesita runtime de tokio: `mdns::tokio::Behaviour` abre un socket netlink al construirse.
    #[tokio::test]
    async fn se_construye_en_las_dos_redes() {
        for red in [Red::Mainnet, Red::Testnet] {
            assert!(
                ZxBehaviour::nueva(
                    &clave(),
                    ParametrosRed::de(red),
                    limites::LIMITE_BLOQUE_GENESIS
                )
                .is_ok(),
                "{red:?}"
            );
        }
    }

    /// **`dag-dev` construye un behaviour con sync, temas, identify y mDNS propios.**
    ///
    /// Esto comprueba **configuración, no entrega**: que los dos temas suscritos son exactamente los
    /// dev y que no se suscribe ninguno de mainnet/testnet, que el protocolo de sync es el dev, que
    /// el `identify` es dev y que mDNS está apagado. Que la suscripción exista no acredita que un
    /// mensaje llegue al callback (C-NET-12): hoy sigue siendo `Ignorar` mientras `zx-node` no
    /// valide el DAG causal.
    #[tokio::test]
    async fn dag_dev_construye_con_sync_temas_propios_y_sin_mdns() {
        let p = ParametrosRed::dag_dev();
        let b = ZxBehaviour::nueva(&clave(), p, limites::LIMITE_BLOQUE_GENESIS).unwrap();

        assert_eq!(
            b.parametros_de_red().protocolo_sync(),
            "/zerox-dag-dev/sync/1"
        );
        assert_eq!(
            b.parametros_de_red().protocolo_identify(),
            "/zerox-dag-dev/id/1"
        );
        assert!(!b.mdns.is_enabled(), "dag-dev MUST NOT usar mDNS");

        let temas: Vec<String> = b.gossipsub.topics().map(ToString::to_string).collect();
        assert_eq!(temas.len(), 2, "se suscriben exactamente dos temas");
        assert!(temas.contains(&p.topic_bloques().to_owned()));
        assert!(temas.contains(&p.topic_txs().to_owned()));
        for ajeno in [
            "/zerox/blocks/2",
            "/zerox/txs/1",
            "/zerox-testnet/blocks/2",
            "/zerox-testnet/txs/1",
            "/zerox/blocks/1",
            "/zerox-testnet/blocks/1",
        ] {
            assert!(
                !temas.iter().any(|t| t == ajeno),
                "tema ajeno suscrito en dag-dev: {ajeno}"
            );
        }
    }

    /// **C-NET-11 + C-NET-25.** El mismo tema y los mismos bytes dan el mismo id; cambia el tema o
    /// cambian los datos y cambia el id.
    ///
    /// Con el default de libp2p —`(emisor, secuencia)`— la primera afirmación sería **falsa**: el
    /// mismo bloque llegado de dos peers tendría dos ids y se procesaría dos veces. Por eso aquí los
    /// dos mensajes iguales llevan **emisores distintos**: es la única forma de que la prueba
    /// ejercite la independencia del emisor. Y hashear solo los datos permitiría que unos bytes en
    /// `/txs/1` consumieran el id de un anuncio en `/blocks/2`.
    #[test]
    fn el_id_de_mensaje_depende_del_tema_y_del_contenido() {
        let emisor_a = clave().public().to_peer_id();
        let emisor_b = clave().public().to_peer_id();
        assert_ne!(
            emisor_a, emisor_b,
            "hacen falta dos emisores distintos para probar la independencia"
        );

        let mensaje = |tema: &str, datos: &[u8], source: PeerId| gossipsub::Message {
            source: Some(source),
            data: datos.to_vec(),
            sequence_number: None,
            topic: gossipsub::IdentTopic::new(tema).hash(),
        };

        // Mismo tema + mismos bytes = un solo id, **aunque cambie el emisor**.
        let a = id_por_contenido(&mensaje("/zerox/blocks/2", b"bloque", emisor_a));
        let b = id_por_contenido(&mensaje("/zerox/blocks/2", b"bloque", emisor_b));
        assert_eq!(
            a, b,
            "mismo tema y bytes desde emisores distintos: es UN mensaje"
        );

        // Mismo tema, otros datos.
        let c = id_por_contenido(&mensaje("/zerox/blocks/2", b"otro bloque", emisor_a));
        assert_ne!(a, c, "datos distintos, id distinto");

        // **Los mismos bytes en otro tema no colisionan.**
        let t = id_por_contenido(&mensaje("/zerox/txs/1", b"bloque", emisor_a));
        assert_ne!(
            a, t,
            "mismos bytes en /txs/1 MUST NOT consumir el id del anuncio"
        );
        let t2 = id_por_contenido(&mensaje("/zerox-testnet/blocks/2", b"bloque", emisor_b));
        assert_ne!(a, t2, "mismos bytes en otra red, id distinto");
    }

    /// **`ParametrosDelNodo` es inerte: no emite tráfico ni eventos.**
    ///
    /// Existe solo para llevar [`ParametrosRed`] dentro del `#[derive(NetworkBehaviour)]`. Su
    /// `ToSwarm` es [`std::convert::Infallible`] —el tipo de evento no tiene valores— y su
    /// `ConnectionHandler` es el `dummy` de libp2p, que no negocia ningún protocolo; `poll` devuelve
    /// `Pending` siempre. Sin esta comprobación, un cambio futuro podría darle tráfico propio sin que
    /// ningún test lo notara.
    #[test]
    fn parametros_del_nodo_no_emite_trafico_ni_eventos() {
        use libp2p::swarm::dummy;
        use std::task::{Context, Poll};

        // Si el handler dejara de ser el `dummy`, esta asignación no compilaría.
        let _: <ParametrosDelNodo as NetworkBehaviour>::ConnectionHandler =
            dummy::ConnectionHandler;

        let mut p = ParametrosDelNodo::nuevos(ParametrosRed::de(Red::Testnet));
        let waker = futures::task::noop_waker();
        let mut cx = Context::from_waker(&waker);
        assert!(
            matches!(p.poll(&mut cx), Poll::Pending),
            "un behaviour sin tráfico no puede producir eventos"
        );
    }

    /// El id es un SHA3-256 completo: 32 bytes, no un truncado.
    #[test]
    fn el_id_de_mensaje_mide_32_bytes() {
        let m = gossipsub::Message {
            source: None,
            data: b"x".to_vec(),
            sequence_number: None,
            topic: gossipsub::IdentTopic::new("/zerox/blocks/2").hash(),
        };
        assert_eq!(id_por_contenido(&m).0.len(), 32);
    }

    /// **C-NET-25 · la suscripción es exacta: los dos temas de la red, ni uno más.**
    ///
    /// Sin `subscribe`, el behaviour queda mudo y publicar falla. Con un tema de más —`/blocks/1`—
    /// se duplica tráfico y se reabre el canal que C-NET-25 prohíbe. Este test es el único que ve
    /// ese error antes de producción.
    #[tokio::test]
    async fn la_suscripcion_son_los_dos_temas_exactos_de_la_red() {
        for red in [Red::Mainnet, Red::Testnet] {
            let p = ParametrosRed::de(red);
            let b = ZxBehaviour::nueva(&clave(), p, limites::LIMITE_BLOQUE_GENESIS).unwrap();
            let temas: Vec<String> = b.gossipsub.topics().map(ToString::to_string).collect();

            assert_eq!(
                temas.len(),
                2,
                "{red:?}: se suscriben exactamente dos temas"
            );
            assert!(
                temas.contains(&p.topic_bloques().to_owned()),
                "{red:?}: falta {}",
                p.topic_bloques()
            );
            assert!(
                temas.contains(&p.topic_txs().to_owned()),
                "{red:?}: falta {}",
                p.topic_txs()
            );
            assert!(
                !temas.iter().any(|t| t.contains("/blocks/1")),
                "{red:?}: C-NET-25 prohíbe suscribir /blocks/1"
            );
        }
    }

    /// **Los dos temas suscritos son de la red pedida, no de la otra.**
    #[tokio::test]
    async fn ningun_tema_suscrito_viene_de_la_otra_red() {
        let m = ParametrosRed::de(Red::Mainnet);
        let bm = ZxBehaviour::nueva(&clave(), m, limites::LIMITE_BLOQUE_GENESIS).unwrap();
        for t in bm.gossipsub.topics() {
            assert!(!t.to_string().contains("testnet"), "mainnet: {t}");
        }

        let t = ParametrosRed::de(Red::Testnet);
        let bt = ZxBehaviour::nueva(&clave(), t, limites::LIMITE_BLOQUE_GENESIS).unwrap();
        for tema in bt.gossipsub.topics() {
            assert!(tema.to_string().contains("testnet"), "testnet: {tema}");
        }
    }

    /// **C-NET-11.** La malla es 8/6/12, no el 6/5/12 de fábrica, y es coherente.
    #[test]
    fn la_malla_es_la_de_produccion_y_no_la_de_fabrica() {
        assert_eq!((MESH_N, MESH_N_BAJO, MESH_N_ALTO), (8, 6, 12));
        assert_ne!(MESH_N, 6, "6 es el default de libp2p");
    }

    /// **C-NET-14.** mDNS está en testnet y **NO** en mainnet.
    ///
    /// Un nodo de mainnet con mDNS anuncia por multicast su presencia a todo su segmento L2 — en un
    /// VPS barato o un datacenter compartido, eso es decirle a los vecinos "aquí corre un nodo
    /// ZEROX". Fuga gratis, y punto de partida barato para un eclipse.
    #[tokio::test]
    async fn mdns_solo_esta_en_testnet() {
        let t = ZxBehaviour::nueva(
            &clave(),
            ParametrosRed::de(Red::Testnet),
            limites::LIMITE_BLOQUE_GENESIS,
        )
        .unwrap();
        assert!(
            t.mdns.is_enabled(),
            "testnet lo necesita para el arnés local"
        );

        let m = ZxBehaviour::nueva(
            &clave(),
            ParametrosRed::de(Red::Mainnet),
            limites::LIMITE_BLOQUE_GENESIS,
        )
        .unwrap();
        assert!(
            !m.mdns.is_enabled(),
            "C-NET-14: mainnet MUST NOT anunciarse por multicast"
        );
    }

    /// **C-NET-13.** Sin margen de transporte, el behaviour **no se construye**.
    ///
    /// Es lo que convierte una partición silenciosa en una negativa a arrancar.
    #[tokio::test]
    async fn sin_margen_de_transporte_no_se_construye() {
        // Escribir este test destapó un fallo: la primera versión saturaba el techo a `usize::MAX`
        // ante un límite absurdo, o sea **desactivaba** el límite de transporte en vez de abortar.
        for absurdo in [u64::MAX, limites::LIMITE_BLOQUE_ABSURDO + 1, 0] {
            let e = ZxBehaviour::nueva(&clave(), ParametrosRed::de(Red::Testnet), absurdo);
            assert!(
                matches!(e, Err(P2pError::MargenDeTransporteInsuficiente { .. })),
                "un límite de bloque de {absurdo} MUST impedir construir el behaviour"
            );
        }
        // Y un límite realista sí construye.
        assert!(
            ZxBehaviour::nueva(
                &clave(),
                ParametrosRed::de(Red::Testnet),
                limites::LIMITE_BLOQUE_GENESIS
            )
            .is_ok()
        );
    }

    /// La identidad de `identify` es de ZEROX y nombra la red.
    #[test]
    fn identify_anuncia_zerox_y_no_la_libreria() {
        for p in [
            ParametrosRed::de(Red::Mainnet),
            ParametrosRed::de(Red::Testnet),
            ParametrosRed::dag_dev(),
        ] {
            assert!(p.protocolo_identify().starts_with("/zerox"), "{p:?}");
            let v = p.agent_version();
            assert!(v.starts_with("zerox/"), "{v}");
            assert!(
                !v.contains("rust-libp2p"),
                "el default delata la librería: {v}"
            );
        }
    }
}
