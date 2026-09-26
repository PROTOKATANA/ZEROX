//! Motor de estado de la transición PoW → PoAS + PoT + DAG (`CONTRATO-v0` v0.1, `ORDEN-W03`).
//!
//! Implementa, sobre los tipos **reales** de `zx-core` (transacciones v1/v2/v3, `OutPoint`,
//! `ClavePublica`, `Lock`, firmas), la máquina de estados del contrato con las interfaces por
//! defecto `CUT-HWΦ`, `FC-3` y `SEC-0`:
//!
//! - [`aplicar`] aplica un bloque en modo estricto y devuelve el estado nuevo;
//! - [`aplicar_con_undo`] devuelve además el **undo por delta** (`I-2`);
//! - [`deshacer`] restituye el estado previo;
//! - [`seleccionar`] y [`nodo_en_linea`] implementan `FC-3` y `C-FIN-01`;
//! - [`aplicar_fusion`] es el modo fusión de `CONTRATO-ESTADO-DAG-v0` §3 (primitivas de W03).
//!
//! El alcance y lo que **no** demuestra están en `INFORME.md` de la orden.

pub mod aplicar;
pub mod error;
pub mod estado;
pub mod fusion;
pub mod seleccion;
pub mod tipos;

#[cfg(test)]
mod tests;

pub use aplicar::{aplicar, aplicar_con_undo, es_terminal, es_terminal_condiciones};
pub use error::ErrorTransicion;
pub use estado::{
    deshacer, gastable_en, invariante_i1, invariante_i1b, phi, suma_garantias, suma_utxo,
};
pub use fusion::aplicar_fusion;
pub use seleccion::{
    ResultadoSeleccion, construir_validos, mapa_por_hash, nodo_en_linea, seleccionar,
};
pub use tipos::{
    BloqueTransicion, EnRetirada, EntradaUtxo, Escalares, Estado, Fase, Garantia, HechosCabecera,
    Marca, Origen, ParametrosTransicion, Pendiente, Punto, TxDescartada, Undo,
};
