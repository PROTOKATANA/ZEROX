//! Reglas de consenso de ZEROX: dificultad, timestamps, peso de bloque, emisión y selección de
//! cadena.
//!
//! Todo lo de aquí es **consensus-critical**: una divergencia de un bit entre dos nodos es un split
//! de cadena. Cada elemento cita la regla `C-XXX` del SPEC que implementa.

#![doc = include_str!("../README.md")]

pub mod dificultad;
pub mod emision;
pub mod error;
pub mod peso;
pub mod timestamps;

pub use dificultad::{VentanaRetarget, siguiente_target};
pub use emision::{recompensa_base, subsidio};
pub use error::ConsensusError;
pub use peso::{PesoValidado, limite, mediana_efectiva};
