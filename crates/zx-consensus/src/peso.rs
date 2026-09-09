//! Peso de bloque y límite dinámico (SPEC §6.5).
//!
//! Diseño post-2019 de Monero: mediana corta + **mediana de largo plazo** + penalización cuadrática.
//! El original de CryptoNote, con solo la mediana corta, es vulnerable al *big bang attack* — 689 GB
//! de cadena en 24 h por ~€118 800 de fees.
//!
//! # Dónde diverge de Monero, y por qué
//!
//! - **`N_LARGO` = un año**, no 138,9 días. Un marketplace tiene ciclo estacional: la cadena no debe
//!   olvidar el pico de Navidad antes de la siguiente y penalizar cada año el mismo tráfico
//!   legítimo. Además, más muestras es **más difícil de mover para un atacante**.
//! - **`ZONA_LIBRE` = 100 KB**, no 300 KB. La de Monero está dimensionada para transacciones
//!   CryptoNote; una transparente de ZEROX pesa ~350 B.
//!
//! # La trampa que este módulo existe para evitar
//!
//! En Cuprate, `2·median − weight` es aritmética `usize` y solo está protegida por un `if` **previo
//! en la misma función**. La invariante vive en el orden de las sentencias, no en un tipo, así que
//! cualquier ruta nueva —un test, un RPC de estimación, un refactor— puede reintroducir el
//! underflow.
//!
//! Aquí [`PesoValidado`] es la única forma de llegar a la fórmula de penalización, y su constructor
//! es **el único sitio donde ocurre la resta**. Llamar al cálculo de recompensa con un `u64` crudo
//! no compila (C-WGT-10).

// Ver la nota de `dificultad.rs`: C-ENC-04 prohíbe floats en consenso, así que toda la aritmética de
// este módulo es entera a propósito.
#![expect(
    clippy::integer_division,
    reason = "C-ENC-04 prohíbe floats; la división entera es la especificación (§6.5)"
)]

use crate::error::ConsensusError;

/// Ventana de la mediana corta, en bloques: 16,7 min a `λ = 1` (era 100, 200 min a `T = 120 s`).
///
/// Decidida el 2026-09-10 (P-041, decisión 3). Es la ventana que abre la sobrecarga ante un pico, y a
/// la vez la que un atacante puede capturar por azar si produce más de la mitad de sus bloques: con
/// 1 000 no la captura nunca al 33-40 % y cada 17 días al 45 % (+3 % sobre lo que ya rellena gratis
/// en la zona libre); a partir del 47 % es continua, pero ahí ya gana la carrera (frontera 46,9 %).
/// Coste: una ráfaga de 1 280 tx/s tarda 25 min en absorberse del todo
/// (`research/scripts/rendimiento/verif_n_corto_barrido.py`).
pub const N_CORTO: usize = 1_000;

/// Ventana de la mediana larga, en bloques: **un año exacto** a `λ = 1 bloque/s`.
///
/// Recalibrada el 2026-09-09 (P-041): era 262 800 a `T = 120 s`. Se conserva el año porque la
/// constante existe para recordar el ciclo estacional del marketplace, y porque mover una mediana
/// de 31,5 M muestras cuesta llenar media ventana (182 días) y más que todo el suministro en
/// tarifas. **Obligación de implementación:** la mediana sobre esta ventana MUST ser incremental
/// (~252 MB de estado); ordenar la ventana por bloque no es viable. Hoy nadie la construye en
/// producción (llega con B2).
pub const N_LARGO: usize = 31_536_000;

/// Zona libre de penalización, en bytes de weight.
///
/// Da ~285 tx transparentes por bloque, que a `λ = 1` son **~285 tx/s ≈ 24,7 M tx/día libres de
/// penalización**, con un suelo de crecimiento adversarial de 3 154 GB/año y un techo instantáneo de
/// `2 · FACTOR_SURGE · Mlt` = 28 571 tx/s. Mantenida sin cambios en el recalibrado de 2026-09-09
/// (P-041, decisión de Katana): subirla abarata inflar la cadena como `1/ZONA_LIBRE²`.
pub const ZONA_LIBRE: u64 = 100_000;

/// Cuánto puede dispararse la mediana corta sobre la larga en una ráfaga.
pub const FACTOR_SURGE: u64 = 50;

