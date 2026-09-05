//! Almacén en memoria: la implementación de referencia (SPEC §12).
//!
//! # Para qué existe
//!
//! No es un juguete. Es la **implementación de referencia** contra la que se compara cualquier
//! backend real: un test diferencial corre la misma secuencia de operaciones contra los dos y exige
//! que respondan igual. Sin una referencia simple y evidentemente correcta, "RocksDB funciona" no
//! tiene contra qué contrastarse.
//!
//! Es la misma idea que el verificador CPU frente al kernel GPU, y por la misma razón: **H-001
//! ocurrió porque el kernel no tenía contra qué compararse.**

use std::collections::HashMap;
use std::sync::RwLock;

use zx_core::digest::BlockHash;
use zx_core::preimage::block::BlockHeader;

use crate::almacen::{AlmacenCadena, Punta};
use crate::error::StorageError;

/// Almacén en RAM.
#[derive(Debug, Default)]
pub struct AlmacenEnMemoria {
    interior: RwLock<Interior>,
}

#[derive(Debug, Default)]
struct Interior {
    cabeceras: HashMap<BlockHash, BlockHeader>,
    por_altura: HashMap<u32, BlockHash>,
    cuerpos: HashMap<BlockHash, Vec<u8>>,
    punta: Option<Punta>,
}

impl AlmacenEnMemoria {
    /// Uno vacío.
    #[must_use]
    pub fn nuevo() -> Self {
        Self::default()
    }

    /// Cuántas cabeceras guarda.
    #[must_use]
    pub fn cabeceras_guardadas(&self) -> usize {
        self.interior.read().map(|i| i.cabeceras.len()).unwrap_or(0)
    }
}

/// Un lock envenenado significa que otro hilo entró en pánico mientras lo tenía.
///
/// Se traduce a error en vez de propagar el pánico: el workspace prohíbe `panic` en producción, y
/// un almacén que revienta porque otro hilo reventó convierte un fallo local en una caída total.
fn envenenado() -> StorageError {
    StorageError::Backend("lock envenenado: otro hilo entró en pánico".to_owned())
}

impl AlmacenCadena for AlmacenEnMemoria {
    fn guardar_cabecera(&self, cabecera: &BlockHeader) -> Result<(), StorageError> {
        // C-STORE-02 · atómico por construcción: los dos índices se tocan bajo el mismo lock de
        // escritura, así que ningún lector puede ver uno actualizado y el otro no.
        let mut i = self.interior.write().map_err(|_| envenenado())?;
        let h = cabecera.block_hash();
        i.cabeceras.insert(h, *cabecera);
        i.por_altura.insert(cabecera.height, h);
        Ok(())
    }

    fn cabecera(&self, hash: &BlockHash) -> Result<Option<BlockHeader>, StorageError> {
        let i = self.interior.read().map_err(|_| envenenado())?;
        Ok(i.cabeceras.get(hash).copied())
    }

    fn hash_en_altura(&self, altura: u32) -> Result<Option<BlockHash>, StorageError> {
        let i = self.interior.read().map_err(|_| envenenado())?;
        Ok(i.por_altura.get(&altura).copied())
    }

    fn guardar_cuerpo(&self, hash: &BlockHash, bytes: &[u8]) -> Result<(), StorageError> {
        let mut i = self.interior.write().map_err(|_| envenenado())?;
        i.cuerpos.insert(*hash, bytes.to_vec());
        Ok(())
    }

    fn cuerpo(&self, hash: &BlockHash) -> Result<Option<Vec<u8>>, StorageError> {
        let i = self.interior.read().map_err(|_| envenenado())?;
        Ok(i.cuerpos.get(hash).cloned())
    }

    fn tiene_cuerpo(&self, hash: &BlockHash) -> Result<bool, StorageError> {
        let i = self.interior.read().map_err(|_| envenenado())?;
        Ok(i.cuerpos.contains_key(hash))
    }

    fn punta(&self) -> Result<Option<Punta>, StorageError> {
        let i = self.interior.read().map_err(|_| envenenado())?;
        Ok(i.punta)
    }

    fn fijar_punta(&self, punta: Punta) -> Result<(), StorageError> {
        let mut i = self.interior.write().map_err(|_| envenenado())?;
        // C-STORE-01 · la punta MUST apuntar a algo que existe.
        if !i.cabeceras.contains_key(&punta.hash) {
            return Err(StorageError::PuntaSinCabecera {
                altura: punta.altura,
            });
        }
        i.punta = Some(punta);
        Ok(())
    }

    fn aplicar_lote(&self, cabeceras: &[BlockHeader], punta: Punta) -> Result<(), StorageError> {
        // C-STORE-07 · un solo lock para todo el lote: el equivalente en memoria de un WriteBatch.
        // Si la punta no cuadra, no se escribe **nada** — comprobar al final y dejar las cabeceras
        // puestas sería justo la atomicidad parcial que esta regla existe para prohibir.
        let mut i = self.interior.write().map_err(|_| envenenado())?;

        let conocida =
            |h| i.cabeceras.contains_key(h) || cabeceras.iter().any(|c| &c.block_hash() == h);
        if !conocida(&punta.hash) {
            return Err(StorageError::PuntaSinCabecera {
                altura: punta.altura,
            });
        }

        for c in cabeceras {
            let h = c.block_hash();
            i.cabeceras.insert(h, *c);
            i.por_altura.insert(c.height, h);
        }
        i.punta = Some(punta);
        Ok(())
    }

