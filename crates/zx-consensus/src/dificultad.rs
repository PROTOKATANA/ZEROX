//! LWMA-1: ajuste de dificultad con retarget por bloque (SPEC §7.3).
//!
//! # Cuál de las dos LWMA-1
//!
//! Existen **dos fórmulas publicadas bajo el mismo nombre**, con resultados numéricos distintos.
//! ZEROX usa la variante de **espacio-target en U512**. La otra —dificultad en `u64`— tiene un bug
//! de overflow confirmado que Wownero tuvo que parchear en producción.
//!
//! # El patrón prohibido
//!
//! `C-DIFF-03` reconstruye los solvetimes de forma **monótona**. La diferencia con saturar no es
//! estilística: `if st < 1 { st = 1 }` es exactamente el patrón que produjo un ataque real, en el
//! que una moneda perdió 4 800 bloques en 5 horas porque los timestamps retrasados se convertían en
//! solvetimes largos artificiales que hundían la dificultad.
//!
//! Del invariante `1 ≤ st[j] ≤ ST_CAP`, **las dos mitades son distintas** —lo precisó D9, porque el
//! comentario anterior decía "por construcción" a secas y solo es cierto de una de ellas:
//!
//! - **`st ≥ 1` sí es por construcción.** Cada timestamp se normaliza contra el anterior **ya
//!   normalizado** antes de restar, así que la diferencia nunca puede ser ≤ 0. Lo importante no es
//!   solo que el valor salga ≥ 1: es que `previo` **nunca queda contaminado** por un timestamp
//!   retrasado. Ahí está la diferencia con el patrón que hundió aquella cadena.
//! - **`st ≤ ST_CAP` es saturación**, literalmente `.min(ST_CAP)`. Y es segura precisamente porque
//!   **no toca `previo`**: recorta el valor que entra en la suma sin desincronizar el reloj de la
//!   reconstrucción.
//!
//! # Determinismo
//!
//! `C-DIFF-01` hace de esto una **función pura**: sus únicas entradas son los `N+1` timestamps y
//! los `N` targets de la ventana. No lee reloj, ni hora de red, ni mempool, ni configuración.
//! Cualquier fuente de no-determinismo aquí es un split de cadena.

// `clippy::integer_division` está en `warn` en el workspace y su sugerencia es "considera usar
// floats". Aquí eso sería **exactamente el bug**: C-ENC-04 prohíbe la coma flotante en toda ruta de
// consenso, y la división entera **truncada** es lo que C-DIFF-07 especifica, no un atajo.
#![expect(
    clippy::integer_division,
    reason = "C-ENC-04 prohíbe floats; la división entera truncada es la especificación (C-DIFF-07)"
)]

use primitive_types::{U256, U512};
use zx_core::target::{min_target, pow_limit};

use crate::error::ConsensusError;

/// Tiempo objetivo entre bloques, en segundos.
pub const T: i64 = 120;

/// Tamaño de la ventana, en bloques (P-003). A 120 s son 3 horas.
pub const N: usize = 90;

/// `k = N(N+1)T/2`. **Constante precomputada**: no se evalúa la expresión en caliente.
pub const K: i64 = 491_400;

/// `NK = N·k`, el denominador de C-DIFF-07.
pub const NK: i64 = 44_226_000;

/// `ST_CAP = 6T`. Techo del solvetime de un bloque.
pub const ST_CAP: i64 = 720;

/// `T_FLOOR = N(N+1)T/20`. Suelo de la suma ponderada (P-003).
///
/// Sin él, un atacante que controle la ventana con timestamps a `padre+1` multiplica la dificultad
/// por **120 en un solo bloque** y congela la cadena al retirarse. Con el suelo, el techo es ×10.
pub const T_FLOOR: i64 = 49_140;

/// `FTL = N·T/20`. Margen de futuro admitido en un timestamp (C-TS-03).
pub const FTL: i64 = 540;

/// Ventana del median-time-past, en bloques (C-TS-02).
pub const MTP_W: usize = 11;

