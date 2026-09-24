//! Puerta **conjunta** de comprobación de una cabecera DAG ya decodificada (SPEC §6.1–§6.2 y
//! §7.1.5, `C-HDR-01`/`C-HDR-03`/`C-HDR-04`/`C-HDR-05`/`C-HDR-06`/`C-HDR-07`/`C-HDR-09` y
//! `C-POT-08`).
//!
//! # Qué es y qué no es
//!
//! [`verificar_cabecera_conjunta`] recorre, en el orden de `C-POT-08`, los pasos que hoy existen
//! por separado: padres contextuales, estructura y flujo del rango PoT, sello ZIP-215, caché y
//! cadena AES con anclaje en `pot_output`, rango contextual y solución PoAS. El **mismo** bloque
//! wire —cabecera y justificación— alimenta todos los pasos: no hay una cabecera por un lado y
//! una justificación por otro.
//!
//! **La respuesta exitosa NO es admisión del nodo.** [`EstadoCabeceraConjunta::Comprobada`] solo
//! significa que las pruebas **locales** se han satisfecho contra los contextos que aporta el
//! llamante. No inserta en GHOSTDAG, no aplica UTXO, no comprueba compromisos del cuerpo, coinbase
//! ni orden DAG, y **no** se llama `validar_bloque`. Los rasgos
//! [`InstantaneaPot`], [`ContextoDag`] y [`ContextoRangoDag`] siguen admitiendo implementaciones
//! de prueba: no acreditan un `past(B)` causal ni que el controlador de rango exista.
//!
//! Tampoco afirma altura derivada (`C-HDR-02`) ni rama contextual activa (`C-HDR-02b`): ambas
//! siguen pendientes, así que aquí no hay «validez global» que declarar.
//!
//! # Orden obligatorio
//!
//! 1. Padres y condiciones estructurales (`C-HDR-05`, `C-FLU-02`, `C-GD-03`) por
//!    [`comprobar_padres_contextual`]. **Sin** caché ni AES.
//! 2. [`verificar_rango_pot_fase_previa`] (estructura y flujo, `C-POT-08` pasos 1 y 1b).
//! 3. [`zx_core::DagBlockHeader::verificar_sello`] sobre el `pre_hash` canónico (`C-HDR-03`,
//!    `C-HDR-04`). Un sello inválido no consulta la caché ni gasta AES.
//! 4. [`verificar_rango_pot_fase_aes`] con **el mismo** token de la fase previa (`C-POT-07`,
//!    `C-POT-08`): caché contextual, cadena AES y anclaje en `pot_output` (`C-POT-01`,
//!    `C-POT-02`, `C-POT-04`, `C-POT-05`). La salida auditada sale de
//!    [`PruebaPotValidada`], **nunca** de `cabecera.pot_output`.
//! 5. [`RangoSolucionValidado::validar`] (`C-HDR-06`). El `SR` de PoAS es **exclusivamente**
//!    [`RangoSolucionValidado::valor`], atado por construcción a esta cabecera; el constructor
//!    sintético `para_oraculos` no interviene. La **misma** instancia validada se conserva en
//!    [`ComprobacionCabecera::rango_validado`] para que C2 la entregue a GHOSTDAG (`w(B)` /
//!    `blue_work`, `C-GD-01`/`C-GD-08`) sin rederivarla.
//! 6. `verificar_solucion_poas` (`C-POT-03`, `C-POT-08` paso 5). El contexto de pieza es
//!    obligatorio: `None` es [`MotivoCabeceraPendiente::ContextoPiezaAusente`], nunca un `None`
//!    aguas arriba.
//!
//! # Fronteras declaradas
//!
//! - El **codec** canónico, `pre_hash` y `block_hash` viven en `zx_core::preimage::dag`
//!   (`C-HDR-01`, `C-HDR-03`, `C-HDR-09`); aquí se reutilizan y no se crea otro serializador. La
//!   puerta recibe un [`BloqueDag`] **ya decodificado**: no cubre el decode acotado de
//!   `C-WIRE-04`/`C-WIRE-05` ni serializa nada, así que **no** acredita por sí sola `C-HDR-01` ni
//!   `C-HDR-09`.
//! - `verificar_sello()` ya aplica ZIP-215 sobre los 32 B de `pre_hash`; no se reimplementa.
//! - No se usa `zx_core::wire_dag::verificar_justificacion_pot`: sigue siendo el stub que
//!   devuelve `IntegracionPotPendiente`; el verificador real es `crate::pot_rango`.
//! - No se impone ningún valor de consenso para `D`, `N(s)`, `SR`, rama, entropía ni historia:
//!   llegan por los contextos.
//!
//! # Clasificación de fallos
//!
//! Los motivos conservan el **tipo original** (no se esconden en cadenas). Un fallo del candidato
//! es [`MotivoCabeceraInvalida`]; una falta de contexto o un origen ambiguo es
//! [`MotivoCabeceraPendiente`]. En particular:
//!
//! - `PadreNoValidado` y `SlotDePadreAusente` son contexto incompleto: `Pendiente`.
//! - `GenesisConCeroPadresNoEsGenesis`, `GenesisConPadres`, `SlotDePadrePosterior`,
//!   `PadresNoAnticadena` y `PadreSeleccionadoIncorrecto` son `Invalida` cuando el contexto
//!   acredita sus datos.
//! - Cualquier otro `ConsensusError` cuyo origen no pueda atribuirse con seguridad queda
//!   `Pendiente`, sin cachear invalidez permanente.
//! - `ErrorPoas::ContextoInvalido` y `ErrorPoas::Prueba(InvalidHistorySize)` son fallos del
//!   **contexto** de pieza: `Pendiente`. El segundo nace de `derive_expiration_history_size`, que
//!   depende de `min_sector_lifetime` y del compromiso de expiración que aporta `PieceCheckParams`
//!   —contexto que la puerta **no** acredita—, así que no puede rechazar el bloque para siempre.
//! - `EntradaNoCanonica` y el resto de `ErrorPoas::Prueba(_)` son fallos del candidato:
//!   `Invalida`. **Antes de un rechazo de producción** hay que recordar que otros resultados
//!   upstream (`InvalidPiece`, `FutureHistorySize`, `SectorExpired`, …) también dependen de la
//!   pieza y de la historia causales: se clasifican aquí como del candidato porque es lo que el
//!   contrato actual permite, no porque la procedencia de `PieceCheckParams` esté acreditada.

