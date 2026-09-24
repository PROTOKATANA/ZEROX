//! Errores de la capa de estado.

use thiserror::Error;

/// Fallo al manipular el conjunto de UTXO.
///
/// Casi todos indican **corrupción de estado**, no dato ajeno inválido: la validación de consenso
/// ya se ejecutó antes de llegar aquí. Quien los reciba **MUST** tratarlos como alerta.
#[derive(Debug, Error, PartialEq, Eq, Clone)]
pub enum StorageError {
    /// Se intentó insertar un outpoint que ya existía.
    ///
    /// Sobrescribir lo escondería, así que es un error. Un outpoint duplicado significa que algo
    /// falla aguas arriba — o una colisión de txid, que C-EMIT-04 existe para impedir.
    #[error("outpoint duplicado: el conjunto ya contenía esa salida")]
    OutpointDuplicado,

    /// Se intentó gastar o retirar un outpoint que no está.
    ///
    /// Al deshacer un bloque es la **detección de corrupción** de C-REORG-02: si lo que el bloque
    /// creó no está donde debería, el estado ya era incorrecto.
    #[error("outpoint ausente: el conjunto no contiene esa salida")]
    OutpointAusente,

    /// La clave del outpoint está, pero la entrada **no es la que el bloque creó** (C-REORG-02).
    ///
    /// La comparación obligatoria de C-REORG-02 no es solo de existencia: hay que cotejar
    /// `value`, `Lock`, altura de creación y marca de coinbase. Un contenido distinto bajo la
    /// misma clave es corrupción, y retirarlo sin mirar la habría propagado en silencio. Va
    /// separado de [`Self::OutpointAusente`] porque el diagnóstico es distinto.
    #[error(
        "entrada de UTXO incoherente: el conjunto no contiene la salida que el undo data espera"
    )]
    UtxoIncoherente,

    /// Un bloque sin transacciones. Ni siquiera el génesis lo está (C-BLK-07).
    #[error("bloque sin transacciones")]
    BloqueSinTransacciones,

    /// Índice de salida fuera del rango de `u32`.
    #[error("índice de salida fuera de rango")]
    IndiceFueraDeRango,

    /// Se intentó mover la punta a una cabecera que no está guardada.
    ///
    /// **Es la comprobación que convierte un almacén corrupto en un error visible.** Sin ella, un
    /// proceso que muriera entre "escribir la punta" y "escribir la cabecera" dejaría un nodo que
    /// arranca creyendo estar en una altura de la que no tiene datos — y el síntoma aparecería
    /// mucho después, al intentar servirla.
    #[error("C-STORE-01: se intentó fijar la punta en {altura} sin haber guardado su cabecera")]
    PuntaSinCabecera {
        /// La altura que se pedía.
        altura: u32,
    },

    /// Los bytes guardados no decodifican. El almacén está corrupto.
    #[error("almacén corrupto: {que} no decodifica")]
    Corrupto {
        /// Qué no decodificaba.
        que: &'static str,
    },

    /// Una entrada del UTXO set guardada no decodifica (C-STORE-05).
    ///
    /// Va aparte de [`Self::Corrupto`] para no perder el error de dentro: si el `Lock` es lo que
    /// falla, saberlo es la diferencia entre diagnosticar en un minuto y en una tarde.
    #[error("almacén corrupto: entrada de UTXO ({que}): {causa}")]
    UtxoCorrupto {
        /// En qué parte de la entrada falló.
        que: &'static str,
        /// El error de dentro.
        causa: String,
    },

    /// Ya existe una entrada en el índice de bloques DAG admitidos bajo ese `block_hash`.
    ///
    /// A diferencia de la cola de candidatos —donde reintentar con otra justificación PoT
    /// reemplaza la entrada—, el **requisito del futuro escritor** es que una entrada admitida no
    /// se sobrescriba: una segunda versión bajo el mismo hash sería una sustitución silenciosa.
    /// Hoy solo puede dispararlo la inyección de fixture de los tests, porque no existe un escritor
    /// de producción ni, por tanto, bytes verificados que este error pudiera proteger.
    #[error("entrada admitida duplicada: el índice ya contenía ese block_hash")]
    AdmitidoDuplicado,

    /// Fallo del backend de disco.
    #[error("fallo del almacén: {0}")]
    Backend(String),
}
