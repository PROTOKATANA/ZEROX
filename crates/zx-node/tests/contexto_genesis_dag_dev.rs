//! Pruebas de integración de la vista causal del primer hijo DAG dev (incremento C1/A2).
//!
//! # Qué prueba y qué no
//!
//! Comprueba que con el bootstrap dev real y la topología `{G}`:
//!
//! - el pasado es **exactamente** `{G}`, con `slot = 0` y padres de génesis;
//! - `f_0` y el ancla confiada del slot 0 son los getters del bootstrap, no recálculos;
//! - el snapshot no depende más que del `hash_candidato` (y solo para detectar autociclo);
//! - las topologías fuera de alcance y el autociclo dan errores tipados distintos;
//! - `comprobar_padres_contextual` sobre una cabecera hija con `{G}` pasa **solo** la comprobación
//!   de padres, y las claves ajenas fallan sin valores por defecto;
//! - el snapshot **no vincula** el `hash_candidato` con el `block_hash` de la cabecera comprobada:
//!   el test `el_snapshot_no_acredita_el_hash_de_la_cabecera_comprobada` documenta ese límite, no
//!   un rechazo.
//!
//! **No** verifica PoT, PoAS, sello ni admisión: `G` es la raíz confiada del perfil dev, no un
//! bloque que superó PoST. La ausencia de una API que convierta el snapshot en `InstantaneaPot` o
//! que escriba el índice de admitidos se comprueba por revisión de API, no con este archivo.

#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    reason = "los tests fallan con panic por diseño; índices sobre arrays de anchura fija"
)]

use zx_consensus::{ConsensusError, ContextoDag, comprobar_padres_contextual};
use zx_core::digest::{BlockHash, BodyCommitment, Digest, MerkleRoot};
use zx_core::preimage::dag::{DagBlockHeader, PadresDag, SolucionPoas};

use zx_node::bootstrap_dag_dev::iniciar_bootstrap_dag_dev;
use zx_node::contexto_genesis_dag_dev::{ErrorContextoPrimerHijoDev, instantanea_primer_hijo};
use zx_node::dag_causal::ErrorVistaCausal;

/// `block_hash` congelado del fixture dev. Es un literal independiente: no se recalcula del bloque.
const HASH_DEV: [u8; 32] = [
    4, 0, 228, 160, 3, 45, 150, 243, 155, 108, 165, 251, 38, 47, 168, 55, 66, 41, 232, 57, 230, 84,
    144, 102, 6, 224, 105, 216, 129, 184, 225, 127,
];

fn h(marca: u8) -> BlockHash {
    BlockHash::from_digest(Digest::from_bytes([marca; 32]))
}

/// Cabecera de la prueba de padres. `timestamp: 0` es deliberado: **ninguna** función de esta
/// prueba mira la marca temporal —ni `instantanea_primer_hijo` ni `comprobar_padres_contextual`
/// comprueban la regla temporal—. Reutilizar `TIMESTAMP_DEV = 1_800_000_000` del bootstrap tampoco
/// acreditaría un reloj: ese valor es aún futuro a 2026-09-24 y no se cambia aquí el fixture de
/// bootstrap ni su hash.
fn cabecera(padres: PadresDag, slot: u64, marca: u8) -> DagBlockHeader {
    DagBlockHeader {
        consensus_branch_id: 0x0D06_0001,
        merkle_root: MerkleRoot::from_digest(Digest::from_bytes([marca; 32])),
        timestamp: 0,
        height: 1,
        slot,
        pot_output: [marca; 16],
        rango_solucion: u64::from(marca),
        sol: SolucionPoas::default(),
        body_commitment: BodyCommitment::from_digest(Digest::from_bytes([marca; 32])),
        padres,
        sello: [marca; 64],
    }
}

// ── 1 · Pasado exactamente `{G}` y datos tomados del bootstrap ────────────────────────────────

