//! **Cómo se escribe una entrada del UTXO set en disco** (C-STORE-05).
//!
//! # Esto no es consenso, y decirlo importa
//!
//! Ningún byte de este módulo entra jamás en un hash ni en una firma. El UTXO set es estado local
//! **reconstruible**: dos nodos pueden guardarlo de formas distintas sin divergir, y cambiar este
//! formato no puede bifurcar la red.
//!
//! Merece la pena escribirlo porque todo lo demás que codifica bytes en este proyecto —`zx-core::wire`,
//! la preimagen del PoW, la de las firmas— **sí** es normativo, y alguien que llegue de allí
//! asumirá lo mismo aquí y bloqueará un cambio de formato de disco por miedo a un fork que no
//! existe.
//!
//! Lo único que **sí** hay que cumplir es que la codificación sea **inyectiva**: dos entradas
//! distintas no pueden producir los mismos bytes, o el almacén perdería UTXOs en silencio. Hay un
//! property test para eso.
//!
//! # Por qué el `Lock` se reutiliza y no se reescribe
//!
//! [`zx_core::wire::lock_a_bytes`] ya sabe escribir un `Lock`. Escribir aquí una segunda forma
//! sería exactamente el patrón que este proyecto ya ha pagado varias veces: dos fuentes para una
//! sola verdad, y la segunda envejeciendo sola. El formato de disco hereda el del cable, y si el
//! del cable cambia, este cambia con él — que es lo correcto, porque el disco es local y migrable.
//!
//! # Por qué `prev_index` va en big-endian y el resto no
//!
//! No es incoherencia. RocksDB ordena las claves por bytes, así que big-endian hace que todas las
//! salidas de una misma transacción queden **contiguas**: recorrerlas es un barrido de prefijo en
//! vez de cuatro mil millones de búsquedas. Es la misma razón que C-STORE-03 da para las alturas.
//!
//! Los campos del **valor** no se ordenan por nada, así que ahí manda la coherencia con el resto
//! del formato del proyecto, que es little-endian.

use zx_consensus::validacion::EntradaUtxo;
use zx_core::amount::Amount;
use zx_core::digest::{Digest, TxId};
use zx_core::tx::{OutPoint, SpentOutput};
use zx_core::wire;

use crate::error::StorageError;

/// Bytes de la clave: el `txid` y el índice de salida.
pub const TAMANO_CLAVE: usize = 36;

/// La clave con la que un UTXO se indexa: `prev_txid(32) ‖ prev_index(4 BE)`.
#[must_use]
pub fn clave(o: &OutPoint) -> [u8; TAMANO_CLAVE] {
    let mut k = [0u8; TAMANO_CLAVE];
    let (txid, indice) = k.split_at_mut(32);
    txid.copy_from_slice(o.prev_txid.as_bytes());
    // C-STORE-05 · big-endian, para que el orden de bytes sea el orden numérico.
    indice.copy_from_slice(&o.prev_index.to_be_bytes());
    k
}

/// El `OutPoint` que produjo una clave.
///
/// # Errores
/// [`StorageError::Corrupto`] si no mide exactamente [`TAMANO_CLAVE`].
pub fn outpoint_desde_clave(bytes: &[u8]) -> Result<OutPoint, StorageError> {
    if bytes.len() != TAMANO_CLAVE {
        return Err(StorageError::Corrupto {
            que: "una clave de UTXO con tamaño distinto de 36",
        });
    }
    let (txid, indice) = bytes.split_at(32);
    let mut t = [0u8; 32];
    t.copy_from_slice(txid);
    let mut i = [0u8; 4];
    i.copy_from_slice(indice);
    Ok(OutPoint {
        prev_txid: TxId::from_digest(Digest::from_bytes(t)),
        prev_index: u32::from_be_bytes(i),
    })
}

