#![feature(generic_const_exprs)]
#![expect(incomplete_features, reason = "ab-proof-of-space usa generic_const_exprs")]

//! Reproductor mínimo del aborto por corrupción de heap observado en `escalado --modo single`.
//!
//! Compara dos formas de generar tablas en paralelo desde hilos del sistema:
//!   `separadas`  : cada hilo crea su propio `TablesCache::default()`.
//!   `compartida` : todos los hilos usan clones del MISMO `TablesCache` (lo que hace el banco del
//!                  clon: un solo `PosTable::generator()` con `rayon::scope`).
//!
//! Uso: `estres <hilos> <tablas_por_hilo> <separadas|compartida>`

use ab_proof_of_space::chiapos::TablesCache;
use intento_banco::{seed_i, tabla};
use std::sync::Arc;
use std::sync::atomic::{AtomicUsize, Ordering};

fn main() {
    let mut args = std::env::args().skip(1);
    // Semilla cruda por hex (32 bytes) para exonerar al ayudante `seed_i`.
    let crudo: Option<Arc<[u8; 32]>> = std::env::var("SEMILLA_HEX").ok().map(|hex| {
        let mut bytes = [0_u8; 32];
        for (i, b) in bytes.iter_mut().enumerate() {
            *b = u8::from_str_radix(&hex[2 * i..2 * i + 2], 16).expect("hex de 32 bytes");
        }
        Arc::new(bytes)
    });
    let hilos: usize = args.next().map(|v| v.parse().unwrap()).unwrap_or(4);
    let por_hilo: usize = args.next().map(|v| v.parse().unwrap()).unwrap_or(20);
    let modo = args.next().unwrap_or_else(|| "separadas".to_string());
    let semilla = Arc::new(args.next().unwrap_or_else(|| "variable".to_string()));
    let base: u64 = args.next().map(|v| v.parse().unwrap()).unwrap_or(0);
    // Que funcion publica se ejercita: `generar` es lo que usa la busqueda del atacante;
    // `generar_paralelo` es lo que usa el plotter honesto (`plotting.rs:620-629`).
    let via = Arc::new(std::env::var("VIA").unwrap_or_else(|_| "generar".to_string()));

    // Hex de la semilla 127: entrada minima reproducible, independiente de este crate.
    {
        let s: [u8; 32] = *seed_i(127);
        eprintln!("SEMILLA_127_HEX\t{}", s.iter().map(|b| format!("{b:02x}")).collect::<String>());
    }
    let cache_compartida = Arc::new(TablesCache::default());
    let hechas = Arc::new(AtomicUsize::new(0));

    let mut manejadores = Vec::with_capacity(hilos);
    for h in 0..hilos {
        let cache_compartida = Arc::clone(&cache_compartida);
        let hechas = Arc::clone(&hechas);
        let separadas = modo == "separadas";
        let _variable = semilla.as_str() == "variable";
        let crudo = crudo.clone();
        let semilla = Arc::clone(&semilla);
        let via = Arc::clone(&via);
        manejadores.push(std::thread::spawn(move || {
            let cache = if separadas {
                TablesCache::default()
            } else {
                TablesCache::clone(&cache_compartida)
            };
            for j in 0..por_hilo {
                // `ciclo`: recorre un conjunto pequeno de semillas verificadas seguras, para poder
                // medir en ventanas de tiempo sin toparse con la semilla que revienta.
                let indice = match semilla.as_str() {
                    "variable" => (h * 1_000_003 + j) as u64,
                    "ciclo" => (h * 16 + j) as u64 % 16,
                    _ => base,
                };
                let s = match &crudo {
                    Some(bytes) => subspace_core_primitives::pos::PosSeed::from(**bytes),
                    None => seed_i(indice),
                };
                let t = match via.as_str() {
                    "paralelo" => intento_banco::tabla_paralela(&s, &cache),
                    "siete_tablas" => {
                        // Camino `Tables::create`: construye las siete tablas y las devuelve.
                        let tablas = ab_proof_of_space::chiapos::Tables::<20>::create((*s).into(), &cache);
                        std::hint::black_box(&tablas);
                        eprintln!("HECHO\thilo={h}\tindice={indice}\ttotal={}", hechas.load(Ordering::Relaxed) + 1);
                        hechas.fetch_add(1, Ordering::Relaxed);
                        continue;
                    }
                    _ => tabla(&s, &cache),
                };
                std::hint::black_box(&t);
                // Se informa DESPUES de completar la tabla: la ultima linea impresa antes del
                // aborto es la ultima tabla que SI termino.
                eprintln!("HECHO\thilo={h}\tindice={indice}\ttotal={}", hechas.load(Ordering::Relaxed) + 1);
                hechas.fetch_add(1, Ordering::Relaxed);
            }
        }));
    }

    for m in manejadores {
        m.join().expect("hilo; qed");
    }
    println!(
        "OK\tmodo={modo}\tsemilla={semilla}\tbase={base}\thilos={hilos}\tpor_hilo={por_hilo}\ttotal={}",
        hechas.load(Ordering::Relaxed)
    );
}
