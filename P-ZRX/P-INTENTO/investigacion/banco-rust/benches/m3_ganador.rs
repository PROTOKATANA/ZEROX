#![feature(generic_const_exprs)]
#![expect(incomplete_features, reason = "ab-proof-of-space usa generic_const_exprs; hay que nombrar Proofs<20>")]

//! M3 · `t_ganador` — el camino que SOLO paga el intento que gana.
//!
//! Descomposicion por componente, con la API publica del clon:
//!   - leer la pieza del historico local (I/O)
//!   - erasure coding: `extend` de la pieza a paridad
//!   - `recover_poly` sobre el registro codificado (lo que hace `proving.rs:243-329`)
//!   - KZG: `poly` + `commit` (compromiso del registro) y `create_witness` (testigo del chunk)
//!
//! Lo que el atacante OMITE respecto del plotter honesto: construir y escribir el sector,
//! `SectorContentsMap`, el checksum de sector, y la extraccion de las 32.768 pruebas no ganadoras.
//! Eso se mide en M4.

use ab_proof_of_space::chiapos::TablesCache;
use criterion::{Criterion, Throughput, criterion_group, criterion_main};
use intento_banco::{NUM_CHUNKS, NUM_S_BUCKETS, proof_index_para_bucket, seed_i, tabla};
use std::hint::black_box;
use std::num::NonZeroUsize;
use subspace_core_primitives::pieces::Record;
use subspace_core_primitives::sectors::SBucket;
use subspace_erasure_coding::ErasureCoding;
use subspace_kzg::{Kzg, Scalar};

fn erasure() -> ErasureCoding {
    ErasureCoding::new(
        NonZeroUsize::new(Record::NUM_S_BUCKETS.next_power_of_two().ilog2() as usize)
            .expect("no cero; qed"),
    )
    .expect("escala valida; qed")
}

fn bench_m3(c: &mut Criterion) {
    let cache = TablesCache::default();
    let table = tabla(&seed_i(0), &cache);

    // Pieza cruda sintetica de 1 MiB. El atacante la tiene del historico archivado; lo que se
    // mide es el coste del calculo posterior, no el contenido. Se usa la conversion INFALIBLE
    // `From<[u8; SAFE_BYTES=31]>` (`shared/subspace-kzg/src/lib.rs:123-136`), que garantiza que el
    // valor cae dentro del cuerpo escalar.
    let mut fuente: Vec<Scalar> = Vec::with_capacity(NUM_CHUNKS);
    for i in 0..NUM_CHUNKS {
        let mut b = [0_u8; 31];
        b[..8].copy_from_slice(&(i as u64).to_le_bytes());
        b[8] = 0x5a;
        fuente.push(Scalar::from(b));
    }

    let erasure = erasure();
    let kzg = Kzg::new();

    let paridad = erasure.extend(&fuente).expect("escala valida; qed");

    // Registro erasure-codificado completo, en orden de s-bucket (source/parity intercalados,
    // igual que `plotting.rs:646-655`).
    let mut codificado: Vec<Scalar> = Vec::with_capacity(NUM_S_BUCKETS);
    for i in 0..NUM_CHUNKS {
        codificado.push(fuente[i].clone());
        codificado.push(paridad[i].clone());
    }
    assert_eq!(codificado.len(), NUM_S_BUCKETS);

    // Patron real de lecturas del prover: `Some` solo en los s-buckets con prueba.
    let mut shards: Vec<Option<Scalar>> = codificado.iter().cloned().map(Some).collect();
    let mut con_prueba = 0_usize;
    let mut primer_ganador = SBucket::ZERO;
    for b in 0..NUM_S_BUCKETS {
        if proof_index_para_bucket(&table.found_proofs, SBucket::from(b as u16)).is_some() {
            if con_prueba == 0 {
                primer_ganador = SBucket::from(b as u16);
            }
            con_prueba += 1;
        } else {
            shards[b] = None;
        }
    }
    eprintln!("[M3] s-buckets con prueba = {con_prueba} de {NUM_S_BUCKETS}");

    let poly_fuente = kzg.poly(&fuente).expect("32768 <= NUM_G1_POWERS; qed");
    let polinomio = erasure
        .recover_poly(&shards)
        .expect("shards suficientes; qed");

    let mut g = c.benchmark_group("m3");
    g.throughput(Throughput::Elements(1));

    g.bench_function("erasure_extend_pieza_1MiB", |b| {
        b.iter(|| erasure.extend(black_box(&fuente)).expect("ok; qed"));
    });

    g.bench_function("kzg_poly_pieza_1MiB", |b| {
        b.iter(|| kzg.poly(black_box(&fuente)).expect("ok; qed"));
    });

    g.bench_function("kzg_commit_pieza", |b| {
        b.iter(|| kzg.commit(black_box(&poly_fuente)).expect("ok; qed"));
    });

    g.bench_function("erasure_recover_poly", |b| {
        b.iter(|| erasure.recover_poly(black_box(&shards)).expect("ok; qed"));
    });

    let indice = u32::from(primer_ganador);
    g.bench_function("kzg_chunk_witness", |b| {
        b.iter(|| {
            kzg.create_witness(black_box(&polinomio), NUM_S_BUCKETS, black_box(indice))
                .expect("ok; qed")
        });
    });

    g.bench_function("tabla_para_la_semilla_ganadora", |b| {
        b.iter(|| tabla(black_box(&seed_i(0)), &cache));
    });

    g.finish();

    // Lectura local de la pieza (1 MiB). El atacante NO la descarga: la tiene archivada.
    let dir = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../tmp-mediciones");
    std::fs::create_dir_all(&dir).expect("directorio de trabajo; qed");
    let ruta = dir.join("pieza_1MiB.bin");
    std::fs::write(&ruta, vec![0x5a_u8; Record::SIZE]).expect("escritura; qed");

    let mut g = c.benchmark_group("m3_io");
    g.throughput(Throughput::Bytes(Record::SIZE as u64));
    g.bench_function("leer_pieza_local_1MiB", |b| {
        b.iter(|| std::fs::read(black_box(&ruta)).expect("lectura; qed"));
    });
    g.finish();

    let _ = std::fs::remove_file(&ruta);
}

criterion_group!(benches, bench_m3);
criterion_main!(benches);
