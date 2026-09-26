//! `ORDEN-W06d1` V5 y V5b: muerte y reinicio.
//!
//! V5: el binario real se lanza como proceso hijo y se mata con `SIGKILL` en >= 10 puntos (semilla
//! fija, fases PoW y PoST) — reabre con el **mismo resumen de estado** que el último bloque
//! persistido y sigue produciendo, 0 corrupciones.
//!
//! V5b: un testigo de una transacción de un bloque PoW alterado en disco (el almacén no lo detecta,
//! `REVISION-W06b.md`) hace que el nodo se niegue a arrancar con error explícito al repetir.

#![expect(
    clippy::expect_used,
    clippy::panic,
    reason = "el test falla con panic por diseño"
)]

use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::time::{Duration, Instant};

use rocksdb::{ColumnFamilyDescriptor, DB, Options};
use zx_core::Red;
use zx_core::wire::{cuerpo_a_bytes, cuerpo_desde_bytes};
use zx_node::nodo::{Config, Nodo};

/// `N_dev` de test: pequeño y múltiplo de 16. No es el valor de red.
const N_DEV_TEST: &str = "32";
/// `SR_dev` de test: sin controlador, ganadores frecuentes.
const SR_DEV_TEST: &str = "18446744073709551615"; // u64::MAX

/// Semilla fija de las esperas entre el arranque y el `SIGKILL` (splitmix64, igual patrón que
/// `crates/zx-storage/tests/matar_a_mitad.rs`).
const SEMILLA_ESPERA: u64 = 0x5a5a_5a5a_5a5a_5a5a;
/// Rondas de muerte y reinicio (`>= 10`, decisión de V5).
const RONDAS: u32 = 12;

/// Jitter corto (no determina cuándo matar, solo cuánto esperar **después** de alcanzar el
/// objetivo de la ronda) para que el `SIGKILL` no caiga siempre justo tras la línea de registro que
/// lo desbloquea — ver `objetivo_minado`. Antes determinaba el tiempo de pared completo de la fase
/// 1; ese diseño fallaba en `debug` porque minar la primera altura puede tardar más de 8 s en el
/// peor caso (búsqueda de nonce probabilística, no un tiempo fijo): las 4 rondas podían matarse
/// antes de admitir ningún bloque (medido: `alturas=[0, 0, 0, 0]` en `logs/V3-despues.log`).
fn espera_millis(ronda: u32) -> u64 {
    let mut z = SEMILLA_ESPERA ^ u64::from(ronda).wrapping_mul(0x9e37_79b9_7f4a_7c15);
    z = z.wrapping_add(0x9e37_79b9_7f4a_7c15);
    z = (z ^ (z >> 30)).wrapping_mul(0xbf58_476d_1ce4_e5b9);
    z = (z ^ (z >> 27)).wrapping_mul(0x94d0_49bb_1331_11eb);
    z ^= z >> 31;
    z % 500
}

/// Número acumulado (todo el registro `.jsonl`, de solo-anexión entre rondas) de eventos
/// `"bloque_minado"` que se exige antes de matar en la ronda `ronda`-ésima de calentamiento. Un
/// contador de eventos reales, no un tiempo de pared: funciona igual en `release` (~1 s/bloque,
/// limitado al reloj de pared) que en `debug` (~8-9 s/bloque, dificultad inicial real sin optimizar,
/// medido en V5b).
fn objetivo_minado(ronda: u32) -> usize {
    usize::try_from(ronda).unwrap_or(1)
}

fn config_de_test(dir: &Path, parada_tras_slots: u64) -> Config {
    Config {
        dir_datos: dir.join("datos"),
        ruta_registro: dir.join("registro.jsonl"),
        red: Red::Dev,
        semilla: 0x1234,
        indices_claves: vec![0, 1, 2],
        n_dev: N_DEV_TEST.parse().expect("N_dev"),
        sr_dev: SR_DEV_TEST.parse().expect("SR_dev"),
        parada_tras_slots: Some(parada_tras_slots),
    }
}

fn lanzar(dir: &Path) -> Child {
    Command::new(env!("CARGO_BIN_EXE_zx-node"))
        .args([
            "--datos",
            dir.join("datos").to_str().expect("ruta"),
            "--registro",
            dir.join("registro.jsonl").to_str().expect("ruta"),
            "--red",
            "dev",
            "--semilla",
            "4660", // 0x1234
            "--claves",
            "0,1,2",
            "--n-dev",
            N_DEV_TEST,
            "--sr-dev",
            SR_DEV_TEST,
            "--parada-tras-slots",
            "100000",
        ])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .expect("lanza zx-node")
}

