//! Almacén sobre RocksDB (SPEC §12).
//!
//! Tras la feature `rocksdb`. Ver [`crate::memoria`] para por qué es opcional y por qué existe una
//! implementación de referencia contra la que compararlo.
//!
//! # Cuatro familias de columnas, no una
//!
//! | Familia | Clave → valor | Por qué separada |
//! |---|---|---|
//! | `cabeceras` | hash(32) → 92 B | Se lee constantemente y es diminuta: comparte caché con todo lo demás si va junta |
//! | `alturas` | altura(4 BE) → hash(32) | El índice de la cadena principal. **Cambia en cada reorg**, y las otras no |
//! | `cuerpos` | hash(32) → bytes | Grandes y de acceso raro. Mezclarlos con las cabeceras arruinaría la caché |
//! | `meta` | clave corta → valor | La punta, y lo que venga |
//!
//! La altura se codifica en **big-endian a propósito**: RocksDB ordena las claves por bytes, así
//! que big-endian hace que el orden lexicográfico coincida con el numérico. Con little-endian, la
//! altura 256 quedaría antes que la 2, y recorrer la cadena por rango dejaría de funcionar.
//!
//! # Escrituras atómicas
//!
//! Guardar una cabecera toca **dos** familias —`cabeceras` y `alturas`—, y hacerlo en dos
//! operaciones deja una ventana donde el índice de alturas apunta a algo que aún no existe. Se usa
//! `WriteBatch`, que RocksDB aplica de forma atómica.

use rocksdb::{ColumnFamilyDescriptor, DB, Options, WriteBatch};
use std::path::Path;

use zx_core::digest::{BlockHash, Digest};
use zx_core::preimage::block::{BlockHeader, TAMANO_CABECERA};
use zx_core::wire;

use crate::almacen::{AlmacenCadena, Punta};
use crate::error::StorageError;

const CF_CABECERAS: &str = "cabeceras";
const CF_ALTURAS: &str = "alturas";
const CF_CUERPOS: &str = "cuerpos";
const CF_META: &str = "meta";

/// Clave de la punta dentro de `meta`.
const CLAVE_PUNTA: &[u8] = b"punta";

/// Almacén persistente.
#[derive(Debug)]
pub struct AlmacenEnDisco {
    db: DB,
}

fn backend<E: std::fmt::Display>(e: E) -> StorageError {
    StorageError::Backend(e.to_string())
}

impl AlmacenEnDisco {
    /// Abre —o crea— el almacén en un directorio.
    ///
    /// # Errores
    /// [`StorageError::Backend`] si RocksDB no puede abrir el directorio.
    pub fn abrir(ruta: &Path) -> Result<Self, StorageError> {
        let mut opts = Options::default();
        opts.create_if_missing(true);
        opts.create_missing_column_families(true);

        let familias = [CF_CABECERAS, CF_ALTURAS, CF_CUERPOS, CF_META]
            .into_iter()
            .map(|n| ColumnFamilyDescriptor::new(n, Options::default()))
            .collect::<Vec<_>>();

        let db = DB::open_cf_descriptors(&opts, ruta, familias).map_err(backend)?;
        Ok(Self { db })
    }

    fn cf(&self, nombre: &str) -> Result<&rocksdb::ColumnFamily, StorageError> {
        self.db
            .cf_handle(nombre)
            .ok_or_else(|| StorageError::Backend(format!("falta la familia {nombre}")))
    }
}

/// La altura como clave, **big-endian** (C-STORE-03): ver la nota de módulo.
fn clave_altura(a: u32) -> [u8; 4] {
    a.to_be_bytes()
}

impl AlmacenCadena for AlmacenEnDisco {
    fn guardar_cabecera(&self, cabecera: &BlockHeader) -> Result<(), StorageError> {
        let hash = cabecera.block_hash();
        let bytes = wire::cabecera_a_bytes(cabecera);

        // C-STORE-02 · atómico: sin esto, el índice de alturas puede apuntar a una cabecera que
        // todavía no está guardada.
        let mut lote = WriteBatch::default();
        lote.put_cf(self.cf(CF_CABECERAS)?, hash.as_bytes(), bytes);
        lote.put_cf(
            self.cf(CF_ALTURAS)?,
            clave_altura(cabecera.height),
            hash.as_bytes(),
        );
        self.db.write(lote).map_err(backend)
    }

