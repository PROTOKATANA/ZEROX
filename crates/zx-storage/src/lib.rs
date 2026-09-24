//! Almacenamiento de bloques, cabeceras y UTXO en memoria o disco (feature `rocksdb`).
//!
//! Contiene implementación y tests. Existe **almacenamiento de candidatos DAG** (cola no validada
//! por `block_hash`, ver [`almacen_dag`]); la admisión, el orden y el estado DAG siguen pendientes.
//! La capa blindada también sigue pendiente. Véanse README.md de este crate y MIGRACION.md en la
//! raíz del proyecto.

#![doc = include_str!("../README.md")]

pub mod almacen;
pub mod almacen_dag;
#[cfg(feature = "rocksdb")]
pub mod disco;
pub mod error;
pub mod formato;
pub mod memoria;
pub mod utxo;

pub use almacen::{AlmacenCadena, Punta};
pub use almacen_dag::AlmacenCandidatosDag;
#[cfg(feature = "rocksdb")]
pub use disco::AlmacenEnDisco;
pub use error::StorageError;
pub use memoria::AlmacenEnMemoria;
pub use utxo::{
    ConjuntoEnMemoria, UndoData, aplicar_bloque, revertir_bloque, revertir_hasta_el_fork,
};