use subspace_kzg::Kzg;
use subspace_verification::PieceCheckParams;

use zx_core::wire_dag::BloqueDag;
use zx_core::{BlockHash, DagBlockHeader, EncodingError, POT_OUTPUT_BYTES, SolucionPoas};

use crate::bloque_dag::{
    ContextoDag, ContextoRangoDag, RangoSolucionValidado, comprobar_padres_contextual,
};
use crate::error::ConsensusError;
use crate::poas::{self, ErrorPoas};
use crate::pot_rango::{
    CachePotVerificada, EstadoPot, InstantaneaPot, MotivoPotInvalido, MotivoPotPendiente,
    PresupuestoPot, PruebaPotValidada, verificar_rango_pot_fase_aes,
    verificar_rango_pot_fase_previa,
};

/// Resultado de la comprobación conjunta de una cabecera DAG.
///
/// Son **tres** estados distinguibles, en la línea de `C-POT-06`: o se satisfizo todo lo local,
/// o hay un defecto verificable del candidato, o falta contexto. Ninguno convierte un pendiente
/// en válido por defecto.
#[derive(Debug, PartialEq, Eq)]
pub enum EstadoCabeceraConjunta {
    /// Todos los pasos locales terminaron y se conserva la evidencia calculada.
    ///
    /// **No es admisión del nodo:** ver [`ComprobacionCabecera`].
    Comprobada(ComprobacionCabecera),
    /// Defecto **del candidato**, final y verificable.
    Invalida(MotivoCabeceraInvalida),
    /// Falta de contexto o fracaso de origen ambiguo. Nunca pasa a válido por defecto.
    Pendiente(MotivoCabeceraPendiente),
}

/// Evidencia calculada por la puerta conjunta cuando **todos** los pasos locales terminaron.
///
/// Los campos son privados y solo hay getters de lectura. El tipo documenta expresamente que
/// **no** es un certificado de admisión: acredita que una cabecera concreta superó las
/// comprobaciones contra los contextos recibidos, que pueden ser mocks o tener procedencia falsa.
/// Falta el derivador causal del pasado, la altura/rama derivadas (`C-HDR-02`, `C-HDR-02b`) y la
/// integración con GHOSTDAG, UTXO y cuerpo. Conserva, eso sí, el `SR` **validado** para que C2 lo
/// use tal cual al conectar GHOSTDAG, sin rederivarlo.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ComprobacionCabecera {
    /// `block_hash` de la cabecera comprobada.
    block_hash: BlockHash,
    /// `slot(B)`, el slot cuyo reto consumió el PoAS (`C-POT-03`).
    slot_auditado: u64,
    /// `salida(f, slot(B))` verificada, la que auditó la solución PoAS.
    salida_auditada: [u8; POT_OUTPUT_BYTES],
    /// Distancia de solución devuelta por `verificar_solucion_poas`.
    solution_distance: u64,
    /// `SR` validado en el paso 5 (`C-HDR-06`) y atado a esta cabecera.
    ///
    /// Es la **misma** instancia que devolvió [`RangoSolucionValidado::validar`], no una
    /// reconstrucción desde `cabecera.rango_solucion` ni desde `para_oraculos`. Cuando se conecte
    /// C2, GHOSTDAG usará este `SR` para `w(B)`/`blue_work` (`C-GD-01`, `C-GD-08`).
    rango_validado: RangoSolucionValidado,
}

impl ComprobacionCabecera {
    /// `block_hash` de la cabecera comprobada.
    #[must_use]
    pub fn block_hash(&self) -> BlockHash {
        self.block_hash
    }

    /// Slot auditado (`slot(B)`) cuyo reto consumió el PoAS.
    #[must_use]
    pub fn slot_auditado(&self) -> u64 {
        self.slot_auditado
    }

    /// Salida del slot auditado, la que `C-POT-03` usó como reto.
    #[must_use]
    pub fn salida_auditada(&self) -> [u8; POT_OUTPUT_BYTES] {
        self.salida_auditada
    }

    /// Distancia de solución devuelta por el verificador PoAS.
    #[must_use]
    pub fn solution_distance(&self) -> u64 {
        self.solution_distance
    }

    /// `SR` validado (`C-HDR-06`) que PoAS consumió y que GHOSTDAG pesará.
    ///
    /// Es la **misma** instancia validada, no una reconstrucción: `bloque()` es
    /// `Some(self.block_hash())` y `valor()` coincide con el `SR` que recibió el PoAS. La puerta
    /// **no** conecta GHOSTDAG aquí; solo conserva el valor para que C2 lo use sin rederivar
    /// `w(B)`/`blue_work` (`C-GD-01`, `C-GD-08`).
    #[must_use]
    pub fn rango_validado(&self) -> RangoSolucionValidado {
        self.rango_validado
    }
}

/// Fallo **del candidato** que hace inválida la cabecera.
///
/// Cada variante envuelve el error tipado original. No se codifican motivos en cadenas.
#[derive(Debug, PartialEq, Eq)]
pub enum MotivoCabeceraInvalida {
    /// Fallo estructural de padres (`C-HDR-05`, `C-FLU-02`, `C-GD-03`).
    Padres(ConsensusError),
    /// `rango_solucion` distinto del esperado (`C-HDR-06`).
    Rango(ConsensusError),
    /// Sello Ed25519 inválido (`C-HDR-04`).
    Sello(EncodingError),
    /// Defecto verificado del rango PoT (`C-POT-06`).
    Pot(MotivoPotInvalido),
    /// Defecto verificado de la solución PoAS (`C-POT-03`, `C-POT-08` paso 5).
    Poas(ErrorPoas),
}

/// Falta de contexto, o fracaso cuyo origen no puede atribuirse con seguridad al candidato.
///
/// Ninguno de estos casos es una prueba de invalidez: no deben cachearse como rechazo permanente.
#[derive(Debug, PartialEq, Eq)]
pub enum MotivoCabeceraPendiente {
    /// Falta de contexto DAG para comprobar los padres, o error ambiguo de esa comprobación.
    Padres(ConsensusError),
    /// Falta de contexto de rango, o error ambiguo al derivar el rango esperado.
    Rango(ConsensusError),
    /// Falta de contexto PoT (`C-POT-06`).
    Pot(MotivoPotPendiente),
    /// No se aportó contexto de pieza; `C-POT-08` paso 5 no puede ejecutarse.
    ContextoPiezaAusente,
    /// El contexto de pieza no cumple las precondiciones aritméticas de upstream.
    ContextoPieza(poas::ContextoInvalido),
    /// La primitiva upstream devolvió `InvalidHistorySize`: la talla de historia de expiración
    /// depende de `min_sector_lifetime` y del compromiso de expiración que aporta el contexto de
    /// pieza (no acreditado), no de un defecto probado del candidato. Conserva el `ErrorPoas`
    /// original.
    PoasContexto(ErrorPoas),
    /// La prueba PoT devuelta no corresponde a esta cabecera. Por construcción de
    /// [`PruebaPotValidada`] no debería ocurrir; se deja `Pendiente` en vez de declarar invalidez.
    PruebaPotIncoherente,
    /// El rango validado no quedó atado a esta cabecera. Por construcción de
    /// [`RangoSolucionValidado::validar`] no debería ocurrir; se deja `Pendiente` en vez de
    /// declarar invalidez.
    RangoSinAtadura,
}

