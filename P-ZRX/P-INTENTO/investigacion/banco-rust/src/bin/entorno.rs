#![feature(generic_const_exprs)]
#![expect(incomplete_features, reason = "ab-proof-of-space usa generic_const_exprs; hay que nombrar Proofs<20>")]

//! Huella estructural del objeto medido. Nada de esto es una medicion de tiempo: son tamanos y
//! constantes que fijan las unidades del modelo.

use intento_banco::{
    FOUND_WORDS, K, NUM_CHUNKS, NUM_S_BUCKETS, PROOFS_BYTES, seed_i, tabla, pruebas_presentes,
};
use ab_proof_of_space::chiapos::TablesCache;

fn main() {
    let cache = TablesCache::default();
    let t = tabla(&seed_i(0), &cache);

    println!(
        "PUESTO\tK={K}\tNUM_S_BUCKETS={NUM_S_BUCKETS}\tNUM_CHUNKS={NUM_CHUNKS}\tFOUND_WORDS={FOUND_WORDS}"
    );
    println!(
        "TAMANO\tsizeof_Proofs20={PROOFS_BYTES}\tmapa_bits_bytes={}\tprueba_bytes={}\tpruebas_por_tabla={}",
        NUM_S_BUCKETS / 8,
        160,
        pruebas_presentes(&t.found_proofs)
    );
    println!(
        "ESTRUCTURA\tproofs_fields={}\tpresencia_densidad={:.6}",
        std::mem::size_of_val(&t.proofs),
        pruebas_presentes(&t.found_proofs) as f64 / NUM_S_BUCKETS as f64
    );

    let cpu = std::fs::read_to_string("/proc/cpuinfo")
        .unwrap_or_default()
        .lines()
        .find(|l| l.starts_with("model name"))
        .unwrap_or("model name: desconocido")
        .to_string();
    println!("CPU\t{}", cpu.trim());

    let hilos = std::thread::available_parallelism().map(|v| v.get()).unwrap_or(0);
    println!("HILOS_DISPONIBLES\t{hilos}");

    let meminfo = std::fs::read_to_string("/proc/meminfo").unwrap_or_default();
    for linea in meminfo.lines().take(3) {
        println!("MEM\t{}", linea.trim());
    }

    println!(
        "RAYON\t{}",
        std::env::var("RAYON_NUM_THREADS").unwrap_or_else(|_| "sin definir".to_string())
    );
}
