//! Parámetros de red por cadena (SPEC §16, C-NET-01, C-NET-02).
//!
//! # Aislamiento de red: lo exigido y lo que hoy hay
//!
//! **C-NET-01 exige** que todo mensaje del protocolo P2P vaya precedido de un prefijo mágico de
//! 4 bytes propio de la red, y que se rechace el que no coincida. **Hoy ese prefijo no se escribe ni
//! se comprueba en el wire** —ni sync ni gossip lo llevan—, así que el aislamiento real de los
//! mensajes de aplicación se apoya en que cada perfil use protocolos y temas distintos. El génesis
//! distinto (C-GEN-04) evita que las cadenas se confundan una vez conectadas, y el runner de
//! `dag-dev` deberá cotejar el saludo de génesis y cortar la conexión cruzada. Mientras C-NET-01 no
//! esté cableado **no** se afirma que el prefijo impida el saludo; son defensas a alturas distintas
//! y ninguna sustituye a la otra.
//!
//! # Los nombres de protocolo NO son cosmética
//!
//! `kad::Config::default()` usa `/ipfs/kad/1.0.0` — la DHT **pública de IPFS** — y no falla al
//! compilar. Verificado en `rust-libp2p@v0.56.0`, `protocols/kad/src/behaviour.rs:196-241`. Un nodo
//! con ese valor o habla con IPFS o no descubre a nadie, según tenga salida a internet. Por eso
//! todos los nombres se derivan de [`ParametrosRed`] y ninguno se deja por defecto.
//!
//! # `dag-dev` no es una red pública disfrazada
//!
//! [`ParametrosRed::dag_dev`] construye un perfil **solo de desarrollo** con sus propios temas,
//! protocolos, puerto efímero, prefijo y `agent_version`. La identidad se modela con
//! [`IdentidadP2p`], que separa [`IdentidadP2p::DagDev`] de [`IdentidadP2p::Publica`]: ningún valor
//! dev se representa como `Red::Testnet` ni puede confundirse con testnet al comparar parámetros.
//!
//! ⚠️ **El prefijo `magic` dev es metadato, no una barrera del wire.** Hoy el `magic` no se escribe
//! ni se comprueba en el códec de sync ni en gossip (C-NET-01 sigue pendiente de cableado), así que
//! un valor distinto **no aísla** el tráfico por sí solo. Los protocolos y temas propios sí separan
//! los mensajes de aplicación; una conexión libp2p cruzada (noise/ping) puede sobrevivir hasta que
//! el runner coteje el saludo de génesis y la corte. No se introduce esta cifra como consenso de
//! lanzamiento.

use zx_core::red::Red;

/// Puerto por defecto de mainnet (C-NET-02).
pub const PUERTO_MAINNET: u16 = 9833;

/// Puerto por defecto de testnet (C-NET-02).
pub const PUERTO_TESTNET: u16 = 19833;

/// Prefijo mágico de la red de desarrollo DAG (`dag-dev`).
///
/// Primeros 4 bytes de `SHA3-256("ZEROX/dag-dev/magic")`, derivados con OpenSSL igual que los
/// públicos y congelados aquí porque no existe un `Red::DagDev` en `zx-core` (no se añade: la
/// orden E1 lo prohíbe). El vector completo es
/// `b030bde676d3a2f24978438955c95d0804c918a9e6e7e6ed98db88e46c81db2a`.
///
/// ⚠️ **Metadato de desarrollo, no barrera del wire ni consenso de lanzamiento.** Ver la nota del
/// encabezado del módulo.
pub const MAGIC_DAG_DEV: [u8; 4] = [0xb0, 0x30, 0xbd, 0xe6];

/// Identidad de red de la capa P2P.
///
/// Es un enum **propio de `zx-p2p`**, no un `Red` de consenso: `zx-core` no tiene —ni debe tener—
/// una variante dev. Separa las dos redes públicas del perfil de desarrollo para que ningún valor
/// dev pueda pasar por `Red::Testnet`.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum IdentidadP2p {
    /// Mainnet o testnet.
    Publica(Red),
    /// Red de desarrollo `dag-dev`. **No es una red pública.**
    DagDev,
}

