//! Los cuatro tipos que `subspace-proof-of-time` necesita, reescritos sin Substrate
//! y sin nightly. Son newtypes sobre [u8;16]; no hay criptografía aquí salvo blake3
//! (crate auditado, adoptado sin modificar).
//!
//! AÑADIDO por el banco de costes (diff documentado en DIFF.md): el enum `Ruta` que
//! fuerza una ruta concreta de verificación. NO forma parte del port original.
use core::ops::{Deref, DerefMut};

macro_rules! bytes16 {
    ($n:ident) => {
        #[derive(Debug, Default, Copy, Clone, PartialEq, Eq)]
        #[repr(C)]
        pub struct $n([u8; 16]);
        impl $n { pub const SIZE: usize = 16; }
        impl From<[u8; 16]> for $n { fn from(v: [u8; 16]) -> Self { Self(v) } }
        impl AsRef<[u8; 16]> for $n { fn as_ref(&self) -> &[u8; 16] { &self.0 } }
        impl Deref for $n { type Target = [u8; 16]; fn deref(&self) -> &[u8; 16] { &self.0 } }
        impl DerefMut for $n { fn deref_mut(&mut self) -> &mut [u8; 16] { &mut self.0 } }
    };
}
bytes16!(PotKey);
bytes16!(PotSeed);
bytes16!(PotOutput);

impl PotSeed {
    /// blake3(seed)[..16] — idéntico a subspace-core-primitives/src/pot.rs:183
    pub fn key(&self) -> PotKey {
        let mut k = PotKey::default();
        k.copy_from_slice(&blake3::hash(&self.0).as_bytes()[..Self::SIZE]);
        k
    }
}
impl PotOutput {
    /// SAFETY: `#[repr(C)]` sobre [u8;16], mismo layout. Igual que pot.rs:299
    pub const fn slice_from_repr(v: &[[u8; 16]]) -> &[Self] { unsafe { core::mem::transmute(v) } }
    pub const fn repr_from_slice(v: &[Self]) -> &[[u8; 16]] { unsafe { core::mem::transmute(v) } }
    pub fn repr_from_slice_mut(v: &mut [Self]) -> &mut [[u8; 16]] { unsafe { core::mem::transmute(v) } }
}

#[derive(Debug, Default, Copy, Clone, PartialEq, Eq)]
pub struct PotCheckpoints([PotOutput; 8]);
impl PotCheckpoints {
    pub const NUM_CHECKPOINTS: core::num::NonZeroU8 = core::num::NonZeroU8::new(8).unwrap();
    pub fn output(&self) -> PotOutput { self.0[7] }
}
impl Deref for PotCheckpoints { type Target = [PotOutput; 8]; fn deref(&self) -> &Self::Target { &self.0 } }
impl DerefMut for PotCheckpoints { fn deref_mut(&mut self) -> &mut Self::Target { &mut self.0 } }

/// Ruta de verificación. AÑADIDO por el banco de costes (ver DIFF.md); no es parte
/// del port original: sirve SOLO para medir las cuatro rutas en el mismo hardware.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Ruta {
    /// Despacho normal por cpufeatures (avx512f+vaes > avx2+vaes > aes+sse4.1 > genérica).
    Auto,
    /// `verify_sequential_avx512f_vaes` forzada (16 carriles AES, 512 bits).
    Avx512fVaes,
    /// `verify_sequential_avx2_vaes` forzada (8 carriles AES, 256 bits).
    Avx2Vaes,
    /// `verify_sequential_aes_sse41` forzada (1 carril AES-NI, 128 bits).
    AesSse41,
    /// Ruta genérica del crate `aes` (sin intrínsecos propios EN ESTE PORT). El
    /// crate `aes` 0.9.3 hace su propia autodetección de AES-NI en tiempo de
    /// ejecución (`aes-0.9.3/src/lib.rs:36-46`) y la usa si la CPU la tiene: en
    /// un Zen 5 (o cualquier x86_64 con AES-NI) esta ruta corre con AES-NI, NO
    /// es AES por software. Forzar software real requiere compilar con
    /// `--cfg aes_backend="soft"` (banco `coste-salto`, operación G-pot-aes-soft).
    Generica,
}
