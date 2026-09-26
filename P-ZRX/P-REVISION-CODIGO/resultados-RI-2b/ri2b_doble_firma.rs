//! RI-2b — comprobación dirigida: ¿el orden `cadena.admitir` antes de `almacen.admitir` en
//! `Nodo::admitir_post_interno` (crates/zx-node/src/nodo.rs) permite que una clave firme dos
//! bloques PoST distintos para el mismo slot tras un `SIGKILL`?
//!
//! Hipótesis: si el proceso muere entre las dos escrituras, el bloque queda "producido" en la
//! `Cadena` en memoria (se pierde igualmente al morir el proceso) pero el `ServicioPot` de
//! verificación, reconstruido tras reiniciar SOLO desde lo persistido, no avanza hasta ese slot.
//! Como el PoT es una función determinista de (terminal, N_dev) y el productor vuelve a auditar la
//! MISMA `salida` para ese slot con la MISMA parcela, la misma clave puede volver a ganar y producir
//! un segundo bloque, distinto solo en el timestamp/sello, para el mismo slot. Si ese segundo intento
//! sí se persiste, el almacén acumulado (que sobrevive a todos los reinicios en el mismo directorio)
//! queda con dos `BloquePost` distintos que comparten `(productor, slot)`: una equivocación real.
//!
//! Se lanza el binario real muchas veces con `SR_dev = u64::MAX` (ganadores casi seguros cada slot,
//! para maximizar el número de admisiones PoST por segundo y la probabilidad de que el `SIGKILL`
//! caiga en la ventana entre las dos escrituras) y `SIGKILL` con una espera aleatoria muy corta
//! (semilla fija) tras cruzar el corte, muchas rondas. Al final se reabre el almacén acumulado y se
//! busca la colisión `(productor, slot)`.

#![expect(
    clippy::expect_used,
    clippy::panic,
    reason = "el test falla con panic por diseño"
)]

use std::collections::HashMap;
use std::path::Path;
use std::process::{Child, Command, Stdio};
use std::time::{Duration, Instant};

use zx_core::Red;
use zx_node::nodo::{Config, Nodo};

const N_DEV_TEST: &str = "32";
const SR_DEV_TEST: &str = "18446744073709551615"; // u64::MAX

const SEMILLA_ESPERA: u64 = 0x52_49_32_62_5f_64_66;
/// Rondas cortas concentradas en la fase de régimen, donde la tasa de admisión PoST es alta.
/// Cada ronda exige progreso real (>= 1 bloque PoST nuevo) antes de matar, así que el número se
/// mantiene moderado dado el presupuesto de la revisión.
const RONDAS_REGIMEN: u32 = 10;

fn espera_micros(ronda: u32) -> u64 {
    let mut z = SEMILLA_ESPERA ^ u64::from(ronda).wrapping_mul(0x9e37_79b9_7f4a_7c15);
    z = z.wrapping_add(0x9e37_79b9_7f4a_7c15);
    z = (z ^ (z >> 30)).wrapping_mul(0xbf58_476d_1ce4_e5b9);
    z = (z ^ (z >> 27)).wrapping_mul(0x94d0_49bb_1331_11eb);
    z ^= z >> 31;
    z % 4_000
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
            "4660",
            "--claves",
            "0,1,2",
            "--n-dev",
            N_DEV_TEST,
            "--sr-dev",
            SR_DEV_TEST,
            "--parada-tras-slots",
            "1000000",
        ])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .expect("lanza zx-node")
}

fn esperar_senal_de_vida(ruta_registro: &Path) {
    let limite = Instant::now() + Duration::from_secs(60);
    loop {
        if let Ok(meta) = std::fs::metadata(ruta_registro)
            && meta.len() > 0
        {
            return;
        }
        assert!(
            Instant::now() < limite,
            "el nodo no dio señales de vida en 60 s"
        );
        std::thread::sleep(Duration::from_millis(20));
    }
}

/// Colisiones `(productor, slot)`: pares que aparecen en más de un `BloquePost` del almacén
/// acumulado (todos los reinicios comparten el mismo directorio de datos).
fn colisiones_productor_slot(nodo: &Nodo) -> Vec<([u8; 32], u64, usize)> {
    let mut visto: HashMap<([u8; 32], u64), usize> = HashMap::new();
    for p in nodo.cadena().bloques_post() {
        let clave: ([u8; 32], u64) = (*p.productor.bytes(), p.slot);
        *visto.entry(clave).or_insert(0) += 1;
    }
    visto
        .into_iter()
        .filter(|(_, n)| *n > 1)
        .map(|((prod, slot), n)| (prod, slot, n))
        .collect()
}

