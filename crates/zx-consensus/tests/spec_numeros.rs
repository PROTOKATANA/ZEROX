//! **El SPEC no puede decir un número que el código contradiga** (C-SPEC-01).
//!
//! # Por qué existe este archivo
//!
//! Este proyecto ha cometido **tres veces** el mismo error, y las tres lo encontró alguien
//! auditando, no el compilador:
//!
//! | | Qué decía | Qué era | Cómo se rompió |
//! |---|---|---|---|
//! | **H-005** | nonce en `[92,100)`, offset 76 | `[96,104)`, offset 80 | `timestamp` pasó de `u32` a `u64` |
//! | Tamaño de cabecera | 112 bytes, en **seis** sitios | **92** | nunca fue cierto; se copió y se propagó |
//! | `MAX_RESPUESTA_BYTES` | 12,8 MB, en **cuatro** sitios | **25,6 MB** | C-NET-13 dobló la constante de la que sale |
//!
//! El patrón es siempre el mismo: **un número que es función de una constante, escrito a mano en
//! prosa.** El compilador no lo ve porque la prosa no compila, y los tests no lo ven porque prueban
//! el código, no lo que el código dice de sí mismo.
//!
//! Los arreglos puntuales —derivar el offset, poner un test por módulo— no cierran el patrón: solo
//! cierran la instancia. Esto sí lo cierra: **lee `SPEC.md` y comprueba que las cifras que afirma
//! coinciden con las constantes reales.**
//!
//! # Cómo añadir una entrada
//!
//! Cuando el SPEC diga un número derivado de una constante, añádelo aquí. Cuesta una línea, y es la
//! diferencia entre que el próximo cambio de constante lo cace un test o lo cace un auditor tres
//! semanas después.
//!
//! # Lo que este test NO puede hacer
//!
//! No entiende el SPEC: comprueba que **una cadena concreta aparece**. Si alguien reescribe la
//! frase, el test falla aunque el número siga bien — y eso es deliberado. Una frase reescrita
//! merece que alguien vuelva a mirar si el número sigue cuadrando.

use zx_consensus::emision::COINBASE_MATURITY;
use zx_consensus::fork_choice::MAX_REORG_LENGTH;
use zx_consensus::peso::{N_LARGO, ZONA_LIBRE};
use zx_core::preimage::block::TAMANO_CABECERA;

/// El SPEC, incrustado en el binario de test.
const SPEC: &str = include_str!("../../../SPEC.md");

/// El SPEC **sin sus citas**: solo lo que afirma, no lo que recuerda.
///
/// Este SPEC documenta sus propios errores en notas citadas (`> ⚠️ Corregido…`), y esa memoria es
/// deliberada: es lo que impide que alguien "arregle" una regla devolviéndola al valor que ya falló.
/// Pero significa que las cifras equivocadas **aparecen en el archivo a propósito**. Las
/// comprobaciones negativas —"esto no debe volver a decirse"— miran solo el texto normativo; las
/// positivas miran el archivo entero.
fn normativo() -> String {
    SPEC.lines()
        .filter(|l| !l.trim_start().starts_with('>'))
        .collect::<Vec<_>>()
        .join("\n")
}

/// Comprueba que una cifra ya corregida no ha vuelto al texto normativo.
fn no_reaparece(viejo: &[&str], que_paso: &str) {
    let texto = normativo();
    for v in viejo {
        assert!(
            !texto.contains(v),
            "\n\nUna regla del SPEC vuelve a decir «{v}».\n{que_paso}\n\n\
             Si de verdad es el valor correcto ahora, cambia también este test y la constante.\n\
             Si no, es una regresión: alguien reescribió la regla con el número que ya falló una vez.\n"
        );
    }
}

/// Comprueba que el SPEC contiene una afirmación, y explica qué hacer si no.
///
/// C-SPEC-01 · toda cifra derivada que el SPEC afirme pasa por aquí o por una comprobación que la
/// recalcule. Añadir una al documento sin añadir su test es una violación de la regla.
/// Para cifras que el SPEC **no debe** fijar en texto normativo porque son **instancias
/// derivadas**, no constantes. Ejemplo: `MAX_RESPUESTA_BYTES` vale 25,6 MB en el génesis, pero
/// C-NET-13 exige que se derive de `LIMITE(H)` y **prohíbe** que sea constante — escribirla como
/// regla contradiría la regla. Su sitio legítimo es una nota ilustrativa.
///
/// Se sigue comprobando que la cifra esté y cuadre; lo que cambia es dónde se admite que viva.
fn afirma_ilustrativa(fragmento: &str, porque: &str) {
    assert!(
        SPEC.contains(fragmento),
        "\n\nEl SPEC ya no ilustra «{fragmento}» en ningún sitio.\n\
         Motivo por el que debería: {porque}\n\n\
         Es una cifra DERIVADA: su sitio es una nota, no una regla. Pero si desaparece del todo, \
         nadie puede comprobar a ojo que la derivación da lo que dice que da.\n"
    );
}

