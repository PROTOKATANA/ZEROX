//! Instantánea de solo lectura de lo que el nodo tiene admitido, compartida entre el hilo de
//! consenso (que la escribe tras cada admisión) y el bucle asíncrono de `zx-p2p` (que la lee para
//! responder al saludo y a las peticiones de sincronización, decisión 4 de `ORDEN-W06d2`).
//!
//! # Por qué una instantánea, y no una llamada al hilo de consenso
//!
//! [`zx_p2p::entrante::ManejadorEntrante`] exige métodos **rápidos y no bloqueantes** (se llaman
//! desde el bucle de eventos de `zx-p2p`; mientras uno corre, el `Swarm` no se pollea). Pedirle la
//! respuesta al hilo de consenso por un canal y esperarla bloquearía exactamente ese bucle. Una
//! instantánea protegida por `RwLock`, actualizada por el hilo de consenso cada vez que cambia algo
//! que el saludo o la sincronización necesitan, resuelve la lectura sin ida y vuelta.

use std::collections::BTreeMap;
use std::sync::RwLock;

use zx_core::digest::BlockHash;
use zx_core::preimage::block::BlockHeader;
use zx_p2p::mensaje::{BloqueRed, Estado};

struct Interior {
    estado: Estado,
    /// Cabeceras PoW admitidas, en orden de altura ascendente (índice == altura).
    cabeceras_pow: Vec<BlockHeader>,
    cuerpos_pow: BTreeMap<BlockHash, BloqueRed>,
    cuerpos_post: BTreeMap<BlockHash, BloqueRed>,
}

/// La instantánea. Ver el docstring del módulo.
pub struct VistaRed {
    interior: RwLock<Interior>,
}

impl VistaRed {
    /// Una instantánea nueva con el saludo inicial (normalmente, justo tras el génesis).
    #[must_use]
    pub fn nueva(estado_inicial: Estado) -> Self {
        Self {
            interior: RwLock::new(Interior {
                estado: estado_inicial,
                cabeceras_pow: Vec::new(),
                cuerpos_pow: BTreeMap::new(),
                cuerpos_post: BTreeMap::new(),
            }),
        }
    }

    /// El hilo de consenso reemplaza el saludo tras cada cambio de punta.
    pub fn actualizar_estado(&self, estado: Estado) {
        if let Ok(mut i) = self.interior.write() {
            i.estado = estado;
        }
    }

    /// El hilo de consenso registra un bloque PoW recién admitido (para servir `CabecerasPow` y
    /// `Bloques`). `altura` MUST ser exactamente `cabeceras_pow.len()` (secuencial, sin huecos): la
    /// fase PoW nunca reordena.
    pub fn registrar_pow(&self, altura: u32, bloque: BloqueRed) {
        let Ok(mut i) = self.interior.write() else {
            return;
        };
        let BloqueRed::Pow { cabecera, .. } = &bloque else {
            debug_assert!(false, "registrar_pow con un bloque que no es PoW");
            return;
        };
        let esperado = i.cabeceras_pow.len();
        if altura as usize == esperado {
            i.cabeceras_pow.push(*cabecera);
        } else if (altura as usize) < esperado {
            // Repetición al reiniciar (D-N03′): ya está, no se duplica.
        } else {
            // Un hueco de verdad sería un bug del llamante; no hay nada seguro que hacer aquí salvo
            // no corromper el índice por altura (dejarlo tal cual y solo indexar el cuerpo).
            tracing::error!(
                altura,
                esperado,
                "registrar_pow con un hueco de altura: la vista de cabeceras queda incompleta"
            );
        }
        i.cuerpos_pow.insert(cabecera.block_hash(), bloque);
    }

    /// El hilo de consenso registra un bloque PoST recién admitido.
    pub fn registrar_post(&self, hash: BlockHash, bloque: BloqueRed) {
        if let Ok(mut i) = self.interior.write() {
            i.cuerpos_post.insert(hash, bloque);
        }
    }

