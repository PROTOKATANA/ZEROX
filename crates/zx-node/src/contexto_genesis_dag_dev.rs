//! Vista causal del **primer hijo** del génesis DAG de desarrollo (incremento C1/A2).
//!
//! # Qué es y qué no es
//!
//! [`instantanea_primer_hijo`] construye una vista inmutable y determinista del pasado de un único
//! candidato: aquel cuyos padres son **exactamente** `{G}`, con `G` el génesis **congelado** del
//! bootstrap dev de [`crate::bootstrap_dag_dev`]. La única fuente estructural es el
//! [`EstadoBootstrapDagDev`] que ya superó estructura y hash en `iniciar_bootstrap_dag_dev`; no se
//! consulta ninguna cola de candidatos, ningún índice de admitidos ni campos del candidato.
//!
//! Es la materia prima estructural que `C-POT-06` pide para `past(B)` y sobre la que `C-FLU-14`
//! comprobará la consistencia de flujo, reducida al caso mínimo: un solo ancestro. La cota de slot
//! de `C-HDR-05` alcanza a ese padre y el mergeset de `C-GD-04` se apoya en el mismo pasado, pero
//! aquí no se calcula ninguno de los dos.
//!
//! **No acredita validez.** `G` se reconoce como **raíz confiada del perfil dev** —el fixture que
//! superó estructura y hash contra un literal congelado—, **no** como un bloque que haya superado
//! PoST, PoT, PoAS, sello ni admisión. Estar en esta vista **no** significa bloque válido ni
//! admitido. `comprobar_padres_contextual` solo comprueba padres: su éxito **no** valida la
//! cabecera ni el bloque.
//!
//! # Fuera de alcance, no invalidez
//!
//! Solo la topología `{G}` está soportada. Cualquier otra —cero padres, un padre distinto de `G`,
//! padres adicionales— devuelve [`ErrorContextoPrimerHijoDev::FueraDeAlcance`], que significa
//! «esta vista aún no alcanza ese candidato», **no** invalidez de consenso. El `1` del presupuesto
//! es el tamaño **exacto** de la topología del primer hijo en este incremento, no una cifra de
//! consenso.
//!
//! # Errores que no se ocultan
//!
//! El candidato se pasa a `VistaPasadoEstructural::desde_padres` con el presupuesto local exacto de
//! un registro —o con el inyectado en la ruta privada de prueba— y su error se conserva como causa
//! tipada en [`ErrorContextoPrimerHijoDev::Vista`]: candidato en su propio pasado, presupuesto
//! agotado, ausencia de registro o incoherencia **nunca** se convierten en snapshot ni se
//! disfrazan unos de otros.
//!
//! # Identidad del candidato: lo que el snapshot no ata
//!
//! El `hash_candidato` que recibe [`instantanea_primer_hijo`] se usa **solo** para rechazar que el
//! candidato aparezca en su propio pasado declarado. El snapshot **no** lo conserva ni lo coteja
//! con ninguna cabecera: hoy no existe un método que vincule [`InstantaneaPrimerHijoDagDev`] con el
//! `block_hash` de la cabecera que el llamante comprueba después. En consecuencia,
//! `comprobar_padres_contextual(&cabecera, &instantanea)` puede devolver `Ok` para una cabecera
//! cuyo `block_hash` no sea el candidato de la vista: esa comprobación solo mira los padres.
//!
//! La futura ruta de **admisión** tendrá que derivar el `block_hash` de la cabecera que realmente
//! comprueba y conservar la asociación entre esa cabecera y el snapshot. Este incremento no la
//! implementa ni convierte la ausencia de vinculación en un rechazo garantizado.
//!
//! # Lo que este módulo deliberadamente no hace
//!
//! No implementa `InstantaneaPot`, `ContextoRangoDag`, `N_dev`, inyecciones, salidas PoT
//! posteriores, contexto de parcela ni altura o rama derivadas: faltan parámetros y evidencia. No
//! hay API pública que convierta este snapshot en `InstantaneaPot` ni que escriba el índice de
//! admitidos, y no se declara ninguna cifra de consenso.