#[test]
fn el_primer_hijo_da_exactamente_g_y_los_datos_del_bootstrap() {
    let bootstrap = iniciar_bootstrap_dag_dev().expect("el bootstrap dev MUST arrancar");
    let genesis = bootstrap.hash_congelado_dev();
    assert_eq!(
        genesis.as_bytes(),
        &HASH_DEV,
        "el génesis del contexto MUST ser el hash congelado"
    );

    let padres = PadresDag::nuevo(genesis, &[]).expect("padres canónicos");
    let instantanea = instantanea_primer_hijo(&bootstrap, &padres, h(0xAB))
        .expect("vista estructural construida");

    let ancestros = instantanea.vista().ancestros();
    assert_eq!(ancestros.len(), 1, "el pasado es exactamente {{G}}");
    let registro = ancestros.first().expect("un solo ancestro G");
    assert_eq!(registro.hash(), genesis);
    assert_eq!(registro.slot(), 0, "C-HDR-05: el génesis tiene slot 0");
    assert!(
        registro.padres().es_genesis(),
        "el registro G conserva los padres de génesis"
    );
    assert!(instantanea.vista().contiene(&genesis));

    assert_eq!(instantanea.hash_genesis_dev(), genesis);
    assert_eq!(instantanea.f0_dev(), bootstrap.f0_dev());
    assert_eq!(
        instantanea.ancla_pot_slot_0_dev(),
        bootstrap.ancla_pot_slot_0_dev()
    );

    // El snapshot solo usa `hash_candidato` para detectar autociclo: otro hash de candidato deja
    // el mismo pasado. No hay ningún campo libre del candidato que pueda alterarlo.
    let con_otro_candidato = instantanea_primer_hijo(&bootstrap, &padres, h(0x99))
        .expect("vista estructural construida con otro candidato");
    assert_eq!(instantanea, con_otro_candidato);
}

// ── 2 · Topologías fuera de alcance y autociclo, con errores tipados distintos ─────────────────

#[test]
fn las_topologias_fuera_de_alcance_no_son_invalidez() {
    let bootstrap = iniciar_bootstrap_dag_dev().expect("el bootstrap dev MUST arrancar");
    let genesis = bootstrap.hash_congelado_dev();

    // Padre desconocido: ni siquiera es G.
    let ajeno = PadresDag::nuevo(h(0xAB), &[]).expect("padres canónicos");
    assert_eq!(
        instantanea_primer_hijo(&bootstrap, &ajeno, h(0x01)),
        Err(ErrorContextoPrimerHijoDev::FueraDeAlcance)
    );

    // Extra adicional: {G, X}.
    let con_extra = PadresDag::nuevo(genesis, &[h(0xCD)]).expect("padres canónicos");
    assert_eq!(
        instantanea_primer_hijo(&bootstrap, &con_extra, h(0x01)),
        Err(ErrorContextoPrimerHijoDev::FueraDeAlcance)
    );

    // Cero padres.
    assert_eq!(
        instantanea_primer_hijo(&bootstrap, &PadresDag::genesis(), h(0x01)),
        Err(ErrorContextoPrimerHijoDev::FueraDeAlcance)
    );
}

#[test]
fn el_autociclo_conserva_candidato_en_su_pasado() {
    let bootstrap = iniciar_bootstrap_dag_dev().expect("el bootstrap dev MUST arrancar");
    let genesis = bootstrap.hash_congelado_dev();
    let padres = PadresDag::nuevo(genesis, &[]).expect("padres canónicos");

    // El candidato es G y su padre es G: autociclo. MUST conservarse como `CandidatoEnSuPasado`,
    // no disfrazarse de `FueraDeAlcance` ni de `PresupuestoAgotado`.
    assert_eq!(
        instantanea_primer_hijo(&bootstrap, &padres, genesis),
        Err(ErrorContextoPrimerHijoDev::Vista(
            ErrorVistaCausal::CandidatoEnSuPasado { hash: genesis }
        ))
    );
}

// ── 3 · `comprobar_padres_contextual` con el contexto mínimo ──────────────────────────────────

