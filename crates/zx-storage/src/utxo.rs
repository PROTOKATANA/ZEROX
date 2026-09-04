//! Conjunto de salidas no gastadas y datos de deshacer (SPEC §12, C-REORG-01..03).
//!
//! # Qué es consensus-critical aquí y qué no
//!
//! El almacén —RocksDB, memoria, lo que sea— **no** lo es. Lo que sí lo es es **qué se guarda para
//! poder revertir** y **en qué orden se aplica**. Por eso la lógica vive tras un trait y el backend
//! es intercambiable: el motor de base de datos no debe poder cambiar el resultado del consenso.
//!
//! # El orden del rollback no es un detalle
//!
//! `C-REORG-02` exige deshacer en orden **inverso** de transacción e inverso de entrada dentro de
//! cada transacción, y comprobar las salidas **antes** de borrarlas. Esa comparación previa no es
//! paranoia: es la detección de corrupción. Si lo que hay en el conjunto no es lo que el bloque
//! creó, el estado ya estaba mal y seguir empeoraría las cosas en silencio.
//!
//! # Atomicidad
//!
//! `C-REORG-03`: un reorg **MUST** ser atómico frente a cualquier consulta externa. Si un solo
//! bloque de la rama nueva falla al conectar, se vuelve **exactamente** al tip anterior. Aquí eso
//! se consigue trabajando sobre una copia y publicándola solo al final — la misma estrategia de dos
//! fases que usa Monero con `rollback_blockchain_switching`.

use std::collections::HashMap;

use zx_consensus::validacion::{ConjuntoUtxo, EntradaUtxo};
use zx_core::tx::{OutPoint, SpentOutput, Tx};

use crate::error::StorageError;

/// Datos necesarios para deshacer un bloque (C-REORG-01).
///
/// Por cada transacción no coinbase y por cada una de sus entradas, **en el orden de la
/// transacción**, se guarda el UTXO consumido **completo**: importe, condición de bloqueo, altura
/// de creación y marca de coinbase. Con eso basta para reconstruirlo sin releer el bloque que lo
/// originó.
#[derive(Clone, PartialEq, Eq, Debug, Default)]
pub struct UndoData {
    /// `consumidos[i]` son los UTXO que gastó la transacción `i+1` del bloque (la 0 es la coinbase,
    /// que no gasta nada), en el orden de sus entradas.
    pub consumidos: Vec<Vec<(OutPoint, EntradaUtxo)>>,
    /// Outpoints que el bloque **creó**, para poder retirarlos al deshacer.
    pub creados: Vec<OutPoint>,
}

/// Conjunto de UTXO en memoria.
///
/// El backend persistente (RocksDB) implementará el mismo contrato; esta versión existe para que la
/// lógica de aplicar y revertir sea testeable sin arrastrar una base de datos, y para que quede
/// claro que **el motor no participa en el consenso**.
#[derive(Clone, Debug, Default)]
pub struct ConjuntoEnMemoria {
    mapa: HashMap<OutPoint, EntradaUtxo>,
}

impl ConjuntoUtxo for ConjuntoEnMemoria {
    fn buscar(&self, o: &OutPoint) -> Option<EntradaUtxo> {
        self.mapa.get(o).cloned()
    }
}

impl ConjuntoEnMemoria {
    /// Un conjunto vacío.
    #[must_use]
    pub fn nuevo() -> Self {
        Self::default()
    }

    /// Número de salidas no gastadas.
    #[must_use]
    pub fn len(&self) -> usize {
        self.mapa.len()
    }

    /// ¿Está vacío?
    #[must_use]
    pub fn is_empty(&self) -> bool {
        self.mapa.is_empty()
    }

    /// Inserta una salida. Devuelve error si el outpoint ya existía.
    ///
    /// Que sea un error y no una sobrescritura importa: dos salidas con el mismo outpoint significa
    /// que algo está mal aguas arriba, y sobrescribir lo escondería.
    ///
    /// # Errores
    /// [`StorageError::OutpointDuplicado`].
    pub fn insertar(&mut self, o: OutPoint, e: EntradaUtxo) -> Result<(), StorageError> {
        if self.mapa.insert(o, e).is_some() {
            return Err(StorageError::OutpointDuplicado);
        }
        Ok(())
    }

