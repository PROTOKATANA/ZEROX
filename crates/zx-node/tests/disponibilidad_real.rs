//! Caracterización de APIs reales, no activación del consenso PoST/DAG.
//! La cabecera existente se usa únicamente como contenedor de compromisos:
//! no se mina ni se llama a validar_cabecera, que todavía implementa PoW.

#![expect(
    clippy::unwrap_used,
    clippy::expect_used,
    reason = "instrumento de test: un fallo al construir o comprobar el fixture debe producir panic"
)]
#![expect(
    clippy::indexing_slicing,
    reason = "índices deliberados sobre fixtures de tamaño conocido y truncamientos bajo prueba"
)]

use std::sync::Arc;

use libp2p::identity::ed25519::{Keypair, SecretKey};
use primitive_types::U256;
use zx_consensus::activacion::Red;
use zx_consensus::bloque::{Bloque, ContextoBloque, validar_cuerpo};
use zx_consensus::error::ConsensusError;
use zx_consensus::testigo::{ContextoGasto, satisface};
use zx_consensus::validacion::{ConjuntoUtxo, EntradaUtxo, validar_tx};
use zx_core::amount::Amount;
use zx_core::digest::{BlockHash, Digest, MerkleRoot, SigHash, TxId};
use zx_core::firma::ClavePublica;
use zx_core::preimage::block::{BlockHeader, merkle_root};
use zx_core::preimage::tx::{HashType, auth_digest, sighash, txid};
use zx_core::tx::{Lock, OutPoint, SpentOutput, Tx, TxIn, TxOut};
use zx_node::cadena::{Cadena, RechazoCuerpo, comprobar_cuerpo};
use zx_p2p::mensaje::BloqueRed;
use zx_storage::{AlmacenCadena, AlmacenEnMemoria, ConjuntoEnMemoria};

struct Caso {
    bloque: BloqueRed,
    utxos: ConjuntoEnMemoria,
    salida: SpentOutput,
    firma_hash: SigHash,
    outpoint: OutPoint,
}

fn caso() -> Caso {
    // Clave fija de test, nunca fondos ni datos de producción.
    let mut secreto = [7u8; 32];
    let clave = Keypair::from(SecretKey::try_from_bytes(&mut secreto).unwrap());
    let lock = Lock::PubKey {
        pubkey: ClavePublica::desde_bytes(clave.public().to_bytes()),
    };
    let outpoint = OutPoint {
        prev_txid: TxId::from_digest(Digest::from_bytes([3; 32])),
        prev_index: 0,
    };
    let salida = SpentOutput {
        value: Amount::nuevo(100).unwrap(),
        lock: lock.clone(),
    };
    let tx = Tx {
        version: 1,
        inputs: vec![TxIn {
            outpoint,
            sequence: u32::MAX,
        }],
        outputs: vec![TxOut {
            value: Amount::nuevo(90).unwrap(),
            lock: lock.clone(),
        }],
        lock_time: 0,
        expiry_height: 0,
    };
    let firma_hash = sighash(&tx, std::slice::from_ref(&salida), HashType::All, 0, 0).unwrap();
    let testigo = clave.sign(firma_hash.as_bytes());
    let coinbase = Tx {
        version: 1,
        inputs: vec![],
        outputs: vec![TxOut {
            value: Amount::CERO,
            lock,
        }],
        lock_time: 0,
        expiry_height: 1,
    };
    let txs = vec![coinbase, tx];
    let ids: Vec<_> = txs.iter().map(|tx| txid(tx, 0)).collect();
    let bloque = BloqueRed {
        cabecera: BlockHeader {
            consensus_branch_id: 0,
            prev_hash: BlockHash::from_digest(Digest::from_bytes([0; 32])),
            merkle_root: merkle_root(&ids),
            timestamp: 1,
            bits: 0,
            nonce: 0,
            height: 1,
        },
        txs,
        testigos: vec![vec![], vec![testigo]],
    };
    let mut utxos = ConjuntoEnMemoria::nuevo();
    utxos
        .insertar(
            outpoint,
            EntradaUtxo {
                salida: salida.clone(),
                altura_creacion: 0,
                es_coinbase: false,
            },
        )
        .unwrap();
    Caso {
        bloque,
        utxos,
        salida,
        firma_hash,
        outpoint,
    }
}

fn comprobar_firma(c: &Caso, bloque: &BloqueRed) -> Result<(), ConsensusError> {
    satisface(
        &c.salida.lock,
        &bloque.testigos[1][0],
        &c.firma_hash,
        ContextoGasto { altura: 1 },
    )
}

fn contexto() -> ContextoBloque {
    ContextoBloque {
        red: Red::Testnet,
        target_esperado: U256::zero(),
        mediana_efectiva: 100_000,
        emitido: 0,
        ts_padre: 0,
        reloj_local: 1,
    }
}