/// ⚠️ Mira **solo texto normativo**: las citas en bloque (`>`) son narrativa histórica y el SPEC
/// cuenta a propósito sus propios errores pasados. Antes miraba el SPEC entero, y por eso el
/// 2026-09-05 la aserción de «92 bytes» siguió en verde después de que §6.1 pasara a 556: tres
/// menciones viejas —dos de ellas en notas— la sostenían. Es el fallo que este fichero existe para
/// impedir, cometido por el propio fichero.
fn afirma(fragmento: &str, porque: &str) {
    assert!(
        normativo().contains(fragmento),
        "\n\nEl SPEC ya no dice «{fragmento}».\n\
         Motivo por el que debería: {porque}\n\n\
         Si has cambiado una CONSTANTE, el SPEC se quedó atrás: actualízalo.\n\
         Si has reescrito la FRASE, actualiza este test — y de paso comprueba que el número sigue \
         cuadrando, que es justo lo que se escapó las tres veces anteriores.\n"
    );
}

/// **El tamaño de cabecera.** Estuvo mal en seis sitios como 112.
#[test]
fn el_spec_dice_el_tamano_real_de_la_cabecera() {
    // ⚠️ MIGRACIÓN EN CURSO (2026-09-05). El SPEC §6.1 ya describe la cabecera de PoAS: 556 B.
    // `zx-core` sigue en los 92 B de PoW. Este test es ROJO A PROPÓSITO hasta que se reescriba
    // `crates/zx-core/src/preimage/block.rs`. Es spec-first funcionando: el SPEC va delante y este
    // test es lo que obliga al código a alcanzarlo. Ver DECISIONES.md §22.
    assert_eq!(
        TAMANO_CABECERA, 556,
        "SPEC §6.1 dice 556 B (112 base + 380 solución + 64 sello). El código sigue en 92, que era \
         la cabecera de PoW. Reescribe zx-core/src/preimage/block.rs."
    );
    afirma(
        "**556**",
        "TAMANO_CABECERA = 112 + 380 + 64, derivado de la tabla de campos de §6.1.",
    );
    no_reaparece(
        &["112 bytes", "cabecera(112"],
        "El 112 estuvo en tres sitios del SPEC y tres del código, y ninguno lo derivaba de la \
         constante. Ojo: 112 vuelve a aparecer en §6.1, pero como el tamaño de la BASE de la \
         cabecera, no de la cabecera entera.",
    );
}

#[test]
fn el_spec_ya_no_habla_de_nonce_ni_de_pow() {
    // Bajo PoAS no hay nonce que iterar ni preimagen de PoW. H-005 —el offset del nonce escrito a
    // mano en vez de derivado— deja de estar en el camino crítico, pero la lección se conserva:
    // por eso este fichero existe.
    no_reaparece(
        &["OFFSET_NONCE", "preimagen del PoW", "el minero GPU"],
        "PoW se retiró el 2026-09-05 (DECISIONES.md §14). Si esto reaparece en texto normativo, \
         alguien está escribiendo reglas de un consenso que ya no existe.",
    );
}

#[test]
fn el_spec_dice_las_cifras_reales_del_transporte() {
    // Se recalculan desde las constantes de consenso, sin depender de zx-p2p —que este crate no
    // ve— pero con la misma aritmética que él usa.
    let limite_bloque_genesis = 2 * ZONA_LIBRE; // C-WGT-09: LIMITE(0) = 2·M(0)
    let gossip = limite_bloque_genesis * 8; // FACTOR_MARGEN
    let respuesta = gossip * 16;
    let peor_caso = respuesta * 8 * 72; // MAX_STREAMS_SYNC × MAX_PEERS_ENTRANTES

    assert_eq!(respuesta, 25_600_000, "25,6 MB");
    assert!(
        (14_000_000_000..15_000_000_000).contains(&peor_caso),
        "el peor caso son ~14,7 GB, no los 7,2 que el SPEC llegó a decir: {peor_caso}"
    );

    afirma_ilustrativa(
        "25,6 MB",
        "MAX_RESPUESTA_BYTES real. El SPEC llegó a decir 12,8 porque C-NET-13 dobló la constante \
         de la que sale y la prosa se quedó atrás.",
    );
    afirma_ilustrativa("14,7 GB", "el peor caso agregado real, que motivó C-NET-21");
    no_reaparece(
        &["7,2 GB"],
        "C-NET-13 dobló MAX_GOSSIP_BYTES, así que el peor caso agregado pasó de 7,2 a 14,7 GB.",
    );
}

/// **Cada regla numerada del SPEC es única.**
///
/// Dos reglas con el mismo número serían dos cosas distintas citadas igual, y una cita ambigua es
/// peor que ninguna: el código diría cumplir una y cumpliría la otra.
/// **La profundidad máxima de reorg** y su relación con la madurez de coinbase.
#[test]
fn el_spec_dice_la_profundidad_real_de_reorg() {
    assert_eq!(MAX_REORG_LENGTH, COINBASE_MATURITY - 1);
    assert_eq!(MAX_REORG_LENGTH, 11_999);

    afirma(
        "MAX_REORG_LENGTH = COINBASE_MATURITY − 1 = 11 999 bloques",
        "la relación entre las dos constantes, no solo el número: si cambia la madurez, cambia esto",
    );
}

