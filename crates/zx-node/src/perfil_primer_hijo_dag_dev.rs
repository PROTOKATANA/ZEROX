//! Perfil **dev** del primer hijo DAG y su contexto PoT/rango (incremento A2/A3/C3 parcial).
//!
//! # Qué es y qué no es
//!
//! [`ContextoPrimerHijoPotDagDev`] reúne, para **un solo candidato de desarrollo** cuyo único padre
//! es el génesis congelado `G` de [`crate::bootstrap_dag_dev`], tres cosas que el núcleo de
//! `zx-consensus` exige por separado:
//!
//! - la **instantánea estructural** del pasado (`{G}`), ya construida por
//!   [`instantanea_primer_hijo`](crate::contexto_genesis_dag_dev::instantanea_primer_hijo), que
//!   implementa `ContextoDag` y es lo que devuelve [`ContextoPrimerHijoPotDagDev::dag`];
//! - la implementación de [`InstantaneaPot`] con las respuestas del **perfil dev** (`N`, ausencia
//!   de inyecciones, ancla confiada del slot 0 y `D_dev = 0`), no con campos del candidato;
//! - la implementación de [`ContextoRangoDag`] que devuelve el `SR` fijo del perfil **solo** cuando
//!   la vista opaca declara `{G}` y el `slot` guardado.
//!
//! **No es admisión.** No verifica PoST, ni PoAS, ni sello, ni cuerpo, ni UTXO. No escribe en
//! ningún índice de admitidos y no existe ningún método que declare `admitido` o `valido`. La
//! puerta A3 sigue pendiente: este módulo es la costura de contexto que A3 podrá usar, no A3.
//!
//! # Identidad del candidato: lo que este tipo conserva y lo que A3 deberá cotejar
//!
//! A diferencia del snapshot de [`crate::contexto_genesis_dag_dev`], este contexto **sí** conserva
//! el `block_hash` del candidato que lo construyó (getter [`ContextoPrimerHijoPotDagDev::hash_candidato`]),
//! además de su `slot` y de la vista estructural.
//!
//! Sin embargo, [`ContextoRangoDag::rango_esperado`] recibe un [`CandidatoSinRango`] que **no
//! expone el hash**. Por eso ese método **no acredita la identidad completa**: solo comprueba
//! padres `{G}` y `slot`. Dos cabeceras distintas con los mismos padres y `slot` obtienen el mismo
//! `SR` esperado de este contexto. El futuro llamante de A3 **MUST** cotejar
//! `cabecera.block_hash()` con [`ContextoPrimerHijoPotDagDev::hash_candidato`] **antes** de usar el
//! contexto, y este módulo no simula ese cotejo devolviendo `Ok` sobre otra cabecera.
//!
//! # El perfil dev, dicho sin adorno
//!
//! Los números **sí** son valores elegidos para el futuro `zx-dag-dev` en red local, pero **no** son
//! parámetros de mainnet/testnet ni tasas representativas medidas: son un **perfil de desarrollo
//! local**, reversible, todavía no conectado a producción ni a admisión.
//!
//! - `N_PRIMER_HIJO_DEV = 200_032_000` es múltiplo de 16 y coincide con la carga de la medición
//!   previa de `research/dag-poas-ancla-de-orden.md` (1,561 s de `prove` en esta máquina,
//!   2026-09-08). Esa cifra es **histórica y de un `bench` optimizado**; el test `dev` actual duró
//!   ~16 s. **No** es una cadencia garantizada hoy ni una tasa representativa medida.
//! - `SR_PRIMER_HIJO_DEV = u64::MAX` es el `SR` elegido para ese perfil dev, con cobertura observada
//!   únicamente en el test local de una parcela de dos piezas con `N = 16`; su tasa bajo
//!   `N_PRIMER_HIJO_DEV` y tres nodos **no está medida**.
//! - `MAX_SLOT_PRIMER_HIJO_DEV = 150` es el máximo de portadores de `C-HDR-07`, **no** un intervalo
//!   de consenso nuevo.
//!
//! El perfil **solo** declara **ausencia de inyecciones** dentro de la primera ventana de hijo y
//! devuelve contexto ausente fuera de ella. No define calendario de épocas, ni controlador de
//! lanzamiento, ni `N_dev` total de red, ni tasa de slots. `D_dev = 0` sale del getter existente
//! [`EstadoBootstrapDagDev::retardo_pot_dev`] y se comprueba en construcción; **no** se duplica
//! como constante contradictoria.

use thiserror::Error;

