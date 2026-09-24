//! Test de integración de la costura A3/D2 del primer hijo DAG dev
//! (`zx_node::puerta_primer_hijo_dag_dev` y `zx_node::cuerpo_coinbase_dag_dev`; `C-POT-03`/
//! `C-POT-05`/`C-POT-06`/`C-POT-08`, `C-HDR-03`/`C-HDR-04`/`C-HDR-06`/`C-HDR-07` y
//! `C-BLK-01`/`C-BLK-02`/`C-BLK-03`/`C-BLK-07`, `C-EMIT-03`/`C-EMIT-04`).
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
//! - La **coinbase cero real** de `CuerpoCoinbaseCeroDagDev`: una sola transacción sin entradas,
//!   salida cero a la clave del plot, `lock_time = 0` y `expiry_height = altura`; sus
//!   `merkle_root` y `body_commitment` se calculan antes de firmar `pre_hash` y alimentan la
//!   cabecera. `comprobar_cuerpo_coinbase_cero_dev` exige esa forma y recalcula ambos compromisos.
//! - Los negativos de sello y PoT: sello alterado ⇒ `Invalida(Sello)` sin consumir presupuesto AES,
//!   y `pot_output` alterado **y resellado** bajo la misma clave ⇒
//!   `Invalida(Pot(PotOutputNoCoincide))`. El segundo no usa un sello roto para fingir un rechazo
//!   PoT.
//! - La **proyección UTXO local de prueba** `simular_utxo_primer_hijo_dag_dev` (`C-GEN-03`,
//!   `C-TX-05`, `C-REORG-01`/`02`/`03`) sobre la evidencia A3 **real**: un único UTXO coinbase cero
//!   indexado por el `txid` de la rama de la cabecera, `altura_creacion = 1`, `es_coinbase = true`,
//!   bloqueo a la clave del productor y `undo.creados` con ese par; `revertir` deja el conjunto
//!   vacío. No es admisión ni estado vivo.
//! - Los negativos acotados del cuerpo: Merkle alterado ⇒ `MerkleRaizNoCoincide`; `body_commitment`
//!   alterado ⇒ `CuerpoCompromisoNoCoincide`; `expiry_height` distinto con compromisos
//!   recalculados ⇒ `CoinbaseSinAltura` (`C-EMIT-04`) y no Merkle; bloque vacío ⇒ `BloqueSinCoinbase`
//!   (`C-BLK-07`); y una segunda coinbase ⇒ error explícito, nunca `Ok`.
//!
//! # Qué NO cubre, y por qué
//!
//! - **Solo el positivo combina A3 y cuerpo básico, y no es admisión.** El positivo pasa la costura
//!   A3 (`Comprobada`) **y** el comprobador limitado del cuerpo coinbase cero; los negativos del
//!   cuerpo mutan cabecera o cuerpo sin exigir sello, porque `comprobar_cuerpo_coinbase_cero_dev`
//!   no verifica sello. No se comprueba UTXO, subsidio, peso dinámico, firmas de gasto, timelocks,
//!   orden GHOSTDAG ni red de tres nodos: `Comprobada` solo dice que las pruebas locales se
//!   satisficieron contra este contexto dev.
//! - **A3 no deriva altura ni rama ni comprueba el reloj de pared.** La `rama` y la `altura` del
//!   fixture son coherentes con `G` por construcción (misma rama dev, altura `G + 1`) y el
//!   `timestamp` avanza con el slot, pero **nadie las verifica** aquí; `reloj_pot` es el reloj PoT,
//!   no un reloj de pared.
//! - **`body_commitment` y `merkle_root` sí acreditan este cuerpo, y nada más.** Ahora se calculan
//!   sobre la coinbase cero real y el comprobador los recalcula; eso **no** convierte el cuerpo en
//!   válido: no cubre la ruta económica completa (`C-EMIT-03` admite el cobro cero como cobro
//!   inferior, no como subsidio).
//! - **La proyección UTXO no es admisión ni el orden de `C-ORD-03`.** Solo aplica el cuerpo de
//!   **un** bloque sobre un conjunto vacío y conserva su undo. No hay mergeset, ni `sp(C)`, ni
//!   cadena seleccionada, ni descarte silencioso de conflictos, ni persistencia, ni índice de
//!   admitidos. La evidencia A3 se usa solo como identidad (hash y slot).
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
    CachePotVerificada, ComprobacionCabecera, ConjuntoUtxo, ConsensusError, EstadoCabeceraConjunta,
    InstantaneaPot, MotivoCabeceraInvalida, MotivoPotInvalido, PresupuestoPot,
    RangoSolucionValidado, checkpoints_a_wire, proyectar_iteraciones, semilla_siguiente,
};
use zx_core::preimage::block::merkle_root;
use zx_core::wire_dag::{
    CHECKPOINTS_POR_BUNDLE, JustificacionPot, PotCheckpoints as PotCheckpointsWire,
};
use zx_core::{
    Amount, BloqueDag, BodyCommitment, ClavePublica, DagBlockHeader, Digest, Lock, MerkleRoot,
    OutPoint, POT_OUTPUT_BYTES, PadresDag, SolucionPoas, Tx, body_commitment, txid,
};
use zx_node::bootstrap_dag_dev::{EstadoBootstrapDagDev, iniciar_bootstrap_dag_dev};
use zx_node::cuerpo_coinbase_dag_dev::{
    CuerpoCoinbaseCeroDagDev, ErrorCuerpoCoinbaseDev, comprobar_cuerpo_coinbase_cero_dev,
};
use zx_node::farmer::{ParcelaDisco, plotear_sector_en_disco};
use zx_node::historia_dag_dev::HistoriaDagDev;
use zx_node::perfil_primer_hijo_dag_dev::ContextoPrimerHijoPotDagDev;
use zx_node::productor_poas::convertir_candidatos_locales;
use zx_node::puerta_primer_hijo_dag_dev::verificar_primer_hijo_dag_dev;
use zx_node::utxo_primer_hijo_dag_dev::{ErrorUtxoPrimerHijoDev, simular_utxo_primer_hijo_dag_dev};
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

    // Cuerpo coinbase cero real: la misma identidad que plotta es la que cobra. Sus compromisos
    // entran en la cabecera antes de firmar `pre_hash`.
    let cuerpo =
        CuerpoCoinbaseCeroDagDev::construir(&bootstrap, ClavePublica::desde_bytes(vk_bytes))
            .expect("la coinbase cero del primer hijo MUST construirse");

    // `N(s)` y `SR` se leen del contexto dev, no de literales del test.
    let cabecera_perfil = cabecera_dev(
        &bootstrap,
        MAX_SLOTS_BUSQUEDA,
        SR_DECLARADO_PARA_DERIVAR,
        &cuerpo,
    );
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
    // comprueba); `body_commitment` y `merkle_root` salen del cuerpo coinbase cero real.
    let mut cabecera = cabecera_dev(&bootstrap, slot, sr, &cuerpo);
    cabecera.pot_output = salida;
    cabecera.sol = sol;
    cabecera.sello = sk.sign(cabecera.pre_hash().as_bytes()).into();
    assert!(
        cabecera.verificar_sello().is_ok(),
        "el sello Ed25519 real del fixture MUST verificar"
    );

    let justificacion =
        JustificacionPot::nueva(portadores).expect("la lista de portadores del rango es canónica");
    let bloque = BloqueDag::nuevo(
        cabecera,
        justificacion,
        cuerpo.txs().to_vec(),
        cuerpo.testigos().to_vec(),
    )
    .expect("bloque con la coinbase cero del primer hijo");

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

