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

    /// El bloque génesis no cumple alguna invariante de §15.
    ///
    /// C-GEN-01 exige que esto **aborte el arranque del nodo**, no que se registre y se siga.
    #[error("§15: génesis inválido: {motivo}")]
    GenesisInvalido {
        /// Qué invariante se rompe.
        motivo: &'static str,
    },

    /// El timestamp de la cabecera no cabe en `i64`.
    ///
    /// La cabecera lo lleva en `u64` y la aritmética de dificultad va en `i64`. Un `as` lo
    /// convertiría en negativo en silencio, que es justo lo que C-ENC-03 prohíbe.
    #[error("timestamp {ts} fuera del rango representable")]
    TimestampFueraDeRango {
        /// Valor leído.
        ts: u64,
    },

    /// C-BLK-04: el hash de cabecera no satisface el PoW.
    #[error("C-BLK-04: el PoW no se satisface")]
    PowInsuficiente,

    /// C-BLK-05: `bits` no es el valor que devuelve el retarget.
    #[error("C-BLK-05: bits esperado {esperado:#010x}, encontrado {encontrado:#010x}")]
    BitsIncorrectos {
        /// El que debería llevar.
        esperado: u32,
        /// El que lleva.
        encontrado: u32,
    },

    /// C-BLK-07: el bloque no empieza por una coinbase.
    #[error("C-BLK-07: la primera transacción MUST ser una coinbase")]
    BloqueSinCoinbase,

    /// C-BLK-07: hay una coinbase que no es la primera.
    #[error("C-BLK-07: solo la primera transacción puede ser coinbase")]
    CoinbaseFueraDeSitio,

    /// C-EMIT-04: la coinbase no declara su altura en `expiry_height`.
    ///
    /// Sin esta regla, dos coinbases de alturas distintas con las mismas salidas tendrían **el
    /// mismo txid**, porque el testigo no entra en el txid.
    #[error("C-EMIT-04: la coinbase de la altura {altura} declara expiry_height {expiry_height}")]
    CoinbaseSinAltura {
        /// Altura del bloque.
        altura: u32,
        /// Lo que declara la coinbase.
        expiry_height: u32,
    },

    /// C-BLK-01: la raíz de Merkle no compromete estas transacciones.
    #[error("C-BLK-01: la raíz de Merkle no coincide con las transacciones del bloque")]
    MerkleRootIncorrecta,

    /// C-EMIT-03: la coinbase reclama más que el subsidio más las comisiones.
    #[error("C-EMIT-03: la coinbase cobra {cobrado} brek, máximo {maximo}")]
    CoinbaseCobraDeMas {
        /// Lo que reclama.
        cobrado: u128,
        /// Subsidio + fees.
        maximo: u128,
    },

    /// C-UPG-02: ninguna rama de consenso cubre esa altura.
    #[error("C-UPG-02: no hay rama de consenso activa a la altura {altura}")]
    SinRamaActiva {
        /// Altura consultada.
        altura: u32,
    },

    /// C-HDR-02b: la cabecera declara una rama de consenso que no es la activa.
    ///
    /// Es lo que da la protección contra *wipe-out*: un bloque de la rama vieja no puede competir
    /// a alturas donde rige otra rama.
    #[error(
        "C-HDR-02b: a la altura {altura} rige la rama {esperado:#010x}, la cabecera dice {encontrado:#010x}"
    )]
    BranchIdIncorrecto {
        /// Altura del bloque.
        altura: u32,
        /// Identificador que debería llevar.
        esperado: u32,
        /// El que lleva.
        encontrado: u32,
    },

    /// La tabla de ramas está mal formada.
    #[error("tabla de ramas inválida: {motivo}")]
    TablaDeRamasInvalida {
        /// Qué invariante se rompe.
        motivo: &'static str,
    },

    /// C-TX-07: versión de transacción fuera del conjunto activo a esa altura.
    #[error("C-TX-07: versión de tx {version} no admitida")]
    VersionDeTxNoAdmitida {
        /// Versión leída.
        version: u32,
    },

    /// C-TX-17: la transacción no tiene entradas o no tiene salidas.
    #[error("C-TX-17: la transacción MUST tener al menos una entrada y una salida")]
    TxSinEntradasOSalidas,

    /// C-TX-08: la transacción caducó.
    #[error("C-TX-08: tx expirada — altura {altura} > expiry_height {expiry_height}")]
    TxExpirada {
        /// Altura del bloque.
        altura: u32,
        /// Altura de expiración declarada.
        expiry_height: u32,
    },

    /// C-TX-13: la entrada no existe en el UTXO set, o ya está gastada.
    #[error("C-TX-13: la entrada no existe en el UTXO set o ya se gastó")]
    EntradaInexistenteOGastada,

    /// C-TX-16: la misma transacción gasta dos veces el mismo outpoint.
    #[error("C-TX-16: doble gasto dentro de la misma transacción")]
    DobleGastoInterno,

    /// C-BLK-09: dos transacciones del bloque gastan el mismo outpoint.
    #[error("C-BLK-09: dos transacciones del bloque gastan el mismo outpoint")]
    DobleGastoEnBloque,

    /// C-TX-14: las salidas suman más que las entradas.
    #[error("C-TX-14: Σ salidas excede Σ entradas")]
    SalidasExcedenEntradas,

    /// C-EMIT-05: se intenta gastar una coinbase que aún no ha madurado.
    #[error("C-EMIT-05: coinbase inmaduro — altura {altura}, madura en {maduro_en}")]
    CoinbaseInmaduro {
        /// Altura del bloque que intenta gastarla.
        altura: u32,
        /// Altura a partir de la cual se puede gastar.
        maduro_en: u32,
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
