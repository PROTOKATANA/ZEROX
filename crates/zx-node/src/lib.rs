//! `zx-node`: nodo de la red dev de ZEROX en un solo proceso, sin red (`ORDEN-W06d1`).
//!
//! Un proceso que arranca de la red dev, mina PoW, deposita garantía con sus propias claves, cruza
//! el corte, produce bloques PoST en régimen con su hilo PoT y su granjero, persiste, y al reiniciar
//! reconstruye el mismo estado. La red (mensajes, sincronización) es `W06d2`.
//!
//! Ver `README` de la orden en `P-ZRX/P-NODO/ORDEN-W06d1.md` y las decisiones/límites en
//! `deepseek/W06d1/PROGRESO.md`.

pub mod claves;
pub mod cli;
pub mod error;
pub mod estado_resumen;
pub mod evidencia;
pub mod identidad;
pub mod nodo;
pub mod padres;
pub mod perfil;
pub mod pow;
pub mod rechazo;
pub mod red;
pub mod regimen;
pub mod registro;

pub use error::{ErrorNodo, ResultadoNodo};
pub use nodo::{Config, Nodo};
