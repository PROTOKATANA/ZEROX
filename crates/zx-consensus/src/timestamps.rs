//! Reglas de timestamp (`C-TS-01`, `C-TS-03`, `C-TS-05`).
//!
//! # Aquí no existe la hora de red
//!
//! `C-TS-04` prohíbe usar mediana de pares, NTP o cualquier hora ajustada. Solo el reloj local.
//!
//! No es purismo: con un `FTL` de minutos, la regla «revert to node time» de Bitcoin y Zcash abriría
//! un ataque Sybil al 33 %. Al eliminar la hora de pares del consenso, la vulnerabilidad deja de
//! existir en lugar de mitigarse.

use crate::error::ErrorPow;

/// `C-TS-01` · Monotonía: `ts(H) > ts(H−1)`. Rechazo **permanente**.
///
/// # Errores
/// [`ErrorPow::TimestampNoMonotono`].
pub fn comprobar_monotonia(altura: u32, ts: i64, ts_padre: i64) -> Result<(), ErrorPow> {
    if ts > ts_padre {
        Ok(())
    } else {
        Err(ErrorPow::TimestampNoMonotono {
            altura,
            ts,
            ts_padre,
        })
    }
}

/// `C-TS-03` · Future Time Limit: `ts(H) ≤ reloj_local + ftl`.
///
/// Rechazo **NO permanente**. Quien reciba este error **MUST** diferir el bloque y reintentarlo, y
/// **MUST NOT** cachearlo como inválido ni banear al par: cachearlo produce un split garantizado
/// ante una partición temporal.
///
/// `ftl` sale del perfil de red (`N·T/20`); `reloj_local` es el reloj del propio nodo, nunca una
/// hora de red (`C-TS-04`).
///
/// # Errores
/// [`ErrorPow::TimestampDemasiadoFuturo`].
pub fn comprobar_ftl(ts: i64, reloj_local: i64, ftl: i64) -> Result<(), ErrorPow> {
    let limite = reloj_local
        .checked_add(ftl)
        .ok_or(ErrorPow::DesbordamientoAritmetico)?;
    if ts <= limite {
        Ok(())
    } else {
        Err(ErrorPow::TimestampDemasiadoFuturo { ts, limite })
    }
}

/// `C-TS-05` · Timestamp que debe poner un minero. **No es regla de consenso.**
///
/// `ts = max(reloj_local, ts(padre) + 1)`. El minero además **no debe publicar** hasta que
/// `ts ≤ reloj_local + ftl`, cosa que esta función no puede imponer.
#[must_use]
pub fn timestamp_del_minero(reloj_local: i64, ts_padre: i64) -> i64 {
    reloj_local.max(ts_padre.saturating_add(1))
}

#[cfg(test)]
#[expect(clippy::unwrap_used, reason = "los tests fallan con panic por diseño")]
mod tests {
    use super::{comprobar_ftl, comprobar_monotonia, timestamp_del_minero};
    use crate::error::ErrorPow;

    #[test]
    fn la_monotonia_es_estricta_y_permanente() {
        assert!(comprobar_monotonia(7, 101, 100).is_ok());
        let e = comprobar_monotonia(7, 100, 100).unwrap_err();
        assert!(matches!(e, ErrorPow::TimestampNoMonotono { .. }), "{e:?}");
        assert!(e.es_permanente());
    }

    #[test]
    fn el_ftl_es_no_permanente_y_depende_del_perfil() {
        assert!(
            comprobar_ftl(1_540, 1_000, 540).is_ok(),
            "justo en el límite"
        );
        let e = comprobar_ftl(1_541, 1_000, 540).unwrap_err();
        assert!(
            matches!(e, ErrorPow::TimestampDemasiadoFuturo { limite: 1_540, .. }),
            "{e:?}"
        );
        assert!(
            !e.es_permanente(),
            "C-TS-03: se difiere y se reintenta, nunca se cachea"
        );
    }

    #[test]
    fn el_minero_avanza_respecto_al_padre() {
        assert_eq!(timestamp_del_minero(1_000, 999), 1_000);
        assert_eq!(timestamp_del_minero(1_000, 1_000), 1_001);
        assert_eq!(timestamp_del_minero(1_000, i64::MAX), i64::MAX);
    }
}
