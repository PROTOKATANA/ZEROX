//! `ORDEN-W07a` V2: test de integración (en proceso) del registro estructurado.
//!
//! Un proceso cruza el corte, produce y persiste bloques PoW y PoST, y luego se reabre (repetición
//! del almacén). Después se comprueba, **línea por línea**, que cada evento es un objeto JSON plano
//! con los campos comunes (`tipo`, `reloj_ns`, `reloj_pared_ns`) y los campos de su tipo en el §1 de
//! `ESQUEMA-REGISTRO-v1.md`, y que el conjunto de tipos observado cubre los que esta ejecución en
//! proceso puede producir. Los tipos que solo aparecen con red (`bloque_recibido`,
//! `bloque_red_admitido`, `bloque_red_rechazado`, `bloque_red_huerfano`, huérfanos, par y límite) se
//! cubren en V3 (tres procesos reales) y así se declara en la tabla de cobertura del `INFORME.md`.
//!
//! No se añade `serde_json`: el parser es manual, como el de `integracion.rs`.

#![expect(
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    reason = "el test falla con panic por diseño; el parser manual indexa cadenas ya comprobadas"
)]

use std::collections::BTreeSet;

use zx_core::Red;
use zx_node::nodo::{Config, Nodo};

const N_DEV_TEST: u64 = 32;
const SR_DEV_TEST: u64 = u64::MAX;

fn config_de_test(dir: &std::path::Path) -> Config {
    Config {
        dir_datos: dir.join("datos"),
        ruta_registro: dir.join("registro.jsonl"),
        red: Red::Dev,
        semilla: 0x5a5a,
        indices_claves: vec![0, 1, 2],
        n_dev: N_DEV_TEST,
        sr_dev: SR_DEV_TEST,
        parada_tras_slots: Some(12),
        dejar_de_producir_en_slot: None,
    }
}

/// Tipos del §1 (salvo los tres de SL-4b2) y campos propios de cada uno.
fn campos_del_tipo(tipo: &str, familia: Option<&str>) -> Option<&'static [&'static str]> {
    match tipo {
        "arranque" => Some(&["version_esquema", "n_dev", "sr_dev", "claves", "modo"]),
        "reinicio_completo" => Some(&[
            "bloques_repetidos",
            "duracion_ns",
            "punta",
            "resumen_estado",
            "n_bloques_dag",
            "compendio_bloques",
        ]),
        "bloque_minado" => Some(&["hash", "altura", "bytes", "n_txs"]),
        "bloque_producido" => Some(&[
            "hash",
            "slot",
            "n_padres",
            "n_txs",
            "bytes",
            "azules_mergeset",
            "rojos_mergeset",
        ]),
        "bloque_recibido" => Some(&["hash", "familia", "bytes"]),
        "bloque_red_admitido" => match familia {
            Some("pow") => Some(&[
                "hash",
                "familia",
                "altura",
                "bytes",
                "t_cabecera_ns",
                "t_admision_ns",
                "t_persistencia_ns",
                "t_total_ns",
                "n_bloques_dag",
            ]),
            Some("post") => Some(&[
                "hash",
                "familia",
                "slot",
                "n_padres",
                "bytes",
                "t_cabecera_ns",
                "t_admision_ns",
                "t_persistencia_ns",
                "t_total_ns",
                "n_bloques_dag",
                "azules_mergeset",
                "rojos_mergeset",
                "txs_descartadas",
            ]),
            _ => None,
        },
        "bloque_red_rechazado" => {
            Some(&["hash", "familia", "etapa", "motivo", "t_hasta_rechazo_ns"])
        }
        "bloque_red_huerfano" => Some(&["hash", "familia", "padres_ausentes"]),
        "huerfano_resuelto" => Some(&["hash"]),
        "huerfano_desalojado" => Some(&["hash", "motivo"]),
        "cambio_punta" => Some(&["punta", "resumen_estado", "profundidad_reorg"]),
        "reorganizacion_pow" => Some(&["punta_anterior", "punta_nueva", "profundidad"]),
        "par_conectado" | "par_desconectado" => Some(&["par"]),
        "par_penalizado" => Some(&["par", "motivo", "accion"]),
        "limite_alcanzado" => Some(&["limite", "detalle"]),
        "parada" => Some(&[
            "motivo",
            "punta",
            "resumen_estado",
            "n_bloques_dag",
            "compendio_bloques",
        ]),
        // `ESQUEMA-REGISTRO-v1.md` §1 bis: eventos de diagnóstico restaurados por `ORDEN-W07a-R`
        // (el analizador los ignora sin error; aquí se validan sus campos como los del §1).
        "dejar_de_producir" => Some(&["motivo"]),
        // `ORDEN-W07d` decisión 3: el bloque de transición propio ya no queda sin rastro; tipo
        // propio para no alterar lo que cuenta `reinicio.rs`.
        "bloque_transicion_producido" => Some(&["hash", "slot"]),
        "bloque_red_pendiente" => Some(&["hash", "familia", "motivo", "veredicto"]),
        "bloque_red_ignorado_sin_penalizar" => Some(&["hash", "familia", "motivo"]),
        "bloque_post_gossip_descartado_sincronizando" => Some(&["hash", "padre_ausente"]),
        "bloque_propio_rechazado_legitimo" => Some(&["hash", "motivo"]),
        "bloque_post_de_red_sin_terminal" => Some(&["hash"]),
        _ => None,
    }
}

fn es_entero(v: &str) -> bool {
    !v.is_empty() && v.bytes().all(|b| b.is_ascii_digit())
}

fn es_hex64(v: &str) -> bool {
    v.len() == 64 && v.bytes().all(|b| b.is_ascii_hexdigit())
}

