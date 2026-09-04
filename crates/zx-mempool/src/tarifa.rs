//! Tarifa mínima dinámica (SPEC §5.5).
//!
//! # Esto NO es consenso, y la distinción importa
//!
//! `C-TX-15`: **no existe tarifa mínima de consenso.** Un bloque **MUST NOT** rechazarse por
//! contener una transacción de fee bajo, o incluso cero. Lo de aquí es la política por defecto del
//! nodo para admitir en su mempool y retransmitir; otro nodo puede relajarla y la red converge por
//! interés propio, no por regla.
//!
//! Se comprobó en el código de referencia antes de escribir esto: en Monero la comprobación se
//! **omite por completo** cuando la transacción llega dentro de un bloque ya minado
//! (`tx_pool.cpp:137-166`), y Cuprate ubica la suya deliberadamente fuera del crate `consensus/`.
//!
//! Convertirlo en consenso habría traído tres males: un minero no podría incluir transacciones
//! gratuitas ni propias, cambiar la política exigiría un hard fork, y aparece una circularidad
//! porque la tarifa depende de la mediana y la mediana de los bloques.
//!
//! # 🔶 La divergencia frente a Monero, y por qué
//!
//! Monero usa `Mf = min(mediana_corta, mediana_larga)`. Como `tarifa ∝ 1/Mf²`, tomar el **mínimo**
//! equivale a tomar la mediana que produce la **tarifa más alta** — y ahí nace el *fee cliff*:
//! cuando la mediana corta se desploma tras un pico, la tarifa mínima **salta hacia arriba de
//! golpe** y deja varadas las transacciones ya firmadas. `monero-project/research-lab#70` sigue
//! **abierto**.
//!
//! Para un checkout eso es el peor fallo posible: el comprador ve "pago pendiente" y abandona.
//!
//! **ZEROX ancla la tarifa solo a la mediana LARGA.** Como `Mlt` está acotada a `±1,7×` por bloque
//! (C-WGT-04), la tarifa resulta **suave en ambas direcciones por construcción**.
//!
//! Contrapartida asumida a conciencia: la tarifa mínima deja de reaccionar a la congestión de corto
//! plazo. El racionamiento del espacio ya lo hacen el límite duro y la penalización; para un
//! marketplace la predictibilidad vale más. El mercado de prioridades sigue existiendo **por
//! encima** del mínimo.
//!
//! ⚠️ Pendiente de revisión adversarial de D8 y D2 (P-011c): si anclar solo a `Mlt` abarata el spam
//! mientras `Mlt` sigue alta y la demanda real ha colapsado.

// C-ENC-04 prohíbe floats en consenso; aquí no es consenso, pero la aritmética entera se mantiene
// por coherencia y porque la tarifa entra en comparaciones que sí deben ser reproducibles.
#![expect(
    clippy::integer_division,
    reason = "aritmética entera deliberada: la tarifa debe ser reproducible bit a bit entre nodos"
)]

use zx_consensus::peso::MedianaLarga;

/// Peso de la transacción de referencia que calibra el nivel absoluto de la tarifa.
///
/// 🔶 **P-011b: valor de Monero adoptado como punto de partida.** Fijarlo para ZEROX requiere un
/// modelo explícito de coste de atacante — encargo abierto para D2 y D8. Con este valor, una
/// transparente típica de ~350 B paga ≈0,0032 ZZK y sostener 100 KB/bloque de spam cuesta
/// ≈656 ZZK/día.
pub const REF_WEIGHT: u128 = 3_000;

/// Cuantización de la tarifa, en brek.
///
/// La tarifa se redondea **hacia arriba** a un múltiplo de este valor. No es estética: reduce la
/// granularidad de la tarifa como **huella identificatoria** — una tarifa con todos sus dígitos
/// permite estimar el momento en que se construyó la transacción.
pub const FEE_MASK: u128 = 10_000;

/// Colchón de aceptación: se admite hasta un 2 % por debajo del mínimo calculado.
///
/// Absorbe la desincronización de un bloque entre lo que calculó el emisor y lo que calcula el
/// receptor. Sin él, cada cambio de mediana rechazaría transacciones legítimas en vuelo.
pub const COLCHON_DIVISOR: u128 = 50;

