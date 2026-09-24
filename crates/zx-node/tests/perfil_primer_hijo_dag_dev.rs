//! Pruebas de integración del contexto dev del primer hijo DAG (incremento A2/A3 parcial).
//!
//! # Qué distingue un puente real de un mock
//!
//! El contexto [`ContextoPrimerHijoPotDagDev`] no es un doble de prueba: implementa los rasgos
//! `InstantaneaPot` y `ContextoRangoDag` del núcleo `zx-consensus` con datos derivados del
//! bootstrap dev **real** y constantes privadas del perfil. Estas pruebas comprueban que:
//!
//! - el pasado es exactamente `{G}` con `slot = 0` y flujo `f_0`, y que `N`, el ancla, las
//!   inyecciones y `D` salen del perfil/bootstrap, no de los campos de la cabecera;
//! - la ventana `1..=150` y los fallos de topología se conservan como errores tipados;
//! - un **portador PoT real** de `zx-pot` verifica con el núcleo `verificar_rango_pot` desde el
//!   ancla confiada del slot 0; un checkpoint mutado da `AesFallido` y un `pot_output` alterado da
//!   `PotOutputNoCoincide`;
//! - el `SR` esperado es `u64::MAX` y el declarado distinto se rechaza;
//! - el límite de identidad: `ContextoRangoDag` no puede separar dos cabeceras con los mismos
//!   padres/slot por su vista opaca, y el getter del hash sí las separa. La futura admisión deberá
//!   cotejar la identidad **antes** de usar A3.
//!
//! **No** se verifica PoAS, sello, cuerpo ni admisión, y no se presenta el método contextual
//! aislado como puerta de admisión.
//!
//! El coste de la prueba con portador real es el de un `prove` de `N = 200_032_000` iteraciones:
//! ~15,9 s en perfil `dev` en esta máquina. La cifra histórica de ~1,56 s corresponde a un
//! `cargo bench` optimizado, **no** a esta prueba de test sin etiqueta. No se rebaja `N` para
//! acelerarla.

#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    reason = "los tests fallan con panic por diseño; índices sobre arrays de anchura fija"
)]

use core::num::NonZeroU32;

use zx_consensus::pot_rango::{
    CachePotVerificada, EstadoPot, InstantaneaPot, InyeccionesPot, MotivoPotInvalido,
    MotivoPotPendiente, PresupuestoPot, verificar_rango_pot,
};
use zx_consensus::{
    ConsensusError, RangoSolucionValidado, checkpoints_a_wire, comprobar_padres_contextual,
    comprobar_rango_contextual, semilla_siguiente,
};
use zx_core::digest::{BlockHash, BodyCommitment, Digest, MerkleRoot};
use zx_core::preimage::dag::{DagBlockHeader, PadresDag, SolucionPoas};
use zx_core::wire_dag::{JustificacionPot, PotCheckpoints};
use zx_pot::tipos::PotSeed;

use zx_node::bootstrap_dag_dev::iniciar_bootstrap_dag_dev;
use zx_node::contexto_genesis_dag_dev::ErrorContextoPrimerHijoDev;
use zx_node::perfil_primer_hijo_dag_dev::{ContextoPrimerHijoPotDagDev, ErrorPerfilPrimerHijoDev};

/// `N` del perfil dev, repetido aquí como literal independiente: la constante del módulo es privada
/// y la prueba no la importa para no convertir el test en una tautología.
const N_PERFIL_DEV: u32 = 200_032_000;

fn h(marca: u8) -> BlockHash {
    BlockHash::from_digest(Digest::from_bytes([marca; 32]))
}

/// Cabecera dev mínima. `padres`, `slot`, `pot_output` y `rango_solucion` se fijan por argumento;
/// `timestamp`, `height`, `merkle_root`, `body_commitment` y `sello` son deliberadamente fijos,
/// porque este contexto **MUST NOT** leerlos para definir `N`, `SR`, flujo, ancla ni inyecciones.
fn cabecera(
    padres: PadresDag,
    slot: u64,
    pot_output: [u8; 16],
    rango_solucion: u64,
) -> DagBlockHeader {
    DagBlockHeader {
        consensus_branch_id: 0x0D06_0001,
        merkle_root: MerkleRoot::from_digest(Digest::from_bytes([0x42; 32])),
        timestamp: 1_800_000_000,
        height: 1,
        slot,
        pot_output,
        rango_solucion,
        sol: SolucionPoas::default(),
        body_commitment: BodyCommitment::from_digest(Digest::from_bytes([0x24; 32])),
        padres,
        sello: [0u8; 64],
    }
}