impl IdentidadP2p {
    /// Nombre corto, para logs e identificadores.
    #[must_use]
    pub const fn nombre(self) -> &'static str {
        match self {
            Self::Publica(red) => red.nombre(),
            Self::DagDev => "dag-dev",
        }
    }
}

/// Parámetros de red de una cadena.
///
/// # Los campos son privados, y eso es la garantía (C-NET-15)
///
/// El único constructor de una red pública es [`ParametrosRed::de`], y el perfil de desarrollo se
/// crea con [`ParametrosRed::dag_dev`] **sin parámetros libres**. Así **no existe** la combinación
/// "me identifico como mainnet pero hablo el prefijo de testnet". Con los campos públicos esa
/// combinación se podía escribir con un literal de struct y el compilador la aceptaba sin
/// rechistar — que es exactamente la confusión de red que C-NET-01 dice que debe ser imposible.
///
/// Lo cazó la primera revisión adversarial: el docstring **afirmaba** que no se construía campo a
/// campo, y nada lo impedía. Una invariante que solo vive en un comentario no es una invariante.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct ParametrosRed {
    identidad: IdentidadP2p,
    magic: [u8; 4],
    puerto: u16,
    topic_bloques: &'static str,
    topic_txs: &'static str,
    protocolo_sync: &'static str,
    protocolo_kad: &'static str,
    protocolo_identify: &'static str,
}

impl ParametrosRed {
    /// La identidad de red P2P. Separa mainnet, testnet y `dag-dev`.
    #[must_use]
    pub const fn identidad(&self) -> IdentidadP2p {
        self.identidad
    }
    /// La red pública, si la hay. `None` para `dag-dev`, **sin pánico**.
    ///
    /// Adapta la antigua `red() -> Red`, que no podía representar el perfil dev: devolver un `Red`
    /// inventado habría disfrazado `dag-dev` de red pública, que es justo lo que se quiere impedir.
    #[must_use]
    pub const fn red(&self) -> Option<Red> {
        match self.identidad {
            IdentidadP2p::Publica(red) => Some(red),
            IdentidadP2p::DagDev => None,
        }
    }
    /// Prefijo mágico de 4 bytes (C-NET-01).
    ///
    /// ⚠️ Hoy es **metadato**: no está en el wire y no aísla por sí solo. Ver el encabezado.
    #[must_use]
    pub const fn magic(&self) -> [u8; 4] {
        self.magic
    }
    /// Puerto TCP/QUIC por defecto (C-NET-02). En `dag-dev` es `0` (efímero).
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
    /// Protocolo del handshake `identify`.
    ///
    /// Mainnet y testnet conservan `/zerox/id/1`; `dag-dev` usa el suyo para que un nodo dev no se
    /// anuncie como red pública ni al revés.
    #[must_use]
    pub const fn protocolo_identify(&self) -> &'static str {
        self.protocolo_identify
    }

    /// Los parámetros de una red **pública**. Único constructor de mainnet/testnet.
    #[must_use]
    pub const fn de(red: Red) -> Self {
        match red {
            Red::Mainnet => Self {
                identidad: IdentidadP2p::Publica(red),
                magic: red.magic(),
                puerto: PUERTO_MAINNET,
                topic_bloques: "/zerox/blocks/2",
                topic_txs: "/zerox/txs/1",
                protocolo_sync: "/zerox/sync/1",
                protocolo_kad: "/zerox/kad/1",
                protocolo_identify: "/zerox/id/1",
            },
            Red::Testnet => Self {
                identidad: IdentidadP2p::Publica(red),
                magic: red.magic(),
                puerto: PUERTO_TESTNET,
                topic_bloques: "/zerox-testnet/blocks/2",
                topic_txs: "/zerox-testnet/txs/1",
                protocolo_sync: "/zerox-testnet/sync/1",
                protocolo_kad: "/zerox-testnet/kad/1",
                protocolo_identify: "/zerox/id/1",
            },
        }
    }

    /// Perfil de **desarrollo** para la red DAG local. **Sin parámetros libres.**
    ///
    /// Todos los valores son elegidos solo para desarrollo: puerto `0` (efímero/loopback que el
    /// futuro runner decidirá), temas y protocolos bajo `/zerox-dag-dev/...` y `agent_version`
    /// `zerox/<versión>/dag-dev`. No son parámetros de consenso ni de lanzamiento.
    ///
    /// La identidad es [`IdentidadP2p::DagDev`]: **no** se construye un `Red` ficticio, así que
    /// ningún consumidor puede confundir este perfil con testnet.
    #[must_use]
    pub const fn dag_dev() -> Self {
        Self {
            identidad: IdentidadP2p::DagDev,
            magic: MAGIC_DAG_DEV,
            puerto: 0,
            topic_bloques: "/zerox-dag-dev/blocks/2",
            topic_txs: "/zerox-dag-dev/txs/1",
            protocolo_sync: "/zerox-dag-dev/sync/1",
            protocolo_kad: "/zerox-dag-dev/kad/1",
            protocolo_identify: "/zerox-dag-dev/id/1",
        }
    }

    /// La cadena de `agent_version` que anuncia `identify`.
    ///
    /// El default de libp2p es `rust-libp2p/<versión>`, que dice qué librería usamos y nada sobre
    /// qué red somos. Este dice lo segundo, que es lo útil para un operador leyendo logs.
    #[must_use]
    pub fn agent_version(&self) -> String {
        format!(
            "zerox/{}/{}",
            env!("CARGO_PKG_VERSION"),
            self.identidad.nombre()
        )
    }
}