    /// Retira una salida, devolviéndola.
    ///
    /// # Errores
    /// [`StorageError::OutpointAusente`] si no estaba.
    pub fn retirar(&mut self, o: &OutPoint) -> Result<EntradaUtxo, StorageError> {
        self.mapa.remove(o).ok_or(StorageError::OutpointAusente)
    }
}

/// Aplica un bloque al conjunto y devuelve los datos para deshacerlo (C-REORG-01).
///
/// Trabaja sobre una **copia** y solo la publica si todo sale bien: si cualquier paso falla, el
/// conjunto original queda intacto (C-REORG-03).
///
/// `txs[0]` **MUST** ser la coinbase. Sus salidas se insertan como cualquier otra, marcadas como
/// coinbase para que C-EMIT-05 pueda aplicar la madurez.
///
/// # Errores
/// [`StorageError`] si alguna entrada no existe o algún outpoint creado ya estaba.
pub fn aplicar_bloque(
    conjunto: &mut ConjuntoEnMemoria,
    txs: &[Tx],
    altura: u32,
) -> Result<UndoData, StorageError> {
    // Copia de trabajo: la atomicidad de C-REORG-03 sale de aquí.
    let mut trabajo = conjunto.clone();
    let mut undo = UndoData::default();

    let (coinbase, resto) = txs
        .split_first()
        .ok_or(StorageError::BloqueSinTransacciones)?;

    // Se gastan primero todas las entradas y solo después se crean las salidas. Al revés, una
    // transacción del bloque podría gastar una salida creada por otra del mismo bloque, que
    // C-BLK-09 prohíbe y que aquí quedaría permitida por accidente.
    for tx in resto {
        let mut de_esta = Vec::with_capacity(tx.inputs.len());
        for entrada in &tx.inputs {
            let consumido = trabajo.retirar(&entrada.outpoint)?;
            de_esta.push((entrada.outpoint, consumido));
        }
        undo.consumidos.push(de_esta);
    }

    for (i, tx) in txs.iter().enumerate() {
        let es_coinbase = i == 0;
        let txid = zx_core::preimage::tx::txid(tx, 0);
        for (j, salida) in tx.outputs.iter().enumerate() {
            let o = OutPoint {
                prev_txid: txid,
                prev_index: u32::try_from(j).map_err(|_| StorageError::IndiceFueraDeRango)?,
            };
            trabajo.insertar(
                o,
                EntradaUtxo {
                    salida: SpentOutput {
                        value: salida.value,
                        lock: salida.lock.clone(),
                    },
                    altura_creacion: altura,
                    es_coinbase,
                },
            )?;
            undo.creados.push(o);
        }
    }
    let _ = coinbase;

    *conjunto = trabajo;
    Ok(undo)
}

/// Deshace un bloque (C-REORG-02).
///
/// El orden **MUST** ser: primero retirar las salidas que el bloque creó —comprobando que están, que
/// es la detección de corrupción—, y después reinsertar los UTXO consumidos en orden **inverso de
/// transacción** e **inverso de entrada** dentro de cada una.
///
/// Como [`aplicar_bloque`], trabaja sobre una copia y la publica solo al final.
///
/// # Errores
/// [`StorageError`] si el estado no es el que el undo data describe — señal de que el conjunto ya
/// estaba corrupto.
pub fn revertir_bloque(
    conjunto: &mut ConjuntoEnMemoria,
    undo: &UndoData,
) -> Result<(), StorageError> {
    let mut trabajo = conjunto.clone();

    // 1 · Retirar lo creado. `retirar` falla si no está: esa es la comprobación de corrupción que
    //     C-REORG-02 exige hacer **antes** de borrar.
    for o in &undo.creados {
        trabajo.retirar(o)?;
    }

    // 2 · Reinsertar lo consumido, en orden inverso de transacción e inverso de entrada.
    //
    //     Con un conjunto sin duplicados el orden es indiferente para el resultado final, pero se
    //     respeta igualmente: es lo que el SPEC especifica, y un backend con log de escrituras
    //     —RocksDB con WAL, por ejemplo— sí produce secuencias distintas según el orden.
    for de_esta in undo.consumidos.iter().rev() {
        for (o, e) in de_esta.iter().rev() {
            trabajo.insertar(*o, e.clone())?;
        }
    }

    *conjunto = trabajo;
    Ok(())
}