/// Presupuesto explícito de **un** slot AES. No es un valor de consenso: lo elige la prueba.
#[derive(Default)]
struct PresupuestoUnSlot {
    consumido: bool,
}

impl PresupuestoPot for PresupuestoUnSlot {
    fn consumir_slot(&mut self, _slot: u64) -> bool {
        if self.consumido {
            false
        } else {
            self.consumido = true;
            true
        }
    }
}

// ── 1 · Todo sale de G y del perfil; la ventana y la topología fallan tipadas ───────────────────

#[test]
fn el_contexto_toma_todo_de_g_y_del_perfil_y_falla_fuera_de_la_ventana() {
    let bootstrap = iniciar_bootstrap_dag_dev().expect("el bootstrap dev MUST arrancar");
    let genesis = bootstrap.hash_congelado_dev();
    let f0 = bootstrap.f0_dev();
    let ancla = bootstrap.ancla_pot_slot_0_dev();

    let padres = PadresDag::nuevo(genesis, &[]).expect("padres canónicos");
    let cabecera_hija = cabecera(padres, 1, [0x11; 16], u64::MAX);
    let contexto =
        ContextoPrimerHijoPotDagDev::desde_bootstrap_y_cabecera(&bootstrap, &cabecera_hija)
            .expect("el contexto dev MUST construirse con {G} y slot 1");

    assert_eq!(contexto.hash_candidato(), cabecera_hija.block_hash());
    assert_eq!(contexto.slot_candidato(), 1);
    assert_eq!(
        contexto.vista().len(),
        1,
        "la vista estructural es exactamente {{G}}"
    );

    // Pasado exacto: G, slot 0, f_0.
    let pasado = InstantaneaPot::pasado(&contexto).expect("el pasado está disponible");
    assert_eq!(pasado.len(), 1);
    let registro = pasado.first().expect("un solo ancestro G");
    assert_eq!(registro.hash, genesis);
    assert_eq!(registro.slot, 0, "C-HDR-05: G tiene slot 0");
    assert_eq!(registro.flujo, f0);

    // El ancla confiada solo en el slot 0; cualquier otro slot es contexto ausente.
    assert_eq!(
        InstantaneaPot::salida_validada(&contexto, 0).expect("ancla del slot 0"),
        ancla
    );
    assert!(matches!(
        InstantaneaPot::salida_validada(&contexto, 1),
        Err(MotivoPotPendiente::ContextoAusente { .. })
    ));

    // Flujo: f_0 en 0..=1; fuera de la ventana, contexto ausente.
    assert_eq!(InstantaneaPot::flujo_candidato_en(&contexto, 0), Ok(f0));
    assert_eq!(InstantaneaPot::flujo_candidato_en(&contexto, 1), Ok(f0));
    assert!(matches!(
        InstantaneaPot::flujo_candidato_en(&contexto, 2),
        Err(MotivoPotPendiente::ContextoAusente { .. })
    ));

    // N(s): el del perfil dev solo en 1..=1.
    assert_eq!(
        InstantaneaPot::iteraciones(&contexto, 1),
        Ok(u64::from(N_PERFIL_DEV))
    );
    assert!(matches!(
        InstantaneaPot::iteraciones(&contexto, 0),
        Err(MotivoPotPendiente::ContextoAusente { .. })
    ));
    assert!(matches!(
        InstantaneaPot::iteraciones(&contexto, 2),
        Err(MotivoPotPendiente::ContextoAusente { .. })
    ));

    // Sin inyecciones en 1..=1; fuera de la ventana, contexto ausente.
    assert_eq!(
        InstantaneaPot::inyecciones_en(&contexto, 1),
        Ok(InyeccionesPot::Ninguna)
    );
    assert!(matches!(
        InstantaneaPot::inyecciones_en(&contexto, 0),
        Err(MotivoPotPendiente::ContextoAusente { .. })
    ));

    // D_dev = 0 y rango esperado fijo `u64::MAX`.
    assert_eq!(InstantaneaPot::retardo_autoria(&contexto), Ok(0));
    let validado = RangoSolucionValidado::validar(&cabecera_hija, &contexto)
        .expect("el rango declarado coincide con el fijo del perfil dev");
    assert_eq!(validado.valor(), u64::MAX);
    assert_eq!(validado.bloque(), Some(cabecera_hija.block_hash()));

    // Ventana dev: slot 0 y slot 151 quedan fuera y el constructor lo diagnostica.
    let cabecera_slot_0 = cabecera(
        PadresDag::nuevo(genesis, &[]).expect("padres canónicos"),
        0,
        [0x12; 16],
        u64::MAX,
    );
    assert!(matches!(
        ContextoPrimerHijoPotDagDev::desde_bootstrap_y_cabecera(&bootstrap, &cabecera_slot_0),
        Err(ErrorPerfilPrimerHijoDev::SlotFueraDeVentana { slot: 0, .. })
    ));
    let cabecera_slot_151 = cabecera(
        PadresDag::nuevo(genesis, &[]).expect("padres canónicos"),
        151,
        [0x13; 16],
        u64::MAX,
    );
    assert!(matches!(
        ContextoPrimerHijoPotDagDev::desde_bootstrap_y_cabecera(&bootstrap, &cabecera_slot_151),
        Err(ErrorPerfilPrimerHijoDev::SlotFueraDeVentana { slot: 151, .. })
    ));

    // Padres ajenos o extras: fallo tipado de vista, no «cabecera inválida».
    let ajenos = PadresDag::nuevo(h(0xAB), &[]).expect("padres canónicos");
    let cabecera_ajena = cabecera(ajenos, 1, [0x14; 16], u64::MAX);
    assert!(matches!(
        ContextoPrimerHijoPotDagDev::desde_bootstrap_y_cabecera(&bootstrap, &cabecera_ajena),
        Err(ErrorPerfilPrimerHijoDev::Vista(
            ErrorContextoPrimerHijoDev::FueraDeAlcance
        ))
    ));
    let con_extra = PadresDag::nuevo(genesis, &[h(0xCD)]).expect("padres canónicos");
    let cabecera_extra = cabecera(con_extra, 1, [0x15; 16], u64::MAX);
    assert!(matches!(
        ContextoPrimerHijoPotDagDev::desde_bootstrap_y_cabecera(&bootstrap, &cabecera_extra),
        Err(ErrorPerfilPrimerHijoDev::Vista(
            ErrorContextoPrimerHijoDev::FueraDeAlcance
        ))
    ));
}

