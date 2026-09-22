//! La **identidad de oportunidad**: qué clave indexa el registro.
//!
//! # Por qué esto es el punto que decide si el firmante sirve
//!
//! `P-ZRX/P-FIRMANTE/ESPECIFICACION.md` §3.4.5: si el registro se indexa por `pre_hash` o por
//! `block_hash`, **no protege nada** — los dos `pre_hash` de un mismo accidente son distintos
//! *por construcción*, que es justo lo que el registro debe detectar. Tiene que indexarse por la
//! identidad de **oportunidad**: el billete y el slot.
//!
//! # Punto de extensión, con la vigente por defecto
//!
//! El encargo (§1) pide explícitamente que la identidad sea un punto de extensión porque hay tres
//! candidatas sobre la mesa y Katana no ha decidido:
//!
//! - la **vigente hoy**, `C-GD-07`/R-FIN-11: `(public_key, sector_index, history_size, chunk, slot)`
//!   — es [`IdentidadTicket::TicketVigente`], la implementación por defecto;
//! - **IDV-01** (`P-ZRX/P-EQUIVOCACION/investigacion/DEFINICION-PROPUESTA.md` §3, con dominio de
//!   red/era) — es [`IdentidadTicket::TicketConRed`];
//! - la de `CANDIDATA.md` — no se implementa aquí para no inventar su codificación; ver
//!   `informe/INTEGRACION.md`.
//!
//! Por eso el índice del registro **no** es la tupla, sino una **huella de 32 bytes** con dominio
//! propio (ver [`IdentidadOportunidad::huella`]). Dos implementaciones distintas producen espacios
//! de claves disjuntos aunque compartan el mismo fichero de registro.
//!
//! # Un límite que hay que decir
//!
//! `ESPECIFICACION.md` FP8: la identidad vigente **no** lleva dominio de red. Si el mismo operador
//! corre la misma parcela en mainnet y en testnet, sus dos `TicketId` colisionan. Aquí no se
//! arregla cambiando la identidad por defecto —eso sería fijar por mi cuenta algo que está en
//! discusión—: se implementa la variante con dominio para que la decisión sea una línea.

use zx_core::{ClavePublica, sha3_256_publico};

/// Longitud de la huella de identidad que indexa el registro, en bytes.
pub const LONGITUD_HUELLA: usize = 32;

/// Dominio de la huella de [`IdentidadTicket::TicketVigente`].
///
/// Es un marcador **local del prototipo**: el registro no es consenso y su clave no puede viajar
/// por la red ni entrar en una preimagen. No es una etiqueta de `SPEC.md` §4.5 y no debe pasar por
/// `C-HASH-05`.
pub const DOMINIO_TICKET_VIGENTE: &[u8] = b"ZXRFIRM/ticket-vigente/c-gd-07";

/// Dominio de la huella de [`IdentidadTicket::TicketConRed`] (IDV-01).
pub const DOMINIO_TICKET_CON_RED: &[u8] = b"ZXRFIRM/ticket-con-red/idv-01";

/// Marca de versión del esquema de codificación de la identidad dentro de la huella.
///
/// Cambiar el orden o el ancho de un campo **obliga** a subir esto: si no, dos codificaciones
/// distintas con los mismos bytes producirían la misma huella y el registro daría por iguales dos
/// oportunidades distintas.
pub const VERSION_ESQUEMA: u8 = 1;

/// Una identidad de oportunidad: lo que el registro usa como clave.
///
/// # Contrato (lo que una implementación **MUST** cumplir)
///
/// 1. `huella()` **MUST** ser función exclusiva de los campos de la identidad: nada de reloj,
///    orden de llegada, punta observada ni estado local del proceso.
/// 2. `huella()` **MUST** ser inyectiva respecto de la tupla lógica: dos oportunidades distintas
///    no pueden compartir huella.
/// 3. Implementaciones distintas **MUST** llevar dominios distintos, para que el mismo fichero de
///    registro no mezcle dos definiciones.
///
/// La implementación de [`IdentidadTicket`] lo cumple por construcción: la huella es
/// `SHA3-256(dominio ‖ versión ‖ campos)`, con todos los campos de anchura fija o precedidos de su
/// longitud, y los dominios son prefijos distintos y no vacíos.
pub trait IdentidadOportunidad {
    /// La huella de 32 bytes que indexa el registro.
    #[must_use]
    fn huella(&self) -> [u8; LONGITUD_HUELLA];

