//! Test de integración de la costura A3/D2 del primer hijo DAG dev
//! (`zx_node::puerta_primer_hijo_dag_dev`; `C-POT-03`/`C-POT-05`/`C-POT-06`/`C-POT-08` y
//! `C-HDR-03`/`C-HDR-04`/`C-HDR-06`/`C-HDR-07`).
//!
//! # Qué ejercita de verdad
//!
//! - El **bootstrap congelado** `G` y **una sola** [`HistoriaDagDev`]: el archivo determinista que
//!   comparten productor y verificador.
//! - Un **ploteo real** de dos piezas bajo una clave que el firmador controla:
//!   `SigningKey::from([7u8; 32])` es la única fuente de la `VerificationKey`/`PublicKey` con la
//!   que se plotta y con la que se firma. No se plotta bajo una clave ajena al firmador.
//! - La **cadena PoT real** desde `bootstrap.ancla_pot_slot_0_dev()`, sin inyecciones, con
//!   `N(s)` leído del contexto dev ([`InstantaneaPot::iteraciones`]) y `SR` leído del contexto
//!   ([`RangoSolucionValidado::validar`]). Los portadores generados se retienen enteros: la
//!   justificación mide `slot` (`C-HDR-07`).
//! - La **auditoría de la parcela** con `convertir_candidatos_locales` y la verificación PoAS real
//!   del paso 5 de `C-POT-08`, con la misma historia y el mismo KZG.
//! - El **sello ZIP-215 real** sobre `pre_hash` (`C-HDR-04`) firmado por la clave del plot. La
//!   firma es **solo del test**: el registro firmante D3 no queda integrado, no se publica ni se
//!   registra nada y este test **no** afirma seguridad de producción.
//! - La función pública `verificar_primer_hijo_dag_dev` con reloj PoT explícito y un presupuesto de
//!   prueba que concede **exactamente** los slots generados; se exige `Comprobada` con el hash de la
//!   cabecera, el slot/salida auditados, la distancia A1 y el rango validado atados al mismo hash.
//! - Dos negativos: sello alterado ⇒ `Invalida(Sello)` sin consumir presupuesto AES, y `pot_output`
//!   alterado **y resellado** bajo la misma clave ⇒ `Invalida(Pot(PotOutputNoCoincide))`. El segundo
//!   no usa un sello roto para fingir un rechazo PoT.
//!
//! # Qué NO cubre, y por qué
//!
//! - **No es admisión.** No se comprueba cuerpo, UTXO, coinbase, orden GHOSTDAG ni red de tres
//!   nodos. `Comprobada` solo dice que las pruebas locales se satisficieron contra este contexto dev.
//! - **A3 no deriva altura ni rama ni comprueba el reloj de pared.** La `rama` y la `altura` del
//!   fixture son coherentes con `G` por construcción (misma rama dev, altura `G + 1`) y el
//!   `timestamp` avanza con el slot, pero **nadie las verifica** aquí; `reloj_pot` es el reloj PoT,
//!   no un reloj de pared.
//! - **`body_commitment` y `merkle_root` no acreditan cuerpo.** El bloque del test tiene cuerpo
//!   vacío y esos dos campos son marcadores: no se calculan sobre transacciones ni se comprueban.
//! - La historia dev **no es historia de red** ni un contexto causal general; `params_pieza` solo es
//!   el contexto de pieza coherente con este archivo determinista.
//!
//! El fixture pesado (archivado ~130 MB + ploteo + cadena PoT con `N` del perfil dev) se construye
//! una sola vez por proceso con [`OnceLock`] y lo comparten los tres tests.

#![cfg(feature = "farmer")]
#![expect(
    clippy::expect_used,
    reason = "instrumento de test: un fallo al construir o comprobar el fixture debe producir panic"
)]
#![expect(
    clippy::panic,
    reason = "los tests fallan con panic por diseño; los negativos discriminan por match"
)]

use std::path::PathBuf;
use std::sync::OnceLock;
use std::sync::atomic::{AtomicU64, Ordering};