/// Tarifa mínima por unidad de peso, en brek (§5.5).
///
/// ```text
/// F               = recompensa_base · REF_WEIGHT / Mlt / Mlt
/// tarifa_por_peso = max(1, F − F/20)
/// ```
///
/// Requisitos que vienen del código de referencia y **MUST** respetarse: **dos divisiones enteras
/// sucesivas** y no una por `Mlt²`, el `0,95×` como `F − F/20` en entero y nunca en coma flotante,
/// y resultado nunca cero.
///
/// # Sobre el `u128`
///
/// Con los valores actuales **no hace falta**: `recompensa_base(0) · REF_WEIGHT = 5,72·10¹⁴`, muy
/// por debajo de `u64::MAX = 1,84·10¹⁹`. Un test lo comprobaba afirmando lo contrario y **falló** —
/// la afirmación era falsa y se corrigió en lugar de adaptar el test.
///
/// Se mantiene en 128 bits de forma **defensiva**: `REF_WEIGHT` está pendiente de calibración
/// (P-011b) y podría subir varios órdenes de magnitud, y el margen no cuesta nada en una ruta que
/// no es caliente.
#[must_use]
pub fn tarifa_por_peso(recompensa_base: u128, mlt: MedianaLarga) -> u128 {
    let m = u128::from(mlt.valor());
    // `MedianaLarga` garantiza `≥ ZONA_LIBRE > 0`, así que no hay división por cero que comprobar:
    // esa es toda la gracia de exigir el tipo en la firma.
    let f = recompensa_base.saturating_mul(REF_WEIGHT) / m / m;
    (f - f / 20).max(1)
}

/// Redondea hacia arriba al múltiplo de [`FEE_MASK`].
const fn cuantizar(v: u128) -> u128 {
    v.div_ceil(FEE_MASK) * FEE_MASK
}

/// Tarifa mínima que debería pagar una transacción de ese peso.
#[must_use]
pub fn tarifa_minima(peso: u64, recompensa_base: u128, mlt: MedianaLarga) -> u128 {
    cuantizar(u128::from(peso).saturating_mul(tarifa_por_peso(recompensa_base, mlt)))
}

/// ¿Se admite esta transacción en el mempool y se retransmite?
///
/// **No es una regla de validez**: una transacción rechazada aquí sigue siendo perfectamente válida
/// dentro de un bloque (C-TX-15). Solo dice que este nodo no la propaga por su cuenta.
#[must_use]
pub fn se_admite(fee: u128, peso: u64, recompensa_base: u128, mlt: MedianaLarga) -> bool {
    let minima = tarifa_minima(peso, recompensa_base, mlt);
    fee >= minima - minima / COLCHON_DIVISOR
}

#[cfg(test)]
mod tests {
    use super::{
        COLCHON_DIVISOR, FEE_MASK, REF_WEIGHT, cuantizar, se_admite, tarifa_minima, tarifa_por_peso,
    };
    use zx_consensus::emision::recompensa_base;
    use zx_consensus::peso::{MedianaLarga, ZONA_LIBRE};

    fn mlt(v: u64) -> MedianaLarga {
        MedianaLarga::nueva(v)
    }

    #[test]
    fn la_tarifa_nunca_es_cero() {
        // Ni con la mediana más alta imaginable ni con la recompensa más baja.
        let enorme = mlt(u64::MAX);
        assert!(tarifa_por_peso(1, enorme) >= 1, "MUST devolver al menos 1");
        assert!(tarifa_por_peso(0, mlt(ZONA_LIBRE)) >= 1);
    }