#[test]
fn sigkill_repetido_en_regimen_no_debe_producir_dos_bloques_del_mismo_slot_por_la_misma_clave() {
    let dir = tempfile::tempdir().expect("tempdir");
    // RI-2b: no se borra al terminar (ni con panic), para poder inspeccionar el registro/almacén
    // tras un fallo de la prueba. Diagnóstico, no parte del hallazgo.
    let dir_ruta = dir.keep();
    eprintln!("[RI-2b] directorio de datos: {}", dir_ruta.display());
    let ruta_registro = dir_ruta.join("registro.jsonl");
    let dir = dir_ruta.as_path();

    // Fase de calentamiento: deja correr hasta cruzar el corte y producir varios bloques PoST,
    // sin matar durante el PoW (no es el objeto de esta prueba).
    {
        let limite = Instant::now() + Duration::from_secs(420);
        let mut hijo = lanzar(dir);
        esperar_senal_de_vida(&ruta_registro);
        loop {
            let contenido = std::fs::read_to_string(&ruta_registro).unwrap_or_default();
            let vistos = contenido.matches("\"bloque_producido\"").count();
            if vistos >= 3 {
                break;
            }
            assert!(
                Instant::now() < limite,
                "no se cruzó el corte y se produjeron >=3 bloques PoST en 420 s"
            );
            assert!(
                hijo.try_wait().ok().flatten().is_none(),
                "el nodo de calentamiento terminó solo"
            );
            std::thread::sleep(Duration::from_millis(50));
        }
        hijo.kill().expect("mata al hijo de calentamiento");
        hijo.wait().expect("lo entierra");
    }

    let mut vistos_totales: Vec<usize> = Vec::new();
    let mut objetivo_producidos = {
        let contenido = std::fs::read_to_string(&ruta_registro).unwrap_or_default();
        contenido.matches("\"bloque_producido\"").count()
    };
    for ronda in 1..=RONDAS_REGIMEN {
        let mut hijo = lanzar(dir);
        esperar_senal_de_vida(&ruta_registro);
        // A diferencia de una espera ciega: primero se exige que ESTA ronda produzca al menos un
        // bloque PoST nuevo (si no, el `kill` casi siempre cae durante la reapertura/repetición,
        // cada vez más cara según crece la historia, y nunca llega a ejercitar la ventana entre
        // `cadena.admitir` y `almacen.admitir` en régimen). Después, una espera pseudoaleatoria muy
        // corta (microsegundos, semilla fija) para no sincronizar el `kill` con ningún evento
        // concreto dentro de esa ventana de producción.
        objetivo_producidos += 1;
        let limite = Instant::now() + Duration::from_secs(45);
        loop {
            let contenido = std::fs::read_to_string(&ruta_registro).unwrap_or_default();
            let vistos = contenido.matches("\"bloque_producido\"").count();
            if vistos >= objetivo_producidos {
                break;
            }
            assert!(
                Instant::now() < limite,
                "ronda {ronda}: no se vio un bloque_producido nuevo (objetivo {objetivo_producidos}) en 20 s"
            );
            if hijo.try_wait().ok().flatten().is_some() {
                // Terminó solo (no debería): se cuenta como ronda sin progreso y se continúa.
                break;
            }
            std::thread::sleep(Duration::from_micros(200));
        }
        std::thread::sleep(Duration::from_micros(espera_micros(ronda)));
        hijo.kill().expect("mata al hijo");
        hijo.wait().expect("lo entierra");

        let cfg = config_de_test(dir, 0);
        let nodo = Nodo::arrancar(&cfg)
            .unwrap_or_else(|e| panic!("ronda {ronda}: reabrir tras SIGKILL falló: {e}"));
        vistos_totales.push(nodo.cadena().bloques_post().len());

        let colisiones = colisiones_productor_slot(&nodo);
        assert!(
            colisiones.is_empty(),
            "ronda {ronda}: colisión (productor, slot) tras SIGKILL: {colisiones:?} \
             (equivocación: la misma clave firmó dos bloques PoST distintos para el mismo slot)"
        );
        drop(nodo);
    }

    // Que el `kill` no esté sincronizado con nada: si todas las rondas vieran el mismo número de
    // bloques PoST acumulados, esta prueba no probaría gran cosa.
    let mut distintos = vistos_totales.clone();
    distintos.sort_unstable();
    distintos.dedup();
    assert!(
        distintos.len() > 1,
        "todas las rondas vieron el mismo número de bloques PoST acumulados ({vistos_totales:?})"
    );
}
