//! RocksDB + flat files: bloques, cabeceras, UTXO set, árbol de commitments, nullifier set
//!
//! Implementa: SPEC.md §<pendiente> — Fase 0, esqueleto sin lógica.

#![doc = include_str!("../README.md")]

pub mod error;
pub mod utxo;

pub use error::StorageError;
pub use utxo::{
    ConjuntoEnMemoria, UndoData, aplicar_bloque, revertir_bloque, revertir_hasta_el_fork,
};