    /// **La propiedad que motiva la divergencia frente a Monero.**
    ///
    /// La tarifa depende **solo** de `Mlt`, que está acotada a ±1,7× por bloque. Así que entre dos
    /// bloques consecutivos no puede saltar: es suave en **ambas** direcciones, que es justo lo que
    /// el *fee cliff* de Monero no garantiza.
    #[test]
    fn la_tarifa_no_puede_saltar_entre_bloques_consecutivos() {
        let base = recompensa_base(0);
        // Cuatro veces el suelo: hay que estar **por encima** de `ZONA_LIBRE` para que el clamp
        // inferior de C-WGT-04 sea observable. Partiendo del suelo, `MedianaLarga` lo devuelve al
        // suelo y la tarifa no puede subir más — que es en sí una propiedad útil: **con la mediana
        // en el suelo, la tarifa mínima ya está en su máximo**.
        let m0 = ZONA_LIBRE * 4;

        // Los dos extremos que C-WGT-04 permite en un bloque.
        let m_arriba = m0 + (m0 * 7) / 10; // 1,7×
        let m_abajo = (m0 * 10) / 17; // 0,588×

        let t0 = tarifa_por_peso(base, mlt(m0));
        let t_arriba = tarifa_por_peso(base, mlt(m_arriba));
        let t_abajo = tarifa_por_peso(base, mlt(m_abajo));

        // tarifa ∝ 1/Mlt², así que 1,7× de mediana ⇒ ~1/2,89 de tarifa, y al revés.
        assert!(t_arriba < t0, "más espacio ⇒ tarifa menor");
        assert!(t_abajo > t0, "menos espacio ⇒ tarifa mayor");

        // Y ninguno de los dos saltos supera el factor 2,89 = 1,7².
        assert!(
            t_abajo <= t0 * 3,
            "la subida máxima por bloque es ~2,89×, salió {t_abajo}/{t0}"
        );
        assert!(t0 <= t_arriba * 3, "y la bajada, lo mismo");
    }

    /// Más espacio en la cadena abarata; menos, encarece. Monótono.
    #[test]
    fn la_tarifa_decrece_al_crecer_la_mediana() {
        let base = recompensa_base(0);
        let mut anterior = u128::MAX;
        for k in 1..=20u64 {
            let t = tarifa_por_peso(base, mlt(ZONA_LIBRE * k));
            assert!(t <= anterior, "MUST ser no creciente en Mlt");
            anterior = t;
        }
    }

    /// Y baja con la recompensa: en régimen de cola, la tarifa mínima es mucho menor.
    #[test]
    fn la_tarifa_baja_con_la_recompensa() {
        let m = mlt(ZONA_LIBRE);
        let al_principio = tarifa_por_peso(recompensa_base(0), m);
        let en_la_cola = tarifa_por_peso(recompensa_base(u128::MAX / 2), m);
        assert!(en_la_cola < al_principio, "la tarifa sigue al subsidio");
    }

    #[test]
    fn la_cuantizacion_redondea_hacia_arriba() {
        assert_eq!(cuantizar(0), 0);
        assert_eq!(cuantizar(1), FEE_MASK);
        assert_eq!(
            cuantizar(FEE_MASK),
            FEE_MASK,
            "un múltiplo exacto no se mueve"
        );
        assert_eq!(cuantizar(FEE_MASK + 1), FEE_MASK * 2);
    }

    /// Toda tarifa mínima es múltiplo de la máscara: es lo que borra la huella.
    #[test]
    fn la_tarifa_minima_siempre_esta_cuantizada() {
        let base = recompensa_base(0);
        for peso in [1u64, 100, 350, 1_000, 100_000] {
            let t = tarifa_minima(peso, base, mlt(ZONA_LIBRE));
            assert_eq!(t % FEE_MASK, 0, "peso {peso} da una tarifa sin cuantizar");
        }
    }

    /// El colchón del 2 % admite lo que quedó justo por debajo, y rechaza lo que está claramente
    /// por debajo.
    #[test]
    fn el_colchon_admite_un_dos_por_ciento_de_desfase() {
        let base = recompensa_base(0);
        let m = mlt(ZONA_LIBRE);
        let peso = 350u64;
        let minima = tarifa_minima(peso, base, m);

        assert!(se_admite(minima, peso, base, m), "la exacta se admite");
        assert!(se_admite(minima + 1, peso, base, m), "de más, también");
        assert!(
            se_admite(minima - minima / COLCHON_DIVISOR, peso, base, m),
            "justo en el borde del colchón"
        );
        assert!(
            !se_admite(minima - minima / COLCHON_DIVISOR - 1, peso, base, m),
            "un brek por debajo del colchón ya no"
        );
        assert!(!se_admite(0, peso, base, m), "cero no se retransmite…");
    }