/// Peso máximo de una transacción individual (C-WGT-11).
///
/// Atado a [`ZONA_LIBRE`], no a un número mágico, para obtener un invariante enunciable: **toda
/// transacción válida cabe siempre en un bloque, a cualquier altura, sin empujarlo más allá de la
/// zona libre**. De ahí salen dos garantías que a un marketplace le importan: ninguna transacción
/// puede quedar inminable porque la mediana esté baja, y nadie puede obligar a un minero a asumir
/// la penalización para incluirle.
pub const MAX_TX_WEIGHT: u64 = ZONA_LIBRE;

/// Promedio entero de dos valores, **a prueba de desbordamiento** (C-WGT-03).
///
/// Equivale a `floor((a+b)/2)` sin calcular nunca `a+b`. No es una micro-optimización: con pesos
/// cercanos al máximo de `u64`, la forma ingenua desborda y da un resultado silenciosamente
/// distinto en cada implementación. Monero lo demuestra con un test que inserta `3<<62` dos veces.
#[must_use]
pub const fn get_mid(a: u64, b: u64) -> u64 {
    (a / 2) + (b / 2) + ((a - 2 * (a / 2)) + (b - 2 * (b / 2))) / 2
}

/// Mediana entera de un multiconjunto (C-WGT-03).
///
/// Con `n` par es [`get_mid`] de los dos centrales. **MUST NOT** usarse coma flotante.
///
/// # Errores
/// [`ConsensusError::VentanaVacia`] si el corte está vacío.
pub fn mediana(valores: &[u64]) -> Result<u64, ConsensusError> {
    if valores.is_empty() {
        return Err(ConsensusError::VentanaVacia);
    }
    let mut v = valores.to_vec();
    v.sort_unstable();
    let n = v.len();
    if n % 2 == 1 {
        v.get(n / 2).copied().ok_or(ConsensusError::VentanaVacia)
    } else {
        let a = v
            .get(n / 2 - 1)
            .copied()
            .ok_or(ConsensusError::VentanaVacia)?;
        let b = v.get(n / 2).copied().ok_or(ConsensusError::VentanaVacia)?;
        Ok(get_mid(a, b))
    }
}

/// Peso de largo plazo de un bloque (C-WGT-04).
///
/// ```text
/// inferior := (Mlt · 10) / 17
/// superior := Mlt + (Mlt · 7) / 10
/// lt_weight := min(max(weight, inferior), superior)
/// ```
///
/// Acota cada bloque al rango `[0,588·Mlt, 1,7·Mlt]` de cara al histórico largo. El `1,7×` da ≈14,2×
/// de expansión anual en Monero; con nuestra ventana de un año, ≈2,9×.
///
/// **Se usa la forma `Mlt + (Mlt·7)/10`, no `(Mlt·17)/10`.** Bajo truncamiento entero las dos son
/// **matemáticamente idénticas** —`⌊x+n⌋ = ⌊x⌋+n` para `n` entero—, así que la razón no es la
/// exactitud: es el **margen de desbordamiento**. `Mlt·17` desborda `u64` a partir de `1,09·10¹⁸`
/// y `Mlt·7` a partir de `2,64·10¹⁸`, 2,4× más holgura. Y mantiene identidad byte a byte con los
/// valores intermedios de la implementación de referencia.
///
/// # ⚠️ El clamp INFERIOR no admite la simetría, y esa es la trampa
///
/// Que el superior sea intercambiable invita a pensar que el inferior también lo es. **No lo es.**
/// La identidad `⌊x⌋ + n = ⌊x + n⌋` vale para la suma; para la resta el equivalente correcto es
/// `⌊n − x⌋ = n − ⌈x⌉`, con **techo**, no con piso.
///
/// D9 lo verificó: `Mlt − (Mlt·7)/17` difiere de `(Mlt·10)/17` en **49 805 de 53 005 casos**
/// (94 %). Con `Mlt = 3`: `(3·10)/17 = 1`, pero `3 − (3·7)/17 = 2`. Solo con techo coinciden al
/// 100 %.
///
/// Y un segundo peligro, más clásico y más probable: **`(Mlt/17)·10` no es `(Mlt·10)/17`** —
/// difieren en el 88 % de los casos. Dividir antes de multiplicar sesga sistemáticamente a la baja.
/// La forma del código multiplica primero, en `u128`.
#[must_use]
pub fn peso_largo_plazo(weight: u64, mlt: u64) -> u64 {
    let mlt128 = u128::from(mlt);
    let inferior = ((mlt128 * 10) / 17) as u64;
    let superior = (mlt128 + (mlt128 * 7) / 10) as u64;
    weight.max(inferior).min(superior)
}

