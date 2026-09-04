//! Validez de transacción y de bloque (SPEC §5.4, §6.4).
//!
//! # El peso es una magnitud del protocolo, no del serializador
//!
//! `C-WGT-02` calcula el peso con una **fórmula fija**, no con el tamaño que produzca el encoder.
//! Es deliberado y corrige una contradicción real del SPEC (H-006): `C-ENC-08` declara que Cap'n
//! Proto no es consensus-critical, pero el peso alimenta la validez de bloque y el subsidio del
//! minero. Si dependiera del serializador, dos nodos calcularían subsidios distintos para el mismo
//! bloque — y ninguna suite de vectores de hashing lo habría detectado, porque los digests
//! coincidirían mientras el consenso divergía por otro lado.
//!
//! Consecuencia: el tamaño en el cable puede diferir del peso de consenso. Es correcto.

use zx_core::amount::Amount;
use zx_core::tx::{Lock, OutPoint, SpentOutput, Tx};

use crate::emision::COINBASE_MATURITY;
use crate::error::ConsensusError;
use crate::peso::MAX_TX_WEIGHT;

/// Versión de transacción admitida en v1.0 (C-TX-07).
pub const VERSION_TX: u32 = 1;

/// Una salida tal y como vive en el UTXO set.
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct EntradaUtxo {
    /// Importe y condición de bloqueo.
    pub salida: SpentOutput,
    /// Altura del bloque que la creó — necesaria para la madurez de coinbase.
    pub altura_creacion: u32,
    /// Si vino de una coinbase (C-EMIT-05).
    pub es_coinbase: bool,
}

/// Acceso de solo lectura al conjunto de salidas no gastadas.
///
/// Deliberadamente mínimo: la validación no necesita más, y cuanto menos pueda mirar, menos
/// superficie hay para que se cuele una fuente de no-determinismo.
pub trait ConjuntoUtxo {
    /// Devuelve la salida si existe y no está gastada.
    fn buscar(&self, outpoint: &OutPoint) -> Option<EntradaUtxo>;
}

/// Bytes que ocupa un `CompactSize` para ese valor (C-ENC-05, forma mínima).
const fn tam_compact_size(v: u64) -> u64 {
    if v < 0xFD {
        1
    } else if v <= 0xFFFF {
        3
    } else if v <= 0xFFFF_FFFF {
        5
    } else {
        9
    }
}

/// Longitud de la codificación canónica de un `Lock` (C-TX-09b).
#[must_use]
pub fn tam_lock(lock: &Lock) -> u64 {
    match lock {
        // 0x00 ‖ pubkey(32)
        Lock::PubKey { .. } => 33,
        // 0x01 ‖ k(1) ‖ CompactSize(n) ‖ n × pubkey(32)
        Lock::MultiSig { pubkeys, .. } => {
            let n = pubkeys.len() as u64;
            2 + tam_compact_size(n) + 32 * n
        }
        // 0x02 ‖ hash(32) ‖ receiver(32) ‖ sender(32) ‖ timeout(4)
        Lock::Htlc { .. } => 101,
    }
}

/// Peso de una transacción (C-WGT-02).
///
/// Fórmula del protocolo, no tamaño del serializador. Incluye el testigo, porque el testigo ocupa
/// banda y disco reales y eso es lo que el peso existe para acotar.
#[must_use]
pub fn peso_tx(tx: &Tx, testigos: &[Vec<u8>]) -> u64 {
    let n_in = tx.inputs.len() as u64;
    let n_out = tx.outputs.len() as u64;
    let n_wit = testigos.len() as u64;

    let mut w = 12; // version ‖ lock_time ‖ expiry_height
    w += tam_compact_size(n_in) + n_in * 40;
    w += tam_compact_size(n_out);
    for s in &tx.outputs {
        w += 8 + tam_lock(&s.lock);
    }
    w += tam_compact_size(n_wit);
    for t in testigos {
        let len = t.len() as u64;
        w += tam_compact_size(len) + len;
    }
    w
}

/// Resultado de validar una transacción: su fee, para que el bloque lo agregue.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct TxValidada {
    /// `Σ entradas − Σ salidas` (C-TX-14).
    pub fee: Amount,
    /// Peso según C-WGT-02.
    pub peso: u64,
}

