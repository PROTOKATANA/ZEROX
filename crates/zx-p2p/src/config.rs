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
/// # Los campos son privados, y eso es la garantía (C-NET-15)
///
/// El único constructor es [`ParametrosRed::de`], así que **no existe** la combinación "me
/// identifico como mainnet pero hablo el prefijo de testnet". Con los campos públicos esa
/// combinación se podía escribir con un literal de struct y el compilador la aceptaba sin
/// rechistar — que es exactamente la confusión de red que C-NET-01 dice que debe ser imposible.
///
/// Lo cazó la primera revisión adversarial: el docstring **afirmaba** que no se construía campo a
/// campo, y nada lo impedía. Una invariante que solo vive en un comentario no es una invariante.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct ParametrosRed {
    red: Red,
    magic: [u8; 4],
    puerto: u16,
    topic_bloques: &'static str,
    topic_txs: &'static str,
    protocolo_sync: &'static str,
    protocolo_kad: &'static str,
}

impl ParametrosRed {
    /// La red.
    #[must_use]
    pub const fn red(&self) -> Red {
        self.red
    }
    /// Prefijo mágico de 4 bytes (C-NET-01).
    #[must_use]
    pub const fn magic(&self) -> [u8; 4] {
        self.magic
    }
    /// Puerto TCP/QUIC por defecto (C-NET-02).
    #[must_use]
    pub const fn puerto(&self) -> u16 {
        self.puerto
    }
    /// Tópico de gossipsub para bloques.
    ///
    /// **`/blocks/2`, no `/blocks/1`** (C-NET-25, C-NET-26): el tema de bloques pasa a llevar
    /// **solo anuncios compactos** —cabecera DAG, nonce de transporte e identificadores cortos—, y
    /// el `/1` significaba bloque completo. Un bloque completo **MUST NOT** viajar por gossip. La
    /// versión sube porque un nodo nuevo que anunciara compacto en `/blocks/1` le mandaría a un nodo
    /// antiguo bytes que no sabe interpretar.
    #[must_use]
    pub const fn topic_bloques(&self) -> &'static str {
        self.topic_bloques
    }
    /// Tópico de gossipsub para transacciones.
    #[must_use]
    pub const fn topic_txs(&self) -> &'static str {
        self.topic_txs
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

    /// Los parámetros de una red. **Único constructor.**
    #[must_use]
    pub const fn de(red: Red) -> Self {
        match red {
            Red::Mainnet => Self {
                red,
                magic: red.magic(),
                puerto: PUERTO_MAINNET,
                topic_bloques: "/zerox/blocks/2",
                topic_txs: "/zerox/txs/1",
                protocolo_sync: "/zerox/sync/1",
                protocolo_kad: "/zerox/kad/1",
            },
            Red::Testnet => Self {
                red,
                magic: red.magic(),
                puerto: PUERTO_TESTNET,
                topic_bloques: "/zerox-testnet/blocks/2",
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
            assert_eq!(ParametrosRed::de(red).magic(), red.magic(), "{red:?}");
        }
    }

    /// Nada se comparte entre redes. Si algo coincidiera, los nodos podrían cruzarse.
    #[test]
    fn ninguna_red_comparte_nada_con_la_otra() {
        let m = ParametrosRed::de(Red::Mainnet);
        let t = ParametrosRed::de(Red::Testnet);

        assert_ne!(m.magic(), t.magic());
        assert_ne!(m.puerto(), t.puerto());
        assert_ne!(m.topic_bloques(), t.topic_bloques());
        assert_ne!(m.topic_txs(), t.topic_txs());
        assert_ne!(m.protocolo_sync(), t.protocolo_sync());
        assert_ne!(m.protocolo_kad(), t.protocolo_kad());
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
                p.protocolo_kad().starts_with("/zerox"),
                "{:?}: el protocolo de Kademlia MUST ser propio, no {}",
                red,
                p.protocolo_kad()
            );
            assert!(!p.protocolo_kad().contains("ipfs"));
        }
    }

    /// **C-NET-25 · el tema de bloques es `/2` y nunca `/1`.**
    ///
    /// El `/1` significaba «bloque completo» y un bloque completo **MUST NOT** difundirse por
    /// gossip. Este test es el que impide que una vuelta atrás silenciosa reintroduzca el tema
    /// viejo: `/blocks/2` también contiene la subcadena `/blocks/`, así que el error no se vería en
    /// ninguna clasificación por prefijo.
    #[test]
    fn el_tema_de_bloques_es_el_dos_y_no_el_uno() {
        for (red, esperado) in [
            (Red::Mainnet, "/zerox/blocks/2"),
            (Red::Testnet, "/zerox-testnet/blocks/2"),
        ] {
            let p = ParametrosRed::de(red);
            assert_eq!(p.topic_bloques(), esperado, "{red:?}");
            assert!(
                !p.topic_bloques().contains("/blocks/1"),
                "{red:?}: C-NET-25 prohíbe difundir el bloque completo por gossip"
            );
        }
    }

    /// **C-NET-25 · las txs conservan `/txs/1`.** El relé compacto cambia el canal de bloques, no
    /// el de transacciones.
    #[test]
    fn las_transacciones_conservan_el_tema_uno() {
        assert_eq!(ParametrosRed::de(Red::Mainnet).topic_txs(), "/zerox/txs/1");
        assert_eq!(
            ParametrosRed::de(Red::Testnet).topic_txs(),
            "/zerox-testnet/txs/1"
        );
    }

    /// **Cada red tiene sus dos temas, y ninguna comparte el conjunto entero con la otra.**
    ///
    /// No es cosmético: los dos temas que `ZxBehaviour` suscribe son **exactamente** los de esa red.
    /// Si mainnet y testnet compartieran un tema, un nodo de una red podría recibir anuncios de la
    /// otra —lo que el prefijo mágico impide en la conexión, y esto en la difusión—.
    #[test]
    fn cada_red_tiene_sus_dos_temas_y_no_hay_suscripcion_cruzada() {
        for red in [Red::Mainnet, Red::Testnet] {
            let p = ParametrosRed::de(red);
            assert_ne!(p.topic_bloques(), p.topic_txs(), "{red:?}");
        }

        let m = ParametrosRed::de(Red::Mainnet);
        let t = ParametrosRed::de(Red::Testnet);
        assert_ne!(m.topic_bloques(), t.topic_bloques());
        assert_ne!(m.topic_txs(), t.topic_txs());
        // Los cuatro son distintos entre sí: no hay un tema que sirva a las dos redes.
        let mut todos = vec![
            m.topic_bloques(),
            m.topic_txs(),
            t.topic_bloques(),
            t.topic_txs(),
        ];
        todos.sort_unstable();
        let antes = todos.len();
        todos.dedup();
        assert_eq!(antes, todos.len(), "hay un tema compartido entre redes");
    }

    /// Todos los protocolos empiezan por `/`: libp2p lo exige en `StreamProtocol::new`.
    #[test]
    fn los_nombres_de_protocolo_tienen_la_forma_que_libp2p_exige() {
        for red in [Red::Mainnet, Red::Testnet] {
            let p = ParametrosRed::de(red);
            for nombre in [
                p.topic_bloques(),
                p.topic_txs(),
                p.protocolo_sync(),
                p.protocolo_kad(),
            ] {
                assert!(nombre.starts_with('/'), "{nombre} debe empezar por /");
                assert!(!nombre.ends_with('/'), "{nombre} no debe acabar en /");
            }
        }
    }
}