/// Mediana de largo plazo (C-WGT-05): `max(ZONA_LIBRE, mediana(lt_weight de la ventana))`.
///
/// El llamante pasa la ventana ya recortada a `min(N_LARGO, H)` bloques (C-WGT-07).
///
/// > ⚠️ Al cachear esto, la clave **MUST** ser el hash del tip, nunca la altura (C-REORG-05).
/// > Indexar por altura devuelve datos de la rama vieja tras un reorg **sin que nada falle
/// > visiblemente**: es un fork silencioso.
///
/// # Errores
/// [`ConsensusError::VentanaVacia`] si la ventana está vacía. Para `H = 0` no se llama: rige
/// C-WGT-07.
pub fn mediana_larga(lt_weights: &[u64]) -> Result<u64, ConsensusError> {
    Ok(mediana(lt_weights)?.max(ZONA_LIBRE))
}

/// Mediana de corto plazo (C-WGT-06) sobre los pesos crudos de la ventana.
///
/// # Errores
/// [`ConsensusError::VentanaVacia`] si la ventana está vacía.
pub fn mediana_corta(pesos: &[u64]) -> Result<u64, ConsensusError> {
    mediana(pesos)
}

/// Mediana de largo plazo con su suelo **ya aplicado** (C-WGT-05).
///
/// # Por qué es un tipo y no un `u64`
///
/// D9 intentó refutar la regla "no reordenar los `min`/`max` de C-WGT-08 porque cambia la
/// semántica en los empates" y **la refutó**: bajo el invariante `Mlt ≥ ZONA_LIBRE`, los
/// reordenamientos razonables dan resultados idénticos en 200 000 casos, empates exactos incluidos.
/// La ley distributiva de retículo se cumple, y el `max(…, ZONA_LIBRE)` final resulta
/// **matemáticamente redundante**.
///
/// Pero encontró que sí hay una razón real, y es otra: `mediana_efectiva` dependía en silencio de
/// una precondición que **otra** función garantiza y que el tipo `u64` no forzaba. Violándola
/// —`Mlt = 1000`, `Mst = 10⁸`— el original da `M = 100 000` y un reordenamiento da `42 900`: 2,3×
/// menos, porque el techo de ráfaga `50·1000` atrapa el valor antes de que el suelo lo rescate.
///
/// Así que la precondición pasa a estar en el tipo. Es el mismo patrón que [`PesoValidado`] para la
/// resta `2M − x`: una invariante que vivía en el orden de las llamadas ahora vive en la firma.
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Debug)]
pub struct MedianaLarga(u64);

impl MedianaLarga {
    /// Aplica el suelo de C-WGT-05. Es la **única** forma de construir el tipo.
    #[must_use]
    pub fn nueva(mediana_cruda: u64) -> Self {
        Self(mediana_cruda.max(ZONA_LIBRE))
    }

    /// El valor, garantizado `≥ ZONA_LIBRE`.
    #[must_use]
    pub const fn valor(self) -> u64 {
        self.0
    }
}

/// Mediana efectiva (C-WGT-08).
///
/// ```text
/// M := max( min( max(Mlt, Mst), FACTOR_SURGE · Mlt ), ZONA_LIBRE )
/// ```
///
/// El `max(…, ZONA_LIBRE)` final es **redundante** dado que [`MedianaLarga`] ya trae el suelo
/// —verificado por D9 sobre 200 000 casos—, pero se conserva escrito porque es lo que dice
/// C-WGT-08 y porque hace la función correcta aunque algún día el invariante se relaje.
///
/// El orden **MUST NOT** reordenarse. No por los empates —eso se refutó— sino porque la
/// equivalencia de los reordenamientos depende del invariante de `Mlt`, y una regla de consenso no
/// debe apoyarse en una condición que vive fuera de ella.
#[must_use]
pub fn mediana_efectiva(mlt: MedianaLarga, mst: u64) -> u64 {
    let mlt = mlt.valor();
    let surge = u128::from(mlt) * u128::from(FACTOR_SURGE);
    let acotado = u128::from(mlt.max(mst)).min(surge);
    (acotado as u64).max(ZONA_LIBRE)
}