/// Clasifica el error de [`comprobar_padres_contextual`] (`C-HDR-05`, `C-FLU-02`, `C-GD-03`).
fn clasificar_padres(error: ConsensusError) -> EstadoCabeceraConjunta {
    match error {
        e
        @ (ConsensusError::PadreNoValidado { .. } | ConsensusError::SlotDePadreAusente { .. }) => {
            EstadoCabeceraConjunta::Pendiente(MotivoCabeceraPendiente::Padres(e))
        }
        e @ (ConsensusError::GenesisConCeroPadresNoEsGenesis
        | ConsensusError::GenesisConPadres
        | ConsensusError::SlotDePadrePosterior { .. }
        | ConsensusError::PadresNoAnticadena { .. }
        | ConsensusError::PadreSeleccionadoIncorrecto { .. }) => {
            EstadoCabeceraConjunta::Invalida(MotivoCabeceraInvalida::Padres(e))
        }
        e => EstadoCabeceraConjunta::Pendiente(MotivoCabeceraPendiente::Padres(e)),
    }
}

/// Núcleo de la puerta, con costuras de test **privadas** para el sello y el PoAS.
///
/// La función pública [`verificar_cabecera_conjunta`] llama a esta con `cabecera.verificar_sello()`
/// y `poas::verificar_solucion_poas` reales, sin exponer ningún argumento que permita sustituirlos.
/// Los parámetros `sello` y `poas` existen solo para que las pruebas internas puedan observar el
/// **orden** con efectos (que un paso no llegue a ejecutarse), no para admitir bloques.
#[expect(
    clippy::too_many_arguments,
    reason = "la puerta encadena contextos y presupuestos explícitos; agruparlos ocultaría la procedencia"
)]
fn comprobar_cabecera_con<C, G, R, P, S, A>(
    bloque: &BloqueDag,
    pot: &C,
    dag: &G,
    rango: &R,
    reloj_pot: u64,
    cache: &mut CachePotVerificada,
    presupuesto: &mut P,
    contexto_pieza: Option<&PieceCheckParams>,
    kzg: &Kzg,
    sello: S,
    poas_step: A,
) -> EstadoCabeceraConjunta
where
    C: InstantaneaPot,
    G: ContextoDag,
    R: ContextoRangoDag,
    P: PresupuestoPot,
    S: Fn(&DagBlockHeader) -> Result<(), EncodingError>,
    A: Fn(
        &SolucionPoas,
        u64,
        [u8; POT_OUTPUT_BYTES],
        u64,
        &PieceCheckParams,
        &Kzg,
    ) -> Result<u64, ErrorPoas>,
{
    let cabecera = &bloque.cabecera;
    let justificacion = &bloque.justificacion;

    // 1 · Padres y estructura (C-HDR-05, C-FLU-02, C-GD-03). Sin caché ni AES.
    if let Err(error) = comprobar_padres_contextual(cabecera, dag) {
        return clasificar_padres(error);
    }

    // 2 · Fase previa del rango PoT: estructura y flujo (C-POT-08 pasos 1 y 1b).
    let token = match verificar_rango_pot_fase_previa(cabecera, justificacion, pot) {
        Ok(token) => token,
        Err(EstadoPot::PotInvalido(motivo)) => {
            return EstadoCabeceraConjunta::Invalida(MotivoCabeceraInvalida::Pot(motivo));
        }
        Err(EstadoPot::PotPendiente(motivo)) => {
            return EstadoCabeceraConjunta::Pendiente(MotivoCabeceraPendiente::Pot(motivo));
        }
        // `verificar_rango_pot_fase_previa` documenta que no puede devolver una prueba; si una
        // implementación futura lo hiciera, no se aceptaría aquí.
        Err(EstadoPot::PotValido(_)) => {
            return EstadoCabeceraConjunta::Pendiente(
                MotivoCabeceraPendiente::PruebaPotIncoherente,
            );
        }
    };

    // 3 · Sello ZIP-215 sobre `pre_hash` (C-HDR-03, C-HDR-04). No consulta caché ni gasta AES.
    if let Err(error) = sello(cabecera) {
        return EstadoCabeceraConjunta::Invalida(MotivoCabeceraInvalida::Sello(error));
    }

    // 4 · Caché contextual, cadena AES y anclaje en `pot_output` (C-POT-07, C-POT-05).
    let prueba: PruebaPotValidada =
        match verificar_rango_pot_fase_aes(token, reloj_pot, cache, presupuesto) {
            EstadoPot::PotValido(prueba) => prueba,
            EstadoPot::PotInvalido(motivo) => {
                return EstadoCabeceraConjunta::Invalida(MotivoCabeceraInvalida::Pot(motivo));
            }
            EstadoPot::PotPendiente(motivo) => {
                return EstadoCabeceraConjunta::Pendiente(MotivoCabeceraPendiente::Pot(motivo));
            }
        };

    // 4b · La prueba tiene que ser de esta cabecera. Por construcción de `PruebaPotValidada` el
    //      `bloque` es el `block_hash` del candidato y el slot auditado es `cabecera.slot`, así
    //      que la discrepancia es imposible; se comprueba igualmente y se declara `Pendiente` en
    //      vez de confiar en ello, porque un cambio futuro del tipo no debe colarse en silencio.
    if prueba.bloque() != cabecera.block_hash() || prueba.slot_auditado() != cabecera.slot {
        return EstadoCabeceraConjunta::Pendiente(MotivoCabeceraPendiente::PruebaPotIncoherente);
    }

    // 5 · Rango contextual (C-HDR-06). La puerta toma el esperado del método del contexto, sin
    //     leer directamente `cabecera.rango_solucion` como esperado; la procedencia causal del
    //     método sigue pendiente. La vista `CandidatoSinRango` **solo** impide leer
    //     `rango_solucion` directamente: un contexto puede haberlo capturado por otra vía o usar
    //     `height`, `timestamp` o `pot_output`, que C-HDR-06 prohíbe como fuente. La garantía
    //     causal —derivar el esperado del pasado validado y del flujo— sigue pendiente
    //     (`TAREAS.md` §2.3).
    let sr = match RangoSolucionValidado::validar(cabecera, rango) {
        Ok(sr) => sr,
        Err(error @ ConsensusError::RangoIncorrecto { .. }) => {
            return EstadoCabeceraConjunta::Invalida(MotivoCabeceraInvalida::Rango(error));
        }
        Err(error) => {
            return EstadoCabeceraConjunta::Pendiente(MotivoCabeceraPendiente::Rango(error));
        }
    };
    // `validar` ata el rango a esta cabecera; `para_oraculos` no pasa por aquí. La comprobación se
    // mantiene explícita por la misma razón que la de la prueba PoT. Esta `sr` es la que se
    // conserva en `ComprobacionCabecera::rango_validado`.
    if sr.bloque() != Some(cabecera.block_hash()) {
        return EstadoCabeceraConjunta::Pendiente(MotivoCabeceraPendiente::RangoSinAtadura);
    }

    // 6 · Solución PoAS (C-POT-03, C-POT-08 paso 5). Sin contexto de pieza no hay paso 5.
    let Some(pieza) = contexto_pieza else {
        return EstadoCabeceraConjunta::Pendiente(MotivoCabeceraPendiente::ContextoPiezaAusente);
    };
    let solution_distance = match poas_step(
        &cabecera.sol,
        prueba.slot_auditado(),
        prueba.salida_auditada(),
        sr.valor(),
        pieza,
        kzg,
    ) {
        Ok(distancia) => distancia,
        // Fallo del contexto, no del candidato.
        Err(ErrorPoas::ContextoInvalido(error)) => {
            return EstadoCabeceraConjunta::Pendiente(MotivoCabeceraPendiente::ContextoPieza(
                error,
            ));
        }
        // `InvalidHistorySize` lo produce `derive_expiration_history_size` al desbordar
        // `min_sector_lifetime + history_size (× 4)`: depende del contexto de pieza que la puerta
        // **no** acredita, así que no puede rechazar el bloque de forma permanente. Se mapea antes
        // de la rama general `Prueba(_)` y conserva el `ErrorPoas` original.
        Err(error @ ErrorPoas::Prueba(subspace_verification::Error::InvalidHistorySize)) => {
            return EstadoCabeceraConjunta::Pendiente(MotivoCabeceraPendiente::PoasContexto(error));
        }
        // Clasificación **condicionada al contexto**, con el `ErrorPoas` original intacto:
        // `EntradaNoCanonica` y el resto de `ErrorPoas::Prueba(_)` se tratan aquí como fallos del
        // candidato porque es lo que el contrato actual permite, no porque la procedencia de
        // `PieceCheckParams` esté acreditada. No puede cachearse como rechazo de producción hasta
        // verificar esa procedencia.
        Err(error @ (ErrorPoas::EntradaNoCanonica | ErrorPoas::Prueba(_))) => {
            return EstadoCabeceraConjunta::Invalida(MotivoCabeceraInvalida::Poas(error));
        }
    };

    EstadoCabeceraConjunta::Comprobada(ComprobacionCabecera {
        block_hash: prueba.bloque(),
        slot_auditado: prueba.slot_auditado(),
        salida_auditada: prueba.salida_auditada(),
        solution_distance,
        rango_validado: sr,
    })
}

