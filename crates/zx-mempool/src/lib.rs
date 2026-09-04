//! Validación de tx pendientes, orden por fee, constructor de plantilla de bloque
//!
//! Implementa: SPEC.md §<pendiente> — Fase 0, esqueleto sin lógica.

#![doc = include_str!("../README.md")]

pub mod error;
pub mod pool;
pub mod tarifa;

pub use error::MempoolError;
pub use pool::{ContextoMempool, Entrada, Mempool};
pub use tarifa::{se_admite, tarifa_minima, tarifa_por_peso};
