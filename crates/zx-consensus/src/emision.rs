//! Curva de emisión, cola perpetua y penalización por tamaño (SPEC §8).
//!
//! # La cola NO es un suelo por bloque
//!
//! Es la consecuencia menos intuitiva de todo el diseño y está en `C-EMIT-07`. El orden es:
//!
//! 1. `recompensa_base = (SOFT_CAP − emitido) >> SHIFT`
//! 2. **el suelo de la cola se aplica aquí**, sobre `recompensa_base`
//! 3. y **después** la penalización cuadrática multiplica ese valor ya suelado
//!
//! Así que un minero cuyo bloque exceda la mediana efectiva percibe **menos de
//! `TAIL_EMISSION`**, tendiendo a 0 conforme el peso se acerca a `2M`. La moneda no percibida
//! **no se emite jamás**: `emitido` acumula el subsidio ya penalizado.
//!
//! La alternativa —aplicar el suelo *después*— garantizaría la cola, pero **anularía la penalización
//! en régimen de cola permanente**, que en ZEROX es para siempre: llenar el bloque hasta `2M`
//! saldría gratis. Es el problema que `monero-project/monero#1878` señalaba ya en 2017.
//!
//! # El suministro no tiene máximo
//!
//! A diferencia de Bitcoin, la emisión no se apaga. Tras el año ~10,15 se emiten
//! `32 × 262 800 = 8 409 600` ZZK/año indefinidamente. Por eso ZEROX no puede tener un `MAX_MONEY`
//! y usa `ZX_VALUE_SANITY_LIMIT` en su lugar.

// C-ENC-04 prohíbe floats: toda la aritmética de aquí es entera a propósito.
#![expect(
    clippy::integer_division,
    reason = "C-ENC-04 prohíbe floats; la división entera truncada es la especificación (C-EMIT-06)"
)]

use crate::error::ConsensusError;
use crate::peso::PesoValidado;

/// Soft cap de la curva: 1 000 000 000 ZZK, en brek.
pub const SOFT_CAP_BREK: u128 = 100_000_000_000_000_000;

/// Desplazamiento de la curva de emisión. Constante de tiempo ≈ 2 años.
pub const SHIFT: u32 = 19;

/// Cola perpetua: 32 ZZK/bloque, en brek. **Emisión nominal, no mínimo por bloque** (C-EMIT-07).
pub const TAIL_EMISSION_BREK: u128 = 3_200_000_000;

/// Bloques que una salida de coinbase debe madurar antes de poder gastarse (C-EMIT-05).
pub const COINBASE_MATURITY: u32 = 100;

/// Recompensa base del bloque de altura `H` (C-EMIT-01).
///
/// ```text
/// recompensa_base(H) = max( (SOFT_CAP − emitido(H)) >> SHIFT , TAIL_EMISSION )
/// ```
///
/// `emitido(H)` es la suma de los **subsidios efectivos** —ya penalizados— de los bloques
/// `0 .. H−1`. El suelo de la cola se aplica **aquí**, antes de la penalización (C-EMIT-07).
#[must_use]
pub fn recompensa_base(emitido: u128) -> u128 {
    let restante = SOFT_CAP_BREK.saturating_sub(emitido);
    (restante >> SHIFT).max(TAIL_EMISSION_BREK)
}

/// Subsidio efectivo del bloque, tras la penalización por tamaño (C-EMIT-06).
///
/// ```text
/// subsidio = base                              si x ≤ M
/// subsidio = (base · x · (2M − x)) / M / M     si M < x ≤ 2M
/// ```
///
/// Toda la aritmética en `u128`, y las **dos divisiones son sucesivas**, no una división por `M²`.
/// El producto intermedio desborda `u64` con holgura: Monero tuvo ese bug en producción y su
/// comentario sigue en el código —*"BUGFIX: 32-bit saturation bug (e.g. ARM7)"*—.
///
/// El caso `x > 2M` no llega aquí: [`PesoValidado`] no puede construirse, así que el bloque ya fue
/// rechazado por C-WGT-09. Esa es toda la gracia de exigir el tipo en la firma.
///
/// # Errores
/// [`ConsensusError::DesbordamientoAritmetico`] si `M` es cero o el producto desborda `u128`.
pub fn subsidio(
    base: u128,
    peso: PesoValidado,
    mediana_efectiva: u64,
) -> Result<u128, ConsensusError> {
    let m = u128::from(mediana_efectiva);
    if m == 0 {
        return Err(ConsensusError::DesbordamientoAritmetico);
    }
    if u128::from(peso.peso()) <= m {
        return Ok(base);
    }
    // `numerador_penalizacion()` es `(2M − x)·x`, con la resta ya hecha y validada.
    let producto = base
        .checked_mul(peso.numerador_penalizacion())
        .ok_or(ConsensusError::DesbordamientoAritmetico)?;
    Ok(producto / m / m)
}

