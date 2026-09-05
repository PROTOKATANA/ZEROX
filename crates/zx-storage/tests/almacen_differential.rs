//! Test diferencial: **memoria y disco deben responder igual** (SPEC §15.1, **C-STORE-04**).
//!
//! # Por qué este archivo es el que de verdad prueba RocksDB
//!
//! "RocksDB funciona" no significa nada sin algo contra lo que contrastarlo. Aquí la misma
//! secuencia de operaciones corre contra las dos implementaciones y se exige que respondan
//! **idénticamente** — no parecido, idéntico.
//!
//! Es la misma disciplina que el verificador CPU frente al kernel GPU, y por la misma razón:
//! **H-001 ocurrió porque el kernel no tenía contra qué compararse.** Un almacén que devuelve
//! cabeceras ligeramente distintas produce nodos que discrepan sobre la cadena, y el síntoma
//! aparece lejísimos de la causa.
//!
//! Corre solo con `--features rocksdb`. Sin la feature, este archivo compila a nada.

#![cfg(feature = "rocksdb")]
#![expect(
    clippy::expect_used,
    clippy::unwrap_used,
    reason = "los tests fallan con panic por diseño"
)]

use zx_core::digest::{BlockHash, Digest, MerkleRoot};
use zx_core::preimage::block::BlockHeader;
use zx_storage::almacen::{AlmacenCadena, Punta};
use zx_storage::utxo::DeltaUtxo;
use zx_storage::{AlmacenEnDisco, AlmacenEnMemoria};

fn cabecera(altura: u32) -> BlockHeader {
    BlockHeader {
        consensus_branch_id: 0xc478_80ea,
        prev_hash: BlockHash::from_digest(Digest::from_bytes([(altura % 256) as u8; 32])),
        merkle_root: MerkleRoot::from_digest(Digest::from_bytes([((altura * 7) % 256) as u8; 32])),
        timestamp: 1_788_480_000 + u64::from(altura) * 120,
        bits: 0x1d00_ffff,
        nonce: u64::from(altura) * 1_000_003,
        height: altura,
    }
}

/// Corre la misma secuencia contra los dos y compara **cada** respuesta.
#[test]
fn los_dos_almacenes_responden_igual() {
    let dir = tempfile::tempdir().expect("tempdir");
    let disco = AlmacenEnDisco::abrir(dir.path()).expect("abre");
    let mem = AlmacenEnMemoria::nuevo();

    let cs: Vec<_> = (0..40).map(cabecera).collect();
    for c in &cs {
        disco.guardar_cabecera(c).expect("disco guarda");
        mem.guardar_cabecera(c).expect("memoria guarda");
    }

    for c in &cs {
        let h = c.block_hash();
        assert_eq!(
            disco.cabecera(&h).unwrap(),
            mem.cabecera(&h).unwrap(),
            "cabecera por hash, altura {}",
            c.height
        );
        assert_eq!(
            disco.hash_en_altura(c.height).unwrap(),
            mem.hash_en_altura(c.height).unwrap(),
            "hash por altura {}",
            c.height
        );
    }

    // Y las que no existen: "no lo tengo" también debe coincidir.
    for n in [200u32, 1_000, u32::MAX] {
        assert_eq!(
            disco.hash_en_altura(n).unwrap(),
            mem.hash_en_altura(n).unwrap(),
            "altura inexistente {n}"
        );
    }
    let ajeno = BlockHash::from_digest(Digest::from_bytes([0xfe; 32]));
    assert_eq!(
        disco.cabecera(&ajeno).unwrap(),
        mem.cabecera(&ajeno).unwrap()
    );
    assert_eq!(disco.cuerpo(&ajeno).unwrap(), mem.cuerpo(&ajeno).unwrap());
    assert_eq!(
        disco.tiene_cuerpo(&ajeno).unwrap(),
        mem.tiene_cuerpo(&ajeno).unwrap(),
        "un cuerpo que no está: los dos backends deben decir que no"
    );

    // Cuerpos, incluido uno vacío y uno grande.
    for (i, c) in cs.iter().enumerate().take(5) {
        let h = c.block_hash();
        let cuerpo = vec![(i % 256) as u8; i * 5_000];
        disco.guardar_cuerpo(&h, &cuerpo).unwrap();
        mem.guardar_cuerpo(&h, &cuerpo).unwrap();
        // `tiene_cuerpo` responde sin materializar el valor, así que es una ruta de código
        // distinta de `cuerpo` en el backend de disco (`get_pinned_cf` frente a `get_cf`). Tiene
        // que dar el mismo resultado, y por eso se comprueba aquí y no solo en uno.
        assert!(
            disco.tiene_cuerpo(&h).unwrap(),
            "disco dice que no lo tiene"
        );
        assert!(
            mem.tiene_cuerpo(&h).unwrap(),
            "memoria dice que no lo tiene"
        );
        assert_eq!(
            disco.cuerpo(&h).unwrap(),
            mem.cuerpo(&h).unwrap(),
            "cuerpo de {} bytes",
            cuerpo.len()
        );
    }

    assert_eq!(
        disco.punta().unwrap(),
        mem.punta().unwrap(),
        "vacía al principio"
    );

    let ultima = cs.last().unwrap();
    let p = Punta {
        hash: ultima.block_hash(),
        altura: ultima.height,
    };
    disco.fijar_punta(p).unwrap();
    mem.fijar_punta(p).unwrap();
    assert_eq!(disco.punta().unwrap(), mem.punta().unwrap());
    assert_eq!(disco.punta().unwrap(), Some(p));
}