#[cfg(test)]
mod tests {
    use super::{IdentidadP2p, MAGIC_DAG_DEV, ParametrosRed};
    use zx_core::red::Red;
    use zx_core::sha3_256_publico;

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

    /// Nada se comparte entre mainnet y testnet. Una coincidencia debilitaría la separación de
    /// protocolos y temas —hoy el aislamiento real, porque el prefijo mágico todavía no viaja.
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

    /// **`dag-dev` no comparte identidad con ninguna red pública.**
    ///
    /// Es la prueba de que dev no es testnet disfrazada: el enum de identidad es distinto y **todos**
    /// los parámetros observables difieren. En los que sí viajan —protocolos, temas, puerto— una
    /// coincidencia acercaría el cruce dev/público; el `magic` se compara solo como etiqueta, porque
    /// todavía no está en el wire.
    #[test]
    fn dag_dev_no_comparte_identidad_con_las_redes_publicas() {
        let dev = ParametrosRed::dag_dev();
        assert_eq!(dev.identidad(), IdentidadP2p::DagDev);
        assert_eq!(dev.red(), None, "dev no finge ser una Red pública");
        assert_ne!(
            dev.identidad(),
            IdentidadP2p::Publica(Red::Testnet),
            "dev MUST NOT representarse como testnet"
        );

        for red in [Red::Mainnet, Red::Testnet] {
            let p = ParametrosRed::de(red);
            assert_ne!(dev.magic(), p.magic(), "{red:?}");
            assert_ne!(dev.puerto(), p.puerto(), "{red:?}");
            assert_ne!(dev.topic_bloques(), p.topic_bloques(), "{red:?}");
            assert_ne!(dev.topic_txs(), p.topic_txs(), "{red:?}");
            assert_ne!(dev.protocolo_sync(), p.protocolo_sync(), "{red:?}");
            assert_ne!(dev.protocolo_kad(), p.protocolo_kad(), "{red:?}");
            assert_ne!(dev.protocolo_identify(), p.protocolo_identify(), "{red:?}");
            assert_ne!(dev.agent_version(), p.agent_version(), "{red:?}");
        }
    }

