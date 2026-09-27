//! Mensajes del protocolo de la red dev híbrida (SPEC §16.1, FORMATO-v0).
//!
//! # El saludo va primero, y no es cortesía
//!
//! Antes de pedir nada, los dos extremos intercambian un [`Estado`]: de qué red y génesis vienen,
//! en qué fase están, dónde tienen la punta PoW y qué puntas PoST conocen. Sirve para dos cosas:
//! decidir **quién pide a quién**, y detectar que se habla con otra red o con otra bifurcación
//! aunque el prefijo mágico haya coincidido. Génesis o red distintos ⇒ desconexión.
//!
//! # Por qué la petición de cabeceras lleva un *locator* y no una altura
//!
//! Pedir "las cabeceras desde la altura 1000" supone que los dos estáis en la misma cadena. Un
//! **locator** —una lista de hashes conocidos, densa cerca de la punta y espaciada hacia atrás— no
//! lo supone: el otro extremo busca el primero que reconoce y responde desde ahí. Es el mecanismo
//! de Bitcoin desde el principio.
//!
//! # Las dos familias de bloque no se adivinan
//!
//! [`BloqueRed`] es un enum con la familia **explícita** en el wire ([`FamiliaBloque`]). El códec
//! exige la familia declarada por el llamante (F-04): una cabecera PoW mide exactamente 92 B y una
//! PoST entre 589 y 1 037 B, y **nunca** se intenta deducir cuál es por la longitud de un buffer
//! ambiguo.

use zx_core::digest::BlockHash;
use zx_core::preimage::block::BlockHeader;
use zx_core::preimage::dag::DagBlockHeader;
use zx_core::red::Red;
use zx_core::tx::Tx;
use zx_core::wire_dag::JustificacionPot;

/// Máximo de puntas PoST que caben en un [`Estado`].
///
/// La cabecera PoST admite hasta 15 padres; 16 puntas cubren ese conjunto con holgura y acotan el
/// saludo. No es una regla de consenso, es una cota del transporte.
pub const MAX_PUNTAS_POST: usize = 16;

/// Familia de bloque del híbrido.
///
/// El discriminante viaja **explícito** en el wire: es la familia declarada que el códec exige, no
/// algo que se deduzca de la longitud (F-04). Son consenso de protocolo: no se reordenan.
#[derive(Clone, Copy, PartialEq, Eq, Debug, Hash)]
pub enum FamiliaBloque {
    /// Cabecera lineal PoW (92 B).
    Pow,
    /// Cabecera DAG PoST (589–1 037 B).
    Post,
}

impl FamiliaBloque {
    /// Discriminante de [`FamiliaBloque::Pow`].
    pub const DISC_POW: u8 = 0x00;
    /// Discriminante de [`FamiliaBloque::Post`].
    pub const DISC_POST: u8 = 0x01;

    /// El byte que identifica esta familia en el wire.
    #[must_use]
    pub const fn discriminante(self) -> u8 {
        match self {
            Self::Pow => Self::DISC_POW,
            Self::Post => Self::DISC_POST,
        }
    }

    /// Interpreta un byte como familia, o `None` si no es ninguna.
    ///
    /// Devuelve `Option` en vez de un valor por defecto: un byte desconocido **no** se interpreta
    /// como PoW "porque es lo primero".
    #[must_use]
    pub const fn desde_byte(b: u8) -> Option<Self> {
        match b {
            Self::DISC_POW => Some(Self::Pow),
            Self::DISC_POST => Some(Self::Post),
            _ => None,
        }
    }
}

/// Un bloque tal y como viaja: cabecera, transacciones y testigos, en su familia.
///
/// Es una versión **con dueño** de lo que el nodo valida por referencia. Vive aquí y no en otro
/// crate porque este crate no depende de consenso (ver el diagrama en `lib.rs`), y sus campos son
/// tipos de `zx-core`.
#[derive(Clone, PartialEq, Eq, Debug)]
#[expect(
    clippy::large_enum_variant,
    reason = "el enum define las dos familias con la cabecera en línea, como pide la orden; \
              boxearla añadiría indirección sin cambiar el wire"
)]
pub enum BloqueRed {
    /// Bloque PoW: cabecera lineal y cuerpo.
    Pow {
        /// Cabecera lineal (F-01).
        cabecera: BlockHeader,
        /// Transacciones, la primera de las cuales es la coinbase PoW.
        txs: Vec<Tx>,
        /// `testigos[i][j]` es el testigo de la entrada `j` de la transacción `i`.
        testigos: Vec<Vec<Vec<u8>>>,
    },
    /// Bloque PoST: cabecera DAG, justificación PoT y cuerpo.
    Post {
        /// Cabecera DAG (F-02).
        cabecera: DagBlockHeader,
        /// Justificación PoT (`ORDEN-W06d3` decisión 1): sin ella,
        /// `zx_post::cabecera_conjunta::verificar_cabecera_conjunta` no puede comprobar el PoT ni el
        /// PoAS de un bloque ajeno (`REVISION-W06d2.md`, bloqueo). Va **fuera** de `block_hash`
        /// (igual que en [`zx_core::wire_dag::BloqueDag`]): es evidencia contextual, no consenso de
        /// la cabecera.
        justificacion: JustificacionPot,
        /// Transacciones, la primera de las cuales es la coinbase PoST.
        txs: Vec<Tx>,
        /// `testigos[i][j]` es el testigo de la entrada `j` de la transacción `i`.
        testigos: Vec<Vec<Vec<u8>>>,
    },
}

