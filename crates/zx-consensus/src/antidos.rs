//! Umbral anti-DoS para cadenas de cabeceras (SPEC §16.1, C-NET-04).
//!
//! # La historia que justifica este módulo: CVE-2019-25220
//!
//! Headers-first existe para no gastar ancho de banda en cuerpos de bloques que resultan ser
//! basura: se validan las cabeceras primero, que son 1000 veces más pequeñas. Pero **el propio
//! headers-first tuvo su agujero**, y es instructivo.
//!
//! Bitcoin Core guardaba un índice por cada cabecera con PoW válido, **sin exigir trabajo
//! acumulado**. Un atacante mandaba cadenas larguísimas de cabeceras de dificultad baja —válidas
//! una a una— y tumbaba el nodo por agotamiento de memoria. Divulgado el 2024-09-18, con cinco años
//! de exposición.
//!
//! Lo que hay que aprender no es el fallo, es **su deriva**:
//!
//! | | Coste del ataque |
//! |---|---|
//! | enero 2019 | ~4,12 BTC (32 % de un bloque) |
//! | septiembre 2024 | **~0,14 BTC (4,4 % de un bloque)** |
//!
//! **El ataque se abarató solo.** El umbral era absoluto y la dificultad de red subía, así que la
//! defensa se erosionaba sin que nadie tocara una línea. De ahí la forma de esta regla: el umbral
//! **MUST** ser relativo al tip propio, nunca una constante.
//!
//! ZEROX lo construye desde el día uno en vez de retrofitearlo, que es la única ventaja real de
//! nacer después.

use primitive_types::U256;

/// Bloques de holgura por debajo del tip que se aceptan sin exigir trabajo.
///
/// El umbral no es "tanto trabajo como mi cadena": eso rechazaría **bifurcaciones legítimas cerca
/// de la punta**, que son sucesos normales cada vez que dos mineros aciertan casi a la vez. La
/// holgura las admite.
///
/// 144 es el valor de Bitcoin Core (`GetAntiDoSWorkThreshold`), donde equivale a un día. En ZEROX,
/// con bloques de 120 s, son **4,8 horas** — más que suficiente para cualquier reorganización
/// honesta, y muy por debajo de `MAX_REORG_LENGTH = 99`… que en realidad es **menor**: la holgura
/// nunca será el factor limitante, porque el nodo se para antes por C-REORG-07.
pub const HOLGURA_BLOQUES: u32 = 144;

/// Trabajo mínimo absoluto que cualquier cadena candidata **MUST** demostrar.
///
/// # Por qué vale cero, y por qué eso es correcto
///
/// Es el análogo de `nMinimumChainWork` de Bitcoin: un suelo que se sube en cada release, según la
/// cadena real crece, para que un nodo nuevo no pueda ser engañado con una cadena falsa de poco
/// trabajo durante su primera sincronización.
///
/// Para una cadena **que todavía no existe**, el único valor correcto es **cero**. Cualquier otro
/// rechazaría la cadena real en el arranque. No es una laguna: es la respuesta.
///
/// 🔶 **P-024** era esto, y queda resuelto así. **No es una constante permanente de consenso**: dos
/// nodos con valores distintos no se bifurcan, solo difieren en cuánta basura retienen antes de
/// descartarla. Se sube por release, como en Bitcoin, en cuanto la cadena tenga historia que
/// proteger.
pub const TRABAJO_MINIMO_CADENA: U256 = U256::zero();

/// El umbral que una cadena de cabeceras **MUST** superar para materializarse (C-NET-04).
///
/// ```text
/// umbral = max( trabajo(tip) − HOLGURA_BLOQUES · trabajo_de_un_bloque,  TRABAJO_MINIMO_CADENA )
/// ```
///
/// # Por qué relativo al tip y no absoluto
///
/// Un umbral absoluto **caduca solo**: la dificultad de red sube, el coste de fabricar una cadena
/// que lo supere baja, y la defensa se evapora sin que nadie se entere. Es literalmente lo que pasó
/// con CVE-2019-25220 entre 2019 y 2024.
///
/// # Errores de saturación
///
/// Se usa aritmética saturada en las dos direcciones: una holgura mayor que el trabajo del tip
/// —posible al principio de la cadena, cuando hay poco acumulado— da cero, no un desbordamiento.
#[must_use]
pub fn umbral(trabajo_tip: U256, trabajo_de_un_bloque: U256) -> U256 {
    let holgura = trabajo_de_un_bloque.saturating_mul(U256::from(HOLGURA_BLOQUES));
    let relativo = trabajo_tip.saturating_sub(holgura);
    if relativo > TRABAJO_MINIMO_CADENA {
        relativo
    } else {
        TRABAJO_MINIMO_CADENA
    }
}

