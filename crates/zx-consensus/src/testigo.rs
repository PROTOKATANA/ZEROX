//! Satisfacción de las condiciones de gasto (SPEC §5.3, C-TX-06b, C-TX-06c).
//!
//! # Dos reglas que no son opcionales
//!
//! **Índices estrictamente crecientes en `MultiSig`.** Cierran dos agujeros a la vez: no hay dos
//! ordenaciones válidas del mismo conjunto de firmas —maleabilidad— y no se puede repetir una
//! clave para contarla dos veces, sin necesidad de comprobarlo aparte.
//!
//! **El testigo se consume entero** (C-TX-06c). Sin esa regla, rellenarlo con basura no invalida la
//! transacción: el `txid` no cambia, porque el testigo es dato de autorización, y el atacante
//! consigue banda y disco gratis. Es el patrón de GHSA-2x4w-pxqw-58v9, el CVE real de Orchard.

use zx_core::digest::SigHash;
use zx_core::encoding::compact_size;
use zx_core::firma::{ClavePublica, Firma, LONGITUD_CLAVE, LONGITUD_FIRMA, verificar};
use zx_core::sha3_256_publico;
use zx_core::tx::Lock;

use crate::error::ConsensusError;

/// Contexto que la verificación de un HTLC necesita y que no está en el testigo.
#[derive(Clone, Copy, Debug)]
pub struct ContextoGasto {
    /// Altura del bloque que incluye la transacción — decide si la vía de timeout está abierta.
    pub altura: u32,
}

/// Lee `n` bytes del principio y devuelve el resto.
fn tomar<'a>(
    bytes: &'a [u8],
    n: usize,
    que: &'static str,
) -> Result<(&'a [u8], &'a [u8]), ConsensusError> {
    bytes
        .split_at_checked(n)
        .ok_or(ConsensusError::TestigoMalFormado { motivo: que })
}

fn leer_clave_y_firma(bytes: &[u8]) -> Result<(ClavePublica, Firma, &[u8]), ConsensusError> {
    let (k, resto) = tomar(bytes, LONGITUD_CLAVE, "falta la clave pública")?;
    let (f, resto) = tomar(resto, LONGITUD_FIRMA, "falta la firma")?;

    let mut kb = [0u8; LONGITUD_CLAVE];
    kb.copy_from_slice(k);
    let mut fb = [0u8; LONGITUD_FIRMA];
    fb.copy_from_slice(f);

    Ok((ClavePublica::desde_bytes(kb), Firma::desde_bytes(fb), resto))
}

