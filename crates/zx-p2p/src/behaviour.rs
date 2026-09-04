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
    StreamProtocol, connection_limits, gossipsub, identify, identity, kad, mdns, ping,
    swarm::NetworkBehaviour,
};

use crate::config::ParametrosRed;
use crate::error::P2pError;
use crate::limites;

/// Versión del protocolo que anuncia `identify`.
///
/// No se comparte entre redes: forma parte de [`ParametrosRed::protocolo_sync`] la identidad real,
/// pero esta cadena es lo que ve un operador al inspeccionar un peer.
const PROTOCOLO_IDENTIFY: &str = "/zerox/id/1";

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
    /// Rechaza conexiones por encima de los límites. **Primero en la lista a propósito**: los
    /// behaviours se consultan en orden de declaración, así que rechazar antes de que los demás
    /// hagan trabajo es más barato.
    pub limites: connection_limits::Behaviour,
    /// Intercambio de direcciones y protocolos soportados.
    pub identify: identify::Behaviour,
    /// Detecta peers muertos, y **mantiene viva** la conexión frente al `idle_connection_timeout`
    /// de 10 s, que es demasiado corto para un enlace de sincronización con huecos.
    pub ping: ping::Behaviour,
    /// Descubrimiento por DHT.
    pub kademlia: kad::Behaviour<kad::store::MemoryStore>,
    /// Descubrimiento en LAN. Es lo que hace utilizable el arnés multinodo local.
    pub mdns: mdns::tokio::Behaviour,
    /// Difusión de bloques y transacciones.
    pub gossipsub: gossipsub::Behaviour,
}

impl ZxBehaviour {
    /// Construye la composición con **todos** los límites de C-NET-11 fijados explícitamente.
    ///
    /// # Errores
    /// [`P2pError::Configuracion`] si algún nombre de protocolo o parámetro es inválido. Solo puede
    /// ocurrir con una [`ParametrosRed`] mal formada, y hay tests que lo cubren.
    pub fn nueva(clave: &identity::Keypair, p: ParametrosRed) -> Result<Self, P2pError> {
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

        let identify = identify::Behaviour::new(
            identify::Config::new(PROTOCOLO_IDENTIFY.to_owned(), clave.public())
                .with_agent_version(p.agent_version()),
        );

        let ping = ping::Behaviour::default();

        // ── C-NET-02 · protocolo propio. El default es la DHT PÚBLICA de IPFS. ──
        let proto_kad = StreamProtocol::try_from_owned(p.protocolo_kad.to_owned())
            .map_err(|_| P2pError::Configuracion("nombre de protocolo de Kademlia inválido"))?;
        let kademlia = kad::Behaviour::with_config(
            peer_id,
            kad::store::MemoryStore::new(peer_id),
            kad::Config::new(proto_kad),
        );

        let mdns = mdns::tokio::Behaviour::new(mdns::Config::default(), peer_id)
            .map_err(|_| P2pError::Configuracion("no se pudo iniciar mDNS"))?;

        let gossipsub = Self::gossipsub(clave)?;

        Ok(Self {
            limites,
            identify,
            ping,
            kademlia,
            mdns,
            gossipsub,
        })
    }

    /// Gossipsub con los dos defaults peligrosos corregidos.
    fn gossipsub(clave: &identity::Keypair) -> Result<gossipsub::Behaviour, P2pError> {
        let cfg = gossipsub::ConfigBuilder::default()
            // C-NET-11 · el default son 65 536 B y un bloque típico mide 100-200 KB.
            .max_transmit_size(limites::MAX_GOSSIP_BYTES)
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

/// Identifica un mensaje por el **hash de su contenido**, no por quién lo mandó.
///
/// El default de libp2p usa `(source_peer_id, sequence_number)`. Con él, el mismo bloque recibido
/// por dos rutas son dos mensajes distintos: se valida dos veces y se reenvía dos veces. Para una
/// cadena, donde el mismo bloque llega por muchos caminos, eso es desperdicio puro.
fn id_por_contenido(m: &gossipsub::Message) -> gossipsub::MessageId {
    gossipsub::MessageId::from(*zx_core::sha3_256_publico(&m.data).as_bytes())
}

#[cfg(test)]
mod tests {
    use super::{
        MESH_N, MESH_N_ALTO, MESH_N_BAJO, PROTOCOLO_IDENTIFY, ZxBehaviour, id_por_contenido,
    };
    use crate::config::ParametrosRed;
    use libp2p::{gossipsub, identity};
    use zx_core::red::Red;

    fn clave() -> identity::Keypair {
        identity::Keypair::generate_ed25519()
    }

    /// Necesita runtime de tokio: `mdns::tokio::Behaviour` abre un socket netlink al construirse.
    #[tokio::test]
    async fn se_construye_en_las_dos_redes() {
        for red in [Red::Mainnet, Red::Testnet] {
            assert!(
                ZxBehaviour::nueva(&clave(), ParametrosRed::de(red)).is_ok(),
                "{red:?}"
            );
        }
    }

    /// **C-NET-11.** El mismo contenido da el mismo id; contenido distinto, id distinto.
    ///
    /// Con el default de libp2p —`(emisor, secuencia)`— la primera afirmación sería **falsa**: el
    /// mismo bloque llegado de dos peers tendría dos ids y se procesaría dos veces.
    #[test]
    fn el_id_de_mensaje_depende_del_contenido_y_no_del_emisor() {
        let mensaje = |datos: &[u8]| gossipsub::Message {
            source: None,
            data: datos.to_vec(),
            sequence_number: None,
            topic: gossipsub::IdentTopic::new("/zerox/blocks/1").hash(),
        };

        let a = id_por_contenido(&mensaje(b"bloque"));
        let b = id_por_contenido(&mensaje(b"bloque"));
        let c = id_por_contenido(&mensaje(b"otro bloque"));

        assert_eq!(a, b, "el mismo bloque por dos rutas es UN mensaje");
        assert_ne!(a, c);
    }

    /// El id es un SHA3-256 completo: 32 bytes, no un truncado.
    #[test]
    fn el_id_de_mensaje_mide_32_bytes() {
        let m = gossipsub::Message {
            source: None,
            data: b"x".to_vec(),
            sequence_number: None,
            topic: gossipsub::IdentTopic::new("/zerox/blocks/1").hash(),
        };
        assert_eq!(id_por_contenido(&m).0.len(), 32);
    }

    /// **C-NET-11.** La malla es 8/6/12, no el 6/5/12 de fábrica, y es coherente.
    #[test]
    fn la_malla_es_la_de_produccion_y_no_la_de_fabrica() {
        assert_eq!((MESH_N, MESH_N_BAJO, MESH_N_ALTO), (8, 6, 12));
        assert_ne!(MESH_N, 6, "6 es el default de libp2p");
    }

    /// La identidad de `identify` es de ZEROX y nombra la red.
    #[test]
    fn identify_anuncia_zerox_y_no_la_libreria() {
        assert!(PROTOCOLO_IDENTIFY.starts_with("/zerox/"));
        for red in [Red::Mainnet, Red::Testnet] {
            let v = ParametrosRed::de(red).agent_version();
            assert!(v.starts_with("zerox/"), "{v}");
            assert!(
                !v.contains("rust-libp2p"),
                "el default delata la librería: {v}"
            );
        }
    }
}
