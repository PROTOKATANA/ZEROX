#![feature(generic_const_exprs)]
#![expect(incomplete_features, reason = "ab-proof-of-space usa generic_const_exprs; hay que nombrar Proofs<20>")]

//! M1 · `t_tabla` — coste de generar la tabla de UNA semilla.
//!
//! Formas que ofrece el codigo fijado:
//!   - `Tables::create_proofs`      = lo que hace `ChiaV2TableGenerator::generate`
//!   - `Tables::create_proofs_parallel` = `ChiaV2TableGenerator::generate_parallel`
//!
//! El escalado agregado (1, 2, 4, 8, 16, 24 hilos) NO vive aqui: es el bin `escalado`,
//! porque Criterion mide latencia de una entrada fija, no rendimiento agregado por hilos.

use ab_proof_of_space::chiapos::TablesCache;
use criterion::{Criterion, Throughput, criterion_group, criterion_main};
use intento_banco::{PROOFS_BYTES, pruebas_presentes, seed_i, tabla, tabla_paralela};
use std::hint::black_box;

fn bench_m1(c: &mut Criterion) {
    let cache = TablesCache::default();

    // Calentamiento JIT/allocs fuera de la medida.
    let caliente = tabla(&seed_i(0), &cache);
    let _ = tabla_paralela(&seed_i(0), &cache);
    let presentes = pruebas_presentes(&caliente.found_proofs);
    drop(caliente);

    eprintln!("[M1] Proofs<20> = {PROOFS_BYTES} bytes; pruebas por tabla (semilla 0) = {presentes}");

    let mut g = c.benchmark_group("m1");
    g.throughput(Throughput::Elements(1));

    // Semilla fija: mide el camino caliente repetido.
    g.bench_function("tabla_1_hilo_semilla_fija", |b| {
        b.iter(|| tabla(black_box(&seed_i(7)), &cache));
    });

    // Semilla distinta en cada iteracion: descarta que el `TablesCache` o cualquier estado
    // compartido este regalando trabajo. Se cicla sobre un conjunto VERIFICADO SEGURO: el camino
    // no paralelo de `ab-proof-of-space` revienta con algunas semillas (ver
    // `mediciones/fallo-semilla.md`), y Criterion ejecuta mas iteraciones de las que parecen.
    let mut i = 0_u64;
    g.bench_function("tabla_1_hilo_semilla_fresca", |b| {
        b.iter(|| {
            i = (i + 1) % 32;
            tabla(black_box(&seed_i(1 + i)), &cache)
        });
    });

    // Rendimiento agregado por hilos, medido con `--threads` de Criterion == 1, y el
    // paralelismo interno del clon gobernado por RAYON_NUM_THREADS.
    g.bench_function("tabla_paralela_interna", |b| {
        b.iter(|| tabla_paralela(black_box(&seed_i(7)), &cache));
    });

    g.finish();
}

criterion_group!(benches, bench_m1);
criterion_main!(benches);
