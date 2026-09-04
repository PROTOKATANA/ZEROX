//! Parámetros de red por cadena (SPEC §16, C-NET-01, C-NET-02).
//!
//! # Lo que de verdad aísla dos redes
//!
//! No es el hash del génesis: es el **prefijo mágico**. El génesis distinto (C-GEN-04) evita que
//! las cadenas se confundan una vez conectadas; el prefijo evita que los nodos **se saluden
//! siquiera**. Son dos defensas a alturas distintas y ninguna sustituye a la otra.
//!
//! # Los nombres de protocolo NO son cosmética
//!
//! `kad::Config::default()` usa `/ipfs/kad/1.0.0` — la DHT **pública de IPFS** — y no falla al
//! compilar. Verificado en `rust-libp2p@v0.56.0`, `protocols/kad/src/behaviour.rs:196-241`. Un nodo
//! con ese valor o habla con IPFS o no descubre a nadie, según tenga salida a internet. Por eso
//! todos los nombres se derivan de [`ParametrosRed`] y ninguno se deja por defecto.

use zx_core::red::Red;

/// Puerto por defecto de mainnet (C-NET-02).
pub const PUERTO_MAINNET: u16 = 9833;

/// Puerto por defecto de testnet (C-NET-02).
pub const PUERTO_TESTNET: u16 = 19833;

/// Parámetros de red de una cadena.
///
/// Se construye siempre desde una [`Red`], nunca campo a campo: así no existe la combinación
/// "prefijo de mainnet con puerto de testnet".
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct ParametrosRed {
    /// La red a la que pertenecen.
    pub red: Red,
    /// Prefijo mágico de 4 bytes (C-NET-01).
    pub magic: [u8; 4],
    /// Puerto TCP/QUIC por defecto (C-NET-02).
    pub puerto: u16,
    /// Tópico de gossipsub para bloques.
    pub topic_bloques: &'static str,
    /// Tópico de gossipsub para transacciones.
    pub topic_txs: &'static str,
    /// Protocolo de request-response para sincronización.
    pub protocolo_sync: &'static str,
    /// Protocolo de Kademlia. **Nunca el de IPFS.**
    pub protocolo_kad: &'static str,
}

impl ParametrosRed {
    /// Los parámetros de una red.
    #[must_use]
    pub const fn de(red: Red) -> Self {
        match red {
            Red::Mainnet => Self {
                red,
                magic: red.magic(),
                puerto: PUERTO_MAINNET,
                topic_bloques: "/zerox/blocks/1",
                topic_txs: "/zerox/txs/1",
                protocolo_sync: "/zerox/sync/1",
                protocolo_kad: "/zerox/kad/1",
            },
            Red::Testnet => Self {
                red,
                magic: red.magic(),
                puerto: PUERTO_TESTNET,
                topic_bloques: "/zerox-testnet/blocks/1",
                topic_txs: "/zerox-testnet/txs/1",
                protocolo_sync: "/zerox-testnet/sync/1",
                protocolo_kad: "/zerox-testnet/kad/1",
            },
        }
    }

    /// La cadena de `agent_version` que anuncia `identify`.
    ///
    /// El default de libp2p es `rust-libp2p/<versión>`, que dice qué librería usamos y nada sobre
    /// qué red somos. Este dice lo segundo, que es lo útil para un operador leyendo logs.
    #[must_use]
    pub fn agent_version(&self) -> String {
        format!("zerox/{}/{}", env!("CARGO_PKG_VERSION"), self.red.nombre())
    }
}

#[cfg(test)]
mod tests {
    use super::ParametrosRed;
    use zx_core::red::Red;

    /// Los prefijos que expone la config son los de la red, no una copia.
    ///
    /// La **derivación** de los prefijos se comprueba en `zx-core::red`, donde viven. Aquí solo se
    /// comprueba que la config no los reescriba por su cuenta, que es el fallo que ocurriría si
    /// alguien volviera a copiarlos.
    #[test]
    fn los_prefijos_vienen_de_la_red_y_no_de_una_copia() {
        for red in [Red::Mainnet, Red::Testnet] {
            assert_eq!(ParametrosRed::de(red).magic, red.magic(), "{red:?}");
        }
    }

    /// Nada se comparte entre redes. Si algo coincidiera, los nodos podrían cruzarse.
    #[test]
    fn ninguna_red_comparte_nada_con_la_otra() {
        let m = ParametrosRed::de(Red::Mainnet);
        let t = ParametrosRed::de(Red::Testnet);

        assert_ne!(m.magic, t.magic);
        assert_ne!(m.puerto, t.puerto);
        assert_ne!(m.topic_bloques, t.topic_bloques);
        assert_ne!(m.topic_txs, t.topic_txs);
        assert_ne!(m.protocolo_sync, t.protocolo_sync);
        assert_ne!(m.protocolo_kad, t.protocolo_kad);
        assert_ne!(m.agent_version(), t.agent_version());
    }

    /// **El nombre de Kademlia MUST NOT ser el de IPFS.**
    ///
    /// `kad::Config::default()` usa `/ipfs/kad/1.0.0` y no falla al compilar. Este test es el único
    /// sitio donde ese error se hace visible antes de producción.
    #[test]
    fn kademlia_nunca_usa_el_protocolo_de_ipfs() {
        for red in [Red::Mainnet, Red::Testnet] {
            let p = ParametrosRed::de(red);
            assert!(
                p.protocolo_kad.starts_with("/zerox"),
                "{:?}: el protocolo de Kademlia MUST ser propio, no {}",
                red,
                p.protocolo_kad
            );
            assert!(!p.protocolo_kad.contains("ipfs"));
        }
    }

    /// Todos los protocolos empiezan por `/`: libp2p lo exige en `StreamProtocol::new`.
    #[test]
    fn los_nombres_de_protocolo_tienen_la_forma_que_libp2p_exige() {
        for red in [Red::Mainnet, Red::Testnet] {
            let p = ParametrosRed::de(red);
            for nombre in [
                p.topic_bloques,
                p.topic_txs,
                p.protocolo_sync,
                p.protocolo_kad,
            ] {
                assert!(nombre.starts_with('/'), "{nombre} debe empezar por /");
                assert!(!nombre.ends_with('/'), "{nombre} no debe acabar en /");
            }
        }
    }
}
