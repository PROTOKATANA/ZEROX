//! Errores de consenso.

use thiserror::Error;

use crate::ghostdag::IdentidadGhostdag;

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

    /// C-BLK-01: la raíz de Merkle recalculada no coincide con la cabecera DAG.
    #[error("C-BLK-01: la raíz de Merkle no coincide con la cabecera DAG")]
    MerkleRaizNoCoincide,

    /// El compromiso completo del cuerpo no coincide con la cabecera DAG.
    #[error("compromiso del cuerpo (txid ‖ auth_digest) no coincide con la cabecera DAG")]
    CuerpoCompromisoNoCoincide,

    /// El número de listas de testigos no es el de transacciones.
    #[error("cuerpo DAG: {testigos} listas de testigos para {txs} transacciones")]
    CuerpoTestigosDescuadrados {
        /// Transacciones.
        txs: usize,
        /// Listas de testigos.
        testigos: usize,
    },

    /// C-HDR-06 (reescrita): `rango_solucion` no es el rango esperado contextual.
    #[error("C-HDR-06: rango_solucion {encontrado}, esperado {esperado}")]
    RangoIncorrecto {
        /// Rango derivado del pasado DAG validado y del flujo.
        esperado: u64,
        /// Rango declarado en la cabecera.
        encontrado: u64,
    },

    /// C-HDR-06 · C-GD-01: un `SR` validado para un bloque se intenta insertar en otro.
    ///
    /// El rango validado queda atado al `block_hash` de la cabecera que lo superó; colocarlo en
    /// un bloque distinto es un error explícito, no una aceptación.
    #[error("C-HDR-06: el SR validado para {validado_para} se intenta usar en {bloque}")]
    RangoDeOtroBloque {
        /// El bloque en el que se intenta insertar.
        bloque: zx_core::BlockHash,
        /// El bloque para el que se validó el `SR`.
        validado_para: zx_core::BlockHash,
    },

    /// C-HDR-06: el contexto de rango no puede resolver el rango esperado para esta vista.
    ///
    /// Es **falta de contexto**, no un veredicto sobre el candidato: el contexto no dispone de la
    /// derivación que C-HDR-06 exige (pasado validado y flujo) para la vista opaca recibida. Por eso
    /// **MUST NOT** confundirse con [`Self::RangoIncorrecto`] ni reutilizar
    /// [`Self::PadreNoValidado`], [`Self::SaltoMayorSmax`] o [`Self::BloqueDesconocido`] para
    /// encubrirlo. La causa concreta viaja como literal tipado, no como rechazo permanente.
    #[error("C-HDR-06: contexto de rango no disponible: {motivo}")]
    ContextoRangoNoDisponible {
        /// Qué premisa contextual falta o no encaja.
        motivo: &'static str,
    },

    /// H-04 · Un bloque con `parent_count = 0` que no es el génesis de la red.
    #[error("C-HDR-01: un bloque no génesis con parent_count = 0")]
    GenesisConCeroPadresNoEsGenesis,

    /// H-04 · El génesis declarado con padres.
    #[error("C-HDR-01: el génesis MUST NOT tener padres")]
    GenesisConPadres,

    /// H-04 · Un padre no está entre los bloques validados del contexto.
    #[error("contexto DAG: el padre {padre} no está validado")]
    PadreNoValidado {
        /// El hash del padre desconocido.
        padre: zx_core::BlockHash,
    },

    /// H-04 · Dos padres en relación de ancestro: el conjunto no es una anticadena.
    #[error("contexto DAG: {antepasado} está en el pasado de {descendiente}, no es anticadena")]
    PadresNoAnticadena {
        /// El padre que aparece antes.
        antepasado: zx_core::BlockHash,
        /// El padre que lo contiene en su pasado.
        descendiente: zx_core::BlockHash,
    },

    /// H-04 · `prev_hash` no es el `sp(B)` de C-GD-03.
    #[error("C-GD-03: padre seleccionado {encontrado}, esperado {esperado}")]
    PadreSeleccionadoIncorrecto {
        /// El que devuelve el contexto.
        esperado: zx_core::BlockHash,
        /// El declarado en `prev_hash`.
        encontrado: zx_core::BlockHash,
    },

    /// C-GD-02 · C-ENC-03: un `blue_work` que desborda `u256` es **fallo de consenso
    /// explícito**, nunca una envoltura ni un truncamiento.
    #[error("C-GD-02: blue_work desborda u256 (C-ENC-03: nunca en silencio)")]
    BlueWorkDesbordado,

    /// C-GD-04 · R-FIN-12: más de 15 padres.
    #[error("R-FIN-12: {declarados} padres, máximo {maximo}")]
    DemasiadosPadresDag {
        /// Padres declarados.
        declarados: u64,
        /// `MAX_PADRES`.
        maximo: u64,
    },

    /// C-GD-04 · R-FIN-12: `|mergeset(B)| + 1 > 180` con `k = 30`.
    #[error("R-FIN-12: |mergeset| + 1 = {tamano}, máximo {maximo}")]
    MergesetExcedeLimite {
        /// `|mergeset(B)| + 1`.
        tamano: u64,
        /// Límite de R-FIN-12.
        maximo: u64,
    },

    /// C-GD-07 · U2: la identidad de billete ya aparece en un padre o su pasado estricto.
    #[error("C-GD-07/U2: el billete {identidad} ya está en el pasado del bloque")]
    BilleteDuplicadoU2 {
        /// Identidad del billete repetida (tupla exacta de `C-GD-07` o fixture sintética).
        identidad: IdentidadGhostdag,
    },

    /// Un hash que el almacén GHOSTDAG no conoce.
    #[error("GHOSTDAG: bloque desconocido {hash}")]
    BloqueDesconocido {
        /// El hash ausente.
        hash: zx_core::BlockHash,
    },

    /// El almacén GHOSTDAG ya tiene ese `block_hash`.
    ///
    /// Es un **duplicado de almacenamiento**, no un veredicto sobre la prueba PoST del bloque ni
    /// motivo automático para penalizar al par: el mismo bloque puede llegar dos veces por
    /// retransmisión. Rechazarlo es lo que impide que `indice.insert` sustituya el índice mientras
    /// `ids` crece y deje dos entradas para un solo id.
    #[error("GHOSTDAG: el bloque {hash} ya está almacenado (duplicado de almacenamiento)")]
    BloqueDuplicado {
        /// El hash repetido.
        hash: zx_core::BlockHash,
    },

    /// Estado GHOSTDAG incoherente: una consulta que por construcción no debería ocurrir.
    #[error("GHOSTDAG: estado incoherente: {motivo}")]
    GhostdagIncoherente {
        /// Qué invariante interna se rompió.
        motivo: &'static str,
    },

    /// C-HDR-05 · C-FLU-02: **algún** padre tiene un `slot` posterior al del bloque.
    ///
    /// La cota es **no estricta** y alcanza a **todos** los padres, no solo al seleccionado
    /// (`sp(B)`, que es el caso particular de `C-GD-03`). Se informa del padre infractor y de los
    /// dos `slot` para poder localizar la violación; el slot se toma del contexto validado, nunca
    /// del candidato.
    #[error(
        "C-HDR-05/C-FLU-02: el padre {padre} tiene slot {slot_padre} posterior a slot(B) = {slot_b}"
    )]
    SlotDePadrePosterior {
        /// Hash del padre infractor.
        padre: zx_core::BlockHash,
        /// `slot` del padre, tomado del contexto.
        slot_padre: u64,
        /// `slot` del bloque candidato.
        slot_b: u64,
    },

    /// C-HDR-05 · C-FLU-02: el contexto no puede dar el `slot` de un padre que dice conocer.
    ///
    /// Sin ese slot la cota no es comprobable. La ausencia **MUST NOT** sustituirse por cero ni
    /// por ningún valor por defecto.
    #[error("contexto DAG: no hay slot contextual para el padre {padre}")]
    SlotDePadreAusente {
        /// Hash del padre cuyo slot falta.
        padre: zx_core::BlockHash,
    },

    /// C-GD-04: `slot(B) − slot(sp(B)) > S_max`.
    #[error("C-GD-04: salto de slot {salto} > S_max")]
    SaltoMayorSmax {
        /// Diferencia de slots.
        salto: u64,
    },
}

impl ConsensusError {
    /// ¿Es un rechazo **permanente**?
    ///
    /// La distinción es de consenso, no cosmética. Un rechazo diferible **MUST NOT** cachearse como
    /// inválido: si un nodo marca permanentemente un bloque que solo llegó pronto, y luego su reloj
    /// se pone al día, se queda fuera de la cadena buena para siempre. C-TS-03 lo dice
    /// explícitamente.
    ///
    /// [`Self::ContextoRangoNoDisponible`] tampoco es permanente: es **falta de contexto** (el
    /// llamante aún no puede resolver el rango esperado de esa vista), no un veredicto sobre el
    /// candidato. Cachearlo como rechazo dejaría fuera un bloque válido que solo necesitaba más
    /// contexto. El resto de variantes conserva su clasificación.
    #[must_use]
    pub const fn es_permanente(&self) -> bool {
        !matches!(
            self,
            Self::TimestampDemasiadoFuturo { .. } | Self::ContextoRangoNoDisponible { .. }
        )
    }
}