/// Límite duro de peso de bloque: `2 · M` (C-WGT-09).
///
/// Un bloque que lo exceda es **inválido**, no meramente penalizado.
#[must_use]
pub fn limite(mediana_efectiva: u64) -> u64 {
    mediana_efectiva.saturating_mul(2)
}

/// Prueba, **por construcción**, de que el peso de un bloque cumple C-WGT-09.
///
/// Es la respuesta a C-WGT-10. La única forma de obtener uno es [`Self::comprobar`], y ese
/// constructor es **el único lugar del código donde se hace la resta `2M − weight`**. Guarda el
/// resultado, así que la fórmula de penalización ya no tiene que restar nada.
///
/// Es "parse, don't validate" aplicado al bug concreto de Cuprate: allí la invariante vive en el
/// orden de las sentencias de una función; aquí vive en la firma de tipos, y **no compila** llamar
/// al cálculo de recompensa con un `u64` crudo, se escriba lo que se escriba alrededor.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct PesoValidado {
    peso: u64,
    /// `2M − peso`, ya calculado. Garantizado no negativo.
    holgura: u64,
}

impl PesoValidado {
    /// Comprueba C-WGT-09 y, de paso, calcula el término que la penalización necesitará.
    ///
    /// # Errores
    /// [`ConsensusError::PesoExcedeLimite`] si `peso > limite`. El bloque es inválido.
    pub fn comprobar(peso: u64, limite: u64) -> Result<Self, ConsensusError> {
        let holgura = limite
            .checked_sub(peso)
            .ok_or(ConsensusError::PesoExcedeLimite { peso, limite })?;
        Ok(Self { peso, holgura })
    }

    /// El peso validado.
    #[must_use]
    pub const fn peso(self) -> u64 {
        self.peso
    }

    /// `2M − peso`. No negativo por construcción.
    #[must_use]
    pub const fn holgura(self) -> u64 {
        self.holgura
    }

    /// El término `(2M − x)·x` de C-EMIT-06, en `u128`.
    ///
    /// Sin resta aquí: ya se hizo en [`Self::comprobar`], que es el único sitio donde pudo salir
    /// mal.
    #[must_use]
    pub const fn numerador_penalizacion(self) -> u128 {
        (self.holgura as u128) * (self.peso as u128)
    }
}

#[cfg(test)]
#[expect(clippy::unwrap_used, reason = "los tests fallan con panic por diseño")]
mod tests {
    use super::{
        FACTOR_SURGE, MAX_TX_WEIGHT, MedianaLarga, N_CORTO, N_LARGO, PesoValidado, ZONA_LIBRE,
        get_mid, limite, mediana, mediana_corta, mediana_efectiva, mediana_larga, peso_largo_plazo,
    };
    use crate::error::ConsensusError;

    #[test]
    fn las_constantes_son_las_del_spec() {
        assert_eq!(N_CORTO, 1_000, "16,7 min a λ = 1");
        assert_eq!(N_LARGO, 31_536_000, "un año exacto a λ = 1 bloque/s");
        assert_eq!(N_LARGO, 86_400 * 365, "86 400 bloques/día × 365");
        assert_eq!(ZONA_LIBRE, 100_000);
        assert_eq!(FACTOR_SURGE, 50);
        assert_eq!(MAX_TX_WEIGHT, ZONA_LIBRE, "C-WGT-11 lo ata a la zona libre");
    }

    /// **C-WGT-03.** El promedio ingenuo `(a+b)/2` desborda; este no.
    ///
    /// Es el test que Monero tiene con `3<<62`: se comprueba primero que la suma **efectivamente**
    /// desborda, para que el test no pase por casualidad.
    #[test]
    fn get_mid_no_desborda() {
        let grande: u64 = 3 << 62;
        assert!(
            grande.checked_add(grande).is_none(),
            "la suma directa debe desbordar"
        );
        assert_eq!(
            get_mid(grande, grande),
            grande,
            "y aun así la media es correcta"
        );

        assert_eq!(get_mid(u64::MAX, u64::MAX), u64::MAX);
        assert_eq!(get_mid(0, 0), 0);
        assert_eq!(get_mid(3, 4), 3, "floor((3+4)/2) = 3");
        assert_eq!(get_mid(4, 5), 4);
        assert_eq!(get_mid(1, 2), 1);
    }