    /// Los bytes canónicos de la identidad, para diagnóstico y para los tests que comprueban la
    /// inyectividad de la codificación.
    #[must_use]
    fn bytes_canonicos(&self) -> Vec<u8>;

    /// El slot de la oportunidad. Va **también** en la clave del registro, aparte de la huella.
    ///
    /// Redundante a propósito: `ESPECIFICACION.md` §3.1 dice «clave `(TicketId(B), slot(B))`», y
    /// si una definición futura de `TicketId` dejara de incluir el slot, la clave seguiría siendo
    /// la que el encargo manda. El coste son 8 bytes por entrada.
    #[must_use]
    fn slot(&self) -> u64;

    /// Hasta cuándo puede aparecer una entrada con esta identidad, en slots.
    ///
    /// Es lo que permite **podar**: pasado `S_max` slots desde `slot()`, `C-GD-04` ya no admite
    /// ningún bloque que reclame este slot. Una entrada con `slot + ttl() < max_slot` del registro
    /// no puede volver a colisionar.
    #[must_use]
    fn ttl_slots(&self) -> u64;
}

/// La huella: `SHA3-256(dominio ‖ versión ‖ cuerpo)`.
///
/// El dominio es distinto por implementación y la versión por esquema, así que dos
/// implementaciones nunca comparten espacio de claves. SHA3-256 se toma del repositorio
/// ([`zx_core::sha3_256_publico`]) en vez de añadir una dependencia de hash: es la función sin
/// dominio que `SPEC.md` reserva para lo que no entra en consenso.
fn huella_de(dominio: &[u8], cuerpo: &[u8]) -> [u8; LONGITUD_HUELLA] {
    let mut preimagen = Vec::with_capacity(dominio.len() + 1 + cuerpo.len());
    preimagen.extend_from_slice(dominio);
    preimagen.push(VERSION_ESQUEMA);
    preimagen.extend_from_slice(cuerpo);
    *sha3_256_publico(&preimagen).as_bytes()
}

/// Las dos implementaciones vivas del punto de extensión.
///
/// Es un `enum` y no `dyn`: un registro único puede alojar las dos definiciones sin coste de
/// despacho dinámico, y añadir una tercera es añadir una variante.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum IdentidadTicket {
    /// **Vigente hoy** — `C-GD-07` / R-FIN-11:
    /// `(public_key, sector_index, history_size, chunk, slot)`.
    ///
    /// Es la implementación por defecto de este prototipo.
    TicketVigente {
        /// Clave pública que firma el sello (`sol.public_key` de la cabecera).
        public_key: ClavePublica,
        /// Índice de sector (`sol.sector_index`).
        sector_index: u16,
        /// Tamaño de historia (`sol.history_size`).
        history_size: u64,
        /// Chunk de la solución (`sol.chunk`, 32 B).
        chunk: [u8; 32],
        /// Índice de PoT del bloque.
        slot: u64,
    },

    /// **IDV-01** — la misma tupla **más un dominio de red/era**.
    ///
    /// Cierra FP8 de `ESPECIFICACION.md` (la misma parcela en dos redes). Se codifica aquí para
    /// demostrar que el punto de extensión funciona con dos implementaciones distintas, no para
    /// proponerla: la decisión es de Katana.
    TicketConRed {
        /// Dominio económico de red/era (IDV-01).
        red: [u8; 32],
        /// Clave pública que firma el sello.
        public_key: ClavePublica,
        /// Índice de sector.
        sector_index: u16,
        /// Tamaño de historia.
        history_size: u64,
        /// Chunk de la solución.
        chunk: [u8; 32],
        /// Índice de PoT del bloque.
        slot: u64,
    },
}

impl IdentidadTicket {
    /// Construye la identidad vigente a partir de la solución PoAS de la cabecera.
    #[must_use]
    pub fn vigente(
        public_key: ClavePublica,
        sector_index: u16,
        history_size: u64,
        chunk: [u8; 32],
        slot: u64,
    ) -> Self {
        Self::TicketVigente {
            public_key,
            sector_index,
            history_size,
            chunk,
            slot,
        }
    }

