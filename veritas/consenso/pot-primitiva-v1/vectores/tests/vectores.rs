//! Vectores fijados de la propuesta P-POT (PROPUESTA-SPEC.md §5).
//!
//! Regeneracion determinista: el test recalcula con el mismo procedimiento y compara
//! contra las constantes capturadas el 2026-09-19. Si la regeneracion cambiara un solo
//! byte, este test falla (misma idea que el test por mutacion de `pot-estable`).

use core::num::NonZeroU32;
use pot_estable::tipos::{PotOutput, PotSeed};

const N: u32 = 16;

fn semilla_genesis() -> PotSeed {
    let mut s = [0u8; 16];
    s.copy_from_slice(&blake3::hash(b"ZEROX-P-POT-V1-genesis").as_bytes()[..16]);
    PotSeed::from(s)
}

fn entropia_v2() -> [u8; 32] {
    *blake3::hash(b"ZEROX-P-POT-V2-entropy").as_bytes()
}

fn salida(seed: PotSeed) -> PotOutput {
    let cps = pot_estable::prove(seed, NonZeroU32::new(N).unwrap())
        .expect("N=16 es multiplo de 8x2");
    cps.output()
}

fn semilla_inyectada(entropia: &[u8; 32], previa: &PotOutput) -> PotSeed {
    let mut buf = [0u8; 48];
    buf[..32].copy_from_slice(entropia);
    buf[32..].copy_from_slice(&previa[..]);
    let mut s = [0u8; 16];
    s.copy_from_slice(&blake3::hash(&buf).as_bytes()[..16]);
    PotSeed::from(s)
}

fn hex(s: &str) -> [u8; 16] {
    let mut v = [0u8; 16];
    for (i, b) in v.iter_mut().enumerate() {
        *b = u8::from_str_radix(&s[2 * i..2 * i + 2], 16).expect("hex");
    }
    v
}

fn hex32(v: &[u8]) -> String {
    let mut s = String::with_capacity(64);
    for b in v {
        s.push_str(&format!("{b:02x}"));
    }
    s
}

#[test]
fn v1_encadenado_sin_inyeccion() {
    let g = semilla_genesis();
    assert_eq!(g[..], hex("10c9a9b2be91883dbbd81307655243d9"));
    let esperadas = [
        "81c5ab0e4ce122413b30e6ff45ca1673",
        "0eeb4bbd31aeb1e131bec475649b7063",
        "1b478f8dc23646fc6e7667ade3c09906",
        "01b5433c12027fdb51e8a0aceb53301c",
    ];
    let mut seed = g;
    for (s, e) in esperadas.iter().enumerate() {
        let out = salida(seed);
        assert_eq!(out[..], hex(e), "slot {s}");
        seed = PotSeed::from(*out);
    }
}

#[test]
fn v2_inyeccion() {
    let ent = entropia_v2();
    assert_eq!(
        ent,
        *blake3::hash(b"ZEROX-P-POT-V2-entropy").as_bytes(),
        "entropia fija"
    );
    let previa = salida(semilla_genesis());
    let s2 = semilla_inyectada(&ent, &previa);
    assert_eq!(s2[..], hex("0c00b302341a3e3c3ba0fb1232e19ea0"));
    assert_eq!(salida(s2)[..], hex("ef47c860bcdcd1a3754905ba9a19e7ce"));
}

#[test]
fn v3_v4_aleatoriedad_reto() {
    let previa = salida(semilla_genesis());
    let aleat = blake3::hash(&previa[..]);
    let mut buf = [0u8; 40];
    buf[..32].copy_from_slice(aleat.as_bytes());
    buf[32..].copy_from_slice(&42u64.to_le_bytes());
    let reto = blake3::hash(&buf);
    assert_eq!(
        hex32(aleat.as_bytes()),
        "dbc39011a97deaa84376770553cfee918b16525e7797374dd394e50c8775f370"
    );
    assert_eq!(
        hex32(reto.as_bytes()),
        "722ce84f18b69115eff93d38f42257e4649b7609f4312d25fcb268d47154c7f0"
    );
}

#[test]
fn v5_dominio_de_n() {
    for n in [7, 15] {
        assert!(pot_estable::prove(semilla_genesis(), NonZeroU32::new(n).unwrap()).is_err());
    }
    assert!(pot_estable::prove(semilla_genesis(), NonZeroU32::new(16).unwrap()).is_ok());
}