/// Comprueba conjuntamente una cabecera DAG ya decodificada contra contextos del llamante.
///
/// Recorre el orden de `C-POT-08` descrito en la cabecera del módulo. La cabecera y la
/// justificación se extraen del **mismo** bloque wire.
///
/// # Argumentos
///
/// - `bloque`: bloque DAG completo. Solo se leen `cabecera` y `justificacion`; **no** se
///   comprueban cuerpo, testigos, coinbase ni UTXO.
/// - `pot`: instantánea contextual del pasado para el PoT ([`InstantaneaPot`]).
/// - `dag`: contexto de padres y slots ([`ContextoDag`]).
/// - `rango`: contexto del rango esperado ([`ContextoRangoDag`]). **Precondición no comprobada:**
///   el controlador que deriva `rango_esperado` de `past(B)` y del flujo **no existe** todavía;
///   este trait solo aporta la costura.
/// - `reloj_pot`: reloj PoT del nodo (`C-NET-32`), estado local.
/// - `cache`: caché contextual verificada (`C-POT-07`).
/// - `presupuesto`: presupuesto de CPU inyectado (`C-NET-33`).
/// - `contexto_pieza`: parámetros de pieza del contexto. El `Option` modela **solo** falta de
///   contexto: `None` produce [`MotivoCabeceraPendiente::ContextoPiezaAusente`] y **nunca** se
///   propaga un `None` al verificador upstream.
/// - `kzg`: parámetros KZG de la red.
///
/// # Errores clasificados
///
/// Devuelve [`EstadoCabeceraConjunta`]. Los fallos contextuales quedan `Pendiente`; los defectos
/// verificables del candidato quedan `Invalida`. Ver la cabecera del módulo.
///
/// # Límites
///
/// El `Ok` **no** es admisión del nodo ni validez global: ver [`ComprobacionCabecera`]. No se
/// derivan altura ni rama (`C-HDR-02`, `C-HDR-02b`), no se ejecuta GHOSTDAG y no se comprueba el
/// cuerpo. `InstantaneaPot`, `ContextoDag` y `ContextoRangoDag` pueden ser mocks.
#[must_use]
#[expect(
    clippy::too_many_arguments,
    reason = "la firma declarada encadena los contextos y el presupuesto; agruparlos ocultaría su procedencia"
)]
pub fn verificar_cabecera_conjunta<C, G, R, P>(
    bloque: &BloqueDag,
    pot: &C,
    dag: &G,
    rango: &R,
    reloj_pot: u64,
    cache: &mut CachePotVerificada,
    presupuesto: &mut P,
    contexto_pieza: Option<&PieceCheckParams>,
    kzg: &Kzg,
) -> EstadoCabeceraConjunta
where
    C: InstantaneaPot,
    G: ContextoDag,
    R: ContextoRangoDag,
    P: PresupuestoPot,
{
    comprobar_cabecera_con(
        bloque,
        pot,
        dag,
        rango,
        reloj_pot,
        cache,
        presupuesto,
        contexto_pieza,
        kzg,
        |cabecera| cabecera.verificar_sello(),
        |solucion, slot, salida, sr, pieza, kzg| {
            poas::verificar_solucion_poas(solucion, slot, salida, sr, pieza, kzg)
        },
    )
}