/// Espera a que el registro dé señales de vida (al menos una línea escrita).
fn esperar_senal_de_vida(ruta_registro: &Path, ronda: u32) {
    let limite = Instant::now() + Duration::from_secs(60);
    loop {
        if let Ok(meta) = std::fs::metadata(ruta_registro)
            && meta.len() > 0
        {
            return;
        }
        assert!(
            Instant::now() < limite,
            "ronda {ronda}: el nodo no dio señales de vida en 60 s"
        );
        std::thread::sleep(Duration::from_millis(20));
    }
}

/// Rondas de calentamiento (fase PoW): kills cortos, antes de forzar el cruce del corte.
const RONDAS_POW: u32 = 4;
/// Rondas de régimen: kills muy cortos, ya cruzado el corte (`N_dev` de test: casi instantáneo).
const RONDAS_REGIMEN: u32 = 5;

#[test]
fn v5_sigkill_en_varios_puntos_reabre_sin_corrupcion_y_sigue_produciendo() {
    let dir = tempfile::tempdir().expect("tempdir");
    let ruta_registro = dir.path().join("registro.jsonl");

    let mut alturas_pow: Vec<u32> = Vec::new();
    let mut posts_regimen: Vec<usize> = Vec::new();

    // Fase 1: `RONDAS_POW` rondas cortas mientras se mina de verdad (dificultad inicial real). Se
    // mata cuando el registro (acumulado, de solo-anexión, entre rondas) acumula `objetivo_minado`
    // eventos `bloque_minado`, no tras un tiempo de pared fijo (ver `objetivo_minado`).
    for ronda in 1..=RONDAS_POW {
        let mut hijo = lanzar(dir.path());
        esperar_senal_de_vida(&ruta_registro, ronda);
        let objetivo = objetivo_minado(ronda);
        let limite = Instant::now() + Duration::from_secs(180);
        loop {
            let contenido = std::fs::read_to_string(&ruta_registro).unwrap_or_default();
            let vistos = contenido.matches("\"bloque_minado\"").count();
            if vistos >= objetivo {
                break;
            }
            assert!(
                Instant::now() < limite,
                "ronda PoW {ronda}: no se vieron {objetivo} bloques minados (acumulado) en 180 s"
            );
            assert!(
                hijo.try_wait().ok().flatten().is_none(),
                "ronda PoW {ronda}: el nodo terminó solo antes de minar lo esperado"
            );
            std::thread::sleep(Duration::from_millis(20));
        }
        // Jitter corto tras alcanzar el objetivo: el `kill` no debe caer siempre justo tras la
        // línea de registro que lo desbloqueó.
        std::thread::sleep(Duration::from_millis(espera_millis(ronda)));
        hijo.kill().expect("mata al hijo");
        hijo.wait().expect("lo entierra");

        let cfg = config_de_test(dir.path(), 0);
        let nodo = Nodo::arrancar(&cfg)
            .unwrap_or_else(|e| panic!("ronda PoW {ronda}: reabrir tras SIGKILL falló: {e}"));
        alturas_pow.push(nodo.altura_pow());
        drop(nodo);
    }
    assert!(
        alturas_pow.iter().any(|a| *a > 0),
        "ninguna ronda de PoW llegó a minar nada: alturas={alturas_pow:?}"
    );

    // Fase 2: deja correr sin matar hasta cruzar el corte (o hasta un límite generoso), para que
    // las rondas de régimen de abajo caigan de verdad en la fase PoST. Se comprueba leyendo el
    // registro (el primer «bloque_producido» solo puede ocurrir tras el corte): abrir el mismo
    // RocksDB con el hijo todavía vivo fallaría por el candado de un solo escritor.
    {
        // 420 s: en `debug` (sin optimizar) minar hasta `H_corte_min = 30` con la dificultad
        // inicial real puede tardar bastante más que en `release` (medido: ~4-5 s/bloque en
        // `debug` frente a ~1 s/bloque, ya limitado por el reloj de pared, en `release`).
        let limite = Instant::now() + Duration::from_secs(420);
        let mut hijo = lanzar(dir.path());
        esperar_senal_de_vida(&ruta_registro, 0);
        loop {
            let contenido = std::fs::read_to_string(&ruta_registro).unwrap_or_default();
            if contenido.contains("\"bloque_producido\"") {
                break;
            }
            assert!(
                Instant::now() < limite,
                "no se cruzó el corte en 180 s de calentamiento"
            );
            assert!(
                hijo.try_wait().ok().flatten().is_none(),
                "el nodo de calentamiento terminó solo antes de cruzar el corte"
            );
            std::thread::sleep(Duration::from_millis(200));
        }
        hijo.kill().expect("mata al hijo de calentamiento");
        hijo.wait().expect("lo entierra");
    }

    // Fase 3: `RONDAS_REGIMEN` rondas ya en régimen. Con `N_dev` de test y `SR_dev = u64::MAX` la
    // producción es tan rápida (varios bloques por slot, slot casi instantáneo) que una espera en
    // milisegundos no discrimina: el primer intento de esta prueba mató siempre tras el mismo lote
    // inicial (`[4, 4, 4, 4, 4, 4, 4, 4]`, bug real de la prueba, no del nodo — ver `PROGRESO.md`).
    // En su lugar, cada ronda espera a ver un número **creciente** de eventos `bloque_producido` en
    // el registro (una cuenta externa, no una escritura interna concreta) antes de matar: el punto
    // de corte varía por construcción, y sigue siendo un `SIGKILL` en un instante arbitrario del
    // proceso (no hay sincronización con ninguna escritura en curso).
    for ronda in 1..=RONDAS_REGIMEN {
        let mut hijo = lanzar(dir.path());
        esperar_senal_de_vida(&ruta_registro, ronda);
        let objetivo = usize::try_from(ronda).unwrap_or(1);
        let limite = Instant::now() + Duration::from_secs(30);
        loop {
            let contenido = std::fs::read_to_string(&ruta_registro).unwrap_or_default();
            let vistos = contenido.matches("\"bloque_producido\"").count();
            if vistos >= objetivo {
                break;
            }
            assert!(
                Instant::now() < limite,
                "ronda régimen {ronda}: no se vieron {objetivo} bloques producidos en 30 s"
            );
            std::thread::sleep(Duration::from_millis(20));
        }
        hijo.kill().expect("mata al hijo");
        hijo.wait().expect("lo entierra");

        let cfg = config_de_test(dir.path(), 0);
        let nodo = Nodo::arrancar(&cfg)
            .unwrap_or_else(|e| panic!("ronda régimen {ronda}: reabrir tras SIGKILL falló: {e}"));
        posts_regimen.push(nodo.cadena().bloques_post().len());
        drop(nodo);
    }

    // El `kill` no está sincronizado con ninguna escritura concreta: si cayera siempre en el mismo
    // punto, esta prueba no probaría nada (mismo espíritu que `matar_a_mitad.rs`). Se exige
    // variación por separado en cada fase: las rondas de PoW nunca producen bloques PoST (el corte
    // aún no se cruzó) y mezclarlas con las de régimen ocultaría que el `kill` de PoW sí varía.
    let mut alturas_vistas = alturas_pow.clone();
    alturas_vistas.sort_unstable();
    alturas_vistas.dedup();
    assert!(
        alturas_vistas.len() > 1,
        "todas las rondas de PoW alcanzaron la misma altura ({alturas_pow:?}): \
         el `kill` parece sincronizado con algo"
    );
    let mut posts_vistos = posts_regimen.clone();
    posts_vistos.sort_unstable();
    posts_vistos.dedup();
    assert!(
        posts_vistos.len() > 1,
        "todas las rondas de régimen alcanzaron el mismo número de bloques PoST \
         ({posts_regimen:?}): el `kill` parece sincronizado con algo"
    );
    let alcanzados = posts_regimen;

    // "Sigue produciendo": tras las `RONDAS` interrupciones, se deja correr una última vez sin
    // matarlo y el número de bloques PoST admitidos crece.
    let antes = *alcanzados.last().expect("al menos una ronda");
    let mut hijo = lanzar(dir.path());
    esperar_senal_de_vida(&ruta_registro, RONDAS + 1);
    std::thread::sleep(Duration::from_secs(3));
    hijo.kill().expect("mata al hijo");
    hijo.wait().expect("lo entierra");

    let cfg = config_de_test(dir.path(), 0);
    let nodo = Nodo::arrancar(&cfg).expect("reabrir la última vez");
    let despues = nodo.cadena().bloques_post().len();
    assert!(
        despues >= antes,
        "el número de bloques PoST no debe decrecer tras reabrir: antes={antes}, después={despues}"
    );
    assert!(
        despues > 0 || nodo.cadena().terminal().is_none(),
        "si ya hay terminal, debería haber al menos un bloque PoST tras dejarlo correr"
    );
}