/// Escribe el valor: `importe(8) ‖ altura(4) ‖ coinbase(1) ‖ Lock`.
pub fn entrada_a_bytes(salida: &mut Vec<u8>, e: &EntradaUtxo) {
    salida.extend_from_slice(&e.salida.value.brek().to_le_bytes());
    salida.extend_from_slice(&e.altura_creacion.to_le_bytes());
    salida.push(u8::from(e.es_coinbase));
    wire::lock_a_bytes(salida, &e.salida.lock);
}

/// Lee el valor.
///
/// # Errores
/// [`StorageError::Corrupto`] si faltan bytes, si sobran, si el importe está fuera de rango o si el
/// `Lock` no decodifica.
pub fn entrada_desde_bytes(bytes: &[u8]) -> Result<EntradaUtxo, StorageError> {
    let corrupto = |que: &'static str, causa: &str| StorageError::UtxoCorrupto {
        que,
        causa: causa.to_owned(),
    };

    let (cabeza, resto) = bytes
        .split_at_checked(13)
        .ok_or_else(|| corrupto("campos fijos", "faltan bytes"))?;
    let (importe, r): (&[u8], &[u8]) = cabeza.split_at(8);
    let (altura, coinbase) = r.split_at(4);

    let mut ocho = [0u8; 8];
    ocho.copy_from_slice(importe);
    let mut cuatro = [0u8; 4];
    cuatro.copy_from_slice(altura);

    // El importe se valida al construirlo, no se acepta crudo: un almacén corrupto no debe poder
    // inyectar un valor fuera de rango en el camino de validación (C-ENC-03).
    let value =
        Amount::nuevo(i64::from_le_bytes(ocho)).map_err(|e| corrupto("importe", &e.to_string()))?;

    let es_coinbase = match coinbase.first() {
        Some(0) => false,
        Some(1) => true,
        // Un booleano que no es 0 ni 1 es una segunda codificación del mismo valor lógico. Se
        // rechaza en vez de interpretarse: si el almacén está corrupto, es mejor saberlo.
        _ => {
            return Err(corrupto(
                "es_coinbase",
                "booleano no canónico: no es 0 ni 1",
            ));
        }
    };

    let (lock, sobra) =
        wire::lock_desde_bytes(resto).map_err(|e| corrupto("lock", &e.to_string()))?;
    if !sobra.is_empty() {
        return Err(corrupto("lock", "sobran bytes tras el lock"));
    }

    Ok(EntradaUtxo {
        salida: SpentOutput { value, lock },
        altura_creacion: u32::from_le_bytes(cuatro),
        es_coinbase,
    })
}

#[cfg(test)]
#[expect(
    clippy::unwrap_used,
    clippy::expect_used,
    reason = "los tests fallan con panic por diseño"
)]
mod tests {
    use super::{TAMANO_CLAVE, clave, entrada_a_bytes, entrada_desde_bytes, outpoint_desde_clave};
    use proptest::prelude::*;
    use zx_consensus::validacion::EntradaUtxo;
    use zx_core::amount::Amount;
    use zx_core::digest::{Digest, TxId};
    use zx_core::firma::ClavePublica;
    use zx_core::tx::{Lock, OutPoint, SpentOutput};

    fn op(txid: u8, idx: u32) -> OutPoint {
        OutPoint {
            prev_txid: TxId::from_digest(Digest::from_bytes([txid; 32])),
            prev_index: idx,
        }
    }

    fn entrada(valor: i64, altura: u32, coinbase: bool) -> EntradaUtxo {
        con_lock(valor, altura, coinbase, 0)
    }

