//! Mensajes del protocolo de sincronización (SPEC §16.1).
//!
//! # El saludo va primero, y no es cortesía
//!
//! Antes de pedir nada, los dos extremos intercambian un [`Estado`]: dónde está tu punta, cuánto
//! trabajo llevas, y **de qué génesis vienes**. Es el patrón `Status` de Ethereum
//! (`consensus-specs`, `p2p-interface.md`), donde la spec lo hace obligatorio:
//!
//! > *"The dialing client MUST send a Status request upon connection."*
//!
//! Sirve para dos cosas distintas. La primera es decidir **quién pide a quién**: el que va por
//! detrás sincroniza del que va por delante, y sin el saludo los dos se pedirían cabeceras
//! mutuamente. La segunda es más importante: el **hash del génesis** detecta que estás hablando
//! con otra cadena aunque el prefijo mágico haya coincidido. C-NET-01 evita que dos redes se
//! saluden; esto evita que dos *bifurcaciones* de la misma red pierdan el tiempo.
//!
//! # Por qué la petición de cabeceras lleva un *locator* y no una altura
//!
//! Pedir "las cabeceras desde la altura 1000" supone que los dos estáis en la misma cadena. Un
//! **locator** —una lista de hashes conocidos, densa cerca de la punta y espaciada hacia atrás—
//! no lo supone: el otro extremo busca el primero que reconoce y responde desde ahí. Es lo que
//! permite descubrir el punto de bifurcación en `O(log n)` peticiones en vez de una búsqueda
//! lineal, y es el mecanismo de Bitcoin desde el principio.

use zx_core::digest::BlockHash;
use zx_core::preimage::block::BlockHeader;
use zx_core::tx::Tx;

/// Un bloque tal y como viaja: cabecera, transacciones y testigos.
///
/// Es una versión **con dueño** de lo que `zx-consensus` valida por referencia. Vive aquí y no allí
/// porque este crate no depende de consenso (ver el diagrama en `lib.rs`), y sus tres campos son
/// tipos de `zx-core`.
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct BloqueRed {
    /// Cabecera.
    pub cabecera: BlockHeader,
    /// Transacciones, la primera de las cuales es la coinbase.
    pub txs: Vec<Tx>,
    /// `testigos[i][j]` es el testigo de la entrada `j` de la transacción `i`.
    pub testigos: Vec<Vec<Vec<u8>>>,
}

/// Lo que un peer dice de sí mismo al saludar.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct Estado {
    /// Hash del génesis. **Distinto ⇒ no hay nada que hablar**, aunque el prefijo mágico cuadrase.
    pub genesis: BlockHash,
    /// Hash de su punta.
    pub tip: BlockHash,
    /// Altura de su punta.
    pub altura: u32,
    /// Trabajo acumulado de su cadena, en big-endian de 32 bytes.
    ///
    /// Va en bytes crudos y no como entero porque el fork choice es de `zx-consensus` y este crate
    /// no lo ve. Aquí solo se transporta; quien compare será quien sepa comparar.
    pub trabajo: [u8; 32],
}

/// Lo que se le pide a un peer.
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum Peticion {
    /// Saludo. Se manda al conectar, antes que nada.
    Estado,
    /// Cabeceras a partir del primer hash del locator que el otro reconozca.
    Cabeceras {
        /// Hashes conocidos, **de la punta hacia atrás**, densos al principio y espaciados después.
        locator: Vec<BlockHash>,
        /// Dónde parar. `None` = hasta donde quepa en la respuesta.
        hasta: Option<BlockHash>,
    },
    /// Cuerpos de bloque, por hash. Solo se piden **tras** validar sus cabeceras (C-NET-03).
    Bloques {
        /// Los bloques que faltan.
        hashes: Vec<BlockHash>,
    },
    /// **Relé compacto.** Las transacciones que faltan de un bloque anunciado, por índice.
    ///
    /// El `bloque` correlaciona la petición con el anuncio en curso (H-03 §2.2).
    FaltantesCompactas {
        /// Hash de la cabecera anunciada.
        bloque: BlockHash,
        /// Índices `u32` estrictamente crecientes y únicos, dentro del número anunciado.
        indices: Vec<u32>,
    },
}