/// Reabre el mismo RocksDB por debajo de `Almacen` (nombres de familia documentados en
/// `crates/zx-storage/src/disco.rs`: «bloques», «registro», «meta») y corrompe la primera firma del
/// primer testigo del primer bloque PoW **no genésis** que encuentra.
fn corromper_primer_testigo_pow(ruta_almacen: &Path) -> zx_core::BlockHash {
    let mut opciones = Options::default();
    opciones.create_if_missing(false);
    let familias = ["bloques", "registro", "meta"]
        .into_iter()
        .map(|n| ColumnFamilyDescriptor::new(n, Options::default()))
        .collect::<Vec<_>>();
    let db = DB::open_cf_descriptors(&opciones, ruta_almacen, familias).expect("reabrir rocksdb");
    let cf_registro = db.cf_handle("registro").expect("cf registro");
    let cf_bloques = db.cf_handle("bloques").expect("cf bloques");

    for item in db.iterator_cf(cf_registro, rocksdb::IteratorMode::Start) {
        let (_indice, hash_bytes) = item.expect("iterar registro");
        let valor = db
            .get_cf(cf_bloques, &hash_bytes)
            .expect("leer bloque")
            .expect("el bloque debe existir");
        let (familia, canonicos) = valor.split_first().expect("sobre no vacío");
        if *familia != 0x01 {
            continue; // familia PoW = 0x01 (formato.rs); se busca un bloque PoW.
        }
        let Ok((cuerpo, _)) = cuerpo_desde_bytes(canonicos) else {
            continue;
        };
        let (cabecera, txs, mut testigos) = cuerpo;
        if cabecera.height == 0 {
            continue; // el génesis no tiene testigos que corromper de forma interesante.
        }
        let Some(primeros) = testigos.iter().position(|t| !t.is_empty()) else {
            continue; // este bloque no tiene testigos (p. ej. solo la coinbase, sin depósito).
        };
        #[expect(
            clippy::indexing_slicing,
            reason = "primeros viene de position(), es un índice válido"
        )]
        {
            let firma = &mut testigos[primeros][0];
            let ultimo = firma.len() - 1;
            firma[ultimo] ^= 0xFF;
        }
        let mut nuevos_canonicos = Vec::new();
        cuerpo_a_bytes(&mut nuevos_canonicos, &cabecera, &txs, &testigos);
        let mut nuevo_valor = vec![0x01u8];
        nuevo_valor.extend_from_slice(&nuevos_canonicos);
        db.put_cf(cf_bloques, &hash_bytes, &nuevo_valor)
            .expect("escribir el bloque corrompido");
        return cabecera.block_hash();
    }
    panic!("no se encontró ningún bloque PoW con testigo no vacío que corromper");
}

