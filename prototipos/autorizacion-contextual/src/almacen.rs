//! Caché experimental de autorizaciones, NO ledger ni almacenamiento de consenso.
//!
//! Sólo admite capacidades creadas por el compositor real. La consulta identifica
//! cuerpo y contexto exactos; ninguna variante gana por llegar antes a la caché.
//! La vista es local y volátil: no autentica un pasado DAG ni decide fork choice.

use std::collections::BTreeMap;
use std::sync::atomic::{AtomicU64, Ordering};

use crate::AutorizacionPerfil;

/// Una clave identifica evidencia; construirla no certifica sus bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct ClaveEvidencia {
    pub cuerpo: [u8; 32],
    pub contexto: [u8; 32],
}

impl ClaveEvidencia {
    #[must_use]
    pub fn de(evidencia: &AutorizacionPerfil) -> Self {
        Self {
            cuerpo: evidencia.body_key(),
            contexto: evidencia.context_key(),
        }
    }
}

/// Presupuesto local. El peso retenido NO mide RAM, disco ni bytes de wire.
#[derive(Clone, Copy, Debug)]
pub struct LimitesLocales {
    pub entradas: usize,
    pub peso_retenido: u64,
}

/// Identifica una versión de esta instancia de caché, no una altura de consenso.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct VistaVersionada {
    instancia: u64,
    contexto: [u8; 32],
    revision: u64,
}

impl VistaVersionada {
    #[must_use]
    pub fn contexto(self) -> [u8; 32] {
        self.contexto
    }

    #[must_use]
    pub fn revision(self) -> u64 {
        self.revision
    }
}

/// Fallos locales: ninguno declara inválido un bloque o billete.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ErrorAlmacen {
    CapacidadAgotada,
    PresupuestoDePeso,
    ContabilidadDesbordada,
    VistaObsoleta,
    ContextoDistinto,
    EvidenciaNoRetenida,
    EvidenciaNoVisible,
    RevisionAgotada,
    InstanciasAgotadas,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Retencion {
    Nueva,
    YaRetenida,
}

/// In-memory, serializado mediante `&mut self`. No publica UTXO, dinero ni conteos.
pub struct AlmacenEvidencias {
    limites: LimitesLocales,
    entradas: BTreeMap<ClaveEvidencia, AutorizacionPerfil>,
    peso_retenido: u64,
    vista: VistaVersionada,
    visible: Option<ClaveEvidencia>,
}

fn sumar_peso(actual: u64, nuevo: u64, limite: u64) -> Result<u64, ErrorAlmacen> {
    let total = actual
        .checked_add(nuevo)
        .ok_or(ErrorAlmacen::ContabilidadDesbordada)?;
    if total > limite {
        return Err(ErrorAlmacen::PresupuestoDePeso);
    }
    Ok(total)
}

static SIGUIENTE_INSTANCIA: AtomicU64 = AtomicU64::new(1);

fn reservar_instancia(contador: &AtomicU64) -> Result<u64, ErrorAlmacen> {
    contador
        .fetch_update(Ordering::Relaxed, Ordering::Relaxed, |actual| {
            actual.checked_add(1)
        })
        .map_err(|_| ErrorAlmacen::InstanciasAgotadas)
}

impl AlmacenEvidencias {
    /// El llamante selecciona el contexto esperado. Esta API NO acredita su origen.
    pub fn nuevo(limites: LimitesLocales, contexto: [u8; 32]) -> Result<Self, ErrorAlmacen> {
        let instancia = reservar_instancia(&SIGUIENTE_INSTANCIA)?;
        Ok(Self {
            limites,
            entradas: BTreeMap::new(),
            peso_retenido: 0,
            vista: VistaVersionada {
                instancia,
                contexto,
                revision: 0,
            },
            visible: None,
        })
    }

    #[must_use]
    pub fn vista(&self) -> VistaVersionada {
        self.vista
    }

    #[must_use]
    pub fn cantidad(&self) -> usize {
        self.entradas.len()
    }

    #[must_use]
    pub fn peso_retenido(&self) -> u64 {
        self.peso_retenido
    }

    /// Guarda evidencia exacta sin sustituir variantes ni elegir un representante.
    /// Un rechazo local preserva toda entrada y la vista anterior.
    pub fn retener(&mut self, evidencia: AutorizacionPerfil) -> Result<Retencion, ErrorAlmacen> {
        let clave = ClaveEvidencia::de(&evidencia);
        if self.entradas.contains_key(&clave) {
            return Ok(Retencion::YaRetenida);
        }
        if self.entradas.len() >= self.limites.entradas {
            return Err(ErrorAlmacen::CapacidadAgotada);
        }
        let peso = sumar_peso(
            self.peso_retenido,
            evidencia.resultado().peso,
            self.limites.peso_retenido,
        )?;
        self.entradas.insert(clave, evidencia);
        self.peso_retenido = peso;
        Ok(Retencion::Nueva)
    }

