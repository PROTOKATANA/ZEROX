//! Generador de vectores de la propuesta P-POT (PROPUESTA-SPEC.md §5).
//!
//! Solo blake3 y el AES de `pot-estable` con N mínimo (16 iteraciones por slot).
//! No ejecuta nada pesado. Salida determinista: misma semilla, mismos bytes.

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

fn hex16(v: &[u8]) -> String {
    let mut s = String::with_capacity(32);
    for b in v {
        s.push_str(&format!("{b:02x}"));
    }
    s
}

fn main() {
    // V1 — encadenado sin inyeccion, 4 slots.
    let g = semilla_genesis();
    println!("V1 semilla(f,0) = {}", hex16(&g[..]));
    let mut seed = g;
    for s in 0..4 {
        let out = salida(seed);
        println!("V1 salida(f,{s}) = {}", hex16(&out[..]));
        seed = PotSeed::from(*out);
    }

    // V2 — inyeccion: semilla = blake3(entropia ‖ salida)[0..16).
    let ent = entropia_v2();
    let previa = salida(g);
    let s2 = semilla_inyectada(&ent, &previa);
    println!("V2 entropia        = {}", hex16(&ent));
    println!("V2 salida(f,s-1)   = {}", hex16(&previa[..]));
    println!("V2 semilla(f,s)    = {}", hex16(&s2[..]));
    println!("V2 salida(f,s)     = {}", hex16(&salida(s2)[..]));

    // V3 — aleatoriedad = blake3(salida).
    let aleat = blake3::hash(&previa[..]);
    println!("V3 aleatoriedad    = {}", hex16(aleat.as_bytes()));

    // V4 — reto = blake3(aleatoriedad ‖ LE64(slot)), slot = 42.
    let mut buf = [0u8; 40];
    buf[..32].copy_from_slice(aleat.as_bytes());
    buf[32..].copy_from_slice(&42u64.to_le_bytes());
    let reto = blake3::hash(&buf);
    println!("V4 reto(f,42)      = {}", hex16(reto.as_bytes()));

    // V5 — dominio de N: 7 y 15 no son multiplo de 16.
    for n in [7, 15] {
        let err = pot_estable::prove(g, NonZeroU32::new(n).unwrap())
            .expect_err("debe rechazar N no multiplo de 16");
        println!("V5 N={n} -> {err}");
    }
}