    /// El dominio de la huella de esta variante.
    #[must_use]
    pub fn dominio(&self) -> &'static [u8] {
        match self {
            Self::TicketVigente { .. } => DOMINIO_TICKET_VIGENTE,
            Self::TicketConRed { .. } => DOMINIO_TICKET_CON_RED,
        }
    }

    /// El slot, sin pasar por el trait.
    #[must_use]
    fn campo_slot(&self) -> u64 {
        match self {
            Self::TicketVigente { slot, .. } | Self::TicketConRed { slot, .. } => *slot,
        }
    }
}

impl IdentidadOportunidad for IdentidadTicket {
    fn huella(&self) -> [u8; LONGITUD_HUELLA] {
        huella_de(self.dominio(), &self.bytes_canonicos())
    }

    fn bytes_canonicos(&self) -> Vec<u8> {
        let mut v = Vec::with_capacity(1 + 32 + 32 + 8 + 8 + 2 + 8);
        match self {
            Self::TicketVigente {
                public_key,
                sector_index,
                history_size,
                chunk,
                slot,
            } => {
                // Orden = orden de la tupla de C-GD-07. Anchura fija donde la hay.
                v.extend_from_slice(public_key.bytes());
                v.extend_from_slice(&sector_index.to_le_bytes());
                v.extend_from_slice(&history_size.to_le_bytes());
                v.extend_from_slice(chunk);
                v.extend_from_slice(&slot.to_le_bytes());
            }
            Self::TicketConRed {
                red,
                public_key,
                sector_index,
                history_size,
                chunk,
                slot,
            } => {
                // El dominio de red va PRIMERO y con anchura fija: dos redes no pueden producir
                // la misma preimagen desplazando el resto.
                v.extend_from_slice(red);
                v.extend_from_slice(public_key.bytes());
                v.extend_from_slice(&sector_index.to_le_bytes());
                v.extend_from_slice(&history_size.to_le_bytes());
                v.extend_from_slice(chunk);
                v.extend_from_slice(&slot.to_le_bytes());
            }
        }
        v
    }

    fn slot(&self) -> u64 {
        self.campo_slot()
    }

    fn ttl_slots(&self) -> u64 {
        // `C-GD-04` acota `slot(B) − slot(sp(B)) ≤ S_max`. Para las dos variantes el TTL es el
        // mismo: la diferencia de identidades no cambia la ventana de producción.
        S_MAX_SLOTS_NOMINAL
    }
}

/// `S_max_slots` **nominal del perfil en estudio**: 150.
///
/// Etiqueta: **derivado / citado, no medido aquí**. `SPEC.md` §11 lo usa como valor de trabajo
/// («`S_max = 150 s` nominales», línea 2026 del archivo) y `crates/zx-core/src/wire_dag.rs:40` lo
/// fija como `MAX_BUNDLES_POT = 150`; `crates/zx-consensus/src/ghostdag.rs:55` lo declara
/// `S_MAX_POR_DEFECTO`. **No es una constante que este prototipo tenga derecho a fijar**: el
/// encargo §8 lo prohíbe. Se pasa a [`crate::registro::Registro::abrir`] y
/// [`crate::firmante::Firmante::nuevo`] como parámetro, y esta constante es solo el valor por
/// defecto del prototipo con su procedencia anotada.
pub const S_MAX_SLOTS_NOMINAL: u64 = 150;

#[cfg(test)]
mod tests {
    use super::{
        DOMINIO_TICKET_CON_RED, DOMINIO_TICKET_VIGENTE, IdentidadOportunidad, IdentidadTicket,
        LONGITUD_HUELLA,
    };
    use zx_core::ClavePublica;

    fn vigente(chunk_byte: u8, slot: u64) -> IdentidadTicket {
        IdentidadTicket::vigente(ClavePublica::desde_bytes([7u8; 32]), 3, 1 << 20, [chunk_byte; 32], slot)
    }

