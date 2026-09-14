//! Contraste del ancla de PoT (research/dag-poas-ancla-de-orden.md:342):
//! mismo instrumento (Criterion) y misma semilla (ChaCha8Rng con semilla por
//! defecto) que `benches/pot.rs` de subspace-proof-of-time @ f8842d0, pero con
//! el port `pot-estable` (pot-estable-rutas). Ancla original: verify =
//! 96,1 ms/slot, ruta avx512f_vaes, 200 032 000 iteraciones, 8 checkpoints,
//! Criterion 100 muestras.
use core::num::NonZeroU32;
use criterion::{Criterion, black_box, criterion_group, criterion_main};
use pot_estable::tipos::Ruta;
use rand_chacha::ChaCha8Rng;
use rand_core::{RngCore, SeedableRng};

const POT_ITERACIONES: u32 = 200_032_000;

fn criterion_benchmark(c: &mut Criterion) {
    let mut rng = ChaCha8Rng::from_seed(Default::default());
    let mut seed_bytes = [0u8; 16];
    rng.fill_bytes(&mut seed_bytes);
    let seed = pot_estable::tipos::PotSeed::from(seed_bytes);
    let iterations = NonZeroU32::new(POT_ITERACIONES).expect("no cero");

    let checkpoints = pot_estable::prove(seed, iterations).unwrap();

    // El análogo exacto del ancla: verify con despacho automático (en esta CPU
    // cae en avx512f_vaes).
    c.bench_function("verify (auto)", |b| {
        b.iter(|| {
            black_box(
                pot_estable::verify(
                    black_box(seed),
                    black_box(iterations),
                    black_box(&checkpoints),
                )
                .unwrap(),
            );
        })
    });

    c.bench_function("verify (forzada avx512f_vaes)", |b| {
        b.iter(|| {
            black_box(
                pot_estable::verify_con_ruta(
                    black_box(seed),
                    black_box(iterations),
                    black_box(&checkpoints),
                    black_box(Ruta::Avx512fVaes),
                )
                .unwrap(),
            );
        })
    });
}

criterion_group! {
    name = benches;
    config = Criterion::default().sample_size(30).warm_up_time(std::time::Duration::from_secs(3));
    targets = criterion_benchmark
}
criterion_main!(benches);
