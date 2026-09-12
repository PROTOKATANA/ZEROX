mod soporte;

use autorizacion_contextual::almacen::{AlmacenEvidencias, ClaveEvidencia, LimitesLocales};
use autorizacion_contextual::autorizar_cuerpo;
use autorizacion_contextual::compromiso::*;
use soporte::{fixture, fixture_multisig, remerkle};
use zx_core::preimage::tx::auth_digest;

#[test]
fn incluye_coinbase_y_auth_vacia_sin_omitirla() {
    let (b, _) = fixture();
    let compromiso = CompromisoCuerpoDeclarado::del_cuerpo(&b).unwrap();
    assert_eq!(compromiso.cantidad(), b.txs.len());
    assert_eq!(compromiso.pares()[0].1, auth_digest(&[]));
}

#[test]
fn autorizaciones_validas_distintas_comparten_header_actual_no_compromiso_candidato() {
    let (a, b, _) = fixture_multisig();
    assert_eq!(a.block_hash(), b.block_hash());
    assert_ne!(
        CompromisoCuerpoDeclarado::del_cuerpo(&a).unwrap(),
        CompromisoCuerpoDeclarado::del_cuerpo(&b).unwrap()
    );
}

#[test]
fn no_se_incluye_headerhash_y_se_preservan_orden_y_multiplicidad() {
    let (mut b, _) = fixture();
    let original = CompromisoCuerpoDeclarado::del_cuerpo(&b).unwrap();
    b.cabecera.nonce = 1;
    assert_eq!(CompromisoCuerpoDeclarado::del_cuerpo(&b).unwrap(), original);
    b.txs.reverse();
    b.testigos.reverse();
    remerkle(&mut b);
    assert_ne!(CompromisoCuerpoDeclarado::del_cuerpo(&b).unwrap(), original);
    b.txs.reverse();
    b.testigos.reverse();
    b.txs.push(b.txs[1].clone());
    b.testigos.push(b.testigos[1].clone());
    remerkle(&mut b);
    let repetido = CompromisoCuerpoDeclarado::del_cuerpo(&b).unwrap();
    assert_eq!(repetido.cantidad(), original.cantidad() + 1);
    assert_eq!(repetido.pares()[1], repetido.pares()[2]);
    // Comprometer repeticiones NO significa admitir el doble gasto de ese cuerpo.
}

#[test]
fn no_se_rellenan_testigos_ausentes_ni_se_ignoran_sobrantes() {
    let (mut b, _) = fixture();
    b.testigos.pop();
    assert_eq!(
        CompromisoCuerpoDeclarado::del_cuerpo(&b),
        Err(ErrorCompromiso::ListasDesalineadas)
    );
    let (mut b, _) = fixture();
    b.testigos.push(vec![]);
    assert_eq!(
        CompromisoCuerpoDeclarado::del_cuerpo(&b),
        Err(ErrorCompromiso::ListasDesalineadas)
    );
}

#[test]
fn no_admite_merkle_contradictoria_ni_finge_comprometer_orchard() {
    let (mut b, _) = fixture();
    b.txs[1].expiry_height = 11;
    assert_eq!(
        CompromisoCuerpoDeclarado::del_cuerpo(&b),
        Err(ErrorCompromiso::MerkleIncoherente)
    );
    let (mut b, _) = fixture();
    b.orchard = Some(vec![]);
    assert_eq!(
        CompromisoCuerpoDeclarado::del_cuerpo(&b),
        Err(ErrorCompromiso::OrchardNoSoportado)
    );
}

#[test]
fn compromiso_esperado_rechaza_otra_variante_valida_sin_seleccionar_por_llegada() {
    let (a, b, ctx) = fixture_multisig();
    let esperado = CompromisoCuerpoDeclarado::del_cuerpo(&a).unwrap();
    assert!(autorizar_cuerpo(&b, &ctx).is_ok());
    assert!(matches!(
        autorizar_con_compromiso(&b, &ctx, &esperado),
        Err(ErrorVinculacion::EntregaDistinta)
    ));
    let evidencia = autorizar_con_compromiso(&a, &ctx, &esperado).unwrap();
    let clave = ClaveEvidencia::de(&evidencia);
    let mut almacen = AlmacenEvidencias::nuevo(
        LimitesLocales {
            entradas: 1,
            peso_retenido: 1_000_000,
        },
        ctx.context_key(),
    )
    .unwrap();
    almacen.retener(evidencia).unwrap();
    let vista = almacen.hacer_visible(clave, almacen.vista()).unwrap();
    assert_eq!(almacen.leer_visible(clave, vista).unwrap().cuerpo(), &a);
    assert!(matches!(
        autorizar_con_compromiso(&b, &ctx, &esperado),
        Err(ErrorVinculacion::EntregaDistinta)
    ));
    assert_eq!(almacen.leer_visible(clave, vista).unwrap().cuerpo(), &a);
}

#[test]
fn compromiso_correcto_no_hace_valida_una_firma_mala() {
    let (mut b, ctx) = fixture();
    b.testigos[1][0][0] ^= 1;
    let compromiso = CompromisoCuerpoDeclarado::del_cuerpo(&b).unwrap();
    assert!(matches!(
        autorizar_con_compromiso(&b, &ctx, &compromiso),
        Err(ErrorVinculacion::Autorizacion(_))
    ));
}
