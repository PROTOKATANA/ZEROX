//! Tipos de dominio de una transacción (SPEC §5).
//!
//! Estos structs **no** saben serializarse a wire: eso es Cap'n Proto, en otro crate, y no es
//! consensus-critical (C-ENC-08). Lo único que saben es escribirse en la preimagen canónica, y solo
//! a través de [`crate::preimage`].

use crate::amount::Amount;
use crate::digest::TxId;
use crate::error::EncodingError;

/// Longitud de un hash de clave pública: `SHA3-256(pubkey)` **completo** (C-ENC-07).
///
/// 32 bytes, sin truncar. 20 bytes darían 80 bits de resistencia a colisiones, insuficiente para
/// una cadena que nace en 2026.
pub const LONGITUD_HASH_CLAVE: usize = 32;

/// Máximo de claves en un `MultiSig` (C-TX-11).
pub const MAX_MULTISIG_KEYS: usize = 16;

/// Hash de una clave pública: `SHA3-256(pubkey)`.
pub type HashClave = [u8; LONGITUD_HASH_CLAVE];

/// Referencia a una salida concreta de una transacción anterior.
///
/// Deriva `Hash` porque es la clave natural del UTXO set. La igualdad es la de sus dos campos, así
/// que dos referencias a la misma salida son la misma clave — que es exactamente lo que C-TX-16 y
/// C-BLK-09 necesitan detectar.
#[derive(Clone, Copy, PartialEq, Eq, Debug, Hash)]
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
    /// Gastable con la firma de la clave cuyo hash coincide.
    PubKey {
        /// `SHA3-256(pubkey)`.
        pubkey_hash: HashClave,
    },
    /// Gastable con `k` firmas de `k` claves distintas del conjunto.
    MultiSig {
        /// Umbral de firmas necesarias.
        k: u8,
        /// Hashes de las claves admitidas.
        pubkey_hashes: Vec<HashClave>,
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
        /// Quien puede gastar presentando la preimagen.
        receiver: HashClave,
        /// Quien recupera los fondos pasado el `timeout`.
        sender: HashClave,
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
    pub fn multisig(k: u8, pubkey_hashes: Vec<HashClave>) -> Result<Self, EncodingError> {
        let n = pubkey_hashes.len();
        let fallo = |motivo| EncodingError::MultiSigInvalido { k, n, motivo };

        if n == 0 || n > MAX_MULTISIG_KEYS {
            return Err(fallo("n debe estar en 1..=MAX_MULTISIG_KEYS"));
        }
        if k == 0 || usize::from(k) > n {
            return Err(fallo("k debe estar en 1..=n"));
        }
        // C-TX-11: las claves MUST ser distintas entre sí. Con n ≤ 16 la comparación cuadrática es
        // más barata y más simple de auditar que ordenar.
        let mut vistas: Vec<&HashClave> = Vec::with_capacity(n);
        for h in &pubkey_hashes {
            if vistas.contains(&h) {
                return Err(fallo("las claves deben ser distintas"));
            }
            vistas.push(h);
        }
        Ok(Self::MultiSig { k, pubkey_hashes })
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

/// Una transacción, solo con sus **datos de efecto** (§5.1).
///
/// Los datos de autorización —las firmas— viajan aparte, en el testigo. Ver [`crate::preimage`].
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct Tx {
    /// Versión. **MUST** ser `1` en v1.0 (C-TX-07). Es el gancho de extensión del protocolo.
    pub version: u32,
    /// Entradas consumidas.
    pub inputs: Vec<TxIn>,
    /// Salidas creadas.
    pub outputs: Vec<TxOut>,
    /// Altura o timestamp antes del cual la transacción no es válida.
    pub lock_time: u32,
    /// Altura tras la cual deja de ser válida; `0` = sin expiración (C-TX-08).
    pub expiry_height: u32,
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
    use super::{HashClave, Lock, MAX_MULTISIG_KEYS};

    fn clave(n: u8) -> HashClave {
        [n; 32]
    }

    #[test]
    fn los_discriminantes_son_los_del_spec() {
        assert_eq!(
            Lock::PubKey {
                pubkey_hash: clave(0)
            }
            .discriminante(),
            0x00
        );
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
        let demasiadas: Vec<HashClave> = (0..=u8::try_from(MAX_MULTISIG_KEYS).unwrap_or(16))
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
        let justas: Vec<HashClave> = (0..16).map(clave).collect();
        assert_eq!(justas.len(), MAX_MULTISIG_KEYS);
        assert!(Lock::multisig(16, justas).is_ok());
    }
}