    fn sincronizar(&self) -> Result<(), StorageError> {
        // En RAM no hay nada que sincronizar. No es un no-op vacío: documenta que el contrato se
        // cumple trivialmente, en vez de dejar a quien lea preguntándose si falta algo.
        Ok(())
    }
}

#[cfg(test)]
#[expect(
    clippy::unwrap_used,
    clippy::expect_used,
    reason = "los tests fallan con panic por diseño"
)]
mod tests {
    use super::{AlmacenCadena, AlmacenEnMemoria, Punta};
    use crate::error::StorageError;
    use zx_core::digest::{BlockHash, Digest, MerkleRoot};
    use zx_core::preimage::block::BlockHeader;

    fn cabecera(altura: u32) -> BlockHeader {
        BlockHeader {
            consensus_branch_id: 0xc478_80ea,
            prev_hash: BlockHash::from_digest(Digest::from_bytes([altura as u8; 32])),
            merkle_root: MerkleRoot::from_digest(Digest::from_bytes([9; 32])),
            timestamp: 1_788_480_000 + u64::from(altura) * 120,
            bits: 0x1d00_ffff,
            nonce: u64::from(altura),
            height: altura,
        }
    }

    #[test]
    fn una_cabecera_guardada_se_recupera_igual() {
        let a = AlmacenEnMemoria::nuevo();
        let c = cabecera(7);
        a.guardar_cabecera(&c).unwrap();

        assert_eq!(a.cabecera(&c.block_hash()).unwrap(), Some(c));
        assert_eq!(a.hash_en_altura(7).unwrap(), Some(c.block_hash()));
    }

    /// No encontrar algo **no es un error**. Es la diferencia entre "no lo tengo" y "el disco
    /// falló", y confundirlas haría que un nodo tratara una consulta normal como una avería.
    #[test]
    fn no_encontrar_algo_no_es_un_error() {
        let a = AlmacenEnMemoria::nuevo();
        let ajeno = BlockHash::from_digest(Digest::from_bytes([0xff; 32]));

        assert_eq!(a.cabecera(&ajeno).unwrap(), None);
        assert_eq!(a.hash_en_altura(999).unwrap(), None);
        assert_eq!(a.cuerpo(&ajeno).unwrap(), None);
        assert_eq!(a.punta().unwrap(), None);
    }

    /// **C-STORE-01 · la punta no puede apuntar al vacío.**
    ///
    /// Es la comprobación que convierte un almacén corrupto en un error visible. Sin ella, un
    /// proceso que muriera entre escribir la punta y escribir la cabecera dejaría un nodo que
    /// arranca creyendo estar en una altura de la que no tiene datos, y el síntoma aparecería mucho
    /// después, al intentar servirla.
    #[test]
    fn la_punta_no_puede_apuntar_a_una_cabecera_que_no_existe() {
        let a = AlmacenEnMemoria::nuevo();
        let c = cabecera(3);

        let e = a
            .fijar_punta(Punta {
                hash: c.block_hash(),
                altura: 3,
            })
            .expect_err("MUST rechazarse");
        assert!(matches!(e, StorageError::PuntaSinCabecera { altura: 3 }));

        // Y con la cabecera guardada, sí.
        a.guardar_cabecera(&c).unwrap();
        a.fijar_punta(Punta {
            hash: c.block_hash(),
            altura: 3,
        })
        .unwrap();
        assert_eq!(a.punta().unwrap().unwrap().altura, 3);
    }

    #[test]
    fn un_cuerpo_guardado_se_recupera_byte_a_byte() {
        let a = AlmacenEnMemoria::nuevo();
        let h = BlockHash::from_digest(Digest::from_bytes([1; 32]));
        let bytes = vec![0xde, 0xad, 0xbe, 0xef];

        a.guardar_cuerpo(&h, &bytes).unwrap();
        assert_eq!(a.cuerpo(&h).unwrap(), Some(bytes));
    }

    /// Guardar dos veces la misma altura la sobrescribe: es lo que pasa en un reorg.
    #[test]
    fn una_altura_puede_cambiar_de_hash_tras_un_reorg() {
        let a = AlmacenEnMemoria::nuevo();
        let vieja = cabecera(5);
        let mut nueva = cabecera(5);
        nueva.nonce += 1; // otra cabecera a la misma altura: la rama ganadora

        a.guardar_cabecera(&vieja).unwrap();
        assert_eq!(a.hash_en_altura(5).unwrap(), Some(vieja.block_hash()));

        a.guardar_cabecera(&nueva).unwrap();
        assert_eq!(
            a.hash_en_altura(5).unwrap(),
            Some(nueva.block_hash()),
            "la altura apunta a la rama ganadora"
        );

        // Pero la vieja **sigue recuperable por su hash**: la necesita el undo data de un reorg
        // que vuelva atrás.
        assert_eq!(a.cabecera(&vieja.block_hash()).unwrap(), Some(vieja));
    }

    /// Un almacén se puede usar desde varios hilos sin corromperse.
    #[test]
    fn se_puede_usar_desde_varios_hilos() {
        use std::sync::Arc;
        let a = Arc::new(AlmacenEnMemoria::nuevo());
        let mut hilos = Vec::new();

        for t in 0..8u32 {
            let a = Arc::clone(&a);
            hilos.push(std::thread::spawn(move || {
                for i in 0..50u32 {
                    let c = cabecera(t * 50 + i);
                    a.guardar_cabecera(&c).expect("guarda");
                    assert_eq!(a.cabecera(&c.block_hash()).expect("lee"), Some(c));
                }
            }));
        }
        for h in hilos {
            h.join().expect("el hilo no debe entrar en pánico");
        }
        assert_eq!(a.cabeceras_guardadas(), 400);
    }
}
