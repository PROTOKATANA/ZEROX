//! Errores del mempool.
//!
//! **Ninguno significa "transacción inválida".** Significan "este nodo no la retransmite". La
//! validez la decide `zx_consensus`, que ni mira la tarifa (C-TX-15).

use thiserror::Error;

/// Motivo por el que el mempool no admite una transacción.
#[derive(Debug, Error, PartialEq, Eq, Clone)]
pub enum MempoolError {
    /// Ya estaba en el mempool.
    #[error("la transacción ya está en el mempool")]
    YaPresente,

    /// Excede `MAX_TX_WEIGHT`. Esta sí sería inválida en un bloque (C-WGT-11), pero se filtra aquí
    /// para no gastar recursos en ella.
    #[error("C-WGT-11: la transacción pesa {peso}, por encima del máximo")]
    ExcedeMaxTxWeight {
        /// Peso de la transacción.
        peso: u64,
    },

    /// No alcanza la tarifa mínima de retransmisión (§5.5).
    ///
    /// **No es invalidez.** Un minero puede incluirla igualmente y el bloque será válido.
    #[error("§5.5: la comisión no alcanza el mínimo de retransmisión (NO invalida la tx)")]
    TarifaInsuficiente,

    /// El mempool está lleno y lo que ya hay paga más.
    #[error("el mempool está lleno y las transacciones presentes pagan más (peso {peso})")]
    NoCabe {
        /// Peso de la que se rechaza.
        peso: u64,
    },
}