/// Acumula el suministro con el subsidio **ya penalizado** (C-EMIT-07).
///
/// La moneda no percibida por la penalización **no se emite nunca**. Que este contador reciba el
/// valor penalizado y no la recompensa base es lo que lo hace cierto.
///
/// # Errores
/// [`ConsensusError::DesbordamientoAritmetico`] si el acumulado desborda `u128` — imposible en la
/// práctica, pero se trata como valor.
pub fn acumular(emitido: u128, subsidio: u128) -> Result<u128, ConsensusError> {
    emitido
        .checked_add(subsidio)
        .ok_or(ConsensusError::DesbordamientoAritmetico)
}

#[cfg(test)]
#[expect(clippy::unwrap_used, reason = "los tests fallan con panic por diseño")]
mod tests {
    use super::{
        COINBASE_MATURITY, SHIFT, SOFT_CAP_BREK, TAIL_EMISSION_BREK, acumular, recompensa_base,
        subsidio,
    };
    use crate::peso::{PesoValidado, ZONA_LIBRE};

    const BREK_POR_ZZK: u128 = 100_000_000;
    /// Bloques al año a 120 s.
    const BLOQUES_ANIO: u128 = 262_800;

    #[test]
    fn las_constantes_son_las_del_spec() {
        assert_eq!(SOFT_CAP_BREK / BREK_POR_ZZK, 1_000_000_000, "1000 M ZZK");
        assert_eq!(TAIL_EMISSION_BREK / BREK_POR_ZZK, 32, "cola de 32 ZZK");
        assert_eq!(SHIFT, 19);
        assert_eq!(COINBASE_MATURITY, 100);
    }

    #[test]
    fn la_recompensa_inicial_es_la_documentada() {
        // SOFT_CAP >> 19 = 190 734 863 281 brek ≈ 1907,35 ZZK
        assert_eq!(recompensa_base(0), 190_734_863_281);
    }

    /// La curva decrece de forma monótona conforme se emite.
    #[test]
    fn la_curva_decrece() {
        let mut anterior = recompensa_base(0);
        let mut emitido = 0u128;
        for _ in 0..50 {
            emitido += anterior * 10_000;
            let r = recompensa_base(emitido);
            assert!(r <= anterior, "la curva MUST ser monótona decreciente");
            anterior = r;
        }
    }

    /// **C-EMIT-01: la cola es un suelo de la CURVA.** Agotado el soft cap, sigue emitiendo.
    #[test]
    fn la_cola_no_se_apaga_nunca() {
        assert_eq!(recompensa_base(SOFT_CAP_BREK), TAIL_EMISSION_BREK);
        // Y muy por encima del cap tampoco: el suministro no tiene máximo.
        assert_eq!(recompensa_base(SOFT_CAP_BREK * 10), TAIL_EMISSION_BREK);
    }

    /// El cruce de la curva con la cola cae donde dice el SPEC: año ~8,16.
    #[test]
    fn la_cola_arranca_hacia_el_anio_ocho() {
        // La curva cae bajo la cola cuando restante >> 19 < TAIL, es decir
        // restante < TAIL << 19.
        let umbral = TAIL_EMISSION_BREK << SHIFT;
        let emitido_en_el_cruce = SOFT_CAP_BREK - umbral;

        // Simular hasta el cruce contando bloques.
        let mut emitido = 0u128;
        let mut bloques = 0u128;
        while emitido < emitido_en_el_cruce && bloques < 5_000_000 {
            emitido += recompensa_base(emitido);
            bloques += 1;
        }
        let anios = bloques * 100 / BLOQUES_ANIO; // centésimas de año, sin floats
        assert!(
            (790..=840).contains(&anios),
            "cruce en el año {}, se esperaba ~8,16",
            anios
        );
    }

    // ── Penalización ─────────────────────────────────────────────────────────

    fn validado(peso: u64, m: u64) -> PesoValidado {
        PesoValidado::comprobar(peso, m * 2).unwrap()
    }

