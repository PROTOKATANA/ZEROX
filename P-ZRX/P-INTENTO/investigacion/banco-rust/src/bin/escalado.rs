#![feature(generic_const_exprs)]
#![expect(incomplete_features, reason = "ab-proof-of-space usa generic_const_exprs; hay que nombrar Proofs<20>")]

//! M1 · rendimiento agregado por hilos y RAM por tabla viva.
//!
//! Dos formas, como pide el encargo:
//!   `--modo single`   : `h` hilos del sistema, cada uno llamando a `generate` (una tabla a la vez).
//!   `--modo parallel` : una llamada secuencial a `generate_parallel` sobre una piscina rayon de
//!                       tamano `h`.
//!   `--modo anidado`  : `h` hilos del sistema llamando a `generate_parallel` a la vez sobre una
//!                       piscina rayon de 24. Es la forma que usa el granjero real: entrega varios
//!                       generadores a `CpuRecordsEncoder` y cada uno llama a `generate_parallel`
//!                       (`crates/subspace-farmer-components/src/plotting.rs:374-415`).
//!
//! No se usa `--threads=auto`: el tope es 24.

use ab_proof_of_space::chiapos::TablesCache;
use intento_banco::{PROOFS_BYTES, seed_i, tabla, tabla_paralela};
use rayon::ThreadPoolBuilder;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::time::{Duration, Instant};

/// Conjunto de semillas VERIFICADAS seguras.
///
/// `ab-proof-of-space` @ `f8842d0` revienta con SIGSEGV para algunas semillas: ver
/// `banco-rust/src/bin/estres.rs` y `mediciones/fallo-semilla.md`. Los indices 0..126 completaron
/// sin aborto en una corrida de verificacion; se cicla sobre los 32 primeros para no volver a
/// pisar una semilla mala durante el barrido. El fallo NO afecta a las cifras medidas (cada tabla
/// se mide por separado), pero si a la posibilidad de correr muchos cientos de tablas seguidas.
const POOL_SEGURO: u64 = 32;

/// Hilos de la piscina rayon en el modo `anidado` (tope del proyecto).
const POOL_RAYON: usize = 24;

fn rss_kb() -> u64 {
    let status = std::fs::read_to_string("/proc/self/status").unwrap_or_default();
    for linea in status.lines() {
        if let Some(resto) = linea.strip_prefix("VmRSS:") {
            return resto
                .trim()
                .trim_end_matches(" kB")
                .trim()
                .parse()
                .unwrap_or(0);
        }
    }
    0
}

