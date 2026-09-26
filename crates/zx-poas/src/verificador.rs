//! Verificación de una `SolucionPoas` de ZEROX con la API pública de Autonomys.
//!
//! # Qué cubre
//!
//! Adapta `subspace_verification::verify_solution::<ChiaTable, _>` al tipo
//! [`zx_core::SolucionPoas`]. Cubre el **paso 5 de `C-POT-08`**: cuando el PoT del **slot
//! auditado** (`C-POT-03`), el slot, el rango y el contexto de pieza ya vienen **validados por el
//! pasado**, comprueba la prueba de espacio, la distancia de solución y los dos compromisos KZG
//! (chunk↔record y record↔segmento).
//!
//! # Qué NO es
//!
//! **No valida un bloque completo.** Los pasos 1–4 de `C-POT-08` (estructura, flujo, caché y AES
//! secuencial), el sello, la cabecera y la validez absoluta siguen pendientes y corresponden a
//! otras piezas. En particular, esta función no deriva el flujo ni comprueba el pasado: recibe el
//! resultado ya acreditado como argumento. Tampoco declara implementada la validez absoluta.
//!
//! # El contexto de pieza no es opcional
//!
//! La firma recibe `&subspace_verification::PieceCheckParams`, **no** `Option<...>`. El `None` de
//! upstream **omite** la comprobación de inclusión de la pieza en la historia; esta adaptación
//! construye siempre `piece_check_params: Some(...)` y no ofrece una ruta que lo omita.
//!
//! # Frontera de confianza
//!
//! `slot`, `salida_pot_verificada`, `rango_validado` y `contexto_pieza` son argumentos del
//! **contexto ya validado**, nunca valores elegidos a partir de `solucion`. El llamante es
//! responsable de su procedencia; esta función no la acredita.
//!
//! `salida_pot_verificada` es la salida del **slot auditado** que `C-POT-03` usa para derivar el
//! reto, **no** el `pot_output` de la cabecera: ése es la salida **futura**
//! `salida(f, slot(B) + D)` de `C-POT-05`, anclada en otro slot, y no sirve para auditar la PoS de
//! éste.
//!
//! # Precondiciones aritméticas del contexto
//!
//! `PieceCheckParams` es público y su tipo **no** garantiza los rangos que upstream asume. Allí
//! `subspace-verification/src/lib.rs` calcula `current_history_size + 1`, y
//! `SectorId::derive_piece_index` (`subspace-core-primitives/src/sectors.rs`) multiplica y resta
//! con aritmética ordinaria; además `HistorySize::in_pieces` **satura**. Antes de llamar a
//! upstream, [`comprobar_aritmetica_contexto`] reproduce esos operandos con `checked_*` y
//! devuelve [`ErrorPoas::ContextoInvalido`] si el contexto los hace irrepresentables.
//!
//! No se impone ningún tope de consenso: el fixture válido usa
//! `recent_segments = 5 > history_size = 3` y se acepta porque la rama reciente de upstream no se
//! ejecuta. Tampoco se reimplementa el resultado —no se calcula el índice de pieza ni se toca la
//! máscara, la distancia o KZG—: solo se comprueba que la aritmética de upstream no desborde ni
//! reste en negativo.
//!
//! La rama `sector_expiration_check_segment_commitment` de upstream queda fuera de esta
//! comprobación porque ya usa `checked_*` internamente y devuelve `Error::InvalidHistorySize` en
//! vez de desbordar; no puede provocar un `panic`.
//!
//! # Procedencia
//!
//! Dependencias enlazadas por `path` al clon fijado `PDF/autonomys-subspace` @ `f8842d0`. No se
//! copia ni se reimplementa KZG, PoS, la máscara del chunk ni la distancia.

use std::num::NonZeroU64;

use subspace_core_primitives::pieces::{PieceOffset, RecordCommitment, RecordWitness};
use subspace_core_primitives::pos::PosProof;
use subspace_core_primitives::pot::PotOutput;
use subspace_core_primitives::segments::{ArchivedHistorySegment, HistorySize};
use subspace_core_primitives::solutions::{ChunkWitness, Solution};
use subspace_core_primitives::{PublicKey, ScalarBytes};
use subspace_kzg::Kzg;
use subspace_proof_of_space::chia::ChiaTable;
use subspace_verification::{PieceCheckParams, VerifySolutionParams};
use zx_core::SolucionPoas;

