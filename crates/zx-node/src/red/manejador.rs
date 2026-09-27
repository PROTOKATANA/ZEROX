//! [`ManejadorEntrante`] real: el puente entre el bucle asíncrono de `zx-p2p` y el hilo de consenso
//! síncrono (`ORDEN-W06d2`, decisión 1).
//!
//! Cada método es deliberadamente trivial: una lectura de [`VistaRed`] (rápida, sin bloquear) o un
//! `send` a un canal **no bloqueante** hacia el hilo de consenso. Ninguno ejecuta la tubería de
//! admisión — eso es exactamente lo que la orden prohíbe hacer aquí (`~66 ms` de PoT pararían la
//! red). El veredicto real llega después, informado por el hilo de consenso con
//! [`zx_p2p::servicio::ManejoRed::informar_validacion_bloqueante`].

use std::sync::Arc;
use std::time::Instant;

use zx_core::digest::BlockHash;
use zx_core::preimage::block::BlockHeader;
use zx_p2p::entrante::{IdDiferido, ManejadorEntrante, Veredicto};
use zx_p2p::mensaje::{BloqueRed, Estado};

use super::vista::VistaRed;
use super::{EmisorTrabajoRed, ResultadoEnvioTrabajo, TrabajoRed};
use crate::registro::Registro;

/// El manejador. Barato de clonar (todo dentro es `Arc`/canal clonable), pero se comparte como
/// `Arc<ManejadorRed>` porque [`zx_p2p::servicio::arrancar_con`] lo exige.
pub struct ManejadorRed {
    trabajo: EmisorTrabajoRed,
    vista: Arc<VistaRed>,
    /// Registro estructurado compartido (`ORDEN-W07a`): solo se usa para el evento no crítico
    /// `limite_alcanzado` (cola de trabajo llena). No se escribe nada por bloque aquí.
    registro: Arc<Registro>,
}

impl ManejadorRed {
    /// Construye el manejador con el canal hacia el hilo de consenso, la vista compartida y el
    /// registro estructurado.
    #[must_use]
    pub const fn nuevo(
        trabajo: EmisorTrabajoRed,
        vista: Arc<VistaRed>,
        registro: Arc<Registro>,
    ) -> Self {
        Self {
            trabajo,
            vista,
            registro,
        }
    }
}

impl ManejadorEntrante for ManejadorRed {
    fn estado(&self) -> Estado {
        self.vista.estado()
    }

    fn bloque_difundido(&self, id: IdDiferido, bloque: &BloqueRed) -> Veredicto {
        // `ORDEN-W06d6` (RI-3a #3): cola acotada en elementos y en bytes. Si está llena, se
        // descarta **sin bloquear la red** (nunca `send().await`) y se registra — un bloque
        // honesto descartado así se recupera por la petición de padres o por la sincronización por
        // registro (decisión 1), nunca queda perdido en silencio sin que nadie lo sepa.
        let llegada = Instant::now();
        match self.trabajo.intentar_enviar(TrabajoRed::BloqueDifundido {
            id,
            bloque: bloque.clone(),
            llegada,
        }) {
            ResultadoEnvioTrabajo::Encolado => Veredicto::Diferir,
            ResultadoEnvioTrabajo::Lleno(_) => {
                tracing::warn!(
                    "cola de trabajo hacia el hilo de consenso llena: bloque difundido descartado \
                     sin juzgar (límite alcanzado, RI-3a #3)"
                );
                // `ORDEN-W07a`: traza estructurada del único límite que `zx-node` ve descartar algo
                // (la cola propia; los límites C-NET internos de `zx-p2p` no son observables aquí).
                let evento = self
                    .registro
                    .evento("limite_alcanzado")
                    .str("limite", "cola_trabajo_consenso")
                    .str(
                        "detalle",
                        "bloque difundido descartado: cola hacia el hilo de consenso llena",
                    );
                let _ = self.registro.escribir(evento, false);
                Veredicto::Ignorar
            }
            ResultadoEnvioTrabajo::Cerrado(_) => {
                // El hilo de consenso ya no existe: no hay a quién diferirle nada. No es un
                // defecto del par que lo propagó, así que `Ignorar` (nunca `Rechazar`) es la única
                // lectura honesta.
                tracing::error!("hilo de consenso caído: bloque difundido descartado sin juzgar");
                Veredicto::Ignorar
            }
        }
    }