use ed25519_zebra::{SigningKey, VerificationKey};
use subspace_core_primitives::PublicKey;
use subspace_core_primitives::sectors::SectorIndex;

use zx_consensus::{
    CachePotVerificada, EstadoCabeceraConjunta, InstantaneaPot, MotivoCabeceraInvalida,
    MotivoPotInvalido, PresupuestoPot, RangoSolucionValidado, checkpoints_a_wire,
    proyectar_iteraciones, semilla_siguiente,
};
use zx_core::wire_dag::{
    CHECKPOINTS_POR_BUNDLE, JustificacionPot, PotCheckpoints as PotCheckpointsWire,
};
use zx_core::{
    BloqueDag, BodyCommitment, DagBlockHeader, Digest, MerkleRoot, POT_OUTPUT_BYTES, PadresDag,
    SolucionPoas,
};
use zx_node::bootstrap_dag_dev::{EstadoBootstrapDagDev, iniciar_bootstrap_dag_dev};
use zx_node::farmer::{ParcelaDisco, plotear_sector_en_disco};
use zx_node::historia_dag_dev::HistoriaDagDev;
use zx_node::perfil_primer_hijo_dag_dev::ContextoPrimerHijoPotDagDev;
use zx_node::productor_poas::convertir_candidatos_locales;
use zx_node::puerta_primer_hijo_dag_dev::verificar_primer_hijo_dag_dev;
use zx_pot::tipos::PotSeed;

/// Piezas del sector de fixture (valor de desarrollo, igual que el resto de fixtures dev).
const PIEZAS: u16 = 2;
/// Índice de sector del fixture. Valor de test; no es un parámetro de red.
const INDICE_SECTOR: SectorIndex = 2;
/// Máximo de slots a recorrer buscando la primera solución A1. No es un parámetro de red.
const MAX_SLOTS_BUSQUEDA: u64 = 8;
/// `SR` **declarado** solo para que el contexto dev lo valide y devuelva el suyo.
///
/// No es el valor usado por el test por el hecho de declararlo: `RangoSolucionValidado::validar`
/// compara declarado y esperado y el test usa el `valor()` **validado** del contexto.
const SR_DECLARADO_PARA_DERIVAR: u64 = u64::MAX;

/// Fixture pesado compartido: historia, bootstrap, bloque comprobable y sus datos de auditoría.
struct Escenario {
    historia: HistoriaDagDev,
    bootstrap: EstadoBootstrapDagDev,
    bloque: BloqueDag,
    slot: u64,
    salida: [u8; POT_OUTPUT_BYTES],
    distancia: u64,
    sr: u64,
}

static ESCENARIO: OnceLock<Escenario> = OnceLock::new();

fn escenario() -> &'static Escenario {
    ESCENARIO.get_or_init(construir_escenario)
}

