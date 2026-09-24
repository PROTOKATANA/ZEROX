//! La lógica del nodo, expuesta como librería.
//!
//! # Por qué hay `lib.rs` además de `main.rs`
//!
//! Un binario no se puede importar desde un test de integración, y las piezas que más falta hace
//! probar **entre varios nodos a la vez** —el estado de la cadena y el sincronizador— viven aquí.
//! Sin librería, el hito de la fase de red —"dos nodos se sincronizan"— solo podría comprobarse a
//! mano, y un hito que se comprueba a mano es un hito que deja de comprobarse.
//!
//! `main.rs` es entonces lo que debe ser: parseo de argumentos, cableado y bucle de apagado.
//!
//! # La frontera
//!
//! Este es el **único** crate que ve las cuatro capas a la vez. Es donde se rompe el ciclo
//! red↔consenso: `zx-p2p` declara `ManejadorEntrante` y aquí se implementa. Ver
//! `crates/zx-p2p/src/lib.rs` para el diagrama y el job de CI que lo vigila.

pub mod bootstrap_dag_dev;
pub mod cadena;
pub mod contexto_genesis_dag_dev;
pub mod contextual;
pub mod cuerpo_coinbase_dag_dev;
pub mod dag_causal;
#[cfg(feature = "farmer")]
pub mod farmer;
#[cfg(feature = "farmer")]
pub mod historia_dag_dev;
pub mod nodo;
pub mod nodo_dag_dev;
pub mod perfil_primer_hijo_dag_dev;
#[cfg(feature = "farmer")]
pub mod productor_poas;
#[cfg(feature = "farmer")]
pub mod puerta_primer_hijo_dag_dev;
pub mod sync;
