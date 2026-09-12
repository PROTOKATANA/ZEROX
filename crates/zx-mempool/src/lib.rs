//! Admisión de transacciones, tarifas y selección para bloques.
//!
//! Contiene implementación y tests; la integración del nodo y del estado DAG sigue pendiente.
//! Véanse README.md de este crate y MIGRACION.md en la raíz del proyecto.

#![doc = include_str!("../README.md")]

pub mod error;
pub mod pool;
pub mod tarifa;

pub use error::MempoolError;
pub use pool::{ContextoMempool, Entrada, Mempool};
pub use tarifa::{se_admite, tarifa_minima, tarifa_por_peso};