/// Comprueba que un testigo satisface la condición de gasto de la salida (C-TX-06b, C-TX-06c).
///
/// `sighash` es el `signature_digest` de esa entrada (§4.3), ya calculado.
///
/// # Errores
/// [`ConsensusError::TestigoMalFormado`] si el formato no cuadra o sobran bytes,
/// [`ConsensusError::CondicionNoSatisfecha`] si la condición no se cumple.
pub fn satisface(
    lock: &Lock,
    testigo: &[u8],
    sighash: &SigHash,
    ctx: ContextoGasto,
) -> Result<(), ConsensusError> {
    let msg = sighash.as_bytes();
    let resto = match lock {
        Lock::PubKey { pubkey_hash } => {
            let (clave, firma, resto) = leer_clave_y_firma(testigo)?;
            if !clave.coincide_con(pubkey_hash) {
                return Err(ConsensusError::CondicionNoSatisfecha {
                    motivo: "la clave no corresponde al hash de la salida",
                });
            }
            verificar(&clave, &firma, msg).map_err(|_| ConsensusError::CondicionNoSatisfecha {
                motivo: "firma inválida",
            })?;
            resto
        }

        Lock::MultiSig { k, pubkey_hashes } => {
            let mut resto = testigo;
            let mut anterior: Option<u8> = None;

            for _ in 0..*k {
                let (idx_b, r) = tomar(resto, 1, "falta el índice de clave")?;
                let idx = *idx_b.first().ok_or(ConsensusError::TestigoMalFormado {
                    motivo: "índice ilegible",
                })?;

                // C-TX-06b: estrictamente crecientes. Cierra reordenación y repetición de una vez.
                if let Some(prev) = anterior
                    && idx <= prev
                {
                    return Err(ConsensusError::TestigoMalFormado {
                        motivo: "los índices de MultiSig MUST ser estrictamente crecientes",
                    });
                }
                anterior = Some(idx);

                let esperado = pubkey_hashes.get(usize::from(idx)).ok_or(
                    ConsensusError::TestigoMalFormado {
                        motivo: "índice de clave fuera de rango",
                    },
                )?;

                let (clave, firma, r2) = leer_clave_y_firma(r)?;
                if !clave.coincide_con(esperado) {
                    return Err(ConsensusError::CondicionNoSatisfecha {
                        motivo: "la clave no corresponde al índice declarado",
                    });
                }
                verificar(&clave, &firma, msg).map_err(|_| {
                    ConsensusError::CondicionNoSatisfecha {
                        motivo: "firma inválida en MultiSig",
                    }
                })?;
                resto = r2;
            }
            resto
        }

        Lock::Htlc {
            hash,
            receiver,
            sender,
            timeout,
        } => {
            let (via_b, r) = tomar(testigo, 1, "falta el discriminante de vía del HTLC")?;
            let via = *via_b.first().ok_or(ConsensusError::TestigoMalFormado {
                motivo: "vía ilegible",
            })?;

            match via {
                // Vía (a): preimagen + firma del receptor.
                0x00 => {
                    let (n, r) =
                        compact_size::leer(r).map_err(|_| ConsensusError::TestigoMalFormado {
                            motivo: "longitud de preimagen ilegible",
                        })?;
                    let n = usize::try_from(n).map_err(|_| ConsensusError::TestigoMalFormado {
                        motivo: "longitud de preimagen absurda",
                    })?;
                    let (preimagen, r) = tomar(r, n, "preimagen truncada")?;

                    if sha3_256_publico(preimagen).as_bytes() != hash {
                        return Err(ConsensusError::CondicionNoSatisfecha {
                            motivo: "SHA3-256(preimagen) no coincide con el hash del HTLC",
                        });
                    }
                    let (clave, firma, r2) = leer_clave_y_firma(r)?;
                    if !clave.coincide_con(receiver) {
                        return Err(ConsensusError::CondicionNoSatisfecha {
                            motivo: "la vía de preimagen exige la firma del receptor",
                        });
                    }
                    verificar(&clave, &firma, msg).map_err(|_| {
                        ConsensusError::CondicionNoSatisfecha {
                            motivo: "firma inválida",
                        }
                    })?;
                    r2
                }

                // Vía (b): timeout vencido + firma del emisor.
                0x01 => {
                    if ctx.altura < *timeout {
                        return Err(ConsensusError::CondicionNoSatisfecha {
                            motivo: "la vía de timeout aún no está abierta",
                        });
                    }
                    let (clave, firma, r2) = leer_clave_y_firma(r)?;
                    if !clave.coincide_con(sender) {
                        return Err(ConsensusError::CondicionNoSatisfecha {
                            motivo: "la vía de timeout exige la firma del emisor",
                        });
                    }
                    verificar(&clave, &firma, msg).map_err(|_| {
                        ConsensusError::CondicionNoSatisfecha {
                            motivo: "firma inválida",
                        }
                    })?;
                    r2
                }

                _ => {
                    return Err(ConsensusError::TestigoMalFormado {
                        motivo: "vía de HTLC desconocida",
                    });
                }
            }
        }
    };

    // C-TX-06c · nada de relleno. Sin esto, la basura sobrante viaja gratis: no cambia el txid
    // porque el testigo es dato de autorización, así que la transacción sigue siendo válida.
    if resto.is_empty() {
        Ok(())
    } else {
        Err(ConsensusError::TestigoMalFormado {
            motivo: "C-TX-06c: el testigo tiene bytes sobrantes",
        })
    }
}

#[cfg(test)]
#[expect(clippy::unwrap_used, reason = "los tests fallan con panic por diseño")]
mod tests {
    use super::{ContextoGasto, satisface};
    use crate::error::ConsensusError;
    use ed25519_zebra::{SigningKey, VerificationKey};
    use zx_core::digest::{Digest, SigHash};
    use zx_core::encoding::compact_size;
    use zx_core::firma::ClavePublica;
    use zx_core::sha3_256_publico;
    use zx_core::tx::{HashClave, Lock};

    fn sighash() -> SigHash {
        SigHash::from_digest(Digest::from_bytes([0x5a; 32]))
    }

    fn par(semilla: u8) -> (SigningKey, ClavePublica) {
        let sk = SigningKey::from([semilla; 32]);
        let vk = VerificationKey::from(&sk);
        (sk, ClavePublica::desde_bytes(vk.into()))
    }

