#![feature(generic_const_exprs)]
#![expect(incomplete_features, reason = "ab-proof-of-space usa generic_const_exprs")]

//! Extrae las medianas de las salidas crudas de Criterion y de los binarios de barrido, y escribe
//! el fichero de entrada del modelo Julia.
//!
//! Nada de esto teclea una cifra: solo parsea lo que produjo el banco Rust. Si un numero no se
//! encuentra en un fichero, NO se escribe: el modelo fallara al pedirlo en vez de inventarlo.

use std::collections::BTreeMap;
use std::path::Path;

fn factor(unidad: &str) -> Option<f64> {
    match unidad {
        "ns" => Some(1e-9),
        "us" | "µs" => Some(1e-6),
        "ms" => Some(1e-3),
        "s" => Some(1.0),
        _ => None,
    }
}

/// Parsea las lineas `time: [lo unidad mid unidad hi unidad]` de Criterion.
///
/// Formatos reales observados:
///   `m1/tabla_1_hilo_semilla_fija`
///   `                        time:   [744.66 ms 757.82 ms 770.18 ms]`
/// y en una sola linea:
///   `m3/kzg_poly_pieza_1MiB  time:   [1.3231 ms 1.3426 ms 1.3670 ms]`
fn parsear_criterion(texto: &str, salida: &mut BTreeMap<String, (f64, String)>) {
    let mut ultimo_nombre: Option<String> = None;
    for linea in texto.lines() {
        let t = linea.trim();
        // Criterion imprime el nombre y el tiempo en la MISMA linea cuando el nombre es corto
        // (`m2_w10000/por_bucket   time: [...]`) y en dos lineas cuando es largo. Hay que cubrir
        // las dos formas; si no, se pierden claves y el modelo se niega a inventarlas.
        if let Some(pos) = t.find("time:") {
            let antes = t[..pos].trim();
            let nombre = if antes.is_empty() {
                ultimo_nombre.clone()
            } else if antes.contains("change") || antes.contains("thrpt") {
                None
            } else {
                ultimo_nombre = Some(antes.to_string());
                Some(antes.to_string())
            };
            if let Some(nombre) = nombre {
                if let Some((mediana, unidad)) = extraer_triple(&t[pos + "time:".len()..]) {
                    salida.insert(nombre, (mediana, unidad));
                }
            }
        } else if !t.is_empty()
            && !t.starts_with("change:")
            && !t.starts_with("thrpt:")
            && !t.starts_with("Benchmarking")
            && !t.starts_with("Found")
            && !t.starts_with("Collecting")
            && !t.starts_with("Warming")
            && !t.starts_with("Analyzing")
            && !t.starts_with("Performance")
            && !t.starts_with("No change")
            && !t.starts_with('[')
            && !t.starts_with('#')
            && !t.starts_with("RAM")
            && !t.starts_with("MODO")
            && !t.starts_with("METRICA")
        {
            ultimo_nombre = Some(t.to_string());
        }
    }
}

fn extraer_triple(resto: &str) -> Option<(f64, String)> {
    let interior = resto.trim().trim_start_matches('[').trim_end_matches(']');
    let piezas: Vec<&str> = interior.split_whitespace().collect();
    // lo unidad mid unidad hi unidad  => 6 piezas
    if piezas.len() != 6 {
        return None;
    }
    let mediana: f64 = piezas[2].parse().ok()?;
    let unidad = piezas[3].to_string();
    let f = factor(&unidad)?;
    Some((mediana * f, unidad))
}

