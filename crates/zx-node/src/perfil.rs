//! Perfil de la red dev, tal como lo fija `P-ZRX/P-RED-DEV/PERFIL-DEV-v0.md`.
//!
//! Ningún valor de aquí es parámetro de producción (el propio perfil lo dice en su cabecera). Los
//! que dependen del hardware (`N_dev`, `SR_dev`) son argumentos de la CLI, no constantes: la CLI
//! trae valores por defecto razonables para pruebas pequeñas, pero V8 exige poder fijar los reales.

use primitive_types::U256;
use zx_consensus::PARAMETROS_POW_DEV;
use zx_core::{Amount, decodificar_con, trabajo_bloque};
use zx_dag::ghostdag::{Algoritmo, ModoMerge, ModoSp, Parametros as ParametrosGhostdag};

use zx_consensus::transicion::{ParametrosEvidencia, ParametrosTransicion};

/// `H_dep` (§3).
pub const H_DEP: u32 = 1;
/// `M_cb` en bloques PoW (§3).
pub const M_CB: u32 = 5;
/// `M_dep` en bloques PoW (§3).
pub const M_DEP: u32 = 3;
/// `H_corte_min` (§3).
pub const H_CORTE_MIN: u32 = 30;
/// `q` por clave, en ZZK (§3).
pub const Q_ZZK: i64 = 10;
/// `K_min`: una clave por nodo de la red de prueba (§3).
pub const K_MIN: u32 = 3;
/// `M_res_slots` (§3).
pub const M_RES_SLOTS: u64 = 20;
/// `M_dep_slots` (§3).
pub const M_DEP_SLOTS: u64 = 10;
/// `M_rec_slots` (§3).
pub const M_REC_SLOTS: u64 = 30;
/// `R_slots` (`ORDEN-SL4b2` decisión 1: `600`, antes `60`; `= F_SLOTS`, recomendación de SL-2b
/// «`R_slots ≥ F_slots`»; puerta RAT-3: `600 > PLAZO_SLOTS + M_MARGEN_SLOTS = 360`).
pub const R_SLOTS: u64 = 600;
/// `F_slots` (§3).
pub const F_SLOTS: u64 = 600;

/// `Plazo_slots` (`ORDEN-SL4b2` decisión 1, `CONTRATO-EVIDENCIA-v0.md` EV-13): ventana de admisión
/// de una `EvidenceTx` desde `slot_falta`. En `localhost` la segunda cabecera llega en menos de un
/// slot, pero un nodo que reinicia (E-4) o llega tarde (E-5) tiene que poder incluirla todavía: 300
/// slots son de 2,5 a 8 minutos según `N_dev`.
pub const PLAZO_SLOTS: u64 = 300;
/// `M_margen_slots` (`ORDEN-SL4b2` decisión 1, EV-15/EV-15b): margen de inclusión/propagación sobre
/// `Plazo_slots` que exige la puerta RAT-3.
pub const M_MARGEN_SLOTS: u64 = 60;
/// `f = F_NUM/F_DEN` (`ORDEN-SL4b2` decisión 1): fracción confiscada por incidente en la red dev,
/// `1/1` (se confisca la garantía **entera**, RAT-2′).
pub const EVP_F_NUM: u64 = 1;
/// Denominador de `f` (`ORDEN-SL4b2` decisión 1).
pub const EVP_F_DEN: u64 = 1;
/// `S_max_slots` del firmante seguro (`ORDEN-SL4b2` decisión 2, `CONTRATO-EVIDENCIA-v0.md` FIR-10):
/// horizonte de abstención tras perder el registro. Valor nominal de perfil (`SPEC.md` §7.3).
pub const S_MAX_SLOTS: u64 = 150;
/// Tope de evidencias que un bloque propio puede incluir (`ORDEN-SL4b2` decisión 4).
pub const MAX_EVIDENCIAS_POR_BLOQUE: usize = 4;
/// Tope de identidades que el detector de doble firma indexa a la vez (`ORDEN-SL4b2` decisión 3).
pub const MAX_IDENTIDADES_DETECTOR: usize = 65_536;
/// `subsidio_pow(h)`, constante (§3).
pub const SUBSIDIO_POW_ZZK: i64 = 50;
/// `subsidio_post(s)`, constante (§3).
pub const SUBSIDIO_POST_ZZK: i64 = 5;