    /// …pero **cero sigue siendo válido en un bloque**. C-TX-15.
    ///
    /// Este test no comprueba código: comprueba que la separación conceptual está donde debe. Si
    /// algún día alguien mueve esta lógica a `zx-consensus`, este comentario debería frenarle.
    #[test]
    fn rechazar_en_mempool_no_es_invalidar() {
        let base = recompensa_base(0);
        let m = mlt(ZONA_LIBRE);
        assert!(!se_admite(0, 350, base, m), "no se retransmite");
        // Y no hay ninguna función en este módulo que devuelva "inválido": solo "no se admite".
        // La validez la decide `zx_consensus::validar_tx`, que ni mira la tarifa.
    }

    /// El `u128` es **defensivo, no necesario** — y este test lo dice explícitamente.
    ///
    /// Empezó afirmando lo contrario ("el producto desborda `u64`") y **falló**: con los valores
    /// actuales el producto es `5,72·10¹⁴`, tres órdenes de magnitud por debajo de `u64::MAX`. Se
    /// corrigió la afirmación en vez de adaptar el test.
    ///
    /// Queda como guardia de la razón real: si `REF_WEIGHT` sube en la calibración de P-011b, este
    /// test dirá cuándo el margen deja de ser holgura y pasa a ser necesidad.
    #[test]
    fn el_margen_de_u128_es_defensivo_no_necesario() {
        let base = recompensa_base(0);
        let producto = base * REF_WEIGHT;
        assert!(
            producto < u128::from(u64::MAX),
            "hoy cabe de sobra en u64 ({producto} < {}); el u128 es margen para la calibración \
             pendiente de REF_WEIGHT, no una necesidad actual",
            u64::MAX
        );
    }

    /// **La tarifa varía ~60× a lo largo de la vida de la cadena, y conviene saberlo.**
    ///
    /// La tarifa escala con la recompensa base, que cae de `1,9·10¹¹` brek en el lanzamiento a
    /// `3,2·10⁹` en régimen de cola. Con la mediana en el suelo, una transparente típica de 350 B
    /// paga **0,19 ZZK al lanzamiento** y **0,0032 ZZK en la cola**.
    ///
    /// La cifra del SPEC (0,0032 ZZK) es la de **régimen de cola**. Este test empezó comprobándola
    /// contra la recompensa de lanzamiento y **falló**: los dos números eran correctos, pero de
    /// regímenes distintos. Ahora comprueba los dos, para que la diferencia quede visible.
    #[test]
    fn la_tarifa_tipica_varia_sesenta_veces_entre_lanzamiento_y_cola() {
        let m = mlt(ZONA_LIBRE);

        let al_lanzar = tarifa_minima(350, recompensa_base(0), m);
        assert!(
            (15_000_000..=25_000_000).contains(&al_lanzar),
            "al lanzamiento una tx de 350 B paga ~0,19 ZZK; pagó {al_lanzar} brek"
        );

        // Régimen de cola: recompensa_base saturada en TAIL_EMISSION.
        let en_la_cola = tarifa_minima(350, recompensa_base(u128::MAX / 2), m);
        assert!(
            (200_000..=500_000).contains(&en_la_cola),
            "en la cola paga ~0,0032 ZZK; pagó {en_la_cola} brek"
        );

        assert!(
            al_lanzar > en_la_cola * 40,
            "la variación es de decenas de veces, no marginal"
        );
    }

    /// **A medianas muy altas la tarifa satura en 1 brek por unidad de peso.**
    ///
    /// `F ≥ 1` exige `Mlt ≤ √(base·REF) ≈ 23,9 MB`. Por encima de eso, el mínimo deja de escalar y
    /// la tarifa por peso se queda clavada en el suelo. Es una propiedad real del diseño que el
    /// SPEC no mencionaba: si la cadena creciera hasta medianas de decenas de MB, el antispam por
    /// tarifa dejaría de responder y todo el peso recaería en la penalización de C-EMIT-06.
    #[test]
    fn a_medianas_muy_altas_la_tarifa_satura_en_el_suelo() {
        let base = recompensa_base(0);
        let umbral = 23_920_798u64; // √(base·REF)

        assert!(
            tarifa_por_peso(base, mlt(umbral / 2)) > 1,
            "por debajo del umbral aún escala"
        );
        assert_eq!(
            tarifa_por_peso(base, mlt(umbral * 2)),
            1,
            "por encima del umbral la tarifa por peso se clava en 1 brek"
        );
    }
}