/// Deshace varios bloques, **del tip hacia el punto de fork** (C-REORG-02).
///
/// `undos` va en orden de cadena; se recorre al revés. Nunca en paralelo, nunca en otro orden.
///
/// # Errores
/// La de [`revertir_bloque`]. Si alguno falla, el conjunto queda **intacto** (C-REORG-03).
pub fn revertir_hasta_el_fork(
    conjunto: &mut ConjuntoEnMemoria,
    undos: &[UndoData],
) -> Result<(), StorageError> {
    let mut trabajo = conjunto.clone();
    for undo in undos.iter().rev() {
        revertir_bloque(&mut trabajo, undo)?;
    }
    *conjunto = trabajo;
    Ok(())
}

#[cfg(test)]
#[expect(
    clippy::unwrap_used,
    clippy::expect_used,
    reason = "los tests fallan con panic por diseño"
)]
mod tests {
    use super::{
        ConjuntoEnMemoria, UndoData, aplicar_bloque, revertir_bloque, revertir_hasta_el_fork,
    };
    use crate::error::StorageError;
    use zx_consensus::validacion::{ConjuntoUtxo, EntradaUtxo, VERSION_TX};
    use zx_core::amount::Amount;
    use zx_core::firma::ClavePublica;
    use zx_core::preimage::tx::txid;
    use zx_core::tx::{Lock, OutPoint, SpentOutput, Tx, TxIn, TxOut};

    fn salida(brek: i64, k: u8) -> TxOut {
        TxOut {
            value: Amount::nuevo(brek).unwrap(),
            lock: Lock::PubKey {
                pubkey: ClavePublica::desde_bytes([k; 32]),
            },
        }
    }

    fn coinbase(altura: u32, salidas: Vec<TxOut>) -> Tx {
        Tx {
            version: VERSION_TX,
            inputs: vec![],
            outputs: salidas,
            lock_time: 0,
            expiry_height: altura,
        }
    }

    fn gasta(entradas: Vec<OutPoint>, salidas: Vec<TxOut>) -> Tx {
        Tx {
            version: VERSION_TX,
            inputs: entradas
                .into_iter()
                .map(|o| TxIn {
                    outpoint: o,
                    sequence: 0,
                })
                .collect(),
            outputs: salidas,
            lock_time: 0,
            expiry_height: 0,
        }
    }

    fn punto(tx: &Tx, i: u32) -> OutPoint {
        OutPoint {
            prev_txid: txid(tx, 0),
            prev_index: i,
        }
    }

    /// Aplicar y luego deshacer devuelve el conjunto **exactamente** a su estado anterior.
    ///
    /// Es la propiedad de fondo de todo el undo data: si no se cumpliera, un reorg dejaría el estado
    /// desviado y el nodo validaría con un UTXO set que no corresponde a su cadena.
    #[test]
    fn aplicar_y_deshacer_es_la_identidad() {
        let mut c = ConjuntoEnMemoria::nuevo();

        // Bloque 1: solo coinbase.
        let cb1 = coinbase(1, vec![salida(1000, 1), salida(500, 2)]);
        let undo1 = aplicar_bloque(&mut c, core::slice::from_ref(&cb1), 1).unwrap();
        assert_eq!(c.len(), 2);
        let tras_b1: Vec<_> = {
            let mut v: Vec<_> = [punto(&cb1, 0), punto(&cb1, 1)]
                .into_iter()
                .map(|o| (o, c.buscar(&o)))
                .collect();
            v.sort_by_key(|(o, _)| o.prev_index);
            v
        };

        // Bloque 2: gasta una de las dos.
        let cb2 = coinbase(2, vec![salida(10, 3)]);
        let tx = gasta(vec![punto(&cb1, 0)], vec![salida(900, 4)]);
        let undo2 = aplicar_bloque(&mut c, &[cb2, tx], 2).unwrap();
        assert_ne!(c.len(), 2, "el bloque 2 cambió el conjunto");

        // Deshacer el 2: vuelta exacta al estado tras el 1.
        revertir_bloque(&mut c, &undo2).unwrap();
        assert_eq!(c.len(), 2, "misma cardinalidad");
        for (o, esperado) in &tras_b1 {
            assert_eq!(&c.buscar(o), esperado, "la salida {o:?} no volvió igual");
        }

        // Y deshacer el 1 deja el conjunto vacío.
        revertir_bloque(&mut c, &undo1).unwrap();
        assert!(
            c.is_empty(),
            "tras deshacerlo todo, el conjunto MUST quedar vacío"
        );
    }

