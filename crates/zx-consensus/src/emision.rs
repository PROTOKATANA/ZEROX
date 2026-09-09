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
//! A diferencia de Bitcoin, la emisión no se apaga. Tras el año ~10,69 se emiten
//! `26 666 666 brek × 31 536 000 ≈ 8 409 600` ZZK/año indefinidamente. Por eso ZEROX no puede tener un `MAX_MONEY`
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
///
/// **Recalibrado 2026-09-09 (P-041) para `λ = 1 bloque/s`:** era 19 a `T = 120 s`. Sube en 7 porque
/// `2⁷ = 128` es el entero más cercano al factor 120 de ritmo, y el calendario se estira un 5,3 %
/// (los 1000 M se cruzan en el año 10,69 en vez del 10,15). Con 19 a `λ = 1` el techo se cruzaba en
/// 30,9 días y la inflación perpetua era del 100,92 % anual.
pub const SHIFT: u32 = 26;

/// Cola perpetua: 0,26666666 ZZK/bloque (32 ZZK / 120), en brek. **Emisión nominal, no mínimo por
/// bloque** (C-EMIT-07). A `λ = 1` son ≈ 8 409 600 ZZK/año, los mismos que 32 ZZK/bloque a `T = 120 s`.
pub const TAIL_EMISSION_BREK: u128 = 26_666_666;

