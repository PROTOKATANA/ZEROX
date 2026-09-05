//! **Matar el proceso a mitad de una escritura y comprobar que el almacén queda coherente.**
//!
//! # Lo que este test NO pretende demostrar
//!
//! Que RocksDB sea atómico. Eso ya lo demuestra RocksDB con `db_crashtest.py`, que corre en su CI
//! en dos modos —`kill -9` y puntos de fallo inyectados con `SyncPoint`— con años de fuzzing
//! detrás. Repetirlo aquí sería gastar tiempo en verificar a un tercero.
//!
//! # Lo que sí prueba
//!
//! Que el almacén **reabre coherente** tras un `SIGKILL` en cualquier punto: que la punta nunca
//! menciona una cabecera que no está, que no hay agujeros en el índice de alturas, y que el UTXO
//! set nunca va por delante de la cadena. Y de paso valida nuestra configuración de recuperación
//! —`PointInTimeRecovery`, C-STORE-10— contra colas de WAL truncadas de verdad.
//!
//! # ⚠️ Lo que NO consigue probar, y conviene saberlo
//!
//! **No caza de forma fiable una operación lógica partida en dos `db.write()`**, que es el fallo
//! de C-STORE-07 y el que ya existió aquí con `fijar_punta` fuera del lote.
//!
//! Comprobado, no supuesto: se mutó `aplicar_lote` para escribir la punta en su propio lote y
//! **antes** de las cabeceras —el orden prohibido y la partición prohibida, las dos a la vez— y el
//! test **pasó tres veces de tres**. La razón es aritmética: la ventana entre las dos escrituras
//! dura nanosegundos, y diez `kill` repartidos por milisegundos no caen dentro. Subirlo a miles de
//! rondas lo haría inviable en CI.
//!
//! Para una propiedad **estructural** hace falta una comprobación estructural, no una carrera de
//! probabilidades: la hace `una_operacion_logica_es_una_sola_escritura` en `disco.rs`, que lee el
//! código y cuenta.
//!
//! # Por qué la ruta es matar un proceso de verdad
//!
//! `rust-rocksdb` **no expone** `SyncPoint` ni `FaultInjectionTestEnv` — comprobado buscándolos en
//! el índice completo de la API de la versión pineada: cero coincidencias. La ruta whitebox de
//! RocksDB no está disponible desde Rust sin escribir C++ propio. Queda la blackbox, que es la que
//! el propio RocksDB usa para la mitad de sus pruebas de recuperación.
//!
//! Sin dependencias nuevas: el binario de test se relanza a sí mismo con una variable de entorno, y
//! `Child::kill` ya manda `SIGKILL` en Unix.

#![cfg(feature = "rocksdb")]
#![expect(
    clippy::expect_used,
    clippy::unwrap_used,
    clippy::panic,
    reason = "los tests fallan con panic por diseño"
)]

use std::io::{BufRead as _, BufReader, Write as _};
use std::path::Path;
use std::process::{Command, Stdio};

use zx_core::digest::{BlockHash, Digest, MerkleRoot};
use zx_core::preimage::block::BlockHeader;
use zx_storage::AlmacenEnDisco;
use zx_storage::almacen::{AlmacenCadena, Punta};
use zx_storage::utxo::DeltaUtxo;

/// Con esta variable puesta, el binario de test se comporta como el trabajador al que se mata.
const VAR_RUTA: &str = "ZX_MATAR_A_MITAD_RUTA";
/// Cuántas veces se repite el experimento, matando en un punto distinto cada vez.
const RONDAS: u32 = 10;
const RAMA: u32 = 0xc478_80ea;

fn cabecera(altura: u32, prev: BlockHash) -> BlockHeader {
    BlockHeader {
        consensus_branch_id: RAMA,
        prev_hash: prev,
        merkle_root: MerkleRoot::from_digest(Digest::from_bytes([(altura % 251) as u8; 32])),
        timestamp: 1_788_480_000 + u64::from(altura) * 120,
        bits: 0x1d00_ffff,
        nonce: u64::from(altura),
        height: altura,
    }
}

