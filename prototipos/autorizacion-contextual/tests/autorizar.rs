mod soporte;

use autorizacion_contextual::{ContextoIdentificado, EstadoSalida, Rechazo, autorizar_cuerpo};
use soporte::*;
use zx_consensus::emision::COINBASE_MATURITY;
use zx_consensus::error::ConsensusError;
use zx_core::amount::Amount;
use zx_core::digest::{Digest, TxId};
use zx_core::preimage::tx::{HashType, auth_digest, sighash, txid};
use zx_core::tx::{Lock, OutPoint, TxIn};

#[test]
fn evidencia_p2k_real_y_no_reutilizable_con_otra_autorizacion() {
    let (b, ctx) = fixture();
    let ok = autorizar_cuerpo(&b, &ctx).unwrap();
    assert_eq!(ok.cuerpo(), &b);
    assert_eq!(ok.context_key(), ctx.context_key());
    assert_eq!(ok.body_key(), b.body_key());
    assert_eq!(ok.resultado().fees, 10);
    let mut mala = b.clone();
    mala.testigos[1][0][0] ^= 1;
    assert_eq!(mala.block_hash(), b.block_hash());
    assert_eq!(
        txid(&mala.txs[1], b.cabecera.consensus_branch_id),
        txid(&b.txs[1], b.cabecera.consensus_branch_id)
    );
    assert_ne!(auth_digest(&mala.testigos[1]), auth_digest(&b.testigos[1]));
    assert_ne!(mala.body_key(), ok.body_key());
    assert!(matches!(
        autorizar_cuerpo(&mala, &ctx),
        Err(Rechazo::Invalido(
            ConsensusError::CondicionNoSatisfecha { .. }
        ))
    ));
    assert_eq!(
        ok.cuerpo(),
        &b,
        "editar candidato no altera evidencia owned"
    );
}

#[test]
fn dos_autorizaciones_multisig_validas_misma_cabecera() {
    let (a, b, ctx) = fixture_multisig();
    let ea = autorizar_cuerpo(&a, &ctx).unwrap();
    let eb = autorizar_cuerpo(&b, &ctx).unwrap();
    assert_eq!(ea.block_hash(), eb.block_hash());
    assert_ne!(ea.body_key(), eb.body_key());
    let mut repetida = a;
    repetida.testigos[1][0].extend_from_within(..);
    assert!(matches!(
        autorizar_cuerpo(&repetida, &ctx),
        Err(Rechazo::Invalido(ConsensusError::TestigoMalFormado { .. }))
    ));
}

#[test]
fn htlc_preimagen_y_timeout_se_componen_con_contexto_real() {
    let lock = Lock::Htlc {
        hash: *zx_core::sha3_256_publico(b"secreto").as_bytes(),
        receiver: par(7).1,
        sender: par(8).1,
        timeout: 10,
    };
    let ctx = contexto_lock(2, lock.clone());
    let mut b = cuerpo(lock.clone());
    b.testigos[1][0] = vec![0, 7];
    b.testigos[1][0].extend(b"secreto");
    let signature = firmar(&b, lock.clone(), 7);
    b.testigos[1][0].extend(signature);
    autorizar_cuerpo(&b, &ctx).unwrap();
    b.testigos[1][0][2] ^= 1;
    assert!(matches!(
        autorizar_cuerpo(&b, &ctx),
        Err(Rechazo::Invalido(
            ConsensusError::CondicionNoSatisfecha { .. }
        ))
    ));
    b.testigos[1][0] = vec![1];
    let signature = firmar(&b, lock.clone(), 8);
    b.testigos[1][0].extend(signature);
    autorizar_cuerpo(&b, &ctx).unwrap();
    let mut antes = datos(2);
    antes.altura = 9;
    let ctx_antes = ContextoIdentificado::desde_snapshot_declarado(
        antes,
        vec![(outpoint(), EstadoSalida::Disponible(entrada(lock)))],
    )
    .unwrap();
    b.cabecera.height = 9;
    b.txs[0].expiry_height = 9;
    remerkle(&mut b);
    assert!(matches!(
        autorizar_cuerpo(&b, &ctx_antes),
        Err(Rechazo::Invalido(
            ConsensusError::CondicionNoSatisfecha { .. }
        ))
    ));
}