/// Construye, una sola vez, el escenario dev con primitivas reales.
fn construir_escenario() -> Escenario {
    let inicio = std::time::Instant::now();
    let historia = HistoriaDagDev::construir().expect("la historia archivada dev MUST construirse");
    let bootstrap = iniciar_bootstrap_dag_dev().expect("el bootstrap dev MUST arrancar");

    // La clave del plot sale del firmador: VerificationKey y PublicKey son la misma identidad.
    let sk = SigningKey::from([7u8; 32]);
    let vk = VerificationKey::from(&sk);
    let vk_bytes: [u8; 32] = vk.into();
    let public_key = PublicKey::from(vk_bytes);

    // `N(s)` y `SR` se leen del contexto dev, no de literales del test.
    let cabecera_perfil = cabecera_dev(&bootstrap, MAX_SLOTS_BUSQUEDA, SR_DECLARADO_PARA_DERIVAR);
    let contexto_perfil =
        ContextoPrimerHijoPotDagDev::desde_bootstrap_y_cabecera(&bootstrap, &cabecera_perfil)
            .expect("el contexto del perfil dev MUST construirse");
    let sr = RangoSolucionValidado::validar(&cabecera_perfil, &contexto_perfil)
        .expect("el SR declarado MUST ser el esperado por el contexto dev")
        .valor();

    let dir = DirTemporal::nuevo("a3-primer-hijo");
    let ruta = dir.unir("sector.plot");
    let inicio_ploteo = std::time::Instant::now();
    plotear_sector_en_disco(
        &ruta,
        &public_key,
        INDICE_SECTOR,
        PIEZAS,
        historia.historial(),
        historia.protocolo(),
        historia.kzg(),
        historia.erasure_coding(),
    )
    .expect("el ploteo del fixture A3 MUST funcionar");
    eprintln!(
        "[medición local, no consenso] ploteo A3: {:?}; hilos visibles: {}",
        inicio_ploteo.elapsed(),
        std::thread::available_parallelism().map_or(1, |n| n.get())
    );
    let parcela =
        ParcelaDisco::abrir(&ruta, &public_key).expect("la parcela del fixture MUST abrir");
    let params = historia.params_pieza();

    // Cadena PoT real desde el ancla confiada del slot 0, reteniendo todos los portadores.
    let mut salida_anterior = bootstrap.ancla_pot_slot_0_dev();
    let mut portadores: Vec<PotCheckpointsWire> = Vec::new();
    let mut hallado: Option<(u64, [u8; POT_OUTPUT_BYTES], SolucionPoas, u64)> = None;
    let mut slots_recorridos = 0u64;

    for slot in 1..=MAX_SLOTS_BUSQUEDA {
        // `N(s)` del contexto dev (`C-POT-04`/`C-POT-06`), no un literal del test.
        let n = contexto_perfil
            .iteraciones(slot)
            .expect("N(s) del perfil dev MUST estar en la ventana");
        let n_u32 = proyectar_iteraciones(n).expect("N del perfil dev MUST estar en el dominio");

        let semilla = semilla_siguiente(salida_anterior, None);
        let checkpoints =
            zx_pot::prove(PotSeed::from(semilla), n_u32).expect("N del perfil es múltiplo de 16");
        let wire = checkpoints_a_wire(&checkpoints);
        let salida_slot = wire.outputs()[CHECKPOINTS_POR_BUNDLE - 1];

        portadores.push(wire);
        salida_anterior = salida_slot;
        slots_recorridos += 1;

        let resultado = convertir_candidatos_locales(
            &parcela,
            salida_slot,
            slot,
            sr,
            &params,
            historia.kzg(),
            historia.erasure_coding(),
        )
        .expect("la conversión con el contexto del fixture MUST completarse");

        if let Some(primera) = resultado.soluciones().first().copied() {
            hallado = Some((slot, salida_slot, *primera.solucion(), primera.distancia()));
            break;
        }
    }

    let (slot, salida, sol, distancia) = hallado.unwrap_or_else(|| {
        panic!(
            "el fixture no produjo ninguna solución verificada por A1 en {slots_recorridos} slots \
             PoT encadenados desde el ancla dev con SR {sr}; no se fabrica una solución ni se \
             amplía el límite de {MAX_SLOTS_BUSQUEDA} slots"
        )
    });

    assert_eq!(
        usize::try_from(slot).expect("el slot cabe en usize"),
        portadores.len(),
        "C-HDR-07: el rango (0, slot] debe llevar exactamente `slot` portadores"
    );
    assert_eq!(
        sol.public_key.bytes(),
        &vk_bytes,
        "la solución MUST provenir de la clave del plot que el firmador controla"
    );

    // Cabecera `{G}`: rama y altura coherentes con G por construcción (A3 no las deriva ni las
    // comprueba); `body_commitment` y `merkle_root` son marcadores que NO acreditan cuerpo.
    let mut cabecera = cabecera_dev(&bootstrap, slot, sr);
    cabecera.pot_output = salida;
    cabecera.sol = sol;
    cabecera.sello = sk.sign(cabecera.pre_hash().as_bytes()).into();
    assert!(
        cabecera.verificar_sello().is_ok(),
        "el sello Ed25519 real del fixture MUST verificar"
    );

    let justificacion =
        JustificacionPot::nueva(portadores).expect("la lista de portadores del rango es canónica");
    let bloque = BloqueDag::nuevo(cabecera, justificacion, Vec::new(), Vec::new())
        .expect("bloque sin cuerpo");

    eprintln!(
        "[medición local, no consenso] A3/primer hijo: primera solución A1 en el slot {slot} tras \
         {slots_recorridos} slots PoT; tiempo total {:?}",
        inicio.elapsed()
    );

    Escenario {
        historia,
        bootstrap,
        bloque,
        slot,
        salida,
        distancia,
        sr,
    }
}