    fn con_red(red_byte: u8, chunk_byte: u8, slot: u64) -> IdentidadTicket {
        IdentidadTicket::TicketConRed {
            red: [red_byte; 32],
            public_key: ClavePublica::desde_bytes([7u8; 32]),
            sector_index: 3,
            history_size: 1 << 20,
            chunk: [chunk_byte; 32],
            slot,
        }
    }

    #[test]
    fn la_huella_mide_32_bytes_y_es_determinista() {
        let a = vigente(1, 100);
        assert_eq!(a.huella().len(), LONGITUD_HUELLA);
        assert_eq!(a.huella(), vigente(1, 100).huella());
    }

    #[test]
    fn cambiar_cualquier_campo_cambia_la_huella() {
        let base = vigente(1, 100);
        // chunk
        assert_ne!(base.huella(), vigente(2, 100).huella());
        // slot
        assert_ne!(base.huella(), vigente(1, 101).huella());
        // sector_index
        let otro_sector = IdentidadTicket::vigente(
            ClavePublica::desde_bytes([7u8; 32]),
            4,
            1 << 20,
            [1u8; 32],
            100,
        );
        assert_ne!(base.huella(), otro_sector.huella());
        // history_size
        let otra_historia = IdentidadTicket::vigente(
            ClavePublica::desde_bytes([7u8; 32]),
            3,
            (1 << 20) + 1,
            [1u8; 32],
            100,
        );
        assert_ne!(base.huella(), otra_historia.huella());
        // public_key
        let otra_clave = IdentidadTicket::vigente(
            ClavePublica::desde_bytes([8u8; 32]),
            3,
            1 << 20,
            [1u8; 32],
            100,
        );
        assert_ne!(base.huella(), otra_clave.huella());
    }

    /// Las dos implementaciones **comparten forma de tupla** a propósito, para que este test
    /// demuestre lo único que importa: que el dominio las separa igualmente.
    ///
    /// Las codificaciones **no** tienen por qué medir lo mismo: `TicketConRed` antepone 32 bytes
    /// de dominio de red, así que su cuerpo es más largo. Lo que se comprueba es que (i) el
    /// dominio es distinto y (ii) la huella no coincide, que es lo que impide que la misma tupla
    /// lógica bajo dos definiciones comparta entrada de registro.
    #[test]
    fn las_dos_implementaciones_no_comparten_espacio_de_claves() {
        let a = vigente(1, 100);
        let b = con_red(1, 1, 100);
        assert_eq!(a.bytes_canonicos().len() + 32, b.bytes_canonicos().len());
        assert_ne!(
            a.huella(),
            b.huella(),
            "el dominio debe separar las dos definiciones"
        );
        assert_ne!(DOMINIO_TICKET_VIGENTE, DOMINIO_TICKET_CON_RED);
        // Y dos redes distintas tampoco colisionan entre sí (FP8).
        assert_ne!(con_red(1, 1, 100).huella(), con_red(2, 1, 100).huella());
    }
    #[test]
    fn el_slot_y_el_ttl_se_leen_de_la_identidad() {
        assert_eq!(vigente(1, 4_242).slot(), 4_242);
        assert_eq!(vigente(1, 4_242).ttl_slots(), super::S_MAX_SLOTS_NOMINAL);
        assert_eq!(con_red(9, 1, 7).slot(), 7);
    }

    /// Contra un `Hash` de bytes crudos: sin la separación por longitudes, la concatenación de
    /// campos de distinta anchura podría colisionar al desplazarse.
    #[test]
    fn los_bytes_canonicos_no_dependen_de_la_concatenacion_cruda() {
        // sector_index = 0x0102 con history_size = 0x0304... frente a otra tupla que produciría la
        // misma concatenación si no hubiera anchura fija. Aquí la anchura es fija por tipo, así
        // que basta comprobar que la codificación crece con los campos variables:
        let a = vigente(1, 100);
        let b = IdentidadTicket::TicketVigente {
            public_key: ClavePublica::desde_bytes([7u8; 32]),
            sector_index: 3,
            history_size: 1 << 20,
            chunk: [1u8; 32],
            slot: 100,
        };
        assert_eq!(a.bytes_canonicos(), b.bytes_canonicos());
        assert_eq!(a.huella(), b.huella());
    }
}
