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

pub mod address;
pub mod amount;
pub mod digest;
pub mod encoding;
pub mod error;
pub mod firma;
mod hash;
pub mod preimage;
pub mod red;
pub mod target;
pub mod tx;

pub use address::{Address, Red};
pub use amount::{Amount, ZX_VALUE_SANITY_LIMIT};
pub use digest::{AuthDigest, BlockHash, Digest, MerkleRoot, SigHash, TxId};
pub use error::{CoreError, EncodingError};
pub use firma::{ClavePublica, Firma, verificar};
// El módulo `hash` sigue privado: `h_d` MUST ser inalcanzable desde fuera. Se reexporta únicamente
// `sha3_256_publico`, que no acepta etiqueta de dominio y por tanto no puede producir un digest de
// consenso. Ver la nota de diseño de `crate::hash`.
pub use hash::sha3_256_publico;
pub use preimage::tx::{HashType, auth_digest, sighash, txid};
pub use target::{CompactBits, TrabajoAcumulado, cumple_pow, trabajo_bloque};
pub use tx::{Lock, OutPoint, SpentOutput, Tx, TxIn, TxOut};
