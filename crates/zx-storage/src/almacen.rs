//! El almacén de la cadena: cabeceras, cuerpos y punta (SPEC §12, C-STORE).
//!
//! # Por qué un trait y no RocksDB directamente
//!
//! Tres razones, en orden de importancia:
//!
//! 1. **Los tests no deben tocar disco.** Un test que abre una base de datos es lento, deja basura
//!    y falla de formas que no tienen que ver con lo que prueba. Con una implementación en memoria,
//!    la lógica de cadena se prueba a velocidad de RAM.
//! 2. **La corrección se prueba una vez, no por backend.** Un test diferencial puede correr la
//!    misma secuencia de operaciones contra los dos y exigir que coincidan byte a byte. Sin trait,
//!    eso no se puede escribir.
//! 3. **RocksDB es una dependencia enorme.** Que compilarla sea opcional mantiene el ciclo de
//!    desarrollo rápido para todo lo que no la necesita.
//!
//! # La invariante que no puede romperse: primero el dato, después la punta
//!
//! **La punta se escribe SIEMPRE al final.** Si el proceso muere entre medias, un almacén con
//! cabeceras que la punta no menciona es **recuperable** —sobra información, se ignora—, mientras
//! que una punta que apunta a una cabecera que no se llegó a escribir es un almacén **corrupto**:
//! el nodo arranca creyendo estar en una altura de la que no tiene datos.
//!
//! Es la misma razón por la que `revertir_bloque` aplica el undo data antes de mover el tip.

use zx_core::digest::BlockHash;
use zx_core::preimage::block::BlockHeader;

use crate::error::StorageError;

/// Dónde está la punta de la cadena.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct Punta {
    /// Hash de la cabecera de la punta.
    pub hash: BlockHash,
    /// Su altura.
    pub altura: u32,
}

/// Lo que el nodo necesita guardar de la cadena.
///
/// Los cuerpos se guardan como **bytes ya serializados** y no como estructuras: el almacén no
/// necesita entender lo que guarda, y hacerle entenderlo lo ataría al formato de wire. Quien los
/// escribe y los lee es quien sabe interpretarlos.
pub trait AlmacenCadena: Send + Sync {
    /// Guarda una cabecera, indexada por su hash y por su altura.
    ///
    /// # Errores
    /// [`StorageError`] si el backend falla.
    fn guardar_cabecera(&self, cabecera: &BlockHeader) -> Result<(), StorageError>;

    /// Recupera una cabecera por su hash.
    ///
    /// # Errores
    /// [`StorageError`] si el backend falla. **No encontrarla no es un error**: es `Ok(None)`.
    fn cabecera(&self, hash: &BlockHash) -> Result<Option<BlockHeader>, StorageError>;

    /// El hash de la cabecera a una altura dada, en la cadena principal.
    ///
    /// # Errores
    /// [`StorageError`] si el backend falla.
    fn hash_en_altura(&self, altura: u32) -> Result<Option<BlockHash>, StorageError>;

    /// Guarda el cuerpo de un bloque, ya serializado.
    ///
    /// # Errores
    /// [`StorageError`] si el backend falla.
    fn guardar_cuerpo(&self, hash: &BlockHash, bytes: &[u8]) -> Result<(), StorageError>;

    /// Recupera el cuerpo de un bloque.
    ///
    /// # Errores
    /// [`StorageError`] si el backend falla.
    fn cuerpo(&self, hash: &BlockHash) -> Result<Option<Vec<u8>>, StorageError>;

    /// ¿Tenemos el cuerpo de este bloque?
    ///
    /// Existe aparte de [`Self::cuerpo`] porque la pregunta se hace en bucle sobre la cadena
    /// entera —"¿qué cuerpos me faltan?"— y responderla leyendo cada cuerpo significaría mover
    /// gigabytes por el bus para acabar mirando solo si había algo. Las implementaciones **MUST**
    /// responder sin materializar el valor.
    ///
    /// # Errores
    /// [`StorageError`] si el backend falla.
    fn tiene_cuerpo(&self, hash: &BlockHash) -> Result<bool, StorageError>;

    /// La punta actual, o `None` si el almacén está vacío.
    ///
    /// # Errores
    /// [`StorageError`] si el backend falla.
    fn punta(&self) -> Result<Option<Punta>, StorageError>;

    /// Mueve la punta.
    ///
    /// **MUST llamarse después** de haber guardado la cabecera correspondiente: ver la nota de
    /// módulo sobre por qué el orden importa.
    ///
    /// # Errores
    /// [`StorageError::PuntaSinCabecera`] si la cabecera no está guardada — la comprobación que
    /// convierte un almacén corrupto en un error visible.
    fn fijar_punta(&self, punta: Punta) -> Result<(), StorageError>;

    /// Fuerza a que lo escrito llegue a disco.
    ///
    /// En memoria no hace nada. En RocksDB importa: sin esto, un corte de corriente pierde lo que
    /// estuviera en el buffer del sistema operativo.
    ///
    /// # Errores
    /// [`StorageError`] si el backend falla.
    fn sincronizar(&self) -> Result<(), StorageError>;
}