/// Lo que un peer responde.
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum Respuesta {
    /// Respuesta al saludo.
    Estado(Estado),
    /// Cabeceras consecutivas, de menor a mayor altura.
    Cabeceras(Vec<BlockHeader>),
    /// Bloques completos, **en el orden en que se pidieron**.
    Bloques(Vec<BloqueRed>),
    /// **Relé compacto.** Las transacciones pedidas, en el mismo orden que la petición.
    FaltantesCompactas {
        /// Hash de la cabecera a la que pertenecen.
        bloque: BlockHash,
        /// Pares `(transacción, testigos)`, en el orden de los índices pedidos.
        transacciones: Vec<(Tx, Vec<Vec<u8>>)>,
    },
    /// "No tengo eso." No es un error: un peer honesto puede no tener un bloque que ya podó, o que
    /// pertenece a una rama que él descartó.
    ///
    /// Distinguirlo de un error de protocolo importa por C-NET-05: esto **no puntúa**.
    NoDisponible,
}

impl Peticion {
    /// Discriminante de wire. Son consenso de protocolo: no se reordenan.
    pub const DISC_ESTADO: u8 = 0x00;
    /// Discriminante de [`Peticion::Cabeceras`].
    pub const DISC_CABECERAS: u8 = 0x01;
    /// Discriminante de [`Peticion::Bloques`].
    pub const DISC_BLOQUES: u8 = 0x02;
    /// Discriminante de [`Peticion::FaltantesCompactas`]. **Nuevo; los anteriores no se mueven.**
    pub const DISC_FALTANTES: u8 = 0x03;

    /// El byte que identifica esta variante.
    #[must_use]
    pub const fn discriminante(&self) -> u8 {
        match self {
            Self::Estado => Self::DISC_ESTADO,
            Self::Cabeceras { .. } => Self::DISC_CABECERAS,
            Self::Bloques { .. } => Self::DISC_BLOQUES,
            Self::FaltantesCompactas { .. } => Self::DISC_FALTANTES,
        }
    }
}

impl Respuesta {
    /// Discriminante de [`Respuesta::Estado`].
    pub const DISC_ESTADO: u8 = 0x00;
    /// Discriminante de [`Respuesta::Cabeceras`].
    pub const DISC_CABECERAS: u8 = 0x01;
    /// Discriminante de [`Respuesta::Bloques`].
    pub const DISC_BLOQUES: u8 = 0x02;
    /// Discriminante de [`Respuesta::NoDisponible`].
    pub const DISC_NO_DISPONIBLE: u8 = 0x03;
    /// Discriminante de [`Respuesta::FaltantesCompactas`]. **Nuevo; empieza en 0x04 porque 0x03 ya
    /// estaba tomado por `NoDisponible`, que no se mueve.**
    pub const DISC_FALTANTES: u8 = 0x04;

    /// El byte que identifica esta variante.
    #[must_use]
    pub const fn discriminante(&self) -> u8 {
        match self {
            Self::Estado(_) => Self::DISC_ESTADO,
            Self::Cabeceras(_) => Self::DISC_CABECERAS,
            Self::Bloques(_) => Self::DISC_BLOQUES,
            Self::FaltantesCompactas { .. } => Self::DISC_FALTANTES,
            Self::NoDisponible => Self::DISC_NO_DISPONIBLE,
        }
    }

    /// ¿Responde esta respuesta a esa petición?
    ///
    /// **Comprobarlo no es paranoia.** libp2p correlaciona petición y respuesta por identificador
    /// de stream, así que un peer no puede colar una respuesta a una petición que no hiciste. Pero
    /// **sí puede responder con el tipo equivocado**: pides cabeceras y te manda bloques. Sin esta
    /// comprobación, el código de sincronización tendría que hacer `match` sobre una respuesta que
    /// no espera, y el camino menos malo de ese `match` acaba siendo ignorarla en silencio.
    #[must_use]
    pub const fn responde_a(&self, p: &Peticion) -> bool {
        matches!(
            (self, p),
            (Self::Estado(_), Peticion::Estado)
                | (Self::Cabeceras(_), Peticion::Cabeceras { .. })
                | (Self::Bloques(_), Peticion::Bloques { .. })
                | (
                    Self::FaltantesCompactas { .. },
                    Peticion::FaltantesCompactas { .. }
                )
                // NoDisponible vale para cualquier petición de datos, pero NO para el saludo:
                // un peer que no sabe decir quién es no sirve para nada.
                | (
                    Self::NoDisponible,
                    Peticion::Cabeceras { .. }
                        | Peticion::Bloques { .. }
                        | Peticion::FaltantesCompactas { .. }
                )
        )
    }
}

#[cfg(test)]
mod tests {
    use super::{Estado, Peticion, Respuesta};
    use zx_core::digest::{BlockHash, Digest};

