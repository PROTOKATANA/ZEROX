//! Pruebas del **núcleo de verificación de un rango PoT** (`zx-consensus::pot_rango`, SPEC §7.1.2).
//!
//! Cubren: varios slots consecutivos, inyección en el borde exacto, cambio de `N` en `t_j`, dos
//! flujos en el mismo slot (caché), mutación de un checkpoint intermedio con el último intacto,
//! `pot_output` incorrecto, `d = 0`, 150 portadores y exceso estructural, `slot + D` desbordado,
//! `N` fuera de dominio, doble inyección, pasado incompleto, reloj futuro, presupuesto agotado,
//! contexto circular y génesis; y para la caché, misma clave, otra clave y portador alterado.
//!
//! # Qué NO acreditan
//!
//! Las implementaciones de [`InstantaneaPot`], [`CachePot`] y [`PresupuestoPot`] de este archivo
//! son **mocks**: devuelven datos libres y **no** acreditan que `f`, `N(s)`, `D` ni la salida
//! ancla provengan de un pasado DAG validado. Prueban el núcleo, no la validez de un bloque. No
//! existe todavía un derivador real de `past(B)`; por eso el núcleo **no** puede producir
//! `PotValido` en la ruta activa y `wire_dag::verificar_justificacion_pot` sigue pendiente.

#![expect(clippy::expect_used, reason = "los tests fallan con panic por diseño")]

use core::num::NonZeroU32;
use std::collections::BTreeMap;

use zx_consensus::pot::{checkpoints_a_primitiva, checkpoints_a_wire, semilla_siguiente};
use zx_consensus::pot_rango::{
    BloqueDelPasado, CachePot, ClaveCachePot, EntradaCachePot, EstadoPot, FLUJO_BYTES,
    InstantaneaPot, InyeccionPot, InyeccionesPot, MotivoPotInvalido, MotivoPotPendiente,
    PresupuestoPot, verificar_rango_pot,
};
use zx_core::digest::{BlockHash, BodyCommitment, Digest, MerkleRoot};
use zx_core::wire_dag::{BUNDLE_BYTES, JustificacionPot, POT_OUTPUT_BYTES, PotCheckpoints};
use zx_core::{DagBlockHeader, PadresDag, SolucionPoas};
use zx_pot::tipos::PotSeed;

// ─────────────────────────────────────────────────────────────────────────────
// Mocks
// ─────────────────────────────────────────────────────────────────────────────

/// Instantánea contextual de prueba: **datos libres**, sin procedencia acreditada.
#[derive(Clone)]
struct ContextoPrueba {
    flujo: [u8; FLUJO_BYTES],
    flujos_por_slot: BTreeMap<u64, [u8; FLUJO_BYTES]>,
    pasado: Vec<BloqueDelPasado>,
    inyecciones: BTreeMap<u64, InyeccionesPot>,
    iteraciones: BTreeMap<u64, u64>,
    retardo: u64,
    salidas: BTreeMap<u64, [u8; POT_OUTPUT_BYTES]>,
}

impl InstantaneaPot for ContextoPrueba {
    fn flujo_candidato_en(&self, slot: u64) -> Result<[u8; FLUJO_BYTES], MotivoPotPendiente> {
        Ok(self
            .flujos_por_slot
            .get(&slot)
            .copied()
            .unwrap_or(self.flujo))
    }

    fn pasado(&self) -> Result<&[BloqueDelPasado], MotivoPotPendiente> {
        Ok(&self.pasado)
    }

    fn inyecciones_en(&self, slot: u64) -> Result<InyeccionesPot, MotivoPotPendiente> {
        Ok(self
            .inyecciones
            .get(&slot)
            .cloned()
            .unwrap_or(InyeccionesPot::Ninguna))
    }

    fn iteraciones(&self, slot: u64) -> Result<u64, MotivoPotPendiente> {
        self.iteraciones
            .get(&slot)
            .copied()
            .ok_or(MotivoPotPendiente::ContextoAusente { que: "N(s)" })
    }

    fn retardo_autoria(&self) -> Result<u64, MotivoPotPendiente> {
        Ok(self.retardo)
    }

    fn salida_validada(&self, slot: u64) -> Result<[u8; POT_OUTPUT_BYTES], MotivoPotPendiente> {
        self.salidas
            .get(&slot)
            .copied()
            .ok_or(MotivoPotPendiente::ContextoAusente {
                que: "salida ancla",
            })
    }
}

/// Caché de prueba en un vector.
#[derive(Default)]
struct CachePrueba {
    entradas: Vec<(ClaveCachePot, EntradaCachePot)>,
}

