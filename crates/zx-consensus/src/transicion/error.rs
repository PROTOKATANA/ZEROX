//! Errores del motor de transición (`ErrorTransicion`).
//!
//! Los nombres de las variantes son **los mismos** que el `Err` del oráculo T01 (`ORDEN-W03` §3.9),
//! más los propios de la implementación real. La correspondencia declarada para el diferencial está
//! en §4 de la orden:
//!
//! - [`ErrorTransicion::ErrFirma`] equivale a `ErrAutorizacion` de T01;
//! - [`ErrorTransicion::ErrForma`] transporta el [`ErrorFormaTx`] de `zx-core` y §4 fija qué
//!   variantes cuentan como qué nombre de T01.

use thiserror::Error;
use zx_core::ErrorFormaTx;

/// Fallo al aplicar un bloque o al rehacer el estado.
#[derive(Debug, Error, PartialEq, Eq, Clone)]
pub enum ErrorTransicion {
    /// El bloque génesis no respeta `C-GEN-03`, o un génesis aparece fuera de la fase génesis.
    #[error("ErrGenesis")]
    ErrGenesis,
    /// `pow_ok`/`prueba_valida` en falso (§3.2).
    #[error("ErrPow")]
    ErrPow,
    /// Emisión por encima del subsidio más tarifas, o coinbase mal colocada o ausente donde se exige.
    #[error("ErrEmision")]
    ErrEmision,
    /// Gasto de una salida `coinbase_pow` antes de su madurez (`TRN-02`, `TRN-02b`).
    #[error("ErrInmaduro")]
    ErrInmaduro,
    /// Depósito en fase PoW antes de `H_dep`.
    #[error("ErrDepositoTemprano")]
    ErrDepositoTemprano,
    /// Operación de garantía cuyo firmante no es la clave, o entrada cuya firma no verifica.
    #[error("ErrAutorizacion")]
    ErrAutorizacion,
    /// Saldo insuficiente o desajuste de valor en un depósito.
    #[error("ErrSaldo")]
    ErrSaldo,
    /// Entrada repetida, entrada inexistente o salida creada dos veces.
    #[error("ErrDobleGasto")]
    ErrDobleGasto,
    /// Bloque PoW cuyo padre es terminal o descendiente de un terminal (`TRN-05`).
    #[error("ErrPowTrasCorte")]
    ErrPowTrasCorte,
    /// Bloque PoST sin terminal en su pasado (`TRN-06`).
    #[error("ErrSinTerminal")]
    ErrSinTerminal,
    /// Dos terminales en el pasado de un bloque PoST. Reservado: no alcanzable con un padre.
    #[error("ErrTerminalAmbiguo")]
    ErrTerminalAmbiguo,
    /// El productor no alcanza `requisito(B)` en `past(B)` (`TRN-07`).
    #[error("ErrGarantia")]
    ErrGarantia,
    /// Operación válida solo en la otra fase (`TRN-04`, `X-13`, `X-14`).
    #[error("ErrOperacionFase")]
    ErrOperacionFase,
    /// Prueba de sector después de `P_sec` (`TRN-12`). Fuera de alcance en `SEC-0`.
    #[error("ErrPruebaTardia")]
    ErrPruebaTardia,
    /// Bloque PoST que usa un sector no activo. Fuera de alcance en `SEC-0`.
    #[error("ErrSectorInactivo")]
    ErrSectorInactivo,
    /// Altura, slot o peso que no progresan (`R-10`).
    #[error("ErrSlot")]
    ErrSlot,
    /// Desbordamiento aritmético detectado; nunca silencioso.
    #[error("ErrDesbordamiento")]
    ErrDesbordamiento,
    /// Operación declarada en el contrato pero no modelada en v0 (`SEC-A`, evidencias).
    #[error("ErrFueraDeAlcanceV0")]
    ErrFueraDeAlcanceV0,
    /// Segundo retiro de una clave con una retirada viva (`R-2`).
    #[error("ErrRetiroPendiente")]
    ErrRetiroPendiente,
    /// La firma de una entrada o de aceptación no verifica (equivale a `ErrAutorizacion` de T01).
    #[error("ErrFirma")]
    ErrFirma,
    /// Fallo de forma de una transacción o de una cabecera PoST (`zx-core`).
    #[error("ErrForma: {0}")]
    ErrForma(#[from] ErrorFormaTx),
    /// Un bloque cuyo padre no es válido o no se conoce (`R-15`).
    #[error("ErrSinPadre")]
    ErrSinPadre,
}

impl ErrorTransicion {
    /// Nombre del error tal y como lo escribe el oráculo T01, para el diferencial.
    ///
    /// Aplica las correspondencias de §4 de la orden: `ErrFirma` se lee como `ErrAutorizacion` y
    /// los errores de forma concretos se leen como el nombre de T01 que sustituyen.
    #[must_use]
    pub fn nombre_t01(&self) -> &'static str {
        match self {
            Self::ErrFirma | Self::ErrAutorizacion => "ErrAutorizacion",
            Self::ErrForma(ErrorFormaTx::VersionInactiva { .. }) => "VersionInactiva",
            Self::ErrForma(ErrorFormaTx::ImporteCero) => "ErrSaldo",
            Self::ErrForma(ErrorFormaTx::TransferenciaSinSalidas) => "ErrSaldo",
            Self::ErrGenesis => "ErrGenesis",
            Self::ErrPow => "ErrPow",
            Self::ErrEmision => "ErrEmision",
            Self::ErrInmaduro => "ErrInmaduro",
            Self::ErrDepositoTemprano => "ErrDepositoTemprano",
            Self::ErrSaldo => "ErrSaldo",
            Self::ErrDobleGasto => "ErrDobleGasto",
            Self::ErrPowTrasCorte => "ErrPowTrasCorte",
            Self::ErrSinTerminal => "ErrSinTerminal",
            Self::ErrTerminalAmbiguo => "ErrTerminalAmbiguo",
            Self::ErrGarantia => "ErrGarantia",
            Self::ErrOperacionFase => "ErrOperacionFase",
            Self::ErrPruebaTardia => "ErrPruebaTardia",
            Self::ErrSectorInactivo => "ErrSectorInactivo",
            Self::ErrSlot => "ErrSlot",
            Self::ErrDesbordamiento => "ErrDesbordamiento",
            Self::ErrFueraDeAlcanceV0 => "ErrFueraDeAlcanceV0",
            Self::ErrRetiroPendiente => "ErrRetiroPendiente",
            Self::ErrForma(_) => "ErrForma",
            Self::ErrSinPadre => "ErrSinPadre",
        }
    }
}
