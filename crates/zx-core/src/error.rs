//! Jerarquía de errores de `zx-core`.
//!
//! Dos capas, por diseño:
//!
//! - **Errores por módulo** ([`EncodingError`]…): un dato inválido llegado de un par no confiable.
//!   Es el caso **esperado**: se rechaza el objeto y la vida sigue.
//! - [`CoreError::InternalInvariant`]: una invariante que este propio crate debía garantizar y no
//!   garantizó. Es un **bug**, no un bloque inválido. Existe porque los lints del workspace
//!   prohíben `panic!`, así que un bug tiene que viajar como valor.
//!
//! La distinción importa operativamente: lo primero se cuenta y se ignora, lo segundo se alerta.
//! En ambos casos se **falla cerrado** — se rechaza —, nunca se continúa.

use thiserror::Error;

/// Fallos al decodificar o codificar la preimagen canónica (SPEC §2).
#[derive(Debug, Error, PartialEq, Eq, Clone)]
pub enum EncodingError {
    /// El buffer se acabó antes de leer el campo completo.
    #[error("datos insuficientes: se esperaban {esperados} bytes, quedaban {disponibles}")]
    Truncado {
        /// Bytes que el campo necesitaba.
        esperados: usize,
        /// Bytes que realmente quedaban.
        disponibles: usize,
    },

    /// C-ENC-05: un `CompactSize` codificado de forma no mínima.
    ///
    /// No es pedantería. Sin esta regla un minero puede probar varias codificaciones distintas del
    /// mismo objeto contra el filtro de dificultad, en vez de solo la intencionada.
    #[error(
        "C-ENC-05: CompactSize no mínimo — el valor {valor} se codificó con el prefijo {prefijo:#04x}, \
         pero cabía en una forma más corta"
    )]
    CompactSizeNoMinimo {
        /// Valor decodificado.
        valor: u64,
        /// Byte de prefijo que se usó.
        prefijo: u8,
    },
}

/// Error agregado de `zx-core`.
#[derive(Debug, Error)]
pub enum CoreError {
    /// Fallo de codificación canónica (SPEC §2).
    #[error(transparent)]
    Encoding(#[from] EncodingError),

    /// Una invariante interna de `zx-core` se rompió.
    ///
    /// **No es un rechazo de dato ajeno: es un bug de este crate.** No debería poder ocurrir con
    /// datos válidos por construcción. Si aparece en producción, quien lo reciba **MUST** tratarlo
    /// como alerta, no como "un bloque inválido más" — y de todas formas rechazar.
    #[error("invariante interna rota (bug de zx-core): {0}")]
    InternalInvariant(&'static str),
}
