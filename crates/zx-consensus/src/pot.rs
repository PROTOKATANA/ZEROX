//! Operaciones **puras** del PoT de ZEROX: el adaptador entre el wire y la primitiva AES de
//! `zx-pot` (`C-POT-02`, `C-POT-04`; encargo 03a) y las derivaciones de semilla, aleatoriedad y
//! reto (`C-POT-01`, `C-POT-03`; encargo 03b). Todo vive en SPEC §7.1.1.
//!
//! # Qué hay aquí
//!
//! 1. **Un slot AES** (`C-POT-02`): dadas `(semilla, N, checkpoints)`, decide si la cadena AES128
//!    secuencial reproduce esos checkpoints ([`verificar_slot_aes`]), con la conversión
//!    wire↔primitiva ([`checkpoints_a_primitiva`], [`checkpoints_a_wire`]) y la proyección de
//!    `N(s)` ([`proyectar_iteraciones`], `C-POT-04`).
//! 2. **Semilla, aleatoriedad y reto** (`C-POT-01`, `C-POT-03`): [`semilla_siguiente`] encadena la
//!    salida anterior con cero o una inyección, [`aleatoriedad_de_salida`] hashea la salida, y
//!    [`reto_desde_salida`] concatena aleatoriedad y `LE64(slot)`.
//!
//! # Qué NO es
//!
//! **No** es `validar_bloque`: no conoce flujo, procedencia de la semilla, `N(s)` del contexto,
//! inyección acreditada, sello, caché, anclaje de `pot_output` ni el orden de validación de
//! §7.1.2, y **no** está cableado a `zx-node`.
//!
//! # Origen de las entradas: no acreditado aquí
//!
//! La semilla, la entropía, la salida y `N(s)` llegan como **argumentos libres**, y ninguna de
//! estas funciones **acredita su origen causal**. Esa garantía corresponde al futuro verificador
//! contextual (§7.1.2), que no existe. En particular, [`reto_desde_salida`] deriva un reto de
//! *cualquier* salida que el llamante entregue: **estas funciones, por sí solas, no impiden
//! saltarse slots**. El candidato solo aporta los 128 B de checkpoints, que son evidencia
//! reemplazable.
//!
//! # Tres estados, sin inventarlos aquí
//!
//! `Ok(true)` es «la cadena reproduce los checkpoints», `Ok(false)` es «no los reproduce» y
//! [`ErrorContextoPot`] es «el contexto está fuera de dominio, no se pudo verificar». El futuro
//! verificador de bloque traducirá esos errores de contexto a `Pendiente` —nunca a `Inválido`—;
//! este módulo **no** implementa ese verificador ni su clasificación.

use core::num::NonZeroU32;

use thiserror::Error;
use zx_core::wire_dag::{
    CHECKPOINTS_POR_BUNDLE, POT_OUTPUT_BYTES, PotCheckpoints as PotCheckpointsWire,
};
use zx_pot::tipos::{PotCheckpoints, PotOutput, PotSeed};

/// Motivo por el que un slot **no se pudo verificar por el contexto**, no por el candidato.
///
/// Ninguno de estos casos es una prueba inválida: el adaptador acepta `N(s)` como argumento libre
/// y no acredita su origen causal, así que un valor fuera de dominio no es un defecto del
/// candidato. El futuro verificador de bloque los tratará como `Pendiente` con diagnóstico de
/// contexto, como exige `C-POT-04`.
#[derive(Debug, Error, PartialEq, Eq, Clone)]
pub enum ErrorContextoPot {
    /// `N(s) == 0`: el trabajo secuencial de un slot debe ser positivo.
    #[error("N(s) = 0: el trabajo de un slot PoT debe ser positivo")]
    IteracionesCero,
    /// `N(s) > u32::MAX`: no cabe en el dominio de la primitiva.
    #[error("N(s) = {valor} excede u32::MAX")]
    IteracionesExcedenU32 {
        /// Valor recibido como argumento.
        valor: u64,
    },
    /// `N(s) % 16 != 0`: la primitiva trabaja en múltiplos de checkpoints por dos.
    #[error("N(s) = {valor} no es múltiplo de 16")]
    IteracionesNoMultiploDe16 {
        /// Valor recibido como argumento.
        valor: u64,
    },
    /// La primitiva rechazó la terna **después** de comprobar el dominio. No debería ocurrir con
    /// `N(s)` ya proyectado; se mantiene como error de contexto para no confundirlo con una prueba
    /// inválida.
    #[error("la primitiva PoT rechazó la terna tras proyectar N(s)")]
    PrimitivaRechazada,
}

