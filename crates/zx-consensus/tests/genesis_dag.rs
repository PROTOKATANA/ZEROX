//! Pruebas del génesis DAG **solo dev** (`zx-consensus::genesis_dag`, preparación C3).
//!
//! # Qué prueba y qué no
//!
//! Construye un fixture DAG de desarrollo con valores **elegidos para test** y comprueba que la
//! construcción es determinista, que el `block_hash` coincide con un literal **congelado** en este
//! archivo y que cada mutación de un campo, compromiso o lista se rechaza con un motivo tipado.
//! **No** verifica PoT, PoAS ni sello: el fixture no es una admisión PoST ni un génesis de red.
//!
//! El hash literal se obtuvo **una vez** de esta misma construcción y se congeló aquí; los `assert`
//! no lo recalculan del candidato. Eso es lo que convierte la comparación en una prueba y no en una
//! tautología.

#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    reason = "los tests fallan con panic por diseño; índices sobre arrays de anchura fija"
)]

use zx_consensus::genesis::{
    GENESIS_TESTNET, HASH_GENESIS_TESTNET, TIMESTAMP_MINIMO_GENESIS, coinbase_genesis,
    comprobar_al_arrancar,
};
use zx_consensus::genesis_dag::{
    ErrorGenesisDagDev, ParametrosGenesisDagDev, comprobar_estructura_y_hash_dag_dev,
    construir_dag_dev,
};
use zx_core::preimage::block::merkle_root;
use zx_core::{
    Amount, BlockHash, BloqueDag, BodyCommitment, ClavePublica, Digest, EncodingError,
    JustificacionPot, Lock, MerkleRoot, PadresDag, PotCheckpoints, SolucionPoas, TxOut,
    ZX_VALUE_SANITY_LIMIT, bloque_dag_a_bytes, bloque_dag_desde_bytes, body_commitment, txid,
};

// ── Fixture solo dev · valores elegidos para test, sin significado de red ────────────────────

/// Marca del fixture. Es un texto legible en los parámetros, pero en el wire se condensa por XOR.
const MENSAJE: &[u8] = b"ZEROX DAG dev genesis fixture - elegido para test, sin valor";
/// Segundos Unix elegidos para test (posterior a 2026-01-01).
const TIMESTAMP: u64 = 1_800_000_000;
/// Rama de desarrollo arbitraria; no es la rama activa de ninguna red.
const BRANCH: u32 = 0x0D06_0001;
/// Salida PoT del fixture.
const POT: [u8; 16] = [
    0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xF0, 0x0F,
];
/// Rango de solución del fixture.
const SR: u64 = 0x00AB_CDEF;
/// Sello del fixture; no es una firma Ed25519 válida y aquí no se verifica.
const SELLO: [u8; 64] = [0x5A; 64];
/// `block_hash` congelado de este fixture, obtenido una sola vez de la construcción determinista.
const HASH_ESPERADO: [u8; 32] = [
    4, 0, 228, 160, 3, 45, 150, 243, 155, 108, 165, 251, 38, 47, 168, 55, 66, 41, 232, 57, 230, 84,
    144, 102, 6, 224, 105, 216, 129, 184, 225, 127,
];

fn solucion_fixture() -> SolucionPoas {
    SolucionPoas {
        public_key: ClavePublica::desde_bytes([0x21; 32]),
        sector_index: 7,
        history_size: 0x0102_0304_0506_0708,
        piece_offset: 9,
        record_commitment: [0x31; 48],
        record_witness: [0x32; 48],
        chunk: [0x33; 32],
        chunk_witness: [0x34; 48],
        proof_of_space: [0x35; 160],
    }
}

fn hash_esperado() -> BlockHash {
    BlockHash::from_digest(Digest::from_bytes(HASH_ESPERADO))
}

fn parametros() -> ParametrosGenesisDagDev<'static> {
    ParametrosGenesisDagDev {
        mensaje_marca_dev: MENSAJE,
        timestamp: TIMESTAMP,
        consensus_branch_id: BRANCH,
        pot_output: POT,
        rango_solucion: SR,
        solucion: solucion_fixture(),
        sello: SELLO,
        hash_esperado: hash_esperado(),
    }
}

fn exige_error(bloque: &BloqueDag, p: &ParametrosGenesisDagDev<'_>) -> ErrorGenesisDagDev {
    match comprobar_estructura_y_hash_dag_dev(bloque, p) {
        Ok(_) => panic!("el candidato mutado MUST rechazarse"),
        Err(e) => e,
    }
}

// ── Construcción determinista y hash congelado ───────────────────────────────────────────────