#[test]
fn no_confunde_ausencia_desconocida_gastada_e_inexistente() {
    let (b, _) = fixture();
    for entradas in [vec![], vec![(outpoint(), EstadoSalida::Desconocido)]] {
        let ctx = ContextoIdentificado::desde_snapshot_declarado(datos(2), entradas).unwrap();
        assert_eq!(
            autorizar_cuerpo(&b, &ctx).unwrap_err(),
            Rechazo::Dependencias(vec![outpoint()])
        );
    }
    let ctx = ContextoIdentificado::desde_snapshot_declarado(
        datos(2),
        vec![(outpoint(), EstadoSalida::Gastado)],
    )
    .unwrap();
    assert_eq!(
        autorizar_cuerpo(&b, &ctx).unwrap_err(),
        Rechazo::GastadoEnSnapshot(vec![outpoint()])
    );
    let ctx = ContextoIdentificado::desde_snapshot_declarado(
        datos(2),
        vec![(outpoint(), EstadoSalida::Inexistente)],
    )
    .unwrap();
    assert_eq!(
        autorizar_cuerpo(&b, &ctx).unwrap_err(),
        Rechazo::Invalido(ConsensusError::EntradaInexistenteOGastada)
    );
    let mut incompleto = datos(2);
    incompleto.completo = false;
    let ctx = ContextoIdentificado::desde_snapshot_declarado(incompleto, vec![]).unwrap();
    assert_eq!(
        autorizar_cuerpo(&b, &ctx).unwrap_err(),
        Rechazo::ContextoIncompleto
    );
}

#[test]
fn contexto_con_todos_los_campos_vinculados_y_orden_independiente() {
    let (b, ctx) = fixture();
    let baseline = autorizar_cuerpo(&b, &ctx).unwrap();
    let mut variantes = Vec::new();
    let mut d = datos(2);
    d.dominio[0] ^= 1;
    variantes.push(d);
    let mut d = datos(2);
    d.ancla_causal[0] ^= 1;
    variantes.push(d);
    let mut d = datos(2);
    d.emitido = 1;
    variantes.push(d);
    let mut d = datos(2);
    d.mediana_efectiva += 1;
    variantes.push(d);
    let mut d = datos(2);
    d.red = zx_core::red::Red::Mainnet;
    variantes.push(d);
    let mut d = datos(2);
    d.completo = false;
    variantes.push(d);
    let mut d = datos(2);
    d.altura += 1;
    variantes.push(d);
    for datos in variantes {
        let otro =
            ContextoIdentificado::desde_snapshot_declarado(datos, ctx.salidas().to_vec()).unwrap();
        assert_ne!(otro.context_key(), baseline.context_key());
    }
    let adicional = (
        OutPoint {
            prev_txid: TxId::from_digest(Digest::from_bytes([9; 32])),
            prev_index: 10,
        },
        EstadoSalida::Gastado,
    );
    let mut entradas = ctx.salidas().to_vec();
    entradas.push(adicional);
    let otro = ContextoIdentificado::desde_snapshot_declarado(datos(2), entradas.clone()).unwrap();
    entradas.reverse();
    let permutado = ContextoIdentificado::desde_snapshot_declarado(datos(2), entradas).unwrap();
    assert_eq!(otro.context_key(), permutado.context_key());
    assert_ne!(otro.context_key(), ctx.context_key());
}