    fn cabecera(&self, hash: &BlockHash) -> Result<Option<BlockHeader>, StorageError> {
        let Some(bytes) = self
            .db
            .get_cf(self.cf(CF_CABECERAS)?, hash.as_bytes())
            .map_err(backend)?
        else {
            return Ok(None);
        };
        let (c, resto) =
            wire::cabecera_desde_bytes(&bytes).map_err(|_| StorageError::Corrupto {
                que: "una cabecera guardada",
            })?;
        // Sobrar bytes significa que lo guardado no es lo que creemos: corrupción, no "casi bien".
        if !resto.is_empty() || bytes.len() != TAMANO_CABECERA {
            return Err(StorageError::Corrupto {
                que: "una cabecera guardada, con longitud inesperada",
            });
        }
        Ok(Some(c))
    }

    fn hash_en_altura(&self, altura: u32) -> Result<Option<BlockHash>, StorageError> {
        let Some(bytes) = self
            .db
            .get_cf(self.cf(CF_ALTURAS)?, clave_altura(altura))
            .map_err(backend)?
        else {
            return Ok(None);
        };
        let arr: [u8; 32] = bytes.try_into().map_err(|_| StorageError::Corrupto {
            que: "un hash del índice de alturas",
        })?;
        Ok(Some(BlockHash::from_digest(Digest::from_bytes(arr))))
    }

    fn guardar_cuerpo(&self, hash: &BlockHash, bytes: &[u8]) -> Result<(), StorageError> {
        self.db
            .put_cf(self.cf(CF_CUERPOS)?, hash.as_bytes(), bytes)
            .map_err(backend)
    }

    fn cuerpo(&self, hash: &BlockHash) -> Result<Option<Vec<u8>>, StorageError> {
        self.db
            .get_cf(self.cf(CF_CUERPOS)?, hash.as_bytes())
            .map_err(backend)
    }

    fn punta(&self) -> Result<Option<Punta>, StorageError> {
        let Some(bytes) = self
            .db
            .get_cf(self.cf(CF_META)?, CLAVE_PUNTA)
            .map_err(backend)?
        else {
            return Ok(None);
        };
        // hash(32) ‖ altura(4 BE)
        let (h, a) = bytes.split_at_checked(32).ok_or(StorageError::Corrupto {
            que: "la punta guardada",
        })?;
        let hash: [u8; 32] = h.try_into().map_err(|_| StorageError::Corrupto {
            que: "el hash de la punta",
        })?;
        let altura: [u8; 4] = a.try_into().map_err(|_| StorageError::Corrupto {
            que: "la altura de la punta",
        })?;
        Ok(Some(Punta {
            hash: BlockHash::from_digest(Digest::from_bytes(hash)),
            altura: u32::from_be_bytes(altura),
        }))
    }

    fn fijar_punta(&self, punta: Punta) -> Result<(), StorageError> {
        // C-STORE-01 · la punta MUST apuntar a algo que existe. Se comprueba **leyendo**, no
        // confiando: es lo único que separa un almacén recuperable de uno corrupto.
        if self.cabecera(&punta.hash)?.is_none() {
            return Err(StorageError::PuntaSinCabecera {
                altura: punta.altura,
            });
        }
        let mut v = Vec::with_capacity(36);
        v.extend_from_slice(punta.hash.as_bytes());
        v.extend_from_slice(&punta.altura.to_be_bytes());
        self.db
            .put_cf(self.cf(CF_META)?, CLAVE_PUNTA, v)
            .map_err(backend)
    }

    fn sincronizar(&self) -> Result<(), StorageError> {
        self.db.flush().map_err(backend)
    }
}
