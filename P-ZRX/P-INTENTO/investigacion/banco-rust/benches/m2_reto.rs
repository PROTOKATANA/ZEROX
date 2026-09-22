#![feature(generic_const_exprs)]
#![expect(incomplete_features, reason = "ab-proof-of-space usa generic_const_exprs; hay que nombrar Proofs<20>")]

//! M2 · `t_reto` — coste de probar una tabla YA GENERADA contra retos.
//!
//! Pregunta del encargo: *¿escala como `w · t_reto`, o hay forma mas barata de cruzar una tabla
//! con `w` buckets a la vez?*
//!
//! Aqui se miden las dos formas:
//!   - `por_bucket`: el camino que ofrece el codigo del clon, `w` veces `for_s_bucket`
//!     (rank/select sobre el mapa de presencia de 8 KiB).
//!   - `lote`: `AND` palabra a palabra del mapa de presencia con un mapa objetivo de `w` bits.
//!     Coste `O(NUM_S_BUCKETS/64)` independiente de `w`.
//!
//! Y el test completo de candidato (derivacion + acierto + distancia) para el caso realista.

use ab_proof_of_space::chiapos::TablesCache;
use criterion::{Criterion, Throughput, criterion_group, criterion_main};
use intento_banco::{
    NUM_S_BUCKETS, bitset_objetivo, buckets_de_retos, buckets_para_w, cruce_lote,
    proof_index_para_bucket, retos_globales, sector_id_i, seed_i, tabla,
};
use std::hint::black_box;
use subspace_core_primitives::sectors::SBucket;
use subspace_verification::is_within_solution_range;

const W: [usize; 5] = [1, 10, 100, 1_000, 10_000];

fn bench_m2(c: &mut Criterion) {
    let cache = TablesCache::default();
    let seed = seed_i(0);
    let table = tabla(&seed, &cache);
    let sector_id = sector_id_i(0);

    // Buckets representativos del mapa real. El `rank/select` del clon recorre TODOS los bytes
    // anteriores al bucket, asi que el coste depende del indice: hay que medir bajo, medio y alto,
    // no solo el primero (que daria ~0 y no representa nada).
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
            .find(|b| proof_index_para_bucket(&table.found_proofs, *b).is_some())
            .expect("la tabla tiene pruebas; qed")
    };
    let bajo = presente_cerca(0);
    let medio = presente_cerca(NUM_S_BUCKETS / 2);
    let alto = presente_cerca(NUM_S_BUCKETS - 1);
    let sin_prueba: SBucket = (0..u16::MAX)
        .map(SBucket::from)
        .find(|b| proof_index_para_bucket(&table.found_proofs, *b).is_none())
        .expect("la tabla tiene buckets vacios; qed");
    eprintln!("[M2] buckets de sonda: bajo={bajo:?} medio={medio:?} alto={alto:?}");

    // Objetivos realistas: `w` retos derivados de la identidad.
    let w_max = *W.iter().max().expect("no vacio; qed");
    let (buckets_max, ssc_max, gc_max) = buckets_para_w(&sector_id, w_max, 0);

    let mut g = c.benchmark_group("m2_aislado");
    g.throughput(Throughput::Elements(1));

    g.bench_function("rank_select_bucket_bajo", |b| {
        b.iter(|| proof_index_para_bucket(black_box(&table.found_proofs), black_box(bajo)));
    });
    g.bench_function("rank_select_bucket_medio", |b| {
        b.iter(|| proof_index_para_bucket(black_box(&table.found_proofs), black_box(medio)));
    });
    g.bench_function("rank_select_bucket_alto", |b| {
        b.iter(|| proof_index_para_bucket(black_box(&table.found_proofs), black_box(alto)));
    });
    g.bench_function("rank_select_bucket_sin_prueba", |b| {
        b.iter(|| proof_index_para_bucket(black_box(&table.found_proofs), black_box(sin_prueba)));
    });

    // Peor caso del rank/select: bucket maximo, obliga a recorrer los 8 KiB completos.
    let ultimo = SBucket::from(u16::MAX);
    g.bench_function("rank_select_bucket_maximo_sin_prueba", |b| {
        b.iter(|| proof_index_para_bucket(black_box(&table.found_proofs), black_box(ultimo)));
    });

    // Test de distancia sobre un chunk crudo (lo que decide "gana").
    let chunk = [0x5a_u8; 32];
    g.bench_function("distancia_un_acierto", |b| {
        b.iter(|| {
            is_within_solution_range(
                black_box(&gc_max[0]),
                black_box(&chunk),
                black_box(&ssc_max[0]),
                black_box(u64::MAX),
            )
        });
    });
    g.finish();

    // Cruce de una tabla con w retos: las dos formas.
    for w in W {
        let buckets = &buckets_max[..w];
        let objetivo = bitset_objetivo(buckets);

        let mut g = c.benchmark_group(format!("m2_w{w}"));
        g.throughput(Throughput::Elements(w as u64));

        // OJO: si el bucle solo mirase `.is_some()`, LLVM eliminaria la suma de `count_ones`
        // (el indice seria un valor muerto) y la medida seria la del test de bit, no la del
        // rank/select. Se acumula el indice para que el trabajo medido sea el real.
        g.bench_function("por_bucket", |b| {
            b.iter(|| {
                let mut hits = 0_usize;
                let mut suma = 0_usize;
                for bucket in black_box(buckets) {
                    if let Some(indice) =
                        proof_index_para_bucket(black_box(&table.found_proofs), *bucket)
                    {
                        hits += 1;
                        suma = suma.wrapping_add(indice);
                    }
                }
                black_box((hits, suma))
            });
        });

        g.bench_function("lote_and_64k", |b| {
            b.iter(|| cruce_lote(black_box(&table.found_proofs), black_box(&objetivo)));
        });

        // Construir el mapa objetivo desde los w buckets (coste por reto adicional).
        g.bench_function("construir_objetivo", |b| {
            b.iter(|| bitset_objetivo(black_box(buckets)));
        });

        // Derivacion del s-bucket POR IDENTIDAD (SectorId XOR global_challenge). Los retos
        // globales NO se cobran aqui: los produce el PoT una vez y son compartidos por todas las
        // identidades candidatas.
        let retos = retos_globales(w, 0);
        g.bench_function("derivar_buckets", |b| {
            b.iter(|| buckets_de_retos(black_box(&sector_id), black_box(&retos)));
        });

        g.finish();
    }
}

criterion_group!(benches, bench_m2);
criterion_main!(benches);
