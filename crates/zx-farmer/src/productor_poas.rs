//! Conversión local de candidatos de disco a soluciones PoAS verificadas (D2, tramo parcial).
//!
//! # Alcance: conversión local, no productor activo
//!
//! Este módulo es **solo** la conversión `candidato de D1 → solución de Autonomys → verificación
//! de A1`. **No** es el productor de bloques del destino y no debe llamarse «productor activo»:
//!
//! - no elige padres del DAG ni baraja su cola de candidatos (SPEC §11, política de producción);
//! - no aplica el filtro de profundidad de fusión ni la kosherización (SPEC §11, *bounded merge
//!   depth*, con sus cinco valores `<<PENDIENTE>>`);
//! - no arranca desde génesis (SPEC §15.1, bootstrap pendiente);
//! - no ensambla cuerpo, cabecera, prefirma ni sello (`C-HDR-03`/`C-HDR-09`);
//! - no deriva el `pot_output` futuro de la cabecera (`C-POT-05`), que es la salida de otro slot;
//! - no firma, no admite en red y no publica.
//!
//! El contrato completo de D2 exige congelar el **snapshot causal** del pasado DAG validado
//! *antes* de derivar la salida de slot, el rango y el contexto de pieza. Esta función recibe ese
//! lote ya construido y **no acredita su procedencia**: igual que
//! [`zx_poas::verificar_solucion_poas`], confía en quien la llama. En particular, no
//! acepta datos de una cabecera candidata como contexto validado.
//!
//! # Qué significa «comprobada»
//!
//! [`SolucionComprobadaLocal`] afirma solo que la solución verificó **contra las entradas
//! proporcionadas** —el mismo `slot`, la misma `salida_slot`, el mismo `rango_validado` y el mismo
//! `contexto_pieza`— con la primitiva pública de Autonomys. No es validez global del bloque, no es
//! validez absoluta (`C-POT-08` paso 5 es una parte) y no autoriza publicación.
//!
//! # Reglas citadas
//!
//! - `C-POT-03`: el reto del slot auditado se deriva de la salida de ese slot; D1 ya lo aplica y
//!   esta función no lo rederiva.
//! - `C-POT-05`: la salida auditada **no** es el `pot_output` futuro de la cabecera.
//! - `C-POT-08` paso 5: con el PoT, el slot, el rango y el contexto de pieza ya validados, se
//!   comprueba la prueba de espacio, la distancia y los dos compromisos KZG.
//! - `C-HDR-03`/`C-HDR-09`: layout, prefirma, sello y hash de cabecera; fuera de este tramo. La
//!   selección de padres, el filtro de profundidad de fusión (SPEC §11) y el bootstrap del génesis
//!   (SPEC §15.1) quedan igualmente fuera y siguen pendientes.
//!
//! # Contadores
//!
//! Los contadores de [`DiagnosticoLocal`] son de diagnóstico **local** de esta conversión. **No**
//! son las métricas F1–F3 de la 0.0.1 ni métricas de red, y no deben presentarse como tales. No se
//! deriva de la distancia ningún peso GHOSTDAG: el peso es otra magnitud (`C-GD-01`/`C-GD-08`).

use std::num::NonZeroU64;

use subspace_core_primitives::solutions::Solution;
use subspace_erasure_coding::ErasureCoding;
use subspace_farmer_components::proving::ProvingError;
use subspace_farmer_components::reading::ReadSectorRecordChunksMode;
use subspace_kzg::Kzg;
use subspace_proof_of_space::Table;
use subspace_proof_of_space::TableGenerator;
use subspace_proof_of_space::chia::ChiaTable;
use subspace_verification::PieceCheckParams;
use thiserror::Error;
use zx_core::{ClavePublica, SolucionPoas};
use zx_poas::ErrorPoas;
use zx_poas::verificar_solucion_poas;

use crate::farmer::{ErrorFarmer, ParcelaDisco};