// Composición explícita limitada a nuestro fixture transparente P2K/HashType::All.
// No es una API de producción ni un certificado de validez PoST/DAG o DA global.
fn autorizar_fixture_p2k(b: &BloqueRed, utxos: &ConjuntoEnMemoria) -> Result<(), ConsensusError> {
    validar_cuerpo(
        &Bloque {
            cabecera: b.cabecera,
            txs: &b.txs,
            testigos: &b.testigos,
        },
        &contexto(),
        utxos,
    )?;
    for (tx, testigos) in b.txs.iter().zip(&b.testigos).skip(1) {
        let gastadas: Vec<_> = tx
            .inputs
            .iter()
            .map(|entrada| {
                utxos
                    .buscar(&entrada.outpoint)
                    .map(|e| e.salida)
                    .ok_or(ConsensusError::EntradaInexistenteOGastada)
            })
            .collect::<Result<_, _>>()?;
        for (k, (salida, testigo)) in gastadas.iter().zip(testigos).enumerate() {
            assert!(matches!(salida.lock, Lock::PubKey { .. }));
            let digest = sighash(
                tx,
                &gastadas,
                HashType::All,
                k,
                b.cabecera.consensus_branch_id,
            )
            .expect("fixture P2K con índices y salidas completas");
            satisface(
                &salida.lock,
                testigo,
                &digest,
                ContextoGasto {
                    altura: b.cabecera.height,
                },
            )?;
        }
    }
    Ok(())
}

#[test]
fn composicion_explicita_del_fixture_rechaza_firma_mala_con_el_mismo_pasado() {
    let c = caso();
    autorizar_fixture_p2k(&c.bloque, &c.utxos).unwrap();
    let mut mala = c.bloque.clone();
    mala.testigos[1][0] = vec![0xff; 64];
    assert!(matches!(
        autorizar_fixture_p2k(&mala, &c.utxos),
        Err(ConsensusError::CondicionNoSatisfecha { .. })
    ));
    assert_eq!(mala.cabecera, c.bloque.cabecera);
}

#[test]
fn ausencia_y_corrupcion_son_distintas_abajo_pero_bloque_devuelve_none_en_ambas() {
    let c = caso();
    let almacen = Arc::new(AlmacenEnMemoria::nuevo());
    let cadena = Cadena::con_almacen(Red::Testnet, almacen.clone()).unwrap();
    let hash = c.bloque.cabecera.block_hash();
    assert_eq!(almacen.cuerpo(&hash).unwrap(), None);
    assert!(!almacen.tiene_cuerpo(&hash).unwrap());
    assert!(cadena.bloque(hash).is_none());
    almacen.guardar_cuerpo(&hash, &[0xff]).unwrap();
    assert_eq!(almacen.cuerpo(&hash).unwrap(), Some(vec![0xff]));
    assert!(zx_core::wire::cuerpo_desde_bytes(&[0xff]).is_err());
    assert!(almacen.tiene_cuerpo(&hash).unwrap());
    assert!(cadena.bloque(hash).is_none());
}

#[test]
fn wire_completo_y_truncado_no_equivalen_a_compromiso_correcto() {
    let c = caso();
    let mut bytes = Vec::new();
    zx_core::wire::cuerpo_a_bytes(
        &mut bytes,
        &c.bloque.cabecera,
        &c.bloque.txs,
        &c.bloque.testigos,
    );
    let ((cabecera, txs, testigos), resto) = zx_core::wire::cuerpo_desde_bytes(&bytes).unwrap();
    assert!(resto.is_empty());
    assert_eq!(
        BloqueRed {
            cabecera,
            txs,
            testigos
        },
        c.bloque
    );
    assert!(zx_core::wire::cuerpo_desde_bytes(&bytes[..bytes.len() - 1]).is_err());
    let mut raiz_incorrecta = c.bloque.clone();
    raiz_incorrecta.cabecera.merkle_root = MerkleRoot::from_digest(Digest::from_bytes([0x55; 32]));
    assert!(matches!(
        comprobar_cuerpo(&raiz_incorrecta),
        Err(RechazoCuerpo::RaizNoCoincide)
    ));
}

#[test]
fn mismo_compromiso_y_auth_distinto_admiten_reparacion_criptografica_real() {
    let c = caso();
    let mut mala = c.bloque.clone();
    mala.testigos[1][0] = vec![0xff; 64];
    assert_ne!(
        auth_digest(&c.bloque.testigos[1]),
        auth_digest(&mala.testigos[1])
    );
    assert_eq!(c.bloque.txs, mala.txs);
    assert_eq!(c.bloque.cabecera, mala.cabecera);
    assert_eq!(c.bloque.cabecera.block_hash(), mala.cabecera.block_hash());
    assert_eq!(txid(&c.bloque.txs[1], 0), txid(&mala.txs[1], 0));
    comprobar_cuerpo(&c.bloque).unwrap();
    comprobar_cuerpo(&mala).unwrap();
    comprobar_firma(&c, &c.bloque).unwrap();
    assert!(matches!(
        comprobar_firma(&c, &mala),
        Err(ConsensusError::CondicionNoSatisfecha { .. })
    ));
    // Las dos APIs estructurales actuales NO integran satisface: caracterizar
    // este hueco no convierte la entrega mala en un bloque autorizado.
    validar_tx(&mala.txs[1], &mala.testigos[1], &c.utxos, 1).unwrap();
    let b = Bloque {
        cabecera: mala.cabecera,
        txs: &mala.txs,
        testigos: &mala.testigos,
    };
    validar_cuerpo(&b, &contexto(), &c.utxos).unwrap();
}

