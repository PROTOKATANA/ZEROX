//! Igualdad económica y compatibilidad de descriptores declarados, no verificador PoST.
//! No calcula salidas PoT, acredita eventos ni fabrica una declaración válida.

use std::num::{NonZeroU32, NonZeroU64};

/// Identificador fijado externamente para la red; no se renueva por rama o upgrade.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct DominioRed(pub [u8; 32]);

/// Coordenadas declaradas. Sus tipos NO prueban PoAS ni posesión de espacio.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct CoordenadasBillete {
    pub slot: u64,
    pub public_key: [u8; 32],
    pub sector_index: u16,
    pub history_size: NonZeroU64,
    pub piece_offset: u16,
}

/// Clave exacta candidata, deliberadamente sin serialización o hash de consenso.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct ClaveEconomica {
    dominio: DominioRed,
    coordenadas: CoordenadasBillete,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct RedAjena;

impl DominioRed {
    /// Proyecta una declaración de la red esperada. No autoriza cobrar ni ejecutar.
    pub fn clave_local(
        self,
        red_declarada: Self,
        coordenadas: CoordenadasBillete,
    ) -> Result<ClaveEconomica, RedAjena> {
        if self != red_declarada {
            return Err(RedAjena);
        }
        Ok(ClaveEconomica {
            dominio: self,
            coordenadas,
        })
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct OrigenPot {
    pub dominio: DominioRed,
    pub slot_inicial: u64,
    pub semilla_inicial: [u8; 16],
    pub iteraciones_iniciales: NonZeroU32,
    /// Identifica la semántica de transición, no la versión incidental del binario.
    pub transicion: [u8; 32],
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct EventoPot {
    pub activacion: u64,
    pub entropia: [u8; 32],
    pub iteraciones_efectivas: NonZeroU32,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ErrorDescriptor {
    HorizonteAnteriorAlOrigen,
    EventoFueraDelHorizonte,
    EventosSuperpuestos,
}

/// Snapshot de calendario suministrado como oráculo. No es evidencia PoT autenticada.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DescriptorPotDeclarado {
    origen: OrigenPot,
    eventos: Vec<EventoPot>,
    completo_hasta: u64,
}

impl DescriptorPotDeclarado {
    /// Normaliza anuncios por activación; no resuelve anuncios contradictorios.
    /// Rechaza incluso duplicados exactos: sólo se admite una transición por slot.
    /// Convención del descriptor: origen resume el estado inicial y los eventos son
    /// posteriores. No fija cómo se procesa el génesis real ni prohíbe una inyección inicial.
    pub fn nuevo(
        origen: OrigenPot,
        mut eventos: Vec<EventoPot>,
        completo_hasta: u64,
    ) -> Result<Self, ErrorDescriptor> {
        if completo_hasta < origen.slot_inicial {
            return Err(ErrorDescriptor::HorizonteAnteriorAlOrigen);
        }
        if eventos.iter().any(|evento| {
            evento.activacion <= origen.slot_inicial || evento.activacion > completo_hasta
        }) {
            return Err(ErrorDescriptor::EventoFueraDelHorizonte);
        }
        eventos.sort_by_key(|evento| evento.activacion);
        if eventos
            .windows(2)
            .any(|par| par[0].activacion == par[1].activacion)
        {
            return Err(ErrorDescriptor::EventosSuperpuestos);
        }
        Ok(Self {
            origen,
            eventos,
            completo_hasta,
        })
    }

    fn cubre(&self, slot: u64) -> bool {
        self.origen.slot_inicial <= slot && slot <= self.completo_hasta
    }

    fn eventos_hasta(&self, slot: u64) -> &[EventoPot] {
        let fin = self
            .eventos
            .partition_point(|evento| evento.activacion <= slot);
        &self.eventos[..fin]
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Compatibilidad {
    Compatible,
    Incompatible,
    Pendiente,
}

/// Compara campos exactos del prefijo, no hashes de salida ni etiquetas de punta.
#[must_use]
pub fn comparar_en(
    izquierda: &DescriptorPotDeclarado,
    derecha: &DescriptorPotDeclarado,
    slot: u64,
) -> Compatibilidad {
    if !izquierda.cubre(slot) || !derecha.cubre(slot) {
        return Compatibilidad::Pendiente;
    }
    if izquierda.origen == derecha.origen
        && izquierda.eventos_hasta(slot) == derecha.eventos_hasta(slot)
    {
        Compatibilidad::Compatible
    } else {
        Compatibilidad::Incompatible
    }
}

/// El llamante suministra el pasado real y cada slot; no se deduce aquí un DAG.
/// No aplica a todos los padres la desigualdad que sólo corresponde al SP.
#[must_use]
pub fn comparar_pasado(
    candidato: &DescriptorPotDeclarado,
    pasado: &[(&DescriptorPotDeclarado, u64)],
) -> Compatibilidad {
    let mut pendiente = false;
    for &(historia, slot) in pasado {
        match comparar_en(candidato, historia, slot) {
            Compatibilidad::Incompatible => return Compatibilidad::Incompatible,
            Compatibilidad::Pendiente => pendiente = true,
            Compatibilidad::Compatible => {}
        }
    }
    if pendiente {
        Compatibilidad::Pendiente
    } else {
        Compatibilidad::Compatible
    }
}