    /// El undo data guarda el UTXO **completo**, no solo su outpoint (C-REORG-01).
    ///
    /// Sin el importe, la condición de bloqueo, la altura y la marca de coinbase, reconstruirlo
    /// exigiría releer el bloque que lo creó — que puede estar a cien mil bloques de distancia.
    #[test]
    fn el_undo_data_guarda_el_utxo_completo() {
        let mut c = ConjuntoEnMemoria::nuevo();
        let cb1 = coinbase(1, vec![salida(1000, 7)]);
        aplicar_bloque(&mut c, core::slice::from_ref(&cb1), 1).unwrap();

        let cb2 = coinbase(2, vec![salida(10, 3)]);
        let tx = gasta(vec![punto(&cb1, 0)], vec![salida(900, 4)]);
        let undo = aplicar_bloque(&mut c, &[cb2, tx], 2).unwrap();

        let (_, consumido) = undo
            .consumidos
            .first()
            .and_then(|v| v.first())
            .expect("la tx gastó una entrada");

        assert_eq!(consumido.salida.value.brek(), 1000, "importe");
        assert_eq!(consumido.altura_creacion, 1, "altura de creación");
        assert!(
            consumido.es_coinbase,
            "marca de coinbase — la necesita C-EMIT-05"
        );
        assert_eq!(
            consumido.salida.lock,
            Lock::PubKey {
                pubkey: ClavePublica::desde_bytes([7; 32])
            },
            "condición de bloqueo"
        );
    }

    /// **C-REORG-03: atomicidad.** Si aplicar falla a mitad, el conjunto queda intacto.
    #[test]
    fn un_bloque_que_falla_no_deja_el_conjunto_a_medias() {
        let mut c = ConjuntoEnMemoria::nuevo();
        let cb1 = coinbase(1, vec![salida(1000, 1)]);
        aplicar_bloque(&mut c, core::slice::from_ref(&cb1), 1).unwrap();
        let antes = c.len();

        // Segunda tx gasta algo inexistente: el bloque entero debe fallar.
        let cb2 = coinbase(2, vec![salida(10, 3)]);
        let buena = gasta(vec![punto(&cb1, 0)], vec![salida(900, 4)]);
        let mala = gasta(
            vec![OutPoint {
                prev_txid: txid(&cb1, 0),
                prev_index: 99,
            }],
            vec![salida(1, 5)],
        );

        let r = aplicar_bloque(&mut c, &[cb2, buena, mala], 2);
        assert!(matches!(r, Err(StorageError::OutpointAusente)), "{r:?}");
        assert_eq!(
            c.len(),
            antes,
            "C-REORG-03: el conjunto MUST quedar exactamente como estaba"
        );
        assert!(
            c.buscar(&punto(&cb1, 0)).is_some(),
            "la salida que la primera tx gastó sigue ahí"
        );
    }

    /// Y lo mismo al deshacer: un undo data incoherente no deja el conjunto a medias.
    #[test]
    fn un_undo_incoherente_no_deja_el_conjunto_a_medias() {
        let mut c = ConjuntoEnMemoria::nuevo();
        let cb = coinbase(1, vec![salida(1000, 1)]);
        aplicar_bloque(&mut c, core::slice::from_ref(&cb), 1).unwrap();
        let antes = c.len();

        let falso = UndoData {
            consumidos: vec![],
            creados: vec![punto(&cb, 0), punto(&cb, 42)], // el segundo no existe
        };
        assert!(revertir_bloque(&mut c, &falso).is_err());
        assert_eq!(c.len(), antes, "el conjunto MUST quedar intacto");
    }

    /// **La detección de corrupción de C-REORG-02.** Deshacer algo que no está es un error, no un
    /// no-op silencioso.
    #[test]
    fn deshacer_lo_que_no_esta_es_un_error() {
        let mut c = ConjuntoEnMemoria::nuevo();
        let cb = coinbase(1, vec![salida(1000, 1)]);
        let undo = aplicar_bloque(&mut c, core::slice::from_ref(&cb), 1).unwrap();

        revertir_bloque(&mut c, &undo).unwrap();
        // Deshacerlo dos veces: la segunda MUST fallar.
        assert!(
            matches!(
                revertir_bloque(&mut c, &undo),
                Err(StorageError::OutpointAusente)
            ),
            "deshacer dos veces MUST detectarse, no pasar en silencio"
        );
    }

