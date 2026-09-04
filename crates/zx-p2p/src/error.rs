//! Errores de la capa de red.
//!
//! # La distinción que gobierna este enum
//!
//! **Un error de un peer NO es un error del nodo** (C-NET-05). La mayoría de lo que sale mal en una
//! red es culpa de un peer concreto —o de nadie— y la respuesta correcta es desconectarlo y seguir,
//! no propagar hacia arriba. Solo los errores de configuración y de arranque suben.

use thiserror::Error;

/// Error de la capa de red.
#[derive(Debug, Error)]
pub enum P2pError {
    /// Configuración inválida. Solo puede ocurrir al construir el nodo, nunca en caliente.
    #[error("configuración de red inválida: {0}")]
    Configuracion(&'static str),

    /// No se pudo levantar el transporte.
    #[error("no se pudo levantar el transporte: {0}")]
    Transporte(&'static str),

    /// La dirección de escucha no es válida.
    #[error("dirección de escucha inválida")]
    DireccionInvalida,
}

/// Por qué se corta con un peer.
///
/// Va **separado** de [`P2pError`] a propósito: son cosas de naturaleza distinta y mezclarlas
/// invita a tratar "este peer va lento" como si fuera "el nodo está roto".
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum MotivoDesconexion {
    /// No respondió a tiempo, o respondió vacío repetidas veces. **No puntúa** (C-NET-05).
    Lento,
    /// Mandó algo que no se puede ni parsear. **No puntúa**: puede ser una versión distinta.
    Ilegible,
    /// Superó un límite de tamaño de C-NET-11. **No puntúa**, pero se corta de inmediato.
    Excedido,
    /// Violación de consenso **positivamente identificada**. Esto sí puntúa hacia el baneo.
    ViolacionDeConsenso,
}

impl MotivoDesconexion {
    /// ¿Este motivo cuenta hacia el baneo por IP?
    ///
    /// **Solo una violación de consenso identificada.** La razón está en el comentario de Zebra
    /// sobre GHSA-qhr3-cvch-5fh2: *quien te entrega un bloque no es quien eligió su altura*. Un
    /// peer honesto puede entregarte contenido malo que él no fabricó, y penalizarlo por eso deja
    /// que un tercero haga que banees a peers honestos.
    #[must_use]
    pub const fn puntua(self) -> bool {
        matches!(self, Self::ViolacionDeConsenso)
    }
}

#[cfg(test)]
mod tests {
    use super::MotivoDesconexion;

    /// **C-NET-05.** Lento y malicioso no son lo mismo, y esto lo fija.
    ///
    /// Si alguien hiciera que `Lento` puntuara, un peer con mala conexión acabaría baneado y —peor—
    /// un atacante podría provocar que baneemos a peers honestos ralentizándolos.
    #[test]
    fn solo_la_violacion_de_consenso_puntua() {
        assert!(MotivoDesconexion::ViolacionDeConsenso.puntua());
        for m in [
            MotivoDesconexion::Lento,
            MotivoDesconexion::Ilegible,
            MotivoDesconexion::Excedido,
        ] {
            assert!(!m.puntua(), "{m:?} MUST NOT puntuar hacia el baneo");
        }
    }
}
