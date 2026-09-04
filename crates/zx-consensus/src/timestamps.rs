//! Reglas de timestamp (SPEC §7.4).
//!
//! # Aquí no existe la hora de red
//!
//! `C-TS-04` prohíbe usar mediana de pares, NTP o cualquier hora ajustada. Solo el reloj local.
//!
//! No es purismo: con `FTL = 540 s`, la regla "revert to node time" de Bitcoin y Zcash abriría un
//! ataque Sybil al 33 %. Al eliminar la hora de pares del consenso, la vulnerabilidad deja de
//! existir en lugar de mitigarse.

use crate::dificultad::FTL;
use crate::error::ConsensusError;

/// C-TS-01 · Monotonía: `ts(H) ≥ ts(H−1) + 1`. Rechazo **permanente**.
///
/// # Errores
/// [`ConsensusError::TimestampNoMonotono`].
pub fn comprobar_monotonia(altura: u32, ts: i64, ts_padre: i64) -> Result<(), ConsensusError> {
    if ts > ts_padre {
        Ok(())
    } else {
        Err(ConsensusError::TimestampNoMonotono {
            altura,
            ts,
            ts_padre,
        })
    }
}

/// C-TS-03 · Future Time Limit: `ts(H) ≤ reloj_local + FTL`.
///
/// Rechazo **NO permanente**. Quien reciba este error **MUST** diferir el bloque y reintentarlo, y
/// **MUST NOT** cachearlo como inválido ni banear al par: cachearlo produce un split garantizado
/// ante una partición temporal.
///
/// `reloj_local` es el reloj del propio nodo, nunca una hora de red (C-TS-04).
///
/// # Errores
/// [`ConsensusError::TimestampDemasiadoFuturo`].
pub fn comprobar_ftl(ts: i64, reloj_local: i64) -> Result<(), ConsensusError> {
    let limite = reloj_local
        .checked_add(FTL)
        .ok_or(ConsensusError::DesbordamientoAritmetico)?;
    if ts <= limite {
        Ok(())
    } else {
        Err(ConsensusError::TimestampDemasiadoFuturo { ts, limite })
    }
}

/// C-TS-05 · Timestamp que debe poner un minero. **No es regla de consenso.**
///
/// `ts = max(reloj_local, ts(padre) + 1)`. El minero además **no debe publicar** hasta que
/// `ts ≤ reloj_local + FTL`, cosa que esta función no puede imponer.
#[must_use]
pub fn timestamp_del_minero(reloj_local: i64, ts_padre: i64) -> i64 {
    reloj_local.max(ts_padre.saturating_add(1))
}