/// Bloques que una salida de coinbase debe madurar antes de poder gastarse (C-EMIT-05).
///
/// 3,33 h a `λ = 1` (era 100 bloques a `T = 120 s`; P-041). Mayor que la finalidad del DAG, `F = 2 h`.
pub const COINBASE_MATURITY: u32 = 12_000;

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
/// Que eso sea equivalente no es evidente y D9 lo **demostró**: para enteros no negativos,
/// `⌊⌊a/m⌋/n⌋ = ⌊a/(m·n)⌋`. La demostración es corta —escribir `a = mn·Q + R` y descomponer `R`—
/// y está verificada además sobre 200 000 pares aleatorios.
///
/// El producto intermedio desborda `u64` con holgura: Monero tuvo ese bug en producción y su
/// comentario sigue en el código —*"BUGFIX: 32-bit saturation bug (e.g. ARM7)"*—.
///
/// # ⚠️ `u128` no es "sin condiciones": hay un techo real, y se falla seguro
///
/// Decir "en Rust, `u128` nativo" y quedarse ahí sería impreciso. D9 calculó el techo exacto: con
/// `base = recompensa_base(0) = 190 734 863 281`, el numerador máximo `base·M²` **desborda `u128`
/// en cuanto `M > 42 238 129 881 480`**. Eso es solo el `2,3·10⁻⁶` inferior del rango de `u64`, así
/// que el tipo del parámetro no protege.
///
/// No es un agujero de acuñación: `checked_mul` devuelve error y **se falla cerrado**. Pero sí es
/// una **denegación de validación** si `M` llegara ahí: todo bloque con `x ∈ (M, 2M]` fallaría en
/// vez de calcular. Bajo el ataque de llenado máximo sostenido del punto 9 de D9 —2,89× al año—,
/// `M` cruzaría ese umbral hacia el **año 7 de ataque continuo**, no dentro de siglos.
///
/// Lo que lo hace inalcanzable en la práctica no es el tipo: es la física. Un bloque en ese umbral
/// pesaría ~84,5 TB, y sostenerlo serían ~22 200 PB/año. Queda documentado como **límite conocido**,
/// no como problema resuelto.
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
    use crate::peso::{FACTOR_SURGE, PesoValidado, ZONA_LIBRE};

    const BREK_POR_ZZK: u128 = 100_000_000;
    /// Bloques al año a `λ = 1 bloque/s`.
    const BLOQUES_ANIO: u128 = 31_536_000;

    #[test]
    fn las_constantes_son_las_del_spec() {
        assert_eq!(SOFT_CAP_BREK / BREK_POR_ZZK, 1_000_000_000, "1000 M ZZK");
        assert_eq!(
            TAIL_EMISSION_BREK, 26_666_666,
            "cola de 32/120 ZZK por bloque"
        );
        // La cola anual se conserva: ≈ 8 409 600 ZZK (a 1 ZZK de la cifra a 120 s).
        let cola_anual_zzk = TAIL_EMISSION_BREK * BLOQUES_ANIO / BREK_POR_ZZK;
        assert!(
            (8_409_599..=8_409_600).contains(&cola_anual_zzk),
            "{cola_anual_zzk}"
        );
        assert_eq!(SHIFT, 26);
        assert_eq!(COINBASE_MATURITY, 12_000);
    }

    #[test]
    fn la_recompensa_inicial_es_la_documentada() {
        // SOFT_CAP >> 26 = 1 490 116 119 brek ≈ 14,90 ZZK (a T = 120 s era >> 19 = 1907,35 ZZK)
        assert_eq!(recompensa_base(0), 1_490_116_119);
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

    /// El cruce de la curva con la cola cae donde dice el SPEC: año ~8,56 a `λ = 1`.
    #[test]
    fn la_cola_arranca_hacia_el_anio_ocho() {
        // La curva cae bajo la cola cuando restante >> SHIFT < TAIL, es decir
        // restante < TAIL << SHIFT.
        let umbral = TAIL_EMISSION_BREK << SHIFT;
        let emitido_en_el_cruce = SOFT_CAP_BREK - umbral;

        // Simular hasta el cruce contando bloques. A 31,5 M bloques/año son ~270 M bloques; se
        // avanza en tramos de 4 096 con la recompensa del primero. El error relativo del tramo es
        // 4 096 · 2⁻²⁶ ≈ 6·10⁻⁵, muy por debajo de la tolerancia del test.
        const TRAMO: u128 = 4_096;
        let mut emitido = 0u128;
        let mut bloques = 0u128;
        while emitido < emitido_en_el_cruce && bloques < 400_000_000 {
            emitido += recompensa_base(emitido) * TRAMO;
            bloques += TRAMO;
        }
        let anios = bloques * 100 / BLOQUES_ANIO; // centésimas de año, sin floats
        assert!(
            (840..=875).contains(&anios),
            "cruce en el año {}, se esperaba ~8,56",
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

    /// El producto intermedio desborda `u64`: es el bug que Monero tuvo en producción.
    ///
    /// Con la recompensa recalibrada a `λ = 1` (14,90 ZZK, P-041) el producto **ya no desborda en el
    /// suelo de la mediana** (`1,49·10⁹ × 10¹⁰ ≈ 1,5·10¹⁹ < u64::MAX`), pero sí en el régimen de
    /// sobrecarga que C-WGT-08 permite, `M = FACTOR_SURGE · ZONA_LIBRE`: `1,49·10⁹ × 2,5·10¹³ ≈
    /// 3,7·10²²`. El `u128` que C-EMIT-06 exige sigue siendo necesidad, no holgura.
    #[test]
    fn el_producto_intermedio_no_cabria_en_u64() {
        let base = recompensa_base(0);
        let m = FACTOR_SURGE * ZONA_LIBRE;
        let peso = validado(m + 1, m);
        let producto = base * peso.numerador_penalizacion();
        assert!(
            producto > u128::from(u64::MAX),
            "el producto ocupa más de 64 bits: hacer esto en u64 daría otro resultado"
        );
        // Y el cálculo real no desborda porque va en u128.
        assert!(subsidio(base, peso, m).is_ok());
    }

    /// Inflación perpetua: 26 666 666 brek × 31 536 000 bloques ≈ 8 409 600 ZZK ≈ 0,84 % sobre 1000 M.
    /// Es la misma cola anual que 32 ZZK × 262 800 bloques a `T = 120 s`, a 1 ZZK de redondeo.
    #[test]
    fn la_inflacion_perpetua_es_la_documentada() {
        let anual = TAIL_EMISSION_BREK * BLOQUES_ANIO;
        let anual_zzk = anual / BREK_POR_ZZK;
        assert!(
            (8_409_599..=8_409_600).contains(&anual_zzk),
            "≈ 8 409 600 ZZK/año; salió {anual_zzk}"
        );
        // En diezmilésimas de punto porcentual, para no usar floats.
        let ppm = anual * 1_000_000 / SOFT_CAP_BREK;
        assert!(
            (8_300..=8_500).contains(&ppm),
            "inflación {ppm} ppm, se esperaba ~8410 (0,841 %)"
        );
    }
}