    /// Una entrada con uno de los tres tipos de `Lock`, elegido por `cual`.
    ///
    /// Los tres, y no solo `PubKey`, porque la inyectividad tiene que valer para todos: dos locks
    /// de tipos distintos no pueden producir los mismos bytes, y comprobarlo con un solo tipo no
    /// prueba nada de eso.
    fn con_lock(valor: i64, altura: u32, coinbase: bool, cual: u8) -> EntradaUtxo {
        let pk = |b: u8| ClavePublica::desde_bytes([b; 32]);
        let lock = match cual % 3 {
            0 => Lock::PubKey { pubkey: pk(9) },
            1 => Lock::MultiSig {
                k: 2,
                pubkeys: vec![pk(1), pk(2), pk(3)],
            },
            _ => Lock::Htlc {
                hash: [4; 32],
                receiver: pk(5),
                sender: pk(6),
                timeout: 777,
            },
        };
        EntradaUtxo {
            salida: SpentOutput {
                value: Amount::nuevo(valor).unwrap(),
                lock,
            },
            altura_creacion: altura,
            es_coinbase: coinbase,
        }
    }

    fn ida_y_vuelta(e: &EntradaUtxo) -> EntradaUtxo {
        let mut b = Vec::new();
        entrada_a_bytes(&mut b, e);
        entrada_desde_bytes(&b).expect("debe decodificar lo que acabamos de escribir")
    }

    #[test]
    fn la_clave_mide_36_y_da_la_vuelta() {
        let o = op(7, 0x0102_0304);
        let k = clave(&o);
        assert_eq!(k.len(), TAMANO_CLAVE);
        assert_eq!(outpoint_desde_clave(&k).unwrap(), o);
    }

    /// **El índice va en big-endian, y eso es lo que hace útil el orden de RocksDB.**
    ///
    /// RocksDB ordena por bytes. Con big-endian, las salidas de una misma transacción quedan
    /// contiguas y en orden numérico; con little-endian la salida 256 iría antes que la 2 y
    /// recorrerlas por rango dejaría de funcionar. Es la misma razón de C-STORE-03.
    #[test]
    fn el_orden_de_las_claves_es_el_orden_numerico() {
        let mut claves: Vec<_> = [300u32, 2, 1, 256, 0]
            .iter()
            .map(|i| clave(&op(7, *i)))
            .collect();
        claves.sort_unstable();
        let indices: Vec<u32> = claves
            .iter()
            .map(|k| outpoint_desde_clave(k).unwrap().prev_index)
            .collect();
        assert_eq!(
            indices,
            vec![0, 1, 2, 256, 300],
            "ordenar bytes debe ordenar números"
        );
    }

    /// Las salidas de una misma transacción son un prefijo común: un barrido, no una búsqueda.
    #[test]
    fn las_salidas_de_una_tx_comparten_prefijo() {
        let a = clave(&op(7, 0));
        let b = clave(&op(7, 99));
        assert_eq!(a[..32], b[..32], "los 32 primeros bytes son el txid");
        assert_ne!(clave(&op(8, 0))[..32], a[..32]);
    }

    #[test]
    fn la_entrada_da_la_vuelta() {
        for (v, h, cb) in [
            (1i64, 0u32, false),
            (50_000, 12345, true),
            (i64::from(u32::MAX), 1, false),
        ] {
            let e = entrada(v, h, cb);
            assert_eq!(ida_y_vuelta(&e), e, "valor {v}, altura {h}, coinbase {cb}");
        }
    }

    /// **Nada se acepta crudo.** Un almacén corrupto no puede inyectar valores imposibles en el
    /// camino de validación: el importe se reconstruye con su constructor, no con un `from_le_bytes`
    /// a pelo, y el booleano tiene que ser 0 o 1.
    #[test]
    fn los_bytes_corruptos_se_rechazan() {
        let mut b = Vec::new();
        entrada_a_bytes(&mut b, &entrada(50_000, 1, false));

        assert!(
            entrada_desde_bytes(b.get(..5).unwrap()).is_err(),
            "truncada"
        );
        let mut sobra = b.clone();
        sobra.push(0);
        assert!(entrada_desde_bytes(&sobra).is_err(), "con bytes de más");

        let mut booleano = b.clone();
        *booleano.get_mut(12).unwrap() = 2;
        assert!(
            entrada_desde_bytes(&booleano).is_err(),
            "booleano no canónico"
        );

        let mut importe = b.clone();
        importe
            .get_mut(..8)
            .unwrap()
            .copy_from_slice(&i64::MIN.to_le_bytes());
        assert!(
            entrada_desde_bytes(&importe).is_err(),
            "importe fuera de rango"
        );
    }