    /// **Mainnet y testnet conservan sus valores anteriores.** Este test es la red de seguridad
    /// contra un cambio de perfil que mueva sin querer una red pública.
    #[test]
    fn mainnet_y_testnet_conservan_sus_valores() {
        let m = ParametrosRed::de(Red::Mainnet);
        assert_eq!(m.identidad(), IdentidadP2p::Publica(Red::Mainnet));
        assert_eq!(m.red(), Some(Red::Mainnet));
        assert_eq!(m.magic(), Red::Mainnet.magic());
        assert_eq!(m.puerto(), super::PUERTO_MAINNET);
        assert_eq!(m.topic_bloques(), "/zerox/blocks/2");
        assert_eq!(m.topic_txs(), "/zerox/txs/1");
        assert_eq!(m.protocolo_sync(), "/zerox/sync/1");
        assert_eq!(m.protocolo_kad(), "/zerox/kad/1");
        assert_eq!(m.protocolo_identify(), "/zerox/id/1");

        let t = ParametrosRed::de(Red::Testnet);
        assert_eq!(t.identidad(), IdentidadP2p::Publica(Red::Testnet));
        assert_eq!(t.red(), Some(Red::Testnet));
        assert_eq!(t.magic(), Red::Testnet.magic());
        assert_eq!(t.puerto(), super::PUERTO_TESTNET);
        assert_eq!(t.topic_bloques(), "/zerox-testnet/blocks/2");
        assert_eq!(t.topic_txs(), "/zerox-testnet/txs/1");
        assert_eq!(t.protocolo_sync(), "/zerox-testnet/sync/1");
        assert_eq!(t.protocolo_kad(), "/zerox-testnet/kad/1");
        assert_eq!(t.protocolo_identify(), "/zerox/id/1");
    }

    /// **El `magic` dev se deriva, no se inventa.**
    ///
    /// El literal está congelado porque no hay `Red::DagDev`, pero la fórmula es la misma que la de
    /// las redes públicas: primeros 4 bytes de `SHA3-256("ZEROX/dag-dev/magic")`. Este test coteja
    /// el literal contra la primitiva del repositorio; el valor completo se verificó además con
    /// OpenSSL al congelarlo.
    #[test]
    fn el_magic_dag_dev_se_deriva_de_su_formula() {
        let h = sha3_256_publico(b"ZEROX/dag-dev/magic");
        let b = h.as_bytes();
        let cuatro: [u8; 4] = [b[0], b[1], b[2], b[3]];
        assert_eq!(cuatro, MAGIC_DAG_DEV);
        assert_eq!(ParametrosRed::dag_dev().magic(), MAGIC_DAG_DEV);
    }

    /// **El `magic` dev es metadato, no una barrera del wire.**
    ///
    /// El hallazgo que gobierna la orden E1: un `magic` distinto **no aísla** el tráfico porque no
    /// aparece en el códec de sync ni en gossip. Este test fija que la cifra dev es distinta de las
    /// públicas —lo que sí sirve para etiquetar— y que **no se antepone** a un mensaje del wire. La
    /// prueba de que el mismo mensaje se lee bajo los dos perfiles está en `codec`.
    #[test]
    fn el_magic_dev_distingue_pero_no_esta_en_el_wire() {
        let dev = ParametrosRed::dag_dev().magic();
        assert_ne!(dev, ParametrosRed::de(Red::Mainnet).magic());
        assert_ne!(dev, ParametrosRed::de(Red::Testnet).magic());

        // El saludo `Estado` empieza por su discriminante (`0x00`), nunca por el prefijo mágico:
        // no hay bytes de red delante del mensaje.
        let peticion = crate::codec::peticion_a_bytes(&crate::mensaje::Peticion::Estado);
        assert_eq!(peticion.first().copied(), Some(0x00));
        assert_ne!(peticion.get(..4), Some(dev.as_slice()));
    }

    /// **Mainnet y testnet comparten el protocolo `identify`; dev tiene el suyo.**
    ///
    /// `protocolo_identify` deja de ser una constante de `behaviour` para que el perfil dev no
    /// anuncie el handshake de una red pública.
    #[test]
    fn el_protocolo_identify_depende_del_perfil() {
        assert_eq!(
            ParametrosRed::de(Red::Mainnet).protocolo_identify(),
            "/zerox/id/1"
        );
        assert_eq!(
            ParametrosRed::de(Red::Testnet).protocolo_identify(),
            "/zerox/id/1"
        );
        assert_eq!(
            ParametrosRed::dag_dev().protocolo_identify(),
            "/zerox-dag-dev/id/1"
        );
    }