impl BloqueRed {
    /// La familia declarada de este bloque.
    #[must_use]
    pub const fn familia(&self) -> FamiliaBloque {
        match self {
            Self::Pow { .. } => FamiliaBloque::Pow,
            Self::Post { .. } => FamiliaBloque::Post,
        }
    }

    /// Las transacciones del bloque, sea cual sea la familia.
    #[must_use]
    pub fn txs(&self) -> &[Tx] {
        match self {
            Self::Pow { txs, .. } | Self::Post { txs, .. } => txs,
        }
    }

    /// Las listas de testigos del bloque, sea cual sea la familia.
    #[must_use]
    pub fn testigos(&self) -> &[Vec<Vec<u8>>] {
        match self {
            Self::Pow { testigos, .. } | Self::Post { testigos, .. } => testigos,
        }
    }
}

/// Fase del híbrido en la que está un nodo.
#[derive(Clone, Copy, PartialEq, Eq, Debug, Hash)]
pub enum Fase {
    /// Fase PoW (antes del corte).
    Pow,
    /// Fase PoST (después del corte).
    Post,
}

impl Fase {
    /// Discriminante de [`Fase::Pow`].
    pub const DISC_POW: u8 = 0x00;
    /// Discriminante de [`Fase::Post`].
    pub const DISC_POST: u8 = 0x01;

    /// El byte que identifica esta fase en el wire.
    #[must_use]
    pub const fn discriminante(self) -> u8 {
        match self {
            Self::Pow => Self::DISC_POW,
            Self::Post => Self::DISC_POST,
        }
    }

    /// Interpreta un byte como fase, o `None` si no es ninguna.
    #[must_use]
    pub const fn desde_byte(b: u8) -> Option<Self> {
        match b {
            Self::DISC_POW => Some(Self::Pow),
            Self::DISC_POST => Some(Self::Post),
            _ => None,
        }
    }
}

/// La punta PoW declarada en el saludo: hash, altura y trabajo acumulado.
///
/// Es la terna `(hash, altura, trabajo_acumulado 32 B BE)` de la orden. El trabajo va en bytes
/// crudos **big-endian** y no como entero porque el *fork choice* es del nodo y este crate no lo ve:
/// aquí solo se transporta; quien compare será quien sepa comparar.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct PuntaPow {
    /// Hash de la punta PoW.
    pub hash: BlockHash,
    /// Altura de esa punta.
    pub altura: u32,
    /// Trabajo acumulado, en big-endian de 32 bytes.
    pub trabajo_acumulado: [u8; 32],
}

/// Lo que un peer dice de sí mismo al saludar.
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct Estado {
    /// Hash del génesis. **Distinto ⇒ no hay nada que hablar**, aunque la red cuadrase.
    pub hash_genesis: BlockHash,
    /// Red de la que se viene. **Distinta ⇒ desconexión.**
    pub red: Red,
    /// Fase en la que está el peer.
    pub fase: Fase,
    /// Su punta PoW.
    pub punta_pow: PuntaPow,
    /// Hash del terminal PoW, si ya se cruzó el corte.
    pub terminal: Option<BlockHash>,
    /// Puntas PoST conocidas, como mucho [`MAX_PUNTAS_POST`].
    pub puntas_post: Vec<BlockHash>,
    /// `blue_work_virtual`, en big-endian de 32 bytes.
    pub blue_work_virtual: [u8; 32],
    /// `ORDEN-W06d6` decisión 1: longitud del registro de admisión de quien saluda (PoW + PoST, en
    /// el orden real en que los admitió). Es lo que permite al que sincroniza saber, sin pedir
    /// nada más, cuánto le falta: compara esto con lo que ya tiene y decide cuántas páginas de
    /// `Peticion::Registro` pedir.
    pub longitud_registro: u64,
}

