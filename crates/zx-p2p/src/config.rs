//! Parámetros de red por cadena (SPEC §16, C-NET-01, C-NET-02).
//!
//! # Los nombres de protocolo NO son cosmética
//!
//! `kad::Config::default()` usa `/ipfs/kad/1.0.0` — la DHT **pública de IPFS** — y no falla al
//! compilar. Verificado en `rust-libp2p@v0.56.0`, `protocols/kad/src/behaviour.rs:196-241`. Por eso
//! todos los nombres se derivan de [`ParametrosRed`] y ninguno se deja por defecto.
//!
//! # Aislamiento de red
//!
//! C-NET-01 exige que todo mensaje del protocolo P2P vaya precedido de un prefijo mágico de 4 bytes
//! propio de la red. El `magic` sigue siendo **metadato** (no se escribe en el wire): el aislamiento
//! real de los mensajes de aplicación se apoya en protocolos y temas distintos, y el saludo
//! [`crate::mensaje::Estado`] coteja `hash_genesis` y `red` para cortar la conexión cruzada.
//!
//! # La red dev de 0.0.1
//!
//! [`ParametrosRed::dag_dev`] construye el perfil de desarrollo: protocolo `/zx-dev/1` y **dos**
//! temas de gossip, `/zx-dev/bloques/pow/1` y `/zx-dev/bloques/post/1`, ambos con el bloque completo.
//! El relé compacto (BIP 152) no se porta en 0.0.1.

use zx_core::red::Red;

/// Puerto por defecto de mainnet (C-NET-02).
pub const PUERTO_MAINNET: u16 = 9833;

/// Puerto por defecto de testnet (C-NET-02).
pub const PUERTO_TESTNET: u16 = 19833;

/// Parámetros de red de una cadena.
///
/// # Los campos son privados, y eso es la garantía (C-NET-15)
///
/// El único constructor es [`ParametrosRed::de`], así que **no existe** la combinación "me
/// identifico como mainnet pero hablo el prefijo de testnet". Con los campos públicos esa
/// combinación se podía escribir con un literal de struct y el compilador la aceptaba sin
/// rechistar.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct ParametrosRed {
    red: Red,
    puerto: u16,
    topic_pow: &'static str,
    topic_post: &'static str,
    protocolo_sync: &'static str,
    protocolo_kad: &'static str,
    protocolo_identify: &'static str,
}

impl ParametrosRed {
    /// La red de estos parámetros.
    #[must_use]
    pub const fn red(&self) -> Red {
        self.red
    }

    /// Prefijo mágico de 4 bytes (C-NET-01).
    ///
    /// ⚠️ Hoy es **metadato**: no está en el wire y no aísla por sí solo.
    #[must_use]
    pub const fn magic(&self) -> [u8; 4] {
        self.red.magic()
    }

    /// Puerto TCP/QUIC por defecto (C-NET-02). En dev es `0` (efímero).
    #[must_use]
    pub const fn puerto(&self) -> u16 {
        self.puerto
    }