/// Piezas de un segmento de historia archivada.
///
/// Es `ArchivedHistorySegment::NUM_PIECES` del clon fijado (`128 × 2 / 1 = 256`). Se toma la
/// constante del crate, no se escribe a mano.
const PIEZAS_POR_SEGMENTO: u64 = ArchivedHistorySegment::NUM_PIECES as u64;

/// Motivo por el que el contexto de pieza no es aritméticamente representable en upstream.
///
/// Son precondiciones que `PieceCheckParams` **no** garantiza por tipo. No son topes de consenso:
/// solo verifican que las operaciones `+ 1`, `*` y `-` de `subspace-verification/src/lib.rs` y
/// `subspace-core-primitives/src/sectors.rs` no desborden ni resten en negativo con el contexto y
/// la solución recibidos.
#[derive(Debug, PartialEq, Eq, thiserror::Error)]
pub enum ContextoInvalido {
    /// `current_history_size + 1` (upstream, `verify_solution`) desbordaría `u64`.
    #[error("current_history_size = u64::MAX: la suma `+ 1` de upstream desborda")]
    CurrentHistorySizeSinMargen,
    /// `recent_segments.in_pieces()` (upstream) saturaría al multiplicar por
    /// `ArchivedHistorySegment::NUM_PIECES`.
    #[error("recent_segments = {0} no cabe en piezas sin saturar u64")]
    RecentSegmentsEnPiezas(u64),
    /// Un miembro de `recent_history_fraction` no cabe en piezas sin saturar.
    #[error("recent_history_fraction.{miembro} = {segmentos} no cabe en piezas sin saturar u64")]
    FraccionEnPiezas {
        /// `"0"` (divisor) o `"1"` (multiplicador) del par de la fracción.
        miembro: &'static str,
        /// Talla recibida, en segmentos.
        segmentos: u64,
    },
    /// `recent_segments_in_pieces * recent_history_fraction.1.in_pieces()` desborda `u64`.
    #[error(
        "recent_segments ({reciente_piezas} piezas) × fracción ({multiplicador} piezas) desborda u64"
    )]
    UmbralRecienteDesborda {
        /// `recent_segments` ya en piezas.
        reciente_piezas: u64,
        /// `recent_history_fraction.1` ya en piezas.
        multiplicador: u64,
    },
    /// `max_pieces_in_sector * recent_history_fraction.0.in_pieces() ... * 2` desborda `u64`.
    #[error("las piezas intercaladas del sector desbordan u64")]
    PiezasIntercaladasDesbordan {
        /// `max_pieces_in_sector` del contexto.
        max_pieces_in_sector: u16,
        /// `recent_history_fraction.0` ya en piezas.
        divisor_piezas: u64,
    },
    /// La rama reciente de upstream restaría en negativo: solo se informa cuando la condición
    /// exacta de upstream ejecuta la resta `history_size_in_pieces - recent_segments_in_pieces`.
    #[error("la rama reciente restaría {historia_piezas} − {reciente_piezas} piezas de historia")]
    RestaRecienteNegativa {
        /// `history_size` del candidato ya en piezas.
        historia_piezas: u64,
        /// `recent_segments` del contexto ya en piezas.
        reciente_piezas: u64,
    },
}

