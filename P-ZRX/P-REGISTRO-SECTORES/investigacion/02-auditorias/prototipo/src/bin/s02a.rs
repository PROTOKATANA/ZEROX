//! Driver de medición de S02a: coste real de regenerar para contestar una auditoría sobre R2.
//!
//! Modos (todos con `RAYON_NUM_THREADS` fijado por el invocador; semilla por CLI):
//!
//! ```text
//! s02a treg    <piezas> <reps>
//! s02a validar <piezas> <posiciones> <lvals_csv>
//! s02a medir   <piezas> <aperturas> <lvals_csv>
//! ```
//!
//! Sin Python. Compilación `--release`. Los resultados se escriben a stdout en TSV; la
//! clasificación estadística (mediana, p99) se hace fuera con `sort`/`awk`.

use std::env;
use std::fs;
use std::time::Instant;

use prototipo_s01::estrategias::{
    Estrategia, almacenamiento_bytes, camino_arbol, construir_solucion, posiciones_fisicas,
    producir_apertura,
};
use prototipo_s01::merkle::vacio;
use prototipo_s01::r2::Apertura;
use prototipo_s01::regeneracion::TablaRegistro;
use prototipo_s01::sector::{Entorno, ErrorSector, ParametrosPlot, Sector};
use subspace_core_primitives::pos::PosProof;
use subspace_core_primitives::pieces::Record;

/// Semilla por defecto si no se pasa CLI.
const SEMILLA_DEFECTO: u64 = 0x5a5a_5a5a_5a5a_5a5a;

/// RNG splitmix64 determinista (mismo generador que el fixture, sin dependencias nuevas).
struct Rng(u64);

impl Rng {
    fn nuevo(semilla: u64) -> Self {
        Self(semilla | 1)
    }
    fn siguiente(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }
    fn indice(&mut self, n: usize) -> usize {
        (self.siguiente() % (n as u64)) as usize
    }
}

/// RAM máxima (pico) del proceso, en KiB.
fn vmhwm_kib() -> u64 {
    let texto = fs::read_to_string("/proc/self/status").unwrap_or_default();
    for linea in texto.lines() {
        if let Some(resto) = linea.strip_prefix("VmHWM:") {
            return resto
                .trim()
                .split_whitespace()
                .next()
                .and_then(|s| s.parse().ok())
                .unwrap_or(0);
        }
    }
    0
}

/// Tiempo de CPU del proceso (suma de `runtime_ns` de todas las tareas), en ns.
fn cpu_ns() -> u128 {
    let mut total = 0u128;
    if let Ok(dir) = fs::read_dir("/proc/self/task") {
        for entrada in dir.flatten() {
            if let Ok(texto) = fs::read_to_string(entrada.path().join("schedstat")) {
                if let Some(primero) = texto.split_whitespace().next() {
                    total += primero.parse::<u128>().unwrap_or(0);
                }
            }
        }
    }
    total
}

fn hilos() -> u64 {
    env::var("RAYON_NUM_THREADS")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(0)
}

fn lvals(csv: &str) -> Vec<usize> {
    csv.split(',')
        .filter_map(|s| s.trim().parse::<usize>().ok())
        .collect()
}

/// Lista de estrategias medidas: E-disco, E-árbol(L) para cada `L` pedido y E-nada.
///
/// `E-árbol(profundidad)` no se duplica con `E-nada`.
fn lista_estrategias(lvals: &[usize], profundidad: usize) -> Vec<Estrategia> {
    let mut v = vec![Estrategia::Disco];
    for &l in lvals {
        if l < profundidad && !v.contains(&Estrategia::Arbol(l)) {
            v.push(Estrategia::Arbol(l));
        }
    }
    v.push(Estrategia::Nada);
    v
}

/// Posiciones con `codificado == 1`: son las que una solución ganadora puede abrir.
fn indices_cod1(posiciones: &[(u16, u16, u8)]) -> Vec<usize> {
    posiciones
        .iter()
        .enumerate()
        .filter(|(_, (_, _, cod))| *cod == 1)
        .map(|(i, _)| i)
        .collect()
}

/// Muestrea `n` posiciones (con reemplazo) entre las codificadas.
fn muestrear(rng: &mut Rng, indices: &[usize], n: usize) -> Vec<usize> {
    (0..n).map(|_| indices[rng.indice(indices.len())]).collect()
}

