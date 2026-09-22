#![feature(generic_const_exprs)]
#![expect(incomplete_features, reason = "ab-proof-of-space usa generic_const_exprs; hay que nombrar Proofs<20>")]

//! M4 · segunda mitad del cono: cuanto de `create_proofs` es inevitable y cuanto es podable.
//!
//! `Tables::<20>::create` construye las siete tablas completas y las DEVUELVE.
//! `Tables::create_proofs` construye esas mismas tablas y ademas extrae las 32.768 pruebas.
//! El atacante solo necesita las pruebas que caen en sus `w` buckets.
//!
//! `t_create_proofs - t_create` es la COTA SUPERIOR de lo que una poda podria ahorrar.
//!
//! No se usa Criterion aqui: `Tables::create` reserva decenas de MiB y no conviene meterlo en un bucle de
//! muestras. Se mide con `Instant`, n repeticiones, y se declara como coste unico, no microbenchmark.

use ab_proof_of_space::chiapos::{Tables, TablesCache};
use intento_banco::{PROOFS_BYTES, pruebas_presentes, seed_i, tabla, tabla_paralela};
use rayon::ThreadPoolBuilder;
use std::time::Instant;

fn main() {
    let hilos: usize = std::env::args()
        .nth(1)
        .map(|v| v.parse().expect("entero"))
        .unwrap_or(24);
    let reps: usize = std::env::args()
        .nth(2)
        .map(|v| v.parse().expect("entero"))
        .unwrap_or(3);

    let _ = ThreadPoolBuilder::new().num_threads(hilos).build_global();
    let cache = TablesCache::default();
    let seed = seed_i(0);

    let mut t_create = Vec::new();
    let mut t_proofs = Vec::new();
    let mut t_parallel = Vec::new();
    let mut presentes = 0;

    for r in 0..reps {
        let t0 = Instant::now();
        let tablas = Tables::<20>::create(seed.into(), &cache);
        t_create.push(t0.elapsed().as_secs_f64());
        drop(tablas);

        let t0 = Instant::now();
        let p = tabla(&seed, &cache);
        t_proofs.push(t0.elapsed().as_secs_f64());
        presentes = pruebas_presentes(&p.found_proofs);
        drop(p);

        let t0 = Instant::now();
        let p = tabla_paralela(&seed, &cache);
        t_parallel.push(t0.elapsed().as_secs_f64());
        drop(p);

        eprintln!("[cono] rep {r} hecha");
    }

    let mediana = |v: &mut Vec<f64>| {
        v.sort_by(|a, b| a.partial_cmp(b).expect("sin NaN"));
        v[v.len() / 2]
    };

    let mc = mediana(&mut t_create);
    let mp = mediana(&mut t_proofs);
    let mpar = mediana(&mut t_parallel);

    println!("METRICA\tsegundos");
    println!("create_siete_tablas\t{mc:.6}");
    println!("create_proofs\t{mp:.6}");
    println!("create_proofs_parallel_{hilos}h\t{mpar:.6}");
    println!(
        "cota_superior_poda_extraccion\t{:.6}",
        (mp - mc).max(0.0)
    );
    println!(
        "fraccion_podable_sobre_create_proofs\t{:.6}",
        (mp - mc).max(0.0) / mp
    );
    println!("pruebas_por_tabla\t{presentes}");
    println!("sizeof_Proofs20_bytes\t{PROOFS_BYTES}");
    println!("# create={t_create:?}");
    println!("# create_proofs={t_proofs:?}");
    println!("# create_proofs_parallel={t_parallel:?}");
}