/// El byte de red en el wire.
///
/// La orden nombra el campo `red` sin fijar su codificación. Se fija aquí, explícita y **cerrada**:
/// `Mainnet = 0`, `Testnet = 1`, `Dev = 2`. Un byte fuera de ese conjunto se rechaza en el códec;
/// no se interpreta como una red por defecto.
#[must_use]
pub const fn red_discriminante(red: Red) -> u8 {
    match red {
        Red::Mainnet => 0x00,
        Red::Testnet => 0x01,
        Red::Dev => 0x02,
    }
}

/// Interpreta el byte de red del wire, o `None` si no es una red conocida.
#[must_use]
pub const fn red_desde_discriminante(b: u8) -> Option<Red> {
    match b {
        0x00 => Some(Red::Mainnet),
        0x01 => Some(Red::Testnet),
        0x02 => Some(Red::Dev),
        _ => None,
    }
}

/// Lo que se le pide a un peer.
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum Peticion {
    /// Saludo. Se manda al conectar, antes que nada.
    Estado,
    /// Cabeceras **PoW** a partir del primer hash del locator que el otro reconozca.
    CabecerasPow {
        /// Hashes conocidos, **de la punta hacia atrás**, densos al principio y espaciados después.
        locator: Vec<BlockHash>,
        /// Dónde parar. `None` = hasta donde quepa en la respuesta.
        parada: Option<BlockHash>,
    },
    /// Bloques completos (PoW o PoST), por hash. Solo se piden **tras** validar sus cabeceras.
    Bloques {
        /// Los bloques que faltan, como mucho [`crate::limites::MAX_HASHES_POR_PETICION`].
        hashes: Vec<BlockHash>,
    },
    /// `ORDEN-W06d6` decisión 1: una página del registro de admisión del que responde, empezando
    /// en el índice `desde` (0 = desde el génesis). Sustituye a la resolución de huérfanos PoST de
    /// uno en uno como vía **principal** de puesta al día (la resolución por padres se queda para
    /// los huecos pequeños).
    Registro {
        /// Índice del registro de admisión desde el que empezar (0 = el génesis).
        desde: u64,
    },
}

impl Peticion {
    /// Discriminante de wire. Son consenso de protocolo: no se reordenan.
    pub const DISC_ESTADO: u8 = 0x00;
    /// Discriminante de [`Peticion::CabecerasPow`].
    pub const DISC_CABECERAS_POW: u8 = 0x01;
    /// Discriminante de [`Peticion::Bloques`].
    pub const DISC_BLOQUES: u8 = 0x02;
    /// Discriminante de [`Peticion::Registro`]. Nuevo en `ORDEN-W06d6`: se añade al final, sin
    /// reordenar los discriminantes existentes.
    pub const DISC_REGISTRO: u8 = 0x03;

    /// El byte que identifica esta variante.
    #[must_use]
    pub const fn discriminante(&self) -> u8 {
        match self {
            Self::Estado => Self::DISC_ESTADO,
            Self::CabecerasPow { .. } => Self::DISC_CABECERAS_POW,
            Self::Bloques { .. } => Self::DISC_BLOQUES,
            Self::Registro { .. } => Self::DISC_REGISTRO,
        }
    }
}

/// Lo que un peer responde.
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum Respuesta {
    /// Respuesta al saludo.
    Estado(Estado),
    /// Cabeceras **PoW** consecutivas, de menor a mayor altura.
    CabecerasPow(Vec<BlockHeader>),
    /// Bloques completos, **en el orden en que se pidieron**.
    Bloques(Vec<BloqueRed>),
    /// "No tengo eso." No es un error: un peer honesto puede no tener un bloque que ya podó, o que
    /// pertenece a una rama que él descartó.
    ///
    /// Distinguirlo de un error de protocolo importa: esto **no puntúa**.
    NoDisponible,
    /// `ORDEN-W06d6` decisión 1: respuesta a [`Peticion::Registro`]. Como mucho
    /// [`crate::limites::MAX_BLOQUES_POR_RESPUESTA`] bloques y
    /// [`crate::limites::MAX_RESPUESTA_BYTES`] bytes, en el orden real de admisión del que
    /// responde, empezando en `desde`.
    Registro {
        /// El mismo `desde` de la petición (para que quien sincroniza pueda casarlo sin ambigüedad
        /// si algún día hay más de una página en vuelo).
        desde: u64,
        /// Los bloques de esta página, en orden de admisión.
        bloques: Vec<BloqueRed>,
        /// Longitud **total** del registro del que responde, en el momento de responder.
        longitud: u64,
    },
}