fn coinbase(altura: u32) -> zx_core::tx::Tx {
    zx_core::tx::Tx {
        version: 1,
        inputs: vec![],
        outputs: vec![zx_core::tx::TxOut {
            value: zx_core::amount::Amount::nuevo(1_000 + i64::from(altura)).unwrap(),
            lock: zx_core::tx::Lock::PubKey {
                pubkey: zx_core::firma::ClavePublica::desde_bytes([9; 32]),
            },
        }],
        lock_time: 0,
        expiry_height: altura,
    }
}

/// El trabajador: avanza la cadena en bucle y anuncia cada avance, hasta que lo maten.
fn trabajar(ruta: &Path) -> ! {
    let almacen = AlmacenEnDisco::abrir(ruta).expect("abre");

    // Se retoma donde estuviera, que es lo que haría un nodo tras reiniciar.
    let (mut altura, mut prev) = match almacen.punta().expect("punta") {
        Some(p) => (p.altura + 1, p.hash),
        None => (0, BlockHash::from_digest(Digest::from_bytes([0; 32]))),
    };

    let salida = std::io::stdout();
    loop {
        let c = cabecera(altura, prev);
        prev = c.block_hash();
        let punta = Punta { hash: prev, altura };
        almacen
            .aplicar_lote(core::slice::from_ref(&c), punta)
            .expect("aplica el lote");

        // Y, por separado, finalizar un bloque atrasado: son dos operaciones lógicas distintas, y
        // el test tiene que cubrir también la ventana ENTRE ellas.
        if altura >= 3 {
            let fin = altura - 3;
            let d = DeltaUtxo::de_bloque(&[coinbase(fin)], fin, RAMA).expect("delta");
            almacen.finalizar(fin, &d).expect("finaliza");
        }

        let mut s = salida.lock();
        writeln!(s, "AVANCE {altura}").expect("anuncia");
        s.flush().expect("vacía");
        drop(s);

        altura += 1;
    }
}

/// **El invariante: ningún componente del estado puede ir por delante de otro.**
///
/// Se comprueba tras reabrir. Quedarse **corto** es legítimo —es lo que un `kill -9` produce, y el
/// nodo lo arregla resincronizando—; que la punta mencione una cabecera que no está, o que el UTXO
/// set diga una altura que la cadena no alcanza, no lo es.
///
/// Devuelve la altura alcanzada, para que quien llame pueda comprobar que el test no se ha quedado
/// vacío. Devolverla en vez de abrir el almacén otra vez no es estética: **la segunda apertura
/// fallaba**, porque la primera todavía tenía el fichero de bloqueo de RocksDB.
fn comprobar(ruta: &Path, ronda: u32) -> u32 {
    let a = AlmacenEnDisco::abrir(ruta).expect("reabre tras el kill -9");

    let Some(p) = a.punta().expect("punta") else {
        // Nada escrito todavía: legítimo si se mató muy pronto.
        assert_eq!(
            a.altura_finalizada().expect("finalizada"),
            None,
            "ronda {ronda}: sin punta pero con altura finalizada — el UTXO va por delante de la cadena"
        );
        return 0;
    };

    // C-STORE-01 · la punta apunta a algo que existe.
    assert!(
        a.cabecera(&p.hash).expect("lee").is_some(),
        "ronda {ronda}: la punta menciona una cabecera que no está guardada"
    );
    assert_eq!(
        a.hash_en_altura(p.altura).expect("lee"),
        Some(p.hash),
        "ronda {ronda}: el índice de alturas no coincide con la punta"
    );

    // Sin agujeros: toda altura hasta la punta tiene su cabecera.
    for h in 0..=p.altura {
        let hash = a.hash_en_altura(h).expect("lee").unwrap_or_else(|| {
            panic!(
                "ronda {ronda}: falta la altura {h}, con la punta en {}",
                p.altura
            )
        });
        assert!(
            a.cabecera(&hash).expect("lee").is_some(),
            "ronda {ronda}: la altura {h} apunta a una cabecera que no está"
        );
    }

    // C-STORE-06 · el UTXO set nunca por delante de la cadena de cabeceras.
    if let Some(fin) = a.altura_finalizada().expect("finalizada") {
        assert!(
            fin <= p.altura,
            "ronda {ronda}: finalizado hasta {fin} con la cadena solo hasta {}",
            p.altura
        );
    }

    p.altura
}