    /// Insertar dos veces el mismo outpoint es un error, no una sobrescritura.
    ///
    /// Sobrescribir escondería una colisión de txid — precisamente lo que C-EMIT-04 existe para
    /// impedir en las coinbases.
    #[test]
    fn un_outpoint_duplicado_es_un_error() {
        let mut c = ConjuntoEnMemoria::nuevo();
        let o = OutPoint {
            prev_txid: zx_core::digest::TxId::from_digest(zx_core::digest::Digest::from_bytes(
                [1; 32],
            )),
            prev_index: 0,
        };
        let e = EntradaUtxo {
            salida: SpentOutput {
                value: Amount::nuevo(1).unwrap(),
                lock: Lock::PubKey {
                    pubkey: ClavePublica::desde_bytes([0; 32]),
                },
            },
            altura_creacion: 0,
            es_coinbase: false,
        };
        c.insertar(o, e.clone()).unwrap();
        assert!(matches!(
            c.insertar(o, e),
            Err(StorageError::OutpointDuplicado)
        ));
    }

    /// **Un reorg completo: deshacer varios bloques del tip hacia el fork y reconstruir.**
    ///
    /// El estado resultante MUST coincidir con el de un nodo que solo hubiera visto la rama
    /// ganadora — es la contraparte de estado del test diferencial de `zx-consensus`.
    #[test]
    fn un_reorg_devuelve_el_estado_al_punto_de_fork() {
        let cb0 = coinbase(0, vec![salida(1_000_000, 1)]);

        // Cadena que vive el reorg.
        let mut vivido = ConjuntoEnMemoria::nuevo();
        aplicar_bloque(&mut vivido, core::slice::from_ref(&cb0), 0).unwrap();
        let en_el_fork = vivido.len();

        // Rama A: tres bloques.
        let mut undos_a = Vec::new();
        let mut ultimo = punto(&cb0, 0);
        for h in 1..=3u32 {
            let cb = coinbase(h, vec![salida(10, u8::try_from(h).unwrap())]);
            let tx = gasta(vec![ultimo], vec![salida(100, 9)]);
            ultimo = punto(&tx, 0);
            undos_a.push(aplicar_bloque(&mut vivido, &[cb, tx], h).unwrap());
        }
        assert_ne!(vivido.len(), en_el_fork, "la rama A cambió el estado");

        // Deshacer la rama A entera, del tip al fork.
        revertir_hasta_el_fork(&mut vivido, &undos_a).unwrap();
        assert_eq!(vivido.len(), en_el_fork, "vuelta al punto de fork");

        // Un nodo limpio que solo vio el bloque 0.
        let mut limpio = ConjuntoEnMemoria::nuevo();
        aplicar_bloque(&mut limpio, core::slice::from_ref(&cb0), 0).unwrap();

        assert_eq!(vivido.len(), limpio.len());
        assert_eq!(
            vivido.buscar(&punto(&cb0, 0)),
            limpio.buscar(&punto(&cb0, 0)),
            "tras el reorg el estado MUST ser idéntico al de un nodo limpio"
        );
    }

    /// Las salidas de la coinbase se marcan como tales: sin eso, C-EMIT-05 no podría aplicar la
    /// madurez y un minero gastaría su recompensa al bloque siguiente.
    #[test]
    fn las_salidas_de_coinbase_quedan_marcadas() {
        let mut c = ConjuntoEnMemoria::nuevo();
        let cb = coinbase(5, vec![salida(1000, 1)]);
        let tx = gasta(vec![], vec![salida(1, 2)]);
        // Una tx sin entradas que no sea la primera no debería existir en un bloque válido, pero
        // aquí se comprueba solo el marcado del almacén.
        aplicar_bloque(&mut c, &[cb.clone(), tx.clone()], 5).unwrap();

        let de_coinbase = c.buscar(&punto(&cb, 0)).unwrap();
        assert!(
            de_coinbase.es_coinbase,
            "la primera tx del bloque es la coinbase"
        );
        assert_eq!(de_coinbase.altura_creacion, 5);

        let normal = c.buscar(&punto(&tx, 0)).unwrap();
        assert!(!normal.es_coinbase, "las demás no");
    }
}
