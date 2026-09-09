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
/// 🔶 **P-011b: el valor de Monero (3 000) se adoptó como punto de partida.** Fijarlo para ZEROX
/// requiere un modelo explícito de coste de atacante — encargo abierto para D2 y D8.
///
/// **Recalibrado 2026-09-09 (P-041) a `384 000 = 3 000 × 128`.** La tarifa escala con
/// `recompensa_base`, y al dividir la recompensa por 128 para `λ = 1 bloque/s` el antispam se
/// debilitaba en el mismo factor. Con 384 000 se conserva el coste del atacante del diseño original:
/// inflar 1 GB de cadena cuesta 543 590 ZZK al lanzamiento. Una transparente típica de ~350 B paga
/// ≈0,19 ZZK, y con [`TARIFA_SUELO`] esa cifra ya **no** baja en régimen de cola (antes caía a
/// ≈0,0034 ZZK); sostener 100 KB/bloque de spam cuesta ≈4,7 M ZZK/día, también sin degradarse.
pub const REF_WEIGHT: u128 = 384_000;

/// Suelo absoluto de la tarifa mínima, en brek por unidad de peso (SPEC §5.5).
///
/// 🔶 **Decidido por Katana el 2026-09-10.** Es la tarifa cruda del **lanzamiento** con la mediana en
/// [`ZONA_LIBRE`](zx_consensus::peso::ZONA_LIBRE), y no se deriva en tiempo de ejecución a propósito:
/// es un ancla fija, no una función del estado de la cadena. Ese es justo su cometido.
///
/// # Los dos caminos que cierra, que son el mismo visto de dos lados
///
/// `F ∝ recompensa_base / Mf²`, así que la tarifa mínima cae por dos vías independientes:
///
/// 1. **El lazo con la capacidad.** Subir `Mf` abarata la tarifa, y eso abarata seguir subiéndola.
///    Sin suelo la serie de costes **converge**: llevar la mediana hasta 34 MB/bloque cuesta 2,42× la
///    primera ronda. Con suelo, cada ronda cuesta 1,7× **más** que la anterior.
/// 2. **La degradación con la emisión.** `recompensa_base` cae 56× del lanzamiento al régimen de cola
///    (año 8,56+), y la tarifa con ella. El ataque que costaba 487 M ZZK pasaba a costar 8,7 M, el
///    0,9 % del suministro. Con suelo se queda en 487 M para siempre.
///
/// # Lo que cuesta
///
/// La tarifa mínima **nunca baja de 0,19 ZZK** por una transparente de 350 B, aunque sobre capacidad.
/// El suelo está en unidades de moneda, no de poder adquisitivo: si el ZZK se revaloriza mucho habrá
/// que bajarlo, y **se puede**, porque esta sección no es consenso.
///
/// **Sin auditar.** Nadie lo ha atacado; ver la pregunta abierta para D8 en SPEC §5.5.
pub const TARIFA_SUELO: u128 = 54_359;

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
/// ```text
/// tarifa_por_peso = max(TARIFA_SUELO, max(1, F − F/20))
/// ```
///
/// Requisitos que vienen del código de referencia y **MUST** respetarse: **dos divisiones enteras
/// sucesivas** y no una por `Mlt²`, el `0,95×` como `F − F/20` en entero y nunca en coma flotante,
/// y resultado nunca cero. El suelo se aplica **al final**, sobre el valor ya redondeado.
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
    (f - f / 20).max(1).max(TARIFA_SUELO)
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
        COLCHON_DIVISOR, FEE_MASK, REF_WEIGHT, TARIFA_SUELO, cuantizar, se_admite, tarifa_minima,
        tarifa_por_peso,
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

    /// **La propiedad que motiva la divergencia frente a Monero, ahora reforzada por el suelo.**
    ///
    /// La tarifa depende solo de `Mlt`, acotada a ±1,7× por bloque, así que entre dos bloques
    /// consecutivos nunca podía saltar más de 2,89×: suave en **ambas** direcciones, que es lo que el
    /// *fee cliff* de Monero no garantiza. Con [`TARIFA_SUELO`] (2026-09-10) la garantía se vuelve
    /// trivial en el régimen normal —la tarifa es **constante**— y el test comprueba las dos cosas:
    /// que sigue acotada donde el suelo no muerde, y que donde muerde no se mueve en absoluto.
    #[test]
    fn la_tarifa_no_puede_saltar_entre_bloques_consecutivos() {
        let base = recompensa_base(0);

        // Régimen donde el suelo NO muerde: por debajo de ZONA_LIBRE la mediana no puede bajar, así
        // que se usa una recompensa alta artificial para levantar la tarifa cruda por encima del
        // suelo y observar la cota de C-WGT-04.
        let base_alta = base * 100;
        let m0 = ZONA_LIBRE * 4;
        let m_arriba = m0 + (m0 * 7) / 10; // 1,7×
        let m_abajo = (m0 * 10) / 17; // 0,588×

        let t0 = tarifa_por_peso(base_alta, mlt(m0));
        let t_arriba = tarifa_por_peso(base_alta, mlt(m_arriba));
        let t_abajo = tarifa_por_peso(base_alta, mlt(m_abajo));

        assert!(t_arriba < t0, "más espacio ⇒ tarifa menor");
        assert!(t_abajo > t0, "menos espacio ⇒ tarifa mayor");
        assert!(
            t_abajo <= t0 * 3,
            "la subida máxima por bloque es ~2,89×, salió {t_abajo}/{t0}"
        );
        assert!(t0 <= t_arriba * 3, "y la bajada, lo mismo");

        // Régimen real (recompensa de lanzamiento): el suelo muerde y no hay salto ninguno.
        assert_eq!(
            tarifa_por_peso(base, mlt(m0)),
            tarifa_por_peso(base, mlt(m_arriba)),
            "con el suelo puesto la tarifa es constante: no hay cliff que garantizar"
        );
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

    /// **Ya NO baja con la recompensa: [`TARIFA_SUELO`] corta esa vía (2026-09-10).**
    ///
    /// La tarifa cruda sí sigue al subsidio, y esa era la fuga: la recompensa cae 56× del lanzamiento
    /// al régimen de cola, y el antispam caía con ella. El suelo la sostiene; el test comprueba las
    /// dos mitades, que la cruda baja y que la efectiva no.
    #[test]
    fn la_tarifa_ya_no_baja_con_la_recompensa() {
        let m = mlt(ZONA_LIBRE);
        let al_principio = tarifa_por_peso(recompensa_base(0), m);
        let en_la_cola = tarifa_por_peso(recompensa_base(u128::MAX / 2), m);
        assert_eq!(en_la_cola, al_principio, "el suelo MUST sostener la tarifa");

        // Y la cruda, sin suelo, sí caía: 56× entre los dos regímenes.
        let cruda =
            |base: u128| base * REF_WEIGHT / u128::from(ZONA_LIBRE) / u128::from(ZONA_LIBRE);
        let razon = cruda(recompensa_base(0)) / cruda(recompensa_base(u128::MAX / 2)).max(1);
        assert!(
            (50..=60).contains(&razon),
            "la tarifa cruda cae ~56× con la recompensa; salió {razon}×"
        );
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

    /// **La tarifa YA NO varía a lo largo de la vida de la cadena: `TARIFA_SUELO` la sostiene.**
    ///
    /// La tarifa cruda escala con la recompensa base, que cae 56× del lanzamiento (`1,49·10⁹` brek)
    /// al régimen de cola (`2,67·10⁷`). Hasta el 2026-09-10 la tarifa caía con ella, de 0,19 a
    /// 0,0034 ZZK, y con ella el antispam: el ataque que llevaba la mediana a 34 MB/bloque pasaba de
    /// costar 487 M ZZK a costar 8,7 M. Con el suelo, **las dos cifras son 0,19 ZZK**.
    #[test]
    fn la_tarifa_no_se_degrada_en_regimen_de_cola() {
        let m = mlt(ZONA_LIBRE);

        let al_lanzar = tarifa_minima(350, recompensa_base(0), m);
        assert!(
            (15_000_000..=25_000_000).contains(&al_lanzar),
            "al lanzamiento una tx de 350 B paga ~0,19 ZZK; pagó {al_lanzar} brek"
        );

        // Régimen de cola: recompensa_base saturada en TAIL_EMISSION.
        let en_la_cola = tarifa_minima(350, recompensa_base(u128::MAX / 2), m);
        assert_eq!(
            en_la_cola, al_lanzar,
            "el suelo MUST sostener la tarifa en régimen de cola"
        );

        // Y el suelo es exactamente la tarifa cruda del lanzamiento con la mediana en su suelo.
        assert_eq!(
            tarifa_por_peso(recompensa_base(0), m),
            TARIFA_SUELO,
            "TARIFA_SUELO MUST ser F(recompensa_base(0), ZONA_LIBRE)"
        );

        // Ni la mediana más alta imaginable la baja: es lo que rompe el lazo de realimentación.
        assert_eq!(
            tarifa_por_peso(recompensa_base(0), mlt(u64::MAX)),
            TARIFA_SUELO,
            "con Mlt enorme la tarifa cruda se hunde; el suelo MUST sostenerla"
        );
    }

    /// **La saturación en 1 brek ya no se alcanza: [`TARIFA_SUELO`] muerde mucho antes.**
    ///
    /// La tarifa cruda satura en 1 brek/peso cuando `Mlt > √(base·REF) ≈ 23,9 MB`, y ahí el antispam
    /// por tarifa dejaba de responder por completo. Con el suelo, la tarifa efectiva se clava en
    /// `TARIFA_SUELO` en cuanto `Mlt` pasa de `ZONA_LIBRE`, que es 239× antes.
    #[test]
    fn el_suelo_muerde_antes_que_la_saturacion_en_un_brek() {
        let base = recompensa_base(0);
        let umbral_saturacion = 23_920_798u64; // √(base·REF)

        // Donde la cruda saturaría en 1, la efectiva vale el suelo.
        assert_eq!(
            tarifa_por_peso(base, mlt(umbral_saturacion * 2)),
            TARIFA_SUELO
        );

        // Y el suelo ya manda desde una mediana 239× menor que ese umbral.
        assert_eq!(tarifa_por_peso(base, mlt(ZONA_LIBRE + 1)), TARIFA_SUELO);
        assert!(
            u128::from(umbral_saturacion) / u128::from(ZONA_LIBRE) > 200,
            "el suelo se adelanta a la saturación por más de dos órdenes"
        );
    }
}
