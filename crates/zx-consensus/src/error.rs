//! Errores de consenso.

use thiserror::Error;

/// Fallo al aplicar una regla de consenso.
#[derive(Debug, Error, PartialEq, Eq, Clone)]
pub enum ConsensusError {
    /// La ventana del retarget no tiene el tamaño exacto que exige C-DIFF-02.
    ///
    /// **MUST NOT** encogerse dinámicamente: una ventana más corta produce un target distinto y
    /// por tanto un split.
    #[error(
        "ventana de tamaño incorrecto: {timestamps} timestamps y {targets} targets \
         (se esperan N+1 y N)"
    )]
    VentanaDeTamanoIncorrecto {
        /// Timestamps recibidos.
        timestamps: usize,
        /// Targets recibidos.
        targets: usize,
    },

    /// Ventana vacía donde se esperaba al menos un elemento.
    #[error("ventana vacía")]
    VentanaVacia,

    /// C-ENC-03: desbordamiento detectado. **Nunca en silencio.**
    #[error("C-ENC-03: desbordamiento aritmético en una ruta de consenso")]
    DesbordamientoAritmetico,

    /// C-WGT-09: el peso del bloque excede el límite duro. El bloque es **inválido**.
    #[error("C-WGT-09: peso {peso} excede el límite {limite}")]
    PesoExcedeLimite {
        /// Peso del bloque.
        peso: u64,
        /// `2 · M(H)`.
        limite: u64,
    },

    /// C-WGT-11: una transacción excede `MAX_TX_WEIGHT`.
    #[error("C-WGT-11: la transacción pesa {peso}, máximo {maximo}")]
    TxExcedeMaximo {
        /// Peso de la transacción.
        peso: u64,
        /// `MAX_TX_WEIGHT`.
        maximo: u64,
    },

    /// C-TX-06b/06c: el testigo no tiene el formato que exige el `Lock`.
    #[error("C-TX-06b: testigo mal formado: {motivo}")]
    TestigoMalFormado {
        /// Qué falla.
        motivo: &'static str,
    },

    /// El testigo está bien formado pero no satisface la condición de gasto.
    #[error("condición de gasto no satisfecha: {motivo}")]
    CondicionNoSatisfecha {
        /// Qué falla.
        motivo: &'static str,
    },

    /// C-REORG-07: la reorganización excede la profundidad máxima.
    ///
    /// Quien reciba esto **MUST** detener el nodo y alertar al operador. **MUST NOT** limitarse a
    /// rechazar el bloque y seguir: eso deja al nodo en una minoría de red sin saberlo.
    #[error(
        "C-REORG-07: reorg de {profundidad} bloques excede el máximo de {maximo} — \
         DETENER el nodo y alertar al operador"
    )]
    ReorgDemasiadoProfunda {
        /// Bloques que habría que desconectar.
        profundidad: u32,
        /// `MAX_REORG_LENGTH`.
        maximo: u32,
    },

    /// C-TS-01: el timestamp no avanza respecto al padre. Rechazo **permanente**.
    #[error("C-TS-01: ts({altura}) = {ts} no supera ts(padre) = {ts_padre}")]
    TimestampNoMonotono {
        /// Altura del bloque.
        altura: u32,
        /// Timestamp del bloque.
        ts: i64,
        /// Timestamp del padre.
        ts_padre: i64,
    },

    /// C-TS-03: el timestamp está demasiado en el futuro.
    ///
    /// Rechazo **NO permanente**: el bloque se difiere y se reintenta. **MUST NOT** cachearse como
    /// inválido ni banearse al par — hacerlo produce un split garantizado ante partición temporal.
    #[error("C-TS-03: ts = {ts} excede reloj_local + FTL = {limite} (diferible, NO permanente)")]
    TimestampDemasiadoFuturo {
        /// Timestamp del bloque.
        ts: i64,
        /// Límite admitido.
        limite: i64,
    },
}

impl ConsensusError {
    /// ¿Es un rechazo **permanente**?
    ///
    /// La distinción es de consenso, no cosmética. Un rechazo diferible **MUST NOT** cachearse como
    /// inválido: si un nodo marca permanentemente un bloque que solo llegó pronto, y luego su reloj
    /// se pone al día, se queda fuera de la cadena buena para siempre. C-TS-03 lo dice
    /// explícitamente.
    #[must_use]
    pub const fn es_permanente(&self) -> bool {
        !matches!(self, Self::TimestampDemasiadoFuturo { .. })
    }
}