/// Cabecera dev con padres `{G}`. Los compromisos de cuerpo son marcadores **elegidos para test**.
fn cabecera_dev(
    bootstrap: &EstadoBootstrapDagDev,
    slot: u64,
    rango_solucion: u64,
) -> DagBlockHeader {
    let genesis = &bootstrap.bloque_dev().cabecera;
    DagBlockHeader {
        // Coherente con G; este test **no** comprueba C-HDR-02b.
        consensus_branch_id: genesis.consensus_branch_id,
        // Marcador: no acredita cuerpo (el bloque del test tiene cuerpo vacío).
        merkle_root: MerkleRoot::from_digest(Digest::from_bytes([0xA1; 32])),
        // Posterior al timestamp de G; A3 no comprueba reloj de pared ni §7.4.
        timestamp: genesis.timestamp.saturating_add(slot),
        // Altura coherente con G por construcción; A3 no la deriva (C-HDR-02).
        height: genesis.height.saturating_add(1),
        slot,
        // Se sobrescribe con la salida auditada en el bloque positivo.
        pot_output: [0u8; POT_OUTPUT_BYTES],
        rango_solucion,
        sol: SolucionPoas::default(),
        // Marcador: no acredita cuerpo.
        body_commitment: BodyCommitment::from_digest(Digest::from_bytes([0xB2; 32])),
        padres: PadresDag::nuevo(bootstrap.hash_congelado_dev(), &[])
            .expect("los padres {G} son canónicos"),
        sello: [0u8; 64],
    }
}

/// Presupuesto de prueba: concede un número exacto de verificaciones AES y cuenta los intentos.
struct PresupuestoCuenta {
    restantes: usize,
    intentos: usize,
}

impl PresupuestoCuenta {
    fn nuevo(restantes: usize) -> Self {
        Self {
            restantes,
            intentos: 0,
        }
    }
}

impl PresupuestoPot for PresupuestoCuenta {
    fn consumir_slot(&mut self, _slot: u64) -> bool {
        self.intentos += 1;
        if self.restantes == 0 {
            false
        } else {
            self.restantes -= 1;
            true
        }
    }
}

/// Directorio temporal que se limpia al soltarse. Mismo patrón que el fixture D1.
struct DirTemporal {
    ruta: PathBuf,
}

impl DirTemporal {
    fn nuevo(nombre: &str) -> Self {
        static CONTADOR: AtomicU64 = AtomicU64::new(0);
        let n = CONTADOR.fetch_add(1, Ordering::Relaxed);
        let base =
            std::env::temp_dir().join(format!("zx-a3-{}-{}-{}", std::process::id(), nombre, n));
        let _ = std::fs::remove_dir_all(&base);
        std::fs::create_dir_all(&base).expect("crear directorio temporal del fixture A3");
        Self { ruta: base }
    }

    fn unir(&self, hijo: &str) -> PathBuf {
        self.ruta.join(hijo)
    }
}

impl Drop for DirTemporal {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.ruta);
    }
}

