//! Pruebas de integración del bootstrap aislado del génesis DAG de desarrollo (incremento C3).
//!
//! # Qué prueba y qué no
//!
//! Comprueba que [`iniciar_bootstrap_dag_dev`] reproduce el hash **congelado** del fixture dev y
//! que el bloque se reserializa sin cola; que una mutación de `pot_output` o del hash esperado se
//! rechaza con motivo tipado; que la coinbase del génesis es de valor cero, sin entradas y sin
//! testigos; que `f_0`, el ancla confiada del slot 0 y el retardo dev coinciden con **vectores
//! congelados independientes**; y que el binario `zx-dag-dev` arranca e imprime su alcance acotado
//! mientras rechaza argumentos de red.
//!
//! La **ausencia de un UTXO activo** no la comprueba este archivo: el bootstrap no inserta nada,
//! pero verificar que no queda un UTXO sigue **pendiente de integración**.
//!
//! **No** verifica PoT, PoAS ni sello: el fixture no es una admisión PoST ni un génesis de red.
//! El hash y los vectores se congelan como literales en este archivo; los `assert` no los
//! recalcular del candidato bajo prueba (eso sería una tautología).

#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    reason = "los tests fallan con panic por diseño; índices sobre arrays de anchura fija"
)]

use zx_consensus::genesis_dag::{
    ErrorGenesisDagDev, ParametrosGenesisDagDev, comprobar_estructura_y_hash_dag_dev,
    construir_dag_dev,
};
use zx_core::{
    Amount, BlockHash, Digest, SolucionPoas, bloque_dag_a_bytes, bloque_dag_desde_bytes,
};
use zx_node::bootstrap_dag_dev::iniciar_bootstrap_dag_dev;

// ── Vectores congelados · literales independientes de la llamada bajo prueba ─────────────────

/// `block_hash` congelado del fixture dev (el mismo literal que fija el perfil de producción del
/// bootstrap). No se recalcula del bloque.
const HASH_DEV: [u8; 32] = [
    4, 0, 228, 160, 3, 45, 150, 243, 155, 108, 165, 251, 38, 47, 168, 55, 66, 41, 232, 57, 230, 84,
    144, 102, 6, 224, 105, 216, 129, 184, 225, 127,
];

/// `pot_output(G)` congelado del fixture dev: es el ancla confiada del slot 0.
const POT_DEV: [u8; 16] = [
    0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xF0, 0x0F,
];

/// `f_0` del hash dev, calculado **fuera** de la función bajo prueba:
///
/// ```text
/// printf 'ZZKFlowId_______ZZKFlowGenesis__' > f0.bin
/// printf '\x04\x00\xe4\xa0\x03\x2d\x96\xf3\x9b\x6c\xa5\xfb\x26\x2f\xa8\x37' >> f0.bin
/// printf '\x42\x29\xe8\x39\xe6\x54\x90\x66\x06\xe0\x69\xd8\x81\xb8\xe1\x7f' >> f0.bin
/// openssl dgst -sha3-256 f0.bin
///   -> 50f0364c87a1a61b27c6fc1b1a10749e13916a8deffa229e900af731360359af
/// ```
const F0_DEV: [u8; 32] = [
    0x50, 0xF0, 0x36, 0x4C, 0x87, 0xA1, 0xA6, 0x1B, 0x27, 0xC6, 0xFC, 0x1B, 0x1A, 0x10, 0x74, 0x9E,
    0x13, 0x91, 0x6A, 0x8D, 0xEF, 0xFA, 0x22, 0x9E, 0x90, 0x0A, 0xF7, 0x31, 0x36, 0x03, 0x59, 0xAF,
];

/// Perfil de prueba **ajeno** al fixture dev: sirve para comprobar que la comprobación discrimina
/// mutaciones sin exponer ninguna API pública para inyectar perfiles en producción.
fn parametros_de_prueba(hash_esperado: BlockHash) -> ParametrosGenesisDagDev<'static> {
    ParametrosGenesisDagDev {
        mensaje_marca_dev: b"perfil de prueba del bootstrap dev",
        timestamp: zx_consensus::genesis::TIMESTAMP_MINIMO_GENESIS,
        consensus_branch_id: 0x0D06_0002,
        pot_output: [0x77; 16],
        rango_solucion: 0x1234,
        solucion: SolucionPoas::default(),
        sello: [0x11; 64],
        hash_esperado,
    }
}

// ── 1 · Hash congelado y reserialización sin cola ────────────────────────────────────────────

#[test]
fn el_hash_dev_congelado_cuadra_y_el_bloque_se_reserializa_sin_cola() {
    let estado = iniciar_bootstrap_dag_dev().expect("el bootstrap dev MUST arrancar");
    assert_eq!(
        estado.hash_congelado_dev().as_bytes(),
        &HASH_DEV,
        "el hash del estado MUST ser el literal congelado, no uno recalculado"
    );

    let mut bytes = Vec::new();
    bloque_dag_a_bytes(&mut bytes, estado.bloque_dev());
    let (leido, resto) = bloque_dag_desde_bytes(&bytes).expect("el bloque dev MUST decodificar");
    assert!(resto.is_empty(), "el códec no debe dejar cola");
    assert_eq!(
        &leido,
        estado.bloque_dev(),
        "ida y vuelta exacta del bloque dev"
    );
    assert_eq!(leido.cabecera.a_bytes().len(), 589, "P = 1, génesis");
    assert!(
        leido.justificacion.is_empty(),
        "justificación count = 0 canónico"
    );
}

// ── 2 · Mutaciones con motivo tipado, sin API pública de inyección ───────────────────────────