    /// Puede recuperar evidencia antigua, pero NO la promueve a la vista actual.
    #[must_use]
    pub fn consultar(&self, clave: ClaveEvidencia) -> Option<&AutorizacionPerfil> {
        self.entradas.get(&clave)
    }

    /// Cambio local de contexto, incluso A→A: invalida solicitudes en vuelo.
    /// La revisión no se recicla al volver a A después de A→B→A.
    pub fn cambiar_contexto(
        &mut self,
        contexto: [u8; 32],
    ) -> Result<VistaVersionada, ErrorAlmacen> {
        let revision = self
            .vista
            .revision
            .checked_add(1)
            .ok_or(ErrorAlmacen::RevisionAgotada)?;
        self.vista.contexto = contexto;
        self.vista.revision = revision;
        self.visible = None;
        Ok(self.vista)
    }

    /// Hace visible exactamente la clave solicitada bajo compare-and-swap local.
    /// La selección debe venir del consumidor; no se busca por blockhash ni llegada.
    pub fn hacer_visible(
        &mut self,
        clave: ClaveEvidencia,
        esperada: VistaVersionada,
    ) -> Result<VistaVersionada, ErrorAlmacen> {
        if esperada != self.vista {
            return Err(ErrorAlmacen::VistaObsoleta);
        }
        if clave.contexto != self.vista.contexto {
            return Err(ErrorAlmacen::ContextoDistinto);
        }
        if !self.entradas.contains_key(&clave) {
            return Err(ErrorAlmacen::EvidenciaNoRetenida);
        }
        let revision = self
            .vista
            .revision
            .checked_add(1)
            .ok_or(ErrorAlmacen::RevisionAgotada)?;
        self.visible = Some(clave);
        self.vista.revision = revision;
        Ok(self.vista)
    }

    /// No devuelve otra autorización ni otro contexto si el solicitado no está visible.
    pub fn leer_visible(
        &self,
        clave: ClaveEvidencia,
        esperada: VistaVersionada,
    ) -> Result<&AutorizacionPerfil, ErrorAlmacen> {
        if esperada != self.vista {
            return Err(ErrorAlmacen::VistaObsoleta);
        }
        if clave.contexto != self.vista.contexto {
            return Err(ErrorAlmacen::ContextoDistinto);
        }
        if self.visible != Some(clave) {
            return Err(ErrorAlmacen::EvidenciaNoVisible);
        }
        self.entradas
            .get(&clave)
            .ok_or(ErrorAlmacen::EvidenciaNoRetenida)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn revision_agotada_no_cambia_contexto_ni_vista() {
        let mut almacen = AlmacenEvidencias::nuevo(
            LimitesLocales {
                entradas: 0,
                peso_retenido: 0,
            },
            [1; 32],
        )
        .unwrap();
        almacen.vista.revision = u64::MAX;
        let anterior = almacen.vista();
        assert_eq!(
            almacen.cambiar_contexto([2; 32]),
            Err(ErrorAlmacen::RevisionAgotada)
        );
        assert_eq!(almacen.vista(), anterior);
        assert_eq!(almacen.cantidad(), 0);
        assert_eq!(almacen.peso_retenido(), 0);
    }

    #[test]
    fn presupuesto_de_peso_tiene_fronteras_enteras_comprobadas() {
        assert_eq!(sumar_peso(9, 1, 10), Ok(10));
        assert_eq!(sumar_peso(9, 2, 10), Err(ErrorAlmacen::PresupuestoDePeso));
        assert_eq!(
            sumar_peso(u64::MAX, 1, u64::MAX),
            Err(ErrorAlmacen::ContabilidadDesbordada)
        );
        assert_eq!(sumar_peso(u64::MAX, 0, u64::MAX), Ok(u64::MAX));
    }

    #[test]
    fn identificador_de_instancia_no_se_recicla_al_agotarse() {
        let contador = AtomicU64::new(u64::MAX - 1);
        assert_eq!(reservar_instancia(&contador), Ok(u64::MAX - 1));
        assert_eq!(
            reservar_instancia(&contador),
            Err(ErrorAlmacen::InstanciasAgotadas)
        );
        assert_eq!(contador.load(Ordering::Relaxed), u64::MAX);
    }
}
