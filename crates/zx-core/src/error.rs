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

    /// C-WIRE-04: un contador declarado absurdamente grande.
    ///
    /// **No es una regla de consenso, es una cota del *parser*.** Sin ella, un peer puede declarar
    /// un `CompactSize` de 2⁶⁴−1 elementos con un cuerpo de veinte bytes y provocar una reserva de
    /// memoria enorme **antes** de que nadie lea un solo elemento — y mucho antes de que el
    /// consenso llegue a opinar sobre el peso.
    #[error("C-WIRE-04: se declararon {declarados} elementos y el máximo del lector es {maximo}")]
    DemasiadosElementos {
        /// Cuántos declaró el emisor.
        declarados: u64,
        /// Cota del lector.
        maximo: u64,
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

    /// La firma no verifica bajo las reglas de ZIP-215.
    #[error("firma inválida: {motivo}")]
    FirmaInvalida {
        /// Por qué se rechaza.
        motivo: &'static str,
    },

    /// C-ENC-06/07: dirección bech32m inválida.
    #[error("C-ENC-06: dirección inválida: {motivo}")]
    DireccionInvalida {
        /// Por qué se rechaza.
        motivo: &'static str,
    },

    /// C-POW-04: `bits` no está en forma canónica.
    #[error("C-POW-04: bits {bits:#010x} no canónico: {motivo}")]
    BitsNoCanonico {
        /// Valor leído.
        bits: u32,
        /// Por qué se rechaza.
        motivo: &'static str,
    },

    /// C-POW-05: el target decodificado sale de `[MIN_TARGET, POW_LIMIT]`.
    #[error("C-POW-05: {motivo}")]
    TargetFueraDeRango {
        /// Por qué se rechaza.
        motivo: &'static str,
    },

    /// Índice de entrada fuera del rango de la transacción.
    #[error("índice de entrada {indice} fuera de rango ({entradas} entradas)")]
    IndiceDeEntradaFueraDeRango {
        /// Índice pedido.
        indice: usize,
        /// Entradas que tiene la transacción.
        entradas: usize,
    },

    /// Estrategia A de padres: `1 <= parent_count <= 15` para un bloque no génesis.
    #[error("Estrategia A: {declarados} padres declarados, máximo {maximo}")]
    DemasiadosPadres {
        /// Cuántos padres se declararon (incluido el seleccionado).
        declarados: u64,
        /// `MAX_PADRES` = 15.
        maximo: u64,
    },

    /// El constructor de padres rechaza duplicados; no los elimina en silencio.
    #[error("Estrategia A: padre adicional duplicado")]
    PadreDuplicado,

    /// Un padre adicional repite el `prev_hash` (padre seleccionado).
    #[error("Estrategia A: un padre adicional es igual al padre seleccionado (`prev_hash`)")]
    PadreRepetidoConSeleccionado,

    /// El parser del wire solo acepta el orden canónico estrictamente ascendente.
    #[error(
        "Estrategia A: los padres adicionales no están en orden canónico estrictamente ascendente"
    )]
    PadresNoCanonicos,

    /// El número de listas de testigos no es exactamente el número de transacciones.
    ///
    /// No se sustituyen listas ausentes por listas vacías al calcular el compromiso del cuerpo.
    #[error("cuerpo: {testigos} listas de testigos para {txs} transacciones")]
    CuerpoTestigosDescuadrados {
        /// Número de transacciones.
        txs: usize,
        /// Número de listas de testigos recibidas.
        testigos: usize,
    },

    /// La justificación PoT declara más de `MAX_BUNDLES_POT = 150` portadores.
    #[error("PoT: {declarados} portadores declarados, máximo {maximo}")]
    DemasiadosBundlesPot {
        /// Cuántos se declararon.
        declarados: u64,
        /// `MAX_BUNDLES_POT` = 150.
        maximo: u64,
    },

    /// Una lista de índices de wire no está en orden estrictamente creciente.
    #[error("índices no canónicos: MUST ser estrictamente crecientes y únicos")]
    IndicesNoCanonicos,
}

/// Fallo al comprobar los compromisos del cuerpo de un bloque DAG.
///
/// Distingue **cuál** de los dos compromisos falla: Merkle cubre efectos, `BodyCommitment` cubre
/// efectos y autorización. Igualarlos no es verificar firmas.
#[derive(Debug, Error, PartialEq, Eq, Clone)]
pub enum CompromisosError {
    /// `merkle_root` no coincide con la raíz recalculada sobre los `txid`.
    #[error("C-BLK-01: la raíz de Merkle no coincide con las transacciones")]
    MerkleNoCoincide,

    /// `body_commitment` no coincide con el recalculado sobre `(txid, auth_digest)`.
    #[error("compromiso del cuerpo no coincide con (txid, auth_digest)")]
    CuerpoNoCoincide,

    /// El número de listas de testigos no cuadra con el de transacciones.
    #[error(transparent)]
    TestigosDescuadrados(#[from] EncodingError),
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
