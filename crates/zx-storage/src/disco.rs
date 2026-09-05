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
//! | `meta` | clave corta → valor | La punta, la altura finalizada, y lo que venga |
//! | `utxo` | outpoint(36 B) → entrada | El UTXO set **finalizado**. Enorme y de acceso aleatorio: separarlo es lo que evita que se coma la caché de las cabeceras |
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

use rocksdb::{ColumnFamilyDescriptor, DB, DBRecoveryMode, Options, WriteBatch};
use std::path::Path;

use zx_consensus::validacion::EntradaUtxo;
use zx_core::digest::{BlockHash, Digest};
use zx_core::preimage::block::{BlockHeader, TAMANO_CABECERA};
use zx_core::tx::OutPoint;
use zx_core::wire;

use crate::almacen::{AlmacenCadena, Punta};
use crate::error::StorageError;
use crate::formato;
use crate::utxo::DeltaUtxo;

const CF_CABECERAS: &str = "cabeceras";
const CF_ALTURAS: &str = "alturas";
const CF_CUERPOS: &str = "cuerpos";
const CF_META: &str = "meta";
/// El UTXO set finalizado: clave de 36 B → entrada serializada (C-STORE-05).
const CF_UTXO: &str = "utxo";

/// Clave de la punta dentro de `meta`.
const CLAVE_PUNTA: &[u8] = b"punta";

/// Clave de la altura finalizada dentro de `meta`.
///
/// Va aparte de la punta a propósito: son **dos marcadores de progreso distintos** que difieren
/// hasta en `MAX_REORG_LENGTH` bloques. La punta es hasta dónde llega la cadena de cabeceras; esta
/// es hasta dónde llega el UTXO set (C-STORE-06).
const CLAVE_FINALIZADA: &[u8] = b"finalizada";

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

        // C-STORE-10 · el modo de recuperación se fija **explícitamente**, aunque hoy coincida con
        // el valor por omisión de RocksDB. Depender de un default es depender de que nadie lo
        // mueva, y este ya se movió una vez: en RocksDB 6.6 pasó de tolerar la cola corrupta a
        // `PointInTimeRecovery`.
        //
        // Y NO se usa `AbsoluteConsistency`, aunque el nombre suene a más seguro: convierte la cola
        // truncada normal de un `kill -9` en una base de datos **que no abre**. Reproducido por
        // PingCAP en facebook/rocksdb#2871. Un nodo que no arranca es peor que uno que resincroniza
        // los últimos bloques.
        opts.set_wal_recovery_mode(DBRecoveryMode::PointInTime);

        // El WAL se queda activo —es lo que da la atomicidad entre familias— y por eso NO hace
        // falta `atomic_flush`. Comentario textual de `options.h`: "it is not necessary to set
        // atomic_flush to true if WAL is always enabled […] This option is useful when there are
        // column families with writes NOT protected by WAL". Aquí no hay ninguna así.

        let familias = [CF_CABECERAS, CF_ALTURAS, CF_CUERPOS, CF_META, CF_UTXO]
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

    fn tiene_cuerpo(&self, hash: &BlockHash) -> Result<bool, StorageError> {
        // `get_pinned_cf` devuelve una vista sobre el bloque de RocksDB en vez de copiar el valor
        // al montón. Para un cuerpo de cientos de kilobytes, la diferencia entre esto y `get_cf`
        // es toda la copia — y aquí solo interesa si existe.
        Ok(self
            .db
            .get_pinned_cf(self.cf(CF_CUERPOS)?, hash.as_bytes())
            .map_err(backend)?
            .is_some())
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

    fn aplicar_lote(&self, cabeceras: &[BlockHeader], punta: Punta) -> Result<(), StorageError> {
        // C-STORE-07 · un `WriteBatch`, una llamada a `write`. RocksDB garantiza atomicidad entre
        // familias de columnas porque **comparten el WAL** —cita de su wiki: "By sharing
        // write-ahead logs we get awesome benefit of atomic writes"— pero esa garantía es **por
        // lote**, no por operación lógica. Dos `write()` seguidos son dos átomos, no uno.
        let mut lote = WriteBatch::default();
        let mut en_el_lote = false;

        for c in cabeceras {
            let hash = c.block_hash();
            if hash == punta.hash {
                en_el_lote = true;
            }
            lote.put_cf(
                self.cf(CF_CABECERAS)?,
                hash.as_bytes(),
                wire::cabecera_a_bytes(c),
            );
            lote.put_cf(
                self.cf(CF_ALTURAS)?,
                clave_altura(c.height),
                hash.as_bytes(),
            );
        }

        // C-STORE-01 · la punta MUST apuntar a algo que existe. Si viene en el lote, existirá
        // cuando el lote se aplique; si no, tiene que estar ya guardada. Se comprueba **antes** de
        // escribir: una punta colgando es lo único que este almacén no sabe recuperar.
        if !en_el_lote && self.cabecera(&punta.hash)?.is_none() {
            return Err(StorageError::PuntaSinCabecera {
                altura: punta.altura,
            });
        }

        let mut v = Vec::with_capacity(36);
        v.extend_from_slice(punta.hash.as_bytes());
        v.extend_from_slice(&punta.altura.to_be_bytes());
        lote.put_cf(self.cf(CF_META)?, CLAVE_PUNTA, v);

        self.db.write(lote).map_err(backend)
    }

    fn utxo(&self, o: &OutPoint) -> Result<Option<EntradaUtxo>, StorageError> {
        let Some(bytes) = self
            .db
            .get_pinned_cf(self.cf(CF_UTXO)?, formato::clave(o))
            .map_err(backend)?
        else {
            return Ok(None);
        };
        formato::entrada_desde_bytes(&bytes).map(Some)
    }

    fn finalizar(&self, altura: u32, delta: &DeltaUtxo) -> Result<(), StorageError> {
        let cf_utxo = self.cf(CF_UTXO)?;
        let mut lote = WriteBatch::default();

        // Se comprueba **leyendo** antes de escribir, igual que C-STORE-01 hace con la punta.
        // RocksDB no avisa de una sobrescritura: un `put` sobre una clave que ya existe la pisa en
        // silencio, y eso perdería un UTXO que solo se echaría de menos el día que alguien lo
        // intentara gastar. Es la defensa de BIP-30, y aquí además C-EMIT-04 la hace imposible —
        // pero comprobarla cuesta una lectura y no comprobarla costó a Bitcoin una regla de
        // consenso con dos excepciones grabadas por hash.
        for o in delta.gastados_planos() {
            let clave = formato::clave(o);
            if self
                .db
                .get_pinned_cf(cf_utxo, clave)
                .map_err(backend)?
                .is_none()
            {
                return Err(StorageError::OutpointAusente);
            }
            lote.delete_cf(cf_utxo, clave);
        }

        for (o, e) in &delta.creados {
            let clave = formato::clave(o);
            if self
                .db
                .get_pinned_cf(cf_utxo, clave)
                .map_err(backend)?
                .is_some()
            {
                return Err(StorageError::OutpointDuplicado);
            }
            let mut valor = Vec::with_capacity(64);
            formato::entrada_a_bytes(&mut valor, e);
            lote.put_cf(cf_utxo, clave, valor);
        }

        // C-STORE-07 · la altura finalizada entra en el MISMO lote que las mutaciones. Escribirla
        // aparte dejaría una ventana en la que el marcador dice una cosa y el conjunto otra.
        lote.put_cf(self.cf(CF_META)?, CLAVE_FINALIZADA, altura.to_be_bytes());

        self.db.write(lote).map_err(backend)
    }

    fn altura_finalizada(&self) -> Result<Option<u32>, StorageError> {
        let Some(bytes) = self
            .db
            .get_pinned_cf(self.cf(CF_META)?, CLAVE_FINALIZADA)
            .map_err(backend)?
        else {
            return Ok(None);
        };
        let arr: [u8; 4] = bytes
            .as_ref()
            .try_into()
            .map_err(|_| StorageError::Corrupto {
                que: "la altura finalizada",
            })?;
        Ok(Some(u32::from_be_bytes(arr)))
    }

    fn sincronizar(&self) -> Result<(), StorageError> {
        self.db.flush().map_err(backend)
    }
}