// ── 2 · Portador real desde el ancla confiada: núcleo PoT, AesFallido y PotOutputNoCoincide ────

#[test]
fn el_nucleo_pot_verifica_un_portador_real_desde_el_ancla_confiada() {
    let bootstrap = iniciar_bootstrap_dag_dev().expect("el bootstrap dev MUST arrancar");
    let genesis = bootstrap.hash_congelado_dev();
    let ancla = bootstrap.ancla_pot_slot_0_dev();

    // Portador real del slot 1: semilla = ancla (sin inyección, C-POT-01) y N del perfil dev.
    let semilla = semilla_siguiente(ancla, None);
    let portador_primitiva = zx_pot::prove(
        PotSeed::from(semilla),
        NonZeroU32::new(N_PERFIL_DEV).expect("N > 0"),
    )
    .expect("N múltiplo de 16");
    let portador = checkpoints_a_wire(&portador_primitiva);
    let pot_output = *portador_primitiva.output();

    let padres = PadresDag::nuevo(genesis, &[]).expect("padres canónicos");
    let cabecera_hija = cabecera(padres, 1, pot_output, u64::MAX);
    let justificacion = JustificacionPot::nueva(vec![portador]).expect("un portador");
    let contexto =
        ContextoPrimerHijoPotDagDev::desde_bootstrap_y_cabecera(&bootstrap, &cabecera_hija)
            .expect("el contexto dev MUST construirse");

    let mut cache = CachePotVerificada::nueva();
    let mut presupuesto = PresupuestoUnSlot::default();
    let estado = verificar_rango_pot(
        &cabecera_hija,
        &justificacion,
        &contexto,
        1,
        &mut cache,
        &mut presupuesto,
    );
    assert!(
        matches!(&estado, EstadoPot::PotValido(_)),
        "se esperaba PotValido, llegó {estado:?}"
    );
    assert!(
        presupuesto.consumido,
        "el presupuesto de un slot MUST consumirse"
    );

    // La API pública no expone la salida auditada (`PruebaPotValidada` tiene getters `pub(crate)`).
    // Con `D = 0` la posición auditada coincide con `pot_output`, así que el `PotValido` ya obliga a
    // que el núcleo la tomara del portador verificado; aquí se comprueba además el determinismo.
    let mut cache_repetida = CachePotVerificada::nueva();
    let mut presupuesto_repetido = PresupuestoUnSlot::default();
    let repetido = verificar_rango_pot(
        &cabecera_hija,
        &justificacion,
        &contexto,
        1,
        &mut cache_repetida,
        &mut presupuesto_repetido,
    );
    assert_eq!(estado, repetido, "el núcleo es determinista");

    // Un checkpoint mutado es un defecto del candidato: AesFallido, nunca contexto.
    let mut outputs = portador.outputs();
    let primero = outputs.first_mut().expect("hay ocho checkpoints");
    primero[0] ^= 1;
    let portador_roto = PotCheckpoints::desde_outputs(outputs);
    let justificacion_rota = JustificacionPot::nueva(vec![portador_roto]).expect("un portador");
    let mut cache_rota = CachePotVerificada::nueva();
    let mut presupuesto_roto = PresupuestoUnSlot::default();
    let estado_roto = verificar_rango_pot(
        &cabecera_hija,
        &justificacion_rota,
        &contexto,
        1,
        &mut cache_rota,
        &mut presupuesto_roto,
    );
    assert_eq!(
        estado_roto,
        EstadoPot::PotInvalido(MotivoPotInvalido::AesFallido { slot: 1 })
    );

    // Solo el `pot_output` alterado, con contexto reconstruido para esa cabecera: no cuadra.
    let mut pot_output_roto = pot_output;
    pot_output_roto[0] ^= 1;
    let cabecera_pot_roto = cabecera(
        PadresDag::nuevo(genesis, &[]).expect("padres canónicos"),
        1,
        pot_output_roto,
        u64::MAX,
    );
    let contexto_pot_roto =
        ContextoPrimerHijoPotDagDev::desde_bootstrap_y_cabecera(&bootstrap, &cabecera_pot_roto)
            .expect("el contexto dev MUST reconstruirse");
    let mut cache_pot_roto = CachePotVerificada::nueva();
    let mut presupuesto_pot_roto = PresupuestoUnSlot::default();
    let estado_pot_roto = verificar_rango_pot(
        &cabecera_pot_roto,
        &justificacion,
        &contexto_pot_roto,
        1,
        &mut cache_pot_roto,
        &mut presupuesto_pot_roto,
    );
    assert!(
        matches!(
            estado_pot_roto,
            EstadoPot::PotInvalido(MotivoPotInvalido::PotOutputNoCoincide { .. })
        ),
        "se esperaba PotOutputNoCoincide, llegó {estado_pot_roto:?}"
    );
}