/// **C-STORE-01 en los dos.** Ninguno acepta una punta sin cabecera.
///
/// Si solo lo comprobara memoria, el bug solo aparecería en producción.
#[test]
fn ninguno_acepta_una_punta_sin_cabecera() {
    let dir = tempfile::tempdir().expect("tempdir");
    let disco = AlmacenEnDisco::abrir(dir.path()).expect("abre");
    let mem = AlmacenEnMemoria::nuevo();

    let p = Punta {
        hash: cabecera(9).block_hash(),
        altura: 9,
    };
    assert!(disco.fijar_punta(p).is_err(), "disco MUST rechazar");
    assert!(mem.fijar_punta(p).is_err(), "memoria MUST rechazar");
}

/// **Lo que memoria no puede probar: que los datos sobreviven a cerrar y reabrir.**
///
/// Es la razón de ser del backend de disco. Sin este test, lo único demostrado sería que responde
/// igual **mientras el proceso vive**.
#[test]
fn los_datos_sobreviven_a_reabrir_el_almacen() {
    let dir = tempfile::tempdir().expect("tempdir");
    let cs: Vec<_> = (0..10).map(cabecera).collect();
    let ultima = cs.last().unwrap();
    let cuerpo = vec![0xab; 4096];

    {
        let a = AlmacenEnDisco::abrir(dir.path()).expect("abre");
        for c in &cs {
            a.guardar_cabecera(c).unwrap();
        }
        a.guardar_cuerpo(&ultima.block_hash(), &cuerpo).unwrap();
        a.fijar_punta(Punta {
            hash: ultima.block_hash(),
            altura: ultima.height,
        })
        .unwrap();
        a.sincronizar().unwrap();
    } // se cierra aquí

    let a = AlmacenEnDisco::abrir(dir.path()).expect("reabre");
    assert_eq!(
        a.punta().unwrap(),
        Some(Punta {
            hash: ultima.block_hash(),
            altura: ultima.height
        }),
        "la punta sobrevive"
    );
    for c in &cs {
        assert_eq!(a.cabecera(&c.block_hash()).unwrap(), Some(*c));
    }
    assert_eq!(a.cuerpo(&ultima.block_hash()).unwrap(), Some(cuerpo));
}

