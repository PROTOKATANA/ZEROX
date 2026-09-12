//! Vectores de contratos discretos con descriptores explícitamente sintéticos.
//! No acreditan PoT, PoAS, DAG alcanzable, pagos ni finalidad.

use std::num::{NonZeroU32, NonZeroU64};

use autorizacion_contextual::dominio::*;

fn origen() -> OrigenPot {
    OrigenPot {
        dominio: DominioRed([1; 32]),
        slot_inicial: 0,
        semilla_inicial: [2; 16],
        iteraciones_iniciales: NonZeroU32::new(1600).unwrap(),
        transicion: [3; 32],
    }
}

fn evento(activacion: u64, entropia: u8, iteraciones: u32) -> EventoPot {
    EventoPot {
        activacion,
        entropia: [entropia; 32],
        iteraciones_efectivas: NonZeroU32::new(iteraciones).unwrap(),
    }
}

fn descriptor(eventos: Vec<EventoPot>, hasta: u64) -> DescriptorPotDeclarado {
    DescriptorPotDeclarado::nuevo(origen(), eventos, hasta).unwrap()
}

fn coordenadas() -> CoordenadasBillete {
    CoordenadasBillete {
        slot: 4,
        public_key: [4; 32],
        sector_index: 7,
        history_size: NonZeroU64::new(3).unwrap(),
        piece_offset: 0,
    }
}

#[test]
fn clave_estable_no_depende_de_la_evidencia_ni_de_una_era_renacida() {
    let red = DominioRed([1; 32]);
    let a = red.clave_local(red, coordenadas()).unwrap();
    let b = red.clave_local(red, coordenadas()).unwrap();
    let c = red.clave_local(red, coordenadas()).unwrap();
    assert_eq!(a, a);
    assert_eq!(a, b);
    assert_eq!(b, a);
    assert_eq!(b, c);
    assert_eq!(a, c);
    // Ningún flow, raíz, prueba, CBID ni versión de caché entra en esta proyección.
    // Esto comprueba la política elegida, no que mutaciones de una prueba verifiquen.
    let mut otro = coordenadas();
    otro.piece_offset = 1;
    assert_ne!(a, red.clave_local(red, otro).unwrap());
    otro = coordenadas();
    otro.slot = 5;
    assert_ne!(a, red.clave_local(red, otro).unwrap());
}

#[test]
fn otra_red_no_es_otro_ticket_admisible_en_la_historia_local() {
    let red = DominioRed([1; 32]);
    assert_eq!(
        red.clave_local(DominioRed([2; 32]), coordenadas()),
        Err(RedAjena)
    );
}

#[test]
fn divergencia_futura_no_rechaza_pasado_comun_y_el_borde_es_inclusivo() {
    let a = descriptor(vec![evento(10, 1, 1600)], 20);
    let b = descriptor(vec![evento(10, 2, 1600)], 20);
    assert_eq!(comparar_en(&a, &b, 9), Compatibilidad::Compatible);
    assert_eq!(comparar_en(&a, &b, 10), Compatibilidad::Incompatible);
    assert_eq!(comparar_en(&a, &b, 20), Compatibilidad::Incompatible);
    assert_eq!(comparar_en(&a, &b, 21), Compatibilidad::Pendiente);
}

#[test]
fn omitir_n_confunde_relojes_con_las_mismas_entropias() {
    let a = descriptor(vec![evento(10, 1, 1600)], 20);
    let b = descriptor(vec![evento(10, 1, 3200)], 20);
    assert_eq!(comparar_en(&a, &b, 9), Compatibilidad::Compatible);
    assert_eq!(comparar_en(&a, &b, 10), Compatibilidad::Incompatible);
    let mut distinto = origen();
    distinto.iteraciones_iniciales = NonZeroU32::new(3200).unwrap();
    let c = DescriptorPotDeclarado::nuevo(distinto, vec![], 20).unwrap();
    assert_eq!(comparar_en(&a, &c, 0), Compatibilidad::Incompatible);
}

#[test]
fn anuncios_se_ordenan_pero_duplicados_no_se_aplican_dos_veces() {
    let eventos = vec![evento(5, 1, 1600), evento(10, 2, 3200)];
    let mut invertidos = eventos.clone();
    invertidos.reverse();
    assert_eq!(descriptor(eventos, 20), descriptor(invertidos, 20));
    assert_eq!(
        DescriptorPotDeclarado::nuevo(origen(), vec![evento(5, 1, 1600); 2], 20),
        Err(ErrorDescriptor::EventosSuperpuestos)
    );
}

#[test]
fn cobertura_y_convencion_de_origen_se_comprueban_sin_certificar_procedencia() {
    assert_eq!(
        DescriptorPotDeclarado::nuevo(origen(), vec![evento(21, 1, 1600)], 20),
        Err(ErrorDescriptor::EventoFueraDelHorizonte)
    );
    assert_eq!(
        DescriptorPotDeclarado::nuevo(origen(), vec![evento(0, 1, 1600)], 20),
        Err(ErrorDescriptor::EventoFueraDelHorizonte)
    );
    let mut posterior = origen();
    posterior.slot_inicial = 5;
    assert_eq!(
        DescriptorPotDeclarado::nuevo(posterior, vec![], 4),
        Err(ErrorDescriptor::HorizonteAnteriorAlOrigen)
    );
}

#[test]
fn cada_antecedente_se_compara_en_su_slot_no_en_la_punta_actual() {
    let a = descriptor(vec![evento(10, 1, 1600)], 30);
    let b = descriptor(vec![evento(10, 2, 1600)], 30);
    assert_eq!(comparar_pasado(&a, &[(&b, 9)]), Compatibilidad::Compatible);
    assert_eq!(
        comparar_pasado(&a, &[(&b, 10)]),
        Compatibilidad::Incompatible
    );
    assert_eq!(comparar_pasado(&a, &[(&a, 25)]), Compatibilidad::Compatible);
    assert_eq!(comparar_pasado(&a, &[(&a, 31)]), Compatibilidad::Pendiente);
    // La API no inventa slot(B) ni extiende a todos los padres el límite de SP.
}

#[test]
fn evidencia_de_incompatibilidad_conocida_no_depende_del_orden_de_lectura() {
    let a = descriptor(vec![evento(10, 1, 1600)], 20);
    let b = descriptor(vec![evento(10, 2, 1600)], 20);
    assert_eq!(
        comparar_pasado(&a, &[(&a, 30), (&b, 10)]),
        Compatibilidad::Incompatible
    );
    assert_eq!(
        comparar_pasado(&a, &[(&b, 10), (&a, 30)]),
        Compatibilidad::Incompatible
    );
}