/// Error de la conversión local de candidatos a soluciones verificadas.
///
/// Distingue el fallo de la auditoría/parcela, el fallo de la conversión de candidatos
/// (`into_solutions` y sus lecturas) y el fallo del contexto de pieza. Un **rechazo de A1**
/// (`ErrorPoas::Prueba` distinto de `InvalidHistorySize`) **no** es un error de esta API: se
/// descarta y se cuenta en [`DiagnosticoLocal::rechazos_a1`], sin atribuir causa. Un candidato que
/// no produce solución no es error.
#[derive(Debug, Error)]
pub enum ErrorProductorPoas {
    /// Fallo al auditar la parcela o al leer sus archivos.
    #[error("auditoría de parcela: {0}")]
    Farmer(#[from] ErrorFarmer),
    /// Fallo al convertir los candidatos en soluciones: E/S, decodificación del mapa de sector,
    /// polinomio o testigo. Se propaga; no se confunde con «sin solución».
    #[error("conversión de candidatos a soluciones: {0}")]
    Proving(#[from] ProvingError),
    /// El contexto de pieza no es representable o la solución generada no lo es, incluido
    /// `ErrorPoas::Prueba(InvalidHistorySize)`, que nace de la expiración de sector y depende del
    /// contexto de pieza. Es un fallo **del contexto o de la conversión**, no del candidato. El
    /// resto de `ErrorPoas::Prueba` se descarta y se cuenta como rechazo de A1, sin atribución de
    /// causa.
    #[error("contexto de pieza no representable: {0}")]
    Contexto(#[from] ErrorPoas),
}

/// Diagnóstico local de una conversión de candidatos.
///
/// Son contadores de esta llamada, no métricas F1–F3 ni de red. Cada campo es el recuento
/// acumulado sobre todas las auditorías de sector devueltas por D1 para ese slot.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct DiagnosticoLocal {
    /// Candidatos de chunk vistos por la auditoría (`SolutionCandidates::len()`), antes de
    /// descartar los que no están codificados.
    pub candidatos: usize,
    /// Soluciones que `into_solutions` produjo (iterador recorrido con `Ok(Solution<()>)`).
    pub soluciones_generadas: usize,
    /// Soluciones generadas que A1 rechazó con `ErrorPoas::Prueba`, **sin** que este contador
    /// acredite la causa.
    ///
    /// Un rechazo **no** prueba un falso positivo del auditor A1: `ErrorPoas::Prueba` también
    /// procede de un `PieceCheckParams` inyectado incompatible (`FutureHistorySize`,
    /// `InvalidPieceOffset`, `SectorExpired`, `InvalidPiece`, …). Todos los rechazos con contexto
    /// ajeno pueden ocultar un fallo de integración causal, y esta función **no acredita la
    /// procedencia del contexto**. `InvalidHistorySize` no se cuenta aquí: se propaga por
    /// [`ErrorProductorPoas::Contexto`].
    pub rechazos_a1: usize,
    /// Soluciones que pasaron A1 y se devolvieron, con su distancia.
    pub soluciones_verificadas: usize,
}

/// Solución PoAS verificada **contra las entradas proporcionadas**.
///
/// Los campos son privados a propósito: no se puede construir una instancia sin pasar por la
/// verificación de esta API. [`Self::solucion`] y [`Self::distancia`] exponen lo comprobado.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SolucionComprobadaLocal {
    solucion: SolucionPoas,
    distancia: u64,
}

impl SolucionComprobadaLocal {
    /// La solución PoAS verificada.
    #[must_use]
    pub fn solucion(&self) -> &SolucionPoas {
        &self.solucion
    }

    /// Distancia de solución que devolvió A1 (`<= rango_validado / 2`).
    ///
    /// No es peso GHOSTDAG: es el criterio de desempate de `C-GD-03`/`C-GD-05`.
    #[must_use]
    pub fn distancia(&self) -> u64 {
        self.distancia
    }
}

/// Resultado de convertir los candidatos de un slot en soluciones verificadas.
#[derive(Debug, Default)]
pub struct ResultadoConversionLocal {
    soluciones: Vec<SolucionComprobadaLocal>,
    diagnostico: DiagnosticoLocal,
}

impl ResultadoConversionLocal {
    /// Las soluciones que pasaron A1, en el orden en que se generaron.
    #[must_use]
    pub fn soluciones(&self) -> &[SolucionComprobadaLocal] {
        &self.soluciones
    }