/// **La zona libre y la ventana larga**, que alimentan medio SPEC.
#[test]
fn el_spec_dice_los_parametros_reales_de_peso() {
    assert_eq!(ZONA_LIBRE, 100_000);
    assert_eq!(N_LARGO, 21_600, "6 h a λ = 1 bloque/s");

    // 21 600 × 1 s = 6 h exactas.
    assert_eq!(N_LARGO as u64, 6 * 60 * 60);

    afirma("21 600", "N_LARGO, la ventana de capacidad");
    afirma(
        "ZONA_LIBRE    = 100 000",
        "es constante de consenso: va en texto normativo, no en una nota",
    );
    afirma_ilustrativa(
        "100 KB",
        "la forma legible de ZONA_LIBRE, para leer el SPEC sin calculadora",
    );
}

/// El checkpoint firmado (SPEC §12.1, DECISIONES.md §25).
///
/// ⚠️ Este test existe por un fallo del 2026-09-05: `UMBRAL_CHECKPOINT` se escribió mil veces bajo
/// —«3,2 PiB» etiquetando 3,277 TiB— y **ningún guardián lo cazó, porque la constante estaba solo
/// en `DECISIONES.md` y este fichero lee `SPEC.md`**. La lección no es el factor 1000: es que una
/// constante de consenso escrita fuera del SPEC está donde la defensa no mira.
///
/// Así que aquí no se comprueba solo que el número esté: se comprueba que **la etiqueta en petabytes
/// no pueda volver a mentir**, rederivando el espacio desde el rango.
#[test]
#[expect(
    clippy::integer_division,
    reason = "rederiva pieces_to_solution_range con el truncamiento entero de solutions.rs:30-40"
)]
fn el_umbral_del_checkpoint_dice_el_espacio_que_dice() {
    const UMBRAL: u64 = 90_185_365;
    const CADUCIDAD: u64 = 63_072_000;

    // pieces_to_solution_range invertida, con el orden EXACTO de solutions.rs:30-40.
    // Se rederiva aquí en vez de importarse: si alguien cambia la fórmula, este test debe romperse.
    let base = ((u64::MAX / 120) / (1 << 15)) * (1 << 16);
    let piezas = base / UMBRAL;
    let sectores = piezas / 1000; // MAX_PIECES_IN_SECTOR
    // Un sector mide 1007,90 MiB (research/coste-ploteo-medido.md). En MiB para no perder precisión.
    let mib = sectores * 100_790 / 100;
    let pib = mib as f64 / 1024.0 / 1024.0 / 1024.0;

    assert!(
        (3.15..3.25).contains(&pib),
        "UMBRAL_CHECKPOINT dice ser 3,2 PiB y son {pib:.4} PiB. Si esto falla por un factor 1000, \
         alguien ha vuelto a confundir piezas con sectores: un sector son 1000 piezas."
    );

    // Y que esté por ENCIMA del cruce de 10,3 TiB, que es lo que hace que el ancla sirva de algo.
    let tib = mib as f64 / 1024.0 / 1024.0;
    assert!(
        tib > 10.3,
        "el umbral ({tib:.1} TiB) está por debajo del cruce de 10,3 TiB: se emitiría el checkpoint \
         donde forjar todavía cuesta menos que verificar, que es justo lo que §25 descartó."
    );

    assert_eq!(
        CADUCIDAD,
        2 * 365 * 24 * 60 * 60,
        "63 072 000 bloques son dos años exactos a λ = 1 bloque/s (eran 525 600 a T = 120 s)"
    );

    afirma("90 185 365", "UMBRAL_CHECKPOINT, SPEC §12.1");
    afirma(
        "63 072 000",
        "ALTURA_CADUCIDAD, SPEC §12.1 — literal, NO 2·N_LARGO",
    );
    no_reaparece(
        &["90 185 375 997", "2 · N_LARGO"],
        "el umbral estuvo mil veces bajo y la caducidad colgaba de N_LARGO, que un network \
         upgrade puede cambiar (SPEC:1926). Los dos corregidos el 2026-09-06.",
    );
}

#[test]
fn ninguna_regla_esta_numerada_dos_veces() {
    let mut vistas: Vec<&str> = Vec::new();
    let mut repetidas: Vec<&str> = Vec::new();

    for linea in SPEC.lines() {
        let Some(resto) = linea.strip_prefix("**C-") else {
            continue;
        };
        let Some(fin) = resto.find(|c: char| !c.is_ascii_alphanumeric() && c != '-') else {
            continue;
        };
        let id = resto.get(..fin).unwrap_or_default();
        if vistas.contains(&id) {
            repetidas.push(id);
        } else {
            vistas.push(id);
        }
    }

    assert!(
        repetidas.is_empty(),
        "reglas numeradas más de una vez: {repetidas:?}"
    );
    assert!(
        vistas.len() > 140,
        "solo se encontraron {} reglas",
        vistas.len()
    );
}