/// ¿Merece esta cadena de cabeceras que le reservemos memoria? (C-NET-04)
///
/// `trabajo_candidata` es el trabajo acumulado de la cadena que un peer propone. Si no llega al
/// umbral, **MUST NOT** materializarse en un índice por cabecera — y el peer **MUST NOT** ser
/// penalizado por ello: proponer una cadena que no gana no es mala fe, es la situación normal de
/// cualquiera que vaya por detrás.
#[must_use]
pub fn merece_memoria(trabajo_candidata: U256, trabajo_tip: U256, trabajo_bloque: U256) -> bool {
    trabajo_candidata >= umbral(trabajo_tip, trabajo_bloque)
}

#[cfg(test)]
mod tests {
    use super::{HOLGURA_BLOQUES, TRABAJO_MINIMO_CADENA, merece_memoria, umbral};
    use primitive_types::U256;

    fn u(n: u64) -> U256 {
        U256::from(n)
    }

    /// El umbral deja pasar bifurcaciones cerca de la punta.
    ///
    /// Es lo que la holgura existe para permitir: dos mineros que aciertan casi a la vez producen
    /// exactamente esto, y rechazarlo convertiría un suceso normal en una partición.
    #[test]
    fn una_bifurcacion_cercana_a_la_punta_pasa() {
        let bloque = u(1_000);
        let tip = bloque * u(10_000); // una cadena de 10 000 bloques

        // Una rama que se separó hace 10 bloques tiene casi el mismo trabajo.
        let rama = tip - bloque * u(10);
        assert!(
            merece_memoria(rama, tip, bloque),
            "10 bloques atrás debe pasar"
        );

        // Y una que se separó justo en el borde de la holgura, también.
        let borde = tip - bloque * u(u64::from(HOLGURA_BLOQUES));
        assert!(merece_memoria(borde, tip, bloque), "el borde exacto pasa");
    }

    /// Y rechaza la cadena de bajo trabajo, que es el ataque.
    #[test]
    fn una_cadena_de_bajo_trabajo_se_rechaza() {
        let bloque = u(1_000);
        let tip = bloque * u(10_000);

        // El ataque de CVE-2019-25220: muchísimas cabeceras válidas, poquísimo trabajo total.
        let basura = bloque * u(50);
        assert!(
            !merece_memoria(basura, tip, bloque),
            "una cadena de 50 bloques de trabajo NO merece memoria frente a una de 10 000"
        );

        // Un byte por debajo del umbral tampoco.
        let justo_debajo = umbral(tip, bloque) - u(1);
        assert!(!merece_memoria(justo_debajo, tip, bloque));
        assert!(
            merece_memoria(umbral(tip, bloque), tip, bloque),
            "el umbral justo sí"
        );
    }

    /// **Una cadena recién nacida acepta cualquier cosa, y debe.**
    ///
    /// Con el tip en el génesis no hay trabajo acumulado, así que el umbral es cero. Rechazar aquí
    /// significaría que el primer nodo nunca puede sincronizar con el segundo.
    #[test]
    fn una_cadena_sin_historia_no_rechaza_nada() {
        let bloque = u(1_000);
        assert_eq!(umbral(U256::zero(), bloque), TRABAJO_MINIMO_CADENA);
        assert!(merece_memoria(U256::zero(), U256::zero(), bloque));
        assert!(merece_memoria(u(1), U256::zero(), bloque));
    }

    /// **No desborda por ningún extremo.**
    ///
    /// Al principio de la cadena la holgura supera al trabajo del tip, y una resta sin saturar
    /// envolvería a un número enorme — convirtiendo el umbral en "nada pasa nunca".
    #[test]
    fn no_desborda_en_ningun_extremo() {
        let bloque = u(1_000_000);

        // Holgura mayor que el trabajo del tip: umbral cero, no un número gigante.
        assert_eq!(umbral(u(10), bloque), TRABAJO_MINIMO_CADENA);

        // Y trabajo por bloque absurdo tampoco desborda al multiplicar.
        assert_eq!(umbral(U256::MAX, U256::MAX), TRABAJO_MINIMO_CADENA);
        assert!(umbral(U256::MAX, U256::one()) > U256::zero());
    }

    /// **El umbral es relativo al tip: sube con la cadena.**
    ///
    /// Es la propiedad que CVE-2019-25220 no tenía, y por la que el ataque se abarató solo entre
    /// 2019 y 2024. Un umbral que no crece con la red es una defensa con fecha de caducidad.
    #[test]
    fn el_umbral_crece_con_la_cadena() {
        let bloque = u(1_000);
        let joven = umbral(bloque * u(1_000), bloque);
        let vieja = umbral(bloque * u(1_000_000), bloque);
        assert!(
            vieja > joven,
            "el umbral MUST subir con el trabajo acumulado, o caduca solo"
        );
    }
}
