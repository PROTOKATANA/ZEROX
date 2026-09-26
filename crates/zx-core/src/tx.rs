//! Tipos de dominio de una transacción (SPEC §5).
//!
//! Estos structs **no** saben serializarse a wire: eso es Cap'n Proto, en otro crate, y no es
//! consensus-critical (C-ENC-08). Lo único que saben es escribirse en la preimagen canónica, y solo
//! a través de [`crate::preimage`].

use crate::amount::Amount;
use crate::digest::TxId;
use crate::error::EncodingError;
use crate::firma::ClavePublica;
use crate::preimage::dag::DagBlockHeader;

/// Máximo de claves en un `MultiSig` (C-TX-11).
pub const MAX_MULTISIG_KEYS: usize = 16;

/// Referencia a una salida concreta de una transacción anterior.
///
/// Deriva `Hash` porque es la clave natural del UTXO set. La igualdad es la de sus dos campos, así
/// que dos referencias a la misma salida son la misma clave — que es exactamente lo que C-TX-16 y
/// C-BLK-09 necesitan detectar.
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Debug, Hash)]
pub struct OutPoint {
    /// Transacción que creó la salida.
    pub prev_txid: TxId,
    /// Índice de la salida dentro de esa transacción.
    pub prev_index: u32,
}

/// Entrada de una transacción (§5.2).
///
/// **La firma no está aquí.** Es dato de autorización y vive en el testigo (§4.4). Que el txid no
/// la incluya es lo que lo hace no maleable (C-TX-01).
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct TxIn {
    /// Salida que se consume.
    pub outpoint: OutPoint,
    /// Campo `sequence`.
    pub sequence: u32,
}

/// Condición de gasto de una salida (C-TX-09).
///
/// Enum **cerrado**. No hay lenguaje de script en v1.0, y ese es el punto: un conjunto cerrado de
/// tipos tiene una superficie de ataque acotada y enumerable. La puerta a futuras extensiones es el
/// campo `version` de la transacción, no un intérprete.
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum Lock {
    /// Gastable con la firma de esta clave.
    ///
    /// **P2K, no P2KH** (P-020): la salida guarda la clave Ed25519 en claro, no su hash. Como
    /// `SHA3-256` produce 32 bytes y una clave Ed25519 mide **exactamente** 32 bytes, hashear no
    /// ahorraba un solo byte aquí y costaba 32 bytes por entrada en el testigo.
    PubKey {
        /// La clave pública Ed25519, 32 bytes.
        pubkey: ClavePublica,
    },
    /// Gastable con `k` firmas de `k` claves distintas del conjunto.
    MultiSig {
        /// Umbral de firmas necesarias.
        k: u8,
        /// Las claves admitidas, en claro (P2K, ver [`Lock::PubKey`]).
        pubkeys: Vec<ClavePublica>,
    },
    /// Hash Time-Locked Contract.
    ///
    /// Gastable por *(a)* preimagen `p` con `SHA3-256(p) = hash` **y** firma de `receiver`; o
    /// *(b)* altura de bloque `≥ timeout` **y** firma de `sender`.
    ///
    /// Es el gancho para canales de pago: junto con `MultiSig` y `lock_time` basta para construir
    /// canales unidireccionales.
    Htlc {
        /// `SHA3-256(preimagen)`.
        hash: [u8; 32],
        /// Clave de quien puede gastar presentando la preimagen.
        receiver: ClavePublica,
        /// Clave de quien recupera los fondos pasado el `timeout`.
        sender: ClavePublica,
        /// Altura a partir de la cual `sender` puede recuperar.
        timeout: u32,
    },
}

/// Discriminantes de [`Lock`] (C-TX-09). Son consenso: no se reordenan jamás.
impl Lock {
    /// Discriminante de `PubKey`.
    pub const DISC_PUBKEY: u8 = 0x00;
    /// Discriminante de `MultiSig`.
    pub const DISC_MULTISIG: u8 = 0x01;
    /// Discriminante de `Htlc`.
    pub const DISC_HTLC: u8 = 0x02;

    /// El byte discriminante de esta variante.
    #[must_use]
    pub const fn discriminante(&self) -> u8 {
        match self {
            Self::PubKey { .. } => Self::DISC_PUBKEY,
            Self::MultiSig { .. } => Self::DISC_MULTISIG,
            Self::Htlc { .. } => Self::DISC_HTLC,
        }
    }