/// Error al verificar una `SolucionPoas` con la primitiva de Autonomys.
#[derive(Debug, PartialEq, Eq, thiserror::Error)]
pub enum ErrorPoas {
    /// La solución no se puede convertir a la representación de upstream, o una magnitud del
    /// candidato no es representable en la aritmética de upstream.
    ///
    /// Cubre `history_size = 0` (upstream usa `NonZeroU64`), un `chunk_witness` que no cabe y una
    /// `history_size` cuyo paso a piezas desborda `u64` (`HistorySize::in_pieces` satura y la
    /// saturación no se acepta como dato). No se redondea ni se sustituye por 1: la entrada es
    /// inválida y se informa como tal, sin `panic`.
    #[error("entrada no canónica: la solución no es representable por la primitiva upstream")]
    EntradaNoCanonica,
    /// El contexto de pieza no cumple las precondiciones aritméticas de upstream.
    ///
    /// Es un fallo **del contexto**, distinto de una prueba inválida del candidato.
    #[error("contexto de pieza inválido: {0}")]
    ContextoInvalido(ContextoInvalido),
    /// La primitiva upstream rechazó la prueba.
    ///
    /// Conserva el error concreto de `subspace_verification` como fuente, sin transformarlo en
    /// `Ok` ni en un booleano.
    #[error("la solución PoAS no verifica: {0}")]
    Prueba(#[source] subspace_verification::Error),
}

/// Convierte segmentos a piezas **sin** aceptar la saturación de `HistorySize::in_pieces`.
///
/// `in_pieces` multiplica con `saturating_mul`, así que un valor saturado no distingue «cabe» de
/// «no cabe». Se reproduce aquí la multiplicación original con [`u64::checked_mul`]: `None`
/// significa que el dato no es representable como piezas.
fn a_piezas(size: HistorySize) -> Option<u64> {
    size.get().checked_mul(PIEZAS_POR_SEGMENTO)
}

/// Comprueba que la aritmética de upstream no desborda ni resta en negativo con este contexto y
/// esta solución (ver la cabecera del módulo).
///
/// Reproduce los operandos de `subspace-verification/src/lib.rs` y de
/// `SectorId::derive_piece_index`; **no** calcula el índice de pieza. Las divisiones usan
/// [`u64::div_euclid`] para dejar explícito que son la división entera exacta de upstream.
fn comprobar_aritmetica_contexto(
    solucion: &SolucionPoas,
    contexto: &PieceCheckParams,
) -> Result<(), ErrorPoas> {
    // `subspace-verification/src/lib.rs`: `current_history_size + 1`, sin comprobar.
    if contexto.current_history_size.get().checked_add(1).is_none() {
        return Err(ErrorPoas::ContextoInvalido(
            ContextoInvalido::CurrentHistorySizeSinMargen,
        ));
    }

    // `HistorySize::in_pieces` satura: comprobar la multiplicación original de cada talla.
    let reciente = a_piezas(contexto.recent_segments).ok_or(ErrorPoas::ContextoInvalido(
        ContextoInvalido::RecentSegmentsEnPiezas(contexto.recent_segments.get()),
    ))?;
    let (fraccion_divisor, fraccion_multiplicador) = contexto.recent_history_fraction;
    let divisor = a_piezas(fraccion_divisor).ok_or(ErrorPoas::ContextoInvalido(
        ContextoInvalido::FraccionEnPiezas {
            miembro: "0",
            segmentos: fraccion_divisor.get(),
        },
    ))?;
    let multiplicador = a_piezas(fraccion_multiplicador).ok_or(ErrorPoas::ContextoInvalido(
        ContextoInvalido::FraccionEnPiezas {
            miembro: "1",
            segmentos: fraccion_multiplicador.get(),
        },
    ))?;

    // `derive_piece_index`: `recent_segments_in_pieces * frac.1 / frac.0`.
    let umbral_reciente =
        reciente
            .checked_mul(multiplicador)
            .ok_or(ErrorPoas::ContextoInvalido(
                ContextoInvalido::UmbralRecienteDesborda {
                    reciente_piezas: reciente,
                    multiplicador,
                },
            ))?;
    // `divisor` procede de un `HistorySize` no nulo y no saturado: es `>= 256`, nunca cero.
    let min_historia = umbral_reciente.div_euclid(divisor);

    // `derive_piece_index`: `max_pieces_in_sector * frac.0 / frac.1 * 2`, de izquierda a derecha.
    let intercaladas_brutas = u64::from(contexto.max_pieces_in_sector)
        .checked_mul(divisor)
        .ok_or(ErrorPoas::ContextoInvalido(
            ContextoInvalido::PiezasIntercaladasDesbordan {
                max_pieces_in_sector: contexto.max_pieces_in_sector,
                divisor_piezas: divisor,
            },
        ))?;
    let num_intercaladas = intercaladas_brutas
        .div_euclid(multiplicador)
        .checked_mul(2)
        .ok_or(ErrorPoas::ContextoInvalido(
            ContextoInvalido::PiezasIntercaladasDesbordan {
                max_pieces_in_sector: contexto.max_pieces_in_sector,
                divisor_piezas: divisor,
            },
        ))?
        .max(1);

    // La talla de historia del candidato también pasa por `in_pieces` en upstream; si su
    // multiplicación original no cabe, la entrada no es canónica.
    let historia = solucion
        .history_size
        .checked_mul(PIEZAS_POR_SEGMENTO)
        .ok_or(ErrorPoas::EntradaNoCanonica)?;

    // Resta exacta de la rama reciente de upstream, y **solo** bajo sus tres condiciones. El
    // fixture válido (`recent_segments = 5 > history_size = 3`) no entra y sigue aceptándose.
    let offset = u64::from(solucion.piece_offset);
    if historia > min_historia
        && offset < num_intercaladas
        && solucion.piece_offset % 2 == 1
        && historia < reciente
    {
        return Err(ErrorPoas::ContextoInvalido(
            ContextoInvalido::RestaRecienteNegativa {
                historia_piezas: historia,
                reciente_piezas: reciente,
            },
        ));
    }

    Ok(())
}

/// Convierte `SolucionPoas` de ZEROX a la `Solution<()>` de upstream.
///
/// Es una conversión **comprobada**: en este paso la única magnitud que no cabe es
/// `history_size = 0`, que upstream modela con `NonZeroU64`. El paso a piezas del candidato se
/// comprueba aparte en [`comprobar_aritmetica_contexto`]. El resto son campos de anchura fija.
fn a_solucion_upstream(solucion: &SolucionPoas) -> Result<Solution<()>, ErrorPoas> {
    let history_size =
        NonZeroU64::new(solucion.history_size).ok_or(ErrorPoas::EntradaNoCanonica)?;

    Ok(Solution {
        public_key: PublicKey::from(*solucion.public_key.bytes()),
        // ZEROX es UTXO y no lleva dirección de recompensa en la solución.
        reward_address: (),
        sector_index: solucion.sector_index,
        history_size: HistorySize::new(history_size),
        piece_offset: PieceOffset::from(solucion.piece_offset),
        record_commitment: RecordCommitment::from(solucion.record_commitment),
        record_witness: RecordWitness::from(solucion.record_witness),
        chunk: ScalarBytes::from(solucion.chunk),
        chunk_witness: ChunkWitness::try_from(solucion.chunk_witness.as_slice())
            .map_err(|_| ErrorPoas::EntradaNoCanonica)?,
        proof_of_space: PosProof::from(solucion.proof_of_space),
    })
}

/// Verifica una `SolucionPoas` contra el contexto ya validado (paso 5 de `C-POT-08`).
///
/// Construye `VerifySolutionParams` con `piece_check_params: Some(contexto_pieza.clone())` y llama
/// a la primitiva pública `subspace_verification::verify_solution::<ChiaTable, _>`. Devuelve la
/// **distancia de solución** (`<= rango_validado / 2`) que upstream calcula. No es la entrada de
/// peso de `C-GD-01`/`C-GD-08`: ésas usan el `rango_validado` (el `SR` validado, `C-GD-01`).
/// `solution_distance` es el criterio de desempate de `C-GD-03` —y por tanto la segunda clave del
/// orden de `C-GD-05`— cuando dos bloques empatan en `blue_work`.
///
/// # Argumentos
///
/// - `solucion`: solución PoAS del bloque candidato.
/// - `slot`: índice de PoT del bloque, **del contexto**.
/// - `salida_pot_verificada`: salida de 16 B del **slot auditado** (`C-POT-03`), **del contexto**;
///   no es el `pot_output` futuro de la cabecera (`C-POT-05`).
/// - `rango_validado`: rango de solución **del contexto**, nunca el declarado por el candidato.
/// - `contexto_pieza`: parámetros de pieza **del contexto**; obligatorio. Sus precondiciones
///   aritméticas se comprueban antes de llamar a upstream.
/// - `kzg`: parámetros KZG de la red.
///
/// # Errores
///
/// [`ErrorPoas::EntradaNoCanonica`] si la conversión falla o una talla del candidato no es
/// representable (por ejemplo, `history_size = 0`), [`ErrorPoas::ContextoInvalido`] si el contexto
/// desborda la aritmética de upstream, y [`ErrorPoas::Prueba`] con el error upstream concreto si
/// la prueba no verifica.
pub fn verificar_solucion_poas(
    solucion: &SolucionPoas,
    slot: u64,
    salida_pot_verificada: [u8; 16],
    rango_validado: u64,
    contexto_pieza: &PieceCheckParams,
    kzg: &Kzg,
) -> Result<u64, ErrorPoas> {
    let solucion_upstream = a_solucion_upstream(solucion)?;
    comprobar_aritmetica_contexto(solucion, contexto_pieza)?;

    // El contexto de pieza es obligatorio: nunca `None`. Un `None` aquí omitiría la comprobación
    // de que la pieza pertenece a la historia (upstream, `subspace-verification/src/lib.rs`).
    let parametros = VerifySolutionParams {
        proof_of_time: PotOutput::from(salida_pot_verificada),
        solution_range: rango_validado,
        piece_check_params: Some(contexto_pieza.clone()),
    };

    subspace_verification::verify_solution::<ChiaTable, _>(
        &solucion_upstream,
        slot,
        &parametros,
        kzg,
    )
    .map_err(ErrorPoas::Prueba)
}
