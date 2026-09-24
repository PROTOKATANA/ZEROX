//! Costura de la puerta conjunta A3 para el **primer hijo** del génesis DAG de desarrollo
//! (incremento A3/D2 parcial).
//!
//! # Qué es y qué no es
//!
//! [`verificar_primer_hijo_dag_dev`] es la **costura** que ata el contexto dev del primer hijo
//! ([`ContextoPrimerHijoPotDagDev`]) a la puerta conjunta de `zx-consensus`
//! ([`verificar_cabecera_conjunta`]). Construye el contexto **dentro** de la llamada a partir del
//! bootstrap congelado y de `bloque.cabecera`; **no** acepta un contexto inyectado por el
//! llamante. Después entrega a la puerta:
//!
//! - el propio contexto como [`InstantaneaPot`](zx_consensus::InstantaneaPot) y como
//!   [`ContextoRangoDag`](zx_consensus::ContextoRangoDag);
//! - `contexto.dag()` como [`ContextoDag`](zx_consensus::ContextoDag);
//! - `historia.params_pieza()` como contexto de pieza (`C-POT-08` paso 5);
//! - `historia.kzg()` como parámetros KZG.
//!
//! **No es admisión del nodo.** El resultado es el [`EstadoCabeceraConjunta`] de A3, con sus tres
//! estados (`Comprobada`, `Invalida`, `Pendiente`) **sin cambiar**: `Comprobada` solo significa que
//! las pruebas locales se satisficieron contra este contexto dev. No se escribe ningún índice de
//! admitidos, UTXO, GHOSTDAG ni publicación, no se expone `validar_bloque`, no se integra el
//! registro firmante D3 y no se declara validez global ni seguridad de producción. A3 tampoco
//! deriva altura ni rama (`C-HDR-02`, `C-HDR-02b`) y la puerta **no** comprueba
//! el reloj de pared ni el `timestamp` del candidato: `reloj_pot` es el reloj **PoT** del nodo
//! (`C-NET-32`) y lo aporta el llamante, igual que la caché (`C-POT-07`) y el presupuesto
//! (`C-NET-33`). Este módulo **no** fabrica un reloj ni un presupuesto ilimitado.
//!
//! # Qué significa «una sola fuente» aquí
//!
//! El único contexto que se construye es el del perfil dev del primer hijo: pasado `{G}`, flujo
//! `f_0`, ausencia de inyecciones en la ventana dev, `N_PRIMER_HIJO_DEV`, `D_dev = 0` y el `SR` del
//! perfil. Todos salen del bootstrap y de las constantes del perfil, **nunca** del candidato; ver
//! [`ContextoPrimerHijoPotDagDev`]. El contexto **sí** conserva el `block_hash` del candidato y
//! esta costura lo coteja explícitamente antes de llamar a A3. Si no coincidiera —hoy es
//! inconstruible porque `desde_bootstrap_y_cabecera` lo deriva de esa misma cabecera, pero se
//! comprueba para que un cambio futuro del tipo no se cuele en silencio— se devuelve
//! [`ErrorPuertaPrimerHijoDev::HashCandidatoIncoherente`], **nunca** `Comprobada`.
//!
//! # La historia es el fixture archivado, no historia de red
//!
//! [`HistoriaDagDev`] es el archivo determinista **de desarrollo**: un `RecordedHistorySegment`
//! fijo con el `Archiver` real y un `FarmerProtocolInfo` de fixture. No es historia de mainnet ni
//! testnet, no acredita disponibilidad de historia en red y **no** es un contexto causal general.
//! Aquí solo aporta el contexto de pieza y el KZG comunes con los que se auditó la parcela;
//! `historia.params_pieza()` **no** valida una cabecera por sí mismo. La procedencia causal del
//! pasado DAG sigue pendiente (`TAREAS.md` §2.3) y este módulo no la fabrica.
//!
//! # Errores que no son invalidez permanente
//!
//! Un fallo al construir la vista `{G}` devuelve
//! [`ErrorPuertaPrimerHijoDev::ContextoNoDisponible`] con el [`ErrorPerfilPrimerHijoDev`] original:
//! es **falta de contexto**, no una invalidación permanente del candidato. Solo los estados de A3
//! distinguen después defecto del candidato (`Invalida`) de falta de contexto (`Pendiente`).
//!
//! # Reglas citadas
//!
//! - `C-POT-03`: el reto del slot auditado se deriva de la salida de ese slot; la puerta A3 lo
//!   ejecuta vía `verificar_solucion_poas`, no se rederiva aquí.
//! - `C-POT-05`: el `pot_output` anclado es redundancia comprobada, no fuente de verdad.
//! - `C-POT-06`: la salida de PoT tiene tres estados y nada `Pendiente` pasa a válido por defecto.
//! - `C-POT-08`: el orden de validación es el de la puerta conjunta; esta costura no lo reordena.
//! - `C-HDR-03`/`C-HDR-04`: el sello ZIP-215 se verifica dentro de A3, sin costuras.
//! - `C-HDR-06`: el `SR` esperado lo aporta el contexto, nunca el declarado por el candidato.
//! - `C-HDR-07`: la justificación llega con el bloque; aquí no se cuenta ni se reinterpreta.

use thiserror::Error;

use zx_consensus::{
    CachePotVerificada, EstadoCabeceraConjunta, PresupuestoPot, verificar_cabecera_conjunta,
};
use zx_core::{BlockHash, BloqueDag};

use crate::bootstrap_dag_dev::EstadoBootstrapDagDev;
use crate::historia_dag_dev::HistoriaDagDev;
use crate::perfil_primer_hijo_dag_dev::{ContextoPrimerHijoPotDagDev, ErrorPerfilPrimerHijoDev};