/// Valida una transacción **no coinbase** contra el UTXO set (§5.4).
///
/// Cubre C-TX-07, C-TX-08, C-TX-12..C-TX-14, C-TX-16..C-TX-18 y la madurez de C-EMIT-05.
/// **No** verifica firmas: eso es [`crate::testigo::satisface`], que necesita el sighash de cada
/// entrada y se llama aparte.
///
/// # Errores
/// La variante de [`ConsensusError`] que corresponda a la regla incumplida.
pub fn validar_tx<U: ConjuntoUtxo>(
    tx: &Tx,
    testigos: &[Vec<u8>],
    utxos: &U,
    altura: u32,
) -> Result<TxValidada, ConsensusError> {
    // C-TX-07 · versión dentro del conjunto activo.
    if tx.version != VERSION_TX {
        return Err(ConsensusError::VersionDeTxNoAdmitida {
            version: tx.version,
        });
    }

    // C-TX-17 · al menos una entrada y una salida.
    if tx.inputs.is_empty() || tx.outputs.is_empty() {
        return Err(ConsensusError::TxSinEntradasOSalidas);
    }

    // Un testigo por entrada, ni más ni menos: si sobran, hay bytes que nadie valida.
    if testigos.len() != tx.inputs.len() {
        return Err(ConsensusError::TestigoMalFormado {
            motivo: "MUST haber exactamente un testigo por entrada",
        });
    }

    // C-TX-08 · expiración.
    if tx.expiry_height != 0 && altura > tx.expiry_height {
        return Err(ConsensusError::TxExpirada {
            altura,
            expiry_height: tx.expiry_height,
        });
    }

    // C-TX-18 · tope de peso.
    let peso = peso_tx(tx, testigos);
    if peso > MAX_TX_WEIGHT {
        return Err(ConsensusError::TxExcedeMaximo {
            peso,
            maximo: MAX_TX_WEIGHT,
        });
    }

    // C-TX-13 y C-TX-16 · las entradas existen, y no se repite ningún outpoint.
    let mut vistos: Vec<OutPoint> = Vec::with_capacity(tx.inputs.len());
    let mut total_entradas = Amount::CERO;

    for entrada in &tx.inputs {
        // C-TX-16 · ni siquiera dentro de la misma transacción.
        if vistos.contains(&entrada.outpoint) {
            return Err(ConsensusError::DobleGastoInterno);
        }
        vistos.push(entrada.outpoint);

        let utxo = utxos
            .buscar(&entrada.outpoint)
            .ok_or(ConsensusError::EntradaInexistenteOGastada)?;

        // C-EMIT-05 · madurez de coinbase.
        if utxo.es_coinbase {
            let maduro_en = utxo
                .altura_creacion
                .checked_add(COINBASE_MATURITY)
                .ok_or(ConsensusError::DesbordamientoAritmetico)?;
            if altura < maduro_en {
                return Err(ConsensusError::CoinbaseInmaduro { altura, maduro_en });
            }
        }

        total_entradas = total_entradas
            .suma_comprobada(utxo.salida.value)
            .ok_or(ConsensusError::DesbordamientoAritmetico)?;
    }

    // C-TX-12 lo garantiza el tipo `Amount`: no existe uno fuera de rango.
    let total_salidas = Amount::suma(tx.outputs.iter().map(|s| s.value))
        .map_err(|_| ConsensusError::DesbordamientoAritmetico)?;

    // C-TX-14 · Σ entradas ≥ Σ salidas.
    let fee = total_entradas
        .resta_comprobada(total_salidas)
        .ok_or(ConsensusError::SalidasExcedenEntradas)?;

    Ok(TxValidada { fee, peso })
}

/// Comprueba que ninguna transacción del bloque gasta un outpoint que ya gastó otra (C-BLK-09).
///
/// Es distinto de C-TX-16, que solo mira **dentro** de una transacción.
///
/// # Errores
/// [`ConsensusError::DobleGastoEnBloque`] con el outpoint repetido.
pub fn comprobar_sin_doble_gasto_en_bloque(txs: &[Tx]) -> Result<(), ConsensusError> {
    let mut vistos: Vec<OutPoint> = Vec::new();
    for tx in txs {
        for e in &tx.inputs {
            if vistos.contains(&e.outpoint) {
                return Err(ConsensusError::DobleGastoEnBloque);
            }
            vistos.push(e.outpoint);
        }
    }
    Ok(())
}

#[cfg(test)]
#[expect(clippy::unwrap_used, reason = "los tests fallan con panic por diseño")]
mod tests {
    use super::{
        ConjuntoUtxo, EntradaUtxo, VERSION_TX, comprobar_sin_doble_gasto_en_bloque, peso_tx,
        tam_lock, validar_tx,
    };
    use crate::emision::COINBASE_MATURITY;
    use crate::error::ConsensusError;
    use crate::peso::MAX_TX_WEIGHT;
    use zx_core::amount::Amount;
    use zx_core::digest::{Digest, TxId};
    use zx_core::firma::ClavePublica;
    use zx_core::tx::{Lock, OutPoint, SpentOutput, Tx, TxIn, TxOut};

