//! RocksDB + flat files: bloques, cabeceras, UTXO set, árbol de commitments, nullifier set
//!
//! Implementa: SPEC.md §<pendiente> — Fase 0, esqueleto sin lógica.

#![doc = include_str!("../README.md")]

pub mod almacen;
#[cfg(feature = "rocksdb")]
pub mod disco;
pub mod error;
pub mod memoria;
pub mod utxo;

pub use almacen::{AlmacenCadena, Punta};
#[cfg(feature = "rocksdb")]
pub use disco::AlmacenEnDisco;
pub use error::StorageError;
pub use memoria::AlmacenEnMemoria;
pub use utxo::{
    ConjuntoEnMemoria, UndoData, aplicar_bloque, revertir_bloque, revertir_hasta_el_fork,
};