use core::convert::Infallible;

use thiserror::Error;

use zx_consensus::{ConsensusError, ContextoDag};
use zx_core::{BlockHash, PadresDag};

use crate::bootstrap_dag_dev::EstadoBootstrapDagDev;
use crate::dag_causal::{
    ErrorVistaCausal, FuenteRegistrosDag, PresupuestoVista, RegistroEstructural,
    VistaPasadoEstructural,
};

/// Fallo tipado de la construcción de la vista del primer hijo DAG dev.
///
/// Distingue **fuera de alcance** —la topología no es `{G}`, no es un juicio sobre el candidato— de
/// **vista fallida**, que conserva el error estructural concreto de
/// [`VistaPasadoEstructural::desde_padres`].
#[derive(Debug, Error, PartialEq, Eq)]
pub enum ErrorContextoPrimerHijoDev {
    /// La topología no es exactamente `{G}`: esta vista todavía no alcanza ese candidato.
    ///
    /// **No** es invalidez de consenso: es alcance del incremento preparatorio.
    #[error("fuera de alcance: esta vista solo sirve con exactamente el padre G")]
    FueraDeAlcance,
    /// La vista estructural del pasado falló; el motivo tipado se conserva sin reinterpretarlo.
    #[error("la vista estructural del pasado falló: {0}")]
    Vista(ErrorVistaCausal<Infallible>),
}

/// Fuente privada de registros del génesis dev.
///
/// Responde **solo** a [`EstadoBootstrapDagDev::hash_congelado_dev`] y construye el registro `G`
/// con los `padres` y el `slot` de la cabecera ya comprobada por el bootstrap. Nunca consulta
/// campos del candidato ni la cola de candidatos. El `block_hash` del registro es el de la
/// cabecera: si no coincidiera con el hash congelado —imposible tras
/// `iniciar_bootstrap_dag_dev`, pero comprobado por la vista— el recorrido devuelve
/// [`ErrorVistaCausal::RegistroIncoherente`] en vez de un snapshot silencioso.
struct FuenteGenesisDev<'a> {
    bootstrap: &'a EstadoBootstrapDagDev,
}

impl FuenteRegistrosDag for FuenteGenesisDev<'_> {
    // La fuente es infalible: solo lee de una estructura en memoria ya comprobada. Un `From`
    // imposible no se fabrica; la ausencia de clave es `Ok(None)`, no un error.
    type Error = Infallible;

    fn leer(&self, hash: &BlockHash) -> Result<Option<RegistroEstructural>, Self::Error> {
        let congelado = self.bootstrap.hash_congelado_dev();
        if *hash != congelado {
            // Cualquier otra clave es ausencia de contexto, nunca invalidez del candidato.
            return Ok(None);
        }
        let cabecera = &self.bootstrap.bloque_dev().cabecera;
        Ok(Some(RegistroEstructural::nuevo(
            cabecera.block_hash(),
            cabecera.padres,
            cabecera.slot,
        )))
    }
}

/// Instantánea inmutable del pasado del primer hijo DAG dev: exactamente `{G}`.
///
/// Conserva la vista estructural y los datos del bootstrap que el llamante puede volver a leer:
/// el hash congelado del génesis, `f_0` (`C-FLU-06`) y el `pot_output(G)` como **ancla PoT
/// confiada del slot 0**. Sus campos son privados y no existe una conversión a `InstantaneaPot`.
///
/// **No conserva la identidad del candidato:** el `hash_candidato` con el que se construyó se usó
/// solo para descartar el autociclo y no se guarda aquí; `comprobar_padres_contextual` no vincula el
/// `block_hash` de la cabecera con este snapshot. Ver la cabecera del módulo.
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct InstantaneaPrimerHijoDagDev {
    vista: VistaPasadoEstructural,
    hash_genesis_dev: BlockHash,
    f0_dev: [u8; 32],
    ancla_pot_slot_0_dev: [u8; 16],
}