#[test]
fn la_construccion_es_determinista_y_el_hash_congelado_cuadra() {
    let p = parametros();
    let a = construir_dag_dev(&p).unwrap();
    let b = construir_dag_dev(&p).unwrap();
    assert_eq!(a, b, "la construcción MUST ser determinista");

    // El literal está congelado arriba: no se deriva en esta llamada.
    assert_eq!(a.cabecera.block_hash().as_bytes(), &HASH_ESPERADO);

    // El testigo es opaco: no se construye ni se lee. Basta con que el comprobador acepte; el
    // hash del candidato ya se cotejó contra el literal fijo de arriba.
    assert!(
        comprobar_estructura_y_hash_dag_dev(&a, &p).is_ok(),
        "el comprobador MUST devolver Ok(_) para el fixture congelado"
    );
}

#[test]
fn cabecera_minima_de_589_bytes_y_roundtrip() {
    let p = parametros();
    let bloque = construir_dag_dev(&p).unwrap();

    assert_eq!(bloque.cabecera.a_bytes().len(), 589, "P = 1, génesis");
    assert!(bloque.justificacion.is_empty(), "count = 0 canónico");
    assert_eq!(bloque.txs().len(), 1, "una sola tx: la coinbase");

    let mut bytes = Vec::new();
    bloque_dag_a_bytes(&mut bytes, &bloque);
    let (leido, resto) = bloque_dag_desde_bytes(&bytes).unwrap();
    assert!(resto.is_empty(), "el códec no debe dejar cola");
    assert_eq!(leido, bloque, "ida y vuelta exacta");
    assert!(leido.justificacion.is_empty());
    assert_eq!(leido.txs().len(), 1);
}

// ── Mutaciones: cada una con su motivo, sin panic ────────────────────────────────────────────

#[test]
fn las_mutaciones_fallan_con_motivo_y_sin_panico() {
    let p = parametros();
    let base = construir_dag_dev(&p).unwrap();

    // timestamp declarado distinto del parámetro.
    let mut m = base.clone();
    m.cabecera.timestamp = TIMESTAMP + 1;
    assert!(matches!(
        exige_error(&m, &p),
        ErrorGenesisDagDev::CampoNoCoincide { campo: "timestamp" }
    ));

    // rama declarada distinta.
    let mut m = base.clone();
    m.cabecera.consensus_branch_id ^= 1;
    assert!(matches!(
        exige_error(&m, &p),
        ErrorGenesisDagDev::CampoNoCoincide {
            campo: "consensus_branch_id"
        }
    ));

    // pot_output mutado.
    let mut m = base.clone();
    m.cabecera.pot_output[0] ^= 1;
    assert!(matches!(
        exige_error(&m, &p),
        ErrorGenesisDagDev::CampoNoCoincide {
            campo: "pot_output"
        }
    ));

    // rango de solución mutado.
    let mut m = base.clone();
    m.cabecera.rango_solucion += 1;
    assert!(matches!(
        exige_error(&m, &p),
        ErrorGenesisDagDev::CampoNoCoincide {
            campo: "rango_solucion"
        }
    ));

    // solución PoAS mutada.
    let mut m = base.clone();
    m.cabecera.sol.chunk[0] ^= 1;
    assert!(matches!(
        exige_error(&m, &p),
        ErrorGenesisDagDev::CampoNoCoincide { campo: "solucion" }
    ));

    // sello mutado.
    let mut m = base.clone();
    m.cabecera.sello[0] ^= 1;
    assert!(matches!(
        exige_error(&m, &p),
        ErrorGenesisDagDev::CampoNoCoincide { campo: "sello" }
    ));

    // altura distinta de cero.
    let mut m = base.clone();
    m.cabecera.height = 1;
    assert!(matches!(
        exige_error(&m, &p),
        ErrorGenesisDagDev::AlturaNoEsCero(1)
    ));

    // slot distinto de cero.
    let mut m = base.clone();
    m.cabecera.slot = 1;
    assert!(matches!(
        exige_error(&m, &p),
        ErrorGenesisDagDev::SlotNoEsCero(1)
    ));

    // padres no vacíos.
    let mut m = base.clone();
    m.cabecera.padres =
        PadresDag::nuevo(BlockHash::from_digest(Digest::from_bytes([1; 32])), &[]).unwrap();
    assert!(matches!(
        exige_error(&m, &p),
        ErrorGenesisDagDev::PadresNoVacios(1)
    ));

    // justificación PoT no vacía.
    let mut m = base.clone();
    m.justificacion = JustificacionPot::nueva(vec![PotCheckpoints::desde_bytes([0; 128])]).unwrap();
    assert!(matches!(
        exige_error(&m, &p),
        ErrorGenesisDagDev::JustificacionNoVacia(1)
    ));

    // merkle_root mutado directamente.
    let mut m = base.clone();
    m.cabecera.merkle_root = MerkleRoot::from_digest(Digest::from_bytes([0xEE; 32]));
    assert!(matches!(
        exige_error(&m, &p),
        ErrorGenesisDagDev::MerkleNoCoincide
    ));

    // body_commitment mutado directamente.
    let mut m = base.clone();
    m.cabecera.body_commitment = BodyCommitment::from_digest(Digest::from_bytes([0xEE; 32]));
    assert!(matches!(
        exige_error(&m, &p),
        ErrorGenesisDagDev::CuerpoNoCoincide
    ));

    // Lista de testigos de la coinbase no vacía.
    let m = BloqueDag::nuevo(
        base.cabecera,
        JustificacionPot::vacia(),
        base.txs().to_vec(),
        vec![vec![vec![1u8; 64]]],
    )
    .unwrap();
    assert!(matches!(
        exige_error(&m, &p),
        ErrorGenesisDagDev::TestigoCoinbaseNoVacio(1)
    ));

    // Coinbase distinta, con compromisos recalculados para aislar el motivo.
    let otra = coinbase_genesis(b"otra marca de coinbase del fixture");
    let mut cab = base.cabecera;
    cab.merkle_root = merkle_root(&[txid(&otra, BRANCH)]);
    cab.body_commitment = body_commitment(core::slice::from_ref(&otra), &[vec![]], BRANCH).unwrap();
    let m = BloqueDag::nuevo(cab, JustificacionPot::vacia(), vec![otra], vec![vec![]]).unwrap();
    assert!(matches!(
        exige_error(&m, &p),
        ErrorGenesisDagDev::CoinbaseNoEsLaDerivada
    ));

    // Hash esperado externo equivocado: es el último cerrojo.
    let mut p_malo = parametros();
    p_malo.hash_esperado = BlockHash::from_digest(Digest::from_bytes([0xFF; 32]));
    match comprobar_estructura_y_hash_dag_dev(&base, &p_malo) {
        Err(ErrorGenesisDagDev::HashNoCoincide { .. }) => {}
        otro => panic!("se esperaba HashNoCoincide, llegó {otro:?}"),
    }
}