    /// Construye un `MultiSig` validando C-TX-11.
    ///
    /// # Errores
    /// [`EncodingError::MultiSigInvalido`] si `k` está fuera de `1..=n`, si `n > MAX_MULTISIG_KEYS`,
    /// o si hay claves repetidas.
    pub fn multisig(k: u8, pubkeys: Vec<ClavePublica>) -> Result<Self, EncodingError> {
        let n = pubkeys.len();
        let fallo = |motivo| EncodingError::MultiSigInvalido { k, n, motivo };

        if n == 0 || n > MAX_MULTISIG_KEYS {
            return Err(fallo("n debe estar en 1..=MAX_MULTISIG_KEYS"));
        }
        if k == 0 || usize::from(k) > n {
            return Err(fallo("k debe estar en 1..=n"));
        }
        // C-TX-11: las claves MUST ser distintas entre sí. Con n ≤ 16 la comparación cuadrática es
        // más barata y más simple de auditar que ordenar.
        let mut vistas: Vec<&ClavePublica> = Vec::with_capacity(n);
        for h in &pubkeys {
            if vistas.contains(&h) {
                return Err(fallo("las claves deben ser distintas"));
            }
            vistas.push(h);
        }
        Ok(Self::MultiSig { k, pubkeys })
    }
}

/// Salida de una transacción (§5.3).
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct TxOut {
    /// Importe, en brek.
    pub value: Amount,
    /// Condición de gasto.
    pub lock: Lock,
}

/// Tipo de operación de garantía (F-07, `C-BON-02/05/06`).
///
/// Los valores son consenso: no se reordenan. El `u8` del wire es el discriminante.
#[repr(u8)]
#[derive(Clone, Copy, PartialEq, Eq, Debug, Hash)]
pub enum TipoGarantia {
    /// Depósito: entradas ≥ 1, salidas ≥ 0 (cambio). `Σ entradas = Σ salidas + importe`.
    Deposito = 1,
    /// Retiro: sin entradas ni salidas; mueve `importe` de activo a en retirada.
    Retiro = 2,
    /// Liberación: sin entradas ni salidas; crea la salida implícita por `importe`.
    Liberacion = 3,
}

impl TipoGarantia {
    /// El byte de wire (F-07).
    #[must_use]
    pub const fn byte(self) -> u8 {
        self as u8
    }

    /// Decodifica el byte de wire (F-07). Conjunto **cerrado**: otro valor se rechaza.
    #[must_use]
    pub const fn desde_byte(v: u8) -> Option<Self> {
        match v {
            1 => Some(Self::Deposito),
            2 => Some(Self::Retiro),
            3 => Some(Self::Liberacion),
            _ => None,
        }
    }
}

/// Campos de efecto extra por versión (F-05, F-06, F-07, F-06/SL-4a).
///
/// Es el «gancho de extensión» de `C-TX-07`. La coherencia con `version` es obligatoria:
/// `1 ⇔ Ninguna`, `2 ⇔ Garantia`, `3 ⇔ CoinbasePost`, `4 ⇔ Evidencia`; `validar_forma_tx` la exige
/// (para la v4, `validar_forma_tx_v4`, que el motor invoca cuando el perfil activa la evidencia).
#[derive(Clone, PartialEq, Eq, Debug)]
#[expect(
    clippy::large_enum_variant,
    reason = "EV-01/EV-02: la v4 transporta dos cabeceras PoAS_PoT_DAG completas (hasta 1 037 B \
              cada una); boxearlas complicaría el wire, la preimagen y el undo sin beneficio"
)]
pub enum ExtensionTx {
    /// Versión 1: sin campos extra (idéntica a `9681061`).
    Ninguna,
    /// Versión 2: operación de garantía (F-07), con el nonce por clave de F-15.
    Garantia {
        /// Operación.
        tipo: TipoGarantia,
        /// Clave a la que se acredita / de la que se retira / a la que se libera.
        clave: ClavePublica,
        /// Importe de la operación. `> 0` y `≤ ZX_VALUE_SANITY_LIMIT`.
        importe: Amount,
        /// Nonce por clave de garantía (F-15): debe ser `nonce_siguiente[clave]` al aplicarse.
        nonce: u64,
    },
    /// Versión 3: coinbase PoST (F-09). `clave` MUST ser `sol.public_key` de su cabecera y `slot`
    /// MUST ser el slot del bloque (F-17); ambas cosas las comprueba la máquina de estados.
    CoinbasePost {
        /// Clave pagada.
        clave: ClavePublica,
        /// Importe de la coinbase.
        importe: Amount,
        /// Slot del bloque que la contiene (F-17).
        slot: u64,
    },
    /// Versión 4 · `EvidenceTx` (EV-01…EV-04): **exactamente dos** cabeceras `PoAS_PoT_DAG`
    /// completas, con su sello, en orden canónico `pre_hash(h1) < pre_hash(h2)`.
    ///
    /// No lleva entradas, ni salidas, ni testigos de transacción: el sello vive dentro de cada
    /// cabecera. El `txid` compromete los bytes completos de ambas (`EV-03`).
    Evidencia {
        /// `H1`: cabecera con el `pre_hash` lexicográficamente menor.
        h1: DagBlockHeader,
        /// `H2`: cabecera con el `pre_hash` lexicográficamente mayor.
        h2: DagBlockHeader,
    },
}