/// Proyecta `N(s): u64` al dominio de la primitiva (`C-POT-04`).
///
/// Comprueba cero, rango y múltiplo de 16 **sin `panic` y sin envolver en silencio**. El
/// adaptador recibe `n` como argumento libre: **no** acredita que provenga del pasado validado.
/// Esa garantía corresponde al futuro verificador contextual (§7.1.2).
///
/// # Errores
/// [`ErrorContextoPot`] si `n` está fuera del dominio: cero, mayor que `u32::MAX`, o no múltiplo
/// de 16.
pub fn proyectar_iteraciones(n: u64) -> Result<NonZeroU32, ErrorContextoPot> {
    let acotado =
        u32::try_from(n).map_err(|_| ErrorContextoPot::IteracionesExcedenU32 { valor: n })?;
    if acotado == 0 {
        return Err(ErrorContextoPot::IteracionesCero);
    }
    if !acotado.is_multiple_of(16) {
        return Err(ErrorContextoPot::IteracionesNoMultiploDe16 { valor: n });
    }
    NonZeroU32::new(acotado).ok_or(ErrorContextoPot::IteracionesCero)
}

/// Convierte los ocho valores de 16 B del wire a los checkpoints de la primitiva.
///
/// Es una conversión **explícita, valor a valor y comprobable**: el wire es un `[u8; 128]` opaco
/// y la primitiva un `[PotOutput; 8]`. **No** usa `transmute` ni reinterpreta el contenido.
#[must_use]
pub fn checkpoints_a_primitiva(wire: &PotCheckpointsWire) -> PotCheckpoints {
    let mut checkpoints = PotCheckpoints::default();
    for (destino, fuente) in checkpoints.iter_mut().zip(wire.outputs().iter()) {
        *destino = PotOutput::from(*fuente);
    }
    checkpoints
}

/// Convierte los checkpoints de la primitiva a los 128 B del wire, en el mismo orden.
///
/// Es la vuelta exacta de [`checkpoints_a_primitiva`], también sin `transmute`.
#[must_use]
pub fn checkpoints_a_wire(checkpoints: &PotCheckpoints) -> PotCheckpointsWire {
    let mut outputs = [[0u8; POT_OUTPUT_BYTES]; CHECKPOINTS_POR_BUNDLE];
    for (destino, fuente) in outputs.iter_mut().zip(checkpoints.iter()) {
        *destino = **fuente;
    }
    PotCheckpointsWire::desde_outputs(outputs)
}

/// **Verifica un slot AES** de la primitiva PoT (`C-POT-02`).
///
/// `semilla` y `n` —el `N(s)`— no viajan en los checkpoints del wire, pero llegan como
/// **argumentos libres**: este adaptador no acredita su origen causal, y esa garantía corresponde
/// al futuro verificador contextual. `checkpoints` es lo único que aporta el candidato. Devuelve
/// `Ok(true)` si la cadena AES128 reproduce los ocho checkpoints, `Ok(false)` si no, y `Err` si el
/// contexto está fuera de dominio. **No valida un bloque.**
///
/// La verificación es una función determinista de `(semilla, N, checkpoints)`: la misma terna da
/// el mismo resultado en cualquier nodo y en cualquier orden de llegada.
///
/// # Errores
/// [`ErrorContextoPot`] si `n` está fuera del dominio de [`proyectar_iteraciones`].
pub fn verificar_slot_aes(
    semilla: [u8; POT_OUTPUT_BYTES],
    n: u64,
    checkpoints: &PotCheckpointsWire,
) -> Result<bool, ErrorContextoPot> {
    let iteraciones = proyectar_iteraciones(n)?;
    let primitiva = checkpoints_a_primitiva(checkpoints);
    zx_pot::verify(PotSeed::from(semilla), iteraciones, &primitiva)
        .map_err(|_| ErrorContextoPot::PrimitivaRechazada)
}

// ─────────────────────────────────────────────────────────────────────────────
// Derivaciones puras de semilla, aleatoriedad y reto (C-POT-01, C-POT-03)
// ─────────────────────────────────────────────────────────────────────────────

/// Bytes de la entropía de una inyección (`C-POT-01`).
///
/// Es la entrada de 32 B que el contexto aporta en un slot con inyección. El módulo la recibe como
/// argumento libre: **no acredita** de dónde sale ni que el slot sea el declarado.
pub const ENTROPIA_BYTES: usize = 32;

/// Bytes de la aleatoriedad y del reto de un slot (`C-POT-03`).
pub const ALEATORIEDAD_BYTES: usize = 32;

/// Longitud de la concatenación `entropía ‖ salida_anterior`: 32 + 16 = 48 B (`C-POT-01`).
const ENTRADA_SEMILLA_BYTES: usize = ENTROPIA_BYTES + POT_OUTPUT_BYTES;