// ── Aritmética sin desbordamiento silencioso ─────────────────────────────────────────────────

#[test]
fn una_coinbase_con_muchas_salidas_positivas_no_desborda_en_panico() {
    let p = parametros();
    let base = construir_dag_dev(&p).unwrap();

    let lock = Lock::PubKey {
        pubkey: ClavePublica::desde_bytes([0x77; 32]),
    };
    let mut cb = coinbase_genesis(MENSAJE);
    cb.outputs = vec![
        TxOut {
            value: Amount::nuevo(ZX_VALUE_SANITY_LIMIT).unwrap(),
            lock: lock.clone(),
        },
        TxOut {
            value: Amount::nuevo(ZX_VALUE_SANITY_LIMIT).unwrap(),
            lock: lock.clone(),
        },
        TxOut {
            value: Amount::nuevo(ZX_VALUE_SANITY_LIMIT).unwrap(),
            lock,
        },
    ];

    let m = BloqueDag::nuevo(
        base.cabecera,
        JustificacionPot::vacia(),
        vec![cb],
        vec![vec![]],
    )
    .unwrap();
    let e = exige_error(&m, &p);
    assert!(
        matches!(
            e,
            ErrorGenesisDagDev::Core(EncodingError::ImporteFueraDeRango { .. })
        ),
        "Amount::suma MUST rechazar el desbordamiento sin panic: {e:?}"
    );
}

// ── Timestamp marcador y génesis lineal intacto ──────────────────────────────────────────────

#[test]
fn un_timestamp_marcador_de_posicion_se_rechaza() {
    let mut p = parametros();
    p.timestamp = TIMESTAMP_MINIMO_GENESIS - 1;
    let bloque = construir_dag_dev(&p).unwrap();
    match comprobar_estructura_y_hash_dag_dev(&bloque, &p) {
        Err(ErrorGenesisDagDev::TimestampNoPlausible(t)) => {
            assert_eq!(t, TIMESTAMP_MINIMO_GENESIS - 1);
        }
        otro => panic!("se esperaba TimestampNoPlausible, llegó {otro:?}"),
    }

    // Un marcador de posición puro (epoch 0) tampoco habilita nada.
    let mut p_cero = parametros();
    p_cero.timestamp = 0;
    let bloque = construir_dag_dev(&p_cero).unwrap();
    assert!(matches!(
        comprobar_estructura_y_hash_dag_dev(&bloque, &p_cero),
        Err(ErrorGenesisDagDev::TimestampNoPlausible(0))
    ));
}

/// El perfil DAG de desarrollo no toca el génesis lineal: testnet sigue arrancando y congelado.
#[test]
fn el_genesis_lineal_de_testnet_conserva_sus_pruebas() {
    let h = comprobar_al_arrancar(GENESIS_TESTNET).unwrap();
    assert_eq!(h.as_bytes(), &HASH_GENESIS_TESTNET);
}