    /// UTXO set de juguete: una lista, que para un test es más auditable que un mapa.
    struct UtxosFalsos(Vec<(OutPoint, EntradaUtxo)>);

    impl ConjuntoUtxo for UtxosFalsos {
        fn buscar(&self, o: &OutPoint) -> Option<EntradaUtxo> {
            self.0.iter().find(|(k, _)| k == o).map(|(_, v)| v.clone())
        }
    }

    fn clave(n: u8) -> ClavePublica {
        ClavePublica::desde_bytes([n; 32])
    }

    fn outpoint(n: u8) -> OutPoint {
        OutPoint {
            prev_txid: TxId::from_digest(Digest::from_bytes([n; 32])),
            prev_index: 0,
        }
    }

    fn entrada(n: u8) -> TxIn {
        TxIn {
            outpoint: outpoint(n),
            sequence: 0,
        }
    }

    fn salida(brek: i64) -> TxOut {
        TxOut {
            value: Amount::nuevo(brek).unwrap(),
            lock: Lock::PubKey {
                pubkey: clave(0xEE),
            },
        }
    }

    fn utxo(brek: i64, es_coinbase: bool, altura_creacion: u32) -> EntradaUtxo {
        EntradaUtxo {
            salida: SpentOutput {
                value: Amount::nuevo(brek).unwrap(),
                lock: Lock::PubKey { pubkey: clave(1) },
            },
            altura_creacion,
            es_coinbase,
        }
    }

    fn tx_simple() -> Tx {
        Tx {
            version: VERSION_TX,
            inputs: vec![entrada(1)],
            outputs: vec![salida(900)],
            lock_time: 0,
            expiry_height: 0,
        }
    }

    fn utxos_con(brek: i64) -> UtxosFalsos {
        UtxosFalsos(vec![(outpoint(1), utxo(brek, false, 0))])
    }

    fn testigos(n: usize) -> Vec<Vec<u8>> {
        vec![vec![0u8; 96]; n]
    }

    #[test]
    fn una_tx_correcta_valida_y_devuelve_su_fee() {
        let tx = tx_simple();
        let v = validar_tx(&tx, &testigos(1), &utxos_con(1000), 10).unwrap();
        assert_eq!(v.fee.brek(), 100, "1000 − 900");
        assert!(v.peso > 0);
    }

    /// C-TX-14: no se puede crear valor de la nada.
    #[test]
    fn las_salidas_no_pueden_exceder_las_entradas() {
        let mut tx = tx_simple();
        tx.outputs = vec![salida(1_001)];
        let e = validar_tx(&tx, &testigos(1), &utxos_con(1000), 10).unwrap_err();
        assert!(matches!(e, ConsensusError::SalidasExcedenEntradas));
    }

    /// Fee cero es válido: C-TX-15 dice que **no existe tarifa mínima de consenso**.
    #[test]
    fn una_tx_con_fee_cero_es_valida() {
        let mut tx = tx_simple();
        tx.outputs = vec![salida(1000)];
        let v = validar_tx(&tx, &testigos(1), &utxos_con(1000), 10).unwrap();
        assert_eq!(
            v.fee,
            Amount::CERO,
            "C-TX-15: un fee de cero NO invalida el bloque"
        );
    }

    #[test]
    fn se_rechaza_una_version_desconocida() {
        let mut tx = tx_simple();
        tx.version = 2;
        assert!(matches!(
            validar_tx(&tx, &testigos(1), &utxos_con(1000), 10),
            Err(ConsensusError::VersionDeTxNoAdmitida { version: 2 })
        ));
    }

    #[test]
    fn se_rechaza_una_tx_sin_entradas_o_sin_salidas() {
        let mut sin_in = tx_simple();
        sin_in.inputs.clear();
        assert!(validar_tx(&sin_in, &[], &utxos_con(1000), 10).is_err());

        let mut sin_out = tx_simple();
        sin_out.outputs.clear();
        assert!(validar_tx(&sin_out, &testigos(1), &utxos_con(1000), 10).is_err());
    }