    /// Por debajo o igual a la mediana no hay penalización.
    #[test]
    fn sin_penalizacion_hasta_la_mediana() {
        let base = recompensa_base(0);
        let m = ZONA_LIBRE;
        for peso in [0, 1, m / 2, m] {
            assert_eq!(
                subsidio(base, validado(peso, m), m).unwrap(),
                base,
                "peso {peso}"
            );
        }
    }

    /// Entre `M` y `2M` la penalización crece, y en `2M` el subsidio es cero.
    #[test]
    fn la_penalizacion_llega_a_cero_en_el_doble_de_la_mediana() {
        let base = recompensa_base(0);
        let m = ZONA_LIBRE;

        let mut anterior = base;
        for k in 1..=10u64 {
            let peso = m + (m * k) / 10;
            let s = subsidio(base, validado(peso, m), m).unwrap();
            assert!(s <= anterior, "el subsidio MUST decrecer al crecer el peso");
            anterior = s;
        }
        assert_eq!(
            subsidio(base, validado(2 * m, m), m).unwrap(),
            0,
            "en 2M el subsidio es 0"
        );
    }

    /// **C-EMIT-07, el hallazgo H-004.** Un bloque grande cobra MENOS que la cola nominal.
    ///
    /// Es lo que hace que la cola sea emisión nominal y no un mínimo garantizado. Si esto fallara,
    /// se habría implementado el suelo *después* de la penalización y la penalización dejaría de
    /// morder en régimen de cola permanente — que en ZEROX es para siempre.
    #[test]
    fn en_regimen_de_cola_un_bloque_grande_cobra_menos_que_la_cola() {
        let base = recompensa_base(SOFT_CAP_BREK); // = TAIL_EMISSION_BREK
        assert_eq!(base, TAIL_EMISSION_BREK);

        let m = ZONA_LIBRE;
        let grande = m + m / 2; // 1,5·M
        let s = subsidio(base, validado(grande, m), m).unwrap();

        assert!(
            s < TAIL_EMISSION_BREK,
            "C-EMIT-07: la cola es nominal, no un suelo por bloque — cobró {s} de {TAIL_EMISSION_BREK}"
        );
        assert!(s > 0, "pero sigue cobrando algo mientras el peso < 2M");
    }

    /// El contador de suministro acumula el valor **ya penalizado** (C-EMIT-07).
    ///
    /// La moneda no percibida no se emite. Si se acumulara la recompensa base, el suministro
    /// crecería más rápido de lo que nadie cobra.
    #[test]
    fn el_suministro_acumula_lo_penalizado_no_lo_base() {
        let base = recompensa_base(0);
        let m = ZONA_LIBRE;
        let penalizado = subsidio(base, validado(m + m / 2, m), m).unwrap();
        assert!(penalizado < base);

        let emitido = acumular(0, penalizado).unwrap();
        assert_eq!(emitido, penalizado, "MUST acumular el penalizado");
        assert_ne!(emitido, base, "MUST NOT acumular la recompensa base");
    }

    /// El producto intermedio desborda `u64` con holgura: es el bug que Monero tuvo en producción.
    #[test]
    fn el_producto_intermedio_no_cabria_en_u64() {
        let base = recompensa_base(0);
        let m = ZONA_LIBRE;
        let peso = validado(m + 1, m);
        let producto = base * peso.numerador_penalizacion();
        assert!(
            producto > u128::from(u64::MAX),
            "el producto ocupa más de 64 bits: hacer esto en u64 daría otro resultado"
        );
        // Y el cálculo real no desborda porque va en u128.
        assert!(subsidio(base, peso, m).is_ok());
    }

    /// Inflación perpetua: 32 ZZK × 262 800 bloques ≈ 0,84 % sobre 1000 M.
    #[test]
    fn la_inflacion_perpetua_es_la_documentada() {
        let anual = TAIL_EMISSION_BREK * BLOQUES_ANIO;
        assert_eq!(anual / BREK_POR_ZZK, 8_409_600, "8 409 600 ZZK/año");
        // En diezmilésimas de punto porcentual, para no usar floats.
        let ppm = anual * 1_000_000 / SOFT_CAP_BREK;
        assert!(
            (8_300..=8_500).contains(&ppm),
            "inflación {ppm} ppm, se esperaba ~8410 (0,841 %)"
        );
    }
}