// ── 3 · El contexto no depende de los campos del candidato; el rango distinto se rechaza ────────

#[test]
fn el_contexto_no_se_deriva_de_los_campos_del_candidato_y_rechaza_el_rango_distinto() {
    let bootstrap = iniciar_bootstrap_dag_dev().expect("el bootstrap dev MUST arrancar");
    let genesis = bootstrap.hash_congelado_dev();
    let padres = PadresDag::nuevo(genesis, &[]).expect("padres canónicos");

    let cabecera_a = cabecera(padres, 1, [0x11; 16], u64::MAX);

    // Misma topología y slot; `pot_output`, `timestamp`, `height` y `rango_solucion` distintos.
    let mut cabecera_b = cabecera(padres, 1, [0x22; 16], 7);
    cabecera_b.timestamp += 99;
    cabecera_b.height = 5;

    assert_ne!(
        cabecera_a.block_hash(),
        cabecera_b.block_hash(),
        "las dos cabeceras MUST tener hashes distintos"
    );

    let contexto_a =
        ContextoPrimerHijoPotDagDev::desde_bootstrap_y_cabecera(&bootstrap, &cabecera_a)
            .expect("contexto A");
    let contexto_b =
        ContextoPrimerHijoPotDagDev::desde_bootstrap_y_cabecera(&bootstrap, &cabecera_b)
            .expect("contexto B");

    // Los valores del perfil y de G son idénticos: no dependen de los campos del candidato.
    assert_eq!(
        InstantaneaPot::pasado(&contexto_a),
        InstantaneaPot::pasado(&contexto_b)
    );
    assert_eq!(
        InstantaneaPot::flujo_candidato_en(&contexto_a, 1),
        InstantaneaPot::flujo_candidato_en(&contexto_b, 1)
    );
    assert_eq!(
        InstantaneaPot::iteraciones(&contexto_a, 1),
        InstantaneaPot::iteraciones(&contexto_b, 1)
    );
    assert_eq!(
        InstantaneaPot::inyecciones_en(&contexto_a, 1),
        InstantaneaPot::inyecciones_en(&contexto_b, 1)
    );
    assert_eq!(
        InstantaneaPot::salida_validada(&contexto_a, 0),
        InstantaneaPot::salida_validada(&contexto_b, 0)
    );
    assert_eq!(
        InstantaneaPot::retardo_autoria(&contexto_a),
        InstantaneaPot::retardo_autoria(&contexto_b)
    );

    // La identidad del candidato sí difiere.
    assert_ne!(contexto_a.hash_candidato(), contexto_b.hash_candidato());

    // El rango declarado distinto del fijo se rechaza; nunca se convierte en esperado.
    assert_eq!(
        RangoSolucionValidado::validar(&cabecera_b, &contexto_b),
        Err(ConsensusError::RangoIncorrecto {
            esperado: u64::MAX,
            encontrado: 7
        })
    );
    assert!(comprobar_rango_contextual(&cabecera_b, &contexto_b).is_err());
    assert!(comprobar_rango_contextual(&cabecera_a, &contexto_a).is_ok());
}