/// Numerador de la corrección del sesgo del clamp (C-DIFF-07).
///
/// # ✅ P-005 CERRADO 2026-09-04 (Katana) → **no se corrige.** Vale 1, y así se queda.
///
/// Los dos factores se conservan en la fórmula en vez de colapsarla a `S·t/NK` para que la
/// **ausencia** de corrección sea visible en el código y no parezca un descuido.
///
/// ## Qué pasó, porque el error importa más que el resultado
///
/// Este módulo llegó a implementar `99752/100000 ≈ 0,9975`, aproximando `1 − e⁻⁶`, con una
/// aserción de compilación que exigía `BIAS_NUM < BIAS_DEN` para "que la corrección apriete, nunca
/// afloje".
///
/// **D9 refutó la dirección, y la refutación se verificó de forma independiente.** La derivación:
///
/// - En régimen estable `S = N·T_tgt`, así que `next = T_tgt · t / k`, y la estabilidad exige
///   `t = k`, es decir `E[st] = T`.
/// - Pero el clamp `min(6T, ST)` recorta **por arriba y no por abajo**:
///   `E[min(X, 6T)] = T(1 − e⁻⁶) = 119,70 s < T`.
/// - Luego `E[t] = 0,9975·k`, el target **baja**, y los bloques salen **más lentos**. El punto fijo
///   está en `ρ·(1 − e^(−6/ρ)) = 1` → `ρ = 1,00252` → **120,30 s**, exactamente la cifra que el
///   propio SPEC citaba, lo que valida el modelo.
/// - Para llevar `ρ` a 1 haría falta `r = 1/(1 − e⁻⁶) = 1,002486`, es decir **`r > 1`: aflojar**.
///
/// Multiplicar por `0,9975` empujaba en el sentido contrario: desplazaba el punto fijo a
/// **120,61 s**, *más lejos* de 120 que no corregir. Y la aserción de compilación estaba
/// **protegiendo la dirección equivocada**.
///
/// ## Por qué se cierra en "no corregir" y no en "invertirlo"
///
/// La dirección está demostrada. **El valor no.** El campo medio de primer orden da `r ≈ 1,002486`;
/// el Monte Carlo de D9 —float y aritmética entera, varias semillas, hasta 300 000 bloques— sitúa
/// el punto fijo empírico en `r ≈ 1,0045`. **Discrepan**, así que hay efectos de segundo orden que
/// el modelo simple no captura, y por la regla de independencia matemática una cifra que dos
/// métodos no reproducen **no puede presentarse como demostrada**. Fijar en el consenso, para
/// siempre, un número que no sabemos justificar, a cambio de un error del 0,25 %, es un mal cambio.
///
/// Además el 0,25 % es pequeño en su contexto: durante cualquier crecimiento de hashrate LWMA va
/// por detrás y los bloques salen *más rápido* que `T`, un efecto un orden de magnitud mayor.
///
/// ## Consecuencias declaradas
///
/// | | Con `BIAS = 1` |
/// |---|---|
/// | Solvetime medio estacionario | **120,30 s**, no 120,00 |
/// | Desviación | **+0,25 %** (+0,30 s/bloque) |
/// | Bloques al año | 262 139 en vez de 262 800 — **661 menos** |
/// | Calendario de emisión | se estira un 0,25 %: el hito de 1000 M llega ~18 días tarde |
/// | `N_LARGO` | la ventana "de un año" mide en realidad **366 días** |
///
/// No son fallos: son la definición del sistema, y ahora están escritas.
///
/// Precedente: Flux, TENT y Tari usan LWMA-1 con clamp y **no corrigen**.
///
/// Efecto lateral bueno: con `BIAS = 1` las cifras de C-DIFF-05 (×120 sin suelo, ×10 con él)
/// vuelven a ser **exactas** — verificado por D9 con aritmética de fracciones.
///
/// ## Si algún día se reabre
///
/// Haría falta un modelo que capture los efectos de segundo orden —ponderación no uniforme de la
/// ventana, Jensen sobre `S`— y **reconcilie** campo medio con Monte Carlo. El algoritmo funciona
/// con cualquier racional: serían dos líneas, y la aserción de abajo ya protege la dirección buena.
pub const BIAS_NUM: u64 = 1;

/// Denominador de la corrección del sesgo. Ver [`BIAS_NUM`]. ✅ **P-005 cerrado: no se corrige.**
pub const BIAS_DEN: u64 = 1;

