//! Composición real de firmas + caché local. No usa cabeceras PoST ni publica ledger.

mod soporte;

use autorizacion_contextual::almacen::*;
use autorizacion_contextual::autorizar_cuerpo;
use soporte::{contexto, fixture, fixture_multisig};

fn cache(contexto: [u8; 32], entradas: usize) -> AlmacenEvidencias {
    AlmacenEvidencias::nuevo(
        LimitesLocales {
            entradas,
            peso_retenido: 1_000_000,
        },
        contexto,
    )
    .unwrap()
}

#[test]
fn entrega_mala_no_bloquea_reparacion_ni_degrada_evidencia_buena() {
    let (bueno, ctx) = fixture();
    let mut malo = bueno.clone();
    malo.testigos[1][0][0] ^= 1;
    assert_eq!(malo.block_hash(), bueno.block_hash());
    let mut almacen = cache(ctx.context_key(), 2);
    assert!(autorizar_cuerpo(&malo, &ctx).is_err());
    assert_eq!(almacen.cantidad(), 0);

    let evidencia = autorizar_cuerpo(&bueno, &ctx).unwrap();
    let clave = ClaveEvidencia::de(&evidencia);
    assert_eq!(almacen.retener(evidencia), Ok(Retencion::Nueva));
    let visible = almacen.hacer_visible(clave, almacen.vista()).unwrap();
    assert!(autorizar_cuerpo(&malo, &ctx).is_err());
    assert_eq!(almacen.vista(), visible);
    assert_eq!(
        almacen.leer_visible(clave, visible).unwrap().cuerpo(),
        &bueno
    );
    assert_eq!(almacen.cantidad(), 1);
}

#[test]
fn duplicado_exacto_no_duplica_almacenamiento_ni_cambia_la_vista() {
    let (b, ctx) = fixture();
    let evidencia = autorizar_cuerpo(&b, &ctx).unwrap();
    let mut almacen = cache(ctx.context_key(), 1);
    let peso = evidencia.resultado().peso;
    almacen.retener(evidencia.clone()).unwrap();
    let vista = almacen.vista();
    assert_eq!(almacen.retener(evidencia), Ok(Retencion::YaRetenida));
    assert_eq!(almacen.peso_retenido(), peso);
    assert_eq!(almacen.cantidad(), 1);
    assert_eq!(almacen.vista(), vista);
}

#[test]
fn dos_autorizaciones_validas_misma_cabecera_no_eligen_ganador_por_llegada() {
    let (a, b, ctx) = fixture_multisig();
    let ea = autorizar_cuerpo(&a, &ctx).unwrap();
    let eb = autorizar_cuerpo(&b, &ctx).unwrap();
    assert_eq!(ea.block_hash(), eb.block_hash());
    assert_eq!(a.txs, b.txs);
    assert_ne!(a.testigos, b.testigos);
    let ka = ClaveEvidencia::de(&ea);
    let kb = ClaveEvidencia::de(&eb);
    assert_ne!(ka, kb);
    for orden in [[ea.clone(), eb.clone()], [eb.clone(), ea.clone()]] {
        let mut almacen = cache(ctx.context_key(), 2);
        for evidencia in orden {
            almacen.retener(evidencia).unwrap();
        }
        assert_eq!(almacen.consultar(ka).unwrap().cuerpo(), &a);
        assert_eq!(almacen.consultar(kb).unwrap().cuerpo(), &b);
        // Selección exacta suministrada por el consumidor, NO fork choice del test.
        let vista = almacen.hacer_visible(kb, almacen.vista()).unwrap();
        assert_eq!(almacen.leer_visible(kb, vista).unwrap().cuerpo(), &b);
        assert!(matches!(
            almacen.leer_visible(ka, vista),
            Err(ErrorAlmacen::EvidenciaNoVisible)
        ));
    }
}

#[test]
fn capacidad_agotada_no_expulsa_la_evidencia_visible_ni_invalida_la_variante() {
    let (a, b, ctx) = fixture_multisig();
    let ea = autorizar_cuerpo(&a, &ctx).unwrap();
    let eb = autorizar_cuerpo(&b, &ctx).unwrap();
    let ka = ClaveEvidencia::de(&ea);
    let kb = ClaveEvidencia::de(&eb);
    let mut almacen = cache(ctx.context_key(), 1);
    almacen.retener(ea).unwrap();
    let vista = almacen.hacer_visible(ka, almacen.vista()).unwrap();
    let peso = almacen.peso_retenido();
    assert_eq!(almacen.retener(eb), Err(ErrorAlmacen::CapacidadAgotada));
    assert_eq!(almacen.cantidad(), 1);
    assert_eq!(almacen.peso_retenido(), peso);
    assert_eq!(almacen.vista(), vista);
    assert!(almacen.consultar(kb).is_none());
    assert_eq!(almacen.leer_visible(ka, vista).unwrap().cuerpo(), &a);
    assert!(autorizar_cuerpo(&b, &ctx).is_ok());
}

#[test]
fn limite_local_de_peso_no_es_regla_de_invalidez() {
    let (b, ctx) = fixture();
    let evidencia = autorizar_cuerpo(&b, &ctx).unwrap();
    let mut almacen = AlmacenEvidencias::nuevo(
        LimitesLocales {
            entradas: 1,
            peso_retenido: 0,
        },
        ctx.context_key(),
    )
    .unwrap();
    let antes = almacen.vista();
    assert_eq!(
        almacen.retener(evidencia),
        Err(ErrorAlmacen::PresupuestoDePeso)
    );
    assert_eq!(almacen.cantidad(), 0);
    assert_eq!(almacen.peso_retenido(), 0);
    assert_eq!(almacen.vista(), antes);
    assert!(autorizar_cuerpo(&b, &ctx).is_ok());
}