// ── 4 · Límite de identidad: la vista opaca no ata; el hash guardado sí distingue ──────────────

/// Demuestra el **límite**, no una admisión.
///
/// `ContextoRangoDag::rango_esperado` recibe `CandidatoSinRango`, que no expone el hash: con los
/// mismos padres `{G}` y el mismo `slot`, el contexto construido para `A` devuelve el `SR` esperado
/// para `B`. El getter [`ContextoPrimerHijoPotDagDev::hash_candidato`] sí separa las dos
/// cabeceras, y la futura ruta de admisión **MUST** cotejarlo antes de llamar a A3. Este test no
/// presenta el método contextual aislado como puerta de admisión.
#[test]
fn el_contexto_de_rango_no_ata_la_identidad_y_el_hash_si_las_distingue() {
    let bootstrap = iniciar_bootstrap_dag_dev().expect("el bootstrap dev MUST arrancar");
    let genesis = bootstrap.hash_congelado_dev();
    let padres = PadresDag::nuevo(genesis, &[]).expect("padres canónicos");

    let cabecera_a = cabecera(padres, 1, [0x11; 16], u64::MAX);
    let cabecera_b = cabecera(padres, 1, [0x33; 16], u64::MAX);
    assert_ne!(cabecera_a.block_hash(), cabecera_b.block_hash());

    let contexto_a =
        ContextoPrimerHijoPotDagDev::desde_bootstrap_y_cabecera(&bootstrap, &cabecera_a)
            .expect("contexto A");

    // LÍMITE: el contexto de A devuelve el `SR` esperado para B, que no es su candidato.
    assert!(
        comprobar_rango_contextual(&cabecera_b, &contexto_a).is_ok(),
        "la vista opaca no vincula la cabecera con el candidato del contexto"
    );

    // El getter del hash sí distingue las dos cabeceras.
    assert_eq!(contexto_a.hash_candidato(), cabecera_a.block_hash());
    assert_ne!(contexto_a.hash_candidato(), cabecera_b.block_hash());
}

// ── 5 · `dag()` entrega el contexto DAG; los padres se comprueban, la identidad no ─────────────

