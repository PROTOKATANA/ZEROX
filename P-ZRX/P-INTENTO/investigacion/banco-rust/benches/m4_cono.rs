#![feature(generic_const_exprs)]
#![expect(incomplete_features, reason = "ab-proof-of-space usa generic_const_exprs; hay que nombrar Proofs<20>")]

//! M4 · cono minimo de dependencia.
//!
//! Pregunta: *¿hacen falta las siete tablas completas para responder a un bucket, o se puede
//! podar?*
//!
//! Aqui se mide el coste de responder UN bucket desde las dos representaciones que el clon ofrece:
//!   - `Tables` (las siete tablas completas, camino `ChiaTable::find_proof`)
//!   - `Proofs` (el objeto compacto del camino `ChiaV2Table::find_proof`: mapa de bits + 32768 pruebas)
//!
//! El otro lado del cono —cuanto de `create_proofs` es inevitable (las tablas) y cuanto es
//! podable (extraer las 32768 pruebas, de las que el atacante solo necesita las que caen en sus
//! `w` buckets)— se mide en el bin `cono`, porque `Tables::create` reserva decenas de MiB y no conviene
//! dentro de un bucle de Criterion.

use ab_proof_of_space::chiapos::{Tables, TablesCache};
use criterion::{Criterion, Throughput, criterion_group, criterion_main};
use intento_banco::{
    NUM_S_BUCKETS, PROOFS_BYTES, proof_index_para_bucket, pruebas_presentes, seed_i, tabla,
};
use std::hint::black_box;
use subspace_core_primitives::sectors::SBucket;

fn bench_m4(c: &mut Criterion) {
    let cache = TablesCache::default();
    let seed = seed_i(0);

    let compacto = tabla(&seed, &cache);
    let presente_cerca = |centro: usize| -> SBucket {
        (0..NUM_S_BUCKETS)
            .map(|d| {
                if centro + d < NUM_S_BUCKETS {
                    centro + d
                } else {
                    centro.saturating_sub(d)
                }
            })
            .map(|i| SBucket::from(i as u16))
            .find(|b| proof_index_para_bucket(&compacto.found_proofs, *b).is_some())
            .expect("hay pruebas; qed")
    };
    let bucket_bajo = presente_cerca(0);
    let bucket_medio = presente_cerca(NUM_S_BUCKETS / 2);
    let bucket_alto = presente_cerca(NUM_S_BUCKETS - 1);

    let presentes = pruebas_presentes(&compacto.found_proofs);
    eprintln!(
        "[M4] tabla compacta = {PROOFS_BYTES} B, {presentes} pruebas, sondas = {bucket_bajo:?} {bucket_medio:?} {bucket_alto:?}"
    );

    let mut g = c.benchmark_group("m4");
    g.throughput(Throughput::Elements(1));

    g.bench_function("responder_1_bucket_mapa_compacto_bajo", |b| {
        b.iter(|| proof_index_para_bucket(black_box(&compacto.found_proofs), black_box(bucket_bajo)));
    });
    g.bench_function("responder_1_bucket_mapa_compacto_medio", |b| {
        b.iter(|| {
            proof_index_para_bucket(black_box(&compacto.found_proofs), black_box(bucket_medio))
        });
    });
    g.bench_function("responder_1_bucket_mapa_compacto_alto", |b| {
        b.iter(|| proof_index_para_bucket(black_box(&compacto.found_proofs), black_box(bucket_alto)));
    });
    g.finish();

    // Las siete tablas completas: se construyen UNA vez fuera de la medida y se filtran para que
    // Criterion mida solo `find_proof`, no la construccion. Ocupan decenas de MiB, no GiB: lo dice
    // el propio consumo medido, no una estimacion.
    eprintln!("[M4] construyendo las siete tablas completas...");
    let t0 = std::time::Instant::now();
    let tablas: &'static Tables<20> = Box::leak(Box::new(Tables::<20>::create(seed.into(), &cache)));
    eprintln!("[M4] siete tablas construidas en {:?}", t0.elapsed());

    let mut g = c.benchmark_group("m4");
    g.throughput(Throughput::Elements(1));
    g.bench_function("responder_1_bucket_siete_tablas_medio", |b| {
        b.iter(|| {
            tablas
                .find_proof(black_box(u32::from(bucket_medio).to_le_bytes()))
                .next()
        });
    });
    g.finish();
}

criterion_group!(benches, bench_m4);
criterion_main!(benches);