/// **C-STORE-03 · el orden de las claves de altura es el numérico, no el lexicográfico.**
///
/// La altura se codifica en big-endian a propósito. Con little-endian, la altura 256 se ordenaría
/// antes que la 2 —sus bytes son `00 01 00 00` frente a `02 00 00 00`— y cualquier recorrido por
/// rango daría la cadena desordenada. Es la clase de fallo que no se ve hasta pasar los 256
/// bloques.
#[test]
fn las_alturas_se_ordenan_numericamente() {
    let dir = tempfile::tempdir().expect("tempdir");
    let a = AlmacenEnDisco::abrir(dir.path()).expect("abre");

    // Alturas que cruzan los bordes de byte: ahí es donde little-endian rompería.
    for h in [1u32, 2, 255, 256, 257, 65_535, 65_536] {
        a.guardar_cabecera(&cabecera(h)).unwrap();
    }
    for h in [1u32, 2, 255, 256, 257, 65_535, 65_536] {
        assert_eq!(
            a.hash_en_altura(h).unwrap(),
            Some(cabecera(h).block_hash()),
            "altura {h}"
        );
    }

    assert!(
        2u32.to_be_bytes() < 256u32.to_be_bytes(),
        "big-endian ordena 2 antes que 256"
    );
    assert!(
        256u32.to_le_bytes() < 2u32.to_le_bytes(),
        "little-endian lo haría al revés — este es el fallo que se evita"
    );
}

/// **C-STORE-07 · `aplicar_lote` da el mismo resultado en los dos backends.**
///
/// La operación que en disco es un `WriteBatch` y en memoria es un solo `lock`. Si divergen, el
/// almacén real hace algo distinto de la implementación de referencia — y la de referencia es la
/// que dice qué es correcto.
#[test]
fn aplicar_lote_deja_a_los_dos_igual() {
    let dir = tempfile::tempdir().expect("tempdir");
    let disco = AlmacenEnDisco::abrir(dir.path()).expect("abre");
    let mem = AlmacenEnMemoria::nuevo();

    let cs: Vec<_> = (1..=6).map(cabecera).collect();
    let ultima = cs.last().expect("hay cabeceras");
    let p = Punta {
        hash: ultima.block_hash(),
        altura: ultima.height,
    };

    disco.aplicar_lote(&cs, p).expect("disco aplica");
    mem.aplicar_lote(&cs, p).expect("memoria aplica");

    assert_eq!(disco.punta().unwrap(), mem.punta().unwrap());
    assert_eq!(disco.punta().unwrap(), Some(p));
    for c in &cs {
        let h = c.block_hash();
        assert_eq!(disco.cabecera(&h).unwrap(), mem.cabecera(&h).unwrap());
        assert_eq!(
            disco.hash_en_altura(c.height).unwrap(),
            mem.hash_en_altura(c.height).unwrap(),
            "altura {}",
            c.height
        );
    }
}

/// **Y si la punta no cuadra, ninguno escribe NADA.**
///
/// Es la mitad de la atomicidad que se olvida. Comprobar la punta al final y dejar las cabeceras
/// puestas sería exactamente la escritura parcial que C-STORE-07 prohíbe — y el nodo arrancaría con
/// cabeceras que su punta no referencia, sin ningún error que lo delate.
#[test]
fn un_lote_con_punta_invalida_no_escribe_nada() {
    let dir = tempfile::tempdir().expect("tempdir");
    let disco = AlmacenEnDisco::abrir(dir.path()).expect("abre");
    let mem = AlmacenEnMemoria::nuevo();

    let cs: Vec<_> = (1..=4).map(cabecera).collect();
    // Una punta que no está en el lote ni guardada de antes.
    let ajena = Punta {
        hash: cabecera(99).block_hash(),
        altura: 99,
    };

    assert!(
        disco.aplicar_lote(&cs, ajena).is_err(),
        "disco MUST rechazar"
    );
    assert!(
        mem.aplicar_lote(&cs, ajena).is_err(),
        "memoria MUST rechazar"
    );

    for c in &cs {
        let h = c.block_hash();
        assert_eq!(
            disco.cabecera(&h).unwrap(),
            None,
            "disco no debe haber escrito"
        );
        assert_eq!(
            mem.cabecera(&h).unwrap(),
            None,
            "memoria no debe haber escrito"
        );
    }
    assert_eq!(disco.punta().unwrap(), None);
    assert_eq!(mem.punta().unwrap(), None);
}

// ─────────────────────────────────────────────────────────────────────────────
// El UTXO set: C-STORE-04 extendido a lo que se añadió en B1.
// ─────────────────────────────────────────────────────────────────────────────