    /// C-TX-13: gastar algo que no existe.
    #[test]
    fn se_rechaza_una_entrada_inexistente() {
        let tx = tx_simple();
        let vacio = UtxosFalsos(vec![]);
        assert!(matches!(
            validar_tx(&tx, &testigos(1), &vacio, 10),
            Err(ConsensusError::EntradaInexistenteOGastada)
        ));
    }

    /// **C-TX-16**: el mismo outpoint dos veces dentro de la misma transacción.
    #[test]
    fn se_rechaza_el_doble_gasto_interno() {
        let mut tx = tx_simple();
        tx.inputs = vec![entrada(1), entrada(1)];
        let e = validar_tx(&tx, &testigos(2), &utxos_con(1000), 10).unwrap_err();
        assert!(matches!(e, ConsensusError::DobleGastoInterno), "{e:?}");
    }

    /// **C-BLK-09**: dos transacciones distintas del mismo bloque gastando lo mismo.
    #[test]
    fn se_rechaza_el_doble_gasto_entre_txs_del_bloque() {
        let a = tx_simple();
        let b = tx_simple();
        assert!(matches!(
            comprobar_sin_doble_gasto_en_bloque(&[a, b]),
            Err(ConsensusError::DobleGastoEnBloque)
        ));

        let mut c = tx_simple();
        c.inputs = vec![entrada(2)];
        assert!(comprobar_sin_doble_gasto_en_bloque(&[tx_simple(), c]).is_ok());
    }

    /// **C-EMIT-05, con el borde exacto.** 99 confirmaciones no bastan; 100 sí.
    #[test]
    fn el_borde_exacto_de_la_madurez_de_coinbase() {
        let tx = tx_simple();
        let creado_en = 500u32;
        let utxos = UtxosFalsos(vec![(outpoint(1), utxo(1000, true, creado_en))]);
        let maduro_en = creado_en + COINBASE_MATURITY;

        let e = validar_tx(&tx, &testigos(1), &utxos, maduro_en - 1).unwrap_err();
        assert!(
            matches!(e, ConsensusError::CoinbaseInmaduro { .. }),
            "una antes: {e:?}"
        );
        assert!(
            validar_tx(&tx, &testigos(1), &utxos, maduro_en).is_ok(),
            "justo en la altura, sí"
        );
        assert!(validar_tx(&tx, &testigos(1), &utxos, maduro_en + 1).is_ok());
    }

    /// Una salida **no** coinbase no tiene madurez: se gasta al bloque siguiente.
    #[test]
    fn una_salida_normal_no_tiene_madurez() {
        let tx = tx_simple();
        let utxos = UtxosFalsos(vec![(outpoint(1), utxo(1000, false, 500))]);
        assert!(validar_tx(&tx, &testigos(1), &utxos, 501).is_ok());
    }

    /// C-TX-08: el borde de la expiración.
    #[test]
    fn el_borde_exacto_de_la_expiracion() {
        let mut tx = tx_simple();
        tx.expiry_height = 100;
        assert!(
            validar_tx(&tx, &testigos(1), &utxos_con(1000), 100).is_ok(),
            "en la altura, vale"
        );
        assert!(
            validar_tx(&tx, &testigos(1), &utxos_con(1000), 101).is_err(),
            "una después, no"
        );

        tx.expiry_height = 0;
        assert!(
            validar_tx(&tx, &testigos(1), &utxos_con(1000), u32::MAX).is_ok(),
            "0 = sin expiración"
        );
    }

    #[test]
    fn se_exige_un_testigo_por_entrada() {
        let tx = tx_simple();
        assert!(
            validar_tx(&tx, &[], &utxos_con(1000), 10).is_err(),
            "cero testigos"
        );
        assert!(
            validar_tx(&tx, &testigos(2), &utxos_con(1000), 10).is_err(),
            "uno de más"
        );
    }

    // ── Peso ─────────────────────────────────────────────────────────────────

