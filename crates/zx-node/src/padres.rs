//! Elección de padres canónicos para un bloque en régimen (decisión 6; «Relanzamiento» punto 3).
//!
//! Usa el GHOSTDAG **real** de `zx-cadena` (`Cadena::contexto_dag`) para calcular el padre
//! seleccionado: nunca el atajo dev de `zx_post::ContextoTransicion`. Tope de **3** padres en total
//! (`PROGRESO.md` punto 8: `zx-cadena` no acepta más, aunque el perfil dev hable de 15).

use zx_cadena::Cadena;
use zx_core::{BlockHash, PadresDag};
use zx_dag::ErrorDag;
use zx_dag::bloque_dag::ContextoDag;

/// Tope real de padres que `zx-cadena` admite por bloque (`crates/zx-cadena/src/cadena.rs`,
/// `MAX_PADRES_ORACULO`). No configurable desde fuera del crate.
pub const MAX_PADRES_CADENA: usize = 3;

/// Fallo al elegir padres.
#[derive(Debug, thiserror::Error)]
pub enum ErrorPadres {
    /// Aún no hay terminal fijado: no hay DAG que consultar.
    #[error("no hay terminal fijado: no se pueden elegir padres de régimen")]
    SinTerminal,
    /// No hay ninguna punta válida todavía (se debe usar el bloque de transición, no régimen).
    #[error("no hay puntas válidas: el siguiente bloque es el de transición, no de régimen")]
    SinPuntas,
    /// Fallo de GHOSTDAG al calcular el padre seleccionado real.
    #[error("GHOSTDAG: {0}")]
    Dag(#[from] ErrorDag),
    /// El formato de padres rechazó la combinación (no debería, ya que se controla el tope).
    #[error("formato de padres: {0}")]
    Formato(#[from] zx_core::EncodingError),
}

/// Elige los padres canónicos del próximo bloque en régimen: hasta [`MAX_PADRES_CADENA`] puntas
/// válidas actuales de `cadena`, con el padre seleccionado calculado por el GHOSTDAG real (no
/// declarado).
///
/// Si hay más puntas que el tope, se toman las primeras en orden de hash (determinista); es un
/// compromiso documentado (`PROGRESO.md` punto 8), no una elección por peso: con 3 claves propias en
/// un solo proceso el número de puntas vivas rara vez lo alcanza.
///
/// # Errores
/// [`ErrorPadres::SinTerminal`], [`ErrorPadres::SinPuntas`] o los de GHOSTDAG/formato.
pub fn padres_de_regimen(cadena: &Cadena) -> Result<PadresDag, ErrorPadres> {
    let dag = cadena.contexto_dag().ok_or(ErrorPadres::SinTerminal)?;
    let mut tips = cadena.tips_validas();
    if tips.is_empty() {
        return Err(ErrorPadres::SinPuntas);
    }
    tips.truncate(MAX_PADRES_CADENA);

    if tips.len() == 1 {
        #[expect(
            clippy::indexing_slicing,
            reason = "se comprobó tips.len() == 1 en la rama anterior"
        )]
        let unico = tips[0];
        return Ok(PadresDag::nuevo(unico, &[])?);
    }

    // `padre_seleccionado` ignora qué posición se declara «seleccionado»: el `sp` real lo decide
    // GHOSTDAG (C-GD-03). Se construye un `PadresDag` provisional solo para preguntarlo.
    #[expect(
        clippy::indexing_slicing,
        reason = "se comprobó tips.len() >= 2 en la rama anterior"
    )]
    let (primero, resto) = (tips[0], &tips[1..]);
    let provisional = PadresDag::nuevo(primero, resto)?;
    let sp: BlockHash = ContextoDag::padre_seleccionado(dag, &provisional)?;

    let extras: Vec<BlockHash> = tips.into_iter().filter(|h| *h != sp).collect();
    Ok(PadresDag::nuevo(sp, &extras)?)
}

#[cfg(test)]
mod tests {
    // Cubierto de extremo a extremo por `tests/integracion.rs` (padres reales sobre GHOSTDAG real).
}