/// Extrae los pares `clave -> valor crudo` de un objeto JSON plano (sin objetos anidados), con
/// soporte de cadenas, números y listas de cadenas.
fn campos_json(linea: &str) -> Vec<(String, String)> {
    let l = linea.trim();
    assert!(l.starts_with('{') && l.ends_with('}'), "no es objeto: {l}");
    let interior = &l[1..l.len() - 1];
    let bytes = interior.as_bytes();
    let mut campos = Vec::new();
    let mut i = 0usize;
    loop {
        while i < bytes.len() && (bytes[i] == b' ' || bytes[i] == b',') {
            i += 1;
        }
        if i >= bytes.len() {
            break;
        }
        assert_eq!(bytes[i], b'"', "clave sin comillas en: {l}");
        let (clave, fin) = extraer_cadena(interior, i);
        i = fin;
        while i < bytes.len() && bytes[i] == b' ' {
            i += 1;
        }
        assert_eq!(bytes[i], b':', "falta ':' en: {l}");
        i += 1;
        while i < bytes.len() && bytes[i] == b' ' {
            i += 1;
        }
        let inicio_valor = i;
        if bytes[i] == b'"' {
            let (_, fin) = extraer_cadena(interior, i);
            i = fin;
        } else if bytes[i] == b'[' {
            let mut prof = 0i32;
            let mut dentro = false;
            while i < bytes.len() {
                match bytes[i] {
                    b'"' => dentro = !dentro,
                    b'[' if !dentro => prof += 1,
                    b']' if !dentro => {
                        prof -= 1;
                        if prof == 0 {
                            i += 1;
                            break;
                        }
                    }
                    _ => {}
                }
                i += 1;
            }
        } else {
            while i < bytes.len() && bytes[i] != b',' {
                i += 1;
            }
        }
        campos.push((clave, interior[inicio_valor..i].trim().to_string()));
    }
    campos
}

/// Devuelve `(cadena_sin_comillas, índice_tras_la_comilla_de_cierre)`.
fn extraer_cadena(s: &str, inicio: usize) -> (String, usize) {
    let bytes = s.as_bytes();
    assert_eq!(bytes[inicio], b'"');
    let mut i = inicio + 1;
    let mut valor = String::new();
    while i < bytes.len() {
        match bytes[i] {
            b'\\' => {
                valor.push(bytes[i + 1] as char);
                i += 2;
            }
            b'"' => return (valor, i + 1),
            b => {
                valor.push(b as char);
                i += 1;
            }
        }
    }
    panic!("cadena sin cerrar");
}

#[test]
fn los_eventos_cumplen_el_esquema_y_cubren_los_tipos_en_proceso() {
    let dir = tempfile::tempdir().expect("tempdir");
    let cfg = config_de_test(dir.path());

    let mut nodo = Nodo::arrancar(&cfg).expect("arranque limpio");
    nodo.ejecutar().expect("ejecución sin rechazos fatales");
    assert!(nodo.cadena().terminal().is_some(), "debe cruzar el corte");
    // Cerrar el almacén antes de reabrirlo (RocksDB no permite dos handles del mismo directorio).
    drop(nodo);

    // Reapertura: emite `reinicio_completo` (repetición del almacén).
    let _reabierto = Nodo::arrancar(&cfg).expect("reabrir y repetir el almacén");

    let contenido = std::fs::read_to_string(&cfg.ruta_registro).expect("leer el registro");
    let mut vistos: BTreeSet<String> = BTreeSet::new();
    let mut n_lineas = 0usize;
    for linea in contenido.lines() {
        if linea.trim().is_empty() {
            continue;
        }
        n_lineas += 1;
        let campos = campos_json(linea);
        let get = |k: &str| campos.iter().find(|(c, _)| c == k).map(|(_, v)| v.as_str());
        // Campos comunes, en cualquier posición.
        let tipo_raw = get("tipo").unwrap_or_else(|| panic!("sin tipo: {linea}"));
        let tipo = extraer_cadena(tipo_raw, 0).0;
        for comun in ["reloj_ns", "reloj_pared_ns"] {
            let v = get(comun).unwrap_or_else(|| panic!("{tipo} sin {comun}: {linea}"));
            assert!(es_entero(v), "{tipo}.{comun} no es entero: {v}");
        }
        let familia = get("familia").map(|v| extraer_cadena(v, 0).0);
        let requeridos = campos_del_tipo(&tipo, familia.as_deref())
            .unwrap_or_else(|| panic!("tipo fuera del §1: {tipo}: {linea}"));
        for k in requeridos {
            let v =
                get(k).unwrap_or_else(|| panic!("{tipo} sin el campo obligatorio {k}: {linea}"));
            assert!(!v.is_empty(), "{tipo}.{k} vacío: {linea}");
            if *k == "hash" {
                assert!(
                    es_hex64(&extraer_cadena(v, 0).0),
                    "{tipo}.hash no hex64: {v}"
                );
            }
        }
        vistos.insert(tipo);
    }
    assert!(n_lineas > 0, "el registro no debe estar vacío");

    // Cobertura de lo que una ejecución en proceso puede producir.
    let exigidos = [
        "arranque",
        "reinicio_completo",
        "bloque_minado",
        "bloque_producido",
        "cambio_punta",
        "parada",
    ];
    for t in exigidos {
        assert!(
            vistos.contains(t),
            "no se observó el evento {t}; vistos={vistos:?}"
        );
    }
    eprintln!(
        "V2: {n_lineas} líneas; tipos observados en proceso = {vistos:?}; (los de red, en V3)"
    );
}
