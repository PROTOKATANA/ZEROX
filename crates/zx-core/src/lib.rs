//! Tipos base, hash con dominio y codificación canónica de ZEROX.
//!
//! Este crate es la raíz de la que cuelga todo lo consensus-critical. Su responsabilidad es que
//! **dos nodos cualesquiera produzcan exactamente los mismos bytes y exactamente los mismos
//! digests** para el mismo objeto. Cualquier fuente de divergencia aquí es un split de cadena.
//!
//! Cada elemento cita la regla `C-XXX` del SPEC que implementa. Si el código y el SPEC discrepan,
//! el SPEC manda y el procedimiento es
//! `DETENER → INVESTIGAR → PROPONER CAMBIO → ACTUALIZAR SPEC → CONTINUAR`.
//!
//! # La invariante de diseño de este crate
//!
//! Cap'n Proto serializa para wire y disco, y **no es consensus-critical** (C-ENC-08). Lo que se
//! hashea y se firma es la preimagen canónica de §4, byte a byte, definida aquí.
//!
//! Confundir las dos sería un split silencioso, así que no se deja a la disciplina: la función de
//! hash con dominio es `pub(crate)`, y **no existe ninguna función pública que acepte `&[u8]`
//! arbitrarios y una etiqueta de dominio**. La defensa es la ausencia de una firma invocable, no un
//! comentario. `zx-core` tampoco depende de `capnp`: no puede ni nombrar un tipo de wire.

#![doc = include_str!("../README.md")]

pub mod digest;
pub mod encoding;
pub mod error;
mod hash;

pub use digest::{AuthDigest, BlockHash, Digest, MerkleRoot, SigHash, TxId};
pub use error::{CoreError, EncodingError};