    /// `ORDEN-W06d10` decisión 1: `zx-p2p` penalizó al propagador de un bloque difundido
    /// **demostrablemente inválido** (lo desconectó y puntuó). Escribe `par_penalizado` (`par`,
    /// `motivo`, `accion`) según `P-ZRX/P-MEDICION/ESQUEMA-REGISTRO-v1.md` §1. No es crítico: un
    /// fallo de escritura no debe tumbar nada (el par ya está desconectado).
    fn par_penalizado(&self, peer: libp2p::PeerId, motivo: &str, accion: &str) {
        let evento = self
            .registro
            .evento("par_penalizado")
            .str("par", &peer.to_string())
            .str("motivo", motivo)
            .str("accion", accion);
        let _ = self.registro.escribir(evento, false);
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

    fn pagina_registro(&self, desde: u64) -> (Vec<BloqueRed>, u64) {
        self.vista.pagina_registro(
            desde,
            zx_p2p::limites::MAX_BLOQUES_POR_RESPUESTA,
            zx_p2p::limites::MAX_RESPUESTA_BYTES,
        )
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

    /// Registro estructurado de test (fichero temporal que vive todo el test).
    fn registro() -> (tempfile::TempDir, Arc<crate::registro::Registro>) {
        let dir = tempfile::tempdir().expect("tempdir");
        let r = Arc::new(
            crate::registro::Registro::abrir(&dir.path().join("registro.jsonl"))
                .expect("abrir registro"),
        );
        (dir, r)
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
            longitud_registro: 0,
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
        let (_dir, reg) = registro();
        let (tx, mut rx) = super::super::nueva_cola_trabajo_red();
        let m = ManejadorRed::nuevo(tx, Arc::new(VistaRed::nueva(estado_vacio())), reg);

        let v = m.bloque_difundido(IdDiferido::default(), &bloque_pow(1));
        assert_eq!(v, Veredicto::Diferir);

        let recibido = rx.try_recv().expect("debe haber encolado trabajo");
        match recibido {
            TrabajoRed::BloqueDifundido { id, bloque, .. } => {
                assert_eq!(id, IdDiferido::default());
                assert_eq!(bloque, bloque_pow(1));
            }
            TrabajoRed::BloqueDeSincronizacion { .. } => panic!("no es de sincronización"),
        }
    }

    #[test]
    fn sin_hilo_de_consenso_se_ignora_sin_penalizar() {
        let (_dir, reg) = registro();
        let (tx, rx) = super::super::nueva_cola_trabajo_red();
        drop(rx); // el hilo de consenso "murió": el canal está cerrado.
        let m = ManejadorRed::nuevo(tx, Arc::new(VistaRed::nueva(estado_vacio())), reg);
        assert_eq!(
            m.bloque_difundido(IdDiferido::default(), &bloque_pow(1)),
            Veredicto::Ignorar
        );
    }

    #[test]
    fn estado_y_lecturas_delegan_en_la_vista() {
        let (_dir, reg) = registro();
        let (tx, _rx) = super::super::nueva_cola_trabajo_red();
        let vista = Arc::new(VistaRed::nueva(estado_vacio()));
        let m = ManejadorRed::nuevo(tx, Arc::clone(&vista), reg);
        assert_eq!(m.estado(), estado_vacio());
        assert!(m.cabeceras_desde(&[h(5)], None).is_empty());
        assert!(m.bloques_por_hash(&[h(5)]).is_empty());
    }

    /// `ORDEN-W07a` §1: con la cola de trabajo llena, un bloque difundido se descarta **sin
    /// bloquear la red** y se traza `limite_alcanzado` (el único límite que `zx-node` ve descartar
    /// algo; los internos de `zx-p2p` no son observables desde aquí).
    #[test]
    fn cola_llena_traza_el_limite_alcanzado() {
        use super::super::ResultadoEnvioTrabajo;

        let (dir, reg) = registro();
        let (tx, _rx) = super::super::nueva_cola_trabajo_red();
        for i in 0..super::super::MAX_TRABAJO_RED {
            let resultado = tx.intentar_enviar(TrabajoRed::BloqueDifundido {
                id: IdDiferido::default(),
                bloque: bloque_pow((i % 200) as u8),
                llegada: std::time::Instant::now(),
            });
            assert!(
                matches!(resultado, ResultadoEnvioTrabajo::Encolado),
                "la cola debe admitir hasta su tope declarado"
            );
        }
        let m = ManejadorRed::nuevo(
            tx,
            Arc::new(VistaRed::nueva(estado_vacio())),
            Arc::clone(&reg),
        );
        assert_eq!(
            m.bloque_difundido(IdDiferido::default(), &bloque_pow(3)),
            Veredicto::Ignorar
        );
        let texto =
            std::fs::read_to_string(dir.path().join("registro.jsonl")).expect("leer registro");
        assert!(
            texto.contains("\"tipo\":\"limite_alcanzado\""),
            "falta limite_alcanzado: {texto}"
        );
    }
}