/// Fallo de la costura dev del primer hijo **antes** de ejecutar la puerta conjunta.
///
/// Separa la indisponibilidad del contexto `{G}` —que **no** es un juicio sobre el candidato— de
/// una incoherencia entre el `block_hash` del contexto y el de la cabecera, que tampoco se declara
/// «inválida» de consenso y por eso se devuelve como error explícito, nunca como `Comprobada`.
#[derive(Debug, Error)]
pub enum ErrorPuertaPrimerHijoDev {
    /// El contexto `{G}` del primer hijo no se pudo construir; conserva el motivo tipado.
    ///
    /// Es **falta de contexto** (`C-POT-06`), no invalidación permanente del candidato.
    #[error("contexto {{G}} del primer hijo no disponible: {0}")]
    ContextoNoDisponible(#[from] ErrorPerfilPrimerHijoDev),
    /// El `block_hash` del contexto no coincide con el de la cabecera entregada a la puerta.
    ///
    /// Por construcción de
    /// [`ContextoPrimerHijoPotDagDev::desde_bootstrap_y_cabecera`] hoy es inconstruible; se
    /// conserva la comprobación para que un cambio futuro del tipo no cuele una comprobación de
    /// otra cabecera. No es un juicio de invalidez de consenso.
    #[error(
        "el contexto se construyó para otro candidato: contexto {contexto:?}, cabecera {cabecera:?}"
    )]
    HashCandidatoIncoherente {
        /// `block_hash` que conserva el contexto.
        contexto: BlockHash,
        /// `block_hash` de la cabecera que se intenta comprobar.
        cabecera: BlockHash,
    },
}

/// Comprueba el primer hijo dev con la puerta conjunta A3 y el contexto dev construido aquí.
///
/// Construye `ContextoPrimerHijoPotDagDev::desde_bootstrap_y_cabecera(bootstrap, &bloque.cabecera)`
/// **dentro** de la llamada, coteja `contexto.hash_candidato() == bloque.cabecera.block_hash()` y,
/// solo entonces, llama a `verificar_cabecera_conjunta` con `&contexto` como
/// [`InstantaneaPot`](zx_consensus::InstantaneaPot) y
/// [`ContextoRangoDag`](zx_consensus::ContextoRangoDag), `contexto.dag()` como
/// [`ContextoDag`](zx_consensus::ContextoDag), `Some(&historia.params_pieza())` y
/// `historia.kzg()`. No existe argumento para inyectar otro contexto.
///
/// # Argumentos
///
/// - `bootstrap`: estado del génesis congelado; fuente del pasado `{G}`, de `f_0`, del ancla del
///   slot 0 y de `D_dev`.
/// - `bloque`: bloque DAG completo. Solo se leen `cabecera` y `justificacion`; **no** se
///   comprueban cuerpo, testigos, coinbase, UTXO, altura ni rama.
/// - `historia`: fixture archivado dev; aporta el contexto de pieza y el KZG comunes. **No** es
///   historia de red ni contexto causal general.
/// - `reloj_pot`: reloj PoT del nodo (`C-NET-32`), estado local que aporta el llamante.
/// - `cache`: caché contextual verificada (`C-POT-07`), vacía al comienzo de una verificación.
/// - `presupuesto`: presupuesto de CPU inyectado (`C-NET-33`); **no** se fabrica ilimitado.
///
/// # Errores
///
/// [`ErrorPuertaPrimerHijoDev::ContextoNoDisponible`] si la vista `{G}` no se puede construir
/// (topología fuera de alcance, slot fuera de la ventana dev o retardo distinto de `D_dev = 0`), y
/// [`ErrorPuertaPrimerHijoDev::HashCandidatoIncoherente`] si el hash del contexto no es el de la
/// cabecera. Ninguno de los dos es invalidación permanente del candidato.
///
/// # Límites
///
/// El [`EstadoCabeceraConjunta`] devuelto **no** es admisión: ver la cabecera del módulo. No se
/// expone `validar_bloque`, no se escribe en índices, UTXO, GHOSTDAG ni publicación, y A3 no deriva
/// altura ni rama ni comprueba el reloj de pared.
pub fn verificar_primer_hijo_dag_dev<P>(
    bootstrap: &EstadoBootstrapDagDev,
    bloque: &BloqueDag,
    historia: &HistoriaDagDev,
    reloj_pot: u64,
    cache: &mut CachePotVerificada,
    presupuesto: &mut P,
) -> Result<EstadoCabeceraConjunta, ErrorPuertaPrimerHijoDev>
where
    P: PresupuestoPot,
{
    let contexto =
        ContextoPrimerHijoPotDagDev::desde_bootstrap_y_cabecera(bootstrap, &bloque.cabecera)
            .map_err(ErrorPuertaPrimerHijoDev::ContextoNoDisponible)?;

    // Cotejo explícito de identidad antes de llamar a A3. La puerta no puede ver el hash a través
    // de `CandidatoSinRango`, así que la costura lo fija aquí: nunca `Comprobada` sobre otra
    // cabecera.
    let hash_cabecera = bloque.cabecera.block_hash();
    if contexto.hash_candidato() != hash_cabecera {
        return Err(ErrorPuertaPrimerHijoDev::HashCandidatoIncoherente {
            contexto: contexto.hash_candidato(),
            cabecera: hash_cabecera,
        });
    }

    // El contexto de pieza se copia a una variable local para no tomar prestado un temporal.
    let params_pieza = historia.params_pieza();

    Ok(verificar_cabecera_conjunta(
        bloque,
        &contexto,
        contexto.dag(),
        &contexto,
        reloj_pot,
        cache,
        presupuesto,
        Some(&params_pieza),
        historia.kzg(),
    ))
}
