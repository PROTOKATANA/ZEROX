//! AÑADIDO por el banco de costes (ver DIFF.md): las cuatro rutas forzadas deben
//! coincidir entre sí y con el despacho automático, y un checkpoint mutado debe
//! fallar en las cuatro. No sustituye a `diferencial.rs`.
use std::num::NonZeroU32;
use pot_estable::tipos::{PotSeed, Ruta};
use pot_estable::{verify_con_ruta, verify};

const SEED: [u8; 16] = [
    0xd6, 0x66, 0xcc, 0xd8, 0xd5, 0x93, 0xc2, 0x3d, 0xa8, 0xdb, 0x6b, 0x5b, 0x14, 0x13, 0xb1,
    0x3a,
];

const RUTAS: [Ruta; 4] = [
    Ruta::Avx512fVaes,
    Ruta::Avx2Vaes,
    Ruta::AesSse41,
    Ruta::Generica,
];

#[test]
fn las_cuatro_rutas_coinciden_y_un_checkpoint_mutado_falla_en_las_cuatro() {
    let seed = PotSeed::from(SEED);
    let iterations = NonZeroU32::new(4000).unwrap();
    let checkpoints = pot_estable::prove(seed, iterations).unwrap();

    assert!(verify(seed, iterations, &checkpoints).unwrap(), "auto");
    for ruta in RUTAS {
        assert!(
            verify_con_ruta(seed, iterations, &checkpoints, ruta).unwrap(),
            "ruta {ruta:?} debe aceptar"
        );
    }

    let mut mutados = checkpoints;
    mutados[3][5] ^= 0x01;
    for ruta in RUTAS {
        assert!(
            !verify_con_ruta(seed, iterations, &mutados, ruta).unwrap(),
            "ruta {ruta:?} debe rechazar el checkpoint mutado"
        );
    }

    let mut seed_ajeno = seed;
    seed_ajeno[0] ^= 0x01;
    for ruta in RUTAS {
        assert!(
            !verify_con_ruta(seed_ajeno, iterations, &checkpoints, ruta).unwrap(),
            "ruta {ruta:?} debe rechazar la semilla ajena"
        );
    }
}