    #[test]
    fn la_mediana_impar_y_par() {
        assert_eq!(mediana(&[5, 1, 3]).unwrap(), 3, "impar: el central");
        assert_eq!(mediana(&[1, 2, 3, 4]).unwrap(), 2, "par: get_mid(2,3) = 2");
        assert_eq!(mediana(&[7]).unwrap(), 7);
        assert!(mediana(&[]).is_err());
    }

    #[test]
    fn la_mediana_no_depende_del_orden_de_entrada() {
        let a = [9u64, 1, 5, 3, 7];
        let mut b = a;
        b.reverse();
        assert_eq!(mediana(&a).unwrap(), mediana(&b).unwrap());
    }

    /// **Las dos formas del clamp superior son idénticas — y aun así se usa la literal.**
    ///
    /// Este test empezó afirmando lo contrario. El SPEC y `research/dynamic-blocksize.md` decían
    /// que `Mlt + (Mlt·7)/10` **no** es `(Mlt·17)/10` bajo truncamiento entero. **Es falso**, y el
    /// test lo cazó: como `Mlt` es entero y `⌊x+n⌋ = ⌊x⌋+n` para `n` entero,
    ///
    /// ```text
    /// Mlt + ⌊7·Mlt/10⌋ = ⌊Mlt + 7·Mlt/10⌋ = ⌊17·Mlt/10⌋    ∀ Mlt ∈ ℤ
    /// ```
    ///
    /// Comprobado además sobre 300 000 valores, incluidos aleatorios hasta 2⁶³: cero divergencias.
    ///
    /// La razón de conservar la forma literal es **otra, y sí es real**: el margen de
    /// desbordamiento. `Mlt·17` desborda `u64` a partir de `1,09·10¹⁸`; `Mlt·7`, a partir de
    /// `2,64·10¹⁸` — 2,4× más holgura. Y mantiene identidad byte a byte con los valores intermedios
    /// de la implementación de referencia.
    #[test]
    fn las_dos_formas_del_clamp_superior_coinciden() {
        for m in (0u64..5_000).chain([1_000_000, u64::from(u32::MAX), 1_000_000_000_000]) {
            assert_eq!(
                m + (m * 7) / 10,
                (m * 17) / 10,
                "con Mlt = {m} las dos formas deberían coincidir"
            );
        }

        // Y el código usa la literal, que es la que aguanta valores mayores sin desbordar.
        let mlt = 1_000_000u64;
        assert_eq!(peso_largo_plazo(u64::MAX, mlt), mlt + (mlt * 7) / 10);
    }

    #[test]
    fn el_peso_de_largo_plazo_acota_por_arriba_y_por_abajo() {
        let mlt = 100_000u64;
        let inferior = (mlt * 10) / 17;
        let superior = mlt + (mlt * 7) / 10;

        assert_eq!(
            peso_largo_plazo(0, mlt),
            inferior,
            "un bloque vacío sube al suelo"
        );
        assert_eq!(
            peso_largo_plazo(u64::MAX, mlt),
            superior,
            "uno enorme baja al techo"
        );
        assert_eq!(peso_largo_plazo(mlt, mlt), mlt, "en el centro no se toca");
    }

    #[test]
    fn la_mediana_larga_nunca_baja_de_la_zona_libre() {
        assert_eq!(mediana_larga(&[1, 2, 3]).unwrap(), ZONA_LIBRE);
        let alto = ZONA_LIBRE * 3;
        assert_eq!(mediana_larga(&[alto, alto, alto]).unwrap(), alto);
    }