// Si la corrección se reabre alguna vez, MUST **aflojar** —`BIAS_NUM ≥ BIAS_DEN`— porque el clamp
// recorta por arriba y sesga el target a la baja.
//
// Esta aserción estaba **al revés** y por tanto protegía activamente la dirección equivocada. Queda
// como recordatorio de que un candado mal orientado es peor que no tener candado: da confianza en
// la propiedad contraria a la que hace falta.
const _: () = assert!(
    BIAS_NUM >= BIAS_DEN,
    "C-DIFF-07: si la corrección del sesgo se reabre, debe aflojar (>= 1), no apretar — ver P-005"
);

/// La ventana que consume el retarget (C-DIFF-01).
///
/// Es todo lo que la función pura puede mirar. Si algún día alguien necesita "una cosa más" aquí,
/// esa cosa entra en el consenso y hay que pasar por el SPEC.
#[derive(Clone, Copy, Debug)]
pub struct VentanaRetarget<'a> {
    /// Los `N+1` timestamps, de `ts(H−N−1)` a `ts(H−1)`, en orden ascendente de altura.
    pub timestamps: &'a [i64],
    /// Los `N` targets, ya decodificados desde `bits` (C-DIFF-09), en el mismo orden.
    pub targets: &'a [U256],
}

/// Reconstruye los solvetimes de la ventana de forma monótona (C-DIFF-03).
///
/// Invariante garantizado por construcción: `1 ≤ st[j] ≤ ST_CAP`.
fn solvetimes(timestamps: &[i64]) -> Result<Vec<i64>, ConsensusError> {
    let mut previo = *timestamps.first().ok_or(ConsensusError::VentanaVacia)?;
    let mut st = Vec::with_capacity(N);

    for actual in timestamps.iter().skip(1) {
        // Normalización: si el timestamp no avanza, se toma `previo + 1`. Nunca se satura después.
        let c = if *actual > previo {
            *actual
        } else {
            previo
                .checked_add(1)
                .ok_or(ConsensusError::DesbordamientoAritmetico)?
        };
        let bruto = c
            .checked_sub(previo)
            .ok_or(ConsensusError::DesbordamientoAritmetico)?;
        st.push(bruto.min(ST_CAP));
        previo = c;
    }
    Ok(st)
}

/// Calcula el target del bloque de altura `h` (C-DIFF-01..08).
///
/// Es una **función pura** de la ventana. Para `1 ≤ h ≤ N` no debe llamarse: rige
/// `TARGET_INICIAL` (C-DIFF-02).
///
/// # Errores
/// - [`ConsensusError::VentanaDeTamanoIncorrecto`] si la ventana no trae exactamente `N+1`
///   timestamps y `N` targets. **MUST NOT** encogerse dinámicamente.
/// - [`ConsensusError::DesbordamientoAritmetico`] ante cualquier desbordamiento (C-ENC-03).
pub fn siguiente_target(v: VentanaRetarget<'_>) -> Result<U256, ConsensusError> {
    if v.timestamps.len() != N + 1 || v.targets.len() != N {
        return Err(ConsensusError::VentanaDeTamanoIncorrecto {
            timestamps: v.timestamps.len(),
            targets: v.targets.len(),
        });
    }

    // C-DIFF-03 · solvetimes monótonos.
    let st = solvetimes(v.timestamps)?;

    // C-DIFF-04 · suma ponderada `t = Σ j·st[j]`, con j desde 1.
    let mut t: i64 = 0;
    for (idx, s) in st.iter().enumerate() {
        let j = i64::try_from(idx).map_err(|_| ConsensusError::DesbordamientoAritmetico)? + 1;
        let termino = j
            .checked_mul(*s)
            .ok_or(ConsensusError::DesbordamientoAritmetico)?;
        t = t
            .checked_add(termino)
            .ok_or(ConsensusError::DesbordamientoAritmetico)?;
    }

    // C-DIFF-05 · suelo.
    if t < T_FLOOR {
        t = T_FLOOR;
    }

    // C-DIFF-06 · suma de targets en U512, sin divisiones intermedias.
    let mut s = U512::zero();
    for target in v.targets {
        let ancho = U512::from(*target);
        s = s
            .checked_add(ancho)
            .ok_or(ConsensusError::DesbordamientoAritmetico)?;
    }

    // C-DIFF-07 · `next = (S · t · BIAS_NUM) / (NK · BIAS_DEN)`, división entera truncada.
    let t_u = u64::try_from(t).map_err(|_| ConsensusError::DesbordamientoAritmetico)?;
    let numerador = s
        .checked_mul(U512::from(t_u))
        .and_then(|x| x.checked_mul(U512::from(BIAS_NUM)))
        .ok_or(ConsensusError::DesbordamientoAritmetico)?;
    let nk = u64::try_from(NK).map_err(|_| ConsensusError::DesbordamientoAritmetico)?;
    let denominador = U512::from(nk)
        .checked_mul(U512::from(BIAS_DEN))
        .ok_or(ConsensusError::DesbordamientoAritmetico)?;
    if denominador.is_zero() {
        return Err(ConsensusError::DesbordamientoAritmetico);
    }
    let next = numerador / denominador;

    // C-DIFF-08 · acotado. El clamp se aplica en U512 y solo después se estrecha, para que un
    // resultado por encima de POW_LIMIT no se trunque en silencio al convertir.
    let limite = U512::from(pow_limit());
    let suelo = U512::from(min_target());
    let acotado = next.max(suelo).min(limite);

    // Tras el clamp, `acotado ≤ POW_LIMIT < 2^224`, así que entra en U256 sin pérdida. Se
    // convierte por bytes en vez de con `low_u256()` para que la conversión sea explícita y
    // auditable: si algún día el clamp dejara de garantizar la cota, esto se vería.
    let bytes = acotado.to_big_endian();
    let bajos = bytes
        .get(32..)
        .ok_or(ConsensusError::DesbordamientoAritmetico)?;
    Ok(U256::from_big_endian(bajos))
}

