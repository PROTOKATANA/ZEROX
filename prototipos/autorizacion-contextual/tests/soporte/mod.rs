#![allow(dead_code)]

use autorizacion_contextual::{ContextoIdentificado, CuerpoCandidato, DatosContexto, EstadoSalida};
use ed25519_zebra::{SigningKey, VerificationKey};
use zx_consensus::activacion::{RAMA_V1_MAINNET, Red};
use zx_consensus::validacion::EntradaUtxo;
use zx_core::amount::Amount;
use zx_core::digest::{BlockHash, Digest, TxId};
use zx_core::firma::ClavePublica;
use zx_core::preimage::block::{BlockHeader, merkle_root};
use zx_core::preimage::tx::{HashType, sighash, txid};
use zx_core::tx::{Lock, OutPoint, SpentOutput, Tx, TxIn, TxOut};

pub fn par(seed: u8) -> (SigningKey, ClavePublica) {
    let sk = SigningKey::from([seed; 32]);
    let pk = ClavePublica::desde_bytes(VerificationKey::from(&sk).into());
    (sk, pk)
}

pub fn outpoint() -> OutPoint {
    OutPoint {
        prev_txid: TxId::from_digest(Digest::from_bytes([3; 32])),
        prev_index: 0,
    }
}

pub fn datos(ancla: u8) -> DatosContexto {
    DatosContexto {
        dominio: [1; 32],
        ancla_causal: [ancla; 32],
        red: Red::Testnet,
        altura: 10,
        mediana_efectiva: 100_000,
        emitido: 0,
        completo: true,
    }
}

pub fn entrada(lock: Lock) -> EntradaUtxo {
    EntradaUtxo {
        salida: SpentOutput {
            value: Amount::nuevo(100).unwrap(),
            lock,
        },
        altura_creacion: 0,
        es_coinbase: false,
    }
}

pub fn contexto(ancla: u8) -> ContextoIdentificado {
    contexto_lock(ancla, Lock::PubKey { pubkey: par(7).1 })
}

pub fn contexto_lock(ancla: u8, lock: Lock) -> ContextoIdentificado {
    ContextoIdentificado::desde_snapshot_declarado(
        datos(ancla),
        vec![(outpoint(), EstadoSalida::Disponible(entrada(lock)))],
    )
    .unwrap()
}

pub fn cuerpo(lock: Lock) -> CuerpoCandidato {
    let tx = Tx {
        version: 1,
        inputs: vec![TxIn {
            outpoint: outpoint(),
            sequence: u32::MAX,
        }],
        outputs: vec![TxOut {
            value: Amount::nuevo(90).unwrap(),
            lock: lock.clone(),
        }],
        lock_time: 0,
        expiry_height: 0,
    };
    let coinbase = Tx {
        version: 1,
        inputs: vec![],
        outputs: vec![TxOut {
            value: Amount::CERO,
            lock,
        }],
        lock_time: 0,
        expiry_height: 10,
    };
    let txs = vec![coinbase, tx];
    let header = BlockHeader {
        consensus_branch_id: RAMA_V1_MAINNET.id,
        prev_hash: BlockHash::from_digest(Digest::from_bytes([2; 32])),
        merkle_root: merkle_root(
            &txs.iter()
                .map(|tx| txid(tx, RAMA_V1_MAINNET.id))
                .collect::<Vec<_>>(),
        ),
        timestamp: 10,
        bits: 0,
        nonce: 0,
        height: 10,
    };
    CuerpoCandidato {
        cabecera: header,
        txs,
        testigos: vec![vec![], vec![vec![]]],
        hash_type: HashType::All,
        orchard: None,
    }
}

pub fn firmar(b: &CuerpoCandidato, lock: Lock, seed: u8) -> Vec<u8> {
    let digest = sighash(
        &b.txs[1],
        &[entrada(lock).salida],
        HashType::All,
        0,
        b.cabecera.consensus_branch_id,
    )
    .unwrap();
    let firma: [u8; 64] = par(seed).0.sign(digest.as_bytes()).into();
    firma.to_vec()
}

pub fn fixture() -> (CuerpoCandidato, ContextoIdentificado) {
    let lock = Lock::PubKey { pubkey: par(7).1 };
    let mut b = cuerpo(lock.clone());
    b.testigos[1][0] = firmar(&b, lock, 7);
    (b, contexto(2))
}

/// Misma cabecera/efectos: dos conjuntos de autorización válidos, 1-de-2.
pub fn fixture_multisig() -> (CuerpoCandidato, CuerpoCandidato, ContextoIdentificado) {
    let lock = Lock::multisig(1, vec![par(7).1, par(8).1]).unwrap();
    let mut first = cuerpo(lock.clone());
    first.testigos[1][0] = vec![0];
    let signature = firmar(&first, lock.clone(), 7);
    first.testigos[1][0].extend(signature);
    let mut second = first.clone();
    second.testigos[1][0] = vec![1];
    let signature = firmar(&second, lock.clone(), 8);
    second.testigos[1][0].extend(signature);
    (first, second, contexto_lock(2, lock))
}

pub fn remerkle(b: &mut CuerpoCandidato) {
    b.cabecera.merkle_root = merkle_root(
        &b.txs
            .iter()
            .map(|tx| txid(tx, b.cabecera.consensus_branch_id))
            .collect::<Vec<_>>(),
    );
}