    /// El saludo actual (para responder `Peticion::Estado`).
    #[must_use]
    pub fn estado(&self) -> Estado {
        self.interior
            .read()
            .map(|i| i.estado.clone())
            .unwrap_or_else(|e| e.into_inner().estado.clone())
    }

    /// Cabeceras PoW desde el primer hash del locator que reconozcamos, hasta `hasta` o hasta donde
    /// tengamos. Vacío si no reconocemos nada del locator (respuesta legítima, ver
    /// [`zx_p2p::entrante::ManejadorEntrante::cabeceras_desde`]).
    #[must_use]
    pub fn cabeceras_desde(
        &self,
        locator: &[BlockHash],
        hasta: Option<BlockHash>,
    ) -> Vec<BlockHeader> {
        let Ok(i) = self.interior.read() else {
            return Vec::new();
        };
        let Some(inicio) = locator
            .iter()
            .find_map(|h| i.cabeceras_pow.iter().position(|c| c.block_hash() == *h))
        else {
            return Vec::new();
        };
        let mut salida = Vec::new();
        for c in i.cabeceras_pow.iter().skip(inicio + 1) {
            salida.push(*c);
            if Some(c.block_hash()) == hasta {
                break;
            }
        }
        salida
    }

    /// Los bloques completos (PoW o PoST) que tengamos de los pedidos, en el orden pedido.
    #[must_use]
    pub fn bloques_por_hash(&self, hashes: &[BlockHash]) -> Vec<BloqueRed> {
        let Ok(i) = self.interior.read() else {
            return Vec::new();
        };
        hashes
            .iter()
            .filter_map(|h| {
                i.cuerpos_pow
                    .get(h)
                    .or_else(|| i.cuerpos_post.get(h))
                    .cloned()
            })
            .collect()
    }

    /// ¿Tenemos ya el cuerpo de este hash (PoW o PoST), lo pidamos o no otra vez?
    #[must_use]
    pub fn tiene_cuerpo(&self, hash: &BlockHash) -> bool {
        self.interior
            .read()
            .is_ok_and(|i| i.cuerpos_pow.contains_key(hash) || i.cuerpos_post.contains_key(hash))
    }

    /// Un *locator* al estilo Bitcoin: denso cerca de la punta, espaciado hacia atrás,
    /// **siempre** termina en el génesis (`ORDEN-W06d2`, decisión 4). Sirve para pedirle a un par
    /// `CabecerasPow` sin suponer que las dos cadenas coinciden más allá del primer hash que
    /// reconozca.
    #[must_use]
    pub fn locator(&self) -> Vec<BlockHash> {
        let Ok(i) = self.interior.read() else {
            return Vec::new();
        };
        let n = i.cabeceras_pow.len();
        if n == 0 {
            return Vec::new();
        }
        let mut salida = Vec::new();
        let mut paso: usize = 1;
        let mut idx = n - 1;
        loop {
            #[expect(
                clippy::indexing_slicing,
                reason = "idx siempre es < n por construcción del bucle"
            )]
            salida.push(i.cabeceras_pow[idx].block_hash());
            if idx == 0 {
                break;
            }
            idx = idx.saturating_sub(paso);
            paso = paso.saturating_mul(2);
        }
        salida
    }

    /// Nuestra altura PoW más alta conocida (0 si solo tenemos el génesis o nada aún).
    #[must_use]
    pub fn altura_pow(&self) -> u32 {
        self.interior
            .read()
            .map(|i| i.cabeceras_pow.len().saturating_sub(1) as u32)
            .unwrap_or(0)
    }
}

#[cfg(test)]
#[expect(
    clippy::indexing_slicing,
    reason = "los tests fallan con panic por diseño"
)]
mod tests {
    use super::VistaRed;
    use zx_core::digest::{BlockHash, Digest, MerkleRoot};
    use zx_core::preimage::block::BlockHeader;
    use zx_core::red::Red;
    use zx_p2p::mensaje::{BloqueRed, Estado, Fase, PuntaPow};