    /// C-WGT-08: la mediana efectiva respeta el suelo y el techo de ráfaga.
    #[test]
    fn la_mediana_efectiva_respeta_suelo_y_techo() {
        // Suelo: `MedianaLarga` ya lo aplica, así que un Mlt crudo pequeño sube a ZONA_LIBRE.
        assert_eq!(mediana_efectiva(MedianaLarga::nueva(1), 1), ZONA_LIBRE);

        // Sin ráfaga: gana la mayor de las dos.
        let mlt = ZONA_LIBRE * 2;
        assert_eq!(
            mediana_efectiva(MedianaLarga::nueva(mlt), ZONA_LIBRE),
            mlt,
            "max(Mlt, Mst)"
        );
        assert_eq!(mediana_efectiva(MedianaLarga::nueva(ZONA_LIBRE), mlt), mlt);

        // Techo de ráfaga: la corta no puede pasar de FACTOR_SURGE · Mlt.
        assert_eq!(
            mediana_efectiva(MedianaLarga::nueva(mlt), mlt * 1000),
            mlt * FACTOR_SURGE,
            "C-WGT-08: surge"
        );
    }

    /// **El tipo hace imposible el caso que D9 encontró.**
    ///
    /// Con `Mlt = 1000` crudo y `Mst = 10⁸`, un reordenamiento de C-WGT-08 daría `42 900` en vez de
    /// `100 000` — 2,3× menos, porque el techo de ráfaga `50·1000` atraparía el valor antes de que
    /// el suelo lo rescatara. `MedianaLarga` no permite construir ese `Mlt`.
    #[test]
    fn mediana_larga_impide_el_caso_patologico_de_d9() {
        let cruda = 1_000u64;
        assert!(
            cruda < ZONA_LIBRE,
            "el caso solo existe por debajo del suelo"
        );

        let mlt = MedianaLarga::nueva(cruda);
        assert_eq!(
            mlt.valor(),
            ZONA_LIBRE,
            "el constructor aplica el suelo, siempre"
        );

        // Con el suelo aplicado, el techo de ráfaga ya no puede atrapar nada por debajo de él.
        let m = mediana_efectiva(mlt, 100_000_000);
        assert_eq!(
            m,
            ZONA_LIBRE * FACTOR_SURGE,
            "el surge muerde, pero desde el suelo correcto"
        );
        assert!(
            m > 42_900,
            "no puede darse el valor degradado que D9 encontró"
        );
    }

    /// D9 refutó que reordenar cambie algo **bajo el invariante**. Se comprueba aquí para que la
    /// afirmación del SPEC quede respaldada por un test y no por una creencia.
    #[test]
    fn bajo_el_invariante_reordenar_no_cambia_nada() {
        for mlt_crudo in [0u64, 1, ZONA_LIBRE, ZONA_LIBRE * 3, ZONA_LIBRE * 1000] {
            for mst in [0u64, 1, ZONA_LIBRE, ZONA_LIBRE * 7, u64::from(u32::MAX)] {
                let mlt = MedianaLarga::nueva(mlt_crudo).valor();
                let original = {
                    let surge = u128::from(mlt) * u128::from(FACTOR_SURGE);
                    ((u128::from(mlt.max(mst)).min(surge)) as u64).max(ZONA_LIBRE)
                };
                // Ley distributiva de retículo: max(Mlt, min(Mst, S)) = min(max(Mlt, Mst), S),
                // válida porque S = 50·Mlt ≥ Mlt.
                let distributiva = {
                    let surge = u128::from(mlt) * u128::from(FACTOR_SURGE);
                    let interno = u128::from(mst).min(surge);
                    ((u128::from(mlt).max(interno)) as u64).max(ZONA_LIBRE)
                };
                assert_eq!(
                    original, distributiva,
                    "con Mlt={mlt} y Mst={mst} los reordenamientos deben coincidir"
                );
            }
        }
    }