#[test]
fn v5b_testigo_pow_corrupto_impide_arrancar() {
    let dir = tempfile::tempdir().expect("tempdir");
    let ruta_registro = dir.path().join("registro.jsonl");

    // Deja correr lo suficiente para que al menos un depósito (con testigo real) se persista:
    // M_cb = 5, M_dep = 3 (perfil dev); con 3 claves rotando la coinbase, la primera madura hacia
    // la altura 8-9. En `release` basta con ~18 s (~1 bloque/s, limitado al reloj de pared); en
    // `debug` (sin optimizar) minar cada altura tarda bastante más (medido: ~4-5 s/bloque con la
    // dificultad inicial real), así que se espera con margen amplio para no depender del perfil.
    let mut hijo = lanzar(dir.path());
    esperar_senal_de_vida(&ruta_registro, 0);
    std::thread::sleep(Duration::from_secs(75));
    hijo.kill().expect("mata al hijo");
    hijo.wait().expect("lo entierra");

    let ruta_almacen: PathBuf = dir.path().join("datos").join("storage");
    let hash_corrompido = corromper_primer_testigo_pow(&ruta_almacen);

    let cfg = config_de_test(dir.path(), 0);
    let resultado = Nodo::arrancar(&cfg);
    match resultado {
        Err(e) => {
            let texto = e.to_string();
            assert!(
                texto.contains(&hash_corrompido.to_string())
                    || texto.contains("Firma")
                    || texto.contains("firma"),
                "el error debería señalar el fallo de firma del bloque {hash_corrompido}: {texto}"
            );
        }
        Ok(_) => panic!(
            "el nodo debió negarse a arrancar: el testigo del bloque {hash_corrompido} está corrupto"
        ),
    }
}
