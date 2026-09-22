#![feature(generic_const_exprs)]
#![expect(incomplete_features, reason = "ab-proof-of-space usa generic_const_exprs")]

//! Distribucion espacial de las pruebas dentro de la tabla.
//!
//! `create_proofs` recorre los s-buckets en orden 0..65535 y CORTA al llegar a `NUM_CHUNKS`
//! pruebas (`shared/ab-proof-of-space/src/chiapos.rs:225-268`). Si el numero estructural de
//! buckets con prueba superase 32768, el mapa de presencia quedaria sesgado hacia los buckets
//! bajos — y como el reto elige el bucket de forma uniforme, la probabilidad `o` de que un reto
//! caiga en un bucket con prueba NO seria 1/2. Esto se mide, no se supone.

use ab_proof_of_space::chiapos::TablesCache;
use intento_banco::{NUM_S_BUCKETS, seed_i, tabla};

const DECILES: usize = 16;

fn main() {
    let n: u64 = std::env::args()
        .nth(1)
        .map(|v| v.parse().expect("entero"))
        .unwrap_or(32);
    let cache = TablesCache::default();

    let ancho = NUM_S_BUCKETS / DECILES;
    let mut por_dec = vec![0_u64; DECILES];
    let mut total = 0_u64;
    let mut max_bucket = 0_usize;
    let mut min_pruebas = usize::MAX;
    let mut max_pruebas = 0_usize;

    for i in 0..n {
        let t = tabla(&seed_i(i), &cache);
        let mut cuenta = 0_usize;
        for (byte_i, byte) in t.found_proofs.iter().enumerate() {
            if *byte == 0 {
                continue;
            }
            for bit in 0..8 {
                if byte & (1 << bit) != 0 {
                    let b = byte_i * 8 + bit;
                    por_dec[b / ancho] += 1;
                    cuenta += 1;
                    if b > max_bucket {
                        max_bucket = b;
                    }
                }
            }
        }
        total += cuenta as u64;
        min_pruebas = min_pruebas.min(cuenta);
        max_pruebas = max_pruebas.max(cuenta);
    }

    println!("SEMILLAS\t{n}");
    println!("PRUEBAS_TOTALES\t{total}");
    println!("PRUEBAS_MEDIA\t{:.3}", total as f64 / n as f64);
    println!("PRUEBAS_MIN\t{min_pruebas}");
    println!("PRUEBAS_MAX\t{max_pruebas}");
    println!("BUCKET_MAX_VISTO\t{max_bucket}");
    println!("DECIL\tBUCKETS\tPRUEBAS\tFRACCION_DEL_DECIL");
    for d in 0..DECILES {
        let ini = d * ancho;
        let fin = ini + ancho;
        let frac = por_dec[d] as f64 / (n as f64 * ancho as f64);
        println!("{d}\t{ini}-{fin}\t{}\t{frac:.6}", por_dec[d]);
    }
    let o = total as f64 / (n as f64 * NUM_S_BUCKETS as f64);
    println!("O_MEDIDO\t{o:.6}");
}