/// Regenera todas las hojas del sector con tablas reales y las coteja con el sector almacenado.
///
/// Devuelve `(hojas_regeneradas, pruebas, chunks_discrepantes)`:
/// - `hojas`: vector de longitud `m = next_pow2(n)` con las hojas regeneradas (relleno `vacío`).
/// - `pruebas`: `Option<PosProof>` por posición (solo las codificadas tienen).
/// - `chunks_discrepantes`: cuántos chunks regenerados difieren del fichero de sector.
fn regenerar_todo(
    entorno: &Entorno,
    _p: &ParametrosPlot,
    sector: &Sector,
    posiciones: &[(u16, u16, u8)],
    records: &[Box<Record>],
) -> Result<(Vec<[u8; 32]>, Vec<Option<PosProof>>, usize, usize), ErrorSector> {
    let n = sector.campos.n as usize;
    let m = sector.arbol.hojas_rellenadas();
    let (mapa_sz, _, _) = sector.tamanos_regiones();
    let mut hojas = vec![vacio(); m];
    let mut pruebas: Vec<Option<PosProof>> = vec![None; n];
    let mut discrepancias = 0usize;
    let mut hojas_discrepantes = 0usize;

    let mut por_offset: Vec<Vec<usize>> = vec![Vec::new(); records.len()];
    for (j, (_, po, _)) in posiciones.iter().enumerate() {
        por_offset[usize::from(*po)].push(j);
    }

    for (po, indices) in por_offset.iter().enumerate() {
        if indices.is_empty() {
            continue;
        }
        let tabla = TablaRegistro::desde_pieza(entorno, &records[po], &sector.sector_id, po as u16)?;
        for &j in indices {
            let (sb, po_j, cod) = posiciones[j];
            let ch = tabla.chunk_para_hoja(sb, cod)?;
            let ini = mapa_sz + j * 32;
            let almacenado: [u8; 32] = sector.bytes[ini..ini + 32]
                .try_into()
                .map_err(|_| ErrorSector::Coherencia("chunk almacenado fuera de rango".into()))?;
            if ch != almacenado {
                discrepancias += 1;
            }
            let h = prototipo_s01::r2::hoja(sb, po_j, cod, &ch);
            if h != sector.arbol.hojas()[j] {
                hojas_discrepantes += 1;
            }
            hojas[j] = h;
            if cod == 1 {
                pruebas[j] = tabla.proof(sb);
            }
        }
    }
    Ok((hojas, pruebas, discrepancias, hojas_discrepantes))
}

/// Construye la apertura a partir de hojas ya regeneradas (modo corrección, sin volver a regenerar).
fn apertura_desde_hojas(
    sector: &Sector,
    posiciones: &[(u16, u16, u8)],
    hojas: &[[u8; 32]],
    estrategia: Estrategia,
    i: usize,
) -> Result<Apertura, ErrorSector> {
    let (s_bucket, piece_offset, codificado) = posiciones[i];
    let camino = match estrategia {
        Estrategia::Disco => sector.arbol.camino(i),
        Estrategia::Arbol(l) => {
            let start = (i >> l) << l;
            let bloque = 1usize << l;
            camino_arbol(&sector.arbol, i, l, &hojas[start..start + bloque])
        }
        Estrategia::Nada => camino_arbol(&sector.arbol, i, sector.arbol.profundidad(), hojas),
    };
    Ok(Apertura {
        chunk_location: i as u32,
        camino,
        codificado,
        raiz_chunks: sector.arbol.raiz(),
        digest_mapa: sector.digest_mapa,
        digest_meta: sector.digest_meta,
        s_bucket,
        piece_offset,
    })
}

/// Chunk almacenado de la posición `i` leído del fichero de sector.
fn chunk_almacenado_disco(sector: &Sector, i: usize) -> Result<[u8; 32], ErrorSector> {
    let (mapa_sz, _, _) = sector.tamanos_regiones();
    let ini = mapa_sz + i * 32;
    sector.bytes[ini..ini + 32]
        .try_into()
        .map_err(|_| ErrorSector::Coherencia("chunk almacenado fuera de rango".into()))
}

fn chunk_fuente_desde_mascara(mascara: &[u8; 32], proof: &PosProof) -> [u8; 32] {
    let ph: [u8; 32] = *proof.hash();
    let mut salida = [0u8; 32];
    for i in 0..32 {
        salida[i] = mascara[i] ^ ph[i];
    }
    salida
}

struct Contexto {
    entorno: Entorno,
    p: ParametrosPlot,
    sector: Sector,
    posiciones: Vec<(u16, u16, u8)>,
    records: Vec<Box<Record>>,
    indices_cod1: Vec<usize>,
    profundidad: usize,
    m: usize,
}