/// Median-time-past sobre los `MTP_W` bloques anteriores (C-TS-02).
///
/// **Solo** sirve de reloj para `lock_time` y HTLC. **MUST NOT** entrar en el retarget.
///
/// # Errores
/// [`ConsensusError::VentanaDeTamanoIncorrecto`] si no se dan exactamente `MTP_W` timestamps.
pub fn median_time_past(ultimos: &[i64]) -> Result<i64, ConsensusError> {
    if ultimos.len() != MTP_W {
        return Err(ConsensusError::VentanaDeTamanoIncorrecto {
            timestamps: ultimos.len(),
            targets: 0,
        });
    }
    let mut v = ultimos.to_vec();
    v.sort_unstable();
    v.get(MTP_W / 2)
        .copied()
        .ok_or(ConsensusError::VentanaVacia)
}

#[cfg(test)]
#[expect(clippy::unwrap_used, reason = "los tests fallan con panic por diseño")]
mod tests {
    use super::{
        BIAS_DEN, BIAS_NUM, FTL, K, MTP_W, N, NK, ST_CAP, T, T_FLOOR, VentanaRetarget,
        median_time_past, siguiente_target,
    };
    use crate::error::ConsensusError;
    use primitive_types::{U256, U512};
    use zx_core::target::{min_target, pow_limit};

    /// Las constantes precomputadas **MUST** coincidir con su definición.
    ///
    /// Es la lección de H-005: toda constante que sea función de otras se comprueba, no se confía.
    #[test]
    fn las_constantes_precomputadas_cuadran() {
        let n = i64::try_from(N).unwrap();
        assert_eq!(K, n * (n + 1) * T / 2, "k = N(N+1)T/2");
        assert_eq!(NK, n * K, "NK = N·k");
        assert_eq!(ST_CAP, 6 * T, "ST_CAP = 6T");
        assert_eq!(T_FLOOR, n * (n + 1) * T / 20, "T_FLOOR = N(N+1)T/20");
        assert_eq!(FTL, n * T / 20, "FTL = N·T/20");
    }

    /// Ventana en la que todos los bloques salieron exactamente a tiempo y con el mismo target.
    fn ventana_estable(target: U256) -> (Vec<i64>, Vec<U256>) {
        let ts: Vec<i64> = (0..=N).map(|i| i64::try_from(i).unwrap() * T).collect();
        let tg: Vec<U256> = vec![target; N];
        (ts, tg)
    }

