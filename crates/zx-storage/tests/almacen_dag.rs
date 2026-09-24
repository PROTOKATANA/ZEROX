//! Preparación C1: el almacén de candidatos DAG sobre RocksDB (SPEC §15.1, C-HDR-07/09,
//! C-WIRE-07).
//!
//! # Qué prueba este archivo y qué no
//!
//! Prueba que la cola **no confiable** de candidatos guarda, reemplaza y sobrevive a cerrar y
//! reabrir, y que **no** toca las familias lineales. No prueba validez de bloque: las cabeceras
//! de fixture son *candidatas* y **no** acreditan PoAS ni sello. Guardar no es admitir.
//!
//! Corre solo con `--features rocksdb`. Sin la feature, este archivo compila a nada.

#![cfg(feature = "rocksdb")]
#![expect(
    clippy::expect_used,
    clippy::unwrap_used,
    reason = "los tests fallan con panic por diseño"
)]

use zx_core::amount::Amount;
use zx_core::digest::{BlockHash, BodyCommitment, Digest, MerkleRoot, TxId};
use zx_core::firma::ClavePublica;
use zx_core::preimage::block::BlockHeader;
use zx_core::preimage::dag::{DagBlockHeader, PadresDag, SolucionPoas};
use zx_core::tx::{Lock, OutPoint, Tx, TxIn, TxOut};
use zx_core::wire_dag::{
    BUNDLE_BYTES, BloqueDag, JustificacionPot, PotCheckpoints, bloque_dag_a_bytes,
};
use zx_storage::almacen::AlmacenCadena;
use zx_storage::{AlmacenCandidatosDag, AlmacenEnDisco, AlmacenEnMemoria};

/// Cabecera de fixture, etiquetada **candidata**: **no** es una PoAS válida. Dos llamadas con
/// distinto `marca` dan cabeceras distintas con el **mismo `slot`**.
fn cabecera_candidata(slot: u64, marca: u8) -> DagBlockHeader {
    DagBlockHeader {
        consensus_branch_id: 0xc478_80ea,
        merkle_root: MerkleRoot::from_digest(Digest::from_bytes([marca; 32])),
        timestamp: 1_788_480_000 + slot,
        height: 1,
        slot,
        pot_output: [marca; 16],
        rango_solucion: u64::from(marca),
        sol: SolucionPoas::default(),
        body_commitment: BodyCommitment::from_digest(Digest::from_bytes([marca; 32])),
        padres: PadresDag::nuevo(BlockHash::from_digest(Digest::from_bytes([0x07; 32])), &[])
            .expect("un padre seleccionado es canónico"),
        sello: [marca; 64],
    }
}

/// Cabecera **lineal** de fixture, para comprobar que la familia de cabeceras de la cadena no se
/// toca al añadir la de candidatos DAG.
fn cabecera_lineal(altura: u32) -> BlockHeader {
    BlockHeader {
        consensus_branch_id: 0xc478_80ea,
        prev_hash: BlockHash::from_digest(Digest::from_bytes([(altura % 256) as u8; 32])),
        merkle_root: MerkleRoot::from_digest(Digest::from_bytes([9; 32])),
        timestamp: 1_788_480_000 + u64::from(altura) * 120,
        bits: 0x1d00_ffff,
        nonce: u64::from(altura),
        height: altura,
    }
}

fn tx(n: u8) -> Tx {
    Tx {
        version: 1,
        inputs: vec![TxIn {
            outpoint: OutPoint {
                prev_txid: TxId::from_digest(Digest::from_bytes([n; 32])),
                prev_index: u32::from(n),
            },
            sequence: 0,
        }],
        outputs: vec![TxOut {
            value: Amount::nuevo(i64::from(n) * 100).expect("importe válido"),
            lock: Lock::PubKey {
                pubkey: ClavePublica::desde_bytes([n; 32]),
            },
        }],
        lock_time: 0,
        expiry_height: 0,
    }
}