impl Respuesta {
    /// Discriminante de [`Respuesta::Estado`].
    pub const DISC_ESTADO: u8 = 0x00;
    /// Discriminante de [`Respuesta::CabecerasPow`].
    pub const DISC_CABECERAS_POW: u8 = 0x01;
    /// Discriminante de [`Respuesta::Bloques`].
    pub const DISC_BLOQUES: u8 = 0x02;
    /// Discriminante de [`Respuesta::NoDisponible`].
    pub const DISC_NO_DISPONIBLE: u8 = 0x03;
    /// Discriminante de [`Respuesta::Registro`]. Nuevo en `ORDEN-W06d6`: al final, sin reordenar.
    pub const DISC_REGISTRO: u8 = 0x04;

    /// El byte que identifica esta variante.
    #[must_use]
    pub const fn discriminante(&self) -> u8 {
        match self {
            Self::Estado(_) => Self::DISC_ESTADO,
            Self::CabecerasPow(_) => Self::DISC_CABECERAS_POW,
            Self::Bloques(_) => Self::DISC_BLOQUES,
            Self::NoDisponible => Self::DISC_NO_DISPONIBLE,
            Self::Registro { .. } => Self::DISC_REGISTRO,
        }
    }

    /// ¿Responde esta respuesta a esa petición?
    ///
    /// libp2p correlaciona petición y respuesta por identificador de stream, así que un peer no
    /// puede colar una respuesta a una petición que no hiciste. Pero **sí puede responder con el
    /// tipo equivocado**: pides cabeceras y te manda bloques. Sin esta comprobación, el código de
    /// sincronización tendría que hacer `match` sobre una respuesta que no espera, y el camino menos
    /// malo de ese `match` acaba siendo ignorarla en silencio.
    #[must_use]
    pub const fn responde_a(&self, p: &Peticion) -> bool {
        matches!(
            (self, p),
            (Self::Estado(_), Peticion::Estado)
                | (Self::CabecerasPow(_), Peticion::CabecerasPow { .. })
                | (Self::Bloques(_), Peticion::Bloques { .. })
                | (Self::Registro { .. }, Peticion::Registro { .. })
                // NoDisponible vale para cualquier petición de datos, pero NO para el saludo:
                // un peer que no sabe decir quién es no sirve para nada.
                | (
                    Self::NoDisponible,
                    Peticion::CabecerasPow { .. } | Peticion::Bloques { .. } | Peticion::Registro { .. }
                )
        )
    }
}

#[cfg(test)]
mod tests {
    use super::{
        Estado, FamiliaBloque, Fase, MAX_PUNTAS_POST, Peticion, PuntaPow, Respuesta,
        red_desde_discriminante, red_discriminante,
    };
    use zx_core::digest::{BlockHash, Digest};
    use zx_core::red::Red;

    fn h(n: u8) -> BlockHash {
        BlockHash::from_digest(Digest::from_bytes([n; 32]))
    }

    fn estado() -> Estado {
        Estado {
            hash_genesis: h(1),
            red: Red::Dev,
            fase: Fase::Pow,
            punta_pow: PuntaPow {
                hash: h(2),
                altura: 100,
                trabajo_acumulado: [3; 32],
            },
            terminal: None,
            puntas_post: vec![h(4)],
            blue_work_virtual: [5; 32],
            longitud_registro: 42,
        }
    }

    /// Los discriminantes son distintos entre sí en cada enum. Si dos coincidieran, un mensaje se
    /// decodificaría como otro.
    #[test]
    fn los_discriminantes_no_colisionan() {
        let peticiones = [
            Peticion::Estado,
            Peticion::CabecerasPow {
                locator: vec![],
                parada: None,
            },
            Peticion::Bloques { hashes: vec![] },
            Peticion::Registro { desde: 0 },
        ];
        let mut vistos = Vec::new();
        for p in &peticiones {
            assert!(!vistos.contains(&p.discriminante()), "{p:?} colisiona");
            vistos.push(p.discriminante());
        }

        let respuestas = [
            Respuesta::Estado(estado()),
            Respuesta::CabecerasPow(vec![]),
            Respuesta::Bloques(vec![]),
            Respuesta::NoDisponible,
            Respuesta::Registro {
                desde: 0,
                bloques: vec![],
                longitud: 0,
            },
        ];
        let mut vistos = Vec::new();
        for r in &respuestas {
            assert!(!vistos.contains(&r.discriminante()), "{r:?} colisiona");
            vistos.push(r.discriminante());
        }

        assert_eq!(Peticion::Estado.discriminante(), 0x00);
        assert_eq!(Peticion::DISC_CABECERAS_POW, 0x01);
        assert_eq!(Peticion::DISC_BLOQUES, 0x02);
        assert_eq!(Peticion::DISC_REGISTRO, 0x03);
        assert_eq!(Respuesta::DISC_ESTADO, 0x00);
        assert_eq!(Respuesta::DISC_CABECERAS_POW, 0x01);
        assert_eq!(Respuesta::DISC_BLOQUES, 0x02);
        assert_eq!(Respuesta::DISC_NO_DISPONIBLE, 0x03);
        assert_eq!(Respuesta::DISC_REGISTRO, 0x04);
    }

