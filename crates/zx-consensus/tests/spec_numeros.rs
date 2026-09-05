//! **El SPEC no puede decir un número que el código contradiga.**
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
use zx_core::preimage::block::{
    OFFSET_NONCE_CABECERA, OFFSET_NONCE_PREIMAGEN, TAMANO_CABECERA, TAMANO_PREIMAGEN_POW,
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
fn afirma(fragmento: &str, porque: &str) {
    assert!(
        SPEC.contains(fragmento),
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
    assert_eq!(
        TAMANO_CABECERA, 92,
        "si esto cambia, el SPEC entero lo dice mal"
    );
    afirma(
        "92 bytes",
        "TAMANO_CABECERA = 4+32+32+8+4+8+4. Decía 112 en tres sitios del SPEC y tres del código.",
    );
    no_reaparece(
        &["112 bytes", "cabecera(112"],
        "TAMANO_CABECERA son 92. El 112 estuvo en tres sitios del SPEC y tres del código, y \
         ninguno lo derivaba de la constante.",
    );
}

/// **El offset del nonce.** Es H-005 literal: quedó obsoleto al cambiar el tipo de `timestamp`.
#[test]
fn el_spec_dice_el_offset_real_del_nonce() {
    assert_eq!(OFFSET_NONCE_CABECERA, 80);
    assert_eq!(OFFSET_NONCE_PREIMAGEN, 96);
    assert_eq!(TAMANO_PREIMAGEN_POW, 108);

    afirma(
        "[96, 104)",
        "OFFSET_NONCE_PREIMAGEN = 96 y el nonce mide 8 bytes. H-005 fue decir [92,100).",
    );
    no_reaparece(
        &["[92, 100)", "[92,100)"],
        "Eso es H-005. El rango [92,100) cubre los últimos 4 bytes de `bits` y solo la mitad del \
         nonce: el minero habría mutado la dificultad mientras minaba.",
    );
}

/// **La profundidad máxima de reorg** y su relación con la madurez de coinbase.
#[test]
fn el_spec_dice_la_profundidad_real_de_reorg() {
    assert_eq!(MAX_REORG_LENGTH, COINBASE_MATURITY - 1);
    assert_eq!(MAX_REORG_LENGTH, 99);

    afirma(
        "MAX_REORG_LENGTH = COINBASE_MATURITY − 1 = 99 bloques",
        "la relación entre las dos constantes, no solo el número: si cambia la madurez, cambia esto",
    );
}

/// **La zona libre y la ventana larga**, que alimentan medio SPEC.
#[test]
fn el_spec_dice_los_parametros_reales_de_peso() {
    assert_eq!(ZONA_LIBRE, 100_000);
    assert_eq!(N_LARGO, 262_800, "un año a 120 s");

    // 262 800 × 120 s = 31 536 000 s = 365 días exactos.
    assert_eq!(N_LARGO as u64 * 120, 365 * 24 * 60 * 60);

    afirma("262 800", "N_LARGO, la ventana de la mediana larga");
    afirma("100 KB", "ZONA_LIBRE = 100 000 unidades de peso");
}

/// **El límite de transporte y el peor caso de memoria.**
///
/// Es la tercera instancia del patrón: `MAX_RESPUESTA_BYTES` se dobló y cuatro comentarios se
/// quedaron atrás. Aquí las cifras se **derivan**, no se copian.
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

    afirma(
        "25,6 MB",
        "MAX_RESPUESTA_BYTES real. El SPEC llegó a decir 12,8 porque C-NET-13 dobló la constante \
         de la que sale y la prosa se quedó atrás.",
    );
    afirma("14,7 GB", "el peor caso agregado real, que motivó C-NET-21");
    no_reaparece(
        &["7,2 GB"],
        "C-NET-13 dobló MAX_GOSSIP_BYTES, así que el peor caso agregado pasó de 7,2 a 14,7 GB.",
    );
}

/// **Cada regla numerada del SPEC es única.**
///
/// Dos reglas con el mismo número serían dos cosas distintas citadas igual, y una cita ambigua es
/// peor que ninguna: el código diría cumplir una y cumpliría la otra.
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
