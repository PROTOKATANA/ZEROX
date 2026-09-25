//! Registro de sectores **abstracto en memoria**, etiquetado como tal.
//!
//! No es una regla de consenso ni un formato de cadena: sirve únicamente para ejercitar en el
//! prototipo el alta, el duplicado y la caducidad por slot del modelo de amenaza §5. La caducidad
//! se mide en slots y se compara con `slot_actual`; no hay relojes ni estados globales.

use std::collections::HashMap;

use crate::r2::{CamposPublicos, CompromisoR2};

/// Clave de identidad de un sector: `(public_key, sector_index, history_size)`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct ClaveSector {
    /// Clave pública.
    pub public_key: [u8; 32],
    /// Índice de sector.
    pub sector_index: u16,
    /// Tamaño de historia.
    pub history_size: u64,
}

impl From<&CamposPublicos> for ClaveSector {
    fn from(c: &CamposPublicos) -> Self {
        Self {
            public_key: c.public_key,
            sector_index: c.sector_index,
            history_size: c.history_size,
        }
    }
}

/// Alta registrada.
#[derive(Debug, Clone, Copy)]
pub struct Alta {
    /// Compromiso R2 del sector completo.
    pub r2: CompromisoR2,
    /// Slot en que se dio de alta.
    pub slot_alta: u64,
}

/// Error del registro abstracto.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum ErrorRegistro {
    /// Ya hay un alta para esa identidad de sector.
    #[error("alta duplicada para (sector_index {sector_index}, history_size {history_size})")]
    Duplicado {
        /// Índice de sector.
        sector_index: u16,
        /// Tamaño de historia.
        history_size: u64,
    },
    /// El alta está caducada respecto al slot actual.
    #[error("alta caducada: slot_alta {slot_alta}, slot_actual {slot_actual}, caducidad {caducidad}")]
    Caducado {
        /// Slot del alta.
        slot_alta: u64,
        /// Slot actual.
        slot_actual: u64,
        /// Caducidad en slots.
        caducidad: u64,
    },
}

/// Registro abstracto en memoria.
#[derive(Debug, Default)]
pub struct RegistroSectores {
    entradas: HashMap<ClaveSector, Alta>,
    caducidad_slots: u64,
}

impl RegistroSectores {
    /// Crea un registro con la caducidad indicada (en slots).
    #[must_use]
    pub fn nuevo(caducidad_slots: u64) -> Self {
        Self {
            entradas: HashMap::new(),
            caducidad_slots,
        }
    }

    /// Caducidad en slots.
    #[must_use]
    pub fn caducidad_slots(&self) -> u64 {
        self.caducidad_slots
    }

    /// Número de altas vivas.
    #[must_use]
    pub fn len(&self) -> usize {
        self.entradas.len()
    }

    /// ¿Está vacío?
    #[must_use]
    pub fn is_empty(&self) -> bool {
        self.entradas.is_empty()
    }

    /// Alta de un sector. Rechaza duplicado y alta caducada; no muta el registro en ninguno de los
    /// dos casos.
    ///
    /// # Errores
    ///
    /// [`ErrorRegistro::Duplicado`] si la identidad ya existe; [`ErrorRegistro::Caducado`] si
    /// `slot_actual − slot_alta > caducidad`.
    pub fn alta(
        &mut self,
        campos: &CamposPublicos,
        r2: CompromisoR2,
        slot_alta: u64,
        slot_actual: u64,
    ) -> Result<(), ErrorRegistro> {
        let clave = ClaveSector::from(campos);
        if self.entradas.contains_key(&clave) {
            return Err(ErrorRegistro::Duplicado {
                sector_index: clave.sector_index,
                history_size: clave.history_size,
            });
        }
        if slot_actual.saturating_sub(slot_alta) > self.caducidad_slots {
            return Err(ErrorRegistro::Caducado {
                slot_alta,
                slot_actual,
                caducidad: self.caducidad_slots,
            });
        }
        self.entradas.insert(clave, Alta { r2, slot_alta });
        Ok(())
    }

    /// Consulta el alta viva de una identidad, sin caducarla.
    #[must_use]
    pub fn consultar(&self, clave: &ClaveSector) -> Option<&Alta> {
        self.entradas.get(clave)
    }

    /// Elimina las altas caducadas respecto a `slot_actual`. Devuelve cuántas retiró.
    pub fn caducar(&mut self, slot_actual: u64) -> usize {
        let caducidad = self.caducidad_slots;
        let antes = self.entradas.len();
        self.entradas
            .retain(|_, alta| slot_actual.saturating_sub(alta.slot_alta) <= caducidad);
        antes - self.entradas.len()
    }
}

#[cfg(test)]
mod tests {
    use super::{ErrorRegistro, RegistroSectores};
    use crate::r2::{CBID_PRUEBA, CamposPublicos, CompromisoR2};

    fn campos() -> CamposPublicos {
        CamposPublicos {
            cbid: CBID_PRUEBA,
            public_key: [1u8; 32],
            sector_index: 2,
            history_size: 1,
            pieces_in_sector: 2,
            n: 65_536,
        }
    }

    #[test]
    fn duplicado_y_caducidad() {
        let mut r = RegistroSectores::nuevo(10);
        assert!(r.alta(&campos(), CompromisoR2([9u8; 32]), 100, 100).is_ok());
        assert_eq!(
            r.alta(&campos(), CompromisoR2([9u8; 32]), 100, 100),
            Err(ErrorRegistro::Duplicado {
                sector_index: 2,
                history_size: 1
            })
        );
        let mut r2 = RegistroSectores::nuevo(10);
        assert_eq!(
            r2.alta(&campos(), CompromisoR2([9u8; 32]), 100, 111),
            Err(ErrorRegistro::Caducado {
                slot_alta: 100,
                slot_actual: 111,
                caducidad: 10
            })
        );
        assert!(r2.is_empty());
    }
}