#[test]
fn mutar_pot_output_o_hash_esperado_se_rechaza_con_motivo() {
    let mut p = parametros_de_prueba(BlockHash::from_digest(Digest::from_bytes([0; 32])));
    let base = construir_dag_dev(&p).expect("el perfil de prueba MUST construirse");
    // El perfil se queda con el hash real solo para aislar la comprobación que probamos; la
    // prueba del hash congelado es la del test 1.
    p.hash_esperado = base.cabecera.block_hash();
    assert!(
        comprobar_estructura_y_hash_dag_dev(&base, &p).is_ok(),
        "el perfil de prueba MUST ser coherente antes de mutarlo"
    );

    // Mutar el `pot_output` del bloque: `CampoNoCoincide`, antes del hash.
    let mut m = base.clone();
    m.cabecera.pot_output[0] ^= 1;
    assert!(matches!(
        comprobar_estructura_y_hash_dag_dev(&m, &p),
        Err(ErrorGenesisDagDev::CampoNoCoincide {
            campo: "pot_output"
        })
    ));

    // Mutar el hash esperado: `HashNoCoincide`, el último cerrojo.
    let mut p_malo = p;
    p_malo.hash_esperado = BlockHash::from_digest(Digest::from_bytes([0xFF; 32]));
    assert!(matches!(
        comprobar_estructura_y_hash_dag_dev(&base, &p_malo),
        Err(ErrorGenesisDagDev::HashNoCoincide { .. })
    ));
}

// ── 3 · Coinbase de valor cero, sin entradas y sin testigos ─────────────────────────────────

#[test]
fn la_coinbase_del_genesis_dev_es_cero_sin_entradas_ni_testigos() {
    let estado = iniciar_bootstrap_dag_dev().expect("el bootstrap dev MUST arrancar");
    let bloque = estado.bloque_dev();
    assert_eq!(bloque.txs().len(), 1, "una sola tx: la coinbase");
    let coinbase = bloque.txs().first().expect("una sola tx: la coinbase");
    assert!(coinbase.inputs.is_empty(), "C-BLK-07: sin entradas");
    assert_eq!(coinbase.expiry_height, 0, "C-EMIT-04: expiry_height = 0");
    let total = Amount::suma(coinbase.outputs.iter().map(|o| o.value))
        .expect("la suma de salidas MUST estar en rango");
    assert_eq!(total, Amount::CERO, "C-GEN-03: Σ value(salidas) = 0");
    let testigo = bloque
        .testigos()
        .first()
        .expect("una lista de testigos por tx");
    assert!(
        testigo.is_empty(),
        "el testigo de la coinbase es la lista vacía"
    );
    assert!(
        bloque.justificacion.is_empty(),
        "C-HDR-07: el génesis lleva justificación PoT vacía"
    );
    // Este bootstrap no inserta nada ni expone método para aplicar UTXO; comprobar que no queda un
    // UTXO activo sigue pendiente de integración y este test no lo afirma.
}

// ── 4 · `f_0` y ancla del slot 0 contra vectores congelados ──────────────────────────────────

#[test]
fn el_f0_y_el_ancla_del_slot_0_coinciden_con_vectores_congelados() {
    let estado = iniciar_bootstrap_dag_dev().expect("el bootstrap dev MUST arrancar");
    assert_eq!(estado.f0_dev(), F0_DEV, "f_0 MUST ser el vector OpenSSL");
    assert_eq!(
        estado.ancla_pot_slot_0_dev(),
        POT_DEV,
        "el ancla confiada del slot 0 MUST ser el pot_output del fixture"
    );
    assert_eq!(
        estado.bloque_dev().cabecera.pot_output,
        POT_DEV,
        "el campo pot_output de la cabecera dev MUST ser el literal"
    );
    assert_eq!(
        estado.retardo_pot_dev(),
        0,
        "D_dev = 0 es una cifra elegida solo para desarrollo, no una norma de consenso"
    );
    // No se compara `f_0` con `flujo_genesis` otra vez: sería la misma función dos veces.
}

// ── 5 · El binario arranca e imprime el alcance; rechaza argumentos de red ───────────────────

#[test]
fn el_binario_arranca_e_imprime_su_alcance_y_rechaza_argumentos_de_red() {
    let exe = env!("CARGO_BIN_EXE_zx-dag-dev");

    let salida = std::process::Command::new(exe)
        .output()
        .expect("el binario dev MUST ejecutarse");
    assert!(
        salida.status.success(),
        "sin argumentos MUST salir con éxito"
    );
    let texto = String::from_utf8_lossy(&salida.stdout);
    assert!(
        texto.contains("solo bootstrap local; sin red, persistencia ni admisión PoST"),
        "el aviso acotado MUST estar: {texto}"
    );
    let hash_hex: String = HASH_DEV.iter().map(|b| format!("{b:02x}")).collect();
    assert!(
        texto.contains(&hash_hex),
        "el hash dev MUST mostrarse: {texto}"
    );

    for arg in ["--red", "--peer", "--datos"] {
        let salida = std::process::Command::new(exe)
            .arg(arg)
            .arg("x")
            .output()
            .expect("el binario dev MUST ejecutarse");
        assert!(
            !salida.status.success(),
            "el argumento {arg} MUST rechazarse sin ejecutar el bootstrap"
        );
    }
}

/// El perfil dev no toca la ruta lineal: el génesis de testnet sigue arrancando y congelado.
#[test]
fn el_genesis_lineal_de_testnet_conserva_sus_pruebas() {
    use zx_consensus::genesis::{GENESIS_TESTNET, HASH_GENESIS_TESTNET, comprobar_al_arrancar};
    let h = comprobar_al_arrancar(GENESIS_TESTNET).expect("testnet MUST arrancar");
    assert_eq!(h.as_bytes(), &HASH_GENESIS_TESTNET);
}
