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
//! | Tamaño de cabecera | valores repetidos a mano | tabla de campos | faltaba derivar el tamaño |
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
use zx_core::preimage::dag::{
    MAX_PADRES, OFFSET_COMPROMISO_CUERPO, OFFSET_PADRES_EXTRA, OFFSET_PARENT_COUNT,
    TAMANO_CABECERA_MAX, TAMANO_CABECERA_MIN, TAMANO_PREFIJO_FIJO, tamano_cabecera,
};
use zx_core::wire_dag::{
    BUNDLE_BYTES, CHECKPOINTS_POR_BUNDLE, MAX_BLOQUE_DAG_AGREGADO, MAX_BUNDLES_POT,
    MAX_JUSTIFICACION_POT_CODIFICADA, MAX_JUSTIFICACION_POT_PAYLOAD, POT_OUTPUT_BYTES,
};

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

/// Formatea un entero con espacio como separador de millares, igual que lo escribe el SPEC.
///
/// Existe para que las cadenas que se buscan en el SPEC se **construyan** desde la constante y
/// no se transcriban a mano: `afirma(&format!("{} B", miles(MAX_...)))` falla si la constante
/// cambia, aunque el literal escrito a mano siguiera diciendo el valor viejo.
fn miles(n: usize) -> String {
    let s = n.to_string();
    let mut salida = String::with_capacity(s.len() + s.len().div_ceil(3));
    for (i, c) in s.chars().enumerate() {
        if i > 0 && (s.len() - i).is_multiple_of(3) {
            salida.push(' ');
        }
        salida.push(c);
    }
    salida
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
///
/// El guardián del SPEC y el del código viven en tests separados: que el SPEC conserve la base
/// PoAS de 556 B es un hecho del presente (verde), y que el código la alcance es una deuda
/// futura (ignorado, `TAREAS.md` §1.4). Juntos, un rojo crónico dejaría de leerse.
#[test]
fn el_spec_conserva_la_base_poas_de_556() {
    afirma(
        "**556**",
        "Base PoAS lineal = 112 + 380 + 64; no es certificación del formato DAG final.",
    );
    no_reaparece(
        &["112 bytes", "cabecera(112"],
        "El 112 estuvo en tres sitios del SPEC y tres del código, y ninguno lo derivaba de la \
         constante. Ojo: 112 vuelve a aparecer en §6.1, pero como el tamaño de la BASE de la \
         cabecera, no de la cabecera entera.",
    );
}

#[test]
#[ignore = "TAREAS.md §1.4 (SPEC cerrado, falta cablear): el código conserva la cabecera lineal de 92 B; el formato DAG ya está especificado en SPEC §6.1–§6.2 (589/1 037 B, codec único) y 556 B es la base LINEAL, no el destino. Quitar este ignore cuando la cabecera DAG se cablee en la ruta activa."]
fn el_codigo_alcanza_la_base_poas_de_556() {
    // MIGRACIÓN PENDIENTE: 556 B describe la base PoAS lineal, no la cabecera DAG final.
    // El guardián exige que el código alcance esa base y permanece rojo mientras conserve
    // el formato anterior. No certifica padres múltiples ni consenso DAG por pasar.
    assert_eq!(
        TAMANO_CABECERA, 556,
        "SPEC §6.1 conserva la base PoAS lineal de 556 B (112 + 380 + 64). El código todavía \
         no implementa esa base; el formato DAG está especificado (SPEC §6.1–§6.2) y falta \
         cablearlo."
    );
}

#[test]
fn el_spec_ya_no_habla_de_nonce_ni_de_pow() {
    // Bajo PoAS no hay nonce que iterar ni preimagen de PoW. H-005 —el offset del nonce escrito a
    // mano en vez de derivado— deja de estar en el camino crítico, pero la lección se conserva:
    // por eso este fichero existe.
    no_reaparece(
        &["OFFSET_NONCE", "preimagen del PoW", "el minero GPU"],
        "El destino es PoSpace-Time + DAG (MIGRACION.md). Si esto reaparece en texto normativo, \
         se están reintroduciendo reglas del consenso retirado.",
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
fn el_spec_identifica_el_limite_transitorio_de_reorg() {
    assert_eq!(MAX_REORG_LENGTH, COINBASE_MATURITY - 1);
    assert_eq!(MAX_REORG_LENGTH, 11_999);

    afirma(
        "MAX_REORG_LENGTH = COINBASE_MATURITY − 1 = 11 999 bloques",
        "límite transitorio del código, expresamente pendiente de sustituir al integrar R-FIN-7",
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

/// Las constantes nominales de bootstrap se conservan sin certificar su calibración DAG.
/// La antigua conversión rango→espacio dividía por 120 y no es válida como evidencia para A″.
#[test]
fn el_checkpoint_conserva_constantes_y_declara_calibracion_pendiente() {
    afirma(
        "UMBRAL_CHECKPOINT  = 90 185 365",
        "constante nominal conservada; no se ha autorizado recalibrar el bootstrap",
    );
    afirma(
        "ALTURA_CADUCIDAD   = 63 072 000",
        "constante nominal conservada; altura y calendario DAG pendientes",
    );
    afirma(
        "equivalencia de espacio DAG pendiente",
        "la conversión antigua por 120 no certifica espacio en PoST/DAG",
    );
    no_reaparece(
        &["90 185 375 997", "2 · N_LARGO", "equivale a 3,2 PiB"],
        "no reintroducir el umbral erróneo, un calendario dependiente de capacidad, ni una \
         equivalencia de espacio sin recalibrar",
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
    // Comprobar áreas comunes concretas no obliga a conservar reglas de un consenso retirado.
    for requerida in [
        "ENC-01", "HASH-01", "HDR-01", "BLK-01", "SPEC-01", "SPEC-02", "SPEC-03",
    ] {
        assert!(
            vistas.contains(&requerida),
            "falta la regla común C-{requerida}"
        );
    }
}

/// **Los offsets de la cabecera DAG** (S-03, §6.1). Cada cifra se deriva de la constante.
///
/// Grupo de mutación: el offset se mueve si cambia `TAMANO_COMPROMISO_CUERPO` (32, primitivo) o
/// el prefijo; la cadena del SPEC deja de aparecer.
#[test]
fn el_spec_dice_los_offsets_de_la_cabecera_dag() {
    // Relaciones entre constantes, no entre literales.
    assert_eq!(
        OFFSET_COMPROMISO_CUERPO, TAMANO_PREFIJO_FIJO,
        "S-03: OFFSET_COMPROMISO_CUERPO debe ser TAMANO_PREFIJO_FIJO"
    );
    assert_eq!(
        OFFSET_PARENT_COUNT,
        OFFSET_COMPROMISO_CUERPO + 32,
        "S-03: OFFSET_PARENT_COUNT = OFFSET_COMPROMISO_CUERPO + 32 (32 = ancho de hash)"
    );
    assert_eq!(
        OFFSET_PADRES_EXTRA,
        OFFSET_PARENT_COUNT + 1,
        "S-03: OFFSET_PADRES_EXTRA = OFFSET_PARENT_COUNT + 1 (byte parent_count)"
    );

    afirma(
        &format!("header_encoding[0, {})", miles(TAMANO_PREFIJO_FIJO)),
        "C-HDR-03: la prefirma lineal son los bytes anteriores al sello",
    );
    afirma(
        &format!(
            "body_commitment [{}, {})",
            miles(OFFSET_COMPROMISO_CUERPO),
            miles(OFFSET_PARENT_COUNT)
        ),
        "S-03: el compromiso del cuerpo ocupa [492, 524)",
    );
    afirma(
        &format!(
            "parent_count [{}, {})",
            miles(OFFSET_PARENT_COUNT),
            miles(OFFSET_PADRES_EXTRA)
        ),
        "S-03: parent_count es el byte [524, 525)",
    );
    afirma(
        &format!(
            "extra_parents [{}, {}",
            miles(OFFSET_PADRES_EXTRA),
            miles(OFFSET_PADRES_EXTRA)
        ),
        "S-03: los padres adicionales empiezan en 525",
    );
}

/// **Los tamaños de la cabecera DAG** (S-03 y C-HDR-09, §6.1–§6.2).
///
/// Grupo de mutación: `MAX_PADRES`.
#[test]
fn el_spec_dice_los_tamanos_de_la_cabecera_dag() {
    // Relaciones, incluida la del SPEC: `MAX = MIN + 32·(MAX_PADRES − 1)`.
    assert_eq!(
        TAMANO_CABECERA_MIN,
        OFFSET_PADRES_EXTRA + 64,
        "S-03: TAMANO_CABECERA_MIN = OFFSET_PADRES_EXTRA + 64 (sello Ed25519)"
    );
    assert_eq!(
        tamano_cabecera(1),
        TAMANO_CABECERA_MIN,
        "S-03: tamano_cabecera(1) es la cabecera mínima"
    );
    assert_eq!(
        tamano_cabecera(2),
        TAMANO_CABECERA_MIN + 32,
        "S-03: dos padres añaden un prev_hash de 32 B"
    );
    assert_eq!(
        tamano_cabecera(MAX_PADRES as u8),
        TAMANO_CABECERA_MAX,
        "S-03: tamano_cabecera(MAX_PADRES) es la cabecera máxima"
    );
    assert_eq!(
        TAMANO_CABECERA_MAX,
        TAMANO_CABECERA_MIN + 32 * (MAX_PADRES - 1),
        "S-03: MAX = MIN + 32·(MAX_PADRES − 1)"
    );

    afirma(
        &format!("normal(P) = {} + 32·(P−1)", miles(TAMANO_CABECERA_MIN)),
        "S-03: fórmula del tamaño de cabecera con P padres",
    );
    afirma(
        &format!("1 ≤ P ≤ {}", MAX_PADRES),
        "R-FIN-12: máximo de padres de la cabecera",
    );
    afirma(
        &format!("P=1` mide **{} B**", miles(TAMANO_CABECERA_MIN)),
        "S-03: la cabecera mínima (P=1) mide 589 B",
    );
    afirma(
        &format!("P=2` **{} B**", miles(tamano_cabecera(2))),
        "S-03: la cabecera con dos padres mide 621 B",
    );
    afirma(
        &format!("P=15` **{} B**", miles(TAMANO_CABECERA_MAX)),
        "S-03: la cabecera máxima mide 1 037 B",
    );
    afirma(
        &format!("**{}**", miles(TAMANO_CABECERA_MIN)),
        "C-HDR-09: tamaño mínimo de la cabecera DAG",
    );
    afirma(
        &format!("**{}**", miles(TAMANO_CABECERA_MAX)),
        "C-HDR-09: tamaño máximo de la cabecera DAG",
    );
    afirma(
        &format!("más de {} padres", MAX_PADRES),
        "C-GD-04/R-FIN-12: tope de padres en §11",
    );
}

/// **Los máximos de la justificación PoT y del agregado** (S-08, C-HDR-07, §6.1–§6.2).
///
/// Grupo de mutación: `MAX_BUNDLES_POT` (la del ejemplo del encargo, 150 → 149).
#[test]
fn el_spec_dice_los_maximos_de_la_justificacion_pot() {
    // Relaciones: la que importa es `codificada == 1 + payload`, donde nació H-07.
    assert_eq!(
        BUNDLE_BYTES,
        CHECKPOINTS_POR_BUNDLE * POT_OUTPUT_BYTES,
        "C-HDR-07: BUNDLE_BYTES = CHECKPOINTS_POR_BUNDLE · POT_OUTPUT_BYTES"
    );
    assert_eq!(
        MAX_JUSTIFICACION_POT_PAYLOAD,
        MAX_BUNDLES_POT * BUNDLE_BYTES,
        "S-08: payload = MAX_BUNDLES_POT · BUNDLE_BYTES (150 · 128)"
    );
    assert_eq!(
        MAX_JUSTIFICACION_POT_CODIFICADA,
        1 + MAX_JUSTIFICACION_POT_PAYLOAD,
        "S-08: codificada = 1 + payload (el byte de pot_bundle_count; el error de H-07)"
    );
    assert_eq!(
        MAX_BLOQUE_DAG_AGREGADO,
        TAMANO_CABECERA_MAX + MAX_JUSTIFICACION_POT_CODIFICADA,
        "S-08: agregado = TAMANO_CABECERA_MAX + justificación codificada"
    );

    afirma(
        &format!(
            "{} B cada uno: {} PotOutput de {} B",
            miles(BUNDLE_BYTES),
            CHECKPOINTS_POR_BUNDLE,
            POT_OUTPUT_BYTES
        ),
        "C-HDR-07: tamaño de cada portador PoT",
    );
    afirma(
        &format!("0 ≤ pot_bundle_count ≤ {}", MAX_BUNDLES_POT),
        "C-HDR-07: cota del número de portadores",
    );
    afirma(
        &format!("= {} B", miles(MAX_JUSTIFICACION_POT_PAYLOAD)),
        "S-08: payload máximo de la justificación (150 × 128)",
    );
    afirma(
        &format!("{} B", miles(MAX_JUSTIFICACION_POT_CODIFICADA)),
        "S-08: justificación codificada; incluye el byte de pot_bundle_count",
    );
    afirma(
        &format!("{} B", miles(MAX_BLOQUE_DAG_AGREGADO)),
        "S-08: máximo agregado de cabecera más justificación",
    );
    // El `1 + payload` que se perdió una ronda entera: se deriva, no se escribe.
    let byte_contador = MAX_JUSTIFICACION_POT_CODIFICADA - MAX_JUSTIFICACION_POT_PAYLOAD;
    afirma(
        &format!(
            "{} + {}",
            byte_contador,
            miles(MAX_JUSTIFICACION_POT_PAYLOAD)
        ),
        "S-08: el byte del contador más el payload",
    );
    afirma(
        &format!(
            "{} + {}",
            miles(TAMANO_CABECERA_MAX),
            miles(MAX_JUSTIFICACION_POT_CODIFICADA)
        ),
        "S-08: cabecera máxima más justificación codificada",
    );
}
