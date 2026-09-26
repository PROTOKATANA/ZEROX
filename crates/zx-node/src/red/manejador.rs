//! [`ManejadorEntrante`] real: el puente entre el bucle asíncrono de `zx-p2p` y el hilo de consenso
//! síncrono (`ORDEN-W06d2`, decisión 1).
//!
//! Cada método es deliberadamente trivial: una lectura de [`VistaRed`] (rápida, sin bloquear) o un
//! `send` a un canal **no bloqueante** hacia el hilo de consenso. Ninguno ejecuta la tubería de
//! admisión — eso es exactamente lo que la orden prohíbe hacer aquí (`~66 ms` de PoT pararían la
//! red). El veredicto real llega después, informado por el hilo de consenso con
//! [`zx_p2p::servicio::ManejoRed::informar_validacion_bloqueante`].

use std::sync::Arc;

use tokio::sync::mpsc::UnboundedSender;

use zx_core::digest::BlockHash;
use zx_core::preimage::block::BlockHeader;
use zx_p2p::entrante::{IdDiferido, ManejadorEntrante, Veredicto};
use zx_p2p::mensaje::{BloqueRed, Estado};

use super::TrabajoRed;
use super::vista::VistaRed;

/// El manejador. Barato de clonar (todo dentro es `Arc`/canal clonable), pero se comparte como
/// `Arc<ManejadorRed>` porque [`zx_p2p::servicio::arrancar_con`] lo exige.
pub struct ManejadorRed {
    trabajo: UnboundedSender<TrabajoRed>,
    vista: Arc<VistaRed>,
}

impl ManejadorRed {
    /// Construye el manejador con el canal hacia el hilo de consenso y la vista compartida.
    #[must_use]
    pub const fn nuevo(trabajo: UnboundedSender<TrabajoRed>, vista: Arc<VistaRed>) -> Self {
        Self { trabajo, vista }
    }
}

impl ManejadorEntrante for ManejadorRed {
    fn estado(&self) -> Estado {
        self.vista.estado()
    }

    fn bloque_difundido(&self, id: IdDiferido, bloque: &BloqueRed) -> Veredicto {
        if self
            .trabajo
            .send(TrabajoRed::BloqueDifundido {
                id,
                bloque: bloque.clone(),
            })
            .is_err()
        {
            // El hilo de consenso ya no existe: no hay a quién diferirle nada. No es un defecto del
            // par que lo propagó, así que `Ignorar` (nunca `Rechazar`) es la única lectura honesta.
            tracing::error!("hilo de consenso caído: bloque difundido descartado sin juzgar");
            return Veredicto::Ignorar;
        }
        Veredicto::Diferir
    }

    fn tx_difundida(&self, _tx_serializada: &[u8]) -> Veredicto {
        // 0.0.1 no tiene tema de transacciones (REVISION-W06c.md): nada que hacer con esto todavía.
        Veredicto::Ignorar
    }

    fn cabeceras_desde(&self, locator: &[BlockHash], hasta: Option<BlockHash>) -> Vec<BlockHeader> {
        self.vista.cabeceras_desde(locator, hasta)
    }

    fn bloques_por_hash(&self, hashes: &[BlockHash]) -> Vec<BloqueRed> {
        self.vista.bloques_por_hash(hashes)
    }
}

#[cfg(test)]
#[expect(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    reason = "los tests fallan con panic por diseño"
)]
mod tests {
    use super::super::TrabajoRed;
    use super::super::vista::VistaRed;
    use super::ManejadorRed;
    use std::sync::Arc;
    use zx_core::amount::Amount;
    use zx_core::digest::{BlockHash, Digest, MerkleRoot, TxId};
    use zx_core::firma::ClavePublica;
    use zx_core::preimage::block::BlockHeader;
    use zx_core::red::Red;
    use zx_core::tx::{ExtensionTx, Lock, OutPoint, Tx, TxIn, TxOut};
    use zx_p2p::entrante::{IdDiferido, ManejadorEntrante, Veredicto};
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

    fn bloque_pow(n: u8) -> BloqueRed {
        BloqueRed::Pow {
            cabecera: BlockHeader {
                consensus_branch_id: 0xa8b4_66a7,
                prev_hash: h(n),
                merkle_root: MerkleRoot::from_digest(Digest::from_bytes([2; 32])),
                timestamp: 1_000,
                bits: 0x1c07_fff8,
                nonce: u64::from(n),
                height: u32::from(n),
            },
            txs: vec![Tx {
                version: 1,
                inputs: vec![TxIn {
                    outpoint: OutPoint {
                        prev_txid: TxId::from_digest(Digest::from_bytes([n; 32])),
                        prev_index: 0,
                    },
                    sequence: 0,
                }],
                outputs: vec![TxOut {
                    value: Amount::nuevo(1).unwrap(),
                    lock: Lock::PubKey {
                        pubkey: ClavePublica::desde_bytes([n; 32]),
                    },
                }],
                lock_time: 0,
                expiry_height: 0,
                extension: ExtensionTx::Ninguna,
            }],
            testigos: vec![vec![vec![0xAA; 64]]],
        }
    }

    #[test]
    fn bloque_difundido_siempre_difiere_y_encola() {
        let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();
        let m = ManejadorRed::nuevo(tx, Arc::new(VistaRed::nueva(estado_vacio())));

        let v = m.bloque_difundido(IdDiferido::default(), &bloque_pow(1));
        assert_eq!(v, Veredicto::Diferir);

        let recibido = rx.try_recv().expect("debe haber encolado trabajo");
        match recibido {
            TrabajoRed::BloqueDifundido { id, bloque } => {
                assert_eq!(id, IdDiferido::default());
                assert_eq!(bloque, bloque_pow(1));
            }
            TrabajoRed::BloqueDeSincronizacion { .. } => panic!("no es de sincronización"),
        }
    }

    #[test]
    fn sin_hilo_de_consenso_se_ignora_sin_penalizar() {
        let (tx, rx) = tokio::sync::mpsc::unbounded_channel();
        drop(rx); // el hilo de consenso "murió": el canal está cerrado.
        let m = ManejadorRed::nuevo(tx, Arc::new(VistaRed::nueva(estado_vacio())));
        assert_eq!(
            m.bloque_difundido(IdDiferido::default(), &bloque_pow(1)),
            Veredicto::Ignorar
        );
    }

    #[test]
    fn estado_y_lecturas_delegan_en_la_vista() {
        let (tx, _rx) = tokio::sync::mpsc::unbounded_channel();
        let vista = Arc::new(VistaRed::nueva(estado_vacio()));
        let m = ManejadorRed::nuevo(tx, Arc::clone(&vista));
        assert_eq!(m.estado(), estado_vacio());
        assert!(m.cabeceras_desde(&[h(5)], None).is_empty());
        assert!(m.bloques_por_hash(&[h(5)]).is_empty());
    }
}