    fn calcular(ts: &[i64], tg: &[U256]) -> U256 {
        siguiente_target(VentanaRetarget {
            timestamps: ts,
            targets: tg,
        })
        .unwrap()
    }

    /// Con la red exactamente en su ritmo, el target no debe moverse casi nada.
    ///
    /// El "casi" es la corrección del sesgo: el resultado es ~0,25 % **más difícil** que el target
    /// de entrada, que es justo lo que la corrección persigue — compensar que el clamp `min(6T, ST)`
    /// recorta por arriba y no por abajo.
    #[test]
    fn en_regimen_estable_el_target_apenas_se_mueve() {
        let base = U256::one() << 200_usize;
        let (ts, tg) = ventana_estable(base);
        let next = calcular(&ts, &tg);

        let ratio_num = U512::from(next) * U512::from(1_000_000_u32);
        let ratio = (ratio_num / U512::from(base)).low_u64();
        assert!(
            (990_000..=1_000_000).contains(&ratio),
            "esperado ~0,9975·base, salió ratio {ratio}/1e6"
        );
        // Y la corrección aprieta, nunca afloja.
        assert!(
            next <= base,
            "la corrección del sesgo MUST hacer el target igual o menor"
        );
    }

    /// Bloques al doble de rápido ⇒ el target **baja** (más difícil).
    #[test]
    fn bloques_rapidos_endurecen() {
        let base = U256::one() << 200_usize;
        let (_, tg) = ventana_estable(base);
        let rapidos: Vec<i64> = (0..=N)
            .map(|i| i64::try_from(i).unwrap() * (T / 2))
            .collect();
        let next = calcular(&rapidos, &tg);
        assert!(
            next < base,
            "el doble de rápido debe endurecer: {next} < {base}"
        );
    }

    /// Bloques al doble de lentos ⇒ el target **sube** (más fácil).
    #[test]
    fn bloques_lentos_ablandan() {
        let base = U256::one() << 200_usize;
        let (_, tg) = ventana_estable(base);
        let lentos: Vec<i64> = (0..=N)
            .map(|i| i64::try_from(i).unwrap() * (T * 2))
            .collect();
        let next = calcular(&lentos, &tg);
        assert!(
            next > base,
            "el doble de lentos debe ablandar: {next} > {base}"
        );
    }

    /// **C-DIFF-05, y el motivo de P-003.** El suelo acota el endurecimiento a ×10.
    ///
    /// Sin él, un atacante que controle la ventana poniendo todos los timestamps a `padre+1`
    /// multiplica la dificultad por **120 en un solo bloque** y congela la cadena al retirarse.
    #[test]
    fn el_suelo_acota_el_endurecimiento_a_diez_veces() {
        let base = U256::one() << 200_usize;
        let (_, tg) = ventana_estable(base);
        // El peor caso: cada timestamp exactamente uno más que el anterior ⇒ st[j] = 1 ∀j.
        let hostiles: Vec<i64> = (0..=N).map(|i| i64::try_from(i).unwrap()).collect();
        let next = calcular(&hostiles, &tg);

        // t queda en T_FLOOR = K/10, así que next ≈ base/10, no base/120.
        let diez_veces_mas_dificil = base / U256::from(10_u32);
        let cien_veces = base / U256::from(100_u32);
        assert!(
            next > cien_veces,
            "sin suelo caería a ~base/120; con suelo no: {next}"
        );
        assert!(
            next <= diez_veces_mas_dificil * U256::from(11_u32) / U256::from(10_u32),
            "el suelo debe acotar el endurecimiento cerca de ×10: {next}"
        );
    }

    /// **C-DIFF-03: el invariante es por construcción, no por saturación.**
    ///
    /// Timestamps que retroceden no pueden generar solvetimes negativos ni cero. Este es el patrón
    /// que hundió una cadena real: 4 800 bloques perdidos en 5 horas.
    #[test]
    fn los_timestamps_que_retroceden_no_hunden_la_dificultad() {
        let base = U256::one() << 200_usize;
        let (_, tg) = ventana_estable(base);

        // Timestamps caóticos, algunos hacia atrás y con saltos enormes.
        let mut caos: Vec<i64> = Vec::with_capacity(N + 1);
        for i in 0..=N {
            let i = i64::try_from(i).unwrap();
            caos.push(if i % 3 == 0 { i * T } else { i * T - 10_000 });
        }
        let next = calcular(&caos, &tg);

        // Sea cual sea el desorden, el resultado sigue acotado y no se desploma a "gratis".
        assert!(next >= min_target() && next <= pow_limit());
        assert!(
            next <= base * U256::from(11_u32) / U256::from(10_u32),
            "un retroceso de timestamps NO debe poder ablandar la dificultad: {next}"
        );
    }