    /// Tópico de gossipsub para **bloques PoW completos**.
    #[must_use]
    pub const fn topic_bloques_pow(&self) -> &'static str {
        self.topic_pow
    }

    /// Tópico de gossipsub para **bloques PoST completos**.
    #[must_use]
    pub const fn topic_bloques_post(&self) -> &'static str {
        self.topic_post
    }

    /// Protocolo de request-response para sincronización.
    #[must_use]
    pub const fn protocolo_sync(&self) -> &'static str {
        self.protocolo_sync
    }

    /// Protocolo de Kademlia. **Nunca el de IPFS.**
    #[must_use]
    pub const fn protocolo_kad(&self) -> &'static str {
        self.protocolo_kad
    }

    /// Protocolo del handshake `identify`.
    #[must_use]
    pub const fn protocolo_identify(&self) -> &'static str {
        self.protocolo_identify
    }

    /// Los parámetros de una red. Único constructor.
    #[must_use]
    pub const fn de(red: Red) -> Self {
        match red {
            Red::Mainnet => Self {
                red,
                puerto: PUERTO_MAINNET,
                topic_pow: "/zerox/bloques/pow/1",
                topic_post: "/zerox/bloques/post/1",
                protocolo_sync: "/zerox/sync/1",
                protocolo_kad: "/zerox/kad/1",
                protocolo_identify: "/zerox/id/1",
            },
            Red::Testnet => Self {
                red,
                puerto: PUERTO_TESTNET,
                topic_pow: "/zerox-testnet/bloques/pow/1",
                topic_post: "/zerox-testnet/bloques/post/1",
                protocolo_sync: "/zerox-testnet/sync/1",
                protocolo_kad: "/zerox-testnet/kad/1",
                protocolo_identify: "/zerox/id/1",
            },
            Red::Dev => Self {
                red,
                puerto: 0,
                topic_pow: "/zx-dev/bloques/pow/1",
                topic_post: "/zx-dev/bloques/post/1",
                protocolo_sync: "/zx-dev/1",
                protocolo_kad: "/zx-dev/kad/1",
                protocolo_identify: "/zx-dev/id/1",
            },
        }
    }

    /// Perfil de **desarrollo** de la red dev de 0.0.1. Sin parámetros libres.
    ///
    /// Todos los valores son solo para desarrollo: puerto `0` (efímero/loopback que el runner
    /// decide), temas y protocolos bajo `/zx-dev/...` y `agent_version` `zerox/<versión>/dev`. No
    /// son parámetros de consenso ni de lanzamiento.
    #[must_use]
    pub const fn dag_dev() -> Self {
        Self::de(Red::Dev)
    }

    /// La cadena de `agent_version` que anuncia `identify`.
    ///
    /// El default de libp2p es `rust-libp2p/<versión>`, que dice qué librería usamos y nada sobre
    /// qué red somos.
    #[must_use]
    pub fn agent_version(&self) -> String {
        format!("zerox/{}/{}", env!("CARGO_PKG_VERSION"), self.red.nombre())
    }
}

#[cfg(test)]
mod tests {
    use super::{PUERTO_MAINNET, PUERTO_TESTNET, ParametrosRed};
    use zx_core::red::Red;

    /// Los prefijos que expone la config son los de la red, no una copia.
    #[test]
    fn los_prefijos_vienen_de_la_red_y_no_de_una_copia() {
        for red in [Red::Mainnet, Red::Testnet, Red::Dev] {
            assert_eq!(ParametrosRed::de(red).magic(), red.magic(), "{red:?}");
        }
    }

    /// Nada se comparte entre mainnet y testnet.
    #[test]
    fn ninguna_red_comparte_nada_con_la_otra() {
        let m = ParametrosRed::de(Red::Mainnet);
        let t = ParametrosRed::de(Red::Testnet);

        assert_ne!(m.magic(), t.magic());
        assert_ne!(m.puerto(), t.puerto());
        assert_ne!(m.topic_bloques_pow(), t.topic_bloques_pow());
        assert_ne!(m.topic_bloques_post(), t.topic_bloques_post());
        assert_ne!(m.protocolo_sync(), t.protocolo_sync());
        assert_ne!(m.protocolo_kad(), t.protocolo_kad());
        assert_ne!(m.agent_version(), t.agent_version());
    }

    /// **La red dev no comparte nada con las públicas.**
    #[test]
    fn la_red_dev_no_comparte_nada_con_las_publicas() {
        let dev = ParametrosRed::dag_dev();
        assert_eq!(dev.red(), Red::Dev);
        assert_eq!(dev.protocolo_sync(), "/zx-dev/1");

        for red in [Red::Mainnet, Red::Testnet] {
            let p = ParametrosRed::de(red);
            assert_ne!(dev.magic(), p.magic(), "{red:?}");
            assert_ne!(dev.puerto(), p.puerto(), "{red:?}");
            assert_ne!(dev.topic_bloques_pow(), p.topic_bloques_pow(), "{red:?}");
            assert_ne!(dev.topic_bloques_post(), p.topic_bloques_post(), "{red:?}");
            assert_ne!(dev.protocolo_sync(), p.protocolo_sync(), "{red:?}");
            assert_ne!(dev.protocolo_kad(), p.protocolo_kad(), "{red:?}");
            assert_ne!(dev.protocolo_identify(), p.protocolo_identify(), "{red:?}");
            assert_ne!(dev.agent_version(), p.agent_version(), "{red:?}");
        }
    }