    fn h(n: u8) -> BlockHash {
        BlockHash::from_digest(Digest::from_bytes([n; 32]))
    }

    fn estado() -> Estado {
        Estado {
            genesis: h(1),
            tip: h(2),
            altura: 100,
            trabajo: [3; 32],
        }
    }

    /// Los discriminantes son distintos entre sí en cada enum. Si dos coincidieran, un mensaje se
    /// decodificaría como otro.
    #[test]
    fn los_discriminantes_no_colisionan() {
        let peticiones = [
            Peticion::Estado,
            Peticion::Cabeceras {
                locator: vec![],
                hasta: None,
            },
            Peticion::Bloques { hashes: vec![] },
            Peticion::FaltantesCompactas {
                bloque: h(0),
                indices: vec![],
            },
        ];
        let mut vistos = Vec::new();
        for p in &peticiones {
            assert!(!vistos.contains(&p.discriminante()), "{p:?} colisiona");
            vistos.push(p.discriminante());
        }

        let respuestas = [
            Respuesta::Estado(estado()),
            Respuesta::Cabeceras(vec![]),
            Respuesta::Bloques(vec![]),
            Respuesta::FaltantesCompactas {
                bloque: h(0),
                transacciones: vec![],
            },
            Respuesta::NoDisponible,
        ];
        let mut vistos = Vec::new();
        for r in &respuestas {
            assert!(!vistos.contains(&r.discriminante()), "{r:?} colisiona");
            vistos.push(r.discriminante());
        }

        // Los viejos NO se han movido: son consenso de protocolo.
        assert_eq!(Peticion::Estado.discriminante(), 0x00);
        assert_eq!(Peticion::DISC_CABECERAS, 0x01);
        assert_eq!(Peticion::DISC_BLOQUES, 0x02);
        assert_eq!(Respuesta::DISC_ESTADO, 0x00);
        assert_eq!(Respuesta::DISC_CABECERAS, 0x01);
        assert_eq!(Respuesta::DISC_BLOQUES, 0x02);
        assert_eq!(Respuesta::DISC_NO_DISPONIBLE, 0x03);
        assert_eq!(Peticion::DISC_FALTANTES, 0x03);
        assert_eq!(Respuesta::DISC_FALTANTES, 0x04);
    }

    /// Cada respuesta responde a su petición y **solo** a la suya.
    #[test]
    fn una_respuesta_del_tipo_equivocado_se_detecta() {
        let cabeceras = Peticion::Cabeceras {
            locator: vec![h(1)],
            hasta: None,
        };
        let bloques = Peticion::Bloques { hashes: vec![h(1)] };
        let faltantes = Peticion::FaltantesCompactas {
            bloque: h(1),
            indices: vec![1, 2],
        };

        assert!(Respuesta::Estado(estado()).responde_a(&Peticion::Estado));
        assert!(Respuesta::Cabeceras(vec![]).responde_a(&cabeceras));
        assert!(Respuesta::Bloques(vec![]).responde_a(&bloques));
        assert!(
            Respuesta::FaltantesCompactas {
                bloque: h(1),
                transacciones: vec![]
            }
            .responde_a(&faltantes)
        );

        // Los cruces, que son lo que de verdad se comprueba aquí.
        assert!(!Respuesta::Cabeceras(vec![]).responde_a(&bloques));
        assert!(!Respuesta::Bloques(vec![]).responde_a(&cabeceras));
        assert!(!Respuesta::Estado(estado()).responde_a(&cabeceras));
        assert!(!Respuesta::Cabeceras(vec![]).responde_a(&Peticion::Estado));
        assert!(
            !Respuesta::FaltantesCompactas {
                bloque: h(1),
                transacciones: vec![]
            }
            .responde_a(&bloques)
        );
    }

    /// `NoDisponible` vale para datos, **nunca** para el saludo.
    ///
    /// Un peer que responde "no disponible" a "¿quién eres?" no es un peer con el que se pueda
    /// hacer nada: no se sabe si va por delante, por detrás, ni si es de esta cadena.
    #[test]
    fn no_disponible_no_vale_como_saludo() {
        assert!(!Respuesta::NoDisponible.responde_a(&Peticion::Estado));
        assert!(Respuesta::NoDisponible.responde_a(&Peticion::Bloques { hashes: vec![] }));
        assert!(Respuesta::NoDisponible.responde_a(&Peticion::Cabeceras {
            locator: vec![],
            hasta: None
        }));
    }
}
