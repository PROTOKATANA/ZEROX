//! Test diferencial: **la longitud serializada de una transacción es su peso** (C-WGT-02, C-WIRE-03).
//!
//! # Por qué existe este archivo
//!
//! `C-WGT-02` define el peso con una **fórmula del protocolo**, escrita a mano, deliberadamente
//! independiente de cualquier serializador. Esa independencia fue la corrección de **H-006**: el
//! SPEC decía antes `peso = tamaño_serializado(tx)`, y eso ataba el consenso —el peso alimenta el
//! límite de bloque y la penalización de subsidio— a los caprichos de una librería de
//! serialización.
//!
//! `zx-core::wire` produce una codificación cuya longitud debería coincidir con esa fórmula. Pero
//! **son dos definiciones independientes**, escritas en dos crates distintos, y podrían divergir.
//!
//! Se mantienen separadas **a propósito**. La alternativa —definir el peso como `bytes.len()`—
//! haría que coincidieran por construcción, y volvería a atar el consenso al serializador: cambiar
//! un byte del formato de cable cambiaría el peso de todas las transacciones, y con él la validez
//! de bloques y el subsidio. Justo lo que H-006 arregló.
//!
//! Así que en vez de acoplarlas, se comprueban una contra otra sobre transacciones **generadas al
//! azar**. Si un día divergen, falla esto — no el consenso, en producción, en silencio.

#![expect(
    clippy::expect_used,
    reason = "en un test, un expect con mensaje es más útil que propagar el error"
)]

use proptest::prelude::*;
use zx_consensus::validacion::{peso_tx, tam_lock};
use zx_core::amount::{Amount, ZX_VALUE_SANITY_LIMIT};
use zx_core::digest::{Digest, TxId};
use zx_core::firma::ClavePublica;
use zx_core::tx::{Lock, MAX_MULTISIG_KEYS, OutPoint, Tx, TxIn, TxOut};
use zx_core::wire;

/// Una clave, determinista a partir de una semilla.
fn clave(n: u8) -> ClavePublica {
    ClavePublica::desde_bytes([n; 32])
}

prop_compose! {
    fn entrada()(
        txid in any::<[u8; 32]>(),
        prev_index in any::<u32>(),
        sequence in any::<u32>(),
    ) -> TxIn {
        TxIn {
            outpoint: OutPoint {
                prev_txid: TxId::from_digest(Digest::from_bytes(txid)),
                prev_index,
            },
            sequence,
        }
    }
}

/// Genera los tres tipos de `Lock`, con `MultiSig` de tamaño variable.
///
/// Las claves se derivan del índice para garantizar unicidad: C-TX-11 rechaza repetidas, y un
/// generador que las repitiera estaría probando el rechazo en vez de la longitud.
fn lock() -> impl Strategy<Value = Lock> {
    prop_oneof![
        any::<u8>().prop_map(|n| Lock::PubKey { pubkey: clave(n) }),
        (1u8..=MAX_MULTISIG_KEYS as u8).prop_flat_map(|n| {
            (1u8..=n).prop_map(move |k| {
                let claves = (0..n).map(clave).collect();
                #[expect(
                    clippy::unwrap_used,
                    reason = "k y n construidos en rango por el generador"
                )]
                Lock::multisig(k, claves).unwrap()
            })
        }),
        (any::<[u8; 32]>(), any::<u8>(), any::<u8>(), any::<u32>()).prop_map(
            |(hash, r, s, timeout)| Lock::Htlc {
                hash,
                // r y s distintos no es requisito de C-TX-09b, pero un HTLC consigo mismo no
                // aporta nada al test y confunde al leer un contraejemplo.
                receiver: clave(r),
                sender: clave(s.wrapping_add(1)),
                timeout,
            }
        ),
    ]
}

prop_compose! {
    fn salida()(
        brek in 0i64..ZX_VALUE_SANITY_LIMIT,
        lock in lock(),
    ) -> TxOut {
        #[expect(clippy::unwrap_used, reason = "brek generado dentro del rango de C-TX-12")]
        TxOut { value: Amount::nuevo(brek).unwrap(), lock }
    }
}

prop_compose! {
    /// Una transacción con sus testigos.
    ///
    /// Los **contadores** se quedan en 0..6 para que la batería sea rápida; el umbral de
    /// `CompactSize` donde 1 byte pasa a 3 (el valor 253) lo cruza aparte
    /// `el_umbral_de_compact_size_no_descuadra_el_peso`, con un caso construido a mano.
    ///
    /// Lo que **sí** cruza ese umbral aquí es la **longitud de cada testigo** (0..300), que es el
    /// otro `CompactSize` de la codificación.
    fn tx_con_testigos()(
        version in any::<u32>(),
        lock_time in any::<u32>(),
        expiry_height in any::<u32>(),
        inputs in prop::collection::vec(entrada(), 0..6),
        outputs in prop::collection::vec(salida(), 0..6),
        testigos in prop::collection::vec(
            prop::collection::vec(any::<u8>(), 0..300),
            0..6,
        ),
    ) -> (Tx, Vec<Vec<u8>>) {
        (
            Tx { version, inputs, outputs, lock_time, expiry_height },
            testigos,
        )
    }
}

