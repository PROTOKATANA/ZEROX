//! # Prototipo P-FIRMANTE — el firmante seguro
//!
//! Un **filtro de accidentes honestos**, no un mecanismo de seguridad: impide que un productor
//! honesto firme dos veces la misma oportunidad por tener dos nodos, por reiniciar con el estado
//! perdido o por reconstruir el candidato cuando cambia la punta.
//!
//! La especificación completa está en `P-ZRX/P-FIRMANTE/ESPECIFICACION.md` §3 (copia congelada de
//! `P-ZRX/P-EQUIVOCACION/investigacion/FALSOS-POSITIVOS.md`). Las reglas del consenso que la
//! enmarcan están en `SPEC.md` §11 (`C-GD-03`, `C-GD-04`, `C-GD-07`, `C-GD-10`) y `C-HDR-07`.
//!
//! # Las tres piezas
//!
//! - [`identidad`] — **qué** identifica una oportunidad. Es el punto de extensión: la definición
//!   vigente (`C-GD-07`/R-FIN-11) es la de por defecto, y hay una segunda implementación para
//!   demostrar que la extensión funciona.
//! - [`registro`] — **dónde** se persiste `(identidad, slot) -> pre_hash`, con `fsync` antes de
//!   devolver y bloqueo de fichero entre procesos. Es el punto 3 de la regla.
//! - [`firmante`] — **la política**: decidir, persistir y solo entonces sellar.
//!
//! # Lo que este crate NO es
//!
//! No toca el consenso, no fija ningún parámetro (`S_max_slots` entra como parámetro; ver
//! [`identidad::S_MAX_SLOTS_NOMINAL`] para su procedencia) y no propone texto de `SPEC.md`. La
//! lista de lo que no cubre está en `informe/INFORME.md` y en la documentación de
//! [`registro::Registro`].

#![deny(unsafe_code)]
#![warn(missing_docs)]

pub mod aborto;
pub mod firmante;
pub mod identidad;
pub mod registro;

pub use firmante::{Firmante, FirmanteError, Resultado};
pub use identidad::{
    DOMINIO_TICKET_CON_RED, DOMINIO_TICKET_VIGENTE, IdentidadOportunidad, IdentidadTicket,
    LONGITUD_HUELLA, S_MAX_SLOTS_NOMINAL, VERSION_ESQUEMA,
};
pub use registro::{Registro, RegistroError, Resolucion};