#[test]
fn almacen_actual_por_blockhash_permite_reparar_y_degradar_la_autorizacion() {
    let c = caso();
    let mut mala = c.bloque.clone();
    mala.testigos[1][0] = vec![0xff; 64];
    let almacen = Arc::new(AlmacenEnMemoria::nuevo());
    let cadena = Cadena::con_almacen(Red::Testnet, almacen).unwrap();
    let hash = c.bloque.cabecera.block_hash();
    cadena.guardar_bloque(&mala).unwrap();
    assert!(comprobar_firma(&c, &cadena.bloque(hash).unwrap()).is_err());
    cadena.guardar_bloque(&c.bloque).unwrap();
    comprobar_firma(&c, &cadena.bloque(hash).unwrap()).unwrap();
    cadena.guardar_bloque(&mala).unwrap();
    assert!(comprobar_firma(&c, &cadena.bloque(hash).unwrap()).is_err());
    // No se adopta la cabecera ni se activa una rama como efecto del guardado.
    assert_eq!(cadena.altura(), 0);
}

#[test]
fn entrega_con_efectos_ajenos_es_rechazada_sin_reemplazar_cuerpo_guardado() {
    let c = caso();
    let almacen = Arc::new(AlmacenEnMemoria::nuevo());
    let cadena = Cadena::con_almacen(Red::Testnet, almacen).unwrap();
    let hash = c.bloque.cabecera.block_hash();
    cadena.guardar_bloque(&c.bloque).unwrap();
    let mut ajena = c.bloque.clone();
    ajena.txs[1].outputs[0].value = Amount::nuevo(89).unwrap();
    assert!(matches!(
        comprobar_cuerpo(&ajena),
        Err(RechazoCuerpo::RaizNoCoincide)
    ));
    assert!(cadena.guardar_bloque(&ajena).is_err());
    assert_eq!(cadena.bloque(hash), Some(c.bloque));
}

#[test]
fn conflicto_es_contextual_y_ausencia_utxo_no_prueba_por_si_sola_doble_gasto() {
    let c = caso();
    validar_tx(&c.bloque.txs[1], &c.bloque.testigos[1], &c.utxos, 1).unwrap();
    comprobar_firma(&c, &c.bloque).unwrap();
    let mut gastado = c.utxos.clone();
    gastado.retirar(&c.outpoint).unwrap();
    let desconocido = ConjuntoEnMemoria::nuevo();
    for vista in [&gastado, &desconocido] {
        assert!(matches!(
            validar_tx(&c.bloque.txs[1], &c.bloque.testigos[1], vista, 1),
            Err(ConsensusError::EntradaInexistenteOGastada)
        ));
    }
    comprobar_firma(&c, &c.bloque).unwrap();
}

#[test]
fn testigo_interno_malformado_no_es_desalineacion_exterior_ni_merkle_incorrecto() {
    let c = caso();
    let mut truncado = c.bloque.clone();
    truncado.testigos[1][0].truncate(63);
    comprobar_cuerpo(&truncado).unwrap();
    assert!(matches!(
        comprobar_firma(&c, &truncado),
        Err(ConsensusError::TestigoMalFormado { .. })
    ));
    let mut desalineado = c.bloque.clone();
    desalineado.testigos.pop();
    assert!(matches!(
        comprobar_cuerpo(&desalineado),
        Err(RechazoCuerpo::TestigosDescuadrados { .. })
    ));
}

#[test]
fn conflicto_entre_contextos_no_equivale_a_doble_gasto_dentro_del_cuerpo() {
    let c = caso();
    // Por separado es una transacción firmada y gastable en este pasado.
    validar_tx(&c.bloque.txs[1], &c.bloque.testigos[1], &c.utxos, 1).unwrap();
    comprobar_firma(&c, &c.bloque).unwrap();
    let mut duplicada = c.bloque.clone();
    duplicada.txs.push(c.bloque.txs[1].clone());
    duplicada.testigos.push(c.bloque.testigos[1].clone());
    let ids: Vec<_> = duplicada.txs.iter().map(|tx| txid(tx, 0)).collect();
    duplicada.cabecera.merkle_root = merkle_root(&ids);
    comprobar_cuerpo(&duplicada).unwrap();
    let bloque = Bloque {
        cabecera: duplicada.cabecera,
        txs: &duplicada.txs,
        testigos: &duplicada.testigos,
    };
    // El validador real no omite la transacción repetida como M0: C-BLK-09.
    assert!(matches!(
        validar_cuerpo(&bloque, &contexto(), &c.utxos),
        Err(ConsensusError::DobleGastoEnBloque)
    ));
}