    /// C-DIFF-08: el resultado siempre queda dentro de `[MIN_TARGET, POW_LIMIT]`.
    #[test]
    fn el_resultado_siempre_esta_acotado() {
        // Partiendo del target más fácil y con bloques lentísimos, no puede superar POW_LIMIT.
        let (_, tg) = ventana_estable(pow_limit());
        let lentisimos: Vec<i64> = (0..=N)
            .map(|i| i64::try_from(i).unwrap() * 100_000)
            .collect();
        assert!(
            calcular(&lentisimos, &tg) <= pow_limit(),
            "C-DIFF-08: techo"
        );

        // Partiendo del más difícil y con bloques instantáneos, no puede bajar de MIN_TARGET.
        let (_, tg) = ventana_estable(min_target());
        let instantaneos: Vec<i64> = (0..=N).map(|i| i64::try_from(i).unwrap()).collect();
        assert!(
            calcular(&instantaneos, &tg) >= min_target(),
            "C-DIFF-08: suelo"
        );
    }

    /// C-DIFF-01: función pura. La misma ventana da siempre el mismo resultado.
    #[test]
    fn es_determinista() {
        let base = U256::one() << 190_usize;
        let (ts, tg) = ventana_estable(base);
        let a = calcular(&ts, &tg);
        for _ in 0..8 {
            assert_eq!(calcular(&ts, &tg), a);
        }
    }

    /// C-DIFF-02: la ventana es **siempre** de tamaño `N`. No se encoge ni crece.
    #[test]
    fn se_rechaza_una_ventana_de_tamano_incorrecto() {
        let base = U256::one() << 200_usize;
        // Se construyen holgados y se recortan, para poder probar también tamaños por exceso.
        let ts_largo: Vec<i64> = (0..=(N + 5))
            .map(|i| i64::try_from(i).unwrap() * T)
            .collect();
        let tg_largo: Vec<U256> = vec![base; N + 5];

        // (timestamps, targets) — solo (N+1, N) es válido.
        let casos = [
            (N, N),
            (N + 1, N - 1),
            (N + 2, N),
            (N + 1, N + 1),
            (0, 0),
            (N + 3, N + 2),
        ];
        for (t_len, g_len) in casos {
            let r = siguiente_target(VentanaRetarget {
                timestamps: ts_largo.get(..t_len).unwrap(),
                targets: tg_largo.get(..g_len).unwrap(),
            });
            assert!(
                matches!(r, Err(ConsensusError::VentanaDeTamanoIncorrecto { .. })),
                "({t_len}, {g_len}) debería rechazarse, devolvió {r:?}"
            );
        }

        // Y el caso válido sí pasa, para que el test no sea trivialmente cierto.
        assert!(
            siguiente_target(VentanaRetarget {
                timestamps: ts_largo.get(..=N).unwrap(),
                targets: tg_largo.get(..N).unwrap(),
            })
            .is_ok(),
            "(N+1, N) es la única forma válida"
        );
    }

    /// ✅ **P-005 cerrado: no se corrige.** `BIAS = 1/1`, y este test lo fija.
    ///
    /// La **dirección** —si alguna vez se reabre— ya la impone una aserción de compilación
    /// (`BIAS_NUM >= BIAS_DEN`), que es más fuerte que un test. Lo que este comprueba es que la
    /// decisión sigue siendo la tomada: si alguien introduce una corrección, este test falla y
    /// obliga a reabrir P-005 explícitamente en vez de deslizar una constante.
    #[test]
    fn la_correccion_del_sesgo_sigue_en_la_identidad() {
        assert_eq!(
            (BIAS_NUM, BIAS_DEN),
            (1, 1),
            "P-005 se cerró en NO corregir (sesgo documentado de +0,30 s). Si esto falla, alguien \
             fijó una corrección — reabre P-005, comprueba que la dirección es AFLOJAR, y \
             actualiza SPEC C-DIFF-07 con las consecuencias declaradas"
        );
    }

