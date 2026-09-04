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

    /// C-TX-12: un importe negativo o por encima de `ZX_VALUE_SANITY_LIMIT`.
    #[error("C-TX-12: importe fuera de rango: {brek} brek")]
    ImporteFueraDeRango {
        /// Valor rechazado.
        brek: i64,
    },

    /// C-TX-10: byte discriminante de `Lock` desconocido.
    ///
    /// **MUST** rechazarse, nunca tratarse como "gastable por cualquiera".
    #[error("C-TX-10: discriminante de Lock desconocido: {discriminante:#04x}")]
    LockDesconocido {
        /// Byte leído.
        discriminante: u8,
    },

    /// C-TX-11: `MultiSig` con parámetros inválidos.
    #[error("C-TX-11: MultiSig inválido — k={k}, n={n}: {motivo}")]
    MultiSigInvalido {
        /// Umbral de firmas.
        k: u8,
        /// Número de claves.
        n: usize,
        /// Por qué se rechaza.
        motivo: &'static str,
    },

    /// C-SIG-03: `hash_type` fuera del conjunto definido.
    #[error("C-SIG-03: hash_type inválido: {valor:#04x}")]
    HashTypeInvalido {
        /// Byte leído.
        valor: u8,
    },

    /// C-SIG-04: `SIGHASH_SINGLE` sin salida correspondiente.
    #[error(
        "C-SIG-04: SIGHASH_SINGLE en la entrada {indice} sin salida en ese índice ({salidas} salidas)"
    )]
    SingleSinSalida {
        /// Índice de la entrada que se firma.
        indice: usize,
        /// Número de salidas de la transacción.
        salidas: usize,
    },

    /// Índice de entrada fuera del rango de la transacción.
    #[error("índice de entrada {indice} fuera de rango ({entradas} entradas)")]
    IndiceDeEntradaFueraDeRango {
        /// Índice pedido.
        indice: usize,
        /// Entradas que tiene la transacción.
        entradas: usize,
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