/// Longitud de la concatenación `aleatoriedad ‖ LE64(slot)`: 32 + 8 = 40 B (`C-POT-03`).
const ENTRADA_RETO_BYTES: usize = ALEATORIEDAD_BYTES + 8;

/// Deriva la **semilla del slot siguiente** a partir de la salida anterior (`C-POT-01`).
///
/// ```text
/// semilla(f, s) = salida(f, s−1)                                  (sin inyección)
/// semilla(f, s) = blake3(entropía(f, s) ‖ salida(f, s−1))[0..16)  (con inyección)
/// ```
///
/// `entropia = None` representa **cero inyecciones** y devuelve la salida anterior **tal cual**:
/// los mismos 16 bytes, sin pasar por blake3. `entropia = Some(..)` representa **una inyección**
/// (a lo sumo una por llamada): concatena los 32 B de entropía **primero** y los 16 B de la salida
/// después —un buffer explícito de 48 B— y trunca `blake3` a 16 B.
///
/// # Lo que esta función NO acredita
///
/// Es una fórmula **pura de sus argumentos**. No sabe quién decidió inyectar ni en qué slot, y no
/// recibe el slot: `None` o `Some(..)` los elige el llamante con entradas libres. Por sí sola
/// **no impide saltarse slots** ni sustituye a la procedencia contextual, que exigiría el flujo,
/// la semilla y el `N(s)` del pasado DAG validado (§7.1.2), hoy inexistente.
#[must_use]
pub fn semilla_siguiente(
    salida_anterior: [u8; POT_OUTPUT_BYTES],
    entropia: Option<[u8; ENTROPIA_BYTES]>,
) -> [u8; POT_OUTPUT_BYTES] {
    let Some(entropia) = entropia else {
        return salida_anterior;
    };

    // Concatenación explícita de 48 B: entropía primero, salida después. Sin `unsafe` ni
    // reinterpretación de memoria.
    let mut buffer = [0u8; ENTRADA_SEMILLA_BYTES];
    let (primera, segunda) = buffer.split_at_mut(ENTROPIA_BYTES);
    primera.copy_from_slice(&entropia);
    segunda.copy_from_slice(&salida_anterior);

    let digest = blake3::hash(&buffer);
    let (cabeza, _) = digest.as_bytes().split_at(POT_OUTPUT_BYTES);
    let mut semilla = [0u8; POT_OUTPUT_BYTES];
    semilla.copy_from_slice(cabeza);
    semilla
}

/// Deriva la **aleatoriedad** del slot a partir de su salida (`C-POT-03`).
///
/// `aleatoriedad(f, s) = blake3(salida(f, s))`, 32 B. Es una fórmula pura: **no acredita** que la
/// salida venga de la cadena secuencial hasta `s`; eso lo aporta el contexto.
#[must_use]
pub fn aleatoriedad_de_salida(salida: [u8; POT_OUTPUT_BYTES]) -> [u8; ALEATORIEDAD_BYTES] {
    blake3::hash(&salida).into()
}

/// Deriva el **reto** del slot desde su salida, en una sola ruta (`C-POT-03`).
///
/// ```text
/// reto(f, s) = blake3(aleatoriedad(f, s) ‖ LE64(s))
/// ```
///
/// Calcula la aleatoriedad **dentro de esta ruta**, llamando a [`aleatoriedad_de_salida`]; no
/// acepta una aleatoriedad precalculada ni ofrece un atajo del tipo `blake3(flujo ‖ slot)` o una
/// PRF sobre un valor fijo de época. Concatena 32 B de aleatoriedad + 8 B de `slot` en
/// **little-endian**, en un buffer explícito de 40 B y sin `unsafe`.
///
/// # Lo que esta función NO acredita
///
/// `salida` y `slot` llegan como argumentos libres: comprueba la **forma** del hash y la
/// codificación, pero no que la salida provenga de la cadena secuencial hasta `s` ni que el slot
/// sea el del candidato. Por sí sola **no impide saltarse slots**.
#[must_use]
pub fn reto_desde_salida(salida: [u8; POT_OUTPUT_BYTES], slot: u64) -> [u8; ALEATORIEDAD_BYTES] {
    let aleatoriedad = aleatoriedad_de_salida(salida);

    // Concatenación explícita de 40 B: aleatoriedad primero, `LE64(slot)` después.
    let mut buffer = [0u8; ENTRADA_RETO_BYTES];
    let (primera, segunda) = buffer.split_at_mut(ALEATORIEDAD_BYTES);
    primera.copy_from_slice(&aleatoriedad);
    segunda.copy_from_slice(&slot.to_le_bytes());

    blake3::hash(&buffer).into()
}