#[test]
fn matar_a_mitad_de_escritura_no_deja_el_almacen_incoherente() {
    // ── ¿Somos el hijo? ──────────────────────────────────────────────────────
    if let Ok(ruta) = std::env::var(VAR_RUTA) {
        trabajar(Path::new(&ruta));
    }

    let exe = std::env::current_exe().expect("ruta del propio binario");
    let mut alcanzadas: Vec<u32> = Vec::new();

    for ronda in 1..=RONDAS {
        let dir = tempfile::tempdir().expect("tempdir");

        let mut hijo = Command::new(&exe)
            .args([
                "--exact",
                "matar_a_mitad_de_escritura_no_deja_el_almacen_incoherente",
                "--nocapture",
            ])
            .env(VAR_RUTA, dir.path())
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .spawn()
            .expect("lanza al trabajador");

        // Se espera a la PRIMERA señal —confirma que el trabajador abrió y escribe— y a partir de
        // ahí se le deja correr una espera distinta en cada ronda antes de matarlo.
        //
        // La primera versión leía N señales y mataba justo después de la N-ésima: eso sincroniza el
        // `kill` con el final de una escritura, y entonces nunca cae **a mitad** de ninguna. Con una
        // espera en microsegundos el trabajador sigue escribiendo mientras tanto, y el golpe cae
        // donde caiga — que es todo el sentido de la prueba.
        let mut arrancó = false;
        let salida = hijo.stdout.take().expect("stdout");
        let mut lector = BufReader::new(salida);
        let mut linea = String::new();
        while lector.read_line(&mut linea).unwrap_or(0) > 0 {
            if linea.starts_with("AVANCE ") {
                arrancó = true;
                break;
            }
            linea.clear();
        }
        assert!(
            arrancó,
            "ronda {ronda}: el trabajador no llegó a escribir nada. Si esto salta, el test no está \
             probando nada y lleva sin hacerlo desde que se rompiera lo que lo impide."
        );
        std::thread::sleep(std::time::Duration::from_micros(u64::from(ronda) * 211));

        // SIGKILL: ni destructores, ni cierre de la base de datos, ni volcado. `wait` no es
        // opcional — sin él, el hijo sigue teniendo el fichero de bloqueo de RocksDB y la
        // reapertura falla con `Resource temporarily unavailable`.
        hijo.kill().expect("mata al trabajador");
        hijo.wait().expect("lo entierra");

        alcanzadas.push(comprobar(dir.path(), ronda));
    }

    // **Que el test no se vuelva vacío en silencio.** Si un día el trabajador dejara de escribir,
    // `comprobar` aprobaría cada ronda por la vía rápida —«sin punta, legítimo»— y este archivo
    // seguiría en verde sin probar nada. Que las alturas alcanzadas varíen demuestra dos cosas: que
    // hubo trabajo, y que el golpe cayó en puntos distintos.
    let maxima = alcanzadas.iter().copied().max().unwrap_or(0);
    assert!(
        maxima > 0,
        "ninguna ronda llegó a escribir una punta: el test no está probando nada"
    );
    let distintas = {
        let mut v = alcanzadas.clone();
        v.sort_unstable();
        v.dedup();
        v.len()
    };
    assert!(
        distintas > 1,
        "todas las rondas murieron en el mismo punto ({alcanzadas:?}): el `kill` está \
         sincronizado con la escritura y nunca cae a mitad"
    );
}
