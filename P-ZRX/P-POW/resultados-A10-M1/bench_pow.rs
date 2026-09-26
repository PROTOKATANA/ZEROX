//! Banco de medida del `hash_pow` dev (ORDEN-A10-M1).
//!
//! No es código de consenso ni se migra al árbol real: vive únicamente en la copia de trabajo de
//! `deepseek/A10M1/`. Llama exclusivamente a `zx_core::sha3_256_publico` sobre la preimagen
//! canónica del PoW (`BlockHeader::preimagen_pow`), variando el nonce en `[OFFSET_NONCE_PREIMAGEN,
//! +8)` (C-HDR-04), exactamente como especifica la ORDEN.
//!
//! Modos (`argv[1]`):
//!   - `cpu-bench <duracion_s>`      → hashea con 1 hilo (el proceso completo se fija con `taskset`
//!                                     desde fuera) durante al menos `duracion_s` segundos.
//!   - `cpu-bench-mt <hilos> <duracion_s>` → igual, pero reparte `hilos` hilos internos sobre el
//!                                     conjunto de CPUs que `taskset` le haya dado al proceso.
//!   - `dump-ref <seed> <n> <fichero>` → escribe `n` digests de 32 bytes, uno por nonce generado con
//!                                     `splitmix64(seed)`, concatenados en orden, para comparar
//!                                     bit a bit con el kernel GPU (validación (b)).
//!   - `search <objetivo_bits_cero> <max_nonce>` → primer nonce cuyo `hash_pow` (interpretado
//!                                     big-endian) tiene al menos `objetivo_bits_cero` bits altos a
//!                                     cero (validación (c)).
//!   - `vector <hex>` → SHA3-256 desnudo de un mensaje hex arbitrario (para contrastar un vector
//!                                     NIST puntual a mano).

use std::env;
use std::fs::File;
use std::io::{BufWriter, Write as _};
use std::process::ExitCode;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};

use zx_core::preimage::block::{BlockHeader, OFFSET_NONCE_PREIMAGEN};
use zx_core::{BlockHash, CBID_RED_DEV, Digest, MerkleRoot, sha3_256_publico};

/// La misma cabecera fija que usan los tests de `zx-consensus` (§1 de la ORDEN): lo único que
/// importa para el hashrate es que la preimagen tenga siempre 108 bytes y que el nonce varíe en su
/// rango contractual; los demás campos son arbitrarios pero fijos y reproducibles.
fn cabecera_base() -> BlockHeader {
    BlockHeader {
        consensus_branch_id: CBID_RED_DEV,
        prev_hash: BlockHash::from_digest(Digest::from_bytes([0x11; 32])),
        merkle_root: MerkleRoot::from_digest(Digest::from_bytes([0x22; 32])),
        timestamp: 1_790_380_800,
        bits: 0x1e7f_ffff,
        nonce: 0,
        height: 1,
    }
}

/// SplitMix64 (Vigna 2015), dominio público, réplica bit a bit en el kernel CUDA. Solo sirve para
/// generar una secuencia de nonces determinista y reproducible entre CPU y GPU; no es
/// consensus-critical.
#[inline]
fn splitmix64_next(state: &mut u64) -> u64 {
    *state = state.wrapping_add(0x9E37_79B9_7F4A_7C15);
    let mut z = *state;
    z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
    z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
    z ^ (z >> 31)
}

/// Escribe el nonce (little-endian, C-HDR-04) en la preimagen y devuelve `sha3_256_publico`.
#[inline]
fn hash_con_nonce(preimagen: &mut [u8; zx_core::preimage::block::TAMANO_PREIMAGEN_POW], nonce: u64) -> Digest {
    preimagen[OFFSET_NONCE_PREIMAGEN..OFFSET_NONCE_PREIMAGEN + 8]
        .copy_from_slice(&nonce.to_le_bytes());
    sha3_256_publico(preimagen)
}