    /// El diagnóstico local de la conversión.
    #[must_use]
    pub fn diagnostico(&self) -> DiagnosticoLocal {
        self.diagnostico
    }
}

/// Convierte los candidatos de disco de `slot` en soluciones verificadas por A1.
///
/// # Procedimiento
///
/// 1. Llama a [`ParcelaDisco::auditar_candidatos`] con `salida_slot`, `slot` y `rango_validado`, y
///    **conserva los préstamos de la parcela y de su descriptor** durante toda la conversión.
/// 2. Por cada `AuditResult`, consume sus `solution_candidates` con
///    `SolutionCandidates::into_solutions::<(), ChiaTable, _>` en modo
///    [`ReadSectorRecordChunksMode::ConcurrentChunks`], con el `Kzg` y el `ErasureCoding`
///    recibidos y un generador **paralelo** de tablas (`ChiaTable::generator()` +
///    `generate_parallel`). No se usa la ruta no paralela de `ab-proof-of-space`.
/// 3. Convierte cada `Solution<()>` campo a campo a [`SolucionPoas`] y llama a
///    [`verificar_solucion_poas`] con **el mismo** `slot`, `salida_slot`, `rango_validado`,
///    `contexto_pieza` y `kzg`. Solo se devuelven los pares que pasaron A1.
///
/// Un candidato que no produce solución no es error. Un rechazo de A1 (`ErrorPoas::Prueba`
/// distinto de `InvalidHistorySize`) se descarta y se cuenta en
/// [`DiagnosticoLocal::rechazos_a1`], sin atribuir causa. Un fallo de E/S, de `into_solutions`,
/// de un elemento del iterador, de aritmética del contexto o de conversión no representable
/// **se propaga como error**, nunca se convierte en «sin solución». `InvalidHistorySize` se
/// propaga por [`ErrorProductorPoas::Contexto`].
///
/// # Límites
///
/// `salida_slot`, `slot`, `rango_validado` y `contexto_pieza` son el lote coherente que debe
/// inyectar un futuro snapshot causal del pasado DAG validado. Esta función **no acredita esa
/// procedencia** y no acepta datos de una cabecera candidata como contexto. No elige padres, no
/// firma y no publica.
///
/// # Errores
///
/// [`ErrorProductorPoas::Farmer`] si falla la auditoría, [`ErrorProductorPoas::Proving`] si falla
/// la conversión de candidatos y [`ErrorProductorPoas::Contexto`] si el contexto, una solución
/// generada o la expiración de sector (`InvalidHistorySize`) no son representables.
// `Se permite el número de argumentos`: la firma mantiene separadas las piezas del contexto
// inyectado (salida, slot, rango, parámetros de pieza) de las instancias de la red (KZG y erasure
// coding); agruparlas ocultaría que ninguna se fabrica aquí.
#[allow(clippy::too_many_arguments)]
pub fn convertir_candidatos_locales(
    parcela: &ParcelaDisco,
    salida_slot: [u8; 16],
    slot: u64,
    rango_validado: u64,
    contexto_pieza: &PieceCheckParams,
    kzg: &Kzg,
    erasure_coding: &ErasureCoding,
) -> Result<ResultadoConversionLocal, ErrorProductorPoas> {
    // `auditorias` retiene los préstamos de `&ParcelaDisco` y del descriptor `File` de la parcela
    // durante toda la conversión: `into_solutions` lee de ese mismo descriptor.
    let auditorias = parcela.auditar_candidatos(salida_slot, slot, rango_validado)?;

    // Vive fuera del bucle para que su préstamo cubra la conversión de cada auditoría.
    let recompensa = ();

    let mut diagnostico = DiagnosticoLocal::default();
    let mut verificadas = Vec::new();

    for auditoria in auditorias {
        let candidatos = auditoria.solution_candidates;
        diagnostico.candidatos += candidatos.len();

        // Generador paralelo, uno por auditoría: `into_solutions` lo consume por movimiento.
        let generador = ChiaTable::generator();
        let generadas = candidatos.into_solutions::<(), ChiaTable, _>(
            &recompensa,
            kzg,
            erasure_coding,
            ReadSectorRecordChunksMode::ConcurrentChunks,
            move |seed| generador.generate_parallel(seed),
        )?;

        for generada in generadas {
            let solucion_upstream = generada?;
            diagnostico.soluciones_generadas += 1;
            let solucion = a_solucion_poas(&solucion_upstream);

            match verificar_solucion_poas(
                &solucion,
                slot,
                salida_slot,
                rango_validado,
                contexto_pieza,
                kzg,
            ) {
                Ok(distancia) => {
                    diagnostico.soluciones_verificadas += 1;
                    verificadas.push(SolucionComprobadaLocal {
                        solucion,
                        distancia,
                    });
                }
                // `InvalidHistorySize` nace de `derive_expiration_history_size`, que depende de
                // `min_sector_lifetime` y del compromiso de expiración que aporta
                // `PieceCheckParams`. Es un fallo del contexto de pieza (misma clasificación que
                // `zx_poas`), no un rechazo ordinario del candidato: se
                // propaga conservando el motivo upstream, sin contarlo ni convertirlo en conjunto
                // vacío.
                Err(
                    error @ ErrorPoas::Prueba(subspace_verification::Error::InvalidHistorySize),
                ) => {
                    return Err(ErrorProductorPoas::Contexto(error));
                }
                // Rechazo de A1 con el contexto recibido. Se descarta y se cuenta, sin atribuir
                // causa: no prueba un falso positivo del auditor y, con contexto ajeno, puede
                // ocultar un fallo de integración causal.
                Err(ErrorPoas::Prueba(_)) => {
                    diagnostico.rechazos_a1 += 1;
                }
                // Contexto o representación: es un error, no un «sin solución».
                Err(error) => return Err(ErrorProductorPoas::Contexto(error)),
            }
        }
    }

    Ok(ResultadoConversionLocal {
        soluciones: verificadas,
        diagnostico,
    })
}

/// Convierte `Solution<()>` de la API de Autonomys a [`SolucionPoas`] campo a campo.
///
/// La única magnitud que puede no ser representable es `history_size = 0`; aquí se usa
/// `NonZeroU64::from(...).get()`, que reproduce el valor sin invertir la garantía de
/// [`zx_poas`]. El resto son campos de anchura fija y `piece_offset` es un `u16`.
fn a_solucion_poas(solucion: &Solution<()>) -> SolucionPoas {
    SolucionPoas {
        public_key: ClavePublica::desde_bytes(*solucion.public_key),
        sector_index: solucion.sector_index,
        history_size: NonZeroU64::from(solucion.history_size).get(),
        piece_offset: solucion.piece_offset.into(),
        record_commitment: *solucion.record_commitment,
        record_witness: *solucion.record_witness,
        chunk: *solucion.chunk,
        chunk_witness: *solucion.chunk_witness,
        proof_of_space: *solucion.proof_of_space,
    }
}