    /// `pubkey(32) ‖ sig(64)` sobre el sighash dado.
    fn testigo_pubkey(sk: &SigningKey, pk: &ClavePublica, sh: &SigHash) -> Vec<u8> {
        let mut w = Vec::with_capacity(96);
        w.extend_from_slice(pk.bytes());
        let firma: [u8; 64] = sk.sign(sh.as_bytes()).into();
        w.extend_from_slice(&firma);
        w
    }

    fn ctx(altura: u32) -> ContextoGasto {
        ContextoGasto { altura }
    }

    // ── PubKey ───────────────────────────────────────────────────────────────

    #[test]
    fn pubkey_valida() {
        let (sk, pk) = par(1);
        let lock = Lock::PubKey {
            pubkey_hash: pk.hash(),
        };
        let w = testigo_pubkey(&sk, &pk, &sighash());
        assert!(satisface(&lock, &w, &sighash(), ctx(0)).is_ok());
    }

    #[test]
    fn pubkey_con_la_clave_equivocada() {
        let (sk, pk) = par(2);
        let (_, otra) = par(3);
        let lock = Lock::PubKey {
            pubkey_hash: otra.hash(),
        };
        let w = testigo_pubkey(&sk, &pk, &sighash());
        assert!(matches!(
            satisface(&lock, &w, &sighash(), ctx(0)),
            Err(ConsensusError::CondicionNoSatisfecha { .. })
        ));
    }

    /// La firma está atada al sighash: sirve para esa entrada y no para otra.
    #[test]
    fn una_firma_no_sirve_para_otro_sighash() {
        let (sk, pk) = par(4);
        let lock = Lock::PubKey {
            pubkey_hash: pk.hash(),
        };
        let w = testigo_pubkey(&sk, &pk, &sighash());
        let otro = SigHash::from_digest(Digest::from_bytes([0x11; 32]));
        assert!(satisface(&lock, &w, &otro, ctx(0)).is_err());
    }

    /// **C-TX-06c.** Un byte de más y se rechaza.
    ///
    /// Sin esta regla el relleno viaja gratis: no cambia el txid, porque el testigo es dato de
    /// autorización, así que la transacción seguiría siendo válida. Es GHSA-2x4w-pxqw-58v9.
    #[test]
    fn el_relleno_sobrante_se_rechaza() {
        let (sk, pk) = par(5);
        let lock = Lock::PubKey {
            pubkey_hash: pk.hash(),
        };
        let mut w = testigo_pubkey(&sk, &pk, &sighash());
        assert!(
            satisface(&lock, &w, &sighash(), ctx(0)).is_ok(),
            "el testigo limpio vale"
        );

        w.push(0x00);
        let e = satisface(&lock, &w, &sighash(), ctx(0)).unwrap_err();
        assert!(
            matches!(e, ConsensusError::TestigoMalFormado { .. }),
            "un solo byte de relleno MUST invalidar: {e:?}"
        );

        // Y con mucho relleno tampoco, evidentemente.
        w.extend_from_slice(&[0xFF; 10_000]);
        assert!(satisface(&lock, &w, &sighash(), ctx(0)).is_err());
    }

    #[test]
    fn un_testigo_truncado_se_rechaza() {
        let (sk, pk) = par(6);
        let lock = Lock::PubKey {
            pubkey_hash: pk.hash(),
        };
        let w = testigo_pubkey(&sk, &pk, &sighash());
        for n in [0usize, 1, 31, 32, 95] {
            assert!(
                satisface(&lock, w.get(..n).unwrap(), &sighash(), ctx(0)).is_err(),
                "{n} bytes debería rechazarse"
            );
        }
    }

    // ── MultiSig ─────────────────────────────────────────────────────────────

    fn entrada_multisig(idx: u8, sk: &SigningKey, pk: &ClavePublica, sh: &SigHash) -> Vec<u8> {
        let mut e = vec![idx];
        e.extend_from_slice(pk.bytes());
        let firma: [u8; 64] = sk.sign(sh.as_bytes()).into();
        e.extend_from_slice(&firma);
        e
    }