use zx_consensus::bloque_dag::{CandidatoSinRango, ContextoRangoDag};
use zx_consensus::error::ConsensusError;
use zx_consensus::pot_rango::{
    BloqueDelPasado, FLUJO_BYTES, InstantaneaPot, InyeccionesPot, MotivoPotPendiente,
};
use zx_core::wire_dag::POT_OUTPUT_BYTES;
use zx_core::{BlockHash, DagBlockHeader};

use crate::bootstrap_dag_dev::EstadoBootstrapDagDev;
use crate::contexto_genesis_dag_dev::{
    ErrorContextoPrimerHijoDev, InstantaneaPrimerHijoDagDev, instantanea_primer_hijo,
};
use crate::dag_causal::VistaPasadoEstructural;

/// `N` del perfil dev del primer hijo: 200 032 000 iteraciones por slot.
///
/// Es múltiplo de 16 y coincide con la carga de la medición previa de
/// `research/dag-poas-ancla-de-orden.md` (1,561 s de `prove`, 2026-09-08), cifra **histórica y de un
/// `bench` optimizado**; el test `dev` actual duró ~16 s. **No** es una cadencia garantizada hoy ni
/// un parámetro de mainnet/testnet, aunque **sí** es el valor elegido para el futuro `zx-dag-dev` en
/// red local; ver la cabecera del módulo.
const N_PRIMER_HIJO_DEV: u64 = 200_032_000;

/// `SR` del perfil dev del primer hijo: `u64::MAX`.
///
/// **Sí** es el `SR` elegido para el futuro `zx-dag-dev` en red local, pero **no** es un parámetro
/// de mainnet/testnet ni una tasa representativa medida. Su cobertura solo está observada en el test
/// local de una parcela de dos piezas con `N = 16`; su tasa bajo `N_PRIMER_HIJO_DEV` y tres nodos
/// **no está medida**.
const SR_PRIMER_HIJO_DEV: u64 = u64::MAX;

/// Máximo de portadores de `C-HDR-07`, usado como cota de la ventana dev del primer hijo.
///
/// Es el número máximo de portadores del formato, **no** un intervalo de consenso nuevo.
const MAX_SLOT_PRIMER_HIJO_DEV: u64 = 150;

/// Fallo tipado de la construcción del contexto dev del primer hijo.
///
/// Distingue la **ventana dev** fuera de alcance y el retardo no nulo del perfil, de **vista
/// fallida**, que conserva el error estructural concreto de
/// [`instantanea_primer_hijo`](crate::contexto_genesis_dag_dev::instantanea_primer_hijo) sin
/// convertirlo en «cabecera inválida».
#[derive(Debug, Error, PartialEq, Eq)]
pub enum ErrorPerfilPrimerHijoDev {
    /// El `slot` declarado no cae en la ventana dev `1..=150` del primer hijo.
    #[error("slot {slot} fuera de la ventana dev 1..={max_slot} del primer hijo")]
    SlotFueraDeVentana {
        /// El `slot` declarado por la cabecera.
        slot: u64,
        /// El máximo de la ventana, `150`, máximo de portadores de `C-HDR-07`.
        max_slot: u64,
    },
    /// El bootstrap declara un retardo de autoría distinto de `D_dev = 0`.
    #[error("el perfil dev exige D_dev = 0; el bootstrap declara {retardo}")]
    RetardoPotNoCero {
        /// El retardo declarado por el bootstrap.
        retardo: u64,
    },
    /// La vista estructural del pasado falló; el motivo tipado se conserva sin reinterpretarlo.
    #[error("la vista estructural del primer hijo falló: {0}")]
    Vista(ErrorContextoPrimerHijoDev),
    /// La vista que superó `{G}` no contiene el registro de `G`: incoherencia interna de la vista.
    #[error("la vista del primer hijo no contiene el registro de G")]
    VistaSinGenesis,
}

/// Contexto inmutable del primer hijo DAG dev: perfil PoT dev más vista estructural `{G}`.
///
/// Conserva la identidad completa del candidato (`block_hash` y `slot`), la vista estructural
/// existente para A3 y los datos del perfil dev derivados del bootstrap: el pasado es exactamente
/// `[BloqueDelPasado { hash: G, slot: 0, flujo: f_0 }]`, el ancla confiada del slot 0 y `D_dev = 0`.
///
/// Los campos son privados y no existe una lista de pasado, `f_0`, ancla, `N` ni `SR` inyectable
/// por el llamante: todo sale del bootstrap y de las constantes privadas de este módulo. **No**
/// acredita admisión ni existe un método que declare `admitido` o `valido`; ver la cabecera del
/// módulo para el límite de identidad.
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct ContextoPrimerHijoPotDagDev {
    instantanea: InstantaneaPrimerHijoDagDev,
    hash_candidato: BlockHash,
    slot_candidato: u64,
    pasado: [BloqueDelPasado; 1],
    flujo: [u8; FLUJO_BYTES],
    ancla_slot_0: [u8; POT_OUTPUT_BYTES],
    retardo_autoria: u64,
}