    /// **P-020 · el ahorro de P2K, en bytes concretos.**
    ///
    /// El testigo de una entrada `PubKey` mide 64 B (solo la firma), no 96 B (clave ‖ firma). Este
    /// test fija la cuenta completa de una transacción 2-in/2-out y **calcula también** lo que
    /// pesaría con P2KH, para que el número del 17 % no sea una afirmación de un documento sino algo
    /// que el código reproduce. Si alguien reintroduce la clave en el testigo, esto falla.
    #[test]
    fn p2k_ahorra_32_bytes_por_entrada() {
        const TESTIGO_P2K: usize = 64; // sig(64)
        const TESTIGO_P2KH: usize = 96; // pubkey(32) ‖ sig(64)

        let tx = Tx {
            version: VERSION_TX,
            inputs: vec![entrada(1), entrada(2)],
            outputs: vec![salida(1_000), salida(2_000)],
            lock_time: 0,
            expiry_height: 0,
        };

        let p2k = peso_tx(&tx, &[vec![0u8; TESTIGO_P2K], vec![0u8; TESTIGO_P2K]]);
        let p2kh = peso_tx(&tx, &[vec![0u8; TESTIGO_P2KH], vec![0u8; TESTIGO_P2KH]]);

        // 12 + CS(2) + 2·40 + CS(2) + 2·(8+33) + CS(2) + 2·(CS(64)+64)
        assert_eq!(
            p2k,
            12 + 1 + 80 + 1 + 82 + 1 + 2 * (1 + 64),
            "cuenta de P2K"
        );
        assert_eq!(p2k, 307);
        assert_eq!(p2kh, 371);

        assert_eq!(p2kh - p2k, 64, "32 bytes por cada una de las 2 entradas");
        // El ahorro está entre el 17 % y el 18 %, comprobado sin dividir ni usar floats:
        // 17·p2kh ≤ 100·(p2kh − p2k) < 18·p2kh.
        let ahorro = p2kh - p2k;
        assert!(
            17 * p2kh <= 100 * ahorro && 100 * ahorro < 18 * p2kh,
            "el ahorro MUST rondar el 17 % en una 2-in/2-out: {ahorro}/{p2kh}"
        );
    }

    #[test]
    fn el_tamano_de_lock_es_el_de_su_codificacion_canonica() {
        assert_eq!(tam_lock(&Lock::PubKey { pubkey: clave(0) }), 33, "1 + 32");
        assert_eq!(
            tam_lock(&Lock::multisig(1, vec![clave(1), clave(2)]).unwrap()),
            2 + 1 + 64,
            "1 disc + 1 k + 1 CompactSize + 2×32"
        );
        assert_eq!(
            tam_lock(&Lock::Htlc {
                hash: [1u8; 32],
                receiver: clave(2),
                sender: clave(3),
                timeout: 0
            }),
            101,
            "1 + 32·3 + 4"
        );
    }

    /// El peso crece con las entradas, con las salidas y **con el testigo**.
    ///
    /// Que incluya el testigo es lo que hace que el peso mida banda y disco reales, que es para lo
    /// que existe.
    #[test]
    fn el_peso_crece_con_todo_lo_que_ocupa_sitio() {
        let base = peso_tx(&tx_simple(), &testigos(1));

        let mut mas_entradas = tx_simple();
        mas_entradas.inputs.push(entrada(2));
        assert!(peso_tx(&mas_entradas, &testigos(2)) > base, "entradas");

        let mut mas_salidas = tx_simple();
        mas_salidas.outputs.push(salida(1));
        assert!(peso_tx(&mas_salidas, &testigos(1)) > base, "salidas");

        let testigo_gordo = vec![vec![0u8; 5_000]];
        assert!(
            peso_tx(&tx_simple(), &testigo_gordo) > base,
            "el testigo MUST contar"
        );
    }

    /// Una transparente típica 2-in 2-out ronda los ~350 B que asume el dimensionado de
    /// `ZONA_LIBRE`. Si esto se disparara, los 205 000 tx/día del SPEC dejarían de ser ciertos.
    #[test]
    fn una_tx_tipica_pesa_lo_que_asume_el_spec() {
        let tx = Tx {
            version: VERSION_TX,
            inputs: vec![entrada(1), entrada(2)],
            outputs: vec![salida(100), salida(200)],
            lock_time: 0,
            expiry_height: 0,
        };
        // Testigo PubKey: pubkey(32) ‖ sig(64).
        let p = peso_tx(&tx, &testigos(2));
        assert!(
            (300..=400).contains(&p),
            "una 2-in 2-out debería rondar los 350 B; salió {p}. El dimensionado de ZONA_LIBRE \
             (~285 tx/bloque, 205 000 tx/día) depende de esta cifra"
        );
    }

    /// C-TX-18: el tope por transacción se aplica de verdad.
    #[test]
    fn se_rechaza_una_tx_por_encima_del_maximo() {
        let tx = tx_simple();
        let enorme = vec![vec![0u8; usize::try_from(MAX_TX_WEIGHT).unwrap() + 1]];
        let e = validar_tx(&tx, &enorme, &utxos_con(1000), 10).unwrap_err();
        assert!(matches!(e, ConsensusError::TxExcedeMaximo { .. }), "{e:?}");
    }
}