fn justificacion(marca: u8, bundles: usize) -> JustificacionPot {
    let lista: Vec<PotCheckpoints> = (0..bundles)
        .map(|i| PotCheckpoints::desde_bytes([marca.wrapping_add(i as u8); BUNDLE_BYTES]))
        .collect();
    JustificacionPot::nueva(lista).expect("dentro del máximo de portadores")
}

fn bloque(cabecera: DagBlockHeader, justificacion: JustificacionPot) -> BloqueDag {
    BloqueDag::nuevo(
        cabecera,
        justificacion,
        vec![tx(1), tx(2)],
        vec![vec![vec![0x11; 64]], vec![vec![0x22; 64]]],
    )
    .expect("txs y testigos cuadran")
}

fn bytes_del_bloque(b: &BloqueDag) -> Vec<u8> {
    let mut v = Vec::new();
    bloque_dag_a_bytes(&mut v, b);
    v
}

/// **C-STORE-04 extendido a los candidatos DAG.** Misma secuencia, respuestas idénticas,
/// incluidas las ausencias. El backend de disco no puede inventarse un "casi válido".
#[test]
fn memoria_y_disco_responden_igual_para_candidatos_dag() {
    let dir = tempfile::tempdir().expect("tempdir");
    let disco = AlmacenEnDisco::abrir(dir.path()).expect("abre");
    let mem = AlmacenEnMemoria::nuevo();

    let c1 = cabecera_candidata(41, 0x11);
    let c2 = cabecera_candidata(41, 0x22);
    let b1 = bloque(c1, justificacion(0x11, 1));
    let b2 = bloque(c2, justificacion(0x22, 2));
    for b in [&b1, &b2] {
        disco.guardar_candidato_dag(b).expect("disco guarda");
        mem.guardar_candidato_dag(b).expect("memoria guarda");
    }

    for b in [&b1, &b2] {
        let h = b.cabecera.block_hash();
        let rd = disco.candidato_dag(&h).expect("disco lee").expect("está");
        let rm = mem.candidato_dag(&h).expect("memoria lee").expect("está");
        assert_eq!(rd, *b);
        assert_eq!(rm, *b);
        assert_eq!(bytes_del_bloque(&rd), bytes_del_bloque(b));
        assert_eq!(bytes_del_bloque(&rd), bytes_del_bloque(&rm));
    }

    // Una misma cabecera con otra justificación: los dos reemplazan igual.
    let c1b = cabecera_candidata(41, 0x22);
    assert_ne!(c1b.block_hash(), c1.block_hash());
    let b1v2 = bloque(c1, justificacion(0x33, 1));
    disco.guardar_candidato_dag(&b1v2).expect("disco reemplaza");
    mem.guardar_candidato_dag(&b1v2).expect("memoria reemplaza");
    let h1 = c1.block_hash();
    assert_eq!(
        disco.candidato_dag(&h1).unwrap(),
        mem.candidato_dag(&h1).unwrap()
    );
    assert_eq!(disco.candidato_dag(&h1).unwrap(), Some(b1v2));

    // Ausencias: los dos dicen que no, y no lo confunden con inválido.
    let ajeno = BlockHash::from_digest(Digest::from_bytes([0xfe; 32]));
    assert_eq!(disco.candidato_dag(&ajeno).unwrap(), None);
    assert_eq!(mem.candidato_dag(&ajeno).unwrap(), None);
    assert_eq!(
        disco.candidato_dag(&ajeno).unwrap(),
        mem.candidato_dag(&ajeno).unwrap()
    );
}