impl InstantaneaPrimerHijoDagDev {
    /// La vista estructural del pasado. Para este incremento contiene **solo** `G`.
    #[must_use]
    pub fn vista(&self) -> &VistaPasadoEstructural {
        &self.vista
    }

    /// `block_hash` **congelado** del génesis dev, tomado del bootstrap.
    #[must_use]
    pub fn hash_genesis_dev(&self) -> BlockHash {
        self.hash_genesis_dev
    }

    /// `f_0 = H_flujo(ETIQUETA_GENESIS ‖ block_hash(génesis))` (`C-FLU-06`) tomado del bootstrap.
    #[must_use]
    pub fn f0_dev(&self) -> [u8; 32] {
        self.f0_dev
    }

    /// `pot_output(G)` tomado del bootstrap, tratado como **ancla PoT confiada del slot 0**.
    ///
    /// No es una salida AES acreditada desde `semilla(f_0, 0)`.
    #[must_use]
    pub fn ancla_pot_slot_0_dev(&self) -> [u8; 16] {
        self.ancla_pot_slot_0_dev
    }
}

/// Construye la vista del primer hijo con el presupuesto local **exacto** de un registro.
///
/// El `1` es el número de ancestros de la topología `{G}` de este incremento, no una cifra de
/// consenso.
///
/// # Identidad
/// `hash_candidato` se usa **solo** para rechazar el autociclo en el pasado declarado. El snapshot
/// **no** lo conserva ni lo ata a la cabecera que el llamante compruebe después; ver la sección
/// «Identidad del candidato» de la cabecera del módulo.
///
/// # Errores
/// [`ErrorContextoPrimerHijoDev::FueraDeAlcance`] si la topología no es `{G}`;
/// [`ErrorContextoPrimerHijoDev::Vista`] con el motivo estructural concreto en caso contrario.
pub fn instantanea_primer_hijo(
    bootstrap: &EstadoBootstrapDagDev,
    padres: &PadresDag,
    hash_candidato: BlockHash,
) -> Result<InstantaneaPrimerHijoDagDev, ErrorContextoPrimerHijoDev> {
    instantanea_primer_hijo_con_presupuesto(
        bootstrap,
        padres,
        hash_candidato,
        PresupuestoVista::nuevo(1),
    )
}

/// Ruta privada con presupuesto inyectado: permite probar el agotamiento sin cambiar la API
/// pública, que usa uno.
fn instantanea_primer_hijo_con_presupuesto(
    bootstrap: &EstadoBootstrapDagDev,
    padres: &PadresDag,
    hash_candidato: BlockHash,
    presupuesto: PresupuestoVista,
) -> Result<InstantaneaPrimerHijoDagDev, ErrorContextoPrimerHijoDev> {
    let genesis = bootstrap.hash_congelado_dev();
    if padres.count() != 1 || padres.seleccionado() != genesis || !padres.extras().is_empty() {
        return Err(ErrorContextoPrimerHijoDev::FueraDeAlcance);
    }

    let fuente = FuenteGenesisDev { bootstrap };
    let vista = VistaPasadoEstructural::desde_padres(&fuente, padres, hash_candidato, presupuesto)
        .map_err(ErrorContextoPrimerHijoDev::Vista)?;

    Ok(InstantaneaPrimerHijoDagDev {
        vista,
        hash_genesis_dev: genesis,
        f0_dev: bootstrap.f0_dev(),
        ancla_pot_slot_0_dev: bootstrap.ancla_pot_slot_0_dev(),
    })
}

/// Contexto DAG mínimo del primer hijo dev: reconoce únicamente a `G`.
///
/// `es_bloque_validado(G)` es cierto en el **sentido especial del bootstrap dev**: `G` es la raíz
/// confiada que superó estructura y hash contra el literal congelado, **no** un bloque que haya
/// superado PoST ni admisión. El resto de consultas sobre claves ajenas devuelven un error
/// contextual; ninguna responde `false` ni `0` fabricados.
impl ContextoDag for InstantaneaPrimerHijoDagDev {
    /// Cierto solo para `G`, en el sentido especial del bootstrap dev documentado arriba.
    fn es_bloque_validado(&self, h: &BlockHash) -> bool {
        *h == self.hash_genesis_dev
    }