#[test]
fn rechaza_perfiles_no_soportados_sin_fallback() {
    let (base, ctx) = fixture();
    for ht in [
        HashType::None,
        HashType::Single,
        HashType::AllAnyoneCanPay,
        HashType::NoneAnyoneCanPay,
        HashType::SingleAnyoneCanPay,
    ] {
        let mut b = base.clone();
        b.hash_type = ht;
        assert!(matches!(
            autorizar_cuerpo(&b, &ctx),
            Err(Rechazo::NoSoportado(_))
        ));
    }
    let mut b = base.clone();
    b.orchard = Some(vec![]);
    assert!(matches!(
        autorizar_cuerpo(&b, &ctx),
        Err(Rechazo::NoSoportado(_))
    ));
    let mut b = base.clone();
    b.txs[1].lock_time = 1;
    assert!(matches!(
        autorizar_cuerpo(&b, &ctx),
        Err(Rechazo::NoSoportado(_))
    ));
    let mut b = base;
    b.txs[1].inputs[0].outpoint.prev_txid = txid(&b.txs[0], b.cabecera.consensus_branch_id);
    remerkle(&mut b);
    assert!(matches!(
        autorizar_cuerpo(&b, &ctx),
        Err(Rechazo::NoSoportado(_))
    ));
}

#[test]
fn fronteras_coinbase_y_multisig_no_bypassean_validacion() {
    let (base, ctx) = fixture();
    let mut b = base.clone();
    b.txs[0].version = 2;
    assert!(matches!(
        autorizar_cuerpo(&b, &ctx),
        Err(Rechazo::Invalido(
            ConsensusError::VersionDeTxNoAdmitida { .. }
        ))
    ));
    let mut b = base.clone();
    b.testigos[0].push(vec![]);
    assert!(matches!(
        autorizar_cuerpo(&b, &ctx),
        Err(Rechazo::Invalido(ConsensusError::TestigoMalFormado { .. }))
    ));
    let mut b = base.clone();
    b.txs[0].outputs.clear();
    assert!(matches!(
        autorizar_cuerpo(&b, &ctx),
        Err(Rechazo::NoSoportado(_))
    ));
    for index in [0, 1] {
        let mut b = base.clone();
        b.txs[index].outputs[0].lock = Lock::MultiSig {
            k: 0,
            pubkeys: vec![par(7).1],
        };
        assert!(matches!(
            autorizar_cuerpo(&b, &ctx),
            Err(Rechazo::Codificacion(_))
        ));
    }
    let mut b = base;
    b.txs[0].outputs = vec![b.txs[0].outputs[0].clone(); 2500];
    assert!(matches!(
        autorizar_cuerpo(&b, &ctx),
        Err(Rechazo::Invalido(ConsensusError::TxExcedeMaximo { .. }))
    ));
}

#[test]
fn snapshot_incoherente_y_locks_manuales_se_rechazan() {
    let lock = Lock::MultiSig {
        k: 0,
        pubkeys: vec![par(7).1],
    };
    assert!(matches!(
        ContextoIdentificado::desde_snapshot_declarado(
            datos(2),
            vec![(outpoint(), EstadoSalida::Disponible(entrada(lock)))]
        ),
        Err(Rechazo::Codificacion(_))
    ));
    let salida = entrada(Lock::PubKey { pubkey: par(7).1 });
    assert!(matches!(
        ContextoIdentificado::desde_snapshot_declarado(
            datos(2),
            vec![
                (outpoint(), EstadoSalida::Disponible(salida.clone())),
                (outpoint(), EstadoSalida::Gastado)
            ]
        ),
        Err(Rechazo::ContextoInvalido(_))
    ));
    let mut futura = salida;
    futura.altura_creacion = 11;
    assert!(matches!(
        ContextoIdentificado::desde_snapshot_declarado(
            datos(2),
            vec![(outpoint(), EstadoSalida::Disponible(futura))]
        ),
        Err(Rechazo::ContextoInvalido(_))
    ));
}