/// GHOSTDAG `k` (§4).
pub const GHOSTDAG_K: u32 = 10;
/// Máximo de padres reales de un bloque (§4, «formato de cabecera sin cambios»).
pub const MAX_PADRES: u8 = 15;
/// Tope de mergeset: sin cota adicional declarada en el perfil dev más allá del formato de
/// cabecera; se usa el máximo representable para no imponer un límite que el perfil no fija.
pub const MERGESET_LIMITE: u32 = u32::MAX;

/// `subsidio_pow(altura)` constante del perfil dev (§3): 50 ZZK.
#[must_use]
pub fn subsidio_pow(_altura: u32) -> Amount {
    #[expect(
        clippy::unwrap_used,
        reason = "50 ZZK es una constante del perfil dev, siempre representable"
    )]
    Amount::nuevo(SUBSIDIO_POW_ZZK).unwrap()
}

/// `subsidio_post(slot)` constante del perfil dev (§3): 5 ZZK.
#[must_use]
pub fn subsidio_post(_slot: u64) -> Amount {
    #[expect(
        clippy::unwrap_used,
        reason = "5 ZZK es una constante del perfil dev, siempre representable"
    )]
    Amount::nuevo(SUBSIDIO_POST_ZZK).unwrap()
}

/// Fallo al construir el perfil de transición dev.
#[derive(Debug, thiserror::Error)]
pub enum ErrorPerfil {
    /// `PARAMETROS_POW_DEV.bits_iniciales` no decodifica (no debería: es una constante del propio
    /// perfil consensus-critical de W04).
    #[error("bits iniciales del perfil dev inválidos: {0}")]
    BitsIniciales(#[from] zx_core::EncodingError),
    /// `W_min = 30 · trabajo(máximo dev)` desborda `U256` (no debería con el target dev).
    #[error("W_min desborda U256")]
    WMinDesborda,
}

/// `ParametrosTransicion` del perfil dev (§3 de `PERFIL-DEV-v0.md`).
///
/// `W_min = 30 · trabajo(bits_iniciales dev)`: el trabajo de un bloque a la dificultad **inicial**
/// (la más baja de la red dev, D-P05) es el mínimo trabajo por bloque; con margen para que 3 nodos
/// minen y depositen sin que la dificultad haya podido subir mucho.
///
/// # Errores
/// [`ErrorPerfil`] si los bits iniciales no decodifican o si `W_min` desborda.
pub fn parametros_transicion_dev() -> Result<ParametrosTransicion, ErrorPerfil> {
    #[expect(
        clippy::unwrap_used,
        reason = "30 ZZK es una constante del perfil dev, siempre representable"
    )]
    let s_min = Amount::nuevo(K_MIN as i64 * Q_ZZK).unwrap();
    #[expect(
        clippy::unwrap_used,
        reason = "10 ZZK es una constante del perfil dev, siempre representable"
    )]
    let q = Amount::nuevo(Q_ZZK).unwrap();

    let target_max = decodificar_con(
        PARAMETROS_POW_DEV.bits_iniciales,
        &PARAMETROS_POW_DEV.limites,
    )?;
    let trabajo_max = trabajo_bloque(target_max).ok_or(ErrorPerfil::WMinDesborda)?;
    let w_min = trabajo_max
        .checked_mul(U256::from(30u32))
        .ok_or(ErrorPerfil::WMinDesborda)?;

    Ok(ParametrosTransicion {
        h_dep: H_DEP,
        m_cb: M_CB,
        m_dep: M_DEP,
        h_corte_min: H_CORTE_MIN,
        w_min,
        s_min,
        q,
        k_min: K_MIN,
        m_res_slots: M_RES_SLOTS,
        m_dep_slots: M_DEP_SLOTS,
        m_rec_slots: M_REC_SLOTS,
        r_slots: R_SLOTS,
        f_slots: Some(F_SLOTS),
        subsidio_pow,
        subsidio_post,
    })
}