    #[test]
    fn multisig_2_de_3_valido() {
        let (sk0, pk0) = par(10);
        let (_, pk1) = par(11);
        let (sk2, pk2) = par(12);
        let hashes: Vec<HashClave> = vec![pk0.hash(), pk1.hash(), pk2.hash()];
        let lock = Lock::multisig(2, hashes).unwrap();

        let mut w = entrada_multisig(0, &sk0, &pk0, &sighash());
        w.extend(entrada_multisig(2, &sk2, &pk2, &sighash()));
        assert!(satisface(&lock, &w, &sighash(), ctx(0)).is_ok());
    }

    /// **C-TX-06b.** Los índices deben crecer estrictamente: cierra la maleabilidad por reordenación.
    #[test]
    fn multisig_rechaza_indices_desordenados() {
        let (sk0, pk0) = par(10);
        let (_, pk1) = par(11);
        let (sk2, pk2) = par(12);
        let lock = Lock::multisig(2, vec![pk0.hash(), pk1.hash(), pk2.hash()]).unwrap();

        // Las mismas dos firmas, en el otro orden: MUST rechazarse.
        let mut w = entrada_multisig(2, &sk2, &pk2, &sighash());
        w.extend(entrada_multisig(0, &sk0, &pk0, &sighash()));
        let e = satisface(&lock, &w, &sighash(), ctx(0)).unwrap_err();
        assert!(
            matches!(e, ConsensusError::TestigoMalFormado { .. }),
            "{e:?}"
        );
    }

    /// Y repetir el mismo índice tampoco cuela — la monotonía **estricta** lo cubre gratis.
    #[test]
    fn multisig_rechaza_la_misma_clave_dos_veces() {
        let (sk0, pk0) = par(10);
        let (_, pk1) = par(11);
        let lock = Lock::multisig(2, vec![pk0.hash(), pk1.hash()]).unwrap();

        let mut w = entrada_multisig(0, &sk0, &pk0, &sighash());
        w.extend(entrada_multisig(0, &sk0, &pk0, &sighash()));
        assert!(
            satisface(&lock, &w, &sighash(), ctx(0)).is_err(),
            "una sola firma no puede contar dos veces"
        );
    }

    #[test]
    fn multisig_rechaza_menos_firmas_de_las_exigidas() {
        let (sk0, pk0) = par(10);
        let (_, pk1) = par(11);
        let lock = Lock::multisig(2, vec![pk0.hash(), pk1.hash()]).unwrap();
        let w = entrada_multisig(0, &sk0, &pk0, &sighash());
        assert!(
            satisface(&lock, &w, &sighash(), ctx(0)).is_err(),
            "1 de 2 no basta"
        );
    }

    /// Una firma **de más** también se rechaza, por C-TX-06c: sobran bytes.
    #[test]
    fn multisig_rechaza_una_firma_de_mas() {
        let (sk0, pk0) = par(10);
        let (sk1, pk1) = par(11);
        let lock = Lock::multisig(1, vec![pk0.hash(), pk1.hash()]).unwrap();

        let mut w = entrada_multisig(0, &sk0, &pk0, &sighash());
        w.extend(entrada_multisig(1, &sk1, &pk1, &sighash()));
        assert!(
            satisface(&lock, &w, &sighash(), ctx(0)).is_err(),
            "k = 1 exige exactamente 1"
        );
    }

    #[test]
    fn multisig_rechaza_indice_fuera_de_rango() {
        let (sk0, pk0) = par(10);
        let lock = Lock::multisig(1, vec![pk0.hash()]).unwrap();
        let w = entrada_multisig(7, &sk0, &pk0, &sighash());
        assert!(satisface(&lock, &w, &sighash(), ctx(0)).is_err());
    }

    // ── HTLC ─────────────────────────────────────────────────────────────────

    fn htlc(
        preimagen: &[u8],
        receptor: &ClavePublica,
        emisor: &ClavePublica,
        timeout: u32,
    ) -> Lock {
        Lock::Htlc {
            hash: *sha3_256_publico(preimagen).as_bytes(),
            receiver: receptor.hash(),
            sender: emisor.hash(),
            timeout,
        }
    }

    fn testigo_htlc_preimagen(
        preimagen: &[u8],
        sk: &SigningKey,
        pk: &ClavePublica,
        sh: &SigHash,
    ) -> Vec<u8> {
        let mut w = vec![0x00];
        compact_size::escribir(&mut w, preimagen.len() as u64);
        w.extend_from_slice(preimagen);
        w.extend_from_slice(pk.bytes());
        let firma: [u8; 64] = sk.sign(sh.as_bytes()).into();
        w.extend_from_slice(&firma);
        w
    }