    fn h(n: u8) -> BlockHash {
        BlockHash::from_digest(Digest::from_bytes([n; 32]))
    }

    fn estado_vacio() -> Estado {
        Estado {
            hash_genesis: h(0),
            red: Red::Dev,
            fase: Fase::Pow,
            punta_pow: PuntaPow {
                hash: h(0),
                altura: 0,
                trabajo_acumulado: [0; 32],
            },
            terminal: None,
            puntas_post: Vec::new(),
            blue_work_virtual: [0; 32],
        }
    }

    fn cabecera(altura: u32, prev: BlockHash) -> BlockHeader {
        BlockHeader {
            consensus_branch_id: 0xa8b4_66a7,
            prev_hash: prev,
            merkle_root: MerkleRoot::from_digest(Digest::from_bytes([9; 32])),
            timestamp: 1_000 + u64::from(altura),
            bits: 0x1c07_fff8,
            nonce: u64::from(altura),
            height: altura,
        }
    }

    fn bloque_pow(altura: u32, prev: BlockHash) -> BloqueRed {
        BloqueRed::Pow {
            cabecera: cabecera(altura, prev),
            txs: Vec::new(),
            testigos: Vec::new(),
        }
    }

    #[test]
    fn sin_nada_registrado_las_cabeceras_desde_cualquier_locator_estan_vacias() {
        let v = VistaRed::nueva(estado_vacio());
        assert!(v.cabeceras_desde(&[h(5)], None).is_empty());
    }

    #[test]
    fn el_locator_devuelve_lo_que_sigue_al_primero_reconocido() {
        let v = VistaRed::nueva(estado_vacio());
        let mut prev = h(0);
        for altura in 0..5u32 {
            let b = bloque_pow(altura, prev);
            let BloqueRed::Pow { cabecera, .. } = &b else {
                unreachable!()
            };
            prev = cabecera.block_hash();
            v.registrar_pow(altura, b);
        }
        // El locator reconoce la altura 2; deben volver las alturas 3 y 4.
        let hash_altura_2 = {
            let mut p = h(0);
            for altura in 0..3u32 {
                let c = cabecera(altura, p);
                p = c.block_hash();
            }
            p
        };
        let resultado = v.cabeceras_desde(&[hash_altura_2], None);
        assert_eq!(resultado.len(), 2);
        assert_eq!(resultado[0].height, 3);
        assert_eq!(resultado[1].height, 4);
    }

    #[test]
    fn el_locator_siempre_termina_en_el_genesis_y_es_denso_cerca_de_la_punta() {
        let v = VistaRed::nueva(estado_vacio());
        let mut prev = h(0);
        let mut hashes = Vec::new();
        for altura in 0..20u32 {
            let b = bloque_pow(altura, prev);
            let BloqueRed::Pow { cabecera, .. } = &b else {
                unreachable!()
            };
            prev = cabecera.block_hash();
            hashes.push(prev);
            v.registrar_pow(altura, b);
        }
        let locator = v.locator();
        assert_eq!(locator.first(), Some(&hashes[19]), "empieza en la punta");
        assert_eq!(locator.last(), Some(&hashes[0]), "termina en el génesis");
        // Denso al principio: los dos primeros pasos son de distancia 1 y 2.
        assert_eq!(locator[1], hashes[18]);
        assert_eq!(locator[2], hashes[16]);
    }

    #[test]
    fn bloques_por_hash_respeta_el_orden_pedido_y_omite_lo_ausente() {
        let v = VistaRed::nueva(estado_vacio());
        let b0 = bloque_pow(0, h(0));
        let BloqueRed::Pow { cabecera: c0, .. } = &b0 else {
            unreachable!()
        };
        let hash0 = c0.block_hash();
        v.registrar_pow(0, b0);

        let ausente = h(200);
        let salida = v.bloques_por_hash(&[ausente, hash0]);
        assert_eq!(salida.len(), 1);
        assert!(
            matches!(&salida[0], BloqueRed::Pow { cabecera, .. } if cabecera.block_hash() == hash0)
        );
    }
}