    /// `G` no es ancestro de sí mismo (el pasado es estricto): `(G, G)` devuelve `false`.
    ///
    /// Cualquier clave desconocida es un error contextual, no un `false` fabricado.
    fn esta_en_el_pasado_de(
        &self,
        antepasado: &BlockHash,
        descendiente: &BlockHash,
    ) -> Result<bool, ConsensusError> {
        if *antepasado != self.hash_genesis_dev {
            return Err(ConsensusError::BloqueDesconocido { hash: *antepasado });
        }
        if *descendiente != self.hash_genesis_dev {
            return Err(ConsensusError::BloqueDesconocido {
                hash: *descendiente,
            });
        }
        Ok(false)
    }

    /// `slot` de `G`, leído del registro del pasado. Clave ajena es `PadreNoValidado`; registro
    /// ausente es `SlotDePadreAusente`; **nunca** un cero por defecto.
    fn slot_de_padre(&self, h: &BlockHash) -> Result<u64, ConsensusError> {
        if *h != self.hash_genesis_dev {
            return Err(ConsensusError::PadreNoValidado { padre: *h });
        }
        self.vista
            .get(h)
            .map(RegistroEstructural::slot)
            .ok_or(ConsensusError::SlotDePadreAusente { padre: *h })
    }

    /// Para `{G}`, el padre seleccionado es `G`. Otra topología es un padre no validado.
    fn padre_seleccionado(&self, padres: &PadresDag) -> Result<BlockHash, ConsensusError> {
        if padres.es_genesis() || padres.seleccionado() != self.hash_genesis_dev {
            return Err(ConsensusError::PadreNoValidado {
                padre: padres.seleccionado(),
            });
        }
        if let Some(ajeno) = padres
            .extras()
            .iter()
            .find(|p| **p != self.hash_genesis_dev)
        {
            return Err(ConsensusError::PadreNoValidado { padre: *ajeno });
        }
        Ok(self.hash_genesis_dev)
    }

    /// `G` es el génesis del perfil dev; cualquier otra clave, no.
    fn es_genesis(&self, h: &BlockHash) -> bool {
        *h == self.hash_genesis_dev
    }
}

#[cfg(test)]
#[expect(clippy::expect_used, reason = "los tests fallan con panic por diseño")]
mod pruebas {
    use super::{
        ErrorContextoPrimerHijoDev, ErrorVistaCausal, PresupuestoVista,
        instantanea_primer_hijo_con_presupuesto,
    };
    use crate::bootstrap_dag_dev::iniciar_bootstrap_dag_dev;
    use zx_core::{BlockHash, Digest, PadresDag};

    fn h(marca: u8) -> BlockHash {
        BlockHash::from_digest(Digest::from_bytes([marca; 32]))
    }

    /// Presupuesto cero en la ruta privada: `PresupuestoAgotado` y **ninguna** vista truncada.
    #[test]
    fn presupuesto_cero_da_presupuesto_agotado_sin_vista_truncada() {
        let bootstrap = iniciar_bootstrap_dag_dev().expect("el bootstrap dev MUST arrancar");
        let genesis = bootstrap.hash_congelado_dev();
        let padres = PadresDag::nuevo(genesis, &[]).expect("padres canónicos");

        let resultado = instantanea_primer_hijo_con_presupuesto(
            &bootstrap,
            &padres,
            h(0xAB),
            PresupuestoVista::nuevo(0),
        );
        assert_eq!(
            resultado,
            Err(ErrorContextoPrimerHijoDev::Vista(
                ErrorVistaCausal::PresupuestoAgotado { presupuesto: 0 }
            ))
        );
    }
}