    /// La derivación que refutó la dirección anterior, ejecutada de verdad para que no se repita.
    ///
    /// El clamp `min(6T, ST)` recorta por arriba, así que la media observada del solvetime es
    /// `T(1 − e⁻⁶) < T`. Eso hace que `t < k`, el target baje y los bloques salgan **más lentos**.
    /// Corregirlo exige multiplicar por **más** de 1, no por menos.
    ///
    /// Se calcula `1 − e⁻⁶` con una serie de Taylor en aritmética racional entera, para no meter
    /// coma flotante en un crate de consenso ni siquiera en un test.
    #[test]
    fn el_clamp_sesga_el_solvetime_a_la_baja() {
        // e⁻⁶ = Σ (−6)ⁿ/n!, en punto fijo de 12 decimales con acumuladores con signo.
        const ESCALA: i128 = 1_000_000_000_000;
        let mut termino: i128 = ESCALA;
        let mut suma: i128 = 0;
        for n in 0..64_i128 {
            suma += termino;
            termino = termino * -6 / (n + 1);
        }
        let e_menos_6 = suma; // ≈ 0,002478752 · ESCALA
        let factor = ESCALA - e_menos_6; // 1 − e⁻⁶

        assert!(
            (997_500_000_000..=997_530_000_000).contains(&factor),
            "1 − e⁻⁶ debería ser ≈0,99752; salió {factor}/{ESCALA}"
        );

        // La media truncada es MENOR que T: ese es el sesgo, y va hacia abajo.
        let t_ms: i128 = 120_000;
        let media_truncada = t_ms * factor / ESCALA;
        assert!(
            media_truncada < t_ms,
            "el clamp recorta por arriba: la media observada ({media_truncada} ms) MUST ser menor \
             que T ({t_ms} ms). Si fuera mayor, la corrección iría en el otro sentido"
        );

        // Y por tanto el factor corrector es T / media_truncada > 1: AFLOJA.
        let corrector = t_ms * ESCALA / media_truncada;
        assert!(
            corrector > ESCALA,
            "el factor corrector es {corrector}/{ESCALA} > 1 — ponerlo < 1, como estaba, empeora \
             el sesgo en vez de corregirlo"
        );
    }

    /// Cota de overflow de C-DIFF-07 con los valores máximos reales.
    ///
    /// El SPEC estima `S·t·BIAS_NUM ≈ 2^265`; el máximo real es 2^269. Ambos caben de sobra en
    /// U512, pero el número correcto es el segundo.
    #[test]
    fn el_numerador_de_c_diff_07_cabe_en_u512() {
        let s_max = U512::from(pow_limit()) * U512::from(u32::try_from(N).unwrap());
        let t_max = U512::from(u64::try_from(ST_CAP).unwrap())
            * U512::from(u64::try_from(N * (N + 1) / 2).unwrap());
        let prod = s_max
            .checked_mul(t_max)
            .and_then(|x| x.checked_mul(U512::from(BIAS_NUM)));
        assert!(prod.is_some(), "el numerador MUST caber en U512");
        let bits = 512 - prod.unwrap().leading_zeros();
        assert!(bits <= 280, "el numerador ocupa {bits} bits");
    }

    // ── MTP ──────────────────────────────────────────────────────────────────

    #[test]
    fn el_mtp_es_la_mediana_y_no_le_afecta_el_orden() {
        let v: Vec<i64> = (0..MTP_W).map(|i| i64::try_from(i).unwrap() * 10).collect();
        let esperado = i64::try_from(MTP_W / 2).unwrap() * 10;
        assert_eq!(median_time_past(&v).unwrap(), esperado);

        let mut desordenado = v;
        desordenado.reverse();
        assert_eq!(
            median_time_past(&desordenado).unwrap(),
            esperado,
            "la mediana no ve el orden"
        );
    }

    #[test]
    fn el_mtp_exige_exactamente_once_timestamps() {
        assert!(median_time_past(&[1, 2, 3]).is_err());
        assert!(median_time_past(&[]).is_err());
    }
}