/// Cabecera dev con padres `{G}`. Los compromisos de cuerpo salen del cuerpo coinbase cero real.
fn cabecera_dev(
    bootstrap: &EstadoBootstrapDagDev,
    slot: u64,
    rango_solucion: u64,
    cuerpo: &CuerpoCoinbaseCeroDagDev,
) -> DagBlockHeader {
    let genesis = &bootstrap.bloque_dev().cabecera;
    DagBlockHeader {
        // Coherente con G; este test **no** comprueba C-HDR-02b.
        consensus_branch_id: genesis.consensus_branch_id,
        // Compromisos reales del cuerpo coinbase cero (`C-BLK-01`/`C-BLK-02`/`C-BLK-03`).
        merkle_root: cuerpo.merkle_root(),
        // Posterior al timestamp de G; A3 no comprueba reloj de pared ni §7.4.
        timestamp: genesis.timestamp.saturating_add(slot),
        // Altura coherente con G por construcción; A3 no la deriva (C-HDR-02).
        height: genesis.height.saturating_add(1),
        slot,
        // Se sobrescribe con la salida auditada en el bloque positivo.
        pot_output: [0u8; POT_OUTPUT_BYTES],
        rango_solucion,
        sol: SolucionPoas::default(),
        // Compromiso real del cuerpo (efectos y autorización) de la coinbase cero.
        body_commitment: cuerpo.body_commitment(),
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

/// Positivo: cuerpo coinbase cero real, PoT real encadenado, PoAS real, sello real y contexto dev
/// ⇒ `Comprobada` y comprobador de cuerpo `Ok`. Solo este positivo combina A3 y cuerpo básico; no es
/// admisión.
#[test]
fn primer_hijo_dev_comprobado_con_pot_poas_y_sello_reales() {
    let e = escenario();
    let hash = e.bloque.cabecera.block_hash();
    assert!(
        !e.bloque.txs().is_empty(),
        "el cuerpo del fixture MUST llevar la coinbase cero"
    );
    comprobar_cuerpo_coinbase_cero_dev(&e.bootstrap, &e.bloque).expect(
        "el comprobador limitado del cuerpo coinbase cero MUST aceptar el cuerpo real del fixture",
    );
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

/// Reensambla un bloque dev `{G}` con los `txs`/`testigos` dados y los compromisos recalculados.
///
/// **No** rehace el sello: `comprobar_cuerpo_coinbase_cero_dev` no verifica sello, así que estos
/// negativos aíslan la comprobación del cuerpo. El llamante MUST partir de una cabecera base
/// coherente con `{G}`.
fn bloque_con_cuerpo(e: &Escenario, txs: Vec<Tx>, testigos: Vec<Vec<Vec<u8>>>) -> BloqueDag {
    let rama = e.bootstrap.bloque_dev().cabecera.consensus_branch_id;
    let txids: Vec<_> = txs.iter().map(|t| txid(t, rama)).collect();
    let mut cabecera = e.bloque.cabecera;
    cabecera.merkle_root = merkle_root(&txids);
    cabecera.body_commitment =
        body_commitment(&txs, &testigos, rama).expect("el cuerpo emparejado MUST comprometerse");
    BloqueDag::nuevo(cabecera, e.bloque.justificacion.clone(), txs, testigos)
        .expect("txs y testigos emparejados")
}

/// Negativo: `merkle_root` alterado con el cuerpo intacto ⇒ `MerkleRaizNoCoincide`.
#[test]
fn merkle_alterado_con_cuerpo_intacto_es_merkle_raiz_no_coincide() {
    let e = escenario();
    let mut bloque = e.bloque.clone();
    bloque.cabecera.merkle_root = MerkleRoot::from_digest(Digest::from_bytes([0x5A; 32]));
    // No se rehace el sello: el comprobador de cuerpo no verifica sello.
    assert!(matches!(
        comprobar_cuerpo_coinbase_cero_dev(&e.bootstrap, &bloque),
        Err(ErrorCuerpoCoinbaseDev::Compromisos(
            ConsensusError::MerkleRaizNoCoincide
        ))
    ));
}

/// Negativo: `body_commitment` alterado con el Merkle intacto ⇒ `CuerpoCompromisoNoCoincide`.
#[test]
fn body_commitment_alterado_con_merkle_intacto_es_cuerpo_compromiso_no_coincide() {
    let e = escenario();
    let mut bloque = e.bloque.clone();
    bloque.cabecera.body_commitment = BodyCommitment::from_digest(Digest::from_bytes([0x6B; 32]));
    assert!(matches!(
        comprobar_cuerpo_coinbase_cero_dev(&e.bootstrap, &bloque),
        Err(ErrorCuerpoCoinbaseDev::Compromisos(
            ConsensusError::CuerpoCompromisoNoCoincide
        ))
    ));
}

/// Negativo: coinbase con `expiry_height` distinto y compromisos **recalculados** ⇒ rechazo por
/// `C-EMIT-04`, no por Merkle.
#[test]
fn coinbase_con_expiry_distinto_con_compromisos_recalculados_es_c_emit_04() {
    let e = escenario();
    let mut coinbase = e
        .bloque
        .txs()
        .first()
        .expect("la coinbase del fixture MUST existir")
        .clone();
    coinbase.expiry_height = coinbase.expiry_height.saturating_add(1);
    let testigos: Vec<Vec<Vec<u8>>> = vec![Vec::new()];
    let bloque = bloque_con_cuerpo(e, vec![coinbase], testigos);

    match comprobar_cuerpo_coinbase_cero_dev(&e.bootstrap, &bloque) {
        Err(ErrorCuerpoCoinbaseDev::CoinbaseSinAltura { altura, expiry }) => {
            assert_eq!(altura, 1, "el perfil dev deriva altura 1 de G con height 0");
            assert_ne!(expiry, altura, "el expiry mutado no coincide con la altura");
        }
        otro => panic!("se esperaba CoinbaseSinAltura (C-EMIT-04); llegó {otro:?}"),
    }
}

/// Negativo: bloque sin ninguna transacción ⇒ `BloqueSinCoinbase` (`C-BLK-07`).
#[test]
fn bloque_vacio_es_bloque_sin_coinbase_c_blk_07() {
    let e = escenario();
    let bloque = BloqueDag::nuevo(
        e.bloque.cabecera,
        JustificacionPot::vacia(),
        Vec::new(),
        Vec::new(),
    )
    .expect("el bloque vacío empareja cero transacciones con cero testigos");
    assert!(matches!(
        comprobar_cuerpo_coinbase_cero_dev(&e.bootstrap, &bloque),
        Err(ErrorCuerpoCoinbaseDev::BloqueSinCoinbase)
    ));
}

/// Negativo: una segunda coinbase no se acepta mediante `Ok`: queda fuera del perfil.
///
/// Los compromisos se recalculan para que el rechazo sea del número de transacciones y no de un
/// Merkle desactualizado.
#[test]
fn una_segunda_coinbase_no_se_acepta_como_ok() {
    let e = escenario();
    let coinbase = e
        .bloque
        .txs()
        .first()
        .expect("la coinbase del fixture MUST existir")
        .clone();
    let testigos: Vec<Vec<Vec<u8>>> = vec![Vec::new(), Vec::new()];
    let bloque = bloque_con_cuerpo(e, vec![coinbase.clone(), coinbase], testigos);
    assert!(matches!(
        comprobar_cuerpo_coinbase_cero_dev(&e.bootstrap, &bloque),
        Err(ErrorCuerpoCoinbaseDev::TransaccionesFueraDePerfil { encontradas: 2 })
    ));
}

/// Obtiene la `ComprobacionCabecera` **real** de la puerta A3 para el bloque del fixture.
///
/// No fabrica mocks: ejecuta `verificar_primer_hijo_dag_dev` con caché vacía y presupuesto exacto,
/// igual que el positivo de A3. Solo repite la verificación AES; el archivo, el ploteo y la cadena
/// PoT siguen viniendo del `OnceLock` compartido.
fn comprobacion_real(e: &Escenario) -> ComprobacionCabecera {
    let mut cache = CachePotVerificada::nueva();
    let slots = usize::try_from(e.slot).expect("el slot cabe en usize");
    let mut presupuesto = PresupuestoCuenta::nuevo(slots);
    match verificar_primer_hijo_dag_dev(
        &e.bootstrap,
        &e.bloque,
        &e.historia,
        e.slot,
        &mut cache,
        &mut presupuesto,
    ) {
        Ok(EstadoCabeceraConjunta::Comprobada(c)) => c,
        otro => panic!("el fixture MUST producir una comprobación A3 real; llegó {otro:?}"),
    }
}

/// Positivo: la evidencia A3 real proyecta la coinbase cero en un conjunto **vacío** y revierte.
///
/// Comprueba un único UTXO indexado por el `txid` de la rama de la cabecera (`C-TX-05`) con valor
/// cero, `altura_creacion = 1`, `es_coinbase = true`, bloqueo a la clave del productor y el par
/// completo en `undo.creados` (`C-REORG-01`); `revertir` deja el conjunto vacío (`C-REORG-02`/
/// `C-REORG-03`). No mide red ni conecta el estado vivo.
///
/// No se añade un test de corrupción del undo: `EstadoUtxoPrimerHijoDev` no expone mutación del
/// conjunto y no hay constructor público para inyectarlo sin reimplementar el storage. Esa
/// detección ya la cubren los tests de `zx-storage` (`C-REORG-02`).
#[test]
fn utxo_simulado_del_primer_hijo_registra_la_coinbase_cero_y_revierte() {
    let e = escenario();
    let comprobacion = comprobacion_real(e);
    let rama = e.bloque.cabecera.consensus_branch_id;

    let estado = simular_utxo_primer_hijo_dag_dev(&e.bootstrap, &e.bloque, &comprobacion)
        .expect("la evidencia A3 real del fixture MUST permitir la simulación UTXO");

    assert_eq!(
        estado.block_hash(),
        e.bloque.cabecera.block_hash(),
        "la proyección conserva el hash de la cabecera cotejada"
    );
    assert_eq!(
        estado.conjunto().len(),
        1,
        "C-GEN-03: solo la coinbase cero del primer hijo crea un UTXO"
    );

    let coinbase = e
        .bloque
        .txs()
        .first()
        .expect("la coinbase del fixture MUST existir");
    let outpoint = OutPoint {
        prev_txid: txid(coinbase, rama),
        prev_index: 0,
    };
    let entrada = estado.conjunto().buscar(&outpoint).expect(
        "la salida coinbase cero MUST quedar indexada por el txid de la rama de la cabecera",
    );

    assert_eq!(entrada.salida.value, Amount::CERO, "C-EMIT-03: valor cero");
    assert_eq!(entrada.altura_creacion, 1, "altura del primer hijo de G");
    assert!(entrada.es_coinbase, "la salida creada es de coinbase");

    let sk = SigningKey::from([7u8; 32]);
    let vk = VerificationKey::from(&sk);
    let vk_bytes: [u8; 32] = vk.into();
    assert_eq!(
        entrada.salida.lock,
        Lock::PubKey {
            pubkey: ClavePublica::desde_bytes(vk_bytes)
        },
        "el bloqueo es la clave del productor que plotta y firma"
    );

    assert!(
        estado.undo().creados.contains(&(outpoint, entrada.clone())),
        "C-REORG-01: el undo data MUST registrar el par completo de la salida creada"
    );

    let tras_revertir = estado
        .revertir()
        .expect("revertir la proyección MUST devolver el conjunto vacío");
    assert!(
        tras_revertir.is_empty(),
        "C-REORG-02/C-REORG-03: deshacer el único bloque deja el conjunto vacío"
    );
}

/// Negativo: cabecera mutada **y resellada** con la evidencia A3 del bloque original.
///
/// El hash de la evidencia no coincide con el del bloque mutado, así que la simulación MUST
/// rechazar por hash antes de crear ningún UTXO. El resello con la misma clave demuestra que el
/// rechazo no es del sello.
#[test]
fn cabecera_mutada_y_resellada_con_evidencia_original_es_error_de_hash() {
    let e = escenario();
    let comprobacion = comprobacion_real(e);
    let sk = SigningKey::from([7u8; 32]);

    let mut bloque = e.bloque.clone();
    bloque.cabecera.timestamp = bloque.cabecera.timestamp.saturating_add(1);
    bloque.cabecera.sello = sk.sign(bloque.cabecera.pre_hash().as_bytes()).into();
    assert!(
        bloque.cabecera.verificar_sello().is_ok(),
        "el resello con la misma clave MUST verificar: el rechazo no es del sello"
    );
    assert_ne!(
        bloque.cabecera.block_hash(),
        comprobacion.block_hash(),
        "la mutación MUST cambiar el hash para que la guarda tenga algo que ver"
    );

    match simular_utxo_primer_hijo_dag_dev(&e.bootstrap, &bloque, &comprobacion) {
        Err(ErrorUtxoPrimerHijoDev::HashDeEvidenciaNoCoincide {
            comprobacion: guardada,
            bloque: entregada,
        }) => {
            assert_eq!(guardada, comprobacion.block_hash());
            assert_eq!(entregada, bloque.cabecera.block_hash());
        }
        otro => panic!("se esperaba error de hash antes de tocar el UTXO; llegó {otro:?}"),
    }
}

/// Negativo: cuerpo coinbase mutado con cabecera y compromisos recomputados, evidencia original.
///
/// Recalcular `merkle_root` y `body_commitment` cambia el `block_hash`, de modo que la función
/// MUST rechazar por hash (no por el comprobador de cuerpo) antes de publicar estado. Se resella
/// para descartar que el rechazo venga del sello.
#[test]
fn cuerpo_mutado_con_compromisos_recalculados_y_evidencia_original_es_error_de_hash() {
    let e = escenario();
    let comprobacion = comprobacion_real(e);
    let sk = SigningKey::from([7u8; 32]);

    let mut coinbase = e
        .bloque
        .txs()
        .first()
        .expect("la coinbase del fixture MUST existir")
        .clone();
    let salida = coinbase
        .outputs
        .get_mut(0)
        .expect("la coinbase del fixture tiene una salida");
    salida.value = Amount::nuevo(1).expect("1 brek es un importe válido");

    let testigos: Vec<Vec<Vec<u8>>> = vec![Vec::new()];
    let mut bloque = bloque_con_cuerpo(e, vec![coinbase], testigos);
    bloque.cabecera.sello = sk.sign(bloque.cabecera.pre_hash().as_bytes()).into();

    assert_ne!(
        bloque.cabecera.block_hash(),
        e.bloque.cabecera.block_hash(),
        "recalcular los compromisos MUST cambiar el hash de cabecera"
    );

    match simular_utxo_primer_hijo_dag_dev(&e.bootstrap, &bloque, &comprobacion) {
        Err(ErrorUtxoPrimerHijoDev::HashDeEvidenciaNoCoincide { .. }) => {}
        otro => {
            panic!("se esperaba error de hash, no del comprobador de cuerpo; llegó {otro:?}")
        }
    }
}

/// Negativo de cuerpo aislado: `expiry_height` erróneo con la **misma** cabecera y evidencia A3.
///
/// No se falsifica la `ComprobacionCabecera`: se reutiliza la evidencia **real** del bloque
/// original y se cambia solo la transacción, dejando la cabecera intacta. El hash y el slot siguen
/// coincidiendo, así que la simulación MUST rechazar por el comprobador de cuerpo
/// (`CoinbaseSinAltura`, `C-EMIT-04`) sin publicar ningún UTXO.
#[test]
fn cuerpo_con_expiry_erroneo_mismo_hash_es_rechazado_por_el_comprobador_de_cuerpo() {
    let e = escenario();
    let comprobacion = comprobacion_real(e);

    let mut coinbase = e
        .bloque
        .txs()
        .first()
        .expect("la coinbase del fixture MUST existir")
        .clone();
    coinbase.expiry_height = coinbase.expiry_height.saturating_add(1);

    let testigos: Vec<Vec<Vec<u8>>> = vec![Vec::new()];
    let bloque = BloqueDag::nuevo(
        e.bloque.cabecera,
        e.bloque.justificacion.clone(),
        vec![coinbase],
        testigos,
    )
    .expect("txs y testigos emparejados");
    assert_eq!(
        bloque.cabecera.block_hash(),
        comprobacion.block_hash(),
        "el hash de cabecera queda intacto a propósito para aislar el cuerpo"
    );

    match simular_utxo_primer_hijo_dag_dev(&e.bootstrap, &bloque, &comprobacion) {
        Err(ErrorUtxoPrimerHijoDev::Cuerpo(ErrorCuerpoCoinbaseDev::CoinbaseSinAltura {
            altura,
            expiry,
        })) => {
            assert_eq!(altura, 1, "altura derivada del primer hijo de G");
            assert_ne!(expiry, altura, "el expiry mutado no coincide con la altura");
        }
        otro => {
            panic!("se esperaba CoinbaseSinAltura del comprobador de cuerpo; llegó {otro:?}")
        }
    }
}