fn uja_energia() -> Option<u64> {
    let rutas = [
        "/sys/class/powercap/intel-rapl:0/energy_uj",
        "/sys/class/powercap/intel-rapl/intel-rapl:0/energy_uj",
    ];
    for r in rutas {
        if let Ok(texto) = std::fs::read_to_string(r) {
            if let Ok(v) = texto.trim().parse::<u64>() {
                return Some(v);
            }
        }
    }
    None
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let mut modo = String::from("single");
    let mut hilos = 1_usize;
    let mut segundos = 15_u64;
    let mut reps = 3_usize;
    let mut ram = 0_usize;

    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "--modo" => {
                modo = args[i + 1].clone();
                i += 2;
            }
            "--hilos" => {
                hilos = args[i + 1].parse().expect("entero");
                i += 2;
            }
            "--segundos" => {
                segundos = args[i + 1].parse().expect("entero");
                i += 2;
            }
            "--reps" => {
                reps = args[i + 1].parse().expect("entero");
                i += 2;
            }
            "--ram" => {
                ram = args[i + 1].parse().expect("entero");
                i += 2;
            }
            otro => panic!("argumento desconocido: {otro}"),
        }
    }

    if ram > 0 {
        // RAM por tabla viva: se retienen `ram` tablas y se mide el crecimiento de RSS.
        let cache = TablesCache::default();
        let antes = rss_kb();
        let mut vivas = Vec::with_capacity(ram);
        for j in 0..ram {
            vivas.push(tabla(&seed_i(j as u64), &cache));
        }
        let despues = rss_kb();
        let delta = despues.saturating_sub(antes);
        println!(
            "RAM\ttablas={ram}\tsizeof_Proofs={PROOFS_BYTES}\tdelta_kb={delta}\tbyte_por_tabla={}",
            delta * 1024 / ram.max(1) as u64
        );
        std::hint::black_box(&vivas);
        return;
    }

    println!("MODO\tHILOS\tREP\tSEGUNDOS\tTABLAS\ttablas_por_s\tms_por_tabla\trss_pico_kb\tuj");

    let mut tasas: Vec<f64> = Vec::with_capacity(reps);

    for rep in 0..reps {
        let parar = Arc::new(AtomicBool::new(false));
        let total = Arc::new(AtomicU64::new(0));
        let uj0 = uja_energia();
        let t0 = Instant::now();

        if modo == "single" {
            let mut manejadores = Vec::with_capacity(hilos);
            for h in 0..hilos {
                let parar = Arc::clone(&parar);
                let total = Arc::clone(&total);
                manejadores.push(std::thread::spawn(move || {
                    let cache = TablesCache::default();
                    let mut contador = 0_u64;
                    while !parar.load(Ordering::Relaxed) {
                        let t = tabla(&seed_i((h as u64 + contador) % POOL_SEGURO), &cache);
                        std::hint::black_box(&t);
                        contador += 1;
                    }
                    total.fetch_add(contador, Ordering::Relaxed);
                }));
            }
            std::thread::sleep(Duration::from_secs(segundos));
            parar.store(true, Ordering::Relaxed);
            for m in manejadores {
                m.join().expect("hilo; qed");
            }
        } else if modo == "anidado" {
            // Piscina rayon de 24; `hilos` llamadas concurrentes a `generate_parallel`.
            let _ = ThreadPoolBuilder::new()
                .num_threads(POOL_RAYON)
                .build_global();
            let mut manejadores = Vec::with_capacity(hilos);
            for h in 0..hilos {
                let parar = Arc::clone(&parar);
                let total = Arc::clone(&total);
                manejadores.push(std::thread::spawn(move || {
                    let cache = TablesCache::default();
                    let mut contador = 0_u64;
                    while !parar.load(Ordering::Relaxed) {
                        let t = tabla_paralela(&seed_i((h as u64 + contador) % POOL_SEGURO), &cache);
                        std::hint::black_box(&t);
                        contador += 1;
                    }
                    total.fetch_add(contador, Ordering::Relaxed);
                }));
            }
            std::thread::sleep(Duration::from_secs(segundos));
            parar.store(true, Ordering::Relaxed);
            for m in manejadores {
                m.join().expect("hilo; qed");
            }
        } else {
            // Piscina rayon de tamano exacto `hilos`.
            let _ = ThreadPoolBuilder::new()
                .num_threads(hilos)
                .build_global();
            let cache = TablesCache::default();
            let fin = Instant::now() + Duration::from_secs(segundos);
            let mut contador = 0_u64;
            while Instant::now() < fin {
                let t = tabla_paralela(&seed_i(contador % POOL_SEGURO), &cache);
                std::hint::black_box(&t);
                contador += 1;
            }
            total.store(contador, Ordering::Relaxed);
        }

        let transcurrido = t0.elapsed().as_secs_f64();
        let uj = match (uj0, uja_energia()) {
            (Some(a), Some(b)) => b.saturating_sub(a).to_string(),
            _ => "no_leible".to_string(),
        };
        let tablas = total.load(Ordering::Relaxed);
        let tasa = tablas as f64 / transcurrido;
        let ms = 1000.0 * transcurrido / tablas.max(1) as f64;
        tasas.push(tasa);
        println!(
            "{modo}\t{hilos}\t{rep}\t{segundos}\t{tablas}\t{tasa:.6}\t{ms:.6}\t{}\t{uj}",
            rss_kb()
        );
    }

    tasas.sort_by(|a, b| a.partial_cmp(b).expect("sin NaN"));
    let mediana = tasas[tasas.len() / 2];
    println!("# MEDIANA\t{modo}\t{hilos}\ttablas_por_s={mediana:.6}\tms_por_tabla={:.6}", 1000.0 / mediana);
}
