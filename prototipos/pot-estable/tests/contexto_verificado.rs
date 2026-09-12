//! Pruebas del verificador PoT real, no del calendario ni de una regla de finalidad.
//! Semilla pública y cantidades de iteraciones elegidas sólo para regresión.

use pot_estable::tipos::PotSeed;
use std::num::NonZeroU32;

fn iteraciones(n: u32) -> NonZeroU32 {
    NonZeroU32::new(n).expect("los vectores de prueba usan cantidades positivas")
}

#[test]
fn cada_checkpoint_es_necesario_aunque_la_salida_final_coincida() {
    let seed = PotSeed::from([0x42; 16]);
    let cantidad = iteraciones(1_600);
    let checkpoints = pot_estable::prove(seed, cantidad).expect("múltiplo válido de 16");
    assert!(pot_estable::verify(seed, cantidad, &checkpoints).unwrap());
    for indice in 0..checkpoints.len() {
        let mut corruptos = checkpoints;
        corruptos[indice][0] ^= 1;
        if indice + 1 < checkpoints.len() {
            assert_eq!(corruptos.output(), checkpoints.output());
        }
        assert!(
            !pot_estable::verify(seed, cantidad, &corruptos).unwrap(),
            "checkpoint alterado: {indice}"
        );
    }
}

#[test]
fn una_prueba_no_se_reutiliza_con_otra_semilla_o_cantidad_de_trabajo() {
    let seed = PotSeed::from([0x42; 16]);
    let checkpoints = pot_estable::prove(seed, iteraciones(1_600)).unwrap();
    assert!(
        !pot_estable::verify(PotSeed::from([0x43; 16]), iteraciones(1_600), &checkpoints).unwrap()
    );
    assert!(!pot_estable::verify(seed, iteraciones(3_200), &checkpoints).unwrap());
}

#[test]
fn trabajo_mal_formado_es_error_no_un_checkpoint_pendiente() {
    let seed = PotSeed::from([0x42; 16]);
    let checkpoints = pot_estable::prove(seed, iteraciones(1_600)).unwrap();
    assert!(pot_estable::verify(seed, iteraciones(17), &checkpoints).is_err());
    assert!(pot_estable::prove(seed, iteraciones(17)).is_err());
}