    fn testigo_htlc_timeout(sk: &SigningKey, pk: &ClavePublica, sh: &SigHash) -> Vec<u8> {
        let mut w = vec![0x01];
        w.extend_from_slice(pk.bytes());
        let firma: [u8; 64] = sk.sign(sh.as_bytes()).into();
        w.extend_from_slice(&firma);
        w
    }

    #[test]
    fn htlc_via_preimagen() {
        let (sk_r, pk_r) = par(20);
        let (_, pk_s) = par(21);
        let secreto = b"el secreto del canal de pago";
        let lock = htlc(secreto, &pk_r, &pk_s, 1000);

        let w = testigo_htlc_preimagen(secreto, &sk_r, &pk_r, &sighash());
        assert!(
            satisface(&lock, &w, &sighash(), ctx(0)).is_ok(),
            "antes del timeout, con secreto"
        );
    }

    #[test]
    fn htlc_rechaza_una_preimagen_incorrecta() {
        let (sk_r, pk_r) = par(20);
        let (_, pk_s) = par(21);
        let lock = htlc(b"el secreto", &pk_r, &pk_s, 1000);
        let w = testigo_htlc_preimagen(b"otro secreto", &sk_r, &pk_r, &sighash());
        assert!(matches!(
            satisface(&lock, &w, &sighash(), ctx(0)),
            Err(ConsensusError::CondicionNoSatisfecha { .. })
        ));
    }

    /// La vía de preimagen exige la firma del **receptor**, no la de cualquiera.
    #[test]
    fn htlc_la_via_de_preimagen_exige_al_receptor() {
        let (_, pk_r) = par(20);
        let (sk_s, pk_s) = par(21);
        let secreto = b"secreto";
        let lock = htlc(secreto, &pk_r, &pk_s, 1000);
        // El emisor conoce el secreto pero no puede usar esta vía.
        let w = testigo_htlc_preimagen(secreto, &sk_s, &pk_s, &sighash());
        assert!(satisface(&lock, &w, &sighash(), ctx(0)).is_err());
    }

    /// **El borde del timeout.** Cerrado antes, abierto exactamente en el `timeout`.
    #[test]
    fn htlc_el_borde_exacto_del_timeout() {
        let (_, pk_r) = par(20);
        let (sk_s, pk_s) = par(21);
        let lock = htlc(b"x", &pk_r, &pk_s, 1000);
        let w = testigo_htlc_timeout(&sk_s, &pk_s, &sighash());

        assert!(
            satisface(&lock, &w, &sighash(), ctx(999)).is_err(),
            "999 aún no"
        );
        assert!(
            satisface(&lock, &w, &sighash(), ctx(1000)).is_ok(),
            "1000 sí — el ≥ del SPEC"
        );
        assert!(satisface(&lock, &w, &sighash(), ctx(1001)).is_ok());
    }

    #[test]
    fn htlc_la_via_de_timeout_exige_al_emisor() {
        let (sk_r, pk_r) = par(20);
        let (_, pk_s) = par(21);
        let lock = htlc(b"x", &pk_r, &pk_s, 1000);
        let w = testigo_htlc_timeout(&sk_r, &pk_r, &sighash());
        assert!(satisface(&lock, &w, &sighash(), ctx(2000)).is_err());
    }

    #[test]
    fn htlc_rechaza_una_via_desconocida() {
        let (_, pk_r) = par(20);
        let (sk_s, pk_s) = par(21);
        let lock = htlc(b"x", &pk_r, &pk_s, 0);
        let mut w = testigo_htlc_timeout(&sk_s, &pk_s, &sighash());
        if let Some(v) = w.first_mut() {
            *v = 0x02;
        }
        assert!(matches!(
            satisface(&lock, &w, &sighash(), ctx(0)),
            Err(ConsensusError::TestigoMalFormado { .. })
        ));
    }

    /// Una preimagen vacía es legítima si su hash coincide — no hay razón para prohibirla.
    #[test]
    fn htlc_admite_una_preimagen_vacia() {
        let (sk_r, pk_r) = par(20);
        let (_, pk_s) = par(21);
        let lock = htlc(b"", &pk_r, &pk_s, 1000);
        let w = testigo_htlc_preimagen(b"", &sk_r, &pk_r, &sighash());
        assert!(satisface(&lock, &w, &sighash(), ctx(0)).is_ok());
    }
}