fn main() {
    let raiz = std::env::args()
        .nth(1)
        .unwrap_or_else(|| "mediciones".to_string());
    let raiz = Path::new(&raiz);

    let mut tiempos: BTreeMap<String, (f64, String)> = BTreeMap::new();
    let ficheros = [
        "m1_tabla.txt",
        "m2_reto.txt",
        "m3_ganador.txt",
        "m4_cono.txt",
    ];
    for f in ficheros {
        let ruta = raiz.join(f);
        if let Ok(texto) = std::fs::read_to_string(&ruta) {
            parsear_criterion(&texto, &mut tiempos);
        } else {
            eprintln!("[exportar] falta {ruta:?}: no se escriben sus claves");
        }
    }

    let mut salida = std::fs::File::create(raiz.join("modelo-entrada.tsv"))
        .expect("fichero de salida; qed");
    use std::io::Write as _;
    writeln!(salida, "clave\tmediana_s\tunidad_original\tfuente\testado").expect("escritura; qed");

    for (nombre, (segundos, unidad)) in &tiempos {
        let fuente = if nombre.starts_with("m1/") {
            "mediciones/m1_tabla.txt"
        } else if nombre.starts_with("m2") {
            "mediciones/m2_reto.txt"
        } else if nombre.starts_with("m3") {
            "mediciones/m3_ganador.txt"
        } else {
            "mediciones/m4_cono.txt"
        };
        writeln!(
            salida,
            "criterion/{nombre}\t{segundos:.12e}\t{unidad}\t{fuente}\tmedido"
        )
        .expect("escritura; qed");
    }

    // Hilos con los que se midio el camino paralelo: salen del entorno de la corrida.
    let hilos = std::env::var("RAYON_NUM_THREADS").unwrap_or_else(|_| "sin_definir".to_string());
    writeln!(
        salida,
        "banco/rayon_hilos\t{hilos}\thilos\tentorno de la corrida\tconfigurado"
    )
    .expect("escritura; qed");

    // Barrido agregado por hilos: lineas `# MEDIANA\tmodo\thilos\ttablas_por_s=..\tms_por_tabla=..`
    if let Ok(texto) = std::fs::read_to_string(raiz.join("m1_escalado.txt")) {
        for linea in texto.lines() {
            if let Some(resto) = linea.strip_prefix("# MEDIANA\t") {
                let campos: Vec<&str> = resto.split('\t').collect();
                if campos.len() >= 3 {
                    let modo = campos[0];
                    let hilos = campos[1];
                    if let Some(v) = campos[2].strip_prefix("tablas_por_s=") {
                        writeln!(
                            salida,
                            "escalado/{modo}/{hilos}hilos\t{v}\ttablas/s\tmediciones/m1_escalado.txt\tmedido"
                        )
                        .expect("escritura; qed");
                    }
                }
            }
        }
    }

    // Coste de las siete tablas (Instant, n=3).
    if let Ok(texto) = std::fs::read_to_string(raiz.join("m4_cono_tablas.txt")) {
        for linea in texto.lines() {
            let campos: Vec<&str> = linea.split('\t').collect();
            if campos.len() == 2 && campos[1].parse::<f64>().is_ok() {
                writeln!(
                    salida,
                    "cono/{}\t{}\ts\tmediciones/m4_cono_tablas.txt\tmedido",
                    campos[0], campos[1]
                )
                .expect("escritura; qed");
            }
        }
    }

    // Distribucion de pruebas: o medido.
    if let Ok(texto) = std::fs::read_to_string(raiz.join("distribucion.txt")) {
        for linea in texto.lines() {
            let campos: Vec<&str> = linea.split('\t').collect();
            if campos.len() == 2 && campos[0] == "O_MEDIDO" {
                writeln!(
                    salida,
                    "distribucion/o\t{}\tprobabilidad\tmediciones/distribucion.txt\tmedido",
                    campos[1]
                )
                .expect("escritura; qed");
            }
            if campos.len() == 2 && campos[0] == "BUCKET_MAX_VISTO" {
                writeln!(
                    salida,
                    "distribucion/bucket_max\t{}\tindice\tmediciones/distribucion.txt\tmedido",
                    campos[1]
                )
                .expect("escritura; qed");
            }
        }
    }

    // RAM por tabla viva.
    if let Ok(texto) = std::fs::read_to_string(raiz.join("m1_ram.txt")) {
        for linea in texto.lines() {
            let campos: Vec<&str> = linea.split('\t').collect();
            for c in campos {
                if let Some(v) = c.strip_prefix("byte_por_tabla=") {
                    writeln!(
                        salida,
                        "ram/byte_por_tabla\t{v}\tbytes\tmediciones/m1_ram.txt\tmedido"
                    )
                    .expect("escritura; qed");
                }
                if let Some(v) = c.strip_prefix("sizeof_Proofs=") {
                    writeln!(
                        salida,
                        "ram/sizeof_Proofs20\t{v}\tbytes\tmediciones/m1_ram.txt\tmedido"
                    )
                    .expect("escritura; qed");
                }
            }
        }
    }

    eprintln!(
        "[exportar] {} claves de Criterion escritas en {}",
        tiempos.len(),
        raiz.join("modelo-entrada.tsv").display()
    );
}