/// `contexto.dag()` es el `ContextoDag` que A3 espera: pasa `{G}` y rechaza un padre ajeno.
///
/// Esto comprueba **padres**, no identidad ni validez global: la vista opaca sigue sin atar el
/// `block_hash` de la cabecera (ver el test del límite de identidad arriba).
#[test]
fn el_contexto_dag_comprueba_padres_con_g_y_rechaza_al_ajeno() {
    let bootstrap = iniciar_bootstrap_dag_dev().expect("el bootstrap dev MUST arrancar");
    let genesis = bootstrap.hash_congelado_dev();

    let padres = PadresDag::nuevo(genesis, &[]).expect("padres canónicos");
    let hija = cabecera(padres, 1, [0x11; 16], u64::MAX);
    let contexto = ContextoPrimerHijoPotDagDev::desde_bootstrap_y_cabecera(&bootstrap, &hija)
        .expect("el contexto dev MUST construirse con {G} y slot 1");

    assert!(
        comprobar_padres_contextual(&hija, contexto.dag()).is_ok(),
        "el contexto DAG del primer hijo MUST satisfacer la comprobación de padres"
    );

    let ajenos = PadresDag::nuevo(h(0xAB), &[]).expect("padres canónicos");
    let hija_ajena = cabecera(ajenos, 1, [0x12; 16], u64::MAX);
    assert_eq!(
        comprobar_padres_contextual(&hija_ajena, contexto.dag()),
        Err(ConsensusError::PadreNoValidado { padre: h(0xAB) })
    );
}

// ── 6 · Diferible: el contexto de rango no es permanencia y no se confunde con rango malo ──────

/// La falta de contexto no es un rechazo permanente: no se cachea como inválido.
#[test]
fn el_contexto_de_rango_no_se_cachea_como_rechazo_permanente() {
    assert!(
        !ConsensusError::ContextoRangoNoDisponible { motivo: "prueba" }.es_permanente(),
        "la falta de contexto es diferible; MUST NOT cachearse como rechazo permanente"
    );
    // `C-TS-03` sigue difiriendo y la clasificación general no se anula: un rechazo permanente
    // ya existente sigue siéndolo.
    assert!(!ConsensusError::TimestampDemasiadoFuturo { ts: 0, limite: 0 }.es_permanente());
    assert!(
        ConsensusError::RangoIncorrecto {
            esperado: 0,
            encontrado: 1
        }
        .es_permanente()
    );
    assert!(ConsensusError::PowInsuficiente.es_permanente());
}

/// Un rango que la vista no puede resolver da `ContextoRangoNoDisponible`, nunca `RangoIncorrecto`
/// ni `Ok`; con el slot guardado y un declarado distinto del fijo, sí es `RangoIncorrecto`.
#[test]
fn el_rango_fuera_de_la_vista_es_contexto_y_no_rango_incorrecto() {
    let bootstrap = iniciar_bootstrap_dag_dev().expect("el bootstrap dev MUST arrancar");
    let genesis = bootstrap.hash_congelado_dev();
    let padres = PadresDag::nuevo(genesis, &[]).expect("padres canónicos");

    let cabecera_guardada = cabecera(padres, 1, [0x11; 16], u64::MAX);
    let contexto =
        ContextoPrimerHijoPotDagDev::desde_bootstrap_y_cabecera(&bootstrap, &cabecera_guardada)
            .expect("contexto dev con slot 1");

    // Mismo `{G}` pero otro slot: el contexto no resuelve el rango esperado de esa vista.
    let cabecera_otro_slot = cabecera(padres, 2, [0x12; 16], u64::MAX);
    assert!(
        matches!(
            RangoSolucionValidado::validar(&cabecera_otro_slot, &contexto),
            Err(ConsensusError::ContextoRangoNoDisponible { .. })
        ),
        "un slot fuera de la vista MUST dar contexto no disponible"
    );

    // Mismo slot y rango declarado distinto del fijo: eso sí es `RangoIncorrecto`.
    let cabecera_rango_malo = cabecera(padres, 1, [0x13; 16], 7);
    assert_eq!(
        RangoSolucionValidado::validar(&cabecera_rango_malo, &contexto),
        Err(ConsensusError::RangoIncorrecto {
            esperado: u64::MAX,
            encontrado: 7
        })
    );
}
