//! Prototipo S01: compromiso R1/R2 de un sector PoAS real y apertura de una solución ganadora.
//!
//! Resultado de investigación **aislado**: nada de este crate entra en el workspace de ZEROX ni en
//! el consenso. Ver `../../INFORME.md` y `../../ESPECIFICACION-BYTES.md`.

pub mod estrategias;
pub mod h_d;
pub mod merkle;
pub mod r2;
pub mod regeneracion;
pub mod registro;
pub mod sector;

pub use h_d::{
    TAG_ALTA, TAG_HOJA, TAG_MAPA, TAG_META, TAG_NODO, TAG_RAIZ, TAG_VACIO, h_d,
};
pub use merkle::{Merkle, nodo, raiz_desde_camino};
pub use r2::{
    Apertura, CBID_PRUEBA, CamposPublicos, CompromisoR1, CompromisoR2, ErrorApertura, NUM_CHUNKS,
    VERSION_R2, compromiso_r1, compromiso_r2, compromiso_r2_con_version, digest_mapa, digest_meta,
    hoja, preimagen_r2, verificar_apertura,
};
pub use registro::{Alta, ClaveSector, ErrorRegistro, RegistroSectores};
pub use sector::{
    Entorno, ErrorSector, NUM_S_BUCKETS, ParametrosPlot, SEMILLA_SPLITMIX_DEV, Sector,
    llenar_determinista,
};