    /// **La asimetría suma/resta del clamp**, que D9 encontró y que el superior no tenía.
    ///
    /// `⌊x⌋ + n = ⌊x + n⌋` vale para la suma. Para la resta hace falta **techo**:
    /// `⌊n − x⌋ = n − ⌈x⌉`. Quien "simplifique" el clamp inferior por analogía con el superior
    /// obtiene otro número.
    #[test]
    fn el_clamp_inferior_no_admite_la_forma_por_resta() {
        let mut difieren = 0u32;
        for mlt in 0u64..3_000 {
            let correcto = (mlt * 10) / 17;
            let por_resta_mal = mlt - (mlt * 7) / 17;
            if correcto != por_resta_mal {
                difieren += 1;
            }
            // Con techo sí coincide. `div_ceil` es exactamente ⌈7·Mlt/17⌉.
            let por_resta_con_techo = mlt - (mlt * 7).div_ceil(17);
            assert_eq!(
                correcto, por_resta_con_techo,
                "con Mlt={mlt}: la forma por resta solo vale con TECHO, no con piso"
            );
        }
        assert!(
            difieren > 2_000,
            "la forma ingenua por resta difiere casi siempre: {difieren}/3000"
        );

        // El caso mínimo que lo enseña de un vistazo.
        assert_eq!((3 * 10) / 17, 1);
        assert_eq!(3 - (3 * 7) / 17, 2, "un 2 donde debería salir 1");
    }

    /// Y el error clásico de orden de operaciones: dividir antes de multiplicar sesga a la baja.
    #[test]
    fn dividir_antes_de_multiplicar_sesga_el_clamp_inferior() {
        let mut difieren = 0u32;
        for mlt in 1u64..3_000 {
            if (mlt * 10) / 17 != (mlt / 17) * 10 {
                difieren += 1;
            }
        }
        assert!(
            difieren > 2_000,
            "(Mlt/17)·10 difiere de (Mlt·10)/17 en casi todos los casos: {difieren}/2999"
        );
    }

    #[test]
    fn el_limite_es_el_doble_de_la_mediana() {
        assert_eq!(limite(ZONA_LIBRE), 2 * ZONA_LIBRE);
        assert_eq!(limite(0), 0);
    }

    /// **C-WGT-10.** El constructor es el único sitio donde ocurre la resta, y rechaza el exceso.
    #[test]
    fn el_peso_validado_rechaza_por_encima_del_limite() {
        let lim = 2 * ZONA_LIBRE;
        assert!(
            PesoValidado::comprobar(lim, lim).is_ok(),
            "exactamente en el límite es válido"
        );
        let e = PesoValidado::comprobar(lim + 1, lim).unwrap_err();
        assert!(matches!(e, ConsensusError::PesoExcedeLimite { .. }));
    }

    /// La holgura `2M − x` se calcula una sola vez, en el constructor, y es correcta.
    ///
    /// En Cuprate esa resta vive suelta en la función de recompensa, protegida solo por un `if`
    /// previo: cualquier ruta nueva que la llame sin ese `if` hace underflow de `usize`. Aquí no
    /// existe una ruta así.
    #[test]
    fn la_holgura_se_calcula_una_vez_y_es_correcta() {
        let m = ZONA_LIBRE;
        let lim = 2 * m;
        let peso = m + m / 4;
        let v = PesoValidado::comprobar(peso, lim).unwrap();

        assert_eq!(v.peso(), peso);
        assert_eq!(v.holgura(), lim - peso);
        assert_eq!(
            v.numerador_penalizacion(),
            u128::from(lim - peso) * u128::from(peso)
        );

        // En el límite exacto la holgura es cero y el numerador también: subsidio nulo.
        let borde = PesoValidado::comprobar(lim, lim).unwrap();
        assert_eq!(borde.holgura(), 0);
        assert_eq!(borde.numerador_penalizacion(), 0);
    }

    /// El invariante de C-WGT-11, enunciable en una frase: toda transacción válida cabe en un
    /// bloque a la mediana mínima sin empujarlo más allá de la zona libre.
    #[test]
    fn toda_tx_valida_cabe_en_el_bloque_mas_pequeno() {
        let m_minima = ZONA_LIBRE;
        assert!(
            MAX_TX_WEIGHT <= m_minima,
            "C-WGT-11: una tx del tamaño máximo NO debe poder empujar el bloque más allá de la \
             zona libre — si no, habría fondos atrapados cuando la mediana esté baja"
        );
        // Y desde luego cabe bajo el límite duro.
        assert!(PesoValidado::comprobar(MAX_TX_WEIGHT, limite(m_minima)).is_ok());
    }

    #[test]
    fn la_mediana_corta_es_la_mediana_cruda() {
        let pesos = vec![10u64, 20, 30];
        assert_eq!(
            mediana_corta(&pesos).unwrap(),
            20,
            "sin suelo, a diferencia de la larga"
        );
    }
}