/// Una rama de consenso real. Nunca cero: el txid depende de ella (C-TX-05), y clavarla a cero fue
/// un fallo latente que ningún test veía porque los tests la clavaban también.
const RAMA: u32 = 0xc478_80ea;

fn salida(brek: i64, k: u8) -> zx_core::tx::TxOut {
    zx_core::tx::TxOut {
        value: zx_core::amount::Amount::nuevo(brek).unwrap(),
        lock: zx_core::tx::Lock::PubKey {
            pubkey: zx_core::firma::ClavePublica::desde_bytes([k; 32]),
        },
    }
}

fn coinbase(altura: u32, salidas: Vec<zx_core::tx::TxOut>) -> zx_core::tx::Tx {
    zx_core::tx::Tx {
        version: 1,
        inputs: vec![],
        outputs: salidas,
        lock_time: 0,
        expiry_height: altura,
    }
}

fn gasta(
    entradas: Vec<zx_core::tx::OutPoint>,
    salidas: Vec<zx_core::tx::TxOut>,
) -> zx_core::tx::Tx {
    zx_core::tx::Tx {
        version: 1,
        inputs: entradas
            .into_iter()
            .map(|o| zx_core::tx::TxIn {
                outpoint: o,
                sequence: 0xffff_fffe,
            })
            .collect(),
        outputs: salidas,
        lock_time: 0,
        expiry_height: 0,
    }
}

/// Los outpoints que un delta crea, para poder consultarlos después.
fn creados(d: &DeltaUtxo) -> Vec<zx_core::tx::OutPoint> {
    d.creados.iter().map(|(o, _)| *o).collect()
}

/// **C-STORE-04 sobre el UTXO set.** Misma secuencia, respuestas idénticas.
///
/// Se comparan también las **ausencias**: que los dos digan "no lo tengo" para lo mismo es la mitad
/// del contrato, y es la mitad que un test descuidado se salta.
#[test]
fn los_dos_conjuntos_utxo_responden_igual() {
    let dir = tempfile::tempdir().expect("tempdir");
    let disco = AlmacenEnDisco::abrir(dir.path()).expect("abre");
    let mem = AlmacenEnMemoria::nuevo();

    assert_eq!(
        disco.altura_finalizada().unwrap(),
        mem.altura_finalizada().unwrap(),
        "los dos empiezan sin finalizar nada"
    );

    // Bloque 1: solo coinbase, con dos salidas.
    let cb1 = coinbase(1, vec![salida(50_000, 1), salida(25_000, 2)]);
    let d1 = DeltaUtxo::de_bloque(core::slice::from_ref(&cb1), 1, RAMA).unwrap();
    disco.finalizar(1, &d1).unwrap();
    mem.finalizar(1, &d1).unwrap();

    let nacidos = creados(&d1);
    for o in &nacidos {
        assert_eq!(
            disco.utxo(o).unwrap(),
            mem.utxo(o).unwrap(),
            "la entrada recién creada tiene que ser idéntica"
        );
        assert!(disco.utxo(o).unwrap().is_some());
    }
    assert_eq!(
        disco.altura_finalizada().unwrap(),
        mem.altura_finalizada().unwrap()
    );
    assert_eq!(disco.altura_finalizada().unwrap(), Some(1));

    // Un outpoint que no existe: los dos deben decir que no.
    let fantasma = zx_core::tx::OutPoint {
        prev_txid: zx_core::digest::TxId::from_digest(Digest::from_bytes([0xee; 32])),
        prev_index: 3,
    };
    assert_eq!(disco.utxo(&fantasma).unwrap(), mem.utxo(&fantasma).unwrap());
    assert_eq!(disco.utxo(&fantasma).unwrap(), None);

    // Bloque 2: gasta la primera salida del 1 y crea otra.
    let primera = *nacidos.first().unwrap();
    let cb2 = coinbase(2, vec![salida(10, 3)]);
    let tx = gasta(vec![primera], vec![salida(49_000, 4)]);
    let d2 = DeltaUtxo::de_bloque(&[cb2, tx], 2, RAMA).unwrap();
    disco.finalizar(2, &d2).unwrap();
    mem.finalizar(2, &d2).unwrap();

    // La gastada desaparece **en los dos**.
    assert_eq!(disco.utxo(&primera).unwrap(), mem.utxo(&primera).unwrap());
    assert_eq!(disco.utxo(&primera).unwrap(), None, "gastada");

    // La otra del bloque 1 sigue ahí, y las nuevas también.
    let segunda = *nacidos.get(1).unwrap();
    assert_eq!(disco.utxo(&segunda).unwrap(), mem.utxo(&segunda).unwrap());
    assert!(disco.utxo(&segunda).unwrap().is_some(), "no se tocó");
    for o in creados(&d2) {
        assert_eq!(disco.utxo(&o).unwrap(), mem.utxo(&o).unwrap());
        assert!(disco.utxo(&o).unwrap().is_some());
    }
    assert_eq!(disco.altura_finalizada().unwrap(), Some(2));
    assert_eq!(mem.altura_finalizada().unwrap(), Some(2));
}