#[test]
fn cambiar_rama_no_traslada_evidencia_y_no_borra_su_contexto_original() {
    let (b, c1) = fixture();
    let c2 = contexto(9);
    let e1 = autorizar_cuerpo(&b, &c1).unwrap();
    let e2 = autorizar_cuerpo(&b, &c2).unwrap();
    let k1 = ClaveEvidencia::de(&e1);
    let k2 = ClaveEvidencia::de(&e2);
    assert_eq!(k1.cuerpo, k2.cuerpo);
    assert_ne!(k1.contexto, k2.contexto);
    let mut almacen = cache(c1.context_key(), 2);
    almacen.retener(e1).unwrap();
    almacen.retener(e2).unwrap();
    let vista1 = almacen.hacer_visible(k1, almacen.vista()).unwrap();
    let vista2 = almacen.cambiar_contexto(c2.context_key()).unwrap();
    assert_eq!(
        almacen.hacer_visible(k1, vista1),
        Err(ErrorAlmacen::VistaObsoleta)
    );
    assert_eq!(
        almacen.hacer_visible(k1, vista2),
        Err(ErrorAlmacen::ContextoDistinto)
    );
    assert_eq!(almacen.vista(), vista2);
    assert!(almacen.consultar(k1).is_some());
    let publicada = almacen.hacer_visible(k2, vista2).unwrap();
    assert_eq!(
        almacen.leer_visible(k2, publicada).unwrap().context_key(),
        c2.context_key()
    );
}

#[test]
fn aba_rechaza_solicitud_antigua_aunque_vuelva_el_mismo_contexto() {
    let (b, ctx) = fixture();
    let evidencia = autorizar_cuerpo(&b, &ctx).unwrap();
    let clave = ClaveEvidencia::de(&evidencia);
    let mut almacen = cache(ctx.context_key(), 1);
    let inicial = almacen.vista();
    almacen.retener(evidencia).unwrap();
    almacen.cambiar_contexto(contexto(9).context_key()).unwrap();
    let regreso = almacen.cambiar_contexto(ctx.context_key()).unwrap();
    assert_eq!(inicial.contexto(), regreso.contexto());
    assert_ne!(inicial.revision(), regreso.revision());
    assert_eq!(
        almacen.hacer_visible(clave, inicial),
        Err(ErrorAlmacen::VistaObsoleta)
    );
    assert_eq!(almacen.vista(), regreso);
    let nueva = almacen.hacer_visible(clave, regreso).unwrap();
    assert!(almacen.leer_visible(clave, nueva).is_ok());
}

#[test]
fn publicaciones_competidoras_no_comparten_una_version_consumida() {
    let (a, b, ctx) = fixture_multisig();
    let ea = autorizar_cuerpo(&a, &ctx).unwrap();
    let eb = autorizar_cuerpo(&b, &ctx).unwrap();
    let ka = ClaveEvidencia::de(&ea);
    let kb = ClaveEvidencia::de(&eb);
    let mut almacen = cache(ctx.context_key(), 2);
    almacen.retener(ea).unwrap();
    almacen.retener(eb).unwrap();
    let observada_por_ambas = almacen.vista();
    let primera = almacen.hacer_visible(ka, observada_por_ambas).unwrap();
    assert_eq!(
        almacen.hacer_visible(kb, observada_por_ambas),
        Err(ErrorAlmacen::VistaObsoleta)
    );
    assert_eq!(almacen.vista(), primera);
    assert_eq!(almacen.leer_visible(ka, primera).unwrap().cuerpo(), &a);
}

#[test]
fn no_se_adjunta_certificado_a_bytes_mutados_despues_de_verificar() {
    let (mut b, ctx) = fixture();
    let evidencia = autorizar_cuerpo(&b, &ctx).unwrap();
    let original = b.clone();
    let clave = ClaveEvidencia::de(&evidencia);
    b.testigos[1][0][0] ^= 1;
    assert_ne!(clave.cuerpo, b.body_key());
    let mut almacen = cache(ctx.context_key(), 1);
    almacen.retener(evidencia).unwrap();
    assert_eq!(almacen.consultar(clave).unwrap().cuerpo(), &original);
    let falsa = ClaveEvidencia {
        cuerpo: b.body_key(),
        contexto: ctx.context_key(),
    };
    let antes = almacen.vista();
    assert_eq!(
        almacen.hacer_visible(falsa, antes),
        Err(ErrorAlmacen::EvidenciaNoRetenida)
    );
    assert_eq!(almacen.vista(), antes);
    assert!(almacen.consultar(falsa).is_none());
}

#[test]
fn una_vista_no_se_reutiliza_en_otra_instancia_o_cache_recreada() {
    let (b, ctx) = fixture();
    let evidencia = autorizar_cuerpo(&b, &ctx).unwrap();
    let clave = ClaveEvidencia::de(&evidencia);
    let anterior = cache(ctx.context_key(), 1).vista();
    let mut nueva = cache(ctx.context_key(), 1);
    nueva.retener(evidencia).unwrap();
    assert_eq!(anterior.contexto(), nueva.vista().contexto());
    assert_eq!(anterior.revision(), nueva.vista().revision());
    assert_ne!(anterior, nueva.vista());
    let antes = nueva.vista();
    assert_eq!(
        nueva.hacer_visible(clave, anterior),
        Err(ErrorAlmacen::VistaObsoleta)
    );
    assert_eq!(nueva.vista(), antes);
    assert!(nueva.hacer_visible(clave, antes).is_ok());
}