/// Una transacción, solo con sus **datos de efecto** (§5.1).
///
/// Los datos de autorización —las firmas— viajan aparte, en el testigo. Ver [`crate::preimage`].
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct Tx {
    /// Versión. En v0: `1` transferencia/coinbase PoW, `2` garantía, `3` coinbase PoST. Es el
    /// gancho de extensión del protocolo (C-TX-07).
    pub version: u32,
    /// Entradas consumidas.
    pub inputs: Vec<TxIn>,
    /// Salidas creadas.
    pub outputs: Vec<TxOut>,
    /// Altura o timestamp antes del cual la transacción no es válida.
    pub lock_time: u32,
    /// Altura tras la cual deja de ser válida; `0` = sin expiración (C-TX-08).
    pub expiry_height: u32,
    /// Campos de efecto extra de la versión (F-05). Coherencia obligatoria con `version`.
    pub extension: ExtensionTx,
}

impl Tx {
    /// ¿Esta transacción es candidata a **coinbase PoW**?
    ///
    /// F-05: una v1 con `n_in = 0` solo es válida como coinbase PoW (o como la coinbase sin salidas
    /// de valor del génesis, F-13). `validar_forma_tx` no puede saber si la transacción es la
    /// primera de un bloque PoW, así que no la rechaza: la acepta y expone esta marca para que el
    /// contexto decida. No sustituye a la comprobación contextual.
    #[must_use]
    pub fn es_candidata_coinbase_pow(&self) -> bool {
        self.version == 1
            && self.inputs.is_empty()
            && matches!(self.extension, ExtensionTx::Ninguna)
    }
}

/// La salida que una entrada consume, tal y como existía en el UTXO set.
///
/// Hace falta para el sighash: `amounts_digest` y `scripts_digest` (C-SIG-02) comprometen el
/// importe y la condición de bloqueo de **las salidas gastadas**, no de las que se crean. Es lo que
/// permite a un firmante *offline* verificar el fee real sin recibir las transacciones previas
/// enteras.
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct SpentOutput {
    /// Importe de la salida consumida.
    pub value: Amount,
    /// Condición de bloqueo que se está satisfaciendo.
    pub lock: Lock,
}

#[cfg(test)]
mod tests {
    use super::{ClavePublica, Lock, MAX_MULTISIG_KEYS};

    fn clave(n: u8) -> ClavePublica {
        ClavePublica::desde_bytes([n; 32])
    }

    #[test]
    fn los_discriminantes_son_los_del_spec() {
        assert_eq!(Lock::PubKey { pubkey: clave(0) }.discriminante(), 0x00);
        assert_eq!(Lock::DISC_MULTISIG, 0x01);
        assert_eq!(Lock::DISC_HTLC, 0x02);
    }

    #[test]
    fn multisig_valido() {
        assert!(Lock::multisig(2, vec![clave(1), clave(2), clave(3)]).is_ok());
        assert!(Lock::multisig(1, vec![clave(1)]).is_ok());
    }

    #[test]
    fn multisig_rechaza_k_fuera_de_rango() {
        assert!(Lock::multisig(0, vec![clave(1)]).is_err(), "k = 0");
        assert!(
            Lock::multisig(3, vec![clave(1), clave(2)]).is_err(),
            "k > n"
        );
    }

    #[test]
    fn multisig_rechaza_n_fuera_de_rango() {
        assert!(Lock::multisig(1, vec![]).is_err(), "n = 0");
        let demasiadas: Vec<ClavePublica> = (0..=u8::try_from(MAX_MULTISIG_KEYS).unwrap_or(16))
            .map(clave)
            .collect();
        assert!(
            Lock::multisig(1, demasiadas).is_err(),
            "n > MAX_MULTISIG_KEYS"
        );
    }

    #[test]
    fn multisig_rechaza_claves_repetidas() {
        assert!(
            Lock::multisig(2, vec![clave(7), clave(7)]).is_err(),
            "C-TX-11: las claves deben ser distintas"
        );
    }

    #[test]
    fn dieciseis_claves_es_el_limite_exacto() {
        let justas: Vec<ClavePublica> = (0..16).map(clave).collect();
        assert_eq!(justas.len(), MAX_MULTISIG_KEYS);
        assert!(Lock::multisig(16, justas).is_ok());
    }
}