fn modo_cpu_bench_mt(hilos: usize, duracion_s: f64) {
    let parar = Arc::new(AtomicBool::new(false));
    let total = Arc::new(AtomicU64::new(0));
    let mut manejadores = Vec::with_capacity(hilos);

    let inicio = Instant::now();
    for id in 0..hilos {
        let parar = Arc::clone(&parar);
        let total = Arc::clone(&total);
        manejadores.push(std::thread::spawn(move || {
            let mut preimagen = cabecera_base().preimagen_pow();
            // Cada hilo recorre una progresión aritmética distinta (paso = nº de hilos) para no
            // repetir nonce entre hilos; no afecta al hashrate, solo evita duplicar trabajo.
            let mut nonce: u64 = id as u64;
            let mut contador: u64 = 0;
            const LOTE: u64 = 1 << 16;
            loop {
                for _ in 0..LOTE {
                    let _ = hash_con_nonce(&mut preimagen, nonce);
                    nonce = nonce.wrapping_add(hilos as u64);
                }
                contador += LOTE;
                if parar.load(Ordering::Relaxed) {
                    break;
                }
            }
            total.fetch_add(contador, Ordering::Relaxed);
        }));
    }

    std::thread::sleep(Duration::from_secs_f64(duracion_s));
    parar.store(true, Ordering::Relaxed);
    for m in manejadores {
        let _ = m.join();
    }
    let transcurrido = inicio.elapsed().as_secs_f64();
    let n = total.load(Ordering::Relaxed);
    println!(
        "hilos={hilos} hashes={n} segundos={transcurrido:.6} hs={:.3}",
        n as f64 / transcurrido
    );
}

fn modo_dump_ref(seed: u64, n: u64, fichero: &str) {
    let mut preimagen = cabecera_base().preimagen_pow();
    let f = File::create(fichero).expect("no se pudo crear el fichero de salida");
    let mut w = BufWriter::new(f);
    let mut estado = seed;
    for _ in 0..n {
        let nonce = splitmix64_next(&mut estado);
        let d = hash_con_nonce(&mut preimagen, nonce);
        w.write_all(d.as_bytes()).expect("fallo de escritura");
    }
    w.flush().expect("fallo de flush");
    println!("dump-ref: {n} digests escritos en {fichero} (seed={seed})");
}

fn modo_search(objetivo_bits_cero: u32, max_nonce: u64) {
    let mut preimagen = cabecera_base().preimagen_pow();
    for nonce in 0..max_nonce {
        let d = hash_con_nonce(&mut preimagen, nonce);
        if cuenta_bits_cero_altos(d.as_bytes()) >= objetivo_bits_cero {
            println!(
                "search: nonce={nonce} hash={} bits_cero={}",
                hex(d.as_bytes()),
                cuenta_bits_cero_altos(d.as_bytes())
            );
            return;
        }
    }
    println!("search: sin resultado hasta max_nonce={max_nonce}");
}

/// Bits altos a cero de un digest interpretado big-endian (como manda C-POW-01).
fn cuenta_bits_cero_altos(b: &[u8; 32]) -> u32 {
    let mut c = 0u32;
    for byte in b.iter() {
        if *byte == 0 {
            c += 8;
        } else {
            c += byte.leading_zeros();
            break;
        }
    }
    c
}

fn hex(b: &[u8]) -> String {
    b.iter().map(|x| format!("{x:02x}")).collect()
}

fn modo_vector(hex_msg: &str) {
    let bytes = (0..hex_msg.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex_msg[i..i + 2], 16).expect("hex inválido"))
        .collect::<Vec<u8>>();
    let d = sha3_256_publico(&bytes);
    println!("{}", hex(d.as_bytes()));
}

fn main() -> ExitCode {
    let args: Vec<String> = env::args().collect();
    match args.get(1).map(String::as_str) {
        Some("cpu-bench-mt") => {
            let hilos: usize = args[2].parse().expect("hilos");
            let duracion: f64 = args[3].parse().expect("duracion");
            modo_cpu_bench_mt(hilos, duracion);
        }
        Some("dump-ref") => {
            let seed: u64 = args[2].parse().expect("seed");
            let n: u64 = args[3].parse().expect("n");
            modo_dump_ref(seed, n, &args[4]);
        }
        Some("search") => {
            let objetivo: u32 = args[2].parse().expect("objetivo");
            let max_nonce: u64 = args[3].parse().expect("max_nonce");
            modo_search(objetivo, max_nonce);
        }
        Some("vector") => {
            modo_vector(&args[2]);
        }
        Some("preimagen-hex") => {
            // Utilidad: imprime la preimagen base (nonce=0) en hex, para que el lado CUDA construya
            // exactamente la misma plantilla de 108 bytes sin duplicar la lógica de serialización.
            let preimagen = cabecera_base().preimagen_pow();
            println!("{}", hex(&preimagen));
        }
        _ => {
            eprintln!(
                "uso: bench_pow <cpu-bench-mt hilos duracion_s | dump-ref seed n fichero | search bits_cero max_nonce | vector hex | preimagen-hex>"
            );
            return ExitCode::FAILURE;
        }
    }
    ExitCode::SUCCESS
}
