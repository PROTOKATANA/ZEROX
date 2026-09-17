//! Capa de red de ZEROX sobre libp2p (SPEC §16).
//!
//! # Lo que este crate NO hace
//!
//! **No decide nada.** No valida bloques, no elige cadena, no toca el estado. Transporta bytes y
//! los entrega a `zx-consensus` para que decida. Esa frontera es lo que mantiene el consenso
//! testeable sin red y la red testeable sin cadena.
//!
//! # El principio que gobierna todo el crate
//!
//! **Ningún límite de transporte se deja en su valor por defecto** (C-NET-11). La capa de
//! transporte de libp2p no es segura por defecto para una cadena, y sus cuatro defaults peligrosos
//! **no fallan al compilar** — se propagan como bloques que nunca llegan o memoria que se agota.
//! Ver [`limites`].
//!
//! # La frontera, y por qué es una regla y no un gusto
//!
//! ```text
//! zx-node ──▶ zx-p2p ──▶ zx-core
//!    │                      ▲
//!    ├──▶ zx-consensus ─────┤
//!    ├──▶ zx-storage ───────┤
//!    └──▶ zx-mempool ───────┘
//! ```
//!
//! **`zx-p2p` NO depende de `zx-consensus`, `zx-storage` ni `zx-mempool`** — solo de `zx-core`,
//! que son tipos puros. `zx-consensus` aparece únicamente en `[dev-dependencies]`, para que los
//! tests puedan comprobar que los límites de transporte siguen siendo coherentes con los de
//! consenso.
//!
//! La razón no es estética. Red y consenso se necesitan **en las dos direcciones**: la red valida
//! lo que recibe, y el sincronizador pide bloques por la red. Si `zx-p2p` pudiera ver
//! `zx-consensus`, ese ciclo se cerraría poco a poco y sin que nadie lo decidiera. Cortado desde el
//! `Cargo.toml`, **no se puede cerrar por accidente**: el ciclo se rompe en `zx-node`, que es el
//! único que ve las cuatro cosas a la vez.
//!
//! Es el mismo reparto que `zebra-network` —cuya única dependencia interna es `zebra-chain`, tipos
//! puros— frente a `zebrad`, y que `lighthouse_network` frente a `beacon_node/network`.
//!
//! Se cortó **el mismo día que se escribió la primera línea del crate**, tras descubrir que la
//! dependencia ya estaba puesta. Es la única parte de esta arquitectura que duele arreglar tarde:
//! re-cablear un `Cargo.toml` que lleva meses acumulando tipos mezclados no es mover una línea.
//!
//! # Estado
//!
//! En construcción (Fase 5). Hecho: parámetros de red, límites, composición de behaviours.

pub mod behaviour;
pub mod codec;
pub mod config;
pub mod entrante;
pub mod error;
pub mod id_corto;
pub mod limites;
pub mod limites_ip;
pub mod mensaje;
pub mod presupuesto;
pub mod rele_compacto;
pub mod servicio;