/// **Los dos rechazan gastar lo que no existe, y los dos rechazan crear lo que ya está.**
///
/// Lo segundo es la defensa de BIP-30. Aquí no puede ocurrir —C-EMIT-04 hace único el txid de
/// coinbase— pero se comprueba igual: un `put` de RocksDB sobre una clave existente la pisa **en
/// silencio**, y el UTXO perdido solo se echaría de menos el día que alguien intentara gastarlo.
#[test]
fn ninguno_gasta_lo_que_no_hay_ni_crea_lo_que_ya_esta() {
    let dir = tempfile::tempdir().expect("tempdir");
    let disco = AlmacenEnDisco::abrir(dir.path()).expect("abre");
    let mem = AlmacenEnMemoria::nuevo();

    let cb = coinbase(1, vec![salida(1, 1)]);
    let d = DeltaUtxo::de_bloque(core::slice::from_ref(&cb), 1, RAMA).unwrap();
    disco.finalizar(1, &d).unwrap();
    mem.finalizar(1, &d).unwrap();

    // Aplicar el MISMO delta otra vez: crea algo que ya está.
    assert!(
        disco.finalizar(2, &d).is_err(),
        "disco MUST rechazar el duplicado"
    );
    assert!(
        mem.finalizar(2, &d).is_err(),
        "memoria MUST rechazar el duplicado"
    );

    // Gastar algo inexistente.
    let fantasma = zx_core::tx::OutPoint {
        prev_txid: zx_core::digest::TxId::from_digest(Digest::from_bytes([0x77; 32])),
        prev_index: 0,
    };
    let cb2 = coinbase(2, vec![salida(1, 2)]);
    let mala = DeltaUtxo::de_bloque(&[cb2, gasta(vec![fantasma], vec![])], 2, RAMA).unwrap();
    assert!(disco.finalizar(2, &mala).is_err(), "disco MUST rechazar");
    assert!(mem.finalizar(2, &mala).is_err(), "memoria MUST rechazar");

    // Y tras los rechazos, los dos siguen exactamente donde estaban.
    assert_eq!(
        disco.altura_finalizada().unwrap(),
        mem.altura_finalizada().unwrap()
    );
    assert_eq!(disco.altura_finalizada().unwrap(), Some(1), "no avanzó");
}

/// **El UTXO set sobrevive a cerrar y reabrir.** Lo único que memoria no puede demostrar.
#[test]
fn el_utxo_set_sobrevive_a_reabrir() {
    let dir = tempfile::tempdir().expect("tempdir");
    let cb = coinbase(1, vec![salida(50_000, 1)]);
    let d = DeltaUtxo::de_bloque(core::slice::from_ref(&cb), 1, RAMA).unwrap();
    let o = *creados(&d).first().unwrap();

    {
        let a = AlmacenEnDisco::abrir(dir.path()).expect("abre");
        a.finalizar(1, &d).unwrap();
        a.sincronizar().unwrap();
    }

    let b = AlmacenEnDisco::abrir(dir.path()).expect("reabre");
    assert_eq!(
        b.altura_finalizada().unwrap(),
        Some(1),
        "la altura persiste"
    );
    let recuperada = b.utxo(&o).unwrap().expect("el UTXO sigue ahí");
    assert_eq!(
        recuperada,
        d.creados.first().unwrap().1,
        "y es byte a byte el que se guardó"
    );
}