#[test]
fn madurez_expiracion_y_balance_se_delegan_al_validador_nativo() {
    let (mut b, ctx) = fixture();
    let mut salida = entrada(Lock::PubKey { pubkey: par(7).1 });
    salida.es_coinbase = true;
    let inmaduro = ContextoIdentificado::desde_snapshot_declarado(
        datos(2),
        vec![(outpoint(), EstadoSalida::Disponible(salida.clone()))],
    )
    .unwrap();
    assert!(matches!(
        autorizar_cuerpo(&b, &inmaduro),
        Err(Rechazo::Invalido(ConsensusError::CoinbaseInmaduro { .. }))
    ));
    let mut d = datos(2);
    d.altura = COINBASE_MATURITY;
    let maduro = ContextoIdentificado::desde_snapshot_declarado(
        d,
        vec![(outpoint(), EstadoSalida::Disponible(salida))],
    )
    .unwrap();
    b.cabecera.height = COINBASE_MATURITY;
    b.txs[0].expiry_height = COINBASE_MATURITY;
    remerkle(&mut b);
    autorizar_cuerpo(&b, &maduro).unwrap();
    let (mut b, _) = fixture();
    b.txs[1].expiry_height = 9;
    remerkle(&mut b);
    assert!(matches!(
        autorizar_cuerpo(&b, &ctx),
        Err(Rechazo::Invalido(ConsensusError::TxExpirada { .. }))
    ));
    let (mut b, _) = fixture();
    b.txs[1].outputs[0].value = Amount::nuevo(101).unwrap();
    remerkle(&mut b);
    assert!(matches!(
        autorizar_cuerpo(&b, &ctx),
        Err(Rechazo::Invalido(ConsensusError::SalidasExcedenEntradas))
    ));
}

#[test]
fn dos_inputs_usan_importes_locks_y_orden_del_sighash_correctos() {
    let (mut b, _) = fixture();
    let segundo = OutPoint {
        prev_txid: TxId::from_digest(Digest::from_bytes([1; 32])),
        prev_index: 2,
    };
    b.txs[1].inputs.push(TxIn {
        outpoint: segundo,
        sequence: 7,
    });
    let e0 = entrada(Lock::PubKey { pubkey: par(7).1 });
    let e1 = entrada(Lock::PubKey { pubkey: par(8).1 });
    b.testigos[1].clear();
    for (i, seed) in [(0, 7), (1, 8)] {
        let sh = sighash(
            &b.txs[1],
            &[e0.salida.clone(), e1.salida.clone()],
            HashType::All,
            i,
            b.cabecera.consensus_branch_id,
        )
        .unwrap();
        let signature: [u8; 64] = par(seed).0.sign(sh.as_bytes()).into();
        b.testigos[1].push(signature.to_vec());
    }
    remerkle(&mut b);
    let ctx = ContextoIdentificado::desde_snapshot_declarado(
        datos(2),
        vec![
            (outpoint(), EstadoSalida::Disponible(e0.clone())),
            (segundo, EstadoSalida::Disponible(e1.clone())),
        ],
    )
    .unwrap();
    autorizar_cuerpo(&b, &ctx).unwrap();
    let mut alterada = e1;
    alterada.salida.value = Amount::nuevo(99).unwrap();
    let otro = ContextoIdentificado::desde_snapshot_declarado(
        datos(2),
        vec![
            (outpoint(), EstadoSalida::Disponible(e0)),
            (segundo, EstadoSalida::Disponible(alterada)),
        ],
    )
    .unwrap();
    assert!(matches!(
        autorizar_cuerpo(&b, &otro),
        Err(Rechazo::Invalido(
            ConsensusError::CondicionNoSatisfecha { .. }
        ))
    ));
}

#[test]
fn doble_gasto_no_se_omite_como_conflicto_de_modelo_abstracto() {
    let (mut b, ctx) = fixture();
    b.txs.push(b.txs[1].clone());
    b.testigos.push(b.testigos[1].clone());
    remerkle(&mut b);
    assert_eq!(
        autorizar_cuerpo(&b, &ctx).unwrap_err(),
        Rechazo::Invalido(ConsensusError::DobleGastoEnBloque)
    );
}

#[test]
fn clave_local_compromete_testigos_sobrantes_aunque_encoder_los_omite() {
    let (a, ctx) = fixture();
    let mut b = a.clone();
    b.testigos.push(vec![vec![1]]);
    assert_ne!(a.body_key(), b.body_key());
    assert!(matches!(
        autorizar_cuerpo(&b, &ctx),
        Err(Rechazo::Invalido(ConsensusError::TestigoMalFormado { .. }))
    ));
}