#[cfg(test)]
#[expect(clippy::panic, reason = "los tests fallan con panic por diseño")]
mod tests_estructura {
    /// **C-STORE-07 leído en el código: una operación lógica, una sola llamada a `write`.**
    ///
    /// Existe porque el test de `kill -9` **no puede** demostrarlo. Se comprobó: mutando
    /// `aplicar_lote` para partir la escritura en dos, aquel test pasó tres veces de tres — la
    /// ventana entre las dos llamadas dura nanosegundos y ningún golpe repartido por milisegundos
    /// cae dentro.
    ///
    /// Una propiedad estructural se comprueba mirando la estructura. Es el mismo recurso que
    /// `spec_numeros.rs` usa para atar el SPEC al código: leer el fuente y contar.
    ///
    /// Si algún día una de estas funciones necesita de verdad dos escrituras, habrá que cambiar
    /// también C-STORE-07 — que es exactamente la conversación que este test fuerza a tener.
    #[test]
    fn una_operacion_logica_es_una_sola_escritura() {
        let fuente = include_str!("disco.rs");

        for nombre in ["fn aplicar_lote", "fn finalizar"] {
            let desde = fuente
                .find(nombre)
                .unwrap_or_else(|| panic!("no se encuentra `{nombre}` en disco.rs"));
            let cuerpo = fuente.get(desde..).unwrap_or_default();
            // Hasta el cierre de la función: la primera línea que empieza en la columna 4 con `}`.
            let hasta = cuerpo.find("\n    }\n").unwrap_or(cuerpo.len());
            let cuerpo = cuerpo.get(..hasta).unwrap_or_default();

            let escrituras = cuerpo.matches("self.db.write(").count();
            assert_eq!(
                escrituras, 1,
                "`{nombre}` hace {escrituras} llamadas a `self.db.write(` y C-STORE-07 exige una.\n\
                 Dos escrituras son dos átomos, no uno: entre ellas hay una ventana en la que un \
                 componente del estado va por delante de otro, y un corte ahí no se arregla \
                 ignorando lo que sobra."
            );
        }
    }
}