/// **Lo que solo el disco demuestra:** cerrar y reabrir conserva ambos candidatos con igual slot,
/// la última justificación de la entrada reemplazada y la cabecera lineal de la misma base.
#[test]
fn los_candidatos_sobreviven_a_reabrir_sin_tocar_la_cadena_lineal() {
    let dir = tempfile::tempdir().expect("tempdir");
    let c1 = cabecera_candidata(7, 0x10);
    let c2 = cabecera_candidata(7, 0x20);
    let b1 = bloque(c1, justificacion(0x10, 1));
    let b2 = bloque(c2, justificacion(0x20, 2));
    let b1v2 = bloque(c1, justificacion(0x99, 1));
    let lineal = cabecera_lineal(5);

    {
        let a = AlmacenEnDisco::abrir(dir.path()).expect("abre");
        a.guardar_candidato_dag(&b1).expect("guarda candidato 1");
        a.guardar_candidato_dag(&b2).expect("guarda candidato 2");
        a.guardar_candidato_dag(&b1v2).expect("reemplaza el 1");
        // La misma base guarda una cabecera lineal: la familia nueva no la desplaza.
        a.guardar_cabecera(&lineal).expect("guarda cabecera lineal");
        a.sincronizar().expect("sincroniza");
    }

    let a = AlmacenEnDisco::abrir(dir.path()).expect("reabre");
    assert_eq!(
        a.candidato_dag(&c1.block_hash()).unwrap(),
        Some(b1v2.clone()),
        "la sustitución sobrevive al reinicio"
    );
    assert_eq!(a.candidato_dag(&c2.block_hash()).unwrap(), Some(b2));
    let recuperado = a
        .candidato_dag(&c1.block_hash())
        .unwrap()
        .expect("el candidato reemplazado sigue ahí");
    assert_eq!(
        recuperado.justificacion, b1v2.justificacion,
        "no queda la justificación vieja"
    );
    assert_eq!(bytes_del_bloque(&recuperado), bytes_del_bloque(&b1v2));
    assert_eq!(
        a.cabecera(&lineal.block_hash()).unwrap(),
        Some(lineal),
        "la ruta lineal sigue leyendo su cabecera"
    );
    assert_eq!(a.hash_en_altura(5).unwrap(), Some(lineal.block_hash()));
}

/// **Compatibilidad hacia atrás de la familia nueva.** Un almacén creado antes de C1 solo tiene
/// las cinco familias lineales; `create_missing_column_families` añade `candidatos_dag` vacía al
/// abrirlo y la ruta lineal sigue leyendo. No es solo "reabrir con el mismo binario".
#[test]
fn un_almacen_lineal_previo_se_abre_y_gana_la_familia_de_candidatos() {
    use rocksdb::{ColumnFamilyDescriptor, DB, Options};

    let dir = tempfile::tempdir().expect("tempdir");
    let lineal = cabecera_lineal(9);

    {
        // Las CINCO familias lineales de antes de C1, en un directorio recién creado.
        let mut opts = Options::default();
        opts.create_if_missing(true);
        opts.create_missing_column_families(true);
        let familias: Vec<_> = ["cabeceras", "alturas", "cuerpos", "meta", "utxo"]
            .into_iter()
            .map(|n| ColumnFamilyDescriptor::new(n, Options::default()))
            .collect();
        let db = DB::open_cf_descriptors(&opts, dir.path(), familias).expect("abre el antiguo");
        db.put_cf(
            db.cf_handle("cabeceras").expect("familia cabeceras"),
            lineal.block_hash().as_bytes(),
            zx_core::wire::cabecera_a_bytes(&lineal),
        )
        .expect("guarda la cabecera lineal");
        db.put_cf(
            db.cf_handle("alturas").expect("familia alturas"),
            lineal.height.to_be_bytes(),
            lineal.block_hash().as_bytes(),
        )
        .expect("guarda la altura");
        db.flush().expect("sincroniza");
    }

    let a = AlmacenEnDisco::abrir(dir.path()).expect("abre y crea la familia nueva");
    assert_eq!(
        a.cabecera(&lineal.block_hash()).unwrap(),
        Some(lineal),
        "la cabecera lineal previa sigue ahí"
    );
    assert_eq!(a.hash_en_altura(9).unwrap(), Some(lineal.block_hash()));

    // Y la familia nueva existe y funciona en esa misma base.
    let c = cabecera_candidata(9, 0x77);
    let b = bloque(c, justificacion(0x77, 1));
    a.guardar_candidato_dag(&b).expect("guarda candidato");
    assert_eq!(a.candidato_dag(&c.block_hash()).unwrap(), Some(b));
}
