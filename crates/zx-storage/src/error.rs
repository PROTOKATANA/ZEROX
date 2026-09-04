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

    /// Fallo del backend de disco.
    #[error("fallo del almacén: {0}")]
    Backend(String),
}