impl ContextoPrimerHijoPotDagDev {
    /// Construye el contexto dev del primer hijo a partir del bootstrap y de **esa** cabecera.
    ///
    /// Deriva `hash_candidato` de la cabecera y construye la vista estructural con
    /// [`instantanea_primer_hijo`](crate::contexto_genesis_dag_dev::instantanea_primer_hijo) sobre
    /// `cabecera.padres`. Después exige que `1 <= slot <= 150` (`C-HDR-07`) y que el bootstrap
    /// declare `D_dev = 0`. El pasado, el flujo, el ancla y el `N`/`SR` del perfil **no** se leen de
    /// `pot_output`, `rango_solucion`, `timestamp`, `height` ni sello de la cabecera.
    ///
    /// # Errores
    /// [`ErrorPerfilPrimerHijoDev::Vista`] si la topología no es `{G}` o la vista falla;
    /// [`ErrorPerfilPrimerHijoDev::SlotFueraDeVentana`] si el `slot` queda fuera de `1..=150`;
    /// [`ErrorPerfilPrimerHijoDev::RetardoPotNoCero`] si el bootstrap no declara `D_dev = 0`.
    pub fn desde_bootstrap_y_cabecera(
        bootstrap: &EstadoBootstrapDagDev,
        cabecera: &DagBlockHeader,
    ) -> Result<Self, ErrorPerfilPrimerHijoDev> {
        let hash_candidato = cabecera.block_hash();
        let instantanea = instantanea_primer_hijo(bootstrap, &cabecera.padres, hash_candidato)
            .map_err(ErrorPerfilPrimerHijoDev::Vista)?;

        if !(1..=MAX_SLOT_PRIMER_HIJO_DEV).contains(&cabecera.slot) {
            return Err(ErrorPerfilPrimerHijoDev::SlotFueraDeVentana {
                slot: cabecera.slot,
                max_slot: MAX_SLOT_PRIMER_HIJO_DEV,
            });
        }

        let retardo_autoria = bootstrap.retardo_pot_dev();
        if retardo_autoria != 0 {
            return Err(ErrorPerfilPrimerHijoDev::RetardoPotNoCero {
                retardo: retardo_autoria,
            });
        }

        let genesis = instantanea.hash_genesis_dev();
        let Some(registro_genesis) = instantanea.vista().get(&genesis) else {
            return Err(ErrorPerfilPrimerHijoDev::VistaSinGenesis);
        };
        let flujo = instantanea.f0_dev();
        let ancla_slot_0 = instantanea.ancla_pot_slot_0_dev();
        let pasado = [BloqueDelPasado {
            hash: genesis,
            slot: registro_genesis.slot(),
            flujo,
        }];

        Ok(Self {
            instantanea,
            hash_candidato,
            slot_candidato: cabecera.slot,
            pasado,
            flujo,
            ancla_slot_0,
            retardo_autoria,
        })
    }

    /// `block_hash` del candidato con el que se construyó este contexto.
    ///
    /// Es la identidad completa que A3 **MUST** cotejar antes de usar el contexto, porque
    /// [`ContextoRangoDag::rango_esperado`] no puede verla a través de [`CandidatoSinRango`].
    #[must_use]
    pub fn hash_candidato(&self) -> BlockHash {
        self.hash_candidato
    }

    /// `slot` del candidato con el que se construyó este contexto.
    #[must_use]
    pub fn slot_candidato(&self) -> u64 {
        self.slot_candidato
    }

    /// Contexto DAG del pasado (`{G}`) que A3 recibe como `G: ContextoDag`.
    ///
    /// Devuelve la instantánea del pasado —que **sí** implementa `ContextoDag`—, no la
    /// [`VistaPasadoEstructural`] desnuda: `verificar_cabecera_conjunta` exige un `ContextoDag`.
    /// Para inspeccionar los registros de la vista, usar [`Self::vista`]. Pasar este contexto a
    /// `comprobar_padres_contextual` **solo** comprueba padres: **no** acredita identidad ni
    /// validez global; ver la cabecera del módulo.
    #[must_use]
    pub fn dag(&self) -> &InstantaneaPrimerHijoDagDev {
        &self.instantanea
    }

    /// Vista estructural de registros del pasado (`{G}`), para diagnóstico.
    ///
    /// **No** es por sí misma el contexto de A3: `verificar_cabecera_conjunta` exige un
    /// `ContextoDag`, que aporta [`Self::dag`]. Esta vista no afirma identidad ni validez global.
    #[must_use]
    pub fn vista(&self) -> &VistaPasadoEstructural {
        self.instantanea.vista()
    }
}