    /// **El `agent_version` dev nombra la red dev.**
    #[test]
    fn el_agent_version_dev_no_se_hace_pasar_por_publico() {
        let dev = ParametrosRed::dag_dev().agent_version();
        assert!(dev.starts_with("zerox/"), "{dev}");
        assert!(dev.ends_with("/dag-dev"), "{dev}");
        assert_ne!(dev, ParametrosRed::de(Red::Testnet).agent_version());
        assert_ne!(dev, ParametrosRed::de(Red::Mainnet).agent_version());
    }

    /// **El nombre de Kademlia MUST NOT ser el de IPFS.**
    ///
    /// `kad::Config::default()` usa `/ipfs/kad/1.0.0` y no falla al compilar. Este test es el único
    /// sitio donde ese error se hace visible antes de producción.
    #[test]
    fn kademlia_nunca_usa_el_protocolo_de_ipfs() {
        for p in [
            ParametrosRed::de(Red::Mainnet),
            ParametrosRed::de(Red::Testnet),
            ParametrosRed::dag_dev(),
        ] {
            assert!(
                p.protocolo_kad().starts_with("/zerox"),
                "{:?}: el protocolo de Kademlia MUST ser propio, no {}",
                p.identidad(),
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
        for (p, esperado) in [
            (ParametrosRed::de(Red::Mainnet), "/zerox/blocks/2"),
            (ParametrosRed::de(Red::Testnet), "/zerox-testnet/blocks/2"),
            (ParametrosRed::dag_dev(), "/zerox-dag-dev/blocks/2"),
        ] {
            assert_eq!(p.topic_bloques(), esperado, "{:?}", p.identidad());
            assert!(
                !p.topic_bloques().contains("/blocks/1"),
                "{:?}: C-NET-25 prohíbe difundir el bloque completo por gossip",
                p.identidad()
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

    /// **Cada perfil tiene sus dos temas, y ninguno comparte el conjunto entero con otro.**
    ///
    /// No es cosmético: los dos temas que `ZxBehaviour` suscribe son **exactamente** los de ese
    /// perfil. Si dos perfiles compartieran un tema, un nodo de uno podría recibir anuncios de otro.
    /// Hoy el aislamiento de los mensajes de aplicación se apoya en temas y protocolos distintos:
    /// **no** en el prefijo mágico, que aún no viaja en el wire (C-NET-01 pendiente de cableado); el
    /// runner futuro cotejará el saludo de génesis para cortar la conexión cruzada.
    #[test]
    fn cada_perfil_tiene_sus_dos_temas_y_no_hay_suscripcion_cruzada() {
        let perfiles = [
            ParametrosRed::de(Red::Mainnet),
            ParametrosRed::de(Red::Testnet),
            ParametrosRed::dag_dev(),
        ];
        for p in perfiles {
            assert_ne!(p.topic_bloques(), p.topic_txs(), "{:?}", p.identidad());
        }

        // Los seis temas son distintos entre sí: no hay uno que sirva a dos perfiles.
        let mut todos = Vec::new();
        for p in perfiles {
            todos.push(p.topic_bloques());
            todos.push(p.topic_txs());
        }
        todos.sort_unstable();
        let antes = todos.len();
        todos.dedup();
        assert_eq!(antes, todos.len(), "hay un tema compartido entre perfiles");
    }

    /// Todos los protocolos empiezan por `/`: libp2p lo exige en `StreamProtocol::new`.
    #[test]
    fn los_nombres_de_protocolo_tienen_la_forma_que_libp2p_exige() {
        for p in [
            ParametrosRed::de(Red::Mainnet),
            ParametrosRed::de(Red::Testnet),
            ParametrosRed::dag_dev(),
        ] {
            for nombre in [
                p.topic_bloques(),
                p.topic_txs(),
                p.protocolo_sync(),
                p.protocolo_kad(),
                p.protocolo_identify(),
            ] {
                assert!(nombre.starts_with('/'), "{nombre} debe empezar por /");
                assert!(!nombre.ends_with('/'), "{nombre} no debe acabar en /");
            }
        }
    }
}