    /// Cada familia y cada fase tiene su byte, y no se interpreta un byte desconocido.
    #[test]
    fn las_familias_y_fases_tienen_byte_cerrado() {
        assert_eq!(FamiliaBloque::Pow.discriminante(), 0x00);
        assert_eq!(FamiliaBloque::Post.discriminante(), 0x01);
        assert_eq!(FamiliaBloque::desde_byte(0x00), Some(FamiliaBloque::Pow));
        assert_eq!(FamiliaBloque::desde_byte(0x01), Some(FamiliaBloque::Post));
        for b in [0x02u8, 0x7f, 0xff] {
            assert_eq!(FamiliaBloque::desde_byte(b), None, "familia {b:#04x}");
        }

        assert_eq!(Fase::Pow.discriminante(), 0x00);
        assert_eq!(Fase::Post.discriminante(), 0x01);
        assert_eq!(Fase::desde_byte(0x01), Some(Fase::Post));
        assert_eq!(Fase::desde_byte(0x02), None);
    }

    /// El byte de red está cerrado: cada `Red` tiene el suyo y ninguno se adivina.
    #[test]
    fn el_byte_de_red_es_cerrado() {
        for red in [Red::Mainnet, Red::Testnet, Red::Dev] {
            let b = red_discriminante(red);
            assert_eq!(red_desde_discriminante(b), Some(red), "{red:?}");
        }
        assert_eq!(red_desde_discriminante(0x03), None);
        assert_eq!(red_desde_discriminante(0xff), None);
    }

    /// Cada respuesta responde a su petición y **solo** a la suya.
    #[test]
    fn una_respuesta_del_tipo_equivocado_se_detecta() {
        let cabeceras = Peticion::CabecerasPow {
            locator: vec![h(1)],
            parada: None,
        };
        let bloques = Peticion::Bloques { hashes: vec![h(1)] };

        assert!(Respuesta::Estado(estado()).responde_a(&Peticion::Estado));
        assert!(Respuesta::CabecerasPow(vec![]).responde_a(&cabeceras));
        assert!(Respuesta::Bloques(vec![]).responde_a(&bloques));

        assert!(!Respuesta::CabecerasPow(vec![]).responde_a(&bloques));
        assert!(!Respuesta::Bloques(vec![]).responde_a(&cabeceras));
        assert!(!Respuesta::Estado(estado()).responde_a(&cabeceras));
        assert!(!Respuesta::CabecerasPow(vec![]).responde_a(&Peticion::Estado));
    }

    /// `NoDisponible` vale para datos, **nunca** para el saludo.
    #[test]
    fn no_disponible_no_vale_como_saludo() {
        assert!(!Respuesta::NoDisponible.responde_a(&Peticion::Estado));
        assert!(Respuesta::NoDisponible.responde_a(&Peticion::Bloques { hashes: vec![] }));
        assert!(Respuesta::NoDisponible.responde_a(&Peticion::CabecerasPow {
            locator: vec![],
            parada: None
        }));
        assert!(Respuesta::NoDisponible.responde_a(&Peticion::Registro { desde: 0 }));
    }

    /// `ORDEN-W06d6` decisión 1: `Respuesta::Registro` responde solo a `Peticion::Registro`.
    #[test]
    fn registro_responde_solo_a_registro() {
        let peticion_registro = Peticion::Registro { desde: 7 };
        let respuesta_registro = Respuesta::Registro {
            desde: 7,
            bloques: vec![],
            longitud: 10,
        };
        assert!(respuesta_registro.responde_a(&peticion_registro));
        assert!(!respuesta_registro.responde_a(&Peticion::Estado));
        assert!(!Respuesta::Bloques(vec![]).responde_a(&peticion_registro));
        assert!(!Respuesta::CabecerasPow(vec![]).responde_a(&peticion_registro));
    }

    /// La cota de puntas PoST es la declarada.
    #[test]
    fn la_cota_de_puntas_post_es_dieciseis() {
        assert_eq!(MAX_PUNTAS_POST, 16);
    }
}