    proptest! {
        /// **Ida y vuelta para cualquier entrada.**
        #[test]
        fn ida_y_vuelta_siempre(v in 0i64..1_000_000_000_000, h in 0u32.., cb in any::<bool>(), l: u8) {
            let e = con_lock(v, h, cb, l);
            prop_assert_eq!(ida_y_vuelta(&e), e);
        }

        /// **INYECTIVA** — lo único que C-STORE-05 exige de verdad.
        ///
        /// Dos entradas distintas no pueden dar los mismos bytes. Si pudieran, el almacén perdería
        /// UTXOs en silencio: se sobrescribirían entre sí y nadie se enteraría hasta que alguien
        /// intentara gastar el que desapareció.
        ///
        /// # Por qué genera pares que difieren en UN campo, y no dos entradas al azar
        ///
        /// La primera versión sorteaba las dos entradas de forma independiente y **pasaba con la
        /// codificación rota**: se comprobó borrando el byte de `es_coinbase`, y el test siguió en
        /// verde. El motivo es que con `v ∈ 0..10⁶` y `h ∈ 0..10⁵` la probabilidad de sortear dos
        /// entradas que coincidan en todo menos en un campo es prácticamente cero — así que el caso
        /// que detecta un campo perdido **nunca se generaba**.
        ///
        /// Ahora se construye una entrada y una variante suya que difiere en exactamente un campo.
        /// Eso sí detecta que la codificación deje de escribir alguno.
        #[test]
        fn cambiar_un_solo_campo_cambia_los_bytes(
            v in 0i64..1_000_000, h in 0u32..100_000, cb in any::<bool>(), l: u8, campo: u8,
        ) {
            let e1 = con_lock(v, h, cb, l);
            let e2 = match campo % 4 {
                0 => con_lock(v + 1, h, cb, l),
                1 => con_lock(v, h + 1, cb, l),
                2 => con_lock(v, h, !cb, l),
                _ => con_lock(v, h, cb, l.wrapping_add(1)),
            };
            prop_assume!(e1 != e2);

            let (mut b1, mut b2) = (Vec::new(), Vec::new());
            entrada_a_bytes(&mut b1, &e1);
            entrada_a_bytes(&mut b2, &e2);
            prop_assert_ne!(b1, b2, "difieren en el campo {} y aun así dan los mismos bytes", campo % 4);
        }

        /// Y la dirección contraria: entradas iguales dan bytes iguales. Sin esto, una codificación
        /// que metiera basura no determinista pasaría el test de arriba sin problema.
        #[test]
        fn entradas_iguales_dan_bytes_iguales(
            v in 0i64..1_000_000, h in 0u32..100_000, cb in any::<bool>(), l: u8,
        ) {
            let (mut b1, mut b2) = (Vec::new(), Vec::new());
            entrada_a_bytes(&mut b1, &con_lock(v, h, cb, l));
            entrada_a_bytes(&mut b2, &con_lock(v, h, cb, l));
            prop_assert_eq!(b1, b2);
        }

        /// Y lo mismo para las claves: dos outpoints distintos, dos claves distintas.
        #[test]
        fn claves_distintas_para_outpoints_distintos(t1: u8, i1: u32, t2: u8, i2: u32) {
            let (o1, o2) = (op(t1, i1), op(t2, i2));
            prop_assert_eq!(o1 == o2, clave(&o1) == clave(&o2));
        }
    }
}