#[test]
fn comprobar_padres_contextual_solo_comprueba_padres_con_g() {
    let bootstrap = iniciar_bootstrap_dag_dev().expect("el bootstrap dev MUST arrancar");
    let genesis = bootstrap.hash_congelado_dev();
    let padres = PadresDag::nuevo(genesis, &[]).expect("padres canónicos");

    // La cabecera hija se construye **antes** del snapshot y su `block_hash()` es el candidato que
    // recibe `instantanea_primer_hijo`: la vista y la cabecera comprobada comparten el mismo dato,
    // no una coincidencia implícita. Aun así, el snapshot no *ata* ese hash (ver el test del
    // límite de identidad más abajo): solo lo usa para descartar el autociclo.
    let hija = cabecera(padres, 0, 0x42);
    let instantanea = instantanea_primer_hijo(&bootstrap, &padres, hija.block_hash())
        .expect("vista estructural construida");

    // Un hijo con {G} y slot(B) = 0: C-HDR-05 es no estricta, así que 0 ≤ 0 pasa. No se inventa
    // aquí ninguna regla slot(B) > 0 ni se afirma PoT.
    assert!(
        comprobar_padres_contextual(&hija, &instantanea).is_ok(),
        "el contexto mínimo MUST satisfacer la comprobación de padres"
    );

    // Una clave ajena falla: el padre no está validado en este contexto. Se reutiliza **el mismo**
    // snapshot solo para comprobar el rechazo de la clave ajena, no como prueba de vinculación del
    // candidato: el snapshot no ata el `block_hash` de la cabecera, así que no se afirma que
    // `hija_ajena` sea «el» candidato de la vista.
    let padres_ajenos = PadresDag::nuevo(h(0xAB), &[]).expect("padres canónicos");
    let hija_ajena = cabecera(padres_ajenos, 0, 0x43);
    assert_eq!(
        comprobar_padres_contextual(&hija_ajena, &instantanea),
        Err(ConsensusError::PadreNoValidado { padre: h(0xAB) })
    );

    // Consultas directas del trait con clave ajena: error contextual, sin `false`/`0` fabricados.
    assert_eq!(
        instantanea.slot_de_padre(&h(0xAB)),
        Err(ConsensusError::PadreNoValidado { padre: h(0xAB) })
    );
    assert_eq!(
        instantanea.esta_en_el_pasado_de(&h(0xAB), &genesis),
        Err(ConsensusError::BloqueDesconocido { hash: h(0xAB) })
    );
    assert_eq!(
        instantanea.esta_en_el_pasado_de(&genesis, &h(0xAB)),
        Err(ConsensusError::BloqueDesconocido { hash: h(0xAB) })
    );
    assert!(!instantanea.es_bloque_validado(&h(0xAB)));
    assert!(!instantanea.es_genesis(&h(0xAB)));

    // Y las consultas válidas responden con el dato del registro, no con un valor por defecto.
    assert_eq!(
        instantanea.slot_de_padre(&genesis).expect("G tiene slot"),
        0
    );
    assert_eq!(
        instantanea.padre_seleccionado(&padres).expect("sp = G"),
        genesis
    );
    assert!(instantanea.es_genesis(&genesis));
    assert!(
        !instantanea
            .esta_en_el_pasado_de(&genesis, &genesis)
            .expect("G no es su propio ancestro"),
        "el pasado es estricto: G no está en el pasado de G"
    );
}

// ── 4 · Límite de identidad: el snapshot no ata el hash de la cabecera ────────────────────────

/// El snapshot **no acredita** el `hash_candidato` frente a la cabecera que después se comprueba.
///
/// `instantanea_primer_hijo` usa `hash_candidato` **solo** para rechazar el autociclo en el pasado
/// declarado: no lo conserva ni lo coteja con ninguna cabecera, y `comprobar_padres_contextual`
/// solo mira los padres. Por eso otra cabecera con el mismo `{G}`, de `block_hash` distinto, pasa
/// contra el mismo snapshot aunque no sea el candidato de la vista.
///
/// Este test documenta el **límite**, no un rechazo garantizado: hoy no existe un método que
/// vincule el snapshot con el `block_hash` de la cabecera, así que un emparejamiento erróneo no se
/// detecta aquí. La futura ruta de admisión deberá derivar el `block_hash` de la cabecera que
/// realmente comprueba y conservar la asociación con el snapshot.
#[test]
fn el_snapshot_no_acredita_el_hash_de_la_cabecera_comprobada() {
    let bootstrap = iniciar_bootstrap_dag_dev().expect("el bootstrap dev MUST arrancar");
    let genesis = bootstrap.hash_congelado_dev();
    let padres = PadresDag::nuevo(genesis, &[]).expect("padres canónicos");

    // El snapshot se construyó para `hija`.
    let hija = cabecera(padres, 0, 0x42);
    let instantanea = instantanea_primer_hijo(&bootstrap, &padres, hija.block_hash())
        .expect("vista estructural construida");

    // Otra cabecera con el mismo `{G}` y hash distinto pasa la comprobación de padres: el snapshot
    // no la reconoce como ajena ni la rechaza por no ser el candidato de la vista.
    let otra = cabecera(padres, 0, 0x77);
    assert_ne!(
        otra.block_hash(),
        hija.block_hash(),
        "las dos cabeceras MUST tener hashes distintos para que el límite sea observable"
    );
    assert!(
        comprobar_padres_contextual(&otra, &instantanea).is_ok(),
        "la comprobación de padres no vincula el hash de la cabecera con el candidato del snapshot"
    );
}