    /// **Mainnet y testnet conservan sus puertos.** Red de seguridad contra un cambio de perfil.
    #[test]
    fn mainnet_y_testnet_conservan_sus_puertos() {
        assert_eq!(ParametrosRed::de(Red::Mainnet).puerto(), PUERTO_MAINNET);
        assert_eq!(ParametrosRed::de(Red::Testnet).puerto(), PUERTO_TESTNET);
    }

    /// **La red dev usa los temas y el protocolo que fija la orden.**
    #[test]
    fn la_red_dev_usa_los_nombres_de_la_orden() {
        let dev = ParametrosRed::dag_dev();
        assert_eq!(dev.topic_bloques_pow(), "/zx-dev/bloques/pow/1");
        assert_eq!(dev.topic_bloques_post(), "/zx-dev/bloques/post/1");
        assert_eq!(dev.protocolo_sync(), "/zx-dev/1");
        assert_eq!(dev.protocolo_identify(), "/zx-dev/id/1");
        assert_eq!(dev.puerto(), 0);
    }

    /// Cada perfil tiene **dos** temas de bloque distintos entre sí.
    #[test]
    fn cada_perfil_tiene_sus_dos_temas_y_no_hay_suscripcion_cruzada() {
        let perfiles = [
            ParametrosRed::de(Red::Mainnet),
            ParametrosRed::de(Red::Testnet),
            ParametrosRed::dag_dev(),
        ];
        for p in perfiles {
            assert_ne!(
                p.topic_bloques_pow(),
                p.topic_bloques_post(),
                "{:?}",
                p.red()
            );
        }

        let mut todos = Vec::new();
        for p in perfiles {
            todos.push(p.topic_bloques_pow());
            todos.push(p.topic_bloques_post());
        }
        todos.sort_unstable();
        let antes = todos.len();
        todos.dedup();
        assert_eq!(antes, todos.len(), "hay un tema compartido entre perfiles");
    }

    /// **El nombre de Kademlia MUST NOT ser el de IPFS.**
    #[test]
    fn kademlia_nunca_usa_el_protocolo_de_ipfs() {
        for p in [
            ParametrosRed::de(Red::Mainnet),
            ParametrosRed::de(Red::Testnet),
            ParametrosRed::dag_dev(),
        ] {
            assert!(
                p.protocolo_kad().starts_with("/zerox") || p.protocolo_kad().starts_with("/zx-dev"),
                "{:?}: el protocolo de Kademlia MUST ser propio, no {}",
                p.red(),
                p.protocolo_kad()
            );
            assert!(!p.protocolo_kad().contains("ipfs"));
        }
    }

    /// Todos los nombres empiezan por `/` y no acaban en `/`: libp2p lo exige.
    #[test]
    fn los_nombres_de_protocolo_tienen_la_forma_que_libp2p_exige() {
        for p in [
            ParametrosRed::de(Red::Mainnet),
            ParametrosRed::de(Red::Testnet),
            ParametrosRed::dag_dev(),
        ] {
            for nombre in [
                p.topic_bloques_pow(),
                p.topic_bloques_post(),
                p.protocolo_sync(),
                p.protocolo_kad(),
                p.protocolo_identify(),
            ] {
                assert!(nombre.starts_with('/'), "{nombre} debe empezar por /");
                assert!(!nombre.ends_with('/'), "{nombre} no debe acabar en /");
            }
        }
    }

    /// El `agent_version` dev nombra la red dev.
    #[test]
    fn el_agent_version_dev_no_se_hace_pasar_por_publico() {
        let dev = ParametrosRed::dag_dev().agent_version();
        assert!(dev.starts_with("zerox/"), "{dev}");
        assert!(dev.ends_with("/dev"), "{dev}");
        assert_ne!(dev, ParametrosRed::de(Red::Testnet).agent_version());
    }
}