/// `Parametros` de GHOSTDAG del perfil dev (§4): `k = 10`, `max_padres = 15`.
#[must_use]
pub fn parametros_ghostdag_dev() -> ParametrosGhostdag {
    ParametrosGhostdag {
        k: GHOSTDAG_K,
        max_padres: MAX_PADRES,
        mergeset_limite: MERGESET_LIMITE,
        s_max: u64::MAX,
        u2: true,
        u3_dinamica: true,
        sp: ModoSp::Zerox,
        merge: ModoMerge::Terna,
    }
}

/// Algoritmo GHOSTDAG de producción (no el `Referencia` de los oráculos de test).
#[must_use]
pub const fn algoritmo_ghostdag_dev() -> Algoritmo {
    Algoritmo::Kernel
}

/// Comprueba que `Cadena::nueva` recibe el mismo `k` que este perfil (defensa contra desajuste).
#[must_use]
pub const fn ghostdag_k() -> u32 {
    GHOSTDAG_K
}

/// Máximo de padres que `Cadena::nueva` recibe del perfil dev (§4, `ORDEN-W06a-C` decisión 1).
#[must_use]
pub const fn ghostdag_max_padres() -> u8 {
    MAX_PADRES
}

/// `ParametrosEvidencia` del perfil dev (`ORDEN-SL4b2` decisión 1): `f = 1/1`, `Plazo_slots = 300`,
/// `M_margen_slots = 60`, `cbid = CBID_RED_DEV`, evidencia **activa**.
#[must_use]
pub const fn parametros_evidencia_dev() -> ParametrosEvidencia {
    ParametrosEvidencia {
        f_num: EVP_F_NUM,
        f_den: EVP_F_DEN,
        plazo_slots: PLAZO_SLOTS,
        m_margen_slots: M_MARGEN_SLOTS,
        cbid: zx_core::CBID_RED_DEV,
        evp: true,
    }
}

/// Puerta RAT-3 (`CONTRATO-EVIDENCIA-v0.md`, «Ratificación v0»): `R_slots > Plazo_slots +
/// M_margen_slots`. El nodo (`ORDEN-SL4b2` decisión 1) **se niega a arrancar** si no se cumple: sin
/// esta desigualdad, un infractor podría completar una liberación de su garantía antes de que la
/// ventana de admisión de su propia falta cierre (EV-15).
///
/// Toma `r_slots` y `evidencia` explícitos (no las constantes del módulo) para que un test pueda
/// comprobar un perfil que la incumple sin construir un nodo entero.
#[must_use]
pub const fn puerta_rat3(r_slots: u64, evidencia: &ParametrosEvidencia) -> bool {
    r_slots > evidencia.plazo_slots + evidencia.m_margen_slots
}

#[cfg(test)]
mod tests {
    use super::{parametros_evidencia_dev, parametros_transicion_dev, puerta_rat3};
    use zx_consensus::transicion::ParametrosEvidencia;

    #[test]
    #[expect(clippy::expect_used, reason = "el test falla con panic por diseño")]
    fn el_perfil_dev_construye() {
        let p = parametros_transicion_dev().expect("perfil dev válido");
        assert_eq!(p.h_corte_min, super::H_CORTE_MIN);
        assert_eq!(p.k_min, super::K_MIN);
        assert!(!p.w_min.is_zero());
    }

    /// El perfil dev real cumple la puerta RAT-3: `600 > 300 + 60`.
    #[test]
    fn la_puerta_rat3_se_cumple_con_el_perfil_dev_real() {
        assert!(puerta_rat3(super::R_SLOTS, &parametros_evidencia_dev()));
    }

    /// Un perfil de prueba que la incumple (`R_slots` demasiado corto para su propia ventana):
    /// `puerta_rat3` debe devolver `false`, no un pánico ni un `true` optimista.
    #[test]
    fn la_puerta_rat3_detecta_un_perfil_que_la_incumple() {
        let evidencia_mala = ParametrosEvidencia {
            plazo_slots: 300,
            m_margen_slots: 60,
            ..parametros_evidencia_dev()
        };
        // 360 == 300 + 60: la desigualdad es estricta (`>`), así que el igual también incumple.
        assert!(!puerta_rat3(360, &evidencia_mala));
        // Y con margen aún más corto que la ventana, sigue incumpliendo.
        assert!(!puerta_rat3(100, &evidencia_mala));
    }
}