impl CachePot for CachePrueba {
    fn buscar(&self, clave: &ClaveCachePot) -> Option<EntradaCachePot> {
        self.entradas
            .iter()
            .find(|(c, _)| c == clave)
            .map(|(_, e)| *e)
    }

    fn registrar(&mut self, clave: ClaveCachePot, entrada: EntradaCachePot) {
        if let Some((_, existente)) = self.entradas.iter_mut().find(|(c, _)| *c == clave) {
            *existente = entrada;
        } else {
            self.entradas.push((clave, entrada));
        }
    }
}

/// Presupuesto de prueba: unidades enteras.
struct PresupuestoPrueba {
    restantes: usize,
}

impl PresupuestoPot for PresupuestoPrueba {
    fn consumir_slot(&mut self, _slot: u64) -> bool {
        if self.restantes == 0 {
            false
        } else {
            self.restantes -= 1;
            true
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cadena de prueba
// ─────────────────────────────────────────────────────────────────────────────

const FLUJO: [u8; FLUJO_BYTES] = [0x11; FLUJO_BYTES];
const BASE: [u8; POT_OUTPUT_BYTES] = [0xAB; POT_OUTPUT_BYTES];
const N_FIJO: u64 = 16;
const SLOT_SP: u64 = 100;
const RETARDO: u64 = 2;
const RELOJ: u64 = 1_000;

/// Cadena de un rango construida con la primitiva real: portadores, iteraciones y salidas.
struct Cadena {
    flujo: [u8; FLUJO_BYTES],
    retardo: u64,
    slot_sp: u64,
    slot_b: u64,
    inyecciones: BTreeMap<u64, InyeccionPot>,
    iteraciones: BTreeMap<u64, u64>,
    portadores: Vec<PotCheckpoints>,
    salidas: BTreeMap<u64, [u8; POT_OUTPUT_BYTES]>,
    pot_output: [u8; POT_OUTPUT_BYTES],
}

fn generar<F: Fn(u64) -> u64>(
    flujo: [u8; FLUJO_BYTES],
    slot_sp: u64,
    retardo: u64,
    d: usize,
    base: [u8; POT_OUTPUT_BYTES],
    inyecciones: BTreeMap<u64, InyeccionPot>,
    n_de: F,
) -> Cadena {
    let mut portadores = Vec::with_capacity(d);
    let mut iteraciones = BTreeMap::new();
    let mut salidas = BTreeMap::new();
    salidas.insert(slot_sp + retardo, base);

    let mut salida = base;
    for i in 1..=u64::try_from(d).expect("d cabe en u64") {
        let slot = slot_sp + retardo + i;
        let entropia = inyecciones.get(&slot).map(|inyeccion| inyeccion.entropia);
        let semilla = semilla_siguiente(salida, entropia);
        let n = n_de(slot);
        iteraciones.insert(slot, n);
        let carrier = zx_pot::prove(
            PotSeed::from(semilla),
            NonZeroU32::new(u32::try_from(n).expect("N cabe en u32")).expect("N > 0"),
        )
        .expect("N múltiplo de 16");
        salida = *carrier.output();
        salidas.insert(slot, salida);
        portadores.push(checkpoints_a_wire(&carrier));
    }

    Cadena {
        flujo,
        retardo,
        slot_sp,
        slot_b: slot_sp + u64::try_from(d).expect("d cabe en u64"),
        inyecciones,
        iteraciones,
        portadores,
        salidas,
        pot_output: salida,
    }
}

fn hash_de(n: u8) -> BlockHash {
    BlockHash::from_digest(Digest::from_bytes([n; 32]))
}

fn cabecera(
    slot: u64,
    pot_output: [u8; POT_OUTPUT_BYTES],
    sp: BlockHash,
    extras: &[BlockHash],
) -> DagBlockHeader {
    DagBlockHeader {
        consensus_branch_id: 0xc478_80ea,
        merkle_root: MerkleRoot::from_digest(Digest::from_bytes([1; 32])),
        timestamp: 1_788_480_000,
        height: 1,
        slot,
        pot_output,
        rango_solucion: 5,
        sol: SolucionPoas::default(),
        body_commitment: BodyCommitment::from_digest(Digest::from_bytes([2; 32])),
        padres: PadresDag::nuevo(sp, extras).expect("padres canónicos"),
        sello: [0u8; 64],
    }
}

fn justificacion(cadena: &Cadena) -> JustificacionPot {
    JustificacionPot::nueva(cadena.portadores.clone()).expect("≤ 150 portadores")
}

fn contexto(cadena: &Cadena, padres: &[(BlockHash, u64)]) -> ContextoPrueba {
    let pasado = padres
        .iter()
        .map(|(hash, slot)| BloqueDelPasado {
            hash: *hash,
            slot: *slot,
            flujo: cadena.flujo,
        })
        .collect();
    let inyecciones = cadena
        .inyecciones
        .iter()
        .map(|(slot, inyeccion)| (*slot, InyeccionesPot::Una(inyeccion.clone())))
        .collect();
    ContextoPrueba {
        flujo: cadena.flujo,
        flujos_por_slot: BTreeMap::new(),
        pasado,
        inyecciones,
        iteraciones: cadena.iteraciones.clone(),
        retardo: cadena.retardo,
        salidas: cadena.salidas.clone(),
    }
}

/// Escenario completo: cadena, cabecera y contexto coherentes.
struct Escenario {
    cadena: Cadena,
    cabecera: DagBlockHeader,
    justificacion: JustificacionPot,
    contexto: ContextoPrueba,
}

fn escenario(d: usize, inyecciones: BTreeMap<u64, InyeccionPot>) -> Escenario {
    escenario_con(d, inyecciones, |_| N_FIJO)
}

fn escenario_con<F: Fn(u64) -> u64>(
    d: usize,
    inyecciones: BTreeMap<u64, InyeccionPot>,
    n_de: F,
) -> Escenario {
    let cadena = generar(FLUJO, SLOT_SP, RETARDO, d, BASE, inyecciones, n_de);
    let (sp, extra) = (hash_de(0x01), hash_de(0x02));
    let cabecera = cabecera(cadena.slot_b, cadena.pot_output, sp, &[extra]);
    let justificacion = justificacion(&cadena);
    let contexto = contexto(&cadena, &[(sp, SLOT_SP), (extra, SLOT_SP)]);
    Escenario {
        cadena,
        cabecera,
        justificacion,
        contexto,
    }
}

fn verificar(escenario: &Escenario, reloj: u64) -> EstadoPot {
    let mut cache = CachePrueba::default();
    let mut presupuesto = PresupuestoPrueba { restantes: 1_000 };
    verificar_rango_pot(
        &escenario.cabecera,
        &escenario.justificacion,
        &escenario.contexto,
        reloj,
        &mut cache,
        &mut presupuesto,
    )
}

fn clave_de(cadena: &Cadena, slot: u64) -> ClaveCachePot {
    let anterior = cadena
        .salidas
        .get(&(slot - 1))
        .copied()
        .expect("salida del slot anterior");
    let entropia = cadena.inyecciones.get(&slot).map(|i| i.entropia);
    ClaveCachePot {
        flujo: cadena.flujo,
        slot,
        semilla: semilla_siguiente(anterior, entropia),
        iteraciones: cadena.iteraciones.get(&slot).copied().expect("N del slot"),
    }
}

fn portador_con_checkpoint_alterado(portador: &PotCheckpoints) -> PotCheckpoints {
    let mut outputs = portador.outputs();
    if let Some(intermedio) = outputs.get_mut(1)
        && let Some(byte) = intermedio.first_mut()
    {
        *byte ^= 0x01;
    }
    PotCheckpoints::desde_outputs(outputs)
}

/// La salida de un portador, por la ruta pública del adaptador.
fn salida_de(portador: &PotCheckpoints) -> [u8; POT_OUTPUT_BYTES] {
    *checkpoints_a_primitiva(portador).output()
}

// ─────────────────────────────────────────────────────────────────────────────
// 1 · Varios slots consecutivos
// ─────────────────────────────────────────────────────────────────────────────

#[test]
fn un_rango_de_varios_slots_consecutivos_verifica() {
    let escenario = escenario(3, BTreeMap::new());
    assert_eq!(escenario.cadena.portadores.len(), 3);
    assert_eq!(verificar(&escenario, RELOJ), EstadoPot::PotValido);
}

// ─────────────────────────────────────────────────────────────────────────────
// 2 · Inyección en el borde exacto del rango
// ─────────────────────────────────────────────────────────────────────────────

fn inyeccion_en(slot: u64, ancla: BlockHash) -> BTreeMap<u64, InyeccionPot> {
    let mut mapa = BTreeMap::new();
    mapa.insert(
        slot,
        InyeccionPot {
            entropia: [0x55; 32],
            ancla,
        },
    );
    mapa
}

/// La misma inyección, ya envuelta como la entrega el contexto.
fn inyecciones_una(slot: u64, ancla: BlockHash) -> BTreeMap<u64, InyeccionesPot> {
    let mut mapa = BTreeMap::new();
    mapa.insert(
        slot,
        InyeccionesPot::Una(InyeccionPot {
            entropia: [0x55; 32],
            ancla,
        }),
    );
    mapa
}

#[test]
fn la_inyeccion_se_aplica_exactamente_en_su_slot() {
    // El primer slot del rango es `slot(sp) + D + 1 = 103`.
    let escenario = escenario(3, inyeccion_en(103, hash_de(0x30)));
    assert_eq!(verificar(&escenario, RELOJ), EstadoPot::PotValido);

    // El mismo contexto con la inyección declarada un slot más tarde: los portadores se
    // construyeron con ella en 103, así que la cadena ya no reproduce.
    let mut movida = escenario;
    movida.contexto.inyecciones = inyecciones_una(104, hash_de(0x30));
    assert_eq!(
        verificar(&movida, RELOJ),
        EstadoPot::PotInvalido(MotivoPotInvalido::AesFallido { slot: 103 })
    );
}

// ─────────────────────────────────────────────────────────────────────────────
// 3 · Cambio de N en t_j
// ─────────────────────────────────────────────────────────────────────────────

#[test]
fn el_cambio_de_n_en_el_slot_de_inyeccion_se_respeta() {
    // El contexto cambia `N` exactamente en el slot de una inyección —su `t_j`— y el núcleo
    // aplica las dos cosas en ese slot y en ningún otro.
    let escenario = escenario_con(3, inyeccion_en(105, hash_de(0x30)), |slot| {
        if slot < 105 { 16 } else { 32 }
    });
    assert_eq!(verificar(&escenario, RELOJ), EstadoPot::PotValido);

    // Si el contexto declara para 105 el `N` anterior, el portador real (construido con 32) no
    // verifica.
    let mut equivocado = escenario;
    equivocado.contexto.iteraciones.insert(105, 16);
    assert_eq!(
        verificar(&equivocado, RELOJ),
        EstadoPot::PotInvalido(MotivoPotInvalido::AesFallido { slot: 105 })
    );
}

// ─────────────────────────────────────────────────────────────────────────────
// 4 · Dos flujos en el mismo slot: la caché de otra clave no invalida
// ─────────────────────────────────────────────────────────────────────────────

#[test]
fn una_entrada_de_cache_de_otro_flujo_no_invalida() {
    let escenario = escenario(3, BTreeMap::new());
    let mut cache = CachePrueba::default();
    cache.registrar(
        ClaveCachePot {
            flujo: [0x99; FLUJO_BYTES],
            slot: 103,
            semilla: [0x77; POT_OUTPUT_BYTES],
            iteraciones: 16,
        },
        EntradaCachePot {
            salida: [0x01; POT_OUTPUT_BYTES],
            portador: None,
        },
    );
    let mut presupuesto = PresupuestoPrueba { restantes: 1_000 };
    assert_eq!(
        verificar_rango_pot(
            &escenario.cabecera,
            &escenario.justificacion,
            &escenario.contexto,
            RELOJ,
            &mut cache,
            &mut presupuesto,
        ),
        EstadoPot::PotValido
    );
}

// ─────────────────────────────────────────────────────────────────────────────
// 5 · Mutación de un checkpoint intermedio con el último intacto
// ─────────────────────────────────────────────────────────────────────────────

#[test]
fn mutar_un_checkpoint_intermedio_con_el_ultimo_intacto_invalida() {
    let mut escenario = escenario(3, BTreeMap::new());
    let original = escenario
        .cadena
        .portadores
        .get(1)
        .copied()
        .expect("segundo");
    let alterado = portador_con_checkpoint_alterado(&original);
    assert_eq!(
        salida_de(&original),
        salida_de(&alterado),
        "el último no cambia"
    );
    if let Some(slot) = escenario.cadena.portadores.get_mut(1) {
        *slot = alterado;
    }
    escenario.justificacion = justificacion(&escenario.cadena);
    assert_eq!(
        verificar(&escenario, RELOJ),
        EstadoPot::PotInvalido(MotivoPotInvalido::AesFallido { slot: 104 })
    );
}

// ─────────────────────────────────────────────────────────────────────────────
// 6 · pot_output incorrecto
// ─────────────────────────────────────────────────────────────────────────────

#[test]
fn un_pot_output_incorrecto_invalida() {
    let mut escenario = escenario(3, BTreeMap::new());
    escenario.cabecera.pot_output = [0x00; POT_OUTPUT_BYTES];
    assert!(matches!(
        verificar(&escenario, RELOJ),
        EstadoPot::PotInvalido(MotivoPotInvalido::PotOutputNoCoincide { .. })
    ));
}

// ─────────────────────────────────────────────────────────────────────────────
// 7 · d = 0
// ─────────────────────────────────────────────────────────────────────────────

#[test]
fn un_rango_vacio_exige_que_el_ancla_acreditada_sea_pot_output() {
    // `d = 0`: el ancla en `slot(B) + D` es la salida del mismo slot y debe ser `pot_output`.
    let escenario = escenario(0, BTreeMap::new());
    assert!(escenario.justificacion.is_empty());
    assert_eq!(verificar(&escenario, RELOJ), EstadoPot::PotValido);

    let mut incorrecto = escenario;
    incorrecto.cabecera.pot_output = [0x00; POT_OUTPUT_BYTES];
    assert!(matches!(
        verificar(&incorrecto, RELOJ),
        EstadoPot::PotInvalido(MotivoPotInvalido::PotOutputNoCoincide { .. })
    ));
}

#[test]
fn un_rango_vacio_sin_ancla_en_el_contexto_es_pendiente() {
    let mut escenario = escenario(0, BTreeMap::new());
    escenario.contexto.salidas.clear();
    assert_eq!(
        verificar(&escenario, RELOJ),
        EstadoPot::PotPendiente(MotivoPotPendiente::ContextoAusente {
            que: "salida ancla"
        })
    );
}

// ─────────────────────────────────────────────────────────────────────────────
// 8 · 150 portadores y exceso estructural
// ─────────────────────────────────────────────────────────────────────────────

#[test]
fn ciento_cincuenta_portadores_verifican() {
    let escenario = escenario(150, BTreeMap::new());
    assert_eq!(escenario.cadena.portadores.len(), 150);
    assert_eq!(verificar(&escenario, RELOJ), EstadoPot::PotValido);
}

#[test]
fn una_diferencia_de_151_es_exceso_estructural() {
    // 150 portadores reales, pero `slot(B) − slot(sp) = 151`.
    let cadena = generar(FLUJO, SLOT_SP, RETARDO, 150, BASE, BTreeMap::new(), |_| {
        N_FIJO
    });
    let (sp, extra) = (hash_de(0x01), hash_de(0x02));
    let cabecera = cabecera(cadena.slot_sp + 151, cadena.pot_output, sp, &[extra]);
    let contexto = contexto(&cadena, &[(sp, SLOT_SP), (extra, SLOT_SP)]);
    let justificacion = justificacion(&cadena);
    let mut cache = CachePrueba::default();
    let mut presupuesto = PresupuestoPrueba { restantes: 1_000 };

    assert_eq!(
        verificar_rango_pot(
            &cabecera,
            &justificacion,
            &contexto,
            RELOJ,
            &mut cache,
            &mut presupuesto,
        ),
        EstadoPot::PotInvalido(MotivoPotInvalido::DiferenciaDeSlots(
            zx_core::wire_dag::ErrorDiferenciaSlots::ExcedeMaximo { diferencia: 151 }
        ))
    );
}

#[test]
fn un_descuadre_del_numero_de_portadores_invalida() {
    // `d = 3` con solo dos portadores reales.
    let cadena = generar(FLUJO, SLOT_SP, RETARDO, 2, BASE, BTreeMap::new(), |_| {
        N_FIJO
    });
    let (sp, extra) = (hash_de(0x01), hash_de(0x02));
    let cabecera = cabecera(cadena.slot_sp + 3, cadena.pot_output, sp, &[extra]);
    let contexto = contexto(&cadena, &[(sp, SLOT_SP), (extra, SLOT_SP)]);
    let justificacion = justificacion(&cadena);
    let mut cache = CachePrueba::default();
    let mut presupuesto = PresupuestoPrueba { restantes: 1_000 };

    assert_eq!(
        verificar_rango_pot(
            &cabecera,
            &justificacion,
            &contexto,
            RELOJ,
            &mut cache,
            &mut presupuesto,
        ),
        EstadoPot::PotInvalido(MotivoPotInvalido::DiferenciaDeSlots(
            zx_core::wire_dag::ErrorDiferenciaSlots::NoCoincide {
                bundles: 2,
                diferencia: 3
            }
        ))
    );
}

// ─────────────────────────────────────────────────────────────────────────────
// 9 · slot + D desbordado
// ─────────────────────────────────────────────────────────────────────────────

#[test]
fn slot_mas_d_desbordado_es_pendiente() {
    let sp = hash_de(0x01);
    let slot_sp = u64::MAX - 5;
    let cabecera = cabecera(u64::MAX - 4, [0x00; POT_OUTPUT_BYTES], sp, &[]);
    let justificacion =
        JustificacionPot::nueva(vec![PotCheckpoints::desde_bytes([0u8; BUNDLE_BYTES])])
            .expect("un portador");
    let contexto = ContextoPrueba {
        flujo: FLUJO,
        flujos_por_slot: BTreeMap::new(),
        pasado: vec![BloqueDelPasado {
            hash: sp,
            slot: slot_sp,
            flujo: FLUJO,
        }],
        inyecciones: BTreeMap::new(),
        iteraciones: BTreeMap::new(),
        retardo: 10,
        salidas: BTreeMap::new(),
    };
    let mut cache = CachePrueba::default();
    let mut presupuesto = PresupuestoPrueba { restantes: 10 };

    assert_eq!(
        verificar_rango_pot(
            &cabecera,
            &justificacion,
            &contexto,
            u64::MAX,
            &mut cache,
            &mut presupuesto,
        ),
        EstadoPot::PotPendiente(MotivoPotPendiente::AritmeticaDeSlotsDesbordada)
    );
}

// ─────────────────────────────────────────────────────────────────────────────
// 10 · N fuera de dominio (sin ejecutar AES)
// ─────────────────────────────────────────────────────────────────────────────

#[test]
fn n_cero_no_multiplo_o_mayor_que_u32_max_es_pendiente() {
    for n_malo in [0u64, 17, u64::from(u32::MAX) + 1] {
        let mut escenario = escenario(1, BTreeMap::new());
        escenario.contexto.iteraciones.insert(103, n_malo);
        assert!(
            matches!(
                verificar(&escenario, RELOJ),
                EstadoPot::PotPendiente(MotivoPotPendiente::IteracionesFueraDeDominio {
                    slot: 103,
                    ..
                })
            ),
            "N = {n_malo}"
        );
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// 11 · Doble inyección en el mismo slot
// ─────────────────────────────────────────────────────────────────────────────

#[test]
fn dos_inyecciones_en_el_mismo_slot_son_pendiente() {
    let mut escenario = escenario(1, BTreeMap::new());
    escenario
        .contexto
        .inyecciones
        .insert(103, InyeccionesPot::Varias);
    assert_eq!(
        verificar(&escenario, RELOJ),
        EstadoPot::PotPendiente(MotivoPotPendiente::InyeccionesMultiples { slot: 103 })
    );
}

// ─────────────────────────────────────────────────────────────────────────────
// 12 · Contexto circular (el ancla es el propio candidato)
// ─────────────────────────────────────────────────────────────────────────────

#[test]
fn un_ancla_que_es_el_propio_candidato_es_contexto_circular() {
    let mut escenario = escenario(1, BTreeMap::new());
    let ancla = escenario.cabecera.block_hash();
    escenario.contexto.inyecciones = inyecciones_una(103, ancla);
    assert_eq!(
        verificar(&escenario, RELOJ),
        EstadoPot::PotPendiente(MotivoPotPendiente::ContextoCircular { slot: 103 })
    );
}

// ─────────────────────────────────────────────────────────────────────────────
// 13 · Pasado incompleto y flujo discreparte
// ─────────────────────────────────────────────────────────────────────────────

#[test]
fn un_padre_ausente_del_pasado_es_pendiente() {
    let mut escenario = escenario(1, BTreeMap::new());
    escenario
        .contexto
        .pasado
        .retain(|b| b.hash != hash_de(0x02));
    assert_eq!(
        verificar(&escenario, RELOJ),
        EstadoPot::PotPendiente(MotivoPotPendiente::PasadoIncompleto)
    );
}

#[test]
fn un_flujo_de_pasado_discrepante_invalida() {
    let mut escenario = escenario(1, BTreeMap::new());
    if let Some(entrada) = escenario.contexto.pasado.first_mut() {
        entrada.flujo = [0xEE; FLUJO_BYTES];
    }
    assert!(matches!(
        verificar(&escenario, RELOJ),
        EstadoPot::PotInvalido(MotivoPotInvalido::FlujoDePasadoDiscrepa { .. })
    ));
}

#[test]
fn un_slot_de_padre_posterior_invalida() {
    let mut escenario = escenario(1, BTreeMap::new());
    if let Some(entrada) = escenario.contexto.pasado.get_mut(1) {
        entrada.slot = escenario.cabecera.slot + 1;
    }
    assert!(matches!(
        verificar(&escenario, RELOJ),
        EstadoPot::PotInvalido(MotivoPotInvalido::SlotDePadrePosterior { .. })
    ));
}

// ─────────────────────────────────────────────────────────────────────────────
// 14 · Reloj futuro y presupuesto agotado
// ─────────────────────────────────────────────────────────────────────────────

#[test]
fn un_slot_por_delante_del_reloj_es_pendiente() {
    let escenario = escenario(3, BTreeMap::new());
    assert_eq!(
        verificar(&escenario, 104),
        EstadoPot::PotPendiente(MotivoPotPendiente::RelojFuturo {
            slot: 105,
            reloj_pot: 104
        })
    );
    assert_eq!(
        verificar(&escenario, 50),
        EstadoPot::PotPendiente(MotivoPotPendiente::RelojFuturo {
            slot: 103,
            reloj_pot: 50
        })
    );
}

#[test]
fn el_presupuesto_agotado_es_pendiente_y_nunca_invalido() {
    let escenario = escenario(3, BTreeMap::new());
    let mut cache = CachePrueba::default();
    let mut presupuesto = PresupuestoPrueba { restantes: 0 };
    assert_eq!(
        verificar_rango_pot(
            &escenario.cabecera,
            &escenario.justificacion,
            &escenario.contexto,
            RELOJ,
            &mut cache,
            &mut presupuesto,
        ),
        EstadoPot::PotPendiente(MotivoPotPendiente::PresupuestoAgotado { slot: 103 })
    );
}

// ─────────────────────────────────────────────────────────────────────────────
// 15 · Caché: misma clave con portador verificado, portador alterado y solo salida
// ─────────────────────────────────────────────────────────────────────────────

fn cache_con_portadores(escenario: &Escenario, portador: EntradaCachePot) -> CachePrueba {
    let mut cache = CachePrueba::default();
    for slot in 103..=105u64 {
        let indice = usize::try_from(slot - 103).expect("índice");
        let real = escenario
            .cadena
            .portadores
            .get(indice)
            .copied()
            .expect("portador");
        let entrada = if slot == 103 {
            portador
        } else {
            EntradaCachePot {
                salida: *escenario.cadena.salidas.get(&slot).expect("salida"),
                portador: Some(real),
            }
        };
        cache.registrar(clave_de(&escenario.cadena, slot), entrada);
    }
    cache
}

#[test]
fn un_acierto_de_cache_completo_no_gasta_aes() {
    let escenario = escenario(3, BTreeMap::new());
    let mut cache = CachePrueba::default();
    for slot in 103..=105u64 {
        let indice = usize::try_from(slot - 103).expect("índice");
        cache.registrar(
            clave_de(&escenario.cadena, slot),
            EntradaCachePot {
                salida: *escenario.cadena.salidas.get(&slot).expect("salida"),
                portador: escenario.cadena.portadores.get(indice).copied(),
            },
        );
    }
    // Presupuesto CERO: si algo pasara por AES, sería `Pendiente`.
    let mut presupuesto = PresupuestoPrueba { restantes: 0 };
    assert_eq!(
        verificar_rango_pot(
            &escenario.cabecera,
            &escenario.justificacion,
            &escenario.contexto,
            RELOJ,
            &mut cache,
            &mut presupuesto,
        ),
        EstadoPot::PotValido
    );
}

#[test]
fn cache_usa_el_flujo_del_slot_al_cruzar_una_inyeccion() {
    // B está en 103, pero su rango futuro alcanza 105. La inyección de 104 cambia
    // el flujo vigente para los dos últimos portadores.
    let mut escenario = escenario(3, inyeccion_en(104, hash_de(0x30)));
    let flujo_nuevo = [0x22; FLUJO_BYTES];
    escenario.contexto.flujos_por_slot.insert(104, flujo_nuevo);
    escenario.contexto.flujos_por_slot.insert(105, flujo_nuevo);

    let mut cache = CachePrueba::default();
    for (indice, portador) in escenario.cadena.portadores.iter().enumerate() {
        let slot = 103 + u64::try_from(indice).expect("índice");
        let mut clave = clave_de(&escenario.cadena, slot);
        if slot >= 104 {
            clave.flujo = flujo_nuevo;
        }
        cache.registrar(
            clave,
            EntradaCachePot {
                salida: salida_de(portador),
                portador: Some(*portador),
            },
        );
    }

    // Con la clave del flujo anterior habría un fallo de caché y se agotaría el
    // presupuesto en 104, pese a tener todos los portadores verificados.
    let mut presupuesto = PresupuestoPrueba { restantes: 0 };
    assert_eq!(
        verificar_rango_pot(
            &escenario.cabecera,
            &escenario.justificacion,
            &escenario.contexto,
            RELOJ,
            &mut cache,
            &mut presupuesto,
        ),
        EstadoPot::PotValido
    );
}

#[test]
fn un_portador_alterado_bajo_la_misma_clave_invalida_sin_gastar_aes() {
    let escenario = escenario(3, BTreeMap::new());
    let real = escenario
        .cadena
        .portadores
        .first()
        .copied()
        .expect("primero");
    let alterado = portador_con_checkpoint_alterado(&real);
    assert_eq!(salida_de(&real), salida_de(&alterado));
    let mut cache = cache_con_portadores(
        &escenario,
        EntradaCachePot {
            salida: *escenario.cadena.salidas.get(&103).expect("salida"),
            portador: Some(alterado),
        },
    );
    let mut presupuesto = PresupuestoPrueba { restantes: 0 };
    assert_eq!(
        verificar_rango_pot(
            &escenario.cabecera,
            &escenario.justificacion,
            &escenario.contexto,
            RELOJ,
            &mut cache,
            &mut presupuesto,
        ),
        EstadoPot::PotInvalido(MotivoPotInvalido::CacheDiscrepante { slot: 103 })
    );
}

#[test]
fn una_salida_de_cache_distinta_bajo_la_misma_clave_invalida() {
    let escenario = escenario(3, BTreeMap::new());
    let mut cache = cache_con_portadores(
        &escenario,
        EntradaCachePot {
            salida: [0x00; POT_OUTPUT_BYTES],
            portador: None,
        },
    );
    let mut presupuesto = PresupuestoPrueba { restantes: 0 };
    assert_eq!(
        verificar_rango_pot(
            &escenario.cabecera,
            &escenario.justificacion,
            &escenario.contexto,
            RELOJ,
            &mut cache,
            &mut presupuesto,
        ),
        EstadoPot::PotInvalido(MotivoPotInvalido::CacheDiscrepante { slot: 103 })
    );
}

#[test]
fn una_entrada_con_solo_la_salida_no_acredita_y_gasta_aes() {
    // La coincidencia de 16 B no basta: con presupuesto cero el núcleo debe quedarse en
    // `Pendiente`, no aceptar el portador por la salida final (tensión de C-POT-07).
    let escenario = escenario(3, BTreeMap::new());
    let mut cache = cache_con_portadores(
        &escenario,
        EntradaCachePot {
            salida: *escenario.cadena.salidas.get(&103).expect("salida"),
            portador: None,
        },
    );
    let mut presupuesto = PresupuestoPrueba { restantes: 0 };
    assert_eq!(
        verificar_rango_pot(
            &escenario.cabecera,
            &escenario.justificacion,
            &escenario.contexto,
            RELOJ,
            &mut cache,
            &mut presupuesto,
        ),
        EstadoPot::PotPendiente(MotivoPotPendiente::PresupuestoAgotado { slot: 103 })
    );
}

// ─────────────────────────────────────────────────────────────────────────────
// 16 · Génesis
// ─────────────────────────────────────────────────────────────────────────────

#[test]
fn el_genesis_no_lleva_portadores_ni_se_inventa_entropia_externa() {
    let cabecera = cabecera(0, [0x00; POT_OUTPUT_BYTES], hash_de(0x01), &[]);
    let cabecera = DagBlockHeader {
        padres: PadresDag::genesis(),
        ..cabecera
    };
    let contexto = ContextoPrueba {
        flujo: FLUJO,
        flujos_por_slot: BTreeMap::new(),
        pasado: Vec::new(),
        inyecciones: BTreeMap::new(),
        iteraciones: BTreeMap::new(),
        retardo: RETARDO,
        salidas: BTreeMap::new(),
    };
    let mut cache = CachePrueba::default();
    let mut presupuesto = PresupuestoPrueba { restantes: 10 };

    assert_eq!(
        verificar_rango_pot(
            &cabecera,
            &JustificacionPot::vacia(),
            &contexto,
            RELOJ,
            &mut cache,
            &mut presupuesto,
        ),
        EstadoPot::PotPendiente(MotivoPotPendiente::GenesisSinEntropiaExterna)
    );

    let con_portadores =
        JustificacionPot::nueva(vec![PotCheckpoints::desde_bytes([0u8; BUNDLE_BYTES])])
            .expect("un portador");
    assert_eq!(
        verificar_rango_pot(
            &cabecera,
            &con_portadores,
            &contexto,
            RELOJ,
            &mut cache,
            &mut presupuesto,
        ),
        EstadoPot::PotInvalido(MotivoPotInvalido::PortadoresEnGenesis { portadores: 1 })
    );
}