/// Positivo: PoT real encadenado, PoAS real, sello real y contexto dev ⇒ `Comprobada`.
#[test]
fn primer_hijo_dev_comprobado_con_pot_poas_y_sello_reales() {
    let e = escenario();
    let hash = e.bloque.cabecera.block_hash();
    assert!(
        e.bloque.cabecera.verificar_sello().is_ok(),
        "el bloque del fixture MUST llegar con sello válido"
    );

    let mut cache = CachePotVerificada::nueva();
    let slots = usize::try_from(e.slot).expect("el slot cabe en usize");
    // Presupuesto exacto: un AES por portador del rango, sin caché previa.
    let mut presupuesto = PresupuestoCuenta::nuevo(slots);

    let estado = verificar_primer_hijo_dag_dev(
        &e.bootstrap,
        &e.bloque,
        &e.historia,
        e.slot,
        &mut cache,
        &mut presupuesto,
    )
    .expect("el contexto dev del primer hijo MUST estar disponible");

    match estado {
        EstadoCabeceraConjunta::Comprobada(c) => {
            assert_eq!(
                c.block_hash(),
                hash,
                "el hash comprobado es el de la cabecera"
            );
            assert_eq!(
                c.slot_auditado(),
                e.slot,
                "el slot auditado es el del candidato"
            );
            assert_eq!(
                c.salida_auditada(),
                e.salida,
                "la salida auditada es la del último portador del rango"
            );
            assert_eq!(
                c.solution_distance(),
                e.distancia,
                "la distancia es la que devolvió la verificación PoAS"
            );
            assert_eq!(
                c.rango_validado().bloque(),
                Some(hash),
                "C-HDR-06: el SR validado queda atado a esta cabecera"
            );
            assert_eq!(
                c.rango_validado().valor(),
                e.sr,
                "el SR es el que aportó el contexto dev, no otro"
            );
        }
        otro => panic!("se esperaba Comprobada; llegó {otro:?}"),
    }

    assert_eq!(
        presupuesto.intentos, slots,
        "se MUST consumir un AES por cada portador del rango"
    );
}

/// Negativo: sello alterado ⇒ `Invalida(Sello)` sin tocar la caché ni el presupuesto AES.
#[test]
fn sello_alterado_es_invalida_sin_gastar_presupuesto() {
    let e = escenario();
    let mut bloque = e.bloque.clone();
    bloque.cabecera.sello[0] ^= 0x01;

    let mut cache = CachePotVerificada::nueva();
    let mut presupuesto = PresupuestoCuenta::nuevo(1_000);

    let estado = verificar_primer_hijo_dag_dev(
        &e.bootstrap,
        &bloque,
        &e.historia,
        e.slot,
        &mut cache,
        &mut presupuesto,
    )
    .expect("el contexto dev del primer hijo MUST estar disponible");

    match estado {
        EstadoCabeceraConjunta::Invalida(MotivoCabeceraInvalida::Sello(_)) => {}
        otro => panic!("se esperaba Invalida(Sello); llegó {otro:?}"),
    }
    assert_eq!(
        presupuesto.intentos, 0,
        "un sello inválido MUST NOT consumir presupuesto AES"
    );
}

/// Negativo: `pot_output` alterado **y resellado** ⇒ `Invalida(Pot(PotOutputNoCoincide))`.
///
/// El sello se rehace con la misma clave, así que el rechazo es del anclaje PoT y no de un sello
/// roto. El contexto lo reconstruye el propio wrapper a partir de la cabecera mutada.
#[test]
fn pot_output_alterado_y_resellado_es_invalida_pot_output_no_coincide() {
    let e = escenario();
    let sk = SigningKey::from([7u8; 32]);
    let mut bloque = e.bloque.clone();
    bloque.cabecera.pot_output[0] ^= 0x01;
    bloque.cabecera.sello = sk.sign(bloque.cabecera.pre_hash().as_bytes()).into();
    assert!(
        bloque.cabecera.verificar_sello().is_ok(),
        "el sello resellado con la misma clave MUST verificar: el rechazo no es del sello"
    );

    let mut cache = CachePotVerificada::nueva();
    let mut presupuesto = PresupuestoCuenta::nuevo(1_000);

    let estado = verificar_primer_hijo_dag_dev(
        &e.bootstrap,
        &bloque,
        &e.historia,
        e.slot,
        &mut cache,
        &mut presupuesto,
    )
    .expect("el contexto dev del primer hijo MUST estar disponible");

    match estado {
        EstadoCabeceraConjunta::Invalida(MotivoCabeceraInvalida::Pot(
            MotivoPotInvalido::PotOutputNoCoincide { .. },
        )) => {}
        otro => panic!("se esperaba Invalida(Pot(PotOutputNoCoincide)); llegó {otro:?}"),
    }
}