#[cfg(test)]
mod pruebas {
    #![expect(
        clippy::expect_used,
        clippy::panic,
        reason = "los tests fallan con panic por diseño"
    )]

    use core::num::NonZeroU32;
    use std::cell::Cell;
    use std::collections::BTreeMap;
    use std::num::NonZeroU64;

    use ed25519_zebra::{SigningKey, VerificationKey};
    use subspace_core_primitives::segments::{HistorySize, SegmentCommitment};
    use subspace_kzg::Kzg;
    use subspace_verification::{Error, PieceCheckParams};

    use zx_core::digest::{BodyCommitment, Digest, MerkleRoot};
    use zx_core::wire_dag::{CHECKPOINTS_POR_BUNDLE, JustificacionPot, PotCheckpoints};
    use zx_core::{
        BlockHash, ClavePublica, DagBlockHeader, POT_OUTPUT_BYTES, PadresDag, SolucionPoas,
    };
    use zx_pot::tipos::{PotCheckpoints as PotCheckpointsPrimitiva, PotSeed};

    use super::{
        ComprobacionCabecera, EstadoCabeceraConjunta, MotivoCabeceraInvalida,
        MotivoCabeceraPendiente, comprobar_cabecera_con, verificar_cabecera_conjunta,
    };
    use crate::bloque_dag::{ContextoDag, ContextoRangoDag, RangoSolucionValidado};
    use crate::error::ConsensusError;
    use crate::poas::ErrorPoas;
    use crate::pot::semilla_siguiente;
    use crate::pot_rango::{
        BloqueDelPasado, CachePotVerificada, FLUJO_BYTES, InstantaneaPot, InyeccionesPot,
        MotivoPotInvalido, MotivoPotPendiente, PresupuestoPot,
    };

    const FLUJO: [u8; FLUJO_BYTES] = [0x11; FLUJO_BYTES];
    const BASE: [u8; POT_OUTPUT_BYTES] = [0xAB; POT_OUTPUT_BYTES];
    const AUDITADA: [u8; POT_OUTPUT_BYTES] = [0x5A; POT_OUTPUT_BYTES];
    const N: u64 = 16;
    const SLOT_SP: u64 = 100;
    const RETARDO: u64 = 2;
    /// `d = slot(B) − slot(sp) = 1 ≤ D = 2`: la salida auditada la aporta el pasado.
    const SLOT_B: u64 = SLOT_SP + 1;
    /// `slot(sp) + D`: ancla del rango, también en el pasado.
    const SLOT_BASE: u64 = SLOT_SP + RETARDO;
    const RELOJ: u64 = 1_000;

    fn hash_de(n: u8) -> BlockHash {
        BlockHash::from_digest(Digest::from_bytes([n; 32]))
    }

    /// Contexto de prueba que implementa los tres rasgos. **Datos libres, sin procedencia.**
    struct Mundo {
        flujo: [u8; FLUJO_BYTES],
        pasado: Vec<BloqueDelPasado>,
        iteraciones: BTreeMap<u64, u64>,
        retardo: u64,
        salidas: BTreeMap<u64, [u8; POT_OUTPUT_BYTES]>,
        validados: Vec<BlockHash>,
        slots_padre: Vec<(BlockHash, u64)>,
        genesis: BlockHash,
        sp: BlockHash,
        rango_esperado: u64,
    }

    impl InstantaneaPot for Mundo {
        fn flujo_candidato_en(&self, _slot: u64) -> Result<[u8; FLUJO_BYTES], MotivoPotPendiente> {
            Ok(self.flujo)
        }

        fn pasado(&self) -> Result<&[BloqueDelPasado], MotivoPotPendiente> {
            Ok(&self.pasado)
        }

        fn inyecciones_en(&self, _slot: u64) -> Result<InyeccionesPot, MotivoPotPendiente> {
            Ok(InyeccionesPot::Ninguna)
        }

        fn iteraciones(&self, slot: u64) -> Result<u64, MotivoPotPendiente> {
            self.iteraciones
                .get(&slot)
                .copied()
                .ok_or(MotivoPotPendiente::ContextoAusente { que: "N(s)" })
        }

        fn retardo_autoria(&self) -> Result<u64, MotivoPotPendiente> {
            Ok(self.retardo)
        }

        fn salida_validada(&self, slot: u64) -> Result<[u8; POT_OUTPUT_BYTES], MotivoPotPendiente> {
            self.salidas
                .get(&slot)
                .copied()
                .ok_or(MotivoPotPendiente::ContextoAusente {
                    que: "salida ancla",
                })
        }
    }

    impl ContextoDag for Mundo {
        fn es_bloque_validado(&self, h: &BlockHash) -> bool {
            self.validados.contains(h)
        }

        fn esta_en_el_pasado_de(
            &self,
            _antepasado: &BlockHash,
            _descendiente: &BlockHash,
        ) -> Result<bool, ConsensusError> {
            Ok(false)
        }

        fn slot_de_padre(&self, h: &BlockHash) -> Result<u64, ConsensusError> {
            if !self.validados.contains(h) {
                return Err(ConsensusError::PadreNoValidado { padre: *h });
            }
            self.slots_padre
                .iter()
                .find_map(|(id, slot)| (id == h).then_some(*slot))
                .ok_or(ConsensusError::SlotDePadreAusente { padre: *h })
        }

        fn padre_seleccionado(&self, _padres: &PadresDag) -> Result<BlockHash, ConsensusError> {
            Ok(self.sp)
        }

        fn es_genesis(&self, h: &BlockHash) -> bool {
            *h == self.genesis
        }
    }

    impl ContextoRangoDag for Mundo {
        fn rango_esperado(
            &self,
            _candidato: &crate::bloque_dag::CandidatoSinRango<'_>,
        ) -> Result<u64, ConsensusError> {
            Ok(self.rango_esperado)
        }
    }

    struct PresupuestoUnit {
        restantes: usize,
        intentos: usize,
    }

    impl PresupuestoUnit {
        fn nuevo(restantes: usize) -> Self {
            Self {
                restantes,
                intentos: 0,
            }
        }
    }

    impl PresupuestoPot for PresupuestoUnit {
        fn consumir_slot(&mut self, _slot: u64) -> bool {
            self.intentos += 1;
            if self.restantes == 0 {
                false
            } else {
                self.restantes -= 1;
                true
            }
        }
    }

    /// Contexto de pieza con aritmética válida. Solo lo usan las espías de PoAS; el verificador
    /// real no se llama en las pruebas internas.
    fn pieza_dummy() -> PieceCheckParams {
        let h = |n: u64| HistorySize::from(NonZeroU64::new(n).expect("n > 0"));
        PieceCheckParams {
            max_pieces_in_sector: 1,
            segment_commitment: SegmentCommitment::default(),
            recent_segments: h(1),
            recent_history_fraction: (h(1), h(1)),
            min_sector_lifetime: h(1),
            current_history_size: h(1),
            sector_expiration_check_segment_commitment: None,
        }
    }

    /// Reproduce la conversión wire↔primitiva **sin** llamar a `pot::checkpoints_a_wire`: ese
    /// punto público está declarado huérfano en `ci/consenso-pendiente.txt` y una llamada desde
    /// tests internos lo daría por alcanzado (ver `ci/alcance-consenso.sh`).
    fn a_wire(carrier: &PotCheckpointsPrimitiva) -> PotCheckpoints {
        let mut outputs = [[0u8; POT_OUTPUT_BYTES]; CHECKPOINTS_POR_BUNDLE];
        for (destino, fuente) in outputs.iter_mut().zip(carrier.iter()) {
            *destino = **fuente;
        }
        PotCheckpoints::desde_outputs(outputs)
    }

    fn cabecera(
        slot: u64,
        pot_output: [u8; POT_OUTPUT_BYTES],
        sp: BlockHash,
        extras: &[BlockHash],
    ) -> DagBlockHeader {
        DagBlockHeader {
            consensus_branch_id: 0xc478_80ea,
            merkle_root: MerkleRoot::from_digest(Digest::from_bytes([1; 32])),
            timestamp: 1_788_480_000,
            height: 1,
            slot,
            pot_output,
            rango_solucion: 5,
            sol: SolucionPoas::default(),
            body_commitment: BodyCommitment::from_digest(Digest::from_bytes([2; 32])),
            padres: PadresDag::nuevo(sp, extras).expect("padres canónicos"),
            sello: [0u8; 64],
        }
    }

    /// Escenario PoT/AES válido: `d = 1 ≤ D = 2`, un portador real en `SLOT_BASE + 1`.
    fn escenario() -> (DagBlockHeader, JustificacionPot, Mundo) {
        let semilla = semilla_siguiente(BASE, None);
        let carrier = zx_pot::prove(
            PotSeed::from(semilla),
            NonZeroU32::new(u32::try_from(N).expect("N cabe en u32")).expect("N > 0"),
        )
        .expect("N múltiplo de 16");
        let portador = a_wire(&carrier);
        let pot_output = *carrier.output();

        let sp = hash_de(0x01);
        let extra = hash_de(0x02);
        let cabecera = cabecera(SLOT_B, pot_output, sp, &[extra]);
        let justificacion = JustificacionPot::nueva(vec![portador]).expect("un portador");

        let mut salidas = BTreeMap::new();
        salidas.insert(SLOT_BASE, BASE);
        salidas.insert(SLOT_B, AUDITADA);
        let mut iteraciones = BTreeMap::new();
        iteraciones.insert(SLOT_BASE + 1, N);

        let mundo = Mundo {
            flujo: FLUJO,
            pasado: vec![
                BloqueDelPasado {
                    hash: sp,
                    slot: SLOT_SP,
                    flujo: FLUJO,
                },
                BloqueDelPasado {
                    hash: extra,
                    slot: SLOT_SP,
                    flujo: FLUJO,
                },
            ],
            iteraciones,
            retardo: RETARDO,
            salidas,
            validados: vec![sp, extra],
            slots_padre: vec![(sp, SLOT_SP), (extra, SLOT_SP)],
            genesis: hash_de(0xEE),
            sp,
            rango_esperado: 5,
        };
        (cabecera, justificacion, mundo)
    }

    fn bloque(cabecera: DagBlockHeader, justificacion: JustificacionPot) -> zx_core::BloqueDag {
        zx_core::BloqueDag::nuevo(cabecera, justificacion, Vec::new(), Vec::new())
            .expect("bloque sin cuerpo")
    }

    fn firmar(cabecera: &mut DagBlockHeader, sk: &SigningKey) {
        let vk = VerificationKey::from(sk);
        cabecera.sol.public_key = ClavePublica::desde_bytes(vk.into());
        let pre = cabecera.pre_hash();
        cabecera.sello = sk.sign(pre.as_bytes()).into();
    }

    /// Sello espía que acierta; solo observa el orden.
    fn sello_ok(_cabecera: &DagBlockHeader) -> Result<(), zx_core::EncodingError> {
        Ok(())
    }

    #[test]
    fn padres_invalidos_no_llaman_sello_ni_tocan_presupuesto() {
        let (_cabecera_valida, justificacion, mundo) = escenario();
        // Cabecera con cero padres que el contexto no reconoce como génesis.
        let mut impostora = cabecera(1, [0u8; POT_OUTPUT_BYTES], hash_de(0xEE), &[]);
        impostora.padres = PadresDag::genesis();
        let impostora = bloque(impostora, justificacion);

        let sello_llamado = Cell::new(false);
        let poas_llamado = Cell::new(false);
        let mut cache = CachePotVerificada::nueva();
        let mut presupuesto = PresupuestoUnit::nuevo(1_000);

        let estado = comprobar_cabecera_con(
            &impostora,
            &mundo,
            &mundo,
            &mundo,
            RELOJ,
            &mut cache,
            &mut presupuesto,
            Some(&pieza_dummy()),
            &Kzg::new(),
            |_c| {
                sello_llamado.set(true);
                Ok(())
            },
            |_sol, _slot, _salida, _sr, _pieza, _kzg| {
                poas_llamado.set(true);
                Ok(0)
            },
        );

        assert_eq!(
            estado,
            EstadoCabeceraConjunta::Invalida(MotivoCabeceraInvalida::Padres(
                ConsensusError::GenesisConCeroPadresNoEsGenesis
            ))
        );
        assert!(!sello_llamado.get(), "el sello no debe alcanzarse");
        assert!(!poas_llamado.get(), "el PoAS no debe alcanzarse");
        assert_eq!(presupuesto.intentos, 0, "no se gasta AES");
    }

    #[test]
    fn flujo_discrepante_no_llama_sello_ni_toca_presupuesto() {
        let (cabecera, justificacion, mut mundo) = escenario();
        // El flujo del pasado que aporta el contexto discrepa del que el candidato calcula.
        if let Some(primero) = mundo.pasado.first_mut() {
            primero.flujo = [0x22; FLUJO_BYTES];
        }
        let bloque = bloque(cabecera, justificacion);

        let sello_llamado = Cell::new(false);
        let mut cache = CachePotVerificada::nueva();
        let mut presupuesto = PresupuestoUnit::nuevo(1_000);

        let estado = comprobar_cabecera_con(
            &bloque,
            &mundo,
            &mundo,
            &mundo,
            RELOJ,
            &mut cache,
            &mut presupuesto,
            Some(&pieza_dummy()),
            &Kzg::new(),
            |_c| {
                sello_llamado.set(true);
                Ok(())
            },
            |_sol, _slot, _salida, _sr, _pieza, _kzg| Ok(0),
        );

        match estado {
            EstadoCabeceraConjunta::Invalida(MotivoCabeceraInvalida::Pot(
                MotivoPotInvalido::FlujoDePasadoDiscrepa { .. },
            )) => {}
            otro => panic!("se esperaba flujo discrepante, llegó {otro:?}"),
        }
        assert!(!sello_llamado.get(), "el sello no debe alcanzarse");
        assert_eq!(presupuesto.intentos, 0, "la fase previa no gasta AES");
    }

    #[test]
    fn sello_invalido_tras_la_fase_previa_no_toca_cache_ni_presupuesto() {
        let (cabecera, justificacion, mundo) = escenario();
        let bloque = bloque(cabecera, justificacion);
        let mut cache = CachePotVerificada::nueva();
        let mut presupuesto = PresupuestoUnit::nuevo(1_000);

        let estado = comprobar_cabecera_con(
            &bloque,
            &mundo,
            &mundo,
            &mundo,
            RELOJ,
            &mut cache,
            &mut presupuesto,
            Some(&pieza_dummy()),
            &Kzg::new(),
            |_c| {
                Err(zx_core::EncodingError::FirmaInvalida {
                    motivo: "sello inválido de prueba",
                })
            },
            |_sol, _slot, _salida, _sr, _pieza, _kzg| Ok(0),
        );

        match estado {
            EstadoCabeceraConjunta::Invalida(MotivoCabeceraInvalida::Sello(_)) => {}
            otro => panic!("se esperaba sello inválido, llegó {otro:?}"),
        }
        assert_eq!(presupuesto.intentos, 0, "el sello no gasta AES");

        // Si la caché estuviera tocada, un intento posterior con presupuesto cero acertaría y no
        // daría `PresupuestoAgotado`. Al no haberse consultado, la caché sigue vacía.
        let mut presupuesto_cero = PresupuestoUnit::nuevo(0);
        let segundo = comprobar_cabecera_con(
            &bloque,
            &mundo,
            &mundo,
            &mundo,
            RELOJ,
            &mut cache,
            &mut presupuesto_cero,
            Some(&pieza_dummy()),
            &Kzg::new(),
            sello_ok,
            |_sol, _slot, _salida, _sr, _pieza, _kzg| Ok(0),
        );
        assert_eq!(
            segundo,
            EstadoCabeceraConjunta::Pendiente(MotivoCabeceraPendiente::Pot(
                MotivoPotPendiente::PresupuestoAgotado {
                    slot: SLOT_BASE + 1
                }
            )),
            "la caché no debe haberse llenado con el sello inválido"
        );
        assert_eq!(presupuesto_cero.intentos, 1);
    }

    #[test]
    fn pot_invalido_no_invoca_poas() {
        let (mut cabecera, justificacion, mundo) = escenario();
        // Anclaje incorrecto: el rango AES termina, pero no cuadra con `pot_output`. Como el sello
        // se espía, no hace falta refirmar la cabecera.
        cabecera.pot_output = [0u8; POT_OUTPUT_BYTES];
        let bloque = bloque(cabecera, justificacion);

        let poas_llamado = Cell::new(false);
        let mut cache = CachePotVerificada::nueva();
        let mut presupuesto = PresupuestoUnit::nuevo(1_000);

        let estado = comprobar_cabecera_con(
            &bloque,
            &mundo,
            &mundo,
            &mundo,
            RELOJ,
            &mut cache,
            &mut presupuesto,
            Some(&pieza_dummy()),
            &Kzg::new(),
            sello_ok,
            |_sol, _slot, _salida, _sr, _pieza, _kzg| {
                poas_llamado.set(true);
                Ok(0)
            },
        );

        match estado {
            EstadoCabeceraConjunta::Invalida(MotivoCabeceraInvalida::Pot(
                MotivoPotInvalido::PotOutputNoCoincide { .. },
            )) => {}
            otro => panic!("se esperaba anclaje incorrecto, llegó {otro:?}"),
        }
        assert!(!poas_llamado.get(), "el PoAS no debe ejecutarse");
    }

    #[test]
    fn pot_pendiente_no_invoca_poas() {
        let (cabecera, justificacion, mundo) = escenario();
        let bloque = bloque(cabecera, justificacion);

        let poas_llamado = Cell::new(false);
        let mut cache = CachePotVerificada::nueva();
        let mut presupuesto = PresupuestoUnit::nuevo(1_000);

        // Reloj por detrás del último slot del rango: se retiene.
        let estado = comprobar_cabecera_con(
            &bloque,
            &mundo,
            &mundo,
            &mundo,
            SLOT_B,
            &mut cache,
            &mut presupuesto,
            Some(&pieza_dummy()),
            &Kzg::new(),
            sello_ok,
            |_sol, _slot, _salida, _sr, _pieza, _kzg| {
                poas_llamado.set(true);
                Ok(0)
            },
        );

        match estado {
            EstadoCabeceraConjunta::Pendiente(MotivoCabeceraPendiente::Pot(
                MotivoPotPendiente::RelojFuturo { .. },
            )) => {}
            otro => panic!("se esperaba reloj futuro, llegó {otro:?}"),
        }
        assert!(!poas_llamado.get(), "el PoAS no debe ejecutarse");
        assert_eq!(presupuesto.intentos, 0, "el reloj no gasta AES");
    }

    #[test]
    fn contexto_de_pieza_ausente_es_pendiente_y_no_invoca_poas() {
        let (cabecera, justificacion, mundo) = escenario();
        let bloque = bloque(cabecera, justificacion);

        let poas_llamado = Cell::new(false);
        let mut cache = CachePotVerificada::nueva();
        let mut presupuesto = PresupuestoUnit::nuevo(1_000);

        let estado = comprobar_cabecera_con(
            &bloque,
            &mundo,
            &mundo,
            &mundo,
            RELOJ,
            &mut cache,
            &mut presupuesto,
            None,
            &Kzg::new(),
            sello_ok,
            |_sol, _slot, _salida, _sr, _pieza, _kzg| {
                poas_llamado.set(true);
                Ok(0)
            },
        );

        assert_eq!(
            estado,
            EstadoCabeceraConjunta::Pendiente(MotivoCabeceraPendiente::ContextoPiezaAusente)
        );
        assert!(!poas_llamado.get(), "sin contexto de pieza no hay paso 5");
        assert_eq!(
            presupuesto.intentos, 1,
            "el rango AES real sí se ejecuta antes"
        );
    }

    /// Ruta **instrumentada**: la espía de PoAS devuelve una distancia. No es la función pública:
    /// sirve para comprobar que, solo cuando todos los pasos terminan, se registran los datos.
    #[test]
    fn la_espia_de_poas_ok_registra_los_datos_solo_al_final() {
        let (cabecera, justificacion, mundo) = escenario();
        let esperado = cabecera.block_hash();
        let bloque = bloque(cabecera, justificacion);
        // El `SR` esperado sale del mismo contexto, no del campo declarado: reproduce la
        // precondición de C-HDR-06 para comparar con la instancia conservada.
        let sr_esperado = RangoSolucionValidado::validar(&bloque.cabecera, &mundo)
            .expect("el contexto coincide con lo declarado");
        let mut cache = CachePotVerificada::nueva();
        let mut presupuesto = PresupuestoUnit::nuevo(1_000);

        let estado = comprobar_cabecera_con(
            &bloque,
            &mundo,
            &mundo,
            &mundo,
            RELOJ,
            &mut cache,
            &mut presupuesto,
            Some(&pieza_dummy()),
            &Kzg::new(),
            sello_ok,
            |_sol, slot, salida, sr, _pieza, _kzg| {
                assert_eq!(slot, SLOT_B);
                assert_eq!(salida, AUDITADA);
                // La espía recibe exactamente el `valor()` del `SR` validado.
                assert_eq!(sr, sr_esperado.valor());
                Ok(42)
            },
        );

        match estado {
            EstadoCabeceraConjunta::Comprobada(c) => {
                let esperado_comprobacion = ComprobacionCabecera {
                    block_hash: esperado,
                    slot_auditado: SLOT_B,
                    salida_auditada: AUDITADA,
                    solution_distance: 42,
                    rango_validado: sr_esperado,
                };
                assert_eq!(c, esperado_comprobacion);
                assert_eq!(c.block_hash(), esperado);
                assert_eq!(c.slot_auditado(), SLOT_B);
                assert_eq!(c.salida_auditada(), AUDITADA);
                assert_eq!(c.solution_distance(), 42);
                // La comprobación conserva la **misma** instancia validada, atada a la cabecera.
                assert_eq!(c.rango_validado().bloque(), Some(esperado));
                assert_eq!(c.rango_validado().valor(), sr_esperado.valor());
            }
            otro => panic!("se esperaba comprobación, llegó {otro:?}"),
        }
    }

    /// Fallo 1 · `InvalidHistorySize` de upstream depende del contexto de pieza.
    ///
    /// La espía PoAS devuelve `ErrorPoas::Prueba(Error::InvalidHistorySize)` tras PoT, sello y `SR`
    /// exitosos. `derive_expiration_history_size` usa `min_sector_lifetime` y el compromiso de
    /// expiración que aporta `PieceCheckParams` —contexto que la puerta no acredita—, así que un
    /// contexto aritméticamente erróneo no puede marcar el bloque como inválido para siempre: el
    /// estado es `Pendiente` y conserva la causa tipada original.
    #[test]
    fn invalid_history_size_de_upstream_es_pendiente_y_conserva_la_causa() {
        let (cabecera, justificacion, mundo) = escenario();
        let bloque = bloque(cabecera, justificacion);
        let mut cache = CachePotVerificada::nueva();
        let mut presupuesto = PresupuestoUnit::nuevo(1_000);

        let estado = comprobar_cabecera_con(
            &bloque,
            &mundo,
            &mundo,
            &mundo,
            RELOJ,
            &mut cache,
            &mut presupuesto,
            Some(&pieza_dummy()),
            &Kzg::new(),
            sello_ok,
            |_sol, _slot, _salida, _sr, _pieza, _kzg| {
                Err(ErrorPoas::Prueba(Error::InvalidHistorySize))
            },
        );

        assert_eq!(
            estado,
            EstadoCabeceraConjunta::Pendiente(MotivoCabeceraPendiente::PoasContexto(
                ErrorPoas::Prueba(Error::InvalidHistorySize)
            ))
        );
    }

    /// La función **pública** llama al sello real y al PoAS real: con un sello auténtico se llega
    /// hasta el paso 6 y, sin contexto de pieza, el estado es `Pendiente`.
    #[test]
    fn la_funcion_publica_usa_el_sello_real_y_termina_pendiente_sin_pieza() {
        let (mut cabecera, justificacion, mundo) = escenario();
        let sk = SigningKey::from([7u8; 32]);
        firmar(&mut cabecera, &sk);
        assert!(
            cabecera.verificar_sello().is_ok(),
            "la cabecera está firmada"
        );
        let bloque = bloque(cabecera, justificacion);

        let mut cache = CachePotVerificada::nueva();
        let mut presupuesto = PresupuestoUnit::nuevo(1_000);
        let estado = verificar_cabecera_conjunta(
            &bloque,
            &mundo,
            &mundo,
            &mundo,
            RELOJ,
            &mut cache,
            &mut presupuesto,
            None,
            &Kzg::new(),
        );

        assert_eq!(
            estado,
            EstadoCabeceraConjunta::Pendiente(MotivoCabeceraPendiente::ContextoPiezaAusente)
        );
        assert_eq!(presupuesto.intentos, 1, "se ejecutó un AES real");
    }
}