impl Contexto {
    fn construir(piezas: u16) -> Result<Self, ErrorSector> {
        let entorno = Entorno::construir_dev()?;
        let p = ParametrosPlot {
            pieces_in_sector: piezas,
            ..ParametrosPlot::default()
        };
        let sector = entorno.plotear(&p)?;
        let posiciones = posiciones_fisicas(&sector)?;
        let records: Vec<Box<Record>> = (0..piezas)
            .map(|po| TablaRegistro::pieza_de(&entorno, &p, &sector.sector_id, po))
            .collect::<Result<_, _>>()?;
        let indices_cod1 = indices_cod1(&posiciones);
        let profundidad = sector.arbol.profundidad();
        let m = sector.arbol.hojas_rellenadas();
        Ok(Self {
            entorno,
            p,
            sector,
            posiciones,
            records,
            indices_cod1,
            profundidad,
            m,
        })
    }

    fn cabecera(&self, modo: &str) -> String {
        format!(
            "{modo}\tpiezas={}\thilos={}\tn={}\tm={}\tprofundidad={}\tcod1={}\tsector_bytes={}",
            self.p.pieces_in_sector,
            hilos(),
            self.sector.campos.n,
            self.m,
            self.profundidad,
            self.indices_cod1.len(),
            self.sector.bytes.len()
        )
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = env::args().collect();
    let modo = args.get(1).cloned().unwrap_or_else(|| "treg".to_string());

    match modo.as_str() {
        "treg" => modo_treg(&args),
        "validar" => modo_validar(&args),
        "medir" => modo_medir(&args),
        otro => {
            eprintln!("modo desconocido: {otro}");
            Ok(())
        }
    }
}

/// `treg <piezas> <reps>`: mide generación de tabla + codificación erasure por registro.
fn modo_treg(args: &[String]) -> Result<(), Box<dyn std::error::Error>> {
    let piezas: u16 = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(2);
    let reps: usize = args.get(3).and_then(|s| s.parse().ok()).unwrap_or(5);
    let ctx = Contexto::construir(piezas)?;
    println!(
        "modo\tpiezas\thilos\trep\tregistro\tt_reg_ns\tcpu_ns\tvmhwm_kib"
    );
    for rep in 0..reps {
        for po in 0..piezas {
            let t = Instant::now();
            let _tabla = TablaRegistro::desde_pieza(
                &ctx.entorno,
                &ctx.records[usize::from(po)],
                &ctx.sector.sector_id,
                po,
            )?;
            let wall = t.elapsed().as_nanos();
            println!(
                "treg\t{}\t{}\t{}\t{}\t{}\t{}\t{}",
                piezas,
                hilos(),
                rep,
                po,
                wall,
                0,
                vmhwm_kib()
            );
        }
    }
    Ok(())
}

/// `validar <piezas> <posiciones> <lvals>`: regenera y coteja todo el sector, y verifica
/// `posiciones` aperturas por estrategia contra R2 con el verificador de S01.
fn modo_validar(args: &[String]) -> Result<(), Box<dyn std::error::Error>> {
    let piezas: u16 = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(2);
    let npos: usize = args.get(3).and_then(|s| s.parse().ok()).unwrap_or(100);
    let lv = lvals(args.get(4).map(String::as_str).unwrap_or("0,1,2,4"));
    let ctx = Contexto::construir(piezas)?;
    println!("{}", ctx.cabecera("validar"));

    let t = Instant::now();
    let (hojas, pruebas, discrepancias, hojas_disc) = regenerar_todo(
        &ctx.entorno,
        &ctx.p,
        &ctx.sector,
        &ctx.posiciones,
        &ctx.records,
    )?;
    println!(
        "REGENERACION\tpiezas={}\thilos={}\tn={}\tchunks_discrepantes={}\thojas_discrepantes={}\tt_reg_total_ns={}\tvmhwm_kib={}",
        piezas,
        hilos(),
        ctx.sector.campos.n,
        discrepancias,
        hojas_disc,
        t.elapsed().as_nanos(),
        vmhwm_kib()
    );

    let mut rng = Rng::nuevo(SEMILLA_DEFECTO ^ u64::from(piezas));
    let muestras = muestrear(&mut rng, &ctx.indices_cod1, npos);
    let r2 = ctx.sector.r2();
    for estrategia in lista_estrategias(&lv, ctx.profundidad) {
        let mut fallos = 0usize;
        for &i in &muestras {
            let apertura =
                apertura_desde_hojas(&ctx.sector, &ctx.posiciones, &hojas, estrategia, i)?;
            let proof = pruebas[i].ok_or_else(|| {
                ErrorSector::Coherencia(format!("sin prueba en posición codificada {i}"))
            })?;
            let mascara = chunk_almacenado_disco(&ctx.sector, i)?;
            let fuente = chunk_fuente_desde_mascara(&mascara, &proof);
            let sol = construir_solucion(&ctx.sector, &ctx.posiciones, i, &fuente, proof)?;
            if prototipo_s01::r2::verificar_apertura(
                &r2,
                &apertura,
                &sol,
                apertura.s_bucket,
                &ctx.sector.campos,
            )
            .is_err()
            {
                fallos += 1;
            }
        }
        println!(
            "CORRECCION\tpiezas={}\thilos={}\testrategia={}\tL={:?}\tposiciones={}\tfallos={}",
            piezas,
            hilos(),
            estrategia.etiqueta(),
            estrategia.nivel(ctx.profundidad),
            muestras.len(),
            fallos
        );
    }
    Ok(())
}

/// `medir <piezas> <aperturas> <lvals>`: mide `aperturas` aperturas vivas por estrategia.
fn modo_medir(args: &[String]) -> Result<(), Box<dyn std::error::Error>> {
    let piezas: u16 = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(2);
    let naperturas: usize = args.get(3).and_then(|s| s.parse().ok()).unwrap_or(30);
    let lv = lvals(args.get(4).map(String::as_str).unwrap_or("0,1,2,4"));
    let ctx = Contexto::construir(piezas)?;
    println!("{}", ctx.cabecera("medir"));
    println!(
        "modo\tpiezas\thilos\testrategia\tL\tapertura\tposicion\ttablas\thojas\twall_ns\tcpu_ns\tverif\talmacenamiento_bytes\tvmhwm_kib"
    );

    let mut rng = Rng::nuevo(SEMILLA_DEFECTO ^ (u64::from(piezas) << 32));
    let muestras = muestrear(&mut rng, &ctx.indices_cod1, naperturas);
    let r2 = ctx.sector.r2();

    // Pruebas para E-disco (una tabla por registro, fuera del camino cronometrado).
    let mut offsets_disco: Vec<u16> = Vec::new();
    for &i in &muestras {
        let po = ctx.posiciones[i].1;
        if !offsets_disco.contains(&po) {
            offsets_disco.push(po);
        }
    }
    let mut pruebas_disco: Vec<Option<PosProof>> = vec![None; muestras.len()];
    for po in offsets_disco {
        let tabla = TablaRegistro::desde_pieza(
            &ctx.entorno,
            &ctx.records[usize::from(po)],
            &ctx.sector.sector_id,
            po,
        )?;
        for (k, &i) in muestras.iter().enumerate() {
            let (sb, po_i, _) = ctx.posiciones[i];
            if po_i == po {
                pruebas_disco[k] = tabla.proof(sb);
            }
        }
    }

    for estrategia in lista_estrategias(&lv, ctx.profundidad) {
        let almacenamiento =
            almacenamiento_bytes(estrategia, ctx.sector.bytes.len(), ctx.m);
        // Calentamiento.
        for &i in muestras.iter().take(2) {
            let _ = producir_apertura(
                &ctx.entorno,
                &ctx.p,
                &ctx.sector,
                &ctx.posiciones,
                &ctx.records,
                estrategia,
                i,
            )?;
        }
        for (k, &i) in muestras.iter().enumerate() {
            let cpu0 = cpu_ns();
            let t = Instant::now();
            let ap = producir_apertura(
                &ctx.entorno,
                &ctx.p,
                &ctx.sector,
                &ctx.posiciones,
                &ctx.records,
                estrategia,
                i,
            )?;
            let wall = t.elapsed().as_nanos();
            let cpu = cpu_ns().saturating_sub(cpu0);

            let (fuente, proof) = if let Estrategia::Disco = estrategia {
                let proof = pruebas_disco[k].ok_or_else(|| {
                    ErrorSector::Coherencia(format!("sin prueba disco en {i}"))
                })?;
                (chunk_fuente_desde_mascara(&ap.chunk_almacenado, &proof), proof)
            } else {
                (
                    ap.chunk_fuente.ok_or_else(|| {
                        ErrorSector::Coherencia(format!("sin chunk fuente en {i}"))
                    })?,
                    ap.proof
                        .ok_or_else(|| ErrorSector::Coherencia(format!("sin prueba en {i}")))?,
                )
            };
            let sol = construir_solucion(&ctx.sector, &ctx.posiciones, i, &fuente, proof)?;
            let verif = prototipo_s01::r2::verificar_apertura(
                &r2,
                &ap.apertura,
                &sol,
                ap.apertura.s_bucket,
                &ctx.sector.campos,
            )
            .is_ok();

            println!(
                "medir\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}",
                piezas,
                hilos(),
                estrategia.etiqueta(),
                estrategia.nivel(ctx.profundidad).map_or(-1, |l| l as i64),
                k,
                i,
                ap.tablas,
                ap.hojas,
                wall,
                cpu,
                u8::from(verif),
                almacenamiento,
                vmhwm_kib()
            );
        }
    }
    Ok(())
}