impl InstantaneaPot for ContextoPrimerHijoPotDagDev {
    /// `f_0` en `0..=slot_candidato`; fuera de esa ventana, contexto ausente.
    fn flujo_candidato_en(&self, slot: u64) -> Result<[u8; FLUJO_BYTES], MotivoPotPendiente> {
        if slot <= self.slot_candidato {
            Ok(self.flujo)
        } else {
            Err(MotivoPotPendiente::ContextoAusente {
                que: "flujo fuera de la ventana dev del primer hijo",
            })
        }
    }

    /// El pasado es el slice único de `G` con su flujo `f_0`; ni el candidato ni la cola no fiable.
    fn pasado(&self) -> Result<&[BloqueDelPasado], MotivoPotPendiente> {
        Ok(self.pasado.as_slice())
    }

    /// Sin inyecciones **solo** en `1..=slot_candidato`; fuera, contexto ausente.
    ///
    /// La ausencia es la hipótesis **dev limitada a la primera ventana**, no una derivación general
    /// de `C-FLU-12`.
    fn inyecciones_en(&self, slot: u64) -> Result<InyeccionesPot, MotivoPotPendiente> {
        if (1..=self.slot_candidato).contains(&slot) {
            Ok(InyeccionesPot::Ninguna)
        } else {
            Err(MotivoPotPendiente::ContextoAusente {
                que: "inyecciones fuera de la ventana dev del primer hijo",
            })
        }
    }

    /// `N_PRIMER_HIJO_DEV` **solo** en `1..=slot_candidato`; fuera, contexto ausente.
    ///
    /// No se deriva de la cabecera ni de `pot_output`: es el perfil dev inmutable.
    fn iteraciones(&self, slot: u64) -> Result<u64, MotivoPotPendiente> {
        if (1..=self.slot_candidato).contains(&slot) {
            Ok(N_PRIMER_HIJO_DEV)
        } else {
            Err(MotivoPotPendiente::ContextoAusente {
                que: "N(s) fuera de la ventana dev del primer hijo",
            })
        }
    }

    /// El `D_dev = 0` comprobado en construcción, leído del getter del bootstrap.
    fn retardo_autoria(&self) -> Result<u64, MotivoPotPendiente> {
        Ok(self.retardo_autoria)
    }

    /// **Solo** el slot 0 devuelve el ancla confiada de `G`; cualquier otro slot es contexto ausente.
    ///
    /// Nunca se calcula la salida con el `pot_output` del candidato.
    fn salida_validada(&self, slot: u64) -> Result<[u8; POT_OUTPUT_BYTES], MotivoPotPendiente> {
        if slot == 0 {
            Ok(self.ancla_slot_0)
        } else {
            Err(MotivoPotPendiente::ContextoAusente {
                que: "salida anclada fuera del slot 0 del primer hijo",
            })
        }
    }
}

impl ContextoRangoDag for ContextoPrimerHijoPotDagDev {
    /// `SR_PRIMER_HIJO_DEV` solo si la vista opaca declara padres `{G}` y el `slot` guardado.
    ///
    /// El esperado sale del perfil dev inmutable más `past = {G}` y `f_0`; **jamás** del
    /// `rango_solucion` declarado ni de otros campos del candidato. `CandidatoSinRango` no expone
    /// hash, así que este método **no** acredita la identidad completa: el futuro llamante de A3
    /// **MUST** cotejar `cabecera.block_hash()` con
    /// [`ContextoPrimerHijoPotDagDev::hash_candidato`] **antes** de usarlo. Fuera de `{G}` o del
    /// slot guardado devuelve [`ConsensusError::ContextoRangoNoDisponible`] con causa concreta, sin
    /// reutilizar un error de padre o de salto.
    fn rango_esperado(&self, candidato: &CandidatoSinRango<'_>) -> Result<u64, ConsensusError> {
        let genesis = self.instantanea.hash_genesis_dev();
        let padres = candidato.padres();
        if padres.count() != 1 || padres.seleccionado() != genesis || !padres.extras().is_empty() {
            return Err(ConsensusError::ContextoRangoNoDisponible {
                motivo: "los padres del candidato no son exactamente {G}",
            });
        }
        if candidato.slot() != self.slot_candidato {
            return Err(ConsensusError::ContextoRangoNoDisponible {
                motivo: "el slot del candidato no coincide con el slot guardado",
            });
        }
        Ok(SR_PRIMER_HIJO_DEV)
    }
}