proptest! {
    /// **La invariante.** Longitud serializada == peso del protocolo, para cualquier transacción.
    #[test]
    fn la_longitud_serializada_es_el_peso_del_protocolo(
        (tx, testigos) in tx_con_testigos()
    ) {
        let mut bytes = Vec::new();
        wire::tx_a_bytes(&mut bytes, &tx, &testigos);

        let peso = peso_tx(&tx, &testigos);

        prop_assert_eq!(
            bytes.len() as u64,
            peso,
            "C-WGT-02 y C-WIRE-03 divergen: {} entradas, {} salidas, {} testigos",
            tx.inputs.len(),
            tx.outputs.len(),
            testigos.len()
        );
    }

    /// Y la vuelta completa: lo que se escribe se lee igual.
    ///
    /// Sin esto, la invariante de arriba podría cumplirse con un serializador que escribiera basura
    /// de la longitud correcta.
    #[test]
    fn la_transaccion_da_la_vuelta(
        (tx, testigos) in tx_con_testigos()
    ) {
        let mut bytes = Vec::new();
        wire::tx_a_bytes(&mut bytes, &tx, &testigos);

        let ((leida, t_leidos), resto) = wire::tx_desde_bytes(&bytes)
            .map_err(|e| TestCaseError::fail(format!("no decodifica: {e}")))?;

        prop_assert_eq!(leida, tx);
        prop_assert_eq!(t_leidos, testigos);
        prop_assert!(resto.is_empty(), "sobran {} bytes", resto.len());
    }

    /// `tam_lock` y la longitud real del `Lock` serializado coinciden.
    ///
    /// Es la misma clase de invariante un nivel más abajo: `tam_lock` alimenta a `peso_tx`, así que
    /// si se equivoca, el peso se equivoca — y el peso decide la validez de un bloque.
    #[test]
    fn el_tamano_declarado_de_lock_es_su_longitud_real(l in lock()) {
        let mut bytes = Vec::new();
        wire::lock_a_bytes(&mut bytes, &l);
        prop_assert_eq!(bytes.len() as u64, tam_lock(&l), "{:?}", l);
    }

    /// Ningún dato, por hostil que sea, hace entrar en pánico al lector de transacciones.
    ///
    /// El workspace prohíbe `panic` y `unwrap`, pero eso no cubre un índice fuera de rango. Un
    /// parser de datos de red que entra en pánico es un DoS remoto de una línea.
    #[test]
    fn ningun_byte_arbitrario_hace_entrar_en_panico_al_lector(
        basura in prop::collection::vec(any::<u8>(), 0..512)
    ) {
        let _ = wire::tx_desde_bytes(&basura);
    }

    /// Lo mismo para el lector de cabeceras.
    #[test]
    fn ningun_byte_arbitrario_hace_entrar_en_panico_al_leer_cabeceras(
        basura in prop::collection::vec(any::<u8>(), 0..256)
    ) {
        let _ = wire::cabecera_desde_bytes(&basura);
    }

    /// Y para el de `Lock`, que es el que interpreta un byte discriminante ajeno.
    #[test]
    fn ningun_byte_arbitrario_hace_entrar_en_panico_al_leer_locks(
        basura in prop::collection::vec(any::<u8>(), 0..512)
    ) {
        let _ = wire::lock_desde_bytes(&basura);
    }
}

/// **El umbral de `CompactSize`, cruzado a mano.**
///
/// Los generadores de arriba se quedan cortos a propósito, así que este es el único sitio donde se
/// prueba el punto donde un contador pasa de 1 byte a 3: el valor **253**. Es donde una fórmula de
/// longitud escrita a mano se equivoca, porque es fácil olvidar que el prefijo creció.
///
/// Se comprueban los dos lados del salto —252 y 253— en las tres listas de la codificación.
#[test]
fn el_umbral_de_compact_size_no_descuadra_el_peso() {
    for n in [1usize, 252, 253, 254, 300] {
        let tx = Tx {
            version: 1,
            inputs: (0..n)
                .map(|i| TxIn {
                    outpoint: OutPoint {
                        prev_txid: TxId::from_digest(Digest::from_bytes([(i % 256) as u8; 32])),
                        prev_index: i as u32,
                    },
                    sequence: 0,
                })
                .collect(),
            outputs: (0..n)
                .map(|i| TxOut {
                    value: Amount::CERO,
                    lock: Lock::PubKey {
                        pubkey: clave((i % 256) as u8),
                    },
                })
                .collect(),
            lock_time: 0,
            expiry_height: 0,
        };
        let testigos: Vec<Vec<u8>> = (0..n).map(|_| vec![0u8; 64]).collect();

        let mut bytes = Vec::new();
        wire::tx_a_bytes(&mut bytes, &tx, &testigos);

        assert_eq!(
            bytes.len() as u64,
            peso_tx(&tx, &testigos),
            "con {n} elementos por lista (umbral de CompactSize en 253)"
        );

        // Y sigue dando la vuelta con los contadores de 3 bytes.
        let ((leida, t), resto) = wire::tx_desde_bytes(&bytes).expect("decodifica");
        assert_eq!(leida, tx, "n={n}");
        assert_eq!(t, testigos, "n={n}");
        assert!(resto.is_empty(), "n={n}");
    }
}

/// **El umbral, también en la longitud de un testigo suelto.**
///
/// Un solo testigo de exactamente 253 bytes: el `CompactSize` de su longitud cruza el salto aunque
/// el contador de testigos siga siendo 1.
#[test]
fn el_umbral_de_compact_size_en_la_longitud_de_un_testigo() {
    for len in [252usize, 253, 254, 65_535, 65_536] {
        let tx = Tx {
            version: 1,
            inputs: vec![],
            outputs: vec![],
            lock_time: 0,
            expiry_height: 0,
        };
        let testigos = vec![vec![0xa5u8; len]];

        let mut bytes = Vec::new();
        wire::tx_a_bytes(&mut bytes, &tx, &testigos);
        assert_eq!(
            bytes.len() as u64,
            peso_tx(&tx, &testigos),
            "testigo de {len} bytes"
        );
    }
}
